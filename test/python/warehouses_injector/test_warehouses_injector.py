"""Tests for the Dynamic-Slot warehouse wiring (DYNSLOT-WAREHOUSE)."""

from __future__ import annotations

from pathlib import Path

from mission_tools.miz_tools import DcsMission
from warehouses_injector import apply_warehouses


def _template_group(group_id: int, name: str, unit_type: str, dyn: bool = True) -> dict:
    return {
        "groupId": group_id,
        "name": name,
        "dynSpawnTemplate": dyn,
        "units": [{"type": unit_type}],
    }


def _mission(theatre: str = "Caucasus", groups: list[dict] | None = None) -> DcsMission:
    groups = groups if groups is not None else [_template_group(2114, "DST - UH-1H", "UH-1H")]
    mission_content = {
        "coalition": {
            "blue": {"country": [{"name": "USA", "helicopter": {"group": groups}}]},
        }
    }
    warehouses = {
        "airports": {
            23: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
            24: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
            99: {"coalition": "RED", "dynamicSpawn": False, "aircrafts": {}},
        }
    }
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content=mission_content,
        warehouses_content=warehouses,
        theatre_content=theatre,
    )


class TestCoalitionSelection:
    def test_all_of_coalition_when_no_airports(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": "unlimited"}}}}}
        result = apply_warehouses(m, cfg)
        ap = m.warehouses_content["airports"]
        assert ap[23]["dynamicSpawn"] is True
        assert ap[24]["dynamicSpawn"] is True
        assert ap[99]["dynamicSpawn"] is False  # red untouched (not declared)
        assert result.airports_configured == 2

    def test_undeclared_coalition_untouched(self) -> None:
        m = _mission()
        apply_warehouses(m, {"blue": {"defaults": {}}})
        assert m.warehouses_content["airports"][99]["dynamicSpawn"] is False

    def test_specific_airport_by_id(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {}, "airports": {24: {}}}}
        apply_warehouses(m, cfg)
        ap = m.warehouses_content["airports"]
        assert ap[24]["dynamicSpawn"] is True
        assert ap[23]["dynamicSpawn"] is False

    def test_specific_airport_by_numeric_string(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {}, "airports": {"24": {}}}}  # numeric string key
        apply_warehouses(m, cfg)
        assert m.warehouses_content["airports"][24]["dynamicSpawn"] is True
        assert m.warehouses_content["airports"][23]["dynamicSpawn"] is False

    def test_specific_airport_by_name(self) -> None:
        m = _mission(theatre="Caucasus")
        cfg = {"blue": {"defaults": {}, "airports": {"Senaki-Kolkhi": {}}}}  # Senaki-Kolkhi == id 23
        apply_warehouses(m, cfg)
        assert m.warehouses_content["airports"][23]["dynamicSpawn"] is True


class TestStockAndFuel:
    def test_amount_unlimited_and_int(self) -> None:
        m = _mission()
        cfg = {
            "blue": {
                "defaults": {
                    "fuel": "unlimited",
                    "weapons": "unlimited",
                    "aircrafts": {"UH-1H": {"amount": "unlimited"}, "Yak-52": {"amount": 10}},
                }
            }
        }
        apply_warehouses(m, cfg)
        a = m.warehouses_content["airports"][23]
        assert a["unlimitedFuel"] is True
        assert a["unlimitedMunitions"] is True
        # DCS nests dynamic-slot aircraft by category: helicopters vs planes.
        assert a["aircrafts"]["helicopters"]["UH-1H"]["unlimited"] is True
        assert a["aircrafts"]["planes"]["Yak-52"] == {"unlimited": False, "initialAmount": 10}


class TestTemplateLinking:
    def test_link_by_explicit_name(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 1, "template": "DST - UH-1H"}}}}}
        result = apply_warehouses(m, cfg)
        assert m.warehouses_content["airports"][23]["aircrafts"]["helicopters"]["UH-1H"]["linkDynTempl"] == 2114
        assert result.templates_linked == 2  # both blue airports

    def test_link_auto_by_type(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 1}}}}}  # no template -> match by type
        apply_warehouses(m, cfg)
        assert m.warehouses_content["airports"][24]["aircrafts"]["helicopters"]["UH-1H"]["linkDynTempl"] == 2114

    def test_unknown_template_no_link(self) -> None:
        m = _mission()
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 1, "template": "Nope"}}}}}
        result = apply_warehouses(m, cfg)
        assert "linkDynTempl" not in m.warehouses_content["airports"][23]["aircrafts"]["helicopters"]["UH-1H"]
        assert result.templates_linked == 0

    def test_non_template_group_ignored(self) -> None:
        m = _mission(groups=[_template_group(5, "Normal UH-1H", "UH-1H", dyn=False)])
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 1}}}}}
        apply_warehouses(m, cfg)
        assert "linkDynTempl" not in m.warehouses_content["airports"][23]["aircrafts"]["helicopters"]["UH-1H"]


class TestPerAirportOverride:
    def test_override_merges_over_defaults(self) -> None:
        m = _mission()
        cfg = {
            "blue": {
                "defaults": {"aircrafts": {"UH-1H": {"amount": "unlimited"}}},
                "airports": {24: {"aircrafts": {"Yak-52": {"amount": 5}}}},
            }
        }
        apply_warehouses(m, cfg)
        a24 = m.warehouses_content["airports"][24]["aircrafts"]
        assert a24["helicopters"]["UH-1H"]["unlimited"] is True  # from defaults
        assert a24["planes"]["Yak-52"]["initialAmount"] == 5  # from override
        assert 23 not in [
            k
            for k in m.warehouses_content["airports"]
            if m.warehouses_content["airports"][k]["dynamicSpawn"] and k == 23
        ]


class TestCategoryNesting:
    """C8: DCS nests dynamic-slot aircraft under aircrafts.{helicopters,planes};
    a flat entry is silently ignored and the template never binds."""

    def test_helicopter_and_plane_nested_by_category(self) -> None:
        groups = [
            {"groupId": 10, "name": "DST - UH-1H", "dynSpawnTemplate": True, "units": [{"type": "UH-1H"}]},
            {"groupId": 11, "name": "DST - A-10C II", "dynSpawnTemplate": True, "units": [{"type": "A-10C_2"}]},
        ]
        mission_content = {
            "coalition": {
                "blue": {
                    "country": [
                        {
                            "name": "USA",
                            "helicopter": {"group": [groups[0]]},
                            "plane": {"group": [groups[1]]},
                        }
                    ]
                }
            }
        }
        warehouses = {"airports": {23: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}}}}
        m = DcsMission(
            file_path=Path("d.miz"),
            mission_content=mission_content,
            warehouses_content=warehouses,
            theatre_content="Caucasus",
        )
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 1}, "A-10C_2": {"amount": 1}}}}}
        apply_warehouses(m, cfg)

        aircrafts = m.warehouses_content["airports"][23]["aircrafts"]
        assert aircrafts["helicopters"]["UH-1H"]["linkDynTempl"] == 10
        assert aircrafts["planes"]["A-10C_2"]["linkDynTempl"] == 11
        # Nothing placed flat (the bug): only the two category sub-tables.
        assert set(aircrafts.keys()) == {"helicopters", "planes"}


class TestAutoFill:
    def test_defaults_without_aircrafts_stock_every_coalition_template(self) -> None:
        m = _mission()  # one blue dynamic template: UH-1H (groupId 2114)
        cfg = {"blue": {"defaults": {"fuel": "unlimited"}}}  # no aircrafts -> auto-fill

        result = apply_warehouses(m, cfg)

        heli = m.warehouses_content["airports"][23]["aircrafts"]["helicopters"]
        assert heli["UH-1H"]["unlimited"] is True
        assert heli["UH-1H"]["linkDynTempl"] == 2114
        assert result.templates_linked == 2  # both blue airports auto-filled

    def test_explicit_aircrafts_overrides_auto_fill(self) -> None:
        m = _mission()  # blue template is UH-1H
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 3}}}}}

        apply_warehouses(m, cfg)

        heli = m.warehouses_content["airports"][23]["aircrafts"]["helicopters"]
        assert heli["UH-1H"]["initialAmount"] == 3  # explicit list used, not the unlimited auto-fill


class TestEdgeCases:
    def test_no_airports_returns_zero(self) -> None:
        m = DcsMission(file_path=Path("d.miz"), warehouses_content={"airports": {}}, mission_content={})
        result = apply_warehouses(m, {"blue": {"defaults": {}}})
        assert result.airports_configured == 0
