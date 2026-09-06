"""The Discord half of ticket 04: the buttons, what a silence means, and the form that comes back.

The intake is asserted against a protocol elsewhere. What can only break here is the wiring to the
library: a draft shown without buttons, a click that answers the wrong question, a *File the issue*
button still sitting on the message after the issue was filed, or an escalation that opens an empty
form. All of those pass a protocol test and fail a reporter.

Each test drives the real :class:`~discord.ui.View`: the buttons are pressed by calling the callback
the library would call, so what is asserted is the object that will actually be sent to Discord.
"""

from __future__ import annotations

import unittest
from typing import Any, cast

import discord

from tests.intake_fixtures import fixture_checkout
from tests.test_attachments import _fake_downloader
from veaf_support_bot.attachments import AttachmentCollector
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.discord_bot import (
    ESCALATION_EXPIRY_SECONDS,
    BugModal,
    InteractionExchange,
    ModalExchange,
    _ChoiceView,
    _EscalationView,
    role_ids_of,
)
from veaf_support_bot.draft import CANCEL, DRAFT_EXPIRY_SECONDS, EDIT, EXPIRED, FILE, MATCH_EXPIRY_SECONDS
from veaf_support_bot.intake import BugIntake
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.service import InFlightTasks


class _Stub:
    """A stand-in for the ``aiohttp`` response ``discord.HTTPException`` wants."""

    status = 403
    reason = "Forbidden"


class _User:
    """The parts of a Discord user the adapter reads."""

    def __init__(self) -> None:
        """Initialize the user, with no role until a test gives it one."""
        self.id = 4242
        self.display_name = "Tripack"


class _Response:
    """Records how a click was answered."""

    def __init__(self) -> None:
        """Initialize the recorder."""
        self.deferred = 0
        self.modals: list[BugModal] = []

    async def defer(self, **kwargs: Any) -> None:
        """Record a deferred acknowledgement.

        Args:
            **kwargs: What it was deferred with.
        """
        self.deferred += 1

    async def send_modal(self, modal: BugModal) -> None:
        """Record a modal being opened.

        Args:
            modal: The form.
        """
        self.modals.append(modal)


class _Click:
    """The interaction a button callback receives."""

    def __init__(self) -> None:
        """Initialize the click."""
        self.response = _Response()
        self.user = _User()
        self.locale = "en-GB"


class _Message:
    """A posted message whose components can be replaced."""

    def __init__(self) -> None:
        """Initialize the message."""
        self.views: list[Any] = []
        self.edit_error: Exception | None = None

    async def edit(self, content: str | None = None, view: Any = None, allowed_mentions: Any = None) -> _Message:
        """Record an edit.

        Args:
            content: The new content, when it changed.
            view: The components to show, or ``None`` to take them off.
            allowed_mentions: What the message may ping.

        Returns:
            The message.

        Raises:
            Exception: :attr:`edit_error`, when set.
        """
        if self.edit_error is not None:
            raise self.edit_error
        self.views.append(view)
        return self


class _Interaction:
    """The parts of ``discord.Interaction`` the consent step touches.

    Attributes:
        shown: What was written on the reporter's message, with the components it carried.
        press: Which button label to press as soon as a view is shown, or ``None`` to leave it
            unanswered — which is how a silence is asserted without waiting eight minutes.
    """

    def __init__(self, *, press: str | None = None, edit_error: Exception | None = None) -> None:
        """Initialize the interaction.

        Args:
            press: The label of the button to press when a view appears.
            edit_error: Raised instead of showing anything, when given.
        """
        self.response = _Response()
        self.user = _User()
        self.locale = "en-GB"
        self.shown: list[tuple[str, Any]] = []
        self.clicks: list[_Click] = []
        self.press = press
        self._edit_error = edit_error

    async def edit_original_response(self, content: str, view: Any = None, allowed_mentions: Any = None) -> _Message:
        """Record what the reporter was shown, and answer it when the test asked to.

        Args:
            content: The message content.
            view: The components.
            allowed_mentions: What the message may ping.

        Returns:
            A message.

        Raises:
            Exception: The one this interaction was built with.
        """
        if self._edit_error is not None:
            raise self._edit_error
        self.shown.append((content, view))
        if view is not None and self.press is not None:
            for item in view.children:
                if item.label == self.press:
                    click = _Click()
                    self.clicks.append(click)
                    await item.callback(cast(discord.Interaction, cast(object, click)))
        return _Message()


def _intake() -> BugIntake:
    """Build an intake over the fixture checkout.

    Returns:
        The intake.
    """
    collector = AttachmentCollector(fixture_checkout(), _fake_downloader({}))
    return BugIntake(fixture_checkout(), collector, refresh=False)


def _modal_exchange(interaction: _Interaction, *, reopen: Any = None) -> ModalExchange:
    """Build the exchange under test.

    Args:
        interaction: The fake interaction.
        reopen: What the *Edit* button does.

    Returns:
        The exchange.
    """
    return ModalExchange(cast(discord.Interaction, cast(object, interaction)), reopen, get_logger("test"))


class TestTheDraftIsShownWithItsButtons(unittest.IsolatedAsyncioTestCase):
    async def test_the_draft_is_written_on_the_reporters_own_message(self) -> None:
        interaction = _Interaction(press="Cancel")

        await _modal_exchange(interaction).decide("the issue as it will be filed", "en")

        self.assertEqual(interaction.shown[0][0], "the issue as it will be filed")

    async def test_pressing_file_answers_file(self) -> None:
        interaction = _Interaction(press="File the issue")

        self.assertEqual(await _modal_exchange(interaction).decide("draft", "en"), FILE)

    async def test_pressing_cancel_answers_cancel(self) -> None:
        interaction = _Interaction(press="Cancel")

        self.assertEqual(await _modal_exchange(interaction).decide("draft", "en"), CANCEL)

    async def test_the_buttons_speak_the_reporters_language(self) -> None:
        interaction = _Interaction(press="Annuler")

        self.assertEqual(await _modal_exchange(interaction).decide("brouillon", "fr"), CANCEL)

    async def test_without_a_form_to_reopen_no_edit_button_is_offered(self) -> None:
        """A button that leads nowhere is worse than a missing one."""
        interaction = _Interaction(press="Cancel")

        await _modal_exchange(interaction).decide("draft", "en")

        labels = [item.label for item in interaction.shown[0][1].children]
        self.assertNotIn("Edit", labels)

    async def test_a_discord_failure_answers_cancel_rather_than_filing(self) -> None:
        """Fail closed: a draft nobody could be shown must not be published on his behalf."""
        interaction = _Interaction(edit_error=discord.HTTPException(cast(Any, _Stub()), "gone"))

        self.assertEqual(await _modal_exchange(interaction).decide("draft", "en"), CANCEL)


class TestWhatASilenceMeans(unittest.IsolatedAsyncioTestCase):
    """Both waits end in the answer that publishes nothing, and both fit in one interaction token."""

    async def test_an_unanswered_draft_expires(self) -> None:
        self.assertEqual(_ChoiceView(default=EXPIRED, timeout=DRAFT_EXPIRY_SECONDS).choice, EXPIRED)

    async def test_the_two_waits_fit_inside_discords_fifteen_minutes(self) -> None:
        # Past the token the service can no longer edit the message, so the reporter would be left
        # on a preview that never resolves — the expiry has to be announceable.
        self.assertLess(MATCH_EXPIRY_SECONDS + DRAFT_EXPIRY_SECONDS, 15 * 60)


class TestTheProposalIsPutToTheReporter(unittest.IsolatedAsyncioTestCase):
    async def test_recognising_the_match_answers_yes(self) -> None:
        interaction = _Interaction(press="Yes, that is it")

        self.assertTrue(await _modal_exchange(interaction).confirm("#712 looks like yours", "en"))

    async def test_saying_it_is_different_answers_no(self) -> None:
        interaction = _Interaction(press="No, mine is different")

        self.assertFalse(await _modal_exchange(interaction).confirm("#712 looks like yours", "en"))

    async def test_a_discord_failure_answers_no_rather_than_silencing_the_report(self) -> None:
        interaction = _Interaction(edit_error=discord.HTTPException(cast(Any, _Stub()), "gone"))

        self.assertFalse(await _modal_exchange(interaction).confirm("#712", "en"))


class TestTheButtonsAreTakenAwayWithTheAnswer(unittest.IsolatedAsyncioTestCase):
    async def test_the_final_message_carries_no_components(self) -> None:
        """Otherwise *File the issue* is still there to be pressed after the issue was filed."""
        interaction = _Interaction()

        await _modal_exchange(interaction).post("✅ Issue opened: https://example.invalid/1")

        self.assertEqual(interaction.shown[-1][1], None)


class TestEditGivesTheFormBack(unittest.IsolatedAsyncioTestCase):
    async def test_pressing_edit_reopens_the_form_with_his_answers(self) -> None:
        opened: list[BugModal] = []

        async def reopen(click: discord.Interaction) -> None:
            modal = BugModal(_intake(), [], get_logger("test"), prefill=_form())
            opened.append(modal)
            await click.response.send_modal(modal)

        interaction = _Interaction(press="Edit")

        answer = await _modal_exchange(interaction, reopen=reopen).decide("draft", "en")

        self.assertEqual(answer, EDIT)
        self.assertEqual(str(opened[0].summary.default), "convert-v5 crashes")


class _Submission(_Interaction):
    """A modal submission: it can be deferred, and it shows the draft on its own response."""

    async def edit_original_response(self, content: str, view: Any = None, allowed_mentions: Any = None) -> _Message:
        """Show the reporter something, pressing a button if the test asked for one.

        Args:
            content: The message content.
            view: The components.
            allowed_mentions: What the message may ping.

        Returns:
            A message.
        """
        return await super().edit_original_response(content, view, allowed_mentions)


class TestTheSubmissionIsWiredEndToEnd(unittest.IsolatedAsyncioTestCase):
    """The production ``reopen`` and the production task registry — not stand-ins for them.

    Four bugs shipped green on this repository because a test drove the handler and never the thing
    that connects it. The *Edit* button is exactly that shape: a modal that reopens empty passes
    every protocol test in the suite.
    """

    async def _submit(self, press: str, tasks: Any = None) -> _Submission:
        """Run one real modal submission.

        Args:
            press: The button label to press on the draft.
            tasks: The in-flight registry, when the test is about tracking.

        Returns:
            The submission interaction, with what it was shown and what it opened.
        """
        from tests.test_intake_github_wiring import _Filer

        collector = AttachmentCollector(fixture_checkout(), _fake_downloader({}))
        intake = BugIntake(fixture_checkout(), collector, refresh=False, filer=_Filer())
        modal = BugModal(intake, [], get_logger("test"), prefill=_form(), tasks=tasks)
        interaction = _Submission(press=press)
        await modal.on_submit(cast(discord.Interaction, cast(object, interaction)))
        return interaction

    async def test_the_draft_reaches_the_reporter_through_the_real_modal(self) -> None:
        interaction = await self._submit("Cancel")

        self.assertIn("convert-v5 crashes", interaction.shown[0][0])

    async def test_the_edit_button_reopens_the_form_with_what_he_submitted(self) -> None:
        interaction = await self._submit("Edit")

        reopened = [modal for click in interaction.clicks for modal in click.response.modals]
        self.assertTrue(reopened, "the Edit button opened no form at all")
        self.assertEqual(str(reopened[0].summary.default), "convert-v5 crashes")
        self.assertEqual(str(reopened[0].steps.default), "run it")

    async def test_the_submission_is_tracked_so_a_shutdown_waits_for_it(self) -> None:
        tasks = _Registry()

        await self._submit("Cancel", tasks=tasks)

        self.assertEqual(tasks.tracked, ["bug:4242"])
        self.assertEqual(len(tasks), 0, "a finished exchange must not stay in the registry")


class _Registry(InFlightTasks):
    """The real registry, plus a note of what it was asked to track.

    Subclassed rather than replaced: what has to be asserted is that the **production** registry is
    handed the submission, under a name a drain can report.

    Attributes:
        tracked: The names tracked, in order.
    """

    def __init__(self) -> None:
        """Initialize the registry."""
        super().__init__()
        self.tracked: list[str | None] = []

    def track(self, coro: Any, *, name: str | None = None) -> Any:
        """Record the name, then track for real.

        Args:
            coro: The coroutine to run.
            name: What to call it.

        Returns:
            The task.
        """
        self.tracked.append(name)
        return super().track(coro, name=name)


def _form(**overrides: str) -> BugForm:
    """Build a submitted form.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    base = {
        "summary": "convert-v5 crashes",
        "happened": "it stopped",
        "expected": "it should convert",
        "steps": "run it",
        "doctor": "",
        "reporter": "Tripack",
        "reporter_id": "4242",
        "language": "en",
    }
    base.update(overrides)
    return BugForm(**base)


class TestTheModalIsPrefilledOrEmpty(unittest.TestCase):
    def test_with_no_prefill_every_field_starts_empty(self) -> None:
        modal = BugModal(_intake(), [], get_logger("test"))

        self.assertIsNone(modal.summary.default)
        self.assertIsNone(modal.doctor.default)

    def test_a_prefilled_modal_carries_every_field(self) -> None:
        modal = BugModal(_intake(), [], get_logger("test"), prefill=_form(doctor="veaf-tools 6.19.0"))

        filled = [modal.summary.default, modal.happened.default, modal.expected.default, modal.steps.default]
        self.assertEqual(filled, ["convert-v5 crashes", "it stopped", "it should convert", "run it"])
        self.assertEqual(str(modal.doctor.default), "veaf-tools 6.19.0")


class _AnswerMessage:
    """The public answer message an escalation button is attached to."""

    def __init__(self, *, edit_error: Exception | None = None) -> None:
        """Initialize the message.

        Args:
            edit_error: Raised by :meth:`edit`, when given.
        """
        self.views: list[Any] = []
        self.edit_error = edit_error

    async def edit(self, content: str | None = None, view: Any = None, allowed_mentions: Any = None) -> _AnswerMessage:
        """Record an edit.

        Args:
            content: The new content.
            view: The components.
            allowed_mentions: What the message may ping.

        Returns:
            The message.

        Raises:
            Exception: :attr:`edit_error`, when set.
        """
        if self.edit_error is not None:
            raise self.edit_error
        self.views.append(view)
        return self


def _answered(intake: BugIntake | None, message: _AnswerMessage) -> InteractionExchange:
    """Build an exchange that has already posted its answer.

    Args:
        intake: What an escalation would hand its form to.
        message: The answer message.

    Returns:
        The exchange.
    """
    exchange = InteractionExchange(
        cast(discord.Interaction, cast(object, _Interaction())),
        get_logger("test"),
        intake=intake,
    )
    exchange._message = cast(discord.Message, cast(object, message))  # noqa: SLF001 - the seam under test
    return exchange


class TestTheEscalationOffer(unittest.IsolatedAsyncioTestCase):
    async def test_the_answer_gains_a_report_button(self) -> None:
        message = _AnswerMessage()

        await _answered(_intake(), message).offer_escalation("how do I set a QRA?", "you cannot", "en")

        labels = [item.label for item in message.views[0].children]
        self.assertEqual(labels, ["Report a bug"])

    async def test_without_an_intake_nothing_is_offered(self) -> None:
        """The deployment where ``/bug`` is not published either."""
        message = _AnswerMessage()

        await _answered(None, message).offer_escalation("q", "a", "en")

        self.assertEqual(message.views, [])

    async def test_pressing_it_opens_the_form_carrying_the_exchange(self) -> None:
        message = _AnswerMessage()
        await _answered(_intake(), message).offer_escalation("how do I set a QRA?", "you cannot", "en")
        click = _Click()

        await message.views[0].children[0].callback(cast(discord.Interaction, cast(object, click)))

        opened = click.response.modals[0]
        self.assertIn("QRA", str(opened.summary.default))
        self.assertIn("you cannot", str(opened.happened.default))

    async def test_a_failure_to_offer_it_does_not_lose_the_answer(self) -> None:
        """The answer is already posted; trading it for a button would be the wrong way round."""
        message = _AnswerMessage(edit_error=discord.HTTPException(cast(Any, _Stub()), "rate limited"))

        await _answered(_intake(), message).offer_escalation("q", "a", "en")  # must not raise

    async def test_the_button_is_taken_off_when_it_stops_being_live(self) -> None:
        message = _AnswerMessage()
        view = _EscalationView(label="Report a bug", open_form=_never, logger=get_logger("test"))
        view.message = cast(discord.Message, cast(object, message))

        await view.on_timeout()

        self.assertEqual(message.views, [None])

    async def test_it_stays_offered_for_as_long_as_a_thread_is_read(self) -> None:
        """Not the interaction budget: nobody is waiting on this one."""
        self.assertGreater(ESCALATION_EXPIRY_SECONDS, DRAFT_EXPIRY_SECONDS)


async def _never(click: discord.Interaction) -> None:
    """Stand in for a button action that is not exercised.

    Args:
        click: The click.
    """


class _CachelessRole:
    """A role id the guild cache could not resolve — what ``Intents.none()`` produces."""

    def __init__(self, role_id: int) -> None:
        """Initialize the role.

        Args:
            role_id: Its id.
        """
        self.id = role_id


class TestTheRolesAreReadOffTheInteraction(unittest.TestCase):
    """The gate that decides who gets a hypothesis, and the way it can silently refuse everybody.

    ``Member.roles`` resolves each id against the guild cache and drops what it cannot find, and
    this bot runs on ``Intents.none()``. A gate reading only that would refuse every reporter
    forever while looking healthy — the exact shape of failure this repository has shipped green
    before, so it is asserted on the raw payload attribute the interaction actually carries.
    """

    def test_the_raw_payload_ids_are_used_even_with_an_empty_guild_cache(self) -> None:
        member = _User()
        member._roles = [111, 222]  # type: ignore[attr-defined]
        member.roles = []  # type: ignore[attr-defined]

        self.assertEqual(role_ids_of(member), ("111", "222"))

    def test_resolved_roles_are_used_when_that_is_all_there_is(self) -> None:
        class _Resolved:
            roles = [_CachelessRole(333)]

        self.assertEqual(role_ids_of(_Resolved()), ("333",))

    def test_a_user_with_no_roles_at_all_is_not_an_error(self) -> None:
        """A direct message, or a member of no role: refused enrichment, never a crash."""
        self.assertEqual(role_ids_of(object()), ())

    def test_the_ids_are_strings_so_they_compare_with_the_configured_one(self) -> None:
        """An int id against a string from the environment silently matches nothing."""
        member = _User()
        member._roles = [444]  # type: ignore[attr-defined]

        self.assertIsInstance(role_ids_of(member)[0], str)

    def test_the_submission_carries_them_to_the_intake(self) -> None:
        modal = BugModal(_intake(), [], get_logger("test"), prefill=_form())
        interaction = _Submission()
        interaction.user._roles = [555]  # type: ignore[attr-defined]

        submission = modal.submission(cast(discord.Interaction, cast(object, interaction)))

        self.assertEqual(submission.roles, ("555",))


if __name__ == "__main__":
    unittest.main()
