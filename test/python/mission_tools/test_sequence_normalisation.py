"""Tests for the mission's sequence normalisation.

`FIX-GROUP-CONTAINER-SHAPE`. Eight readers assume a group container is a list, which the Lua parser
hands back only when the keys are a contiguous `1..N`. A hand edit, a third-party tool or a deletion
produces the other, and the build then dies on `AttributeError: 'int' object has no attribute 'get'`
at whichever subsystem read the table first — three debugging rounds on 2026-08-18, and the message
named the offending table in none of them.

The `payload.pylons` tests are the important ones: they pin the trap a blanket normalisation would
have walked into.
"""

from __future__ import annotations

from typing import Any

from mission_tools.sequence_normalisation import normalise_mission_sequences


def _mission(group_container: Any, **group_extra: Any) -> dict[str, Any]:
    """A minimal mission whose `plane.group` container is whatever the caller wants to test."""
    return {
        "coalition": {
            "blue": {
                "country": {1: {"id": 2, "name": "USA", "plane": {"group": group_container, **group_extra}}},
            }
        }
    }


def _groups(mission: dict[str, Any]) -> Any:
    return mission["coalition"]["blue"]["country"][0]["plane"]["group"]


_ALPHA = {"name": "Alpha", "groupId": 1}
_BRAVO = {"name": "Bravo", "groupId": 2}
_CHARLIE = {"name": "Charlie", "groupId": 3}


class TestTheShapesTheParserProduces:
    def test_a_contiguous_dict_becomes_a_list(self) -> None:
        mission = _mission({1: _ALPHA, 2: _BRAVO})
        holes = normalise_mission_sequences(mission)
        assert _groups(mission) == [_ALPHA, _BRAVO]
        assert holes == []  # contiguous is not a hole: nothing to report

    def test_a_list_is_left_alone(self) -> None:
        mission = _mission([_ALPHA, _BRAVO])
        assert normalise_mission_sequences(mission) == []
        assert _groups(mission) == [_ALPHA, _BRAVO]

    def test_a_holed_dict_is_closed_up(self) -> None:
        # The `1,3,4` a hand-deleted Lua block leaves behind.
        mission = _mission({1: _ALPHA, 3: _BRAVO, 4: _CHARLIE})
        normalise_mission_sequences(mission)
        assert _groups(mission) == [_ALPHA, _BRAVO, _CHARLIE]

    def test_the_survivors_keep_their_order(self) -> None:
        mission = _mission({3: _CHARLIE, 1: _ALPHA})
        normalise_mission_sequences(mission)
        # Numeric keys sort as numbers: waypoint 10 must not land between 1 and 2.
        assert [g["name"] for g in _groups(mission)] == ["Alpha", "Charlie"]

    def test_a_single_high_key_is_closed_to_one(self) -> None:
        # `units` numbered `[3]`, which the repair regex of 2026-08-18 produced.
        mission = _mission({3: _ALPHA})
        normalise_mission_sequences(mission)
        assert _groups(mission) == [_ALPHA]

    def test_an_empty_container_becomes_an_empty_list(self) -> None:
        # `setdefault("group", []).append(...)` returns the EXISTING empty dict, so its `[]` default
        # never applies and `.append` lands on a dict — the crash this lot opened on. The key is kept:
        # `tasks = {}` is what DCS writes on every waypoint with no task, and an empty list and an
        # empty dict serialise identically, so a mission nobody touched is unchanged.
        mission = _mission({})
        normalise_mission_sequences(mission)
        assert mission["coalition"]["blue"]["country"][0]["plane"]["group"] == []

    def test_an_empty_container_can_then_be_appended_to(self) -> None:
        mission = _mission({})
        normalise_mission_sequences(mission)
        plane = mission["coalition"]["blue"]["country"][0]["plane"]
        plane.setdefault("group", []).append(_ALPHA)  # the exact call coalition_placeholder makes
        assert plane["group"] == [_ALPHA]


class TestTheHolesAreNamed:
    def test_a_hole_is_reported_with_its_path(self) -> None:
        mission = _mission({1: _ALPHA, 3: _BRAVO})
        holes = normalise_mission_sequences(mission)
        assert len(holes) == 1
        assert holes[0].path == "coalition.blue.country[1].plane.group"
        assert holes[0].keys == (1, 3)

    def test_the_message_says_what_it_became(self) -> None:
        holes = normalise_mission_sequences(_mission({1: _ALPHA, 3: _BRAVO}))
        assert str(holes[0]) == "coalition.blue.country[1].plane.group: keys 1, 3 -> 1..2"

    def test_a_hole_deeper_in_is_reported_too(self) -> None:
        # The one that killed a build in the waypoint injector, unrelated to the edit that caused it.
        mission = _mission(
            {
                1: {
                    "name": "Alpha",
                    "units": {3: {"name": "Alpha-1"}},
                    "route": {"points": {2: {"x": 0}}},
                }
            }
        )
        paths = {hole.path for hole in normalise_mission_sequences(mission)}
        assert "coalition.blue.country[1].plane.group[1].units" in paths
        assert "coalition.blue.country[1].plane.group[1].route.points" in paths

    def test_a_well_formed_mission_reports_nothing(self) -> None:
        mission = _mission(
            [
                {
                    "name": "Alpha",
                    "units": [{"name": "Alpha-1"}],
                    "route": {"points": [{"x": 0}, {"x": 1}]},
                }
            ]
        )
        assert normalise_mission_sequences(mission) == []


class TestThePylonTrap:
    """A blanket normalisation would move every weapon to a different station, in silence."""

    def _fa18(self) -> dict[str, Any]:
        # A real FA-18C carries stations 1, 4, 5, 6 and 9 — the numbering IS the meaning.
        return _mission(
            {
                1: {
                    "name": "Hornet",
                    "units": {
                        1: {
                            "name": "Hornet-1",
                            "payload": {
                                "fuel": 4900,
                                "pylons": {
                                    1: {"CLSID": "AIM-9"},
                                    4: {"CLSID": "Mk-82"},
                                    5: {"CLSID": "tank"},
                                    6: {"CLSID": "Mk-82"},
                                    9: {"CLSID": "AIM-9"},
                                },
                            },
                        }
                    },
                }
            }
        )

    def test_pylons_keep_their_station_numbers(self) -> None:
        mission = self._fa18()
        normalise_mission_sequences(mission)
        pylons = _groups(mission)[0]["units"][0]["payload"]["pylons"]
        assert isinstance(pylons, dict)
        assert sorted(pylons) == [1, 4, 5, 6, 9]

    def test_each_station_keeps_its_store(self) -> None:
        mission = self._fa18()
        normalise_mission_sequences(mission)
        pylons = _groups(mission)[0]["units"][0]["payload"]["pylons"]
        assert pylons[4]["CLSID"] == "Mk-82"
        assert pylons[9]["CLSID"] == "AIM-9"

    def test_a_sparse_pylon_table_is_not_reported_as_a_hole(self) -> None:
        # It is not holed, it is keyed. Reporting it would train the reader to ignore the warnings.
        assert normalise_mission_sequences(self._fa18()) == []

    def test_the_units_around_it_are_still_normalised(self) -> None:
        mission = self._fa18()
        normalise_mission_sequences(mission)
        assert isinstance(_groups(mission)[0]["units"], list)


class TestTheOtherSequences:
    def test_trigger_zones(self) -> None:
        mission = {"triggers": {"zones": {1: {"name": "A"}, 4: {"name": "B"}}}}
        holes = normalise_mission_sequences(mission)
        assert mission["triggers"]["zones"] == [{"name": "A"}, {"name": "B"}]
        assert holes[0].path == "triggers.zones"

    def test_zone_vertices(self) -> None:
        mission = {"triggers": {"zones": [{"name": "A", "verticies": {1: {"x": 0}, 3: {"x": 1}}}]}}
        normalise_mission_sequences(mission)
        assert mission["triggers"]["zones"][0]["verticies"] == [{"x": 0}, {"x": 1}]

    def test_map_drawing_objects(self) -> None:
        mission = {"drawings": {"layers": {1: {"name": "Blue", "objects": {2: {"name": "line"}}}}}}
        normalise_mission_sequences(mission)
        assert mission["drawings"]["layers"][0]["objects"] == [{"name": "line"}]

    def test_nested_combo_tasks(self) -> None:
        # A waypoint's task is a ComboTask holding more tasks, which is how DCS writes an Escort.
        mission = _mission(
            {
                1: {
                    "name": "Alpha",
                    "route": {
                        "points": [
                            {
                                "task": {
                                    "id": "ComboTask",
                                    "params": {
                                        "tasks": {1: {"id": "Escort", "params": {"groupId": 3}}, 3: {"id": "EPLRS"}}
                                    },
                                }
                            }
                        ]
                    },
                }
            }
        )
        normalise_mission_sequences(mission)
        tasks = _groups(mission)[0]["route"]["points"][0]["task"]["params"]["tasks"]
        assert [t["id"] for t in tasks] == ["Escort", "EPLRS"]

    def test_the_country_container_itself(self) -> None:
        mission = {"coalition": {"blue": {"country": {2: {"id": 2, "name": "USA"}}}}}
        holes = normalise_mission_sequences(mission)
        assert mission["coalition"]["blue"]["country"] == [{"id": 2, "name": "USA"}]
        assert holes[0].path == "coalition.blue.country"


class TestItSurvivesMalformedInput:
    def test_a_non_mapping_is_left_alone(self) -> None:
        assert normalise_mission_sequences(None) == []
        assert normalise_mission_sequences("not a mission") == []

    def test_an_unexpected_shape_does_not_raise(self) -> None:
        # A `.miz` is untrusted input; the normaliser must not become the new crash.
        mission = {"coalition": {"blue": {"country": "nonsense"}}, "triggers": {"zones": 42}}
        assert normalise_mission_sequences(mission) == []

    def test_a_missing_branch_is_skipped(self) -> None:
        assert normalise_mission_sequences({"theatre": "Caucasus"}) == []
