"""CHORE-VERSION-AT-MERGE: the changelog carries an open `[Unreleased]` section.

A pull request adds its entry there and does not touch the version; the release commit renames the
heading and moves `pyproject.toml` with both agent manifests. That is what `.claude/commands/release.md`
has always described — but the section vanished with the 6.15.0 release and nobody noticed, so every PR
started minting its own version heading instead. Two concurrent PRs then conflicted by construction:
of the 10 merges following 6.16.0, 9 touched `CHANGELOG.md` and 8 touched the three version files.

These tests are cheap and they bite exactly where the process rotted: a release that forgets to
re-open the section, and a version that has no release entry behind it.
"""

from __future__ import annotations

import re
import tomllib
import unittest
from pathlib import Path

_UNRELEASED = "## [Unreleased]"


def _repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "pyproject.toml").is_file():
            return parent
    raise RuntimeError("repo root (with pyproject.toml) not found")


class TestChangelogProcess(unittest.TestCase):
    def setUp(self) -> None:
        self.root = _repo_root()
        self.changelog = (self.root / "CHANGELOG.md").read_text(encoding="utf-8")

    def test_an_unreleased_section_is_open(self) -> None:
        """Where every pull request writes. Its absence is what started the per-PR versioning."""
        self.assertIn(
            _UNRELEASED,
            self.changelog,
            "CHANGELOG.md has no `## [Unreleased]` section — a release must re-open one "
            "(see .claude/commands/release.md, step 4.2)",
        )

    def test_the_shipped_version_has_a_release_entry(self) -> None:
        """Ties the number to a documented release rather than to whichever PR merged last."""
        parsed = tomllib.loads((self.root / "pyproject.toml").read_text(encoding="utf-8"))
        version = parsed["tool"]["poetry"]["version"]
        self.assertRegex(
            self.changelog,
            rf"(?m)^## \[{re.escape(version)}\]",
            f"no `## [{version}]` heading matches the version in pyproject.toml",
        )

    def test_unreleased_comes_before_every_version_heading(self) -> None:
        """Newest first: an `[Unreleased]` buried under released versions would never be read."""
        first_version = re.search(r"^## \[\d+\.\d+\.\d+\]", self.changelog, re.MULTILINE)
        assert first_version is not None, "no version heading at all in CHANGELOG.md"
        self.assertLess(
            self.changelog.index(_UNRELEASED),
            first_version.start(),
            "`## [Unreleased]` must sit above the most recent released version",
        )


if __name__ == "__main__":
    unittest.main()
