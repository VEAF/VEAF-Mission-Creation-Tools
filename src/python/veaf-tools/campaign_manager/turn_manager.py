"""Between two missions: merge the state file, play the turn, judge the objectives (ticket 08).

The turn is the **bookkeeping** half of the enemy's turn, done by fixed rules so that it is the same
every time: logistics feed the reserves, the reserves repair the garrisons, and a neutral zone that
only one side borders is retaken by it. The **intent** half — where the enemy puts its effort, what
the next mission asks — is Claude's, and lives in the next mission's briefing (ticket 09).
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

from luadata.io.read import read as read_lua
from veaf_libs.dcs_units_data import get_unit_category
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, WARNING, ValidationIssue

from campaign_manager.campaign_manager import state_from_dict, validate_state
from campaign_manager.models import (
    COALITIONS,
    RESERVE_CATEGORIES,
    CampaignDefinition,
    CampaignState,
    Objective,
    ZoneState,
)

#: How DCS unit categories (`dcsUnits.yaml`) fall into the reserve's categories. Anything else —
#: infantry, artillery, an unknown mod — is counted as armour.
_RESERVE_BY_DCS_CATEGORY: dict[str, str] = {
    "Air Defence": "air_defense",
    "ADEquipment": "air_defense",
    "Unarmed": "transport",
}


def _error(key: str, **kwargs: Any) -> ValidationIssue:
    return ValidationIssue(ERROR, t(f"campaign.issue.{key}", **kwargs))


def reserve_category(unit_type: str) -> str:
    """Return the reserve category a unit type is replaced from.

    Args:
        unit_type: The DCS type name.

    Returns:
        One of :data:`RESERVE_CATEGORIES`.
    """
    return _RESERVE_BY_DCS_CATEGORY.get(get_unit_category(unit_type) or "", "armor")


def _as_list(value: Any) -> list[Any]:
    """An empty Lua table reads as a dict: what should be a list is made one."""
    if isinstance(value, list):
        return value
    return []


def _read_lua_table(path: Path) -> dict[str, Any] | None:
    try:
        raw = read_lua(str(path))
    except Exception:  # luadata raises bare Exceptions on a malformed literal; a missing file is one too
        return None
    return raw if isinstance(raw, dict) else None


def read_state_file(path: Path) -> tuple[CampaignState | None, list[ValidationIssue]]:
    """Read the state file a mission wrote (a Lua literal, ``return {...}``).

    The mission writes a complete temporary (``<file>.tmp``) before the file itself. When the file
    is missing or cut short — a server killed in the middle of a write — the temporary is read
    instead, and a warning says so.

    Args:
        path: The file, fetched from the server's ``Saved Games``.

    Returns:
        The state it holds, or ``None`` with the issue that prevented reading it.
    """
    issues: list[ValidationIssue] = []
    raw = _read_lua_table(path)
    if raw is None:
        temporary = path.with_name(path.name + ".tmp")
        raw = _read_lua_table(temporary)
        if raw is None:
            # A path typed wrong is the common case: saying "not a state file" sent the user looking
            # for a corrupt file that did not exist (David, 2026-10-06).
            if not path.is_file() and not temporary.is_file():
                return None, [_error("state_file_missing", path=path)]
            return None, [_error("state_file_unreadable", path=path)]
        issues.append(ValidationIssue(WARNING, t("campaign.issue.state_file_from_temporary", path=temporary)))
    zones = raw.get("zones")
    if isinstance(zones, dict):
        for zone in zones.values():
            if isinstance(zone, dict) and "garrison" in zone:
                zone["garrison"] = _as_list(zone["garrison"])
    raw["scenery_destroyed"] = _as_list(raw.get("scenery_destroyed"))
    raw["convoys"] = _as_list(raw.get("convoys"))
    for convoy in raw["convoys"]:
        if isinstance(convoy, dict):
            for key in ("sent", "alive", "absorbed"):
                convoy[key] = _as_list(convoy.get(key))
    for side in (raw.get("sides") or {}).values():
        if isinstance(side, dict) and not isinstance(side.get("reserve"), dict):
            side["reserve"] = {}
    state = state_from_dict(raw)
    if state is None:
        return None, [_error("state_malformed", path=path)]
    return state, issues


def validate_state_file(
    campaign: CampaignDefinition, current: CampaignState, flown: CampaignState
) -> list[ValidationIssue]:
    """Check that a state file is the next mission of this campaign.

    Args:
        campaign: The validated campaign.
        current: The campaign state before the mission.
        flown: The state the mission wrote.

    Returns:
        Every reason to refuse it; empty when it can be applied.
    """
    issues = validate_state(campaign, flown)
    if issues:
        return issues
    expected = current.mission + 1
    if flown.mission <= current.mission:
        return [_error("state_file_already_applied", mission=flown.mission)]
    if flown.mission != expected:
        return [_error("state_file_skips", mission=flown.mission, expected=expected)]
    return []


def _units(garrison: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
    return [unit for group in garrison or [] for unit in group["units"]]


def _loss_record(zone: str, side: str, types: list[str]) -> list[dict[str, Any]]:
    """One `losses` change for these unit types, or nothing when there are none."""
    if not types:
        return []
    counted: dict[str, int] = {}
    for unit_type in types:
        counted[unit_type] = counted.get(unit_type, 0) + 1
    ordered = dict(sorted(counted.items(), key=lambda item: (-item[1], item[0])))
    return [{"kind": "losses", "zone": zone, "side": side, "lost": len(types), "types": ordered}]


def _losses(name: str, before: ZoneState, flown: ZoneState) -> list[dict[str, Any]]:
    """What a zone's garrisons lost during the flight, charged to the side that owned each.

    The same garrison on both sides of the flight loses the units alive before and dead after,
    matched by position — the record keeps them in place. A garrison that is gone, or replaced
    because the zone changed hands, lost every unit it started with; a garrison drawn in flight
    lost its dead units.

    Args:
        name: The zone.
        before: The zone in the campaign state, before the flight.
        flown: The zone in the state file.

    Returns:
        Zero, one or two `losses` changes.
    """
    same_garrison = before.garrison is not None and flown.garrison is not None and flown.owner == before.owner
    if same_garrison:
        pairs = zip(_units(before.garrison), _units(flown.garrison), strict=False)
        return _loss_record(name, flown.owner, [b["type"] for b, f in pairs if b.get("alive") and not f.get("alive")])
    changes = []
    if before.garrison is not None:
        changes += _loss_record(name, before.owner, [u["type"] for u in _units(before.garrison) if u.get("alive")])
    if flown.garrison is not None:
        changes += _loss_record(name, flown.owner, [u["type"] for u in _units(flown.garrison) if not u.get("alive")])
    return changes


def _settle_convoy(convoy: dict[str, Any], reserve: dict[str, int]) -> list[dict[str, Any]]:
    """What an assault convoy cost, and what of it goes back to the reserve.

    Its dead are what left minus what is alive minus what became a zone's garrison, type by type; its
    survivors still on the road return to its side's reserve, category by category.

    Args:
        convoy: The convoy, as the state file records it.
        reserve: Its side's reserve, after the merge; modified.

    Returns:
        A `losses` change for its dead, and a `convoy_returned` change for its survivors.
    """
    left = list(convoy.get("sent") or [])
    for unit_type in [*(convoy.get("alive") or []), *(convoy.get("absorbed") or [])]:
        if unit_type in left:
            left.remove(unit_type)
    label = t("campaign.convoy_label", **{"from": convoy["from"], "to": convoy["to"]})
    changes = _loss_record(label, convoy["side"], left)
    alive = convoy.get("alive") or []
    for unit_type in alive:
        category = reserve_category(unit_type)
        reserve[category] = reserve.get(category, 0) + 1
    if alive:
        changes.append(
            {
                "kind": "convoy_returned",
                "side": convoy["side"],
                "from": convoy["from"],
                "to": convoy["to"],
                "units": len(alive),
            }
        )
    return changes


def merge_state_file(current: CampaignState, flown: CampaignState) -> tuple[CampaignState, list[dict[str, Any]]]:
    """Merge what a mission left into the campaign state.

    Per zone the mission's record replaces the campaign's: owner, garrison with its losses, airbase
    warehouse. A capture still in progress when the mission ended is dropped — the next mission
    starts with the zone as it was left. Reserves are taken as the mission left them, a garrison
    drawn in flight having been paid from them (ticket 06); a category the file does not carry
    keeps the campaign's count.

    Args:
        current: The campaign state before the mission. Not modified.
        flown: The state the mission wrote.

    Returns:
        The new campaign state, and what changed, as a list of change records.
    """
    merged = copy.deepcopy(current)
    changes: list[dict[str, Any]] = []
    merged.mission = flown.mission
    for name, zone in flown.zones.items():
        before = merged.zones[name]
        if zone.owner != before.owner:
            changes.append({"kind": "owner", "zone": name, "from": before.owner, "to": zone.owner})
        changes += _losses(name, before, zone)
        before.owner = zone.owner
        before.garrison = copy.deepcopy(zone.garrison)
        before.capture = None
        if zone.warehouse is not None:
            before.warehouse = copy.deepcopy(zone.warehouse)
    for side, side_state in merged.sides.items():
        flown_reserve = flown.sides[side].reserve if side in flown.sides else {}
        for category in RESERVE_CATEGORIES:
            if isinstance(flown_reserve.get(category), int):
                side_state.reserve[category] = flown_reserve[category]
    # assault convoys (ticket 04 of FEAT-OPPOSITION-SCALES-WITH-PLAYERS): their reserve was charged
    # when they left, so the reserve just taken already counts them out
    for convoy in flown.convoys:
        if convoy.get("side") in merged.sides:
            changes += _settle_convoy(convoy, merged.sides[convoy["side"]].reserve)
    merged.convoys = []
    newly_destroyed = len(flown.scenery_destroyed) - len(current.scenery_destroyed)
    if newly_destroyed > 0:
        changes.append({"kind": "scenery", "destroyed": newly_destroyed})
    merged.scenery_destroyed = copy.deepcopy(flown.scenery_destroyed)
    return merged, changes


def _feed_reserves(campaign: CampaignDefinition, state: CampaignState) -> list[dict[str, Any]]:
    changes = []
    output = campaign.rules.logistics_output
    for zone in campaign.zones:
        owner = state.zones[zone.name].owner
        if zone.kind != "logistics" or owner not in COALITIONS:
            continue
        reserve = state.sides[owner].reserve
        added = {category: output.get(category, 0) for category in RESERVE_CATEGORIES}
        if not any(added.values()):
            continue
        for category, amount in added.items():
            reserve[category] = reserve.get(category, 0) + amount
        changes.append({"kind": "logistics", "zone": zone.name, "side": owner, "added": added})
    return changes


def _repair(campaign: CampaignDefinition, state: CampaignState) -> list[dict[str, Any]]:
    changes = []
    left = dict.fromkeys(COALITIONS, campaign.rules.repairs_per_mission)
    for zone in campaign.zones:
        zone_state = state.zones[zone.name]
        owner = zone_state.owner
        if owner not in COALITIONS:
            continue
        reserve = state.sides[owner].reserve
        repaired = 0
        for group in zone_state.garrison or []:
            for unit in group["units"]:
                if left[owner] == 0:
                    break
                if unit.get("alive"):
                    continue
                category = reserve_category(unit["type"])
                if reserve.get(category, 0) <= 0:
                    continue
                reserve[category] -= 1
                unit["alive"] = True
                unit.pop("missiles", None)  # a unit replaced comes back fully loaded
                left[owner] -= 1
                repaired += 1
        if repaired:
            changes.append({"kind": "repaired", "zone": zone.name, "units": repaired})
    return changes


def _counter_attack(campaign: CampaignDefinition, state: CampaignState) -> list[dict[str, Any]]:
    if not campaign.rules.counter_attack:
        return []
    owners = {name: zone.owner for name, zone in state.zones.items()}  # before any retake: no cascade
    changes = []
    for zone in campaign.zones:
        if owners[zone.name] != "neutral":
            continue
        bordering = {owners[n] for n in campaign.neighbours(zone.name)} & set(COALITIONS)
        if len(bordering) == 1:
            (side,) = bordering
            state.zones[zone.name].owner = side
            state.zones[zone.name].garrison = None
            changes.append({"kind": "counter_attack", "zone": zone.name, "side": side})
    return changes


def play_turn(campaign: CampaignDefinition, state: CampaignState) -> list[dict[str, Any]]:
    """Play the fixed rules of the turn between two missions, for both sides.

    Args:
        campaign: The validated campaign, whose `rules` the turn follows.
        state: The campaign state after the merge. Modified in place.

    Returns:
        What the turn changed, as a list of change records.
    """
    return _feed_reserves(campaign, state) + _repair(campaign, state) + _counter_attack(campaign, state)


def enemy_of(side: str) -> str:
    """Return the other coalition.

    Args:
        side: ``blue`` or ``red``.

    Returns:
        ``red`` for ``blue``, ``blue`` otherwise.
    """
    return "red" if side == "blue" else "blue"


def garrison_strength(garrison: list[dict[str, Any]] | None) -> int | None:
    """Return the share of a garrison still alive, in percent.

    Args:
        garrison: A recorded garrison, or ``None`` when it has not been drawn yet.

    Returns:
        The rounded percentage, or ``None`` for a garrison with no unit.
    """
    units = [unit for group in garrison or [] for unit in group["units"]]
    if not units:
        return None
    return round(100 * sum(1 for unit in units if unit.get("alive")) / len(units))


def evaluate_objectives(campaign: CampaignDefinition, state: CampaignState) -> list[tuple[Objective, bool]]:
    """Judge each objective of the campaign against a state.

    A ``capture`` is met when the player side holds every zone it names; a ``destroy`` when the
    enemy no longer holds the zone — its garrison destroyed, or the zone taken.

    Args:
        campaign: The validated campaign.
        state: The campaign state.

    Returns:
        Each objective with whether it is met, in declaration order.
    """
    enemy = enemy_of(campaign.player_side)
    judged = []
    for objective in campaign.objectives:
        owners = [state.zones[name].owner for name in objective.zones]
        if objective.kind == "capture":
            met = all(owner == campaign.player_side for owner in owners)
        else:
            met = all(owner != enemy for owner in owners)
        judged.append((objective, met))
    return judged


def describe_change(change: dict[str, Any]) -> str:
    """Say a change record in the user's language.

    Args:
        change: One record from :func:`merge_state_file` or :func:`play_turn`.

    Returns:
        One translated line.
    """
    kind = change["kind"]
    values = {k: v for k, v in change.items() if k != "kind"}
    # sides and reserve categories are stored as keys; they are said as words
    # a convoy's ends are zones, not sides
    side_keys = ("side",) if kind == "convoy_returned" else ("from", "to", "side")
    for key in side_keys:
        if key in values:
            values[key] = t(f"campaign.side_name.{values[key]}")
    if kind == "logistics":
        values["added"] = ", ".join(
            f"{t(f'campaign.reserve_name.{category}')} +{amount}"
            for category, amount in change["added"].items()
            if amount
        )
    return t(f"campaign.change.{kind}", **values)


def outcome(campaign: CampaignDefinition, state: CampaignState) -> str:
    """Say where the campaign stands.

    Args:
        campaign: The validated campaign.
        state: The campaign state.

    Returns:
        ``won`` when every objective is met, ``out_of_missions`` when the planned number of missions
        has been flown without them, ``running`` otherwise.
    """
    judged = evaluate_objectives(campaign, state)
    if judged and all(met for _, met in judged):
        return "won"
    if state.mission >= campaign.missions:
        return "out_of_missions"
    return "running"
