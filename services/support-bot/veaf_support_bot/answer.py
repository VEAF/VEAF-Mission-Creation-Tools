"""Assembling what the bot posts: the protocol that gets sources, and the message that shows them.

An answer with no source is a claim. The Worker cannot tell the service which passages it used
(:mod:`veaf_support_bot.doc_pages` explains why), so the service asks the **model** — the only party
that knows — to end its answer with the titles of the excerpts it drew on, and then validates every
declared title against the real ``doc/`` tree.

The protocol turn is sent as a *prior* turn, never appended to the question. The Worker embeds the
last user message verbatim to retrieve passages (``latestQuery`` in ``poc/doc-chatbot/worker``), so
appending instructions to the question would poison the retrieval query with them — the answer would
degrade to buy the sources, which is the wrong trade.

What can still go wrong, and why it is safe: the model may forget the trailer. Then no source is
shown, the reader gets the "no page was cited" line and a route to the support page. Under-citing
reads as a documentation gap; over-citing would be a fabricated reference. The bad direction is the
one that cannot happen here.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Sequence
from typing import Final

from veaf_support_bot.doc_pages import resolve_title
from veaf_support_bot.texts import support_page_url, text

#: Longest content a Discord message can carry.
DISCORD_MESSAGE_LIMIT: Final = 2000

#: Longest name a Discord thread can carry.
DISCORD_THREAD_NAME_LIMIT: Final = 100

#: Keyword the model is asked to put on the last line of its answer. Uppercase ASCII in both
#: languages on purpose: a localized marker would have to be matched in two spellings, and the model
#: translates a French instruction's keyword often enough to matter.
SOURCES_KEYWORD: Final = "SOURCES"

#: The marker as the instruction shows it, keyword and colon.
SOURCES_MARKER: Final = f"{SOURCES_KEYWORD}:"

#: Separator between declared titles. A comma is not usable — documentation titles contain them.
SOURCES_SEPARATOR: Final = "|"

#: Most sources rendered. The Worker retrieves six passages, which can span six pages; more than
#: this in one footer stops being a citation and becomes a wall.
MAX_SOURCES: Final = 5

#: Longest link label. The label is the title the **model** typed, and nothing upstream bounds it:
#: :func:`~veaf_support_bot.doc_pages.normalize_title` only strips decoration from the ends, so
#: ``"Le build" + "." * 500`` still resolves and would be echoed whole. Five of those rendered a
#: 3299-character message, which Discord refuses — and the refusal is swallowed, so the reader is
#: left on the placeholder with no answer and no error. The longest real French title is 79
#: characters, so this cuts nothing the corpus actually has.
MAX_SOURCE_LABEL_CHARS: Final = 100

#: Decoration the model puts around a title, or around the trailer itself. Stripped from both ends
#: of every declared title, in any order, so ``**`Le build`**`` and ``` `Le build`, ``` both resolve.
_TITLE_TRIM: Final = " \t`*_"

#: What may sit between the keyword and its colon: the decoration above, plus every horizontal space
#: French typography puts before a colon — the ordinary one, the no-break, the narrow no-break and
#: the thin space a word processor or a model substitutes for it.
_MARKER_GAP: Final = " \t\u00a0\u202f\u2009`*_"

#: What may sit before the keyword: the same, plus a bullet, a heading marker and a quote marker.
_MARKER_LEAD: Final = _MARKER_GAP + "#>-"

#: Matches the trailer, tolerating the reformattings a model actually produces.
#:
#: Only the exact ``SOURCES:`` at the start of a line used to be accepted, which failed twice over on
#: any wobble: the raw protocol line stayed in the body the reader sees **and** every citation was
#: lost, so a correctly sourced answer displayed "no page was cited". Two of those wobbles are
#: invited by this module itself — the instruction shows the marker inside backticks, so a model
#: copying the form it was shown writes ``` `SOURCES: ...` ```; and the bot answers in French, where
#: typography puts a space before a colon. Bold, a heading marker, a quote and a bullet cost nothing
#: more to accept, and neither does a full-width colon.
#:
#: The direction that matters stays safe: a title the corpus does not have is still dropped, so a
#: looser trailer cannot invent a source.
_SOURCES_LINE_RE: Final = re.compile(
    rf"^[{re.escape(_MARKER_LEAD)}]*{SOURCES_KEYWORD}[{re.escape(_MARKER_GAP)}]*[:：∶](?P<titles>.*)$",
    re.IGNORECASE | re.MULTILINE,
)

_PROTOCOL: Final = (
    "For every answer in this conversation, finish with one final line, on its own, in exactly this "
    f"form: `{SOURCES_MARKER} <title>{SOURCES_SEPARATOR} <title>`. Each `<title>` is the heading of a "
    "documentation excerpt you actually used, copied exactly as it appears at the top of that "
    f"excerpt. Separate several titles with `{SOURCES_SEPARATOR}`. Never invent a title, and never "
    f"list one you did not use. If you used none, write `{SOURCES_MARKER}` and nothing after it. "
    "Write this line even when you answer that the documentation does not cover the question. "
    "Everything before that line is the answer, written normally for the reader."
)

_PROTOCOL_ACK: Final = "Understood. I will end every answer with that line."


def protocol_turns(question: str, *, extra: str = "") -> list[dict[str, str]]:
    """Build the conversation sent to the Worker for one question.

    Args:
        question: The user's question, verbatim.
        extra: A further instruction for callers asking something other than a plain question —
            :mod:`veaf_support_bot.existing` asks whether a feature already exists. It joins the
            instruction turn rather than the question, because the Worker embeds the last user turn
            to retrieve passages and instructions in it would poison the retrieval.

    Returns:
        Three turns: the protocol instruction, the model's acknowledgement, and the question. The
        question is last and untouched, which is what keeps the Worker's retrieval query clean.
    """
    instruction = f"{extra}\n\n{_PROTOCOL}" if extra else _PROTOCOL
    return [
        {"role": "user", "content": instruction},
        {"role": "assistant", "content": _PROTOCOL_ACK},
        {"role": "user", "content": question},
    ]


def split_sources(answer: str) -> tuple[str, list[str]]:
    """Separate the answer body from the trailer of declared titles.

    Args:
        answer: The full text the model produced.

    Returns:
        ``(body, titles)``. The body has the trailer removed and is stripped; *titles* holds the
        declared titles in order, with duplicates and blanks removed. Both are empty-safe: an answer
        with no trailer returns itself and an empty list.
    """
    matches = list(_SOURCES_LINE_RE.finditer(answer))
    if not matches:
        return answer.strip(), []
    # The last one: an answer that quotes the protocol back before obeying it would otherwise have
    # its own explanation read as the trailer.
    last = matches[-1]
    body = (answer[: last.start()] + answer[last.end() :]).strip()
    seen: list[str] = []
    for raw in last.group("titles").split(SOURCES_SEPARATOR):
        # One pass over both sets, not whitespace then decoration: `` **Le build** `` leaves a
        # leading space behind when the two are stripped in sequence.
        title = raw.strip(_TITLE_TRIM)
        if title and title not in seen:
            seen.append(title)
    return body, seen


def source_links(titles: Iterable[str], lang: str) -> list[str]:
    """Turn declared titles into Markdown links, dropping the ones the corpus does not have.

    Args:
        titles: The titles the model declared.
        lang: ``"fr"`` or ``"en"``; a title is only looked up in the asker's own corpus.

    Returns:
        Markdown links, at most :data:`MAX_SOURCES` of them, in the order declared, each label capped
        at :data:`MAX_SOURCE_LABEL_CHARS`. A title with no matching page yields nothing at all —
        never a guess, and never a bare title, which would read as a source the reader cannot check.
    """
    links: list[str] = []
    seen: set[str] = set()
    for title in titles:
        url = resolve_title(title, lang)
        # Two different titles can resolve to the same page — the model retypes headings, and `#
        # Getting help` reached twice is one source, not two.
        if url is None or url in seen:
            continue
        seen.add(url)
        # The URL comes from the corpus and is bounded by it; the label does not, so it is the label
        # that is cut. That is what keeps the footer a size :func:`render` can reserve room for.
        label = title if len(title) <= MAX_SOURCE_LABEL_CHARS else title[: MAX_SOURCE_LABEL_CHARS - 1].rstrip() + "…"
        links.append(f"[{label}]({url})")
        if len(links) == MAX_SOURCES:
            break
    return links


def thread_name(question: str) -> str:
    """Build the name of the thread a question opens.

    Args:
        question: The user's question.

    Returns:
        A name within Discord's limit, never empty — Discord refuses a blank thread name, and a
        question made only of punctuation would produce one.
    """
    topic = " ".join(question.split()) or "?"
    budget = DISCORD_THREAD_NAME_LIMIT - len(text("ask.thread_name", "en", topic=""))
    if len(topic) > budget:
        topic = topic[: max(budget - 1, 1)].rstrip() + "…"
    return text("ask.thread_name", "en", topic=topic)


def render(body: str, links: Sequence[str], lang: str) -> str:
    """Assemble the message posted in the thread.

    Args:
        body: The answer text, trailer already removed.
        links: Markdown links to the pages cited, possibly none.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message content, within :data:`DISCORD_MESSAGE_LIMIT`. The footer — sources and the
        "may be wrong" note — is never what gets cut: it is reserved before the body is truncated,
        because an answer that loses its caveat is worse than one that loses its last sentence.
    """
    footer = (
        text("ask.sources", lang, links=" · ".join(links))
        if links
        else text("ask.no_sources", lang, support_url=support_page_url(lang))
    )
    footer = f"{footer}\n{text('ask.disclaimer', lang)}"

    room = DISCORD_MESSAGE_LIMIT - len(footer) - 2
    if room <= 0:
        # The footer alone fills the message. Nothing of the body can be shown, and the promise
        # above still holds: sources and caveat are what must survive. Unreachable while labels are
        # capped, and kept so the bound is a property of the code rather than of the corpus.
        return footer[:DISCORD_MESSAGE_LIMIT]
    trimmed = body.strip()
    if len(trimmed) > room:
        notice = text("ask.truncated", lang)
        # Two characters reserved, not one: the ellipsis *and* the newline before the notice.
        trimmed = trimmed[: max(room - len(notice) - 2, 0)].rstrip() + "…\n" + notice
    return f"{trimmed}\n\n{footer}" if trimmed else footer


def render_partial(body: str, lang: str) -> str:
    """Assemble the placeholder shown while the answer is still streaming in.

    Args:
        body: What has arrived so far, possibly empty.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message content for an intermediate edit. No sources and no disclaimer: neither is known
        yet, and showing a disclaimer under a half-written answer invites the reader to act on it.
    """
    partial = split_sources(body)[0].strip()
    if not partial:
        return text("ask.thinking", lang)
    marker = " " + text("ask.streaming", lang)
    room = DISCORD_MESSAGE_LIMIT - len(marker)
    if len(partial) > room:
        partial = partial[: room - 1].rstrip() + "…"
    return partial + marker
