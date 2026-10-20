"""A staged veaf-tools replaces the installed one only at a start, alone (FIX-OPENCODE-TEST-FINDINGS 01).

A PyInstaller onefile executable reads its Python modules from its own file, by path, the first time
each is imported. Swapping the file under a running server made its next first-time import read the
new file at the old offsets (`Error -3 while decompressing data`, reproduced 2026-10-20).
"""

import os
import subprocess
import sys
from pathlib import Path

import pytest
from veaf_libs import staged_update
from veaf_libs.staged_update import running_copies, staged_path, take_staged_update


@pytest.fixture
def exe(tmp_path: Path) -> Path:
    """An installed veaf-tools with a staged update beside it."""
    installed = tmp_path / "veaf-tools.exe"
    installed.write_bytes(b"running")
    staged_path(installed).write_bytes(b"staged")
    return installed


def _take(exe: Path, others: list[int] | None = None, code: int = 0) -> tuple[int | None, list]:
    launched: list = []

    def launch(cmd: list[str]) -> int:
        launched.append((cmd, exe.read_bytes()))
        return code

    outcome = take_staged_update(
        exe, ["mcp"], own_pids={1, 2}, list_running=lambda _exe, _own: [] if others is None else others, launch=launch
    )
    return outcome, launched


def test_alone_the_start_moves_the_staged_exe_in_and_runs_it_with_the_same_arguments(exe: Path) -> None:
    outcome, launched = _take(exe, code=3)

    assert outcome == 3
    assert launched == [([str(exe), "mcp"], b"staged")]
    assert not staged_path(exe).exists()
    assert [p.read_bytes() for p in exe.parent.glob("veaf-tools.exe.*.old")] == [b"running"]


def test_another_copy_running_leaves_everything_in_place(exe: Path) -> None:
    """The four servers of the measurement: none of them may see its file change."""
    outcome, launched = _take(exe, others=[4242])

    assert (outcome, launched) == (None, [])
    assert exe.read_bytes() == b"running"
    assert staged_path(exe).read_bytes() == b"staged"


def test_a_platform_that_cannot_list_processes_waits(exe: Path) -> None:
    launched: list = []

    outcome = take_staged_update(
        exe, ["mcp"], own_pids=set(), list_running=lambda _e, _o: None, launch=lambda cmd: launched.append(cmd) or 0
    )

    assert (outcome, launched) == (None, [])
    assert exe.read_bytes() == b"running"


def test_nothing_staged_does_nothing(exe: Path) -> None:
    staged_path(exe).unlink()

    assert _take(exe) == (None, [])


def test_a_staged_exe_that_cannot_move_in_puts_the_running_one_back(exe: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def locked(*_args: object) -> None:
        raise PermissionError(13, "held by a virus scanner")

    monkeypatch.setattr(staged_update.os, "replace", locked)

    assert _take(exe) == (None, [])
    assert exe.read_bytes() == b"running"
    assert staged_path(exe).read_bytes() == b"staged"
    assert list(exe.parent.glob("veaf-tools.exe.*.old")) == []


def test_a_new_exe_that_does_not_start_is_staged_again_and_the_old_one_carries_on(exe: Path) -> None:
    def refused(_cmd: list[str]) -> int:
        raise OSError("blocked by a virus scanner")

    outcome = take_staged_update(exe, ["mcp"], own_pids=set(), list_running=lambda _e, _o: [], launch=refused)

    assert outcome is None
    assert exe.read_bytes() == b"running"
    assert staged_path(exe).read_bytes() == b"staged"


def test_copies_set_aside_by_earlier_swaps_are_deleted_when_free(exe: Path) -> None:
    (exe.parent / "veaf-tools.exe.1.old").write_bytes(b"older")

    _take(exe)

    assert [p.read_bytes() for p in exe.parent.glob("veaf-tools.exe.*.old")] == [b"running"]


def _start_copy(dest: Path) -> subprocess.Popen:
    """Copy a standalone system program to ``dest`` and start it waiting ~30 s."""
    if sys.platform == "win32":
        source, args = Path(os.environ["SystemRoot"]) / "System32" / "ping.exe", ["-n", "30", "127.0.0.1"]
    else:
        source, args = Path("/bin/sleep"), ["30"]
    dest.write_bytes(source.read_bytes())
    dest.chmod(0o755)
    return subprocess.Popen([str(dest), *args], stdout=subprocess.DEVNULL)


@pytest.mark.skipif(sys.platform not in ("win32", "linux"), reason="process listing is Windows and Linux only")
def test_running_copies_sees_a_process_started_from_the_file_and_not_this_one(tmp_path: Path) -> None:
    """Measured on the real process table: a program started from the file is listed."""
    copy = tmp_path / "veaf-tools.exe"
    child = _start_copy(copy)
    try:
        assert running_copies(copy, {os.getpid()}) == [child.pid]
        assert running_copies(copy, {child.pid}) == []
    finally:
        child.kill()
        child.wait()


@pytest.mark.skipif(sys.platform not in ("win32", "linux"), reason="process listing is Windows and Linux only")
def test_running_copies_counts_a_copy_set_aside(tmp_path: Path) -> None:
    """A process still running from `veaf-tools.exe.<n>.old` reads by its original path too."""
    installed = tmp_path / "veaf-tools.exe"
    child = _start_copy(installed.with_name(f"{installed.name}.7.old"))
    try:
        assert running_copies(installed, set()) == [child.pid]
    finally:
        child.kill()
        child.wait()
