"""Tests for the terrain elevation grid: storage and queries."""

from array import array
from pathlib import Path

import pytest
from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.terrain_elevation import (
    PENDING_HEIGHT,
    ElevationGrid,
    RoutePoint,
    grid_for_theatre,
    line_of_sight,
    load_grid,
    maxima_per_cell,
    profile,
    route_exposure,
    save_grid,
)


def _plane(rows: int = 5, cols: int = 6, spacing: float = 100.0) -> ElevationGrid:
    """A tilted plane: height = x/10 + y/20, exact under bilinear interpolation."""
    grid = GridSpec(1000.0, -500.0, spacing, rows, cols)
    heights = array("h")
    for r in range(rows):
        for c in range(cols):
            x, y = grid.cell_position(r, c)
            heights.append(round(x / 10 + y / 20))
    return ElevationGrid("TestTheatre", grid, heights)


def test_a_sample_reads_back_exactly() -> None:
    plane = _plane()
    assert plane.elevation_at(1000.0, -500.0) == 75.0
    assert plane.elevation_at(1400.0, 0.0) == 140.0


def test_between_samples_the_height_is_interpolated() -> None:
    plane = _plane()
    # Halfway between four samples of a plane: the plane itself.
    assert plane.elevation_at(1050.0, -450.0) == pytest.approx(1050 / 10 - 450 / 20, abs=0.5)


def test_a_point_off_the_grid_is_not_covered_never_zero() -> None:
    plane = _plane()
    assert plane.elevation_at(999.0, 0.0) is None
    assert plane.elevation_at(1000.0, 1000.0) is None


def test_the_file_round_trips_and_is_reproducible(tmp_path: Path) -> None:
    plane = _plane(rows=40, cols=50)
    a, b = tmp_path / "a.terrain", tmp_path / "b.terrain"
    save_grid(plane, a)
    save_grid(_plane(rows=40, cols=50), b)
    assert a.read_bytes() == b.read_bytes()
    loaded = load_grid(a)
    assert loaded.theatre == "TestTheatre" and loaded.grid == plane.grid
    assert loaded.heights == plane.heights


def test_negative_heights_survive_the_round_trip(tmp_path: Path) -> None:
    grid = GridSpec(0.0, 0.0, 10.0, 2, 3)
    heights = array("h", [-28, 0, 5642, -400, 3, 3])
    save_grid(ElevationGrid("T", grid, heights), tmp_path / "t.json")
    assert load_grid(tmp_path / "t.json").heights == heights


def test_an_unfinished_grid_is_never_written(tmp_path: Path) -> None:
    grid = GridSpec(0.0, 0.0, 10.0, 1, 2)
    with pytest.raises(ValueError, match="not swept"):
        save_grid(ElevationGrid("T", grid, array("h", [1, PENDING_HEIGHT])), tmp_path / "t.json")


def test_a_file_holding_the_wrong_count_is_refused(tmp_path: Path) -> None:
    path = tmp_path / "t.terrain"
    save_grid(_plane(), path)
    path.write_bytes(path.read_bytes().replace(b'"rows": 5', b'"rows": 6'))
    with pytest.raises(ValueError, match="one height per cell"):
        load_grid(path)


def test_a_damaged_or_foreign_file_is_refused(tmp_path: Path) -> None:
    path = tmp_path / "t.terrain"
    save_grid(_plane(rows=40, cols=50), path)
    data = path.read_bytes()
    path.write_bytes(data[:-20])
    with pytest.raises(ValueError, match="damaged"):
        load_grid(path)
    path.write_bytes(b"{}")
    with pytest.raises(ValueError, match="not a terrain grid"):
        load_grid(path)
    path.write_bytes(data.replace(b"VEAFTERR\x01\x00", b"VEAFTERR\x02\x00", 1))
    with pytest.raises(ValueError, match="format 2"):
        load_grid(path)


def test_the_grid_is_the_one_swept_on_this_workstation(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    assert grid_for_theatre("TestTheatre") is None
    save_grid(_plane(), tmp_path / "home" / "terrain" / "TestTheatre.terrain")
    found = grid_for_theatre("TestTheatre")
    assert found is not None and found.grid.rows == 5


# --- queries (ticket 02) -------------------------------------------------------------------------


def _ridge(spacing: float = 100.0) -> ElevationGrid:
    """Flat ground at 100 m, crossed by a ridge 1000 m high along x = -275000, near Kutaisi."""
    grid = GridSpec(-280000.0, 680000.0, spacing, 101, 101)
    heights = array("h")
    for r in range(grid.rows):
        for c in range(grid.cols):
            x, _y = grid.cell_position(r, c)
            heights.append(1000 if abs(x - (-275000.0)) <= 100 else 100)
    return ElevationGrid("Caucasus", grid, heights)


def test_a_profile_follows_every_leg_and_gives_its_maximum() -> None:
    ridge = _ridge()
    route = [(-279000.0, 685000.0), (-271000.0, 685000.0), (-271000.0, 689000.0)]
    legs = profile(ridge, route)
    assert [round(leg.length) for leg in legs] == [8000, 4000]
    assert legs[0].highest == 1000 and legs[0].covered
    assert legs[1].highest == 100
    # Sampled every half spacing, ends included.
    assert len(legs[0].samples) == 8000 // 50 + 1


def test_a_profile_leaving_the_grid_says_so() -> None:
    legs = profile(_ridge(), [(-279000.0, 685000.0), (-250000.0, 685000.0)])
    assert not legs[0].covered
    assert any(s.height is None for s in legs[0].samples)


def test_the_ridge_masks_a_low_target_and_not_a_high_one() -> None:
    ridge = _ridge()
    observer, target = (-279000.0, 685000.0), (-271000.0, 685000.0)
    low = line_of_sight(ridge, observer, 10.0, target, 150.0)
    assert not low.visible
    assert low.mask is not None and abs(low.mask.x - (-275000.0)) <= 100
    assert low.mask.clearance < 0
    high = line_of_sight(ridge, observer, 10.0, target, 3000.0)
    assert high.visible and high.mask is not None and high.mask.clearance > 0


def test_over_flat_ground_the_earth_hides_a_low_target_beyond_the_radar_horizon() -> None:
    grid = GridSpec(0.0, 0.0, 1000.0, 2, 201)
    flat = ElevationGrid("T", grid, array("h", [0] * grid.size))
    # 4/3 Earth: from 10 m, a target at 10 m is seen up to about 26 km, and not at 60 km.
    assert line_of_sight(flat, (0.0, 0.0), 10.0, (0.0, 20000.0), 10.0).visible
    assert not line_of_sight(flat, (0.0, 0.0), 10.0, (0.0, 60000.0), 10.0).visible


def test_a_target_off_the_grid_is_not_covered() -> None:
    sight = line_of_sight(_ridge(), (-279000.0, 685000.0), 10.0, (-250000.0, 685000.0), 150.0)
    assert not sight.covered


def test_the_maximum_per_mgrs_square_names_the_square_and_the_highest_sample() -> None:
    ridge = _ridge()
    cells = maxima_per_cell(ridge, (-280000.0, 680000.0, -270000.0, 690000.0), "mgrs10km")
    assert cells, "the patch lies in at least one square"
    assert all(c.cell.startswith("38T ") for c in cells)
    top = max(cells, key=lambda c: c.highest)
    assert top.highest == 1000 and abs(top.x - (-275000.0)) <= 100
    assert sum(c.samples for c in cells) == ridge.grid.size


def test_the_maximum_per_quadrangle_names_its_south_west_corner() -> None:
    cells = maxima_per_cell(_ridge(), (-280000.0, 680000.0, -270000.0, 690000.0), "quadrangle30")
    assert all(c.cell[0] == "N" and "E0" in c.cell for c in cells)


def test_an_unknown_cell_kind_is_refused() -> None:
    with pytest.raises(ValueError, match="mgrs10km"):
        maxima_per_cell(_ridge(), (0.0, 0.0, 1.0, 1.0), "hexagon")


def test_a_route_behind_the_ridge_is_hidden_at_low_level_and_seen_high() -> None:
    ridge = _ridge()
    sam = (-279000.0, 685000.0)
    low = [RoutePoint(-271000.0, 681000.0, 50.0, True), RoutePoint(-271000.0, 689000.0, 50.0, True)]
    high = [RoutePoint(-271000.0, 681000.0, 3000.0, False), RoutePoint(-271000.0, 689000.0, 3000.0, False)]
    hidden = route_exposure(ridge, sam, 10.0, low, max_range=20000.0)[0]
    seen = route_exposure(ridge, sam, 10.0, high, max_range=20000.0)[0]
    assert hidden.seen_length == 0 and hidden.in_range_length == pytest.approx(8000)
    assert seen.seen_length == pytest.approx(8000) and seen.covered


def test_out_of_range_is_not_counted_as_seen() -> None:
    ridge = _ridge()
    sam = (-279000.0, 680000.0)
    route = [RoutePoint(-279000.0, 682000.0, 3000.0, False), RoutePoint(-279000.0, 690000.0, 3000.0, False)]
    leg = route_exposure(ridge, sam, 10.0, route, max_range=5000.0)[0]
    assert leg.in_range_length == pytest.approx(3000, abs=1000)
    assert leg.seen_length == leg.in_range_length


def _plateau() -> ElevationGrid:
    """Flat ground at 1500 m."""
    grid = GridSpec(0.0, 0.0, 250.0, 81, 81)
    return ElevationGrid("T", grid, array("h", [1500] * grid.size))


def _altitudes_seen(start: RoutePoint, end: RoutePoint) -> list[float]:
    """The altitudes route_exposure checks the aircraft at, read from the line_of_sight calls."""
    import veaf_libs.terrain_elevation as module

    seen: list[float] = []
    real = module.line_of_sight

    def spy(elevation, observer, height, target, altitude):  # noqa: ANN001, ANN202
        seen.append(altitude)
        return real(elevation, observer, height, target, altitude)

    module.line_of_sight = spy
    try:
        route_exposure(_plateau(), (0.0, 0.0), 5.0, [start, end], max_range=1e6, step=1000.0)
    finally:
        module.line_of_sight = real
    return seen


def test_a_leg_from_baro_to_radio_goes_straight_between_both_altitudes_above_sea() -> None:
    alts = _altitudes_seen(RoutePoint(0.0, 0.0, 3000.0, False), RoutePoint(0.0, 10000.0, 100.0, True))
    # From 3000 m above sea to 1500 + 100 m: never above the start, never under the end.
    assert 1600 < min(alts) and max(alts) < 3000


def test_a_leg_from_radio_to_baro_never_goes_under_the_ground() -> None:
    alts = _altitudes_seen(RoutePoint(0.0, 0.0, 100.0, True), RoutePoint(0.0, 10000.0, 3000.0, False))
    assert 1600 < min(alts) and max(alts) < 3000


def test_a_leg_between_two_radio_points_follows_the_ground() -> None:
    alts = _altitudes_seen(RoutePoint(0.0, 0.0, 100.0, True), RoutePoint(0.0, 10000.0, 100.0, True))
    assert alts and all(a == 1600 for a in alts)


def test_an_alias_of_the_theatre_finds_the_grid(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    save_grid(_plane(), tmp_path / "home" / "terrain" / "Caucasus.terrain")
    assert grid_for_theatre("caucasus") is not None
