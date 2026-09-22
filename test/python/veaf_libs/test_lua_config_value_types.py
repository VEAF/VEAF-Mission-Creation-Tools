"""A value a mission maker writes must reach Lua meaning what it said, or not reach it at all.

``_to_lua_scalar`` used to end in ``lua_string(str(value))``, which is correct for a scalar and
nonsense for anything else.  A list written under ``modules.CSAR.settings`` came out as a *quoted
Python repr*::

    csarPrefix: ["helicargo", "MEDEVAC"]     ->     csar.csarPrefix = "['helicargo', 'MEDEVAC']"

Syntactically valid Lua, semantically a string where the script iterates a table, and written
without a warning.  Nothing could catch it downstream: ``check_lua_syntax`` is happy, and the only
reader that would disagree is DCS, at mission time.

So the tests here assert the generated Lua *text* per Python type, and they do it on every channel a
mission maker can write a value into — ``settings:``, ``module_settings:``, a module's ``setConfig``
keys and a CSAR setting — because the defect was never CSAR-specific: it sat in the one helper those
four share.

A mapping is refused rather than rendered.  There is no consumer for one, and the whole reason this
file exists is that silence is what let the defect live.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from veaf_libs.lua_config_generator import _SKIP_SETCONFIG_KEYS, generate_config_lua
from veaf_libs.lua_syntax import check_lua_syntax

#: The shipped package, read as text by the enumeration guard at the bottom of this file.
SOURCE_ROOT = Path(__file__).parents[3] / "src" / "python" / "veaf-tools"


def _csar(value: object) -> str:
    """Return the generated Lua for ``csarPrefix: <value>`` under ``modules.CSAR.settings``."""
    return generate_config_lua({"external_modules": {"csar": {"enabled": True, "csarPrefix": value}}})


# ---------------------------------------------------------------------------
# Scalars keep the behaviour they had
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (True, "true"),
        (False, "false"),
        (20, "20"),
        (1.5, "1.5"),
        ("MEDEVAC", '"MEDEVAC"'),
        (None, "nil"),
    ],
)
def test_scalar_settings_are_unchanged(value: object, expected: str) -> None:
    assert f"csar.csarPrefix = {expected}" in _csar(value)


# ---------------------------------------------------------------------------
# Lists become Lua tables
# ---------------------------------------------------------------------------


def test_list_of_strings_becomes_a_lua_table() -> None:
    assert 'csar.csarPrefix = { "helicargo", "MEDEVAC" }' in _csar(["helicargo", "MEDEVAC"])


def test_list_of_numbers_becomes_a_lua_table() -> None:
    assert "csar.csarPrefix = { 1, 2, 3 }" in _csar([1, 2, 3])


def test_empty_list_becomes_an_empty_lua_table() -> None:
    assert "csar.csarPrefix = {}" in _csar([])


def test_mixed_list_keeps_each_element_in_its_own_form() -> None:
    assert 'csar.csarPrefix = { "a", 2, true }' in _csar(["a", 2, True])


def test_nested_list_becomes_a_nested_lua_table() -> None:
    """Handled rather than refused: the renderer is recursive, so nesting costs no extra path."""
    assert "csar.csarPrefix = { { 1, 2 }, { 3 } }" in _csar([[1, 2], [3]])


def test_a_list_element_carrying_a_quote_stays_safe() -> None:
    """The element goes through the same string helper as a scalar, so the file still parses."""
    lua = _csar(['he said "no"', "plain"])
    check_lua_syntax(lua)
    assert "['he said" not in lua  # not a Python repr


def test_the_generated_table_parses() -> None:
    check_lua_syntax(_csar(["helicargo", "MEDEVAC"]))


# ---------------------------------------------------------------------------
# Mappings are refused, loudly, naming what to fix
# ---------------------------------------------------------------------------


def test_mapping_is_refused_naming_the_target() -> None:
    with pytest.raises(ValueError) as caught:
        _csar({"UH-1H": 8})
    message = str(caught.value)
    assert "csar.csarPrefix" in message


def test_mapping_nested_in_a_list_is_refused_too() -> None:
    with pytest.raises(ValueError):
        _csar([{"UH-1H": 8}])


def test_the_refusal_says_what_to_do_instead() -> None:
    """A message that only says 'no' sends the reader back to the guesswork this lot is about."""
    with pytest.raises(ValueError) as caught:
        _csar({"UH-1H": 8})
    assert "mission-script.lua" in str(caught.value)


# ---------------------------------------------------------------------------
# The same value, through the other three channels
# ---------------------------------------------------------------------------


def test_settings_section_renders_a_list() -> None:
    lua = generate_config_lua({"settings": {"someList": ["a", "b"]}})
    assert 'veaf.config.someList = { "a", "b" }' in lua


def test_settings_section_refuses_a_mapping_naming_the_key() -> None:
    with pytest.raises(ValueError) as caught:
        generate_config_lua({"settings": {"someMap": {"a": 1}}})
    assert "veaf.config.someMap" in str(caught.value)


def test_module_settings_renders_a_list() -> None:
    lua = generate_config_lua({"module_settings": {"veafSkynet.SomeList": [1, 2]}})
    assert "veafSkynet.SomeList = { 1, 2 }" in lua


def test_module_settings_refuses_a_mapping_naming_the_key() -> None:
    with pytest.raises(ValueError) as caught:
        generate_config_lua({"module_settings": {"veafSkynet.SomeMap": {"a": 1}}})
    assert "veafSkynet.SomeMap" in str(caught.value)


def test_setconfig_renders_a_list() -> None:
    lua = generate_config_lua({"lua_modules": {"SPAWN": {"enabled": True, "someList": ["a", "b"]}}})
    assert 'veaf.setConfig("SPAWN", "someList", { "a", "b" })' in lua


def test_setconfig_refuses_a_mapping_naming_the_module_and_the_key() -> None:
    with pytest.raises(ValueError) as caught:
        generate_config_lua({"lua_modules": {"SPAWN": {"enabled": True, "someMap": {"a": 1}}}})
    message = str(caught.value)
    assert "SPAWN" in message
    assert "someMap" in message


# ---------------------------------------------------------------------------
# The keys a module handles structurally must not also go through setConfig
# ---------------------------------------------------------------------------


def test_every_structured_module_key_is_skipped_by_setconfig() -> None:
    """Enumerated from the source, not sampled — that is how the one hole was found.

    ``_emit_module_body`` reads nine keys off a module's config as lists or mappings.
    Eight were listed in ``_SKIP_SETCONFIG_KEYS``; ``user_menus`` was not, so every
    mission with YAML radio menus carried a whole Python repr of its menu tree in
    ``veaf-config.lua``, written by a ``setConfig`` call nothing reads::

        veaf.setConfig("RADIO", "user_menus", "{'tree': [{'menu': 'Flags', ...}]}")

    Inert, which is why it survived; it is the same defect as ``csarPrefix`` and only
    the refusal added by this lot made it visible.

    The pattern matches ``mod_cfg.get("x")`` in any form, deliberately.  The first version
    of this test required a ``or []`` / ``or {}`` default, which is how eight of the ten
    reads are written — and ``user_menus`` is one of the two that are not.  So the guard
    was green while blind to the very key it was written for.  A key read off a module's
    config and *also* emitted as a ``setConfig`` is the defect whatever the read looks
    like, so the enumeration matches the read, not the idiom around it.
    """
    source = (SOURCE_ROOT / "veaf_libs" / "lua_config_generator.py").read_text(encoding="utf-8")
    structured = {match.group(1) for match in re.finditer(r'mod_cfg\.get\("(\w+)"\)', source)}
    assert "user_menus" in structured, "the enumeration no longer sees the key that motivated it"
    assert len(structured) >= 10, sorted(structured)
    assert structured <= _SKIP_SETCONFIG_KEYS, sorted(structured - _SKIP_SETCONFIG_KEYS)


def test_radio_user_menus_emits_no_setconfig() -> None:
    yaml_data = {
        "lua_modules": {
            "RADIO": {
                "enabled": True,
                "user_menus": {
                    "tree": [{"menu": "Flags", "items": [{"command": "A", "action": "flag.on", "flag": "a"}]}]
                },
            }
        }
    }
    lua = generate_config_lua(yaml_data)
    assert '"user_menus"' not in lua
