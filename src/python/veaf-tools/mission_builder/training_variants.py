"""Training versions of a mission night, built with it (FEAT-ROLE-TRAINING-VARIANTS).

A ``training:`` block in ``mission.yaml`` makes the build produce, beside the night's ``.miz``, one
training version per role — ``TRAINING_A2G``, ``TRAINING_CAP``, ``TRAINING_SEAD`` — and a common one,
``TRAINING_ALL``. Each is a build profile **derived** here, never written into ``mission.yaml``.

The block says two things:

- ``elements``: what each element of the night **is** — ``enemy_cap``, ``qra``, ``sam_lr``,
  ``a2g_target``, ``sam_threat`` — so a version can take out what its role assumes already done.
  An element nobody declares stays in every version.
- ``randomize``: what the briefing describes **vaguely**. In a training version, the groups such an
  entry ``replaces`` leave their fixed place, and a combat zone draws among the entry's ``pool`` at
  every launch — the existing ``#spawngroup`` / ``#spawncount`` / ``#spawnradius`` markers do the
  drawing. The night's mission keeps the fixed groups: it is the definitive one.

A ``pool`` candidate is one of three kinds: ``command`` (a fake unit carrying ``#command="-sa15"``),
``group`` (a group of the night **adopted** as it is — renamed under the zone's prefix so the zone
captures it, the markers added to its first unit's name) or ``units`` (a ground group the build
creates from DCS types). Renaming breaks whatever names the group elsewhere — a trigger's script, a
module of ``mission.yaml``, a mission script — and DCS says nothing, so a referenced group is refused
(decision D6 of the lot).

The work is split in two because the build is: the configuration Lua is written before the mission
table is read back from the ``.miz``. :func:`plan_variant` therefore reads the **source** mission
table, decides everything, and returns both the configuration to build with and the table edits;
:func:`apply_to_mission` replays those edits on the table the build carries.
"""

from __future__ import annotations

import copy
import math
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from veaf_libs.dcs_units_data import get_unit_category
from veaf_libs.i18n import t
from veaf_libs.mission_table import indexed
from veaf_libs.shortcut_eras import era_of_alias

from mission_builder.group_removal import iter_group_slots, matches_any, name_matches, remove_groups

#: The training versions, in the order the build emits them.
ROLES: tuple[str, ...] = ("A2G", "CAP", "SEAD", "ALL")

#: What an element of the night can be.
KINDS: tuple[str, ...] = ("enemy_cap", "qra", "sam_lr", "a2g_target", "sam_threat")

#: Prefix of the derived build profiles, and so of the ``.miz`` suffix: ``_TRAINING_A2G``.
PROFILE_PREFIX = "TRAINING_"

#: Key a derived profile sets, naming its role; the builder reads it.
VARIANT_KEY = "training_variant"

#: Prefix of a combat zone the build injects for a draw.
DRAW_ZONE_PREFIX = "TRAINING-"

#: The kinds each version takes out: the state "the other roles have done their job".
REMOVED_KINDS: dict[str, frozenset[str]] = {
    "A2G": frozenset({"enemy_cap", "qra", "sam_lr"}),
    "CAP": frozenset({"a2g_target"}),
    "SEAD": frozenset({"enemy_cap", "qra", "a2g_target"}),
    "ALL": frozenset(),
}

#: The versions whose QRA is forced on.
FORCED_QRA_ROLES: frozenset[str] = frozenset({"CAP"})

#: DCS unit categories a draw may place: ground units only.
_GROUND_CATEGORIES = frozenset({"Air Defence", "Armor", "Artillery", "Infantry", "Unarmed", "MissilesSS"})

_RANGE = re.compile(r"^\d+(-\d+)?$")
_DRAW_NAME = re.compile(r"^[A-Za-z0-9_-]+$")
_SELECTORS = ("groups", "zone", "qra", "cap_mission")
_CANDIDATE_KEYS = ("group", "command", "units")

#: Smallest radius of an injected trigger zone, and the margin around the groups it must contain.
_MIN_ZONE_RADIUS = 500.0
_ZONE_MARGIN = 200.0
#: Spacing between the units of a group the build creates, as `add_group` spaces them.
_UNIT_SPACING = 15.0

_YAML_LABEL = "mission.yaml"

#: The marker of a unit whose command runs once, at mission start (`veafInterpreter`).
_INTERPRETER = "#veafInterpreter"


class TrainingError(ValueError):
    """The ``training:`` block cannot be built; the message says what and where."""


@dataclass(frozen=True)
class TrainingElement:
    """One element of the night and what it is."""

    kind: str
    groups: tuple[str, ...] = ()
    zone: str | None = None
    qra: str | None = None
    cap_mission: str | None = None


@dataclass(frozen=True)
class UnitSpec:
    """A DCS unit type and how many of it."""

    type: str
    count: int = 1


@dataclass(frozen=True)
class PoolCandidate:
    """One candidate of a draw: exactly one of ``group``, ``command`` or ``units``."""

    group: str | None = None
    command: str | None = None
    carrier: str | None = None
    units: tuple[UnitSpec, ...] = ()


@dataclass(frozen=True)
class Draw:
    """A vague element of the night, drawn again at every launch of a training version."""

    name: str
    replaces: tuple[str, ...]
    pool: tuple[PoolCandidate, ...]
    count: str = "1"
    radius: str = "0"
    at: tuple[float, float] | None = None


@dataclass(frozen=True)
class TrainingPlan:
    """The parsed ``training:`` block."""

    elements: tuple[TrainingElement, ...] = ()
    draws: tuple[Draw, ...] = ()


@dataclass
class GroupEdit:
    """A group a draw creates in the mission table."""

    side: str
    country_id: int
    country_name: str
    group: dict[str, Any]


@dataclass
class ResolvedDraw:
    """A draw placed against the mission: which zone hosts it and what it does to the table."""

    draw: Draw
    host_zone: str
    inject_zone: bool
    center: tuple[float, float]
    zone_radius: float
    removed: list[str] = field(default_factory=list)
    adopted: dict[str, str] = field(default_factory=dict)
    """Adopted group's name → its name in the training version (the same when not renamed)."""
    markers: dict[str, str] = field(default_factory=dict)
    """Group name in the training version → the markers its first unit's name gains."""
    created: list[GroupEdit] = field(default_factory=list)


@dataclass
class VariantPlan:
    """Everything one training version changes: the configuration and the mission table."""

    role: str
    config: dict[str, Any]
    removed_groups: list[str] = field(default_factory=list)
    draws: list[ResolvedDraw] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ── parsing ──────────────────────────────────────────────────────────────────────────────────────


def training_block(yaml_data: dict[str, Any]) -> object:
    """The raw ``training:`` value of ``mission.yaml``, or ``None`` when absent."""
    return yaml_data.get("training") if isinstance(yaml_data, dict) else None


def parse_training(raw: object) -> tuple[TrainingPlan | None, list[str]]:
    """Parse a ``training:`` block into a :class:`TrainingPlan`.

    Args:
        raw: The block as YAML loaded it.

    Returns:
        ``(plan, errors)``: ``plan`` is ``None`` when the block is absent or any error was found.
    """
    if raw is None:
        return None, []
    if not isinstance(raw, dict):
        return None, [t("training.not_a_mapping")]
    errors: list[str] = []
    elements = tuple(_parse_elements(raw.get("elements"), errors))
    draws = tuple(_parse_draws(raw.get("randomize"), errors))
    for key in raw:
        if key not in ("elements", "randomize"):
            errors.append(t("training.unknown_key", field=key))
    if errors:
        return None, errors
    return TrainingPlan(elements=elements, draws=draws), []


def _as_names(value: object) -> tuple[str, ...] | None:
    """A name or a list of names as a tuple, or ``None`` when it is neither."""
    if isinstance(value, str) and value:
        return (value,)
    if isinstance(value, list) and value and all(isinstance(item, str) and item for item in value):
        return tuple(value)
    return None


def _parse_elements(raw: object, errors: list[str]) -> list[TrainingElement]:
    """Parse ``training.elements``, appending to ``errors``."""
    if raw is None:
        return []
    if not isinstance(raw, list):
        errors.append(t("training.elements_not_a_list"))
        return []
    elements: list[TrainingElement] = []
    for index, entry in enumerate(raw, start=1):
        where = f"training.elements[{index}]"
        if not isinstance(entry, dict):
            errors.append(t("training.entry_not_a_mapping", where=where))
            continue
        kind = entry.get("kind")
        if kind not in KINDS:
            errors.append(t("training.unknown_kind", where=where, kind=kind, kinds=", ".join(KINDS)))
            continue
        selectors = [key for key in _SELECTORS if key in entry]
        if len(selectors) != 1:
            errors.append(t("training.one_selector", where=where, selectors=", ".join(_SELECTORS)))
            continue
        selector = selectors[0]
        if selector == "groups":
            names = _as_names(entry["groups"])
            if names is None:
                errors.append(t("training.bad_names", where=where, field="groups"))
                continue
            elements.append(TrainingElement(kind=kind, groups=names))
        else:
            value = entry[selector]
            if not isinstance(value, str) or not value:
                errors.append(t("training.bad_names", where=where, field=selector))
                continue
            elements.append(
                TrainingElement(
                    kind=kind,
                    zone=value if selector == "zone" else None,
                    qra=value if selector == "qra" else None,
                    cap_mission=value if selector == "cap_mission" else None,
                )
            )
    return elements


def _parse_range(value: object, default: str) -> str | None:
    """A ``count`` or ``radius``: a whole number or ``min-max``, as the markers write them."""
    if value is None:
        return default
    if isinstance(value, bool):
        return None
    text = str(value).replace(" ", "")
    if not _RANGE.match(text):
        return None
    low, _, high = text.partition("-")
    if high and int(high) < int(low):
        return None
    return text


def range_max(value: str) -> int:
    """The upper bound of a ``min-max`` range, or the number itself."""
    return int(value.rpartition("-")[2])


def _parse_candidate(raw: object, where: str, errors: list[str]) -> PoolCandidate | None:
    """Parse one ``pool`` candidate, appending to ``errors``."""
    if not isinstance(raw, dict):
        errors.append(t("training.entry_not_a_mapping", where=where))
        return None
    keys = [key for key in _CANDIDATE_KEYS if key in raw]
    if len(keys) != 1:
        errors.append(t("training.one_candidate_key", where=where, keys=", ".join(_CANDIDATE_KEYS)))
        return None
    carrier = raw.get("carrier")
    if carrier is not None and (not isinstance(carrier, str) or not carrier):
        errors.append(t("training.bad_names", where=where, field="carrier"))
        return None
    if keys[0] == "group":
        if not isinstance(raw["group"], str) or not raw["group"]:
            errors.append(t("training.bad_names", where=where, field="group"))
            return None
        return PoolCandidate(group=raw["group"])
    if keys[0] == "command":
        command = raw["command"]
        if not isinstance(command, str) or not command.strip():
            errors.append(t("training.bad_names", where=where, field="command"))
            return None
        return PoolCandidate(command=command.strip(), carrier=carrier)
    specs: list[UnitSpec] = []
    for unit in raw["units"] if isinstance(raw["units"], list) else [None]:
        count = unit.get("count", 1) if isinstance(unit, dict) else None
        if (
            not isinstance(unit, dict)
            or not isinstance(unit.get("type"), str)
            or not isinstance(count, int)
            or isinstance(count, bool)
            or count < 1
        ):
            errors.append(t("training.bad_units", where=where))
            return None
        specs.append(UnitSpec(type=unit["type"], count=count))
    if not specs:
        errors.append(t("training.bad_units", where=where))
        return None
    return PoolCandidate(units=tuple(specs))


def _parse_draws(raw: object, errors: list[str]) -> list[Draw]:
    """Parse ``training.randomize``, appending to ``errors``."""
    if raw is None:
        return []
    if not isinstance(raw, list):
        errors.append(t("training.randomize_not_a_list"))
        return []
    draws: list[Draw] = []
    seen: set[str] = set()
    for index, entry in enumerate(raw, start=1):
        where = f"training.randomize[{index}]"
        if not isinstance(entry, dict):
            errors.append(t("training.entry_not_a_mapping", where=where))
            continue
        name = entry.get("name")
        if not isinstance(name, str) or not _DRAW_NAME.match(name):
            errors.append(t("training.bad_draw_name", where=where))
            continue
        if name.lower() in seen:
            errors.append(t("training.duplicate_draw_name", where=where, name=name))
            continue
        seen.add(name.lower())
        replaces = _as_names(entry.get("replaces"))
        if replaces is None:
            errors.append(t("training.bad_names", where=where, field="replaces"))
            continue
        raw_pool = entry.get("pool")
        if not isinstance(raw_pool, list) or not raw_pool:
            errors.append(t("training.empty_pool", where=where))
            continue
        pool = [_parse_candidate(item, f"{where}.pool[{i}]", errors) for i, item in enumerate(raw_pool, start=1)]
        count = _parse_range(entry.get("count"), "1")
        radius = _parse_range(entry.get("radius"), "0")
        if count is None or radius is None:
            errors.append(t("training.bad_range", where=where))
            continue
        if range_max(count) > len(pool) or range_max(count) < 1:
            errors.append(t("training.count_exceeds_pool", where=where, count=count, size=len(pool)))
            continue
        at = entry.get("at")
        point: tuple[float, float] | None = None
        if at is not None:
            if not isinstance(at, dict) or not all(isinstance(at.get(k), (int, float)) for k in ("x", "y")):
                errors.append(t("training.bad_at", where=where))
                continue
            point = (float(at["x"]), float(at["y"]))
        if any(candidate is None for candidate in pool):
            continue
        draws.append(
            Draw(
                name=name,
                replaces=replaces,
                pool=tuple(c for c in pool if c is not None),
                count=count,
                radius=radius,
                at=point,
            )
        )
    return draws


# ── reading mission.yaml ────────────────────────────────────────────────────────────────────────


def _module(yaml_data: dict[str, Any], name: str) -> tuple[str | None, Any]:
    """A ``modules:`` entry by name, case-insensitively: ``(actual key, value)``."""
    modules = yaml_data.get("modules")
    if not isinstance(modules, dict):
        return None, None
    for key, value in modules.items():
        if str(key).upper() == name:
            return key, value
    return None, None


def _combat_zones(yaml_data: dict[str, Any]) -> list[dict[str, Any]]:
    """The ``modules.COMBATZONE.combat_zones`` entries."""
    _, cfg = _module(yaml_data, "COMBATZONE")
    entries = cfg.get("combat_zones") if isinstance(cfg, dict) else None
    return [entry for entry in entries or [] if isinstance(entry, dict)]


def _zone_name(entry: dict[str, Any]) -> str:
    """A combat zone entry's trigger-zone name."""
    return str(entry.get("zone_name") or entry.get("zone") or "")


def _qra_definitions(yaml_data: dict[str, Any]) -> list[dict[str, Any]]:
    """The ``modules.QRA.definitions`` entries."""
    _, cfg = _module(yaml_data, "QRA")
    entries = cfg.get("definitions") if isinstance(cfg, dict) else None
    return [entry for entry in entries or [] if isinstance(entry, dict)]


def _cap_missions(yaml_data: dict[str, Any]) -> list[dict[str, Any]]:
    """The top-level ``cap_missions`` entries."""
    return [entry for entry in yaml_data.get("cap_missions") or [] if isinstance(entry, dict)]


def _in_zone_by_prefix(group_name: str, zone: str) -> bool:
    """Whether a combat zone's prefix rule takes the group: case-insensitive, as `veafCombatZone` reads it."""
    return bool(zone) and group_name.upper().startswith(zone.upper())


# ── resolving against the mission ───────────────────────────────────────────────────────────────


@dataclass
class _GroupRef:
    side: str
    country: dict[str, Any]
    category: str
    group: dict[str, Any]

    @property
    def name(self) -> str:
        return str(self.group.get("name", ""))

    def first_unit(self) -> dict[str, Any] | None:
        units = indexed(self.group.get("units"))
        return units[0] if units and isinstance(units[0], dict) else None

    def position(self) -> tuple[float, float]:
        unit = self.first_unit() or self.group
        return float(unit.get("x", 0.0)), float(unit.get("y", 0.0))


def _groups_by_name(mission: dict[str, Any]) -> dict[str, _GroupRef]:
    """Every named group of the mission, by name (the first one when two share it)."""
    found: dict[str, _GroupRef] = {}
    for side, country, category, group in iter_group_slots(mission):
        name = str(group.get("name", ""))
        if name and name not in found:
            found[name] = _GroupRef(side, country, category, group)
    return found


def _trigger_zone_names(mission: dict[str, Any]) -> set[str]:
    """The names of the mission's trigger zones."""
    zones = (mission.get("triggers") or {}).get("zones")
    return {str(zone.get("name")) for zone in indexed(zones) if isinstance(zone, dict) and zone.get("name")}


def _matching(names: list[str], patterns: tuple[str, ...], where: str, errors: list[str]) -> list[str]:
    """The names matching the patterns; a pattern matching nothing is an error."""
    for pattern in patterns:
        if not any(name_matches(name, pattern) for name in names):
            errors.append(t("training.pattern_matches_nothing", where=where, pattern=pattern))
    return [name for name in names if matches_any(name, patterns)]


@dataclass
class _Resolved:
    """The plan placed against one mission, before any version is chosen."""

    explicit: dict[str, str]
    """Group name → kind, for groups an element names (by ``groups``)."""
    zone_groups: dict[str, list[str]]
    """Combat zone named by an element → the groups its prefix rule takes."""
    zone_kinds: dict[str, str]
    qra_kinds: dict[str, str]
    cap_kinds: dict[str, str]
    draws: list[ResolvedDraw]


def _resolve(
    plan: TrainingPlan,
    yaml_data: dict[str, Any],
    mission: dict[str, Any],
    references: list[tuple[str, str]],
    errors: list[str],
) -> _Resolved:
    """Place the plan against the mission, appending every problem to ``errors``."""
    groups = _groups_by_name(mission)
    names = list(groups)
    declared_zones = {_zone_name(entry) for entry in _combat_zones(yaml_data)} - {""}
    qra_names = {str(entry.get("name")) for entry in _qra_definitions(yaml_data) if entry.get("name")}
    cap_names = {str(entry.get("group_name")) for entry in _cap_missions(yaml_data) if entry.get("group_name")}

    explicit: dict[str, str] = {}
    zone_groups: dict[str, list[str]] = {}
    zone_kinds: dict[str, str] = {}
    qra_kinds: dict[str, str] = {}
    cap_kinds: dict[str, str] = {}
    for index, element in enumerate(plan.elements, start=1):
        where = f"training.elements[{index}]"
        if element.groups:
            for name in _matching(names, element.groups, where, errors):
                if name in explicit and explicit[name] != element.kind:
                    errors.append(t("training.group_two_kinds", group=name, first=explicit[name], second=element.kind))
                explicit[name] = element.kind
        elif element.zone is not None:
            if element.zone not in declared_zones:
                errors.append(t("training.unknown_zone", where=where, zone=element.zone))
                continue
            zone_kinds[element.zone] = element.kind
            zone_groups[element.zone] = [name for name in names if _in_zone_by_prefix(name, element.zone)]
        elif element.qra is not None:
            if element.qra not in qra_names:
                errors.append(t("training.unknown_qra", where=where, qra=element.qra))
                continue
            qra_kinds[element.qra] = element.kind
        elif element.cap_mission is not None:
            if element.cap_mission not in cap_names:
                errors.append(t("training.unknown_cap_mission", where=where, cap=element.cap_mission))
                continue
            cap_kinds[element.cap_mission] = element.kind

    draws: list[ResolvedDraw] = []
    claimed: dict[str, str] = {}
    for index, draw in enumerate(plan.draws, start=1):
        where = f"training.randomize[{index}]"
        resolved = _resolve_draw(draw, where, groups, declared_zones, yaml_data, references, explicit, errors)
        if resolved is None:
            continue
        for name in resolved.removed + list(resolved.adopted):
            if name in claimed:
                errors.append(t("training.group_two_draws", group=name, first=claimed[name], second=draw.name))
            claimed[name] = draw.name
        draws.append(resolved)
    return _Resolved(explicit, zone_groups, zone_kinds, qra_kinds, cap_kinds, draws)


def _resolve_draw(
    draw: Draw,
    where: str,
    groups: dict[str, _GroupRef],
    declared_zones: set[str],
    yaml_data: dict[str, Any],
    references: list[tuple[str, str]],
    explicit: dict[str, str],
    errors: list[str],
) -> ResolvedDraw | None:
    """Place one draw against the mission, or ``None`` when it cannot be."""
    count_before = len(errors)
    replaced = _matching(list(groups), draw.replaces, where, errors)
    for name in replaced:
        if name in explicit:
            errors.append(t("training.drawn_and_classified", group=name, draw=draw.name, kind=explicit[name]))
    pool_groups = [candidate.group for candidate in draw.pool if candidate.group]
    for name in pool_groups:
        if name not in replaced:
            errors.append(t("training.pool_group_not_replaced", where=where, group=name))
    for candidate in draw.pool:
        if candidate.command and candidate.command.startswith("-") and era_of_alias(candidate.command) is None:
            errors.append(t("training.unknown_command", where=where, command=candidate.command))
        for spec in candidate.units:
            _check_ground_type(spec.type, where, errors)
        if candidate.carrier:
            _check_ground_type(candidate.carrier, where, errors)
    refs = [groups[name] for name in replaced]
    for ref in refs:
        if ref.category not in ("vehicle", "static"):
            errors.append(t("training.not_a_ground_group", where=where, group=ref.name, category=ref.category))
        elif ref.name in pool_groups and any(
            _INTERPRETER in str((unit or {}).get("name", "")) for unit in indexed(ref.group.get("units"))
        ):
            # Its command runs at mission start and its carrier is destroyed: there is nothing left to draw.
            errors.append(t("training.interpreter_group", where=where, group=ref.name))
    if len(errors) > count_before or not refs:
        return None

    center = draw.at or _mean([ref.position() for ref in refs])
    host = _host_zone(replaced, declared_zones)
    inject = host is None
    host_zone = host or f"{DRAW_ZONE_PREFIX}{draw.name}"
    resolved = ResolvedDraw(draw=draw, host_zone=host_zone, inject_zone=inject, center=center, zone_radius=0.0)
    resolved.removed = [name for name in replaced if name not in pool_groups]

    markers = _markers(draw)
    first_marked = False
    for name in pool_groups:
        new_name = name if not inject else f"{host_zone}-{name}"
        if new_name != name:
            for label in _references_to(name, references):
                errors.append(t("training.referenced_group", where=where, group=name, source=label))
        resolved.adopted[name] = new_name
        resolved.markers[new_name] = markers if not first_marked else _without_count(markers)
        first_marked = True

    template = refs[0]
    carrier_default = _default_carrier(refs)
    for number, candidate in enumerate(draw.pool, start=1):
        if candidate.group:
            continue
        group_name = f"{host_zone}-{draw.name}-{number}"
        if group_name in groups:
            errors.append(t("training.name_taken", where=where, group=group_name))
            continue
        tags = markers if not first_marked else _without_count(markers)
        first_marked = True
        if candidate.command:
            carrier = candidate.carrier or carrier_default
            if carrier is None:
                errors.append(t("training.no_carrier", where=where, command=candidate.command))
                continue
            unit_name = f'#command="{candidate.command}" {tags} {group_name}'
            units = [{"type": carrier, "name": unit_name}]
        else:
            units = []
            for spec in candidate.units:
                for _ in range(spec.count):
                    units.append({"type": spec.type, "name": f"{group_name} #{len(units) + 1:02d}"})
            units[0]["name"] = f"{units[0]['name']} {tags}"
        resolved.created.append(
            GroupEdit(
                side=template.side,
                country_id=int(template.country.get("id", 0)),
                country_name=str(template.country.get("name", "")),
                group=_ground_group(group_name, center, units),
            )
        )

    spread = [_distance(center, ref.position()) for ref in refs if ref.name in pool_groups]
    resolved.zone_radius = max([_MIN_ZONE_RADIUS, *(d + _ZONE_MARGIN for d in spread)])
    if len(errors) > count_before:
        return None
    return resolved


def _check_ground_type(unit_type: str, where: str, errors: list[str]) -> None:
    """A type a draw may place: known to DCS, and a ground unit."""
    category = get_unit_category(unit_type)
    if category is None:
        errors.append(t("training.unknown_type", where=where, type=unit_type))
    elif category not in _GROUND_CATEGORIES:
        errors.append(t("training.not_a_ground_type", where=where, type=unit_type, category=category))


def _host_zone(replaced: list[str], declared_zones: set[str]) -> str | None:
    """The combat zone of the night all the replaced groups already belong to, if one does.

    The longest declared zone name prefixing every one of them wins, as the most specific one.
    """
    hosts = [zone for zone in declared_zones if all(_in_zone_by_prefix(name, zone) for name in replaced)]
    return max(hosts, key=len) if hosts else None


def _default_carrier(refs: list[_GroupRef]) -> str | None:
    """The carrier of a ``command`` candidate by default: the first ground unit type of the replaced groups.

    The authoring guide's rule: a carrier of the class the command spawns, so the editor's threat ring
    reads like what will spawn. The replaced groups are that class.
    """
    for ref in refs:
        for unit in indexed(ref.group.get("units")):
            unit_type = str((unit or {}).get("type", "")) if isinstance(unit, dict) else ""
            if get_unit_category(unit_type) in _GROUND_CATEGORIES:
                return unit_type
    return None


def _markers(draw: Draw) -> str:
    """The combat-zone markers every element of a draw carries; the count on the first one only.

    `veafCombatZone` folds the larger of the counts its elements state into their spawn group, and a
    ``1-2`` range is drawn per element: written on every element, the larger of several draws would win,
    biasing the count up. Written once, it is drawn once.
    """
    group = f"training-{draw.name}"
    markers = f'#spawngroup="{group}" #spawncount={draw.count} #spawnradius={draw.radius}'
    return markers


def _without_count(markers: str) -> str:
    """The markers without the ``#spawncount`` one."""
    return re.sub(r" #spawncount=\S+", "", markers)


def _ground_group(name: str, center: tuple[float, float], units: list[dict[str, Any]]) -> dict[str, Any]:
    """A stationary ground group in the shape `add_group` writes."""
    built = []
    for index, unit in enumerate(units):
        built.append(
            {
                "name": unit["name"],
                "type": unit["type"],
                "x": center[0] + index * _UNIT_SPACING,
                "y": center[1],
                "skill": "Average",
                "heading": 0,
                "playerCanDrive": True,
                "coldAtStart": False,
            }
        )
    return {
        "name": name,
        "x": center[0],
        "y": center[1],
        "task": "Ground Nothing",
        "route": {
            "points": [
                {
                    "x": center[0],
                    "y": center[1],
                    "alt": 0,
                    "alt_type": "BARO",
                    "type": "Turning Point",
                    "action": "Off Road",
                    "speed": 0,
                    "ETA": 0,
                    "ETA_locked": True,
                    "formation_template": "",
                    "name": "",
                    "speed_locked": True,
                    "task": {"id": "ComboTask", "params": {"tasks": []}},
                }
            ]
        },
        "units": built,
        "visible": False,
        "hidden": False,
        "lateActivation": False,
        "taskSelected": True,
        "uncontrollable": False,
        "start_time": 0,
    }


def _mean(points: list[tuple[float, float]]) -> tuple[float, float]:
    """The centroid of the points."""
    return sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points)


def _distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    """The distance between two points, in metres."""
    return math.hypot(a[0] - b[0], a[1] - b[1])


# ── references ──────────────────────────────────────────────────────────────────────────────────


def reference_sources(folder: Path | None, yaml_data: dict[str, Any], mission: dict[str, Any]) -> list[tuple[str, str]]:
    """Every text that may name a group, labelled for a message.

    ``mission.yaml`` without its ``training:`` block, the Mission Editor's trigger tables (where a DO
    SCRIPT may be written inline), and the files under ``src/mission/l10n`` (the dictionary that holds
    the other DO SCRIPT texts, and the scripts embedded by the editor) plus the ``custom_scripts`` the
    mission declares. The build's own generated scripts are left out: they are rendered from
    ``mission.yaml``, already searched.

    Args:
        folder: The mission folder, or ``None`` when only the tables are at hand.
        yaml_data: The parsed ``mission.yaml``.
        mission: The parsed DCS ``mission`` table.

    Returns:
        ``(label, text)`` pairs.
    """
    config = {key: value for key, value in yaml_data.items() if key != "training"}
    sources = [(_YAML_LABEL, "\n".join(sorted(_scalars(config))))]
    sources.append((t("training.source_triggers"), repr((mission.get("trig"), mission.get("trigrules")))))
    if folder is None:
        return sources
    l10n = folder / "src" / "mission" / "l10n"
    paths = sorted(p for p in l10n.rglob("*") if p.is_file()) if l10n.is_dir() else []
    custom = yaml_data.get("custom_scripts")
    scripts = custom.get("scripts") if isinstance(custom, dict) else None
    for entry in scripts or []:
        path = entry.get("path") if isinstance(entry, dict) else None
        if isinstance(path, str):
            paths.append(folder / path)
    for path in paths:
        try:
            sources.append((path.relative_to(folder).as_posix(), path.read_text(encoding="utf-8", errors="replace")))
        except (OSError, ValueError):
            continue
    return sources


def _scalars(value: object) -> set[str]:
    """Every string scalar of a loaded YAML value, keys included."""
    if isinstance(value, str):
        return {value}
    if isinstance(value, dict):
        return set().union(*(_scalars(k) | _scalars(v) for k, v in value.items())) if value else set()
    if isinstance(value, list):
        return set().union(*(_scalars(item) for item in value)) if value else set()
    return set()


def _references_to(name: str, sources: list[tuple[str, str]]) -> list[str]:
    """The labels of the sources naming the group.

    In ``mission.yaml`` a reference is a value equal to the name (a QRA's group list, an asset); in a
    script or a trigger it is the name as a Lua string literal.
    """
    quoted = (f'"{name}"', f"'{name}'", f"[[{name}]]")
    labels = []
    for label, text in sources:
        hit = name in text.splitlines() if label == _YAML_LABEL else any(q in text for q in quoted)
        if hit:
            labels.append(label)
    return labels


# ── the versions ────────────────────────────────────────────────────────────────────────────────


def profile_name(role: str) -> str:
    """The derived build profile of a role: ``A2G`` → ``TRAINING_A2G``."""
    return f"{PROFILE_PREFIX}{role}"


def variant_profiles(yaml_data: dict[str, Any]) -> list[str]:
    """The training profiles a build emits beside the night's mission, or ``[]`` without a block."""
    return [profile_name(role) for role in ROLES] if training_block(yaml_data) is not None else []


def with_training_profiles(yaml_data: dict[str, Any]) -> dict[str, Any]:
    """``mission.yaml`` with the derived training profiles added, so a profile lookup finds them.

    A profile of the same name the mission maker wrote is merged over the derived one: theirs wins.

    Args:
        yaml_data: The raw ``mission.yaml`` mapping; left unchanged.

    Returns:
        The mapping with ``profiles.TRAINING_<ROLE>`` set, or ``yaml_data`` itself without a block.
    """
    if training_block(yaml_data) is None:
        return yaml_data
    profiles = dict(yaml_data.get("profiles") or {}) if isinstance(yaml_data.get("profiles"), dict) else {}
    for role in ROLES:
        own = profiles.get(profile_name(role))
        profiles[profile_name(role)] = {VARIANT_KEY: role, **(own if isinstance(own, dict) else {})}
    return {**yaml_data, "profiles": profiles}


def plan_variant(
    role: str,
    yaml_data: dict[str, Any],
    mission: dict[str, Any],
    references: list[tuple[str, str]] | None = None,
) -> VariantPlan:
    """Decide everything one training version changes.

    Args:
        role: One of :data:`ROLES`.
        yaml_data: The resolved ``mission.yaml`` of that version (its profile applied).
        mission: The **source** mission table; left unchanged.
        references: The texts that may name a group (:func:`reference_sources`).

    Returns:
        The version's configuration and table edits.

    Raises:
        TrainingError: When the block is malformed or does not fit the mission; the message lists
            every problem.
    """
    plan, errors = parse_training(training_block(yaml_data))
    if plan is None and not errors:
        raise TrainingError(t("training.no_block"))
    if plan is None:
        raise TrainingError("\n".join(errors))
    resolved = _resolve(plan, yaml_data, mission, references or [], errors)
    if errors:
        raise TrainingError("\n".join(errors))

    removed_kinds = REMOVED_KINDS[role]
    variant = VariantPlan(role=role, config=copy.deepcopy(yaml_data), draws=resolved.draws)
    protected = {name for name, kind in resolved.explicit.items() if kind not in removed_kinds}
    for draw in resolved.draws:
        protected.update(draw.adopted)
        protected.update(draw.removed)

    removed = [name for name, kind in resolved.explicit.items() if kind in removed_kinds]
    for zone, kind in resolved.zone_kinds.items():
        if kind in removed_kinds:
            removed.extend(name for name in resolved.zone_groups[zone] if name not in protected)
    for draw in resolved.draws:
        removed.extend(draw.removed)
    variant.removed_groups = list(dict.fromkeys(removed))

    _edit_qra(variant, resolved, removed_kinds, role)
    _edit_cap_missions(variant, resolved, removed_kinds)
    _add_draw_zones(variant)
    return variant


def _edit_qra(variant: VariantPlan, resolved: _Resolved, removed_kinds: frozenset[str], role: str) -> None:
    """Take out the QRA a version does without, or force on the ones it trains against."""
    key, cfg = _module(variant.config, "QRA")
    definitions = cfg.get("definitions") if isinstance(cfg, dict) else None
    if role in FORCED_QRA_ROLES and not resolved.qra_kinds:
        variant.warnings.append(t("training.no_qra_to_force", role=role))
    if key is None or not isinstance(definitions, list):
        return
    kept = []
    for entry in definitions:
        name = str(entry.get("name")) if isinstance(entry, dict) else ""
        kind = resolved.qra_kinds.get(name)
        if kind in removed_kinds:
            continue
        if kind is not None and role in FORCED_QRA_ROLES:
            entry = {**entry, "active_at_start": True}
        kept.append(entry)
    variant.config["modules"][key] = {**cfg, "definitions": kept}


def _edit_cap_missions(variant: VariantPlan, resolved: _Resolved, removed_kinds: frozenset[str]) -> None:
    """Take out the on-demand CAPs a version does without."""
    caps = variant.config.get("cap_missions")
    if not isinstance(caps, list) or not resolved.cap_kinds:
        return
    variant.config["cap_missions"] = [
        entry
        for entry in caps
        if not (isinstance(entry, dict) and resolved.cap_kinds.get(str(entry.get("group_name"))) in removed_kinds)
    ]


def _add_draw_zones(variant: VariantPlan) -> None:
    """Declare the combat zone of each injected draw: active at start, no radio menu, no activation."""
    injected = [draw for draw in variant.draws if draw.inject_zone]
    if not injected:
        return
    modules = variant.config.setdefault("modules", {})
    key, cfg = _module(variant.config, "COMBATZONE")
    if not isinstance(cfg, dict):
        cfg = {"enabled": True} if cfg is None or cfg is True else {"enabled": bool(cfg)}
    zones = list(cfg.get("combat_zones") or [])
    for draw in injected:
        zones.append(
            {
                "zone_name": draw.host_zone,
                "friendly_name": draw.host_zone,
                "active_at_start": True,
                "radio_menu_disabled": True,
                "user_activation_disabled": True,
                "completable": False,
            }
        )
    modules[key or "COMBATZONE"] = {**cfg, "combat_zones": zones}


def apply_to_mission(mission: dict[str, Any], variant: VariantPlan) -> list[str]:
    """Replay a version's table edits on the mission the build carries, in place.

    Args:
        mission: The parsed DCS ``mission`` table of the ``.miz`` being built (mutated).
        variant: The version's plan, from :func:`plan_variant`.

    Returns:
        The warnings to report.
    """
    from mission_tools.group_insertion import add_group
    from veaf_mission_mcp.add_trigger_zone import insert_trigger_zone

    warnings = list(variant.warnings)
    remove_groups(mission, variant.removed_groups)
    groups = _groups_by_name(mission)
    for draw in variant.draws:
        for old_name, new_name in draw.adopted.items():
            ref = groups.get(old_name)
            if ref is None:
                continue
            ref.group["name"] = new_name
            unit = ref.first_unit()
            if unit is None:
                continue
            # A static's zone membership is read off its own name, so it takes the group's new one.
            base = new_name if ref.category == "static" else unit.get("name", new_name)
            unit["name"] = f"{base} {draw.markers[new_name]}"
        for edit in draw.created:
            add_group(
                mission,
                coalition=edit.side,
                country_id=edit.country_id,
                country_name=edit.country_name,
                category="vehicle",
                group=edit.group,
            )
        if draw.inject_zone:
            insert_trigger_zone(
                mission,
                name=draw.host_zone,
                position={"x": draw.center[0], "y": draw.center[1]},
                radius=draw.zone_radius,
            )
    return warnings


def check_training(
    yaml_data: dict[str, Any], mission: dict[str, Any] | None, references: list[tuple[str, str]]
) -> tuple[list[str], list[str]]:
    """Every problem of a ``training:`` block, for the pre-build validator.

    Args:
        yaml_data: The raw ``mission.yaml``.
        mission: The source mission table, or ``None`` when it cannot be read (only the block's own
            shape is then checked).
        references: The texts that may name a group (:func:`reference_sources`).

    Returns:
        ``(errors, warnings)``.
    """
    raw = training_block(yaml_data)
    if raw is None:
        return [], []
    errors: list[str] = []
    if yaml_data.get("build_variants"):
        errors.append(t("training.with_build_variants"))
    plan, parse_errors = parse_training(raw)
    errors.extend(parse_errors)
    if plan is None or mission is None:
        return errors, []
    warnings: list[str] = []
    for role in ROLES:
        try:
            variant = plan_variant(role, yaml_data, mission, references)
        except TrainingError as exc:
            errors.extend(str(exc).splitlines())
            break
        warnings.extend(variant.warnings)
    return errors, list(dict.fromkeys(warnings))
