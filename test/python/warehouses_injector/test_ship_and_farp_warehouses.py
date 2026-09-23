"""FIX-DYNSLOT-WIRING ticket 02 — the warehouses of ships and FARPs.

DCS keeps two warehouse tables: ``airports``, keyed by airdrome id, and ``warehouses``, keyed by the
**unit id** of a ship or a static that carries one. Dynamic slots work in both. The step only ever
walked the first, so on a fully built ``test-import.miz`` the airports ended with 832 links and none
dangling, while the second table kept its 69 links, **all 69** pointing at a group that no longer
exists. Nine of its 41 entries carry stock.

For a carrier-based airframe that is a complete explanation on its own, which is how this lot
started: a mission maker asking why the F-14B(U) is not offered.

What an object can host is read from the units database rather than guessed (measured 2026-09-22 on
`dcsUnits.yaml`): the ``AircraftCarrier`` attribute means planes **and** helicopters (Stennis,
Tarawa, Kuznetsov), ``HelicopterCarrier`` alone or the ``Heliport`` category means helicopters only
(Perry, Moskva, FARP, oil platform), and anything else hosts no aircraft at all and is left alone.
On the two real missions measured, that is 5 carriers, 13 helicopter-capable ships and 23 heliports.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pytest
from mission_tools.miz_tools import DcsMission
from warehouses_injector import apply_warehouses

#: Unit ids of the objects each mission below carries a warehouse for.
_STENNIS = 1330
_PERRY = 1156
_FARP = 702
_TANKER = 1400
_RED_KUZNETSOV = 2001


def _template(group_id: int, name: str, unit_type: str) -> dict:
    """A dynamic-spawn template the warehouse step can link to."""
    return {"groupId": group_id, "name": name, "dynSpawnTemplate": True, "units": [{"type": unit_type}]}


def _carrier(unit_id: int, name: str, unit_type: str) -> dict:
    """A ship/static group whose single unit carries a warehouse."""
    return {"name": name, "units": [{"unitId": unit_id, "name": name, "type": unit_type}]}


def _mission(*, warehouses: dict | None = None) -> DcsMission:
    """A Caucasus mission with one blue plane template, one helicopter template, and four objects."""
    mission_content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "CJTF Blue",
                        "id": 80,
                        "plane": {"group": [_template(472, "F-14B Template", "F-14B")]},
                        "helicopter": {"group": [_template(2114, "UH-1H Template", "UH-1H")]},
                        "ship": {
                            "group": [
                                _carrier(_STENNIS, "CSG-74 Stennis", "Stennis"),
                                _carrier(_PERRY, "FFG-7CL Escort", "PERRY"),
                                _carrier(_TANKER, "Tanker Elnya", "ELNYA"),
                            ]
                        },
                        "static": {"group": [_carrier(_FARP, "FARP Kaspi MM54", "FARP")]},
                    }
                ]
            },
            "red": {
                "country": [
                    {
                        "name": "CJTF Red",
                        "id": 81,
                        "ship": {"group": [_carrier(_RED_KUZNETSOV, "CV Kuznetsov", "CV_1143_5")]},
                    }
                ]
            },
        }
    }
    default = {
        _STENNIS: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
        _PERRY: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
        _TANKER: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
        _FARP: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}},
        _RED_KUZNETSOV: {"coalition": "RED", "dynamicSpawn": False, "aircrafts": {}},
    }
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content=mission_content,
        warehouses_content={"airports": {}, "warehouses": warehouses if warehouses is not None else default},
        theatre_content="Caucasus",
    )


def _stock(mission: DcsMission, unit_id: int) -> dict:
    """The ``aircrafts`` sub-tables of one ship/FARP warehouse."""
    return (mission.warehouses_content or {})["warehouses"][unit_id].get("aircrafts") or {}


class TestWhatEachObjectCanHost:
    """An object is stocked with what it can actually take, read from the units database."""

    def test_a_carrier_takes_planes_and_helicopters(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {"fuel": "unlimited"}}})
        stock = _stock(mission, _STENNIS)
        assert set(stock) == {"planes", "helicopters"}
        assert stock["planes"]["F-14B"]["linkDynTempl"] == 472
        assert stock["helicopters"]["UH-1H"]["linkDynTempl"] == 2114

    def test_a_helicopter_ship_takes_helicopters_only(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert set(_stock(mission, _PERRY)) == {"helicopters"}

    def test_a_farp_takes_helicopters_only(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert set(_stock(mission, _FARP)) == {"helicopters"}

    def test_a_ship_with_no_flight_deck_is_left_alone(self) -> None:
        """A tanker hosts no aircraft: it must not even get ``dynamicSpawn``.

        Measured while writing this: an Arleigh Burke would have been the wrong example — DCS
        gives it ``HelicopterCarrier``, and it does have a helipad. 23 of the 57 stock ships
        carry no carrier attribute at all; the Elnya tanker is one.
        """
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        entry = (mission.warehouses_content or {})["warehouses"][_TANKER]
        assert entry["dynamicSpawn"] is False
        assert entry["aircrafts"] == {}


class TestSelection:
    """Which objects a coalition block reaches."""

    def test_every_object_of_the_coalition_by_default(self) -> None:
        """No ``ships:``/``farps:`` key means all of them, as ``airports:`` already behaves."""
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        entries = (mission.warehouses_content or {})["warehouses"]
        assert entries[_STENNIS]["dynamicSpawn"] is True
        assert entries[_PERRY]["dynamicSpawn"] is True
        assert entries[_FARP]["dynamicSpawn"] is True

    def test_an_undeclared_coalition_is_untouched(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert (mission.warehouses_content or {})["warehouses"][_RED_KUZNETSOV]["dynamicSpawn"] is False

    def test_ships_key_narrows_the_ships_and_only_the_ships(self) -> None:
        """Each family defaults on its own: naming a ship says nothing about the FARPs."""
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}, "ships": {"CSG-74 Stennis": {}}}})
        entries = (mission.warehouses_content or {})["warehouses"]
        assert entries[_STENNIS]["dynamicSpawn"] is True
        assert entries[_PERRY]["dynamicSpawn"] is False
        assert entries[_FARP]["dynamicSpawn"] is True, "farps: was not named, so its own default applies"

    def test_farps_key_names_a_farp(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}, "farps": {"FARP Kaspi MM54": {}}}})
        entries = (mission.warehouses_content or {})["warehouses"]
        assert entries[_FARP]["dynamicSpawn"] is True
        assert entries[_STENNIS]["dynamicSpawn"] is True, "ships: was not named, so its own default applies"

    def test_a_numeric_unit_id_reaches_the_same_entry_as_the_name(self) -> None:
        by_name = _mission()
        apply_warehouses(by_name, {"blue": {"defaults": {}, "ships": {"CSG-74 Stennis": {}}}})
        by_id = _mission()
        apply_warehouses(by_id, {"blue": {"defaults": {}, "ships": {_STENNIS: {}}}})
        assert _stock(by_name, _STENNIS) == _stock(by_id, _STENNIS)

    def test_an_empty_ships_key_selects_nothing(self) -> None:
        """``ships: {}`` is an explicit empty list, not the absent-key default."""
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}, "ships": {}}})
        entries = (mission.warehouses_content or {})["warehouses"]
        assert entries[_STENNIS]["dynamicSpawn"] is False
        assert entries[_FARP]["dynamicSpawn"] is True, "farps: was not named, so its default still applies"

    def test_a_name_that_matches_nothing_is_reported_and_skipped(self, caplog: pytest.LogCaptureFixture) -> None:
        """A typo in a ship name must say so: silently configuring nothing is the worse outcome."""
        mission = _mission()
        with caplog.at_level(logging.WARNING):
            apply_warehouses(mission, {"blue": {"defaults": {}, "ships": {"CSG-74 Stenis": {}}}})
        assert "CSG-74 Stenis" in caplog.text
        assert (mission.warehouses_content or {})["warehouses"][_STENNIS]["dynamicSpawn"] is False

    def test_naming_a_farp_under_ships_matches_nothing(self) -> None:
        """The two keys select by unit category, so a heliport is not reachable through ships:."""
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}, "ships": {"FARP Kaspi MM54": {}}, "farps": {}}})
        assert (mission.warehouses_content or {})["warehouses"][_FARP]["dynamicSpawn"] is False


class TestDeadLinks:
    """A link a previous build left pointing at nothing does not survive."""

    def test_a_dead_link_is_replaced(self) -> None:
        mission = _mission(
            warehouses={
                _STENNIS: {
                    "coalition": "BLUE",
                    "dynamicSpawn": True,
                    "aircrafts": {"planes": {"F-14B": {"initialAmount": 100, "linkDynTempl": 3853}}},
                }
            }
        )
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert _stock(mission, _STENNIS)["planes"]["F-14B"]["linkDynTempl"] == 472

    def test_a_dead_link_on_a_type_with_no_template_is_dropped(self) -> None:
        """Nothing can be linked, so the stale id must go rather than be left to render as None."""
        mission = _mission(
            warehouses={
                _STENNIS: {
                    "coalition": "BLUE",
                    "dynamicSpawn": True,
                    "aircrafts": {"planes": {"Su-33": {"initialAmount": 100, "linkDynTempl": 3872}}},
                }
            }
        )
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert "linkDynTempl" not in _stock(mission, _STENNIS)["planes"]["Su-33"]


class TestResult:
    """The run result counts what it touched."""

    def test_objects_are_counted_apart_from_airports(self) -> None:
        mission = _mission()
        result = apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert result.airports_configured == 0
        assert result.objects_configured == 3, "the Stennis, the Perry and the FARP; not the tanker"
        assert result.templates_linked > 0
