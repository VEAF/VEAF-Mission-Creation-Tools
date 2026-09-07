"""The seam into ``veaf-tools``: that it really crosses, and that it fails the right way.

Two properties, and the second is the one that keeps a report alive:

* the functions here run the **tools' own** code — the real ``redact``, the real ``parse_block``, the
  real excerpt builder — out of a checkout, rather than a stand-in agreeing with itself;
* a checkout that cannot supply one of them raises :class:`ToolkitUnavailable`, and the callers turn
  that into a stated missing section instead of a lost report.
"""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from tests.intake_fixtures import FORGED_BLOCK, doctor_block, fixture_root
from veaf_support_bot.toolkit import (
    PUBLISHED_MISSION_FIELDS,
    ToolkitUnavailable,
    _diagnostic_profile,
    _mission_table,
    _select_published_fields,
    digest_log,
    expected_schema,
    parse_doctor_block,
    redact,
    summarise_mission,
)

#: A ``mission`` file shaped the way DCS writes one, small enough to read and complete enough that
#: the real parser accepts it.
_LUA_MISSION = """mission =
{
    ["theatre"] = "Caucasus",
    ["version"] = 22,
    ["start_time"] = 28800,
    ["descriptionText"] = "Squadron briefing, with a real name in it",
    ["date"] =
    {
        ["Year"] = 2016,
        ["Month"] = 6,
        ["Day"] = 21,
    },
    ["weather"] =
    {
        ["clouds"] =
        {
            ["base"] = 2000,
            ["preset"] = "Preset10",
        },
        ["season"] =
        {
            ["temperature"] = 20,
        },
    },
    ["triggers"] =
    {
        ["zones"] =
        {
            [1] =
            {
                ["name"] = "ZoneA",
                ["radius"] = 1000,
            },
        },
    },
    ["coalition"] =
    {
        ["blue"] =
        {
            ["country"] =
            {
                [1] =
                {
                    ["id"] = 2,
                    ["name"] = "USA",
                    ["plane"] =
                    {
                        ["group"] =
                        {
                            [1] =
                            {
                                ["name"] = "VEAF 1-1",
                            },
                        },
                    },
                },
            },
        },
    },
}
"""

#: A log shaped like the real thing: DCS records, one of them an error, and a home directory.
SYNTHETIC_LOG = "\n".join(
    [
        "2026-09-05 10:00:00.000 INFO    APP (Main): DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)",
        *[f"2026-09-05 10:00:{index:02d}.000 INFO    TERRAIN (Main): loading tile {index}" for index in range(1, 60)],
        r"2026-09-05 10:01:00.000 ERROR   SCRIPTING (Main): Mission script error: C:\Users\Firstname Lastname\dev\x.lua:3: boom",
        "2026-09-05 10:01:01.000 WARNING SOUND (Main): missing sample",
    ]
)


class TestRedactionCrossesTheSeam(unittest.TestCase):
    def test_a_home_directory_is_stripped_by_the_tools_own_helper(self) -> None:
        raw = r"failed reading C:\Users\Firstname Lastname\Saved Games\DCS\Logs\dcs.log"
        self.assertNotIn("Firstname Lastname", redact(fixture_root(), raw))

    def test_a_checkout_with_no_tools_tree_refuses_rather_than_returning_the_text(self) -> None:
        """Failing open here would publish a home directory because an import failed."""
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaises(ToolkitUnavailable):
                redact(Path(empty) / "nowhere", "anything")


class TestTheDoctorBlock(unittest.TestCase):
    def test_a_real_block_is_parsed_by_the_tools_own_parser(self) -> None:
        facts = parse_doctor_block(fixture_root(), f"here you go\n{doctor_block('6.16.3')}\nthanks")
        self.assertTrue(facts.present)
        self.assertEqual(facts.claim("tool.version"), "6.16.3")
        self.assertEqual(facts.schema, expected_schema(fixture_root()))

    def test_no_block_is_reported_as_missing_and_never_guessed(self) -> None:
        facts = parse_doctor_block(fixture_root(), "I did not run that command")
        self.assertFalse(facts.present)
        self.assertEqual(facts.claim("tool.version"), "")
        self.assertTrue(facts.problem)

    def test_an_empty_field_is_reported_as_missing(self) -> None:
        self.assertFalse(parse_doctor_block(fixture_root(), "   ").present)

    def test_a_truncated_block_is_reported_rather_than_half_parsed(self) -> None:
        facts = parse_doctor_block(fixture_root(), "=== VEAF-TOOLS DOCTOR BEGIN ===\ntool.version: 1.0\n")
        self.assertFalse(facts.present)
        self.assertIn("could not be read", facts.problem)

    def test_a_hand_typed_block_parses_and_stays_a_claim(self) -> None:
        """The format is designed to be pasted; what comes back is what the text said, not a reading."""
        facts = parse_doctor_block(fixture_root(), FORGED_BLOCK)
        self.assertTrue(facts.present)
        self.assertEqual(facts.claim("tool.version"), "99.99.99")

    def test_an_unreachable_parser_is_a_missing_block_not_a_crash(self) -> None:
        with tempfile.TemporaryDirectory() as empty:
            facts = parse_doctor_block(Path(empty) / "nowhere", doctor_block())
        self.assertFalse(facts.present)
        self.assertTrue(facts.problem)
        self.assertEqual(facts.claim("tool.version"), "")


class TestTheLogDigest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.log = Path(self.directory.name) / "dcs.log"
        self.log.write_text(SYNTHETIC_LOG + "\n", encoding="utf-8")
        self.addCleanup(self.directory.cleanup)

    def test_a_large_log_is_reduced_and_bounded(self) -> None:
        digest = digest_log(fixture_root(), self.log, max_chars=2000)
        self.assertLessEqual(len(digest.excerpt), 2000)
        self.assertEqual(digest.total_records, len(SYNTHETIC_LOG.splitlines()))
        self.assertLess(digest.selected_records, digest.total_records)

    def test_the_excerpt_is_already_redacted(self) -> None:
        """The excerpt builder redacts; this asserts the service is not relying on doing it twice."""
        digest = digest_log(fixture_root(), self.log)
        self.assertNotIn("Firstname Lastname", digest.excerpt)

    def test_the_catalogue_speaks_in_its_own_wording(self) -> None:
        digest = digest_log(fixture_root(), self.log)
        self.assertTrue(digest.catalogue.strip())

    def test_a_checkout_without_the_log_tooling_refuses(self) -> None:
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaises(ToolkitUnavailable):
                digest_log(Path(empty) / "nowhere", self.log)

    def test_a_log_the_reader_chokes_on_is_a_missing_section_not_a_lost_report(self) -> None:
        with self.assertRaises(ToolkitUnavailable):
            digest_log(fixture_root(), Path(self.directory.name) / "there-is-no-such-file.log")

    def test_a_renamed_diagnostic_profile_falls_back_on_what_the_profile_does(self) -> None:
        """Its display name is French prose; a reword must not silently pick the wrong profile."""

        class _Renamed:
            @staticmethod
            def builtin_profiles(_: object) -> dict[str, object]:
                class _Filters:
                    context_lines = 0

                class _WithContext:
                    context_lines = 3

                return {"Tout": _Filters(), "Erreurs et alentours": _WithContext()}

        chosen = _diagnostic_profile(_Renamed(), object())  # type: ignore[arg-type]
        self.assertEqual(chosen.context_lines, 3)

    def test_a_catalogue_with_no_diagnostic_profile_at_all_refuses(self) -> None:
        class _Nothing:
            @staticmethod
            def builtin_profiles(_: object) -> dict[str, object]:
                return {}

        with self.assertRaises(ToolkitUnavailable):
            _diagnostic_profile(_Nothing(), object())  # type: ignore[arg-type]


class TestTheMissionSummary(unittest.TestCase):
    #: A parsed mission table shaped like the real thing, including the fields that must not travel.
    TABLE = {
        "theatre": "Caucasus",
        "version": 22,
        "start_time": 28800,
        "date": {"Year": 2016, "Month": 6, "Day": 21},
        "descriptionText": "Squadron briefing, with a real name in it",
        "sortie": "Operation Something",
        "weather": {"season": {"temperature": 20}, "clouds": {"base": 2000, "preset": "Preset10"}},
        "triggers": {"zones": [{"name": "ZoneA"}, {"name": "ZoneB"}]},
        "coalition": {
            "blue": {
                "country": [
                    {
                        "plane": {"group": [{"name": "VEAF 1-1"}, {"name": "VEAF 1-2"}]},
                        "vehicle": {"group": [{"name": "convoy"}]},
                    }
                ]
            },
            "red": {"country": [{"plane": {"group": [{"name": "bandit"}]}}]},
        },
    }

    def test_only_the_chosen_fields_are_published(self) -> None:
        summary = _select_published_fields(dict(self.TABLE))
        self.assertLessEqual(set(summary.fields), set(PUBLISHED_MISSION_FIELDS))

    def test_the_briefing_prose_never_travels(self) -> None:
        summary = _select_published_fields(dict(self.TABLE))
        rendered = repr(summary.fields)
        self.assertNotIn("Squadron briefing", rendered)
        self.assertNotIn("Operation Something", rendered)

    def test_group_names_are_counted_not_listed(self) -> None:
        summary = _select_published_fields(dict(self.TABLE))
        self.assertEqual(summary.fields["group_counts"], {"blue/plane": 2, "blue/vehicle": 1, "red/plane": 1})
        self.assertNotIn("VEAF 1-1", repr(summary.fields))

    def test_the_shape_that_helps_reproduce_is_kept(self) -> None:
        summary = _select_published_fields(dict(self.TABLE))
        self.assertEqual(summary.fields["theatre"], "Caucasus")
        self.assertEqual(summary.fields["date"], "2016-6-21")
        self.assertEqual(summary.fields["trigger_zone_count"], 2)
        self.assertEqual(summary.fields["weather"]["cloud_base"], 2000)

    def test_what_was_dropped_is_named(self) -> None:
        summary = _select_published_fields(dict(self.TABLE))
        self.assertIn("descriptionText", summary.withheld)

    def test_nothing_is_claimed_withheld_that_the_same_report_publishes(self) -> None:
        """An issue that says *not published: weather* while printing the weather loses its credit."""
        summary = _select_published_fields(dict(self.TABLE))
        for key, published in (("weather", "weather"), ("coalition", "coalitions"), ("triggers", "trigger_zone_count")):
            with self.subTest(key=key):
                self.assertIn(published, summary.fields, "the fixture must publish it, or this proves nothing")
                self.assertNotIn(key, summary.withheld, "claimed withheld while being published")
                stated = [entry for entry in summary.withheld if entry.startswith(key)]
                self.assertEqual(len(stated), 1, "what was left out of it is still named")
                self.assertIn("above", stated[0])

    def test_a_key_that_really_was_dropped_is_still_named_plainly(self) -> None:
        """A mission whose weather block is not a table has nothing published from it."""
        table = dict(self.TABLE) | {"weather": "not a table"}
        summary = _select_published_fields(table)
        self.assertNotIn("weather", summary.fields)
        self.assertIn("weather", summary.withheld)

    def test_the_dict_shape_of_a_sequence_table_is_counted_too(self) -> None:
        """The Lua parser hands back a dict when the keys were never a contiguous 1..N."""
        table = dict(self.TABLE)
        table["coalition"] = {"blue": {"country": {"1": {"plane": {"group": {"1": {}, "2": {}}}}}}}
        summary = _select_published_fields(table)
        self.assertEqual(summary.fields["group_counts"], {"blue/plane": 2})

    def test_a_mission_stating_none_of_the_published_fields_yields_an_empty_set(self) -> None:
        summary = _select_published_fields({"descriptionText": "only prose"})
        self.assertEqual(summary.fields, {})
        self.assertEqual(summary.withheld, ("descriptionText",))

    def test_the_parsed_table_is_found_wherever_the_parser_put_it(self) -> None:
        class _Parsed:
            mission_content = {"theatre": "Syria"}

        self.assertEqual(_mission_table(_Parsed()), {"theatre": "Syria"})
        self.assertEqual(_mission_table({"theatre": "Syria"}), {"theatre": "Syria"})
        self.assertEqual(_mission_table(object()), {})

    def test_a_mission_the_parser_cannot_read_refuses_rather_than_crashing_the_report(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            broken = Path(directory) / "broken.miz"
            broken.write_bytes(b"not a zip at all")
            with self.assertRaises(ToolkitUnavailable):
                summarise_mission(fixture_root(), broken)

    def test_a_real_miz_goes_through_the_tools_own_parser(self) -> None:
        """End to end: a real archive, the real ``read_miz``, and only the chosen fields out."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.miz"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("mission", _LUA_MISSION)
                archive.writestr("options", "options = {}")
                archive.writestr("warehouses", 'warehouses = { ["airports"] = {} }')
            summary = summarise_mission(fixture_root(), path)
        self.assertEqual(summary.fields["theatre"], "Caucasus")
        self.assertEqual(summary.fields["trigger_zone_count"], 1)
        self.assertEqual(summary.fields["group_counts"], {"blue/plane": 1})
        self.assertNotIn("VEAF 1-1", repr(summary.fields), "group names are counted, never listed")
        self.assertNotIn("Squadron briefing", repr(summary.fields))


if __name__ == "__main__":
    unittest.main()
