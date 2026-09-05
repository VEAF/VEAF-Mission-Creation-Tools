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

#: Marker the model is asked to put on the last line of its answer. Uppercase ASCII in both
#: languages on purpose: a localized marker would have to be matched in two spellings, and the model
#: translates a French instruction's keyword often enough to matter.
SOURCES_MARKER: Final = "SOURCES:"

#: Separator between declared titles. A comma is not usable — documentation titles contain them.
SOURCES_SEPARATOR: Final = "|"

#: Most sources rendered. The Worker retrieves six passages, which can span six pages; more than
#: this in one footer stops being a citation and becomes a wall.
MAX_SOURCES: Final = 5

_SOURCES_LINE_RE: Final = re.compile(rf"^\s*{SOURCES_MARKER}(?P<titles>.*)$", re.IGNORECASE | re.MULTILINE)

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


def protocol_turns(question: str) -> list[dict[str, str]]:
    """Build the conversation sent to the Worker for one question.

    Args:
        question: The user's question, verbatim.

    Returns:
        Three turns: the protocol instruction, the model's acknowledgement, and the question. The
        question is last and untouched, which is what keeps the Worker's retrieval query clean.
    """
    return [
        {"role": "user", "content": _PROTOCOL},
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
        title = raw.strip().strip("`*_")
        if title and title not in seen:
            seen.append(title)
    return body, seen


def source_links(titles: Iterable[str], lang: str) -> list[str]:
    """Turn declared titles into Markdown links, dropping the ones the corpus does not have.

    Args:
        titles: The titles the model declared.
        lang: ``"fr"`` or ``"en"``; a title is only looked up in the asker's own corpus.

    Returns:
        Markdown links, at most :data:`MAX_SOURCES` of them, in the order declared. A title with no
        matching page yields nothing at all — never a guess, and never a bare title, which would
        read as a source the reader cannot check.
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
        links.append(f"[{title}]({url})")
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
    trimmed = body.strip()
    if len(trimmed) > room:
        notice = text("ask.truncated", lang)
        trimmed = trimmed[: max(room - len(notice) - 1, 0)].rstrip() + "…\n" + notice
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
