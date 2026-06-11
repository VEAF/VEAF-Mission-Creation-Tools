"""Tests for veaf_tools.commands.prepare — NEVER_OVERWRITE protection."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path


def _copy_defaults(mission_folder: Path, defaults_source: Path, force: bool = False) -> tuple[int, int]:
    """Replicate the prepare copy loop logic for testing purposes."""
    files_installed = 0
    files_skipped = 0
    yes_to_all = force

    NEVER_OVERWRITE: frozenset[str] = frozenset({".gitignore"})

    for source_file in defaults_source.rglob("*"):
        if source_file.is_file():
            relative_path = source_file.relative_to(defaults_source)
            dest_file = mission_folder / relative_path
            dest_file.parent.mkdir(parents=True, exist_ok=True)

            if dest_file.exists():
                if source_file.name in NEVER_OVERWRITE:
                    files_skipped += 1
                    continue
                if yes_to_all:
                    shutil.copy2(source_file, dest_file)
                    files_installed += 1
                else:
                    files_skipped += 1
            else:
                shutil.copy2(source_file, dest_file)
                files_installed += 1

    return files_installed, files_skipped


class TestPrepareNeverOverwrite(unittest.TestCase):
    def _run_prepare(self, mission_folder: Path, defaults_source: Path, force: bool = False) -> tuple[int, int]:
        return _copy_defaults(mission_folder, defaults_source, force=force)

    def setUp(self) -> None:
        self.tmpdir = tempfile.mkdtemp()
        self.mission_folder = Path(self.tmpdir) / "mission"
        self.mission_folder.mkdir()
        self.defaults = Path(self.tmpdir) / "defaults"
        self.defaults.mkdir()

        # Defaults folder contains a .gitignore and a regular file
        gitignore_default = self.defaults / ".gitignore"
        gitignore_default.write_text("# default .gitignore\n/published/\n", encoding="utf-8")
        regular_default = self.defaults / "mission.yaml"
        regular_default.write_text("# default mission.yaml\n", encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmpdir)

    def test_gitignore_not_overwritten_with_force(self) -> None:
        """--force must NOT overwrite .gitignore (NEVER_OVERWRITE protection)."""
        existing_gitignore = self.mission_folder / ".gitignore"
        existing_gitignore.write_text("# user customizations\n/my-secrets/\n", encoding="utf-8")

        self._run_prepare(self.mission_folder, self.defaults, force=True)

        content = existing_gitignore.read_text(encoding="utf-8")
        self.assertIn("# user customizations", content)
        self.assertNotIn("# default .gitignore", content)

    def test_gitignore_installed_when_absent(self) -> None:
        """When .gitignore does not exist, it must be copied normally."""
        self._run_prepare(self.mission_folder, self.defaults, force=False)

        gitignore = self.mission_folder / ".gitignore"
        self.assertTrue(gitignore.exists())
        self.assertIn("# default .gitignore", gitignore.read_text(encoding="utf-8"))

    def test_regular_file_overwritten_with_force(self) -> None:
        """`--force` still overwrites regular files that are not in NEVER_OVERWRITE."""
        existing_yaml = self.mission_folder / "mission.yaml"
        existing_yaml.write_text("# user mission.yaml\n", encoding="utf-8")

        self._run_prepare(self.mission_folder, self.defaults, force=True)

        content = existing_yaml.read_text(encoding="utf-8")
        self.assertIn("# default mission.yaml", content)


class TestPrepareDefaultsResolution(unittest.TestCase):
    """`prepare` resolves defaults from the mission folder's published/ (IMC2-001)."""

    def test_mission_published_is_first_candidate(self) -> None:
        from veaf_tools.commands.prepare import _defaults_source_candidates

        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            candidates = _defaults_source_candidates(folder)
        self.assertEqual(candidates[0], folder / "published" / "src" / "defaults" / "mission-folder")

    def test_resolves_from_mission_published(self) -> None:
        from veaf_tools.commands.prepare import _resolve_defaults_source

        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            installed = folder / "published" / "src" / "defaults" / "mission-folder"
            installed.mkdir(parents=True)
            # Even though the dev-checkout fallback exists during the test run, published/ wins.
            self.assertEqual(_resolve_defaults_source(folder), installed)


if __name__ == "__main__":
    unittest.main()
