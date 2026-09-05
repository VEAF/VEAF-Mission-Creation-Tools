"""The ``/bug`` exchange itself: the order of the steps, and what the reporter is told.

The order is the part that can break silently. Downloading before deferring means Discord closes the
interaction and the reporter sees *"the application did not respond"* while the service happily
works on a report nobody will ever be shown — so the order is recorded and asserted, not assumed.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any, cast

from tests.intake_fixtures import PYTHON_TRACEBACK, doctor_block, fixture_checkout
from tests.test_attachments import _fake_downloader
from tests.test_toolkit import SYNTHETIC_LOG
from veaf_support_bot.attachments import AttachmentCollector, Incoming, Prepared
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.intake import (
    PREVIEW_MAX_CHARS,
    BugIntake,
    BugSubmission,
    _redacted_form,
    render_preview,
)


class RecordingExchange:
    """Records the order the exchange was driven in."""

    def __init__(self) -> None:
        self.calls: list[str] = []
        self.posted: list[str] = []

    async def defer(self) -> None:
        self.calls.append("defer")

    async def post(self, content: str) -> None:
        self.calls.append("post")
        self.posted.append(content)


class _RecordingCollector(AttachmentCollector):
    """A collector that notes when it ran, so the order can be asserted."""

    def __init__(self, exchange: RecordingExchange, *args: object, **kwargs: object) -> None:
        super().__init__(*args, **kwargs)  # type: ignore[arg-type]
        self._exchange = exchange

    async def collect(self, incoming: list[Incoming], workdir: Path):  # type: ignore[no-untyped-def]
        self._exchange.calls.append("collect")
        return await super().collect(incoming, workdir)


def _form(**overrides: str) -> BugForm:
    base = {
        "summary": "convert-v5 crashes",
        "happened": PYTHON_TRACEBACK,
        "expected": "it should convert",
        "steps": "run it",
        "doctor": doctor_block("6.16.3"),
        "reporter": "Someone",
        "reporter_id": "42",
        "language": "en",
    }
    base.update(overrides)
    return BugForm(**base)


class TestTheExchange(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()
        self.exchange = RecordingExchange()

    def _intake(self, bodies: dict[str, bytes] | None = None, **kwargs: object) -> BugIntake:
        collector = _RecordingCollector(
            self.exchange,
            self.checkout,
            _fake_downloader(bodies or {}),
        )
        return BugIntake(self.checkout, collector, refresh=False, **kwargs)  # type: ignore[arg-type]

    async def test_the_submission_is_acknowledged_before_anything_slow_runs(self) -> None:
        await self._intake().handle(self.exchange, BugSubmission(_form(), []))
        self.assertEqual(self.exchange.calls[0], "defer")
        self.assertIn("collect", self.exchange.calls)
        self.assertLess(self.exchange.calls.index("defer"), self.exchange.calls.index("collect"))

    async def test_the_reporter_is_shown_what_was_found(self) -> None:
        await self._intake().handle(self.exchange, BugSubmission(_form(), []))
        shown = self.exchange.posted[0]
        self.assertIn("6.16.3", shown)
        self.assertIn("sample.py", shown)

    async def test_an_attached_log_reaches_the_report(self) -> None:
        body = (SYNTHETIC_LOG + "\n").encode("utf-8")
        report = await self._intake({"u": body}).handle(
            self.exchange, BugSubmission(_form(), [Incoming("dcs.log", "u", len(body))])
        )
        assert report is not None
        self.assertEqual(len(report.log_digests), 1)
        self.assertEqual(len(report.attachments), 1)

    async def test_each_kind_of_attachment_lands_in_its_own_bucket(self) -> None:
        """A `mission.yaml` filed under *log excerpts* would come out under the wrong heading."""
        log = (SYNTHETIC_LOG + "\n").encode("utf-8")
        yaml = b"modules:\n  spawn: true\n"
        report = await self._intake({"a": log, "b": yaml}).handle(
            self.exchange,
            BugSubmission(
                _form(),
                [Incoming("dcs.log", "a", len(log)), Incoming("mission.yaml", "b", len(yaml))],
            ),
        )
        assert report is not None
        self.assertEqual(len(report.log_digests), 1)
        self.assertEqual(len(report.quoted_files), 1)
        self.assertIn("mission.yaml", report.quoted_files[0])
        self.assertNotIn("mission.yaml", "".join(report.log_digests))

    async def test_the_downloaded_files_are_still_there_while_the_sink_runs(self) -> None:
        """Ticket 05 uploads them to the issue; a cleanup before that hands it paths to nothing."""
        seen: list[bool] = []

        async def sink(report: object) -> str:
            prepared = cast(Prepared, cast(Any, report).attachments[0])
            seen.append(prepared.path.is_file())
            return "filed"

        await self._intake({"u": b"hello"}, sink=sink).handle(
            self.exchange, BugSubmission(_form(), [Incoming("notes.txt", "u", 5)])
        )
        self.assertEqual(seen, [True])

    async def test_the_temporary_directory_does_not_survive_the_exchange(self) -> None:
        body = b"hello"
        report = await self._intake({"u": body}).handle(
            self.exchange, BugSubmission(_form(), [Incoming("notes.txt", "u", 5)])
        )
        assert report is not None
        prepared = cast(Prepared, report.attachments[0])
        self.assertFalse(prepared.path.exists(), "an 11 MB log per report would fill the disk")

    async def test_a_failure_after_the_acknowledgement_becomes_a_sentence(self) -> None:
        """A placeholder that never resolves is the silent failure this service exists to avoid."""

        class _Exploding(AttachmentCollector):
            async def collect(self, incoming, workdir):  # type: ignore[no-untyped-def]
                raise RuntimeError("boom")

        intake = BugIntake(
            self.checkout,
            _Exploding(self.checkout, _fake_downloader({})),
            refresh=False,
        )
        report = await intake.handle(self.exchange, BugSubmission(_form(), []))
        self.assertIsNone(report)
        self.assertIn("went wrong", self.exchange.posted[0])

    async def test_a_report_goes_to_the_sink_when_there_is_one(self) -> None:
        seen: list[object] = []

        async def sink(report: object) -> str:
            seen.append(report)
            return "filed"

        await self._intake(sink=sink).handle(self.exchange, BugSubmission(_form(), []))
        self.assertEqual(len(seen), 1)
        self.assertEqual(self.exchange.posted[0], "filed")

    async def test_the_preview_never_exceeds_what_discord_accepts(self) -> None:
        long_form = _form(happened=PYTHON_TRACEBACK + ("very long line " * 400))
        await self._intake().handle(self.exchange, BugSubmission(long_form, []))
        self.assertLessEqual(len(self.exchange.posted[0]), PREVIEW_MAX_CHARS)


class TestRedactingTheFormWithoutLosingItsShape(unittest.TestCase):
    def test_a_home_directory_straddling_two_fields_is_still_stripped(self) -> None:
        """Redacting field by field would miss an account name recognised from a neighbour."""
        form = _form(happened=r"C:\Users\Firstname Lastname\dev crashed")
        checkout = fixture_checkout()
        from veaf_support_bot.bugreport import safe_redact

        redacted, _ = safe_redact(checkout, form.all_text())
        rebuilt = _redacted_form(form, redacted)
        self.assertNotIn("Firstname Lastname", rebuilt.all_text())

    def test_the_fields_come_back_on_their_own_boundaries(self) -> None:
        form = _form()
        rebuilt = _redacted_form(form, form.all_text().replace("convert-v5", "convert-vX"))
        self.assertEqual(rebuilt.expected, form.expected)
        self.assertEqual(rebuilt.steps, form.steps)
        self.assertEqual(rebuilt.doctor, form.doctor)

    def test_unchanged_text_returns_the_same_form(self) -> None:
        form = _form()
        self.assertIs(_redacted_form(form, form.all_text()), form)

    def test_a_redaction_that_changed_the_shape_is_refused_rather_than_mis_assigned(self) -> None:
        form = _form()
        with self.assertRaises(ValueError):
            _redacted_form(form, form.all_text() + "\nan extra line")


class TestThePreview(unittest.TestCase):
    def test_a_report_with_no_location_says_so_rather_than_showing_an_empty_section(self) -> None:
        from veaf_support_bot.bugreport import assemble

        report = assemble(_form(happened="the button did nothing"), fixture_checkout())
        rendered = render_preview(report, "en")
        self.assertIn("No usable error trace", rendered)

    def test_the_revision_travels_with_every_location(self) -> None:
        from veaf_support_bot.bugreport import assemble

        report = assemble(_form(), fixture_checkout())
        self.assertIn(report.freshness.revision, render_preview(report, "en"))


class TestTheTemporaryDirectoryIsCleanedEvenOnFailure(unittest.IsolatedAsyncioTestCase):
    async def test_a_crash_during_assembly_leaves_nothing_behind(self) -> None:
        checkout = fixture_checkout()

        class _Exploding(AttachmentCollector):
            async def collect(self, incoming, workdir):  # type: ignore[no-untyped-def]
                self.seen = workdir
                raise RuntimeError("boom")

        collector = _Exploding(checkout, _fake_downloader({}))
        intake = BugIntake(checkout, collector, refresh=False)
        exchange = RecordingExchange()
        self.assertIsNone(await intake.handle(exchange, BugSubmission(_form(), [])))
        self.assertFalse(Path(collector.seen).exists())


class TestTheRealDownloader(unittest.IsolatedAsyncioTestCase):
    """The downloader the fake above stands in for, against a real socket.

    Worth the server it takes to run: the ceiling is the one thing here that a header can lie about,
    and a fake that enforces it correctly proves only that the fake is correct.
    """

    def setUp(self) -> None:
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from threading import Thread

        body = b"x" * 200_000

        class _Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:  # noqa: N802 - the stdlib's own naming
                self.send_response(200)
                # A deliberate lie: the header claims one byte, the body is 200 kB.
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_: object) -> None:
                return None

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.shutdown)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/file.log"
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)

    async def test_a_body_within_the_ceiling_lands_on_disk(self) -> None:
        from veaf_support_bot.attachments import http_download

        target = Path(self.directory.name) / "ok.log"
        written = await http_download(self.url, target, 1_000_000)
        self.assertEqual(written, 200_000)
        self.assertEqual(target.stat().st_size, 200_000)

    async def test_a_body_past_the_ceiling_stops_while_reading(self) -> None:
        from veaf_support_bot.attachments import TooLarge, http_download

        target = Path(self.directory.name) / "big.log"
        with self.assertRaises(TooLarge):
            await http_download(self.url, target, 1024)


if __name__ == "__main__":
    unittest.main()
