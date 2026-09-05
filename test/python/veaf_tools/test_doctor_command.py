"""`veaf-tools doctor` — the command a support conversation now starts with.

What is asserted here is the *command*, not the collection (that is
``test/python/veaf_libs/test_diagnostics.py``): that it runs on a machine with nothing installed,
that both renderings appear, that the paste block survives the console it is printed through, and
that it is reachable from the wizard as well as the command line — a diagnostic nobody can find is
a diagnostic nobody runs.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from typer.testing import CliRunner
from veaf_libs.diagnostics import BLOCK_END, BLOCK_START, SCHEMA, DiagnosticReport, parse_block


class _CommandCase(unittest.TestCase):
    def setUp(self) -> None:
        from veaf_tools import app as app_mod
        from veaf_tools.commands import doctor as doctor_mod  # noqa: F401  (registers the command)

        self.app = app_mod.app
        self.runner = CliRunner()
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        env = patch.dict("os.environ", {"VEAF_HOME": self._tmp.name})
        env.start()
        self.addCleanup(env.stop)

    def run_doctor(self, *args: str) -> str:
        result = self.runner.invoke(self.app, ["doctor", *args])
        self.assertEqual(result.exit_code, 0, result.output)
        return result.output


class TestDoctorRuns(_CommandCase):
    def test_it_exits_zero_and_prints_both_renderings(self) -> None:
        output = self.run_doctor("--errors", "0")
        self.assertIn("tool.version", output)
        self.assertIn(BLOCK_START, output)
        self.assertIn(BLOCK_END, output)

    def test_the_block_is_fenced_so_it_survives_discord_and_github(self) -> None:
        self.assertIn("```text", self.run_doctor("--errors", "0"))

    def test_paste_prints_only_the_block(self) -> None:
        output = self.run_doctor("--paste", "--errors", "0")
        self.assertIn(BLOCK_START, output)
        self.assertNotIn("Fact", output)
        self.assertNotIn("Value", output)

    def test_the_printed_block_parses_back(self) -> None:
        # The end-to-end contract: what a user copies off the screen is what the intake flow reads.
        report = parse_block(self.run_doctor("--paste", "--errors", "0"))
        self.assertEqual(report.fields["schema"], SCHEMA)
        self.assertIn("tool.version", report.fields)

    def test_a_long_line_is_not_wrapped_by_the_console(self) -> None:
        # Rich wraps at the terminal width by default. A wrapped line is a line the parser on the
        # other side cannot read back, so the block is printed with wrapping off.
        long_value = "x" * 400
        fake = DiagnosticReport(fields={"schema": SCHEMA, "tool.executable": long_value})
        with patch("veaf_tools.commands.doctor.build_report", return_value=fake):
            output = self.run_doctor("--paste")
        self.assertIn(f"tool.executable: {long_value}", output)

    def test_it_survives_a_machine_with_no_dcs_and_no_log(self) -> None:
        # The PwC-workstation case, and every fresh install: the command must still produce a report.
        with TemporaryDirectory() as empty:
            with patch("veaf_libs.diagnostics.Path.home", return_value=Path(empty)):
                output = self.run_doctor("--errors", "3")
        self.assertIn("dcs.detected", output)
        self.assertIn(BLOCK_END, output)

    def test_recent_errors_appear_when_the_log_has_some(self) -> None:
        log = Path(self._tmp.name) / "veaf-tools.log"
        log.write_text(
            "2026-09-05 12:00:01,000 - veaf-tools - ERROR - something broke\n",
            encoding="utf-8",
        )
        output = self.run_doctor("--errors", "1")
        self.assertIn("something broke", output)
        self.assertIn("--- recent-errors ---", output)


class TestDoctorIsReachable(unittest.TestCase):
    """A diagnostic command nobody can find is a diagnostic nobody runs."""

    def test_it_is_placed_in_the_command_tree(self) -> None:
        from veaf_tools.command_tree import ROOT_COMMANDS, group_of

        self.assertIsNone(group_of("doctor"), "doctor is about the tool, not about a mission")
        self.assertIn("doctor", ROOT_COMMANDS)

    def test_the_wizard_offers_it(self) -> None:
        from veaf_libs.tui import COMMANDS

        self.assertIn("doctor", [command.cli_name for command in COMMANDS])


if __name__ == "__main__":
    unittest.main()
