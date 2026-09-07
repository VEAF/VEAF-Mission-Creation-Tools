"""Does the product already do this? The documentation is **asked**, not searched.

A large share of feature requests are documentation gaps wearing a costume: the thing exists, the
user did not find it. Answering *"it is there, here is the page"* serves him on the spot and keeps
the tracker clean — so the check has to come before anything is drafted.

## Why this is not the text matching :mod:`veaf_support_bot.priorart` does

That module compares a bug report against prior bug reports: two texts of the same kind, whose
discriminating words are identifiers the reporter pasted — ``veafSpawn.lua``, ``KeyError``,
``FEAT-SUPPORT-BUG-INTAKE``. A suggestion written in ordinary language has none of those, and the
corpus it would be compared against is the whole documentation, where the words naming a feature are
everywhere. Measured on the real tree, 144 pages:

| word | pages containing it | pages with it in a heading |
|---|---|---|
| ``csar`` | 24 (17%) | 6 |
| ``combat`` | 69 (48%) | 20 |
| ``zone`` | 87 (60%) | 20 |

No threshold separates *the page describing CSAR* from *the twenty-four pages mentioning CSAR*,
because the documentation cross-references itself: that is what makes it good documentation. Three
successive attempts at scoring it were measured and thrown away — rarity weighting still matched a
request for SMS alerts against the support page, on ``bot`` and ``serveur``, at 57%. A wrong *"it
already exists"* silences a real idea, and the user will not argue with a bot.

## What is asked instead

The question *"does the documentation describe a way to do this?"* is the question ``/ask`` already
answers, from the same corpus, with its sources and under its quota. So this module asks it — one
exchange with the Worker, the request itself as the retrieval query, an answer that either explains
how to do the thing or says the documentation is silent.

Two consequences worth stating plainly:

* the check **costs a model call**, which the lot's PRD said it would not. That constraint was
  written before the corpus was measured, and it is incompatible with the goal stated beside it;
* the machine never concludes on its own. It shows the answer and its pages, and the person who
  asked says whether that is what he meant. What he answers is recorded either way — a *"no, that
  is not it"* on an answer the documentation gave is worth reading later.

Everything the Worker returns is data. Nothing in it selects a code path; the body is shown and the
declared titles are looked up in the real tree, so a title the corpus does not have is dropped
rather than linked. See :mod:`veaf_support_bot.untrusted`.
"""

from __future__ import annotations

import re
from collections.abc import AsyncIterator, Mapping, Sequence
from dataclasses import dataclass
from logging import Logger
from typing import Protocol

from veaf_support_bot import answer as answer_module
from veaf_support_bot.ask import MAX_QUESTION_CHARS
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.untrusted import one_line
from veaf_support_bot.worker import WorkerFailure

#: The documentation describes a way to do it.
EXISTS = "exists"

#: The documentation says nothing about it.
ABSENT = "absent"

#: The documentation could not be consulted at all — the Worker was down, the quota was spent, the
#: answer came back empty. Deliberately not the same as :data:`ABSENT`: *"the documentation does not
#: mention it"* is a finding, *"nobody could ask"* is a missing step, and an issue that confuses the
#: two tells its reader the documentation was checked when it was not.
UNKNOWN = "unknown"

#: What the model is told to answer when the documentation does not cover the request. Uppercase
#: ASCII in both languages, for the reason :data:`~veaf_support_bot.answer.SOURCES_KEYWORD` is: a
#: localized keyword would have to be matched in two spellings, and the model translates the
#: keyword of a French instruction often enough to matter.
NOTHING_KEYWORD = "NOTHING"

#: Decoration to strip before comparing a body to the keyword.
_NOTHING_TRIM = " \t\n`*_\"'«»“”.,;:!?()[]"

#: Longest answer carried into the thread and into the issue. Discord's own ceiling is 2000
#: characters for a whole message, and this one shares it with the question and the links.
ANSWER_MAX_CHARS = 1200

#: The task the model is given, sent as a *prior* turn so the request itself stays the retrieval
#: query — appending instructions to the request would poison the search with them, see
#: :func:`veaf_support_bot.answer.protocol_turns`.
#:
#: Deliberately **not** named ``_PROTOCOL``: :mod:`veaf_support_bot.answer` has a constant of that
#: name carrying a different instruction — the one asking for the sources trailer — and this is
#: passed to it as ``extra``. A reviewer reading two identically named constants concluded the
#: protocol was being sent twice, which it is not: the two texts are joined, and dropping either
#: would cost this check its task or its citations.
_TASK = (
    "The user is about to describe a feature he would like to see. Your only task is to say whether "
    "the documentation already describes a way to do it. If it does, answer by explaining how, "
    "briefly, for a reader who looked and did not find it. If the documentation does not describe a "
    f"way to do it, answer with exactly `{NOTHING_KEYWORD}` and nothing else. Never describe a "
    "feature the documentation does not describe, and never guess at one that might exist."
)

#: The second question, asked in the **same** call — measured 2026-09-07: ten open issues, short
#: titles, the whole list under 600 characters, so joining them costs on the order of 200 tokens and
#: no second model call at all.
#:
#: Why a model is asked this when a word matcher already sweeps the tracker: two people writing the
#: same request share no identifier, only ordinary words. The tracker proves it — ``#240 -cap un peu
#: plus selectif``, ``#187 Modifications du watchdog de CAP``, ``#178 Gérer la destruction du -cap``
#: are one subject in three vocabularies, and somebody writing *"je voudrais que la CAP arrête de
#: tirer sur les pilotes en parachute"* may share no word with any of them while a human reader sees
#: the connection instantly.
#:
#: The answer is a **line**, not prose to interpret: an unparsable answer is simply no match, and a
#: number that is not one of the numbers offered is discarded rather than trusted.
_ISSUE_TASK = (
    "\n\nSecond, and separately: here are the issues currently open on the tracker. If the user's "
    "request is one of them — the same need, however differently worded — end your whole answer "
    "with a final line reading exactly `{marker} #<number>`, using one of the numbers below. If it "
    "is none of them, do not write that line at all. Never invent a number, and never name an issue "
    "that is not in this list.\n\n{issues}"
)

#: Longest issue title carried into the prompt. A title is a line, not a paragraph.
ISSUE_TITLE_MAX_CHARS = 120

#: The marker that final line carries. Uppercase and unpunctuated, like the absence keyword above.
ISSUE_KEYWORD = "ISSUE"

#: How many open issues travel with the request. The tracker held ten when this was measured; the
#: bound is here so a tracker that grows to two hundred does not quietly turn one prompt into a
#: paste the retrieval cannot carry.
MAX_ISSUES_OFFERED = 40

#: A final line naming one issue, with the decoration a model puts around it.
_ISSUE_LINE = re.compile(rf"^[\s>*_`-]*{ISSUE_KEYWORD}[\s:]*#(\d+)[\s.`*_]*$", re.MULTILINE | re.IGNORECASE)


@dataclass(frozen=True)
class DocumentationCheck:
    """What the documentation answered about one request.

    Nothing here has been acted on: :attr:`verdict` is a finding, and whether it settles the request
    is the asker's to say.

    Attributes:
        verdict: :data:`EXISTS`, :data:`ABSENT` or :data:`UNKNOWN`.
        answer: What the documentation assistant answered, bounded. Empty unless the verdict is
            :data:`EXISTS`.
        links: The documentation pages it cited, as Markdown links, already validated against the
            real tree.
        problem: Why the documentation could not be consulted. Empty unless the verdict is
            :data:`UNKNOWN`.
        issue: An open issue the model recognised as the same request, or ``0``. Independent of
            :attr:`verdict`: the documentation being silent and the tracker already holding the
            request are different facts, and a request can be both undocumented and already asked.
        issue_title: That issue's title, and :attr:`issue_url` its address. They are **the
            evidence**: a proposal a reader cannot judge without opening GitHub is an assertion, and
            an assertion is what silences a real request. Carried here rather than looked up again by
            the flow, which would mean a second call to the tracker for something already in hand.
        issue_url: Where to read it.
    """

    verdict: str = UNKNOWN
    answer: str = ""
    links: tuple[str, ...] = ()
    problem: str = ""
    issue: int = 0
    issue_title: str = ""
    issue_url: str = ""

    @property
    def found(self) -> bool:
        """Say whether there is an answer to put to the asker.

        Returns:
            ``True`` when the documentation described a way to do it.
        """
        return self.verdict == EXISTS

    def describe(self) -> str:
        """Render one line saying what the documentation was asked and what it said.

        Recorded in the issue, so a reader three months later does not redo the search — and so the
        difference between *the documentation is silent* and *the documentation was not consulted*
        survives into the tracker.

        Returns:
            A sentence, never empty.
        """
        if self.verdict == EXISTS:
            pages = f" It cited: {', '.join(self.links)}." if self.links else " It cited no page."
            return f"The documentation was asked whether this already exists, and it answered.{pages}"
        if self.verdict == ABSENT:
            return "The documentation was asked whether this already exists; it says nothing about it."
        reason = f" ({self.problem})" if self.problem else ""
        return f"The documentation could not be asked whether this already exists{reason}."


class DocumentationWorker(Protocol):
    """What this check needs from the Worker client, and nothing more.

    A protocol rather than :class:`~veaf_support_bot.worker.WorkerClient` itself, for the reason
    every other seam in this service is one: the tests drive it with a scripted stand-in, and a
    stand-in that has to *be* the client is a stand-in that carries a session factory and a timeout
    to say one sentence.
    """

    def stream(self, messages: Sequence[Mapping[str, str]], lang: str, subject: str) -> AsyncIterator[str]:
        """Stream the answer to a conversation, one text fragment at a time.

        Args:
            messages: The conversation turns, oldest first.
            lang: ``"fr"`` or ``"en"``.
            subject: Per-user rate-limit subject.

        Returns:
            The fragments, in order.
        """


class DocumentationSource(Protocol):
    """Who answers *does this already exist?*, as a flow sees it.

    :class:`AskTheDocumentation` is the one implementation; the protocol exists so a flow can be
    driven, in a test, by a scripted answer rather than by an HTTP client.
    """

    async def check(
        self, request: str, lang: str, subject: str, issues: Sequence[tuple[int, str, str]] = ()
    ) -> DocumentationCheck:
        """Ask whether the documentation already describes a way to do this, and whether the request
        is one of the open issues.

        Args:
            request: What the user would like, in his own words.
            lang: ``"fr"`` or ``"en"``.
            subject: Per-user rate-limit subject.
            issues: The open issues, as ``(number, title, url)``, for the second question of the
                same call. Empty asks the documentation question alone.

        Returns:
            The finding.
        """


class AskTheDocumentation:
    """Puts one request to the documentation assistant and reads what came back."""

    def __init__(self, worker: DocumentationWorker, *, logger: Logger | None = None) -> None:
        """Initialize the check.

        Args:
            worker: The documentation chatbot client, the same one ``/ask`` uses.
            logger: Logger to use; defaults to the service's ``suggest`` logger.
        """
        self._worker = worker
        self._logger = logger or get_logger("suggest")

    async def check(
        self, request: str, lang: str, subject: str, issues: Sequence[tuple[int, str, str]] = ()
    ) -> DocumentationCheck:
        """Ask whether the documentation already describes a way to do this — and whether it is one
        of the open issues.

        Two answers from one call. The second question is ticket 05: a duplicate is recognised today
        by comparing words, and no two humans write the same request in the same words.

        Args:
            request: What the user would like, in his own words. Sent as the last turn and
                untouched, because it is what the Worker embeds to retrieve passages.
            lang: ``"fr"`` or ``"en"``.
            subject: Per-user rate-limit subject, as the Worker counts them.
            issues: The open issues, as ``(number, title, url)``. Empty asks the documentation
                question alone, which is what a deployment with no tracker access does.

        Returns:
            The finding. Never raises: every failure becomes :data:`UNKNOWN` with its reason, since
            losing a suggestion because the documentation could not be reached is the one outcome
            this step must not produce.
        """
        # Bounded here, not only where the form is: the whole submission is five modal fields, up
        # to 5000 characters, and it is the *last user turn* the Worker embeds to retrieve passages.
        # ``/ask`` trims at the same number for the same reason — past it, retrieval is being handed
        # a paste and does nothing useful with it.
        task = _TASK + _issue_task(issues)
        turns = answer_module.protocol_turns(" ".join(request.split())[:MAX_QUESTION_CHARS], extra=task)
        try:
            collected = "".join([fragment async for fragment in self._worker.stream(turns, lang, subject)])
        except WorkerFailure as failure:
            self._logger.warning(
                "the documentation could not be asked whether this already exists",
                extra={"event": "suggest.check_failed", "kind": failure.kind.value, "detail": failure.detail},
            )
            return DocumentationCheck(verdict=UNKNOWN, problem=failure.kind.value)

        body, titles = answer_module.split_sources(collected)
        named, named_title, named_url = _named_issue(body, issues)
        # Read off the body, then removed from it: the line is an instruction to this code, and
        # leaving `ISSUE #240` at the end of a paragraph shown to a human is the same defect the
        # idempotency marker had in the Discord preview.
        body = _ISSUE_LINE.sub("", body).strip()
        if not body.strip():
            self._logger.warning(
                "the documentation assistant answered nothing at all",
                extra={"event": "suggest.check_empty"},
            )
            return DocumentationCheck(verdict=UNKNOWN, problem="empty")
        if says_nothing(body):
            self._logger.info(
                "the documentation says nothing about this request",
                extra={"event": "suggest.checked", "verdict": ABSENT},
            )
            return DocumentationCheck(verdict=ABSENT, issue=named, issue_title=named_title, issue_url=named_url)
        links = answer_module.source_links(titles, lang)
        if not links:
            # Measured in front of a human, 2026-09-07: the first real `/suggest` announced *"la
            # documentation semble déjà répondre à ta demande"* and displayed, as that answer, *"la
            # documentation ne décrit pas de moyen de dessiner une route pour qu'un convoi la
            # suive"* — the exact opposite of what it concluded. The model is told to answer the
            # keyword when the documentation does not cover a subject; it answered in prose, so the
            # keyword check saw nothing and the absence of a keyword was read as presence.
            #
            # Requiring a **citation** does not depend on guessing what a sentence means, and it is
            # the rule the whole service already runs on: a link the asker can open is what lets him
            # contradict the machine. An answer with no page to open is not an answer that something
            # exists. It also covers the case the log line below names: a model that cited a page
            # the corpus does not have, whose title was dropped as unverifiable.
            self._logger.info(
                "the documentation answered without citing a page, so it is read as silence",
                extra={"event": "suggest.checked", "verdict": ABSENT, "reason": "no-citation"},
            )
            return DocumentationCheck(verdict=ABSENT, issue=named, issue_title=named_title, issue_url=named_url)
        self._logger.info(
            "the documentation describes a way to do this",
            extra={"event": "suggest.checked", "verdict": EXISTS, "pages": len(links)},
        )
        return DocumentationCheck(
            verdict=EXISTS,
            answer=body[:ANSWER_MAX_CHARS],
            links=tuple(links),
            issue=named,
            issue_title=named_title,
            issue_url=named_url,
        )


def _issue_task(issues: Sequence[tuple[int, str, str]]) -> str:
    """Render the second question, or nothing when there is no tracker to compare against.

    Args:
        issues: The open issues, as ``(number, title, url)``.

    Returns:
        The instruction to append, empty when *issues* is.
    """
    if not issues:
        return ""
    listed = "\n".join(
        f"- #{number} {one_line(title, ISSUE_TITLE_MAX_CHARS)}" for number, title, _ in issues[:MAX_ISSUES_OFFERED]
    )
    return _ISSUE_TASK.format(marker=ISSUE_KEYWORD, issues=listed)


def _named_issue(body: str, issues: Sequence[tuple[int, str, str]]) -> tuple[int, str, str]:
    """Read back which issue the model named, if any, and refuse one it invented.

    Args:
        body: The answer body, trailer already removed.
        issues: The issues that were offered.

    Returns:
        The issue, as ``(number, title, url)``, or ``(0, "", "")``. A number outside the offered list
        is dropped: a model naming ``#999`` would otherwise send an asker to an issue nobody wrote,
        which is worse than not recognising his request at all. The title travels with it because it
        is the evidence the proposal is judged on.
    """
    found = _ISSUE_LINE.search(body)
    if found is None:
        return 0, "", ""
    number = int(found.group(1))
    for offered, title, url in issues:
        if offered == number:
            return number, title, url
    return 0, "", ""


def says_nothing(body: str) -> bool:
    """Decide whether an answer is the *"the documentation does not cover this"* keyword.

    The comparison is an equality, not a prefix: *"NOTHING is documented about the radio menu"* is
    an answer, and reading it as an absence would throw it away — the failure this whole module is
    shaped around, one step earlier. What the decoration bound above still buys is the punctuation
    and emphasis a model puts around the word: ``**NOTHING**.`` strips down to the keyword itself.

    Args:
        body: The answer body, trailer already removed.

    Returns:
        ``True`` when the model answered the keyword and nothing else.
    """
    return body.strip(_NOTHING_TRIM).strip().upper() == NOTHING_KEYWORD
