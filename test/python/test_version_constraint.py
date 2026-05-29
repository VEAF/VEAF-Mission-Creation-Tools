"""Tests for version_matches_constraint (from veaf-tools-updater)."""

from __future__ import annotations

import unittest


# Copy of the two pure functions from veaf-tools-updater.py (no deps)
def parse_version_parts(version: str) -> list[int]:
    return [int(x) for x in version.split(".")]


def version_matches_constraint(release_version: str, constraint: str) -> bool:
    try:
        rel = parse_version_parts(release_version)

        if constraint.startswith("^"):
            pin = parse_version_parts(constraint[1:])
            pin_padded = pin + [0] * (3 - len(pin))
            rel_padded = rel + [0] * (3 - len(rel))
            return rel_padded[0] == pin_padded[0] and rel_padded >= pin_padded

        if constraint.startswith("~"):
            pin = parse_version_parts(constraint[1:])
            pin_padded = pin + [0] * (3 - len(pin))
            rel_padded = rel + [0] * (3 - len(rel))
            return rel_padded[0] == pin_padded[0] and rel_padded[1] == pin_padded[1] and rel_padded >= pin_padded

        pin = parse_version_parts(constraint)
        return rel[: len(pin)] == pin

    except ValueError:
        return False


class TestPrefixMatch(unittest.TestCase):
    def test_major_prefix(self) -> None:
        self.assertTrue(version_matches_constraint("6.1.3", "6"))
        self.assertTrue(version_matches_constraint("6.0.0", "6"))
        self.assertFalse(version_matches_constraint("7.0.0", "6"))

    def test_major_minor_prefix(self) -> None:
        self.assertTrue(version_matches_constraint("6.1.0", "6.1"))
        self.assertTrue(version_matches_constraint("6.1.99", "6.1"))
        self.assertFalse(version_matches_constraint("6.2.0", "6.1"))

    def test_exact(self) -> None:
        self.assertTrue(version_matches_constraint("6.1.3", "6.1.3"))
        self.assertFalse(version_matches_constraint("6.1.4", "6.1.3"))


class TestCaretRange(unittest.TestCase):
    def test_same_major_newer(self) -> None:
        self.assertTrue(version_matches_constraint("6.1.3", "^6.1.3"))
        self.assertTrue(version_matches_constraint("6.9.9", "^6.1.3"))

    def test_same_major_older(self) -> None:
        self.assertFalse(version_matches_constraint("6.1.2", "^6.1.3"))

    def test_different_major(self) -> None:
        self.assertFalse(version_matches_constraint("7.0.0", "^6.1.3"))


class TestTildeRange(unittest.TestCase):
    def test_same_major_minor_newer(self) -> None:
        self.assertTrue(version_matches_constraint("6.1.3", "~6.1.3"))
        self.assertTrue(version_matches_constraint("6.1.99", "~6.1.3"))

    def test_same_major_minor_older(self) -> None:
        self.assertFalse(version_matches_constraint("6.1.2", "~6.1.3"))

    def test_different_minor(self) -> None:
        self.assertFalse(version_matches_constraint("6.2.0", "~6.1.3"))


if __name__ == "__main__":
    unittest.main()
