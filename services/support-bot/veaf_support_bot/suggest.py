"""The ``/suggest`` exchange: an idea in, a feature request out — or nothing at all.

## The order, and why each step is where it is

1. **The modal is the response.** Discord closes an interaction after three seconds; ``send_modal``
   *is* the acknowledgement, so opening the form costs nothing and cannot time out.
2. **The documentation is asked first.** A large share of feature requests are documentation gaps
   wearing a costume, and answering *"it is there, here is the page"* serves the asker on the spot,
   keeps the tracker clean, and turns the exchange into a signal about the documentation rather than
   a task for a maintainer. See :mod:`veaf_support_bot.existing` for why it is *asked* and not
   searched.
3. **Then the tracker and the plans.** The same deterministic sweep the bug flow runs, over the open
   issues, ``.backlog/`` and ``ROADMAP.md`` — a suggestion can already be requested, already
   scheduled, or already declined, and those three live in text a machine can match because they are
   written in the project's own vocabulary.
4. **Draft, consent, file — in that order.** The issue is rendered *as it will be filed* and put to
   the asker with three buttons; only a press of *File the issue* reaches GitHub.

Neither check ever concludes on its own. Both are shown with their evidence and can be refused, and
a refusal continues the flow rather than ending it: a wrong *"it already exists"* silences a real
idea, and the person will not argue with a bot.

## Nothing is public before the click

The whole preparation is ephemeral, exactly as ``/bug``'s is. It is tempting to open the thread
first — an answer that resolves a request is useful to everybody — but that publishes somebody's
half-formed idea before he has agreed to publish anything. The thread is opened after the click, and
carries the issue's address.

## What it deliberately does not do

No design sketch, and no judgement on whether the idea is good. David alone decides that, and an
issue is a report rather than a queue entry — which the documentation says out loud, because a
suggestion sitting open for a year is only disappointing to someone who was told otherwise.

Everything the asker types is data: it is quoted into the issue and never parsed for a decision. The
component comes from a Discord choice bound to :data:`~veaf_support_bot.suggestion.COMPONENTS`.
"""

from __future__ import annotations

import re
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from logging import Logger
from typing import Protocol

from veaf_support_bot.draft import (
    CANCEL,
    EDIT,
    EXPIRED,
    FILE,
    SAME,
    UNANSWERED,
    Draft,
    room_for_a_question,
)
from veaf_support_bot.exchange import ThreadExchange, ThreadHandle
from veaf_support_bot.existing import DocumentationCheck, DocumentationSource
from veaf_support_bot.filing import Outcome
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.priorart import DUPLICATE, SOURCE_OPEN_ISSUE, Candidate, Match, PriorArtGate, Sweep, render_match
from veaf_support_bot.quota import QuotaKeeper
from veaf_support_bot.suggestion import (
    BASE_LABEL,
    SuggestionForm,
    build_title,
    render_suggestion_body,
    suggestion_key,
)
from veaf_support_bot.texts import REPOSITORY_URL, normalize_language, text
from veaf_support_bot.untrusted import one_line, quote

#: The family of prior-art sentences this flow speaks from. Not the bug flow's: that one tells the
#: reporter his observation will be added to the existing issue, and then adds it. This flow opens
#: nothing and comments nothing on an accepted match, so it must not promise either.
PRIOR_ART_FAMILY = "suggest.priorart"

#: Longest message this flow sends. Discord refuses anything over 2000 characters, and a
#: refusal here is total silence: the asker keeps the ephemeral placeholder for ever, having
#: filled five fields. Measured before this bound existed: the no-filer path rendered 2040
#: characters on an ordinary form, and the documentation question up to 2402.
MESSAGE_MAX_CHARS = 1900

#: How long one deferred interaction token lives. Discord's own number, and the hard bound this
#: whole exchange runs inside: past it, an edit is refused and whatever the asker clicked is lost.
TOKEN_LIFETIME_SECONDS = 900

#: Longest issue title shown in a proposal. A title is a line: past this it is the proposal itself
#: that becomes unreadable, which defeats the point of showing one.
ISSUE_TITLE_IN_PROPOSAL_CHARS = 120

#: The label this service puts on every bug report it files. A feature request cannot be a duplicate
#: of one, so issues carrying it are not offered to the model at all.
BUG_LABEL = "bug"

#: Left at the end for the last message — the outcome of the filing, or the sentence saying why
#: nothing was filed. An expiry the service can no longer announce is an expiry nobody learns about.
CLOSING_MARGIN_SECONDS = 30

#: Longest thread name. Discord's own ceiling is 100 characters.
THREAD_NAME_MAX_CHARS = 90

#: Longest title echoed into the opening message of that thread.
TITLE_IN_THREAD_MAX_CHARS = 200

#: What the asker is told for each answer that is not "file it". A table rather than branches, so a
#: new answer cannot be added without a sentence to go with it: a decision somebody makes and the
#: bot does not acknowledge reads exactly like a bot that crashed.
DECLINED: dict[str, str] = {
    EDIT: "draft.editing",
    CANCEL: "draft.cancelled",
    EXPIRED: "draft.expired",
}


@dataclass
class SuggestSubmission:
    """One submitted form, plus what came with the interaction.

    Attributes:
        form: What the asker typed, and the component he picked.
        thread_url: Where the suggestion was made, when it came from somewhere that has a thread.
    """

    form: SuggestionForm
    thread_url: str = ""


class PreparedFiler(Protocol):
    """What this flow needs from :mod:`veaf_support_bot.filing`, and nothing more."""

    @property
    def machine_label(self) -> str:
        """Return the label marking an issue as machine-filed.

        Returns:
            The label.
        """

    async def file_prepared(self, key: str, title: str, body: str, labels: Sequence[str]) -> Outcome:
        """File one already-rendered issue.

        Args:
            key: The idempotency key, which the body carries as a hidden marker.
            title: The issue title.
            body: The issue body.
            labels: The labels to ask for.

        Returns:
            What became of it.
        """

    async def add_comment(self, number: int, body: str) -> Outcome:
        """Add one comment to an existing issue.

        The same call the enrichment uses, which is what ticket 07 means by *one mechanism*: the
        bug flow's own duplicate comment and this one both end here rather than each growing a
        renderer-shaped method of their own.

        Args:
            number: The issue to comment on.
            body: The comment body, already rendered.

        Returns:
            What became of it.
        """


class SuggestionTracker(Protocol):
    """What this flow needs from :mod:`veaf_support_bot.relay`, and nothing more."""

    def remember(self, issue: int, *, channel_id: int, thread_id: int, lang: str) -> None:
        """Record that one issue must report back into one thread.

        Args:
            issue: The issue that was filed.
            channel_id: Channel the thread lives in.
            thread_id: The thread.
            lang: Language the asker was answered in.
        """


class _AskTheAsker:
    """The :class:`~veaf_support_bot.priorart.MatchConfirmation` protocol, over the exchange.

    The sweep speaks in :class:`~veaf_support_bot.priorart.Sweep` objects and the exchange speaks in
    strings, so the rendering — which is where the evidence is put in front of the asker — happens
    on this side of the seam.

    Attributes:
        exchange: Who gets asked.
    """

    def __init__(self, exchange: ThreadExchange) -> None:
        """Initialize the adapter.

        Args:
            exchange: The Discord side.
        """
        self._exchange = exchange

    async def confirm(self, sweep: Sweep, lang: str) -> str:
        """Put the match, with its evidence, to the asker.

        Args:
            sweep: The finding.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            What he answered: ``SAME``, ``DIFFERENT`` or ``UNANSWERED``.
        """
        return await self._exchange.confirm(render_match(sweep, lang, family=PRIOR_ART_FAMILY), lang)


def _issue_number(sweep: Sweep) -> int | None:
    """Read the issue number out of a finding, when the finding is a GitHub issue at all.

    Args:
        sweep: The finding the asker recognised.

    Returns:
        The number, or ``None`` when the match is a lot or a roadmap section — which are not places
        a comment can be added.
    """
    if sweep.best is None:
        return None
    matched = re.fullmatch(r"#(\d+)", sweep.best.candidate.reference.strip())
    return int(matched.group(1)) if matched else None


def render_observation(form: SuggestionForm, lang: str) -> str:
    """Render what gets added to the existing issue.

    Args:
        form: The submitted form.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The comment body: who asked, and the problem in his own words. Quoted rather than pasted,
        for the same reason every other published field is.
    """
    return text(
        "suggest.observation.body",
        lang,
        asker=one_line(form.asker, 80),
        problem=quote(form.problem),
    )


def _match_for(number: int, title: str = "", url: str = "") -> Match:
    """Wrap an issue the model named in the shape the rest of the flow already speaks.

    Args:
        number: The issue number.
        title: Its title, so the comment and the log name the issue rather than a bare number.
        url: Where to read it.

    Returns:
        A match carrying that reference. The score is 0: this one was not measured by word overlap,
        and printing a number it did not earn would be evidence the sweep never produced.
    """
    return Match(
        candidate=Candidate(source=SOURCE_OPEN_ISSUE, reference=f"#{number}", title=title, url=url),
        score=0.0,
    )


class SuggestIntake:
    """Runs one ``/suggest`` exchange, from the submitted form to a filed feature request."""

    def __init__(
        self,
        *,
        documentation: DocumentationSource | None = None,
        quota: QuotaKeeper | None = None,
        prior_art: PriorArtGate | None = None,
        filer: PreparedFiler | None = None,
        tracker: SuggestionTracker | None = None,
        logger: Logger | None = None,
        clock: Callable[[], float] | None = None,
    ) -> None:
        """Initialize the flow.

        Args:
            documentation: Who asks the documentation whether this already exists. ``None`` skips
                the question, and the issue then says the documentation was not consulted rather
                than implying it was.
            quota: The per-user counters the documentation question is charged against — it is one
                model call, on the same allowance ``/ask`` spends. ``None`` charges nothing.
            prior_art: The deterministic sweep over issues, ``.backlog/`` and ``ROADMAP.md``, and the
                step that lets the asker refuse it. ``None`` skips it.
            filer: Where an accepted suggestion is filed. ``None`` means this deployment has no
                GitHub App: the request is prepared and shown, and the asker is told plainly that
                nothing was opened.
            tracker: What remembers which thread an issue must answer in. ``None`` files the request
                and opens the thread all the same; what is lost is the follow-up.
            logger: Logger to use; defaults to the service's ``suggest`` logger.
            clock: Source of monotonic timestamps for the token budget; defaults to
                :func:`time.monotonic`.
        """
        self._documentation = documentation
        self._quota = quota
        self._prior_art = prior_art
        self._filer = filer
        self._tracker = tracker
        self._logger = logger or get_logger("suggest")
        self._clock: Callable[[], float] = clock or time.monotonic

    async def handle(self, exchange: ThreadExchange, submission: SuggestSubmission) -> Outcome | None:
        """Run one suggestion end to end.

        Args:
            exchange: The Discord side.
            submission: The form and where it came from.

        Returns:
            What became of the filing, or ``None`` when nothing was filed — which is the ordinary
            outcome of a request the documentation already answers.
        """
        form = submission.form
        lang = normalize_language(form.language)
        await exchange.defer()
        started = self._clock()
        # Mutable, and passed down rather than kept on the instance: one flow object serves every
        # exchange at once. What it carries is whether the issue exists, which decides what an
        # unexpected failure is allowed to claim afterwards.
        progress: dict[str, object] = {}
        try:
            return await self._run(exchange, submission, lang, started, progress)
        except Exception as error:
            filed = bool(progress.get("filed"))
            self._logger.exception(
                "the /suggest exchange failed after the acknowledgement",
                extra={
                    "event": "suggest.crashed",
                    "user": form.asker_id,
                    "error": type(error).__name__,
                    "filed": filed,
                },
            )
            # "Nothing was opened" is a lie once the issue exists, and it is the sentence that
            # decides whether he files it again.
            await self._say(exchange, text("suggest.error.after_filing" if filed else "suggest.error.unexpected", lang))
            return None

    async def _run(
        self,
        exchange: ThreadExchange,
        submission: SuggestSubmission,
        lang: str,
        started: float,
        progress: dict[str, object],
    ) -> Outcome | None:
        """Run the steps in order, stopping at the first one that settles the request.

        Args:
            exchange: The Discord side.
            submission: The form and where it came from.
            lang: ``"fr"`` or ``"en"``.
            started: When the interaction was acknowledged, for the token budget.
            progress: Where this exchange records that the issue exists.

        Returns:
            The filing outcome, or ``None``.
        """
        form = submission.form
        missing = form.missing_fields()
        if missing:
            await self._say(exchange, text("suggest.missing", lang, fields=", ".join(missing)))
            return None

        check = await self._ask_documentation(form, lang)
        asked = check.found and self._may_ask(started, "documentation")
        # `== SAME`, not truthiness: every non-empty string was true, so a future value — or a
        # stand-in returning something else — would have settled the request without a yes.
        if asked and await exchange.confirm(render_documentation(check, lang), lang) == SAME:
            self._logger.info(
                "the documentation already answered the request",
                extra={"event": "suggest.settled", "user": form.asker_id, "by": "documentation"},
            )
            await self._say(exchange, text("suggest.settled.documentation", lang))
            return None

        if check.issue and self._may_ask(started, "a request already made in other words"):
            settled = await self._propose_the_named_issue(
                exchange,
                form,
                check.issue,
                lang,
                started,
                title=check.issue_title,
                url=check.issue_url,
            )
            if settled:
                return None

        sweep, answer = await self._sweep(exchange, form, lang, started)
        # Only an explicit *yes* settles a request. A silence means the asker never saw the
        # proposal or never answered it, and dropping his request on that would be the machine
        # deciding his idea already exists.
        if answer == SAME and sweep is not None:
            self._logger.info(
                "existing work already covers the request",
                extra={"event": "suggest.settled", "user": form.asker_id, "by": sweep.verdict},
            )
            await self._say(
                exchange,
                render_match(sweep, lang, family=PRIOR_ART_FAMILY) + "\n\n" + text("suggest.settled.prior_art", lang),
            )
            await self._record_the_second_voice(exchange, form, sweep, lang)
            return None

        return await self._file(exchange, submission, check, sweep, lang, asked=asked, progress=progress)

    async def _propose_the_named_issue(
        self,
        exchange: ThreadExchange,
        form: SuggestionForm,
        number: int,
        lang: str,
        started: float,
        title: str = "",
        url: str = "",
    ) -> bool:
        """Put the issue the model recognised to the asker, with what it is, and take his answer.

        A model saying *this is #240* is a proposal like any other: it is shown with the issue it
        names and a way to refuse it, and a refusal carries the request on untouched. What it is not
        is a decision — the whole reason the deterministic sweep proposes rather than applies.

        Args:
            exchange: The Discord side.
            form: The submitted form.
            number: The issue the model named, already validated against the ones it was offered.
            lang: ``"fr"`` or ``"en"``.
            started: When the interaction was acknowledged.
            title: That issue's title, which is the **evidence**. A proposal a reader cannot judge
                without opening GitHub is an assertion, and an assertion is what silences a real
                request: measured on #938, where the title alone would have settled it in a second.
            url: Where to read it.

        Returns:
            Whether the request is settled. ``False`` for a refusal **and** for a silence: neither
            is an agreement, and only an agreement may stop somebody's request.
        """
        proposal = text(
            "suggest.named_issue",
            lang,
            issue=number,
            title=one_line(title, ISSUE_TITLE_IN_PROPOSAL_CHARS) if title else text("suggest.no_title", lang),
            url=url or f"{REPOSITORY_URL}/issues/{number}",
        )
        answer = await exchange.confirm(proposal, lang)
        self._logger.info(
            "a request already made in other words was proposed",
            extra={"event": "suggest.named_issue", "issue": number, "answer": answer},
        )
        if answer != SAME:
            return False
        await self._say(exchange, text("suggest.settled.named_issue", lang, issue=number))
        await self._record_the_second_voice(exchange, form, Sweep(verdict=DUPLICATE, best=_match_for(number)), lang)
        return True

    async def _record_the_second_voice(
        self, exchange: ThreadExchange, form: SuggestionForm, sweep: Sweep, lang: str
    ) -> None:
        """Offer to add the asker's observation to the issue he just recognised as his own.

        Why it is worth doing at all: a suggestion is only wanted or not, and one person deciding.
        *A second person asking for the same thing* is the only signal of priority a suggestion will
        ever carry — and until this existed it was thrown away entirely. The asker was told the
        subject is tracked elsewhere, and nothing anywhere recorded that one more person needed it.

        Two guards, both deliberate:

        * it is **drafted and shown**, and posted only on a second click. Recognising an issue as
          one's own is not the same act as agreeing to publish under it, and this publishes words on
          a public tracker;
        * it carries the problem as the asker stated it and who asked, and nothing else. The issue
          already holds a feature request; a second copy of the template would bury the one line a
          maintainer actually needs.

        Args:
            exchange: The Discord side.
            form: The submitted form.
            sweep: The finding the asker recognised, which carries the issue's reference.
            lang: ``"fr"`` or ``"en"``.
        """
        number = _issue_number(sweep)
        if self._filer is None or number is None:
            return
        body = render_observation(form, lang)
        decision = await exchange.decide(
            Draft(title=text("suggest.observation.title", lang, issue=number), body=body).render(
                lang, header="suggest.observation.header"
            ),
            lang,
        )
        if decision != FILE:
            # Every other answer posts nothing, expiry included. The request was already settled by
            # his own *yes*; what he declined here is publishing under his name.
            await self._say(exchange, text("suggest.observation.declined", lang))
            return
        outcome = await self._filer.add_comment(number, body)
        self._logger.info(
            "a second voice was recorded on an existing issue",
            extra={"event": "suggest.observed", "issue": number, "action": outcome.action},
        )
        await self._say(
            exchange,
            text("suggest.observation.recorded", lang, issue=number)
            if outcome.action == "commented"
            else text("suggest.observation.failed", lang, issue=number),
        )

    def _may_ask(self, started: float, what: str) -> bool:
        """Say whether one more timed question still leaves room for the consent click.

        Every question this flow asks waits on the **same** interaction token, and Discord expires
        it after fifteen minutes. The bug flow already spends 300 + 480 of those 900 seconds on its
        two waits, which its own constants describe as leaving two minutes to write the last
        message; this flow has one more question to ask, and three waits do not fit. So the *checks*
        give way, never the consent: an asker who clicks *File the issue* on a dead token has agreed
        to something that will never happen, and nothing tells him.

        Args:
            started: When the interaction was acknowledged.
            what: What is about to be asked, for the log line.

        Returns:
            ``True`` when the question fits. ``False`` skips it — the finding is still computed and
            still recorded in the issue, it is simply not put to the asker.
        """
        spent = self._clock() - started
        if room_for_a_question(spent):
            return True
        self._logger.info(
            "a check was not put to the asker: the interaction token would not outlive it",
            extra={"event": "suggest.check_skipped", "check": what, "spent": round(spent)},
        )
        return False

    async def _open_issues(self) -> tuple[tuple[int, str, str], ...]:
        """Read the open issues' numbers and titles, for the second question of the same call.

        Ticket 05: a duplicate is recognised today by comparing words, and no two humans write the
        same request in the same words. The titles ride along with the documentation question rather
        than costing a call of their own — measured 2026-09-07, ten open issues and under 600
        characters of titles.

        Returns:
            The issues as ``(number, title, url)``, without the bug reports, or an empty tuple when
            there is no gate, no source, or the tracker could not be read. A tracker that cannot be reached costs the *recognition*, never the suggestion:
            the deterministic sweep still runs afterwards and the issue still records what happened.
        """
        source = self._prior_art.sweeper.issues if self._prior_art is not None else None
        if source is None:
            return ()
        try:
            records = await source.open_issues()
        except Exception as error:  # noqa: BLE001 - a courtesy check must not cost a suggestion
            self._logger.warning(
                "the open issues could not be read, so the request is not compared against them",
                extra={"event": "suggest.issues_unavailable", "error": type(error).__name__},
            )
            return ()
        # A feature request cannot be a duplicate of a **bug report**: they are different natures,
        # and the tracker says which is which with the label this service itself applies. Measured
        # 2026-09-07: asked for a UI resembling ctld-tools', the model proposed #938 — a bug report
        # titled *La mission ne fonctionne pas*, filed five minutes earlier.
        #
        # What is deliberately not filtered is the *origin*: an issue this bot opened for somebody
        # else is a perfectly good duplicate.
        return tuple(
            (record.number, record.title, record.url)
            for record in records
            if BUG_LABEL not in {label.lower() for label in record.labels}
        )

    async def _ask_documentation(self, form: SuggestionForm, lang: str) -> DocumentationCheck:
        """Ask the documentation whether this already exists, if there is an allowance for it.

        A spent quota does not stop a suggestion: the check is a courtesy to the asker and a
        cleanliness measure for the tracker, not a toll on contributing. What it does is go on the
        record — the issue says the documentation was not consulted, and why.

        Args:
            form: The submitted form.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            The finding.
        """
        if self._documentation is None:
            return DocumentationCheck(problem="not configured")
        issues = await self._open_issues()
        if self._quota is not None:
            decision = self._quota.check_and_consume(form.asker_id)
            if not decision.allowed:
                self._logger.info(
                    "the documentation was not asked: the day's allowance is spent",
                    extra={"event": "suggest.check_refused", "user": form.asker_id, "reason": decision.reason},
                )
                return DocumentationCheck(problem=f"quota: {decision.reason}")
        return await self._documentation.check(form.all_text(), lang, form.asker_id, issues)

    async def _sweep(
        self, exchange: ThreadExchange, form: SuggestionForm, lang: str, started: float
    ) -> tuple[Sweep | None, str]:
        """Compare the request against what is already reported, scheduled or declined.

        Args:
            exchange: The Discord side, which is who gets asked about a match.
            form: The submitted form.
            lang: ``"fr"`` or ``"en"``.
            started: When the interaction was acknowledged. When the token budget has no room left
                for another question, the sweep still runs and its finding still reaches the issue —
                the gate simply has nobody to ask, which it already answers as *not accepted*.

        Returns:
            A pair of the finding — ``None`` when no sweep is configured — and whether the asker
            answered about the proposed match. A sweep nobody could be asked about — no gate,
            or no room left in the token for one more question — answers ``UNANSWERED``,
            which is what it is: not a refusal, and never an agreement.
        """
        if self._prior_art is None:
            return None, UNANSWERED
        confirmation = _AskTheAsker(exchange) if self._may_ask(started, "prior art") else None
        answer: str
        sweep, answer = await self._prior_art.run(form.all_text(), lang, confirmation=confirmation)
        self._logger.info(
            "prior art swept",
            extra={
                "event": "suggest.prior_art",
                "verdict": sweep.verdict,
                "answer": answer,
                "reference": sweep.best.candidate.reference if sweep.best else "",
                "problems": list(sweep.problems),
            },
        )
        return sweep, answer

    async def _file(
        self,
        exchange: ThreadExchange,
        submission: SuggestSubmission,
        check: DocumentationCheck,
        sweep: Sweep | None,
        lang: str,
        *,
        asked: bool,
        progress: dict[str, object],
    ) -> Outcome | None:
        """Show the issue, wait for the click, and file it — or say why nothing was filed.

        Args:
            exchange: The Discord side.
            submission: The form and where it came from.
            check: What the documentation answered.
            sweep: What the deterministic sweep found.
            lang: ``"fr"`` or ``"en"``.
            asked: Whether the documentation's answer was actually put to the asker. The issue must
                not say he disagreed with something nobody showed him.
            progress: Where the fact that the issue now exists is recorded.

        Returns:
            The outcome, or ``None`` when nothing was filed.
        """
        form = submission.form
        key = suggestion_key(form)
        title = build_title(form)
        body = render_suggestion_body(
            form, key, check=check, sweep=sweep, thread_url=submission.thread_url, asked=asked
        )
        if self._filer is None:
            await self._say(
                exchange, Draft(title=title, body=body).render(lang) + "\n\n" + text("filed.disabled", lang)
            )
            return None

        choice = await exchange.decide(Draft(title=title, body=body).render(lang), lang)
        self._logger.info(
            "the asker decided what to do with his draft",
            extra={"event": "suggest.decided", "user": form.asker_id, "choice": choice},
        )
        if choice != FILE:
            await self._say(exchange, text(DECLINED.get(choice, "draft.cancelled"), lang))
            return None

        # The thread is opened after the click and before the filing: after, because an abandoned
        # draft must not leave a public thread about a request nobody filed; before, because the
        # issue carries its link and rewriting a body afterwards is a second write that can fail.
        handle = await self._open_thread(exchange, form, lang)
        thread_url = handle.url or submission.thread_url
        body = render_suggestion_body(form, key, check=check, sweep=sweep, thread_url=thread_url, asked=asked)
        # Filtered rather than passed through: GitHub answers 422 on an empty label name and the
        # retry drops **every** label, so one unset variable would file suggestions nobody can
        # filter on — which is the whole point of labelling them.
        labels = tuple(label for label in (BASE_LABEL, self._filer.machine_label) if label)
        outcome = await self._filer.file_prepared(key, title, body, labels)
        progress["filed"] = bool(outcome.number)
        await self._say(exchange, render_outcome(outcome, lang))
        if not handle.opened:
            return outcome
        if not outcome.number:
            # The thread was opened one line before the filing failed, and it is public: leaving it
            # empty puts the asker's idea in the channel under a title that links to nothing, for
            # ever. Saying what happened costs one message and is the only thing that explains it.
            await exchange.post_in_thread(handle, text("suggest.thread.failed", lang))
            return outcome
        self._track(outcome, handle, lang)
        await exchange.post_in_thread(
            handle,
            text(
                "suggest.thread.opening",
                lang,
                title=one_line(title, TITLE_IN_THREAD_MAX_CHARS),
                url=outcome.url or f"#{outcome.number}",
            ),
        )
        return outcome

    async def _open_thread(self, exchange: ThreadExchange, form: SuggestionForm, lang: str) -> ThreadHandle:
        """Open the public thread the issue's news will come back into.

        Args:
            exchange: The Discord side.
            form: The submitted form.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            Where it was opened, or an empty handle when none could be.
        """
        name = text("suggest.thread.name", lang, topic=one_line(form.summary, THREAD_NAME_MAX_CHARS))
        handle = await exchange.open_followup_thread(name[:THREAD_NAME_MAX_CHARS])
        if not handle.opened:
            self._logger.warning(
                "no follow-up thread could be opened for this suggestion",
                extra={"event": "suggest.no_thread", "user": form.asker_id},
            )
        return handle

    def _track(self, outcome: Outcome, handle: ThreadHandle, lang: str) -> None:
        """Record that this issue answers in this thread.

        Args:
            outcome: The filing outcome.
            handle: The thread that was opened.
            lang: ``"fr"`` or ``"en"``.
        """
        if self._tracker is None:
            return
        self._tracker.remember(outcome.number, channel_id=handle.channel_id, thread_id=handle.thread_id, lang=lang)

    async def _say(self, exchange: ThreadExchange, message: str) -> None:
        """Tell the asker something, and survive Discord refusing to carry it.

        Args:
            exchange: The Discord side.
            message: What to say.
        """
        try:
            await exchange.post(message[:MESSAGE_MAX_CHARS])
        except Exception as error:  # noqa: BLE001 - the last resort cannot have a resort of its own
            self._logger.error(
                "could not tell the asker what became of his suggestion",
                extra={"event": "suggest.post_failed", "error": type(error).__name__},
            )


def render_documentation(check: DocumentationCheck, lang: str) -> str:
    """Render what the documentation answered, with the pages it cited.

    Shown with its sources for the same reason a prior-art match is shown with its evidence: the
    asker has to be able to see *why* the machine thinks his idea already exists, and disagree.

    Args:
        check: The finding.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message put to the asker.
    """
    pages = "\n" + text("suggest.documentation.pages", lang, links=", ".join(check.links)) if check.links else ""
    # The answer gives way, never the pages: a citation the asker can open is what lets him disagree
    # with the machine, and half a link is worse than a shorter answer.
    room = MESSAGE_MAX_CHARS - len(text("suggest.documentation.question", lang, answer="")) - len(pages)
    return text("suggest.documentation.question", lang, answer=check.answer[: max(room, 0)]) + pages


def render_outcome(outcome: Outcome, lang: str) -> str:
    """Render what became of the filing attempt.

    A failure is a sentence the asker reads, never a silence: he has spent minutes on this and must
    not walk away believing an issue exists.

    Args:
        outcome: What the filer returned.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message.
    """
    if outcome.action == "failed":
        return text(
            "filed.error",
            lang,
            reason=one_line(outcome.error, 300),
            issue_url=f"{REPOSITORY_URL}/issues/new?template=feature_request.yml",
        )
    key = {"created": "filed.created", "reused": "suggest.filed.reused", "commented": "filed.commented"}[outcome.action]
    message = text(key, lang, url=outcome.url or f"#{outcome.number}")
    if outcome.notes:
        message += "\n" + text("filed.notes", lang, notes="; ".join(outcome.notes))
    return message
