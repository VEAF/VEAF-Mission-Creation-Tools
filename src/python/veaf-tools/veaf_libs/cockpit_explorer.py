"""Explore a live cockpit both ways: name a control to see it, or move one to name it.

Writing a checklist means knowing three things about a control — its element, its
animation argument, and the value of the position you want. For the aircraft the resolver
covers, it reads them from the index. For the others there was nothing: the AH-64D names
7 controls' position values out of 478, so an author had no route short of reading Lua.

**Moving the switch is that route.** Read every argument of the aircraft at once, wait for
one to change, and the control names itself — with a *measured* value rather than an
inferred one. The reverse direction, boxing a named control, is what proved useful first:
during ticket 04's session the pilot could not find the hydraulic transfer pump.

One Lua call reads the whole cockpit, not one per control: the F-16C has 284 and the
AH-64D 478, and a round trip each would make the loop unusable.

See ``.backlog/FEAT-ASSIST-AUTHORING/tickets/08-explore-cockpit.md``.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from veaf_libs.checklist_verifier import LuaRunner, VerificationError

#: A reading has to move by more than this to count as the pilot having done something.
#: Loose enough to ignore an argument that jitters, tight enough to catch a two-position
#: switch whose travel is 0 to 1.
CHANGE_THRESHOLD = 0.02

#: Arguments read per Lua call. The whole cockpit goes in one round trip, but a single
#: string holding 478 results is worth splitting rather than discovering a limit in game.
BATCH_SIZE = 150


@dataclass(frozen=True)
class ControlChange:
    """A control the pilot just moved.

    Attributes:
        element: Its cockpit element name.
        hint: What DCS shows on mouse-over.
        argument: Its animation argument.
        value: What the argument reads now — a **measured** position value.
        was: What it read before.
        position: The name of the position, when the index knows one for this value.
    """

    element: str
    hint: str
    argument: int
    value: float
    was: float
    position: str | None = None

    def as_step(self, label: str = "...") -> str:
        """Render this control as the checklist step an author would paste in.

        Field names, not prose: this is YAML for a file, not a message for a reader.
        """
        fields = (
            ("label", label),
            ("element", self.element),
            ("argument", self.argument),
            ("equals", self.value),
        )
        return "\n".join(f"  {'- ' if name == 'label' else '  '}{name}: {value}" for name, value in fields)


def arguments_of(index: dict[str, Any]) -> list[int]:
    """Return every animation argument the index knows, in ascending order.

    Duplicates are dropped: several elements can share an argument — a switch and its
    guard, a control and its per-seat twin — and reading it twice tells us nothing new.
    """
    return sorted({int(entry["argument"]) for entry in index.get("controls", {}).values() if "argument" in entry})


def read_many(run_lua: LuaRunner, arguments: list[int]) -> dict[int, float]:
    """Read a batch of animation arguments in as few round trips as possible.

    Args:
        run_lua: Runs Lua in the mission environment.
        arguments: The animation arguments to read.

    Returns:
        Argument -> current value. An argument the cockpit does not answer for is absent
        rather than zero: a missing reading and a reading of zero mean different things.

    Raises:
        VerificationError: when there is no cockpit to read at all.
    """
    readings: dict[int, float] = {}
    for start in range(0, len(arguments), BATCH_SIZE):
        batch = arguments[start : start + BATCH_SIZE]
        listed = ",".join(str(argument) for argument in batch)
        reply = run_lua(
            'local ok, res = pcall(function() return net.dostring_in("export", '
            f"\"local d = GetDevice(0) if not d then return 'nodevice' end "
            f"local out = {{}} for _, a in ipairs({{{listed}}}) do "
            f"out[#out+1] = a .. '=' .. tostring(d:get_argument_value(a)) end return table.concat(out, ',')\")"
            " end) return tostring(res)"
        )
        if "nodevice" in str(reply):
            raise VerificationError(
                "no cockpit to read — is a pilot sitting in the aircraft, on this machine, with the bridge connected?"
            )
        readings.update(_parse_readings(str(reply)))
    if not readings:
        raise VerificationError("the cockpit returned no readings at all")
    return readings


def _parse_readings(reply: str) -> dict[int, float]:
    """Parse ``510=-1,566=0`` into a mapping, skipping anything malformed."""
    readings: dict[int, float] = {}
    for pair in reply.split(","):
        argument, separator, value = pair.partition("=")
        if not separator:
            continue
        try:
            readings[int(argument.strip())] = float(value.strip())
        except ValueError:
            continue
    return readings


def identify(before: dict[int, float], after: dict[int, float], index: dict[str, Any]) -> list[ControlChange]:
    """Name the controls whose argument moved between two readings.

    Args:
        before: The previous reading.
        after: The current one.
        index: The aircraft's control index.

    Returns:
        One entry per changed argument, richest first — a control whose position this can
        name is more useful to an author than one it cannot. An argument no element of the
        index claims is skipped: it moved, but there is nothing to say about it.
    """
    by_argument: dict[int, dict[str, Any]] = {}
    for element, entry in index.get("controls", {}).items():
        if "argument" in entry:
            by_argument.setdefault(int(entry["argument"]), {**entry, "element": element})

    changes: list[ControlChange] = []
    for argument, value in after.items():
        was = before.get(argument)
        if was is None or abs(value - was) <= CHANGE_THRESHOLD:
            continue
        entry = by_argument.get(argument)
        if entry is None:
            continue
        changes.append(
            ControlChange(
                element=str(entry["element"]),
                hint=str(entry.get("hint", "")),
                argument=argument,
                value=value,
                was=was,
                position=_position_named(entry.get("values") or {}, value),
            )
        )
    return sorted(changes, key=lambda change: (change.position is None, change.element))


def _position_named(values: dict[str, float], value: float) -> str | None:
    """Return the position whose value matches, when the index knows one."""
    for name, known in values.items():
        if abs(float(known) - value) <= CHANGE_THRESHOLD:
            return str(name)
    return None
