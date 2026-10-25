"""The `veaf-logs` build compiles the Go viewer with the release version in it (FEAT-GO-VEAF-LOGS-SHIP, ticket 01).

The shipped `veaf-logs.exe` is `src/go/veaf-logs/` (ADR 0023). Its report reads the version from a Go
variable the linker sets, so the version goes on the `go build` command line rather than into
`veaf_tools._version`. These tests stub the Go toolchain and assert the command the release runs.
"""

from __future__ import annotations

import logging
import subprocess
from pathlib import Path

import pytest
import typer

from veaf_build import worker as worker_module
from veaf_build.worker import BuildAndReleaseWorker

_TEST_VERSION = "0.0.0"


def _recording_worker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, returncode: int = 0
) -> tuple[BuildAndReleaseWorker, list[dict[str, object]]]:
    """Return a worker whose `go build` call is only recorded, with its directory and environment."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    calls: list[dict[str, object]] = []
    monkeypatch.setattr(worker, "_prepare_dist", lambda: calls.append({"cmd": ["wipe dist"]}))

    def _fake_run(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        calls.append({"cmd": cmd, **kwargs})
        return subprocess.CompletedProcess(cmd, returncode, "", "")

    monkeypatch.setattr(worker_module.subprocess, "run", _fake_run)
    return worker, calls


def test_veaf_logs_is_the_go_build_of_its_module(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    exe = worker.build_veaf_logs()
    (call,) = calls
    cmd = call["cmd"]
    assert isinstance(cmd, list)
    assert cmd[:2] == ["go", "build"]
    assert cmd[-1] == "./cmd/veaf-logs"
    assert call["cwd"] == str(worker.script_root / "src" / "go" / "veaf-logs")
    assert cmd[cmd.index("-o") + 1] == str(exe)
    assert exe == worker.dist_dir / "veaf-logs.exe"


def test_veaf_logs_carries_the_version_it_is_built_for(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """The window's report reads `internal/analysis.Version`: unset, it says `unknown`."""
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_logs()
    cmd = calls[0]["cmd"]
    assert isinstance(cmd, list)
    ldflags = cmd[cmd.index("-ldflags") + 1]
    assert "-X github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/analysis.Version=0.0.0" in ldflags


def test_veaf_logs_is_a_windowed_windows_executable(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """No console window behind the viewer, and the Windows build wherever the release runs it."""
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_logs()
    cmd = calls[0]["cmd"]
    assert isinstance(cmd, list)
    assert "-H windowsgui" in cmd[cmd.index("-ldflags") + 1]
    env = calls[0]["env"]
    assert isinstance(env, dict)
    assert env["GOOS"] == "windows"
    assert env["GOARCH"] == "amd64"


def test_veaf_logs_build_keeps_the_other_executables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """The release builds `veaf-tools` first: wiping `dist/` here would drop it from the release."""
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_logs()
    assert {"cmd": ["wipe dist"]} not in calls


def test_veaf_logs_build_failure_aborts_with_go_s_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """A failed release must say why without `--verbose`."""
    worker, _ = _recording_worker(tmp_path, monkeypatch, returncode=1)

    def _failing(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(cmd, 1, "", "main.go:3: undefined: ui")

    monkeypatch.setattr(worker_module.subprocess, "run", _failing)
    with pytest.raises(typer.Abort):
        worker.build_veaf_logs()
    errors = [r.getMessage() for r in caplog.records if r.levelno >= logging.ERROR]
    assert any("main.go:3: undefined: ui" in message for message in errors)


def test_veaf_logs_build_computes_a_version_when_none_is_given(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Like `build-standalone`: the repository has no `package.json` to read one from."""
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.version = None
    monkeypatch.setattr(worker, "resolve_auto_version", lambda: "9.9.9")
    worker.build_veaf_logs()
    assert worker.version == "9.9.9"
    cmd = calls[0]["cmd"]
    assert isinstance(cmd, list)
    assert "analysis.Version=9.9.9" in cmd[cmd.index("-ldflags") + 1]


def test_veaf_logs_build_without_go_aborts_cleanly(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, _ = _recording_worker(tmp_path, monkeypatch)

    def _missing(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError(cmd[0])

    monkeypatch.setattr(worker_module.subprocess, "run", _missing)
    with pytest.raises(typer.Abort):
        worker.build_veaf_logs()
