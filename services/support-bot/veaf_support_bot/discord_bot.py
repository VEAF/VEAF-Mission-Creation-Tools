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

from collections.abc import Awaitable, Callable
from logging import Logger
from typing import Any, cast

import discord
from discord import app_commands

from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.attachments import Incoming
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.draft import (
    CANCEL,
    DRAFT_EXPIRY_SECONDS,
    EDIT,
    EXPIRED,
    FILE,
    MATCH_EXPIRY_SECONDS,
)
from veaf_support_bot.health import ServiceState
from veaf_support_bot.intake import (
    DOCTOR_MAX_CHARS,
    PARAGRAPH_MAX_CHARS,
    SUMMARY_MAX_CHARS,
    BugIntake,
    BugSubmission,
    ThreadHandle,
    escalation_form,
)
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.service import InFlightTasks
from veaf_support_bot.texts import text

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

#: The two answers to a prior-art proposal. Local to this module: the protocol they implement
#: speaks in booleans, so nothing outside needs to name them.
_SAME = "same"
_DIFFERENT = "different"

#: How long the escalation button stays on an answer. It sits on a public message that nobody is
#: waiting on, so it is measured in "while the thread is still being read" rather than in the
#: interaction budget the draft's buttons live inside.
ESCALATION_EXPIRY_SECONDS = 3600

#: Longest thread name Discord accepts.
THREAD_NAME_CEILING = 100

#: Channel kinds a public follow-up thread can hang off. A thread, a forum post and a direct
#: message cannot, and the report is then filed without a follow-up rather than not filed. Named
#: rather than inlined so a test can stand in front of the one branch that matters here.
THREADABLE: tuple[type, ...] = (discord.TextChannel,)

#: Prefix added to a followed thread's name once its issue is closed, so the state is visible
#: in the channel list without opening anything.
CLOSED_MARK = "✅ "


class InteractionExchange:
    """The :class:`~veaf_support_bot.ask.Exchange` protocol over a real Discord interaction."""

    def __init__(
        self,
        interaction: discord.Interaction,
        logger: Logger | None = None,
        *,
        intake: BugIntake | None = None,
        tasks: InFlightTasks | None = None,
    ) -> None:
        """Initialize the exchange.

        Args:
            interaction: The interaction the command was invoked with.
            logger: Logger to use; defaults to the service's ``discord`` logger.
            intake: What an escalation hands its form to. ``None`` — a deployment with no checkout,
                where ``/bug`` is not published either — leaves the offer out rather than showing a
                button that leads nowhere.
            tasks: Registry a shutdown drains, passed on to the escalated report's own modal.
        """
        self._interaction = interaction
        self._logger = logger or get_logger("discord")
        self._intake = intake
        self._tasks = tasks
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

    async def offer_escalation(self, question: str, answer: str, lang: str) -> None:
        """Attach a *Report a bug* button to the answer, carrying the exchange into the form.

        Never raises: the answer is already posted by the time this runs, and losing it to a failure
        while adding a button would trade the thing that worked for the thing that did not.

        Args:
            question: What was asked.
            answer: What the bot replied.
            lang: ``"fr"`` or ``"en"``.
        """
        if self._intake is None or self._message is None:
            return
        view = _EscalationView(
            label=text("escalate.button", lang),
            open_form=self._escalation_opener(self._intake, question, answer, lang),
            logger=self._logger,
        )
        try:
            view.message = await self._message.edit(view=view, allowed_mentions=NO_MENTIONS)
        except discord.HTTPException as error:
            self._logger.warning(
                "could not offer the escalation button",
                extra={"event": "ask.escalation_failed", "error": type(error).__name__},
            )

    def _escalation_opener(
        self, intake: BugIntake, question: str, answer: str, lang: str
    ) -> Callable[[discord.Interaction], Awaitable[None]]:
        """Build what the escalation button does when pressed.

        Args:
            intake: What the escalated report is handed to, passed in rather than read back off
                the exchange so the closure cannot outlive the check that it exists.
            question: What was asked.
            answer: What the bot replied.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            A coroutine function opening the report form, pre-filled with the exchange.
        """

        async def open_form(click: discord.Interaction) -> None:
            """Open the report form on the asker's own click.

            Args:
                click: The click, which is the interaction the modal must answer.
            """
            prefill = escalation_form(
                question,
                answer,
                reporter=click.user.display_name,
                reporter_id=str(click.user.id),
                language=lang,
            )
            await click.response.send_modal(BugModal(intake, [], self._logger, prefill=prefill, tasks=self._tasks))

        return open_form


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
        register_commands(self.tree, handler, self._logger, tasks, intake)
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
    intake: BugIntake | None = None,
) -> None:
    """Attach ``/ask`` to a command tree.

    Split out of the client so the registration itself is testable: a handler that works and a
    command nobody attached is exactly the shape of bug this repository has shipped green before.

    Args:
        tree: The command tree to attach to.
        handler: The handler the command delegates to.
        logger: Logger for failures that escape the handler.
        tasks: Registry a shutdown drains; the exchange is run as a tracked task when given.
        intake: What an unsatisfying answer escalates to. ``None`` leaves the offer out — the same
            deployment where ``/bug`` is not published at all.
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
        exchange = InteractionExchange(interaction, logger, intake=intake, tasks=tasks)
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

    Ephemeral throughout. The preparation is a private step: it says what the service read and what
    it could not, which concerns the reporter and nobody else. What becomes public is the issue, and
    it is opened only when the button below is pressed.

    The two questions — *is this your bug already reported?* and *does this go?* — are asked on the
    reporter's own message, one after the other, and both are bounded in time. Their timeouts add up
    to less than the fifteen minutes Discord keeps the interaction token alive, because the last
    thing this exchange does is write the answer onto that same message.
    """

    def __init__(
        self,
        interaction: discord.Interaction,
        reopen: Callable[[discord.Interaction], Awaitable[None]] | None = None,
        logger: Logger | None = None,
    ) -> None:
        """Initialize the exchange.

        Args:
            interaction: The modal submission interaction.
            reopen: What the *Edit* button does — opens the form again, on the button's own
                interaction. ``None`` leaves the button out, which is what an escalation with no
                form behind it needs.
            logger: Logger to use; defaults to the service's ``discord`` logger.
        """
        self._interaction = interaction
        self._reopen = reopen
        self._logger = logger or get_logger("discord")

    async def defer(self) -> None:
        """Acknowledge the submission privately, inside Discord's three-second budget."""
        await self._interaction.response.defer(thinking=True, ephemeral=True)

    async def post(self, content: str) -> None:
        """Replace the acknowledgement with what the service made of the report.

        The buttons are cleared with it: a message that still offers *File the issue* after the
        issue was filed is an invitation to file it twice.

        Args:
            content: The message content.
        """
        await self._interaction.edit_original_response(content=content, view=None, allowed_mentions=NO_MENTIONS)

    async def open_followup_thread(self, name: str) -> ThreadHandle:
        """Open the public thread the issue's news will come back into.

        A thread cannot hang off an ephemeral response, so this posts a short public anchor in the
        channel and threads off it. That anchor is the *only* thing `/bug` makes public on its own:
        the report itself is on the issue, and the preparation stays in the reporter's ephemeral
        message.

        Args:
            name: The thread name.

        Returns:
            Where it was opened, or an empty handle when Discord refused — most often a missing
            *Create Public Threads*, or a channel that cannot hold threads. The report is filed
            either way; what is lost is the follow-up.
        """
        raw = self._interaction.channel
        if not isinstance(raw, THREADABLE):
            # A thread, a forum post, a DM: nothing to hang a public thread off. Reported rather
            # than raised, because it must not cost the report.
            self._logger.warning(
                "no follow-up thread: the command was not used in a text channel",
                extra={"event": "bug.thread_channel", "channel": type(raw).__name__},
            )
            return ThreadHandle()
        # THREADABLE is the runtime check — named so a test can stand in front of this one branch —
        # and this is the same statement for the type checker, which cannot read a tuple built at
        # module scope.
        channel = cast(discord.TextChannel, raw)
        try:
            anchor = await channel.send(name, allowed_mentions=NO_MENTIONS)
            thread = await anchor.create_thread(name=name[:THREAD_NAME_CEILING])
        except (discord.HTTPException, discord.ClientException) as error:
            self._logger.warning(
                "no follow-up thread could be opened",
                extra={"event": "bug.thread_failed", "error": f"{type(error).__name__}: {error}"},
            )
            return ThreadHandle()
        return ThreadHandle(channel_id=channel.id, thread_id=thread.id, url=thread.jump_url, handle=thread)

    async def post_in_thread(self, handle: ThreadHandle, content: str) -> None:
        """Post the opening message inside the follow-up thread.

        Args:
            handle: The thread that was opened.
            content: What to post.
        """
        thread = handle.handle if handle.handle is not None else self._interaction.client.get_channel(handle.thread_id)
        if not hasattr(thread, "send"):
            # Nothing to post through. Said out loud rather than skipped: the reporter would
            # otherwise be left with a public thread and no idea which issue it belongs to.
            self._logger.warning(
                "the follow-up thread could not be reached to announce the issue",
                extra={"event": "bug.thread_unreachable", "discord_thread": handle.thread_id},
            )
            return
        try:
            await thread.send(content, allowed_mentions=NO_MENTIONS)
        except discord.HTTPException as error:
            self._logger.warning(
                "the follow-up thread could not be opened with a message",
                extra={"event": "bug.thread_message_failed", "error": type(error).__name__},
            )

    async def decide(self, content: str, lang: str) -> str:
        """Show the draft with its buttons and wait for one to be pressed.

        Args:
            content: The draft, rendered and bounded.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            One of :data:`~veaf_support_bot.draft.CHOICES`. A silence returns
            :data:`~veaf_support_bot.draft.EXPIRED` and a Discord failure returns
            :data:`~veaf_support_bot.draft.CANCEL` — both leave the tracker untouched, which is the
            only safe way for this step to fail.
        """
        view = _ChoiceView(default=EXPIRED, timeout=DRAFT_EXPIRY_SECONDS)
        view.add_item(_ChoiceButton(FILE, text("draft.button.file", lang), discord.ButtonStyle.success))
        if self._reopen is not None:
            view.add_item(_EditButton(text("draft.button.edit", lang), self._reopen))
        view.add_item(_ChoiceButton(CANCEL, text("draft.button.cancel", lang), discord.ButtonStyle.secondary))
        return await self._ask(content, view, on_failure=CANCEL, event="bug.draft_failed")

    async def confirm(self, content: str, lang: str) -> bool:
        """Show a prior-art match with its evidence and wait for the reporter's answer.

        Args:
            content: The proposal, with its evidence.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            ``True`` only when he pressed *yes, that is it*. A silence, a refusal and a Discord
            failure all answer ``False``, and the report carries on being filed: a machine's
            unanswered guess must never silence a real bug.
        """
        view = _ChoiceView(default=_DIFFERENT, timeout=MATCH_EXPIRY_SECONDS)
        view.add_item(_ChoiceButton(_SAME, text("match.button.same", lang), discord.ButtonStyle.primary))
        view.add_item(_ChoiceButton(_DIFFERENT, text("match.button.different", lang), discord.ButtonStyle.secondary))
        answer = await self._ask(content, view, on_failure=_DIFFERENT, event="bug.match_failed")
        return answer == _SAME

    async def _ask(self, content: str, view: _ChoiceView, *, on_failure: str, event: str) -> str:
        """Put one question on the reporter's message and wait for it to be answered.

        Args:
            content: What the question says.
            view: The buttons, and what a silence means.
            on_failure: The answer to return when Discord refuses to show the question at all.
            event: Log event for that refusal.

        Returns:
            The answer.
        """
        try:
            await self._interaction.edit_original_response(content=content, view=view, allowed_mentions=NO_MENTIONS)
        except discord.HTTPException as error:
            self._logger.warning(
                "the question could not be shown, so its safe answer is used",
                extra={"event": event, "error": type(error).__name__, "answer": on_failure},
            )
            return on_failure
        await view.wait()
        return view.choice


class _ChoiceButton(discord.ui.Button["_ChoiceView"]):
    """A button that records one answer and ends the wait.

    Args:
        choice: What clicking it means.
        label: What it says.
        style: How it looks.
    """

    def __init__(self, choice: str, label: str, style: discord.ButtonStyle) -> None:
        super().__init__(label=label, style=style)
        self.choice = choice

    async def callback(self, interaction: discord.Interaction) -> None:
        """Record the answer, acknowledge the click, and release the waiter.

        The acknowledgement is a deferred update rather than a message: what the reporter is told
        next is written by the intake onto the *original* response, and a second message here would
        say it twice.

        Args:
            interaction: The click.
        """
        view = self.view
        if view is not None:
            view.choose(self.choice)
        await interaction.response.defer()


class _ChoiceView(discord.ui.View):
    """One question, its buttons, and the answer nobody gave.

    The message these hang off is **ephemeral**, so only the reporter can see it and only he can
    click: there is no second person to guard against. What has to be guarded is time — a view whose
    timeout fires without a click leaves :attr:`choice` at whatever the caller decided a silence
    means, which is never "publish".

    Attributes:
        choice: The answer, or the default the caller built it with.
    """

    def __init__(self, *, default: str, timeout: float) -> None:
        """Initialize the view.

        Args:
            default: The answer a silence produces.
            timeout: Seconds before the silence is final.
        """
        super().__init__(timeout=timeout)
        self.choice = default

    def choose(self, choice: str) -> None:
        """Record an answer and stop waiting.

        Args:
            choice: The answer.
        """
        self.choice = choice
        self.stop()


class _EditButton(discord.ui.Button["_ChoiceView"]):
    """The button that reopens the form instead of answering with a message.

    Opening a modal has to be the *first* response to the interaction that opened it, so this button
    cannot defer first the way the others do.

    Args:
        label: What it says.
        reopen: What actually opens the form.
    """

    def __init__(self, label: str, reopen: Callable[[discord.Interaction], Awaitable[None]]) -> None:
        super().__init__(label=label, style=discord.ButtonStyle.primary)
        self._reopen = reopen

    async def callback(self, interaction: discord.Interaction) -> None:
        """Reopen the form, then end the wait.

        Args:
            interaction: The click.
        """
        await self._reopen(interaction)
        view = self.view
        if view is not None:
            view.choose(EDIT)


class _EscalationView(discord.ui.View):
    """The *Report a bug* button that hangs off an answer, until it stops being offered.

    Unlike the draft's buttons, this one sits on a **public** message that outlives the exchange, so
    it has to clean up after itself: when the view expires the button is removed rather than left
    to answer a click with *this interaction failed*.

    Attributes:
        message: The message the button is attached to, so the timeout can take it off.
    """

    def __init__(
        self,
        *,
        label: str,
        open_form: Callable[[discord.Interaction], Awaitable[None]],
        logger: Logger,
    ) -> None:
        """Initialize the view.

        Args:
            label: What the button says.
            open_form: What pressing it does.
            logger: Logger for a failed clean-up.
        """
        super().__init__(timeout=ESCALATION_EXPIRY_SECONDS)
        self.message: discord.Message | None = None
        self._logger = logger
        self.add_item(_EscalateButton(label, open_form))

    async def on_timeout(self) -> None:
        """Take the button off the answer once it is no longer live."""
        if self.message is None:
            return
        try:
            await self.message.edit(view=None)
        except discord.HTTPException as error:
            self._logger.warning(
                "could not remove the escalation button",
                extra={"event": "ask.escalation_cleanup_failed", "error": type(error).__name__},
            )


class _EscalateButton(discord.ui.Button["_EscalationView"]):
    """The button that opens the report form on the asker's own click.

    Args:
        label: What it says.
        open_form: What pressing it does.
    """

    def __init__(self, label: str, open_form: Callable[[discord.Interaction], Awaitable[None]]) -> None:
        super().__init__(label=label, style=discord.ButtonStyle.secondary, emoji="🐞")
        self._open_form = open_form

    async def callback(self, interaction: discord.Interaction) -> None:
        """Open the form.

        The button stays on the message: a second reader of the same thread may want it too, and
        the answer is public.

        Args:
            interaction: The click.
        """
        await self._open_form(interaction)


class BugModal(discord.ui.Modal):
    """The five fields ``.github/ISSUE_TEMPLATE/bug_report.yml`` needs, and nothing more.

    Version and component are **not** asked. They come from the ``doctor`` block, or the issue says
    they are missing — asking a reporter for a version is how a report ends up saying "latest".
    """

    def __init__(
        self,
        intake: BugIntake,
        attachments: list[Incoming],
        logger: Logger,
        *,
        prefill: BugForm | None = None,
        tasks: InFlightTasks | None = None,
    ) -> None:
        """Build the modal.

        Args:
            intake: What the submission is handed to.
            attachments: The files the command carried, already flattened.
            logger: Logger for a failure that escapes the handler.
            prefill: Answers to open the form with — what *Edit* gives back to the reporter, and
                what an escalation from ``/ask`` carries in. A reporter who has to retype four
                fields to fix a typo in one does not fix the typo.
            tasks: Registry a shutdown drains. The submission is its own interaction, living for
                fifteen minutes across two questions, so it is the one that has to be tracked.
        """
        super().__init__(title="Report a bug", timeout=None)
        self._intake = intake
        self._attachments = attachments
        self._logger = logger
        self._tasks = tasks
        self.summary: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="In one line, what is wrong?",
            style=discord.TextStyle.short,
            max_length=SUMMARY_MAX_CHARS,
            required=True,
            default=prefill.summary if prefill else None,
        )
        self.happened: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="What happened?",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
            default=prefill.happened if prefill else None,
        )
        self.expected: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="What did you expect?",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
            default=prefill.expected if prefill else None,
        )
        self.steps: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="Steps to reproduce",
            style=discord.TextStyle.paragraph,
            max_length=PARAGRAPH_MAX_CHARS,
            required=True,
            default=prefill.steps if prefill else None,
        )
        self.doctor: discord.ui.TextInput[BugModal] = discord.ui.TextInput(
            label="Paste the output of: veaf-tools doctor",
            style=discord.TextStyle.paragraph,
            max_length=DOCTOR_MAX_CHARS,
            required=False,
            default=prefill.doctor if prefill else None,
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
            roles=role_ids_of(interaction.user),
        )

    async def on_submit(self, interaction: discord.Interaction) -> None:
        """Run the deterministic pass, then ask the reporter what to do with what it produced.

        Args:
            interaction: The submission interaction.
        """
        submission = self.submission(interaction)

        async def reopen(click: discord.Interaction) -> None:
            """Give the form back, with his answers still in it.

            Args:
                click: The *Edit* click, which is the interaction the modal must answer.
            """
            await click.response.send_modal(
                BugModal(
                    self._intake,
                    self._attachments,
                    self._logger,
                    prefill=submission.form,
                    tasks=self._tasks,
                )
            )

        exchange = ModalExchange(interaction, reopen, self._logger)
        running = self._intake.handle(exchange, submission)
        if self._tasks is None:
            await running
        else:
            # Awaited, not fired and forgotten: a shutdown must wait for the last message rather
            # than leave the reporter on a draft whose buttons answer nobody.
            await self._tasks.track(running, name=f"bug:{submission.form.reporter_id}")

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


class ClientThreadPoster:
    """The :class:`~veaf_support_bot.relay.ThreadPoster` protocol over the gateway connection.

    The relay runs in a background task with no interaction of its own, so it reaches Discord
    through the client. A thread the cache does not hold is fetched once — the bot runs on
    ``Intents.none()``, so the cache is cold after every restart, and a relay that only worked on
    warm state would go quiet exactly when the service came back up.
    """

    def __init__(self, client: discord.Client, logger: Logger | None = None) -> None:
        """Initialize the poster.

        Args:
            client: The connected gateway client.
            logger: Logger to use.
        """
        self._client = client
        self._logger = logger or get_logger("relay")

    async def _thread(self, thread_id: int) -> discord.Thread | None:
        """Resolve one thread, from the cache or from the API.

        Args:
            thread_id: The thread.

        Returns:
            The thread, or ``None`` only when Discord says it does not exist.

        Raises:
            discord.HTTPException: Discord could not answer *this time* — a 5xx, a rate limit, a
                permission lost for a moment. The distinction matters more than it looks: the relay
                reads ``None`` as **the thread is gone for good** and drops the link, so folding a
                503 into it would stop following a report for ever, on every link, the first time
                Discord had a bad minute after a restart. Raising leaves the link alone and the
                round counts a failure.
        """
        cached = self._client.get_channel(thread_id)
        if isinstance(cached, discord.Thread):
            return cached
        try:
            fetched = await self._client.fetch_channel(thread_id)
        except discord.NotFound:
            self._logger.info(
                "a followed thread no longer exists",
                extra={"event": "relay.thread_gone", "discord_thread": thread_id},
            )
            return None
        except (discord.HTTPException, discord.ClientException) as error:
            self._logger.warning(
                "a followed thread could not be resolved this round",
                extra={"event": "relay.thread_unreachable", "discord_thread": thread_id, "error": type(error).__name__},
            )
            raise
        return fetched if isinstance(fetched, discord.Thread) else None

    async def post_to_thread(self, channel_id: int, thread_id: int, content: str) -> bool:
        """Post one message into a followed thread.

        Args:
            channel_id: The channel the thread belongs to, unused here and kept by the store so a
                restart can reach the thread without a warm cache.
            thread_id: The thread.
            content: What to post.

        Returns:
            ``True`` when it was posted; ``False`` when the thread is gone for good, which is the
            one answer that makes the relay stop following that report.
        """
        thread = await self._thread(thread_id)
        if thread is None:
            return False
        try:
            # An archived thread accepts a message and un-archives itself, so no special case is
            # needed for one — only for one that no longer exists.
            await thread.send(content, allowed_mentions=NO_MENTIONS)
        except discord.NotFound:
            return False
        except discord.HTTPException as error:
            self._logger.warning(
                "a relayed message was refused",
                extra={"event": "relay.refused", "discord_thread": thread_id, "error": type(error).__name__},
            )
            # Transient: raised so the relay counts a failure and tries again, rather than dropping
            # a link because Discord was rate-limiting.
            raise
        return True

    async def mark_closed(self, channel_id: int, thread_id: int) -> bool:
        """Tag the thread as settled once its issue is closed.

        Args:
            channel_id: The channel the thread belongs to.
            thread_id: The thread.

        Returns:
            Whether the tag was applied. Cosmetic: the closure is also said in words, so a refusal
            here never fails a round.
        """
        try:
            thread = await self._thread(thread_id)
        except (discord.HTTPException, discord.ClientException):
            # Cosmetic, and the closure is also said in words: a refusal here never fails a round.
            return False
        if thread is None:
            return False
        name = thread.name if thread.name.startswith(CLOSED_MARK) else f"{CLOSED_MARK}{thread.name}"
        try:
            await thread.edit(name=name[:THREAD_NAME_CEILING], archived=True)
        except (discord.HTTPException, discord.ClientException) as error:
            self._logger.info(
                "the thread could not be marked as closed",
                extra={"event": "relay.mark_failed", "discord_thread": thread_id, "error": type(error).__name__},
            )
            return False
        return True


def role_ids_of(user: object) -> tuple[str, ...]:
    """Return the role ids the interaction says its author holds.

    Read off the interaction rather than fetched: Discord sends the member object — role ids
    included — inside every guild interaction, so the check costs no API call and cannot be forged
    by the reporter.

    Which attribute carries them is not a detail. ``Member.roles`` resolves each id against the
    **guild cache** and silently drops what it cannot find, and this bot runs on
    ``Intents.none()`` — no guild intent, so that cache can be empty. Reading ``roles`` alone would
    therefore hand back an empty tuple on a perfectly ordinary member, and the enrichment gate would
    refuse every reporter forever while looking like it was working. ``Member._roles`` is the raw
    list from the payload, which is what the interaction actually stated; ``roles`` stays as the
    fallback for anything that exposes only the resolved form.

    Args:
        user: The interaction's author.

    Returns:
        The role ids as strings, matching the configured id's own type.
    """
    raw = getattr(user, "_roles", None)
    if raw is not None:
        return tuple(str(int(role_id)) for role_id in raw)
    return tuple(str(role.id) for role in getattr(user, "roles", ()) if getattr(role, "id", None) is not None)


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
        tasks: Registry a shutdown drains. The command itself returns as soon as the modal is
            open and has nothing to track; what is tracked is the modal's **submission**, a separate
            interaction with its own fifteen-minute token that now spans two questions and a
            filing — so the modal is handed the registry rather than the command.
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
        modal = BugModal(intake, incoming_from(log, mission, extra), logger, tasks=tasks)
        await interaction.response.send_modal(modal)
