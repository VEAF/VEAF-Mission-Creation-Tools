"""A gate must run whenever something its suite asserts on changes.

`Python Quality` filters on `paths:`, so a change outside that filter reads green off the Lua and
docs checks without pytest, ruff or mypy ever running. Measured 2026-09-01: PRs #877, #875 and #866
each merged that way, and #877 carried a stale backlog scope table that turned `develop` red on the
very test written to catch it.

The filter is therefore part of the gate, and it is checked here like any other assertion — for the
Python gate, for `Support Bot`, whose suite reaches out of its own folder for the same kind of
repository-wide guard, and for `Docs Check`.

Their checks are *required* on `develop` (2026-10-03), which moved the pull-request filter out of
the trigger and into a `changes` job (`veaf_build/ci_path_gate.py`): a required check whose workflow
never starts waits as "Expected" for ever, while a job skipped by its `if:` reports "Skipped".
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
    # `tests/test_doc_pages.py` rebuilds the bot's page index from the real `doc/` tree and compares
    # it to the checked-in one. A page renamed or retitled without this in the filter would leave
    # the bot citing a title that no longer exists, with every check green.
    "doc/**",
)

# `veaf_build/docs_check.py` walks every markdown file, and checks that the MCP actions and the
# shortcuts are named by their reference pages (TOOLING-REPO-LINK-GATE, TOOLING-DOC-AUTOGEN).
PATHS_THE_DOCS_CHECK_READS = (
    "doc/**",
    "mkdocs.yml",
    ".backlog/**",
    "docs/**",
    "*.md",
    "src/python/veaf-tools/veaf_mission_mcp/**",
    "src/scripts/veaf/veafShortcuts.lua",
)


def _workflow(workflow: str) -> dict:
    """Return a parsed workflow, with its ``on:`` section under a string key.

    Args:
        workflow: File name of the workflow under ``.github/workflows/``.

    Returns:
        The parsed workflow.

    Raises:
        AssertionError: when the workflow file is missing.
    """
    path = WORKFLOWS / workflow
    assert path.is_file(), f"{path} is missing"
    # PyYAML resolves a bare `on:` to the boolean True (YAML 1.1), which is exactly the key this
    # test needs to read, so quote it before parsing rather than fighting the resolver.
    text = re.sub(r"^on:", '"on":', path.read_text(encoding="utf-8"), count=1, flags=re.MULTILINE)
    return yaml.safe_load(text)


def _gate_paths(workflow: dict) -> list[str]:
    """Return the patterns the ``changes`` job filters pull requests on.

    Args:
        workflow: A parsed workflow.

    Returns:
        The ``GATE_PATHS`` lines of the job's ``gate`` step.
    """
    steps = workflow["jobs"]["changes"]["steps"]
    gate = next(step for step in steps if step.get("id") == "gate")
    return [line.strip() for line in gate["env"]["GATE_PATHS"].splitlines() if line.strip()]


def _depends_on(jobs: dict, name: str, target: str) -> bool:
    """Tell whether job *name* waits for *target*, directly or through another job.

    Args:
        jobs: The workflow's ``jobs`` mapping.
        name: The job to check.
        target: The job it must wait for.

    Returns:
        True when *target* is reachable through ``needs``.
    """
    needs = jobs[name].get("needs", [])
    needs = [needs] if isinstance(needs, str) else needs
    return target in needs or any(_depends_on(jobs, need, target) for need in needs)


class _GateFilterAssertions:
    """Shared assertions: a path the suite asserts on but does not trigger on is decorative.

    The checks these workflows own are *required* on `develop`. A required check whose workflow
    never starts stays "Expected" for ever, so pull requests are not filtered at the trigger: a
    `changes` job filters them, and a job it skips reports "Skipped", which a required check
    accepts.

    A plain mixin rather than a ``TestCase``: pytest collects every ``TestCase`` subclass in a
    module, name or no name, so a shared base would run its own assertions against nothing.
    """

    workflow = ""
    expected: tuple[str, ...] = ()

    def setUp(self) -> None:
        self.parsed = _workflow(self.workflow)
        self.triggers = self.parsed["on"]

    def test_the_gate_covers_what_the_suite_reads(self) -> None:
        declared = _gate_paths(self.parsed)

        for path in self.expected:
            self.assertIn(path, declared, f"a pull request under {path} would not run {self.workflow}")

    def test_push_and_gate_filters_are_identical(self) -> None:
        # GitHub Actions does not resolve YAML anchors, so the list is duplicated in the file. A
        # path added to one side only means the gate runs on `develop` but not on the PR that
        # introduced the change — the wrong way round.
        push_paths = (self.triggers["push"] or {}).get("paths")
        if push_paths is None:
            self.skipTest(f"{self.workflow} runs on every push")
        self.assertEqual(
            push_paths, _gate_paths(self.parsed), f"the two path filters of {self.workflow} have drifted apart"
        )

    def test_every_pull_request_starts_the_workflow(self) -> None:
        self.assertIn("pull_request", self.triggers)
        self.assertFalse(
            (self.triggers["pull_request"] or {}).get("paths"),
            f"{self.workflow} filters pull requests at the trigger: a required check would wait for ever",
        )

    def test_a_failing_gate_runs_the_checks_rather_than_skipping_them(self) -> None:
        # A skipped job reads as a pass to a required check, so a gate that crashed (empty output)
        # must not skip anything: only an explicit `run=false` may.
        jobs = self.parsed["jobs"]
        for name, job in jobs.items():
            needs = job.get("needs", [])
            if "changes" in ([needs] if isinstance(needs, str) else needs):
                condition = str(job.get("if", ""))
                self.assertIn("!cancelled()", condition, f"{self.workflow}: {name} is skipped when the gate fails")
                self.assertIn("needs.changes.outputs.run != 'false'", condition, f"{self.workflow}: {name}")

    def test_every_job_waits_for_the_gate(self) -> None:
        jobs = self.parsed["jobs"]
        for name in jobs:
            if name != "changes":
                self.assertTrue(_depends_on(jobs, name, "changes"), f"{self.workflow}: {name} ignores the gate")


class TestTheGateRunsForWhatItChecks(_GateFilterAssertions, unittest.TestCase):
    """`Python Quality` — the gate the 2026-09-01 measurement was taken on."""

    workflow = "python-quality.yml"
    expected = PATHS_THE_PYTHON_SUITE_READS


class TestTheSupportBotGateRunsForWhatItChecks(_GateFilterAssertions, unittest.TestCase):
    """`Support Bot` — same shape, and the stakes include a committed credential."""

    workflow = "support-bot-ci.yml"
    expected = PATHS_THE_SUPPORT_BOT_SUITE_READS


class TestTheDocsGateRunsForWhatItChecks(_GateFilterAssertions, unittest.TestCase):
    """`Docs Check` — runs on every push, so only its pull-request gate carries a list."""

    workflow = "docs-check.yml"
    expected = PATHS_THE_DOCS_CHECK_READS


if __name__ == "__main__":
    unittest.main()
