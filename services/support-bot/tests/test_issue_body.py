"""The issue: the template's shape, the reporter's language, and evidence nobody rewrote.

The headings are read out of ``.github/ISSUE_TEMPLATE/bug_report.yml`` rather than typed here, so
renaming a field in the form fails this file instead of leaving the bot writing headings a
maintainer no longer recognises.
"""

from __future__ import annotations

import tempfile
import unittest
from functools import partial
from pathlib import Path

from tests.intake_fixtures import fixture_checkout, fixture_root
from veaf_support_bot.attachments import Prepared
from veaf_support_bot.bugreport import BugForm, BugReport, MaterialNote, assemble
from veaf_support_bot.issue_body import (
    INLINE_MAX_CHARS,
    Carried,
    carry,
    heading,
    marker_for,
    render_attachment_comments,
    render_body,
    render_duplicate_comment,
    render_prior_art,
)
from veaf_support_bot.priorart import DUPLICATE, NONE, Candidate, Match, Sweep
from veaf_support_bot.toolkit import redact

#: A French log line with a home directory in it, quoted as evidence.
FRENCH_REPORT = "La mission plante à l'ouverture, erreur « KeyError: 'coalition' »"


def _repository_root() -> Path:
    """Return the real repository this service lives in.

    Returns:
        Its root.
    """
    return Path(__file__).resolve().parents[3]


def _report(language: str = "fr", **overrides: str) -> BugReport:
    """Assemble a report against the fixture checkout.

    Args:
        language: ``"fr"`` or ``"en"``.
        **overrides: Form fields to replace.

    Returns:
        The report.
    """
    fields = {
        "summary": "La mission plante",
        "happened": FRENCH_REPORT,
        "expected": "Elle devrait s'ouvrir",
        "steps": "1. lancer veaf-tools.exe\n2. ouvrir la mission",
        "reporter": "Tripack",
        "reporter_id": "4242",
        "language": language,
    }
    fields.update(overrides)
    return assemble(BugForm(**fields), fixture_checkout())


class TestTheTemplateShape(unittest.TestCase):
    """The headings are the repository's own form, not invented ones."""

    def test_every_english_heading_is_a_label_of_the_bug_report_form(self) -> None:
        template = (_repository_root() / ".github" / "ISSUE_TEMPLATE" / "bug_report.yml").read_text(encoding="utf-8")
        for key in ("version", "component", "happened", "expected", "steps", "context"):
            with self.subTest(field=key):
                self.assertIn(heading(key, "en"), template)

    def test_the_body_carries_the_six_template_sections(self) -> None:
        body = render_body(_report("en"), "abc")
        for key in ("version", "component", "happened", "expected", "steps", "context"):
            with self.subTest(field=key):
                self.assertIn(f"### {heading(key, 'en')}", body)

    def test_an_unknown_language_falls_back_to_english_rather_than_raising(self) -> None:
        self.assertIn(heading("version", "en"), render_body(_report("pt-BR"), "abc"))


class TestTheLanguage(unittest.TestCase):
    """Headings follow the reporter; quoted material follows nobody."""

    def test_a_french_report_gets_french_headings(self) -> None:
        body = render_body(_report("fr"), "abc")
        self.assertIn("### Ce qui s'est passé", body)
        self.assertNotIn("### What happened?", body)

    def test_the_quoted_words_are_the_reporters_own(self) -> None:
        body = render_body(_report("fr"), "abc")
        self.assertIn(FRENCH_REPORT, body)

    def test_a_french_report_keeps_its_english_evidence_untranslated(self) -> None:
        body = render_body(_report("fr", happened="the log says KeyError: 'coalition' at line 412"), "abc")
        self.assertIn("KeyError: 'coalition' at line 412", body)


class TestTheMarker(unittest.TestCase):
    """The one thing that survives losing every local trace of an attempt."""

    def test_the_body_carries_the_key_in_a_comment(self) -> None:
        body = render_body(_report(), "0123456789abcdef")
        self.assertIn(marker_for("0123456789abcdef"), body)

    def test_two_keys_produce_two_markers(self) -> None:
        self.assertNotEqual(marker_for("a"), marker_for("b"))


class TestAttribution(unittest.TestCase):
    """Who reported it, and where."""

    def test_the_discord_author_is_named(self) -> None:
        self.assertIn("Tripack", render_body(_report(), "abc"))

    def test_the_thread_is_linked_when_there_is_one(self) -> None:
        body = render_body(_report(), "abc", thread_url="https://discord.com/channels/1/2/3")
        self.assertIn("https://discord.com/channels/1/2/3", body)

    def test_no_thread_is_said_rather_than_invented(self) -> None:
        body = render_body(_report("en"), "abc")
        self.assertIn("(not recorded)", body)


class TestCarryingTheAttachments(unittest.TestCase):
    """What an issue can hold, and what it says about what it cannot."""

    def setUp(self) -> None:
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)

    def _prepared(self, name: str, kind: str, content: bytes) -> Prepared:
        path = self.root / name
        path.write_bytes(content)
        return Prepared(filename=name, kind=kind, path=path, size=len(content))

    def _carry(self, prepared: Prepared, **options: int) -> Carried:
        """Carry one attachment through the **real** redaction helper.

        Args:
            prepared: The attachment.
            **options: Passed through to :func:`carry`.

        Returns:
            The decision.
        """
        return carry(prepared, redactor=partial(redact, fixture_root()), **options)

    def test_a_small_text_file_travels_whole_inside_the_issue(self) -> None:
        carried = self._carry(self._prepared("veaf-tools.log", "log", b"line one\nline two\n"))
        self.assertIn("line two", carried.text)
        self.assertEqual(carried.reason, "")

    def test_a_binary_is_described_rather_than_carried(self) -> None:
        carried = self._carry(self._prepared("mission.miz", "mission", b"PK\x03\x04binary"))
        self.assertEqual(carried.text, "")
        self.assertIn("binary file", carried.reason)

    def test_a_text_file_past_the_ceiling_is_described_with_its_size(self) -> None:
        carried = self._carry(self._prepared("big.log", "log", b"x" * (INLINE_MAX_CHARS + 10)))
        self.assertEqual(carried.text, "")
        self.assertIn(str(INLINE_MAX_CHARS + 10), carried.reason)

    def test_an_unreadable_file_says_so_instead_of_producing_an_empty_quote(self) -> None:
        prepared = Prepared(filename="gone.log", kind="log", path=self.root / "gone.log", size=10)
        carried = self._carry(prepared)
        self.assertIn("could not be read back", carried.reason)

    def test_the_manifest_names_every_file_and_its_digest(self) -> None:
        carried = [self._carry(self._prepared("veaf-tools.log", "log", b"hello"))]
        body = render_body(_report("en"), "abc", carried=carried)
        self.assertIn("veaf-tools.log", body)
        self.assertIn("sha256:", body)

    def test_the_manifest_says_plainly_when_the_bytes_are_not_in_the_issue(self) -> None:
        carried = [self._carry(self._prepared("mission.miz", "mission", b"PK\x03\x04"))]
        body = render_body(_report("en"), "abc", carried=carried)
        self.assertIn("not published here", body)

    def test_a_carried_file_becomes_a_comment_and_a_described_one_does_not(self) -> None:
        carried = [
            self._carry(self._prepared("veaf-tools.log", "log", b"kept")),
            self._carry(self._prepared("mission.miz", "mission", b"PK\x03\x04")),
        ]
        comments = render_attachment_comments(carried)
        self.assertEqual(len(comments), 1)
        self.assertIn("kept", comments[0])

    def test_no_discord_url_ever_reaches_the_issue(self) -> None:
        carried = [self._carry(self._prepared("mission.miz", "mission", b"PK\x03\x04"))]
        body = render_body(_report(), "abc", carried=carried)
        self.assertNotIn("cdn.discordapp.com", body)
        self.assertNotIn("discordapp.net", body)


class TestThePriorArtSection(unittest.TestCase):
    """A reader must be able to see the sweep ran, and to disagree with what it proposed."""

    def _sweep(self) -> Sweep:
        match = Match(
            candidate=Candidate("open issue", "#712", "the resolver drops an alias", url="https://x/712"),
            score=0.62,
            shared=("veafsample.resolve", "alias"),
        )
        return Sweep(verdict=DUPLICATE, best=match, checked=("9 open issue(s)",))

    def test_a_rejected_match_is_recorded_with_its_evidence(self) -> None:
        rendered = render_prior_art(self._sweep(), "en")
        self.assertIn("#712", rendered)
        self.assertIn("veafsample.resolve", rendered)
        self.assertIn("rejected by the reporter", rendered)

    def test_what_was_checked_is_recorded_even_when_nothing_matched(self) -> None:
        rendered = render_prior_art(Sweep(verdict=NONE, checked=("9 open issue(s)",)), "en")
        self.assertIn("9 open issue(s)", rendered)

    def test_the_section_reaches_the_body(self) -> None:
        report = assemble(
            BugForm(summary="s", happened="h", expected="e", steps="p", language="en"),
            fixture_checkout(),
            prior_art=self._sweep(),
        )
        self.assertIn(f"### {heading('priorart', 'en')}", render_body(report, "abc"))


class TestTheThreeMaterialBuckets(unittest.TestCase):
    """A configuration file must not come out of the renderer under a *log excerpt* heading."""

    def test_a_quoted_file_gets_its_own_heading(self) -> None:
        report = assemble(
            BugForm(summary="s", happened="h", expected="e", steps="p", language="en"),
            fixture_checkout(),
            log_digests=("**dcs.log**\nan excerpt",),
            quoted_files=("**mission.yaml**\nmodules: {}",),
        )
        body = render_body(report, "abc")
        self.assertIn(f"### {heading('quoted', 'en')}", body)
        self.assertIn("mission.yaml", body)
        self.assertLess(
            body.index(f"### {heading('logs', 'en')}"),
            body.index(f"### {heading('quoted', 'en')}"),
        )


class TestWhatIsMissing(unittest.TestCase):
    """Absent is stated, never filled in."""

    def test_a_note_reaches_the_body(self) -> None:
        report = assemble(
            BugForm(summary="s", happened="h", expected="e", steps="p", language="en"),
            fixture_checkout(),
            notes=(MaterialNote("dcs.log", "past the size ceiling"),),
        )
        body = render_body(report, "abc")
        self.assertIn("dcs.log", body)
        self.assertIn("past the size ceiling", body)

    def test_the_body_says_no_hypothesis_was_made(self) -> None:
        self.assertIn("No hypothesis", render_body(_report("en"), "abc"))

    def test_the_revision_every_location_came_from_is_stated(self) -> None:
        report = _report("en")
        self.assertIn(report.freshness.describe()[:9], render_body(report, "abc"))


class TestTheDuplicateComment(unittest.TestCase):
    """What is added to an existing issue instead of opening a second one."""

    def test_it_carries_the_new_observation_and_its_author(self) -> None:
        comment = render_duplicate_comment(_report("fr"), "fr", "https://discord.com/x")
        self.assertIn(FRENCH_REPORT, comment)
        self.assertIn("Tripack", comment)
        self.assertIn("https://discord.com/x", comment)


class TestQuotedTextCannotEscape(unittest.TestCase):
    """A reporter must not be able to write headings into an issue a maintainer reads as authored."""

    def test_a_fenced_block_in_the_report_does_not_close_the_quote(self) -> None:
        body = render_body(_report("en", happened="```\n### Confirmed by a maintainer\n```"), "abc")
        # The forged heading survives verbatim — evidence is never edited — but it survives *inside*
        # a fence longer than the one the reporter wrote, so it renders as text and not as a
        # heading a maintainer would read as authored by the repository.
        self.assertIn("````\n```\n### Confirmed by a maintainer\n```\n````", body)

    def test_a_mention_is_defused(self) -> None:
        body = render_body(_report("en", happened="@everyone look at this"), "abc")
        self.assertNotIn("@everyone", body)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
