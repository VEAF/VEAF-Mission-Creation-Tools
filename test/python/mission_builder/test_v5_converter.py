"""Tests for v5_converter — ConversionReport.to_markdown() and V5Converter.convert()."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.config_migrator import MigrationResult
from mission_builder.v5_converter import ConversionReport, PipelineFile, V5Converter
from veaf_libs.i18n import current_language, set_language, t

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
        pf = PipelineFile(
            step="presets",
            path=folder / "src" / "radioSettings.lua",
            relative="src/presets.yaml",
            converted=True,
            v5_source="src/radioSettings.lua",
        )
        return ConversionReport(
            mission_folder=folder,
            timestamp="2024-01-01 12:00",
            version="test",
            missionconfig_path=mc_path,
            missionconfig_backup=bak_path,
            missionconfig_output=mc_path,
            migration_result=mr,
            pipeline_files=[pf],
        )

    def test_markdown_uses_localized_scan_headers(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertIn(t("report.section.scan"), md)
            self.assertIn(t("report.scan.col.item"), md)
            self.assertIn(t("report.scan.col.status"), md)

    def test_markdown_uses_localized_pipeline_scan_status(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            # Converted pipeline file shows localized status in scan table
            self.assertIn(t("report.scan.pipeline.converted"), md)

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
# V5Converter._build_mission_yaml() — doc links and structure
# ---------------------------------------------------------------------------


class TestBuildMissionYamlDocLinks(unittest.TestCase):
    """_build_mission_yaml must embed correct doc links in generated mission.yaml."""

    def _build_yaml(self) -> str:
        from mission_builder.v5_converter import V5Converter

        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            report = ConversionReport(mission_folder=folder, timestamp="2024-01-01 12:00", version="test")
            return V5Converter(version="test")._build_mission_yaml(report)

    def test_header_doc_url_is_correct(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("doc/mission-maker/GUIDE.en.md", yaml)
        self.assertNotIn("doc/MISSION_MAKER_GUIDE", yaml)

    def test_module_section_has_doc_link(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("#configuring-modules", yaml)

    def test_pipeline_section_has_doc_link(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("#build-profiles", yaml)

    def test_mandatory_modules_explanation_present(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("Mandatory modules", yaml)


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

    def _make_community_folder(self, folder: Path, filenames: list[str]) -> None:
        comm_dir = folder / "published" / "src" / "scripts" / "community"
        comm_dir.mkdir(parents=True)
        for name in filenames:
            (comm_dir / name).write_text("-- stub\n", encoding="utf-8")

    def test_scan_detects_present_community_scripts(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            self._make_community_folder(folder, ["mist.lua", "CTLD.lua"])
            report = V5Converter().convert(folder, backup=False)
            self.assertIn("mist", report.detected_community_script_ids)
            self.assertIn("ctld", report.detected_community_script_ids)
            self.assertNotIn("skynet", report.detected_community_script_ids)

    def test_scan_no_community_folder_yields_empty_set(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            report = V5Converter().convert(folder, backup=False)
            self.assertEqual(report.detected_community_script_ids, set())

    def test_mission_yaml_community_scripts_section_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            self._make_community_folder(folder, ["mist.lua", "CTLD.lua"])
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("community_scripts:", yaml_content)
            self.assertIn("mist: {enabled: true}", yaml_content)
            self.assertIn("ctld: {enabled: true}", yaml_content)
            self.assertIn("skynet: {enabled: false}", yaml_content)

    def test_mission_yaml_community_scripts_all_false_when_no_community_folder(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("community_scripts:", yaml_content)
            self.assertNotIn("enabled: true", yaml_content.split("community_scripts:")[1].split("# ──")[0])
    def test_mission_yaml_global_log_level_defaults_to_info(self) -> None:
        """When no global_log_level is found in missionConfig, generated yaml uses 'info' not 'debug'."""
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- no log level here\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            log_line = next((l for l in yaml_content.splitlines() if "global_log_level" in l and not l.strip().startswith("#")), None)
            self.assertIsNotNone(log_line)
            self.assertEqual(log_line.strip(), "global_log_level: info")


# ---------------------------------------------------------------------------
# IMC-002 — annotated missionConfig.lua embedded in report
# ---------------------------------------------------------------------------


class TestConversionReportAnnotatedContent(unittest.TestCase):
    """to_markdown() embeds annotated content as a Lua code block (IMC-002)."""

    def setUp(self) -> None:
        self._prev_lang = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev_lang)

    def test_annotated_section_present_when_content_set(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), timestamp="2024-01-01 12:00", version="1.0.0")
            report.missionconfig_annotated_content = "-- [v6 migrated]\nlocal x = 1"
            md = report.to_markdown()
            self.assertIn("~~~~lua", md)
            self.assertIn("-- [v6 migrated]", md)
            self.assertIn("local x = 1", md)

    def test_annotated_section_absent_when_empty(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), timestamp="2024-01-01 12:00", version="1.0.0")
            md = report.to_markdown()
            # No annotated content → no tilde fenced code block
            self.assertNotIn("~~~~lua", md)

    def test_annotated_section_title_in_report(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), timestamp="2024-01-01 12:00", version="1.0.0")
            report.missionconfig_annotated_content = "-- [v6 foo]"
            md = report.to_markdown()
            self.assertIn(t("report.section.annotated_config"), md)


# ---------------------------------------------------------------------------
# BAK-004 — backup uses src.name (no .bak extension)
# ---------------------------------------------------------------------------


class TestMigrateConfigBackupNoBak(unittest.TestCase):
    """_migrate_config() backup must create missionConfig.lua, not missionConfig.lua.bak."""

    def test_backup_creates_lua_not_bak(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            scripts_dir = folder / "src" / "scripts"
            scripts_dir.mkdir(parents=True)
            mc = scripts_dir / "missionConfig.lua"
            mc.write_text("-- test\n", encoding="utf-8")
            V5Converter().convert(folder, backup=True)
            bak = folder / "backup_v5" / "src" / "scripts" / "missionConfig.lua"
            bak_old = folder / "backup_v5" / "src" / "scripts" / "missionConfig.lua.bak"
            self.assertTrue(bak.exists(), "backup_v5/.../missionConfig.lua should exist")
            self.assertFalse(bak_old.exists(), "missionConfig.lua.bak must NOT exist")


if __name__ == "__main__":
    unittest.main()
