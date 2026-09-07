"""Continuing an ``/ask`` inside the thread it opened, by mentioning the bot.

An answer is rarely the end of the question. Before this, the only way to ask the next one was a
second ``/ask`` in the channel, retyping the context the thread already held — and David said so the
day the bot went up: *"quand on répond dans le fil ça ne repart pas au bot… c'est dommage"*.

## Why a mention, and not every message in the thread

Because Discord draws the line for us, and draws it in the right place. Reading message content is a
**privileged** intent this service asks for nowhere (``INTENTS = discord.Intents.none()``), and two
exceptions survive without it: content in a DM with the app, and **content in which the app is
mentioned**. So the gateway hands over the text of a message that names the bot and hands over an
empty ``content`` for every other message in the room.

*The bot cannot read what is not addressed to it* is therefore not a promise this module keeps. It is
a property of the connection, and no future edit of this file can break it.

## What is remembered, and why it is a file

A follow-up needs the question the thread was opened on and what has been said since. Reading it back
from Discord looks cheaper and does not work: without that same privileged intent, a fetched history
comes back with empty content for everything except the bot's own messages. So the service keeps its
own record — on the ``state`` volume, beside the quota counters and the relay links, because a
conversation must survive ``docker compose up -d --build``.

## The ellipsis

The Worker picks the documentation passages from the **last user turn only**, and a follow-up is
elliptical by nature: *"et si je veux créer une mission ? on a des modèles ?"* names neither the
tools nor the subject of the thread. Retrieval against that phrase alone lands on the wrong pages,
and the model — which does hold the context — then answers confidently over them, which reads as
*the bot got worse* rather than as *retrieval missed*.

:func:`retrieval_query` therefore builds that turn as the opening question joined to the follow-up,
the follow-up last and verbatim. The same turn is what the model reads, since the Worker uses one
list for both; separating them would mean a new field on ``/chat`` and a Worker deployment, and
asking a model to rewrite the query would spend a request of a free tier shared with the site and the
command line.
"""

from __future__ import annotations

import json
import re
import time
from collections.abc import Callable
from dataclasses import dataclass, field, replace
from logging import Logger
from pathlib import Path
from typing import Any

from veaf_support_bot import answer as answer_module
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.texts import DEFAULT_LANGUAGE, LANGUAGES
from veaf_support_bot.worker import MAX_QUESTION_CHARS

#: Version of the on-disk document. A file that does not carry it is ignored rather than guessed at.
THREADS_VERSION = 1

#: Turns kept per thread. The Worker trims the conversation it sends the model at twelve, so keeping
#: more grows a file on the state volume to feed a slice that is thrown away.
MAX_REMEMBERED_TURNS = 12

#: How long a thread stays continuable without being touched. Discord archives a thread long before
#: this; the bound is here so the file cannot grow for ever on a busy server, not to end a
#: conversation somebody is still having.
DEFAULT_MAX_AGE_SECONDS = 30 * 24 * 3600.0

#: What joins the opening question to the follow-up. A blank line, and no label: the text is embedded
#: for retrieval, and words like "previous question" would be embedded with it.
_JOIN = "\n\n"

#: A Discord user mention, in both the modern and the legacy nickname form.
_MENTION = re.compile(r"<@!?(\d+)>")


def strip_mentions(content: str, bot_id: str) -> str:
    """Remove the bot's own mention from a message, and normalise what is left.

    Only the bot's mention goes: another one is part of what the author wrote, and dropping it would
    change the sentence the model reads.

    Args:
        content: The raw message content.
        bot_id: The bot's user id, as a string.

    Returns:
        The question, whitespace collapsed. Empty when nothing but the mention was written — which
        the caller must treat as *no question*, never as an empty turn sent to the Worker.
    """
    without = _MENTION.sub(lambda match: "" if match.group(1) == bot_id else match.group(0), content)
    return " ".join(without.split())


def retrieval_query(opening: str, followup: str) -> str:
    """Build the last user turn: the thread's subject, then the question actually being asked.

    Args:
        opening: The question the thread was opened on.
        followup: The follow-up, verbatim.

    Returns:
        The joined text, bounded by :data:`~veaf_support_bot.worker.MAX_QUESTION_CHARS`. The ceiling
        cuts the **context** and never the follow-up: what is being asked now must reach the model
        whole, and it is also what the reader will compare the answer against.
    """
    asked = " ".join(followup.split())[:MAX_QUESTION_CHARS]
    subject = " ".join(opening.split())
    room = MAX_QUESTION_CHARS - len(asked) - len(_JOIN)
    if room <= 0:
        return asked
    return f"{subject[:room]}{_JOIN}{asked}"


@dataclass
class ThreadConversation:
    """One continuable thread.

    Attributes:
        thread_id: The Discord thread id.
        question: The question the thread was opened on, kept apart from the turns because it is
            what :func:`retrieval_query` widens a follow-up with, however long the thread grows.
        turns: The exchange so far, alternating ``user`` and ``assistant``, oldest first.
        lang: The language the thread was answered in. A follow-up arrives as a plain message and
            carries no locale of its own — Discord sends one with an *interaction*, not with a
            message — so without this a French thread would be continued in the default language on
            the first follow-up, or an English one abandoned to French.
        updated_at: When the last turn was recorded, as a Unix timestamp.
    """

    thread_id: str
    question: str
    turns: list[dict[str, str]] = field(default_factory=list)
    lang: str = DEFAULT_LANGUAGE
    updated_at: float = 0.0


def followup_turns(conversation: ThreadConversation, followup: str) -> list[dict[str, str]]:
    """Build the conversation sent to the Worker for one follow-up.

    Args:
        conversation: What the thread has said so far.
        followup: The follow-up, verbatim.

    Returns:
        The protocol instruction and its acknowledgement, then every turn exchanged in the thread,
        then the follow-up. The last turn is a user turn and carries no instruction: the Worker
        embeds it to retrieve passages, and an instruction in it would be embedded too.
    """
    protocol = answer_module.protocol_turns(conversation.question)[:2]
    turns = [*protocol, *conversation.turns]
    turns.append({"role": "user", "content": retrieval_query(conversation.question, followup)})
    return turns


class ThreadMemory:
    """Which threads are continuable, and what was said in them.

    A whole-file rewrite of a small JSON document, like the quota counters, the filing ledger and the
    relay links. Every failure degrades the *continuation* and nothing else: a record that cannot be
    read or written costs the follow-up, never the answer that is already on its way.
    """

    def __init__(
        self,
        path: Path,
        *,
        clock: Callable[[], float] | None = None,
        max_turns: int = MAX_REMEMBERED_TURNS,
        max_age_seconds: float = DEFAULT_MAX_AGE_SECONDS,
        logger: Logger | None = None,
    ) -> None:
        """Initialize the memory without touching the disk.

        Args:
            path: File the records are kept in.
            clock: Source of Unix timestamps; defaults to :func:`time.time`.
            max_turns: Turns kept per thread.
            max_age_seconds: How long an untouched thread stays continuable.
            logger: Logger for a store that cannot be read or written.
        """
        self.path = path
        self._clock: Callable[[], float] = clock or time.time
        self._max_turns = max_turns
        self._max_age = max_age_seconds
        self._logger = logger or get_logger("followup")
        self._threads: dict[str, ThreadConversation] | None = None

    def conversation(self, thread_id: str) -> ThreadConversation | None:
        """Return what a thread has said, when it is one this service opened and still remembers.

        Args:
            thread_id: The Discord thread id.

        Returns:
            The conversation, or ``None`` for a thread that is unknown, expired, or was opened by
            something other than ``/ask`` — a ``/bug`` thread among them, which belongs to the relay.
        """
        threads = self._loaded()
        conversation = threads.get(thread_id)
        if conversation is None:
            return None
        if self._expired(conversation, self._clock()):
            return None
        # A copy, not the live record. Two people can mention the bot in the same thread within a
        # second, and both exchanges would otherwise hold the same list: the first to finish appends
        # its question and answer to it, and the second sends a conversation carrying turns nobody
        # in it wrote — with two user turns in a row, which is not a shape the model reads.
        return replace(conversation, turns=[dict(turn) for turn in conversation.turns])

    def forgotten_language(self, thread_id: str) -> str | None:
        """Say whether a thread was continuable and is not any more.

        The difference from *unknown* is what the reader is told. A thread this service never opened
        — somebody else's, or a ``/bug`` thread, which belongs to the relay — is answered with
        nothing at all. One whose record has aged out gets a sentence, because the person mentioning
        the bot is following an invitation the bot itself wrote, and silence there reads as a
        breakage.

        Args:
            thread_id: The Discord thread id.

        Returns:
            The language that thread was answered in, when a record exists for it and has expired.
            ``None`` when there is no record at all — the case that stays silent.
        """
        conversation = self._loaded().get(thread_id)
        if conversation is None or not self._expired(conversation, self._clock()):
            return None
        return conversation.lang

    def remember(self, thread_id: str, question: str, answer: str, lang: str = DEFAULT_LANGUAGE) -> bool:
        """Record one exchange, opening the thread's record when it is the first.

        Args:
            thread_id: The Discord thread id.
            question: What was asked — the opening question for a new thread, the follow-up after.
            answer: What the bot replied.
            lang: The language it was answered in, kept so a follow-up is answered in the same one.

        Returns:
            Whether it reached the disk. The caller needs this rather than a log line: it is what
            decides whether the answer may invite a follow-up, and an invitation over a record that
            was never written leads the reader into silence.
        """
        threads = self._loaded()
        now = self._clock()
        conversation = threads.get(thread_id)
        if conversation is None or self._expired(conversation, now):
            conversation = ThreadConversation(thread_id=thread_id, question=question, lang=lang)
            threads[thread_id] = conversation
        conversation.turns.append({"role": "user", "content": question})
        conversation.turns.append({"role": "assistant", "content": answer})
        # Kept as whole exchanges: dropping a lone user turn would leave the model reading an answer
        # to a question it cannot see.
        excess = len(conversation.turns) - self._max_turns
        if excess > 0:
            conversation.turns = conversation.turns[excess + (excess % 2) :]
        conversation.updated_at = now
        for stale in [key for key, value in threads.items() if self._expired(value, now)]:
            del threads[stale]
        return self._save(threads)

    def _expired(self, conversation: ThreadConversation, now: float) -> bool:
        """Say whether a record is too old to continue.

        Args:
            conversation: The record.
            now: The current Unix timestamp.

        Returns:
            Whether it has aged past the ceiling.
        """
        return now - conversation.updated_at > self._max_age

    def _loaded(self) -> dict[str, ThreadConversation]:
        """Return the records, reading the file once.

        Returns:
            The records by thread id. An unreadable or unrecognised file yields an empty mapping and
            a warning: the follow-up is a convenience on top of an answer that was already given.
        """
        if self._threads is None:
            self._threads = self._read()
        return self._threads

    def _read(self) -> dict[str, ThreadConversation]:
        """Read the document.

        Returns:
            The records by thread id, empty when the file is absent, unreadable or of an unknown
            version.
        """
        if not self.path.exists():
            return {}
        try:
            document = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            self._logger.warning(
                "the thread records could not be read",
                extra={"event": "followup.unreadable", "path": str(self.path), "error": str(error)},
            )
            return {}
        if not isinstance(document, dict) or document.get("version") != THREADS_VERSION:
            self._logger.warning(
                "the thread records are of an unknown version and were ignored",
                extra={"event": "followup.version", "path": str(self.path)},
            )
            return {}
        entries = document.get("threads")
        if not isinstance(entries, list):
            return {}
        threads: dict[str, ThreadConversation] = {}
        for entry in entries:
            conversation = _conversation_of(entry)
            if conversation is not None:
                threads[conversation.thread_id] = conversation
        return threads

    def _save(self, threads: dict[str, ThreadConversation]) -> bool:
        """Write every record out.

        Args:
            threads: The records to persist.

        Returns:
            Whether the file was written.
        """
        document = {
            "version": THREADS_VERSION,
            "threads": [
                {
                    "thread_id": conversation.thread_id,
                    "question": conversation.question,
                    "turns": conversation.turns,
                    "lang": conversation.lang,
                    "updated_at": conversation.updated_at,
                }
                for conversation in threads.values()
            ],
        }
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(document, indent=2), encoding="utf-8")
        except (OSError, ValueError) as error:
            self._logger.warning(
                "the thread records could not be written",
                extra={"event": "followup.unwritable", "path": str(self.path), "error": str(error)},
            )
            return False
        return True


def _conversation_of(entry: Any) -> ThreadConversation | None:
    """Turn one persisted entry into a record.

    Args:
        entry: The decoded entry.

    Returns:
        The record, or ``None`` when the entry is not shaped like one. A single bad entry is skipped
        rather than failing the file: the others are conversations somebody is still having.
    """
    if not isinstance(entry, dict):
        return None
    thread_id = entry.get("thread_id")
    question = entry.get("question")
    if not isinstance(thread_id, str) or not isinstance(question, str):
        return None
    turns: list[dict[str, str]] = []
    for turn in entry.get("turns", []):
        if not isinstance(turn, dict):
            continue
        role = turn.get("role")
        content = turn.get("content")
        if role in {"user", "assistant"} and isinstance(content, str):
            turns.append({"role": role, "content": content})
    updated_at = entry.get("updated_at")
    lang = entry.get("lang")
    return ThreadConversation(
        thread_id=thread_id,
        question=question,
        turns=turns,
        lang=lang if isinstance(lang, str) and lang in LANGUAGES else DEFAULT_LANGUAGE,
        updated_at=float(updated_at) if isinstance(updated_at, (int, float)) else 0.0,
    )
