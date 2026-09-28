"""Tests for putting a group the tools place on ground measured clear (FEAT-CLEAR-GROUND-AT-AUTHORING 04)."""

import math
from pathlib import Path

import pytest
from mission_tools.miz_tools import create_miz, read_miz
from veaf_libs import clear_ground_catalogue as cgc
from veaf_libs import clear_ground_placement as placement
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.clear_ground_catalogue import STATE_BLOCKED, STATE_CLEAR, Catalogue, GridSpec, Layer
from veaf_mission_mcp.add_group import add_group


def _wood_then_field() -> Catalogue:
    """Rows 0-19 wood, rows 20-80 open, 25 m apart: a wood south of x=0, a field north of it."""
    grid = GridSpec(-500, -1000, 25, 81, 81)
    states = bytearray([STATE_CLEAR]) * grid.size
    for row in range(20):
        for col in range(81):
            states[row * 81 + col] = STATE_BLOCKED
    layer = Layer("zone:test", grid, states)
    layer.derive_radii()
    return Catalogue("TestTheatre", [layer])


@pytest.fixture
def field(monkeypatch):
    catalogue = _wood_then_field()
    monkeypatch.setattr(
        placement, "catalogue_for_theatre", lambda theatre: catalogue if theatre == "TestTheatre" else None
    )
    return catalogue


def _units(x: float, y: float, n: int = 3, name: str = "u") -> list[dict]:
    return [{"x": x + i * 20, "y": y, "name": f"{name} #{i}"} for i in range(n)]


def test_a_group_in_the_wood_is_moved_onto_the_field_by_a_rigid_translation(field) -> None:
    units = _units(-300, 0)
    result = placement.place_on_clear_ground("TestTheatre", units, coalition="red")
    assert result.message and result.message.startswith("moved")
    moved = [(u["x"] + result.dx, u["y"] + result.dy) for u in units]
    # The whole footprint, margin included, stands on the field.
    for x, _y in moved:
        assert x - 20 - cgc.PLACEMENT_MARGIN_METERS >= 0 - 25
    assert math.hypot(result.dx, result.dy) <= placement.SEARCH_RADIUS_METERS


def test_a_group_already_in_the_open_stays_and_nothing_is_said(field) -> None:
    result = placement.place_on_clear_ground("TestTheatre", _units(800, 0), coalition="red")
    assert (result.dx, result.dy, result.message) == (0.0, 0.0, None)


def test_not_covered_and_nothing_large_enough_both_place_as_asked_and_say_which(field) -> None:
    uncovered = placement.place_on_clear_ground("Caucasus-nowhere", _units(0, 0), coalition="red")
    assert (uncovered.dx, uncovered.dy) == (0.0, 0.0)
    assert "no clear-ground catalogue covers" in uncovered.message and "clear-ground-sweep" in uncovered.message

    too_big = placement.place_on_clear_ground(
        "TestTheatre", [{"x": -300, "y": 0, "name": '#command="-samVLR" #spawnradius=800'}], coalition="red"
    )
    assert (too_big.dx, too_big.dy) == (0.0, 0.0)
    assert "no clear position for '-samVLR'" in too_big.message and "1000 m" in too_big.message


def test_a_marker_is_sized_by_the_group_it_spawns(field) -> None:
    lone = placement.place_on_clear_ground(
        "TestTheatre", [{"x": 900, "y": 0, "name": '#command="-sa9"'}], coalition="red"
    )
    assert lone.message is None, "a lone launcher in the open field stays"
    battery = placement.place_on_clear_ground(
        "TestTheatre", [{"x": 200, "y": 0, "name": '#command="-sa10"'}], coalition="red"
    )
    assert battery.message and "'-sa10'" in battery.message and battery.dx > 0


def test_a_group_whose_size_is_decided_at_runtime_stays_and_says_so(field) -> None:
    result = placement.place_on_clear_ground(
        "TestTheatre", [{"x": -300, "y": 0, "name": '#command="-armor"'}], coalition="red"
    )
    assert (result.dx, result.dy) == (0.0, 0.0)
    assert "only known when it spawns" in result.message


def test_translate_moves_the_group_its_units_and_its_route_together() -> None:
    group = {"x": 1, "y": 2, "units": [{"x": 1, "y": 2}, {"x": 21, "y": 2}], "route": {"points": [{"x": 1, "y": 2}]}}
    placement.translate_group(group, 100, -50)
    assert (group["x"], group["y"]) == (101, -48)
    assert [(u["x"], u["y"]) for u in group["units"]] == [(101, -48), (121, -48)]
    assert (group["route"]["points"][0]["x"], group["route"]["points"][0]["y"]) == (101, -48)


# ----------------------------------------------------------------- through the MCP action, real data


def _caucasus_miz(tmp_path: Path) -> Path:
    return create_miz(tmp_path / "m.miz", generate_blank_mission("Caucasus"))


def _blocked_point_with_room_nearby() -> tuple[float, float]:
    """A blocked cell of the shipped Caucasus catalogue with a clearing for a 3-vehicle group in reach."""
    catalogue = cgc.catalogue_for_theatre("Caucasus")
    assert catalogue is not None, "the Caucasus catalogue ships with the tools"
    for layer in catalogue.layers:
        grid = layer.grid
        for index in range(0, grid.size, 97):
            if layer.states[index] != STATE_BLOCKED:
                continue
            x, y = grid.cell_position(*divmod(index, grid.cols))
            answer = cgc.find_clear_positions(
                catalogue, x + 20, y, search_radius=placement.SEARCH_RADIUS_METERS, required_radius=20
            )
            if answer.status is cgc.ClearGroundStatus.FOUND and answer.candidates[0].distance > 100:
                return x, y
    raise AssertionError("no blocked cell with a clearing in reach")


def _group(miz: Path, name: str) -> dict:
    def values(table):
        return table.values() if isinstance(table, dict) else table

    content = read_miz(miz).mission_content
    for country in values(content["coalition"]["red"]["country"]):
        for group in values(country.get("vehicle", {}).get("group", {})):
            if group["name"] == name:
                return group
    raise AssertionError(name)


def _add(miz: Path, name: str, x: float, y: float, **kwargs) -> dict:
    return add_group(
        miz,
        coalition="red",
        country_id=0,
        country_name="Russia",
        category="vehicle",
        name=name,
        position={"x": x, "y": y},
        units=[{"type": "BTR-80", "count": 3}],
        **kwargs,
    )


def test_add_group_lands_a_group_asked_into_a_wood_on_a_catalogued_clearing(tmp_path: Path) -> None:
    miz = _caucasus_miz(tmp_path)
    x, y = _blocked_point_with_room_nearby()
    result = _add(miz, "tools-chose", x, y)
    assert any("moved" in w["warning"] for w in result["warnings"]), result["warnings"]

    group = _group(miz, "tools-chose")
    catalogue = cgc.catalogue_for_theatre("Caucasus")
    xs = [u["x"] for u in group["units"]]
    cx, cy = sum(xs) / len(xs), sum(u["y"] for u in group["units"]) / len(xs)
    answer = cgc.find_clear_positions(catalogue, cx, cy, search_radius=1, required_radius=20)
    assert answer.status is cgc.ClearGroundStatus.FOUND, "the group's centre stands on a catalogued clear cell"
    spacings = [b - a for a, b in zip(xs, xs[1:])]
    assert spacings == [20, 20], "moved as one body"
    assert group["route"]["points"][0]["x"] == group["x"], "the stationary waypoint moved with it"


def test_add_group_never_moves_a_position_the_mission_maker_gave(tmp_path: Path) -> None:
    miz = _caucasus_miz(tmp_path)
    x, y = _blocked_point_with_room_nearby()
    result = _add(miz, "maker-chose", x, y, keep_position=True)
    assert not [w for w in result["warnings"] if "moved" in w["warning"] or "placed as requested" in w["warning"]]
    group = _group(miz, "maker-chose")
    assert (group["x"], group["y"]) == (x, y)
    assert group["units"][0]["x"] == x


def test_add_group_never_moves_a_group_with_a_route(tmp_path: Path) -> None:
    miz = _caucasus_miz(tmp_path)
    x, y = _blocked_point_with_room_nearby()
    _add(miz, "convoy", x, y, route=[{"x": x, "y": y}, {"x": x + 5000, "y": y}])
    assert (_group(miz, "convoy")["x"], _group(miz, "convoy")["y"]) == (x, y)


def test_a_move_of_one_cell_diagonal_is_noise_and_not_made(field, monkeypatch) -> None:
    from veaf_libs.clear_ground_catalogue import ClearGroundAnswer, ClearGroundStatus, ClearPosition

    one_diagonal = 25 * math.sqrt(2)
    monkeypatch.setattr(
        placement,
        "find_clear_positions",
        lambda *_a, **_k: ClearGroundAnswer(
            ClearGroundStatus.FOUND, [ClearPosition(0, 0, 500, one_diagonal, "zone:test", 25)]
        ),
    )
    assert placement.place_on_clear_ground("TestTheatre", _units(800, 0), coalition="red").message is None


def test_two_groups_asked_into_the_same_wood_do_not_land_on_each_other(tmp_path: Path) -> None:
    """Review finding: each placement used to ignore the groups already in the mission."""
    miz = _caucasus_miz(tmp_path)
    x, y = _blocked_point_with_room_nearby()
    _add(miz, "first", x, y)
    _add(miz, "second", x, y)
    first, second = _group(miz, "first"), _group(miz, "second")
    nearest = min(math.hypot(a["x"] - b["x"], a["y"] - b["y"]) for a in first["units"] for b in second["units"])
    assert nearest >= 40, f"vehicles of the two groups {nearest:.0f} m apart"


def test_occupied_lists_every_ground_unit_and_sizes_markers(tmp_path: Path) -> None:
    miz = _caucasus_miz(tmp_path)
    _add(miz, "plain", 1000, 1000, keep_position=True)
    add_group(
        miz,
        coalition="red",
        country_id=0,
        country_name="Russia",
        category="vehicle",
        name="marker",
        position={"x": 5000, "y": 5000},
        units=[{"type": "Soldier M4", "name": '#command="-sa10"'}],
        keep_position=True,
    )
    taken = placement.occupied_by(read_miz(miz).mission_content)
    assert len(taken) == 4
    assert max(radius for _x, _y, radius in taken) == pytest.approx(214, abs=1)
