"""`Convert-FootholdBatch -Update` must find the mission folder it should refresh — ticket 04
of FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.

The batch named each target after the archive. Lekaa's archive names carry the version
(``Foothold_CA_4.7.0_Multi_Language_Coldwar-Modern-Vietnam.zip``) while the VEAF mission folders
are named after the map (``VEAF-Foothold-Caucasus``), so ``-Update`` tested
``<target>\\mission.yaml``, found nothing, and silently fell back to a **fresh adoption** — ten
new folders, none of the ten missions refreshed. And the command it fails at is the one every
mission repository's README recommends. The 2026-08-25 refresh worked around it by copying the
five archives under the repository names into a staging folder.

Matching is by **theatre**, read from the mission table on both sides: Lekaa ships one archive
per map, so the map is what says which folder a release belongs to — and the batch already opens
the ``.miz`` inside the ``.zip`` to pick the conversion profile.

The logic lives in PowerShell because the batch does; these tests drive it through ``pwsh``,
which is on the CI runners as well as here. That is why it sits in its own dot-sourced file: the
batch itself takes mandatory parameters and would start converting if a test sourced it.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from upstream_miz import make_release_zip, make_upstream_miz

REPO_ROOT = Path(__file__).resolve().parents[3]
RESOLVER = REPO_ROOT / "tools" / "Resolve-MissionFolder.ps1"
PWSH = shutil.which("pwsh")


def _mission_folder(root: Path, name: str, theatre: str) -> Path:
    """Create a mission folder that looks adopted: a mission.yaml and an exploded mission table."""
    folder = root / name
    (folder / "src" / "mission").mkdir(parents=True)
    (folder / "mission.yaml").write_text("custom_scripts:\n  scripts: []\n", encoding="utf-8")
    (folder / "src" / "mission" / "mission").write_text(
        f'mission =\n{{\n    ["theatre"] = "{theatre}",\n}}\n', encoding="utf-8"
    )
    return folder


@unittest.skipUnless(PWSH, "pwsh not available")
class TestResolveMissionFolder(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.output = self.root / "missions"
        self.output.mkdir()

    def _resolve(self, archive: Path) -> dict:
        """Call Resolve-MissionFolder and return its result as a dict."""
        assert PWSH is not None
        script = (
            f". '{RESOLVER}'; "
            f"Resolve-MissionFolder -OutputFolder '{self.output}' -ArchivePath '{archive}' "
            f"| ConvertTo-Json -Compress"
        )
        done = subprocess.run(
            [PWSH, "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(done.returncode, 0, f"pwsh failed: {done.stderr}")
        return json.loads(done.stdout)

    def _release(self, *, theatre: str, name: str) -> Path:
        miz = make_upstream_miz(folder=self.root / name, name="mission.miz", theatre=theatre)
        return make_release_zip(miz, name=name)

    def test_an_existing_folder_of_the_same_theatre_is_the_target(self) -> None:
        expected = _mission_folder(self.output, "VEAF-Foothold-Caucasus", "Caucasus")

        result = self._resolve(self._release(theatre="Caucasus", name="Foothold_CA_4.7.0_Multi_Language.zip"))

        self.assertEqual(Path(result["Path"]), expected)
        self.assertTrue(result["Matched"], "the batch must know it matched, so -Update can engage")

    def test_a_theatre_with_no_folder_falls_back_to_the_archive_name(self) -> None:
        _mission_folder(self.output, "VEAF-Foothold-Caucasus", "Caucasus")

        result = self._resolve(self._release(theatre="Sinai", name="Foothold_SI_4.7.0_Multi_Language.zip"))

        self.assertEqual(Path(result["Path"]).name, "Foothold_SI_4.7.0_Multi_Language")
        self.assertFalse(result["Matched"], "a new map is a fresh adoption, which is correct")

    def test_two_folders_of_one_theatre_are_left_to_the_human(self) -> None:
        # Guessing between them could refresh the wrong mission, which is worse than not helping.
        _mission_folder(self.output, "VEAF-Foothold-Caucasus", "Caucasus")
        _mission_folder(self.output, "VEAF-Foothold-Caucasus-Test", "Caucasus")

        result = self._resolve(self._release(theatre="Caucasus", name="Foothold_CA_4.7.0.zip"))

        self.assertFalse(result["Matched"])
        self.assertIn("Caucasus", result["Reason"], "and it must say why it did not")

    def test_a_folder_named_after_the_archive_still_wins(self) -> None:
        # Someone adopting with the default naming must keep working exactly as before.
        expected = _mission_folder(self.output, "Foothold_CA_4.7.0", "Caucasus")
        _mission_folder(self.output, "Some-Other-Caucasus-Mission", "Caucasus")

        result = self._resolve(self._release(theatre="Caucasus", name="Foothold_CA_4.7.0.zip"))

        self.assertEqual(Path(result["Path"]), expected)

    def test_a_folder_without_an_exploded_mission_is_ignored(self) -> None:
        # A half-converted folder has no theatre to read; it must not swallow the match.
        (self.output / "half-done").mkdir()
        (self.output / "half-done" / "mission.yaml").write_text("x: 1\n", encoding="utf-8")
        expected = _mission_folder(self.output, "VEAF-Foothold-Caucasus", "Caucasus")

        result = self._resolve(self._release(theatre="Caucasus", name="Foothold_CA_4.7.0.zip"))

        self.assertEqual(Path(result["Path"]), expected)


@unittest.skipUnless(PWSH, "pwsh not available")
class TestTheBatchActuallyUsesIt(unittest.TestCase):
    """The resolver working proves nothing if the batch still names targets after the archive.

    Reading the batch's syntax tree rather than its text, so a mention in a comment or in the
    help block cannot pass for a call.
    """

    BATCH = REPO_ROOT / "tools" / "Convert-FootholdBatch.ps1"

    def _ast_query(self, expression: str) -> str:
        assert PWSH is not None
        script = (
            f"$ast = [System.Management.Automation.Language.Parser]::ParseFile('{self.BATCH}', [ref]$null, [ref]$null); "
            f"{expression}"
        )
        done = subprocess.run(
            [PWSH, "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(done.returncode, 0, f"pwsh failed: {done.stderr}")
        return done.stdout.strip()

    def test_the_batch_calls_the_resolver(self) -> None:
        found = self._ast_query(
            "@($ast.FindAll({ param($n) $n -is "
            "[System.Management.Automation.Language.CommandAst] -and "
            "$n.GetCommandName() -eq 'Resolve-MissionFolder' }, $true)).Count"
        )

        self.assertNotEqual(found, "0", "the batch must resolve its target, not name it after the archive")

    def test_the_batch_dot_sources_the_resolver(self) -> None:
        found = self._ast_query(
            "@($ast.FindAll({ param($n) $n -is "
            "[System.Management.Automation.Language.CommandAst] -and "
            "$n.InvocationOperator -eq 'Dot' }, $true)).Count"
        )

        self.assertNotEqual(found, "0", "a call to a function of a file it never sources would fail at runtime")


if __name__ == "__main__":
    unittest.main()
