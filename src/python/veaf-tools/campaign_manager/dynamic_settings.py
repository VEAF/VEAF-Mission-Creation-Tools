"""The settings of a persistent campaign's live play (FEAT-DYNAMIC-CAMPAIGN).

A persistent campaign is one mission that runs on a server, saves itself and moves on its own: zones
asleep away from the players, counter-attacks, supply helicopters, enemy air, credits and a shop, a
task board, intelligence; and since the V1.5, resources and their supply network, paid spawns,
demolition teams, warehouse stocks, strategic bombers and territory cells. All of it is set in the
`dynamic:` block of `campaign.yaml`.

Only the aircraft need the tools: each is declared by DCS type and loadout **name**, and its pylons
are resolved here from the shipped DCS loadouts, so the runtime spawns it without any template in the
`.miz`. Every other value is checked and passed on as it is; its default lives in the runtime module
(`veafCampaign.DYNAMIC_DEFAULTS`), the one place it is read from.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from veaf_libs.dcs_payloads import payload_pylons
from veaf_libs.dcs_units_data import get_unit_category, get_unit_countermeasures, get_unit_fuel_capacity
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, ValidationIssue

from campaign_manager.models import COALITIONS

#: The roles an aircraft is declared for, per side.
AIR_ROLES: tuple[str, ...] = ("cap", "cas", "sead", "bomber")

#: What each side flies when `dynamic.air` does not say: type, DCS loadout name, aircraft per flight.
DEFAULT_AIR: dict[str, dict[str, dict[str, Any]]] = {
    "red": {
        "cap": {"type": "MiG-29A", "loadout": "R-73*2,R-60M*2,R-27R*2", "count": 2},
        "cas": {"type": "Su-25", "loadout": "FAB-250*4,UB-13*2,R-60M*2,Fuel*2", "count": 2},
        "sead": {"type": "MiG-27K", "loadout": "Kh-25MPU*2,R-60M*2,Fuel", "count": 2},
        "bomber": {"type": "Tu-22M3", "loadout": "FAB-500*33", "count": 1},
    },
    "blue": {
        "cap": {"type": "F-15C", "loadout": "AIM-9*2,AIM-120*2,AIM-7*4,Fuel*3", "count": 2},
        "cas": {"type": "A-10C", "loadout": "AGM-65D*2,Mk-82*6,AIM-9*2,ECM", "count": 2},
        "sead": {"type": "FA-18C_hornet", "loadout": "AIM-9X*2, AIM-120C-5*2, AGM-88C*2, FUEL", "count": 2},
        "bomber": {"type": "B-1B", "loadout": "Mk-84*24", "count": 1},
    },
}


def _positive(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _natural(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _percent(value: Any) -> bool:
    return _natural(value) and value <= 100


def _flag(value: Any) -> bool:
    return isinstance(value, bool)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sides(value: Any) -> bool:
    return isinstance(value, list) and all(side in COALITIONS for side in value)


def _helicopters(value: Any) -> bool:
    return isinstance(value, dict) and all(
        side in COALITIONS and isinstance(kind, str) and get_unit_category(kind) == "Helicopter"
        for side, kind in value.items()
    )


def _counts(value: Any) -> bool:
    return isinstance(value, dict) and all(isinstance(key, str) and _natural(count) for key, count in value.items())


def _statics(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(kind) for kind in value)


Check = Callable[[Any], bool]

#: Every key of `dynamic:` but `air`, and what its value must be. Sub-blocks are checked key by key.
_SCHEMA: dict[str, Check | dict[str, Check]] = {
    "save_seconds": _positive,
    "wake_radius": _positive,
    "ground_wake_radius": _positive,
    "reach_wake_margin": _positive,
    "front_depth": _positive,
    "takeoff_threat_range": _positive,
    "sleep_seconds": _positive,
    "max_awake_zones": _positive,
    "attacks": _sides,
    "attack_seconds": _positive,
    "max_convoys": _natural,
    "supply": _sides,
    "supply_seconds": _positive,
    "max_helicopters": _natural,
    "helicopter_timeout": _positive,
    "helicopter_capture_seconds": _positive,
    "convoy_timeout": _positive,
    "helicopter": _helicopters,
    "supply_crate": _text,
    "hunter": {"enabled": _flag, "ground_kills": _positive, "air_kills": _positive, "chance": _percent},
    "economy": {
        "start_credits": _natural,
        "kill_ground": _natural,
        "kill_air": _natural,
        "capture": _natural,
        "delivery": _natural,
        "prices": _counts,
        "tanker": _text,
        "credits_per_point": _positive,
        "demolition": _natural,
        "warehouse_delivery": _natural,
    },
    "tasks": {"count": _natural, "refresh_seconds": _positive, "air_kills": _positive, "rewards": _counts},
    "intel": {
        "hidden": _flag,
        "seconds": _positive,
        "overflight_altitude": _positive,
        "spy_troops": _text,
        "spy_range": _positive,
    },
    "resources": {
        "enabled": _flag,
        "start": _natural,
        "background_per_hour": _natural,
        "reserve": _natural,
        "prices": _counts,
    },
    "factory": {"buildings": _positive, "per_hour": _natural, "types": _statics},
    "network": {
        "hop_seconds": _positive,
        "isolated_seconds": _positive,
        "depot_store": _natural,
        "max_deliveries": _natural,
    },
    "demolition": {"troops": _text, "range": _positive, "fuse": _positive},
    "warehouse": {"enabled": _flag, "load": _positive},
    "bombers": {
        "enabled": _flag,
        "seconds": _positive,
        "min_distance": _positive,
        "escort": _flag,
        "package_delay": _positive,
    },
    "territory": {"enabled": _flag, "margin": _positive, "hatch_spacing": _positive, "hatch_length": _positive},
    "debug": _flag,
    "debug_status_seconds": _positive,
}

#: The keys of `dynamic.air` that are not a side.
_AIR_SETTINGS: dict[str, Check] = {
    "strike_seconds": _positive,
    "max_flights": _natural,
    "cap_per_players": _positive,
    "cap_helicopter_chance": _percent,
}


def _issue(setting: str) -> ValidationIssue:
    return ValidationIssue(ERROR, t("campaign.issue.bad_dynamic", setting=setting))


def _resolve_aircraft(side: str, role: str, declared: Any, issues: list[ValidationIssue]) -> dict[str, Any] | None:
    """Turn one declared aircraft into what the runtime spawns: type, count and a complete payload.

    Args:
        side: ``blue`` or ``red``.
        role: One of `AIR_ROLES`.
        declared: The `{type, loadout, count}` entry, or ``None`` for the shipped one.
        issues: Where a problem found is appended.

    Returns:
        ``{type, count, payload = {fuel, chaff, flare, gun, pylons}}``, or ``None`` when invalid.
    """
    entry = dict(DEFAULT_AIR[side][role])
    setting = f"dynamic.air.{side}.{role}"
    if declared is not None:
        if not isinstance(declared, dict) or not set(declared) <= {"type", "loadout", "count"}:
            issues.append(_issue(setting))
            return None
        if "type" in declared and "loadout" not in declared:
            entry["loadout"] = None  # a new type keeps none of the shipped one's loadout
        entry.update(declared)
    unit_type, loadout, count = entry.get("type"), entry.get("loadout"), entry.get("count")
    if not isinstance(unit_type, str) or get_unit_category(unit_type) != "Plane" or not _positive(count):
        issues.append(_issue(setting))
        return None
    pylons: dict[int, dict[str, Any]] = {}
    if loadout is not None:
        try:
            pylons = payload_pylons(unit_type, str(loadout))
        except ValueError as error:
            issues.append(ValidationIssue(ERROR, t("campaign.issue.bad_loadout", setting=setting, reason=str(error))))
            return None
    chaff, flare = get_unit_countermeasures(unit_type) or (0, 0)
    payload: dict[str, Any] = {"chaff": int(chaff), "flare": int(flare), "gun": 100, "pylons": pylons}
    fuel = get_unit_fuel_capacity(unit_type)
    if fuel:
        payload["fuel"] = fuel
    return {"type": unit_type, "count": count, "payload": payload}


def _parse_air(raw: Any, issues: list[ValidationIssue]) -> dict[str, Any]:
    """Read `dynamic.air`: the settings, and each side's aircraft resolved to payloads."""
    air: dict[str, Any] = {}
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        issues.append(_issue("dynamic.air"))
        return air
    for key, value in raw.items():
        if key in _AIR_SETTINGS:
            if _AIR_SETTINGS[key](value):
                air[key] = value
            else:
                issues.append(_issue(f"dynamic.air.{key}"))
        elif key not in COALITIONS or not isinstance(value, dict) or not set(value) <= set(AIR_ROLES):
            issues.append(_issue(f"dynamic.air.{key}"))
    for side in COALITIONS:
        side_block = raw.get(side)
        declared: dict[str, Any] = side_block if isinstance(side_block, dict) else {}
        resolved = {role: _resolve_aircraft(side, role, declared.get(role), issues) for role in AIR_ROLES}
        air[side] = {role: aircraft for role, aircraft in resolved.items() if aircraft is not None}
    return air


def parse_dynamic(raw: Any, issues: list[ValidationIssue]) -> dict[str, Any]:
    """Read `dynamic:`, the live play of a persistent campaign.

    Args:
        raw: The block as loaded, or ``None``.
        issues: Where every problem found is appended.

    Returns:
        The valid settings, as the runtime reads them; the aircraft always present, resolved.
    """
    settings: dict[str, Any] = {}
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        issues.append(_issue("dynamic"))
        raw = {}
    for key, value in raw.items():
        if key == "air":
            continue
        check = _SCHEMA.get(key)
        if check is None:
            issues.append(_issue(f"dynamic.{key}"))
        elif isinstance(check, dict):
            if not isinstance(value, dict):
                issues.append(_issue(f"dynamic.{key}"))
                continue
            block = {}
            for sub, sub_value in value.items():
                sub_check = check.get(sub)
                if sub_check is not None and sub_check(sub_value):
                    block[sub] = sub_value
                else:
                    issues.append(_issue(f"dynamic.{key}.{sub}"))
            settings[key] = block
        elif check(value):
            settings[key] = value
        else:
            issues.append(_issue(f"dynamic.{key}"))
    settings["air"] = _parse_air(raw.get("air"), issues)
    return settings
