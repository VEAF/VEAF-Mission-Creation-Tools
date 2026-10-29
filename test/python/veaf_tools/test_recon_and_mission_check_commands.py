"""`dcs recon-*` and `dcs mission-check`, driven without DCS (FEAT-DCS-RECON-AND-MISSION-CHECK).

Both talk to the mission through the VEAF bridge (REFACTOR-BRIDGE-ONLY): the tests stand a fake bridge
session in for `dcs-serve`, recording which Lua state each chunk was sent to.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
import yaml
from mission_tools.miz_tools import create_miz, list_members, read_miz
from PIL import Image
from typer.testing import CliRunner
from veaf_libs.blank_mission import generate_blank_mission
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


class FakeBridge:
    """A bridge session answering like a running shooting mission; records ``(state, code)``.

    ``mission`` is the mission scripting state the bridge runs in; any other state is one reached
    through ``net.dostring_in``.
    """

    def __init__(self, answer: Any = None) -> None:
        self.calls: list[tuple[str, str]] = []
        self.closed = False
        self.started = None  # an already running dcs-serve
        self._answer = answer or self._shooting_mission

    @staticmethod
    def _shooting_mission(_state: str, code: str) -> str:
        if code == UNITS_LUA:
            return UNITS_REPLY
        if "getAbsTime" in code:
            return "Syria\t2011-04-16\t41460"
        return "ok"

    def run(self, code: str, timeout: float = 30.0) -> str:
        self.calls.append(("mission", code))
        return self._answer("mission", code)

    def run_in(self, state: str, code: str, timeout: float = 30.0) -> str:
        self.calls.append((state, code))
        return self._answer(state, code)

    def close(self) -> None:
        self.closed = True


def _use_bridge(monkeypatch: pytest.MonkeyPatch, bridge: FakeBridge) -> FakeBridge:
    for module in ("recon_photos", "mission_check"):
        monkeypatch.setattr(f"veaf_tools.commands.{module}.open_bridge", lambda *a, **kw: bridge)
    return bridge


@pytest.fixture
def fake_bridge(monkeypatch: pytest.MonkeyPatch) -> FakeBridge:
    return _use_bridge(monkeypatch, FakeBridge())


@pytest.fixture
def bridge_lua(tmp_path: Path) -> Path:
    path = tmp_path / "dcs-bridge.lua"
    path.write_text("-- the bridge\n", encoding="utf-8")
    return path


def _carries_the_bridge(miz: Path) -> bool:
    content = read_miz(miz).mission_content or {}
    actions = " ".join(str(a) for a in (content.get("trig") or {}).get("actions", {}).values())
    return "l10n/DEFAULT/dcs-bridge.lua" in list_members(miz) and "dcs-bridge" in actions


def test_prepare_writes_the_shooting_copy_with_the_bridge(app: Any, tmp_path: Path, bridge_lua: Path) -> None:
    files = generate_blank_mission("syria")
    files["l10n/DEFAULT/veaf-config.lua"] = b"veafCombatZone.initialize()\n"
    miz = create_miz(tmp_path / "Golan.miz", files)
    result = CliRunner().invoke(app, ["recon-prepare", str(miz), "--time", "10:00", "--bridge-lua", str(bridge_lua)])
    assert result.exit_code == 0, result.output
    assert _carries_the_bridge(tmp_path / "Golan_RECON.miz")
    assert "F11" in result.output
    # one write of a fresh copy: no backup of it lying around
    assert sorted(p.name for p in tmp_path.rglob("*.miz")) == ["Golan.miz", "Golan_RECON.miz"]


def test_prepare_refuses_a_bad_time(app: Any, tmp_path: Path) -> None:
    files = generate_blank_mission("syria")
    files["l10n/DEFAULT/veaf-config.lua"] = b"--\n"
    miz = create_miz(tmp_path / "Golan.miz", files)
    result = CliRunner().invoke(app, ["recon-prepare", str(miz), "--time", "25:00"])
    assert result.exit_code == 2


def test_plan_writes_a_starter_file_from_the_live_units(app: Any, tmp_path: Path, fake_bridge: FakeBridge) -> None:
    out = tmp_path / "shots.yaml"
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(out), "--operation", "Golan"])
    assert result.exit_code == 0, result.output
    plan = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert [s["groups"] for s in plan["shots"]] == [["SA6Sasa"]]
    assert fake_bridge.calls[0] == ("mission", UNITS_LUA)
    assert fake_bridge.closed
    again = CliRunner().invoke(app, ["recon-plan", "--out", str(out)])
    assert again.exit_code == 2  # no silent overwrite


def test_plan_refuses_an_unknown_coalition(app: Any, tmp_path: Path) -> None:
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(tmp_path / "s.yaml"), "--coalition", "green"])
    assert result.exit_code == 2


def test_plan_reports_a_missing_dcs_serve(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def missing(*args: Any, **kwargs: Any) -> Any:
        from veaf_libs.dcs_bridge_session import DcsServeMissing

        raise DcsServeMissing("No dcs-serve answers, and none was found to start.")

    monkeypatch.setattr("veaf_tools.bridge.open_session", missing)
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(tmp_path / "s.yaml")])
    assert result.exit_code == 1
    assert "No dcs-serve answers" in result.output


def test_plan_reports_a_mission_that_never_connects(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    bridge = FakeBridge()
    monkeypatch.setattr("veaf_tools.bridge.open_session", lambda *a, **kw: bridge)

    def never(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("No answer from the mission's bridge after 5 s")

    monkeypatch.setattr("veaf_tools.bridge.wait_for_mission", never)
    result = CliRunner().invoke(app, ["recon-plan", "--out", str(tmp_path / "s.yaml"), "--wait", "5"])
    assert result.exit_code == 1
    assert "No answer from the mission's bridge" in result.output
    assert bridge.closed  # a dcs-serve started for nothing is stopped


def _shots(tmp_path: Path) -> Path:
    path = tmp_path / "shots.yaml"
    path.write_text(
        "operation: Golan\nshots:\n  - name: 02-sa6\n    title: SA-6\n    groups: [SA6Sasa]\n    heading: 47\n",
        encoding="utf-8",
    )
    return path


def test_shoot_moves_the_camera_from_export_and_writes_the_raw_shot(
    app: Any, tmp_path: Path, fake_bridge: FakeBridge, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "veaf_libs.dcs_window_capture.grab_dcs",
        lambda retry, **kw: (Image.new("RGB", (640, 360), (80, 80, 80)), (640, 360)),
    )
    monkeypatch.setattr("time.sleep", lambda seconds: None)
    raw = tmp_path / "raw"
    result = CliRunner().invoke(app, ["recon-shoot", "--shots", str(_shots(tmp_path)), "--raw-dir", str(raw)])
    assert result.exit_code == 0, result.output
    assert [state for state, code in fake_bridge.calls if "LoSetCameraPosition" in code] == ["export", "export"]
    assert Image.open(raw / "02-sa6.png").size == (640, 360 - INFO_BAR_PX)
    meta = json.loads((raw / "02-sa6.json").read_text(encoding="utf-8"))
    assert meta["theatre"] == "Syria" and meta["target"]["lat"] is not None


def test_shoot_refuses_a_bad_plan(app: Any, tmp_path: Path) -> None:
    bad = tmp_path / "shots.yaml"
    bad.write_text("shots: []\n", encoding="utf-8")
    result = CliRunner().invoke(app, ["recon-shoot", "--shots", str(bad)])
    assert result.exit_code == 2


def test_render_makes_the_photos_and_the_index(
    app: Any, tmp_path: Path, fake_bridge: FakeBridge, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "veaf_libs.dcs_window_capture.grab_dcs",
        lambda retry, **kw: (Image.new("RGB", (640, 360), (80, 80, 80)), (640, 360)),
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
    def answer(state: str, code: str) -> str:
        assert state == "mission"  # where the veaf* modules live
        return "menu\t0\t=VEAF\ncommand\t1\t=" if "radioMenu" in code else ""

    bridge = _use_bridge(monkeypatch, FakeBridge(answer))
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 1
    assert "empty label" in result.output and "FAIL" in result.output
    assert bridge.closed


def test_mission_check_passes_on_a_clean_mission(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    _use_bridge(monkeypatch, FakeBridge(lambda _state, code: "menu\t0\t=VEAF" if "radioMenu" in code else ""))
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 0, result.output
    assert "PASS" in result.output


def test_mission_check_reports_a_lua_error(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    from veaf_libs.dcs_bridge_capture import BridgeLuaError

    def answer(_state: str, _code: str) -> str:
        raise BridgeLuaError("the Lua raised in the mission: attempt to index global 'veafRadio'")

    _use_bridge(monkeypatch, FakeBridge(answer))
    result = CliRunner().invoke(app, ["mission-check"])
    assert result.exit_code == 1 and "veafRadio" in result.output


def test_mission_check_prepare_writes_a_test_copy_with_the_bridge(app: Any, tmp_path: Path, bridge_lua: Path) -> None:
    miz = create_miz(tmp_path / "Golan.miz", generate_blank_mission("syria"))
    before = miz.read_bytes()
    result = CliRunner().invoke(app, ["mission-check-prepare", str(miz), "--bridge-lua", str(bridge_lua)])
    assert result.exit_code == 0, result.output
    assert miz.read_bytes() == before
    assert _carries_the_bridge(tmp_path / "Golan_CHECK.miz")
    assert "mission-check" in result.output
    assert sorted(p.name for p in tmp_path.rglob("*.miz")) == ["Golan.miz", "Golan_CHECK.miz"]
