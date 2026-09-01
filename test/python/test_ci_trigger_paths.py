"""The Python gate must run whenever something its suite asserts on changes.

`Python Quality` filters on `paths:`, so a change outside that filter reads green off the Lua and
docs checks without pytest, ruff or mypy ever running. Measured 2026-09-01: PRs #877, #875 and #866
each merged that way, and #877 carried a stale backlog scope table that turned `develop` red on the
very test written to catch it.

The filter is therefore part of the gate, and it is checked here like any other assertion.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

import yaml

WORKFLOW = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "python-quality.yml"

# Read by the suite, so a change confined to one of these must run the job. The comment in the
# workflow names the test behind each entry; this list is the enforcement.
PATHS_THE_SUITE_READS = (
    ".backlog/**",
    "src/scripts/**",
    "doc/**",
    "plugin/**",
    "*.md",
)


def _load() -> dict:
    """Return the workflow document, with ``on`` read as a string key.

    Raises:
        AssertionError: when the workflow file is missing.
    """
    assert WORKFLOW.is_file(), f"{WORKFLOW} is missing"
    # PyYAML resolves a bare `on:` to the boolean True (YAML 1.1), which is exactly the key this
    # test needs to read, so quote it before parsing rather than fighting the resolver.
    text = re.sub(r"^on:", '"on":', WORKFLOW.read_text(encoding="utf-8"), count=1, flags=re.MULTILINE)
    return yaml.safe_load(text)


class TestTheGateRunsForWhatItChecks(unittest.TestCase):
    """A path the suite asserts on but does not trigger on is a decorative assertion."""

    def setUp(self) -> None:
        self.triggers = _load()["on"]

    def test_the_push_filter_covers_what_the_suite_reads(self) -> None:
        declared = self.triggers["push"]["paths"]

        for path in PATHS_THE_SUITE_READS:
            self.assertIn(path, declared, f"a change under {path} would not run the Python gate")

    def test_push_and_pull_request_filters_are_identical(self) -> None:
        # GitHub Actions does not resolve YAML anchors, so the list is duplicated in the file. A
        # path added to one side only means the gate runs on `develop` but not on the PR that
        # introduced the change — the wrong way round.
        self.assertEqual(
            self.triggers["push"]["paths"],
            self.triggers["pull_request"]["paths"],
            "the two path filters have drifted apart",
        )


if __name__ == "__main__":
    unittest.main()
