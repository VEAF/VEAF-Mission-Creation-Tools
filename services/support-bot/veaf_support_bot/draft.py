"""The issue as it will be filed, shown to the reporter, and the answer he gives.

Ticket 04. Everything before this module is preparation: the form, the ``doctor`` block, the log
excerpt, the located ``file:line``, the prior-art sweep. This is where the reporter sees what all of
that became **before** it reaches a public tracker, and says whether it goes.

## Why the draft is the issue and not a summary

The reporter typed three fields; twenty lines get published. The log excerpt, the extracted code and
the environment are material he never wrote, filed under a machine account that does not carry his
name. So what he is shown is the body :mod:`~veaf_support_bot.filing` will send — the same string,
built once — rather than a friendly recap of it. A recap would be a second implementation, and the
one thing it could never prove is that the issue says what the preview said.

## Truncation is announced, never silent

Discord accepts 2000 characters and a GitHub issue accepts 60 000, so a real report does not fit.
Cutting it quietly would make the preview a lie precisely where it matters — the long parts are the
ones he did not write. :func:`fold` cuts on a line boundary, closes a fenced block it had to cut
through, and returns what it left out so the message can say so.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Final

from veaf_support_bot.texts import text
from veaf_support_bot.untrusted import one_line

#: The reporter files the issue.
FILE: Final = "file"

#: The reporter reopens the form: nothing is filed, and the modal comes back with his answers.
EDIT: Final = "edit"

#: The reporter drops the report. Nothing is filed, and nothing is kept.
CANCEL: Final = "cancel"

#: Nobody answered in time. Same effect as :data:`CANCEL`, and the reporter is told which it was —
#: an abandoned draft turning into an issue days later is the failure this value exists to prevent.
EXPIRED: Final = "expired"

#: Every answer :meth:`~veaf_support_bot.intake.BugExchange.decide` may return.
CHOICES: Final = (FILE, EDIT, CANCEL, EXPIRED)

#: Longest draft message posted back. Discord's own ceiling is 2000 characters; the margin carries
#: the truncation notice, which must fit *after* the cut has been decided.
DRAFT_MAX_CHARS: Final = 1900

#: How long a draft waits for a click, and how long the prior-art proposal waits before it. Both
#: fit inside **one** interaction token, which Discord expires after fifteen minutes: an expiry the
#: service can no longer announce is an expiry nobody learns about, and the reporter would be left
#: on a preview that never resolves. Five plus eight leaves two minutes to write the last message.
MATCH_EXPIRY_SECONDS: Final = 300
DRAFT_EXPIRY_SECONDS: Final = 480

#: Longest title shown in the draft header. The issue keeps its own; this is the preview line.
TITLE_MAX_CHARS: Final = 200

#: The fence a Markdown code block opens and closes with.
_FENCE: Final = "```"


@dataclass(frozen=True)
class Draft:
    """One issue, rendered and waiting for a click.

    Attributes:
        title: The issue title, exactly as it will be created.
        body: The issue body, exactly as it will be sent — not a summary of it.
    """

    title: str
    body: str

    def render(self, lang: str, *, limit: int = DRAFT_MAX_CHARS, header: str = "draft.header") -> str:
        """Render the draft as one Discord message, saying what it had to leave out.

        Args:
            lang: ``"fr"`` or ``"en"``.
            limit: Longest message to produce.
            header: Catalogue key of the opening line. A comment added to an existing issue is a
                different act from opening one, and a preview calling it "the issue as it will be
                filed" would misdescribe what the reporter is agreeing to.

        Returns:
            The message.
        """
        opening = text(header, lang) + "\n" + text("draft.title", lang, title=one_line(self.title, TITLE_MAX_CHARS))
        # The notice is measured before the cut rather than after: a body folded to exactly the
        # remaining room, then given a notice, would overshoot the ceiling by the notice's length.
        notice = text("draft.truncated", lang, lines=9999, chars=999999)
        budget = limit - len(opening) - len("\n\n") - len(notice) - len("\n\n")
        kept, lines, chars = fold(self.body, max(budget, 0))
        parts = [opening, kept]
        if chars:
            parts.append(text("draft.truncated", lang, lines=lines, chars=chars))
        return "\n\n".join(parts)


def fold(body: str, budget: int) -> tuple[str, int, int]:
    """Cut a body down to *budget* characters on a line boundary, and say what was left.

    Args:
        body: The issue body.
        budget: The room available.

    Returns:
        A triple of what is kept, how many lines were dropped, and how many characters.
    """
    if len(body) <= budget:
        return body, 0, 0
    cut = body[:budget]
    # Prefer a whole line: a body cut mid-sentence reads as corruption rather than as an excerpt,
    # and the reader cannot tell which of the two he is looking at.
    boundary = cut.rfind("\n")
    if boundary > 0:
        cut = cut[:boundary]
    dropped = body[len(cut) :]
    return _close_fence(cut), dropped.count("\n"), len(dropped)


def _close_fence(chunk: str) -> str:
    """Close a fenced code block the cut opened, so the rest of the message still renders.

    Args:
        chunk: The kept part of the body.

    Returns:
        The chunk, with a closing fence appended when it needs one.
    """
    if chunk.count(_FENCE) % 2 == 0:
        return chunk
    return chunk.rstrip("\n") + "\n" + _FENCE
