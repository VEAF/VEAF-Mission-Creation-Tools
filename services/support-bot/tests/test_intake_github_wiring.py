"""The wires between the sweep, the intake, the filer and the process — not the handlers.

Four bugs shipped green on this repository because the tests called the handler and never the thing
that branches to it. So this file asserts only the connections:

* the sweep runs **before** anything is opened, on the report's own words;
* an accepted duplicate **comments** and opens nothing; an accepted fix or lot opens nothing at all;
* a **rejected** match does not stop the report — that is the failure mode the ticket names;
* a filing failure **reaches the reporter**;
* the **service builds** the App, the sweeper and the filer out of the configuration, and a
  half-configured App stops the process instead of the first report.

``TestTheseTestsDetectABrokenWiring`` cuts each wire in **production** code — never in a stand-in
defined here: a detector that mutates its own double proves the double, not the wire.
"""

from __future__ import annotations

import tempfile
import unittest
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from tests.intake_fixtures import fixture_checkout, fixture_root
from tests.test_attachments import _fake_downloader
from tests.test_github_app import PEM
from tests.test_priorart import RESOLVER_REPORT, _Issues, _resolver_issue
from veaf_support_bot.attachments import AttachmentCollector
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.config import ConfigurationError, SupportBotConfig
from veaf_support_bot.filing import Outcome
from veaf_support_bot.github_app import GitHubError
from veaf_support_bot.intake import BugIntake, BugSubmission, render_match, sweep_query
from veaf_support_bot.priorart import DUPLICATE, FIXED, IN_PROGRESS, PriorArtGate, PriorArtSweeper, Sweep
from veaf_support_bot.service import build_github_app, build_intake


class _Exchange:
    """A :class:`~veaf_support_bot.intake.BugExchange` that records what the reporter was told."""

    def __init__(self) -> None:
        self.deferred = False
        self.messages: list[str] = []

    async def defer(self) -> None:
        self.deferred = True

    async def post(self, content: str) -> None:
        self.messages.append(content)


class _Filer:
    """A :class:`~veaf_support_bot.intake.ReportFiler` that records what it was asked to do."""

    def __init__(self, outcome: Outcome | None = None) -> None:
        self.outcome = outcome or Outcome(action="created", number=901, url="https://example.invalid/issues/901")
        self.filed: list[Any] = []
        self.commented: list[int] = []

    async def file(self, report: Any, *, thread_url: str = "") -> Outcome:
        self.filed.append(report)
        return self.outcome

    async def comment_on(self, number: int, report: Any, *, thread_url: str = "") -> Outcome:
        self.commented.append(number)
        return Outcome(action="commented", number=number, url=f"https://example.invalid/issues/{number}#c")


class _Answer:
    """A confirmation with a fixed answer."""

    def __init__(self, answer: bool) -> None:
        self.answer = answer
        self.asked = 0

    async def confirm(self, sweep: Sweep, lang: str) -> bool:
        self.asked += 1
        return self.answer


def _intake(**kwargs: Any) -> BugIntake:
    """Build an intake over the fixture checkout.

    Args:
        **kwargs: Passed through to :class:`~veaf_support_bot.intake.BugIntake`.

    Returns:
        The intake.
    """
    collector = AttachmentCollector(fixture_checkout(), _fake_downloader({}))
    return BugIntake(fixture_checkout(), collector, refresh=False, **kwargs)


def _submission(summary: str = RESOLVER_REPORT.splitlines()[0]) -> BugSubmission:
    """Build a submission about the sample resolver.

    Args:
        summary: The one-line summary.

    Returns:
        The submission.
    """
    return BugSubmission(
        form=BugForm(
            summary=summary,
            happened=RESOLVER_REPORT,
            expected="it should resolve the alias",
            steps="1. run it",
            reporter="Tripack",
            reporter_id="4242",
            language="en",
        ),
        attachments=[],
    )


def _gate(answer: bool | None, **issues: Any) -> PriorArtGate:
    """Build a gate over the fixture checkout.

    Args:
        answer: What the reporter answers, or ``None`` for nobody to ask.
        **issues: ``opened`` and ``closed`` issue records.

    Returns:
        The gate.
    """
    sweeper = PriorArtSweeper(fixture_root(), _Issues(**issues))
    return PriorArtGate(sweeper, None if answer is None else _Answer(answer))


class TestTheQuery(unittest.TestCase):
    """What the sweep is given to match on."""

    def test_it_is_the_reporters_own_words(self) -> None:
        query = sweep_query(_intake()._assemble(_submission().form, _harvest()))
        self.assertIn("veafSample.resolve", query)
        self.assertIn("it should resolve the alias", query)

    def test_the_attached_log_is_not_in_it(self) -> None:
        report = _intake()._assemble(_submission().form, _harvest())
        from dataclasses import replace

        report = replace(report, log_digests=("a thousand ordinary log words",))
        self.assertNotIn("a thousand ordinary log words", sweep_query(report))


def _harvest() -> Any:
    """Build an empty attachment harvest.

    Returns:
        The harvest.
    """
    from veaf_support_bot.attachments import Harvest

    return Harvest(prepared=(), rejected=())


class TestTheSweepRunsBeforeAnythingOpens(unittest.IsolatedAsyncioTestCase):
    """Ticket 03's whole point: the four sources are consulted first."""

    async def test_the_finding_is_attached_to_the_report(self) -> None:
        intake = _intake(prior_art=_gate(False, opened=[_resolver_issue()]), filer=_Filer())
        report = await intake.handle(_Exchange(), _submission())
        assert report is not None
        assert report.prior_art is not None
        self.assertEqual(report.prior_art.verdict, DUPLICATE)

    async def test_with_no_sweep_configured_the_report_says_nothing_was_checked(self) -> None:
        report = await _intake(filer=_Filer()).handle(_Exchange(), _submission())
        assert report is not None
        self.assertIsNone(report.prior_art, "an absent sweep must not read as a sweep that found nothing")


class TestWhatAnAcceptedMatchDoes(unittest.IsolatedAsyncioTestCase):
    """Three of the four verdicts open nothing at all."""

    async def test_an_accepted_duplicate_comments_and_opens_nothing(self) -> None:
        filer = _Filer()
        intake = _intake(prior_art=_gate(True, opened=[_resolver_issue()]), filer=filer)
        exchange = _Exchange()
        await intake.handle(exchange, _submission())
        self.assertEqual(filer.commented, [712])
        self.assertEqual(filer.filed, [])
        self.assertIn("#712", exchange.messages[0])

    async def test_an_accepted_fix_opens_nothing_and_names_the_version(self) -> None:
        filer = _Filer()
        intake = _intake(prior_art=_gate(True, closed=[_resolver_issue(state="closed")]), filer=filer)
        exchange = _Exchange()
        await intake.handle(exchange, _submission())
        self.assertEqual(filer.filed, [])
        self.assertEqual(filer.commented, [])
        self.assertIn("6.19.0", exchange.messages[0])

    async def test_an_accepted_lot_opens_nothing(self) -> None:
        filer = _Filer()
        intake = _intake(prior_art=_gate(True), filer=filer)
        exchange = _Exchange()
        await intake.handle(exchange, _submission())
        self.assertEqual((filer.filed, filer.commented), ([], []))
        self.assertIn("FEAT-SAMPLE-RESOLVER", exchange.messages[0])


class TestTheRefusalDoesNotEndTheReport(unittest.IsolatedAsyncioTestCase):
    """The failure mode: a wrong duplicate silences a real bug, and the reporter will not insist."""

    async def test_a_rejected_duplicate_is_filed_anyway(self) -> None:
        filer = _Filer()
        intake = _intake(prior_art=_gate(False, opened=[_resolver_issue()]), filer=filer)
        exchange = _Exchange()
        await intake.handle(exchange, _submission())
        self.assertEqual(len(filer.filed), 1)
        self.assertEqual(filer.commented, [])
        self.assertIn("https://example.invalid/issues/901", exchange.messages[0])

    async def test_with_nobody_to_ask_the_report_is_filed_and_the_finding_recorded(self) -> None:
        filer = _Filer()
        intake = _intake(prior_art=_gate(None, opened=[_resolver_issue()]), filer=filer)
        exchange = _Exchange()
        report = await intake.handle(exchange, _submission())
        self.assertEqual(len(filer.filed), 1)
        assert report is not None and report.prior_art is not None
        self.assertTrue(report.prior_art.found)

    async def test_the_proposal_shown_to_the_reporter_carries_its_evidence(self) -> None:
        intake = _intake(prior_art=_gate(None, opened=[_resolver_issue()]), filer=_Filer())
        exchange = _Exchange()
        await intake.handle(exchange, _submission())
        self.assertIn("#712", exchange.messages[0])
        self.assertIn("match on", exchange.messages[0])


class TestWhatTheReporterIsTold(unittest.IsolatedAsyncioTestCase):
    """Never a silence, and never a claim that an issue exists when it does not."""

    async def test_a_filing_failure_is_said_in_the_thread(self) -> None:
        filer = _Filer(Outcome(action="failed", error="GitHub answered 403: Resource not accessible"))
        exchange = _Exchange()
        await _intake(filer=filer).handle(exchange, _submission())
        self.assertIn("403", exchange.messages[0])
        self.assertIn("bug_report.yml", exchange.messages[0], "he is told how to file it himself")

    async def test_no_github_app_says_nothing_was_opened(self) -> None:
        exchange = _Exchange()
        await _intake().handle(exchange, _submission())
        self.assertIn("No issue was opened", exchange.messages[0])

    async def test_a_reused_issue_says_it_was_not_opened_twice(self) -> None:
        filer = _Filer(Outcome(action="reused", number=901, url="https://example.invalid/issues/901"))
        exchange = _Exchange()
        await _intake(filer=filer).handle(exchange, _submission())
        self.assertIn("already been filed", exchange.messages[0])

    async def test_a_degraded_creation_reports_its_notes(self) -> None:
        filer = _Filer(Outcome(action="created", number=901, url="u", notes=("labels could not be applied",)))
        exchange = _Exchange()
        await _intake(filer=filer).handle(exchange, _submission())
        self.assertIn("labels could not be applied", exchange.messages[0])

    async def test_an_existing_sink_still_owns_the_answer(self) -> None:
        filer = _Filer()

        async def _sink(report: Any) -> str:
            return "the preview ticket 04 owns"

        exchange = _Exchange()
        await _intake(sink=_sink, filer=filer).handle(exchange, _submission())
        self.assertEqual(exchange.messages, ["the preview ticket 04 owns"])
        self.assertEqual(filer.filed, [], "the consent click decides, not the intake")


class TestTheServiceBuildsIt(unittest.TestCase):
    """The configuration reaches the objects, or the process refuses to start."""

    def setUp(self) -> None:
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.key = Path(self.folder.name) / "key.pem"
        self.key.write_text(PEM, encoding="utf-8")

    def _config(self, **overrides: str) -> SupportBotConfig:
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

    def _configured(self, **overrides: str) -> SupportBotConfig:
        settings = {
            "GITHUB_APP_ID": "123456",
            "GITHUB_INSTALLATION_ID": "7890",
            "GITHUB_PRIVATE_KEY_FILE": str(self.key),
        }
        settings.update(overrides)
        return self._config(**settings)

    def test_an_intake_without_an_app_still_sweeps_the_checkout(self) -> None:
        intake = build_intake(self._config())
        assert intake is not None
        self.assertIsNotNone(intake._prior_art, "the two file sources need no credentials")
        self.assertIsNone(intake._filer)

    def test_a_configured_app_produces_a_filer_and_an_issue_backed_sweep(self) -> None:
        intake = build_intake(self._configured())
        assert intake is not None
        self.assertIsNotNone(intake._filer)
        assert intake._prior_art is not None
        self.assertIsNotNone(intake._prior_art.sweeper.issues)

    def test_the_app_is_pointed_at_the_configured_repository(self) -> None:
        app = build_github_app(self._configured(GITHUB_REPOSITORY="VEAF/other"))
        assert app is not None
        self.assertEqual(app.repository, "VEAF/other")
        self.assertEqual(app.credentials.app_id, "123456")

    def test_no_app_configured_builds_no_client(self) -> None:
        self.assertIsNone(build_github_app(self._config()))

    def test_half_an_app_refuses_to_start(self) -> None:
        with self.assertRaises(ConfigurationError) as caught:
            self._config(GITHUB_APP_ID="123456")
        self.assertIn("GITHUB_INSTALLATION_ID", str(caught.exception))

    def test_a_key_given_twice_refuses_to_start(self) -> None:
        with self.assertRaises(ConfigurationError) as caught:
            self._configured(GITHUB_PRIVATE_KEY="-----BEGIN-----\\nx\\n-----END-----")
        self.assertIn("keep one", str(caught.exception))

    def test_a_repository_that_is_not_owner_slash_name_refuses_to_start(self) -> None:
        with self.assertRaises(ConfigurationError):
            self._configured(GITHUB_REPOSITORY="justaname")

    def test_the_private_key_never_reaches_a_log_line(self) -> None:
        redacted = self._configured(GITHUB_PRIVATE_KEY_FILE=str(self.key)).redacted()
        self.assertNotIn("PRIVATE KEY", repr(redacted))

    def test_an_inline_key_is_masked_in_the_loggable_configuration(self) -> None:
        config = self._config(
            GITHUB_APP_ID="1",
            GITHUB_INSTALLATION_ID="2",
            GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\\nMIIEbodyofthekey\\n-----END RSA PRIVATE KEY-----",
        )
        # Not the word "secret": `worker_secret` is a field *name* and appears in every repr.
        self.assertNotIn("MIIEbodyofthekey", repr(config))
        self.assertEqual(config.redacted()["github_private_key"], "***redacted***")

    def test_a_key_that_reads_but_cannot_sign_also_stops_the_process(self) -> None:
        """Reachable is not usable, and the difference used to surface a week later.

        `read_private_key` proves the bytes were *there*. A truncated PEM reads back fine and dies
        at the first `jwt()` — which is the first bug report, in a service whose health endpoints,
        Discord connection and documentation answers are all green.
        """
        malformed = Path(self.folder.name) / "truncated.pem"
        malformed.write_text(PEM[: len(PEM) // 2], encoding="utf-8")
        with self.assertRaises(GitHubError) as caught:
            build_github_app(self._configured(GITHUB_PRIVATE_KEY_FILE=str(malformed)))
        self.assertIn("private key", str(caught.exception))
        self.assertNotIn("PRIVATE KEY-----", str(caught.exception), "the message must not quote the key")

    def test_a_key_that_is_not_rsa_stops_the_process_too(self) -> None:
        """The second shape the reader cannot see: valid PEM, wrong algorithm."""
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import ec

        elliptic = Path(self.folder.name) / "ec.pem"
        elliptic.write_bytes(
            ec.generate_private_key(ec.SECP256R1()).private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption(),
            )
        )
        with self.assertRaises(GitHubError):
            build_github_app(self._configured(GITHUB_PRIVATE_KEY_FILE=str(elliptic)))

    def test_an_unreadable_key_stops_the_process_with_the_configuration_exit_code(self) -> None:
        # Two halves, because the wire has two ends: the build refuses, and the entry point turns
        # that refusal into the exit code a supervisor reads as "restarting will not help".
        from veaf_support_bot import cli
        from veaf_support_bot.github_app import GitHubError

        broken = Path(self.folder.name) / "missing.pem"
        with self.assertRaises(GitHubError):
            build_github_app(self._configured(GITHUB_PRIVATE_KEY_FILE=str(broken)))

        config = self._config()

        def _raise(_config: SupportBotConfig) -> None:
            raise GitHubError("the GitHub App private key file could not be read (FileNotFoundError)")

        original_run, original_from_env = cli._run, SupportBotConfig.from_env
        cli._run = _raise  # type: ignore[assignment]
        SupportBotConfig.from_env = classmethod(lambda cls, env=None: config)  # type: ignore[assignment]
        try:
            self.assertEqual(cli.main([]), cli.EXIT_CONFIG_ERROR)
        finally:
            cli._run = original_run
            SupportBotConfig.from_env = original_from_env  # type: ignore[method-assign]


class TestTheProposalRendering(unittest.TestCase):
    """A verdict must never be rendered as a bare assertion."""

    def test_a_fixed_verdict_without_a_version_says_so_instead_of_inventing_one(self) -> None:
        from veaf_support_bot.priorart import Candidate, Match

        sweep = Sweep(
            verdict=FIXED,
            best=Match(Candidate("closed issue", "#1", "t", url="u"), 0.5, ("x",)),
        )
        rendered = render_match(sweep, "en")
        self.assertIn("names no version", rendered)

    def test_nothing_found_renders_nothing(self) -> None:
        self.assertEqual(render_match(Sweep(), "en"), "")

    def test_an_in_progress_verdict_names_the_lot(self) -> None:
        from veaf_support_bot.priorart import Candidate, Match

        sweep = Sweep(
            verdict=IN_PROGRESS,
            best=Match(Candidate("backlog lot", "FEAT-X", "a lot", url=".backlog/FEAT-X/PRD.md"), 0.5, ("x",)),
        )
        self.assertIn("FEAT-X", render_match(sweep, "fr"))


class TestTheseTestsDetectABrokenWiring(unittest.TestCase):
    """Cut each wire in the shipped module; the named test must go red."""

    def _fails(self, name: str) -> bool:
        """Run one test of this file and say whether it failed.

        Args:
            name: ``Class.method``.

        Returns:
            ``True`` when it did not pass.
        """
        suite = unittest.TestLoader().loadTestsFromName(f"tests.test_intake_github_wiring.{name}")
        result = unittest.TestResult()
        suite.run(result)
        return not result.wasSuccessful()

    def test_an_intake_that_stopped_sweeping_is_caught(self) -> None:
        from veaf_support_bot import intake as module

        original = module.BugIntake._sweep

        async def _no_sweep(self, report, lang):  # type: ignore[no-untyped-def]
            return None, False

        module.BugIntake._sweep = _no_sweep  # type: ignore[method-assign]
        try:
            self.assertTrue(
                self._fails("TestTheSweepRunsBeforeAnythingOpens.test_the_finding_is_attached_to_the_report")
            )
        finally:
            module.BugIntake._sweep = original  # type: ignore[method-assign]

    def test_an_accepted_duplicate_that_files_anyway_is_caught(self) -> None:
        from veaf_support_bot import intake as module

        original = module.BugIntake._act_on

        async def _file_regardless(self, sweep, report, lang, thread_url):  # type: ignore[no-untyped-def]
            return await self._file(report, lang, thread_url)

        module.BugIntake._act_on = _file_regardless  # type: ignore[method-assign]
        try:
            self.assertTrue(
                self._fails("TestWhatAnAcceptedMatchDoes.test_an_accepted_duplicate_comments_and_opens_nothing")
            )
        finally:
            module.BugIntake._act_on = original  # type: ignore[method-assign]

    def test_a_rejection_that_silences_the_report_is_caught(self) -> None:
        from veaf_support_bot import intake as module

        original = module.BugIntake._decide

        async def _stop_on_any_match(self, report, lang, thread_url):  # type: ignore[no-untyped-def]
            sweep, _ = await self._sweep(report, lang)
            from dataclasses import replace

            report = replace(report, prior_art=sweep)
            if sweep is not None and sweep.found:
                return report, render_match(sweep, lang)
            return report, await self._file(report, lang, thread_url)

        module.BugIntake._decide = _stop_on_any_match  # type: ignore[method-assign]
        try:
            self.assertTrue(self._fails("TestTheRefusalDoesNotEndTheReport.test_a_rejected_duplicate_is_filed_anyway"))
        finally:
            module.BugIntake._decide = original  # type: ignore[method-assign]

    def test_a_swallowed_filing_failure_is_caught(self) -> None:
        from veaf_support_bot import intake as module

        original = module._render_outcome
        module._render_outcome = lambda outcome, lang, report: "done"
        try:
            self.assertTrue(self._fails("TestWhatTheReporterIsTold.test_a_filing_failure_is_said_in_the_thread"))
        finally:
            module._render_outcome = original

    def test_a_service_that_stopped_building_the_filer_is_caught(self) -> None:
        from veaf_support_bot import service as module

        original = module.build_github_app
        module.build_github_app = lambda config: None
        try:
            self.assertTrue(
                self._fails("TestTheServiceBuildsIt.test_a_configured_app_produces_a_filer_and_an_issue_backed_sweep")
            )
        finally:
            module.build_github_app = original

    def test_a_service_that_stopped_building_the_sweeper_is_caught(self) -> None:
        from veaf_support_bot import service as module

        original = module.PriorArtGate
        module.PriorArtGate = lambda sweeper: None  # type: ignore[assignment,misc]
        try:
            self.assertTrue(
                self._fails("TestTheServiceBuildsIt.test_an_intake_without_an_app_still_sweeps_the_checkout")
            )
        finally:
            module.PriorArtGate = original  # type: ignore[misc]

    def test_a_half_configured_app_accepted_at_startup_is_caught(self) -> None:
        from veaf_support_bot import config as module

        original = module._check_github
        module._check_github = lambda reader, config: None
        try:
            self.assertTrue(self._fails("TestTheServiceBuildsIt.test_half_an_app_refuses_to_start"))
        finally:
            module._check_github = original

    def test_an_unreadable_key_that_does_not_stop_the_process_is_caught(self) -> None:
        from veaf_support_bot import github_app as module

        original = module.read_private_key
        module.read_private_key = lambda inline, path: PEM
        # `service` resolved the name at import time, so the binding it uses is the one to cut.
        from veaf_support_bot import service as service_module

        service_original = service_module.read_private_key
        service_module.read_private_key = lambda inline, path: PEM
        try:
            self.assertTrue(
                self._fails(
                    "TestTheServiceBuildsIt.test_an_unreadable_key_stops_the_process_with_the_configuration_exit_code"
                )
            )
        finally:
            module.read_private_key = original
            service_module.read_private_key = service_original


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
