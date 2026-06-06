"""Tests for veaf_libs.lua_config_generator."""

import re

from veaf_libs.lua_config_generator import _emit_lua_string, generate_config_lua

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
