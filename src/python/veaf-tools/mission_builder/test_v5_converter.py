"""Tests for v5_converter — ConversionReport.to_markdown() and V5Converter.convert()."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_libs.i18n import current_language, set_language

from mission_builder.config_migrator import MigrationResult
from mission_builder.v5_converter import ConversionReport, PipelineFile, V5Converter

# ---------------------------------------------------------------------------
# ConversionReport.to_markdown() — empty / minimal state
# ---------------------------------------------------------------------------


class TestConversionReportToMarkdownEmpty(unittest.TestCase):
    """to_markdown() with mostly empty report state."""

    def setUp(self) -> None:
        self._prev_lang = current_language()
        set_language("fr")

    def tearDown(self) -> None:
        set_language(self._prev_lang)

    def _make_report(self, folder: Path) -> ConversionReport:
        return ConversionReport(mission_folder=folder, timestamp="2024-01-01 12:00", version="1.0.0")

    def test_contains_mission_folder(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            md = self._make_report(folder).to_markdown()
            self.assertIn(str(folder), md)

    def test_no_missionconfig_shows_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            # In FR mode, the scan table shows "Introuvable" and the actions section also
            # uses report.missionconfig.not_found → "Fichier introuvable …"
            self.assertIn("Introuvable", md)

    def test_mission_yaml_not_generated_row(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("mission.yaml", md)

    def test_warnings_section_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("Avertissements", md)

    def test_doc_links_section(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("https://", md)

    def test_no_missionconfig_skipped_section(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("missionConfig.lua", md)

    def test_cleanup_none_when_empty(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("supprimer", md)

    def test_next_steps_section(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._make_report(Path(td)).to_markdown()
            self.assertIn("Prochaines", md)


# ---------------------------------------------------------------------------
# ConversionReport.to_markdown() — rich state
# ---------------------------------------------------------------------------


class TestConversionReportToMarkdownWithMigration(unittest.TestCase):
    """to_markdown() when missionConfig.lua was found and migrated."""

    def setUp(self) -> None:
        self._prev_lang = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev_lang)

    def _rich_report(self, folder: Path) -> ConversionReport:
        scripts_dir = folder / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        mc_path = scripts_dir / "missionConfig.lua"
        mc_path.touch()
        bak_path = scripts_dir / "missionConfig.lua.bak"
        bak_path.touch()
        mr = MigrationResult(
            new_content="",
            removed_dofiles=['line1: doFile("foo.lua")'],
            wrapped_calls=["line2: veafRadio.initialize()"],
            enabled_modules=["RADIO", "SPAWN"],
        )
        return ConversionReport(
            mission_folder=folder,
            timestamp="2024-01-01 12:00",
            version="test",
            missionconfig_path=mc_path,
            missionconfig_backup=bak_path,
            missionconfig_output=mc_path,
            migration_result=mr,
        )

    def test_removed_dofiles_listed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertIn("doFile", md)

    def test_wrapped_calls_listed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertIn("initialize()", md)

    def test_enabled_modules_listed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertIn("RADIO", md)

    def test_backup_path_in_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertIn(".bak", md)

    def test_mission_yaml_generated_section(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            yaml_path = folder / "mission.yaml"
            yaml_path.touch()
            mr = MigrationResult(new_content="", enabled_modules=["RADIO"])
            pf = PipelineFile(step="presets", path=folder / "src" / "presets.yaml", relative="src/presets.yaml")
            report = ConversionReport(
                mission_folder=folder,
                timestamp="2024-01-01 12:00",
                version="test",
                migration_result=mr,
                mission_yaml_generated=True,
                mission_yaml_path=yaml_path,
                pipeline_files=[pf],
            )
            md = report.to_markdown()
            self.assertIn("mission.yaml", md)
            self.assertIn("Generated", md)

    def test_mission_yaml_existed_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            report = ConversionReport(
                mission_folder=folder,
                mission_yaml_existed=True,
                mission_yaml_skipped_reason="Already exists",
            )
            md = report.to_markdown()
            self.assertIn("Already exists", md)

    def test_warnings_listed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), warnings=["something smells wrong"])
            md = report.to_markdown()
            self.assertIn("something smells wrong", md)

    def test_backup_v5_sources_in_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(
                mission_folder=Path(td),
                backup_v5_sources=["src/radio/radioSettings.lua"],
            )
            md = report.to_markdown()
            self.assertIn("radioSettings.lua", md)

    def test_pipeline_converted_shown(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            pf = PipelineFile(
                step="presets",
                path=folder / "src" / "presets.yaml",
                relative="src/presets.yaml",
                converted=True,
                v5_source="src/radio/radioSettings.lua",
            )
            report = ConversionReport(mission_folder=folder, pipeline_files=[pf])
            md = report.to_markdown()
            self.assertIn("presets.yaml", md)

    def test_pipeline_needs_conversion_shown(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            radio_dir = folder / "src" / "radio"
            radio_dir.mkdir(parents=True)
            (radio_dir / "radioSettings.lua").write_text("radioPresetsBlue = {}\n", encoding="utf-8")
            report = ConversionReport(
                mission_folder=folder,
                pipeline_files=[
                    PipelineFile(
                        step="presets",
                        path=radio_dir / "radioSettings.lua",
                        relative="src/radio/radioSettings.lua",
                        needs_conversion=True,
                        v6_target="src/presets.yaml",
                    )
                ],
            )
            md = report.to_markdown()
            self.assertIn("radioSettings.lua", md)


# ---------------------------------------------------------------------------
# V5Converter.convert() — integration tests
# ---------------------------------------------------------------------------


class TestV5ConverterIntegration(unittest.TestCase):
    """Full V5Converter.convert() integration tests with temp directories."""

    def _make_missionconfig(self, folder: Path, content: str) -> Path:
        scripts_dir = folder / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        mc = scripts_dir / "missionConfig.lua"
        mc.write_text(content, encoding="utf-8")
        return mc

    def test_convert_creates_mission_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'veaf.config.MISSION_NAME = "TestMission"\n')
            report = V5Converter(version="test-1.0").convert(folder)
            self.assertTrue(report.mission_yaml_generated)
            self.assertTrue((folder / "mission.yaml").exists())

    def test_convert_migrates_dofiles(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'doFile("veaf-scripts.lua")\n')
            report = V5Converter().convert(folder, backup=False)
            assert report.migration_result is not None
            self.assertGreater(len(report.migration_result.removed_dofiles), 0)

    def test_convert_wraps_bare_initialize(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veafRadio.initialize()\n")
            report = V5Converter().convert(folder, backup=False)
            assert report.migration_result is not None
            self.assertGreater(len(report.migration_result.wrapped_calls), 0)

    def test_convert_renames_missionconfig_to_mission_script(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            mc = self._make_missionconfig(folder, "-- empty\n")
            V5Converter().convert(folder, backup=False)
            self.assertFalse(mc.exists(), "missionConfig.lua should be renamed")
            self.assertTrue((mc.parent / "mission-script.lua").exists())

    def test_convert_no_missionconfig_emits_warning(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            report = V5Converter().convert(folder)
            self.assertTrue(any("missionConfig.lua not found" in w for w in report.warnings))

    def test_convert_backup_creates_bak(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- backup test\n")
            report = V5Converter().convert(folder, backup=True)
            self.assertIsNotNone(report.missionconfig_backup)

    def test_convert_no_backup_when_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- no backup\n")
            report = V5Converter().convert(folder, backup=False)
            self.assertIsNone(report.missionconfig_backup)

    def test_convert_respects_existing_mission_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            existing_yaml = folder / "mission.yaml"
            existing_yaml.write_text("# existing\n", encoding="utf-8")
            self._make_missionconfig(folder, "-- test\n")
            report = V5Converter().convert(folder)
            self.assertTrue(report.mission_yaml_existed)
            self.assertFalse(report.mission_yaml_generated)
            self.assertEqual(existing_yaml.read_text(), "# existing\n")

    def test_convert_overwrite_flag_overwrites_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            existing_yaml = folder / "mission.yaml"
            existing_yaml.write_text("# old\n", encoding="utf-8")
            self._make_missionconfig(folder, "-- test\n")
            report = V5Converter().convert(folder, overwrite_mission_yaml=True)
            self.assertTrue(report.mission_yaml_generated)
            self.assertNotEqual(existing_yaml.read_text(), "# old\n")

    def test_convert_pipeline_files_detected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "src").mkdir()
            (folder / "src" / "presets.yaml").write_text("# presets\n", encoding="utf-8")
            self._make_missionconfig(folder, "-- test\n")
            report = V5Converter().convert(folder, backup=False)
            steps = [pf.step for pf in report.pipeline_files]
            self.assertIn("presets", steps)

    def test_convert_report_has_actions(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'doFile("x.lua")\n')
            report = V5Converter().convert(folder, backup=False)
            self.assertGreater(len(report.actions), 0)

    def test_build_manual_review_dofiles(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            # Must contain "veaf" in path for _DOFILE_RE to match
            self._make_missionconfig(folder, 'doFile("veaf-scripts.lua")\nveafRadio.initialize()\n')
            report = V5Converter().convert(folder, backup=False)
            self.assertTrue(any("doFile" in item for item in report.manual_review))

    def test_convert_mission_yaml_contains_lua_modules(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veafRadio.initialize()\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("lua_modules:", yaml_content)

    def test_mission_yaml_contains_pipeline_section(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("pipeline", yaml_content)

    def test_to_markdown_after_full_convert(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'doFile("x.lua")\nveafSpawn.initialize()\n')
            report = V5Converter().convert(folder, backup=False)
            md = report.to_markdown()
            self.assertIsInstance(md, str)
            self.assertTrue(md.startswith("#"))

    def test_v5_pipeline_file_triggers_manual_review(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            radio_dir = folder / "src" / "radio"
            radio_dir.mkdir(parents=True)
            (radio_dir / "radioSettings.lua").write_text("radioPresetsBlue = {}\n", encoding="utf-8")
            self._make_missionconfig(folder, "-- test\n")
            report = V5Converter().convert(folder, backup=False, convert_pipeline=False)
            # The v5 presets file should trigger manual review when convert_pipeline=False
            steps_needing_conv = [pf.step for pf in report.pipeline_files if pf.needs_conversion]
            self.assertIn("presets", steps_needing_conv)

    def test_mission_yaml_security_section_when_extracted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veaf.SecurityDisabled = true\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("security:", yaml_content)
            self.assertIn("disabled: true", yaml_content)

    def test_mission_yaml_identity_section_when_name_extracted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'veaf.config.MISSION_NAME = "OpenTraining"\n')
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn('name: "OpenTraining"', yaml_content)


if __name__ == "__main__":
    unittest.main()
