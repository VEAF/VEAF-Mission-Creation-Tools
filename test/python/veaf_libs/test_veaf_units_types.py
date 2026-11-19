"""Every unit the shipped spawn database calls must be one ``veafUnits.findDcsUnit`` can find in game.

FIX-RECON-OT-FINDINGS 05: ``Red Manpad Squad`` and ``Red EWR`` called ``MANPADS SA-18 Igla "Grouse" C2``, a
mission-editor display name that ``dcsUnits.lua`` does not carry; ``veafUnits`` logged ``cannot find unit``
and spawned the group without it. Fourteen types of the database were in that case, the supply convoys'
trucks among them.
"""

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
DCS_UNITS_LUA = ROOT / "src" / "scripts" / "veaf" / "dcsUnits.lua"
VEAF_UNITS_YAML = ROOT / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "veaf-units.yaml"

#: Not a DCS type (absent from ``dcsUnits.lua`` and from the DCS schema) and with no obvious replacement:
#: the HQ-7 EO launcher of the ``hq7eo`` aliases. Left as it is until someone decides what those aliases
#: should spawn.
KNOWN_UNRESOLVED = {"HQ-7_LN_EO"}


def _known_names() -> set[str]:
    """Every type id and display name of ``dcsUnits.lua``, trimmed and lower-cased as ``findDcsUnit`` compares them."""
    text = DCS_UNITS_LUA.read_text(encoding="utf-8")
    found = re.findall(r'^\s+(?:type|name) = "(.*)",\s*$', text, re.MULTILINE)
    return {name.replace('\\"', '"').strip().lower() for name in found}


def _database_types() -> dict[str, set[str]]:
    """Every unit type the spawn database names, with where it is named."""
    data = yaml.safe_load(VEAF_UNITS_YAML.read_text(encoding="utf-8"))
    used: dict[str, set[str]] = {}
    for group in data["groups"]:
        for unit in group.get("units", []):
            used.setdefault(unit["type"], set()).add(f"group {group.get('groupName')}")
    for unit in data["units"]:
        used.setdefault(unit["unitType"], set()).add(f"alias {unit['aliases'][0]}")
    return used


def test_every_spawn_database_type_resolves_in_game() -> None:
    known = _known_names()
    missing = {
        unit_type: sorted(where)
        for unit_type, where in _database_types().items()
        if unit_type.strip().lower() not in known and unit_type not in KNOWN_UNRESOLVED
    }
    assert not missing, f"types veafUnits cannot find in dcsUnits.lua: {missing}"


def test_known_unresolved_types_are_still_unresolved() -> None:
    """A type listed as unresolved that DCS now knows must leave the list."""
    known = _known_names()
    assert not {t for t in KNOWN_UNRESOLVED if t.lower() in known}
