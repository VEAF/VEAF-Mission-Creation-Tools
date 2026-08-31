"""Tests for the Dynamic-Slot warehouse wiring (DYNSLOT-WAREHOUSE)."""

from __future__ import annotations

import logging
from pathlib import Path

import pytest
from mission_tools.miz_tools import DcsMission
from warehouses_injector import apply_warehouses

# Syria airdrome ids, resolved through veaf_libs.dcs_airdromes.
_AKROTIRI = 44
_LAKATAMIA = 48
_NAQOURA = 52
_INCIRLIK = 16


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


class TestHotStart:
    """A dynamic slot the pilot can start with engines running (FIX-WAREHOUSES-INCREMENTAL 03).

    `allowHotStart` is what offers "spawn hot" on a dynamic-slot airfield. The DCS Mission Editor
    writes it `false`, which the bootstrap copies, and nothing ever turned it back on — reported in
    game on 2026-08-16: the option was greyed out on an airfield whose dynamic slots otherwise
    worked. An airfield configured for dynamic slots offers a hot start by default now, and a
    mission that wants cold starts only says so.
    """

    def test_a_configured_airfield_offers_a_hot_start(self) -> None:
        m = _mission()
        apply_warehouses(m, {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": "unlimited"}}}}})
        assert m.warehouses_content["airports"][23]["allowHotStart"] is True

    def test_hot_start_can_be_turned_off(self) -> None:
        m = _mission()
        apply_warehouses(m, {"blue": {"defaults": {"hot_start": False, "aircrafts": {}}}})
        assert m.warehouses_content["airports"][23]["allowHotStart"] is False

    def test_an_airfield_of_another_coalition_is_untouched(self) -> None:
        m = _mission()
        m.warehouses_content["airports"][99]["allowHotStart"] = False
        apply_warehouses(m, {"blue": {"defaults": {"aircrafts": {}}}})
        assert m.warehouses_content["airports"][99]["allowHotStart"] is False


class TestParkingLimits:
    """Stock only what the terrain can park (FIX-DYNSLOT-PARKING 01).

    Reported at the 2026-08-30 meeting and confirmed in game on 2026-08-31: Lakatamia and Naqoura
    (Syria) offered helicopters only, whatever the mission stocked, because they have nothing but
    helipads. The build stocked 149 plane types there that DCS would never offer. It now asks the
    bundled parking dump what the airfield can park, and stays quiet about the rest.
    """

    @staticmethod
    def _syria_mission(airport_ids: list[int]) -> DcsMission:
        """A Syria mission with one blue helicopter template and one blue plane template."""
        groups = [
            _template_group(10, "DST - UH-1H", "UH-1H"),
            _template_group(11, "DST - A-10C II", "A-10C_2"),
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
        warehouses = {
            "airports": {aid: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}} for aid in airport_ids}
        }
        return DcsMission(
            file_path=Path("d.miz"),
            mission_content=mission_content,
            warehouses_content=warehouses,
            theatre_content="Syria",
        )

    def test_a_helipad_only_airfield_is_stocked_with_helicopters_only(self) -> None:
        m = self._syria_mission([_NAQOURA])  # Naqoura: nine Term_Type 40 stands, no runway
        apply_warehouses(m, {"blue": {"defaults": {}}})  # auto-fill
        aircrafts = m.warehouses_content["airports"][_NAQOURA]["aircrafts"]
        assert aircrafts["helicopters"]["UH-1H"]["unlimited"] is True
        assert "planes" not in aircrafts

    def test_a_real_airbase_is_stocked_exactly_as_before(self) -> None:
        m = self._syria_mission([_INCIRLIK])  # Incirlik: 104/68/72 in quantity
        apply_warehouses(m, {"blue": {"defaults": {}}})
        aircrafts = m.warehouses_content["airports"][_INCIRLIK]["aircrafts"]
        assert aircrafts["helicopters"]["UH-1H"]["unlimited"] is True
        assert aircrafts["planes"]["A-10C_2"]["unlimited"] is True

    def test_an_explicit_aircrafts_list_is_filtered_the_same_way(self) -> None:
        # DCS ignores what it cannot park, so writing it is pointless however it was asked for.
        m = self._syria_mission([_NAQOURA])
        cfg = {"blue": {"defaults": {"aircrafts": {"UH-1H": {"amount": 2}, "A-10C_2": {"amount": 4}}}}}
        apply_warehouses(m, cfg)
        aircrafts = m.warehouses_content["airports"][_NAQOURA]["aircrafts"]
        assert aircrafts["helicopters"]["UH-1H"]["initialAmount"] == 2
        assert "planes" not in aircrafts

    def test_a_dropped_type_carries_no_template_link(self) -> None:
        # A linkDynTempl to a type that is no longer stocked is dead weight.
        m = self._syria_mission([_NAQOURA])
        result = apply_warehouses(m, {"blue": {"defaults": {}}})
        assert result.templates_linked == 1  # the helicopter only, not the A-10C

    def test_the_filter_is_silent(self, caplog: pytest.LogCaptureFixture) -> None:
        m = self._syria_mission([_NAQOURA])
        with caplog.at_level(logging.DEBUG):
            apply_warehouses(m, {"blue": {"defaults": {}}})
        assert not [r for r in caplog.records if "A-10C" in r.getMessage()]

    def test_a_theatre_with_no_parking_data_is_untouched(self) -> None:
        # Every map but Caucasus, Persian Gulf and Syria: no data, no filtering, no message.
        m = self._syria_mission([_NAQOURA])
        m.theatre_content = "Normandy"
        apply_warehouses(m, {"blue": {"defaults": {}}})
        aircrafts = m.warehouses_content["airports"][_NAQOURA]["aircrafts"]
        assert aircrafts["planes"]["A-10C_2"]["unlimited"] is True
        assert aircrafts["helicopters"]["UH-1H"]["unlimited"] is True

    def test_an_airfield_absent_from_the_parking_file_is_untouched(self) -> None:
        m = self._syria_mission([999999])
        apply_warehouses(m, {"blue": {"defaults": {}}})
        aircrafts = m.warehouses_content["airports"][999999]["aircrafts"]
        assert aircrafts["planes"]["A-10C_2"]["unlimited"] is True

    def test_stock_the_terrain_cannot_park_is_pruned(self) -> None:
        # Measured on OpenTraining_Syria_20260830.miz: the source mission already carries 144 plane
        # types at Lakatamia, from an earlier build. Skipping the write is not enough — the dead
        # stock has to go, or it survives every future build.
        m = self._syria_mission([_LAKATAMIA])
        m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"] = {
            "planes": {"A-10C_2": {"unlimited": True}},
            "helicopters": {"UH-1H": {"unlimited": True}},
        }
        apply_warehouses(m, {"blue": {"defaults": {}}})
        aircrafts = m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"]
        assert "planes" not in aircrafts
        assert "UH-1H" in aircrafts["helicopters"]

    def test_nothing_is_pruned_on_a_theatre_with_no_parking_data(self) -> None:
        m = self._syria_mission([_LAKATAMIA])
        m.theatre_content = "Normandy"
        m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"] = {"planes": {"F-16C_50": {"unlimited": True}}}
        apply_warehouses(m, {"blue": {"defaults": {}}})
        assert "F-16C_50" in m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"]["planes"]

    def test_an_airfield_of_another_coalition_keeps_its_stock(self) -> None:
        # The prune only ever touches an airfield the config targets.
        m = self._syria_mission([_LAKATAMIA])
        m.warehouses_content["airports"][_LAKATAMIA]["coalition"] = "RED"
        m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"] = {"planes": {"MiG-29A": {"unlimited": True}}}
        apply_warehouses(m, {"blue": {"defaults": {}}})
        assert "MiG-29A" in m.warehouses_content["airports"][_LAKATAMIA]["aircrafts"]["planes"]

    def test_the_three_reported_airfields_together(self) -> None:
        # The measurable outcome of the lot, on the shape of the real Syria data.
        m = self._syria_mission([_AKROTIRI, _LAKATAMIA, _NAQOURA])
        apply_warehouses(m, {"blue": {"defaults": {}}})
        airports = m.warehouses_content["airports"]
        assert "planes" in airports[_AKROTIRI]["aircrafts"]  # 41 plane stands: unchanged
        assert "planes" not in airports[_LAKATAMIA]["aircrafts"]
        assert "planes" not in airports[_NAQOURA]["aircrafts"]
        for aid in (_AKROTIRI, _LAKATAMIA, _NAQOURA):
            assert airports[aid]["aircrafts"]["helicopters"]["UH-1H"]["unlimited"] is True
