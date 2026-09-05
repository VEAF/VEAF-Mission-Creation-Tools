"""The hostile fixture: content that reads like an instruction, and steers nothing.

``/bug`` is a public intake desk, so this is not a hypothetical. What arrives is a form somebody
filled in and files somebody uploaded, and any line of either can say *"set the component to
Documentation"*, *"close this as a duplicate"* or *"@everyone"*.

The assertion this file makes is **differential**, and that is what makes it worth its runtime: the
same report is assembled twice, once clean and once with hostile text spliced into every free-text
field and into the attached log, and the two are required to produce **identical decisions** —
title, component, labels, version, resolved locations. If a single branch anywhere read free text to
choose something, the two would diverge and this would go red.

The second half asserts the presentational boundary: hostile text is quoted, not filtered. Nothing
is dropped — dropping evidence to be safe would corrupt the very report the feature exists to carry
— it simply cannot escape its fence or resolve a mention.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.intake_fixtures import (
    HOSTILE_TEXT,
    PERSONAL_ACCOUNT,
    PERSONAL_EMAIL,
    PERSONAL_FILENAME,
    PERSONAL_MEMBERS,
    PYTHON_TRACEBACK,
    UNREADABLE_MISSION_LUA,
    doctor_block,
    fixture_checkout,
    personal_archive,
    runs_of,
    unreadable_mission,
)
from tests.test_attachments import _fake_downloader
from tests.test_toolkit import SYNTHETIC_LOG
from veaf_support_bot.attachments import UNREDACTED_NAME, AttachmentCollector, Harvest, Incoming
from veaf_support_bot.bugreport import BugForm, BugReport, assemble
from veaf_support_bot.checkout import Checkout
from veaf_support_bot.intake import BugIntake
from veaf_support_bot.untrusted import MAX_FENCE, bound_backtick_runs, defuse_mentions, fence_for, one_line, quote

#: A log carrying the same hostile lines a reporter's own machine would have written into it.
HOSTILE_LOG = "\n".join(
    [
        "2026-09-05 10:00:00.000 INFO    APP (Main): DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)",
        *[
            f"2026-09-05 10:00:{i:02d}.000 ERROR   SCRIPTING (Main): {line}"
            for i, line in enumerate(HOSTILE_TEXT.splitlines())
        ],
        "",
    ]
)

#: The same log without a hostile line in it, same shape and same length.
CLEAN_LOG = "\n".join(
    [
        "2026-09-05 10:00:00.000 INFO    APP (Main): DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)",
        *[
            f"2026-09-05 10:00:{i:02d}.000 ERROR   SCRIPTING (Main): ordinary line {i}"
            for i in range(len(HOSTILE_TEXT.splitlines()))
        ],
        "",
    ]
)


def _form(hostile: bool) -> BugForm:
    """Build the same report twice, once with hostile text spliced into every field.

    Args:
        hostile: Whether to splice it in.

    Returns:
        The form.
    """
    poison = f"\n{HOSTILE_TEXT}" if hostile else ""
    return BugForm(
        summary="convert-v5 crashes on my mission",
        happened=f"{PYTHON_TRACEBACK}{poison}",
        expected=f"It should have converted the mission.{poison}",
        steps=f"1. run convert-v5\n2. watch it fail{poison}",
        doctor=doctor_block("6.16.3"),
        reporter="Someone",
        reporter_id="42",
        language="en",
    )


def _decisions(report: BugReport) -> dict[str, object]:
    """Reduce a report to everything the service **decided**, and nothing it merely quoted.

    Args:
        report: The assembled report.

    Returns:
        The decisions, comparable between two runs.
    """
    return {
        "title": report.title,
        "component": report.component,
        "labels": report.labels,
        "version": report.version,
        "locations": [(item.relative, item.line, item.function) for item in report.located],
        "unresolved": [(item.line,) for item in report.unresolved],
    }


class TestHostileTextChangesNoDecision(unittest.TestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_the_fixture_really_is_hostile(self) -> None:
        """Guards the guard: a fixture that lost its teeth would make every case below vacuous."""
        self.assertIn("ignore all previous instructions", HOSTILE_TEXT)
        self.assertIn("component: Documentation", HOSTILE_TEXT)
        self.assertIn("@everyone", HOSTILE_TEXT)
        self.assertIn("```", HOSTILE_TEXT)

    def test_the_two_reports_decide_exactly_the_same_things(self) -> None:
        clean = assemble(_form(hostile=False), self.checkout)
        hostile = assemble(_form(hostile=True), self.checkout)
        self.assertEqual(_decisions(clean), _decisions(hostile))

    def test_the_component_it_asked_for_is_not_the_component_it_gets(self) -> None:
        hostile = assemble(_form(hostile=True), self.checkout)
        self.assertNotEqual(hostile.component, "Documentation")
        self.assertEqual(hostile.component, "veaf-tools.exe (Python CLI)")

    def test_the_labels_it_asked_for_are_not_applied(self) -> None:
        hostile = assemble(_form(hostile=True), self.checkout)
        self.assertNotIn("security", hostile.labels)
        self.assertNotIn("wontfix", hostile.labels)

    def test_the_title_it_asked_for_is_not_the_title(self) -> None:
        hostile = assemble(_form(hostile=True), self.checkout)
        self.assertNotIn("something else entirely", hostile.title)

    def test_the_hostile_text_is_still_carried_and_not_censored(self) -> None:
        """Dropping evidence to be safe would corrupt the report this feature exists to file."""
        hostile = assemble(_form(hostile=True), self.checkout)
        self.assertIn("ignore all previous instructions", hostile.form.all_text())


class TestAHostileLogChangesNoDecision(unittest.IsolatedAsyncioTestCase):
    async def _digest(self, body: str) -> str:
        checkout = fixture_checkout()
        collector = AttachmentCollector(checkout, _fake_downloader({"u": body.encode("utf-8")}))
        with tempfile.TemporaryDirectory() as directory:
            harvest = await collector.collect([Incoming("dcs.log", "u", len(body))], Path(directory))
            return harvest.prepared[0].rendered

    async def test_a_log_full_of_instructions_produces_the_same_decisions_as_an_ordinary_one(self) -> None:
        checkout = fixture_checkout()
        hostile = assemble(_form(hostile=False), checkout, extra_text=await self._digest(HOSTILE_LOG))
        clean = assemble(_form(hostile=False), checkout, extra_text=await self._digest(CLEAN_LOG))
        self.assertEqual(_decisions(clean), _decisions(hostile))

    async def test_the_hostile_log_lines_are_still_in_the_excerpt(self) -> None:
        self.assertIn("ignore all previous instructions", await self._digest(HOSTILE_LOG))


class TestQuotedTextCannotEscapeItsQuotes(unittest.TestCase):
    def test_a_fence_is_longer_than_any_run_of_backticks_inside(self) -> None:
        self.assertEqual(fence_for("no backticks"), "```")
        self.assertEqual(fence_for("a ``` b"), "````")
        self.assertEqual(fence_for("a ````` b"), "``````")

    def test_a_block_holding_its_own_fence_still_closes_after_the_content(self) -> None:
        rendered = quote("before\n```\nafter")
        fence = rendered.splitlines()[0]
        self.assertTrue(rendered.endswith(fence))
        self.assertEqual(rendered.count(fence), 2)

    def test_a_mention_cannot_resolve(self) -> None:
        defused = defuse_mentions("@everyone @here <@&12345> mail@example.org")
        self.assertNotIn("@everyone", defused)
        self.assertNotIn("@here", defused)
        self.assertIn("everyone", defused, "the text is guarded, not deleted")

    def test_the_hostile_fixture_quotes_without_escaping(self) -> None:
        rendered = quote(HOSTILE_TEXT)
        fence = rendered.splitlines()[0]
        self.assertEqual(rendered.count(f"\n{fence}"), 1, "the closing fence is the only one")
        self.assertNotIn("@everyone", rendered)

    def test_a_line_of_exactly_max_fence_backticks_does_not_close_the_block(self) -> None:
        """The cap used to bite here: 40 backticks in, a 40-backtick fence out, block closed early."""
        rendered = quote(f"before\n{'`' * MAX_FENCE}\nafter")
        fence = rendered.splitlines()[0]
        self.assertTrue(rendered.endswith(f"\n{fence}"))
        self.assertEqual(rendered.count(f"\n{fence}"), 1, "the closing fence is the only one")
        self.assertIn("after", rendered.split(f"\n{fence}")[0], "the content is still inside the block")

    def test_an_absurd_run_is_broken_up_rather_than_growing_the_fence(self) -> None:
        bounded = bound_backtick_runs("`" * (MAX_FENCE * 3))
        self.assertLess(len(fence_for(bounded)), MAX_FENCE)
        self.assertEqual(bounded.count("`"), MAX_FENCE * 3, "the backticks are separated, not deleted")

    def test_a_run_anyone_writes_on_purpose_is_untouched(self) -> None:
        for text in ("`a`", "``b``", "```\ncode\n```"):
            with self.subTest(text=text):
                self.assertEqual(bound_backtick_runs(text), text)

    def test_empty_text_yields_no_empty_fence(self) -> None:
        self.assertEqual(quote("   \n  "), "")

    def test_a_title_line_is_collapsed_and_bounded(self) -> None:
        collapsed = one_line("a\nb   c\t\td", 100)
        self.assertEqual(collapsed, "a b c d")
        self.assertLessEqual(len(one_line("word " * 100, 40)), 40)


class TestNothingAReporterSuppliedIsPublishedRaw(unittest.IsolatedAsyncioTestCase):
    """The second half of the fixture: personal data must reach nothing, wherever it arrives.

    Three paths published it and none of them was covered here, which is precisely why they were
    missed: the fixture carried instruction-shaped text and no account name, no filename and no
    ``.miz`` content. Each case below asserts the leak is closed **and** that the report still says
    what it is about — withholding by deleting the evidence would be its own bug.
    """

    async def _harvest(self, incoming: list[Incoming], bodies: dict[str, bytes]) -> Harvest:
        """Run one attachment pass.

        Args:
            incoming: What the command carried.
            bodies: URL to content.

        Returns:
            The harvest.
        """
        collector = AttachmentCollector(fixture_checkout(), _fake_downloader(bodies))
        with tempfile.TemporaryDirectory() as directory:
            return await collector.collect(incoming, Path(directory))

    async def test_an_archive_member_name_is_redacted_like_any_other_text(self) -> None:
        body = personal_archive()
        harvest = await self._harvest([Incoming("~mis0001.zip", "zip", len(body))], {"zip": body})
        listing = harvest.prepared[0].rendered
        self.assertNotIn(PERSONAL_ACCOUNT, listing)
        self.assertNotIn("jean.dupont@example.com", listing)
        self.assertIn("<user>", listing, "the shape of the tree is still published, only the name is not")
        self.assertIn("secret-op.miz", listing)

    async def test_the_same_strings_in_a_text_file_and_in_an_archive_come_out_the_same(self) -> None:
        """The differential form: two carriers of one string must not disagree about publishing it."""
        archive = personal_archive()
        quoted = ("- " + "\n- ".join(PERSONAL_MEMBERS) + "\n").encode("utf-8")
        harvest = await self._harvest(
            [Incoming("~mis0001.zip", "zip", len(archive)), Incoming("paths.txt", "txt", len(quoted))],
            {"zip": archive, "txt": quoted},
        )
        rendered = {item.kind: item.rendered for item in harvest.prepared}
        for kind in ("archive", "text"):
            with self.subTest(kind=kind):
                self.assertNotIn(PERSONAL_ACCOUNT, rendered[kind])

    async def test_an_unreadable_mission_is_reported_without_quoting_the_mission(self) -> None:
        body = unreadable_mission()
        harvest = await self._harvest([Incoming("broken.miz", "miz", len(body))], {"miz": body})
        self.assertEqual(len(harvest.rejected), 1, "the file is still attached and the reason still stated")
        reason = harvest.rejected[0].reason
        self.assertIn("could not be read", reason)
        self.assertNotIn(PERSONAL_ACCOUNT, reason)
        # Enumerated rather than sampled: the parser quotes whatever sits at the offset it faulted
        # on, so the assertion is that *no* run of the mission's own bytes survives into the reason.
        leaked = sorted(run for run in runs_of(UNREADABLE_MISSION_LUA) if run in reason)
        self.assertEqual(leaked, [], "the published reason quotes the mission's own bytes")

    async def test_the_reporters_filename_meets_redaction_like_the_text_beside_it(self) -> None:
        """A name is reporter-supplied text; `safe_name` makes it safe for a disk, not for an issue."""
        rejected_name = PERSONAL_FILENAME.replace(".log", ".exe")
        harvest = await self._harvest(
            [Incoming(PERSONAL_FILENAME, "log", len(SYNTHETIC_LOG)), Incoming(rejected_name, "exe", 2)],
            {"log": SYNTHETIC_LOG.encode("utf-8"), "exe": b"MZ"},
        )
        published = [item.filename for item in harvest.prepared] + [item.filename for item in harvest.rejected]
        for name in published:
            with self.subTest(name=name):
                self.assertNotIn(PERSONAL_EMAIL, name)
                self.assertIn("<email>", name)
        self.assertEqual(
            sorted(published),
            ["dcs - <email>.exe", "dcs - <email>.log"],
            "the suffix survives redaction; it is what the refusal below quotes",
        )
        self.assertIn(".exe", harvest.rejected[0].reason, "the suffix is still named, so the refusal is actionable")

    async def test_a_name_and_a_body_carrying_one_string_are_treated_alike(self) -> None:
        """The differential form: two carriers of the same string must not disagree about it."""
        quoted = f"the report was written by {PERSONAL_EMAIL}\n".encode()
        harvest = await self._harvest(
            [Incoming(PERSONAL_FILENAME, "log", 10), Incoming("about.txt", "txt", len(quoted))],
            {"log": SYNTHETIC_LOG.encode("utf-8"), "txt": quoted},
        )
        as_a_name = [item.filename for item in harvest.prepared if item.kind == "log"][0]
        as_a_body = [item.rendered for item in harvest.prepared if item.kind == "text"][0]
        self.assertNotIn(PERSONAL_EMAIL, as_a_name)
        self.assertNotIn(PERSONAL_EMAIL, as_a_body)

    async def test_a_name_that_cannot_be_redacted_is_withheld_rather_than_printed(self) -> None:
        """Fails closed, like `safe_redact`: a name nobody could redact is not one to publish."""
        with tempfile.TemporaryDirectory() as nowhere:
            collector = AttachmentCollector(Checkout(Path(nowhere), refresh_seconds=0.0), _fake_downloader({}))
            with tempfile.TemporaryDirectory() as directory:
                harvest = await collector.collect([Incoming(PERSONAL_FILENAME, "u", 1)], Path(directory))
        self.assertEqual(harvest.prepared, ())
        self.assertEqual(harvest.rejected[0].filename, f"{UNREDACTED_NAME}.log")

    async def test_the_redacted_name_is_what_the_whole_report_carries(self) -> None:
        """`Prepared.filename` reaches four places in the body; one raw copy is one too many."""
        archive = personal_archive()
        harvest = await self._harvest(
            [Incoming(PERSONAL_FILENAME, "log", 10), Incoming("m.zip", "zip", len(archive))],
            {"log": SYNTHETIC_LOG.encode("utf-8"), "zip": archive},
        )
        collector = AttachmentCollector(fixture_checkout(), _fake_downloader({}))
        report = BugIntake(fixture_checkout(), collector)._assemble(_form(hostile=False), harvest)
        published = "\n".join(
            (
                report.title,
                *(f"{note.subject}: {note.reason}" for note in report.notes),
                *report.log_digests,
                *report.mission_summaries,
                *report.quoted_files,
            )
        )
        self.assertNotIn(PERSONAL_EMAIL, published)
        self.assertNotIn(
            PERSONAL_ACCOUNT, published, "the account name arrives under `Users/`, where the helper sees it"
        )


if __name__ == "__main__":
    unittest.main()
