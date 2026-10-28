"""`dcs recon-*` and `dcs mission-check`, driven without DCS (FEAT-DCS-RECON-AND-MISSION-CHECK)."""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
import yaml
from mission_tools.miz_tools import create_miz
from PIL import Image
from typer.testing import CliRunner
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.dcs_fiddle_client import FiddleError
from veaf_libs.dcs_recon import INFO_BAR_PX, UNITS_LUA
from veaf_libs.i18n import language


@pytest.fixture(autouse=True)
def _english() -> Iterator[None]:
    """The assertions read the English report."""
    with language("en"):
        yield


UNITS_REPLY = (
    "unit\t1\tSA6Sasa [r] battery#2\tKub 1S91 str\t-190000.0\t9000.0\t800.0\n"
    "unit\t1\tSA6Sasa [r] battery#2\tKub 2P25 ln\t-190040.0\t9030.0\t800.0\n"
    "unit\t2\tBlue#1\tM1A2\t0.0\t0.0\t0.0"
)


@pytest.fixture
def app() -> Any:
    from veaf_tools import app as app_mod
    from veaf_tools.commands import mission_check, recon_photos  # noqa: F401  (registers the commands)

    return app_mod.app


@pytest.fixture
def fake_hook(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, str]]:
    """Answer the hook's chunks like a running shooting mission would; record ``(env, code)``."""
    calls: list[tuple[str, str]] = []

    def exec_lua(code: str, env: str, url: str, timeout: float) -> Any:
        calls.append((env, code))
        if code == UNITS_LUA:
            return UNITS_REPLY
        if "getAbsTime" in code:
            return "Syria\t2011-04-16\t41460"
        return "ok"

    for module in ("recon_photos", "mission_check"):
        monkeypatch.setattr(f"veaf_tools.commands.{module}.exec_lua", exec_lua)
        monkeypatch.setattr(f"veaf_tools.commands.{module}.resolve_fiddle_token", lambda token: None)
    return calls


def test_prepare_writes_the_shooting_copy(app: Any, tmp_path: Path) -> None:
    files = generate_blank_mission("syria")
    files["l10n/DEFAULT/veaf-config.lua"] = b"veafCombatZone.initialize()\n"
    miz = create_miz(tmp_path / "Golan.miz", files)
    result = CliRunner().invoke(app, ["recon-prepare", str(miz), "--time", "10:00"])
    assert result.exit_code == 0, result.output
    assert (tmp_path / "Golan_RECON.miz").exists()
    assert "F11" in result.output


def test_prepare_refuses_a_bad_time(app: Any, tmp_path: Path) -> None:
    files = generate_blank_mission("syria")
    files["l10n/DEFAULT/veaf-config.lua"] = b"--\n"
    miz = create_miz(tmp_path / "Golan.miz", files)
    result = CliRunner().invoke(app, ["recon-prepare", str(miz), "--time", "25:00"])
    assert result.exit_code == 2


def test_plan_writes_a_starter_file_from_the_live_units(
    app: Any, tmp_path: Path, fake_hook: list[tuple[str, str]]
) -> None:
    out = tmp_path / "shots.yaml"
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(out), "--operation", "Golan"])
    assert result.exit_code == 0, result.output
    plan = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert [s["groups"] for s in plan["shots"]] == [["SA6Sasa"]]
    assert fake_hook[0][0] == "server"
    again = CliRunner().invoke(app, ["recon-plan", "--out", str(out)])
    assert again.exit_code == 2  # no silent overwrite


def test_plan_refuses_an_unknown_coalition(app: Any, tmp_path: Path) -> None:
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(tmp_path / "s.yaml"), "--coalition", "green"])
    assert result.exit_code == 2


def test_plan_reports_an_unreachable_dcs(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def down(*args: Any, **kwargs: Any) -> Any:
        raise FiddleError("cannot reach the DCS hook")

    monkeypatch.setattr("veaf_tools.commands.recon_photos.exec_lua", down)
    monkeypatch.setattr("veaf_tools.commands.recon_photos.resolve_fiddle_token", lambda token: None)
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(tmp_path / "s.yaml")])
    assert result.exit_code == 1
    assert "cannot reach" in result.output


def _shots(tmp_path: Path) -> Path:
    path = tmp_path / "shots.yaml"
    path.write_text(
        "operation: Golan\nshots:\n  - name: 02-sa6\n    title: SA-6\n    groups: [SA6Sasa]\n    heading: 47\n",
        encoding="utf-8",
    )
    return path


def test_shoot_moves_the_camera_from_export_and_writes_the_raw_shot(
    app: Any, tmp_path: Path, fake_hook: list[tuple[str, str]], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "veaf_libs.dcs_window_capture.grab_dcs", lambda retry: (Image.new("RGB", (640, 360), (80, 80, 80)), (640, 360))
    )
    monkeypatch.setattr("time.sleep", lambda seconds: None)
    raw = tmp_path / "raw"
    result = CliRunner().invoke(app, ["recon-shoot", "--shots", str(_shots(tmp_path)), "--raw-dir", str(raw)])
    assert result.exit_code == 0, result.output
    assert [env for env, code in fake_hook if "LoSetCameraPosition" in code] == ["export", "export"]
    assert Image.open(raw / "02-sa6.png").size == (640, 360 - INFO_BAR_PX)
    meta = json.loads((raw / "02-sa6.json").read_text(encoding="utf-8"))
    assert meta["theatre"] == "Syria" and meta["target"]["lat"] is not None


def test_shoot_refuses_a_bad_plan(app: Any, tmp_path: Path) -> None:
    bad = tmp_path / "shots.yaml"
    bad.write_text("shots: []\n", encoding="utf-8")
    result = CliRunner().invoke(app, ["recon-shoot", "--shots", str(bad)])
    assert result.exit_code == 2


def test_render_makes_the_photos_and_the_index(
    app: Any, tmp_path: Path, fake_hook: list[tuple[str, str]], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "veaf_libs.dcs_window_capture.grab_dcs", lambda retry: (Image.new("RGB", (640, 360), (80, 80, 80)), (640, 360))
    )
    monkeypatch.setattr("time.sleep", lambda seconds: None)
    shots, raw, out = _shots(tmp_path), tmp_path / "raw", tmp_path / "recon"
    CliRunner().invoke(app, ["recon-shoot", "--shots", str(shots), "--raw-dir", str(raw)])
    result = CliRunner().invoke(
        app, ["recon-render", "--shots", str(shots), "--raw-dir", str(raw), "--out-dir", str(out)]
    )
    assert result.exit_code == 0, result.output
    assert (out / "02-sa6.jpg").exists()
    index = json.loads((out / "recon.json").read_text(encoding="utf-8"))
    assert index == {
        "operation": "Golan",
        "shots": [{"name": "02-sa6", "title": "SA-6", "image": "02-sa6.jpg", "metadata": "02-sa6.json"}],
    }
    meta = json.loads((out / "02-sa6.json").read_text(encoding="utf-8"))
    assert meta["image"] == "02-sa6.jpg" and meta["target"]["dms"].startswith("N")
    # the sidecar build_mission_briefing reads (FEAT-OBJECTIVE-MISSION-V2)
    assert meta["zone"] == "SA6Sasa" and meta["title"] == "SA-6" and meta["order"] == 1
    assert meta["heading"] == 47 and meta["pitch"] == -30
    assert meta["x"] == meta["camera"]["position"][0] and meta["y"] == meta["camera"]["position"][2]
    assert meta["altitude_m"] == round(meta["camera"]["position"][1])


def test_render_without_raw_shots_fails(app: Any, tmp_path: Path) -> None:
    result = CliRunner().invoke(app, ["recon-render", "--shots", str(_shots(tmp_path)), "--raw-dir", str(tmp_path)])
    assert result.exit_code == 1


def test_mission_check_prints_the_lines_and_fails_on_a_defect(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    def exec_lua(code: str, env: str, url: str, timeout: float) -> Any:
        assert env == "server"
        if "radioMenu" in code:
            return "menu\t0\t=VEAF\ncommand\t1\t="
        return ""

    monkeypatch.setattr("veaf_tools.commands.mission_check.exec_lua", exec_lua)
    monkeypatch.setattr("veaf_tools.commands.mission_check.resolve_fiddle_token", lambda token: None)
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 1
    assert "empty label" in result.output and "FAIL" in result.output


def test_mission_check_passes_on_a_clean_mission(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "veaf_tools.commands.mission_check.exec_lua",
        lambda code, env, url, timeout: "menu\t0\t=VEAF" if "radioMenu" in code else None,
    )
    monkeypatch.setattr("veaf_tools.commands.mission_check.resolve_fiddle_token", lambda token: None)
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 0, result.output
    assert "PASS" in result.output


def test_mission_check_reports_an_unreachable_dcs(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    def down(*args: Any, **kwargs: Any) -> Any:
        raise FiddleError("cannot reach the DCS hook")

    monkeypatch.setattr("veaf_tools.commands.mission_check.exec_lua", down)
    monkeypatch.setattr("veaf_tools.commands.mission_check.resolve_fiddle_token", lambda token: None)
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 1 and "cannot reach" in result.output
