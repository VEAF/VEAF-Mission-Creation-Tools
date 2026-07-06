"""Tests for veaf_libs.lua_config_generator."""

import logging
import re
from pathlib import Path

import pytest
import typer
from veaf_libs.lua_config_generator import (
    MANDATORY_MODULES,
    RADIO_MENU_ACTIONS,
    _emit_action_call,
    _emit_airwave_zone,
    _emit_lua_string,
    _emit_module_radio_menu,
    _emit_user_menus,
    _resolve_deps,
    collect_radio_lua_functions,
    find_undefined_lua_functions,
    generate_config_lua,
    generate_mission_yaml_template,
    resolve_module_dependencies,
)

_LONG_STRING_RE = re.compile(r"^\[=*\[")


def _is_long_string(s: str) -> bool:
    """True if *s* is a Lua long-string literal."""
    return bool(_LONG_STRING_RE.match(s))


# ---------------------------------------------------------------------------
# _emit_lua_string
# ---------------------------------------------------------------------------


def test_emit_lua_string_plain():
    assert _emit_lua_string("hello") == '"hello"'


def test_emit_lua_string_empty():
    assert _emit_lua_string("") == '""'


def test_emit_lua_string_with_newline():
    result = _emit_lua_string("line1\nline2")
    assert _is_long_string(result)
    assert "line1\nline2" in result
    # Must NOT be a plain quoted string
    assert not result.startswith('"')


def test_emit_lua_string_with_double_quote():
    result = _emit_lua_string('say "hello"')
    assert _is_long_string(result)
    assert 'say "hello"' in result
    assert not result.startswith('"')


def test_emit_lua_string_with_backslash():
    # Backslash would be misinterpreted by Lua escape processing in plain strings
    result = _emit_lua_string(r"C:\Users\foo")
    assert _is_long_string(result)
    assert r"C:\Users\foo" in result


def test_emit_lua_string_multiline_no_closing_brackets():
    value = "Tacan 64Y\nU290.50 (20)\nZone OUEST"
    result = _emit_lua_string(value)
    # Value has no ]] — expect simplest [[...]] form
    assert result == f"[[{value}]]"


def test_emit_lua_string_value_with_closing_brackets():
    # Value forces long-string (has \n) AND contains ]] — dynamic level must pick a safe delimiter
    value = "line1\nclose]]here"
    result = _emit_lua_string(value)
    assert _is_long_string(result)
    assert value in result
    # The closing bracket sequence of the chosen level must NOT appear inside the value
    m = _LONG_STRING_RE.match(result)
    assert m is not None
    level = len(m.group(0)) - 2  # number of = chars
    closing = "]" + "=" * level + "]"
    assert closing not in value


# ---------------------------------------------------------------------------
# ASSETS block — newline in information produces valid Lua long-string
# ---------------------------------------------------------------------------

_MINIMAL_YAML: dict = {
    "mission": {"name": "Test"},
    "lua_modules": {
        "ASSETS": {
            "assets": [
                {
                    "sort": 1,
                    "name": "T1-Arco-1",
                    "description": "Arco-1 (KC-135)",
                    "information": "Tacan 64Y\nU290.50 (20)\nZone OUEST",
                    "linked": "T1-Arco-1 escort",
                },
            ]
        }
    },
}


def test_assets_multiline_information_uses_long_string():
    lua = generate_config_lua(_MINIMAL_YAML)
    # The specific ASSETS information field must use a long-string
    assert "information = [[Tacan 64Y" in lua
    # Plain quoted newline must NOT appear
    assert '"Tacan 64Y\n' not in lua
    # Content present
    assert "U290.50 (20)" in lua
    assert "Zone OUEST" in lua


def test_assets_plain_information_uses_quoted_string():
    yaml_data: dict = {
        "mission": {"name": "Test"},
        "lua_modules": {
            "ASSETS": {
                "assets": [
                    {
                        "sort": 1,
                        "name": "Base Alpha",
                        "description": "Alpha base",
                        "information": "No newlines here",
                    },
                ]
            }
        },
    }
    lua = generate_config_lua(yaml_data)
    assert 'information = "No newlines here"' in lua


# ---------------------------------------------------------------------------
# External modules — CTLD
# ---------------------------------------------------------------------------


def test_ctld_enabled_generates_guard_and_initialize():
    yaml_data: dict = {"external_modules": {"ctld": {"enabled": True, "hoverPickup": False, "slingLoad": True}}}
    lua = generate_config_lua(yaml_data)
    assert "if ctld then" in lua
    assert "ctld.hoverPickup = false" in lua
    assert "ctld.slingLoad = true" in lua
    assert "ctld.initialize()" in lua
    # Block structure: guard → props → initialize → end, in order
    idx_guard = lua.index("if ctld then")
    idx_init = lua.index("ctld.initialize()")
    idx_end = lua.index("end", idx_init)
    assert idx_guard < idx_init < idx_end
    # initialize() appears exactly once
    assert lua.count("ctld.initialize()") == 1


def test_ctld_disabled_emits_nothing():
    yaml_data: dict = {"external_modules": {"ctld": {"enabled": False}}}
    lua = generate_config_lua(yaml_data)
    assert "ctld" not in lua


def test_ctld_missing_emits_nothing():
    yaml_data: dict = {"external_modules": {}}
    lua = generate_config_lua(yaml_data)
    assert "ctld" not in lua


# ---------------------------------------------------------------------------
# External modules — CSAR
# ---------------------------------------------------------------------------


def test_csar_enabled_generates_guard_and_initialize():
    yaml_data: dict = {"external_modules": {"csar": {"enabled": True, "enableAllslots": True, "useprefix": True}}}
    lua = generate_config_lua(yaml_data)
    assert "if csar then" in lua
    assert "csar.enableAllslots = true" in lua
    assert "csar.useprefix = true" in lua
    assert "csar.initialize()" in lua
    # Block structure: guard → props → initialize → end, in order
    idx_guard = lua.index("if csar then")
    idx_init = lua.index("csar.initialize()")
    idx_end = lua.index("end", idx_init)
    assert idx_guard < idx_init < idx_end
    # initialize() appears exactly once
    assert lua.count("csar.initialize()") == 1


def test_csar_disabled_emits_nothing():
    yaml_data: dict = {"external_modules": {"csar": {"enabled": False}}}
    lua = generate_config_lua(yaml_data)
    assert "csar" not in lua


def test_csar_missing_emits_nothing():
    yaml_data: dict = {"external_modules": {}}
    lua = generate_config_lua(yaml_data)
    assert "csar" not in lua


def test_ctld_and_csar_both_enabled():
    yaml_data: dict = {
        "external_modules": {
            "ctld": {"enabled": True, "hoverPickup": True},
            "csar": {"enabled": True, "enableAllslots": False},
        }
    }
    lua = generate_config_lua(yaml_data)
    assert "if ctld then" in lua
    assert "if csar then" in lua
    assert "ctld.initialize()" in lua
    assert "csar.initialize()" in lua


# ---------------------------------------------------------------------------
# MODUX-001 — Category headers in generated Lua
# ---------------------------------------------------------------------------


def test_category_headers_present_in_lua():
    """Category comment headers must appear in the Lua output."""
    yaml_data: dict = {
        "lua_modules": {
            "UNITS": {},
            "SPAWN": {},
            "ASSETS": {"assets": []},
        }
    }
    lua = generate_config_lua(yaml_data)
    assert "-- ── Infrastructure ──" in lua
    assert "-- ── Core ──" in lua
    assert "-- ── Features ──" in lua


def test_category_headers_present_in_yaml_template():
    """Category comment headers must appear in the YAML template."""
    template = generate_mission_yaml_template()
    assert "# ── Infrastructure (mandatory — cannot be disabled) ──" in template
    assert "# ── Core ──" in template
    assert "# ── Features ──" in template
    assert "# ── Combat ──" in template


# ---------------------------------------------------------------------------
# MODUX-002 — Mandatory module enable/disable error
# ---------------------------------------------------------------------------


def test_mandatory_module_enable_false_raises(caplog):
    """Setting enable: false on a mandatory module must raise typer.Abort."""
    yaml_data: dict = {"lua_modules": {"UNITS": {"enable": False}}}
    with caplog.at_level(logging.ERROR, logger="veaf-tools"):
        with pytest.raises(typer.Abort):
            generate_config_lua(yaml_data)
    assert any("UNITS" in msg for msg in caplog.messages)


def test_mandatory_module_enable_true_raises(caplog):
    """Setting enable: true on a mandatory module must also raise typer.Abort."""
    yaml_data: dict = {"lua_modules": {"UNITS": {"enable": True}}}
    with caplog.at_level(logging.ERROR, logger="veaf-tools"):
        with pytest.raises(typer.Abort):
            generate_config_lua(yaml_data)
    assert any("UNITS" in msg for msg in caplog.messages)


def test_mandatory_module_config_only_passes(caplog):
    """Configuring a mandatory module without enable key must not raise."""
    yaml_data: dict = {"lua_modules": {"UNITS": {"logLevel": "debug"}}}
    with caplog.at_level(logging.ERROR, logger="veaf-tools"):
        generate_config_lua(yaml_data)
    assert not any("UNITS" in msg for msg in caplog.messages)


def test_mandatory_module_no_enable_in_yaml_template():
    """generate_mission_yaml_template must emit bare 'key:' (null) for mandatory modules, never 'enable:'."""
    template = generate_mission_yaml_template(enabled_module_ids=MANDATORY_MODULES | {"RADIO"})
    lines = template.splitlines()

    for mandatory in MANDATORY_MODULES:
        uncommented = [ln for ln in lines if mandatory in ln and not ln.lstrip().startswith("#")]
        assert uncommented, f"{mandatory} must appear uncommented in the template"
        assert not any("enable:" in ln for ln in uncommented), f"{mandatory} must not have 'enable:'"
        # Mandatory modules must be emitted as bare null: "  KEY:" with nothing after the colon
        assert any(ln.strip() == f"{mandatory}:" for ln in uncommented), (
            f"{mandatory} must be emitted as bare null 'key:'"
        )

    # Non-mandatory enabled module (no extra config) must use shorthand `: true`
    assert any(ln.strip() == "RADIO: true" and not ln.startswith("#") for ln in lines), (
        "RADIO (non-mandatory) must produce a 'RADIO: true' shorthand line"
    )


def test_non_mandatory_disabled_no_error(caplog):
    """Disabling a non-mandatory module must NOT produce a mandatory error."""
    yaml_data: dict = {"lua_modules": {"ASSETS": {"enable": False}}}
    with caplog.at_level(logging.ERROR, logger="veaf-tools"):
        generate_config_lua(yaml_data)
    assert not any("always active" in msg for msg in caplog.messages)


# ---------------------------------------------------------------------------
# MODUX-003 — Dependency auto-resolution
# ---------------------------------------------------------------------------


def test_dep_auto_resolution_missing_dep(caplog):
    """SPAWN enabled without UNITS → UNITS auto-enabled + warning."""
    effective = {"SPAWN": {}}
    with caplog.at_level(logging.WARNING, logger="veaf-tools"):
        result = _resolve_deps(effective)
    assert "UNITS" in result
    assert result["UNITS"].get("enabled") is True
    assert any("UNITS" in msg for msg in caplog.messages)


def test_dep_auto_resolution_disabled_dep(caplog):
    """SPAWN enabled and UNITS explicitly disabled → UNITS auto-enabled + warning.
    Other config keys on the dep must be preserved."""
    effective = {"SPAWN": {}, "UNITS": {"enable": False, "logLevel": "debug"}}
    with caplog.at_level(logging.WARNING, logger="veaf-tools"):
        result = _resolve_deps(effective)
    assert result["UNITS"].get("enabled") is True
    # Other config must be preserved (Sourcery fix)
    assert result["UNITS"].get("logLevel") == "debug"
    assert any("UNITS" in msg for msg in caplog.messages)


def test_dep_no_warning_when_dep_present():
    """No warning when dependency is already properly configured."""
    effective = {"SPAWN": {}, "UNITS": {}}
    # Should not raise and should return same dict with no auto-enable change
    result = _resolve_deps(effective)
    assert "UNITS" in result


def test_transitive_dep_resolution(caplog):
    """Transitive chain A→B→C: enabling A auto-enables B and C."""
    # CASMISSION → SPAWN (→ UNITS) and GROUNDAI (→ COMMANDS → MARKERS)
    effective = {"CASMISSION": {}}
    with caplog.at_level(logging.WARNING, logger="veaf-tools"):
        result = _resolve_deps(effective)
    # Direct deps of CASMISSION
    assert "SPAWN" in result
    assert "GROUNDAI" in result
    # Transitive: SPAWN → UNITS
    assert "UNITS" in result
    # Transitive: GROUNDAI → COMMANDS → MARKERS
    assert "COMMANDS" in result
    assert "MARKERS" in result


def test_explicitly_disabled_module_skips_dep_check():
    """If module itself is enable: false, its dependencies are not checked."""
    effective = {"SPAWN": {"enable": False}}
    result = _resolve_deps(effective)
    # UNITS should NOT be auto-added since SPAWN is disabled
    assert "UNITS" not in result


# ---------------------------------------------------------------------------
# resolve_module_dependencies() — pure transitive dependency resolution
# ---------------------------------------------------------------------------


def test_resolve_module_dependencies_transitive():
    """CASMISSION must pull in its full transitive dependency closure."""
    added = resolve_module_dependencies({"CASMISSION"})
    # CASMISSION -> SPAWN, GROUNDAI; SPAWN -> UNITS; GROUNDAI -> COMMANDS; COMMANDS -> MARKERS
    for dep in ("SPAWN", "GROUNDAI", "COMMANDS", "MARKERS", "UNITS"):
        assert dep in added, f"{dep} should be auto-resolved"
    assert "CASMISSION" not in added  # never returns the input itself


def test_resolve_module_dependencies_skips_already_enabled():
    """Dependencies already in the enabled set are not returned again."""
    added = resolve_module_dependencies({"CASMISSION", "GROUNDAI", "SPAWN"})
    assert "GROUNDAI" not in added
    assert "SPAWN" not in added
    assert "COMMANDS" in added  # transitive deps still pulled in


def test_resolve_module_dependencies_leaf_and_empty():
    """A module with no dependencies (or an empty set) resolves to nothing."""
    assert resolve_module_dependencies({"MARKERS"}) == []
    assert resolve_module_dependencies(set()) == []


def test_tum_initialize_emitted_when_enabled():
    """TUM.initialize() is emitted when the tum community script is enabled (TUM-INIT)."""
    lua = generate_config_lua({"modules": {"RADIO": True}, "community_scripts": {"tum": True}})
    assert "TUM.initialize()" in lua
    assert "if TUM then" in lua


def test_tum_initialize_absent_when_disabled():
    """No TUM.initialize() when tum is disabled."""
    lua = generate_config_lua({"community_scripts": {"tum": False}})
    assert "TUM.initialize()" not in lua


def test_tum_initialize_absent_by_default():
    """TUM is opt-in: omitting it (vanilla / convert-v5 default) must NOT emit TUM.initialize() (TUM-AUTOINIT)."""
    # community_scripts present but TUM not listed → still disabled
    lua = generate_config_lua({"community_scripts": {"ctld": True}})
    assert "TUM.initialize()" not in lua
    # no community_scripts section at all → still disabled
    assert "TUM.initialize()" not in generate_config_lua({"modules": {"RADIO": True}})


def test_optout_script_still_enabled_by_default():
    """Opt-out scripts (e.g. ctld) stay enabled when absent — the opt-in change must not regress them."""
    from mission_builder.mission_builder_worker import _normalize_mission_yaml
    from veaf_libs.lua_config_generator import _community_enabled

    normalized = _normalize_mission_yaml({"modules": {"RADIO": True}})
    assert _community_enabled(normalized, "ctld") is True
    assert _community_enabled(normalized, "tum") is False


# ---------------------------------------------------------------------------
# _emit_airwave_zone — every emitted AirWaveZone method must exist in the Lua
# (regression guard for FIX-AIRWAVES-GENERATOR: emitting a non-existent setter
# crashed the mission at start with "attempt to call method '…' (a nil value)").
# ---------------------------------------------------------------------------

_VEAF_AIRWAVES_LUA = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf" / "veafAirWaves.lua"


def _airwavezone_methods() -> set[str]:
    """Real ``AirWaveZone`` method names, parsed from the Lua source."""
    assert _VEAF_AIRWAVES_LUA.is_file(), f"veafAirWaves.lua not found at expected path: {_VEAF_AIRWAVES_LUA}"
    text = _VEAF_AIRWAVES_LUA.read_text(encoding="utf-8")
    return set(re.findall(r"function AirWaveZone:([A-Za-z_]\w*)\s*\(", text))


def _fully_populated_airwave_zone() -> dict:
    """An airwave-zone dict exercising every key ``_emit_airwave_zone`` reads."""
    return {
        "name": "Defense",
        "description": "Intercept zone",
        "player_coalitions": ["BLUE"],
        "zone_center_coordinates": "N42 E42",
        "trigger_zone_name": "ZONE-DEF",
        "zone_radius": 5000,
        "draw_zone": True,
        "respawn_default_offset": [0.1, 0.2],
        "respawn_radius": 300,
        "delay_before_activation": 30,
        "delay_between_waves": 120,
        "min_seconds_between_waves": 60,
        "max_seconds_between_waves": 180,
        "max_altitude_ft": 30000,
        "min_altitude_ft": 1000,
        "max_seconds_outside_ia": 45,
        "message_start": "Start",
        "message_wait_for_humans": "Wait",
        "message_wave_deployed": "Wave inbound",
        "message_end_zone": "Zone cleared",
        "message_end_all": "All cleared",
        "waves": [{"groups": "Wave1", "delay": 10, "number": "2", "bias": 1}],
        "minimum_life_percent": 50,
        "reset_when_dying": True,
        "start": True,
    }


def _emitted_methods(lines: list[str]) -> list[str]:
    """Every ``:method(`` call in an emitted builder chain."""
    return re.findall(r":([A-Za-z_]\w*)\s*\(", "\n".join(lines))


def test_emit_airwave_zone_only_real_methods():
    """Every method the generator emits must exist on ``AirWaveZone`` — otherwise
    the generated ``veaf-config.lua`` crashes the mission at start."""
    real = _airwavezone_methods()
    # sanity: the parser actually found the class methods
    assert {"setName", "setTriggerZone", "start"} <= real
    emitted = _emitted_methods(_emit_airwave_zone(_fully_populated_airwave_zone()))
    unknown = sorted(m for m in set(emitted) if m not in real)
    assert unknown == [], f"generator emits non-existent AirWaveZone methods: {unknown}"


def test_emit_airwave_zone_message_mapping():
    """The wave-deployed / end-zone messages map to the real setters, and the
    previously-fabricated names never reappear."""
    text = "\n".join(_emit_airwave_zone(_fully_populated_airwave_zone()))
    assert ":setMessageDeploy(" in text
    assert ":setMessageWon(" in text
    for bad in (
        "setMessageWaveDeployed",
        "setMessageEndZone",
        "setMessageEndAll",
        "setMinimumSecondsBetweenWaves",
        "setMaximumSecondsBetweenWaves",
    ):
        assert bad not in text


def test_emit_airwave_zone_delay_collapses_range_to_min():
    """A min/max range collapses to a single ``setDelayBetweenWaves(min)`` (the
    runtime has no random range); the fixed delay is the fallback."""
    text = "\n".join(_emit_airwave_zone(_fully_populated_airwave_zone()))
    assert ":setDelayBetweenWaves(60)" in text  # min wins over delay_between_waves=120
    assert text.count(":setDelayBetweenWaves(") == 1
    # fixed delay used when no range is configured
    assert ":setDelayBetweenWaves(90)" in "\n".join(_emit_airwave_zone({"name": "Z", "delay_between_waves": 90}))
    # an explicit zero delay is honoured (not skipped as falsy), for both keys
    assert ":setDelayBetweenWaves(0)" in "\n".join(_emit_airwave_zone({"name": "Z", "delay_between_waves": 0}))
    assert ":setDelayBetweenWaves(0)" in "\n".join(_emit_airwave_zone({"name": "Z", "min_seconds_between_waves": 0}))


# ---------------------------------------------------------------------------
# Community-script enable flags (FIX-VEAF-MODULE-GATING)
# ---------------------------------------------------------------------------


def test_disabled_community_scripts_emit_enable_false():
    """A disabled community script gets `veaf.setConfig("<id>", "enable", false)` so the
    framework's runtime gates (`if ctld and veaf.isEnabled("ctld")`) leave it alone."""
    lua = generate_config_lua({"community_scripts": {"ctld": False, "stts": False}})
    assert 'veaf.setConfig("ctld", "enable", false)' in lua
    assert 'veaf.setConfig("stts", "enable", false)' in lua


def test_enabled_community_scripts_emit_no_enable_flag():
    """Enabled (or default) community scripts emit no enable=false gate flag."""
    lua = generate_config_lua({"community_scripts": {"ctld": True}})
    assert 'veaf.setConfig("ctld", "enable", false)' not in lua


def test_mandatory_mist_never_emitted_as_disabled():
    """MiST is a mandatory dependency — never scaffolded as disabled even if listed false."""
    lua = generate_config_lua({"community_scripts": {"mist": False}})
    assert 'veaf.setConfig("mist", "enable", false)' not in lua


# ---------------------------------------------------------------------------
# COMBATZONE — activate zones at mission start (FEAT-COMBATZONE-ACTIVATE)
# ---------------------------------------------------------------------------


def test_combatzone_active_at_start_emits_activatezone_after_initialize():
    """A combat zone flagged ``active_at_start`` is activated after ``initialize()``."""
    yaml_data: dict = {
        "mission": {"name": "Test"},
        "lua_modules": {
            "COMBATZONE": {
                "combat_zones": [
                    {"zone_name": "OUTPOST_1", "active_at_start": True},
                    {"zone_name": "OUTPOST_2"},
                ]
            }
        },
    }
    lua = generate_config_lua(yaml_data)
    # Flagged zone is activated (silent), non-flagged zone is not.
    assert 'veafCombatZone.ActivateZone("OUTPOST_1", true)' in lua
    assert 'veafCombatZone.ActivateZone("OUTPOST_2"' not in lua
    # Activation must come AFTER initialize() (zones must be registered first).
    assert lua.index("veafCombatZone.initialize()") < lua.index('veafCombatZone.ActivateZone("OUTPOST_1", true)')


# ---------------------------------------------------------------------------
# YAML-declared radio menus (FEAT-RADIO-YAML-MENUS, ADR 0011)
# ---------------------------------------------------------------------------


def test_action_flag_on_off_set():
    assert 'veafSpawn.missionMasterSetFlag("alpha", 1)' in _emit_action_call({"action": "flag.on", "flag": "alpha"})
    assert 'veafSpawn.missionMasterSetFlag("alpha", 0)' in _emit_action_call({"action": "flag.off", "flag": "alpha"})
    assert 'veafSpawn.missionMasterSetFlag("alpha", 5)' in _emit_action_call(
        {"action": "flag.set", "flag": "alpha", "value": 5}
    )


def test_action_flag_increment_decrement():
    assert 'veafSpawn.missionMasterAddValueToFlag("score", 1)' in _emit_action_call(
        {"action": "flag.increment", "flag": "score"}
    )
    assert 'veafSpawn.missionMasterAddValueToFlag("score", -1)' in _emit_action_call(
        {"action": "flag.decrement", "flag": "score"}
    )


def test_action_flag_numeric_name_stays_number():
    # A numeric flag id must not be quoted.
    assert "veafSpawn.missionMasterSetFlag(10, 1)" in _emit_action_call({"action": "flag.on", "flag": 10})


def test_action_message_uses_outtext():
    call = _emit_action_call({"action": "message", "text": "Go!"})
    assert "trigger.action.outText(" in call
    assert "Go!" in call


def test_action_qra_start_stop_guarded():
    start = _emit_action_call({"action": "qra.start", "qra": "QRA-Nord"})
    assert 'veafQraManager.get("QRA-Nord")' in start
    assert "if o then o:start() end" in start
    stop = _emit_action_call({"action": "qra.stop", "qra": "QRA-Nord"})
    assert "o:stop()" in stop


def test_action_airwave_verbs_guarded():
    for verb in ("start", "stop", "reset"):
        call = _emit_action_call({"action": f"airwave.{verb}", "airwave": "Wave-Est"})
        assert 'veafAirWaves.get("Wave-Est")' in call
        assert f"o:{verb}()" in call


def test_action_lua_reference_without_args():
    assert _emit_action_call({"action": "lua", "function": "maMission.doStuff"}) == "maMission.doStuff"


def test_action_lua_reference_with_args():
    call = _emit_action_call({"action": "lua", "function": "maMission.doStuff", "args": [1, "x"]})
    assert call == 'maMission.doStuff, {1, "x"}'


def test_action_unknown_raises():
    with pytest.raises(ValueError):
        _emit_action_call({"action": "does.not.exist"})


def test_action_missing_target_raises():
    with pytest.raises(ValueError):
        _emit_action_call({"action": "flag.set", "flag": "a"})  # missing value
    with pytest.raises(ValueError):
        _emit_action_call({"action": "qra.start"})  # missing qra


def test_vocabulary_is_closed():
    # Guardrail: the documented v1 vocabulary, nothing more.
    assert set(RADIO_MENU_ACTIONS) == {
        "qra.start",
        "qra.stop",
        "airwave.start",
        "airwave.stop",
        "airwave.reset",
        "flag.on",
        "flag.off",
        "flag.set",
        "flag.increment",
        "flag.decrement",
        "message",
        "lua",
    }


def test_user_menus_basic_structure():
    user_menus = {
        "tree": [
            {
                "menu": "Drapeaux",
                "items": [{"command": "Activer ALPHA", "action": "flag.on", "flag": "alpha"}],
            }
        ]
    }
    lua = "\n".join(_emit_user_menus(user_menus))
    assert "veafRadio.createUserMenu(" in lua
    assert "veafRadio.mainmenu(" in lua
    assert 'veafRadio.menu("Drapeaux",' in lua
    assert 'veafRadio.command("Activer ALPHA",' in lua


def test_user_menus_restrict_to_group_passes_name():
    user_menus = {
        "restrict_to_group": "MM Ctrl",
        "tree": [{"command": "Ping", "action": "message", "text": "hi"}],
    }
    lua = "\n".join(_emit_user_menus(user_menus))
    # The group name is passed as createUserMenu's second argument.
    assert '"MM Ctrl"' in lua
    assert lua.rstrip().endswith(")")


def test_module_radio_menu_shortcut_qra():
    lua = "\n".join(_emit_module_radio_menu("QRA-Nord", "qra", ["start", "stop"], None))
    assert 'veafRadio.menu("QRA-Nord",' in lua
    assert 'veafQraManager.get("QRA-Nord")' in lua
    assert "o:start()" in lua
    assert "o:stop()" in lua


def test_generate_qra_radio_menu_shortcut():
    yaml_data: dict = {
        "lua_modules": {"QRA": {}},
        "qra": {"definitions": [{"name": "QRA-Nord", "coalition": "RED", "radio_menu": True}]},
    }
    lua = generate_config_lua(yaml_data)
    assert "veafRadio.createUserMenu(" in lua
    assert 'veafQraManager.get("QRA-Nord")' in lua


def test_generate_qra_without_radio_menu_emits_no_usermenu():
    yaml_data: dict = {
        "lua_modules": {"QRA": {}},
        "qra": {"definitions": [{"name": "QRA-Nord", "coalition": "RED"}]},
    }
    lua = generate_config_lua(yaml_data)
    assert "veafRadio.createUserMenu(" not in lua


def test_generate_radio_user_menus():
    yaml_data: dict = {
        "lua_modules": {
            "RADIO": {"user_menus": {"tree": [{"command": "Activer ALPHA", "action": "flag.on", "flag": "alpha"}]}}
        },
    }
    lua = generate_config_lua(yaml_data)
    assert "veafRadio.createUserMenu(" in lua
    assert 'veafSpawn.missionMasterSetFlag("alpha", 1)' in lua


# ---------------------------------------------------------------------------
# lua action: build-time function verification (ticket 03)
# ---------------------------------------------------------------------------

_YAML_WITH_LUA_REF: dict = {
    "modules": {
        "RADIO": {
            "user_menus": {
                "tree": [
                    {
                        "menu": "Custom",
                        "items": [
                            {"command": "Run", "action": "lua", "function": "maMission.doStuff"},
                            {"command": "Flag", "action": "flag.on", "flag": "a"},
                        ],
                    }
                ]
            }
        }
    }
}


def test_collect_radio_lua_functions():
    assert collect_radio_lua_functions(_YAML_WITH_LUA_REF) == ["maMission.doStuff"]


def test_collect_radio_lua_functions_none():
    assert collect_radio_lua_functions({"modules": {"RADIO": {}}}) == []


def test_find_undefined_lua_functions_reports_missing():
    assert find_undefined_lua_functions(_YAML_WITH_LUA_REF, "-- empty corpus") == ["maMission.doStuff"]


def test_find_undefined_lua_functions_ok_when_defined_dotted():
    corpus = "function maMission.doStuff()\n  return 1\nend"
    assert find_undefined_lua_functions(_YAML_WITH_LUA_REF, corpus) == []


def test_find_undefined_lua_functions_ok_when_assigned():
    corpus = "maMission.doStuff = function() end"
    assert find_undefined_lua_functions(_YAML_WITH_LUA_REF, corpus) == []


def test_find_undefined_lua_functions_deduplicates():
    yaml_data = {
        "modules": {
            "RADIO": {
                "user_menus": {
                    "tree": [
                        {"command": "A", "action": "lua", "function": "m.f"},
                        {"command": "B", "action": "lua", "function": "m.f"},
                    ]
                }
            }
        }
    }
    assert find_undefined_lua_functions(yaml_data, "-- none") == ["m.f"]
