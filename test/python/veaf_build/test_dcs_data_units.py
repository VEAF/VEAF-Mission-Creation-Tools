"""Tests for the datamine-sourced DCS units provider and Lua emitter (DCSDATA-008)."""

from __future__ import annotations

from pathlib import Path

import yaml

from veaf_build.dcs_data import units as U
from veaf_build.dcs_data import units_lua as L

# A minimal datamine unit file (top-level fields are single-tab indented).
_PLANE = '\t["#Index"] = {\n\ttype = "A-10A",\n\tDisplayName = "A-10A Warthog",\n\tattribute = { "Redacted", "Air", "Planes" },\n}\n'
_SHIP = '\ttype = "ALBATROS",\n\tDisplayName = "Albatros",\n\tattribute = { "Naval", "Ships" },\n'
_INFANTRY = (
    '\ttype = "Soldier M4",\n\tDisplayName = "Soldier M4",\n\tcategory = "Infantry",\n\tattribute = { "Infantry" },\n'
)
_TANK = '\ttype = "M-1 Abrams",\n\tName = "M1A2 Abrams",\n\tcategory = "Armor",\n\tattribute = { "Vehicles", "Ground vehicles" },\n'
_TRAIN = '\ttype = "Locomotive",\n\tDisplayName = "Loco",\n\tcategory = "Locomotive",\n\tattribute = { "RailwayUnits", "GroundUnits" },\n'
_FORT = '\ttype = "Oil platform",\n\tDisplayName = "Oil platform",\n\tcategory = "Fortification",\n\tattribute = { },\n'


class TestDeriveKind:
    def test_air(self) -> None:
        assert U._derive_kind(["Air", "Planes"]) == "air"

    def test_naval(self) -> None:
        assert U._derive_kind(["Naval", "Ships"]) == "naval"
        assert U._derive_kind(["Ships"]) == "naval"

    def test_infantry_before_vehicle(self) -> None:
        # infantry wins even if some ground flag is present
        assert U._derive_kind(["Infantry", "Ground Units"]) == "infantry"

    def test_vehicle(self) -> None:
        assert U._derive_kind(["Ground vehicles"]) == "vehicle"
        assert U._derive_kind(["Vehicles"]) == "vehicle"

    def test_rail_is_vehicle(self) -> None:
        assert U._derive_kind(["RailwayUnits", "GroundUnits"]) == "vehicle"

    def test_static_default(self) -> None:
        assert U._derive_kind([]) == "static"
        assert U._derive_kind(["Cargos"]) == "static"


class TestParseUnitFile:
    def test_plane(self) -> None:
        e = U.parse_unit_file(_PLANE, "Planes")
        assert e is not None
        assert e.type == "A-10A"
        assert e.name == "A-10A Warthog"
        assert e.kind == "air"
        assert e.category == "Plane"  # derived from folder
        assert "Redacted" not in e.attributes
        assert "Air" in e.attributes

    def test_ground_uses_datamine_category(self) -> None:
        e = U.parse_unit_file(_TANK, "Cars")
        assert e is not None and e.category == "Armor" and e.kind == "vehicle"
        assert e.name == "M1A2 Abrams"  # Name fallback when no DisplayName

    def test_infantry(self) -> None:
        e = U.parse_unit_file(_INFANTRY, "Cars")
        assert e is not None and e.kind == "infantry"

    def test_train_is_vehicle(self) -> None:
        e = U.parse_unit_file(_TRAIN, "Cars")
        assert e is not None and e.kind == "vehicle"

    def test_fortification_is_static(self) -> None:
        e = U.parse_unit_file(_FORT, "Fortifications")
        assert e is not None and e.kind == "static"

    def test_no_type_returns_none(self) -> None:
        assert U.parse_unit_file('\tDisplayName = "x"\n', "Planes") is None


class TestCarriedUnits:
    def test_containers_carried(self) -> None:
        types = {c.type for c in U.CARRIED_UNITS}
        assert {"Container_20ft", "Container_40ft"} <= types
        for c in U.CARRIED_UNITS:
            assert c.kind == "static"


class TestExtractAllUnits:
    def test_dedup_and_carry(self, tmp_path: Path) -> None:
        base = tmp_path / "_G" / "db" / "Units" / "Planes" / "Plane"
        base.mkdir(parents=True)
        (base / "a10.lua").write_text(_PLANE, encoding="utf-8")
        (base / "a10_dup.lua").write_text(_PLANE, encoding="utf-8")  # same type → deduped
        entries = U.extract_all_units(tmp_path)
        types = [e.type for e in entries]
        assert types.count("A-10A") == 1
        # carried units are added
        assert "Container_20ft" in types


class TestWriteYaml:
    def test_roundtrip(self, tmp_path: Path) -> None:
        out = tmp_path / "u.yaml"
        entries = [U.UnitEntry("A-10A", "A-10A", "air", "Plane", "A-10A", ["Air"])]
        U.write_units_yaml(entries, ("Oil platform",), out, ref="abc123")
        data = yaml.safe_load(out.read_text(encoding="utf-8"))
        assert data["units"][0]["type"] == "A-10A"
        assert data["naval_statics"] == ["Oil platform"]
        assert "abc123" in out.read_text(encoding="utf-8")


class TestRenderLua:
    def _data(self) -> dict:
        return {
            "units": [
                {
                    "type": 'Ship "Q"',  # quotes must be escaped
                    "name": "Quote Ship",
                    "kind": "naval",
                    "category": "Ship",
                    "description": "Quote Ship",
                    "attributes": ["Naval", "Ships"],
                },
                {
                    "type": "Bunker",
                    "name": "Bunker",
                    "kind": "static",
                    "category": "Fortification",
                    "description": "Bunker",
                    "attributes": [],
                },
            ],
            "naval_statics": ["Oil platform"],
        }

    def test_render_structure(self) -> None:
        lua = L.render(self._data(), ref="deadbeefcafe")
        assert "dcsUnits.NavalStatics = {" in lua
        assert '["Oil platform"] = true,' in lua
        assert "dcsUnits.DcsUnitsDatabase = {" in lua
        assert 'kind = "naval"' in lua
        assert "datamine-deadbeef" in lua  # version from ref[:8]

    def test_quotes_escaped(self) -> None:
        lua = L.render(self._data(), ref="x")
        assert '["Ship \\"Q\\""] = {' in lua
        assert 'type = "Ship \\"Q\\"",' in lua

    def test_empty_attribute_table(self) -> None:
        lua = L.render(self._data(), ref="x")
        assert "attribute = {}," in lua

    def test_generate_writes_file(self, tmp_path: Path) -> None:
        ypath = tmp_path / "u.yaml"
        ypath.write_text(yaml.safe_dump(self._data()), encoding="utf-8")
        out = tmp_path / "dcsUnits.lua"
        n = L.generate(yaml_path=ypath, output=out, ref="x")
        assert n == 2
        assert out.read_text(encoding="utf-8").startswith("---")


# The fuel-capacity field (FIX-MCP-AUTHORING-GAPS 04): the datamine carries `M_fuel_max` on every
# air unit and on no other, which is exactly where a spawned aircraft needs one.
_PLANE_WITH_FUEL = (
    '\ttype = "F-15C",\n\tDisplayName = "F-15C",\n\tM_fuel_max = 6103,\n\tattribute = { "Air", "Planes" },\n'
)
_HELI_WITH_FRACTIONAL_FUEL = (
    '\ttype = "CH-47Fbl1",\n\tDisplayName = "CH-47F"'
    ',\n\tM_fuel_max = 3054.592,\n\tattribute = { "Air", "Helicopters" },\n'
)
_NESTED_FUEL_ONLY = (
    '\ttype = "Fake",\n\tDisplayName = "Fake",\n\tsome_table = {\n\t\tM_fuel_max = 999,\n\t},'
    '\n\tattribute = { "Vehicles" },\n'
)


class TestFuelCapacity:
    def test_a_plane_carries_its_capacity(self) -> None:
        e = U.parse_unit_file(_PLANE_WITH_FUEL, "Planes")
        assert e is not None and e.fuel_capacity == 6103
        assert isinstance(e.fuel_capacity, int)  # whole kilograms stay integral, as mission files write them

    def test_a_helicopter_keeps_its_decimals(self) -> None:
        e = U.parse_unit_file(_HELI_WITH_FRACTIONAL_FUEL, "Helicopters")
        assert e is not None and e.fuel_capacity == 3054.592

    def test_a_ground_unit_has_none(self) -> None:
        e = U.parse_unit_file(_TANK, "Cars")
        assert e is not None and e.fuel_capacity is None

    def test_a_nested_value_is_not_mistaken_for_the_units_own(self) -> None:
        # Only the top-level (single-tab) field is the unit's capacity, as for every other field here.
        e = U.parse_unit_file(_NESTED_FUEL_ONLY, "Cars")
        assert e is not None and e.fuel_capacity is None

    def test_the_key_is_emitted_only_where_there_is_one(self, tmp_path: Path) -> None:
        out = tmp_path / "u.yaml"
        entries = [
            U.UnitEntry("F-15C", "F-15C", "air", "Plane", "F-15C", ["Air"], 6103),
            U.UnitEntry("M-1 Abrams", "M1A2", "vehicle", "Armor", "M1A2", ["Vehicles"]),
        ]
        U.write_units_yaml(entries, (), out, ref="abc123")
        units = {u["type"]: u for u in yaml.safe_load(out.read_text(encoding="utf-8"))["units"]}
        assert units["F-15C"]["fuel_capacity"] == 6103
        assert "fuel_capacity" not in units["M-1 Abrams"]

    def test_the_shipped_database_carries_the_values_the_templates_use(self) -> None:
        # Guards the whole chain end to end: a regenerated database that lost the field would let
        # every spawned aircraft go back to being created with no fuel.
        from veaf_libs.dcs_units_data import get_unit_fuel_capacity

        assert get_unit_fuel_capacity("F-15C") == 6103
        assert get_unit_fuel_capacity("F-14B") == 7348
        assert get_unit_fuel_capacity("UH-1H") == 631
        assert get_unit_fuel_capacity("M-1 Abrams") is None  # a tank has no air-unit fuel load
        assert get_unit_fuel_capacity("NoSuchModType") is None
        assert get_unit_fuel_capacity("") is None
