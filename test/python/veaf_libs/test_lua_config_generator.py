"""Tests for veaf_libs.lua_config_generator."""

import re
import logging

import pytest
import typer

from veaf_libs.lua_config_generator import (
    _emit_lua_string,
    _resolve_deps,
    generate_config_lua,
    generate_mission_yaml_template,
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
    yaml_data: dict = {
        "external_modules": {
            "ctld": {"enabled": True, "hoverPickup": False, "slingLoad": True}
        }
    }
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
    yaml_data: dict = {
        "external_modules": {
            "csar": {"enabled": True, "enableAllslots": True, "useprefix": True}
        }
    }
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
    """generate_mission_yaml_template must not emit 'enable:' for mandatory modules."""
    template = generate_mission_yaml_template(enabled_module_ids={"UNITS", "TIME", "RADIO"})
    lines = template.splitlines()
    for mandatory in ("UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"):
        enable_lines = [ln for ln in lines if mandatory in ln and "enable:" in ln and not ln.lstrip().startswith("#")]
        assert enable_lines == [], f"{mandatory} must not have 'enable:' in the template"


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
    assert result["UNITS"].get("enable") is True
    assert any("UNITS" in msg for msg in caplog.messages)


def test_dep_auto_resolution_disabled_dep(caplog):
    """SPAWN enabled and UNITS explicitly disabled → UNITS auto-enabled + warning.
    Other config keys on the dep must be preserved."""
    effective = {"SPAWN": {}, "UNITS": {"enable": False, "logLevel": "debug"}}
    with caplog.at_level(logging.WARNING, logger="veaf-tools"):
        result = _resolve_deps(effective)
    assert result["UNITS"].get("enable") is True
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
