"""Give a mission's sequence tables one known shape, once, on the read path.

A Lua table reaches Python as a **list** when its keys are a contiguous ``1..N`` and as a **dict**
otherwise — the parser flattens the contiguous case. Every reader here picks one and assumes it, so
eight of them are right on a well-formed mission and silently wrong on a holed one. A hand edit, a
third-party tool or a deletion is enough to produce the other, and the build then dies with
``AttributeError: 'int' object has no attribute 'get'`` at whichever subsystem happened to read the
table first — a line nowhere near the edit.

Three things were measured on 2026-08-19 before any of this was written, with the settings
``write_miz`` passes to ``luadata.serialize``:

- a list and the contiguous ``1..N`` dict it came from serialise **byte-identically**, so normalising
  an untouched mission changes nothing;
- a holed dict serialises with its holes intact (``[1]``, ``[3]``);
- the parser already returns a *list* for both the list and the contiguous dict, and a dict only when
  the keys are holed.

Hence the normal form here is a **list** — the opposite of what `FIX-WAREHOUSES-LIST-FORM` chose for
airfields, and for a reason: DCS keys ``warehouses.airports`` by **airdrome id**, so that key carries
information; a group container's key carries nothing but position.

**This is deliberately path-scoped rather than "every numeric-keyed table".** ``payload.pylons`` is
keyed by **station number** — a real FA-18C carries stations 1, 4, 5, 6 and 9 — so a blanket
normalisation would renumber them to ``1..5`` and move every weapon to a different pylon. Silently.
That is the very family of defect this module exists to stop, so the spec below names the sequences
instead of guessing them, and anything absent from it is left exactly as it is.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from veaf_libs.mission_table import CATEGORIES, numeric_first

__all__ = ["HoleClosed", "normalise_mission_sequences"]

#: Marks a spec level whose keys are not known in advance (a coalition side, a category, an index).
_ANY = "*"


@dataclass(frozen=True)
class HoleClosed:
    """One container whose keys were not a contiguous ``1..N``, and what they became."""

    path: str
    """Dotted path to the container, e.g. ``coalition.blue.country[1].plane.group``."""
    keys: tuple[Any, ...]
    """The keys as they were found, in table order."""

    def __str__(self) -> str:
        shown = ", ".join(str(key) for key in self.keys)
        return f"{self.path}: keys {shown} -> 1..{len(self.keys)}"


@dataclass(frozen=True)
class _Spec:
    """One node of the sequence spec: is the value here a sequence, and what lies under it."""

    sequence: bool = False
    """True when the value at this key is a sequence to normalise."""
    children: dict[str, _Spec] = field(default_factory=dict)
    """Sub-specs by key; ``_ANY`` matches every key at that level."""


def _seq(**children: _Spec) -> _Spec:
    return _Spec(sequence=True, children=children)


def _node(**children: _Spec) -> _Spec:
    return _Spec(sequence=False, children=children)


#: A waypoint's task is a ComboTask whose params hold more tasks, nested to any depth.
_TASKS: _Spec = _node(params=_node())
_TASKS.children["params"].children["tasks"] = _Spec(sequence=True, children={_ANY: _TASKS})

#: One group: its units, and its route's waypoints with their tasks. `payload` is absent on purpose.
_GROUP: _Spec = _node(
    units=_seq(),
    route=_node(points=_seq(**{_ANY: _node(task=_TASKS)})),
)

#: Every category of a country holds a `group` sequence.
_COUNTRY: _Spec = _node(**{category: _node(group=_seq(**{_ANY: _GROUP})) for category in CATEGORIES})

#: The mission table's sequences, enumerated from the readers that already treat them as such.
_MISSION_SPEC: _Spec = _node(
    coalition=_node(**{_ANY: _node(country=_seq(**{_ANY: _COUNTRY}))}),
    coalitions=_node(**{_ANY: _seq()}),
    triggers=_node(zones=_seq(**{_ANY: _node(verticies=_seq(), vertices=_seq())})),
    drawings=_node(layers=_seq(**{_ANY: _node(objects=_seq())})),
)


def normalise_mission_sequences(content: Any) -> list[HoleClosed]:
    """Rewrite every sequence table of a parsed mission as a list, in place.

    Args:
        content: The parsed ``mission`` table. Anything that is not a mapping is left alone, so a
            caller need not check first.

    Returns:
        One :class:`HoleClosed` per container whose keys were not already a contiguous ``1..N``.
        Empty for a well-formed mission — normalising it is a no-op, measured byte-identical.
    """
    holes: list[HoleClosed] = []
    if isinstance(content, dict):
        _descend(content, _MISSION_SPEC, "", holes)
    return holes


def _descend(node: Any, spec: _Spec, path: str, holes: list[HoleClosed]) -> None:
    """Walk `node` against `spec`, normalising the sequences the spec names."""
    if not isinstance(node, dict):
        return
    for key, sub_spec in _matching(spec, node):
        value = node.get(key)
        if value is None:
            continue
        if sub_spec.sequence:
            value = _as_list(node, key, f"{path}{key}", holes)
        _descend_into(value, sub_spec, f"{path}{key}", holes)


def _matching(spec: _Spec, node: dict[Any, Any]) -> list[tuple[Any, _Spec]]:
    """Pair each of `node`'s keys with the sub-spec that applies to it."""
    wildcard = spec.children.get(_ANY)
    pairs: list[tuple[Any, _Spec]] = []
    for key in node:
        named = spec.children.get(key) if isinstance(key, str) else None
        chosen = named or wildcard
        if chosen is not None:
            pairs.append((key, chosen))
    return pairs


def _descend_into(value: Any, spec: _Spec, path: str, holes: list[HoleClosed]) -> None:
    """Continue the walk below a value, whether it is a list of items or a plain mapping.

    A sequence's children describe **one item**, under ``_ANY`` — they are not the keys of the
    sequence itself. Walking the items against the sequence's own spec looks almost right and finds
    nothing, which is how this first went wrong.
    """
    if not spec.sequence:
        _descend(value, spec, f"{path}.", holes)
        return
    item_spec = spec.children.get(_ANY)
    if item_spec is None or not isinstance(value, list):
        return
    for index, item in enumerate(value, start=1):
        _descend(item, item_spec, f"{path}[{index}].", holes)


def _as_list(parent: dict[Any, Any], key: Any, path: str, holes: list[HoleClosed]) -> Any:
    """Return the container at `parent[key]` as a list, recording a hole when there was one."""
    container = parent.get(key)
    if isinstance(container, list):
        return container
    if not isinstance(container, dict):
        return container

    ordered = sorted(container.keys(), key=numeric_first)
    if not ordered:
        # An empty list, never a removed key: `tasks = {}` is what DCS writes on every waypoint with
        # no task, so dropping it would change a mission nobody touched. The two serialise identically
        # (measured), so this is free — and it is what `setdefault(key, []).append(...)` needs, since
        # `setdefault` returns the existing empty dict rather than applying its `[]` default.
        parent[key] = []
        return parent[key]

    # A digit-string key is repaired rather than reported: it is contiguous, just wrongly typed.
    if [_position(k) for k in ordered] != list(range(1, len(ordered) + 1)):
        holes.append(HoleClosed(path=path, keys=tuple(ordered)))
    as_list = [container[k] for k in ordered]
    parent[key] = as_list
    return as_list


def _position(key: Any) -> int | None:
    """Read a container key as a 1-based position, or ``None`` when it is not one.

    A digit **string** counts: `luadata` renders ``{"1": …}`` as ``["1"]``, a different Lua entry from
    ``[1]``, and no real mission uses it — so a digit-string key is an unambiguous error to repair
    rather than a shape to preserve. Measured against every mission under ``test/veaf-tools``: all of
    them write ``[1]``.
    """
    if isinstance(key, bool):
        return None
    if isinstance(key, int):
        return key
    if isinstance(key, str) and key.isdigit():
        return int(key)
    return None
