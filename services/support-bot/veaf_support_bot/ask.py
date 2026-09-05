"""The ``/ask`` exchange, written against a narrow protocol rather than against ``discord.py``.

Everything the command does to Discord goes through :class:`Exchange`: defer, open a thread, post,
edit. :mod:`veaf_support_bot.discord_bot` implements it over the real library; the tests implement
it over a recorder. That split is deliberate — the bugs this lot can ship are in the *order* of
those calls, and asserting on the order needs the order to be observable.

## The order, and why each step is where it is

1. **Defer first, before anything else.** Discord closes the interaction after three seconds. Every
   later step — the quota check included — happens after the acknowledgement, so a slow disk or a
   slow Worker can never turn into "the application did not respond".
2. **Quota, then the thread.** A refused question opens no thread: the refusal is for one person,
   and a thread per refusal would bury the channel.
3. **The acknowledgement becomes the question message**, and the thread is opened from it. The
   channel shows who asked what; the answer lives inside, so the channel stays readable and the
   answer has a durable home the next person can find.
4. **Edit as it streams.** A placeholder, then edits at a bounded rate, then the final message with
   its sources and its caveat.

## The failure that has no thread

Opening a thread needs a permission the bot may not have. Losing the answer to that would be the
worst outcome, so a thread failure is reported and the answer is posted where the question was
asked. The exchange degrades; it does not vanish.

## Nothing gets past the defer without answering

Once the interaction is deferred, Discord shows "the bot is thinking" until something edits the
response. So every step after the defer runs under one guard: an exception that nobody expected —
Discord answering 500 to an ``announce``, a future text key that is not there, a bug in ``render`` —
becomes a sentence rather than a placeholder that never resolves. The gateway's own handler only
logs, so a failure that escapes here is one nobody in the thread ever sees.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Callable
from dataclasses import dataclass
from logging import Logger
from typing import Any, Protocol

from veaf_support_bot import answer as answer_module
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.quota import QuotaDecision, QuotaKeeper
from veaf_support_bot.texts import normalize_language, text
from veaf_support_bot.worker import MAX_QUESTION_CHARS, FailureKind, WorkerClient, WorkerFailure

#: Shortest gap between two edits of the streaming message. Discord allows about five message edits
#: per five seconds per channel; anything faster buys no smoothness and spends the budget the final
#: edit needs.
MIN_EDIT_INTERVAL_SECONDS = 1.5

#: Characters that must have arrived since the last edit before another one is worth making.
MIN_EDIT_CHARS = 120


class Exchange(Protocol):
    """What :func:`handle_ask` needs from Discord, and nothing more."""

    async def defer(self) -> None:
        """Acknowledge the interaction so Discord stops counting to three seconds."""

    async def announce(self, content: str) -> None:
        """Turn the deferred acknowledgement into the visible question message.

        This is the message the thread hangs off, so the channel shows the question and the answer
        lives inside — which is what keeps the channel readable.

        Args:
            content: The question line.
        """

    async def open_thread(self, name: str) -> bool:
        """Open a public thread on the question and post subsequent messages inside it.

        Args:
            name: The thread name.

        Returns:
            ``True`` when the thread exists; ``False`` when it could not be opened, in which case
            the answer is posted where the question was asked.
        """

    async def post(self, content: str) -> None:
        """Post the first message of the answer.

        Args:
            content: The message content.
        """

    async def edit(self, content: str) -> None:
        """Replace the content of the message :meth:`post` created.

        Args:
            content: The new content.
        """


@dataclass
class AskContext:
    """Everything about one question that does not come from Discord's API.

    Attributes:
        user_id: The asker's Discord id, which is the quota subject.
        user_display: How to name the asker in the thread's opening line.
        question: The question, verbatim.
        locale: The locale Discord reported, or ``None``.
    """

    user_id: str
    user_display: str
    question: str
    locale: str | None = None


def discord_timestamp(moment: float, style: str) -> str:
    """Render a Unix timestamp as Discord's own timestamp markup.

    Every reader sees it in their own timezone, which a server-rendered clock time cannot do — and
    the VEAF Discord spans several.

    Args:
        moment: Unix timestamp.
        style: Discord style letter, ``"R"`` for relative and ``"t"`` for a short time.

    Returns:
        The markup, e.g. ``"<t:1757030400:R>"``.
    """
    return f"<t:{int(moment)}:{style}>"


def quota_message(decision: QuotaDecision, lang: str) -> str:
    """Render a refusal as the sentence the user reads.

    Args:
        decision: The refusing decision.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The sentence, naming the ceiling and when it lifts.

    Raises:
        ValueError: When the decision does not actually refuse. A refusal message under an allowed
            question would be a silent behaviour change, so it is an error rather than a blank.
    """
    if decision.allowed or decision.reason is None:
        raise ValueError("quota_message called on an allowed decision")
    reset = decision.reset_at if decision.reset_at is not None else time.time()
    return text(
        f"quota.{decision.reason}",
        lang,
        limit=decision.limit,
        reset_relative=discord_timestamp(reset, "R"),
        reset_time=discord_timestamp(reset, "t"),
    )


class AskHandler:
    """Runs one ``/ask`` exchange from the acknowledgement to the final edit."""

    def __init__(
        self,
        worker: WorkerClient,
        quota: QuotaKeeper,
        *,
        clock: Callable[[], float] | None = None,
        logger: Logger | None = None,
        min_edit_interval: float = MIN_EDIT_INTERVAL_SECONDS,
        min_edit_chars: int = MIN_EDIT_CHARS,
    ) -> None:
        """Initialize the handler.

        Args:
            worker: The documentation chatbot client.
            quota: The per-user counters.
            clock: Source of monotonic-ish timestamps for the edit pacing; defaults to
                :func:`time.monotonic`.
            logger: Logger to use; defaults to the service's ``ask`` logger.
            min_edit_interval: Shortest gap between two intermediate edits.
            min_edit_chars: Characters that must have arrived to justify an intermediate edit.
        """
        self._worker = worker
        self._quota = quota
        self._clock: Callable[[], float] = clock or time.monotonic
        self._logger = logger or get_logger("ask")
        self._min_edit_interval = min_edit_interval
        self._min_edit_chars = min_edit_chars

    async def handle(self, exchange: Exchange, context: AskContext) -> None:
        """Answer one question, and answer it even when something unexpected goes wrong.

        Args:
            exchange: The Discord side of the conversation.
            context: The question and who asked it.
        """
        lang = normalize_language(context.locale)
        # Discord's own option limit is generous; retrieval is not. Trimmed here rather than only in
        # the command declaration, so the bound holds whatever a future caller of this handler is.
        context.question = " ".join(context.question.split())[:MAX_QUESTION_CHARS]

        # Step 1, before anything that can be slow. Discord gives three seconds; a quota store on a
        # busy disk plus a Worker round trip is not a budget to gamble.
        await exchange.defer()

        try:
            await self._answer(exchange, context, lang)
        except Exception as error:
            # Past the defer, an escaping exception is not "an error nobody handled": it is a reader
            # left on a placeholder until the interaction token dies fifteen minutes later. The
            # gateway's default handler writes a log line and touches the interaction never again.
            self._logger.exception(
                "the /ask exchange failed after the acknowledgement",
                extra={"event": "ask.crashed", "user": context.user_id, "error": type(error).__name__},
            )
            await self._apologize(exchange, lang)

    async def _apologize(self, exchange: Exchange, lang: str) -> None:
        """Put a sentence where the placeholder is, best effort.

        :meth:`Exchange.edit` falls back to posting when nothing has been posted yet, so this reaches
        the reader wherever the exchange stopped. Its own failure is swallowed: there is nothing
        left to try, and raising here would replace one silent failure with the same one.

        Args:
            exchange: The Discord side of the conversation.
            lang: ``"fr"`` or ``"en"``.
        """
        try:
            await exchange.edit(text("ask.error.unexpected", lang))
        except Exception as error:  # noqa: BLE001 - the last resort cannot have a resort of its own
            self._logger.error(
                "could not even tell the reader the exchange failed",
                extra={"event": "ask.apology_failed", "error": type(error).__name__},
            )

    async def _answer(self, exchange: Exchange, context: AskContext, lang: str) -> None:
        """Run the exchange, from the quota decision to the final edit.

        Args:
            exchange: The Discord side of the conversation.
            context: The question and who asked it.
            lang: ``"fr"`` or ``"en"``.
        """
        decision = self._quota.check_and_consume(context.user_id)
        if not decision.allowed:
            self._logger.info(
                "question refused by the quota",
                extra={
                    "event": "ask.refused",
                    "user": context.user_id,
                    "reason": decision.reason,
                    "limit": decision.limit,
                },
            )
            await exchange.announce(quota_message(decision, lang))
            return

        await exchange.announce(text("ask.header", lang, user=context.user_display, question=context.question))
        opened = await exchange.open_thread(answer_module.thread_name(context.question))
        await exchange.post(text("ask.thinking", lang) if opened else text("ask.error.no_thread", lang))

        collected, failure = await self._collect(exchange, context, lang)
        if failure is not None:
            self._logger.warning(
                "the documentation assistant returned no answer",
                extra={
                    "event": "ask.failed",
                    "user": context.user_id,
                    "kind": failure.kind.value,
                    "detail": failure.detail,
                },
            )
            await exchange.edit(text(f"ask.error.{failure.kind.value}", lang))
            return

        body, titles = answer_module.split_sources(collected)
        links = answer_module.source_links(titles, lang)
        await exchange.edit(answer_module.render(body, links, lang))
        self._logger.info(
            "question answered",
            extra={
                "event": "ask.answered",
                "user": context.user_id,
                "lang": lang,
                "threaded": opened,
                "answer_chars": len(body),
                "declared_sources": len(titles),
                "linked_sources": len(links),
            },
        )

    async def _collect(self, exchange: Exchange, context: AskContext, lang: str) -> tuple[str, WorkerFailure | None]:
        """Stream the answer in, editing the message as it grows.

        Args:
            exchange: The Discord side of the conversation.
            context: The question and who asked it.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            ``(text collected so far, failure or None)``. A failure that arrives **after** some text
            has already been shown is still a failure: a half answer edited over with a caveat-less
            body would look complete, which is the one thing an answer must not do when it is not.
        """
        collected: list[str] = []
        size = 0
        last_edit = self._clock()
        last_size = 0
        messages = answer_module.protocol_turns(context.question)
        budget = self._worker.timeout
        try:
            # The budget belongs here rather than only inside the client: aiohttp's own total timer
            # is consulted while it waits on the socket, never while *this* loop awaits a Discord
            # edit — and a rate-limited edit is exactly what discord.py sleeps through. Without this
            # the loop can outlive the fifteen minutes a deferred interaction token gets, and the
            # answer is then lost with the reader still on the placeholder.
            async with asyncio.timeout(budget):
                async for fragment in self._worker.stream(messages, lang, context.user_id):
                    collected.append(fragment)
                    size += len(fragment)
                    now = self._clock()
                    if size - last_size >= self._min_edit_chars and now - last_edit >= self._min_edit_interval:
                        last_size = size
                        await exchange.edit(answer_module.render_partial("".join(collected), lang))
                        # Stamped *after* the edit, not before: an edit that takes longer than the
                        # interval would otherwise satisfy the gate the moment it returned, so the
                        # throttle would stop throttling precisely while Discord is pushing back.
                        last_edit = self._clock()
        except WorkerFailure as failure:
            return "".join(collected), failure
        except TimeoutError:
            return "".join(collected), WorkerFailure(FailureKind.TIMEOUT, f"the exchange exceeded {budget}s")
        return "".join(collected), None


def build_handler(config: Any, quota: QuotaKeeper, **kwargs: Any) -> AskHandler:
    """Build the handler from a resolved configuration.

    Args:
        config: The :class:`~veaf_support_bot.config.SupportBotConfig` in force.
        quota: The per-user counters.
        **kwargs: Passed through to :class:`AskHandler`, so a test can inject a clock.

    Returns:
        The handler.
    """
    worker = WorkerClient(config.worker_endpoint, config.worker_client, config.worker_secret)
    return AskHandler(worker, quota, **kwargs)
