"""The report has to print what the conversion collected — ticket 02 of FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.

``ConversionReport`` carries two lists documented as what the run has to say, ``actions``
("shown in the summary") and ``manual_review``. Neither reached the markdown: ``self.actions``
occurred **zero** times in the report builder, and ``self.manual_review`` once, only to count
items for the ``N items need manual action`` line. So the count was right while the list behind
it was invisible — a number with nothing to read.

That is how the 2026-08-25 refresh of five Foothold missions onto Lekaa 4.7.0 printed
*"None — the migration completed without warnings"* on a run that had renamed a script and found
six mismatched load delays per mission.

Every test here asserts the **rendered text**. The existing suite asserted the lists
(``any("aien.lua" in a.lower() for a in report.actions)``), which passed throughout — the lists
were never the broken half.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.other_converter import OtherMissionConverter
from mission_builder.v5_converter import ConversionReport
from upstream_miz import make_upstream_miz

# The Syria rename of Lekaa 4.7.0, reduced to what makes it a test: one script the release drops,
# one it introduces, one staged loader kept across both.
BEFORE_RENAME = (
    ("Foothold Config.lua", None),
    ("footholdSyriaSetup.lua", None),
    ("AIEN.lua", 12.0),
)
AFTER_RENAME = (
    ("Foothold Config.lua", None),
    ("footholdSyriaSetupv2.lua", None),
    ("AIEN.lua", 12.0),
)


class TestTheReportPrintsItsLists(unittest.TestCase):
    """A populated list must appear in the markdown, not only in the object."""

    def test_manual_review_items_are_printed(self) -> None:
        report = ConversionReport(mission_folder=Path("mission"), version="test")
        report.manual_review.append("check the load order of Zeus.lua")

        self.assertIn("check the load order of Zeus.lua", report.to_markdown())

    def test_actions_are_printed(self) -> None:
        report = ConversionReport(mission_folder=Path("mission"), version="test")
        report.actions.append("extracted Foothold_SY_4.7.0.miz")

        self.assertIn("extracted Foothold_SY_4.7.0.miz", report.to_markdown())

    def test_the_counter_and_the_items_agree(self) -> None:
        # The counter was already right; it just had nothing to point at. Pinning both together
        # so a future edit cannot restore the state where one moves without the other.
        report = ConversionReport(mission_folder=Path("mission"), version="test")
        report.manual_review += ["first item", "second item"]
        report.warnings.append("a warning")

        markdown = report.to_markdown()

        self.assertIn("3", markdown.split("\n---")[0], "the summary counts review items and warnings")
        for item in ("first item", "second item", "a warning"):
            self.assertIn(item, markdown, item)

    def test_an_empty_report_does_not_print_an_empty_section(self) -> None:
        markdown = ConversionReport(mission_folder=Path("mission"), version="test").to_markdown()

        # No heading promising content that is not there — the failure mode this whole ticket is
        # about is a report that reads as "nothing happened" when something did.
        self.assertNotIn("- \n", markdown, "an empty bullet is a list rendered from nothing")


class TestUpdateReportNamesWhatChanged(unittest.TestCase):
    """End to end: `--update` on a release that added, updated and removed a script."""

    def _refresh(self) -> str:
        """Adopt the old release, refresh onto the new one, return the written report."""
        root = Path(tempfile.mkdtemp())
        mission = root / "VEAF-Foothold-Syria"
        old = make_upstream_miz(BEFORE_RENAME, folder=root / "4.6.0", name="Foothold_SY_4.6.0.miz")
        new = make_upstream_miz(AFTER_RENAME, folder=root / "4.7.0", name="Foothold_SY_4.7.0.miz", body="-- 4.7.0\n")

        converter = OtherMissionConverter(version="test")
        converter.convert(old, mission, profile_name="foothold")
        report = converter.convert(new, mission, profile_name="foothold", update=True)
        return report.to_markdown()

    def test_the_added_script_is_named(self) -> None:
        self.assertIn("footholdSyriaSetupv2.lua", self._refresh())

    def test_the_updated_scripts_are_named(self) -> None:
        self.assertIn("AIEN.lua", self._refresh())

    def test_the_removed_script_is_named(self) -> None:
        # The one that cost the most: it stayed on disk, stayed in mission.yaml, `validate` stayed
        # green, and the build would have injected the previous release's version of it.
        self.assertIn("footholdSyriaSetup.lua", self._refresh())


if __name__ == "__main__":
    unittest.main()
