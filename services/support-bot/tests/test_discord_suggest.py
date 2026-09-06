"""The Discord side of ``/suggest``: the form, the choice, and what reaches the flow.

The component is the part worth asserting hard. A modal can only hold text inputs, so it rides on
the command as a choice bound to the template's own list — and a choice nobody bound, or one bound
to a list that has drifted from the template, is a component nobody can filter on.
"""

from __future__ import annotations

import unittest
from typing import Any, cast

import discord
from discord import app_commands

from veaf_support_bot.discord_bot import SuggestModal, register_suggest_command
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.suggest import SuggestIntake, SuggestSubmission
from veaf_support_bot.suggestion import COMPONENTS, UNKNOWN_COMPONENT, SuggestionForm


class _User:
    """The parts of a Discord user the adapter reads."""

    id = 4242
    display_name = "Tripack"


class _Response:
    """Records what the interaction was answered with."""

    def __init__(self) -> None:
        self.modals: list[SuggestModal] = []
        self.deferred = 0

    async def defer(self, **kwargs: Any) -> None:
        self.deferred += 1

    async def send_modal(self, modal: SuggestModal) -> None:
        self.modals.append(modal)


class _Interaction:
    """The interaction a command or a modal submission receives."""

    def __init__(self, locale: str = "fr") -> None:
        self.response = _Response()
        self.user = _User()
        self.locale = locale


class _RecordingIntake(SuggestIntake):
    """A flow that records what it was handed instead of running."""

    def __init__(self) -> None:
        super().__init__()
        self.handled: list[SuggestSubmission] = []

    async def handle(self, exchange: Any, submission: SuggestSubmission) -> None:
        self.handled.append(submission)
        return None


def a_form(**overrides: str) -> SuggestionForm:
    """Build a form to prefill a modal with.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    base = {
        "summary": "Convoys along a drawn route",
        "problem": "Placing a convoy by hand takes ten minutes.",
        "solution": "Let me draw a route.",
        "alternatives": "a trigger",
        "context": "see mission Tripack-3",
        "component": "Documentation",
    }
    base.update(overrides)
    return SuggestionForm(**base)


def a_modal(**kwargs: Any) -> SuggestModal:
    """Build a modal over a recording flow.

    Args:
        **kwargs: Passed to the modal.

    Returns:
        The modal.
    """
    return SuggestModal(_RecordingIntake(), "Documentation", get_logger("test"), **kwargs)


class TestTheForm(unittest.TestCase):
    """Five fields, the problem among them and required."""

    def test_with_no_prefill_every_field_starts_empty(self) -> None:
        modal = a_modal()

        self.assertIsNone(modal.summary.default)
        self.assertIsNone(modal.problem.default)

    def test_a_prefilled_modal_carries_every_field(self) -> None:
        modal = a_modal(prefill=a_form())

        filled = [
            modal.summary.default,
            modal.problem.default,
            modal.solution.default,
            modal.alternatives.default,
            modal.context.default,
        ]
        self.assertEqual(
            filled,
            [
                "Convoys along a drawn route",
                "Placing a convoy by hand takes ten minutes.",
                "Let me draw a route.",
                "a trigger",
                "see mission Tripack-3",
            ],
        )

    def test_the_problem_is_required_and_the_extras_are_not(self) -> None:
        modal = a_modal()

        self.assertTrue(modal.problem.required)
        self.assertTrue(modal.solution.required)
        self.assertFalse(modal.alternatives.required)
        self.assertFalse(modal.context.required)


class TestWhatReachesTheFlow(unittest.IsolatedAsyncioTestCase):
    """The submission carries the choice, the asker and his language."""

    async def test_the_component_comes_from_the_command_not_from_typing(self) -> None:
        modal = a_modal()

        submission = modal.submission(cast(discord.Interaction, cast(object, _Interaction())))

        self.assertEqual(submission.form.component, "Documentation")

    async def test_the_asker_and_his_language_are_read_off_the_interaction(self) -> None:
        modal = a_modal()

        submission = modal.submission(cast(discord.Interaction, cast(object, _Interaction("en-GB"))))

        self.assertEqual(submission.form.asker, "Tripack")
        self.assertEqual(submission.form.asker_id, "4242")
        self.assertEqual(submission.form.language, "en-GB")

    async def test_submitting_hands_the_form_to_the_flow(self) -> None:
        intake = _RecordingIntake()
        modal = SuggestModal(intake, "Documentation", get_logger("test"))

        await modal.on_submit(cast(discord.Interaction, cast(object, _Interaction())))

        self.assertEqual(len(intake.handled), 1)


class TestTheCommand(unittest.IsolatedAsyncioTestCase):
    """A handler that works and a command nobody attached is a bug this repository has shipped."""

    def _tree(self) -> app_commands.CommandTree:
        client = discord.Client(intents=discord.Intents.none())
        tree = app_commands.CommandTree(client)
        register_suggest_command(tree, _RecordingIntake(), get_logger("test"))
        return tree

    def test_it_is_attached(self) -> None:
        names = {command.name for command in self._tree().get_commands()}

        self.assertIn("suggest", names)

    def test_its_choices_are_the_templates_own_components(self) -> None:
        command = cast(Any, self._tree().get_command("suggest"))

        offered = tuple(choice.value for choice in command._params["component"].choices)
        self.assertEqual(offered, COMPONENTS)

    async def test_picking_nothing_falls_back_to_the_templates_catch_all(self) -> None:
        command = cast(Any, self._tree().get_command("suggest"))
        interaction = _Interaction()

        await command.callback(cast(discord.Interaction, cast(object, interaction)))

        self.assertEqual(interaction.response.modals[0]._component, UNKNOWN_COMPONENT)

    async def test_the_picked_component_reaches_the_modal(self) -> None:
        command = cast(Any, self._tree().get_command("suggest"))
        interaction = _Interaction()

        await command.callback(
            cast(discord.Interaction, cast(object, interaction)),
            app_commands.Choice(name="Documentation", value="Documentation"),
        )

        self.assertEqual(interaction.response.modals[0]._component, "Documentation")

    async def test_opening_the_form_is_the_acknowledgement(self) -> None:
        """A modal *is* the answer to the interaction, so the three-second budget is never spent."""
        command = cast(Any, self._tree().get_command("suggest"))
        interaction = _Interaction()

        await command.callback(cast(discord.Interaction, cast(object, interaction)))

        self.assertEqual(interaction.response.deferred, 0)
        self.assertEqual(len(interaction.response.modals), 1)
