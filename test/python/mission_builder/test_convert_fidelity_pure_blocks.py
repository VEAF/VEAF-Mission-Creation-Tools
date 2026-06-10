"""CONVERT-FIDELITY-002 — fully comment out pure init blocks."""

from __future__ import annotations

from mission_builder.config_migrator import ConfigMigrator


class TestPureInitBlocks:
    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    def test_pure_block_fully_commented(self) -> None:
        content = "if veafSpawn then\n  veafSpawn.initialize()\nend\n"
        out = self.m.migrate(content).new_content
        lines = [line for line in out.splitlines() if line.strip()]
        # Every non-blank line of the block is commented out.
        assert all(line.lstrip().startswith("--") for line in lines), out
        assert "-- [v6 migration] if veafSpawn then" in out
        assert "-- [v6 migration] end" in out

    def test_module_still_recorded_as_enabled(self) -> None:
        content = "if veafSpawn then\n  veafSpawn.initialize()\nend\n"
        result = self.m.migrate(content)
        assert "SPAWN" in result.enabled_modules

    def test_block_with_custom_code_is_not_fully_commented(self) -> None:
        # A non-migrated custom assignment keeps the block visible (only the
        # initialize() line is commented by the existing logic).
        content = 'if veafSpawn then\n  veafSpawn.initialize()\n  veafSpawn.SpawnKeyphrase = "_spawn"\nend\n'
        out = self.m.migrate(content).new_content
        assert 'veafSpawn.SpawnKeyphrase = "_spawn"' in out
        # The guard line stays active (not commented as a migration block).
        assert "if veafSpawn then" in out
        assert "-- [v6 migration] if veafSpawn then" not in out

    def test_block_with_already_extracted_config_is_pure(self) -> None:
        # Config already extracted by pre_extract (now a comment) keeps the block pure.
        content = "if veafSpawn then\n  veafSpawn.initialize()\n  -- [v6 extracted to mission.yaml] foo = 1\nend\n"
        out = self.m.migrate(content).new_content
        assert "-- [v6 migration] if veafSpawn then" in out
