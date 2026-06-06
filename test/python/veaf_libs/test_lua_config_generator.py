"""Tests for veaf_libs.lua_config_generator."""

from veaf_libs.lua_config_generator import _emit_lua_string, generate_config_lua


# ---------------------------------------------------------------------------
# _emit_lua_string
# ---------------------------------------------------------------------------


def test_emit_lua_string_plain():
    assert _emit_lua_string("hello") == '"hello"'


def test_emit_lua_string_empty():
    assert _emit_lua_string("") == '""'


def test_emit_lua_string_with_newline():
    result = _emit_lua_string("line1\nline2")
    assert result.startswith("[[")
    assert result.endswith("]]")
    assert "line1\nline2" in result
    # Must NOT be a plain quoted string with an embedded newline
    assert result != '"line1\nline2"'


def test_emit_lua_string_with_double_quote():
    result = _emit_lua_string('say "hello"')
    assert result.startswith("[[")
    assert "say" in result
    # No raw double-quote at the outer wrapping level
    assert not result.startswith('"')


def test_emit_lua_string_multiline_no_closing_brackets():
    value = "Tacan 64Y\nU290.50 (20)\nZone OUEST"
    result = _emit_lua_string(value)
    assert result == f"[[{value}]]"


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
    # Long-string opener present
    assert "[[" in lua
    # Plain quoted newline must NOT appear
    assert '"Tacan 64Y\n' not in lua
    # Content present
    assert "Tacan 64Y" in lua
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
