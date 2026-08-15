"""The command tree is the single source of truth — REFACTOR-CLI-COMMAND-TREE ticket 01.

The guard that matters is `TestNothingDrifts`: a command added to the CLI without being placed in
the tree fails here, naming the command. Without it the tree would rot the way the wizard's grouping
did, one forgotten command at a time.
"""

from __future__ import annotations

import unittest

from veaf_libs.i18n import language
from veaf_tools.command_tree import COMMAND_GROUPS, ROOT_COMMANDS, all_placed_commands, group_of


def _registered_cli_names() -> set[str]:
    """Every command name registered on the Typer app, as the CLI exposes it.

    A command with no explicit ``name=`` takes it from the function, with underscores turned into
    dashes — Typer's own convention, applied here so the tree can be written the way a user types it.
    """
    import veaf_tools.commands  # noqa: F401  — side effect: registers all commands
    from veaf_tools.app import app

    names = set()
    for command in app.registered_commands:
        name = command.name or (command.callback.__name__ if command.callback else "")
        names.add(name.replace("_", "-"))
    return names


class TestNothingDrifts(unittest.TestCase):
    """Neither side can gain or lose a command without this failing."""

    def test_every_registered_command_is_placed(self) -> None:
        missing = sorted(_registered_cli_names() - set(all_placed_commands()))
        self.assertEqual(
            missing,
            [],
            f"these commands exist but are not placed in the tree, so they would vanish from --help: {missing}",
        )

    def test_the_tree_names_no_command_that_does_not_exist(self) -> None:
        stale = sorted(set(all_placed_commands()) - _registered_cli_names())
        self.assertEqual(stale, [], f"the tree names commands that no longer exist: {stale}")

    def test_no_command_is_placed_twice(self) -> None:
        placed = all_placed_commands()
        duplicates = sorted({name for name in placed if placed.count(name) > 1})
        self.assertEqual(duplicates, [], f"placed in more than one group: {duplicates}")

    def test_group_of_refuses_an_unknown_command(self) -> None:
        # A silent None would let an unplaced command slip into the root by accident.
        with self.assertRaises(KeyError) as caught:
            group_of("no-such-command")
        self.assertIn("no-such-command", str(caught.exception))


class TestTheTreeIsAnImprovement(unittest.TestCase):
    """The reduction *is* the deliverable, so it is asserted rather than eyeballed."""

    def test_no_group_holds_more_than_a_third_of_the_commands(self) -> None:
        total = len(all_placed_commands())
        for group in COMMAND_GROUPS:
            self.assertLessEqual(
                len(group.commands),
                total // 3,
                f"'{group.id}' holds {len(group.commands)} of {total} — the catch-all this lot removes",
            )

    def test_extract_and_inject_pairs_are_adjacent(self) -> None:
        # The old split was by verb, so the two halves of one job lived in different menus.
        for subject in ("waypoints", "aircraft-groups"):
            content = next(g for g in COMMAND_GROUPS if g.id == "content").commands
            positions = sorted(i for i, name in enumerate(content) if name.endswith(subject))
            self.assertEqual(
                positions[1] - positions[0], 1, f"extract-{subject} and inject-{subject} must sit next to each other"
            )

    def test_validate_sits_with_build(self) -> None:
        mission = next(g for g in COMMAND_GROUPS if g.id == "mission").commands
        self.assertIn("validate", mission)
        self.assertIn("build", mission)

    def test_export_is_not_filed_next_to_extract_by_name_alone(self) -> None:
        # Both are in `mission`, but the point is that the tree groups by subject: one writes a
        # readable document, the other unpacks the archive.
        self.assertEqual(group_of("export"), "mission")
        self.assertEqual(group_of("extract"), "mission")


class TestBothFormsWork(unittest.TestCase):
    """`veaf-tools mission build` and `veaf-tools build` must both run (ticket 02, decision b)."""

    def _app(self):
        # build_cli_tree is idempotent per app instance in practice, but a test must not depend on
        # whether main() already ran, so it works on a fresh shallow copy of the registrations.
        import copy

        import typer
        import veaf_tools.commands  # noqa: F401  — side effect: registers all commands
        from veaf_tools.app import app
        from veaf_tools.command_tree import build_cli_tree

        fresh = typer.Typer()
        fresh.registered_commands = [copy.copy(info) for info in app.registered_commands]
        build_cli_tree(fresh)
        return fresh

    def test_a_group_becomes_a_subcommand_holding_its_commands(self) -> None:
        app = self._app()
        by_name = {group.name: group for group in app.registered_groups}
        self.assertEqual(sorted(by_name), sorted(g.id for g in COMMAND_GROUPS))
        mission = next(g for g in COMMAND_GROUPS if g.id == "mission")
        held = {
            (info.name or info.callback.__name__).replace("_", "-")
            for info in by_name["mission"].typer_instance.registered_commands
        }
        self.assertEqual(held, set(mission.commands))

    def test_every_flat_name_survives_as_a_hidden_alias(self) -> None:
        app = self._app()
        for info in app.registered_commands:
            name = (info.name or info.callback.__name__).replace("_", "-")
            if name in ROOT_COMMANDS:
                self.assertFalse(info.hidden, f"{name} is a root command and must stay visible")
            else:
                self.assertTrue(info.hidden, f"{name} must remain callable but absent from --help")

    def test_no_group_id_collides_with_a_command_name(self) -> None:
        # A collision would make one of the two unreachable, and the bridge would guess wrong.
        placed = set(all_placed_commands())
        for group in COMMAND_GROUPS:
            self.assertNotIn(group.id, placed, f"'{group.id}' is both a group and a command")


class TestNoStutter(unittest.TestCase):
    """`convert convert-v5` reads badly; inside the group the command drops the group's word.

    Free of charge because the tree has never been released: the flat `convert-v5` stays registered
    at the root as a hidden alias, and the stuttering spelling is one nobody has ever been able to
    type.
    """

    def test_a_command_starting_with_its_group_drops_it(self) -> None:
        from veaf_tools.command_tree import in_group_name

        self.assertEqual(in_group_name("convert-v5", "convert"), "v5")
        self.assertEqual(in_group_name("convert-other", "convert"), "other")

    def test_nothing_else_in_the_tree_is_shortened(self) -> None:
        from veaf_tools.command_tree import in_group_name

        for group in COMMAND_GROUPS:
            for command in group.commands:
                if group.id == "convert" and command.startswith("convert-"):
                    continue
                self.assertEqual(in_group_name(command, group.id), command, f"{group.id} {command}")

    def test_a_group_named_after_a_command_prefix_does_not_swallow_a_longer_name(self) -> None:
        # `content` holds `extract-waypoints`; a naive prefix strip on a different group must not
        # touch it. Guards the rule rather than the two cases it happens to hit today.
        from veaf_tools.command_tree import in_group_name

        self.assertEqual(in_group_name("extract-waypoints", "content"), "extract-waypoints")

    def test_the_group_registers_the_short_name(self) -> None:
        import copy

        import typer
        import veaf_tools.commands  # noqa: F401  — side effect: registers all commands
        from veaf_tools.app import app
        from veaf_tools.command_tree import build_cli_tree

        fresh = typer.Typer()
        fresh.registered_commands = [copy.copy(info) for info in app.registered_commands]
        build_cli_tree(fresh)
        convert = next(g for g in fresh.registered_groups if g.name == "convert")
        held = {info.name for info in convert.typer_instance.registered_commands}
        self.assertIn("v5", held)
        self.assertIn("other", held)
        self.assertNotIn("convert-v5", held, "the stuttering spelling must be gone from the group")

    def test_the_flat_name_still_resolves_for_the_wizard(self) -> None:
        # The CLI shows `convert v5` while the wizard looks commands up as `convert-v5`, so the
        # bridge has to map back — and `convert other` has two required arguments, which is exactly
        # when a user needs that bridge.
        from veaf_tools.command_tree import resolve_command

        self.assertEqual(resolve_command("convert", "v5"), "convert-v5")
        self.assertEqual(resolve_command("convert", "other"), "convert-other")
        self.assertEqual(resolve_command("convert", "convert-v5"), "convert-v5", "be forgiving on input")
        self.assertEqual(resolve_command("mission", "build"), "build")

    def test_resolve_command_refuses_what_the_group_does_not_hold(self) -> None:
        from veaf_tools.command_tree import resolve_command

        self.assertIsNone(resolve_command("convert", "build"))
        self.assertIsNone(resolve_command("no-such-group", "v5"))


class TestRootCommands(unittest.TestCase):
    def test_the_tool_about_itself_stays_at_the_root(self) -> None:
        for command in ("about", "ask", "user-config", "mcp"):
            self.assertIsNone(group_of(command), f"{command} is about the tool, not about a mission")

    def test_ask_is_no_longer_filed_as_configuration(self) -> None:
        # The documentation chatbot used to live in the wizard's `config` group.
        self.assertNotIn("ask", [c for g in COMMAND_GROUPS for c in g.commands])


class TestGroupsAreTranslated(unittest.TestCase):
    def test_every_group_has_a_label_and_a_description_in_both_languages(self) -> None:
        for lang in ("en", "fr"):
            with language(lang):
                for group in COMMAND_GROUPS:
                    self.assertNotIn("tree.group", group.label, f"[{lang}] missing label for '{group.id}'")
                    self.assertNotIn("tree.group", group.description, f"[{lang}] missing description for '{group.id}'")

    def test_the_two_languages_differ(self) -> None:
        # A French catalogue that merely copies the English one is not translated.
        with language("en"):
            english = [g.label for g in COMMAND_GROUPS]
        with language("fr"):
            french = [g.label for g in COMMAND_GROUPS]
        self.assertNotEqual(english, french)


if __name__ == "__main__":
    unittest.main()
