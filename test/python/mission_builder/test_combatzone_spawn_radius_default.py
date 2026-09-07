"""FEAT-COMBATZONE-ZONE-SPAWN-RADIUS — the dispersion default reaches the generated Lua.

Tripack places air defences in the revetments the Syria map draws for them, and a spawn that
scatters a launcher by tens of metres puts it on the berm instead of inside it. He asked for the
combat zone's dispersion default to be settable; on the YAML workflow it was settable **nowhere**,
since `veaf-config.lua` is generated and carries *"ne pas éditer manuellement"*.

**Every test here that matters asserts `0` specifically.** `0` is the value the feature exists for,
and every neighbouring key in `_emit_module_config` is read with `if x := cfg.get(...)` — a shape
that drops a falsy value in silence. The Lua side of this framework made the identical mistake with
`not 0`, which hid `#spawnradius=0` for three years (FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT). A
test that only checked `50` would pass against a generator that cannot express the one number asked
for.
"""

from veaf_libs.lua_config_generator import generate_config_lua

_ZONE = {"zone_name": "CMBT_PALMYRA", "friendly_name": "PALMYRA"}


def _config(settings: dict | None = None, zones: list | None = None) -> str:
    module: dict = {}
    if settings is not None:
        module["combat_zone_settings"] = settings
    if zones is not None:
        module["combat_zones"] = zones
    return generate_config_lua({"lua_modules": {"COMBATZONE": module}})


class TestMissionWideDefault:
    def test_zero_reaches_the_generated_lua(self) -> None:
        # The whole point of the ticket: a falsy value must survive the generator.
        assert "veafCombatZone.DefaultSpawnRadiusForUnits = 0" in _config({"default_spawn_radius": 0})

    def test_a_non_zero_value_reaches_it_too(self) -> None:
        assert "veafCombatZone.DefaultSpawnRadiusForUnits = 250" in _config({"default_spawn_radius": 250})

    def test_statics_have_their_own_key(self) -> None:
        # Two globals with two different built-in defaults (50 and 0). One key writing both would
        # silently start scattering the statics that are pinned today.
        produced = _config({"default_spawn_radius_statics": 30})
        assert "veafCombatZone.DefaultSpawnRadiusForStatics = 30" in produced
        assert "DefaultSpawnRadiusForUnits" not in produced

    def test_an_absent_key_emits_nothing(self) -> None:
        produced = _config({"radio_menu_name": "Combat Zones"})
        assert "DefaultSpawnRadius" not in produced

    def test_an_explicit_null_emits_nothing(self) -> None:
        # `default_spawn_radius:` with no value is a mission maker asking for the built-in default,
        # not for `nil` to be assigned over it.
        assert "DefaultSpawnRadius" not in _config({"default_spawn_radius": None})


class TestPerZoneDefault:
    def test_zero_reaches_the_zone_chain(self) -> None:
        produced = _config(zones=[{**_ZONE, "default_spawn_radius": 0}])
        assert ":setDefaultSpawnRadius(0)" in produced

    def test_a_non_zero_value_reaches_it_too(self) -> None:
        produced = _config(zones=[{**_ZONE, "default_spawn_radius": 120}])
        assert ":setDefaultSpawnRadius(120)" in produced

    def test_statics_have_their_own_key(self) -> None:
        produced = _config(zones=[{**_ZONE, "default_spawn_radius_statics": 15}])
        assert ":setDefaultSpawnRadiusForStatics(15)" in produced

    def test_it_is_emitted_before_initialize(self) -> None:
        # `initialize()` builds the elements and applies the default, so a setter after it would be
        # read by nobody — and the Lua setter refuses loudly in that case, which would turn a
        # mis-ordered emission into an error in every mission that used the key.
        produced = _config(zones=[{**_ZONE, "default_spawn_radius": 0}])
        chain = produced[produced.index("CMBT_PALMYRA") :]
        assert chain.index(":setDefaultSpawnRadius(0)") < chain.index(":initialize()")

    def test_a_zone_without_the_key_gains_nothing(self) -> None:
        produced = _config(zones=[_ZONE])
        assert "setDefaultSpawnRadius" not in produced

    def test_one_zone_pinned_leaves_its_neighbour_alone(self) -> None:
        # Tripack's actual case: some of his 38 zones pinned, the rest scattering normally.
        produced = _config(
            zones=[
                {"zone_name": "CMBT_PALMYRA", "default_spawn_radius": 0},
                {"zone_name": "CMBT_TIYAS"},
            ]
        )
        palmyra = produced[produced.index("CMBT_PALMYRA") : produced.index("CMBT_TIYAS")]
        tiyas = produced[produced.index("CMBT_TIYAS") :]
        assert ":setDefaultSpawnRadius(0)" in palmyra
        assert "setDefaultSpawnRadius" not in tiyas
