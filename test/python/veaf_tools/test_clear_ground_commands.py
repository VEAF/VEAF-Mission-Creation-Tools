"""`veaf-tools clear-ground-sweep`, driven end to end against a fake DCS."""

import sys
import zipfile
from pathlib import Path

import pytest
from typer.testing import CliRunner
from veaf_libs.clear_ground_catalogue import load_catalogue

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "veaf_libs"))
from test_clear_ground_survey import FakeDcs  # noqa: E402


@pytest.fixture
def app(monkeypatch, tmp_path: Path):
    from veaf_tools import app as app_mod
    from veaf_tools.commands import clear_ground

    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    monkeypatch.setattr(clear_ground.time, "sleep", lambda _seconds: None)
    # Never the real Saved Games folder, whatever a test forgets to pass.
    monkeypatch.setattr(clear_ground, "find_dcs_write_dirs", lambda: [tmp_path / "SavedGames" / "DCS"])
    # A server answers unless a test says otherwise — never whatever runs on this machine.
    monkeypatch.setattr(clear_ground, "is_serving", lambda _url: True)
    return app_mod.app


def _args(tmp_path: Path, *extra: str) -> list[str]:
    bridge = tmp_path / "dcs-bridge.lua"
    bridge.write_text("--", encoding="utf-8")
    return ["clear-ground-sweep", "Caucasus", "--bridge-lua", str(bridge), "--api-key", "k", *extra]


def _connect(monkeypatch, dcs: FakeDcs, *, answers_after: int = 0) -> None:
    from veaf_tools.commands import clear_ground

    calls = {"n": 0}

    def exec_over_bridge(_url, _key, code, timeout):
        calls["n"] += 1
        if calls["n"] <= answers_after:
            raise RuntimeError("dcs-serve returned HTTP 503 (Service Unavailable)")
        return dcs(code)

    monkeypatch.setattr(clear_ground, "exec_over_bridge", exec_over_bridge)


def test_the_sweep_writes_the_mission_waits_sweeps_and_says_dcs_can_close(app, monkeypatch, tmp_path) -> None:
    dcs = FakeDcs(theatre="Caucasus")
    _connect(monkeypatch, dcs, answers_after=3)
    out = tmp_path / "Caucasus.json"
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "0,0", "--out", str(out)))
    assert result.exit_code == 0, result.output

    # Written where the Mission Editor opens, and empty.
    survey = tmp_path / "SavedGames" / "DCS" / "Missions" / "veaf-survey-Caucasus.miz"
    with zipfile.ZipFile(survey) as archive:
        assert '["units"]' not in archive.read("mission").decode("utf-8")
    assert "dcs-serve" in result.output and "veaf-survey-Caucasus.miz" in result.output
    assert [layer.name for layer in load_catalogue(out).layers] == ["zone:0,0"]
    assert "DCS" in result.output.strip().splitlines()[-1], "the last line tells the user DCS can be closed"


def test_the_survey_mission_can_be_written_elsewhere(app, monkeypatch, tmp_path) -> None:
    _connect(monkeypatch, FakeDcs(theatre="Caucasus"))
    target = tmp_path / "elsewhere" / "survey.miz"
    args = _args(
        tmp_path,
        "--no-airfields",
        "--around",
        "0,0",
        "--survey-mission",
        str(target),
        "--out",
        str(tmp_path / "c.json"),
    )
    assert CliRunner().invoke(app, args).exit_code == 0
    assert target.is_file()


def test_a_second_run_finds_nothing_left_to_probe(app, monkeypatch, tmp_path) -> None:
    dcs = FakeDcs(theatre="Caucasus")
    _connect(monkeypatch, dcs)
    args = _args(tmp_path, "--no-airfields", "--around", "0,0", "--out", str(tmp_path / "c.json"))
    assert CliRunner().invoke(app, args).exit_code == 0
    dcs.cells_probed = 0
    assert CliRunner().invoke(app, args).exit_code == 0
    assert dcs.cells_probed == 0


def test_a_mission_holding_units_is_refused_at_once_not_waited_for(app, monkeypatch, tmp_path) -> None:
    dcs = FakeDcs(theatre="Caucasus", groups=4)
    _connect(monkeypatch, dcs)
    result = CliRunner().invoke(app, _args(tmp_path))
    assert result.exit_code == 1
    assert "4 groups" in result.output
    assert dcs.calls == 1


def test_it_gives_up_when_nothing_answers(app, monkeypatch, tmp_path) -> None:
    _connect(monkeypatch, FakeDcs(theatre="Caucasus"), answers_after=10**9)
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "0,0", "--wait", "0"))
    assert result.exit_code == 1
    assert "503" in result.output


def test_a_malformed_point_is_refused(app, tmp_path) -> None:
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "nowhere"))
    assert result.exit_code == 1


class _FakeServer:
    instances: list["_FakeServer"] = []

    def __init__(self, exe, workdir) -> None:
        self.exe, self.workdir, self.running = exe, workdir, False
        _FakeServer.instances.append(self)

    def start(self, _url) -> None:
        self.running = True

    def stop(self) -> None:
        self.running = False


def test_with_no_server_it_starts_one_with_its_own_key_and_stops_it(app, monkeypatch, tmp_path) -> None:
    from veaf_tools.commands import clear_ground

    exe = tmp_path / "dcs-serve.exe"
    exe.write_bytes(b"")
    monkeypatch.setattr(clear_ground, "is_serving", lambda _url: False)
    monkeypatch.setattr(clear_ground, "DcsServe", _FakeServer)
    keys = []
    dcs = FakeDcs(theatre="Caucasus")

    def exec_over_bridge(_url, key, code, timeout):
        keys.append(key)
        return dcs(code)

    monkeypatch.setattr(clear_ground, "exec_over_bridge", exec_over_bridge)
    _FakeServer.instances.clear()
    args = [
        a
        for a in _args(tmp_path, "--no-airfields", "--around", "0,0", "--dcs-serve", str(exe))
        if a not in ("--api-key", "k")
    ]
    result = CliRunner().invoke(app, args)
    assert result.exit_code == 0, result.output
    (server,) = _FakeServer.instances
    assert not server.running, "stopped at the end"
    written = (server.workdir / "dcs-serve.yaml").read_text(encoding="utf-8")
    assert keys and set(keys) == {keys[0]} and keys[0] in written
    assert "dcs-serve.yaml" in result.output


def test_with_no_server_and_none_to_start_it_says_where_to_get_one(app, monkeypatch, tmp_path) -> None:
    from veaf_tools.commands import clear_ground

    monkeypatch.setattr(clear_ground, "is_serving", lambda _url: False)
    monkeypatch.setattr(clear_ground, "find_dcs_serve", lambda _explicit: None)
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "0,0"))
    assert result.exit_code == 1
    assert "veaf-map-capture-kit" in result.output


def test_the_check_command_reports_how_it_counted_and_says_dcs_can_close(app, monkeypatch, tmp_path) -> None:
    from test_clear_ground_check import CatalogueDcs, _mission

    miz, _wood = _mission(tmp_path)
    _connect(monkeypatch, CatalogueDcs())
    report = tmp_path / "report.json"
    bridge = tmp_path / "dcs-bridge.lua"
    bridge.write_text("--", encoding="utf-8")
    result = CliRunner().invoke(
        app, ["clear-ground-check", str(miz), "--bridge-lua", str(bridge), "--api-key", "k", "--report", str(report)]
    )
    assert result.exit_code == 0, result.output
    assert "kept-in-the-wood" in result.output
    assert "neighbours" in result.output or "voisins" in result.output
    assert "DCS" in result.output.strip().splitlines()[-1]
    assert '"units_not_clear": 2' in report.read_text(encoding="utf-8")


def test_a_refused_key_stops_at_once_instead_of_waiting(app, monkeypatch, tmp_path) -> None:
    from veaf_libs.dcs_bridge_capture import BridgeAuthError
    from veaf_tools.commands import clear_ground

    calls = {"n": 0}

    def refused(_url, _key, _code, timeout):
        calls["n"] += 1
        raise BridgeAuthError("dcs-serve refused the request (HTTP 401)")

    monkeypatch.setattr(clear_ground, "exec_over_bridge", refused)
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "0,0"))
    assert result.exit_code == 1
    assert calls["n"] == 1, "a refused key is not retried"
    assert "401" in result.output


def test_a_server_already_running_is_asked_with_our_own_key_first(app, monkeypatch, tmp_path) -> None:
    """The case of 2026-09-28: our server was still up, and a stray dcs-serve.yaml in the current folder
    held another key — the command took that one, and waited on 401s."""
    from veaf_libs.dcs_serve_launcher import ensure_config
    from veaf_tools.commands import clear_ground

    _path, ours = ensure_config(tmp_path / "home" / "clear-ground" / "dcs-serve", "http://127.0.0.1:8080")
    stray = tmp_path / "cwd"
    stray.mkdir()
    (stray / "dcs-serve.yaml").write_text("api_key: somebody-else\n", encoding="utf-8")
    monkeypatch.chdir(stray)
    keys = []
    dcs = FakeDcs(theatre="Caucasus")

    def exec_over_bridge(_url, key, code, timeout):
        keys.append(key)
        return dcs(code)

    monkeypatch.setattr(clear_ground, "exec_over_bridge", exec_over_bridge)
    args = [a for a in _args(tmp_path, "--no-airfields", "--around", "0,0") if a not in ("--api-key", "k")]
    result = CliRunner().invoke(app, args)
    assert result.exit_code == 0, result.output
    assert set(keys) == {ours}


def test_the_theatre_may_be_typed_in_any_case(app, monkeypatch, tmp_path) -> None:
    """Review finding: `caucasus` swept nothing and was refused by the running `Caucasus` mission."""
    _connect(monkeypatch, FakeDcs(theatre="Caucasus"))
    args = _args(tmp_path, "--no-airfields", "--around", "0,0")
    args[1] = "caucasus"
    result = CliRunner().invoke(app, args)
    assert result.exit_code == 0, result.output
    assert (tmp_path / "home" / "clear-ground" / "Caucasus.clear-ground.json").is_file()


def test_something_else_on_the_port_stops_at_once(app, monkeypatch, tmp_path) -> None:
    from veaf_libs.dcs_bridge_capture import BridgeHttpError
    from veaf_tools.commands import clear_ground

    calls = {"n": 0}

    def not_found(_url, _key, _code, timeout):
        calls["n"] += 1
        raise BridgeHttpError(404, "dcs-serve returned HTTP 404 (Not Found)")

    monkeypatch.setattr(clear_ground, "exec_over_bridge", not_found)
    result = CliRunner().invoke(app, _args(tmp_path, "--no-airfields", "--around", "0,0"))
    assert result.exit_code == 1
    assert calls["n"] == 1
    assert "404" in result.output
