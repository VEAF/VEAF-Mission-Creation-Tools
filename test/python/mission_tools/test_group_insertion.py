"""Tests for mission_tools.group_insertion."""

from typing import Any

import pytest
from mission_tools.group_insertion import add_group, find_or_add_country, max_ids


def _mission(coalition: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"coalition": coalition or {"blue": {"country": []}, "red": {"country": []}}}


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
