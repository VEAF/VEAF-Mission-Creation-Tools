"""SECREV-2 / VMR-035 — a conversion profile could rename a script outside the scripts folder.

`_normalize_script_names` joined the profile's replacement string straight onto `scripts_dir`, so a
rule replacing a script with `../../x.lua` renamed the file into the mission folder's parent. A
profile is **data**, and `load_profile` accepts a filesystem path as well as a bundled name — so the
replacement is not necessarily one we shipped. Profiles are the kind of file that gets shared
(`foothold.yaml` is one), which is what makes this worth a guard rather than a shrug.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.other_converter import DetectedLoader, OtherMissionConverter, _is_plain_filename
from veaf_libs.conversion_profile import ConversionProfile, NameRule


def _profile(replacement: str) -> ConversionProfile:
    return ConversionProfile(name="hostile", name_rules=(NameRule(pattern="victim.lua", replacement=replacement),))


class TestIsPlainFilename(unittest.TestCase):
    def test_it_accepts_a_bare_name(self) -> None:
        for name in ("Moose.lua", "CTLD.lua", "a-b_c.1.lua"):
            with self.subTest(name=name):
                self.assertTrue(_is_plain_filename(name))

    def test_it_refuses_anything_carrying_a_directory(self) -> None:
        for name in (
            "../evil.lua",
            "../../evil.lua",
            "sub/evil.lua",
            "sub\\evil.lua",
            "/etc/evil.lua",
            "C:\\Windows\\evil.lua",
            "C:evil.lua",  # drive-relative on Windows, and a colon has no business in a filename
            "..",
            ".",
            "",
        ):
            with self.subTest(name=name):
                self.assertFalse(_is_plain_filename(name))


class TestTheRenameStaysInsideTheScriptsFolder(unittest.TestCase):
    def _run(self, replacement: str) -> tuple[Path, list[DetectedLoader]]:
        root = Path(tempfile.mkdtemp())
        scripts = root / "mission" / "scripts"
        scripts.mkdir(parents=True)
        (scripts / "victim.lua").write_text("-- victim", encoding="utf-8")

        loaders = OtherMissionConverter._normalize_script_names(
            [DetectedLoader(script="victim.lua", trigger_index=0, trigger_comment="ScriptLoader 1")],
            _profile(replacement),
            scripts,
        )
        return root, loaders

    def test_a_traversing_replacement_is_refused_and_nothing_leaves_the_folder(self) -> None:
        root, loaders = self._run("../../escaped.lua")

        self.assertFalse((root / "escaped.lua").exists(), "the rename must not reach the parent folder")
        self.assertTrue((root / "mission" / "scripts" / "victim.lua").exists(), "the original must stay put")
        self.assertEqual(
            [loader.script for loader in loaders],
            ["victim.lua"],
            "the reported name must stay the original, or custom_scripts would point at a file that was never written",
        )

    def test_a_legitimate_rename_still_happens(self) -> None:
        # The guard must not break what the feature is for: foothold.yaml renames versioned scripts.
        root, loaders = self._run("Normalised.lua")

        scripts = root / "mission" / "scripts"
        self.assertTrue((scripts / "Normalised.lua").exists())
        self.assertFalse((scripts / "victim.lua").exists())
        self.assertEqual([loader.script for loader in loaders], ["Normalised.lua"])


if __name__ == "__main__":
    unittest.main()
