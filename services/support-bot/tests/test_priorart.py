"""The four sources, the four outcomes, and the refusal that keeps a real bug alive.

The verdicts are asserted one per test, and so is the case the ticket calls the failure mode: a
match the reporter rejects must leave the flow running, not end it.
"""

from __future__ import annotations

import asyncio
import unittest
from collections.abc import Sequence
from pathlib import Path

from tests.intake_fixtures import fixture_root
from veaf_support_bot.priorart import (
    DUPLICATE,
    FIXED,
    IN_PROGRESS,
    MATCH_MIN_SCORE,
    NONE,
    SOURCE_BACKLOG,
    SOURCE_CLOSED_ISSUE,
    SOURCE_OPEN_ISSUE,
    SOURCE_ROADMAP,
    Candidate,
    IssueRecord,
    Match,
    PriorArtGate,
    PriorArtSweeper,
    Sweep,
    fix_version,
    fold,
    rank,
    read_backlog,
    read_roadmap,
    score_against,
    tokenize,
)

#: A report about the sample resolver, in the reporter's own words.
RESOLVER_REPORT = (
    "veafSample.resolve drops an alias when two aliases share a name\n"
    "The mission_builder spawner then places the group at the wrong airfield."
)


class _Issues:
    """An :class:`~veaf_support_bot.priorart.IssueSource` over a fixed pair of lists."""

    def __init__(self, opened: Sequence[IssueRecord] = (), closed: Sequence[IssueRecord] = ()) -> None:
        self.opened = list(opened)
        self.closed = list(closed)

    async def open_issues(self) -> Sequence[IssueRecord]:
        return self.opened

    async def recently_closed_issues(self) -> Sequence[IssueRecord]:
        return self.closed


class _BrokenIssues:
    """An issue source that cannot answer."""

    async def open_issues(self) -> Sequence[IssueRecord]:
        raise TimeoutError("the tracker did not answer")

    async def recently_closed_issues(self) -> Sequence[IssueRecord]:
        return ()


class _Answer:
    """A confirmation that always gives the same answer, and remembers what it was shown."""

    def __init__(self, answer: bool) -> None:
        self.answer = answer
        self.shown: list[Sweep] = []

    async def confirm(self, sweep: Sweep, lang: str) -> bool:
        self.shown.append(sweep)
        return self.answer


def _resolver_issue(number: int = 712, state: str = "open") -> IssueRecord:
    """Build an issue describing the same defect as :data:`RESOLVER_REPORT`.

    Args:
        number: The issue number.
        state: ``"open"`` or ``"closed"``.

    Returns:
        The record.
    """
    return IssueRecord(
        number=number,
        title="veafSample.resolve loses an alias",
        body="Two aliases of the same name, and mission_builder spawns the group at the wrong airfield.",
        url=f"https://example.invalid/issues/{number}",
        state=state,
        closed_at="2026-09-02T10:00:00Z" if state == "closed" else "",
    )


def _candidate() -> Candidate:
    """Build a candidate shaped like a real issue: a title **and** a body.

    Returns:
        The candidate.
    """
    record = _resolver_issue()
    return Candidate(SOURCE_OPEN_ISSUE, f"#{record.number}", record.title, record.body, record.url)


class TestTokenising(unittest.TestCase):
    """What the score treats as discriminating, and what it throws away."""

    def test_accents_and_case_are_folded(self) -> None:
        self.assertEqual(fold("Problème DÉTECTÉ"), "probleme detecte")

    def test_an_identifier_is_a_signal_token_and_a_short_word_is_not(self) -> None:
        signal, ordinary = tokenize("the mission_builder crashed on mission.yaml")
        self.assertIn("mission_builder", signal)
        self.assertIn("mission.yaml", signal)
        self.assertIn("crashed", ordinary)

    def test_stop_words_are_dropped_entirely(self) -> None:
        signal, ordinary = tokenize("the and pour avec")
        self.assertEqual((signal, ordinary), (frozenset(), frozenset()))


class TestScoring(unittest.TestCase):
    """A proposal needs something distinctive; ordinary words alone are not enough."""

    def test_two_reports_sharing_only_common_words_are_not_matched(self) -> None:
        signal, ordinary = tokenize("le bug arrive quand je lance")
        candidate = Candidate(SOURCE_OPEN_ISSUE, "#1", "un bug arrive quand je lance")
        self.assertIsNone(score_against(signal, ordinary, candidate))

    def test_a_shared_identifier_carries_the_match(self) -> None:
        signal, ordinary = tokenize(RESOLVER_REPORT)
        match = score_against(signal, ordinary, _candidate())
        assert match is not None
        self.assertGreaterEqual(match.score, MATCH_MIN_SCORE)
        self.assertIn("veafsample.resolve", match.shared)

    def test_the_evidence_names_the_source_the_reference_and_the_shared_words(self) -> None:
        signal, ordinary = tokenize(RESOLVER_REPORT)
        match = score_against(signal, ordinary, _candidate())
        assert match is not None
        evidence = match.evidence()
        self.assertIn(SOURCE_OPEN_ISSUE, evidence)
        self.assertIn("#712", evidence)
        self.assertIn("veafsample.resolve", evidence)

    def test_an_empty_report_matches_nothing(self) -> None:
        self.assertIsNone(score_against(frozenset(), frozenset(), Candidate(SOURCE_OPEN_ISSUE, "#1", "")))

    def test_ranking_prefers_a_fix_over_a_duplicate_at_an_equal_score(self) -> None:
        fixed = Candidate(SOURCE_CLOSED_ISSUE, "#2", "t")
        duplicate = Candidate(SOURCE_OPEN_ISSUE, "#1", "t")
        ordered = rank(
            [
                _match(duplicate, 0.5),
                _match(fixed, 0.5),
            ]
        )
        self.assertEqual(ordered[0].candidate.source, SOURCE_CLOSED_ISSUE)


def _match(candidate: Candidate, score: float) -> Match:
    """Build a match without going through the scorer.

    Args:
        candidate: What it points at.
        score: Its score.

    Returns:
        The match.
    """
    return Match(candidate=candidate, score=score, shared=("x",))


class TestTheCheckoutSources(unittest.TestCase):
    """``.backlog/`` and ``ROADMAP.md``, read off disk."""

    def test_an_open_lot_is_a_candidate_and_a_closed_one_is_not(self) -> None:
        lots, problem, unreadable = read_backlog(fixture_root())
        self.assertEqual(problem, "")
        self.assertEqual(unreadable, [])
        references = [lot.reference for lot in lots]
        self.assertIn("FEAT-SAMPLE-RESOLVER", references)
        self.assertNotIn("FEAT-ALREADY-DONE", references)

    def test_a_missing_backlog_is_a_stated_problem_not_an_empty_result(self) -> None:
        lots, problem, unreadable = read_backlog(Path(__file__).parent / "no-such-checkout")
        self.assertEqual(lots, [])
        self.assertEqual(unreadable, [])
        self.assertIn("not a directory", problem)

    def test_each_roadmap_section_is_a_candidate(self) -> None:
        sections, problem = read_roadmap(fixture_root())
        self.assertEqual(problem, "")
        self.assertIn("2. Parked deliberately", [section.reference for section in sections])

    def test_a_missing_roadmap_is_a_stated_problem(self) -> None:
        sections, problem = read_roadmap(Path(__file__).parent / "no-such-checkout")
        self.assertEqual(sections, [])
        self.assertIn("missing", problem)

    def test_the_version_that_carries_a_fix_is_read_off_the_changelog(self) -> None:
        self.assertEqual(fix_version(fixture_root(), 712), "6.19.0")

    def test_an_unreleased_citation_yields_no_version(self) -> None:
        self.assertEqual(fix_version(fixture_root(), 909), "")

    def test_an_uncited_issue_yields_no_version_rather_than_a_guess(self) -> None:
        self.assertEqual(fix_version(fixture_root(), 999999), "")

    def test_a_missing_changelog_yields_no_version(self) -> None:
        self.assertEqual(fix_version(Path(__file__).parent / "no-such-checkout", 712), "")


class TestTheFourOutcomes(unittest.IsolatedAsyncioTestCase):
    """One test per verdict the ticket names, and one for the fourth: nothing found."""

    async def test_an_open_issue_produces_already_reported(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()]))
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertEqual(sweep.verdict, DUPLICATE)
        assert sweep.best is not None
        self.assertEqual(sweep.best.candidate.reference, "#712")

    async def test_a_closed_issue_produces_already_fixed_with_its_version(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues(closed=[_resolver_issue(state="closed")]))
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertEqual(sweep.verdict, FIXED)
        assert sweep.best is not None
        self.assertEqual(sweep.best.candidate.detail, "6.19.0")

    async def test_a_backlog_lot_produces_work_in_progress(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues())
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertEqual(sweep.verdict, IN_PROGRESS)
        assert sweep.best is not None
        self.assertEqual(sweep.best.candidate.source, SOURCE_BACKLOG)

    async def test_a_roadmap_section_can_produce_work_in_progress(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues())
        sweep = await sweeper.sweep(
            "the mission_builder catalogue rewrite never regenerated the airdromes table per theatre"
        )
        self.assertEqual(sweep.verdict, IN_PROGRESS)
        assert sweep.best is not None
        self.assertEqual(sweep.best.candidate.source, SOURCE_ROADMAP)

    async def test_an_unrelated_report_finds_nothing(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues())
        sweep = await sweeper.sweep("the radio menu shows Cyrillic on a Kola map at dusk")
        self.assertEqual(sweep.verdict, NONE)
        self.assertIsNone(sweep.best)


class TestWhatWasCheckedIsRecorded(unittest.IsolatedAsyncioTestCase):
    """A reader must be able to see the sweep ran, and see when it could not."""

    async def test_every_source_is_named_with_how_much_it_held(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()]))
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        described = sweep.describe()
        for expected in ("open issue", "recently closed issue", "backlog lot", "roadmap section"):
            self.assertIn(expected, described)

    async def test_a_tracker_that_fails_is_a_stated_gap_not_a_silent_zero(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), _BrokenIssues())
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertIn("the issue tracker (TimeoutError)", sweep.problems)
        self.assertIn("Not consulted", sweep.describe())

    async def test_no_credentials_says_so_rather_than_pretending_the_tracker_was_read(self) -> None:
        sweeper = PriorArtSweeper(fixture_root(), None)
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertTrue(any("no GitHub credentials" in problem for problem in sweep.problems))
        self.assertNotIn("open issue(s)", sweep.describe())

    async def test_a_sweep_with_no_source_at_all_still_describes_itself(self) -> None:
        sweeper = PriorArtSweeper(Path(__file__).parent / "no-such-checkout", None)
        sweep = await sweeper.sweep(RESOLVER_REPORT)
        self.assertIn("nothing could be consulted", sweep.describe())


class TestTheRefusal(unittest.IsolatedAsyncioTestCase):
    """The guard: a proposal the reporter refuses must not end his report."""

    async def test_an_accepted_match_is_reported_as_accepted(self) -> None:
        gate = PriorArtGate(PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()])), _Answer(True))
        sweep, accepted = await gate.run(RESOLVER_REPORT, "fr")
        self.assertTrue(accepted)
        self.assertEqual(sweep.verdict, DUPLICATE)

    async def test_a_rejected_match_leaves_the_flow_running(self) -> None:
        answer = _Answer(False)
        gate = PriorArtGate(PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()])), answer)
        sweep, accepted = await gate.run(RESOLVER_REPORT, "fr")
        self.assertFalse(accepted)
        self.assertTrue(sweep.found, "the finding survives the refusal, so the issue can record it")

    async def test_the_reporter_is_shown_the_evidence_before_being_asked(self) -> None:
        answer = _Answer(False)
        gate = PriorArtGate(PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()])), answer)
        await gate.run(RESOLVER_REPORT, "fr")
        self.assertEqual(len(answer.shown), 1)
        assert answer.shown[0].best is not None
        self.assertTrue(answer.shown[0].best.shared, "a proposal with no shared word is an assertion")

    async def test_with_nobody_to_ask_the_gate_refuses_rather_than_silencing_the_report(self) -> None:
        gate = PriorArtGate(PriorArtSweeper(fixture_root(), _Issues(opened=[_resolver_issue()])), None)
        sweep, accepted = await gate.run(RESOLVER_REPORT, "fr")
        self.assertTrue(sweep.found)
        self.assertFalse(accepted)

    async def test_nothing_found_is_never_offered_for_confirmation(self) -> None:
        answer = _Answer(True)
        gate = PriorArtGate(PriorArtSweeper(fixture_root(), _Issues()), answer)
        _, accepted = await gate.run("the radio menu shows Cyrillic on a Kola map at dusk", "fr")
        self.assertFalse(accepted)
        self.assertEqual(answer.shown, [])


class TestTheseTestsDetectABrokenSweep(unittest.TestCase):
    """Each cut is made in the shipped module, and the matching test must go red.

    A detector that mutates a stand-in defined in this file proves the stand-in.
    """

    def _fails(self, name: str) -> bool:
        """Run one test of this file and say whether it failed.

        Args:
            name: ``Class.method``.

        Returns:
            ``True`` when it did not pass.
        """
        loader = unittest.TestLoader()
        suite = loader.loadTestsFromName(f"tests.test_priorart.{name}")
        result = unittest.TestResult()
        suite.run(result)
        return not result.wasSuccessful()

    def test_a_gate_that_stopped_asking_is_caught(self) -> None:
        from veaf_support_bot import priorart

        original = priorart.PriorArtGate.run

        async def _always_accept(self, query: str, lang: str):  # type: ignore[no-untyped-def]
            return await self.sweeper.sweep(query), True

        priorart.PriorArtGate.run = _always_accept  # type: ignore[method-assign]
        try:
            self.assertTrue(self._fails("TestTheRefusal.test_a_rejected_match_leaves_the_flow_running"))
        finally:
            priorart.PriorArtGate.run = original  # type: ignore[method-assign]

    def test_a_sweep_that_stopped_reading_the_backlog_is_caught(self) -> None:
        from veaf_support_bot import priorart

        original = priorart.read_backlog
        priorart.read_backlog = lambda root: ([], "", [])
        try:
            self.assertTrue(self._fails("TestTheFourOutcomes.test_a_backlog_lot_produces_work_in_progress"))
        finally:
            priorart.read_backlog = original

    def test_a_closed_lot_leaking_back_into_the_corpus_is_caught(self) -> None:
        from veaf_support_bot import priorart

        original = priorart.CLOSED_LOT_STATUSES
        priorart.CLOSED_LOT_STATUSES = ()  # type: ignore[assignment]
        try:
            self.assertTrue(
                self._fails("TestTheCheckoutSources.test_an_open_lot_is_a_candidate_and_a_closed_one_is_not")
            )
        finally:
            priorart.CLOSED_LOT_STATUSES = original

    def test_a_tracker_failure_swallowed_into_silence_is_caught(self) -> None:
        from veaf_support_bot import priorart

        original = priorart.PriorArtSweeper._issue_records

        async def _silent(self):  # type: ignore[no-untyped-def]
            return (), (), True

        priorart.PriorArtSweeper._issue_records = _silent  # type: ignore[method-assign]
        try:
            self.assertTrue(
                self._fails("TestWhatWasCheckedIsRecorded.test_a_tracker_that_fails_is_a_stated_gap_not_a_silent_zero")
            )
        finally:
            priorart.PriorArtSweeper._issue_records = original  # type: ignore[method-assign]

    def test_dropping_the_evidence_from_a_proposal_is_caught(self) -> None:
        from veaf_support_bot import priorart

        original = priorart.EVIDENCE_MAX_TOKENS
        priorart.EVIDENCE_MAX_TOKENS = 0
        try:
            self.assertTrue(self._fails("TestTheRefusal.test_the_reporter_is_shown_the_evidence_before_being_asked"))
        finally:
            priorart.EVIDENCE_MAX_TOKENS = original


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
