"""Unit tests for veaf_libs.vendored_check — VENDORED-DRIFT-WATCH (VDW-003)."""

from __future__ import annotations

import unittest

from veaf_libs.vendored_check import (
    STATUS_DRIFTED,
    STATUS_ERROR,
    STATUS_MANUAL,
    STATUS_UP_TO_DATE,
    Artifact,
    Watch,
    check_artifacts,
    evaluate_watch,
    parse_manifest,
)

_FIXTURE = {
    "artifacts": [
        {
            "id": "forked",
            "source": "https://github.com/VEAF/Thing",
            "upstream": "https://github.com/up/Thing",
            "pinned": "1.0-VEAF",
            "vendoring": "fork",
            "path": "src/thing.lua",
            "manual_steps": "rebase the fork",
            "watch": [
                {"kind": "github-file", "repo": "VEAF/Thing", "ref": "master", "pinned": "abc123"},
                {"kind": "github-release", "repo": "up/Thing", "pinned": "1.0", "role": "upstream-ref"},
            ],
        },
        {
            "id": "verb",
            "source": "https://github.com/up/Verb",
            "upstream": "https://github.com/up/Verb",
            "pinned": "v2",
            "vendoring": "verbatim",
            "path": "src/verb.json",
            "manual_steps": "",
            "watch": [{"kind": "github-release", "repo": "up/Verb", "pinned": "v2"}],
        },
        {
            "id": "blob",
            "source": "",
            "upstream": "",
            "pinned": "unknown",
            "vendoring": "verbatim",
            "path": "src/blob.ogg",
            "manual_steps": "re-download by hand",
            "watch": [{"kind": "manual"}],
        },
    ]
}


class FakeClient:
    """Deterministic GitHub client for tests (no network)."""

    def __init__(self, releases=None, commits=None):
        self.releases = releases or {}
        self.commits = commits or {}

    def latest_release(self, repo):
        return self.releases.get(repo)

    def latest_file_commit(self, repo, ref, file):
        return self.commits.get((repo, ref, file))


class TestParseManifest(unittest.TestCase):
    def test_parses_artifacts_and_watches(self) -> None:
        artifacts = parse_manifest(_FIXTURE)
        self.assertEqual([a.id for a in artifacts], ["forked", "verb", "blob"])
        forked = artifacts[0]
        self.assertEqual(forked.vendoring, "fork")
        self.assertEqual(len(forked.watches), 2)
        self.assertEqual(forked.watches[0].kind, "github-file")
        self.assertEqual(forked.watches[1].role, "upstream-ref")

    def test_empty_document(self) -> None:
        self.assertEqual(parse_manifest({}), ())


class TestEvaluateWatch(unittest.TestCase):
    def setUp(self) -> None:
        self.artifact = Artifact("x", "", "", "p", "fork", "src/x", "steps", ())

    def test_release_up_to_date(self) -> None:
        w = Watch("github-release", "up/Thing", "", "", "1.0", "")
        r = evaluate_watch(self.artifact, w, FakeClient(releases={"up/Thing": "1.0"}))
        self.assertEqual(r.status, STATUS_UP_TO_DATE)

    def test_release_drifted(self) -> None:
        w = Watch("github-release", "up/Thing", "", "", "1.0", "")
        r = evaluate_watch(self.artifact, w, FakeClient(releases={"up/Thing": "2.0"}))
        self.assertEqual(r.status, STATUS_DRIFTED)
        self.assertEqual(r.latest, "2.0")

    def test_release_unresolved_is_error(self) -> None:
        w = Watch("github-release", "up/Gone", "", "", "1.0", "")
        r = evaluate_watch(self.artifact, w, FakeClient())
        self.assertEqual(r.status, STATUS_ERROR)

    def test_file_match_short_vs_full_sha(self) -> None:
        w = Watch("github-file", "VEAF/Thing", "master", "", "abc123", "")
        client = FakeClient(commits={("VEAF/Thing", "master", None): "abc123def456"})
        self.assertEqual(evaluate_watch(self.artifact, w, client).status, STATUS_UP_TO_DATE)

    def test_file_drifted(self) -> None:
        w = Watch("github-file", "VEAF/Thing", "master", "", "abc123", "")
        client = FakeClient(commits={("VEAF/Thing", "master", None): "ffffff0000"})
        self.assertEqual(evaluate_watch(self.artifact, w, client).status, STATUS_DRIFTED)

    def test_file_with_path(self) -> None:
        w = Watch("github-file", "r/R", "master", "sub/x.lua", "deadbeef", "")
        client = FakeClient(commits={("r/R", "master", "sub/x.lua"): "deadbeef99"})
        self.assertEqual(evaluate_watch(self.artifact, w, client).status, STATUS_UP_TO_DATE)

    def test_file_unresolved_is_error(self) -> None:
        w = Watch("github-file", "r/R", "master", "", "abc", "")
        self.assertEqual(evaluate_watch(self.artifact, w, FakeClient()).status, STATUS_ERROR)

    def test_manual(self) -> None:
        w = Watch("manual", "", "", "", "", "")
        self.assertEqual(evaluate_watch(self.artifact, w, FakeClient()).status, STATUS_MANUAL)

    def test_unknown_kind_is_error(self) -> None:
        w = Watch("weird", "r/R", "", "", "", "")
        self.assertEqual(evaluate_watch(self.artifact, w, FakeClient()).status, STATUS_ERROR)


class TestCheckArtifacts(unittest.TestCase):
    def test_aggregates_and_classifies(self) -> None:
        artifacts = parse_manifest(_FIXTURE)
        client = FakeClient(
            releases={"up/Thing": "9.9", "up/Verb": "v2"},  # up/Thing drifted, up/Verb current
            commits={("VEAF/Thing", "master", None): "abc123ff"},  # forked file current
        )
        report = check_artifacts(artifacts, client)
        self.assertEqual(len(report.results), 4)
        self.assertEqual([r.artifact_id for r in report.drifted], ["forked"])
        self.assertEqual([r.artifact_id for r in report.manual], ["blob"])
        self.assertEqual(report.errors, ())
        self.assertTrue(report.has_actionable)
        self.assertEqual(report.artifact("blob").manual_steps, "re-download by hand")

    def test_no_actionable(self) -> None:
        artifacts = parse_manifest(_FIXTURE)
        client = FakeClient(
            releases={"up/Thing": "1.0", "up/Verb": "v2"},
            commits={("VEAF/Thing", "master", None): "abc123"},
        )
        report = check_artifacts(artifacts, client)
        self.assertFalse(report.has_actionable)
        self.assertEqual(len(report.manual), 1)


if __name__ == "__main__":
    unittest.main()
