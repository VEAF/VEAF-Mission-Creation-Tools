"""The MCP server keeps its own veaf-tools up to date (FEAT-AI-ZERO-SETUP ticket 04)."""

from datetime import datetime, timedelta
from pathlib import Path

import pytest
from veaf_libs import platform_assets
from veaf_mission_mcp.self_update import CLAIM_PREFIX, THROTTLE, start_update_if_due

#: One minute into a 4-hour window, whatever the time zone the tests run in.
WINDOW_START = datetime.fromtimestamp(
    (datetime(2026, 10, 20, 12).timestamp() // THROTTLE.total_seconds()) * THROTTLE.total_seconds()
)
NOW = WINDOW_START + timedelta(minutes=1)


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


def test_a_second_check_in_the_same_window_does_nothing(install: Path, tmp_path: Path) -> None:
    """Two servers started together — Claude Desktop and Claude Code — must not run two updaters."""
    first, _ = _run(install, tmp_path)

    second, launched = _run(install, tmp_path, now=NOW + THROTTLE - timedelta(minutes=2))

    assert first == "started"
    assert (second, launched) == ("throttled", [])


def test_the_next_window_checks_again_and_drops_the_old_claim(install: Path, tmp_path: Path) -> None:
    _run(install, tmp_path, latest="6.30.0")

    outcome, _launched = _run(install, tmp_path, now=NOW + THROTTLE)

    assert outcome == "started"
    assert len(list(tmp_path.glob(f"{CLAIM_PREFIX}*"))) == 1


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
