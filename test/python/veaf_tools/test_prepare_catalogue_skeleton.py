"""`prepare` lays down an empty aircraft catalogue, not a 637 KB copy that will never be refreshed.

FEAT-DEFAULTS-CATALOGUE-FLOW ticket 02. The full copy is what froze: `src/dynamic-slot-templates.yaml`
(351 KB) and `src/spawnables.yaml` (286 KB) were duplicated into every mission folder on the day it
was created, and the build read the duplicate forever after. Since ticket 01 an absent or empty file
already means "use the shipped catalogue", so the copy buys nothing and costs a permanent drift.

What must not regress: a folder that already owns a populated catalogue keeps it, exactly as
`prepare` keeps every other existing file.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from aircrafts_injector.catalogue import catalogue_file_has_groups
from typer.testing import CliRunner
from veaf_tools.app import app
from veaf_tools.commands.build import resolve_aircraft_catalogue

_runner = CliRunner()

_CATALOGUES = (
    ("src/dynamic-slot-templates.yaml", "dynamic_slot_templates"),
    ("src/spawnables.yaml", "spawnable_aircrafts"),
)


class TestPrepareWritesTheSkeleton(unittest.TestCase):
    def _prepare(self, folder: Path, *extra: str) -> None:
        result = _runner.invoke(app, ["prepare", str(folder), *extra])
        self.assertEqual(result.exit_code, 0, result.output)

    def test_a_fresh_folder_gets_an_empty_catalogue(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            for relative, _ in _CATALOGUES:
                with self.subTest(relative):
                    path = folder / relative
                    self.assertTrue(path.is_file(), f"{relative} was not written")
                    self.assertFalse(catalogue_file_has_groups(path))
                    self.assertLess(path.stat().st_size, 4_000, "the full catalogue was copied again")

    def test_the_skeleton_says_what_empty_means(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            text = (folder / "src" / "dynamic-slot-templates.yaml").read_text(encoding="utf-8")
        self.assertIn("ON PURPOSE", text)
        self.assertIn("dynamic_slot_templates: false", text)
        self.assertIn("pull-aircraft-groups", text)

    def test_the_prepared_folder_still_builds_with_a_full_catalogue(self) -> None:
        """The skeleton is only acceptable because the build now falls back — check the whole chain."""
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            for relative, key in _CATALOGUES:
                with self.subTest(relative):
                    path, shipped = resolve_aircraft_catalogue({}, folder, key, relative)
                    self.assertTrue(shipped)
                    assert path is not None
                    self.assertTrue(catalogue_file_has_groups(path))

    def test_a_populated_catalogue_is_kept(self) -> None:
        """A non-interactive run answers "keep all"; the maker's catalogue must survive it."""
        mine = yaml.safe_dump({"airplanes": {"coalitions": {"blue": {"CJTF Blue": {"Mine": {"name": "Mine"}}}}}})
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            path = folder / "src" / "dynamic-slot-templates.yaml"
            path.write_text(mine, encoding="utf-8")

            self._prepare(folder)

            self.assertEqual(path.read_text(encoding="utf-8"), mine)

    def test_force_rewrites_it_as_the_skeleton_not_as_the_full_copy(self) -> None:
        """`--force` is "give me the shipped scaffold back", and the scaffold is now the skeleton."""
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            path = folder / "src" / "dynamic-slot-templates.yaml"
            path.write_text("airplanes:\n  coalitions: {}\n", encoding="utf-8")

            self._prepare(folder, "--force")

            self.assertFalse(catalogue_file_has_groups(path))
            self.assertIn("ON PURPOSE", path.read_text(encoding="utf-8"))

    def test_the_other_default_files_are_still_copied(self) -> None:
        """Only the two catalogues change; presets and warehouses still arrive in full."""
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._prepare(folder)
            self.assertTrue((folder / "src" / "presets.yaml").is_file())
            self.assertGreater((folder / "src" / "presets.yaml").stat().st_size, 1_000)
            self.assertTrue((folder / "src" / "warehouses.yaml").is_file())


if __name__ == "__main__":
    unittest.main()
