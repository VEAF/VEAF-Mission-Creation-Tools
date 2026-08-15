"""SECREV-2 / VMR-062 — a corrupt source mission reported itself as an absent one.

`_read_source_mission` returned `None` both when `src/mission/mission` is missing and when it is
present but fails to parse, and the caller turns `None` into the *"not found"* warning. So a mission
table the parser chokes on silently disabled the group / preset / waypoint / TUM reference checks
while telling the mission maker the file was not there — the one message guaranteed to send them
looking in the wrong place.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_libs.mission_validator import validate_mission_folder


def _folder(mission_text: str | None) -> Path:
    folder = Path(tempfile.mkdtemp())
    (folder / "mission.yaml").write_text("mission:\n  name: test\n", encoding="utf-8")
    if mission_text is not None:
        (folder / "src" / "mission").mkdir(parents=True)
        (folder / "src" / "mission" / "mission").write_text(mission_text, encoding="utf-8")
    return folder


def _messages(folder: Path) -> list[str]:
    return [issue.message for issue in validate_mission_folder(folder)]


class TestSourceMissionDiagnosis(unittest.TestCase):
    def test_an_absent_mission_says_it_is_absent(self) -> None:
        messages = _messages(_folder(None))
        self.assertTrue(
            any("not found" in m or "introuvable" in m for m in messages),
            f"expected a not-found warning, got {messages}",
        )

    def test_an_unparseable_mission_is_not_reported_as_absent(self) -> None:
        # Both locales, because the default here is French: matching only the English wording
        # made this test pass against the very message it was meant to reject.
        messages = _messages(_folder("mission = { this is not lua"))
        self.assertFalse(
            any("not found" in m or "introuvable" in m for m in messages),
            f"a file that exists must not be reported as missing: {messages}",
        )

    def test_an_unparseable_mission_says_it_could_not_be_read(self) -> None:
        messages = _messages(_folder("mission = { this is not lua"))
        self.assertTrue(
            any("parse" in m.lower() or "lire" in m.lower() or "lisible" in m.lower() for m in messages),
            f"expected the parse failure to be named, got {messages}",
        )

    def test_a_readable_mission_produces_neither_message(self) -> None:
        # The control: a mission that parses must not trip either diagnostic, otherwise the two
        # tests above would pass on a validator that always complains.
        messages = _messages(_folder('mission = { ["coalition"] = {}, }'))
        self.assertFalse(
            any("introuvable" in m or "not found" in m or "lisible" in m or "parse" in m.lower() for m in messages),
            f"a parseable mission tripped a source-mission diagnostic: {messages}",
        )


if __name__ == "__main__":
    unittest.main()
