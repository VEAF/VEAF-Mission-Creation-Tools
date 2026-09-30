"""The Saved Games folder is where Windows says it is, not where it usually is."""

import sys
from pathlib import Path

import pytest
from veaf_libs import diagnostics


def test_a_moved_saved_games_folder_is_found_where_windows_keeps_it(tmp_path: Path, monkeypatch) -> None:
    moved = tmp_path / "D-drive" / "Saved Games"
    (moved / "DCS" / "Logs").mkdir(parents=True)
    (moved / "DCS" / "Logs" / "dcs.log").write_text("", encoding="utf-8")
    monkeypatch.setattr(diagnostics, "_windows_known_folder", lambda _folder_id: moved)
    assert diagnostics.saved_games_dir() == moved
    assert diagnostics.find_dcs_write_dirs() == [moved / "DCS"]


def test_without_an_answer_from_windows_the_profile_default_is_used(monkeypatch) -> None:
    monkeypatch.setattr(diagnostics, "_windows_known_folder", lambda _folder_id: None)
    assert diagnostics.saved_games_dir() == Path.home() / "Saved Games"


def test_a_home_given_by_a_test_is_never_second_guessed(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(diagnostics, "_windows_known_folder", lambda _folder_id: Path("C:/elsewhere"))
    assert diagnostics.saved_games_dir(tmp_path) == tmp_path / "Saved Games"


@pytest.mark.skipif(sys.platform != "win32", reason="asks the Windows shell")
def test_windows_answers_with_a_folder_of_the_user() -> None:
    located = diagnostics._windows_known_folder(diagnostics._SAVED_GAMES_FOLDER_ID)
    assert located is not None and located.name


def test_off_windows_nothing_is_asked(monkeypatch) -> None:
    monkeypatch.setattr(diagnostics.sys, "platform", "linux")
    assert diagnostics._windows_known_folder(diagnostics._SAVED_GAMES_FOLDER_ID) is None
