"""Ticket 08: one model call, for members, while the day's small allowance lasts.

Everything before this module is deterministic and free. This is the only place in `/bug` where a
model is used at all, and it runs **after** the issue exists — so a spent quota, an unavailable
model or a reporter without the role can never cost a report. They cost one section, and the issue
says which one is missing and why.

## Three gates, all cheap, all before the call

1. **A VEAF role**, read from the Discord interaction itself: it cannot be forged and costs nothing.
2. **The daily ceiling** — 15, against a free tier measured at 20 requests a day for the whole
   Google project. The counter is the one `/ask` uses, on its own file, with its own ceiling.
3. **One call per report**, enforced here rather than requested of the model.

The counter **fails closed**: counters that cannot be read mean no enrichment, never unlimited
enrichment. That is the opposite of `/ask`'s degraded mode, which stays barely useful because a
documentation bot that goes silent is indistinguishable from a broken one. Here silence costs a
paragraph on an issue that is already filed, and the resource being protected is shared with the
website and the command line.

## Why one call is enough

The location, the surrounding code, the callers, the catalogue matches, the prior art and the
mission summary are all in hand by the time this runs. The model is asked to **conclude on a
prepared file**, not to investigate. If one call proves insufficient the answer is a better prepared
context — more callers, a wider neighbourhood, the matching rule's wording — not a second call.
"""

from __future__ import annotations

from dataclasses import dataclass
from logging import Logger
from typing import Protocol

from veaf_support_bot.bugreport import BugReport
from veaf_support_bot.issue_body import render_hypothesis, render_no_hypothesis
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.quota import QuotaKeeper
from veaf_support_bot.worker import FailureKind, WorkerFailure

#: Enrichments a day, against a free tier measured at 20 requests per Google project per day. The
#: five left over are margin: the same project also serves ``/ask``'s fallbacks and the log
#: analysis, and a ceiling that consumes the last request would make the *next* failure look like a
#: bug in this service.
DEFAULT_ENRICH_PER_DAY = 15

#: Longest hypothesis carried onto the issue. A guess that scrolls is a guess nobody reads to the
#: end, and this one has to stay visibly smaller than the facts above it.
HYPOTHESIS_MAX_CHARS = 4000

#: Why a report was not enriched. Each value is the suffix of a ``hypothesis.absent.*`` text key, so
#: a reason with no sentence fails a test rather than publishing a blank explanation.
NOT_A_MEMBER = "not_a_member"
CEILING_REACHED = "ceiling_reached"
MODEL_UNAVAILABLE = "model_unavailable"
EMPTY_ANSWER = "empty_answer"
DISABLED = "disabled"

#: Every reason, for the catalogue test.
ABSENT_REASONS = (NOT_A_MEMBER, CEILING_REACHED, MODEL_UNAVAILABLE, EMPTY_ANSWER, DISABLED)


@dataclass(frozen=True)
class Enrichment:
    """What became of one enrichment attempt.

    Attributes:
        body: The comment to add to the issue — the hypothesis, or the sentence saying it is
            missing. Never empty: an issue that says nothing about the hypothesis leaves a reader
            wondering whether one was tried.
        enriched: Whether a hypothesis was actually produced.
        reason: Why it was not, when it was not. One of :data:`ABSENT_REASONS`.
        calls: Model calls spent, which the runtime holds at one.
    """

    body: str
    enriched: bool
    reason: str = ""
    calls: int = 0


class HypothesisModel(Protocol):
    """The one model call this module is allowed to make."""

    async def hypothesise(self, context: str, lang: str, subject: str) -> str:
        """Return a hypothesis about a prepared report.

        Args:
            context: The prepared file — everything the deterministic pass established.
            lang: ``"fr"`` or ``"en"``.
            subject: Rate-limit subject, the reporter's Discord id.

        Returns:
            The hypothesis, in Markdown.

        Raises:
            WorkerFailure: The exchange produced no answer.
        """


class Enricher:
    """Runs the three gates, then at most one call, then says what happened either way."""

    def __init__(
        self,
        model: HypothesisModel | None,
        *,
        role_id: str,
        allowance: QuotaKeeper | None,
        logger: Logger | None = None,
    ) -> None:
        """Initialize the enricher.

        Args:
            model: What makes the call. ``None`` disables enrichment entirely — the documented way
                to switch the paid path off without touching the intake.
            role_id: Discord role that opens the enrichment. Empty disables it the same way: a role
                nobody holds is not a default worth guessing, and the alternative — enriching for
                everyone until an id is configured — spends a shared association resource on a
                decision nobody made.
            allowance: The daily counter. ``None``, or one that cannot keep its counters, refuses:
                fail closed.
            logger: Logger to use.
        """
        self._model = model
        self._role_id = role_id
        self._allowance = allowance
        self._logger = logger or get_logger("enrichment")

    @property
    def enabled(self) -> bool:
        """Say whether this deployment enriches at all.

        Returns:
            ``True`` when a model and a role are both configured.
        """
        return self._model is not None and bool(self._role_id)

    def _refusal(self, reason: str, lang: str) -> Enrichment:
        """Build the outcome of a report that was not enriched.

        Args:
            reason: One of :data:`ABSENT_REASONS`.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            The outcome, carrying the sentence the issue will show.
        """
        return Enrichment(body=render_no_hypothesis(reason, lang), enriched=False, reason=reason)

    async def enrich(self, report: BugReport, context: str, lang: str, *, roles: tuple[str, ...]) -> Enrichment:
        """Produce a hypothesis about a report, or say why there is none.

        Args:
            report: The report, already filed.
            context: The prepared file the model concludes on.
            lang: ``"fr"`` or ``"en"``.
            roles: Discord role ids the reporter holds, read off his interaction.

        Returns:
            What to add to the issue. Never raises: the issue exists by the time this runs, and an
            exception here would turn a missing paragraph into a lost report.
        """
        model = self._model
        if model is None or not self._role_id:
            return self._refusal(DISABLED, lang)
        if self._role_id not in roles:
            return self._refusal(NOT_A_MEMBER, lang)
        if not self._spend(report.form.reporter_id):
            return self._refusal(CEILING_REACHED, lang)

        try:
            answer = await model.hypothesise(context, lang, report.form.reporter_id)
        except WorkerFailure as failure:
            self._logger.warning(
                "the hypothesis could not be obtained",
                extra={"event": "enrichment.failed", "kind": failure.kind.value, "detail": failure.detail},
            )
            # An empty stream is raised by the client rather than returned, so mapping the kind back
            # is what keeps the five reasons five. Reading them all as "the model did not answer"
            # would tell a maintainer to retry a model that answered perfectly well, with nothing.
            reason = EMPTY_ANSWER if failure.kind is FailureKind.EMPTY else MODEL_UNAVAILABLE
            return self._refusal(reason, lang)
        if not answer.strip():
            self._logger.warning("the model returned nothing", extra={"event": "enrichment.empty"})
            return self._refusal(EMPTY_ANSWER, lang)

        self._logger.info(
            "hypothesis produced",
            extra={
                "event": "enrichment.done",
                "user": report.form.reporter_id,
                "chars": len(answer),
                "calls": 1,
            },
        )
        return Enrichment(body=render_hypothesis(answer[:HYPOTHESIS_MAX_CHARS], lang), enriched=True, calls=1)

    def _spend(self, subject: str) -> bool:
        """Consume one unit of the day's allowance.

        Args:
            subject: The reporter's Discord id, so consumption is recorded per report.

        Returns:
            ``True`` when there was one to spend. A counter that is absent or degraded answers
            ``False``: a ceiling that cannot be counted is a ceiling that is not enforced, and the
            allowance protects a resource shared with the website and the command line.
        """
        if self._allowance is None:
            return False
        if self._allowance.degraded:
            self._logger.warning(
                "the enrichment allowance cannot be counted, so nothing is enriched",
                extra={"event": "enrichment.degraded", "reason": self._allowance.degraded_reason},
            )
            return False
        return self._allowance.check_and_consume(subject).allowed
