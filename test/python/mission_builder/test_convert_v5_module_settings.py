"""The fourteen scalar settings `convert-v5` used to drop (#725, ticket 04).

Measured by Sharko: of 28 scalar keys in `missionConfig.lua`, **14 reached neither `mission.yaml`
nor the generated Lua**, security passwords and IADS timing among them. Ticket 02 made the loss
*visible*; this one makes it stop happening.

Two shapes, deliberately:

- **`module_settings:`** — a generic carrier keyed by the Lua target (`veafSkynet.DelayForStartup`).
  Named keys per module would have covered the fourteen we know about and nothing else; the corpus
  they were measured on is one mission maker's, and he said so explicitly. A generic carrier ends
  the whole class.
- **Passwords keep their own home**, `security.password_hashes`, which already existed. They are
  not a scalar like the others: `veafSecurity.lua` ships hashes common to every mission in a public
  repository, and copying one into a mission's own list would re-open what `VMR-040` closed.
"""

from mission_builder.config_migrator import ConfigMigrator
from veaf_libs.lua_config_generator import generate_config_lua

#: The hashes `veafSecurity.lua:156-159` ships to every mission — public, and never a secret.
_SHIPPED_L0 = "47c7808d1079fd20add322bbd5cf23b93ad1841e"
_SHIPPED_L1 = "bdc82f5ef92369919a3a53515023ce19f68656cc"


class TestModuleSettingsAreCarried:
    def test_an_iads_setting_reaches_mission_yaml(self) -> None:
        result = ConfigMigrator().migrate("veafSkynet.DelayForStartup = 150\n")
        assert result.module_settings.get("veafSkynet.DelayForStartup") == 150

    def test_a_string_setting_keeps_its_value(self) -> None:
        result = ConfigMigrator().migrate('veafRadio.RadioMenuName = "BFR"\n')
        assert result.module_settings.get("veafRadio.RadioMenuName") == "BFR"

    def test_a_boolean_setting_keeps_its_type(self) -> None:
        result = ConfigMigrator().migrate("veafSpawn.HideRadioMenu = true\n")
        assert result.module_settings.get("veafSpawn.HideRadioMenu") is True

    def test_a_carried_setting_is_no_longer_reported_as_lost(self) -> None:
        # The two tickets have to cover the fourteen between them, with nothing falling in the gap
        # — and nothing counted twice either, which would tell the author to fix what is fixed.
        result = ConfigMigrator().migrate("veafSkynet.DynamicSpawn = true\n")
        assert result.module_settings
        assert not any("DynamicSpawn" in line for line in result.not_migrated)

    def test_it_reaches_the_generated_lua(self) -> None:
        produced = generate_config_lua({"module_settings": {"veafSkynet.DelayForStartup": 150}})
        assert "veafSkynet.DelayForStartup = 150" in produced

    def test_a_string_is_quoted_in_the_generated_lua(self) -> None:
        produced = generate_config_lua({"module_settings": {"veafRadio.RadioMenuName": "BFR"}})
        assert 'veafRadio.RadioMenuName = "BFR"' in produced

    def test_a_mission_with_none_gains_no_block(self) -> None:
        assert "module_settings" not in generate_config_lua({})

    def test_a_key_that_is_not_a_veaf_table_is_refused(self) -> None:
        # The carrier is generic, not a hatch for arbitrary Lua: a key naming something outside the
        # VEAF namespace would let a mission.yaml write anywhere in the runtime.
        import pytest

        with pytest.raises(ValueError, match="module_settings"):
            generate_config_lua({"module_settings": {"os.exit": 1}})


class TestPasswordsGoToTheirOwnHome:
    def test_a_custom_hash_reaches_password_hashes(self) -> None:
        content = f'veafSecurity.password_L1 = {{}}\nveafSecurity.password_L1["{"a" * 40}"] = true\n'
        result = ConfigMigrator().migrate(content)
        assert "a" * 40 in result.password_hashes

    def test_the_shipped_public_hashes_are_never_carried(self) -> None:
        # THE regression test of this ticket. `veafSecurity.lua` ships these two to every mission,
        # in a public repository; `SECREV-2 / VMR-040` closed that by clearing the tables when a
        # mission declares its own. Carrying one back would re-open it — silently, and in the file
        # a mission maker commits.
        for shipped in (_SHIPPED_L0, _SHIPPED_L1):
            result = ConfigMigrator().migrate(f'veafSecurity.password_L1["{shipped}"] = true\n')
            assert shipped not in result.password_hashes, f"{shipped} is the framework's own hash"

    def test_a_mission_declaring_only_the_shipped_hash_declares_nothing(self) -> None:
        result = ConfigMigrator().migrate(f'veafSecurity.password_L1["{_SHIPPED_L1}"] = true\n')
        assert result.password_hashes == []

    def test_the_constant_alone_is_not_a_password(self) -> None:
        # Reassigning veafSecurity.PASSWORD_L1 did nothing in v5: password_L1[PASSWORD_L1] = true
        # runs at module load, before the mission config executes. Treating it as a password would
        # invent one the mission never had.
        result = ConfigMigrator().migrate('veafSecurity.PASSWORD_L1 = "%s"\n' % ("b" * 40))
        assert result.password_hashes == []
