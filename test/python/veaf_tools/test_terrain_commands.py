"""`veaf-tools dcs terrain-sweep`, driven end to end against a fake DCS."""

import json
import sys
from pathlib import Path

import pytest
from typer.testing import CliRunner
from veaf_libs.terrain_elevation import load_grid

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "veaf_libs"))
from test_terrain_survey import FakeTerrainDcs  # noqa: E402


class _Dcs(FakeTerrainDcs):
    """The terrain fake, also answering the survey session's theatre check."""

    def __call__(self, code: str) -> str:
        if "env.mission.theatre" in code:
            self.calls += 1
            return "Caucasus 0"
        return super().__call__(code)


@pytest.fixture
def app(monkeypatch, tmp_path: Path):
    from veaf_tools import app as app_mod
    from veaf_tools.commands import clear_ground

    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    monkeypatch.setattr(clear_ground.time, "sleep", lambda _seconds: None)
    monkeypatch.setattr(clear_ground, "find_dcs_write_dirs", lambda: [tmp_path / "SavedGames" / "DCS"])
    monkeypatch.setattr(clear_ground, "is_serving", lambda _url: True)
    return app_mod.app


def _connect(monkeypatch, dcs: FakeTerrainDcs) -> None:
    from veaf_tools.commands import clear_ground

    monkeypatch.setattr(clear_ground, "exec_over_bridge", lambda _url, _key, code, timeout: dcs(code))


def _args(tmp_path: Path, *extra: str) -> list[str]:
    bridge = tmp_path / "dcs-bridge.lua"
    bridge.write_text("--", encoding="utf-8")
    return ["terrain-sweep", "Caucasus", "--bridge-lua", str(bridge), "--api-key", "k", *extra]


def test_the_sweep_covers_the_extent_dcs_gives_and_says_dcs_can_close(app, monkeypatch, tmp_path) -> None:
    dcs = _Dcs(bounds="-3000 -3000 3000 3000")
    _connect(monkeypatch, dcs)
    out = tmp_path / "Caucasus.terrain"
    result = CliRunner().invoke(app, _args(tmp_path, "--spacing", "500", "--out", str(out)))
    assert result.exit_code == 0, result.output
    grid = load_grid(out)
    assert (grid.grid.rows, grid.grid.cols) == (13, 13)
    assert grid.elevation_at(0.0, 0.0) == 2000.0
    assert "-3000,-3000,3000,3000" in result.output
    assert "DCS" in result.output.strip().splitlines()[-1]


def test_explicit_bounds_are_not_asked_to_dcs(app, monkeypatch, tmp_path) -> None:
    dcs = _Dcs(bounds="this would fail")
    _connect(monkeypatch, dcs)
    out = tmp_path / "c.json"
    result = CliRunner().invoke(
        app, _args(tmp_path, "--bounds", "1000,0,0,1000", "--spacing", "500", "--out", str(out))
    )
    assert result.exit_code == 0, result.output
    assert load_grid(out).grid.origin_x == 0.0


def test_malformed_bounds_are_refused(app, tmp_path) -> None:
    result = CliRunner().invoke(app, _args(tmp_path, "--bounds", "1,2,3"))
    assert result.exit_code == 1


def test_measure_at_writes_the_report_instead_of_a_grid(app, monkeypatch, tmp_path) -> None:
    from veaf_libs import terrain_survey

    monkeypatch.setattr(
        terrain_survey.measure_resolution,
        "__kwdefaults__",
        {
            **terrain_survey.measure_resolution.__kwdefaults__,
            "half_side": 2000.0,
        },
    )
    _connect(monkeypatch, _Dcs())
    report = tmp_path / "r.json"
    result = CliRunner().invoke(app, _args(tmp_path, "--measure-at", "0,0", "--out", str(report)))
    assert result.exit_code == 0, result.output
    spacings = [s["spacing"] for s in json.loads(report.read_text(encoding="utf-8"))["spacings"]]
    assert spacings == list(terrain_survey.CANDIDATE_SPACINGS_METERS)
    assert "1000 m" in result.output
