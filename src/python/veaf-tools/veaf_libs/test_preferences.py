"""Tests for veaf_libs.preferences."""

import json
from pathlib import Path
from unittest.mock import patch

from veaf_libs.preferences import (
    get_last_args,
    get_last_command,
    load_preferences,
    save_invocation,
    save_preferences,
)

# get_veaf_home is a module-level attribute of veaf_libs.preferences,
# so patching "veaf_libs.preferences.get_veaf_home" works directly.
_PATCH_HOME = "veaf_libs.preferences.get_veaf_home"


class TestLoadPreferences:
    def test_returns_empty_dict_when_no_file(self, tmp_path: Path) -> None:
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert load_preferences() == {}

    def test_returns_empty_dict_on_corrupt_file(self, tmp_path: Path) -> None:
        (tmp_path / "preferences.json").write_text("not json", encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert load_preferences() == {}

    def test_returns_saved_data(self, tmp_path: Path) -> None:
        data = {"last_command": "build", "last_args": {}}
        (tmp_path / "preferences.json").write_text(json.dumps(data), encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert load_preferences() == data


class TestSavePreferences:
    def test_round_trip(self, tmp_path: Path) -> None:
        prefs = {"last_command": "extract", "last_args": {"extract": {"mission_folder": "/tmp"}}}
        with patch(_PATCH_HOME, return_value=tmp_path):
            save_preferences(prefs)
            assert load_preferences() == prefs

    def test_silently_ignores_write_error(self) -> None:
        # Providing a non-existent path that cannot be created should not raise
        with patch(_PATCH_HOME, side_effect=OSError("no home")):
            save_preferences({"key": "value"})  # must not raise


class TestGetLastCommand:
    def test_returns_empty_string_when_no_prefs(self, tmp_path: Path) -> None:
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_command() == ""

    def test_returns_empty_string_on_corrupt_file(self, tmp_path: Path) -> None:
        (tmp_path / "preferences.json").write_text("not json", encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_command() == ""

    def test_returns_saved_command(self, tmp_path: Path) -> None:
        (tmp_path / "preferences.json").write_text(json.dumps({"last_command": "build"}), encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_command() == "build"


class TestGetLastArgs:
    def test_returns_empty_dict_when_no_prefs(self, tmp_path: Path) -> None:
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_args("build") == {}

    def test_returns_empty_dict_on_corrupt_file(self, tmp_path: Path) -> None:
        (tmp_path / "preferences.json").write_text("not json", encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_args("build") == {}

    def test_returns_saved_args(self, tmp_path: Path) -> None:
        data = {"last_command": "build", "last_args": {"build": {"mission_folder": "."}}}
        (tmp_path / "preferences.json").write_text(json.dumps(data), encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_args("build") == {"mission_folder": "."}

    def test_returns_empty_dict_for_unknown_command(self, tmp_path: Path) -> None:
        data = {"last_command": "build", "last_args": {"build": {}}}
        (tmp_path / "preferences.json").write_text(json.dumps(data), encoding="utf-8")
        with patch(_PATCH_HOME, return_value=tmp_path):
            assert get_last_args("inject-presets") == {}


class TestSaveInvocation:
    def test_saves_command_and_args(self, tmp_path: Path) -> None:
        with patch(_PATCH_HOME, return_value=tmp_path):
            save_invocation("build", {"mission_folder": ".", "scripts_variant": "standard"})
            assert get_last_command() == "build"
            assert get_last_args("build") == {"mission_folder": ".", "scripts_variant": "standard"}

    def test_preserves_other_commands_args(self, tmp_path: Path) -> None:
        with patch(_PATCH_HOME, return_value=tmp_path):
            save_invocation("extract", {"mission_folder": "/old"})
            save_invocation("build", {"mission_folder": "."})
            # extract args should still be there
            assert get_last_args("extract") == {"mission_folder": "/old"}
