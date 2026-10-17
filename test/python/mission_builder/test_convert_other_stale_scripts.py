"""A refresh must not leave the previous release's script behind — ticket 01 of
FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.

Lekaa renamed Syria's setup script between 4.6 and 4.7 (``footholdSyriaSetup.lua`` →
``…Setupv2.lua``). ``--update`` added the new one and **kept** the old, which ``mission.yaml``
still pointed at — so ``validate`` passed and the build embedded the previous release's setup
over 4.7.0 data. It was caught by comparing the archive with the folder by hand.

The hard half is telling that script apart from one the mission maker wrote themselves. Both sit
in ``src/scripts/``, both are listed in ``custom_scripts:``, and neither is in the fresh upstream
set — the three tests the ticket proposed as the distinction. What separates them is whether the
*previous* release shipped the file, which nothing recorded, so the converter now writes down what
each release loads. A folder converted before that manifest existed reads it from the
``mapResource`` of the base the previous release left, and deletes nothing when neither exists:
the tests below pin that too, since a wrong deletion eats somebody's work.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from mission_builder.other_converter import OtherMissionConverter
from upstream_miz import make_upstream_miz
from veaf_libs.mission_validator import ERROR, validate_mission_folder

RELEASE_4_6 = (
    ("Foothold Config.lua", None),
    ("footholdSyriaSetup.lua", None),
    ("AIEN.lua", 12.0),
)
RELEASE_4_7 = (
    ("Foothold Config.lua", None),
    ("footholdSyriaSetupv2.lua", None),
    ("AIEN.lua", 12.0),
)


class TestStaleUpstreamScriptIsRemoved(unittest.TestCase):
    """The real shape: same mission, one script renamed between two releases."""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.mission = self.root / "VEAF-Foothold-Syria"
        self.converter = OtherMissionConverter(version="test")
        old = make_upstream_miz(RELEASE_4_6, folder=self.root / "4.6.0", name="Foothold_SY_4.6.0.miz")
        self.converter.convert(old, self.mission, profile_name="foothold")

    def _refresh(self):
        new = make_upstream_miz(RELEASE_4_7, folder=self.root / "4.7.0", name="Foothold_SY_4.7.0.miz")
        return self.converter.convert(new, self.mission, profile_name="foothold", update=True)

    def test_the_dropped_script_no_longer_sits_in_the_folder(self) -> None:
        self._refresh()

        stale = self.mission / "src" / "scripts" / "footholdSyriaSetup.lua"
        self.assertFalse(stale.exists(), "the release stopped shipping it, so the build must not find it")

    def test_the_replacement_is_there(self) -> None:
        self._refresh()

        self.assertTrue((self.mission / "src" / "scripts" / "footholdSyriaSetupv2.lua").is_file())

    def test_the_report_names_it(self) -> None:
        # Removing a file silently would be its own version of this lot's defect.
        self.assertIn("footholdSyriaSetup.lua", self._refresh().to_markdown())

    def test_custom_scripts_loads_the_replacement_instead(self) -> None:
        # The entry used to stay and fail `validate`, leaving the swap to a human. 5.3.0 renamed
        # `zoneCommander.lua` on all ten maps (FIX-FOOTHOLD-5-3-0-INTAKE): the converter swaps it.
        self._refresh()

        listed = (self.mission / "mission.yaml").read_text(encoding="utf-8")
        self.assertIn("src/scripts/footholdSyriaSetupv2.lua", listed)
        self.assertNotIn("src/scripts/footholdSyriaSetup.lua", listed)
        errors = [i for i in validate_mission_folder(self.mission) if i.level == ERROR]
        self.assertEqual([], [i.message for i in errors if "footholdSyriaSetup" in i.message])


class TestTheMissionMakersOwnScriptIsLeftAlone(unittest.TestCase):
    """Anything the upstream release never shipped belongs to the mission maker."""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.mission = self.root / "VEAF-Foothold-Syria"
        self.converter = OtherMissionConverter(version="test")
        old = make_upstream_miz(RELEASE_4_6, folder=self.root / "4.6.0", name="Foothold_SY_4.6.0.miz")
        self.converter.convert(old, self.mission, profile_name="foothold")

        # A script of their own, declared in custom_scripts exactly like an upstream one — which is
        # why "listed in custom_scripts and not upstream" cannot be the deletion criterion.
        self.mine = self.mission / "src" / "scripts" / "myOwnStuff.lua"
        self.mine.write_text("-- mine\n", encoding="utf-8")
        yaml_path = self.mission / "mission.yaml"
        yaml_path.write_text(
            yaml_path.read_text(encoding="utf-8").replace(
                "    - path: src/scripts/AIEN.lua",
                "    - path: src/scripts/myOwnStuff.lua\n    - path: src/scripts/AIEN.lua",
            ),
            encoding="utf-8",
        )

    def test_a_hand_added_script_survives_an_update(self) -> None:
        new = make_upstream_miz(RELEASE_4_7, folder=self.root / "4.7.0", name="Foothold_SY_4.7.0.miz")
        self.converter.convert(new, self.mission, profile_name="foothold", update=True)

        self.assertTrue(self.mine.is_file(), "a script upstream never shipped is the maker's, not ours to delete")
        self.assertEqual(self.mine.read_text(encoding="utf-8"), "-- mine\n", "and its content is untouched")
        self.assertIn("src/scripts/myOwnStuff.lua", (self.mission / "mission.yaml").read_text(encoding="utf-8"))


class TestAFolderWithoutAManifest(unittest.TestCase):
    """Every mission adopted before the manifest has no record of what upstream used to load."""

    def setUp(self) -> None:
        root = Path(tempfile.mkdtemp())
        self.root = root
        self.mission = root / "VEAF-Foothold-Syria"
        self.converter = OtherMissionConverter(version="test")
        self.converter.convert(
            make_upstream_miz(RELEASE_4_6, folder=root / "4.6.0"), self.mission, profile_name="foothold"
        )
        # Simulate a folder converted by an older version of the tool: the scripts are there, the
        # record of where they came from is not.
        state = self.mission / "convert-other-state.yaml"
        self.assertTrue(state.is_file(), "the adoption records what this release loads")
        state.unlink()

    def _refresh(self):
        return self.converter.convert(
            make_upstream_miz(RELEASE_4_7, folder=self.root / "4.7.0"),
            self.mission,
            profile_name="foothold",
            update=True,
        )

    def test_the_previous_release_is_read_from_the_base_it_left(self) -> None:
        # The exploded mapResource names what 4.6 embedded — how the ten VEAF Foothold missions,
        # all adopted before the manifest, got their first 5.3.0 refresh right.
        self._refresh()

        self.assertFalse((self.mission / "src" / "scripts" / "footholdSyriaSetup.lua").exists())
        self.assertIn(
            "src/scripts/footholdSyriaSetupv2.lua", (self.mission / "mission.yaml").read_text(encoding="utf-8")
        )

    def test_nothing_is_deleted_when_the_previous_release_is_unknown(self) -> None:
        shutil.rmtree(self.mission / "src" / "mission" / "l10n")

        report = self._refresh()

        survivor = self.mission / "src" / "scripts" / "footholdSyriaSetup.lua"
        self.assertTrue(survivor.is_file(), "with neither record the tool cannot know, so it must not guess")
        self.assertIn("footholdSyriaSetup.lua", report.to_markdown(), "but it must still say so")


if __name__ == "__main__":
    unittest.main()
