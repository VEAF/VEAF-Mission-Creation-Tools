"""Where each `veaf-tools` command lives, for both the CLI and the wizard.

The 25 commands used to be flat in the CLI and grouped four ways in the wizard, and the wizard's
grouping did not hold up: `config` held **10 of 21** and mixed starting a mission, converting one,
configuring it, and `about`/`ask` — a group holding half the options narrows nothing. Worse, the
split was by verb, so `inject-waypoints` and `extract-waypoints`, the two halves of one job, sat in
different menus (`REFACTOR-CLI-COMMAND-TREE`).

The tree sits **above** both consumers on purpose. `CommandSpec.group` in `tui.py` would have been
the obvious home, except the four machine-only commands are deliberately absent from `COMMANDS` —
the wizard cannot drive them — while the CLI needs a group for all 25. Neither list is a superset of
the other, so neither can own the answer.

Groups are ordered, and so are the commands inside them — `prepare` before `validate` before `build`
is the order a mission maker does them in. The **wizard** honours that order; the CLI's `--help` does
not, because Click sorts a group's commands alphabetically and overriding it would mean a custom
Group class for a cosmetic gain. That is an acceptable difference: a five-entry `--help` panel is a
reference you scan, where alphabetical is arguably better, while the wizard is a menu read top to
bottom.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from veaf_libs.i18n import t

if TYPE_CHECKING:
    import typer


@dataclass(frozen=True)
class CommandGroup:
    """One branch of the command tree."""

    id: str
    """Sub-command name on the CLI, and heading id in the wizard, e.g. ``mission``."""

    commands: tuple[str, ...]
    """The commands filed here, in the order both interfaces display them."""

    @property
    def label(self) -> str:
        """The group's heading, translated."""
        return t(f"tree.group.{self.id}.label")

    @property
    def description(self) -> str:
        """One line saying what the group is for, translated."""
        return t(f"tree.group.{self.id}.description")


#: The tree, in display order.
#:
#: `convert` is *getting a mission up to v6* and `dcs` is *this needs DCS running* — the latter is a
#: constraint a reader must know **before** choosing, not a theme, which is why it earns a group of
#: its own in an otherwise subject-based tree.
COMMAND_GROUPS: tuple[CommandGroup, ...] = (
    CommandGroup("mission", ("prepare", "validate", "build", "extract", "export")),
    CommandGroup("convert", ("convert-v5", "convert-other", "migrate-config", "generate-config")),
    CommandGroup(
        "content",
        (
            "extract-waypoints",
            "inject-waypoints",
            "inject-presets",
            "inject-weather",
            "extract-aircraft-groups",
            "inject-aircraft-groups",
        ),
    ),
    CommandGroup("cockpit", ("resolve-checklist", "verify-checklist", "explore-cockpit")),
    CommandGroup("dcs", ("inject-bridge", "capture-map", "smoke-test")),
)

#: Commands that stay at the root, because grouping them would be filing for filing's sake: they are
#: about the tool itself rather than about a mission.
ROOT_COMMANDS: tuple[str, ...] = ("about", "ask", "user-config", "mcp")

#: The wizard has no root: every entry needs a heading, so the root commands get one. The CLI keeps
#: them at the top level — same placement, expressed the way each interface can express it.
ROOT_GROUP_ID = "tool"


def group_of(command: str) -> str | None:
    """Return the group id a command is filed under, or ``None`` when it sits at the root.

    Args:
        command: The command's CLI name, e.g. ``inject-presets``.

    Returns:
        The group id, or ``None`` for a root command.

    Raises:
        KeyError: The command is in neither the tree nor the root list. Every command must be
            placed; a missing one would silently vanish from ``--help``.
    """
    for group in COMMAND_GROUPS:
        if command in group.commands:
            return group.id
    if command in ROOT_COMMANDS:
        return None
    raise KeyError(f"{command}: not placed in the command tree (see veaf_tools/command_tree.py)")


def in_group_name(command: str, group_id: str) -> str:
    """Return what a command is called *inside* its group.

    A command whose name already begins with its group's stutters when the two are read together —
    ``convert convert-v5``. The group has already said that word, so the command drops it and reads
    ``convert v5``. Nothing else in the tree is affected: only ``convert-v5`` and ``convert-other``
    start with their group's name.

    The flat name is unchanged and stays registered at the root as a hidden alias, so
    ``veaf-tools convert-v5`` keeps working. Only the grouped spelling is shortened — and since the
    tree has never been released, no one has ever typed the stuttering form.

    Args:
        command: The command's canonical CLI name, e.g. ``convert-v5``.
        group_id: The group it is filed under.

    Returns:
        The name to use after the group, e.g. ``v5``.
    """
    prefix = f"{group_id}-"
    return command[len(prefix) :] if command.startswith(prefix) else command


def resolve_command(group_id: str, token: str) -> str | None:
    """Map a token typed after a group back to its canonical command name.

    The inverse of :func:`in_group_name`, and the reason both live here: the CLI registers the short
    spelling while the wizard looks commands up by their canonical name, so a token like ``other``
    has to become ``convert-other`` or the CLI↔TUI bridge stops recognising it — and
    ``convert other`` has two required arguments, so that bridge is exactly what a user needs.

    Args:
        group_id: The group named by the first token.
        token: The next token on the command line.

    Returns:
        The canonical command name, or ``None`` when the group holds no such command.
    """
    group = next((g for g in COMMAND_GROUPS if g.id == group_id), None)
    if group is None:
        return None
    for command in group.commands:
        if token in (command, in_group_name(command, group_id)):
            return command
    return None


def build_cli_tree(app: typer.Typer) -> None:
    """Reshape a flat Typer app into the tree, keeping every flat name working.

    Each group becomes a sub-command holding its commands; each command **also** stays registered
    at the root, hidden. So ``veaf-tools mission build`` and ``veaf-tools build`` both run, while
    ``--help`` lists only the tree — the flat names keep every existing script, forum post and doc
    page working and can be dropped at a v7.

    Driven by the tree rather than written out 25 times, because a hand-written pairing is how one
    gets forgotten.

    Args:
        app: The root app, with every command already registered flat. Modified in place.

    Raises:
        KeyError: A registered command is absent from the tree — it would vanish from ``--help``.
    """
    import copy

    import typer

    groups = {group.id: typer.Typer(no_args_is_help=True, help=group.description) for group in COMMAND_GROUPS}

    for info in app.registered_commands:
        name = (info.name or (info.callback.__name__ if info.callback else "")).replace("_", "-")
        group_id = group_of(name)
        if group_id is None:
            continue  # a root command: already where it belongs, and visible
        grouped = copy.copy(info)
        # Shortened when the command name already starts with the group's, so `convert convert-v5`
        # reads `convert v5`. The flat name below is untouched.
        grouped.name = in_group_name(name, group_id)
        groups[group_id].registered_commands.append(grouped)
        # The flat name survives as an alias, absent from every help screen.
        info.hidden = True

    for group in COMMAND_GROUPS:
        # Two panels rather than one list: Typer renders root commands before sub-apps, so without
        # this the four tool commands would sit above the five groups a reader is actually looking for.
        app.add_typer(
            groups[group.id],
            name=group.id,
            help=group.description,
            rich_help_panel=t("tree.panel.groups"),
        )
    for info in app.registered_commands:
        if not info.hidden:
            info.rich_help_panel = t("tree.panel.root")


def all_placed_commands() -> tuple[str, ...]:
    """Every command the tree knows about, grouped ones then root ones.

    Returns:
        The command names, in display order.
    """
    grouped = tuple(command for group in COMMAND_GROUPS for command in group.commands)
    return grouped + ROOT_COMMANDS
