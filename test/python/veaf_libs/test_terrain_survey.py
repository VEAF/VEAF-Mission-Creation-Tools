"""Tests for the terrain sweep, against a fake DCS answering from a synthetic relief."""

import math
from array import array
from pathlib import Path

import pytest
from veaf_libs import terrain_survey as survey
from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.clear_ground_survey import SurveyError
from veaf_libs.terrain_elevation import ElevationGrid
from veaf_libs.terrain_survey import TerrainSweepState


def relief(x: float, y: float) -> float:
    """A cone 2000 m high at the origin, 5 km wide at its base, on a plain at 100 m."""
    return 100 + max(0.0, 1900 * (1 - math.hypot(x, y) / 5000))


class FakeTerrainDcs:
    """Answers the sweep's chunks the way DCS would, from :func:`relief`."""

    def __init__(self, bounds: str = "") -> None:
        self.bounds = bounds
        self.calls = 0
        self.cells = 0
        self.fail_after: int | None = None

    def __call__(self, code: str) -> str:
        self.calls += 1
        if self.fail_after is not None and self.calls > self.fail_after:
            raise RuntimeError("cannot reach dcs-serve")
        header = next((line for line in code.splitlines() if line.startswith("-- terrain:")), None)
        if header is None:
            return ""
        kind, *args = header[len("-- terrain:") :].split()
        if kind == "bounds":
            return self.bounds
        ox, oy, spacing = float(args[0]), float(args[1]), float(args[2])
        cols, start, count = int(args[3]), int(args[4]), int(args[5])
        self.cells += count
        out = []
        for i in range(start, start + count):
            r, c = divmod(i, cols)
            out.append(str(math.floor(relief(ox + r * spacing, oy + c * spacing) + 0.5)))
        return ",".join(out)


def test_the_chunk_sends_the_mission_y_as_the_vec2_y() -> None:
    seen = []

    def exec_lua(code: str) -> str:
        seen.append(code)
        return "7"

    survey.probe_cells(exec_lua, GridSpec(10.0, 20.0, 5.0, 1, 1), 0, 1)
    assert "x = ox + r * s, y = oy + c * s" in seen[0]
    assert "-- terrain:cells 10.0 20.0 5.0 1 0 1" in seen[0]


def test_an_answer_of_the_wrong_length_or_shape_is_refused() -> None:
    grid = GridSpec(0.0, 0.0, 10.0, 1, 3)
    with pytest.raises(SurveyError, match="2 values for 3"):
        survey.probe_cells(lambda _code: "1,2", grid, 0, 3)
    with pytest.raises(SurveyError, match="unexpected height"):
        survey.probe_cells(lambda _code: "1,nil,3", grid, 0, 3)
    with pytest.raises(SurveyError, match="unexpected height"):
        survey.probe_cells(lambda _code: "", grid, 0, 3)


def test_the_bounds_come_from_dcs_when_it_gives_them() -> None:
    bounds, source = survey.map_bounds(FakeTerrainDcs("26000 943000 -418000 113000"), "Caucasus")
    assert source == "terrain"
    assert bounds == (-418000.0, 113000.0, 26000.0, 943000.0)


@pytest.mark.parametrize("answer", ["", "attempt to index nil value", "a b c d", "1 2 3"])
def test_otherwise_from_the_airfields_with_a_margin_said_so(answer: str) -> None:
    bounds, source = survey.map_bounds(FakeTerrainDcs(answer), "Caucasus")
    assert source == "airfields"
    for name, x, y in survey.airfield_positions("Caucasus"):
        assert bounds[0] < x < bounds[2] and bounds[1] < y < bounds[3], name


def test_with_neither_the_bounds_must_be_given() -> None:
    with pytest.raises(SurveyError, match="--bounds"):
        survey.map_bounds(FakeTerrainDcs(""), "NoSuchTheatre")


def test_a_sweep_reads_every_cell_in_order(tmp_path: Path) -> None:
    grid = survey.plan_grid((-6000.0, -6000.0, 6000.0, 6000.0), 500.0)
    dcs = FakeTerrainDcs()
    state = TerrainSweepState(tmp_path / "s", "T", grid)
    state.open()
    survey.sweep(state, dcs, batch_cells=100)
    assert dcs.cells == grid.size and dcs.calls == math.ceil(grid.size / 100)
    built = state.elevation()
    assert built.elevation_at(0.0, 0.0) == 2000.0
    assert built.elevation_at(-6000.0, 6000.0) == 100.0


def test_an_interrupted_sweep_resumes_at_its_first_pending_cell(tmp_path: Path) -> None:
    grid = survey.plan_grid((0.0, 0.0, 5000.0, 5000.0), 250.0)
    dcs = FakeTerrainDcs()
    dcs.fail_after = 2
    state = TerrainSweepState(tmp_path / "s", "T", grid)
    state.open()
    with pytest.raises(RuntimeError):
        survey.sweep(state, dcs, batch_cells=50)
    assert state.done == 100

    again = TerrainSweepState(tmp_path / "s", "T", grid)
    again.open()
    assert again.done == 100
    resumed = FakeTerrainDcs()
    survey.sweep(again, resumed, batch_cells=50)
    assert resumed.cells == grid.size - 100
    fresh = TerrainSweepState(tmp_path / "f", "T", grid)
    fresh.open()
    survey.sweep(fresh, FakeTerrainDcs())
    assert again.elevation().heights == fresh.elevation().heights


def test_half_a_height_left_by_a_cut_append_is_read_again(tmp_path: Path) -> None:
    grid = GridSpec(0.0, 0.0, 10.0, 1, 4)
    state = TerrainSweepState(tmp_path, "T", grid)
    state.open()
    state.append(array("h", [5, 6]))
    with (tmp_path / "heights.bin").open("ab") as f:
        f.write(b"\x07")
    state.open()
    assert state.done == 2


def test_a_sweep_of_another_plan_is_refused_unless_restarted(tmp_path: Path) -> None:
    state = TerrainSweepState(tmp_path, "T", GridSpec(0.0, 0.0, 10.0, 1, 4))
    state.open()
    state.append(array("h", [1, 2]))
    other = TerrainSweepState(tmp_path, "T", GridSpec(0.0, 0.0, 20.0, 1, 4))
    with pytest.raises(SurveyError, match="--restart"):
        other.open()
    other.open(restart=True)
    assert other.done == 0


def test_an_unfinished_sweep_builds_no_grid(tmp_path: Path) -> None:
    state = TerrainSweepState(tmp_path, "T", GridSpec(0.0, 0.0, 10.0, 1, 4))
    state.open()
    with pytest.raises(SurveyError, match="4 cells"):
        state.elevation()


def _reference(spacing: float = 50.0, half: float = 6000.0) -> ElevationGrid:
    grid = survey.plan_grid((-half, -half, half, half), spacing)
    heights = array(
        "h",
        (math.floor(relief(*grid.cell_position(r, c)) + 0.5) for r in range(grid.rows) for c in range(grid.cols)),
    )
    return ElevationGrid("T", grid, heights)


def test_the_comparison_finds_coarser_grids_worse_and_misses_the_summit() -> None:
    results = survey.compare_spacings([_reference()], candidates=(50.0, 250.0, 1000.0), maximum_cell=2000.0)
    same, mid, coarse = results
    # The reference against itself: no error at all.
    assert same.point_max == 0 and same.peak_max == 0
    assert 0 < mid.point_max < coarse.point_max
    # The summit sits on a sample of every candidate here, so a peak error comes from the cone's
    # slope between samples inside a cell, and grows with the spacing.
    assert mid.peak_max <= coarse.peak_max


def test_a_candidate_must_be_a_multiple_of_the_reference() -> None:
    with pytest.raises(ValueError, match="multiple"):
        survey.compare_spacings([_reference()], candidates=(120.0,))


def test_the_measurement_sweeps_one_patch_per_centre() -> None:
    dcs = FakeTerrainDcs()
    report = survey.measure_resolution(
        dcs, "T", [(0.0, 0.0)], half_side=2000.0, reference_spacing=100.0, candidates=(100.0, 500.0)
    )
    assert report.patches[0]["max"] == 2000.0
    assert [s.spacing for s in report.spacings] == [100.0, 500.0]
    assert report.to_dict()["spacings"][1]["point_max"] > 0
