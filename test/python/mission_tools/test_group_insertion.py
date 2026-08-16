"""Tests for mission_tools.group_insertion."""

from typing import Any

import pytest
from mission_tools.group_insertion import (
    add_group,
    air_category_for_type,
    air_category_for_type_verbose,
    assign_country_to_side,
    find_or_add_country,
    max_ids,
)


def _mission(coalition: dict[str, Any] | None = None, coalitions: dict[str, Any] | None = None) -> dict[str, Any]:
    mission: dict[str, Any] = {"coalition": coalition or {"blue": {"country": []}, "red": {"country": []}}}
    if coalitions is not None:
        mission["coalitions"] = coalitions
    return mission


def _group(name: str = "New Group", unit_count: int = 1) -> dict[str, Any]:
    return {
        "name": name,
        "x": 0,
        "y": 0,
        "units": [{"name": f"{name} Unit {i + 1}", "type": "BTR-80", "x": 0, "y": 0} for i in range(unit_count)],
    }


class TestAddGroup:
    def test_appends_the_group_under_the_new_country_and_category(self) -> None:
        mission = _mission()

        add_group(
            mission,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            group=_group("Red Armor Section"),
        )

        countries = mission["coalition"]["red"]["country"]
        assert len(countries) == 1
        assert countries[0]["name"] == "Russia"
        assert [g["name"] for g in countries[0]["vehicle"]["group"]] == ["Red Armor Section"]

    def test_reuses_an_existing_country_instead_of_duplicating_it(self) -> None:
        mission = _mission({"red": {"country": [{"id": 0, "name": "Russia", "plane": {"group": []}}]}})

        add_group(
            mission,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            group=_group("Red Armor Section"),
        )

        countries = mission["coalition"]["red"]["country"]
        assert len(countries) == 1
        assert [g["name"] for g in countries[0]["vehicle"]["group"]] == ["Red Armor Section"]
        # the pre-existing plane container is untouched, not clobbered by the reuse
        assert countries[0]["plane"]["group"] == []

    def test_assigns_a_fresh_group_id_past_the_highest_existing_one(self) -> None:
        mission = _mission(
            {"red": {"country": [{"id": 0, "name": "Russia", "vehicle": {"group": [{"groupId": 7, "units": []}]}}]}}
        )

        new_id = add_group(
            mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group()
        )

        assert new_id == 8

    def test_assigns_fresh_unit_ids_even_with_a_sparse_existing_range(self) -> None:
        mission = _mission(
            {
                "red": {
                    "country": [
                        {
                            "id": 0,
                            "name": "Russia",
                            "vehicle": {"group": [{"groupId": 1, "units": [{"unitId": 3}, {"unitId": 9}]}]},
                        }
                    ]
                }
            }
        )

        add_group(
            mission,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            group=_group(unit_count=2),
        )

        new_group = mission["coalition"]["red"]["country"][0]["vehicle"]["group"][-1]
        unit_ids = [unit["unitId"] for unit in new_group["units"]]
        assert unit_ids == [10, 11]

    def test_calling_twice_creates_two_distinct_groups(self) -> None:
        mission = _mission()

        first_id = add_group(
            mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group()
        )
        second_id = add_group(
            mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group()
        )

        assert first_id != second_id
        groups = mission["coalition"]["red"]["country"][0]["vehicle"]["group"]
        assert len(groups) == 2

    def test_raises_for_an_unknown_category(self) -> None:
        mission = _mission()

        with pytest.raises(ValueError, match="Unknown group category"):
            add_group(
                mission, coalition="red", country_id=0, country_name="Russia", category="submarine", group=_group()
            )

    def test_raises_for_an_unknown_coalition(self) -> None:
        mission = _mission()

        with pytest.raises(KeyError):
            add_group(
                mission, coalition="neutral", country_id=0, country_name="Russia", category="vehicle", group=_group()
            )


class TestAddGroupPopulatesCoalitions:
    """A group's country must land in `coalitions.<side>` too, or DCS cannot load the mission."""

    def test_a_new_group_assigns_its_country_to_the_side(self) -> None:
        # The blank-mission shape: coalitions ships as an empty dict per side, not a list.
        mission = _mission(coalitions={"blue": {}, "red": {}, "neutrals": {}})

        add_group(mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group())

        assert mission["coalitions"]["red"] == [0]

    def test_two_groups_from_the_same_country_list_it_once(self) -> None:
        mission = _mission(coalitions={"blue": {}, "red": {}, "neutrals": {}})

        add_group(mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group("a"))
        add_group(mission, coalition="red", country_id=0, country_name="Russia", category="vehicle", group=_group("b"))

        assert mission["coalitions"]["red"] == [0]

    def test_a_second_country_on_the_side_appends(self) -> None:
        # The populated shape: coalitions.<side> is already a list of ids.
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []})

        add_group(mission, coalition="blue", country_id=11, country_name="Georgia", category="vehicle", group=_group())

        assert mission["coalitions"]["blue"] == [2, 11]

    def test_it_creates_the_coalitions_table_when_absent(self) -> None:
        # A hand-made mission missing the table entirely must still come out loadable.
        mission = _mission()
        assert "coalitions" not in mission

        add_group(mission, coalition="blue", country_id=2, country_name="USA", category="vehicle", group=_group())

        assert mission["coalitions"]["blue"] == [2]


class TestAssignCountryToSide:
    def test_is_idempotent(self) -> None:
        mission: dict[str, Any] = {"coalitions": {"blue": [2]}}
        assign_country_to_side(mission, "blue", 2)
        assert mission["coalitions"]["blue"] == [2]

    def test_normalises_the_empty_dict_shape_to_a_list(self) -> None:
        mission: dict[str, Any] = {"coalitions": {"blue": {}}}
        assign_country_to_side(mission, "blue", 2)
        assert mission["coalitions"]["blue"] == [2]


class TestFindOrAddCountry:
    def test_returns_the_same_object_reference_for_an_existing_country(self) -> None:
        country = {"id": 0, "name": "Russia"}
        coalition = {"country": [country]}

        found = find_or_add_country(coalition, 0, "Russia")
        found["vehicle"] = {"group": ["mutated"]}

        assert coalition["country"][0]["vehicle"] == {"group": ["mutated"]}


class TestMaxIds:
    def test_returns_zero_zero_for_an_empty_mission(self) -> None:
        assert max_ids(_mission()) == (0, 0)


class TestAirCategoryForType:
    """A helicopter written under `plane` is a slot DCS shows with its type in RED and cannot fly.

    Found in game on 2026-08-16: `add_air_group` and `add_player_slot` both hard-coded
    `category="plane"`, so every helicopter slot either action produced was broken — and nothing
    in the mission file says so, since the category is structural, not a validated field.
    """

    def test_a_helicopter_type_resolves_to_helicopter(self) -> None:
        assert air_category_for_type("UH-1H") == "helicopter"
        assert air_category_for_type("CH-47Fbl1") == "helicopter"
        assert air_category_for_type("Mi-8MT") == "helicopter"

    def test_a_plane_type_resolves_to_plane(self) -> None:
        assert air_category_for_type("A-10C_2") == "plane"
        assert air_category_for_type("F-16C_50") == "plane"

    def test_an_unknown_type_falls_back_to_plane(self) -> None:
        # Third-party mods are absent from the generated database (`Hercules` is), so an unknown
        # type must not raise — the mission maker asked for a type we simply cannot classify.
        assert air_category_for_type("Hercules") == "plane"
        assert air_category_for_type("NoSuchAircraftType") == "plane"

    def test_the_fallback_is_reported_so_it_is_not_silent(self) -> None:
        # A silent wrong category is exactly the defect this helper exists to stop: when the type
        # cannot be classified, the caller gets told rather than guessing well.
        category, warning = air_category_for_type_verbose("NoSuchAircraftType")
        assert category == "plane"
        assert warning is not None
        assert "NoSuchAircraftType" in warning

    def test_a_known_type_reports_no_warning(self) -> None:
        assert air_category_for_type_verbose("UH-1H") == ("helicopter", None)
