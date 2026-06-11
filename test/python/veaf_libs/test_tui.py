"""Tests for veaf_libs.tui."""

import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from veaf_libs.tui import (
    _COMMAND_MAP,
    COMMANDS,
    ArgPrompt,
    CommandSpec,
    _folder_hint,
    _mission_yaml_defaults,
    _resolve_prompt_default,
    run_wizard,
)


class TestArgPrompt:
    def test_cli_flag_converts_snake_to_kebab(self) -> None:
        p = ArgPrompt(key="mission_name_or_file", label="Mission", is_option=True)
        assert p.cli_flag == "--mission-name-or-file"

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


class TestMissionYamlDefaults:
    def test_returns_empty_when_no_mission_yaml(self, tmp_path: Path) -> None:
        assert _mission_yaml_defaults(tmp_path) == {}

    def test_derives_mission_name_for_name_prompts(self, tmp_path: Path) -> None:
        (tmp_path / "mission.yaml").write_text("mission:\n  name: Operation-Thunder\n", encoding="utf-8")
        defaults = _mission_yaml_defaults(tmp_path)
        assert defaults["mission_name_or_file"] == "Operation-Thunder"
        assert defaults["input_mission_name_or_file"] == "Operation-Thunder"

    def test_empty_when_mission_block_has_no_name(self, tmp_path: Path) -> None:
        (tmp_path / "mission.yaml").write_text("mission:\n  era: MODERN\n", encoding="utf-8")
        assert _mission_yaml_defaults(tmp_path) == {}

    def test_returns_empty_on_malformed_yaml(self, tmp_path: Path) -> None:
        (tmp_path / "mission.yaml").write_text("mission: [unclosed\n", encoding="utf-8")
        assert _mission_yaml_defaults(tmp_path) == {}


class TestResolvePromptDefault:
    def _prompt(self) -> ArgPrompt:
        return ArgPrompt("mission_name_or_file", "Mission", default="mission.miz", is_option=False)

    def test_saved_preference_wins_over_yaml(self) -> None:
        prompt = self._prompt()
        result = _resolve_prompt_default(
            prompt,
            last_args={"mission_name_or_file": "saved.miz"},
            yaml_defaults={"mission_name_or_file": "FromYaml"},
        )
        assert result == "saved.miz"

    def test_yaml_used_when_no_saved_preference(self) -> None:
        prompt = self._prompt()
        result = _resolve_prompt_default(prompt, last_args={}, yaml_defaults={"mission_name_or_file": "FromYaml"})
        assert result == "FromYaml"

    def test_static_default_when_no_saved_no_yaml(self) -> None:
        prompt = self._prompt()
        result = _resolve_prompt_default(prompt, last_args={}, yaml_defaults={})
        assert result == "mission.miz"

    def test_empty_saved_preference_falls_through_to_yaml(self) -> None:
        prompt = self._prompt()
        result = _resolve_prompt_default(
            prompt,
            last_args={"mission_name_or_file": ""},
            yaml_defaults={"mission_name_or_file": "FromYaml"},
        )
        assert result == "FromYaml"


class TestFolderHint:
    def test_dot_resolves_to_cwd(self) -> None:
        hint = _folder_hint(".")
        assert str(Path.cwd().resolve()) in hint

    def test_empty_defaults_to_cwd(self) -> None:
        hint = _folder_hint("")
        assert str(Path.cwd().resolve()) in hint

    def test_relative_path_resolved_to_absolute(self) -> None:
        hint = _folder_hint("./sub/folder")
        assert str((Path.cwd() / "sub" / "folder").resolve()) in hint

    def test_hint_is_non_empty_string(self) -> None:
        assert _folder_hint(".").strip() != ""


class TestMissionFolderResolvePathFlag:
    def test_resolve_path_defaults_to_false(self) -> None:
        assert ArgPrompt("k", "label").resolve_path is False

    def test_all_mission_folder_prompts_resolve_path(self) -> None:
        folder_prompts = [p for cmd in COMMANDS for p in cmd.prompts if p.key == "mission_folder"]
        assert folder_prompts  # guard: the prompts exist
        assert all(p.resolve_path for p in folder_prompts)

    def test_non_folder_prompts_do_not_resolve_path(self) -> None:
        other_prompts = [p for cmd in COMMANDS for p in cmd.prompts if p.key != "mission_folder"]
        assert all(not p.resolve_path for p in other_prompts)


class TestRunWizard:
    def test_returns_empty_list_when_not_tty(self) -> None:
        # run_wizard() checks isatty() itself — must return [] immediately
        with patch.object(sys.stdout, "isatty", return_value=False):
            with patch("InquirerPy.inquirer.select") as mock_select:
                result = run_wizard()
                mock_select.assert_not_called()  # wizard must not even try to display
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
        assert "--scripts-variant" not in result

    def test_yaml_default_prefills_mission_name_prompt(self) -> None:
        """With no saved arg, the mission.yaml name is offered as the prompt default."""
        captured: dict[str, str] = {}

        mock_select_instance = type("S", (), {"execute": lambda self: "extract"})()

        def _fake_text(message: str, default: str, **kwargs):  # type: ignore[no-untyped-def]
            captured.setdefault("first_default", default)
            return type("T", (), {"execute": lambda self: default})()

        with patch.object(sys.stdout, "isatty", return_value=True):
            with patch("veaf_libs.preferences.get_last_command", return_value="extract"):
                with patch("veaf_libs.preferences.get_last_args", return_value={}):
                    with patch("veaf_libs.preferences.save_invocation"):
                        with patch(
                            "veaf_libs.tui._mission_yaml_defaults",
                            return_value={"mission_name_or_file": "Op-Thunder"},
                        ):
                            with patch("InquirerPy.inquirer.select", return_value=mock_select_instance):
                                with patch("InquirerPy.inquirer.text", side_effect=_fake_text):
                                    result = run_wizard()

        assert captured["first_default"] == "Op-Thunder"
        assert "Op-Thunder" in result

    def test_mission_folder_prompt_passes_long_instruction(self) -> None:
        """The mission_folder prompt must receive a resolved-path hint; others must not."""
        kwargs_by_default: dict[str, dict] = {}

        def _fake_text(message: str, default: str, **kwargs):  # type: ignore[no-untyped-def]
            kwargs_by_default[default] = kwargs
            return type("T", (), {"execute": lambda self, _d=default: _d})()

        mock_select_instance = type("S", (), {"execute": lambda self: "extract"})()

        with patch.object(sys.stdout, "isatty", return_value=True):
            with patch("veaf_libs.preferences.get_last_command", return_value="extract"):
                with patch("veaf_libs.preferences.get_last_args", return_value={}):
                    with patch("veaf_libs.preferences.save_invocation"):
                        with patch("veaf_libs.tui._mission_yaml_defaults", return_value={}):
                            with patch("InquirerPy.inquirer.select", return_value=mock_select_instance):
                                with patch("InquirerPy.inquirer.text", side_effect=_fake_text):
                                    run_wizard()

        # extract → mission_name_or_file (default "mission.miz", no hint) + mission_folder (default ".", hint)
        assert "long_instruction" not in kwargs_by_default["mission.miz"]
        assert "long_instruction" in kwargs_by_default["."]
        assert str(Path.cwd().resolve()) in kwargs_by_default["."]["long_instruction"]

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
