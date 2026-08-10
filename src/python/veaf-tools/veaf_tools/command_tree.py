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

Groups are ordered, and so are the commands inside them: the CLI's `--help` and the wizard's menu
both read in this order, so a reader sees the same shape whichever door they came through.
"""

from __future__ import annotations

from dataclasses import dataclass

from veaf_libs.i18n import t


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


def all_placed_commands() -> tuple[str, ...]:
    """Every command the tree knows about, grouped ones then root ones.

    Returns:
        The command names, in display order.
    """
    grouped = tuple(command for group in COMMAND_GROUPS for command in group.commands)
    return grouped + ROOT_COMMANDS
