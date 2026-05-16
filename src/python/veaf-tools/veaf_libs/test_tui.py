"""Tests for veaf_libs.tui."""

import sys
from unittest.mock import patch

import pytest

from veaf_libs.tui import _COMMAND_MAP, COMMANDS, ArgPrompt, CommandSpec, run_wizard


class TestArgPrompt:
    def test_cli_flag_converts_snake_to_kebab(self) -> None:
        p = ArgPrompt(key="scripts_variant", label="Variant", is_option=True)
        assert p.cli_flag == "--scripts-variant"

    def test_cli_flag_simple_key(self) -> None:
        p = ArgPrompt(key="verbose", label="Verbose", is_option=True)
        assert p.cli_flag == "--verbose"

    def test_positional_arg_is_not_option_by_default_when_set(self) -> None:
        p = ArgPrompt(key="mission_folder", label="Folder", is_option=False)
        assert not p.is_option


class TestCommandMap:
    def test_all_commands_in_map(self) -> None:
        for cmd in COMMANDS:
            assert cmd.cli_name in _COMMAND_MAP

    def test_map_references_same_objects(self) -> None:
        for cmd in COMMANDS:
            assert _COMMAND_MAP[cmd.cli_name] is cmd

    def test_no_duplicate_cli_names(self) -> None:
        names = [cmd.cli_name for cmd in COMMANDS]
        assert len(names) == len(set(names))

    @pytest.mark.parametrize(
        "name",
        [
            "build",
            "extract",
            "convert",
            "inject-presets",
            "inject-weather",
            "inject-aircraft-groups",
            "extract-aircraft-groups",
            "inject-waypoints",
            "extract-waypoints",
            "prepare",
            "about",
        ],
    )
    def test_expected_commands_present(self, name: str) -> None:
        assert name in _COMMAND_MAP


class TestRunWizard:
    def test_returns_empty_list_when_not_tty(self) -> None:
        with patch.object(sys.stdout, "isatty", return_value=False):
            # No InquirerPy interaction should happen — must return []
            result = run_wizard()
        assert result == []

    def test_returns_empty_list_on_keyboard_interrupt(self) -> None:
        """Simulate user pressing Ctrl-C inside the wizard."""
        with patch.object(sys.stdout, "isatty", return_value=True):
            with patch("veaf_libs.preferences.get_last_command", return_value=""):
                with patch("veaf_libs.preferences.get_last_args", return_value={}):
                    with patch("InquirerPy.inquirer.select") as mock_select:
                        mock_select.return_value.execute.side_effect = KeyboardInterrupt
                        result = run_wizard()
        assert result == []

    def test_build_with_defaults_produces_correct_args(self) -> None:
        """Wizard selects 'build' with default values → correct CLI arg list."""
        answers = {
            "mission_name_or_file": "mission.miz",
            "mission_folder": ".",
            "scripts_variant": "standard",
        }

        mock_select_instance = type("S", (), {"execute": lambda self: "build"})()
        mock_text_responses = iter(answers.values())
        mock_text_instance = type("T", (), {"execute": lambda self, _iter=mock_text_responses: next(_iter)})()

        with patch.object(sys.stdout, "isatty", return_value=True):
            with patch("veaf_libs.preferences.get_last_command", return_value="build"):
                with patch("veaf_libs.preferences.get_last_args", return_value={}):
                    with patch("veaf_libs.preferences.save_invocation"):
                        with patch("InquirerPy.inquirer.select", return_value=mock_select_instance):
                            with patch("InquirerPy.inquirer.text", return_value=mock_text_instance):
                                result = run_wizard()

        assert result[0] == "build"
        assert "mission.miz" in result
        assert "." in result
        # scripts_variant is an option — should appear as --scripts-variant standard
        assert "--scripts-variant" in result
        idx = result.index("--scripts-variant")
        assert result[idx + 1] == "standard"

    def test_about_command_returns_no_extra_args(self) -> None:
        """'about' has no prompts — result is just ['about']."""
        mock_select_instance = type("S", (), {"execute": lambda self: "about"})()

        with patch.object(sys.stdout, "isatty", return_value=True):
            with patch("veaf_libs.preferences.get_last_command", return_value="about"):
                with patch("veaf_libs.preferences.get_last_args", return_value={}):
                    with patch("veaf_libs.preferences.save_invocation"):
                        with patch("InquirerPy.inquirer.select", return_value=mock_select_instance):
                            result = run_wizard()

        assert result == ["about"]
