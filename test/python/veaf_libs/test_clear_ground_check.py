"""Tests for checking a mission's ground units in DCS without spawning them (FEAT-CLEAR-GROUND-AT-AUTHORING 05)."""

import sys
from pathlib import Path

import pytest
from mission_tools.miz_tools import create_miz
from veaf_libs import clear_ground_catalogue as cgc
from veaf_libs import clear_ground_check as check
from veaf_libs.blank_mission import generate_blank_mission
from veaf_mission_mcp.add_group import add_group

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_clear_ground_placement import _blocked_point_with_room_nearby  # noqa: E402
from test_clear_ground_survey import FakeDcs  # noqa: E402


class CatalogueDcs(FakeDcs):
    """A DCS that answers exactly as the shipped catalogue measured, except where told otherwise."""

    def __init__(self, blocked_near: tuple[float, float] | None = None) -> None:
        super().__init__(theatre="Caucasus")
        self.catalogue = cgc.catalogue_for_theatre("Caucasus")
        self.blocked_near = blocked_near

    def cell(self, x: float, y: float) -> str:
        if self.blocked_near and abs(x - self.blocked_near[0]) < 200 and abs(y - self.blocked_near[1]) < 200:
            return "0"
        return "1" if check.predict(self.catalogue, x, y) != "blocked" else "0"


def _mission(tmp_path: Path) -> tuple[Path, tuple[float, float]]:
    miz = create_miz(tmp_path / "m.miz", generate_blank_mission("Caucasus"))
    wood = _blocked_point_with_room_nearby()
    common = {"coalition": "red", "country_id": 0, "country_name": "Russia", "category": "vehicle"}
    add_group(
        miz,
        name="placed-by-tools",
        position={"x": wood[0], "y": wood[1]},
        units=[{"type": "BTR-80", "count": 3}],
        **common,
    )
    add_group(
        miz,
        name="kept-in-the-wood",
        position={"x": wood[0], "y": wood[1]},
        units=[{"type": "BTR-80", "count": 2}],
        keep_position=True,
        **common,
    )
    add_group(
        miz,
        name="marker",
        position={"x": wood[0], "y": wood[1]},
        units=[{"type": "Soldier M4", "name": '#command="-sa10"'}],
        keep_position=True,
        **common,
    )
    return miz, wood


def test_the_positions_are_read_from_the_mission_and_markers_are_left_out(tmp_path: Path) -> None:
    miz, _wood = _mission(tmp_path)
    theatre, units, markers = check.ground_units(miz)
    assert theatre == "Caucasus"
    assert sorted({g for g, _u, _x, _y in units}) == ["kept-in-the-wood", "placed-by-tools"]
    assert len(units) == 5 and markers == 1


def test_a_group_kept_in_a_wood_is_found_there_and_the_tools_one_is_not(tmp_path: Path) -> None:
    miz, _wood = _mission(tmp_path)
    report = check.check_mission(miz, CatalogueDcs())
    assert report.blocked_groups == {"kept-in-the-wood": 2}, "the check can fail: it finds the group left in the wood"
    assert report.disagreements == []
    assert "no unit is ever counted as blocked by its neighbours" in report.to_dict()["criterion"]


def test_where_dcs_and_the_catalogue_differ_it_says_so(tmp_path: Path) -> None:
    miz, _wood = _mission(tmp_path)
    _theatre, units, _markers = check.ground_units(miz)
    tools = next((x, y) for g, _u, x, y in units if g == "placed-by-tools")
    report = check.check_mission(miz, CatalogueDcs(blocked_near=tools))
    assert "placed-by-tools" in report.blocked_groups
    assert {u.group for u in report.disagreements} >= {"placed-by-tools"}
    assert all(
        u.probed == "blocked" and u.predicted == "clear" for u in report.disagreements if u.group == "placed-by-tools"
    )


def test_the_offer_launches_nothing_and_names_the_command(tmp_path: Path) -> None:
    miz, _wood = _mission(tmp_path)
    offer = check.offer_check(miz)
    assert offer["launched"] is False
    assert "clear-ground-check" in offer["command"] and str(miz) in offer["command"]
    assert offer["vehicles"] == 5 and offer["markers_left_to_runtime"] == 1
    with pytest.raises(ValueError, match="built .miz"):
        check.offer_check(tmp_path)


def test_a_probe_that_could_not_answer_is_neither_clear_nor_blocked() -> None:
    """Review finding: '?' used to count as a vehicle in a wood."""
    units = [
        check.UnitCheck("g", "a", 0, 0, "unknown", "clear"),
        check.UnitCheck("g", "b", 0, 0, "blocked", "blocked"),
    ]
    report = check.CheckReport("Caucasus", units)
    assert report.blocked == 1 and report.unknown == 1
    assert report.disagreements == []
    assert report.to_dict()["units_unknown"] == 1
