"""One report, one issue — across a double click, a retry and a restart.

The three are genuinely different failures and they are asserted separately. The restart case is the
one that matters most: it is the only one where every local trace of the attempt is gone, and the
only thing left is the marker inside the issue GitHub already holds.
"""

from __future__ import annotations

import asyncio
import json
import tempfile
import unittest
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from tests.intake_fixtures import fixture_checkout
from tests.test_github_app import credentials
from veaf_support_bot.attachments import Prepared
from veaf_support_bot.bugreport import BugForm, BugReport, assemble
from veaf_support_bot.filing import (
    MACHINE_LABEL,
    IssueFiler,
    Ledger,
    RepositoryIssues,
    report_key,
)
from veaf_support_bot.github_app import GitHubApp, Response
from veaf_support_bot.issue_body import marker_for


class _GitHub:
    """A GitHub that creates issues, remembers them, and can be told to fail.

    Deliberately stateful: idempotency is a property of *two* calls, and a transport that answers a
    fixed script cannot show that the second call did not create anything.
    """

    def __init__(self) -> None:
        self.issues: list[dict[str, Any]] = []
        self.comments: list[tuple[int, str]] = []
        self.creations = 0
        self.fail_create: Exception | None = None
        self.refuse_labels = False
        self.fail_comment = False

    async def __call__(
        self,
        method: str,
        url: str,
        headers: Mapping[str, str],
        body: bytes | None,
    ) -> Response:
        payload = json.loads(body) if body else {}
        if url.endswith("/access_tokens"):
            return Response(201, {"token": "ghs-t", "expires_at": "2999-01-01T00:00:00Z"})
        if method == "POST" and url.endswith("/comments"):
            if self.fail_comment:
                return Response(403, {"message": "no"})
            number = int(url.rsplit("/issues/", 1)[1].split("/")[0])
            self.comments.append((number, str(payload.get("body") or "")))
            return Response(201, {"html_url": f"https://example.invalid/issues/{number}#c"})
        if method == "POST" and url.endswith("/issues"):
            if self.fail_create is not None:
                raise self.fail_create
            if self.refuse_labels and payload.get("labels"):
                return Response(422, {"message": "Validation Failed", "errors": [{"message": "label not found"}]})
            self.creations += 1
            item = {
                "number": 900 + self.creations,
                "title": payload.get("title"),
                "body": payload.get("body"),
                "html_url": f"https://example.invalid/issues/{900 + self.creations}",
                "labels": [{"name": name} for name in payload.get("labels") or []],
                "state": "open",
            }
            self.issues.append(item)
            return Response(201, item)
        if method == "GET":
            return Response(200, list(reversed(self.issues)))
        return Response(200, {})


def _report(**overrides: str) -> BugReport:
    """Assemble a report.

    Args:
        **overrides: Form fields to replace.

    Returns:
        The report.
    """
    fields = {
        "summary": "La mission plante",
        "happened": "KeyError: 'coalition'",
        "expected": "Elle devrait s'ouvrir",
        "steps": "1. ouvrir",
        "reporter": "Tripack",
        "reporter_id": "4242",
        "language": "fr",
    }
    fields.update(overrides)
    return assemble(BugForm(**fields), fixture_checkout())


class _Filing(unittest.IsolatedAsyncioTestCase):
    """Shared setup: a fake GitHub, a real ledger on disk."""

    def setUp(self) -> None:
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.ledger_path = Path(self.folder.name) / "state" / "filed.json"
        self.github = _GitHub()

    def _filer(self) -> IssueFiler:
        """Build a filer over the shared fake.

        Returns:
            The filer.
        """
        app = GitHubApp(credentials(), "VEAF/VEAF-Mission-Creation-Tools", self.github)
        return IssueFiler(app, Ledger(self.ledger_path))


class TestTheKey(unittest.TestCase):
    """Stable for the same report, different for a different one."""

    def test_the_same_report_yields_the_same_key(self) -> None:
        self.assertEqual(report_key(_report()), report_key(_report()))

    def test_a_different_report_by_the_same_person_yields_a_different_key(self) -> None:
        self.assertNotEqual(report_key(_report()), report_key(_report(happened="something else entirely")))

    def test_a_different_reporter_yields_a_different_key(self) -> None:
        self.assertNotEqual(report_key(_report()), report_key(_report(reporter_id="9999")))

    def test_the_attachments_are_part_of_the_identity(self) -> None:
        base = _report()
        from dataclasses import replace

        with_file = replace(
            base,
            attachments=(Prepared(filename="a.log", kind="log", path=Path("a.log"), size=12),),
        )
        self.assertNotEqual(report_key(base), report_key(with_file))


class TestFilingOnce(_Filing):
    """The three ways of asking twice."""

    async def test_a_report_becomes_one_issue_with_both_labels(self) -> None:
        outcome = await self._filer().file(_report())
        self.assertEqual(outcome.action, "created")
        self.assertEqual(self.github.creations, 1)
        names = [label["name"] for label in self.github.issues[0]["labels"]]
        self.assertIn("bug", names)
        self.assertIn(MACHINE_LABEL, names)

    async def test_a_double_click_files_once(self) -> None:
        filer = self._filer()
        report = _report()
        first, second = await asyncio.gather(filer.file(report), filer.file(report))
        self.assertEqual(self.github.creations, 1)
        self.assertEqual({first.number, second.number}, {901})
        self.assertEqual({first.action, second.action}, {"created", "reused"})

    async def test_a_retry_after_a_timeout_reuses_the_ledger(self) -> None:
        filer = self._filer()
        report = _report()
        await filer.file(report)
        again = await filer.file(report)
        self.assertEqual(self.github.creations, 1)
        self.assertEqual(again.action, "reused")

    async def test_a_fresh_process_still_reuses_the_ledger(self) -> None:
        report = _report()
        await self._filer().file(report)
        again = await self._filer().file(report)
        self.assertEqual(self.github.creations, 1)
        self.assertEqual(again.action, "reused")

    async def test_a_restart_between_the_post_and_the_ledger_finds_the_issue_by_its_marker(self) -> None:
        report = _report()
        key = report_key(report)
        # Exactly the state a crash leaves: GitHub holds the issue, the ledger holds an attempt.
        self.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        await self._filer().file(report)
        Ledger(self.ledger_path).record(key, {"state": "filing", "started": 0.0})

        outcome = await self._filer().file(report)
        self.assertEqual(self.github.creations, 1, "the marker is what stops the second issue")
        self.assertEqual(outcome.action, "reused")
        self.assertEqual(outcome.number, 901)
        self.assertIn(marker_for(key), self.github.issues[0]["body"])

    async def test_an_interrupted_attempt_whose_issue_does_not_exist_files_it(self) -> None:
        report = _report()
        Ledger(self.ledger_path).record(report_key(report), {"state": "filing", "started": 0.0})
        outcome = await self._filer().file(report)
        self.assertEqual(outcome.action, "created")
        self.assertEqual(self.github.creations, 1)

    async def test_an_unwritable_ledger_does_not_stop_a_report_being_filed(self) -> None:
        app = GitHubApp(credentials(), "o/n", self.github)
        blocked = Path(self.folder.name) / "state.json" / "nested" / "ledger.json"
        Path(self.folder.name, "state.json").write_text("not a directory", encoding="utf-8")
        outcome = await IssueFiler(app, Ledger(blocked)).file(_report())
        self.assertEqual(outcome.action, "created")

    async def test_a_corrupt_ledger_is_ignored_rather_than_losing_the_report(self) -> None:
        self.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        self.ledger_path.write_text("{not json", encoding="utf-8")
        self.assertEqual((await self._filer().file(_report())).action, "created")


class TestWhenItCannotFile(_Filing):
    """A failure is an answer the reporter gets, never a silence."""

    async def test_a_creation_failure_is_returned_rather_than_raised(self) -> None:
        self.github.fail_create = OSError("no route to host")
        outcome = await self._filer().file(_report())
        self.assertEqual(outcome.action, "failed")
        self.assertFalse(outcome.filed)
        self.assertIn("could not be reached", outcome.error)

    async def test_a_refused_label_files_the_issue_anyway_and_says_so(self) -> None:
        self.github.refuse_labels = True
        outcome = await self._filer().file(_report())
        self.assertEqual(outcome.action, "created")
        self.assertTrue(any("could not be applied" in note for note in outcome.notes))

    async def test_a_failed_attachment_comment_does_not_undo_a_filed_issue(self) -> None:
        self.github.fail_comment = True
        folder = Path(self.folder.name)
        (folder / "veaf-tools.log").write_text("a line", encoding="utf-8")
        from dataclasses import replace

        report = replace(
            _report(),
            attachments=(
                Prepared(filename="veaf-tools.log", kind="log", path=folder / "veaf-tools.log", size=6),
            ),
        )
        outcome = await self._filer().file(report)
        self.assertEqual(outcome.action, "created")
        self.assertTrue(any("could not be added" in note for note in outcome.notes))

    async def test_a_failed_comment_on_an_existing_issue_is_reported(self) -> None:
        self.github.fail_comment = True
        outcome = await self._filer().comment_on(712, _report())
        self.assertEqual(outcome.action, "failed")


class TestCommentingInstead(_Filing):
    """The duplicate outcome: nothing new is opened."""

    async def test_the_observation_lands_on_the_existing_issue(self) -> None:
        outcome = await self._filer().comment_on(712, _report(), thread_url="https://discord.com/x")
        self.assertEqual(outcome.action, "commented")
        self.assertEqual(self.github.creations, 0)
        number, body = self.github.comments[0]
        self.assertEqual(number, 712)
        self.assertIn("KeyError: 'coalition'", body)


class TestCarryingTheFiles(_Filing):
    """What was attached travels into the issue, never as a link."""

    async def test_a_text_attachment_becomes_a_comment_on_the_new_issue(self) -> None:
        folder = Path(self.folder.name)
        (folder / "veaf-tools.log").write_text("the interesting line", encoding="utf-8")
        from dataclasses import replace

        report = replace(
            _report(),
            attachments=(
                Prepared(filename="veaf-tools.log", kind="log", path=folder / "veaf-tools.log", size=20),
            ),
        )
        await self._filer().file(report)
        self.assertTrue(any("the interesting line" in body for _, body in self.github.comments))


class TestTheIssueCorpus(_Filing):
    """What the prior-art sweep reads through the App."""

    async def test_pull_requests_are_not_offered_as_duplicates(self) -> None:
        self.github.issues = [
            {"number": 1, "title": "a real issue", "body": "b", "html_url": "u", "state": "open"},
            {"number": 2, "title": "a pull request", "body": "b", "html_url": "u", "pull_request": {"url": "x"}},
        ]
        app = GitHubApp(credentials(), "o/n", self.github)
        records = await RepositoryIssues(app).open_issues()
        self.assertEqual([record.number for record in records], [1])

    async def test_the_closed_half_is_bounded(self) -> None:
        self.github.issues = [
            {"number": index, "title": f"issue {index}", "body": "", "html_url": "u", "state": "closed"}
            for index in range(1, 30)
        ]
        app = GitHubApp(credentials(), "o/n", self.github)
        records = await RepositoryIssues(app, closed_count=5).recently_closed_issues()
        self.assertEqual(len(records), 5)

    async def test_labels_survive_the_round_trip(self) -> None:
        self.github.issues = [
            {"number": 1, "title": "t", "body": "", "html_url": "u", "state": "open", "labels": [{"name": "bug"}]}
        ]
        app = GitHubApp(credentials(), "o/n", self.github)
        records = await RepositoryIssues(app).open_issues()
        self.assertEqual(records[0].labels, ("bug",))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
