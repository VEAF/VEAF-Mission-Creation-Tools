"""Tests for v5_converter — ConversionReport.to_markdown() and V5Converter.convert()."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from mission_builder.config_migrator import MigrationResult
from mission_builder.v5_converter import ConversionReport, PipelineFile, V5Converter
from veaf_libs.i18n import current_language, language, set_language, t

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

    def test_removed_dofiles_not_listed(self) -> None:
        # The commented doFile() lines live only in the migrated buffer convert-v5
        # discards, so they are no longer reported (CONVERT-V5-INIT-COMMENTED-NOISE).
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertNotIn("doFile", md)

    def test_wrapped_calls_not_listed(self) -> None:
        # Same for the bare initialize() calls wrapped in guards.
        with tempfile.TemporaryDirectory() as td:
            md = self._rich_report(Path(td)).to_markdown()
            self.assertNotIn("veafRadio.initialize()", md)

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
        with language("fr"):
            yaml = self._build_yaml()
        # Trailing slash before any fragment, language-aware base (DOC-GUIDE-ANCHORS).
        self.assertIn("veaf.github.io/documentation/dev/mission-maker/GUIDE/", yaml)
        self.assertNotIn("blob/master/doc", yaml)

    def test_module_section_has_doc_link(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("#configuring-modules", yaml)

    def test_pipeline_section_has_doc_link(self) -> None:
        yaml = self._build_yaml()
        self.assertIn("#build-profiles", yaml)

    def test_mandatory_modules_explanation_present(self) -> None:
        """Mandatory module explanation must appear (text is localized)."""
        from veaf_libs.i18n import t

        yaml = self._build_yaml()
        # Use the i18n key — works in any locale
        self.assertIn(t("converter.yaml.modules.desc2"), yaml)


class TestBuildMissionYamlSilenceAtcProvenance(unittest.TestCase):
    """FIX-MISSIONYAML-MISSION-SECTION: migrated silence_atc carries a provenance comment."""

    def test_silence_atc_emits_provenance_comment(self) -> None:
        from mission_builder.config_migrator import MigrationResult
        from mission_builder.v5_converter import V5Converter

        with tempfile.TemporaryDirectory() as td:
            mr = MigrationResult(new_content="", silence_atc=True)
            report = ConversionReport(mission_folder=Path(td), version="test", migration_result=mr)
            yaml = V5Converter(version="test")._build_mission_yaml(report)
        # The field is emitted under mission: with a provenance annotation.
        assert "silence_atc_on_all_airbases: true" in yaml
        assert "migrated from veaf.silenceAtcOnAllAirbases()" in yaml


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

    def test_convert_does_not_report_dofile_or_wrap_edits(self) -> None:
        # The doFile / bare-initialize() edits apply to the discarded migrated buffer,
        # so convert-v5 must not surface them in actions or manual review
        # (CONVERT-V5-INIT-COMMENTED-NOISE).
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'doFile("veaf-scripts.lua")\nveafRadio.initialize()\n')
            report = V5Converter().convert(folder, backup=False)
            joined = " ".join(report.actions + report.manual_review)
            self.assertNotIn("doFile", joined)

    def test_convert_omits_mission_script_action_when_empty(self) -> None:
        # No callbacks detected → mission-script.lua is an empty skeleton → no mention.
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veafRadio.initialize()\n")
            report = V5Converter().convert(folder, backup=False)
            self.assertNotIn("mission-script.lua", " ".join(report.actions))

    def test_convert_reports_mission_script_action_when_callbacks(self) -> None:
        # A detected callback is stubbed into mission-script.lua → it is worth mentioning.
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(
                folder,
                'AirWaveZone:new()\n    :setName("CB-Zone")\n    :setOnDeploy(myDeployFn)\n    :start()\n',
            )
            report = V5Converter().convert(folder, backup=False)
            assert report.migration_result is not None
            self.assertGreater(len(report.migration_result.callback_hints), 0)
            self.assertIn("mission-script.lua", " ".join(report.actions))

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

    def test_build_manual_review_omits_dofiles(self) -> None:
        # The "remove the commented doFile() lines" item is gone: those lines live only
        # in the discarded migrated buffer (CONVERT-V5-INIT-COMMENTED-NOISE).
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, 'doFile("veaf-scripts.lua")\nveafRadio.initialize()\n')
            report = V5Converter().convert(folder, backup=False)
            self.assertFalse(any("doFile" in item for item in report.manual_review))

    def test_convert_mission_yaml_contains_lua_modules(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veafRadio.initialize()\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("modules:", yaml_content)

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
            self.assertIn("name: OpenTraining", yaml_content)

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
            self.assertIn("modules:", yaml_content)
            self.assertIn("MIST: true", yaml_content)
            self.assertIn("CTLD: true", yaml_content)
            self.assertIn("SKYNET: false", yaml_content)

    def test_mission_yaml_unifies_skynet_and_qra_under_modules(self) -> None:
        # MODULES-UNIFY: no standalone external_modules:/qra: — SKYNET nested in
        # the community area, QRA config under modules.QRA.
        mission_config = (
            "veafSkynet.initialize(true, false, true, false)\n"
            "VeafQRA.ToggleAllSilence(false)\n"
            'local q = VeafQRA:new()\n  :setName("NorthQRA")\n  :setCoalition(coalition.side.RED)\n  :start()\n'
        )
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, mission_config)
            self._make_community_folder(folder, ["Skynet-IADS.lua"])
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            # No standalone sections any more
            self.assertNotIn("external_modules:", yaml_content)
            self.assertNotIn("\nqra:", yaml_content)
            # SKYNET nested in modules with its flags
            self.assertIn("  SKYNET:", yaml_content)
            self.assertIn("include_red_in_radio: true", yaml_content)
            # QRA nested under modules.QRA
            self.assertIn("definitions:", yaml_content)
            self.assertIn("NorthQRA", yaml_content)
            # Output round-trips through the unified-schema normalizer
            import yaml as _yaml

            from mission_builder.mission_builder_worker import _normalize_mission_yaml

            normalized = _normalize_mission_yaml(_yaml.safe_load(yaml_content))
            self.assertTrue(normalized["external_modules"]["skynet"]["include_red_in_radio"])
            self.assertEqual(normalized["qra"]["definitions"][0]["name"], "NorthQRA")

    def test_mission_yaml_ctld_settings_nested_under_modules(self) -> None:
        # MODULES-UNIFY-004: ctld.xxx assignments become modules.CTLD.settings.
        mission_config = "ctld.hoverPickup = true\nctld.maximumDistanceLimit = 200\n"
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, mission_config)
            self._make_community_folder(folder, ["CTLD.lua"])
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertNotIn("external_modules:", yaml_content)
            self.assertIn("  CTLD:", yaml_content)
            self.assertIn("    settings:", yaml_content)
            self.assertIn("hoverPickup: true", yaml_content)

            import yaml as _yaml

            from mission_builder.mission_builder_worker import _normalize_mission_yaml

            normalized = _normalize_mission_yaml(_yaml.safe_load(yaml_content))
            assert normalized["external_modules"]["ctld"]["hoverPickup"] is True
            assert normalized["external_modules"]["ctld"]["maximumDistanceLimit"] == 200

    def test_mission_yaml_optin_script_false_even_when_detected(self) -> None:
        # TUM-AUTOINIT: opt-in scripts (TUM) must be emitted as false even when the
        # community file is present, so a freshly converted v5 mission never auto-starts them.
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            self._make_community_folder(folder, ["mist.lua", "TheUniversalMission.lua"])
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("MIST: true", yaml_content)  # opt-out, detected → true
            self.assertIn("TUM: false", yaml_content)  # opt-in, even when detected → false
            self.assertNotIn("TUM: true", yaml_content)

    def test_mission_yaml_silence_atc_emitted_when_v5_active(self) -> None:
        # CONVERT-FIDELITY-003: an active call → mission.silence_atc_on_all_airbases: true.
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "veaf.silenceAtcOnAllAirbases()\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("silence_atc_on_all_airbases: true", yaml_content)

    def test_mission_yaml_silence_atc_absent_when_v5_inactive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- nothing\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertNotIn("silence_atc_on_all_airbases", yaml_content)

    def test_mission_yaml_community_scripts_all_false_when_no_community_folder(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, "-- test\n")
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertIn("modules:", yaml_content)
            # All community script IDs must appear with ": false" (no community folder → none detected)
            from mission_tools.mission_constants import get_community_script_files
            for script in get_community_script_files():
                sid = script["id"].upper()
                self.assertIn(f"  {sid}: false", yaml_content)
                self.assertNotIn(f"  {sid}: true", yaml_content)
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


class TestConversionReportNoAnnotatedBlock(unittest.TestCase):
    """The report no longer embeds a pseudo "annotated missionConfig.lua" Lua block
    (CONVERT-V5-REPORT-ANNOTATION); the migration is reported as line→effect tables."""

    def setUp(self) -> None:
        self._prev_lang = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev_lang)

    def test_no_annotated_lua_block_and_mapping_tables_present(self) -> None:
        from mission_builder.config_migrator import MigrationResult

        with tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), timestamp="2024-01-01 12:00", version="1.0.0")
            report.migration_result = MigrationResult(
                new_content="",
                enabled_modules=["RADIO"],
                removed_dofiles=["line 3: doFile('x.lua')"],
                wrapped_calls=["line 5: veafRadio.initialize()"],
            )
            md = report.to_markdown()
            # No pseudo-annotated Lua block anymore …
            self.assertNotIn("~~~~lua", md)
            # … and the doFile / bare-initialize() line→effect tables are gone too:
            # they described the migrated buffer convert-v5 discards
            # (CONVERT-V5-INIT-COMMENTED-NOISE). The detected modules stay.
            self.assertNotIn("line 3", md)
            self.assertNotIn("line 5", md)
            self.assertIn("RADIO", md)


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


# ---------------------------------------------------------------------------
# V5Converter._build_mission_yaml() — module dependency pre-resolution
# ---------------------------------------------------------------------------


class TestBuildMissionYamlDependencyResolution(unittest.TestCase):
    """convert-v5 must pre-resolve module dependencies in the generated mission.yaml."""

    def _build(self, enabled_modules: list[str]) -> tuple[str, ConversionReport]:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            mr = MigrationResult(new_content="", enabled_modules=enabled_modules)
            report = ConversionReport(mission_folder=folder, version="test", migration_result=mr)
            yaml = V5Converter(version="test")._build_mission_yaml(report)
            return yaml, report

    def test_casmission_pulls_in_groundai_and_spawn(self) -> None:
        yaml, report = self._build(["CASMISSION"])
        self.assertIn("CASMISSION", yaml)
        self.assertIn("GROUNDAI", yaml)
        self.assertIn("SPAWN", yaml)
        # Dependencies recorded so the conversion report can mention them
        self.assertIn("GROUNDAI", report.auto_resolved_deps)
        self.assertIn("SPAWN", report.auto_resolved_deps)

    def test_no_deps_recorded_when_none_needed(self) -> None:
        # RADIO has no dependencies; the always-on base set is self-consistent.
        _, report = self._build(["RADIO"])
        self.assertEqual(report.auto_resolved_deps, [])

    def test_report_mentions_resolved_dependencies(self) -> None:
        _, report = self._build(["CASMISSION"])
        report.mission_yaml_generated = True
        report.mission_yaml_path = report.mission_folder / "mission.yaml"
        markdown = report.to_markdown()
        note = t("report.mission_yaml.deps_resolved", list=", ".join(report.auto_resolved_deps))
        self.assertIn(note, markdown)
        # The auto-resolved module names appear in the rendered report
        self.assertIn("GROUNDAI", markdown)


class TestSummaryHeader(unittest.TestCase):
    """CONVERT-FIDELITY-004 — at-a-glance numeric summary header."""

    def setUp(self) -> None:
        self._prev = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev)

    def _report(self, **kwargs: object) -> ConversionReport:
        return ConversionReport(mission_folder=Path("/tmp/m"), timestamp="2024-01-01 12:00", version="1.0.0", **kwargs)

    def test_summary_precedes_folder_section(self) -> None:
        md = self._report().to_markdown()
        self.assertIn("## Summary", md)
        self.assertLess(md.index("## Summary"), md.index("## Mission Folder"))

    def test_module_count_reported(self) -> None:
        mr = MigrationResult(new_content="", enabled_modules=["SPAWN", "RADIO", "MOVE"])
        md = self._report(migration_result=mr).to_markdown()
        self.assertIn("3 modules migrated", md)

    def test_no_manual_action_when_clean(self) -> None:
        md = self._report().to_markdown()
        self.assertIn("Nothing needs manual action", md)

    def test_manual_action_count_and_lines(self) -> None:
        report = self._report(
            manual_review=["missionConfig.lua — line 12: review this", "line 30: and that"],
            warnings=["a generic warning with no line"],
        )
        md = report.to_markdown()
        self.assertIn("3 items need manual action", md)
        self.assertIn("lines: 12, 30", md)


class TestConversionReportPromotionSection(unittest.TestCase):
    """The report renders the src/mission v6 promotion (FEAT-MIGRATE-MISSION-V6)."""

    def setUp(self) -> None:
        self._prev_lang = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev_lang)

    def _report(self, **kwargs: object) -> ConversionReport:
        return ConversionReport(mission_folder=Path("."), timestamp="2024-01-01 12:00", version="1.0.0", **kwargs)  # type: ignore[arg-type]

    def test_promoted_renders_section_and_scan_row(self) -> None:
        md = self._report(
            promotion_attempted=True, promotion_done=True, promotion_backup="backup_v5/src/mission"
        ).to_markdown()
        self.assertIn(t("report.section.promotion"), md)
        self.assertIn(t("report.scan.promotion.done"), md)
        self.assertIn("backup_v5/src/mission", md)
        # the obsolete "DCS triggers — automatic" section is gone
        self.assertNotIn(t("report.triggers.auto"), md)

    def test_skipped_when_no_promote(self) -> None:
        md = self._report(promotion_attempted=False).to_markdown()
        self.assertIn(t("report.scan.promotion.skipped"), md)
        self.assertIn(t("report.promotion.skipped"), md)

    def test_failed_shows_reason(self) -> None:
        md = self._report(promotion_attempted=True, promotion_done=False, promotion_reason="boom").to_markdown()
        self.assertIn(t("report.scan.promotion.failed"), md)
        self.assertIn("boom", md)


class TestCleanupLegacyV5Files(unittest.TestCase):
    """convert-v5 triages leftover v5 files (CONVERT-V5-CLEANUP-FILES)."""

    def _run(self, layout: dict[str, str | None]) -> tuple[Path, ConversionReport]:
        """Create the given files (str content) / dirs (None) under a temp mission
        folder, run the cleanup, return the folder and report."""
        tmp = Path(tempfile.mkdtemp())
        for rel, content in layout.items():
            p = tmp / rel
            if content is None:
                p.mkdir(parents=True, exist_ok=True)
            else:
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(content, encoding="utf-8")
        report = ConversionReport(mission_folder=tmp)
        V5Converter(version="t")._cleanup_legacy_v5_files(report)
        return tmp, report

    def test_tooling_files_moved_to_backup(self) -> None:
        tmp, report = self._run(
            {"build.cmd": "x", "build-dev.cmd.sample": "s", "replace.ps1": "y", "package.json": "{}", "yarn.lock": "z"}
        )
        for name in ("build.cmd", "build-dev.cmd.sample", "replace.ps1", "package.json", "yarn.lock"):
            self.assertFalse((tmp / name).exists(), name)
            self.assertTrue((tmp / "backup_v5" / name).exists(), name)
            self.assertIn(name, report.legacy_tooling_backed_up)
        shutil.rmtree(tmp)

    def test_configuration_json_flagged_as_secret(self) -> None:
        tmp, report = self._run({"configuration.json": '{"checkwx_apikey": "abc"}'})
        self.assertIn("configuration.json", report.secret_tooling_files)
        self.assertTrue((tmp / "backup_v5" / "configuration.json").exists())
        shutil.rmtree(tmp)

    def test_regenerable_dirs_deleted_not_archived(self) -> None:
        tmp, report = self._run({"node_modules/pkg/index.js": "x", "build/out.miz": "m", "cache/w.json": "{}"})
        for d in ("node_modules", "build", "cache"):
            self.assertFalse((tmp / d).exists(), d)
            self.assertIn(f"{d}/", report.regenerable_deleted)
        self.assertFalse((tmp / "backup_v5" / "node_modules").exists())
        shutil.rmtree(tmp)

    def test_unrecognized_files_listed_not_touched(self) -> None:
        tmp, report = self._run({"todo.txt": "do", "readme.md": "hi"})
        for name in ("todo.txt", "readme.md"):
            self.assertTrue((tmp / name).exists(), name)
            self.assertIn(name, report.unrecognized_files)
        shutil.rmtree(tmp)

    def test_toolchain_binaries_are_not_listed_nor_touched(self) -> None:
        # The veaf-tools executables the maker runs from the folder must never be
        # flagged as "unrecognized" (suggesting to delete your own tools is absurd).
        tmp, report = self._run({"veaf-tools.exe": "x", "veaf-tools-updater.exe": "y", "stray.bin": "z"})
        for name in ("veaf-tools.exe", "veaf-tools-updater.exe"):
            self.assertTrue((tmp / name).exists(), name)
            self.assertNotIn(name, report.unrecognized_files)
            self.assertNotIn(name, report.legacy_tooling_backed_up)
        # An unrelated stray file is still listed.
        self.assertIn("stray.bin", report.unrecognized_files)
        shutil.rmtree(tmp)

    def test_toolchain_match_is_case_insensitive(self) -> None:
        # A mixed-case binary (alone, to avoid a case-insensitive-FS collision) must also
        # be skipped — the match is case-insensitive and platform-independent.
        tmp, report = self._run({"VEAF-Tools.EXE": "u"})
        self.assertNotIn("VEAF-Tools.EXE", report.unrecognized_files)
        shutil.rmtree(tmp)

    def test_protected_entries_never_touched(self) -> None:
        tmp, report = self._run(
            {
                ".git/config": "x",
                "mission.yaml": "modules:",
                "src/mission/mission": "m",
                "src/versions.yaml": "v",
                ".gitignore": "ig",
            }
        )
        self.assertTrue((tmp / ".git" / "config").exists())
        self.assertTrue((tmp / "mission.yaml").exists())
        self.assertTrue((tmp / "src" / "mission" / "mission").exists())
        flat = report.unrecognized_files + report.legacy_tooling_backed_up + report.regenerable_deleted
        for item in (".git", ".git/", "mission.yaml", "src/mission/", "src/versions.yaml", ".gitignore"):
            self.assertNotIn(item, flat)
        shutil.rmtree(tmp)

    def test_unrecognized_src_file_listed_known_v6_excluded(self) -> None:
        tmp, report = self._run({"src/leftover.txt": "x", "src/options": "o", "src/versions.yaml": "v"})
        self.assertIn("src/leftover.txt", report.unrecognized_files)
        self.assertNotIn("src/options", report.unrecognized_files)
        self.assertNotIn("src/versions.yaml", report.unrecognized_files)
        shutil.rmtree(tmp)

    def test_idempotent_second_run_finds_nothing(self) -> None:
        tmp, _ = self._run({"build.cmd": "x", "node_modules/p.js": "y"})
        report2 = ConversionReport(mission_folder=tmp)
        V5Converter(version="t")._cleanup_legacy_v5_files(report2)
        self.assertEqual(report2.legacy_tooling_backed_up, [])
        self.assertEqual(report2.regenerable_deleted, [])
        shutil.rmtree(tmp)


class TestGuideDocLinks(unittest.TestCase):
    """mission.yaml `# Doc:` links use a trailing slash + language-aware path so deep
    links resolve (DOC-GUIDE-ANCHORS)."""

    #: Stable explicit anchors the generator points at — declared on both GUIDE versions.
    _ANCHORS = (
        "#build-profiles",
        "#configuring-modules",
        "#configuration-examples",
        "#ctld-and-csar-integration",
        "#debug-logging",
    )

    def _yaml(self, lang: str) -> str:
        with language(lang), tempfile.TemporaryDirectory() as td:
            report = ConversionReport(mission_folder=Path(td), version="t")
            return V5Converter(version="t")._build_mission_yaml(report)

    def test_fr_links_have_slash_before_anchor(self) -> None:
        md = self._yaml("fr")
        self.assertIn("/dev/mission-maker/GUIDE/#build-profiles", md)
        self.assertNotIn("GUIDE#build-profiles", md)  # the old, broken form

    def test_en_links_use_the_en_path(self) -> None:
        md = self._yaml("en")
        self.assertIn("/dev/en/mission-maker/GUIDE/#build-profiles", md)
        self.assertNotIn("/dev/mission-maker/GUIDE/#build-profiles", md)

    def test_guide_files_declare_every_generator_anchor(self) -> None:
        root = Path(__file__).parents[3] / "doc" / "mission-maker"
        for name in ("GUIDE.md", "GUIDE.en.md"):
            text = (root / name).read_text(encoding="utf-8")
            for anchor in self._ANCHORS:
                self.assertIn(f"{{{anchor}}}", text, f"{name} is missing the explicit anchor {anchor}")

    def test_doc_lang_segment_maps_locale_to_path(self) -> None:
        from mission_builder.v5_converter import _doc_lang_segment

        self.assertEqual(_doc_lang_segment("en"), "en/")
        self.assertEqual(_doc_lang_segment("fr"), "")
