"""Attachments: every ceiling, every refusal, and the promise that none of them stops a report.

The rejection paths matter more than the happy one here. A report that dies because somebody
attached a 30 MB log is a report that never reaches a maintainer, and the reporter has no way of
knowing why — so each case below asserts both halves: the file is refused, **and** the pass carries
on.
"""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from collections.abc import Coroutine
from pathlib import Path
from typing import Any

from tests.intake_fixtures import fixture_checkout, fixture_root
from tests.test_toolkit import SYNTHETIC_LOG
from veaf_support_bot.attachments import (
    AttachmentCollector,
    Downloader,
    Incoming,
    TooLarge,
    classify,
    describe_size,
    safe_name,
)


def _fake_downloader(bodies: dict[str, bytes]) -> Downloader:
    """Build a downloader serving fixed bodies, enforcing the ceiling the way the real one does.

    Args:
        bodies: URL to content.

    Returns:
        A downloader.
    """

    async def download(url: str, target: Path, ceiling: int) -> int:
        body = bodies[url]
        if len(body) > ceiling:
            raise TooLarge(f"{len(body)} > {ceiling}")
        target.write_bytes(body)
        return len(body)

    return download


def _failing_downloader(url: str, target: Path, ceiling: int) -> Coroutine[Any, Any, int]:
    """A downloader that always fails, standing for an expired or unreachable URL.

    Args:
        url: Ignored.
        target: Ignored.
        ceiling: Ignored.

    Returns:
        A coroutine that raises.
    """

    async def _run() -> int:
        raise ConnectionError("the signed URL has expired")

    return _run()


class TestNamingAndClassifying(unittest.TestCase):
    def test_a_traversal_in_a_filename_becomes_a_plain_name(self) -> None:
        for raw in (r"..\..\..\Windows\evil.log", "../../etc/evil.log", "/etc/evil.log"):
            with self.subTest(raw=raw):
                self.assertEqual(safe_name(raw), "evil.log")

    def test_an_unusable_name_still_names_something(self) -> None:
        self.assertEqual(safe_name("   ...  "), "attachment")

    def test_the_allow_list_decides_the_kind(self) -> None:
        self.assertEqual(classify("dcs.log"), "log")
        self.assertEqual(classify("mission.miz"), "mission")
        self.assertEqual(classify("evil.exe"), "")
        self.assertEqual(classify("no-suffix"), "")

    def test_sizes_are_described_the_way_the_refusal_says_them(self) -> None:
        self.assertEqual(describe_size(500), "500 B")
        self.assertIn("MB", describe_size(11 * 1024 * 1024))


class TestTheCollector(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()
        self.directory = tempfile.TemporaryDirectory()
        self.workdir = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)

    def _collector(self, bodies: dict[str, bytes], **limits: int) -> AttachmentCollector:
        return AttachmentCollector(self.checkout, _fake_downloader(bodies), **limits)

    async def test_a_log_is_downloaded_reduced_and_redacted(self) -> None:
        bodies = {"u": (SYNTHETIC_LOG + "\n").encode("utf-8")}
        harvest = await self._collector(bodies).collect([Incoming("dcs.log", "u", len(bodies["u"]))], self.workdir)
        self.assertEqual(harvest.rejected, ())
        prepared = harvest.prepared[0]
        self.assertEqual(prepared.kind, "log")
        self.assertTrue(prepared.path.is_file(), "the file must survive for the issue to carry it")
        self.assertIn("records kept", prepared.rendered)
        self.assertNotIn("Firstname Lastname", prepared.rendered)

    async def test_a_file_larger_than_the_ceiling_is_refused_by_its_declared_size(self) -> None:
        harvest = await self._collector({"u": b"x"}, max_file_bytes=10).collect(
            [Incoming("big.log", "u", size=99999)], self.workdir
        )
        self.assertEqual(harvest.prepared, ())
        self.assertIn("too large", harvest.rejected[0].reason)

    async def test_a_lying_content_length_is_caught_while_reading(self) -> None:
        """Discord's declared size is a claim; the bytes that arrive are the fact."""
        harvest = await self._collector({"u": b"x" * 100}, max_file_bytes=10).collect(
            [Incoming("big.log", "u", size=1)], self.workdir
        )
        self.assertEqual(harvest.prepared, ())
        self.assertIn("larger than", harvest.rejected[0].reason)

    async def test_an_unsupported_type_is_refused_by_name(self) -> None:
        harvest = await self._collector({}).collect([Incoming("payload.exe", "u", 10)], self.workdir)
        self.assertEqual(harvest.prepared, ())
        self.assertIn("unsupported", harvest.rejected[0].reason)

    async def test_an_unreachable_url_is_refused_and_the_pass_continues(self) -> None:
        collector = AttachmentCollector(self.checkout, _failing_downloader)
        harvest = await collector.collect([Incoming("dcs.log", "u", 10)], self.workdir)
        self.assertEqual(harvest.prepared, ())
        self.assertIn("could not be downloaded", harvest.rejected[0].reason)

    async def test_one_bad_file_does_not_stop_the_others(self) -> None:
        bodies = {"good": b"hello there", "bad": b"x"}
        harvest = await self._collector(bodies).collect(
            [Incoming("payload.exe", "bad", 1), Incoming("notes.txt", "good", 11)],
            self.workdir,
        )
        self.assertEqual(len(harvest.prepared), 1)
        self.assertEqual(len(harvest.rejected), 1)

    async def test_the_whole_report_has_a_ceiling_of_its_own(self) -> None:
        bodies = {"a": b"x" * 60, "b": b"y" * 60}
        harvest = await self._collector(bodies, max_file_bytes=100, max_total_bytes=100).collect(
            [Incoming("one.txt", "a", 60), Incoming("two.txt", "b", 60)], self.workdir
        )
        self.assertEqual(len(harvest.prepared), 1)
        self.assertEqual(len(harvest.rejected), 1)

    async def test_two_attachments_of_the_same_name_both_survive(self) -> None:
        bodies = {"a": b"first", "b": b"second"}
        harvest = await self._collector(bodies).collect(
            [Incoming("notes.txt", "a", 5), Incoming("notes.txt", "b", 6)], self.workdir
        )
        self.assertEqual(len(harvest.prepared), 2)
        self.assertNotEqual(harvest.prepared[0].path, harvest.prepared[1].path)

    async def test_a_corrupt_archive_is_attached_with_its_reason(self) -> None:
        harvest = await self._collector({"u": b"not a zip"}).collect([Incoming("~mis0001.zip", "u", 9)], self.workdir)
        self.assertEqual(len(harvest.prepared), 1, "the evidence still travels")
        self.assertIn("unreadable", harvest.rejected[0].reason)

    async def test_an_archive_is_listed_and_never_extracted(self) -> None:
        buffer = self.workdir / "source.zip"
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("mission/mission", "secret mission content")
            archive.writestr("mission/options", "x")
        harvest = await self._collector({"u": buffer.read_bytes()}).collect(
            [Incoming("~mis0001.zip", "u", 100)], self.workdir
        )
        rendered = harvest.prepared[0].rendered
        self.assertIn("mission/mission", rendered)
        self.assertNotIn("secret mission content", rendered)

    async def test_a_real_shaped_mission_is_attached_even_when_it_cannot_be_summarised(self) -> None:
        """The mission parser needs packages the service does not install; the file still travels."""
        source = self.workdir / "source.miz"
        with zipfile.ZipFile(source, "w") as archive:
            archive.writestr("mission", 'mission = { ["theatre"] = "Caucasus", ["version"] = 22 }')
            archive.writestr("options", "options = {}")
        harvest = await self._collector({"u": source.read_bytes()}).collect(
            [Incoming("test.miz", "u", 200)], self.workdir
        )
        self.assertEqual(len(harvest.prepared), 1)
        self.assertEqual(harvest.prepared[0].kind, "mission")
        self.assertTrue(harvest.prepared[0].path.is_file())

    async def test_a_text_file_too_long_to_quote_is_attached_rather_than_quoted(self) -> None:
        body = ("a" * 100 + "\n") * 200
        harvest = await self._collector({"u": body.encode()}).collect(
            [Incoming("mission.yaml", "u", len(body))], self.workdir
        )
        self.assertEqual(harvest.prepared[0].rendered, "")
        self.assertTrue(harvest.prepared[0].withheld)

    async def test_a_short_text_file_is_quoted_redacted(self) -> None:
        body = r"path: C:\Users\Firstname Lastname\dev"
        harvest = await self._collector({"u": body.encode()}).collect(
            [Incoming("mission.yaml", "u", len(body))], self.workdir
        )
        self.assertNotIn("Firstname Lastname", harvest.prepared[0].rendered)

    async def test_nothing_attached_is_not_an_error(self) -> None:
        harvest = await self._collector({}).collect([], self.workdir)
        self.assertEqual((harvest.prepared, harvest.rejected), ((), ()))


class TestTheFixtureIsWhereTheTestThinks(unittest.TestCase):
    def test_the_miniature_repository_carries_the_real_tools(self) -> None:
        """Guards the guard: without this, every assertion above could be vacuously green."""
        self.assertTrue((fixture_root() / "src/python/veaf-tools/veaf_libs/redaction.py").is_file())
        self.assertTrue((fixture_root() / "src/python/veaf-tools/veaf_logs/rules.json").is_file())


if __name__ == "__main__":
    unittest.main()
