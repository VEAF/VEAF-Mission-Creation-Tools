"""Interactive TUI wizard for veaf-tools.

Launched automatically when the tool is run with no arguments in an interactive
terminal.  Uses InquirerPy to present a command-selector and argument prompts,
then builds a list of CLI arguments that Typer executes normally.

Preferences (last command + argument values) are persisted in VEAF_HOME so the
wizard can pre-fill fields on the next run.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, NoReturn

from veaf_tools.command_tree import COMMAND_GROUPS, ROOT_COMMANDS, ROOT_GROUP_ID, group_of, resolve_command

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
    resolve_path: bool = False
    """True → show the absolute path the current default resolves to as a hint."""
    required: bool = False
    """True → when this arg is absent from the CLI, drop into the TUI to ask for it."""
    choices: list[str] | None = None
    """When set, the wizard offers a select among these values instead of free text."""

    @property
    def cli_flag(self) -> str:
        """Convert snake_case key to ``--kebab-case`` CLI option name."""
        return "--" + self.key.replace("_", "-")


#: The wizard's headings, in display order, taken from the command tree — the CLI reads the same one,
#: so the two interfaces cannot disagree about where a command lives (REFACTOR-CLI-COMMAND-TREE).
#: The root commands come last, under their own heading: the wizard has no root.
GROUP_ORDER: tuple[str, ...] = tuple(group.id for group in COMMAND_GROUPS) + (ROOT_GROUP_ID,)

#: The CLI's group names, so the bridge can tell `mission build` from a bare command. None of them
#: is also a command name — asserted by a test, since a collision would make one unreachable.
_GROUP_IDS: frozenset[str] = frozenset(group.id for group in COMMAND_GROUPS)


@dataclass
class CommandSpec:
    """Describes one veaf-tools command exposed in the wizard."""

    cli_name: str
    """Exact name used on the command line (e.g. ``inject-presets``)."""
    description: str
    """One-line description shown in the command selector."""
    prompts: list[ArgPrompt] = field(default_factory=list)
    """Ordered list of prompts — positional args first, then options."""

    @property
    def group(self) -> str:
        """The heading this command is filed under, read from the command tree.

        Derived rather than declared: the tree is the only place a command's group is written, so
        the wizard and the CLI cannot drift apart.
        """
        return group_of(self.cli_name) or ROOT_GROUP_ID


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
            ArgPrompt("mission_folder", t("tui.arg.mission_folder"), default=".", is_option=False, resolve_path=True),
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
            ArgPrompt("template_file", t("tui.arg.template_file"), default="src/spawnables.yaml"),
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
            ArgPrompt(
                "mission_folder", t("tui.arg.mission_folder_dest"), default=".", is_option=False, resolve_path=True
            ),
        ],
    ),
    CommandSpec(
        cli_name="extract-aircraft-groups",
        description=t("tui.cmd.extract_aircraft.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("kind", t("tui.arg.extract_aircraft_kind"), default="both"),
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
            ArgPrompt(
                "mission_folder", t("tui.arg.mission_folder_init"), default=".", is_option=False, resolve_path=True
            ),
            ArgPrompt("force", t("tui.arg.convert_v5_force"), default="", is_flag=True),
            ArgPrompt("icao", t("tui.arg.convert_v5_icao"), default=""),
        ],
    ),
    CommandSpec(
        cli_name="convert-other",
        description=t("tui.cmd.convert_other.description"),
        prompts=[
            ArgPrompt(
                "input_miz",
                t("tui.arg.convert_other_miz"),
                default="mission.miz",
                is_option=False,
                required=True,
            ),
            ArgPrompt(
                "output_folder",
                t("tui.arg.convert_other_output"),
                default=".",
                is_option=False,
                required=True,
            ),
            ArgPrompt("profile", t("tui.arg.convert_other_profile"), default=""),
        ],
    ),
    CommandSpec(
        cli_name="prepare",
        description=t("tui.cmd.prepare.description"),
        prompts=[
            ArgPrompt(
                "mission_folder",
                t("tui.arg.mission_folder_init"),
                default=".",
                is_option=False,
                resolve_path=True,
                required=True,
            ),
            ArgPrompt(
                "template",
                t("tui.arg.prepare_template"),
                default="standard",
                choices=["minimal", "standard", "full", "custom"],
                required=True,
            ),
        ],
    ),
    # ── Config / validation utilities ───────────────────────────────────────
    CommandSpec(
        cli_name="export",
        description=t("tui.cmd.export.description"),
        prompts=[
            ArgPrompt(
                "mission_name_or_file", t("tui.arg.mission_name_or_file"), default="mission.miz", is_option=False
            ),
            ArgPrompt("format", t("tui.arg.export_format"), default="json", choices=["json", "yaml", "markdown"]),
        ],
    ),
    CommandSpec(
        cli_name="validate",
        description=t("tui.cmd.validate.description"),
        prompts=[
            ArgPrompt(
                "mission_folder", t("tui.arg.mission_folder_init"), default=".", is_option=False, resolve_path=True
            ),
            ArgPrompt("strict", t("tui.arg.validate_strict"), default="", is_flag=True),
        ],
    ),
    CommandSpec(
        cli_name="resolve-checklist",
        description=t("tui.cmd.resolve_checklist.description"),
        prompts=[
            ArgPrompt(
                "checklist_file",
                t("tui.arg.checklist_file"),
                default="checklists/my-checklist.yaml",
                is_option=False,
                required=True,
            ),
            ArgPrompt("dry_run", t("tui.arg.checklist_dry_run"), default="", is_flag=True),
        ],
    ),
    CommandSpec(
        cli_name="explore-cockpit",
        description=t("tui.cmd.explore_cockpit.description"),
        prompts=[
            ArgPrompt("aircraft", t("tui.arg.explore_aircraft"), default="F-16C_50", is_option=False, required=True),
            ArgPrompt("control", t("tui.arg.explore_control"), default=""),
        ],
    ),
    CommandSpec(
        cli_name="verify-checklist",
        description=t("tui.cmd.verify_checklist.description"),
        prompts=[
            ArgPrompt(
                "checklist_file",
                t("tui.arg.checklist_file"),
                default="checklists/my-checklist.yaml",
                is_option=False,
                required=True,
            ),
            ArgPrompt("write", t("tui.arg.checklist_write_verified"), default="", is_flag=True),
        ],
    ),
    CommandSpec(
        cli_name="migrate-config",
        description=t("tui.cmd.migrate_config.description"),
        prompts=[
            ArgPrompt("input_file", t("tui.arg.migrate_config_input"), default="", is_option=False, required=True),
        ],
    ),
    CommandSpec(
        cli_name="generate-config",
        description=t("tui.cmd.generate_config.description"),
        prompts=[
            ArgPrompt("output", t("tui.arg.generate_config_output"), default="."),
        ],
    ),
    CommandSpec(
        cli_name="user-config",
        description=t("tui.cmd.user_config.description"),
        prompts=[],
    ),
    CommandSpec(
        cli_name="ask",
        description=t("tui.cmd.ask.description"),
        prompts=[],
    ),
    CommandSpec(
        cli_name="about",
        description=t("tui.cmd.about.description"),
        prompts=[],
    ),
    CommandSpec(
        cli_name="doctor",
        description=t("tui.cmd.doctor.description"),
        prompts=[],
    ),
]

_COMMAND_MAP: dict[str, CommandSpec] = {cmd.cli_name: cmd for cmd in COMMANDS}


def _in_tree_order(commands: list[CommandSpec], group: str) -> list[CommandSpec]:
    """Order a group's commands the way the tree lists them, not the way COMMANDS declares them.

    The tree's intra-group order is deliberate — `prepare` before `validate` before `build` is the
    order a mission maker does them in — and the CLI's ``--help`` reads it too, so the wizard has to
    as well or the two interfaces show the same group differently.

    Args:
        commands: The group's commands, in declaration order.
        group: The group id, or the root pseudo-group.

    Returns:
        The same commands, in tree order; anything the tree does not list keeps its relative place
        at the end rather than disappearing.
    """
    listed = next((g.commands for g in COMMAND_GROUPS if g.id == group), ROOT_COMMANDS)
    return sorted(commands, key=lambda cmd: listed.index(cmd.cli_name) if cmd.cli_name in listed else len(listed))


def _grouped_choices() -> list[Any]:
    """Return the command selector's entries, under one heading per group.

    Twenty commands in a flat list is a wall of text, and the three assistance ones are a
    workflow that only makes sense read together. A group with no installed command
    simply does not appear.
    """
    from InquirerPy.base.control import Choice  # noqa: PLC0415 - optional dependency
    from InquirerPy.separator import Separator  # noqa: PLC0415 - optional dependency

    entries: list[Any] = []
    for group in GROUP_ORDER:
        commands = _in_tree_order([cmd for cmd in COMMANDS if cmd.group == group], group)
        if not commands:
            continue
        if entries:
            entries.append(Separator(" "))
        entries.append(Separator(f"── {t(f'tree.group.{group}.label')} ──"))
        entries.extend(Choice(value=cmd.cli_name, name=f"{cmd.cli_name:<28}  {cmd.description}") for cmd in commands)
    return entries


# Prompt keys that should default to the ``mission.name`` field of a detected
# ``mission.yaml``.  Both the ``build``/``extract`` positional and the
# ``inject-presets`` variant share the same mission identity.
_MISSION_NAME_PROMPT_KEYS: tuple[str, ...] = ("mission_name_or_file", "input_mission_name_or_file")

# ---------------------------------------------------------------------------
# mission.yaml-aware defaults
# ---------------------------------------------------------------------------


def _mission_yaml_defaults(folder: Path | None = None) -> dict[str, str]:
    """Derive prompt defaults from a ``mission.yaml`` in *folder*.

    Reads the ``mission.name`` field and maps it to the mission-name prompts so
    the wizard proposes the real mission name instead of the static
    ``mission.miz`` fallback.

    Args:
        folder: Directory to look in. Defaults to the current working directory.

    Returns:
        Mapping of prompt key to derived default value. Empty when no
        ``mission.yaml`` is present, it carries no ``mission.name``, or it
        cannot be parsed.
    """
    folder = folder or Path.cwd()
    mission_yaml_path = folder / "mission.yaml"
    if not mission_yaml_path.exists():
        return {}

    try:
        import yaml  # noqa: PLC0415

        with mission_yaml_path.open("r", encoding="utf-8") as fh:
            data: dict = yaml.safe_load(fh) or {}
    except Exception:
        # mission.yaml-aware defaults are a convenience — never break the wizard.
        return {}

    defaults: dict[str, str] = {}
    mission_name = (data.get("mission") or {}).get("name")
    if mission_name:
        for key in _MISSION_NAME_PROMPT_KEYS:
            defaults[key] = str(mission_name)
    return defaults


def _resolve_prompt_default(prompt: ArgPrompt, last_args: dict[str, Any], yaml_defaults: dict[str, str]) -> str:
    """Resolve the default value offered for *prompt*.

    Precedence: last saved preference > value derived from ``mission.yaml`` >
    the prompt's static fallback.

    Args:
        prompt: The prompt being resolved.
        last_args: Saved argument values for the selected command.
        yaml_defaults: Defaults derived from a detected ``mission.yaml``.

    Returns:
        The default string to pre-fill in the prompt.
    """
    saved = last_args.get(prompt.key)
    if saved:
        return str(saved)
    yaml_value = yaml_defaults.get(prompt.key)
    if yaml_value:
        return str(yaml_value)
    return prompt.default


def _folder_hint(default_value: str) -> str:
    """Return a localized hint showing the absolute path *default_value* resolves to.

    Clarifies the otherwise-opaque ``.`` default by spelling out that it means
    the current folder and showing the fully resolved path it points at.

    Args:
        default_value: The path string currently offered as the prompt default.

    Returns:
        A one-line localized hint string for the prompt's ``long_instruction``.
    """
    resolved = Path(default_value or ".").resolve()
    return t("tui.hint.mission_folder", path=resolved)


# ---------------------------------------------------------------------------
# Wizard entry point
# ---------------------------------------------------------------------------


def _parse_provided(spec: CommandSpec, tokens: list[str]) -> tuple[dict[str, str], list[str]]:
    """Split a command's CLI tokens into known prompt values and pass-through extras.

    Positional tokens fill the spec's positional prompts in order; ``--kebab[=val]``
    tokens that match a spec option prompt are captured; everything else (unknown
    options like ``--verbose``, surplus positionals) is preserved verbatim for the
    rebuilt command line.

    Returns:
        ``(provided, passthrough)`` — ``provided`` maps ``ArgPrompt.key`` → value;
        ``passthrough`` is the list of unrecognised tokens, in order.
    """
    option_prompts = {p.cli_flag: p for p in spec.prompts if p.is_option}
    positional_prompts = [p for p in spec.prompts if not p.is_option]
    provided: dict[str, str] = {}
    passthrough: list[str] = []
    pos_index = 0
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("-"):
            name, eq, inline = tok.partition("=")
            prompt = option_prompts.get(name)
            if prompt is None:
                passthrough.append(tok)
            elif prompt.is_flag:
                provided[prompt.key] = "true"
            elif eq:
                provided[prompt.key] = inline
            elif i + 1 < len(tokens):
                provided[prompt.key] = tokens[i + 1]
                i += 1
            i += 1
            continue
        if pos_index < len(positional_prompts):
            provided[positional_prompts[pos_index].key] = tok
            pos_index += 1
        else:
            passthrough.append(tok)
        i += 1
    return provided, passthrough


def _exit_cancelled() -> NoReturn:
    """Print a cancellation notice and exit cleanly.

    Called when the user backs out (Ctrl-C / Esc) of a wizard the bridge routed
    them into. Without this the bridge would return ``None`` and Typer would run
    the original, incomplete command — dumping its help screen instead of
    returning the user to the shell.
    """
    from veaf_libs.logger import console  # noqa: PLC0415

    console.print(t("tui.cancelled"))
    raise SystemExit(0)


def maybe_bridge_to_tui(args: list[str]) -> list[str] | None:
    """Decide whether to route a CLI invocation into the TUI, returning rewritten args.

    Rules (interactive terminals only):
      - no command at all → run the full wizard (main menu);
      - a command with a ``CommandSpec`` invoked with ``--tui`` **or** missing a
        ``required`` prompt → run the wizard for that command, pre-filling the args
        already given on the CLI and prompting only the rest;
      - otherwise → ``None`` (let Typer run the command unchanged).

    When the user cancels a wizard they were routed into, the process exits
    cleanly (via :func:`_exit_cancelled`) instead of falling through to Typer.

    Args:
        args: ``sys.argv[1:]``.

    Returns:
        The rewritten arg list to hand to Typer, or ``None`` to run as-is.
    """
    import sys

    if not sys.stdout.isatty():
        return None

    force_tui = "--tui" in args
    tokens = [a for a in args if a != "--tui"]

    if not tokens:
        wizard_args = run_wizard()
        if not wizard_args:
            _exit_cancelled()
        return wizard_args

    command, rest = tokens[0], tokens[1:]
    if command in _GROUP_IDS and rest:
        # The grouped form, `veaf-tools mission build …`: the command is the second token. Without
        # this the bridge saw `mission`, found no CommandSpec, and let Typer run a command that was
        # missing a required option — the exact case the bridge exists to catch
        # (REFACTOR-CLI-COMMAND-TREE ticket 02).
        #
        # `resolve_command` rather than `rest[0]` because a command whose name starts with its
        # group's drops it there: the user types `convert other`, the wizard knows `convert-other`.
        # That command has two required arguments, so getting this wrong would send someone to
        # Typer's help screen instead of the wizard.
        resolved = resolve_command(command, rest[0])
        command, rest = (resolved or rest[0]), rest[1:]
    spec = _COMMAND_MAP.get(command)
    if spec is None:
        return None

    provided, passthrough = _parse_provided(spec, rest)
    missing_required = [p for p in spec.prompts if p.required and p.key not in provided]
    if not force_tui and not missing_required:
        return None

    wizard_args = run_wizard(preselected=command, provided=provided)
    if not wizard_args:
        # The user was routed into the wizard (bare call, ``--tui``, or a missing
        # required option) and cancelled it — exit cleanly rather than letting
        # Typer run the incomplete command and print its help screen.
        _exit_cancelled()
    return wizard_args + passthrough


# ── Back navigation ─────────────────────────────────────────────────────────
# Pressing Ctrl-B (or Escape twice) on any wizard prompt "skips" it (InquirerPy
# returns ``None``), which the wizard loop reads as "step back one level" — or
# quit at the top. Ctrl-B is the primary, single-press binding: it is reliable on
# every prompt type and every platform. A double Escape is offered alongside for
# users who reach for it by reflex; a *single* bare Escape is deliberately not
# bound because ESC is the prefix byte for arrow keys, so on the Windows console a
# lone Escape is ambiguous and a phantom startup ESC regressed the first attempt
# (the first prompt cancelled itself).
#
# A short debounce (reset each time a prompt is shown) gates the Escape binding as
# a belt-and-braces guard: a real press only ever lands well after the prompt has
# rendered, so any burst arriving within a few milliseconds of startup is ignored.
_ESC_DEBOUNCE_SECONDS = 0.4
_prompt_shown_at = 0.0


def _touch_prompt_shown() -> None:
    """Reset the Escape debounce — call right before displaying a prompt."""
    global _prompt_shown_at
    _prompt_shown_at = time.monotonic()


def _escape_is_real() -> bool:
    """True once enough time has elapsed since the prompt rendered for an Escape
    to be a genuine keypress rather than a console startup artifact."""
    return time.monotonic() - _prompt_shown_at >= _ESC_DEBOUNCE_SECONDS


def _skip_keybindings() -> dict[str, list[dict[str, Any]]]:
    """InquirerPy keybindings: Ctrl-B (primary) or a debounced double-Escape → ``skip``."""
    from prompt_toolkit.filters import Condition  # noqa: PLC0415

    return {
        "skip": [
            {"key": "c-b"},
            {"key": ["escape", "escape"], "filter": Condition(_escape_is_real)},
        ]
    }


def _ask_one(
    inquirer: Any,
    prompt: ArgPrompt,
    last_args: dict[str, Any],
    yaml_defaults: dict[str, str],
    current: Any = None,
) -> Any:
    """Show a single prompt and return its value, or ``None`` if the user pressed Escape.

    ``current`` (a value collected on a previous pass) takes precedence over saved
    preferences as the offered default, so stepping back and forth preserves answers.
    """
    display_label = f"{prompt.cli_flag}  {prompt.label}" if prompt.is_option else prompt.label
    esc_hint = t("tui.nav_hint")
    skip_kb = _skip_keybindings()
    _touch_prompt_shown()
    if prompt.choices:
        default_choice = current if current in prompt.choices else last_args.get(prompt.key, prompt.default)
        return inquirer.select(  # type: ignore[attr-defined]
            message=display_label,
            choices=prompt.choices,
            default=default_choice if default_choice in prompt.choices else prompt.choices[0],
            mandatory=False,
            keybindings=skip_kb,
            long_instruction=esc_hint,
        ).execute()
    if prompt.is_flag:
        default_flag = bool(current) if current is not None else bool(last_args.get(prompt.key, prompt.default))
        return inquirer.confirm(  # type: ignore[attr-defined]
            message=display_label,
            default=default_flag,
            mandatory=False,
            keybindings=skip_kb,
            long_instruction=esc_hint,
        ).execute()
    default_value = current if current not in (None, "") else _resolve_prompt_default(prompt, last_args, yaml_defaults)
    long_instruction = f"{_folder_hint(default_value)}  {esc_hint}" if prompt.resolve_path else esc_hint
    return inquirer.text(  # type: ignore[attr-defined]
        message=display_label,
        default=default_value,
        mandatory=False,
        keybindings=skip_kb,
        long_instruction=long_instruction,
    ).execute()


def run_wizard(preselected: str | None = None, provided: dict[str, str] | None = None) -> list[str]:
    """Run the interactive wizard and return a list of CLI arguments for Typer.

    Args:
        preselected: When set to a known command name, skip the command-selection step
            and prompt only that command's arguments (the CLI-TUI bridge entry point).
        provided: Argument values already supplied on the command line (by ``key``);
            those prompts are skipped and passed straight through.

    Returns an empty list when the terminal is not interactive or the user
    cancels.  Unexpected errors are logged and re-raised so they are visible
    to the user rather than silently swallowed.
    """
    import sys

    provided = provided or {}

    # Only meaningful in an interactive terminal
    if not sys.stdout.isatty():
        return []

    try:
        from InquirerPy import inquirer

        from veaf_libs.preferences import get_last_args, get_last_command, save_invocation
    except ImportError:
        return []

    try:
        last_command = get_last_command()
        yaml_defaults = _mission_yaml_defaults()

        # Two-level loop: command selection (level 0), then the selected command's
        # prompts (levels 1..N). Escape steps back one level; Escape at the top
        # (the command menu, or the first prompt of a bridge-preselected command)
        # quits with an empty result.
        while True:
            # ── Step 1: select command (skipped when the bridge pre-selects one) ──
            if preselected and preselected in _COMMAND_MAP:
                selected = preselected
            else:
                choices = _grouped_choices()
                default_choice = last_command if last_command in _COMMAND_MAP else COMMANDS[0].cli_name
                _touch_prompt_shown()
                selected = inquirer.select(  # type: ignore[attr-defined]
                    message=t("tui.select_command"),
                    choices=choices,
                    default=default_choice,
                    instruction=t("tui.instruction"),
                    long_instruction=t("tui.nav_hint_menu"),
                    mandatory=False,
                    keybindings=_skip_keybindings(),
                ).execute()
                if selected is None:  # Escape at the main menu → quit
                    return []

            spec = _COMMAND_MAP[selected]
            if not spec.prompts:
                # No arguments needed (e.g. 'about')
                save_invocation(selected, {})
                return [selected]

            # ── Step 2: prompt for arguments (Escape = back one prompt) ──────────
            last_args = get_last_args(selected)
            collected: dict[str, Any] = {p.key: provided[p.key] for p in spec.prompts if p.key in provided}
            askable = [p for p in spec.prompts if p.key not in provided]
            idx = 0
            back_to_menu = False
            while idx < len(askable):
                prompt = askable[idx]
                value = _ask_one(inquirer, prompt, last_args, yaml_defaults, current=collected.get(prompt.key))
                if value is None:  # Escape
                    if idx == 0:
                        # Nothing earlier to revisit: a bridge-preselected command
                        # quits; a menu-chosen command returns to the selector.
                        if preselected:
                            return []
                        back_to_menu = True
                        break
                    idx -= 1
                    continue
                collected[prompt.key] = value
                idx += 1
            if back_to_menu:
                continue

            # ── Step 3: build CLI args list ──────────────────────────────────────
            cli_args: list[str] = [selected]
            positional: list[str] = []
            options: list[str] = []
            for prompt in spec.prompts:
                raw = collected.get(prompt.key)
                if prompt.is_option:
                    if prompt.is_flag:
                        if raw:  # already a bool from inquirer.confirm
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
