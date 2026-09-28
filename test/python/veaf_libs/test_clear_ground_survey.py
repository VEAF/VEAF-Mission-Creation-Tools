"""Tests for the clear-ground sweep, against a fake DCS answering from a synthetic terrain."""

import math
import zipfile
from pathlib import Path

import pytest
from veaf_libs import clear_ground_survey as survey
from veaf_libs.clear_ground_catalogue import (
    STATE_PENDING,
    ClearGroundStatus,
    find_clear_positions,
    load_catalogue,
    save_catalogue,
)
from veaf_libs.clear_ground_survey import SurveyError, SweepState


class FakeDcs:
    """Answers the survey's Lua chunks from a terrain: a round wood at the origin, the sea past x=5000."""

    def __init__(self, theatre: str = "TestTheatre", groups: int = 0, wood_radius: float = 300.0) -> None:
        self.theatre = theatre
        self.groups = groups
        self.wood_radius = wood_radius
        self.calls = 0
        self.cells_probed = 0
        self.fail_after: int | None = None

    def cell(self, x: float, y: float) -> str:
        if x > 5000:
            return "W"
        return "0" if math.hypot(x, y) <= self.wood_radius else "1"

    def __call__(self, code: str) -> str:
        self.calls += 1
        if self.fail_after is not None and self.calls > self.fail_after:
            raise RuntimeError("cannot reach dcs-serve")
        header = next((line for line in code.splitlines() if line.startswith("-- survey:")), None)
        if header is None:
            if "env.mission.theatre" in code:
                return f"{self.theatre} {self.groups}"
            return ""
        kind, *args = header[len("-- survey:") :].split()
        if kind == "block":
            x, y0, spacing = float(args[0]), float(args[1]), float(args[2])
            rows, count = int(args[3]), int(args[4])
            self.cells_probed += rows * count
            return "".join(self.cell(x + r * spacing, y0 + i * spacing) for r in range(rows) for i in range(count))
        if kind == "points":
            body = code[code.index("local pts = {") + len("local pts = {") :]
            coords = [float(v) for v in body[: body.index("}")].split(",") if v.strip()]
            self.cells_probed += len(coords) // 2
            return "".join(self.cell(coords[i], coords[i + 1]) for i in range(0, len(coords), 2))
        x, y, step, max_radius = map(float, args)
        if self.cell(x, y) != "1":
            return "0 1"
        radius, probes = 0.0, 1
        while radius + step <= max_radius:
            r = radius + step
            count = math.ceil(2 * math.pi * r / step)
            for k in range(count):
                probes += 1
                a = 2 * math.pi * k / count
                if self.cell(x + r * math.cos(a), y + r * math.sin(a)) != "1":
                    return f"{int(radius)} {probes}"
            radius = r
        return f"{int(radius)} {probes}"


def test_grids_snap_to_their_spacing_so_two_sweeps_share_cells() -> None:
    a = survey.grid_around("a", 1234.0, -987.0, 500, 50)
    b = survey.grid_around("b", 1201.0, -1010.0, 500, 50)
    for layer in (a, b):
        assert layer.grid.origin_x % 50 == 0 and layer.grid.origin_y % 50 == 0
    over = survey.grid_over("c", (-130.0, 10.0, 470.0, 390.0), 200)
    assert (over.grid.origin_x, over.grid.origin_y) == (-200.0, 0.0)
    assert over.grid.contains(470.0, 390.0)


def test_the_plan_is_coarse_over_the_map_and_fine_around_zones_and_airfields() -> None:
    layers = survey.plan_sweep("Caucasus", zones=[("combatZone_A", 0.0, 0.0)], coarse=True)
    assert layers[0].name == "coarse" and layers[0].grid.spacing == survey.COARSE_SPACING_METERS
    assert layers[1].name == "zone:combatZone_A" and layers[1].grid.spacing == survey.FINE_SPACING_METERS
    assert any(layer.name.startswith("airfield:") for layer in layers)
    for name, x, y in survey.airfield_positions("Caucasus"):
        assert layers[0].grid.contains(x, y), f"{name} is outside the coarse pass"


def test_a_coarse_pass_on_an_unknown_theatre_needs_its_bounds() -> None:
    with pytest.raises(SurveyError, match="extent must be given"):
        survey.plan_sweep("NoSuchTheatre", coarse=True)
    assert survey.plan_sweep("NoSuchTheatre", bounds=(0, 0, 1000, 1000), coarse=True)[0].grid.size == 36


def test_only_an_empty_mission_on_the_planned_theatre_is_swept() -> None:
    survey.check_survey_mission(FakeDcs(), "TestTheatre")
    with pytest.raises(SurveyError, match="on Caucasus"):
        survey.check_survey_mission(FakeDcs(theatre="Caucasus"), "TestTheatre")
    with pytest.raises(SurveyError, match="holds 3 groups"):
        survey.check_survey_mission(FakeDcs(groups=3), "TestTheatre")


def test_an_answer_that_is_not_one_state_per_cell_is_refused() -> None:
    with pytest.raises(SurveyError, match="unexpected probe answer"):
        survey.probe_row_chunk(lambda _code: "11", 0, 0, 50, 3)
    with pytest.raises(SurveyError, match="unexpected probe answer"):
        survey.probe_row_chunk(lambda _code: "1x1", 0, 0, 50, 3)


def _plan() -> list[survey.PlannedLayer]:
    return [
        survey.grid_around("zone:wood", 0.0, 0.0, 1000, 50),
        survey.grid_over("coast", (4000, -500, 6000, 500), 200),
    ]


def test_a_sweep_fills_every_cell_and_the_catalogue_answers_from_it(tmp_path: Path) -> None:
    dcs = FakeDcs()
    state = SweepState(tmp_path / "sweep", "TestTheatre", _plan())
    state.open()
    progress: list[tuple[int, int]] = []
    survey.sweep(state, dcs, batch_cells=7, on_progress=lambda d, t, _name: progress.append((d, t)))
    assert state.pending() == 0
    assert progress[-1][0] == progress[-1][1]

    catalogue = state.catalogue()
    answer = find_clear_positions(catalogue, 0.0, 0.0, search_radius=1000, required_radius=50)
    assert answer.status is ClearGroundStatus.FOUND
    for candidate in answer.candidates:
        # Clear of the wood by the radius it claims, which is what the whole catalogue promises.
        assert math.hypot(candidate.x, candidate.y) - dcs.wood_radius >= candidate.clear_radius
    at_sea = find_clear_positions(catalogue, 5600.0, 0.0, search_radius=300, required_radius=10)
    assert at_sea.status is ClearGroundStatus.NONE_LARGE_ENOUGH


def test_an_interrupted_sweep_resumes_where_it_stopped(tmp_path: Path) -> None:
    dcs = FakeDcs()
    dcs.fail_after = 20
    state = SweepState(tmp_path / "sweep", "TestTheatre", _plan())
    state.open()
    with pytest.raises(RuntimeError, match="dcs-serve"):
        survey.sweep(state, dcs, batch_cells=10)
    left = state.pending()
    assert 0 < left < sum(p.grid.size for p in _plan())

    resumed = SweepState(tmp_path / "sweep", "TestTheatre", _plan())
    resumed.open()
    assert resumed.pending() == left, "the probed cells were kept on disk"
    dcs.fail_after, dcs.cells_probed = None, 0
    survey.sweep(resumed, dcs, batch_cells=10)
    assert resumed.pending() == 0
    assert dcs.cells_probed == left, "nothing probed twice"


def test_two_sweeps_of_the_same_map_write_the_same_catalogue(tmp_path: Path) -> None:
    files = []
    for run in ("a", "b"):
        state = SweepState(tmp_path / run, "TestTheatre", _plan())
        state.open()
        survey.sweep(state, FakeDcs(), batch_cells=13 if run == "a" else 101)
        path = tmp_path / f"{run}.json"
        save_catalogue(state.catalogue(), path)
        files.append(path.read_bytes())
    assert files[0] == files[1]


def test_the_progress_of_another_plan_is_not_mixed_in(tmp_path: Path) -> None:
    first = SweepState(tmp_path, "TestTheatre", _plan())
    first.open()
    survey.sweep(first, FakeDcs())
    other = SweepState(tmp_path, "TestTheatre", _plan()[:1])
    with pytest.raises(SurveyError, match="another plan"):
        other.open()
    other.open(restart=True)
    assert other.pending() == other.layers[0].grid.size


def test_an_unfinished_sweep_does_not_make_a_catalogue(tmp_path: Path) -> None:
    state = SweepState(tmp_path, "TestTheatre", _plan())
    state.open()
    assert state.states["zone:wood"][0] == STATE_PENDING
    with pytest.raises(SurveyError, match="not probed yet"):
        state.catalogue()


def test_the_survey_mission_holds_no_unit_and_carries_the_bridge(tmp_path: Path) -> None:
    bridge = tmp_path / "dcs-bridge.lua"
    bridge.write_text("-- bridge", encoding="utf-8")
    miz = survey.build_survey_mission("GermanyCW", tmp_path / "survey.miz", bridge)
    with zipfile.ZipFile(miz) as archive:
        names = archive.namelist()
        mission = archive.read("mission").decode("utf-8")
    assert "l10n/DEFAULT/dcs-bridge.lua" in names
    assert '"GermanyCW"' in mission
    assert '["units"]' not in mission, "an empty mission: any unit would be swept as scenery"


def test_combat_zones_are_read_from_a_mission(tmp_path: Path) -> None:
    from veaf_mission_mcp.add_trigger_zone import add_trigger_zone

    bridge = tmp_path / "b.lua"
    bridge.write_text("--", encoding="utf-8")
    miz = survey.build_survey_mission("Caucasus", tmp_path / "m.miz", bridge)
    add_trigger_zone(miz, name="combatZone_Test", position={"x": 100.0, "y": 200.0}, radius=500)
    add_trigger_zone(miz, name="somewhere_else", position={"x": 0.0, "y": 0.0}, radius=500)
    assert survey.combat_zones_of(miz) == [("combatZone_Test", 100.0, 200.0)]


def test_the_cost_measurement_compares_rings_with_grids() -> None:
    ticks = iter(range(10_000))
    report = survey.measure_cost(
        FakeDcs(), [(0.0, 450.0), (0.0, 2500.0)], ring_max=300, clock=lambda: float(next(ticks))
    )
    near, far = report.samples
    # 150 m from the wood: the 140 m ring is the last one that does not reach it.
    assert near.ring_radius == 140
    assert far.ring_radius == 300, "open ground: the ring method stops at its maximum"
    assert far.ring_probes > near.ring_probes
    for sample in report.samples:
        assert set(sample.grid_radius) == {survey.FINE_SPACING_METERS, survey.COARSE_SPACING_METERS}
        # Never more generous than the ground: the grid radius never exceeds the true clearance.
        true_clearance = math.hypot(sample.x, sample.y) - 300
        assert all(radius <= true_clearance for radius in sample.grid_radius.values())
    assert report.to_dict()["samples"][0]["ring_probes"] == near.ring_probes


def test_whole_rows_travel_together_because_the_call_is_what_costs(tmp_path: Path) -> None:
    layer = survey.grid_around("zone:wood", 0.0, 0.0, 1000, 50)  # 41 x 41
    state = SweepState(tmp_path, "TestTheatre", [layer])
    state.open()
    dcs = FakeDcs()
    survey.sweep(state, dcs, batch_cells=41 * 10)
    assert dcs.calls == 5, "41 rows, 10 per call"
    assert state.pending() == 0


def test_the_coarse_pass_is_only_planned_when_asked_for() -> None:
    layers = survey.plan_sweep("Caucasus")
    assert layers and all(layer.name.startswith("airfield:") for layer in layers)
    assert all(layer.grid.spacing == 25.0 for layer in layers)
