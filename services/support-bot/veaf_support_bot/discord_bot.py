"""The only module that imports ``discord``: the gateway, the ``/ask`` command, and the wiring.

Everything else in the service is written against the narrow :class:`~veaf_support_bot.ask.Exchange`
protocol, so the exchange's *order* — defer, announce, thread, post, edit — is testable without a
Discord connection. What lives here is the part only the real library can do, kept as thin as it can
be: turn an ``Interaction`` into that protocol, and turn a gateway connection into readiness.

## Readiness

The service is ready when the gateway is connected, and not before. Ticket 01 made readiness mean
"the health endpoint answers", which was true while the service did nothing; it would now mean a bot
that answers nobody reporting itself as fit to serve. ``on_ready``/``on_resumed`` mark it ready,
``on_disconnect`` marks it not, and a dry run never becomes ready at all — that is the point of a
dry run.

## Command registration

The commands are synced to the one configured guild, never globally. Guild commands appear
immediately, global ones take up to an hour to propagate, and the lot's decision is a bot that
serves the VEAF Discord rather than one invitable anywhere.
"""

from __future__ import annotations

from logging import Logger
from typing import Any

import discord
from discord import app_commands

from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.attachments import Incoming
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.health import ServiceState
from veaf_support_bot.intake import (
    DOCTOR_MAX_CHARS,
    PARAGRAPH_MAX_CHARS,
    SUMMARY_MAX_CHARS,
    BugIntake,
    BugSubmission,
)
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.service import InFlightTasks

#: Gateway intents. The default set minus every privileged one: the bot reads slash-command options,
#: never message content or member lists, so asking for more would be permission it does not need.
INTENTS = discord.Intents.none()

#: Longest question the slash command accepts, mirrored from the handler's own bound.
QUESTION_MAX_LENGTH = 1000

#: No message this bot sends ever pings anybody.
#:
#: Every message it writes carries text it did not author: the asker's own question, echoed into the
#: channel, and the model's answer. Either can contain ``@everyone``, a role mention, or a user
#: mention — deliberately or because the documentation quotes one. Discord resolves mentions in bot
#: messages by permission, so this does not merely rely on the bot never being granted *Mention
#: Everyone*: it removes the question entirely, at the call site, for every message.
NO_MENTIONS = discord.AllowedMentions.none()


class InteractionExchange:
    """The :class:`~veaf_support_bot.ask.Exchange` protocol over a real Discord interaction."""

    def __init__(self, interaction: discord.Interaction, logger: Logger | None = None) -> None:
        """Initialize the exchange.

        Args:
            interaction: The interaction the command was invoked with.
            logger: Logger to use; defaults to the service's ``discord`` logger.
        """
        self._interaction = interaction
        self._logger = logger or get_logger("discord")
        self._thread: discord.Thread | None = None
        self._message: discord.Message | None = None

    async def defer(self) -> None:
        """Acknowledge the interaction publicly, inside Discord's three-second budget."""
        await self._interaction.response.defer(thinking=True)

    async def announce(self, content: str) -> None:
        """Replace the deferred acknowledgement with the visible question message.

        Args:
            content: The question line.
        """
        await self._interaction.edit_original_response(content=content, allowed_mentions=NO_MENTIONS)

    async def open_thread(self, name: str) -> bool:
        """Open a public thread on the question message.

        Args:
            name: The thread name.

        Returns:
            ``True`` when the thread was created. ``False`` when Discord refused — most often a
            missing *Create Public Threads* permission, or a channel that cannot hold threads. The
            caller then answers in place rather than losing the answer.
        """
        try:
            anchor = await self._interaction.original_response()
            self._thread = await anchor.create_thread(name=name)
        except (discord.HTTPException, discord.ClientException) as error:
            self._logger.warning(
                "could not open a thread for the question",
                extra={"event": "ask.thread_failed", "error": f"{type(error).__name__}: {error}"},
            )
            self._thread = None
            return False
        return True

    async def post(self, content: str) -> None:
        """Post the first message of the answer, in the thread when there is one.

        Args:
            content: The message content.
        """
        if self._thread is not None:
            self._message = await self._thread.send(content, allowed_mentions=NO_MENTIONS)
        else:
            self._message = await self._interaction.followup.send(content, wait=True, allowed_mentions=NO_MENTIONS)

    async def edit(self, content: str) -> None:
        """Replace the content of the message :meth:`post` created.

        A failed intermediate edit is swallowed on purpose: Discord rate-limits edits, and losing a
        progress update must not lose the answer. The final edit carries the same risk and the same
        handling — what would be worse is the exception escaping into the gateway's task, where it
        becomes an unhandled error and no message at all.

        Args:
            content: The new content.
        """
        if self._message is None:
            await self.post(content)
            return
        try:
            await self._message.edit(content=content, allowed_mentions=NO_MENTIONS)
        except discord.HTTPException as error:
            self._logger.warning(
                "could not edit the answer message",
                extra={"event": "ask.edit_failed", "error": f"{type(error).__name__}: {error}"},
            )


class SupportBotClient(discord.Client):
    """The gateway connection, and the readiness it publishes."""

    def __init__(
        self,
        config: SupportBotConfig,
        state: ServiceState,
        handler: AskHandler,
        tasks: InFlightTasks | None = None,
        intake: BugIntake | None = None,
        **kwargs: Any,
    ) -> None:
        """Initialize the client without connecting.

        Args:
            config: The resolved configuration.
            state: The state object readiness is published on.
            handler: The ``/ask`` handler.
            tasks: The registry a shutdown drains. An exchange that is not registered there is one
                ``docker stop`` can cut in half, leaving a placeholder that is never edited.
            intake: The ``/bug`` intake. ``None`` when the service has no checkout, in which case
                ``/bug`` is not published at all — a command that answers "I cannot do this" is
                worse than one that is not there.
            **kwargs: Passed to :class:`discord.Client`.
        """
        super().__init__(intents=INTENTS, **kwargs)
        self._config = config
        self._state = state
        self._handler = handler
        self._logger = get_logger("discord")
        self.tree = app_commands.CommandTree(self)
        register_commands(self.tree, handler, self._logger, tasks)
        if intake is not None:
            register_bug_command(self.tree, intake, self._logger, tasks)

    @property
    def guild(self) -> discord.Object:
        """Return the one guild the commands are synced to.

        Returns:
            A reference to the configured guild.
        """
        return discord.Object(id=self._config.discord_guild_id)

    async def setup_hook(self) -> None:
        """Publish the command set to the configured guild, before the gateway goes live."""
        self.tree.copy_global_to(guild=self.guild)
        synced = await self.tree.sync(guild=self.guild)
        self._logger.info(
            "commands synced",
            extra={
                "event": "discord.commands_synced",
                "guild": self._config.discord_guild_id,
                "commands": [command.name for command in synced],
            },
        )

    async def on_ready(self) -> None:
        """Mark the service ready: the gateway is connected and commands can arrive."""
        self._state.mark_ready()
        self._logger.info(
            "connected to the gateway",
            extra={"event": "discord.ready", "user": str(self.user), "guilds": len(self.guilds)},
        )

    async def on_resumed(self) -> None:
        """Mark the service ready again after a resumed session."""
        self._state.mark_ready()
        self._logger.info("gateway session resumed", extra={"event": "discord.resumed"})

    async def on_disconnect(self) -> None:
        """Mark the service not ready: nothing can reach it while the gateway is down."""
        self._state.mark_not_ready("gateway-disconnected")
        self._logger.warning("disconnected from the gateway", extra={"event": "discord.disconnected"})


class DiscordGateway:
    """Adapts :class:`discord.Client` to the service's :class:`~veaf_support_bot.service.Gateway`.

    Only to hold the token: ``Client.start`` takes it as an argument, and the lifecycle must not
    have to carry a secret around to close a connection.
    """

    def __init__(self, client: discord.Client, token: str) -> None:
        """Initialize the adapter.

        Args:
            client: The Discord client.
            token: The bot token.
        """
        self.client = client
        self._token = token

    async def start(self) -> None:
        """Connect and serve until :meth:`close` is called."""
        await self.client.start(self._token)

    async def close(self) -> None:
        """Disconnect and release the connection."""
        await self.client.close()


def register_commands(
    tree: app_commands.CommandTree,
    handler: AskHandler,
    logger: Logger,
    tasks: InFlightTasks | None = None,
) -> None:
    """Attach ``/ask`` to a command tree.

    Split out of the client so the registration itself is testable: a handler that works and a
    command nobody attached is exactly the shape of bug this repository has shipped green before.

    Args:
        tree: The command tree to attach to.
        handler: The handler the command delegates to.
        logger: Logger for failures that escape the handler.
        tasks: Registry a shutdown drains; the exchange is run as a tracked task when given.
    """

    @tree.command(name="ask", description="Ask a question about the VEAF Mission Creation Tools documentation")
    @app_commands.describe(question="What do you want to know?")
    async def ask(interaction: discord.Interaction, question: app_commands.Range[str, 1, QUESTION_MAX_LENGTH]) -> None:
        """Answer a documentation question in a public thread.

        Args:
            interaction: The invoking interaction.
            question: The question asked.
        """
        context = AskContext(
            user_id=str(interaction.user.id),
            user_display=interaction.user.display_name,
            question=question,
            locale=str(interaction.locale) if interaction.locale else None,
        )
        exchange = InteractionExchange(interaction, logger)
        try:
            if tasks is None:
                await handler.handle(exchange, context)
            else:
                # Awaited, not fired and forgotten: the interaction must stay alive for the whole
                # exchange. Tracking it is what makes a shutdown wait for the final edit instead of
                # leaving a "thinking" placeholder on the server forever.
                await tasks.track(handler.handle(exchange, context), name=f"ask:{context.user_id}")
        except Exception as error:
            # The gateway swallows a handler exception into a log nobody reads, and the user is left
            # with a "thinking" message that never resolves — the silent failure this service exists
            # to make impossible.
            logger.exception(
                "the /ask exchange failed",
                extra={"event": "ask.crashed", "user": context.user_id, "error": type(error).__name__},
            )
            raise


class ModalExchange:
    """The :class:`~veaf_support_bot.intake.BugExchange` protocol over a modal submission.

    Ephemeral throughout. The deterministic pass is a *preparation* step: it says what the service
    read and what it could not, which concerns the reporter and nobody else. What becomes public is
    the issue, and opening it is ticket 04's click.
    """

    def __init__(self, interaction: discord.Interaction, logger: Logger | None = None) -> None:
        """Initialize the exchange.

        Args:
            interaction: The modal submission interaction.
            logger: Logger to use; defaults to the service's ``discord`` logger.
        """
        self._interaction = interaction
        self._logger = logger or get_logger("discord")

    async def defer(self) -> None:
        """Acknowledge the submission privately, inside Discord's three-second budget."""
        await self._interaction.response.defer(thinking=True, ephemeral=True)

    async def post(self, content: str) -> None:
        """Replace the acknowledgement with what the service made of the report.

        Args:
            content: The message content.
        """
        await self._interaction.edit_original_response(content=content, allowed_mentions=NO_MENTIONS)


class BugModal(discord.ui.Modal):
    """The five fields ``.github/ISSUE_TEMPLATE/bug_report.yml`` needs, and nothing more.

    Version and component are **not** asked. They come from the ``doctor`` block, or the issue says
    they are missing — asking a reporter for a version is how a report ends up saying "latest".
    """

    def __init__(self, intake: BugIntake, attachments: list[Incoming], logger: Logger) -> None:
        """Build the modal.

        Args:
            intake: What the submission is handed to.
            attachments: The files the command carried, already flattened.
            logger: Logger for a failure that escapes the handler.
        """
        super().__init__(title="Report a bug", timeout=None)
        self._intake = intake
        self._attachments = attachments
        self._logger = logger
        self.summary: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="In one line, what is wrong?",
            style=discord.TextStyle.short,
            max_length=SUMMARY_MAX_CHARS,
            required=True,
        )
        self.happened: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="What happened?",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
        )
        self.expected: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="What did you expect?",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
        )
        self.steps: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="Steps to reproduce",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
        )
        self.doctor: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="Paste the output of: veaf-tools doctor",
            style=discord.TextStyle.paragraph,
            max_length=DOCTOR_MAX_CHARS,
            required=False,
        )
        for item in (self.summary, self.happened, self.expected, self.steps, self.doctor):
            self.add_item(item)

    def submission(self, interaction: discord.Interaction) -> BugSubmission:
        """Turn the filled modal into what the intake consumes.

        Args:
            interaction: The submission interaction.

        Returns:
            The submission.
        """
        return BugSubmission(
            form=BugForm(
                summary=str(self.summary.value),
                happened=str(self.happened.value),
                expected=str(self.expected.value),
                steps=str(self.steps.value),
                doctor=str(self.doctor.value or ""),
                reporter=interaction.user.display_name,
                reporter_id=str(interaction.user.id),
                language=str(interaction.locale) if interaction.locale else "fr",
            ),
            attachments=self._attachments,
        )

    async def on_submit(self, interaction: discord.Interaction) -> None:
        """Run the deterministic pass over the submitted form.

        Args:
            interaction: The submission interaction.
        """
        await self._intake.handle(ModalExchange(interaction, self._logger), self.submission(interaction))

    # discord.py's `Modal.on_error` takes `(interaction, error)`; the `BaseView` it inherits from
    # takes a third `Item` argument, and that is the signature mypy resolves. Matching the base would
    # give the modal a handler the library never calls, so the narrower — correct — one is kept.
    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:  # type: ignore[override]
        """Log a failure the intake did not catch.

        The intake already turns everything past its own acknowledgement into a sentence, so
        reaching here means the failure happened before it — most often Discord refusing the defer.

        Args:
            interaction: The submission interaction.
            error: What went wrong.
        """
        self._logger.exception(
            "the /bug modal failed",
            extra={"event": "bug.modal_failed", "error": type(error).__name__},
        )


def incoming_from(*attachments: discord.Attachment | None) -> list[Incoming]:
    """Flatten the command's optional attachment options into what the collector reads.

    Args:
        *attachments: The options, any of which may be ``None``.

    Returns:
        The attachments that were actually supplied, in option order.
    """
    return [
        Incoming(
            filename=item.filename,
            url=item.url,
            size=int(item.size or 0),
            content_type=str(item.content_type or ""),
        )
        for item in attachments
        if item is not None
    ]


def register_bug_command(
    tree: app_commands.CommandTree,
    intake: BugIntake,
    logger: Logger,
    tasks: InFlightTasks | None = None,
) -> None:
    """Attach ``/bug`` to a command tree.

    Split out of the client for the same reason ``/ask``'s registration is: a handler that works and
    a command nobody attached is the shape of bug this repository has shipped green before.

    The attachments are **command options** rather than files dropped in a thread. Discord uploads
    them before the interaction exists, so no message intent is involved — see
    :mod:`veaf_support_bot.intake` for why that decision is not a convenience.

    Args:
        tree: The command tree to attach to.
        intake: The handler the command delegates to.
        logger: Logger for failures that escape the modal.
        tasks: Registry a shutdown drains. Unused by the command itself, which returns as soon as
            the modal is open; the modal's own submission is a separate interaction with its own
            fifteen-minute token, which ticket 04 tracks when it adds the click that files.
    """

    @tree.command(name="bug", description="Report a bug — a short form, and the files you have")
    @app_commands.describe(
        log="Your veaf-tools.log or dcs.log, if you have one",
        mission="The .miz the problem happens on",
        extra="Anything else: a mission.yaml, a configuration file",
    )
    async def bug(
        interaction: discord.Interaction,
        log: discord.Attachment | None = None,
        mission: discord.Attachment | None = None,
        extra: discord.Attachment | None = None,
    ) -> None:
        """Open the bug-report form.

        Sending the modal **is** the acknowledgement, so this never spends the three-second budget
        on anything else.

        Args:
            interaction: The invoking interaction.
            log: An optional log file.
            mission: An optional mission archive.
            extra: One more optional file.
        """
        modal = BugModal(intake, incoming_from(log, mission, extra), logger)
        await interaction.response.send_modal(modal)
