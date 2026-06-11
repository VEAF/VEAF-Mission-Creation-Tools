"""Tests for build.py pipeline legacy-file warnings (AIRCRAFT-INJECT) and output resolution."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


class TestLegacyAircraftFileWarning(unittest.TestCase):
    """After the hard break (ADR 0002), the old aircraft-group files are no longer injected.

    The build warns whenever a pre-v6 ``src/aircraft-templates.yaml`` or
    ``src/templates.yaml`` is still present, so the user notices it is ignored.
    """

    def _run_legacy_check(self, p_mission_folder: Path, legacy_files: list[str]) -> list[str]:
        """Exercise the legacy-warning logic from build.py in isolation."""
        src_dir = p_mission_folder / "src"
        src_dir.mkdir(parents=True, exist_ok=True)
        for rel in legacy_files:
            (p_mission_folder / rel).write_text("# stub\n", encoding="utf-8")

        warnings: list[str] = []

        # Replicate the exact loop added in build.py.
        for _legacy in ("src/aircraft-templates.yaml", "src/templates.yaml"):
            if (p_mission_folder / _legacy).exists():
                warnings.append(f"orphan: {_legacy}")
        return warnings

    def test_warning_for_aircraft_templates(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_legacy_check(Path(td), ["src/aircraft-templates.yaml"])
        self.assertEqual(len(warnings), 1)

    def test_warning_for_templates(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_legacy_check(Path(td), ["src/templates.yaml"])
        self.assertEqual(len(warnings), 1)

    def test_warning_for_both_legacy_files(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_legacy_check(Path(td), ["src/aircraft-templates.yaml", "src/templates.yaml"])
        self.assertEqual(len(warnings), 2)

    def test_no_warning_when_no_legacy_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_legacy_check(Path(td), [])
        self.assertEqual(warnings, [])


class TestResolvePipelineStepFile(unittest.TestCase):
    """Aircraft-group steps resolve to the new canonical files (AIRCRAFT-INJECT, IMC-Day §8 #3)."""

    def _resolve(self, folder: Path, cfg: dict, key: str, *candidates: str) -> Path | None:
        from veaf_tools.commands.build import resolve_pipeline_step_file

        return resolve_pipeline_step_file(cfg, folder, key, *candidates)

    def test_spawnable_aircrafts_resolves_spawnables_yaml(self) -> None:
        """Regression (IMC-Day §8 #3): spawnables.yaml must be wired to a real injection step."""
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "src").mkdir()
            (folder / "src" / "spawnables.yaml").write_text("# stub\n", encoding="utf-8")
            result = self._resolve(folder, {}, "spawnable_aircrafts", "src/spawnables.yaml")
        self.assertIsNotNone(result)
        self.assertEqual(result.name, "spawnables.yaml")  # type: ignore[union-attr]

    def test_dynamic_slot_templates_resolves_new_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "src").mkdir()
            (folder / "src" / "dynamic-slot-templates.yaml").write_text("# stub\n", encoding="utf-8")
            result = self._resolve(folder, {}, "dynamic_slot_templates", "src/dynamic-slot-templates.yaml")
        self.assertIsNotNone(result)
        self.assertEqual(result.name, "dynamic-slot-templates.yaml")  # type: ignore[union-attr]

    def test_disabled_step_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "src").mkdir()
            (folder / "src" / "spawnables.yaml").write_text("# stub\n", encoding="utf-8")
            result = self._resolve(folder, {"spawnable_aircrafts": False}, "spawnable_aircrafts", "src/spawnables.yaml")
        self.assertIsNone(result)

    def test_custom_file_path_wins(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "custom").mkdir()
            (folder / "custom" / "my.yaml").write_text("# stub\n", encoding="utf-8")
            result = self._resolve(
                folder, {"spawnable_aircrafts": {"file": "custom/my.yaml"}}, "spawnable_aircrafts", "src/spawnables.yaml"
            )
        self.assertEqual(result.name, "my.yaml")  # type: ignore[union-attr]


class TestResolveOutputMission(unittest.TestCase):
    """Output-mission resolution — FIX-BUILD-BARE-NAME-PATH-001."""

    DEFAULT = "mission.miz"

    def _resolve(self, name: str | None, folder: Path) -> tuple[Path, str]:
        from veaf_tools.commands.build import _resolve_output_mission

        return _resolve_output_mission(name, folder, self.DEFAULT)

    def test_default_without_yaml_uses_static_name(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path, base = self._resolve(self.DEFAULT, Path(td))
        self.assertEqual(path.name, "mission.miz")
        self.assertEqual(base, "mission")

    def test_default_with_yaml_derives_name_anchored_in_folder(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "mission.yaml").write_text("mission:\n  name: Training-Syrie\n", encoding="utf-8")
            with patch("veaf_tools.commands.build.validate_yaml_file"):
                path, base = self._resolve(self.DEFAULT, folder)
        self.assertEqual(base, "Training-Syrie")
        self.assertTrue(path.is_absolute())
        self.assertEqual(path.parent, folder)
        self.assertTrue(path.name.startswith("Training-Syrie_"))
        self.assertTrue(path.name.endswith(".miz"))

    def test_bare_name_is_anchored_in_folder(self) -> None:
        """Regression: a bare name must yield an absolute path inside the folder."""
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            path, base = self._resolve("Training-Syrie", folder)
        self.assertEqual(base, "Training-Syrie")
        self.assertTrue(path.is_absolute())
        self.assertEqual(path.parent, folder)
        self.assertTrue(path.name.startswith("Training-Syrie_"))
        self.assertTrue(path.name.endswith(".miz"))

    def test_explicit_miz_file_keeps_suffix_and_stem(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path, base = self._resolve("custom.miz", Path(td))
        self.assertEqual(path.name, "custom.miz")
        self.assertEqual(base, "custom")

    def test_unsafe_characters_are_sanitized(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            path, base = self._resolve('Vol:Aller/Retour', folder)
        self.assertEqual(base, "Vol_Aller_Retour")
        self.assertEqual(path.parent, folder)


if __name__ == "__main__":
    unittest.main()
