"""Every mission-supplied string must come out of the generator as valid Lua.

The defect this file exists for was found in game on 2026-09-01: a wave zone declared
with a coordinate written the way DCS displays one — ``N42°00'00" E042°00'00"`` — was
interpolated straight into a double-quoted Lua string.  The seconds symbol closed the
literal, DCS refused the *whole* ``veaf-config.lua``, and not one VEAF module
initialised.  No radio menu, no spawn, no assets, and a build that reported success.

So the tests here do not check *how* a value is quoted.  They drive one value through
each field a mission maker can write and ask the only question that matters: does the
generated file parse?  The value carries the three characters that break a Lua string
literal — a double quote, a backslash and a newline — because any one of them alone
leaves the other two untested.

The field list is enumerated from the generator, not sampled: every expression the
generator interpolates into a double-quoted Lua string has an entry here or a written
reason in ``.backlog/FIX-GENERATOR-UNESCAPED-STRINGS/tickets/01-…`` for having none.
"""

from __future__ import annotations

import pytest
from veaf_libs.lua_config_generator import generate_config_lua
from veaf_libs.lua_literals import lua_quoted_string, lua_string
from veaf_libs.lua_syntax import LuaSyntaxError, check_lua_syntax

#: The three characters that end a Lua short string early, in one value.
NASTY = 'quote " backslash \\ newline\nsecond line'

#: The exact value that broke the mission, kept verbatim: a DCS coordinate with seconds.
DCS_SECONDS_COORDINATE = "N42°00'00\" E042°00'00\""


def _mission(**extra: object) -> dict:
    """Return a minimal ``mission.yaml`` mapping with *extra* merged in.

    Args:
        **extra: Top-level keys to add or replace.

    Returns:
        A mapping ``generate_config_lua`` accepts.
    """
    base: dict = {"mission": {"name": "Test"}, "lua_modules": {}}
    base.update(extra)
    return base


def _module(module_id: str, config: dict) -> dict:
    """Return a mission mapping carrying one configured module.

    Args:
        module_id: The VEAF module id, e.g. ``AIRWAVES``.
        config: That module's configuration block.

    Returns:
        A mapping ``generate_config_lua`` accepts.
    """
    return _mission(lua_modules={module_id: config})


#: One entry per free-text field, mapping the ``mission.yaml`` path to a mission that
#: puts :data:`NASTY` there.  Enumerated from every raw interpolation the generator
#: performs into a double-quoted Lua string.
FREE_TEXT_FIELDS: dict[str, dict] = {
    # ── mission identity, security, log level ──────────────────────────────
    "mission.name": _mission(mission={"name": NASTY}),
    "mission.export_path": _mission(mission={"name": "Test", "export_path": NASTY}),
    "mission.language": _mission(mission={"name": "Test", "language": NASTY}),
    "global_log_level": _mission(global_log_level=NASTY),
    "security.password_hashes": _mission(security={"password_hashes": [NASTY]}),
    "security.password_mm_hashes": _mission(security={"password_mm_hashes": [NASTY]}),
    # ── per-module setConfig ───────────────────────────────────────────────
    "modules.<id>.logLevel": _module("SPAWN", {"logLevel": NASTY}),
    "modules.<id>.logLevel (disabled module)": _module("ASSETS", {"enable": False, "logLevel": NASTY}),
    "modules.<id>.<setting key>": _module("SPAWN", {NASTY: 1}),
    # ── SHORTCUTS ──────────────────────────────────────────────────────────
    "SHORTCUTS.shortcuts[].name": _module("SHORTCUTS", {"shortcuts": [{"name": NASTY, "command": "-x"}]}),
    "SHORTCUTS.shortcuts[].description": _module(
        "SHORTCUTS", {"shortcuts": [{"name": "a", "description": NASTY, "command": "-x"}]}
    ),
    "SHORTCUTS.shortcuts[].command": _module("SHORTCUTS", {"shortcuts": [{"name": "a", "command": NASTY}]}),
    # ── SANCTUARY ──────────────────────────────────────────────────────────
    "SANCTUARY.sanctuary_zones[].name": _module("SANCTUARY", {"sanctuary_zones": [{"name": NASTY}]}),
    "SANCTUARY.sanctuary_zones[].polygon_units[]": _module(
        "SANCTUARY", {"sanctuary_zones": [{"name": "a", "polygon_units": [NASTY]}]}
    ),
    # ── COMBATZONE global settings ─────────────────────────────────────────
    "COMBATZONE.combat_zone_settings.event_message_combatzonecomplete": _module(
        "COMBATZONE", {"combat_zone_settings": {"event_message_combatzonecomplete": NASTY}}
    ),
    "COMBATZONE.combat_zone_settings.radio_menu_name": _module(
        "COMBATZONE", {"combat_zone_settings": {"radio_menu_name": NASTY}}
    ),
    "COMBATZONE.combat_zone_settings.combat_zone_menu_name": _module(
        "COMBATZONE", {"combat_zone_settings": {"combat_zone_menu_name": NASTY}}
    ),
    "COMBATZONE.combat_zone_settings.operation_menu_name": _module(
        "COMBATZONE", {"combat_zone_settings": {"operation_menu_name": NASTY}}
    ),
    # ── COMBATZONE zones ───────────────────────────────────────────────────
    "COMBATZONE.combat_zones[].zone_name": _module("COMBATZONE", {"combat_zones": [{"zone_name": NASTY}]}),
    "COMBATZONE.combat_zones[].zone_name (active_at_start)": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": NASTY, "active_at_start": True}]}
    ),
    "COMBATZONE.combat_zones[].friendly_name": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": "CZ", "friendly_name": NASTY}]}
    ),
    "COMBATZONE.combat_zones[].radio_group_name": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": "CZ", "radio_group_name": NASTY}]}
    ),
    "COMBATZONE.combat_zones[].radio_menu_prefix": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": "CZ", "radio_menu_prefix": NASTY}]}
    ),
    "COMBATZONE.combat_zones[].chained_zones[]": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": "CZ", "chained_zones": [NASTY]}]}
    ),
    "COMBATZONE.combat_zones[].on_completed_hook_hint": _module(
        "COMBATZONE", {"combat_zones": [{"zone_name": NASTY, "on_completed_hook_hint": NASTY}]}
    ),
    # ── COMBATZONE operations ──────────────────────────────────────────────
    "COMBATZONE.combat_zones[type=operation].zone_name": _module(
        "COMBATZONE", {"combat_zones": [{"type": "operation", "zone_name": NASTY}]}
    ),
    "COMBATZONE.combat_zones[type=operation].friendly_name": _module(
        "COMBATZONE", {"combat_zones": [{"type": "operation", "zone_name": "OP", "friendly_name": NASTY}]}
    ),
    "COMBATZONE.combat_zones[type=operation].tasking_orders[].zone_name": _module(
        "COMBATZONE",
        {"combat_zones": [{"type": "operation", "zone_name": "OP", "tasking_orders": [{"zone_name": NASTY}]}]},
    ),
    "COMBATZONE.combat_zones[type=operation].tasking_orders[].dependencies[]": _module(
        "COMBATZONE",
        {
            "combat_zones": [
                {
                    "type": "operation",
                    "zone_name": "OP",
                    "tasking_orders": [{"zone_name": "A", "dependencies": [NASTY]}],
                }
            ]
        },
    ),
    "COMBATZONE.combat_zones[type=operation].tasking_orders[].dependencies_vars[]": _module(
        "COMBATZONE",
        {
            "combat_zones": [
                {
                    "type": "operation",
                    "zone_name": "OP",
                    "tasking_orders": [{"zone_name": "A", "dependencies_vars": [NASTY]}],
                }
            ]
        },
    ),
    # ── AIRWAVES ───────────────────────────────────────────────────────────
    "AIRWAVES.airwave_zones[].name": _module("AIRWAVES", {"airwave_zones": [{"name": NASTY}]}),
    "AIRWAVES.airwave_zones[].description": _module(
        "AIRWAVES", {"airwave_zones": [{"name": "AW", "description": NASTY}]}
    ),
    "AIRWAVES.airwave_zones[].zone_center_coordinates": _module(
        "AIRWAVES", {"airwave_zones": [{"name": "AW", "zone_center_coordinates": NASTY}]}
    ),
    "AIRWAVES.airwave_zones[].trigger_zone_name": _module(
        "AIRWAVES", {"airwave_zones": [{"name": "AW", "trigger_zone_name": NASTY}]}
    ),
    "AIRWAVES.airwave_zones[].waves[].groups": _module(
        "AIRWAVES", {"airwave_zones": [{"name": "AW", "waves": [{"groups": NASTY}]}]}
    ),
    "AIRWAVES.airwave_zones[].waves[].number": _module(
        "AIRWAVES", {"airwave_zones": [{"name": "AW", "waves": [{"number": NASTY}]}]}
    ),
    "AIRWAVES.airwave_zones[].radio_menu.restrict_to_group": _module(
        "AIRWAVES",
        {"airwave_zones": [{"name": "AW", "radio_menu": True, "radio_menu_restrict_to_group": NASTY}]},
    ),
    # ── QRA ────────────────────────────────────────────────────────────────
    "qra.definitions[].name": _mission(lua_modules={"QRA": {}}, qra={"definitions": [{"name": NASTY}]}),
    "qra.definitions[].trigger_zone": _mission(
        lua_modules={"QRA": {}}, qra={"definitions": [{"name": "Q", "trigger_zone": NASTY}]}
    ),
    "qra.definitions[].simple_groups[]": _mission(
        lua_modules={"QRA": {}}, qra={"definitions": [{"name": "Q", "simple_groups": [NASTY]}]}
    ),
    "qra.definitions[].groups_by_enemy_count[].groups[]": _mission(
        lua_modules={"QRA": {}},
        qra={"definitions": [{"name": "Q", "groups_by_enemy_count": [{"enemy_count": 1, "groups": [NASTY]}]}]},
    ),
    "qra.definitions[].airport_link": _mission(
        lua_modules={"QRA": {}}, qra={"definitions": [{"name": "Q", "airport_link": NASTY}]}
    ),
    "qra.definitions[].radio_menu_restrict_to_group": _mission(
        lua_modules={"QRA": {}},
        qra={"definitions": [{"name": "Q", "radio_menu": True, "radio_menu_restrict_to_group": NASTY}]},
    ),
    # ── RADIO user menus ───────────────────────────────────────────────────
    "RADIO.user_menus.restrict_to_group": _module(
        "RADIO",
        {"user_menus": {"tree": [{"menu": "M", "items": []}], "restrict_to_group": NASTY}},
    ),
    # ── COMBATMISSION ──────────────────────────────────────────────────────
    "cap_missions[].group_name": _mission(
        lua_modules={"COMBATMISSION": {}}, cap_missions=[{"group_name": NASTY, "menu_name": "m"}]
    ),
    "cap_missions[].menu_name": _mission(
        lua_modules={"COMBATMISSION": {}}, cap_missions=[{"group_name": "g", "menu_name": NASTY}]
    ),
    "cap_missions[].briefing": _mission(
        lua_modules={"COMBATMISSION": {}}, cap_missions=[{"group_name": "g", "menu_name": "m", "briefing": NASTY}]
    ),
    "combat_missions[].name": _mission(lua_modules={"COMBATMISSION": {}}, combat_missions=[{"name": NASTY}]),
    "combat_missions[].friendly_name": _mission(
        lua_modules={"COMBATMISSION": {}}, combat_missions=[{"name": "CM", "friendly_name": NASTY}]
    ),
    "combat_missions[].elements[].name": _mission(
        lua_modules={"COMBATMISSION": {}}, combat_missions=[{"name": "CM", "elements": [{"name": NASTY}]}]
    ),
    "combat_missions[].elements[].groups[]": _mission(
        lua_modules={"COMBATMISSION": {}},
        combat_missions=[{"name": "CM", "elements": [{"name": "E", "groups": [NASTY]}]}],
    ),
}


@pytest.mark.parametrize("field", sorted(FREE_TEXT_FIELDS))
def test_free_text_field_still_generates_parsable_lua(field: str) -> None:
    """A quote, a backslash and a newline in *field* must not break the config."""
    lua = generate_config_lua(FREE_TEXT_FIELDS[field])
    check_lua_syntax(lua)


#: The one field whose value lands in a Lua *comment* rather than a literal, so it is
#: neutralised (newlines folded) instead of quoted — see the preservation test below.
_COMMENT_FIELD = "COMBATZONE.combat_zones[].on_completed_hook_hint"


@pytest.mark.parametrize("field", sorted(set(FREE_TEXT_FIELDS) - {_COMMENT_FIELD}))
def test_free_text_field_reaches_the_lua_as_one_intact_literal(field: str) -> None:
    """Parsing is necessary but not sufficient: the value must also survive.

    A generator could satisfy the parse check by dropping the offending characters, or
    by quoting the value into something Lua reads as a different string.  ``lua_string``
    and ``lua_quoted_string`` are the two helpers whose own tests prove a round trip
    through an independent parser, so seeing one of their outputs verbatim in the file
    is the evidence that the value arrived whole.
    """
    lua = generate_config_lua(FREE_TEXT_FIELDS[field])
    assert lua_string(NASTY) in lua or lua_quoted_string(NASTY) in lua


def test_a_hook_hint_comment_keeps_the_zone_name_on_its_own_line() -> None:
    """A newline inside a value written into a Lua comment would end the comment.

    ``--`` runs to the end of the line, so a raw newline in the interpolated zone name
    turns the rest of the value into code.  Quoting cannot help inside a comment; the
    line breaks have to go.
    """
    lua = generate_config_lua(FREE_TEXT_FIELDS[_COMMENT_FIELD])
    check_lua_syntax(lua)
    hint_lines = [line for line in lua.splitlines() if "[v6 migration]" in line]
    assert len(hint_lines) == 1
    assert "second line" in hint_lines[0]


# ---------------------------------------------------------------------------
# The value that was actually flown, in the field it was actually written in
# ---------------------------------------------------------------------------


def test_a_dcs_coordinate_with_seconds_is_usable_as_documented() -> None:
    """``zone_center_coordinates`` accepts the form DCS shows the mission maker.

    Every DCS coordinate written with seconds carries a ``"``.  The field was documented
    and unusable as documented; this is the regression that proves it is not any more.
    """
    lua = generate_config_lua(
        _module("AIRWAVES", {"airwave_zones": [{"name": "AW", "zone_center_coordinates": DCS_SECONDS_COORDINATE}]})
    )
    check_lua_syntax(lua)
    assert "setZoneCenterFromCoordinates" in lua


def test_a_combat_zone_named_with_a_quote_does_not_break_the_mission() -> None:
    """The PRD's second example: a zone called ``Zone "Alpha"``."""
    lua = generate_config_lua(_module("COMBATZONE", {"combat_zones": [{"zone_name": 'Zone "Alpha"'}]}))
    check_lua_syntax(lua)


# ---------------------------------------------------------------------------
# The checker itself must be able to fail
# ---------------------------------------------------------------------------


def test_the_syntax_check_rejects_the_file_that_was_shipped() -> None:
    """The exact line DCS refused, and the line number it must report."""
    broken = 'AirWaveZone:new()\n    :setZoneCenterFromCoordinates("N42°00\'00" E042°00\'00"")\n'
    with pytest.raises(LuaSyntaxError) as excinfo:
        check_lua_syntax(broken)
    assert excinfo.value.line == 2
