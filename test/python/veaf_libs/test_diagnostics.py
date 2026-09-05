"""The diagnostic report and its paste block (FEAT-SUPPORT-DIAGNOSTIC ticket 01).

Two things are pinned here rather than eyeballed. **The block is a contract**: two later lots
(`FEAT-SUPPORT-LOG-ANALYSIS` ticket 05, `FEAT-SUPPORT-BUG-INTAKE` ticket 02) parse it, so the
round trip — build, render, parse back — is tested end to end and not just in halves. And **nothing
may crash**: a diagnostic that dies on the machine being diagnosed is worthless, so each collector
is exercised with its subject missing (no DCS, no log, no `VEAF_HOME`).
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from veaf_libs import diagnostics
from veaf_libs.diagnostics import (
    BLOCK_END,
    BLOCK_START,
    FIELD_ORDER,
    MAX_CHARS_PER_LINE,
    MAX_LINES_PER_ERROR,
    SCHEMA,
    UNKNOWN,
    DiagnosticReport,
    build_report,
    collect_recent_errors,
    find_dcs_write_dirs,
    parse_block,
    read_dcs_version,
    tool_log_path,
)

#: The banner DCS writes on the sixth line of its log — copied from a real one, 2026-09-05.
_DCS_HEADER = (
    "=== Log opened UTC 2026-09-01 16:28:21\n"
    '2026-09-01 16:28:22.943 INFO    APP (Main): Command line: "c:\\jeux\\DCS World\\bin/DCS.exe"\n'
    "2026-09-01 16:28:22.943 INFO    APP (Main): DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)\n"
)


def _make_dcs(home: Path, folder: str, header: str = _DCS_HEADER) -> Path:
    """Create a fake ``Saved Games/<folder>/Logs/dcs.log`` under *home*."""
    logs = home / "Saved Games" / folder / "Logs"
    logs.mkdir(parents=True, exist_ok=True)
    (logs / "dcs.log").write_text(header, encoding="utf-8")
    return home / "Saved Games" / folder


class TestTheBlockIsAContract(unittest.TestCase):
    def test_the_block_announces_its_schema(self) -> None:
        report = DiagnosticReport(fields={"schema": SCHEMA, "tool.version": "6.19.0"})
        self.assertIn(f"schema: {SCHEMA}", report.to_block())

    def test_the_block_is_delimited_so_it_can_be_found_in_prose(self) -> None:
        block = DiagnosticReport(fields={"schema": SCHEMA}).to_block()
        self.assertTrue(block.startswith(BLOCK_START))
        self.assertTrue(block.endswith(BLOCK_END))

    def test_fields_come_in_the_declared_order(self) -> None:
        # Declared backwards on purpose: the block must impose FIELD_ORDER, not echo insertion order.
        report = DiagnosticReport(fields={"tool.version": "6.19.0", "schema": SCHEMA})
        body = [line for line in report.to_block().splitlines() if ":" in line]
        self.assertEqual(body[0].split(":")[0], "schema")

    def test_a_value_cannot_forge_a_second_field(self) -> None:
        # A field is one line, and nothing enforced it: a value carrying a newline came back as two
        # fields, the second one never written by the producer. No collector can do that today, but
        # FEAT-SUPPORT-BUG-INTAKE runs `parse_block` over text a stranger pasted into a public issue.
        report = DiagnosticReport(fields={"schema": SCHEMA, "machine.os": "Windows\nevil: injected"})
        parsed = parse_block(report.to_block())
        self.assertNotIn("evil", parsed.fields)
        self.assertEqual(parsed.fields["machine.os"], "Windows evil: injected")

    def test_a_field_name_cannot_forge_one_either(self) -> None:
        report = DiagnosticReport(fields={"schema": SCHEMA, "a\nb": "x"})
        self.assertEqual(len(parse_block(report.to_block()).fields), 2)

    def test_an_unknown_field_still_travels(self) -> None:
        # A consumer reading what it knows must not lose a field this version added.
        report = DiagnosticReport(fields={"schema": SCHEMA, "future.thing": "42"})
        self.assertIn("future.thing: 42", report.to_block())


class TestRoundTrip(unittest.TestCase):
    """Build → render → parse back must yield the fields the intake flow expects."""

    def test_fields_survive_the_round_trip(self) -> None:
        original = DiagnosticReport(fields={name: f"value-of-{name}" for name in FIELD_ORDER})
        self.assertEqual(parse_block(original.to_block()).fields, original.fields)

    def test_a_multiline_record_comes_back_as_one_entry(self) -> None:
        record = (
            "2026-09-05 12:00:00,123 - veaf-tools - ERROR - boom\n"
            "Traceback (most recent call last):\n"
            '  File "x.py", line 1, in <module>\n'
            "ValueError: boom"
        )
        original = DiagnosticReport(fields={"schema": SCHEMA}, recent_errors=[record])
        self.assertEqual(parse_block(original.to_block()).recent_errors, [record])

    def test_several_records_are_split_on_their_headers(self) -> None:
        records = [
            "2026-09-05 12:00:00,123 - veaf-tools - ERROR - first\n  detail",
            "2026-09-05 12:00:01,000 - veaf-tools - ERROR - second",
        ]
        original = DiagnosticReport(fields={"schema": SCHEMA}, recent_errors=records)
        self.assertEqual(parse_block(original.to_block()).recent_errors, records)

    def test_the_block_is_found_inside_a_surrounding_message(self) -> None:
        # How it actually arrives: pasted in the middle of a Discord message, inside code fences.
        original = DiagnosticReport(fields={"schema": SCHEMA, "tool.version": "6.19.0"})
        message = f"hello, here it is:\n```text\n{original.to_block()}\n```\nthanks!"
        self.assertEqual(parse_block(message).fields["tool.version"], "6.19.0")

    def test_a_truncated_paste_is_refused_rather_than_half_parsed(self) -> None:
        partial = DiagnosticReport(fields={"schema": SCHEMA}).to_block().replace(BLOCK_END, "")
        with self.assertRaises(ValueError):
            parse_block(partial)

    def test_text_without_a_block_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            parse_block("just a complaint, no block")


class TestDcsDetection(unittest.TestCase):
    def test_the_version_is_read_from_the_log_banner(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _make_dcs(Path(tmp), "DCS")
            self.assertEqual(read_dcs_version(folder / "Logs" / "dcs.log"), "2.9.29.27278")

    def test_a_log_without_the_banner_reports_unknown(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _make_dcs(Path(tmp), "DCS", header="nothing useful here\n")
            self.assertEqual(read_dcs_version(folder / "Logs" / "dcs.log"), UNKNOWN)

    def test_a_missing_log_reports_unknown_rather_than_raising(self) -> None:
        self.assertEqual(read_dcs_version(Path("no-such-file.log")), UNKNOWN)

    def test_only_folders_holding_a_log_count_as_an_install(self) -> None:
        # A machine carries per-module folders the updater leaves behind (DCS_F14, DCS.C130J…);
        # they are not installs and must not be reported as one.
        with TemporaryDirectory() as tmp:
            home = Path(tmp)
            _make_dcs(home, "DCS")
            (home / "Saved Games" / "DCS_F14").mkdir(parents=True)
            self.assertEqual([f.name for f in find_dcs_write_dirs(home)], ["DCS"])

    def test_the_freshest_install_comes_first(self) -> None:
        import os
        import time

        with TemporaryDirectory() as tmp:
            home = Path(tmp)
            stable = _make_dcs(home, "DCS")
            beta = _make_dcs(home, "DCS.openbeta")
            now = time.time()
            os.utime(stable / "Logs" / "dcs.log", (now - 10_000, now - 10_000))
            os.utime(beta / "Logs" / "dcs.log", (now, now))
            self.assertEqual([f.name for f in find_dcs_write_dirs(home)], ["DCS.openbeta", "DCS"])

    def test_no_saved_games_folder_at_all(self) -> None:
        with TemporaryDirectory() as tmp:
            self.assertEqual(find_dcs_write_dirs(Path(tmp)), [])

    def test_the_variant_is_named_from_the_folder(self) -> None:
        self.assertEqual(diagnostics._dcs_variant("DCS"), "stable")
        self.assertEqual(diagnostics._dcs_variant("DCS.openbeta"), "openbeta")


class TestRecentErrors(unittest.TestCase):
    def _log(self, tmp: str, body: str) -> Path:
        path = Path(tmp) / "veaf-tools.log"
        path.write_text(body, encoding="utf-8")
        return path

    def test_only_error_records_are_kept(self) -> None:
        with TemporaryDirectory() as tmp:
            path = self._log(
                tmp,
                "2026-09-05 12:00:00,000 - veaf-tools - INFO - starting\n"
                "2026-09-05 12:00:01,000 - veaf-tools - ERROR - boom\n"
                "2026-09-05 12:00:02,000 - veaf-tools - INFO - done\n",
            )
            errors = collect_recent_errors(5, path)
            self.assertEqual(len(errors), 1)
            self.assertIn("boom", errors[0])

    def test_a_traceback_stays_attached_to_its_record(self) -> None:
        with TemporaryDirectory() as tmp:
            path = self._log(
                tmp,
                "2026-09-05 12:00:01,000 - veaf-tools - ERROR - boom\n"
                "Traceback (most recent call last):\n"
                "ValueError: boom\n"
                "2026-09-05 12:00:02,000 - veaf-tools - INFO - done\n",
            )
            self.assertIn("Traceback", collect_recent_errors(5, path)[0])

    def test_only_the_last_n_records_are_returned(self) -> None:
        with TemporaryDirectory() as tmp:
            body = "".join(f"2026-09-05 12:00:0{i},000 - veaf-tools - ERROR - boom{i}\n" for i in range(5))
            errors = collect_recent_errors(2, self._log(tmp, body))
            self.assertEqual([e.split(" - ")[-1] for e in errors], ["boom3", "boom4"])

    def test_a_record_is_capped_in_lines(self) -> None:
        with TemporaryDirectory() as tmp:
            body = "2026-09-05 12:00:01,000 - veaf-tools - ERROR - boom\n" + "  frame\n" * 200
            self.assertEqual(len(collect_recent_errors(1, self._log(tmp, body))[0].splitlines()), MAX_LINES_PER_ERROR)

    def test_a_single_enormous_line_is_capped_too(self) -> None:
        # Measured on the real log: one record quoted a rejected expression over 400 characters
        # long, on one line. Capping lines alone would not have bounded it.
        with TemporaryDirectory() as tmp:
            body = "2026-09-05 12:00:01,000 - veaf-tools - ERROR - " + "x" * 2000 + "\n"
            line = collect_recent_errors(1, self._log(tmp, body))[0]
            self.assertLessEqual(len(line), MAX_CHARS_PER_LINE + len(diagnostics.TRUNCATION_MARK))

    def test_records_are_redacted(self) -> None:
        with TemporaryDirectory() as tmp:
            body = "2026-09-05 12:00:01,000 - veaf-tools - ERROR - cannot read C:\\Users\\Bob\\a.miz\n"
            self.assertNotIn("Bob", collect_recent_errors(1, self._log(tmp, body))[0])

    def test_a_missing_log_yields_nothing_rather_than_raising(self) -> None:
        self.assertEqual(collect_recent_errors(3, Path("no-such-file.log")), [])

    def test_the_history_moved_into_the_rolled_file_is_still_read(self) -> None:
        # The first rollover after the upgrade moves the *whole* previous log into `.1` — measured:
        # a 40 MB log became a 28-byte live file and a 40 MB `.1`. Reading only the live file
        # answered "no recent errors" to a user reporting a crash, on the one run that mattered.
        with TemporaryDirectory() as tmp:
            path = self._log(tmp, "2026-09-05 12:00:09,000 - veaf-tools - ERROR - after the rollover\n")
            body = "".join(f"2026-09-05 12:00:0{i},000 - veaf-tools - ERROR - before{i}\n" for i in range(3))
            (Path(tmp) / "veaf-tools.log.1").write_text(body, encoding="utf-8")
            errors = collect_recent_errors(4, path)
            self.assertEqual(
                [e.split(" - ")[-1] for e in errors],
                ["before0", "before1", "before2", "after the rollover"],
            )

    def test_the_rolled_files_are_only_read_when_the_live_one_is_short(self) -> None:
        with TemporaryDirectory() as tmp:
            path = self._log(
                tmp,
                "".join(f"2026-09-05 12:00:0{i},000 - veaf-tools - ERROR - live{i}\n" for i in range(3)),
            )
            (Path(tmp) / "veaf-tools.log.1").write_text(
                "2026-09-05 11:00:00,000 - veaf-tools - ERROR - rolled\n", encoding="utf-8"
            )
            errors = collect_recent_errors(2, path)
            self.assertEqual([e.split(" - ")[-1] for e in errors], ["live1", "live2"])

    def test_a_gap_in_the_rolled_files_stops_the_search(self) -> None:
        with TemporaryDirectory() as tmp:
            path = self._log(tmp, "")
            (Path(tmp) / "veaf-tools.log.2").write_text(
                "2026-09-05 11:00:00,000 - veaf-tools - ERROR - orphan\n", encoding="utf-8"
            )
            self.assertEqual(collect_recent_errors(3, path), [])

    def test_asking_for_none_reads_nothing(self) -> None:
        self.assertEqual(collect_recent_errors(0, Path("no-such-file.log")), [])

    def test_the_default_log_sits_in_the_veaf_home_not_the_current_directory(self) -> None:
        # The documentation pointed at the current directory for years, so someone following it
        # found nothing and concluded there was no log. This is the answer it now gives.
        from veaf_libs.veaf_home import get_veaf_home

        with TemporaryDirectory() as tmp, patch.dict("os.environ", {"VEAF_HOME": tmp}):
            self.assertEqual(tool_log_path(), get_veaf_home() / "veaf-tools.log")
            self.assertNotEqual(tool_log_path().parent, Path.cwd())


class TestBuildReportSurvivesAnything(unittest.TestCase):
    def test_every_declared_field_is_present(self) -> None:
        with TemporaryDirectory() as tmp:
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(tuple(report.fields), FIELD_ORDER)

    def test_no_dcs_is_reported_rather_than_crashing(self) -> None:
        with TemporaryDirectory() as tmp:
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(report.fields["dcs.detected"], "no")
            self.assertEqual(report.fields["dcs.version"], UNKNOWN)

    def test_dcs_present_is_read_out(self) -> None:
        with TemporaryDirectory() as tmp:
            _make_dcs(Path(tmp), "DCS")
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(report.fields["dcs.version"], "2.9.29.27278")
            self.assertEqual(report.fields["dcs.variant"], "stable")

    def test_a_collector_that_explodes_costs_only_its_own_fields(self) -> None:
        with TemporaryDirectory() as tmp, patch.object(diagnostics, "_collect_machine", side_effect=OSError("nope")):
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(report.fields["machine.os"], UNKNOWN)
            self.assertNotEqual(report.fields["tool.version"], UNKNOWN)

    def test_the_produced_block_parses_back(self) -> None:
        with TemporaryDirectory() as tmp:
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(parse_block(report.to_block()).fields, report.fields)

    def test_the_veaf_home_is_read_from_the_environment(self) -> None:
        with TemporaryDirectory() as tmp, patch.dict("os.environ", {"VEAF_HOME": tmp}):
            report = build_report(error_count=0, home=Path(tmp), log_path=Path(tmp) / "absent.log")
            self.assertEqual(report.fields["veaf.log"], "absent")

    def test_nothing_in_the_block_carries_the_account_name(self) -> None:
        # The whole point: whatever the machine answers, the block is safe to paste in public.
        with TemporaryDirectory() as tmp:
            home = Path(tmp) / "Users" / "Jean Dupont"
            _make_dcs(home, "DCS")
            report = build_report(error_count=0, home=home, log_path=Path(tmp) / "absent.log")
            self.assertNotIn("Jean Dupont", report.to_block())


if __name__ == "__main__":
    unittest.main()
