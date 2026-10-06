"""The AWACS types `-awacs` spawns, checked against the DCS units database (FEAT-AWACS-ESCORT-COMMANDS).

`veafAircraftSpawn.AWACS_TYPES` carries each type's fuel and countermeasures by hand, because the runtime
knows neither and an aircraft created with no fuel falls out of the sky. This reads that Lua table and
compares it with `dcsUnits.yaml`, so a DCS update that adds an AWACS or changes a tank is caught here.
"""

from __future__ import annotations

import re
from pathlib import Path

from veaf_libs.dcs_units_data import (
    get_unit_attributes,
    get_unit_countermeasures,
    get_unit_fuel_capacity,
    get_unit_types_in_category,
)

LUA_MODULE = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf" / "veafAircraftSpawn.lua"


def _lua_awacs_types() -> dict[str, tuple[float, int, int]]:
    """Read `veafAircraftSpawn.AWACS_TYPES` as `{type: (fuel, chaff, flare)}`.

    Returns:
        The table, as the Lua source writes it.
    """
    source = LUA_MODULE.read_text(encoding="utf-8")
    body = re.search(r"veafAircraftSpawn\.AWACS_TYPES = \{(.*?)\n\}", source, re.DOTALL)
    assert body, "veafAircraftSpawn.AWACS_TYPES not found"
    entries = re.findall(
        r'\["([^"]+)"\] = \{ fuel = (\d+), chaff = (\d+), flare = (\d+) \}',
        body.group(1),
    )
    return {name: (float(fuel), int(chaff), int(flare)) for name, fuel, chaff, flare in entries}


def test_every_dcs_awacs_type_is_offered() -> None:
    awacs = {
        unit_type for unit_type in get_unit_types_in_category("Plane") if "AWACS" in get_unit_attributes(unit_type)
    }
    assert set(_lua_awacs_types()) == awacs


def test_fuel_and_countermeasures_match_the_database() -> None:
    for unit_type, (fuel, chaff, flare) in _lua_awacs_types().items():
        assert fuel == get_unit_fuel_capacity(unit_type), unit_type
        assert (chaff, flare) == (get_unit_countermeasures(unit_type) or (0, 0)), unit_type
