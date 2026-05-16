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
    CommandSpec(
        cli_name="build",
        description="Build a DCS mission .miz from a VEAF mission folder",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
            ArgPrompt("mission_folder", "Mission folder", default=".", is_option=False),
            ArgPrompt(
                "scripts_variant",
                "Scripts variant (standard / debug / trace / trace-with-events)",
                default="standard",
            ),
        ],
    ),
    CommandSpec(
        cli_name="extract",
        description="Extract a .miz file into a VEAF mission folder",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
            ArgPrompt("mission_folder", "Mission folder (destination)", default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="convert",
        description="Convert an existing DCS mission into a new VEAF mission folder",
        prompts=[
            ArgPrompt("mission_name", "Mission name (no extension)", default="mission", is_option=False),
            ArgPrompt("mission_folder", "Mission folder", default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="inject-presets",
        description="Inject radio presets from a YAML config into a .miz file",
        prompts=[
            ArgPrompt(
                "input_mission_name_or_file", "Input mission name or .miz file", default="mission.miz", is_option=False
            ),
            ArgPrompt("presets_file", "Presets YAML file", default="./src/presets.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="inject-weather",
        description="Inject weather and time-of-day variants into a .miz file",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="inject-aircraft-groups",
        description="Inject aircraft groups from a YAML template into a .miz file",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
            ArgPrompt("template_file", "Aircraft groups YAML file", default="aircraft-templates.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="extract-aircraft-groups",
        description="Extract aircraft groups from a .miz file into a YAML template",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
            ArgPrompt("output_yaml", "Output YAML file", default="aircraft-templates.yaml"),
        ],
    ),
    CommandSpec(
        cli_name="inject-waypoints",
        description="Inject waypoints from a YAML file into a .miz file",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="extract-waypoints",
        description="Extract waypoints from a .miz file into a YAML file",
        prompts=[
            ArgPrompt("mission_name_or_file", "Mission name or .miz file", default="mission.miz", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="prepare",
        description="Initialise a new VEAF mission folder with default files",
        prompts=[
            ArgPrompt("mission_folder", "Mission folder to initialise", default=".", is_option=False),
        ],
    ),
    CommandSpec(
        cli_name="about",
        description="Show information about veaf-tools",
        prompts=[],
    ),
]

_COMMAND_MAP: dict[str, CommandSpec] = {cmd.cli_name: cmd for cmd in COMMANDS}

# ---------------------------------------------------------------------------
# Wizard entry point
# ---------------------------------------------------------------------------


def run_wizard() -> list[str]:
    """Run the interactive wizard and return a list of CLI arguments for Typer.

    Returns an empty list if the user cancels or an error occurs, which will
    cause Typer to print the help screen.
    """
    try:
        from InquirerPy import inquirer
        from InquirerPy.base.control import Choice

        from veaf_libs.preferences import get_last_args, get_last_command, save_invocation
    except ImportError:
        return []

    try:
        last_command = get_last_command()

        # ── Step 1: select command ───────────────────────────────────────────
        choices = [Choice(value=cmd.cli_name, name=f"{cmd.cli_name:<35s}{cmd.description}") for cmd in COMMANDS]
        default_choice = last_command if last_command in _COMMAND_MAP else COMMANDS[0].cli_name

        selected: str = inquirer.select(
            message="Select a command",
            choices=choices,
            default=default_choice,
            instruction="(↑↓ navigate, Enter confirm)",
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
            if prompt.is_flag:
                value: Any = inquirer.confirm(
                    message=prompt.label,
                    default=bool(saved),
                ).execute()
            else:
                value = inquirer.text(
                    message=prompt.label,
                    default=str(saved) if saved else prompt.default,
                ).execute()
            collected[prompt.key] = value

        # ── Step 3: build CLI args list ──────────────────────────────────────
        cli_args: list[str] = [selected]
        positional: list[str] = []
        options: list[str] = []

        for prompt in spec.prompts:
            val = str(collected.get(prompt.key, ""))
            if not val:
                continue
            if prompt.is_option:
                if prompt.is_flag:
                    if val.lower() in ("true", "1", "yes"):
                        options.append(prompt.cli_flag)
                else:
                    options.extend([prompt.cli_flag, val])
            else:
                positional.append(val)

        cli_args += positional + options

        save_invocation(selected, collected)
        return cli_args

    except (KeyboardInterrupt, EOFError):
        # User pressed Ctrl-C or Ctrl-D
        return []
    except Exception:
        return []
