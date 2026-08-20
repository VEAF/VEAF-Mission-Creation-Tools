"""The bounded retry around ``os.replace`` — FIX-WRITE-MIZ-REPLACE-FLAKE ticket 01.

Every atomic write in the tooling ends the same way: write a temp file beside the target, then
``os.replace`` it onto the target. On Windows that last step fails intermittently with
``PermissionError: [WinError 5]`` when something outside the process still holds a handle on the
freshly written file — measured on 2026-08-20 at 8 failures in 300 writes, with no VEAF code
involved at all, and cleared every time by a single retry 50 ms later.

What is asserted here is the contract of the guard, not the flake: a transient failure is survived,
a permanent one still reaches the caller with its own message, and neither case leaves the temp file
behind. ``os.replace`` is monkeypatched so the tests are deterministic and run on Linux too — the
defect's randomness must not get into its own test.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from veaf_libs.atomic_replace import atomic_replace


def _pair(tmp_path: Path) -> tuple[Path, Path]:
    """Return a (source, target) pair, both existing, as an atomic write would have them."""
    source = tmp_path / "veaf_mission_probe.miz"
    source.write_bytes(b"new content")
    target = tmp_path / "mission.miz"
    target.write_bytes(b"old content")
    return source, target


class TestTransientFailure:
    """A lock that clears must not fail the write."""

    def test_a_single_failure_is_survived(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        source, target = _pair(tmp_path)
        real_replace = os.replace
        calls: list[int] = []

        def flaky(src: object, dst: object) -> None:
            calls.append(1)
            if len(calls) == 1:
                raise PermissionError(5, "Access is denied")
            real_replace(src, dst)  # type: ignore[arg-type]

        monkeypatch.setattr(os, "replace", flaky)
        atomic_replace(source, target, delay=0.0)

        assert len(calls) == 2, "the retry did not happen"
        assert target.read_bytes() == b"new content"
        assert not source.exists(), "the temp file was left behind"

    def test_the_last_attempt_still_counts(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Failing every time but the last one must succeed, not exhaust one attempt too early."""
        source, target = _pair(tmp_path)
        real_replace = os.replace
        calls: list[int] = []

        def flaky(src: object, dst: object) -> None:
            calls.append(1)
            if len(calls) < 5:
                raise PermissionError(5, "Access is denied")
            real_replace(src, dst)  # type: ignore[arg-type]

        monkeypatch.setattr(os, "replace", flaky)
        atomic_replace(source, target, attempts=5, delay=0.0)

        assert len(calls) == 5
        assert target.read_bytes() == b"new content"


class TestPermanentFailure:
    """A real permission problem must still be reported, and reported as itself."""

    def test_the_original_error_reaches_the_caller(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        source, target = _pair(tmp_path)

        def always_denied(src: object, dst: object) -> None:
            raise PermissionError(5, "Access is denied")

        monkeypatch.setattr(os, "replace", always_denied)
        with pytest.raises(PermissionError) as caught:
            atomic_replace(source, target, attempts=3, delay=0.0)

        assert caught.value.errno == 5 or caught.value.winerror == 5  # type: ignore[attr-defined]
        assert "Access is denied" in str(caught.value), "the original message was swallowed"

    def test_no_temp_file_is_left_behind(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        source, target = _pair(tmp_path)

        def always_denied(src: object, dst: object) -> None:
            raise PermissionError(5, "Access is denied")

        monkeypatch.setattr(os, "replace", always_denied)
        with pytest.raises(PermissionError):
            atomic_replace(source, target, attempts=2, delay=0.0)

        assert not source.exists(), "a failed write left its temp file in the mission folder"
        assert target.read_bytes() == b"old content", "the target was damaged by a failed write"

    def test_another_oserror_is_not_retried(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Only the transient lock is worth retrying; anything else must fail at once."""
        source, target = _pair(tmp_path)
        calls: list[int] = []

        def missing(src: object, dst: object) -> None:
            calls.append(1)
            raise FileNotFoundError(2, "No such file or directory")

        monkeypatch.setattr(os, "replace", missing)
        with pytest.raises(FileNotFoundError):
            atomic_replace(source, target, attempts=5, delay=0.0)

        assert len(calls) == 1, "a non-transient error was retried"


class TestHealthyWrite:
    """The guard must cost nothing when nothing is wrong."""

    def test_one_call_and_no_delay(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        source, target = _pair(tmp_path)
        slept: list[float] = []
        monkeypatch.setattr("veaf_libs.atomic_replace.time.sleep", lambda s: slept.append(s))

        atomic_replace(source, target)

        assert target.read_bytes() == b"new content"
        assert slept == [], "a healthy write paid for the retry"

    def test_str_paths_are_accepted(self, tmp_path: Path) -> None:
        """`write_miz` holds its temp path as a str, from `tempfile.mkstemp`."""
        source, target = _pair(tmp_path)

        atomic_replace(str(source), str(target))

        assert target.read_bytes() == b"new content"
