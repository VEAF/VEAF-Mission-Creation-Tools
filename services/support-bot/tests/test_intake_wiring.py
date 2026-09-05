"""The ``/bug`` wiring, not the intake.

Four bugs shipped green on this repository because the tests called the handler and never the thing
that branches to it. So this file asserts only the connections, each one where cutting it would
leave every other test in this suite still passing:

* ``/bug`` is **registered** on the command tree, with the attachment options Discord will send;
* the **client the gateway connects** carries it — registering correctly in a function nobody calls
  is the same bug one layer up;
* the modal **reaches the intake**, carrying the reporter, the typed fields and the attachments;
* the **service builds the intake from the configuration**, and publishes ``/bug`` only when there
  is a checkout to read.

``TestTheseTestsDetectABrokenWiring`` cuts each wire and asserts the matching test fails. Every cut
is made in **production** code — a symbol in a shipped module, or the binding a shipped module
resolves — never in a stand-in defined here: a detector that mutates its own double proves the
double, not the wire.
"""

from __future__ import annotations

import io
import tempfile
import unittest
from pathlib import Path
from typing import Any, cast

import discord
from discord import app_commands

from tests.intake_fixtures import PYTHON_TRACEBACK, doctor_block, fixture_checkout, fixture_root
from tests.test_attachments import _fake_downloader
from veaf_support_bot import discord_bot
from veaf_support_bot import service as service_module
from veaf_support_bot.attachments import AttachmentCollector
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.discord_bot import BugModal, register_bug_command
from veaf_support_bot.intake import BugIntake, BugSubmission
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.service import SupportBotService, build_intake


def _config(**overrides: str) -> SupportBotConfig:
    """Build a configuration bound to an ephemeral port.

    Args:
        **overrides: Extra environment entries, without the ``SUPPORT_BOT_`` prefix.

    Returns:
        The resolved configuration.
    """
    env = {
        "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
        "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
        "SUPPORT_BOT_WORKER_SECRET": "a-secret",
        "SUPPORT_BOT_HEALTH_PORT": "0",
        "SUPPORT_BOT_CHECKOUT_REFRESH_SECONDS": "0",
    }
    env.update({f"SUPPORT_BOT_{key}": value for key, value in overrides.items()})
    return SupportBotConfig.from_env(env)


class _RecordingIntake:
    """A :class:`~veaf_support_bot.intake.BugIntake` stand-in that records what reached it."""

    def __init__(self) -> None:
        self.submissions: list[BugSubmission] = []

    async def handle(self, exchange: Any, submission: BugSubmission) -> None:
        self.submissions.append(submission)


class _FakeUser:
    """The parts of ``discord.User`` the command reads."""

    def __init__(self, identifier: int = 4242, display: str = "Someone") -> None:
        self.id = identifier
        self.display_name = display


class _FakeAttachment:
    """The parts of ``discord.Attachment`` the command reads."""

    def __init__(self, filename: str) -> None:
        self.filename = filename
        self.url = f"https://cdn.discordapp.com/{filename}?ex=expiring"
        self.size = 10
        self.content_type = "text/plain"


class _FakeResponse:
    """Records the modal a command sent."""

    def __init__(self) -> None:
        self.modal: discord.ui.Modal | None = None

    async def send_modal(self, modal: discord.ui.Modal) -> None:
        self.modal = modal


class _FakeInteraction:
    """Enough of ``discord.Interaction`` to drive the command and the modal."""

    def __init__(self) -> None:
        self.user = _FakeUser()
        self.locale = "en-GB"
        self.response = _FakeResponse()
        self.edited: list[str] = []

    async def edit_original_response(self, content: str, **_: Any) -> None:
        self.edited.append(content)


def _tree() -> app_commands.CommandTree:
    """Build a command tree with no gateway behind it.

    Returns:
        The tree.
    """
    return app_commands.CommandTree(discord.Client(intents=discord.Intents.none()))


def _bug_command(tree: app_commands.CommandTree) -> Any:
    """Return the registered ``/bug`` command.

    ``get_commands`` is typed as returning commands, groups and context menus; only one of the three
    has options and a callback, so the narrowing happens once here rather than at every call site.

    Args:
        tree: The tree to look in.

    Returns:
        The command.
    """
    return next(item for item in tree.get_commands() if item.name == "bug")


def _registered() -> tuple[app_commands.CommandTree, _RecordingIntake]:
    """Build a tree with ``/bug`` registered on it.

    Returns:
        The tree and the intake it points at.
    """
    tree = _tree()
    intake = _RecordingIntake()
    register_bug_command(tree, intake, get_logger("test"))  # type: ignore[arg-type]
    return tree, intake


def _fill(modal: BugModal) -> None:
    """Put values into a modal's inputs the way Discord does on submission.

    Args:
        modal: The modal to fill.
    """
    modal.summary._value = "convert-v5 crashes"
    modal.happened._value = PYTHON_TRACEBACK
    modal.expected._value = "it should convert"
    modal.steps._value = "run it"
    modal.doctor._value = doctor_block("6.16.3")


class TestTheCommandIsRegistered(unittest.TestCase):
    def test_bug_is_on_the_tree(self) -> None:
        tree, _ = _registered()
        self.assertIn("bug", {command.name for command in tree.get_commands()})

    def test_the_attachment_options_discord_will_send_are_declared(self) -> None:
        tree, _ = _registered()
        declared = {parameter.name for parameter in _bug_command(tree).parameters}
        self.assertEqual(declared, {"log", "mission", "extra"})

    def test_every_attachment_option_is_optional(self) -> None:
        """A required file would refuse the reports of people who have none."""
        tree, _ = _registered()
        self.assertFalse(any(parameter.required for parameter in _bug_command(tree).parameters))


class TestTheCommandOpensTheModal(unittest.IsolatedAsyncioTestCase):
    async def test_the_command_answers_with_a_modal(self) -> None:
        """Sending the modal *is* the acknowledgement; anything else spends the three seconds."""
        tree, _ = _registered()
        interaction = _FakeInteraction()
        await _bug_command(tree).callback(interaction, None, None, None)
        self.assertIsInstance(interaction.response.modal, BugModal)

    async def test_the_attachments_reach_the_modal(self) -> None:
        tree, _ = _registered()
        interaction = _FakeInteraction()
        await _bug_command(tree).callback(
            interaction,
            _FakeAttachment("dcs.log"),
            None,
            _FakeAttachment("mission.yaml"),
        )
        modal = interaction.response.modal
        assert isinstance(modal, BugModal)
        submission = modal.submission(cast(discord.Interaction, interaction))
        self.assertEqual([item.filename for item in submission.attachments], ["dcs.log", "mission.yaml"])


class TestTheModalReachesTheIntake(unittest.IsolatedAsyncioTestCase):
    async def test_the_typed_fields_and_the_reporter_reach_the_intake(self) -> None:
        intake = _RecordingIntake()
        modal = BugModal(intake, [], get_logger("test"))  # type: ignore[arg-type]
        _fill(modal)
        interaction = _FakeInteraction()
        await modal.on_submit(interaction)  # type: ignore[arg-type]
        self.assertEqual(len(intake.submissions), 1)
        form = intake.submissions[0].form
        self.assertEqual(form.summary, "convert-v5 crashes")
        self.assertEqual(form.reporter_id, "4242")
        self.assertEqual(form.language, "en-GB")
        self.assertIn("Traceback", form.happened)

    async def test_the_modal_asks_the_five_fields_the_template_needs(self) -> None:
        modal = BugModal(_RecordingIntake(), [], get_logger("test"))  # type: ignore[arg-type]
        self.assertEqual(len(modal.children), 5)
        self.assertFalse(modal.doctor.required, "a reporter with no doctor block must still be able to file")


class TestTheServiceBuildsTheIntake(unittest.TestCase):
    def test_no_checkout_means_no_bug_command_at_all(self) -> None:
        """A command that answers 'I cannot do this' is a promise the service does not keep."""
        self.assertIsNone(build_intake(_config()))

    def test_a_configured_checkout_produces_an_intake(self) -> None:
        intake = build_intake(_config(CHECKOUT_PATH=str(fixture_root())))
        self.assertIsInstance(intake, BugIntake)

    def test_a_path_that_is_not_a_working_tree_disables_the_command_rather_than_the_service(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertIsNone(build_intake(_config(CHECKOUT_PATH=directory)))

    def test_the_ceilings_come_from_the_configuration_not_from_the_defaults(self) -> None:
        intake = build_intake(_config(CHECKOUT_PATH=str(fixture_root()), ATTACHMENT_MAX_BYTES="1234"))
        assert intake is not None
        self.assertEqual(intake._collector._max_file, 1234)

    def test_the_service_carries_the_intake_it_built(self) -> None:
        service = SupportBotService(_config(CHECKOUT_PATH=str(fixture_root())))
        self.assertIsInstance(service.intake, BugIntake)

    def test_the_client_the_gateway_runs_carries_the_command(self) -> None:
        """The blind spot one layer up: registration works, nobody calls it."""
        service = SupportBotService(_config(CHECKOUT_PATH=str(fixture_root())))
        gateway = service._build_gateway()
        names = {command.name for command in cast(Any, gateway).client.tree.get_commands()}
        self.assertIn("bug", names)
        self.assertIn("ask", names, "adding /bug must not have unpublished /ask")

    def test_a_service_with_no_checkout_publishes_only_ask(self) -> None:
        service = SupportBotService(_config())
        gateway = service._build_gateway()
        names = {command.name for command in cast(Any, gateway).client.tree.get_commands()}
        self.assertEqual(names, {"ask"})


class TestTheseTestsDetectABrokenWiring(unittest.TestCase):
    """The tests above are only worth their runtime if cutting the wire turns them red.

    Each case severs one connection in **production** code and asserts the matching test fails.
    """

    def _assert_detects(self, case: type[unittest.TestCase], name: str) -> None:
        """Assert that a test method fails.

        Args:
            case: The test class.
            name: The method name.
        """
        result = unittest.TextTestRunner(stream=io.StringIO()).run(case(name))
        self.assertFalse(result.wasSuccessful(), f"{case.__name__}.{name} passed with the wiring cut")

    def test_unregistering_the_bug_command_is_detected(self) -> None:
        original = discord_bot.register_bug_command

        def _no_registration(*_: Any, **__: Any) -> None:
            return None

        setattr(discord_bot, "register_bug_command", _no_registration)
        globals()["register_bug_command"] = _no_registration
        try:
            self._assert_detects(TestTheCommandIsRegistered, "test_bug_is_on_the_tree")
        finally:
            setattr(discord_bot, "register_bug_command", original)
            globals()["register_bug_command"] = original

    def test_a_client_that_registers_no_bug_command_is_detected(self) -> None:
        """Registration works; the client never calls it."""
        original = discord_bot.register_bug_command

        def _no_registration(*_: Any, **__: Any) -> None:
            return None

        setattr(discord_bot, "register_bug_command", _no_registration)
        try:
            self._assert_detects(TestTheServiceBuildsTheIntake, "test_the_client_the_gateway_runs_carries_the_command")
        finally:
            setattr(discord_bot, "register_bug_command", original)

    def test_a_modal_that_loses_the_question_is_detected(self) -> None:
        """Cut in the production module's own binding, so the real modal builds the bad form."""
        original = discord_bot.BugForm

        class _SummaryLosingForm(BugForm):
            def __init__(self, *args: Any, **kwargs: Any) -> None:
                kwargs["summary"] = ""
                super().__init__(*args, **kwargs)

        setattr(discord_bot, "BugForm", _SummaryLosingForm)
        try:
            self._assert_detects(
                TestTheModalReachesTheIntake, "test_the_typed_fields_and_the_reporter_reach_the_intake"
            )
        finally:
            setattr(discord_bot, "BugForm", original)

    def test_a_command_that_drops_its_attachments_is_detected(self) -> None:
        original = discord_bot.incoming_from

        def _drop_them(*_: Any) -> list[Any]:
            return []

        setattr(discord_bot, "incoming_from", _drop_them)
        try:
            self._assert_detects(TestTheCommandOpensTheModal, "test_the_attachments_reach_the_modal")
        finally:
            setattr(discord_bot, "incoming_from", original)

    def test_a_service_that_never_builds_the_intake_is_detected(self) -> None:
        original = service_module.build_intake

        def _no_intake(*_: Any, **__: Any) -> None:
            return None

        setattr(service_module, "build_intake", _no_intake)
        try:
            self._assert_detects(TestTheServiceBuildsTheIntake, "test_the_service_carries_the_intake_it_built")
        finally:
            setattr(service_module, "build_intake", original)

    def test_an_intake_wired_to_default_ceilings_is_detected(self) -> None:
        """A configuration nobody reads is a configuration that enforces nothing."""
        original = service_module.AttachmentCollector

        class _IgnoringTheConfiguration(AttachmentCollector):
            def __init__(self, checkout: Any, download: Any, **_: Any) -> None:
                super().__init__(checkout, download)

        setattr(service_module, "AttachmentCollector", _IgnoringTheConfiguration)
        try:
            self._assert_detects(
                TestTheServiceBuildsTheIntake,
                "test_the_ceilings_come_from_the_configuration_not_from_the_defaults",
            )
        finally:
            setattr(service_module, "AttachmentCollector", original)

    def test_a_command_published_without_a_checkout_is_detected(self) -> None:
        original = service_module.build_intake

        def _always_an_intake(*_: Any, **__: Any) -> BugIntake:
            checkout = fixture_checkout()
            return BugIntake(checkout, AttachmentCollector(checkout, _fake_downloader({})), refresh=False)

        setattr(service_module, "build_intake", _always_an_intake)
        try:
            self._assert_detects(TestTheServiceBuildsTheIntake, "test_a_service_with_no_checkout_publishes_only_ask")
        finally:
            setattr(service_module, "build_intake", original)

    def test_a_decision_that_starts_reading_free_text_is_detected(self) -> None:
        """The differential test is only worth its runtime if a text-reading branch turns it red.

        The cut is a real one, made on the production symbol ``assemble`` resolves: ``build_title``
        starts obeying a ``title:`` line in the reporter's own prose — precisely the shape of bug
        the hostile fixture exists to catch, and precisely the shape somebody could add believing it
        helpful.
        """
        from tests import test_intake_hostile
        from veaf_support_bot import bugreport

        original = bugreport.build_title

        def _obeys_a_title_line(form: Any, version: str) -> str:
            for line in form.all_text().splitlines():
                if line.lower().startswith("title:"):
                    return line.split(":", 1)[1].strip()
            return str(original(form, version))

        setattr(bugreport, "build_title", _obeys_a_title_line)
        try:
            self._assert_detects(
                test_intake_hostile.TestHostileTextChangesNoDecision,
                "test_the_two_reports_decide_exactly_the_same_things",
            )
        finally:
            setattr(bugreport, "build_title", original)


class TestTheFixtureIsARealCheckout(unittest.TestCase):
    def test_the_miniature_repository_looks_like_a_working_tree(self) -> None:
        """Guards the guard: without ``.git`` every build_intake assertion above would be vacuous."""
        self.assertTrue((Path(fixture_root()) / ".git").exists())


if __name__ == "__main__":
    unittest.main()
