"""Tests for MissionBuilderWorker.complete_src_folder_with_defaults() — IMC-008."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker


def _make_worker(mission_folder: Path, defaults_folder: Path, mission_yaml: dict) -> MissionBuilderWorker:
    """Instantiate a MissionBuilderWorker without running __init__, injecting only the attributes
    needed by complete_src_folder_with_defaults()."""
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_folder = mission_folder
    worker.scripts_path = None  # forces defaults_folder resolution via mission_folder/published/src
    worker.mission_yaml = mission_yaml
    worker.pipeline_cfg = mission_yaml.get("pipeline") or {}
    return worker


def _seed_defaults(defaults_folder: Path, *filenames: str) -> None:
    """Create stub files in the given defaults folder."""
    for name in filenames:
        dest = defaults_folder / "src" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(f"# {name} default", encoding="utf-8")


class TestCompleteDefaultsFiltering(unittest.TestCase):
    """Files whose module/pipeline is disabled must not be copied (IMC-008)."""

    def _run(self, mission_yaml: dict, filenames: list[str]) -> tuple[Path, MissionBuilderWorker]:
        tmpdir = Path(tempfile.mkdtemp())
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, *filenames)
        worker = _make_worker(tmpdir, defaults_folder, mission_yaml)
        worker.complete_src_folder_with_defaults()
        return tmpdir, worker

    def tearDown(self) -> None:
        # temp dirs are cleaned up by individual tests
        pass

    def test_file_copied_when_module_enabled(self) -> None:
        """spawnables.yaml is copied when SPAWN is enabled."""
        tmpdir, _ = self._run(
            {"lua_modules": {"SPAWN": {"enable": True}}},
            ["spawnables.yaml"],
        )
        self.assertTrue((tmpdir / "src" / "spawnables.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_file_not_copied_when_lua_module_disabled(self) -> None:
        """spawnables.yaml is NOT copied when SPAWN is disabled."""
        tmpdir, _ = self._run(
            {"lua_modules": {"SPAWN": {"enable": False}}},
            ["spawnables.yaml"],
        )
        self.assertFalse((tmpdir / "src" / "spawnables.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_file_not_copied_when_pipeline_disabled_false(self) -> None:
        """waypoints.yaml is NOT copied when pipeline.waypoints is False."""
        tmpdir, _ = self._run(
            {"pipeline": {"waypoints": False}},
            ["waypoints.yaml"],
        )
        self.assertFalse((tmpdir / "src" / "waypoints.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_file_not_copied_when_pipeline_disabled_dict(self) -> None:
        """presets.yaml is NOT copied when pipeline.presets has enabled: false."""
        tmpdir, _ = self._run(
            {"pipeline": {"presets": {"enabled": False}}},
            ["presets.yaml"],
        )
        self.assertFalse((tmpdir / "src" / "presets.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_unrelated_file_always_copied(self) -> None:
        """A file not in the module map is always copied regardless of yaml config."""
        tmpdir, _ = self._run(
            {"pipeline": {"waypoints": False}},
            ["some-other-file.yaml"],
        )
        self.assertTrue((tmpdir / "src" / "some-other-file.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_file_copied_when_no_mission_yaml(self) -> None:
        """With no mission.yaml at all, all defaults are copied normally."""
        tmpdir, _ = self._run({}, ["waypoints.yaml"])
        self.assertTrue((tmpdir / "src" / "waypoints.yaml").exists())
        shutil.rmtree(tmpdir)


class TestCompleteDefaultsOrphanWarning(unittest.TestCase):
    """An orphan warning is emitted when a file already exists but its module is disabled (IMC-008)."""

    def test_orphan_warning_logged(self) -> None:
        """When SPAWN is disabled and spawnables.yaml already exists, a warning is emitted."""
        from unittest.mock import patch

        from veaf_libs.logger import logger

        tmpdir = Path(tempfile.mkdtemp())
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "spawnables.yaml")

        # Pre-create the file in the mission folder
        (tmpdir / "src").mkdir(parents=True, exist_ok=True)
        (tmpdir / "src" / "spawnables.yaml").write_text("existing content", encoding="utf-8")

        worker = _make_worker(tmpdir, defaults_folder, {"lua_modules": {"SPAWN": {"enable": False}}})

        warnings: list[str] = []
        orig_warning = logger.warning

        def capture_warning(msg, *args, **kwargs):
            warnings.append(str(msg))
            return orig_warning(msg, *args, **kwargs)

        with patch.object(logger, "warning", side_effect=capture_warning):
            worker.complete_src_folder_with_defaults()

        shutil.rmtree(tmpdir)
        orphan_warnings = [w for w in warnings if "Orphan" in w or "orphan" in w.lower()]
        self.assertTrue(orphan_warnings, "Expected at least one orphan warning")


class TestWeatherAliasCoexistence(unittest.TestCase):
    """WEATHER-001/002: versions.yaml copy skipped when legacy missions.yaml is present (FIX-WEATHER-ALIAS)."""

    def _run_with_warnings(self, mission_folder: Path, defaults_folder: Path, mission_yaml: dict) -> list[str]:
        from unittest.mock import patch

        from veaf_libs.logger import logger

        worker = _make_worker(mission_folder, defaults_folder, mission_yaml)
        warnings: list[str] = []
        orig_warning = logger.warning

        def capture_warning(msg, *args, **kwargs):
            warnings.append(str(msg))
            return orig_warning(msg, *args, **kwargs)

        with patch.object(logger, "warning", side_effect=capture_warning):
            worker.complete_src_folder_with_defaults()

        return warnings

    def test_versions_not_copied_when_missions_exists(self) -> None:
        """versions.yaml is NOT copied if src/missions.yaml already exists in mission folder."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "versions.yaml")
        (tmpdir / "src").mkdir(parents=True, exist_ok=True)
        (tmpdir / "src" / "missions.yaml").write_text("# legacy weather config", encoding="utf-8")

        warnings = self._run_with_warnings(tmpdir, defaults_folder, {})

        self.assertFalse((tmpdir / "src" / "versions.yaml").exists(), "versions.yaml must not be created")
        self.assertTrue(
            any("missions.yaml" in w for w in warnings),
            f"Expected a warning mentioning missions.yaml; got: {warnings}",
        )

    def test_versions_copied_when_missions_absent(self) -> None:
        """versions.yaml IS copied normally when no legacy missions.yaml exists."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "versions.yaml")

        self._run_with_warnings(tmpdir, defaults_folder, {})

        self.assertTrue((tmpdir / "src" / "versions.yaml").exists(), "versions.yaml must be copied")


class TestOldScriptsDetection(unittest.TestCase):
    """OLDSCRIPTS-002: warn when unexpected .lua files are present in src/scripts/."""

    def _run_with_warnings(self, mission_folder: Path) -> list[str]:
        from unittest.mock import patch

        from veaf_libs.logger import logger

        # Minimal defaults folder (empty — we only care about the scripts/ check)
        defaults_folder = mission_folder / "published" / "src" / "defaults" / "mission-folder"
        defaults_folder.mkdir(parents=True, exist_ok=True)
        worker = _make_worker(mission_folder, defaults_folder, {})

        warnings: list[str] = []
        orig_warning = logger.warning

        def capture_warning(msg, *args, **kwargs):
            formatted = msg % args if args else str(msg)
            warnings.append(formatted)
            return orig_warning(msg, *args, **kwargs)

        with patch.object(logger, "warning", side_effect=capture_warning):
            worker.complete_src_folder_with_defaults()

        return warnings

    def test_no_warning_for_expected_files(self) -> None:
        """veaf-config.lua, mission-script.lua, veafDynamicConfig.lua must not trigger a warning."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        for name in ("veaf-config.lua", "mission-script.lua", "veafDynamicConfig.lua"):
            (scripts_dir / name).write_text("-- ok", encoding="utf-8")

        warnings = self._run_with_warnings(tmpdir)

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertEqual(unexpected, [], f"Unexpected warnings: {unexpected}")

    def test_warning_for_residual_v5_file(self) -> None:
        """A leftover v5 file like veafSecurity.lua must trigger a warning."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "veafSecurity.lua").write_text("-- v5 residue", encoding="utf-8")

        warnings = self._run_with_warnings(tmpdir)

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertTrue(unexpected, "Expected a warning for veafSecurity.lua")
        self.assertTrue(any("veafSecurity.lua" in w for w in unexpected))

    def test_mixed_expected_and_unexpected_lua_files(self) -> None:
        """Only unexpected files warn; expected files alongside them must not."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        for name in ("veaf-config.lua", "mission-script.lua", "veafDynamicConfig.lua"):
            (scripts_dir / name).write_text("-- ok", encoding="utf-8")
        (scripts_dir / "veafSecurity.lua").write_text("-- v5 residue", encoding="utf-8")

        warnings = self._run_with_warnings(tmpdir)

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertTrue(unexpected, "Expected a warning for veafSecurity.lua when mixed with valid files")
        self.assertTrue(any("veafSecurity.lua" in w for w in unexpected))
        self.assertFalse(any("veaf-config.lua" in w for w in unexpected))
        self.assertFalse(any("mission-script.lua" in w for w in unexpected))
        self.assertFalse(any("veafDynamicConfig.lua" in w for w in unexpected))

    def test_no_warning_when_scripts_dir_absent(self) -> None:
        """No error or warning when src/scripts/ does not exist."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)

        warnings = self._run_with_warnings(tmpdir)

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertEqual(unexpected, [])


if __name__ == "__main__":
    unittest.main()
