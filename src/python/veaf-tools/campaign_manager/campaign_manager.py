"""Read and validate a campaign, and keep its state (FEAT-MULTI-MISSION-CAMPAIGN ticket 01).

Nothing here raises on a malformed input: every problem becomes a :class:`ValidationIssue` with a
translated message, the way `veaf-tools validate` reports a mission folder, so an author sees all
of a file's problems at once rather than the first one.
"""

from __future__ import annotations

import functools
import math
import os
import tempfile
from dataclasses import asdict
from pathlib import Path
from typing import Any

import yaml
from veaf_libs.atomic_replace import atomic_replace
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.dcs_airdromes import airfields_for_theatre
from veaf_libs.dcs_units_data import get_unit_category
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, WARNING, ValidationIssue

from campaign_manager.models import (
    COALITIONS,
    DEFAULT_CAPTURE_SECONDS,
    DEFAULT_MISSION_TEMPLATE,
    DEFAULT_MISSIONS,
    DEFAULT_SIZE_CLASSES,
    DEFAULT_STATE_WRITE_SECONDS,
    ERAS,
    RESERVE_CATEGORIES,
    SIDES,
    SIZE_PARAMETER_RANGES,
    STATE_FORMAT_VERSION,
    ZONE_KINDS,
    ZONE_RADIUS_RANGE,
    CampaignDefinition,
    CampaignRules,
    CampaignState,
    CampaignZone,
    Objective,
    SideState,
    SizeClass,
    ZoneLocation,
    ZoneState,
)


def _error(key: str, **kwargs: Any) -> ValidationIssue:
    """Build an error issue from a `campaign.issue.*` translation key.

    Args:
        key: The key's last part, e.g. ``unknown_zone``.
        **kwargs: The message's placeholders.

    Returns:
        The issue, at error level.
    """
    return ValidationIssue(ERROR, t(f"campaign.issue.{key}", **kwargs))


@functools.lru_cache(maxsize=1)
def _veaf_aliases() -> frozenset[str]:
    """Every unit and group alias of `veaf-units.yaml`, lowercased."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "veaf-units.yaml")) or {}
    aliases: set[str] = set()
    for section in ("units", "groups"):
        for entry in raw.get(section) or []:
            aliases.update(str(alias).lower() for alias in entry.get("aliases") or [])
    return frozenset(aliases)


def _is_known_garrison_entry(entry: str) -> bool:
    """Whether the runtime can spawn this: a VEAF unit or group alias, or a DCS unit type."""
    return entry.lower() in _veaf_aliases() or get_unit_category(entry) is not None


def _is_int(value: Any) -> bool:
    """Whether a YAML value is a whole number — a boolean is not, though Python says it is an `int`.

    Args:
        value: Any loaded value.

    Returns:
        True for an `int` that is not a `bool`.
    """
    # `True` is an `int` in Python; in a YAML file it is a mistake, not a 1.
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value: Any) -> bool:
    """Whether a YAML value is a finite number, boolean excluded.

    Args:
        value: Any loaded value.

    Returns:
        True for a finite `int` or `float`.
    """
    return (_is_int(value) or isinstance(value, float)) and math.isfinite(value)


# ---------------------------------------------------------------------------
# campaign.yaml
# ---------------------------------------------------------------------------


def _parse_size_classes(raw: Any, issues: list[ValidationIssue]) -> dict[str, SizeClass]:
    """Read `size_classes`: the shipped classes, overridden or extended by the campaign's.

    Args:
        raw: The block as loaded, or ``None``.
        issues: Where every problem found is appended.

    Returns:
        Every size class by name; a class with an error keeps its shipped values, or is left out
        when it is new.
    """
    classes = dict(DEFAULT_SIZE_CLASSES)
    if raw is None:
        return classes
    if not isinstance(raw, dict):
        issues.append(_error("malformed_block", block="size_classes"))
        return classes
    for name, params in raw.items():
        name = str(name)
        if not isinstance(params, dict):
            issues.append(_error("malformed_block", block=f"size_classes.{name}"))
            continue
        base = DEFAULT_SIZE_CLASSES.get(name)
        values: dict[str, Any] = asdict(base) if base else {"name": name, "long_range_sam": False}
        valid = True
        for param, value in params.items():
            if param in SIZE_PARAMETER_RANGES:
                low, high = SIZE_PARAMETER_RANGES[param]
                if not _is_int(value) or not low <= value <= high:
                    issues.append(_error("bad_size_parameter", size=name, field=param, value=value, low=low, high=high))
                    valid = False
                    continue
            elif param == "long_range_sam":
                if not isinstance(value, bool):
                    issues.append(_error("bad_long_range_sam", size=name))
                    valid = False
                    continue
            else:
                issues.append(_error("unknown_size_parameter", size=name, field=param))
                valid = False
                continue
            values[param] = value
        missing = sorted(p for p in SIZE_PARAMETER_RANGES if p not in values)
        if missing:
            issues.append(_error("incomplete_size_class", size=name, missing=", ".join(missing)))
            valid = False
        if valid:
            classes[name] = SizeClass(**values)
    return classes


def _parse_reserves(raw: Any, issues: list[ValidationIssue]) -> dict[str, dict[str, int]]:
    """Read `sides`: each coalition's starting reserve, every category defaulting to zero.

    Args:
        raw: The block as loaded, or ``None``.
        issues: Where every problem found is appended.

    Returns:
        The reserve of both coalitions, by category.
    """
    reserves = {side: dict.fromkeys(RESERVE_CATEGORIES, 0) for side in COALITIONS}
    if raw is None:
        return reserves
    if not isinstance(raw, dict):
        issues.append(_error("malformed_block", block="sides"))
        return reserves
    for side, block in raw.items():
        if side not in COALITIONS:
            issues.append(_error("unknown_coalition", side=side))
            continue
        reserve = block.get("reserve") if isinstance(block, dict) else None
        if not isinstance(reserve, dict):
            issues.append(_error("malformed_block", block=f"sides.{side}"))
            continue
        for category, value in reserve.items():
            if category not in RESERVE_CATEGORIES or not _is_int(value) or value < 0:
                issues.append(_error("bad_reserve", side=side, category=category, value=value))
                continue
            reserves[side][category] = value
    return reserves


def _parse_rules(raw: Any, issues: list[ValidationIssue]) -> CampaignRules:
    """Read `rules`: the fixed rules of the turn between missions, each overriding its default.

    Args:
        raw: The block as loaded, or ``None``.
        issues: Where every problem found is appended.

    Returns:
        The rules; an invalid one keeps its default.
    """
    if raw is None:
        return CampaignRules()
    if not isinstance(raw, dict):
        issues.append(_error("malformed_block", block="rules"))
        return CampaignRules()
    values: dict[str, Any] = {}
    for name, value in raw.items():
        if name == "repairs_per_mission" and _is_int(value) and value >= 0:
            values[name] = value
        elif name == "counter_attack" and isinstance(value, bool):
            values[name] = value
        elif (
            name == "logistics_output"
            and isinstance(value, dict)
            and all(k in RESERVE_CATEGORIES and _is_int(v) and v >= 0 for k, v in value.items())
        ):
            values[name] = {category: value.get(category, 0) for category in RESERVE_CATEGORIES}
        else:
            issues.append(_error("bad_rule", rule=name))
    return CampaignRules(**values)


def _parse_seconds(head: dict[str, Any], setting: str, default: int, issues: list[ValidationIssue]) -> int:
    """Read a duration of the `campaign` block, in whole seconds.

    Args:
        head: The `campaign` block.
        setting: The key, e.g. ``capture_seconds``.
        default: The value when the key is absent or invalid.
        issues: Where a problem found is appended.

    Returns:
        The duration.
    """
    value = head.get(setting, default)
    if not _is_int(value) or value < 1:
        issues.append(_error("bad_seconds", setting=setting, value=value))
        return default
    return int(value)


def _parse_location(zone: str, raw: Any, theatre: str | None, issues: list[ValidationIssue]) -> ZoneLocation | None:
    """Read a zone's `at`: an airfield of the theatre, spelt as DCS spells it, or coordinates.

    Args:
        zone: The zone's name, for the messages.
        raw: The `at` value as loaded.
        theatre: The campaign's theatre, or ``None`` when it is unknown (already reported).
        issues: Where a problem found is appended.

    Returns:
        The location, or ``None`` when it is invalid.
    """
    if isinstance(raw, dict) and set(raw) == {"airfield"}:
        wanted = str(raw["airfield"])
        if theatre is None:
            return None  # the unknown theatre is already reported
        for airfield in airfields_for_theatre(theatre):
            if str(airfield["name"]).lower() == wanted.lower():
                return ZoneLocation(airfield=str(airfield["name"]))
        issues.append(_error("unknown_airfield", zone=zone, airfield=wanted, theatre=theatre))
        return None
    if isinstance(raw, dict) and set(raw) == {"lat", "lon"}:
        lat, lon = raw["lat"], raw["lon"]
        if _is_number(lat) and _is_number(lon) and -90 <= lat <= 90 and -180 <= lon <= 180:
            return ZoneLocation(lat=float(lat), lon=float(lon))
    issues.append(_error("bad_location", zone=zone))
    return None


def _parse_zone(
    index: int, raw: Any, theatre: str | None, size_classes: dict[str, SizeClass], issues: list[ValidationIssue]
) -> CampaignZone | None:
    """Read one zone of `zones`.

    Args:
        index: Its position in the list, from 1, for a zone with no name.
        raw: The entry as loaded.
        theatre: The campaign's theatre, or ``None`` when it is unknown (already reported).
        size_classes: The size classes it may name.
        issues: Where every problem found is appended.

    Returns:
        The zone, or ``None`` when any of its fields is invalid.
    """
    if not isinstance(raw, dict) or not raw.get("name"):
        issues.append(_error("zone_without_name", index=index))
        return None
    name = str(raw["name"])
    count = len(issues)
    location = _parse_location(name, raw.get("at"), theatre, issues)

    size = str(raw.get("size", ""))
    if size not in size_classes:
        issues.append(_error("unknown_size", zone=name, size=size, known=", ".join(sorted(size_classes))))

    side = str(raw.get("side", ""))
    if side not in SIDES:
        issues.append(_error("unknown_side", zone=name, side=side))

    kind = raw.get("kind")
    if kind is not None and kind not in ZONE_KINDS:
        issues.append(_error("unknown_kind", zone=name, kind=kind, known=", ".join(ZONE_KINDS)))

    garrison: tuple[str, ...] | None = None
    if "garrison" in raw:
        entries = raw["garrison"]
        if not isinstance(entries, list) or not entries:
            issues.append(_error("empty_garrison", zone=name))
        else:
            garrison = tuple(str(entry) for entry in entries)
            for entry in garrison:
                if not _is_known_garrison_entry(entry):
                    issues.append(_error("unknown_garrison_entry", zone=name, entry=entry))

    radius = raw.get("radius", 2000)
    low, high = ZONE_RADIUS_RANGE
    if not _is_int(radius) or not low <= radius <= high:
        issues.append(_error("bad_radius", zone=name, value=radius, low=low, high=high))

    texts: dict[str, str | None] = {}
    for key in ("display_name", "intel"):
        value = raw.get(key)
        if value is not None and (not isinstance(value, str) or not value.strip()):
            issues.append(_error("bad_zone_text", zone=name, field=key))
        texts[key] = value.strip() if isinstance(value, str) else None

    if len(issues) > count or location is None:
        return None
    return CampaignZone(
        name=name,
        location=location,
        size=size,
        side=side,
        kind=kind,
        garrison=garrison,
        radius=radius,
        display_name=texts["display_name"],
        intel=texts["intel"],
    )


def _parse_connections(raw: Any, names: set[str], issues: list[ValidationIssue]) -> list[tuple[str, str]]:
    """Read `connections`: pairs of declared zones.

    Args:
        raw: The block as loaded, or ``None``.
        names: Every zone name declared, valid or not.
        issues: Where every problem found is appended.

    Returns:
        The valid connections, in declaration order.
    """
    connections: list[tuple[str, str]] = []
    if raw is None:
        return connections
    if not isinstance(raw, list):
        issues.append(_error("malformed_block", block="connections"))
        return connections
    for connection in raw:
        if not isinstance(connection, list) or len(connection) != 2:
            issues.append(_error("bad_connection", connection=connection))
            continue
        a, b = str(connection[0]), str(connection[1])
        if a == b:
            issues.append(_error("self_connection", zone=a))
            continue
        unknown = [zone for zone in (a, b) if zone not in names]
        for zone in unknown:
            issues.append(_error("connection_unknown_zone", zone=zone))
        if not unknown:
            connections.append((a, b))
    return connections


def _unreachable(zones: list[str], connections: list[tuple[str, str]]) -> list[str]:
    """The zones not reachable from the first one, in declaration order."""
    if not zones:
        return []
    reached = {zones[0]}
    frontier = [zones[0]]
    while frontier:
        current = frontier.pop()
        for a, b in connections:
            for here, there in ((a, b), (b, a)):
                if here == current and there not in reached:
                    reached.add(there)
                    frontier.append(there)
    return [zone for zone in zones if zone not in reached]


def _parse_objectives(
    raw: Any, declared: list[str], zones: dict[str, CampaignZone], issues: list[ValidationIssue]
) -> list[Objective]:
    """Read `campaign.objectives`, warning when there is none.

    Args:
        raw: The list as loaded, or ``None``.
        declared: Every zone name declared, valid or not.
        zones: The valid zones, by name.
        issues: Where every problem found is appended.

    Returns:
        The valid objectives, in declaration order.
    """
    objectives: list[Objective] = []
    if raw is None:
        raw = []
    if not isinstance(raw, list):
        issues.append(_error("malformed_block", block="campaign.objectives"))
        return objectives
    if not raw:
        issues.append(ValidationIssue(WARNING, t("campaign.issue.no_objectives")))
    for index, entry in enumerate(raw, start=1):
        objective: Objective | None = None
        if isinstance(entry, dict) and len(entry) == 1:
            ((kind, value),) = entry.items()
            if kind == "capture" and isinstance(value, list) and value:
                objective = Objective("capture", tuple(str(zone) for zone in value))
            elif kind == "destroy" and isinstance(value, dict) and value.get("zone"):
                objective = Objective("destroy", (str(value["zone"]),), value.get("kind"))
        if objective is None:
            issues.append(_error("bad_objective", index=index))
            continue
        known = True
        for zone in objective.zones:
            if zone not in declared:
                issues.append(_error("objective_unknown_zone", zone=zone))
                known = False
        if known and objective.target_kind is not None:
            zone = objective.zones[0]
            # A zone declared but invalid is already reported; its kind says nothing.
            if zone in zones and zones[zone].kind != objective.target_kind:
                issues.append(_error("objective_kind_mismatch", zone=zone, kind=objective.target_kind))
                known = False
        if known:
            objectives.append(objective)
    return objectives


def parse_campaign(raw: Any) -> tuple[CampaignDefinition | None, list[ValidationIssue]]:
    """Read a loaded `campaign.yaml` into a campaign, reporting every problem found.

    Args:
        raw: The YAML document as loaded, whatever its shape.

    Returns:
        The campaign, or ``None`` when any error was found, and every issue — errors and
        warnings — in the order they were found.
    """
    issues: list[ValidationIssue] = []
    if not isinstance(raw, dict) or "campaign" not in raw:
        return None, [_error("missing_block", block="campaign")]
    head = raw["campaign"]
    if not isinstance(head, dict):
        return None, [_error("malformed_block", block="campaign")]

    name = head.get("name")
    if not name:
        issues.append(_error("missing_name"))

    theatre: str | None = str(head.get("theatre", ""))
    if not airfields_for_theatre(theatre or ""):
        issues.append(_error("unknown_theatre", theatre=theatre))
        theatre = None

    era = str(head.get("era", "MODERN"))
    if era not in ERAS:
        issues.append(_error("unknown_era", era=era, known=", ".join(ERAS)))

    missions = head.get("missions", DEFAULT_MISSIONS)
    if not _is_int(missions) or missions < 1:
        issues.append(_error("bad_missions", value=missions))

    player_side = str(head.get("player_side", "blue"))
    if player_side not in COALITIONS:
        issues.append(_error("bad_player_side", side=player_side))

    capture_seconds = _parse_seconds(head, "capture_seconds", DEFAULT_CAPTURE_SECONDS, issues)
    state_write_seconds = _parse_seconds(head, "state_write_seconds", DEFAULT_STATE_WRITE_SECONDS, issues)
    size_classes = _parse_size_classes(raw.get("size_classes"), issues)
    reserves = _parse_reserves(raw.get("sides"), issues)
    rules = _parse_rules(raw.get("rules"), issues)

    raw_zones = raw.get("zones")
    if not isinstance(raw_zones, list):
        issues.append(_error("no_zones") if raw_zones is None else _error("malformed_block", block="zones"))
        raw_zones = []
    elif not raw_zones:
        issues.append(_error("no_zones"))

    zones: dict[str, CampaignZone] = {}
    declared: list[str] = []
    for index, raw_zone in enumerate(raw_zones, start=1):
        zone = _parse_zone(index, raw_zone, theatre, size_classes, issues)
        zone_name = str(raw_zone.get("name")) if isinstance(raw_zone, dict) and raw_zone.get("name") else None
        if zone_name is None:
            continue
        if zone_name in declared:
            issues.append(_error("duplicate_zone", zone=zone_name))
            continue
        declared.append(zone_name)
        if zone is not None:
            zones[zone_name] = zone

    connections = _parse_connections(raw.get("connections"), set(declared), issues)
    unreachable = _unreachable(declared, connections)
    if unreachable:
        issues.append(_error("disconnected", zones=", ".join(unreachable)))

    objectives = _parse_objectives(head.get("objectives"), declared, zones, issues)

    if any(issue.level == ERROR for issue in issues):
        return None, issues
    return (
        CampaignDefinition(
            name=str(name),
            theatre=str(theatre),
            era=era,
            missions=missions,
            player_side=player_side,
            objectives=tuple(objectives),
            size_classes=size_classes,
            zones=tuple(zones[n] for n in declared),
            connections=tuple(connections),
            reserves=reserves,
            rules=rules,
            capture_seconds=capture_seconds,
            state_write_seconds=state_write_seconds,
            mission_template=str(head.get("mission_template", DEFAULT_MISSION_TEMPLATE)),
        ),
        issues,
    )


def load_campaign(path: Path) -> tuple[CampaignDefinition | None, list[ValidationIssue]]:
    """Read and validate a `campaign.yaml` file.

    Args:
        path: The file.

    Returns:
        The campaign, or ``None`` on any error, and every issue found.
    """
    if not path.is_file():
        return None, [_error("no_campaign_file", path=path)]
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None, [_error("campaign_unreadable", path=path)]
    return parse_campaign(raw)


# ---------------------------------------------------------------------------
# Campaign state
# ---------------------------------------------------------------------------


def initial_state(campaign: CampaignDefinition) -> CampaignState:
    """Return the state a campaign starts from, before its first mission.

    Args:
        campaign: The validated campaign.

    Returns:
        Every zone owned by its declared side with no garrison drawn yet, empty reserves, and
        mission 0.
    """
    return CampaignState(
        format_version=STATE_FORMAT_VERSION,
        campaign=campaign.name,
        mission=0,
        zones={zone.name: ZoneState(owner=zone.side) for zone in campaign.zones},
        sides={side: SideState(reserve=dict(campaign.reserves.get(side, {}))) for side in COALITIONS},
    )


def state_to_dict(state: CampaignState) -> dict[str, Any]:
    """Return the state as plain data, the shape it is saved in.

    Args:
        state: The state.

    Returns:
        A dict of builtins only, keyed by zone and side name.
    """
    return asdict(state)


def state_from_dict(raw: Any) -> CampaignState | None:
    """Build a state from plain data, or return ``None`` when its shape is wrong.

    Args:
        raw: The loaded document.

    Returns:
        The state, or ``None``.
    """
    try:
        return CampaignState(
            format_version=int(raw["format_version"]),
            campaign=str(raw["campaign"]),
            mission=int(raw["mission"]),
            zones={str(name): ZoneState(**zone) for name, zone in raw["zones"].items()},
            sides={str(name): SideState(**side) for name, side in raw["sides"].items()},
            scenery_destroyed=list(raw.get("scenery_destroyed") or []),
            history=list(raw.get("history") or []),
        )
    except (KeyError, TypeError, ValueError, AttributeError):
        return None


def save_state(state: CampaignState, path: Path) -> None:
    """Write the state, atomically: a write cut short leaves the previous file whole.

    Args:
        state: The state.
        path: The target file, replaced.
    """
    text = yaml.safe_dump(state_to_dict(state), allow_unicode=True, sort_keys=False)
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    atomic_replace(temp, path)


def load_state(path: Path) -> tuple[CampaignState | None, list[ValidationIssue]]:
    """Read a saved state.

    Args:
        path: The file.

    Returns:
        The state, or ``None`` with the issue that prevented reading it.
    """
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None, [_error("state_unreadable", path=path)]
    state = state_from_dict(raw)
    if state is None:
        return None, [_error("state_malformed", path=path)]
    return state, []


def validate_state(campaign: CampaignDefinition, state: CampaignState) -> list[ValidationIssue]:
    """Check that a state belongs to a campaign and still matches it.

    A zone renamed or removed in `campaign.yaml` is reported, never dropped from the state: what
    the campaign lost there would vanish with it.

    Args:
        campaign: The validated campaign.
        state: The state to check.

    Returns:
        Every mismatch found; empty when the state matches.
    """
    if state.format_version != STATE_FORMAT_VERSION:
        return [_error("state_version", found=state.format_version, expected=STATE_FORMAT_VERSION)]
    if state.campaign != campaign.name:
        return [_error("state_other_campaign", found=state.campaign, expected=campaign.name)]
    issues: list[ValidationIssue] = []
    declared = [zone.name for zone in campaign.zones]
    for name in state.zones:
        if name not in declared:
            issues.append(_error("state_zone_not_in_campaign", zone=name))
    for name in declared:
        if name not in state.zones:
            issues.append(_error("state_zone_missing", zone=name))
    for name, zone in state.zones.items():
        if zone.owner not in SIDES:
            issues.append(_error("unknown_side", zone=name, side=zone.owner))
    return issues
