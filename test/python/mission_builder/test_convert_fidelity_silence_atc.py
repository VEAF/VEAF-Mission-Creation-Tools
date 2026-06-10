"""CONVERT-FIDELITY-003 — silence ATC on all airbases."""

from __future__ import annotations

from mission_builder.config_migrator import ConfigMigrator, MigrationResult


class TestSilenceAtcExtraction:
    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    def test_active_call_detected(self) -> None:
        result = self.m.migrate("veaf.silenceAtcOnAllAirbases()\n")
        assert result.silence_atc is True

    def test_commented_call_not_detected(self) -> None:
        result = self.m.migrate("-- veaf.silenceAtcOnAllAirbases()\n")
        assert result.silence_atc is False

    def test_absent_call_is_false(self) -> None:
        result = self.m.migrate("-- nothing here\n")
        assert result.silence_atc is False

    def test_active_call_is_commented_out(self) -> None:
        result = self.m.migrate("veaf.silenceAtcOnAllAirbases()\n")
        assert "-- [v6 extracted to mission.yaml] veaf.silenceAtcOnAllAirbases()" in result.new_content

    def test_partial_result_field_propagates(self) -> None:
        partial = MigrationResult(new_content="")
        self.m._extract_identity_and_security("veaf.silenceAtcOnAllAirbases()\n", partial)
        assert partial.silence_atc is True
