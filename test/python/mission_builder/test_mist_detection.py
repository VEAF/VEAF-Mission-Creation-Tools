"""MiST is injected only for a mission whose own scripts call it — DROP-MIST ticket 08.

VEAF used to inject MiST into every mission because its own scripts called it. They no longer do,
and neither does any community script shipped here, so MiST became opt-in. The risk that creates is
a silent one: a mission maker's script that calls MiST keeps building without a word and dies in DCS
with ``attempt to index nil (global 'mist')``, from inside a third-party file. These tests cover the
scan that closes it, including what the scan deliberately does *not* see.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.mission_constants import mission_scripts_referencing_mist


def _scripts_dir(root: Path) -> Path:
    scripts = root / "src" / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    return scripts


class TestMistDetectedInMissionScripts(unittest.TestCase):
    """What the scan finds."""

    def test_a_call_is_found(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "myScript.lua").write_text("local n = mist.utils.round(3.7)\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["myScript.lua"])

    def test_every_caller_is_named_not_just_the_first(self) -> None:
        """The log line names them, so a mission maker knows what is pulling MiST in."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "alpha.lua").write_text("mist.scheduleFunction(f, {}, 1)\n", encoding="utf-8")
            (scripts / "bravo.lua").write_text("local h = mist.getHeading(u)\n", encoding="utf-8")
            (scripts / "charlie.lua").write_text("-- nothing here\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["alpha.lua", "bravo.lua"])

    def test_a_file_is_listed_once_however_many_calls_it_makes(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "busy.lua").write_text(
                "mist.utils.round(1)\nmist.utils.round(2)\nmist.vec.mag(v)\n", encoding="utf-8"
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["busy.lua"])

    def test_a_real_third_party_script_is_found(self) -> None:
        """The shape that actually matters: HoundElint, which ten VEAF missions load."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "HoundElint.lua").write_text(
                "if not mist or mist.majorVersion < 4 then return end\n"
                "for name in pairs(mist.DBs.humansByName) do print(name) end\n",
                encoding="utf-8",
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["HoundElint.lua"])


class TestWhatTheScanIgnores(unittest.TestCase):
    """A false positive costs 336 KB in a mission that does not need it."""

    def test_a_comment_is_not_a_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "documented.lua").write_text(
                "-- this used to call mist.utils.round, ported in 2026\nlocal n = veaf.round(3.7)\n",
                encoding="utf-8",
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_mention_inside_a_string_is_not_a_call(self) -> None:
        """CTLD carries an error message naming mist.DBs.MEgroupsByName, and counting it as a call
        is exactly how an earlier pass reported CTLD as still needing MiST when it has not since v2.
        """
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "chatty.lua").write_text('log("group not found in mist.DBs.MEgroupsByName")\n', encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_word_ending_in_mist_is_not_mist(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "naming.lua").write_text("local x = chemist.brew()\nlocal y = a.mist.z\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_missing_folder_is_not_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            self.assertEqual(mission_scripts_referencing_mist(Path(td) / "no" / "such" / "folder"), [])

    def test_a_folder_with_no_lua_finds_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "notes.txt").write_text("mist.utils.round\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_trailing_comment_is_not_a_call(self) -> None:
        """Only a line *starting* with -- was skipped at first; a comment can also follow code."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "trailing.lua").write_text(
                "local n = veaf.round(3.7)  -- was mist.utils.round before the port\n", encoding="utf-8"
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_block_comment_is_not_a_call(self) -> None:
        """A block comment spans lines, which a line-by-line scan cannot see past."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "blocky.lua").write_text(
                "--[[\nThis used to read:\n  mist.utils.round(x)\n]]\nlocal n = veaf.round(3.7)\n",
                encoding="utf-8",
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_a_long_bracket_string_is_not_a_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "longstr.lua").write_text(
                "local help = [==[\ncall mist.utils.round to round a number\n]==]\n", encoding="utf-8"
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])

    def test_an_escaped_quote_does_not_end_the_string_early(self) -> None:
        """With naive quote matching the string closes at the escaped quote, and what follows —
        including a mention of MiST — is read as code."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "escaped.lua").write_text(
                'log("he said \\"use mist.utils.round\\" and left")\n', encoding="utf-8"
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), [])


class TestTheCallsThatAlmostGotAway(unittest.TestCase):
    """Legal Lua the first version of the scan did not recognise.

    These are the dangerous direction: a missed call means a mission built without MiST that dies in
    DCS. Found by review on #847, not by the tests, which is the point of writing them now.
    """

    def test_whitespace_around_the_dot_is_still_a_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "spaced.lua").write_text("local n = mist . utils.round(3.7)\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["spaced.lua"])

    def test_a_newline_around_the_dot_is_still_a_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "wrapped.lua").write_text("local n = mist\n  .utils.round(3.7)\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["wrapped.lua"])

    def test_an_underscore_member_is_still_a_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "under.lua").write_text("mist._helper(unit)\n", encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["under.lua"])

    def test_a_call_after_a_block_comment_is_still_seen(self) -> None:
        """Removing the comment must not swallow the code that follows it."""
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "after.lua").write_text(
                "--[[ a note\nspanning lines\n]]\nmist.utils.round(3.7)\n", encoding="utf-8"
            )

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["after.lua"])

    def test_a_call_after_a_string_is_still_seen(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            scripts = _scripts_dir(Path(td))
            (scripts / "mixed.lua").write_text('log("nothing to see here")\nmist.utils.round(3.7)\n', encoding="utf-8")

            self.assertEqual(mission_scripts_referencing_mist(scripts), ["mixed.lua"])


class TestTheBuilderActsOnIt(unittest.TestCase):
    """The scan is only worth anything if the build reads it — the wiring, not the helper."""

    def _worker(self, root: Path, yaml_content: str = "") -> MissionBuilderWorker:
        (root / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=root,
            output_mission=root / "out.miz",
            dynamic_mode=None,
        )

    def test_the_modules_block_can_ask_for_mist(self) -> None:
        """The escape hatch, in the form mission makers actually write.

        `modules:` is the current section; `community_scripts:` is the deprecated one. A test that
        only covers the deprecated spelling proves the hatch works where nobody looks for it.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _scripts_dir(root)

            worker = self._worker(root, "modules:\n  MIST: true\n")

            self.assertIn("mist", [s["id"] for s in worker._active_community_scripts()])
            self.assertTrue(worker._community_enabled("mist"))

    def test_a_bare_mist_entry_no_longer_asks_for_it(self) -> None:
        """`MIST:` with no value used to mean "mandatory module, always on", and every v6
        mission.yaml shipped with that line. It now means "not asked for", so those missions stop
        carrying MiST — which is the point, and is safe because a mission whose scripts call it is
        caught by the scan instead.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _scripts_dir(root)

            worker = self._worker(root, "modules:\n  MIST:\n  RADIO: true\n")

            self.assertNotIn("mist", [s["id"] for s in worker._active_community_scripts()])
            self.assertFalse(worker._community_enabled("mist"))

    def test_a_bare_mist_entry_still_yields_to_the_scan(self) -> None:
        """The migration case that must not break: an existing mission.yaml carrying `MIST:` and a
        script that calls MiST keeps working, without anyone editing the yaml.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "HoundElint.lua").write_text(
                "for n in pairs(mist.DBs.humansByName) do print(n) end\n", encoding="utf-8"
            )

            worker = self._worker(root, "modules:\n  MIST:\n  RADIO: true\n")

            self.assertEqual(worker.mist_callers, ["HoundElint.lua"])
            self.assertIn("mist", [s["id"] for s in worker._active_community_scripts()])

    def test_a_mission_calling_mist_gets_it_injected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "myScript.lua").write_text("mist.utils.round(1)\n", encoding="utf-8")

            worker = self._worker(root)

            self.assertEqual(worker.mist_callers, ["myScript.lua"])
            self.assertIn("mist", [s["id"] for s in worker._active_community_scripts()])
            self.assertTrue(worker._community_enabled("mist"))

    def test_a_mission_not_calling_mist_does_not(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "myScript.lua").write_text("veaf.round(1)\n", encoding="utf-8")

            worker = self._worker(root)

            self.assertEqual(worker.mist_callers, [])
            self.assertNotIn("mist", [s["id"] for s in worker._active_community_scripts()])
            self.assertFalse(worker._community_enabled("mist"))

    def test_detection_overrides_an_explicit_disable(self) -> None:
        """Whoever wrote `MIST: false` did not write the script that calls it. Breaking the mission
        to honour the flag would be obeying the letter against the intent — and the failure would
        land in DCS, not here.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "myScript.lua").write_text("mist.utils.round(1)\n", encoding="utf-8")

            worker = self._worker(root, "community_scripts:\n  mist: false\n")

            self.assertIn("mist", [s["id"] for s in worker._active_community_scripts()])
            self.assertTrue(worker._community_enabled("mist"))

    def test_the_two_answers_agree(self) -> None:
        """_active_community_scripts packages the file and _community_enabled tells the runtime it is
        there. A build that packaged MiST while declaring it disabled would be its own bug.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "myScript.lua").write_text("mist.utils.round(1)\n", encoding="utf-8")

            worker = self._worker(root, "community_scripts:\n  mist: false\n")
            packaged = "mist" in [s["id"] for s in worker._active_community_scripts()]

            self.assertEqual(packaged, worker._community_enabled("mist"))

    def test_mist_is_not_added_twice_when_asked_for_and_detected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (_scripts_dir(root) / "myScript.lua").write_text("mist.utils.round(1)\n", encoding="utf-8")

            worker = self._worker(root, "community_scripts:\n  mist: true\n")
            ids = [s["id"] for s in worker._active_community_scripts()]

            self.assertEqual(ids.count("mist"), 1)


if __name__ == "__main__":
    unittest.main()
