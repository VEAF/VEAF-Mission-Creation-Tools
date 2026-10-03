"""The path gate that lets a filtered workflow be a required check.

A required check whose workflow never starts — because a pull request touches none of its trigger
paths — stays *Expected* for ever and the pull request can never merge. A job skipped by its own
``if:`` reports *Skipped*, which a required check accepts. So the filtering moves from the workflow
trigger into a job, and that job's decision is what is tested here.
"""

from __future__ import annotations

import unittest

from veaf_build.ci_path_gate import any_path_matches, path_matches


class TestPathMatches(unittest.TestCase):
    """GitHub's trigger-path glob: ``*`` stays inside one segment, ``**`` crosses them."""

    def test_a_double_star_covers_the_whole_subtree(self) -> None:
        self.assertTrue(path_matches("doc/mission-maker/concepts/spawnables.md", "doc/**"))
        self.assertTrue(path_matches("doc/index.md", "doc/**"))

    def test_a_double_star_does_not_reach_a_sibling_prefix(self) -> None:
        self.assertFalse(path_matches("docs/agents/x.md", "doc/**"))

    def test_a_single_star_stays_at_its_level(self) -> None:
        self.assertTrue(path_matches("CHANGELOG.md", "*.md"))
        self.assertFalse(path_matches("doc/index.md", "*.md"))

    def test_a_plain_path_matches_only_itself(self) -> None:
        self.assertTrue(path_matches("pyproject.toml", "pyproject.toml"))
        self.assertFalse(path_matches("services/support-bot/pyproject.toml", "pyproject.toml"))
        self.assertFalse(path_matches("pyproject.toml.bak", "pyproject.toml"))

    def test_regex_characters_in_a_pattern_are_literal(self) -> None:
        self.assertTrue(path_matches(".gitignore", ".gitignore"))
        self.assertFalse(path_matches("xgitignore", ".gitignore"))


class TestAnyPathMatches(unittest.TestCase):
    def test_one_matching_file_is_enough(self) -> None:
        self.assertTrue(any_path_matches([".github/workflows/sbom.yml", "doc/a.md"], ["doc/**"]))

    def test_a_pull_request_outside_every_pattern_does_not_run_the_gate(self) -> None:
        self.assertFalse(any_path_matches([".github/workflows/sbom.yml"], ["doc/**", "*.md"]))

    def test_no_changed_file_runs_nothing(self) -> None:
        self.assertFalse(any_path_matches([], ["doc/**"]))


if __name__ == "__main__":
    unittest.main()
