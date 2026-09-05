"""A gate must run whenever something its suite asserts on changes.

`Python Quality` filters on `paths:`, so a change outside that filter reads green off the Lua and
docs checks without pytest, ruff or mypy ever running. Measured 2026-09-01: PRs #877, #875 and #866
each merged that way, and #877 carried a stale backlog scope table that turned `develop` red on the
very test written to catch it.

The filter is therefore part of the gate, and it is checked here like any other assertion — for the
Python gate, and for `Support Bot`, whose suite reaches out of its own folder for the same kind of
repository-wide guard.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

import yaml

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"

# Read by the suite, so a change confined to one of these must run the job. The comment in each
# workflow names the test behind each entry; these lists are the enforcement.
PATHS_THE_PYTHON_SUITE_READS = (
    ".backlog/**",
    "src/scripts/**",
    "doc/**",
    "plugin/**",
    "*.md",
    # This very test reads the Support Bot workflow, so a change confined to that file must run the
    # Python gate — otherwise the assertions below never fire on the change they exist to catch.
    ".github/workflows/support-bot-ci.yml",
)

# `services/support-bot/tests/test_packaging.py` asserts on two files that live outside the service
# folder: the ROOT `.gitignore` (the only place the `.env` rule can live, since a nested `.gitignore`
# is itself ignored) and the ROOT `pyproject.toml` (read to prove the service version is *not* in the
# tools lockstep). Without them in the filter, a reshuffle of those lines would un-guard the
# service's secret with every check still green.
PATHS_THE_SUPPORT_BOT_SUITE_READS = (
    "services/support-bot/**",
    ".github/workflows/support-bot-ci.yml",
    ".gitignore",
    "pyproject.toml",
)


def _triggers(workflow: str) -> dict:
    """Return the ``on:`` section of a workflow, read as a string key.

    Args:
        workflow: File name of the workflow under ``.github/workflows/``.

    Returns:
        The parsed ``on:`` mapping.

    Raises:
        AssertionError: when the workflow file is missing.
    """
    path = WORKFLOWS / workflow
    assert path.is_file(), f"{path} is missing"
    # PyYAML resolves a bare `on:` to the boolean True (YAML 1.1), which is exactly the key this
    # test needs to read, so quote it before parsing rather than fighting the resolver.
    text = re.sub(r"^on:", '"on":', path.read_text(encoding="utf-8"), count=1, flags=re.MULTILINE)
    return yaml.safe_load(text)["on"]


class _GateFilterAssertions:
    """Shared assertions: a path the suite asserts on but does not trigger on is decorative.

    A plain mixin rather than a ``TestCase``: pytest collects every ``TestCase`` subclass in a
    module, name or no name, so a shared base would run its own assertions against nothing.
    """

    workflow = ""
    expected: tuple[str, ...] = ()

    def setUp(self) -> None:
        self.triggers = _triggers(self.workflow)

    def test_the_push_filter_covers_what_the_suite_reads(self) -> None:
        declared = self.triggers["push"]["paths"]

        for path in self.expected:
            self.assertIn(path, declared, f"a change under {path} would not run {self.workflow}")

    def test_push_and_pull_request_filters_are_identical(self) -> None:
        # GitHub Actions does not resolve YAML anchors, so the list is duplicated in the file. A
        # path added to one side only means the gate runs on `develop` but not on the PR that
        # introduced the change — the wrong way round.
        self.assertEqual(
            self.triggers["push"]["paths"],
            self.triggers["pull_request"]["paths"],
            f"the two path filters of {self.workflow} have drifted apart",
        )


class TestTheGateRunsForWhatItChecks(_GateFilterAssertions, unittest.TestCase):
    """`Python Quality` — the gate the 2026-09-01 measurement was taken on."""

    workflow = "python-quality.yml"
    expected = PATHS_THE_PYTHON_SUITE_READS


class TestTheSupportBotGateRunsForWhatItChecks(_GateFilterAssertions, unittest.TestCase):
    """`Support Bot` — same shape, and the stakes include a committed credential."""

    workflow = "support-bot-ci.yml"
    expected = PATHS_THE_SUPPORT_BOT_SUITE_READS


if __name__ == "__main__":
    unittest.main()
