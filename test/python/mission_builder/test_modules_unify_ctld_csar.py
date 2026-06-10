"""MODULES-UNIFY-004 — extract CTLD/CSAR settings from missionConfig.lua."""

from __future__ import annotations

from mission_builder.config_migrator import ConfigMigrator, MigrationResult


class TestExtractCtldCsar:
    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    def test_ctld_scalar_settings_extracted(self) -> None:
        content = "ctld.hoverPickup = true\nctld.maximumDistanceLimit = 200\nctld.unitLoadList = \"foo\"\n"
        result = MigrationResult(new_content="")
        self.m._extract_ctld_csar(content, result)
        assert result.ctld_config == {
            "hoverPickup": True,
            "maximumDistanceLimit": 200,
            "unitLoadList": "foo",
        }

    def test_csar_settings_extracted(self) -> None:
        content = "csar.enableAllslots = true\ncsar.csarOftenInzone = 10\n"
        result = MigrationResult(new_content="")
        self.m._extract_ctld_csar(content, result)
        assert result.csar_config == {"enableAllslots": True, "csarOftenInzone": 10}

    def test_extracted_lines_are_commented_out(self) -> None:
        content = "ctld.hoverPickup = true\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_ctld_csar(content, result)
        assert "-- [v6 extracted to mission.yaml] ctld.hoverPickup = true" in new_content
        assert "\nctld.hoverPickup = true" not in new_content

    def test_initialize_and_functions_left_untouched(self) -> None:
        content = "ctld.initialize()\nctld.addCallback = function() end\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_ctld_csar(content, result)
        assert result.ctld_config == {}
        assert "ctld.initialize()" in new_content
        assert "-- [v6 extracted" not in new_content

    def test_inline_comment_tolerated(self) -> None:
        content = "ctld.maximumDistanceLimit = 200 -- meters\n"
        result = MigrationResult(new_content="")
        self.m._extract_ctld_csar(content, result)
        assert result.ctld_config == {"maximumDistanceLimit": 200}

    def test_no_assignments_leaves_empty_dicts(self) -> None:
        result = MigrationResult(new_content="")
        self.m._extract_ctld_csar("-- nothing here\n", result)
        assert result.ctld_config == {}
        assert result.csar_config == {}
