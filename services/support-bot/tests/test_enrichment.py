"""Ticket 08: the three gates, the single call, and the five ways there is no hypothesis.

What has to hold is not that a hypothesis appears — it is that **nothing else changes when it does
not**. The issue is filed before this runs, so a reporter without the role, a spent allowance, an
unreachable model and a model that answers with whitespace must all leave the same complete report
behind, each saying which of the five it was.

The other half is the labelling. A machine's guess sits on a public tracker next to measured facts,
and will be read months later by somebody deciding whether a bug is real. So the label is asserted
as a *heading*, above the text, not as a phrase somewhere in it.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any

from tests.intake_fixtures import fixture_checkout, fixture_root
from tests.test_attachments import _fake_downloader
from tests.test_intake_github_wiring import _Exchange, _Filer, _submission
from veaf_support_bot.attachments import AttachmentCollector
from veaf_support_bot.bugreport import BugForm, BugReport
from veaf_support_bot.checkout import Freshness
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.draft import FILE
from veaf_support_bot.enrichment import (
    ABSENT_REASONS,
    CEILING_REACHED,
    DISABLED,
    EMPTY_ANSWER,
    MODEL_UNAVAILABLE,
    NOT_A_MEMBER,
    Enricher,
)
from veaf_support_bot.intake import BugIntake
from veaf_support_bot.issue_body import heading
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.service import build_enricher, build_intake
from veaf_support_bot.toolkit import DoctorFacts
from veaf_support_bot.traces import TraceReading
from veaf_support_bot.worker import FailureKind, WorkerFailure

#: The role that opens the enrichment in these tests.
MEMBER = "1234567890"


class _Model:
    """A model with a scripted answer, counting how often it was called."""

    def __init__(self, answer: str = "This looks like `sample.py:12`.", failure: Exception | None = None) -> None:
        """Initialize the stand-in.

        Args:
            answer: What it returns.
            failure: Raised instead, when given.
        """
        self.answer = answer
        self.failure = failure
        self.calls: list[tuple[str, str, str]] = []

    async def hypothesise(self, context: str, lang: str, subject: str) -> str:
        """Record the call and answer it.

        Args:
            context: The prepared file.
            lang: The language asked for.
            subject: The rate-limit subject.

        Returns:
            The scripted answer.

        Raises:
            Exception: The one this stand-in was built with.
        """
        self.calls.append((context, lang, subject))
        if self.failure is not None:
            raise self.failure
        return self.answer


def _allowance(per_day: int = 15, *, path: Path | None = None) -> QuotaKeeper:
    """Build a working daily allowance.

    Args:
        per_day: The ceiling.
        path: Where the counters live; a temporary file by default.

    Returns:
        The keeper.
    """
    store = QuotaStore(path or Path(tempfile.mkdtemp()) / "enrichment.json")
    limits = QuotaLimits(
        user_window_seconds=60.0,
        user_per_window=per_day,
        user_per_day=per_day,
        global_per_day=per_day,
    )
    return QuotaKeeper(limits, store)


def _report() -> BugReport:
    """Build a minimal filed report.

    Returns:
        The report.
    """
    form = BugForm(
        summary="convert-v5 crashes",
        happened="it stopped",
        expected="it should convert",
        steps="run it",
        doctor="",
        reporter="Tripack",
        reporter_id="4242",
        language="en",
    )
    return BugReport(
        form=form,
        facts=DoctorFacts(),
        trace=TraceReading(),
        freshness=Freshness(),
        version="6.19.0",
        component="Other",
        labels=("bug",),
        title="convert-v5 crashes",
    )


def _enricher(model: Any = None, *, role: str = MEMBER, allowance: QuotaKeeper | None = None) -> Enricher:
    """Build the enricher under test.

    Args:
        model: What makes the call.
        role: The gating role id.
        allowance: The daily counter.

    Returns:
        The enricher.
    """
    return Enricher(model, role_id=role, allowance=allowance if allowance is not None else _allowance())


class TestTheGates(unittest.IsolatedAsyncioTestCase):
    """All three are checked before the call, because the call is the only thing that costs."""

    async def test_a_member_within_the_allowance_gets_one_call(self) -> None:
        model = _Model()

        result = await _enricher(model).enrich(_report(), "the prepared file", "en", roles=(MEMBER,))

        self.assertTrue(result.enriched)
        self.assertEqual(len(model.calls), 1, "one report is one call, enforced here")
        self.assertEqual(result.calls, 1)

    async def test_the_prepared_file_is_what_the_model_reads(self) -> None:
        """The model concludes on a file, it does not investigate — that is why one call is enough."""
        model = _Model()

        await _enricher(model).enrich(_report(), "### Located in the code\n\nsample.py:12", "en", roles=(MEMBER,))

        self.assertIn("sample.py:12", model.calls[0][0])

    async def test_a_non_member_is_refused_without_spending_a_call(self) -> None:
        model = _Model()

        result = await _enricher(model).enrich(_report(), "context", "en", roles=("some-other-role",))

        self.assertEqual(model.calls, [])
        self.assertEqual(result.reason, NOT_A_MEMBER)

    async def test_the_daily_ceiling_stops_the_next_report(self) -> None:
        model = _Model()
        enricher = _enricher(model, allowance=_allowance(per_day=1))

        first = await enricher.enrich(_report(), "context", "en", roles=(MEMBER,))
        second = await enricher.enrich(_report(), "context", "en", roles=(MEMBER,))

        self.assertTrue(first.enriched)
        self.assertFalse(second.enriched)
        self.assertEqual(second.reason, CEILING_REACHED)
        self.assertEqual(len(model.calls), 1)

    async def test_a_counter_that_cannot_be_kept_refuses(self) -> None:
        """Fail closed: an unenforceable ceiling is not a ceiling, and the allowance is shared."""
        model = _Model()
        degraded = QuotaKeeper(QuotaLimits(), None)
        self.assertTrue(degraded.degraded, "the fixture must actually be degraded")

        result = await _enricher(model, allowance=degraded).enrich(_report(), "c", "en", roles=(MEMBER,))

        self.assertEqual(model.calls, [])
        self.assertEqual(result.reason, CEILING_REACHED)

    async def test_no_configured_role_switches_the_whole_thing_off(self) -> None:
        """The documented way to stop spending the allowance without touching the intake."""
        model = _Model()

        result = await _enricher(model, role="").enrich(_report(), "context", "en", roles=(MEMBER,))

        self.assertEqual(model.calls, [])
        self.assertEqual(result.reason, DISABLED)


class TestFailingWithoutFailing(unittest.IsolatedAsyncioTestCase):
    """The issue stands as filed in every one of these, and says which one happened."""

    async def test_an_unavailable_model_leaves_the_issue_alone(self) -> None:
        failure = WorkerFailure(FailureKind.UNAVAILABLE, "connection reset")

        result = await _enricher(_Model(failure=failure)).enrich(_report(), "c", "en", roles=(MEMBER,))

        self.assertFalse(result.enriched)
        self.assertEqual(result.reason, MODEL_UNAVAILABLE)

    async def test_a_blank_answer_is_not_a_hypothesis(self) -> None:
        result = await _enricher(_Model(answer="   \n  ")).enrich(_report(), "c", "en", roles=(MEMBER,))

        self.assertEqual(result.reason, EMPTY_ANSWER)

    async def test_every_refusal_carries_a_sentence_for_the_issue(self) -> None:
        """A blank paragraph would leave a reader unable to tell "not tried" from "withheld"."""
        for reason in ABSENT_REASONS:
            with self.subTest(reason=reason):
                for lang in ("fr", "en"):
                    self.assertTrue(heading(f"hypothesis.absent.{reason}", lang).strip())


class TestTheLabelling(unittest.IsolatedAsyncioTestCase):
    """A guess next to measurements, on a public tracker, read months later by somebody else."""

    async def test_the_label_is_a_heading_above_the_text(self) -> None:
        result = await _enricher(_Model(answer="the cause is X")).enrich(_report(), "c", "en", roles=(MEMBER,))

        first = result.body.splitlines()[0]
        self.assertTrue(first.startswith("## "), "a disclaimer at the bottom is one nobody reads")
        self.assertIn("guess", first)
        self.assertLess(result.body.index("guess"), result.body.index("the cause is X"))

    async def test_the_hypothesis_cannot_ping_anybody(self) -> None:
        result = await _enricher(_Model(answer="blame @everyone")).enrich(_report(), "c", "en", roles=(MEMBER,))

        self.assertNotIn("@everyone", result.body)

    async def test_it_is_written_in_the_reporters_language(self) -> None:
        result = await _enricher(_Model()).enrich(_report(), "c", "fr", roles=(MEMBER,))

        self.assertIn("supposition de machine", result.body)


class TestTheIntakePublishesIt(unittest.IsolatedAsyncioTestCase):
    """The wiring: the hypothesis lands on the issue that was just filed, and only then."""

    def _intake(self, enricher: Enricher | None, filer: _Filer) -> BugIntake:
        """Build an intake over the fixture checkout.

        Args:
            enricher: The enrichment step.
            filer: The filer stand-in.

        Returns:
            The intake.
        """
        collector = AttachmentCollector(fixture_checkout(), _fake_downloader({}))
        return BugIntake(fixture_checkout(), collector, refresh=False, filer=filer, enricher=enricher)

    async def test_the_comment_goes_on_the_issue_that_was_filed(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=FILE)
        submission = _submission()
        submission.roles = (MEMBER,)

        await self._intake(_enricher(_Model()), filer).handle(exchange, submission)

        self.assertEqual([number for number, _ in filer.comments], [901])
        self.assertIn("guess", filer.comments[0][1])

    async def test_a_refused_hypothesis_still_writes_why_on_the_issue(self) -> None:
        filer = _Filer()
        submission = _submission()
        submission.roles = ("not-a-member",)

        await self._intake(_enricher(_Model()), filer).handle(_Exchange(decision=FILE), submission)

        self.assertEqual(len(filer.comments), 1)
        self.assertIn("members", filer.comments[0][1])

    async def test_a_deployment_without_enrichment_says_nothing_at_all(self) -> None:
        """No section about a feature this deployment does not have."""
        filer = _Filer()

        await self._intake(_enricher(_Model(), role=""), filer).handle(_Exchange(decision=FILE), _submission())

        self.assertEqual(filer.comments, [])

    async def test_a_report_that_was_not_filed_is_never_enriched(self) -> None:
        """A cancelled draft costs no model call: the gates are downstream of the click."""
        model = _Model()
        filer = _Filer()

        await self._intake(_enricher(model), filer).handle(_Exchange(decision="cancel"), _submission())

        self.assertEqual(model.calls, [])
        self.assertEqual(filer.comments, [])


class TestTheServiceBuildsIt(unittest.TestCase):
    """The configuration reaches the enricher, and an unset role really does switch it off."""

    def _config(self, **overrides: str) -> Any:
        """Build a configuration over the fixture checkout.

        Args:
            **overrides: Variables to set, without the ``SUPPORT_BOT_`` prefix.

        Returns:
            The resolved configuration.
        """
        env = {
            "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
            "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
            "SUPPORT_BOT_WORKER_SECRET": "a-secret",
            "SUPPORT_BOT_HEALTH_PORT": "0",
            "SUPPORT_BOT_CHECKOUT_PATH": str(fixture_root()),
            "SUPPORT_BOT_CHECKOUT_REFRESH_SECONDS": "0",
        }
        env.update({f"SUPPORT_BOT_{key}": value for key, value in overrides.items()})
        return SupportBotConfig.from_env(env)

    def test_without_a_role_the_enricher_is_off(self) -> None:
        self.assertFalse(build_enricher(self._config()).enabled)

    def test_with_a_role_it_is_on_and_holds_the_configured_ceiling(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            enricher = build_enricher(
                self._config(
                    ENRICH_ROLE_ID=MEMBER,
                    ENRICH_PER_DAY="3",
                    ENRICH_STATE_FILE=str(Path(folder) / "enrichment.json"),
                )
            )

            self.assertTrue(enricher.enabled)
            allowance = enricher._allowance  # noqa: SLF001 - the wiring is the assertion
            assert allowance is not None, "an enabled enricher with no counter would fail closed forever"
            # All three axes carry the same number: a per-user window would let one member spend the
            # day's hypotheses in a minute, which is not what a daily allowance means.
            limits = allowance.limits
            self.assertEqual((limits.global_per_day, limits.user_per_day, limits.user_per_window), (3, 3, 3))

    def test_the_allowance_is_counted_apart_from_the_question_quota(self) -> None:
        """One file for both would let a busy day of questions eat the day's hypotheses."""
        config = self._config(ENRICH_ROLE_ID=MEMBER)

        self.assertNotEqual(config.enrich_state_file, config.quota_state_file)

    def test_the_intake_is_built_with_it(self) -> None:
        intake = build_intake(self._config(ENRICH_ROLE_ID=MEMBER))

        assert intake is not None
        self.assertIsNotNone(intake._enricher, "an enricher nobody wired reaches no issue")  # noqa: SLF001


if __name__ == "__main__":
    unittest.main()
