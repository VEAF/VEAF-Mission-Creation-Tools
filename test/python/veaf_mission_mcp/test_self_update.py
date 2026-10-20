"""The MCP server keeps its own veaf-tools up to date (FEAT-AI-ZERO-SETUP ticket 04)."""

from datetime import datetime, timedelta
from pathlib import Path

import pytest
from veaf_libs import platform_assets
from veaf_mission_mcp.self_update import STAMP_FILE, start_update_if_due

NOW = datetime(2026, 10, 20, 12, 0)


@pytest.fixture
def install(tmp_path: Path) -> Path:
    """A tools folder as the updater leaves it: veaf-tools and the updater side by side."""
    folder = tmp_path / "outils"
    folder.mkdir()
    (folder / platform_assets.veaf_tools_binary_name()).write_bytes(b"")
    (folder / platform_assets.updater_binary_name()).write_bytes(b"")
    return folder / platform_assets.veaf_tools_binary_name()


def _run(install: Path, home: Path, latest: str = "6.31.0", now: datetime = NOW) -> tuple[str, list]:
    launched: list = []
    outcome = start_update_if_due(
        "6.30.0",
        install,
        home,
        now=now,
        fetch_latest=lambda _current: latest,
        launch=lambda cmd, cwd: launched.append((cmd, cwd)),
    )
    return outcome, launched


def test_a_newer_release_starts_the_updater_in_the_server_folder(install: Path, tmp_path: Path) -> None:
    outcome, launched = _run(install, tmp_path)

    assert outcome == "started"
    updater = install.parent / platform_assets.updater_binary_name()
    assert launched == [([str(updater), "--tag", "published-latest"], install.parent)]


def test_the_same_release_starts_nothing(install: Path, tmp_path: Path) -> None:
    outcome, launched = _run(install, tmp_path, latest="6.30.0")

    assert (outcome, launched) == ("up_to_date", [])


def test_an_unknown_latest_version_starts_nothing(install: Path, tmp_path: Path) -> None:
    outcome, launched = _run(install, tmp_path, latest="")

    assert (outcome, launched) == ("up_to_date", [])


def test_a_check_within_four_hours_of_the_last_one_does_nothing(install: Path, tmp_path: Path) -> None:
    _run(install, tmp_path, latest="6.30.0")

    outcome, launched = _run(install, tmp_path, now=NOW + timedelta(hours=3, minutes=59))

    assert (outcome, launched) == ("throttled", [])


def test_a_check_after_four_hours_runs_again(install: Path, tmp_path: Path) -> None:
    _run(install, tmp_path, latest="6.30.0")

    outcome, _launched = _run(install, tmp_path, now=NOW + timedelta(hours=4, minutes=1))

    assert outcome == "started"


def test_an_unreadable_stamp_counts_as_no_check(install: Path, tmp_path: Path) -> None:
    (tmp_path / STAMP_FILE).write_text("garbage", encoding="utf-8")

    assert _run(install, tmp_path)[0] == "started"


def test_offline_is_silent_and_waits_for_the_next_window(install: Path, tmp_path: Path) -> None:
    def offline(_current: str) -> str:
        raise OSError("no network")

    outcome = start_update_if_due("6.30.0", install, tmp_path, now=NOW, fetch_latest=offline, launch=lambda *_a: None)

    assert outcome == "offline"
    assert _run(install, tmp_path, now=NOW + timedelta(hours=1))[0] == "throttled"


def test_no_updater_beside_the_server_starts_nothing(install: Path, tmp_path: Path) -> None:
    (install.parent / platform_assets.updater_binary_name()).unlink()

    outcome, launched = _run(install, tmp_path)

    assert (outcome, launched) == ("no_updater", [])


def test_an_unreadable_running_version_starts_nothing(install: Path, tmp_path: Path) -> None:
    launched: list = []
    outcome = start_update_if_due(
        "unknown", install, tmp_path, now=NOW, fetch_latest=lambda _c: "6.31.0", launch=lambda *a: launched.append(a)
    )

    assert (outcome, launched) == ("up_to_date", [])
