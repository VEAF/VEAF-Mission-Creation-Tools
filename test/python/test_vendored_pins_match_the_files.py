"""A vendored script that declares its own version must agree with the pin in `vendored.yaml`.

**Why this exists.** PR #746 (2026-08-15) updated the vendored `CTLD.lua` from `2.0.0-rc3` to
`2.0.0-rc7` and did not touch `vendored.yaml`. The pin stayed at rc3 for nine days, and nothing noticed
— including the drift watcher, whose whole job is to notice. Worse than silence: the watcher compares
against the pin, so it spent those nine days reporting rc4, rc5, rc6 and rc7 as *available updates* that
had in fact already been applied. A watcher whose alarms are known-wrong is a watcher nobody reads, and
then the real alarm is missed too.

**What this does not do.** Only a few of the eleven vendored artefacts declare a version this can read:
two are directories, and most of the rest are scripts with no machine-readable version at all. So this
is deliberately a table of named entries rather than a heuristic sweep. A heuristic was tried first and
rejected: matching "the pin appears somewhere in the file's version string" reported AIEN as consistent
because the digit `1` of `1.0 build 0154` occurs in its pin — a green light earned by accident, which is
the failure this test exists to prevent, one level up.

Adding an artefact here is cheap and worth doing whenever an upstream starts declaring its version.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "vendored.yaml"

#: artefact id -> the pattern reading the version the vendored file declares about itself.
#:
#: The group must capture exactly what `pinned:` holds, so the comparison is equality and not a
#: substring test. Where an upstream's own string and the pin cannot be made equal, leave the artefact
#: out rather than loosening the comparison.
SELF_DECLARED = {
    "ctld": re.compile(r'^ctld\.VERSION\s*=\s*"([^"]+)"', re.M),
    "csar": re.compile(r'^csar\.Version\s*=\s*"([^"]+)"', re.M),
}

#: Artefacts whose release tag and `pinned:` use the same numbering, so the tag must carry the pin.
#:
#: Not every artefact does. CSAR pins `2024.07.11.01-VEAF`, the date-version of the adapted file, while
#: watching ciribob's separate `1.9.x` release numbering — requiring those two to agree fails on a
#: perfectly correct manifest, which is what the first version of this test did.
WATCH_TAG_CARRIES_THE_PIN = ("ctld",)


def _artifacts() -> dict[str, dict]:
    """Return the manifest's artefacts, keyed by id."""
    manifest = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    return {entry["id"]: entry for entry in manifest["artifacts"] if entry.get("id")}


class TestVendoredPinsMatchTheFiles(unittest.TestCase):
    def setUp(self) -> None:
        self.artifacts = _artifacts()

    def test_the_manifest_is_readable_and_populated(self) -> None:
        """A check that silently reads nothing passes every assertion below."""
        self.assertGreater(len(self.artifacts), 5, "vendored.yaml holds far fewer artefacts than expected")

    def test_every_listed_artefact_still_exists(self) -> None:
        """The table names artefacts by id; a rename must fail here rather than skip silently."""
        for identifier in SELF_DECLARED:
            self.assertIn(identifier, self.artifacts, f"{identifier} is no longer in vendored.yaml")

    def test_the_pattern_still_finds_a_version(self) -> None:
        """An upstream that moves its version declaration must fail loudly, not quietly stop checking."""
        for identifier, pattern in SELF_DECLARED.items():
            path = ROOT / self.artifacts[identifier]["path"]
            self.assertTrue(path.is_file(), f"{identifier}: {path} is missing")
            text = path.read_text(encoding="utf-8", errors="replace")
            self.assertRegex(
                text,
                pattern,
                f"{identifier}: no version declaration found — the upstream moved it, so this test "
                f"stopped checking anything. Fix the pattern rather than deleting the entry.",
            )

    def test_the_pin_is_the_version_the_file_declares(self) -> None:
        """The check itself: what ships and what the manifest claims ships must be the same thing."""
        drift = []
        for identifier, pattern in SELF_DECLARED.items():
            entry = self.artifacts[identifier]
            text = (ROOT / entry["path"]).read_text(encoding="utf-8", errors="replace")
            match = pattern.search(text)
            if not match:
                continue  # reported by the test above
            declared, pinned = match.group(1), str(entry.get("pinned", ""))
            if declared != pinned:
                drift.append(f"{identifier}: the file declares {declared!r}, vendored.yaml pins {pinned!r}")

        self.assertEqual(
            drift,
            [],
            "vendored.yaml disagrees with the files it describes, so the drift watcher is comparing "
            "against the wrong baseline:\n  " + "\n  ".join(drift),
        )

    def test_a_release_watch_tag_carries_the_pinned_version(self) -> None:
        """The watch tag drifts independently of the pin, and it is the one the watcher actually reads.

        Both were stale in the CTLD case, and fixing only `pinned:` would have left the watcher wrong
        while making the manifest look right — the worst of the two states.
        """
        drift = []
        for identifier in WATCH_TAG_CARRIES_THE_PIN:
            entry = self.artifacts[identifier]
            pinned = str(entry.get("pinned", ""))
            tags = [
                str(watch.get("pinned", ""))
                for watch in entry.get("watch") or []
                if watch.get("kind") == "github-release"
            ]
            self.assertTrue(tags, f"{identifier}: no github-release watch left to check")
            for tag in tags:
                if pinned and pinned not in tag:
                    drift.append(f"{identifier}: watch tag {tag!r} does not contain the pinned {pinned!r}")

        self.assertEqual(
            drift,
            [],
            "a release watch is pinned to a different version than the artefact:\n  " + "\n  ".join(drift),
        )


if __name__ == "__main__":
    unittest.main()
