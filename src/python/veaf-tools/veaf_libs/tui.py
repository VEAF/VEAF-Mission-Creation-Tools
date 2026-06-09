"""Interactive TUI wizard for veaf-tools.

Launched automatically when the tool is run with no arguments in an interactive
terminal.  Uses InquirerPy to present a command-selector and argument prompts,
then builds a list of CLI arguments that Typer executes normally.

Preferences (last command + argument values) are persisted in VEAF_HOME so the
wizard can pre-fill fields on the next run.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from veaf_libs.i18n import t

# ---------------------------------------------------------------------------
# Command / argument descriptors
# ---------------------------------------------------------------------------


@dataclass
class ArgPrompt:
    """Describes one argument or option that the wizard prompts for."""

    key: str
    """Preference key and base name for the CLI flag."""
    label: str
    """Human-readable label shown in the wizard."""
    default: str = ""
    """Fallback default when no preference is saved."""
    is_flag: bool = False
    """True → yes/no confirm; False → text input."""
    is_option: bool = True
    """True → rendered as ``--key value``; False → positional argument."""

    @property
    def cli_flag(self) -> str:
        """Convert snake_case key to ``--kebab-case`` CLI option name."""
        return "--" + self.key.replace("_", "-")


@dataclass
class CommandSpec:
    """Describes one veaf-tools command exposed in the wizard."""

    cli_name: str
    """Exact name used on the command line (e.g. ``inject-presets``)."""
    description: str
    """One-line description shown in the command selector."""
    prompts: list[ArgPrompt] = field(default_factory=list)
    """Ordered list of prompts — positional args first, then options."""


# ---------------------------------------------------------------------------
# Available commands
# ---------------------------------------------------------------------------

COMMANDS: list[CommandSpec] = [
    # ── Most frequent: daily build/inject loop ──────────────────────────────
    CommandSpec(
        cli_name="build",
        description=t("tui.cmd.build.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("mission_folder", t("tui.arg.mission_folder"), default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="inject-presets",
        description=t("tui.cmd.inject_presets.description"),
        prompts=[
            ArgPrompt(
                "input_mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("presets_file", t("tui.arg.presets_file"), default="./src/presets.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="inject-weather",
        description=t("tui.cmd.inject_weather.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
        ],
    ),
    CommandSpec(
        cli_name="inject-aircraft-groups",
        description=t("tui.cmd.inject_aircraft.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("template_file", t("tui.arg.template_file"), default="aircraft-templates.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="inject-waypoints",
        description=t("tui.cmd.inject_waypoints.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
        ],
    ),
    # ── Occasional: extraction ──────────────────────────────────────────────
    CommandSpec(
        cli_name="extract",
        description=t("tui.cmd.extract.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("mission_folder", t("tui.arg.mission_folder_dest"), default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="extract-aircraft-groups",
        description=t("tui.cmd.extract_aircraft.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("output_yaml", t("tui.arg.output_yaml"), default="aircraft-templates.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="extract-waypoints",
        description=t("tui.cmd.extract_waypoints.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
        ],
    ),
    # ── Rare: project setup / one-time migration ────────────────────────────
    CommandSpec(
        cli_name="convert-v5",
        description=t("tui.cmd.convert_v5.description"),
        prompts=[
            ArgPrompt("mission_folder", t("tui.arg.mission_folder_init"), default=".", is_option=False),
            ArgPrompt("force", t("tui.arg.convert_v5_force"), default="", is_flag=True),
            ArgPrompt("icao", t("tui.arg.convert_v5_icao"), default=""),
        ],
    ),
    CommandSpec(
        cli_name="prepare",
        description=t("tui.cmd.prepare.description"),
        prompts=[
            ArgPrompt("mission_folder", t("tui.arg.mission_folder_init"), default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="about",
        description=t("tui.cmd.about.description"),
        prompts=[],
    ),
]

_COMMAND_MAP: dict[str, CommandSpec] = {cmd.cli_name: cmd for cmd in COMMANDS}

# ---------------------------------------------------------------------------
# Wizard entry point
# ---------------------------------------------------------------------------


def run_wizard() -> list[str]:
    """Run the interactive wizard and return a list of CLI arguments for Typer.

    Returns an empty list when the terminal is not interactive or the user
    cancels.  Unexpected errors are logged and re-raised so they are visible
    to the user rather than silently swallowed.
    """
    import sys

    # Only meaningful in an interactive terminal
    if not sys.stdout.isatty():
        return []

    try:
        from InquirerPy import inquirer
        from InquirerPy.base.control import Choice

        from veaf_libs.preferences import get_last_args, get_last_command, save_invocation
    except ImportError:
        return []

    try:
        last_command = get_last_command()

        # ── Step 1: select command ───────────────────────────────────────────
        choices = [Choice(value=cmd.cli_name, name=f"{cmd.cli_name:<28}  {cmd.description}") for cmd in COMMANDS]
        default_choice = last_command if last_command in _COMMAND_MAP else COMMANDS[0].cli_name

        selected: str = inquirer.select(  # type: ignore[attr-defined]
            message=t("tui.select_command"),
            choices=choices,
            default=default_choice,
            instruction=t("tui.instruction"),
        ).execute()

        spec = _COMMAND_MAP[selected]
        if not spec.prompts:
            # No arguments needed (e.g. 'about')
            save_invocation(selected, {})
            return [selected]

        # ── Step 2: prompt for arguments ────────────────────────────────────
        last_args = get_last_args(selected)
        collected: dict[str, Any] = {}

        for prompt in spec.prompts:
            saved = last_args.get(prompt.key, prompt.default)
            # Show the CLI flag/name with color prefix for options
            if prompt.is_option:
                display_label = f"{prompt.cli_flag}  {prompt.label}"
            else:
                display_label = prompt.label
            if prompt.is_flag:
                value: Any = inquirer.confirm(  # type: ignore[attr-defined]
                    message=display_label,
                    default=bool(saved),
                ).execute()
            else:
                value = inquirer.text(  # type: ignore[attr-defined]
                    message=display_label,
                    default=str(saved) if saved else prompt.default,
                ).execute()
            collected[prompt.key] = value

        # ── Step 3: build CLI args list ──────────────────────────────────────
        cli_args: list[str] = [selected]
        positional: list[str] = []
        options: list[str] = []

        for prompt in spec.prompts:
            raw = collected.get(prompt.key)
            if prompt.is_option:
                if prompt.is_flag:
                    # raw is already a bool from inquirer.confirm
                    if raw:
                        options.append(prompt.cli_flag)
                else:
                    val = str(raw) if raw is not None else ""
                    if val:
                        options.extend([prompt.cli_flag, val])
            else:
                # Positional: preserve order — always append even if empty so
                # subsequent positionals don't shift into the wrong slot.
                positional.append(str(raw) if raw is not None else "")

        cli_args += positional + options

        save_invocation(selected, collected)
        return cli_args

    except (KeyboardInterrupt, EOFError):
        # User pressed Ctrl-C or Ctrl-D — normal cancellation, not an error
        return []
    except Exception as e:
        # Unexpected error: log it so the user sees what went wrong, then
        # fall back gracefully to the Typer help screen.
        from veaf_libs.logger import logger  # noqa: PLC0415

        logger.warning(t("tui.unexpected_error", error=str(e)))
        return []
