"""Tests for the clear-ground catalogue: the radius derived from probe answers, and the query."""

import math
import random
from pathlib import Path

import pytest
from veaf_libs import clear_ground_catalogue as cgc
from veaf_libs.clear_ground_catalogue import (
    STATE_BLOCKED,
    STATE_CLEAR,
    STATE_WATER,
    Catalogue,
    ClearGroundStatus,
    GridSpec,
    Layer,
    compute_clear_radii,
    find_clear_positions,
    load_catalogue,
    save_catalogue,
)


def _states(rows: int, cols: int, blocked: set[tuple[int, int]] = frozenset(), fill: int = STATE_CLEAR) -> bytearray:
    states = bytearray([fill]) * (rows * cols)
    for r, c in blocked:
        states[r * cols + c] = STATE_BLOCKED
    return states


def _brute_force_radii(states: bytearray, grid: GridSpec) -> bytearray:
    """The definition, computed the slow way: distance to the nearest non-clear sample, outside included."""
    obstacles = [(r, c) for r in range(-1, grid.rows + 1) for c in range(-1, grid.cols + 1)]
    obstacles = [
        (r, c)
        for r, c in obstacles
        if not (0 <= r < grid.rows and 0 <= c < grid.cols) or states[r * grid.cols + c] != STATE_CLEAR
    ]
    radii = bytearray(grid.size)
    for r in range(grid.rows):
        for c in range(grid.cols):
            if states[r * grid.cols + c] != STATE_CLEAR:
                continue
            nearest = min(math.hypot(r - orow, c - ocol) for orow, ocol in obstacles) * grid.spacing
            meters = max(0.0, nearest - grid.spacing)
            radii[r * grid.cols + c] = min(255, int(meters // cgc.RADIUS_UNIT_METERS))
    return radii


def test_the_outside_of_the_grid_counts_as_an_obstacle() -> None:
    grid = GridSpec(0, 0, 50, 5, 5)
    radii = compute_clear_radii(_states(5, 5), grid)
    # The centre is 3 cells from the padding: 150 m, less one spacing for what lies between samples.
    assert radii[2 * 5 + 2] * cgc.RADIUS_UNIT_METERS == 100
    # An edge cell is one cell from the outside, so nothing is promised around it.
    assert radii[0] == 0


def test_a_blocked_sample_shortens_its_neighbours_by_one_spacing() -> None:
    grid = GridSpec(0, 0, 50, 21, 21)
    radii = compute_clear_radii(_states(21, 21, {(10, 10)}), grid)
    assert radii[10 * 21 + 10] == 0, "a blocked cell has no clear radius"
    assert radii[10 * 21 + 11] == 0, "next to an obstacle, the obstacle may stand anywhere in between"
    assert radii[10 * 21 + 12] * cgc.RADIUS_UNIT_METERS == 50
    # Diagonals are Euclidean, not counted in steps: 3-4-5 from the obstacle is 250 m.
    assert radii[13 * 21 + 14] * cgc.RADIUS_UNIT_METERS == 200


def test_water_is_not_clear_ground() -> None:
    grid = GridSpec(0, 0, 50, 7, 7)
    states = _states(7, 7)
    states[3 * 7 + 3] = STATE_WATER
    assert compute_clear_radii(states, grid)[3 * 7 + 3] == 0


def test_the_transform_matches_the_definition_on_a_random_grid() -> None:
    rng = random.Random(1234)
    grid = GridSpec(0, 0, 50, 23, 31)
    blocked = {(rng.randrange(23), rng.randrange(31)) for _ in range(40)}
    states = _states(23, 31, blocked)
    assert compute_clear_radii(states, grid) == _brute_force_radii(states, grid)


def test_the_radius_is_capped_at_what_one_byte_holds() -> None:
    grid = GridSpec(0, 0, 200, 40, 40)
    radii = compute_clear_radii(_states(40, 40), grid)
    assert max(radii) == 255


def test_a_wrong_number_of_answers_is_refused() -> None:
    with pytest.raises(ValueError, match="expected 25"):
        compute_clear_radii(bytearray(24), GridSpec(0, 0, 50, 5, 5))


def _open_field_catalogue() -> Catalogue:
    """A 41 x 41 grid at 50 m, clear everywhere but a wood filling rows 0-19."""
    grid = GridSpec(-1000, -1000, 50, 41, 41)
    blocked = {(r, c) for r in range(20) for c in range(41)}
    layer = Layer("test", grid, _states(41, 41, blocked))
    layer.derive_radii()
    return Catalogue("TestTheatre", [layer])


def test_a_query_returns_the_nearest_position_that_fits_first() -> None:
    catalogue = _open_field_catalogue()
    answer = find_clear_positions(catalogue, 0, 0, search_radius=1000, required_radius=100)
    assert answer.status is ClearGroundStatus.FOUND
    distances = [c.distance for c in answer.candidates]
    assert distances == sorted(distances)
    for candidate in answer.candidates:
        assert candidate.clear_radius >= 100 + cgc.PLACEMENT_MARGIN_METERS
        assert candidate.distance <= 1000
    # The wood ends at row 19 (x = -50): with one spacing lost and 140 m needed, the first row that
    # serves is x = +150 or beyond.
    assert answer.candidates[0].x >= 150


def test_the_margin_keeps_out_a_cell_that_only_just_fits() -> None:
    catalogue = _open_field_catalogue()
    layer = catalogue.layers[0]
    best = max(layer.radii) * cgc.RADIUS_UNIT_METERS
    assert find_clear_positions(catalogue, 0, 0, search_radius=2000, required_radius=best - 40).candidates
    answer = find_clear_positions(catalogue, 0, 0, search_radius=2000, required_radius=best - 39)
    assert answer.status is ClearGroundStatus.NONE_LARGE_ENOUGH


def test_covered_but_nothing_large_enough_is_not_the_same_answer_as_not_covered() -> None:
    catalogue = _open_field_catalogue()
    too_big = find_clear_positions(catalogue, 0, 0, search_radius=1000, required_radius=5000)
    elsewhere = find_clear_positions(catalogue, 50_000, 0, search_radius=1000, required_radius=10)
    nothing = find_clear_positions(None, 0, 0, search_radius=1000, required_radius=10)
    assert too_big.status is ClearGroundStatus.NONE_LARGE_ENOUGH
    assert elsewhere.status is ClearGroundStatus.NOT_COVERED
    assert nothing.status is ClearGroundStatus.NOT_COVERED


def test_a_catalogue_round_trips_and_is_written_identically_twice(tmp_path: Path) -> None:
    catalogue = _open_field_catalogue()
    first, second = tmp_path / "a.json", tmp_path / "b.json"
    save_catalogue(catalogue, first)
    save_catalogue(load_catalogue(first), second)
    assert first.read_bytes() == second.read_bytes()
    loaded = load_catalogue(first)
    assert loaded.theatre == "TestTheatre"
    assert loaded.layers[0].states == catalogue.layers[0].states
    assert loaded.layers[0].radii == catalogue.layers[0].radii


def test_saving_derives_radii_that_were_not_derived(tmp_path: Path) -> None:
    grid = GridSpec(0, 0, 50, 5, 5)
    path = tmp_path / "c.json"
    save_catalogue(Catalogue("T", [Layer("l", grid, _states(5, 5))]), path)
    assert load_catalogue(path).layers[0].radius_at(2, 2) == 100


def test_an_unknown_format_is_refused(tmp_path: Path) -> None:
    path = tmp_path / "c.json"
    path.write_text('{"format": 99, "theatre": "T", "layers": []}', encoding="utf-8")
    with pytest.raises(ValueError, match="format 99"):
        load_catalogue(path)


def test_a_locally_swept_catalogue_wins_over_the_versioned_one(tmp_path: Path, monkeypatch) -> None:
    local, shipped = tmp_path / "home", tmp_path / "shipped"
    monkeypatch.setenv("VEAF_HOME", str(local))
    monkeypatch.setattr(cgc, "bundled_dir", lambda *_parts: shipped)
    assert cgc.catalogue_for_theatre("TestTheatre") is None

    save_catalogue(
        Catalogue("shipped", [Layer("l", GridSpec(0, 0, 50, 3, 3), _states(3, 3))]),
        shipped / cgc.catalogue_file_name("TestTheatre"),
    )
    assert cgc.catalogue_for_theatre("TestTheatre").theatre == "shipped"

    save_catalogue(
        Catalogue("local", [Layer("l", GridSpec(0, 0, 50, 3, 3), _states(3, 3))]),
        local / "clear-ground" / cgc.catalogue_file_name("TestTheatre"),
    )
    assert cgc.catalogue_for_theatre("TestTheatre").theatre == "local"


def test_a_clearing_in_the_next_swept_square_is_offered_to_a_point_just_outside() -> None:
    """Review finding: only layers holding the point itself used to be searched."""
    catalogue = _open_field_catalogue()  # x from -1000 to 1000
    answer = find_clear_positions(catalogue, 1100, 0, search_radius=1000, required_radius=10)
    assert answer.status is ClearGroundStatus.FOUND
    assert answer.candidates[0].spacing == 50
    far = find_clear_positions(catalogue, 5000, 0, search_radius=1000, required_radius=10)
    assert far.status is ClearGroundStatus.NOT_COVERED
