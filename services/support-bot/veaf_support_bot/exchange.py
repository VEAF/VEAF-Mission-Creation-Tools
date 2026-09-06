"""The seam between a flow and Discord: what a flow may ask of a conversation, and nothing more.

Both flows — the ``/bug`` intake and the ``/suggest`` one — need the same six gestures: acknowledge,
say something, put a draft to a vote, put a proposal to a yes-or-no, open a public thread and post
into it. They are declared here rather than in either flow, so the second one to be written does not
copy a protocol out of the first: two copies of a seam drift, and the drift shows up as a flow that
silently stops asking for consent.

Written as a narrow protocol on purpose. Asserting on the *order* of the steps — sweep, show, file —
needs the order to be observable without a Discord connection, which is what
``tests/test_intake.py`` and ``tests/test_suggest.py`` both do against a recording stand-in.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


class ThreadExchange(Protocol):
    """What a flow needs from Discord, and nothing more."""

    async def defer(self) -> None:
        """Acknowledge the modal submission, inside Discord's three-second budget."""

    async def post(self, content: str) -> None:
        """Show the person what the service made of his report.

        Args:
            content: The message content.
        """

    async def decide(self, content: str, lang: str) -> str:
        """Show the draft and return what the person chose to do with it.

        This is the step that publishes, or does not. It lives on the exchange rather than on the
        service because the buttons hang off *this* reporter's own message: a consent object built
        once at start-up would have nowhere to draw them.

        Args:
            content: The draft, rendered and bounded.
            lang: ``"fr"`` or ``"en"``, for the button labels.

        Returns:
            One of :data:`~veaf_support_bot.draft.CHOICES`. Anything that is not
            :data:`~veaf_support_bot.draft.FILE` leaves the tracker untouched, so a silence, a
            refusal and a Discord failure are all safe answers.
        """

    async def confirm(self, content: str, lang: str) -> bool:
        """Show a prior-art match with its evidence and return whether the person recognised it.

        Args:
            content: The proposal, with the evidence it was computed from.
            lang: ``"fr"`` or ``"en"``, for the button labels.

        Returns:
            ``True`` only when he says it is the same subject. Everything else — *mine is
            different*, a silence, a failure — answers ``False`` and the report carries on, because
            a machine's unanswered guess must never silence a real bug.
        """

    async def open_followup_thread(self, name: str) -> ThreadHandle:
        """Open the public thread the issue's news will come back into.

        The exchange itself is ephemeral: the preparation concerns the reporter and nobody else.
        What is public is the report, once he has decided to file it — and it needs a room a
        maintainer's answer can be carried into, because the issue is filed under a machine account
        the reporter is subscribed to nothing on.

        Args:
            name: The thread name.

        Returns:
            Where it was opened. An empty handle means no thread could be opened — a missing
            permission, a channel that holds none — and the report is filed anyway, saying the
            thread was not recorded rather than inventing a link.
        """

    async def post_in_thread(self, handle: ThreadHandle, content: str) -> None:
        """Post the opening message once the issue exists and can be linked to.

        Args:
            handle: The thread opened by :meth:`open_followup_thread`.
            content: What to post.
        """


@dataclass(frozen=True)
class ThreadHandle:
    """Where a report's follow-up thread lives, or nothing.

    Attributes:
        channel_id: The channel it belongs to. Kept alongside the thread id so a restart can reach
            it without a warm Discord cache.
        thread_id: The thread.
        url: Its address, which is what the issue links back to.
        handle: The library object the thread was opened from, kept so posting into it needs no
            cache lookup. The bot runs on ``Intents.none()``, so a freshly created thread is
            routinely absent from the cache: resolving it by id right after creating it is a
            silent way to lose the message that carries the issue's address.
    """

    channel_id: int = 0
    thread_id: int = 0
    url: str = ""
    handle: object | None = None

    @property
    def opened(self) -> bool:
        """Say whether there is a thread to answer in.

        Returns:
            ``True`` when one was opened.
        """
        return self.thread_id > 0
