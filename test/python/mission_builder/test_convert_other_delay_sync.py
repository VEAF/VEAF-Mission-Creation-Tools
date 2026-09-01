"""`--update` writes the upstream load staging into `mission.yaml` — ticket 03 of
FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.

The five VEAF Foothold missions carried **no** ``delay_seconds`` at all: the option landed
2026-08-11, they were adopted 2026-07-28, and ``--update`` preserves a tuned ``mission.yaml``. So
the staging was never written into any of them, and AIEN loaded at t=0 in all five from the day
they shipped — against the one thing ``FOOTHOLD.md`` warns is silent, since it inventories ground
groups once, before Foothold's scheduled tasks have created them.

The detection already existed (``_delay_changes``) and produced six lines per mission; they went
into ``manual_review``, which nothing printed. Ticket 02 makes them visible, this one makes them
unnecessary: David chose "the tool writes them itself, and the report says which".

Writing into a file the mode promises to preserve is the risk, so half of these tests are about
what must **not** change: byte content elsewhere, line endings, and a script the maker added.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.other_converter import OtherMissionConverter
from upstream_miz import make_upstream_miz

STAGED = (
    ("Foothold Config.lua", None),
    ("Foothold CTLD.lua", 3.0),
    ("AIEN.lua", 12.0),
)


def _adopt_without_any_delay(root: Path) -> tuple[OtherMissionConverter, Path]:
    """Adopt a release, then strip every `delay_seconds` — the state the five missions were in."""
    mission = root / "VEAF-Foothold-Caucasus"
    converter = OtherMissionConverter(version="test")
    converter.convert(make_upstream_miz(STAGED, folder=root / "4.6.0"), mission, profile_name="foothold")

    yaml_path = mission / "mission.yaml"
    kept = [
        line for line in yaml_path.read_text(encoding="utf-8").splitlines(keepends=True) if "delay_seconds" not in line
    ]
    yaml_path.write_text("".join(kept), encoding="utf-8")
    return converter, mission


def _scripts_block(yaml_text: str) -> list[str]:
    """The `custom_scripts:` lines, stripped, for readable assertions."""
    start = yaml_text.index("custom_scripts:")
    end = yaml_text.index("\n\n", start)
    return [line.strip() for line in yaml_text[start:end].splitlines()]


class TestTheStagingIsWritten(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.converter, self.mission = _adopt_without_any_delay(self.root)
        self.yaml_path = self.mission / "mission.yaml"

    def _refresh(self, scripts=STAGED):
        fresh = make_upstream_miz(scripts, folder=self.root / "4.7.0")
        return self.converter.convert(fresh, self.mission, profile_name="foothold", update=True)

    def test_a_mission_with_no_delays_at_all_ends_up_staged(self) -> None:
        self._refresh()

        block = _scripts_block(self.yaml_path.read_text(encoding="utf-8"))
        self.assertIn("delay_seconds: 12", block, "AIEN must be staged — this is the whole point")
        self.assertIn("delay_seconds: 3", block)

    def test_the_delay_lands_under_its_own_script(self) -> None:
        self._refresh()

        block = _scripts_block(self.yaml_path.read_text(encoding="utf-8"))
        self.assertEqual(
            block[block.index("- path: src/scripts/AIEN.lua") + 1],
            "delay_seconds: 12",
            "a delay written under the wrong script would stage the wrong one",
        )

    def test_a_delay_that_moved_upstream_is_updated(self) -> None:
        self._refresh()
        # Persian Gulf stages AIEN at 15 s where the others use 12 s, so a map moving is real.
        self._refresh((("Foothold Config.lua", None), ("Foothold CTLD.lua", 3.0), ("AIEN.lua", 15.0)))

        block = _scripts_block(self.yaml_path.read_text(encoding="utf-8"))
        self.assertIn("delay_seconds: 15", block)
        self.assertNotIn("delay_seconds: 12", block)

    def test_a_delay_upstream_dropped_is_dropped_here(self) -> None:
        self._refresh()
        self._refresh((("Foothold Config.lua", None), ("Foothold CTLD.lua", 3.0), ("AIEN.lua", None)))

        block = _scripts_block(self.yaml_path.read_text(encoding="utf-8"))
        self.assertNotIn("delay_seconds: 12", block, "upstream stopped staging it, so neither do we")
        self.assertIn("- path: src/scripts/AIEN.lua", block, "the script itself stays")

    def test_the_report_names_every_delay_written(self) -> None:
        # An edit to a preserved file that the report does not mention is the silent failure this
        # lot is about, in a new costume.
        markdown = self._refresh().to_markdown()

        # The delay has to be read off the line that names the script. Searching the whole
        # document for "12" also matches the timestamp the report stamps on itself, so such an
        # assertion passes twelve minutes past every hour whatever the delay actually says.
        line = next(line for line in markdown.splitlines() if "AIEN.lua" in line)
        self.assertIn("12", line, "the report states the delay it wrote for that script")

    def test_a_second_refresh_against_the_same_release_writes_nothing(self) -> None:
        self._refresh()
        before = self.yaml_path.read_bytes()

        self._refresh()

        self.assertEqual(self.yaml_path.read_bytes(), before, "an idempotent refresh must not rewrite the file")


class TestNothingElseInTheFileMoves(unittest.TestCase):
    """`--update` promises to preserve the tuned file; the delays are the only licence taken."""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.converter, self.mission = _adopt_without_any_delay(self.root)
        self.yaml_path = self.mission / "mission.yaml"

    def test_only_delay_lines_are_added(self) -> None:
        before = self.yaml_path.read_text(encoding="utf-8").splitlines()

        self.converter.convert(
            make_upstream_miz(STAGED, folder=self.root / "4.7.0"), self.mission, profile_name="foothold", update=True
        )

        after = self.yaml_path.read_text(encoding="utf-8").splitlines()
        self.assertEqual(
            [line for line in after if "delay_seconds" not in line],
            before,
            "every other line must survive byte for byte, comments and blank lines included",
        )

    def test_crlf_endings_survive(self) -> None:
        # The batch normalises mission.yaml to CRLF, and a second rewriter flipping it back turned
        # a 6-line diff into a 254-line one on the one mission whose file was LF.
        raw = self.yaml_path.read_text(encoding="utf-8", newline="")
        with open(self.yaml_path, "w", encoding="utf-8", newline="") as handle:
            handle.write(raw.replace("\r\n", "\n").replace("\n", "\r\n"))

        self.converter.convert(
            make_upstream_miz(STAGED, folder=self.root / "4.7.0"), self.mission, profile_name="foothold", update=True
        )

        written = self.yaml_path.read_bytes()
        self.assertNotIn(b"\r\r\n", written, "no doubled carriage returns")
        self.assertEqual(written.count(b"\n"), written.count(b"\r\n"), "every line must still end CRLF")

    def test_the_other_lists_in_the_file_are_not_touched(self) -> None:
        # `strip_native_triggers:` sits right under `custom_scripts:` and is a list of its own.
        # An edit walking the whole file instead of that one block would corrupt it silently.
        before = [line for line in self.yaml_path.read_text(encoding="utf-8").splitlines() if "ScriptLoader" in line]
        self.assertTrue(before, "the scaffold lists the native loader triggers")

        self.converter.convert(
            make_upstream_miz(STAGED, folder=self.root / "4.7.0"), self.mission, profile_name="foothold", update=True
        )

        after = [line for line in self.yaml_path.read_text(encoding="utf-8").splitlines() if "ScriptLoader" in line]
        self.assertEqual(after, before)

    def test_a_script_the_maker_added_keeps_its_own_delay(self) -> None:
        # Upstream knows nothing about it, so the sync has nothing to say about it either.
        text = self.yaml_path.read_text(encoding="utf-8")
        self.yaml_path.write_text(
            text.replace(
                "    - path: src/scripts/AIEN.lua",
                "    - path: src/scripts/myOwnStuff.lua\n      delay_seconds: 42\n    - path: src/scripts/AIEN.lua",
            ),
            encoding="utf-8",
        )
        (self.mission / "src" / "scripts" / "myOwnStuff.lua").write_text("-- mine\n", encoding="utf-8")

        self.converter.convert(
            make_upstream_miz(STAGED, folder=self.root / "4.7.0"), self.mission, profile_name="foothold", update=True
        )

        self.assertIn("delay_seconds: 42", _scripts_block(self.yaml_path.read_text(encoding="utf-8")))


if __name__ == "__main__":
    unittest.main()
