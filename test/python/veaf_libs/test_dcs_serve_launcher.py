"""Tests for starting dcs-serve with a key of our own."""

import socket
from pathlib import Path

import pytest
import yaml
from veaf_libs import dcs_serve_launcher as launcher


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def test_nothing_listening_is_not_serving() -> None:
    assert launcher.is_serving(f"http://127.0.0.1:{_free_port()}", timeout=0.5) is False


def test_the_config_holds_a_generated_key_and_listens_on_this_computer_only(tmp_path: Path) -> None:
    path, key = launcher.ensure_config(tmp_path / "serve", "http://127.0.0.1:8123")
    config = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert config["api_key"] == key and len(key) >= 32
    assert config["http_host"] == "127.0.0.1" and config["tcp_host"] == "127.0.0.1"
    assert config["http_port"] == 8123


def test_a_key_already_written_is_kept(tmp_path: Path) -> None:
    _, first = launcher.ensure_config(tmp_path, "http://127.0.0.1:8080")
    _, second = launcher.ensure_config(tmp_path, "http://127.0.0.1:8080")
    assert first == second


def test_an_explicit_executable_must_exist(tmp_path: Path) -> None:
    exe = tmp_path / "dcs-serve.exe"
    assert launcher.find_dcs_serve(str(exe)) is None
    exe.write_bytes(b"")
    assert launcher.find_dcs_serve(str(exe)) == exe


class _FakeProcess:
    def __init__(self, *, exits: bool = False) -> None:
        self.returncode = 1 if exits else None
        self.terminated = False

    def poll(self):
        return self.returncode

    def terminate(self) -> None:
        self.terminated = True
        self.returncode = 0

    def wait(self, timeout: float) -> int:
        return 0


class _FakePid(_FakeProcess):
    pid = 4242


def test_a_started_server_is_waited_for_and_stopped_with_its_whole_tree(tmp_path: Path, monkeypatch) -> None:
    process = _FakePid()
    seen: dict = {}
    killed: list = []

    def popen(args, cwd, stdout, stderr, start_new_session):
        seen.update(args=args, cwd=cwd)
        return process

    def run(args, capture_output, check):
        killed.append(args)
        process.returncode = 0

    answers = iter([False, True])
    monkeypatch.setattr(launcher.subprocess, "Popen", popen)
    monkeypatch.setattr(launcher.subprocess, "run", run)
    monkeypatch.setattr(launcher.sys, "platform", "win32")
    monkeypatch.setattr(launcher, "is_serving", lambda _url, timeout: next(answers))
    monkeypatch.setattr(launcher.time, "sleep", lambda _s: None)
    server = launcher.DcsServe(tmp_path / "dcs-serve.exe", tmp_path)
    server.start("http://127.0.0.1:8080")
    assert seen["cwd"] == tmp_path, "run in its own folder, where its dcs-serve.yaml is"
    server.stop()
    # dcs-serve.exe is a PyInstaller one-file build: the server is a CHILD of the process started, and
    # stopping the parent alone left it running (2026-09-28). The whole tree goes.
    assert killed == [["taskkill", "/PID", "4242", "/T", "/F"]]


def test_a_server_that_exits_at_once_is_reported(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(launcher.subprocess, "Popen", lambda *a, **k: _FakeProcess(exits=True))
    monkeypatch.setattr(launcher, "is_serving", lambda _url, timeout: False)
    with pytest.raises(RuntimeError, match="stopped at once"):
        launcher.DcsServe(tmp_path / "dcs-serve.exe", tmp_path).start("http://127.0.0.1:8080")


def test_a_server_that_exits_at_once_leaves_its_log_closed(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(launcher.subprocess, "Popen", lambda *a, **k: _FakeProcess(exits=True))
    monkeypatch.setattr(launcher, "is_serving", lambda _url, timeout: False)
    server = launcher.DcsServe(tmp_path / "dcs-serve.exe", tmp_path)
    with pytest.raises(RuntimeError):
        server.start("http://127.0.0.1:8080")
    assert server._log is None
    (tmp_path / "dcs-serve.log").unlink()  # not locked
