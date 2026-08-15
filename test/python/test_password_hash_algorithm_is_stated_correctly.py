"""What documents `password_hashes` must not call the digest SHA-256 (SECREV-2 / VMR-033).

`veafSecurity._checkPassword` hashes what the player types with `sha1.hex(password)`. A mission maker
who follows a page saying SHA-256 produces a hash that can **never** match — and believes access is
restricted while only the password shipped in this public repository still works.

This needs a gate rather than a correction, because it has already been corrected once and came back:
`MISSION_YAML_REFERENCE` carries a "SHA-1, not SHA-256" warning and `ROADMAP` announces the fix under
v6.12.0, while `mission.yaml`, the generator's template, the MCP action's docstring and **both** GUIDE
pages still said SHA-256. Declared done, half done.

Scope is the point, and it took three attempts to get right. Scanning whole files reported the
`published.zip` SHA256 **checksum** in both guides — a legitimate, unrelated use — and the continuation
lines of the multi-line warning. So the window is what matters: the lines immediately around each
`password_hashes` mention, where a reader actually looks for the algorithm.
"""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

_ROOT = Path(__file__).parents[2]

#: The settings whose documentation this polices.
_SETTINGS = ("password_hashes", "password_mm_hashes")

#: How far from a mention the algorithm may be stated: the description above, the example below.
_LINES_BEFORE = 2
_LINES_AFTER = 4

#: A SHA-1 mention this far back still covers a SHA-256 one — the multi-line "SHA-1, not SHA-256" note.
_WARNING_REACH = 4


def _files_documenting_the_settings() -> list[Path]:
    """Every tracked file under src/ or doc/ that mentions one of the settings."""
    result = subprocess.run(
        ["git", "grep", "-l", "-e", _SETTINGS[0], "--", "src/", "doc/"],
        cwd=_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return [_ROOT / line for line in result.stdout.splitlines() if line]


def _offending_lines(path: Path) -> list[int]:
    """Return the 1-based line numbers naming SHA-256 near a password-hash mention."""
    lines = path.read_text(encoding="utf-8").splitlines()
    near: set[int] = set()
    for index, line in enumerate(lines):
        if any(setting in line for setting in _SETTINGS):
            near.update(range(max(0, index - _LINES_BEFORE), min(len(lines), index + _LINES_AFTER + 1)))

    offenders = []
    for index in sorted(near):
        line = lines[index]
        if "SHA-256" not in line and "SHA256" not in line:
            continue
        context = lines[max(0, index - _WARNING_REACH) : index + 1]
        if any("SHA-1" in earlier for earlier in context):
            continue  # the warning itself: "SHA-1, not SHA-256"
        offenders.append(index + 1)
    return offenders


class TestThePasswordDigestIsNamedCorrectly(unittest.TestCase):
    def test_no_page_tells_a_mission_maker_to_use_sha256(self) -> None:
        offenders = [
            f"{path.relative_to(_ROOT).as_posix()}:{line}"
            for path in _files_documenting_the_settings()
            for line in _offending_lines(path)
        ]

        self.assertEqual(
            offenders,
            [],
            "veafSecurity compares sha1.hex(password), so a SHA-256 hash never matches:\n  " + "\n  ".join(offenders),
        )

    def test_the_scan_actually_finds_the_documentation(self) -> None:
        # Without this, a git-grep returning nothing would look exactly like a clean result — the
        # failure mode this ticket keeps running into.
        files = _files_documenting_the_settings()
        self.assertGreater(len(files), 4, f"expected several pages to document these settings, got {files}")
        names = {path.name for path in files}
        self.assertIn("mission.yaml", names, "the shipped default mission.yaml must be in scope")
        self.assertIn("GUIDE.md", names, "the French mission-maker guide must be in scope")

    def test_an_unrelated_sha256_checksum_is_not_reported(self) -> None:
        # Both guides mention the published.zip SHA256 checksum, far from the password section. A gate
        # that flagged those would be turned off within a week.
        sample = Path(self.enterContext(__import__("tempfile").TemporaryDirectory())) / "page.md"
        sample.write_text(
            "Downloads published.zip and verifies the SHA256 checksum.\n" * 5
            + '\nsecurity:\n  password_hashes:\n    - "<SHA-1 hash>"\n',
            encoding="utf-8",
        )

        self.assertEqual(_offending_lines(sample), [])

    def test_a_sha256_next_to_the_setting_is_reported(self) -> None:
        # Proving the gate refuses, on a file we write rather than on the tree it polices.
        sample = Path(self.enterContext(__import__("tempfile").TemporaryDirectory())) / "page.md"
        sample.write_text(
            'security:\n  password_hashes:   # SHA-256 hashes to restrict access\n    - "<hash>"\n',
            encoding="utf-8",
        )

        self.assertEqual(_offending_lines(sample), [2])


if __name__ == "__main__":
    unittest.main()
