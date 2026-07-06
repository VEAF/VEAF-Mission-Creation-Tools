"""Unit tests for veaf_build.dcs_mock_audit_cli — TOOLING-DCS-MOCK-COVERAGE (TDM-002)."""

from __future__ import annotations

import json
import unittest
from unittest.mock import patch

from veaf_libs.dcs_mock_audit import AuditResult

from veaf_build import dcs_mock_audit_cli as cli

_GAP = AuditResult(missing=("coalition.addGroup",), unknown=("trigger.action.x",), unused=("land.getHeight",))
_CLEAN = AuditResult(missing=(), unknown=(), unused=())


class TestRenderMarkdown(unittest.TestCase):
    def test_gap_summary_and_sections(self) -> None:
        md = cli._render_markdown(_GAP)
        self.assertIn("1 DCS call(s) used by VEAF are not mocked", md)
        self.assertIn("`coalition.addGroup`", md)
        self.assertIn("`trigger.action.x`", md)
        self.assertIn("`land.getHeight`", md)

    def test_clean_summary(self) -> None:
        md = cli._render_markdown(_CLEAN)
        self.assertIn("Every DCS call used by VEAF is mocked", md)
        self.assertIn("_none_", md)


class TestMain(unittest.TestCase):
    def test_json_output_and_exit_code(self) -> None:
        with patch.object(cli, "run_audit", return_value=_GAP), patch("builtins.print") as mock_print:
            code = cli.main(["--format", "json"])
        self.assertEqual(code, 1)
        payload = json.loads(mock_print.call_args[0][0])
        self.assertEqual(payload["missing"], ["coalition.addGroup"])

    def test_clean_exit_code(self) -> None:
        with patch.object(cli, "run_audit", return_value=_CLEAN):
            self.assertEqual(cli.main(["--format", "markdown"]), 0)

    def test_table_format_runs(self) -> None:
        with patch.object(cli, "run_audit", return_value=_GAP):
            self.assertEqual(cli.main([]), 1)


class TestRunAudit(unittest.TestCase):
    def test_reads_real_inputs(self) -> None:
        # Smoke test against the vendored schema + real mock + real scripts.
        result = cli.run_audit()
        self.assertIsInstance(result, AuditResult)


if __name__ == "__main__":
    unittest.main()
