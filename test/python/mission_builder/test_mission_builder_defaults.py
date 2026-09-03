"""Tests for MissionBuilderWorker.complete_src_folder_with_defaults() — IMC-008."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import CustomScript, MissionBuilderWorker
from mission_builder_factory import make_worker
from veaf_libs.i18n import set_language


def _make_worker(
    mission_folder: Path,
    defaults_folder: Path,
    mission_yaml: dict,
    custom_scripts: list[CustomScript] | None = None,
    custom_scripts_generate_load_trigger: bool = True,
) -> MissionBuilderWorker:
    """Instantiate a MissionBuilderWorker without running __init__, injecting only the attributes
    needed by complete_src_folder_with_defaults()."""
    # scripts_path stays None (the factory default): that forces defaults_folder resolution
    # via mission_folder/published/src.
    return make_worker(
        mission_folder=mission_folder,
        mission_yaml=mission_yaml,
        pipeline_cfg=mission_yaml.get("pipeline") or {},
        # Raw (pre-profile) yaml: in these unit tests the same dict doubles as the raw
        # config (it carries the pipeline + any profiles the orphan check reasons about).
        _raw_yaml=mission_yaml,
        custom_scripts=custom_scripts or [],
        custom_scripts_generate_load_trigger=custom_scripts_generate_load_trigger,
    )


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

    def test_file_copied_when_pipeline_step_enabled(self) -> None:
        """spawnables.yaml is copied when its pipeline step is enabled."""
        tmpdir, _ = self._run(
            {"pipeline": {"spawnable_aircrafts": True}},
            ["spawnables.yaml"],
        )
        self.assertTrue((tmpdir / "src" / "spawnables.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_file_not_copied_when_pipeline_step_disabled(self) -> None:
        """spawnables.yaml is NOT copied when its pipeline step is disabled."""
        tmpdir, _ = self._run(
            {"pipeline": {"spawnable_aircrafts": False}},
            ["spawnables.yaml"],
        )
        self.assertFalse((tmpdir / "src" / "spawnables.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_dynamic_slot_templates_not_copied_when_disabled(self) -> None:
        """dynamic-slot-templates.yaml is NOT copied when its pipeline step is disabled."""
        tmpdir, _ = self._run(
            {"pipeline": {"dynamic_slot_templates": False}},
            ["dynamic-slot-templates.yaml"],
        )
        self.assertFalse((tmpdir / "src" / "dynamic-slot-templates.yaml").exists())
        shutil.rmtree(tmpdir)

    def test_dynamic_slot_templates_copied_by_default(self) -> None:
        """dynamic-slot-templates.yaml IS copied when its pipeline step is left at its default."""
        tmpdir, _ = self._run({}, ["dynamic-slot-templates.yaml"])
        self.assertTrue((tmpdir / "src" / "dynamic-slot-templates.yaml").exists())
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

    def test_copying_a_missing_default_logs_a_message(self) -> None:
        """Recreating a deleted default must not be silent (IMC-Day §8 #2)."""
        from unittest.mock import patch

        from veaf_libs.logger import logger

        tmpdir = Path(tempfile.mkdtemp())
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "spawnables.yaml")
        worker = _make_worker(tmpdir, defaults_folder, {})

        messages: list[str] = []
        orig = logger.warning

        def capture(msg, *args, **kwargs):
            messages.append(str(msg))
            return orig(msg, *args, **kwargs)

        with patch.object(logger, "warning", side_effect=capture):
            worker.complete_src_folder_with_defaults()

        copied = (tmpdir / "src" / "spawnables.yaml").exists()
        shutil.rmtree(tmpdir)
        self.assertTrue(copied)
        self.assertTrue(
            any("spawnables.yaml" in m for m in messages),
            "Copying a missing default must emit an explicit message",
        )


class TestCompleteDefaultsOrphanWarning(unittest.TestCase):
    """An orphan warning is emitted when a file already exists but its module is disabled (IMC-008)."""

    def setUp(self) -> None:
        set_language("en")

    def tearDown(self) -> None:
        set_language("en")

    def test_orphan_warning_logged(self) -> None:
        """When the pipeline step is disabled and spawnables.yaml already exists, a warning is emitted."""
        from unittest.mock import patch

        from veaf_libs.logger import logger

        tmpdir = Path(tempfile.mkdtemp())
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "spawnables.yaml")

        # Pre-create the file in the mission folder
        (tmpdir / "src").mkdir(parents=True, exist_ok=True)
        (tmpdir / "src" / "spawnables.yaml").write_text("existing content", encoding="utf-8")

        worker = _make_worker(tmpdir, defaults_folder, {"pipeline": {"spawnable_aircrafts": False}})

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

    def _orphan_warnings_for(self, mission_yaml: dict) -> list[str]:
        """Pre-create versions.yaml, run the completion, return the warnings emitted."""
        from unittest.mock import patch

        tmpdir = Path(tempfile.mkdtemp())
        try:
            defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
            _seed_defaults(defaults_folder, "versions.yaml")
            (tmpdir / "src").mkdir(parents=True, exist_ok=True)
            (tmpdir / "src" / "versions.yaml").write_text("existing", encoding="utf-8")
            worker = _make_worker(tmpdir, defaults_folder, mission_yaml)
            with patch("mission_builder.mission_builder_worker.logger") as mock_logger:
                worker.complete_src_folder_with_defaults()
            return [str(c.args[0]) for c in mock_logger.warning.call_args_list if c.args]
        finally:
            shutil.rmtree(tmpdir)

    def test_no_orphan_warning_when_a_profile_still_enables_the_step(self) -> None:
        """weather off in base but enabled by a profile → the file is used, no orphan warning."""
        warnings = self._orphan_warnings_for(
            {"pipeline": {"weather": False}, "profiles": {"SERVER": {"pipeline": {"weather": True}}}}
        )
        self.assertFalse(any("versions.yaml" in w for w in warnings), warnings)

    def test_orphan_warning_when_disabled_in_every_context(self) -> None:
        """weather off in base and every profile → genuine orphan, warning emitted."""
        warnings = self._orphan_warnings_for(
            {"pipeline": {"weather": False}, "profiles": {"TEST": {"pipeline": {"weather": False}}}}
        )
        self.assertTrue(any("versions.yaml" in w for w in warnings), warnings)


class TestWeatherDefaultsCopy(unittest.TestCase):
    """versions.yaml is copied from defaults when absent from the mission folder."""

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

    def test_versions_copied_when_missions_absent(self) -> None:
        """versions.yaml IS copied normally when no versions.yaml exists yet."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        defaults_folder = tmpdir / "published" / "src" / "defaults" / "mission-folder"
        _seed_defaults(defaults_folder, "versions.yaml")

        self._run_with_warnings(tmpdir, defaults_folder, {})

        self.assertTrue((tmpdir / "src" / "versions.yaml").exists(), "versions.yaml must be copied")


class TestOldScriptsDetection(unittest.TestCase):
    """OLDSCRIPTS-002: warn when unexpected .lua files are present in src/scripts/."""

    def setUp(self) -> None:
        set_language("en")

    def tearDown(self) -> None:
        set_language("en")

    def _run_with_warnings(
        self,
        mission_folder: Path,
        custom_scripts: list[CustomScript] | None = None,
        custom_scripts_generate_load_trigger: bool = True,
    ) -> list[str]:
        from unittest.mock import patch

        from veaf_libs.logger import logger

        # Minimal defaults folder (empty — we only care about the scripts/ check)
        defaults_folder = mission_folder / "published" / "src" / "defaults" / "mission-folder"
        defaults_folder.mkdir(parents=True, exist_ok=True)
        worker = _make_worker(
            mission_folder,
            defaults_folder,
            {},
            custom_scripts=custom_scripts,
            custom_scripts_generate_load_trigger=custom_scripts_generate_load_trigger,
        )

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

    def test_no_warning_for_declared_custom_script(self) -> None:
        """A script declared in custom_scripts must not trigger an 'Unexpected' warning."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "FgMission.lua").write_text("-- custom script", encoding="utf-8")

        warnings = self._run_with_warnings(
            tmpdir,
            custom_scripts=[CustomScript(path="FgMission.lua")],
        )

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertEqual(unexpected, [], f"No warning expected for declared custom script: {unexpected}")

    def test_warning_mentions_custom_scripts_hint_for_undeclared_file(self) -> None:
        """Warning for an undeclared file must mention the custom_scripts section."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "MyScript.lua").write_text("-- unknown", encoding="utf-8")

        warnings = self._run_with_warnings(tmpdir)

        unexpected = [w for w in warnings if "Unexpected Lua file" in w and "MyScript.lua" in w]
        self.assertTrue(unexpected, "Expected a warning for undeclared MyScript.lua")
        self.assertTrue(any("custom_scripts" in w for w in unexpected), "Warning must hint at custom_scripts section")

    def test_declared_script_no_warning_alongside_unexpected(self) -> None:
        """Declared custom script is silent; undeclared one still warns."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "FgMission.lua").write_text("-- declared", encoding="utf-8")
        (scripts_dir / "Unknown.lua").write_text("-- undeclared", encoding="utf-8")

        warnings = self._run_with_warnings(
            tmpdir,
            custom_scripts=[CustomScript(path="FgMission.lua")],
        )

        unexpected = [w for w in warnings if "Unexpected Lua file" in w]
        self.assertFalse(any("FgMission.lua" in w for w in unexpected), "FgMission.lua must not warn")
        self.assertTrue(any("Unknown.lua" in w for w in unexpected), "Unknown.lua must warn")


class TestGeneratedArtifactInSources(unittest.TestCase):
    """FIX-EXTRACT-GENERATED-ARTIFACTS-02: the build's own injected Lua left in src/scripts/.

    It is not an "unexpected" file to be adopted under ``custom_scripts:`` — that would
    freeze a stale copy of the spawn database into the mission. It gets its own message and
    is left out of the build, so the mission carries only the copy the pipeline injects.
    """

    def setUp(self) -> None:
        set_language("en")

    def tearDown(self) -> None:
        set_language("en")

    def _folder_with(self, *names: str) -> Path:
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        scripts_dir = tmpdir / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        for name in names:
            (scripts_dir / name).write_text("-- generated\n", encoding="utf-8")
        (tmpdir / "published" / "src" / "defaults" / "mission-folder").mkdir(parents=True, exist_ok=True)
        return tmpdir

    def _warnings(self, mission_folder: Path, custom_scripts: list[CustomScript] | None = None) -> list[str]:
        from unittest.mock import patch

        from veaf_libs.logger import logger

        worker = _make_worker(
            mission_folder,
            mission_folder / "published" / "src" / "defaults" / "mission-folder",
            {},
            custom_scripts=custom_scripts,
        )
        warnings: list[str] = []
        orig_warning = logger.warning

        def capture_warning(msg, *args, **kwargs):
            warnings.append(msg % args if args else str(msg))
            return orig_warning(msg, *args, **kwargs)

        with patch.object(logger, "warning", side_effect=capture_warning):
            worker.complete_src_folder_with_defaults()
        return warnings

    def _collected(self, mission_folder: Path, custom_scripts: list[CustomScript] | None = None) -> dict[str, bytes]:
        worker = _make_worker(
            mission_folder,
            mission_folder / "published" / "src" / "defaults" / "mission-folder",
            {},
            custom_scripts=custom_scripts,
        )
        return worker.get_collected_mission_script_files()

    def test_a_copy_under_src_mission_is_not_embedded_either(self) -> None:
        """The other door: `src/mission/**` takes everything, and warns about nothing."""
        tmpdir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmpdir)
        mission_dir = tmpdir / "src" / "mission" / "l10n" / "DEFAULT"
        mission_dir.mkdir(parents=True)
        (mission_dir / "veaf-spawn-data.lua").write_text("-- generated\n", encoding="utf-8")
        (mission_dir / "dictionary").write_text("dictionary = {}\n", encoding="utf-8")
        (tmpdir / "published" / "src" / "defaults" / "mission-folder").mkdir(parents=True)

        worker = _make_worker(tmpdir, tmpdir / "published" / "src" / "defaults" / "mission-folder", {})
        collected = worker.get_collected_mission_data_files()

        self.assertEqual([key for key in collected if key.endswith("veaf-spawn-data.lua")], [])
        self.assertTrue(
            any(key.endswith("dictionary") for key in collected),
            "the rest of src/mission/ must still be collected",
        )

    def test_spawn_data_gets_its_own_message(self) -> None:
        warnings = self._warnings(self._folder_with("veaf-spawn-data.lua"))

        self.assertFalse(
            any("Unexpected Lua file" in w for w in warnings),
            "a generated artifact must not be reported as an unexpected file",
        )
        self.assertTrue(
            any("veaf-spawn-data.lua" in w and "spawn-groups.yaml" in w for w in warnings),
            f"expected the generated-artifact message, got: {warnings}",
        )

    def test_dcs_bridge_gets_its_own_message(self) -> None:
        warnings = self._warnings(self._folder_with("dcs-bridge.lua"))

        self.assertFalse(any("Unexpected Lua file" in w for w in warnings))
        self.assertTrue(any("dcs-bridge.lua" in w for w in warnings))

    def test_generated_artifact_is_not_embedded(self) -> None:
        collected = self._collected(self._folder_with("veaf-spawn-data.lua", "dcs-bridge.lua"))

        self.assertEqual(
            [key for key in collected if key.endswith(("veaf-spawn-data.lua", "dcs-bridge.lua"))],
            [],
            "the build must embed only the copy the pipeline injects",
        )

    def test_declaring_it_as_a_custom_script_does_not_rescue_it(self) -> None:
        """Honouring the declaration would reinstate the bug while looking like consent."""
        folder = self._folder_with("veaf-spawn-data.lua")
        declared = [CustomScript(path="veaf-spawn-data.lua")]

        warnings = self._warnings(folder, custom_scripts=declared)
        collected = self._collected(folder, custom_scripts=declared)

        self.assertTrue(any("veaf-spawn-data.lua" in w for w in warnings))
        self.assertEqual([key for key in collected if key.endswith("veaf-spawn-data.lua")], [])

    def test_a_real_v5_residue_is_untouched(self) -> None:
        folder = self._folder_with("veafSecurity.lua")

        warnings = self._warnings(folder)
        collected = self._collected(folder)

        self.assertTrue(any("Unexpected Lua file" in w and "veafSecurity.lua" in w for w in warnings))
        self.assertTrue(
            any(key.endswith("veafSecurity.lua") for key in collected),
            "an unexpected script is still embedded — only generated artifacts are dropped",
        )


class TestCustomScriptsLoadTrigger(unittest.TestCase):
    """Tests for _resolves_load_trigger() — custom script trigger generation logic."""

    def _make_worker_with_scripts(
        self,
        custom_scripts: list[CustomScript],
        global_trigger: bool = True,
    ) -> MissionBuilderWorker:
        return make_worker(
            custom_scripts=custom_scripts,
            custom_scripts_generate_load_trigger=global_trigger,
        )

    def test_undeclared_file_always_triggers(self) -> None:
        """A file not in custom_scripts always gets a load trigger."""
        worker = self._make_worker_with_scripts([])
        self.assertTrue(worker._resolves_load_trigger("anything.lua"))

    def test_declared_script_uses_global_default_when_no_override(self) -> None:
        """Declared script with no per-script override follows the global default."""
        worker = self._make_worker_with_scripts(
            [CustomScript(path="FgMission.lua")],
            global_trigger=False,
        )
        self.assertFalse(worker._resolves_load_trigger("FgMission.lua"))

    def test_per_script_override_takes_precedence_over_global(self) -> None:
        """Per-script generate_load_trigger overrides the global default."""
        worker = self._make_worker_with_scripts(
            [CustomScript(path="FgMission.lua", generate_load_trigger=False)],
            global_trigger=True,
        )
        self.assertFalse(worker._resolves_load_trigger("FgMission.lua"))

    def test_per_script_true_overrides_global_false(self) -> None:
        """Per-script True overrides global False."""
        worker = self._make_worker_with_scripts(
            [CustomScript(path="FgMission.lua", generate_load_trigger=True)],
            global_trigger=False,
        )
        self.assertTrue(worker._resolves_load_trigger("FgMission.lua"))

    def test_global_default_true_applies_to_all_declared(self) -> None:
        """With global default True and no per-script override, all declared scripts trigger."""
        worker = self._make_worker_with_scripts(
            [CustomScript(path="A.lua"), CustomScript(path="B.lua")],
            global_trigger=True,
        )
        self.assertTrue(worker._resolves_load_trigger("A.lua"))
        self.assertTrue(worker._resolves_load_trigger("B.lua"))

    def test_global_default_false_with_one_override_true(self) -> None:
        """Only the script with explicit True triggers when global is False."""
        worker = self._make_worker_with_scripts(
            [
                CustomScript(path="A.lua"),
                CustomScript(path="B.lua", generate_load_trigger=True),
            ],
            global_trigger=False,
        )
        self.assertFalse(worker._resolves_load_trigger("A.lua"))
        self.assertTrue(worker._resolves_load_trigger("B.lua"))


class TestShippedVersionsDefaultIsNotADemo(unittest.TestCase):
    """The shipped default versions.yaml is copied into every from-scratch mission, so it must not be
    the seven-variant tutorial that turned one noon mission into a night one (FIX-SCRATCH-MISSION-
    PLAYABLE ticket 04). It ships a single midday variant; the tutorial lives commented out below it.
    """

    def _shipped_default(self) -> Path:
        here = Path(__file__).resolve()
        root = next(p for p in here.parents if (p / "src" / "defaults").is_dir())
        return root / "src" / "defaults" / "mission-folder" / "src" / "versions.yaml"

    def test_it_declares_exactly_one_active_variant_at_noon(self) -> None:
        import yaml

        raw = yaml.safe_load(self._shipped_default().read_text(encoding="utf-8"))
        versions = raw["versions"]
        self.assertEqual(len(versions), 1, f"a from-scratch mission must build one mission, got {versions}")
        self.assertEqual(versions[0]["time"], "12:00", "the single shipped variant must be midday, not dawn")

    def test_the_demo_variants_are_commented_out_not_active(self) -> None:
        # dawn-auto is the night start that reached David; it may survive as a commented example but
        # never as a live entry the build would produce.
        text = self._shipped_default().read_text(encoding="utf-8")
        self.assertNotIn("\n  - name: dawn-auto", text, "dawn-auto must not be an active variant")
        self.assertIn("dawn-auto", text, "the tutorial should remain, commented, so the feature stays discoverable")


if __name__ == "__main__":
    unittest.main()
