"""The `veaf-logs` build carries the release version (FIX-LOGS-EXE-STARTUP-AND-VERSION, ticket 02).

The log viewer's report reads `veaf_tools._version`, which the repository keeps as an
`"unknown"` stub that only `veaf-build` stamps. The release used to run
`pyinstaller veaf-logs.spec` after `veaf-build build` had restored the stub, so every shipped
report said `tool.version: unknown`. These tests stub PyInstaller and assert the orchestration.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
import typer

from veaf_build import worker as worker_module
from veaf_build.worker import BuildAndReleaseWorker

_TEST_VERSION = "0.0.0"


def _recording_worker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, returncode: int = 0
) -> tuple[BuildAndReleaseWorker, list[str]]:
    """Return a worker whose version stamping and PyInstaller call only record their order."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    steps: list[str] = []
    monkeypatch.setattr(worker, "_write_version_py", lambda path: steps.append("stamp"))
    monkeypatch.setattr(worker, "_restore_version_py", lambda path: steps.append("restore"))
    monkeypatch.setattr(worker, "_prepare_dist", lambda: steps.append("wipe dist"))

    def _fake_run(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        steps.append(" ".join(cmd))
        return subprocess.CompletedProcess(cmd, returncode, "", "")

    monkeypatch.setattr(worker_module.subprocess, "run", _fake_run)
    return worker, steps


def test_veaf_logs_is_built_inside_the_stamped_window(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, steps = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_logs()
    assert steps == ["stamp", "pyinstaller veaf-logs.spec --noconfirm", "restore"]


def test_veaf_logs_build_keeps_the_other_executables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """The release builds `veaf-tools` first: wiping `dist/` here would drop it from the release."""
    worker, steps = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_logs()
    assert "wipe dist" not in steps


def test_veaf_logs_build_restores_the_stub_when_pyinstaller_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker, steps = _recording_worker(tmp_path, monkeypatch, returncode=1)
    with pytest.raises(typer.Abort):
        worker.build_veaf_logs()
    assert steps[-1] == "restore"


def test_veaf_logs_build_computes_a_version_when_none_is_given(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Like `build-standalone`: the repository has no `package.json` to read one from."""
    worker, steps = _recording_worker(tmp_path, monkeypatch)
    worker.version = None
    monkeypatch.setattr(worker, "resolve_auto_version", lambda: "9.9.9")
    worker.build_veaf_logs()
    assert worker.version == "9.9.9"
    assert steps[0] == "stamp"


def test_veaf_logs_build_without_pyinstaller_aborts_cleanly(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, steps = _recording_worker(tmp_path, monkeypatch)

    def _missing(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError(cmd[0])

    monkeypatch.setattr(worker_module.subprocess, "run", _missing)
    with pytest.raises(typer.Abort):
        worker.build_veaf_logs()
    assert steps[-1] == "restore"
