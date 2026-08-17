"""A setting `convert-v5` cannot carry must be visible where the mission maker looks (#725).

`convert-v5` generates `mission-script.lua` from scratch and deletes `missionConfig.lua`. Measured
by Sharko on his campaign corpus, **14 of 28 scalar keys** reached neither `mission.yaml` nor the
generated Lua — security passwords and IADS timing among them — and nothing said so. The shipped
`mission-script.lua` was **349 bytes: 8 header lines, no code**.

The information was never missing, which is what makes this cheap: the standalone `migrate-config`
command writes the migrated buffer, where unrecognised lines survive as commented-out code, while
`convert-v5` throws that buffer away. These tests pin the two places a mission maker will actually
look: the generated file, and the conversion report.
"""

from mission_builder.config_migrator import ConfigMigrator, MigrationResult
from mission_builder.v5_converter import _generate_mission_script


class TestTheGeneratedLuaNamesThem:
    def test_an_unmigrated_setting_appears_verbatim(self) -> None:
        # Verbatim, because the author has to be able to uncomment it: a list of key names would
        # tell them what broke without telling them what to put back.
        result = MigrationResult(new_content="", not_migrated=["veafSkynet.DelayForStartup = 150"])
        produced = _generate_mission_script(result, "6.14.3")
        assert "-- veafSkynet.DelayForStartup = 150" in produced

    def test_the_block_says_what_the_reader_should_do(self) -> None:
        result = MigrationResult(new_content="", not_migrated=['veafRadio.RadioMenuName = "BFR"'])
        produced = _generate_mission_script(result, "6.14.3")
        assert "Settings NOT migrated" in produced
        assert "no longer apply" in produced

    def test_a_clean_conversion_gains_no_block(self) -> None:
        # The counter-case that keeps the file readable: a mission whose settings all migrated must
        # not carry a scary empty section.
        produced = _generate_mission_script(MigrationResult(new_content=""), "6.14.3")
        assert "Settings NOT migrated" not in produced

    def test_the_file_is_no_longer_a_bare_header_when_something_was_dropped(self) -> None:
        # The measured symptom: 349 bytes, 8 header lines, no code, on a mission that had lost 14
        # settings. Whatever else changes, that must stop being true.
        bare = len(_generate_mission_script(MigrationResult(new_content=""), "6.14.3"))
        with_losses = len(
            _generate_mission_script(
                MigrationResult(new_content="", not_migrated=["veaf.DO_NOT_EXPORT_JSON_FILES = true"]),
                "6.14.3",
            )
        )
        assert with_losses > bare


class TestTheWholeChain:
    """From v5 source text to the file that ships, with no hand-built MigrationResult."""

    def test_a_dropped_setting_survives_migrate_and_reaches_the_generated_file(self) -> None:
        content = (
            'veaf.config.MISSION_NAME = "Test"\n'  # carried by a named extractor
            "veafSkynet.DelayForStartup = 150\n"  # carried by module_settings (ticket 04)
            "veafSkynet.SomeTable = { a = 1 }\n"  # no key can express this — must be reported
        )
        result = ConfigMigrator().migrate(content)
        produced = _generate_mission_script(result, "6.14.3")

        assert "veafSkynet.SomeTable" in produced
        assert "MISSION_NAME" not in produced, "a carried setting must not be reported as lost"
        assert "DelayForStartup" not in produced, "a setting ticket 04 carries must not be reported as lost"
