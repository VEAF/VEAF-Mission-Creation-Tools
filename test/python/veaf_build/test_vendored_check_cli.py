"""Unit tests for veaf_build.vendored_check_cli — VENDORED-DRIFT-WATCH (VDW-003)."""

from __future__ import annotations

import json
import unittest
from unittest.mock import MagicMock, patch

from veaf_libs.vendored_check import Artifact, CheckReport, Watch, WatchResult

from veaf_build import vendored_check_cli as cli

_ARTIFACTS = (
    Artifact(
        "tum",
        "u",
        "u",
        "0.1",
        "verbatim",
        "src/tum.lua",
        "re-download",
        (Watch("github-release", "u/t", "", "", "0.1", ""),),
    ),
    Artifact("herc", "", "", "?", "verbatim", "src/h.lua", "manual dl", (Watch("manual", "", "", "", "", ""),)),
)
_DRIFT = CheckReport(
    artifacts=_ARTIFACTS,
    results=(
        WatchResult("tum", "github-release", "u/t", "", "0.1", "0.3", "drifted"),
        WatchResult("herc", "manual", "", "", "", None, "manual"),
    ),
)
_CLEAN = CheckReport(
    artifacts=_ARTIFACTS,
    results=(
        WatchResult("tum", "github-release", "u/t", "", "0.1", "0.1", "up-to-date"),
        WatchResult("herc", "manual", "", "", "", None, "manual"),
    ),
)


class TestRenderMarkdown(unittest.TestCase):
    def test_drift_lists_steps_and_manual(self) -> None:
        md = cli._render_markdown(_DRIFT)
        self.assertIn("1 drifted", md)
        self.assertIn("**tum**", md)
        self.assertIn("`0.1` → `0.3`", md)
        self.assertIn("re-download", md)
        self.assertIn("Manual re-checks", md)
        self.assertIn("manual dl", md)

    def test_clean_summary(self) -> None:
        md = cli._render_markdown(_CLEAN)
        self.assertIn("up to date", md)


class TestMain(unittest.TestCase):
    def test_json_and_exit_on_drift(self) -> None:
        with patch.object(cli, "run_check", return_value=_DRIFT), patch("builtins.print") as p:
            code = cli.main(["--format", "json"])
        self.assertEqual(code, 1)
        payload = json.loads(p.call_args[0][0])
        self.assertEqual(payload["drifted"], 1)
        self.assertEqual(payload["manual"], 1)

    def test_clean_exit(self) -> None:
        with patch.object(cli, "run_check", return_value=_CLEAN):
            self.assertEqual(cli.main(["--format", "markdown"]), 0)

    def test_table_runs(self) -> None:
        with patch.object(cli, "run_check", return_value=_DRIFT):
            self.assertEqual(cli.main([]), 1)


class TestRequestsGitHubClient(unittest.TestCase):
    def _resp(self, status, payload):
        r = MagicMock()
        r.status_code = status
        r.json.return_value = payload
        return r

    def test_latest_release_ok_and_404(self) -> None:
        client = cli._RequestsGitHubClient(token="t")
        with patch("requests.get", return_value=self._resp(200, {"tag_name": "v9"})):
            self.assertEqual(client.latest_release("o/r"), "v9")
        with patch("requests.get", return_value=self._resp(404, {})):
            self.assertIsNone(client.latest_release("o/r"))

    def test_latest_file_commit(self) -> None:
        client = cli._RequestsGitHubClient()
        with patch("requests.get", return_value=self._resp(200, [{"sha": "abc"}])):
            self.assertEqual(client.latest_file_commit("o/r", "master", "f.lua"), "abc")
        with patch("requests.get", return_value=self._resp(200, [])):
            self.assertIsNone(client.latest_file_commit("o/r", "master", None))

    def test_network_error_returns_none(self) -> None:
        import requests

        client = cli._RequestsGitHubClient()
        with patch("requests.get", side_effect=requests.RequestException("boom")):
            self.assertIsNone(client.latest_release("o/r"))
            self.assertIsNone(client.latest_file_commit("o/r", "master", None))


class TestRunCheckReadsManifest(unittest.TestCase):
    def test_real_manifest_with_fake_client(self) -> None:
        # Smoke test: the shipped vendored.yaml parses and evaluates without network.
        class Fake:
            def latest_release(self, repo):
                return None

            def latest_file_commit(self, repo, ref, file):
                return None

        report = cli.run_check(client=Fake())
        self.assertTrue(len(report.artifacts) >= 10)
        self.assertTrue(any(r.status == "manual" for r in report.results))


if __name__ == "__main__":
    unittest.main()
