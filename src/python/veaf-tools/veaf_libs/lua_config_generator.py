"""Generate ``veaf-config.lua`` from a parsed ``mission.yaml`` content dict.

This module is the authoritative source for the YAML-to-Lua config generation.
``lua_module_scanner.generate_modules_config_lua`` delegates here for backward
compatibility.

Sections handled
----------------
- ``mission:``          — identity (name, export_path, era)
- ``security:``         — SecurityDisabled, password hashes
- ``global_log_level:`` — veaf.ForcedLogLevel
- ``settings:``         — arbitrary veaf.config.XXX = value
- ``lua_modules:``      — per-module enable / logLevel / init params / data
- ``external_modules:`` — Skynet-IADS, CTLD
- ``qra:``              — VeafQRA builder chains (inside QRA module block)
- ``cap_missions:``     — veafCombatMission.addCapMission() calls
- ``combat_missions:``  — veafCombatMission.AddMissionsWithSkillAndScale() calls
"""

from __future__ import annotations

import re

from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.lua_module_scanner import get_modules

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: Recommended module initialisation order.
#: INTERPRETER **must** remain last.
_MODULE_INIT_ORDER: list[str] = [
    "SECURITY",
    "RADIO",
    "SHORTCUTS",
    "NAMEDPOINTS",
    "SPAWN",
    "CARRIER",
    "CASMISSION",
    "TRANSPORTMISSION",
    "COMBATMISSION",
    "COMBATZONE",
    "QRA",
    "GRASS",
    "ASSETS",
    "AIRWAVES",
    "MOVE",
    "SANCTUARY",
    "WEATHER",
    "REMOTE",
    "AIRBASES",
    "MARKERS",
    "MISSILEGUARDIAN",
    "TIME",
    "UNITS",
    "CACHE",
    "EVENTS",
    "GROUNDAI",
    "SKYNET",
    "SKYNET_MONITOR",
    "INTERPRETER",  # MUST be last
]

#: Per-module ``initialize()`` positional arguments.
#: Maps module ID → list of ``(yaml_key, python_default)`` tuples.
_MODULE_INIT_PARAMS: dict[str, list[tuple[str, object]]] = {
    "RADIO": [("help_menus", True)],
    "CARRIER": [("include_carrier_operations_radio", True)],
}

#: YAML keys that are NOT forwarded as ``veaf.setConfig()`` calls.
_SKIP_SETCONFIG_KEYS: frozenset[str] = frozenset(
    {
        "enable",
        "logLevel",
        "init",
        "assets",
        "custom_points",
        "shortcuts",
        "sanctuary_zones",
        "combat_zone_settings",
        "combat_zones",
        "airwave_zones",
        "password_mm_hashes",
    }
)

#: Module IDs that do NOT have a global ``initialize()`` function.
#: Their data (zones, etc.) is emitted directly without an ``initialize()`` call.
_NO_INIT_MODULES: frozenset[str] = frozenset({"AIRWAVES"})

#: Cosmetic category groupings for YAML template and generated Lua output.
_MODULE_CATEGORIES: dict[str, list[str]] = {
    "Infrastructure": ["UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"],
    "Core": ["SECURITY", "RADIO", "GROUNDAI", "SHORTCUTS", "NAMEDPOINTS", "SPAWN"],
    "Features": [
        "ASSETS",
        "MOVE",
        "GRASS",
        "SANCTUARY",
        "WEATHER",
        "REMOTE",
        "AIRBASES",
        "MISSILEGUARDIAN",
        "INTERPRETER",
    ],
    "Combat": [
        "CASMISSION",
        "TRANSPORTMISSION",
        "COMBATMISSION",
        "COMBATZONE",
        "QRA",
        "AIRWAVES",
        "CARRIER",
    ],
    "External": ["SKYNET", "SKYNET_MONITOR"],
}

#: Flat module→category reverse lookup (built once at module load time).
_MODULE_TO_CATEGORY: dict[str, str] = {mod_id: cat for cat, ids in _MODULE_CATEGORIES.items() for mod_id in ids}

#: Modules that are mandatory (infrastructure tier).
#: These are always active; specifying ``enable`` (true or false) for them is an error.
_MANDATORY_MODULES: frozenset[str] = frozenset({"UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"})

#: Dependency graph: module_id → list of module IDs it requires.
_MODULE_DEPS: dict[str, list[str]] = {
    # Core
    "COMMANDS": ["MARKERS"],
    "GROUNDAI": ["COMMANDS"],
    "SHORTCUTS": ["RADIO", "COMMANDS"],
    "NAMEDPOINTS": ["COMMANDS"],
    "SPAWN": ["UNITS"],
    # Features
    "ASSETS": ["RADIO", "SPAWN"],
    "MOVE": ["SPAWN", "COMMANDS"],
    "GRASS": ["SPAWN"],
    "INTERPRETER": ["RADIO", "COMMANDS"],
    # Combat
    "CASMISSION": ["SPAWN", "GROUNDAI"],
    "TRANSPORTMISSION": ["SPAWN"],
    "COMBATMISSION": ["SPAWN"],
    "COMBATZONE": ["SPAWN"],
    "QRA": ["SPAWN", "RADIO"],
    "AIRWAVES": ["SPAWN"],
    "CARRIER": ["RADIO"],
    # External
    "SKYNET_MONITOR": ["SKYNET"],
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _to_lua_scalar(value: object) -> str:
    """Convert a Python scalar to a Lua literal string."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if value is None:
        return "nil"
    return f'"{value}"'


def _lua_long_string(text: str) -> str:
    """Wrap *text* in a Lua long-string with a dynamically chosen bracket level.

    Chooses the minimum number of ``=`` characters such that the closing
    bracket sequence does not appear anywhere in *text*, making the result
    valid for any input.
    """
    level = 0
    while f"]{('=' * level)}]" in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[{text}]{eq}]"


def _emit_lua_string(value: str) -> str:
    """Return a valid Lua string literal for *value*.

    Uses a Lua long-string (``[[...]]`` or equivalent) when the value contains
    a newline, a double-quote, or a backslash — characters that either cannot
    appear unescaped inside a plain ``"..."`` Lua string or would be silently
    transformed by Lua's escape processing.  Otherwise wraps in double quotes.
    """
    if "\n" in value or '"' in value or "\\" in value:
        return _lua_long_string(value)
    return f'"{value}"'


def _yaml_comment(key: str) -> list[str]:
    """Convert a catalog entry to a list of YAML ``# ...`` comment lines.

    Each line in the translated text becomes ``# <line>``.  Blank lines
    become a bare ``#``.
    """
    return [f"# {line}" if line.strip() else "#" for line in t(key).splitlines()]


def _build_id_to_var() -> dict[str, str]:
    """Return a mapping of module ID → Lua variable name from the module list."""
    result: dict[str, str] = {}
    for mod in get_modules():
        var_name = mod["filename"].removesuffix(".lua")
        result[mod["id"]] = var_name
    return result


def _emit_module_body(
    lines: list[str],
    mod_id: str,
    mod_cfg: dict,
    var_name: str,
    qra_section: dict,
    cap_missions: list,
    combat_missions_data: list,
) -> None:
    """Emit the body of an ``if varName then … end`` initialisation block."""
    init_cfg: dict = mod_cfg.get("init") or {}

    if mod_id in _MODULE_INIT_PARAMS:
        # Modules with typed positional args to initialize()
        param_specs = _MODULE_INIT_PARAMS[mod_id]
        args = ", ".join(_to_lua_scalar(init_cfg.get(yaml_key, default)) for yaml_key, default in param_specs)
        lines.append(f"    {var_name}.initialize({args})")

    elif mod_id == "NAMEDPOINTS":
        custom_points: list = mod_cfg.get("custom_points") or []
        if custom_points:
            lines.append("    local customPoints = {")
            for pt in custom_points:
                pt_name = pt.get("name", "")
                lat = pt.get("lat", "0")
                lon = pt.get("lon", "0")
                lines.append(f'        {{name = "{pt_name}", point = coord.LLtoLO("{lat}", "{lon}")}},')
            lines.append("    }")
            lines.append("    veafNamedPoints.initialize(customPoints)")
        else:
            lines.append("    veafNamedPoints.initialize({})")

    elif mod_id == "ASSETS":
        assets: list = mod_cfg.get("assets") or []
        if assets:
            lines.append(f"    {var_name}.Assets = {{")
            for asset in assets:
                parts: list[str] = []
                parts.append(f"sort = {_to_lua_scalar(asset.get('sort', 0))}")
                parts.append(f"name = {_emit_lua_string(str(asset.get('name', '')))}")
                parts.append(f"description = {_emit_lua_string(str(asset.get('description', '')))}")
                info = str(asset.get("information", ""))
                parts.append(f"information = {_emit_lua_string(info)}")
                for opt_key in ("linked", "jtac", "freq", "mod"):
                    if opt_key in asset and asset[opt_key] is not None:
                        parts.append(f"{opt_key} = {_to_lua_scalar(asset[opt_key])}")
                lines.append("        {" + ", ".join(parts) + "},")
            lines.append("    }")
        lines.append(f"    {var_name}.initialize()")

    elif mod_id == "QRA":
        lines.append(f"    {var_name}.initialize()")
        if qra_section:
            silence_all = qra_section.get("silence_all", False)
            if silence_all is not None:
                lines.append(f"    VeafQRA.ToggleAllSilence({'true' if silence_all else 'false'})")
            for qra_def in qra_section.get("definitions") or []:
                lines.extend(_emit_qra_definition(qra_def, indent="    "))

    elif mod_id == "COMBATMISSION":
        lines.append(f"    {var_name}.initialize()")
        for cap in cap_missions:
            g = cap.get("group_name", "")
            m = cap.get("menu_name", "")
            b = cap.get("briefing", "")
            d = "true" if cap.get("default", False) else "false"
            a = "true" if cap.get("activated", True) else "false"
            lines.append(f'    {var_name}.addCapMission("{g}", "{m}", "{b}", {d}, {a})')
        for cm in combat_missions_data:
            lines.extend(_emit_combat_mission(cm, var_name, indent="    "))

    elif mod_id == "SHORTCUTS":
        shortcuts: list = mod_cfg.get("shortcuts") or []
        lines.append(f"    {var_name}.initialize()")
        for alias in shortcuts:
            name = alias.get("name", "")
            desc = alias.get("description", "")
            cmd = alias.get("command", "")
            bypass = "true" if alias.get("bypass_security", False) else "false"
            lines.append(f"    {var_name}.AddAlias(")
            lines.append("        VeafAlias:new()")
            lines.append(f'        :setName("{name}")')
            if desc:
                lines.append(f'        :setDescription("{desc}")')
            lines.append(f'        :setVeafCommand("{cmd}")')
            lines.append(f"        :setBypassSecurity({bypass})")
            lines.append("    )")

    elif mod_id == "SANCTUARY":
        sanctuary_zones: list = mod_cfg.get("sanctuary_zones") or []
        lines.append(f"    {var_name}.initialize()")
        for zone in sanctuary_zones:
            name = zone.get("name", "")
            polygon_units: list = zone.get("polygon_units") or []
            units_lua = "{" + ", ".join(f'"{u}"' for u in polygon_units) + "}"
            lines.append(f"    {var_name}.addZone(")
            lines.append("        VeafSanctuaryZone:new()")
            lines.append(f'        :setName("{name}")')
            lines.append(f"        :setPolygonFromUnits({units_lua})")
            for setter, yaml_key in [
                ("setCoalition", None),  # special: coalition.side.X
                ("setDelayWarning", "delay_warning"),
                ("setDelaySpawn", "delay_spawn"),
                ("setDelayInstant", "delay_instant"),
                ("setProtectFromMissiles", "protect_from_missiles"),
            ]:
                if setter == "setCoalition":
                    if "coalition" in zone:
                        lines.append(f"        :setCoalition(coalition.side.{zone['coalition']})")
                elif yaml_key and yaml_key in zone:
                    v = zone[yaml_key]
                    lines.append(f"        :{setter}({_to_lua_scalar(v)})")
            lines.append("    )")

    elif mod_id == "COMBATZONE":
        cz_settings: dict = mod_cfg.get("combat_zone_settings") or {}
        cz_zones: list = mod_cfg.get("combat_zones") or []

        # Emit global settings
        if ev_complete := cz_settings.get("event_message_combatzonecomplete"):
            lines.append(f'    {var_name}.EventMessages.CombatZoneComplete = "{ev_complete}"')
        elif (
            "event_message_combatzonecomplete" in cz_settings
            and cz_settings["event_message_combatzonecomplete"] is None
        ):
            lines.append(f"    {var_name}.EventMessages.CombatZoneComplete = nil")
        if wci := cz_settings.get("watchdog_check_interval"):
            lines.append(f"    {var_name}.SecondsBetweenWatchdogChecks = {wci}")
        if rmn := cz_settings.get("radio_menu_name"):
            lines.append(f'    {var_name}.RadioMenuName = "{rmn}"')
        if czrmn := cz_settings.get("combat_zone_menu_name"):
            lines.append(f'    {var_name}.CombatZoneRadioMenuName = "{czrmn}"')
        if ormn := cz_settings.get("operation_menu_name"):
            lines.append(f'    {var_name}.OperationRadioMenuName = "{ormn}"')

        # Emit zone definitions
        for zone_def in cz_zones:
            zone_type = zone_def.get("type", "zone")
            if zone_type == "operation":
                lines.extend(_emit_combat_operation(zone_def, var_name, indent="    "))
            else:
                lines.extend(_emit_combat_zone_def(zone_def, var_name, indent="    "))

        lines.append(f"    {var_name}.initialize()")

    elif mod_id == "AIRWAVES":
        airwave_zones: list = mod_cfg.get("airwave_zones") or []
        for zone in airwave_zones:
            lines.extend(_emit_airwave_zone(zone, indent="    "))
        # No global initialize() — AirWaves is "use by construction"

    else:
        if mod_id not in _NO_INIT_MODULES:
            lines.append(f"    {var_name}.initialize()")


def _emit_combat_zone_def(zone_def: dict, var_name: str, indent: str = "    ") -> list[str]:
    """Emit a VeafCombatZone:new():...:initialize() builder chain."""
    lines: list[str] = []
    zone_name = zone_def.get("zone_name", "")
    lines.append(f"{indent}{var_name}.AddZone(")
    lines.append(f"{indent}    VeafCombatZone:new()")
    lines.append(f'{indent}    :setMissionEditorZoneName("{zone_name}")')
    if fn := zone_def.get("friendly_name"):
        lines.append(f'{indent}    :setFriendlyName("{fn}")')
    if br := zone_def.get("briefing"):
        br_lua = _lua_long_string(br.strip())
        lines.append(f"{indent}    :setBriefing({br_lua})")
    if zone_def.get("user_activation_disabled"):
        lines.append(f"{indent}    :disableUserActivation()")
    if "training" in zone_def:
        lines.append(f"{indent}    :setTraining({'true' if zone_def['training'] else 'false'})")
    for cz in zone_def.get("chained_zones") or []:
        lines.append(f'{indent}    :addChainedCombatZone("{cz}")')
    if cd := zone_def.get("chained_delay"):
        lines.append(f"{indent}    :setChainedCombatZonesDelay({cd})")
    lines.append(f"{indent}    :initialize()")
    lines.append(f"{indent})")
    if hint := zone_def.get("on_completed_hook_hint"):
        lines.append(
            f'{indent}-- [v6 migration] set callback: {var_name}.GetZone("{zone_name}"):setOnCompletedHook({hint})'
        )
    return lines


def _emit_combat_operation(op_def: dict, var_name: str, indent: str = "    ") -> list[str]:
    """Emit a VeafCombatOperation:new():...:initialize() builder chain."""
    lines: list[str] = []
    zone_name = op_def.get("zone_name", "")
    lines.append(f"{indent}{var_name}.AddZone(")
    lines.append(f"{indent}    VeafCombatOperation:new()")
    lines.append(f'{indent}    :setMissionEditorZoneName("{zone_name}")')
    if fn := op_def.get("friendly_name"):
        lines.append(f'{indent}    :setFriendlyName("{fn}")')
    if br := op_def.get("briefing"):
        br_lua = _lua_long_string(br.strip())
        lines.append(f"{indent}    :setBriefing({br_lua})")
    for order in op_def.get("tasking_orders") or []:
        zone_var = order.get("zone_var", "")
        # zone_var is a local variable name from the original Lua;
        # in the generated code we use GetZone() by the zone_name
        # If we have resolved zone_names, use them; otherwise fall back to var name
        resolved = order.get("zone_name", zone_var)
        deps: list = order.get("dependencies") or []
        deps_vars: list = order.get("dependencies_vars") or []
        if deps:
            deps_lua = "{" + ", ".join(f'"{d}"' for d in deps) + "}"
            lines.append(f'{indent}    :addTaskingOrder({var_name}.GetZone("{resolved}"), {deps_lua})')
        elif deps_vars:
            # Can't resolve var→name statically; emit GetZone with the var as name
            deps_lua = "{" + ", ".join(f'"{d}"' for d in deps_vars) + "}"
            lines.append(f'{indent}    :addTaskingOrder({var_name}.GetZone("{resolved}"), {deps_lua})')
        else:
            lines.append(f'{indent}    :addTaskingOrder({var_name}.GetZone("{resolved}"))')
    lines.append(f"{indent}    :initialize()")
    lines.append(f"{indent})")
    return lines


def _emit_airwave_zone(zone: dict, indent: str = "    ") -> list[str]:
    """Emit an AirWaveZone:new():...:start() builder chain."""
    lines: list[str] = []
    name = zone.get("name", "")
    start_commented = not zone.get("start", False)

    lines.append(f"{indent}AirWaveZone:new()")
    lines.append(f'{indent}    :setName("{name}")')
    if desc := zone.get("description"):
        lines.append(f'{indent}    :setDescription("{desc}")')
    for coalition in zone.get("player_coalitions") or []:
        lines.append(f"{indent}    :addPlayerCoalition(coalition.side.{coalition})")
    if coords := zone.get("zone_center_coordinates"):
        lines.append(f'{indent}    :setZoneCenterFromCoordinates("{coords}")')
    if tz := zone.get("trigger_zone_name"):
        lines.append(f'{indent}    :setTriggerZone("{tz}")')
    if zr := zone.get("zone_radius"):
        lines.append(f"{indent}    :setZoneRadius({zr})")
    if "draw_zone" in zone:
        lines.append(f"{indent}    :setDrawZone({'true' if zone['draw_zone'] else 'false'})")
    if ro := zone.get("respawn_default_offset"):
        lines.append(f"{indent}    :setRespawnDefaultOffset({ro[0]}, {ro[1]})")
    if rr := zone.get("respawn_radius"):
        lines.append(f"{indent}    :setRespawnRadius({rr})")
    if da := zone.get("delay_before_activation"):
        lines.append(f"{indent}    :setDelayBeforeActivation({da})")
    if dbw := zone.get("delay_between_waves"):
        lines.append(f"{indent}    :setDelayBetweenWaves({dbw})")
    if min_bw := zone.get("min_seconds_between_waves"):
        lines.append(f"{indent}    :setMinimumSecondsBetweenWaves({min_bw})")
    if max_bw := zone.get("max_seconds_between_waves"):
        lines.append(f"{indent}    :setMaximumSecondsBetweenWaves({max_bw})")
    if max_alt := zone.get("max_altitude_ft"):
        lines.append(f"{indent}    :setMaximumAltitudeInFeet({max_alt})")
    if min_alt := zone.get("min_altitude_ft"):
        lines.append(f"{indent}    :setMinimumAltitudeInFeet({min_alt})")
    if mso := zone.get("max_seconds_outside_ia"):
        lines.append(f"{indent}    :setMaxSecondsOutsideOfZoneIA({mso})")
    for msg_method, yaml_key in [
        ("setMessageStart", "message_start"),
        ("setMessageWaitForHumans", "message_wait_for_humans"),
        ("setMessageWaveDeployed", "message_wave_deployed"),
        ("setMessageEndZone", "message_end_zone"),
        ("setMessageEndAll", "message_end_all"),
    ]:
        if msg := zone.get(yaml_key):
            msg_lua = _lua_long_string(msg)
            lines.append(f"{indent}    :{msg_method}({msg_lua})")
    for wave in zone.get("waves") or []:
        parts = []
        if g := wave.get("groups"):
            parts.append(f'groups = "{g}"')
        if "delay" in wave:
            parts.append(f"delay = {wave['delay']}")
        if n := wave.get("number"):
            parts.append(f'number = "{n}"')
        if "bias" in wave:
            parts.append(f"bias = {wave['bias']}")
        wave_lua = "{" + ", ".join(parts) + "}" if parts else '""'
        lines.append(f"{indent}    :addWave({wave_lua})")
    if mlp := zone.get("minimum_life_percent"):
        lines.append(f"{indent}    :setMinimumLifeForAiInPercent({mlp})")
    if "reset_when_dying" in zone:
        lines.append(f"{indent}    :setResetWhenDying({'true' if zone['reset_when_dying'] else 'false'})")
    if start_commented:
        lines.append(f"{indent}    -- :start()  -- set start: true in mission.yaml to enable")
    else:
        lines.append(f"{indent}    :start()")
    return lines


def _emit_qra_definition(qra_def: dict, indent: str = "    ") -> list[str]:
    """Emit a ``VeafQRA:new():...:start()`` builder chain from a YAML definition."""
    lines: list[str] = []
    name = qra_def.get("name", "QRA")
    # Produce a valid Lua variable name from the display name
    var = re.sub(r"[^A-Za-z0-9_]", "_", name).lstrip("_") or "QRA_var"
    coalition = qra_def.get("coalition", "RED")
    enemy_coalitions: list = qra_def.get("enemy_coalitions") or []

    lines.append(f"{indent}local {var} = VeafQRA:new()")
    lines.append(f'{indent}    :setName("{name}")')
    lines.append(f"{indent}    :setCoalition(coalition.side.{coalition})")
    for enemy in enemy_coalitions:
        lines.append(f"{indent}    :addEnnemyCoalition(coalition.side.{enemy})")

    if tz := qra_def.get("trigger_zone"):
        lines.append(f'{indent}    :setTriggerZone("{tz}")')
    if zr := qra_def.get("zone_radius"):
        lines.append(f"{indent}    :setZoneRadius({zr})")

    for grp in qra_def.get("simple_groups") or []:
        lines.append(f'{indent}    :addGroup("{grp}")')

    for gbc in qra_def.get("groups_by_enemy_count") or []:
        count = gbc.get("enemy_count", 1)
        groups: list = gbc.get("groups") or []
        pick = gbc.get("random_pick", 1)
        groups_lua = "{" + ", ".join(f'"{g}"' for g in groups) + "}"
        lines.append(f"{indent}    :setRandomGroupsToDeployByEnemyQuantity({count}, {groups_lua}, {pick})")

    if dbr := qra_def.get("delay_before_rearming"):
        lines.append(f"{indent}    :setDelayBeforeRearming({dbr})")
    if dba := qra_def.get("delay_before_activating"):
        lines.append(f"{indent}    :setDelayBeforeActivating({dba})")
    if qra_def.get("react_on_helicopters"):
        lines.append(f"{indent}    :setReactOnHelicopters()")
    if al := qra_def.get("airport_link"):
        lines.append(f'{indent}    :setAirportLink("{al}")')

    lines.append(f"{indent}    :start()")
    return lines


def _emit_combat_mission(cm: dict, var_name: str, indent: str = "    ") -> list[str]:
    """Emit a ``veafCombatMission.AddMissionsWithSkillAndScale(...)`` call."""
    lines: list[str] = []
    name = cm.get("name", "")
    friendly_name = cm.get("friendly_name", "")
    secured = "true" if cm.get("secured", False) else "false"
    radio_menu = "true" if cm.get("radio_menu_enabled", True) else "false"
    briefing = str(cm.get("briefing", ""))
    elements: list = cm.get("elements") or []

    lines.append(f"{indent}{var_name}.AddMissionsWithSkillAndScale(")
    lines.append(f"{indent}    VeafCombatMission:new()")
    lines.append(f'{indent}    :setName("{name}")')
    if friendly_name:
        lines.append(f'{indent}    :setFriendlyName("{friendly_name}")')
    lines.append(f"{indent}    :setSecured({secured})")
    lines.append(f"{indent}    :setRadioMenuEnabled({radio_menu})")
    if briefing:
        briefing_lua = _lua_long_string(briefing.strip())
        lines.append(f"{indent}    :setBriefing({briefing_lua})")
    for elem in elements:
        elem_name = elem.get("name", "")
        groups: list = elem.get("groups") or []
        scalable = "true" if elem.get("scalable", True) else "false"
        groups_lua = "{" + ", ".join(f'"{g}"' for g in groups) + "}"
        lines.append(f"{indent}    :addElement(")
        lines.append(f"{indent}        VeafCombatMissionElement:new()")
        lines.append(f'{indent}        :setName("{elem_name}")')
        lines.append(f"{indent}        :setGroups({groups_lua})")
        lines.append(f"{indent}        :setScalable({scalable})")
        lines.append(f"{indent}    )")
    lines.append(f"{indent})")
    return lines


def _resolve_deps(effective: dict) -> dict:
    """Auto-enable missing or disabled dependencies; return updated dict.

    For each enabled module that declares dependencies in ``_MODULE_DEPS``,
    any dependency that is absent or explicitly disabled is auto-added with
    ``enable: true`` and a ``logger.warning`` is emitted.  The loop repeats
    until no more changes are needed (handles transitive dependency chains).
    """
    changed = True
    while changed:
        changed = False
        for mod_id, deps in _MODULE_DEPS.items():
            cfg = effective.get(mod_id, {})
            if isinstance(cfg, dict) and cfg.get("enable") is False:
                continue  # explicitly disabled — skip dep check
            if mod_id not in effective:
                continue  # not requested — skip
            for dep in deps:
                dep_cfg = effective.get(dep, {})
                if isinstance(dep_cfg, dict) and dep_cfg.get("enable") is False:
                    logger.warning(
                        f"Module '{mod_id}' requires '{dep}' but '{dep}' is disabled — auto-enabling '{dep}'"
                    )
                    dep_cfg["enable"] = True
                    effective[dep] = dep_cfg
                    changed = True
                elif dep not in effective:
                    logger.warning(
                        f"Module '{mod_id}' requires '{dep}' which is not configured — auto-enabling '{dep}'"
                    )
                    effective[dep] = {"enable": True}
                    changed = True
    return effective


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def generate_config_lua(
    mission_yaml: dict,
    header: str | None = None,
) -> str:
    """Render ``veaf-config.lua`` from the full *mission_yaml* content dict.

    Parameters
    ----------
    mission_yaml:
        Parsed content of ``mission.yaml`` (from ``yaml.safe_load``).
    header:
        Comment text prepended after the separator line. Defaults to the
        localised generated-file header from the i18n catalog.

    Returns
    -------
    str
        Complete Lua source ready to be written to ``veaf-config.lua``.
    """
    if header is None:
        raw = t("generated.config_lua.header")
        header = "\n".join(f"-- {line}" if not line.startswith("--") else line for line in raw.splitlines())
    sep = "-" * 141
    lines: list[str] = [sep, header, sep, ""]

    id_to_var = _build_id_to_var()

    # ── Mission identity ───────────────────────────────────────────────────
    mission_cfg: dict = mission_yaml.get("mission") or {}
    if mission_cfg:
        lines.append("-- ── Mission identity ─────────────────────────────────────────────────────────")
        if name := mission_cfg.get("name"):
            lines.append(f'veaf.config.MISSION_NAME = "{name}"')
        export_path = mission_cfg.get("export_path")
        if export_path is not None:
            lua_ep = "nil" if not export_path else f'"{export_path}"'
            lines.append(f"veaf.config.MISSION_EXPORT_PATH = {lua_ep}")
        if era := mission_cfg.get("era"):
            lines.append(f"veaf.config.era = veaf.ERA.{era}")
        if language := mission_cfg.get("language"):
            lines.append(f'veaf.config.language = "{language}"')
        lines.append("")

    # ── Security ──────────────────────────────────────────────────────────
    security_cfg: dict = mission_yaml.get("security") or {}
    if security_cfg:
        lines.append("-- ── Security ─────────────────────────────────────────────────────────────────")
        if "disabled" in security_cfg:
            lines.append(f"veaf.SecurityDisabled = {'true' if security_cfg['disabled'] else 'false'}")
        for hash_val in security_cfg.get("password_hashes") or []:
            lines.append(f'veafSecurity.password_L9["{hash_val}"] = true')
        mm_hashes: list = security_cfg.get("password_mm_hashes") or []
        if mm_hashes:
            lines.append("veafSecurity.password_MM = {}")
            for hash_val in mm_hashes:
                lines.append(f'veafSecurity.password_MM["{hash_val}"] = true')
        lines.append("")

    # ── Global log level ──────────────────────────────────────────────────
    if global_log_level := mission_yaml.get("global_log_level"):
        lines.append("-- ── Global log level ─────────────────────────────────────────────────────────")
        lines.append(f'veaf.ForcedLogLevel = "{global_log_level}"')
        lines.append("")

    # ── Settings ──────────────────────────────────────────────────────────
    settings: dict = mission_yaml.get("settings") or {}
    if settings:
        lines.append("-- ── Settings ─────────────────────────────────────────────────────────────────")
        for key, value in settings.items():
            lines.append(f"veaf.config.{key} = {_to_lua_scalar(value)}")
        lines.append("")

    # ── Module configuration + initialization ─────────────────────────────
    lua_modules: dict = mission_yaml.get("lua_modules") or {}
    qra_section: dict = mission_yaml.get("qra") or {}
    cap_missions: list = mission_yaml.get("cap_missions") or []
    combat_missions_data: list = mission_yaml.get("combat_missions") or []
    external_modules: dict = mission_yaml.get("external_modules") or {}
    skynet_cfg: dict = external_modules.get("skynet") or {}
    ctld_cfg: dict = external_modules.get("ctld") or {}

    if lua_modules:
        # ── MODUX-002: error on mandatory modules with any enable key ────
        effective_modules: dict = dict(lua_modules)
        for mandatory_id in _MANDATORY_MODULES:
            mcfg = effective_modules.get(mandatory_id, {})
            if isinstance(mcfg, dict) and "enable" in mcfg:
                logger.error(t("builder.mandatory_module_enable", module=mandatory_id, value=mcfg["enable"]))

        # ── MODUX-003: auto-resolve missing/disabled dependencies ─────────
        effective_modules = _resolve_deps(effective_modules)

        lines.append("-- ── Module configuration + initialization ────────────────────────────────────")
        lines.append("")

        # Determine full ordered list: known order + unknown modules + INTERPRETER
        known_order_set = set(_MODULE_INIT_ORDER)
        all_module_ids = {m["id"] for m in get_modules()}
        extra_ids = [mid for mid in effective_modules if mid not in known_order_set and mid in all_module_ids]
        ordered_ids = [mid for mid in _MODULE_INIT_ORDER if mid != "INTERPRETER"] + extra_ids + ["INTERPRETER"]

        # ── MODUX-001: track category to emit comment headers ─────────────
        current_category: str | None = None

        for mod_id in ordered_ids:
            mod_cfg: dict | None = effective_modules.get(mod_id)
            if mod_cfg is None:
                continue

            # Emit category header when entering a new category
            cat = _MODULE_TO_CATEGORY.get(mod_id)
            if cat and cat != current_category:
                current_category = cat
                lines.append(f"-- ── {cat} ──")
                lines.append("")

            enabled = mod_cfg.get("enable", True)
            log_level: str | None = mod_cfg.get("logLevel")

            if not enabled:
                # Disabled: emit only the setConfig(enable=false)
                lines.append(f'veaf.setConfig("{mod_id}", "enable", false)')
                if log_level:
                    lines.append(f'veaf.setConfig("{mod_id}", "logLevel", "{log_level}")')
                lines.append("")
                continue

            # Per-module log level override
            if log_level:
                lines.append(f'veaf.setConfig("{mod_id}", "logLevel", "{log_level}")')

            # Additional setConfig keys (not special keys handled elsewhere)
            for key, value in mod_cfg.items():
                if key in _SKIP_SETCONFIG_KEYS:
                    continue
                lines.append(f'veaf.setConfig("{mod_id}", "{key}", {_to_lua_scalar(value)})')

            var_name = id_to_var.get(mod_id)
            if not var_name:
                lines.append(f"-- {t('generated.config_lua.module_skipped', id=mod_id)}")
                lines.append("")
                continue

            lines.append(f"if {var_name} then")
            _emit_module_body(lines, mod_id, mod_cfg, var_name, qra_section, cap_missions, combat_missions_data)
            lines.append("end")
            lines.append("")

    # ── External modules ──────────────────────────────────────────────────
    if skynet_cfg.get("enabled"):
        include_red = skynet_cfg.get("include_red_in_radio", False)
        debug_red = skynet_cfg.get("debug_red", False)
        include_blue = skynet_cfg.get("include_blue_in_radio", False)
        debug_blue = skynet_cfg.get("debug_blue", False)
        r = "true" if include_red else "false"
        dr = "true" if debug_red else "false"
        b = "true" if include_blue else "false"
        db = "true" if debug_blue else "false"
        lines.append("-- ── Skynet-IADS ──────────────────────────────────────────────────────────────")
        lines.append("if veafSkynet then")
        lines.append(f"    veafSkynet.initialize({r}, {dr}, {b}, {db})")
        lines.append("end")
        lines.append("")

    if ctld_cfg.get("enabled"):
        lines.append("-- ── CTLD configuration ───────────────────────────────────────────────────────")
        lines.append("-- Note: CTLD.lua must be loaded by mission-script.lua before this block.")
        lines.append("if ctld then")
        ctld_props = {k: v for k, v in ctld_cfg.items() if k != "enabled"}
        for key, value in ctld_props.items():
            lines.append(f"    ctld.{key} = {_to_lua_scalar(value)}")
        lines.append("    ctld.initialize()")
        lines.append("end")
        lines.append("")

    csar_cfg: dict = external_modules.get("csar") or {}
    if csar_cfg.get("enabled"):
        lines.append("-- ── CSAR configuration ───────────────────────────────────────────────────────")
        lines.append("-- Note: CSAR.lua must be loaded by mission-script.lua before this block.")
        lines.append("if csar then")
        csar_props = {k: v for k, v in csar_cfg.items() if k != "enabled"}
        for key, value in csar_props.items():
            lines.append(f"    csar.{key} = {_to_lua_scalar(value)}")
        lines.append("    csar.initialize()")
        lines.append("end")
        lines.append("")

    return "\n".join(lines)


def generate_mission_yaml_template(
    modules: list | None = None,
    enabled_module_ids: set[str] | None = None,
) -> str:
    """Produce a fully-commented ``mission.yaml`` template.

    Parameters
    ----------
    modules:
        List of :class:`~veaf_libs.lua_module_scanner.LuaModule` dicts.
        If *None*, :func:`get_modules` is called.
    enabled_module_ids:
        Set of module IDs to mark as ``enable: true`` (uncommented).
        All others are commented out.  If *None*, all modules appear
        as commented-out examples.
    """
    if modules is None:
        modules = get_modules()
    enabled_set: set[str] = enabled_module_ids or set()

    lines: list[str] = []

    # ── File header ───────────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.header"))
    lines.append("")

    # ── Global log level ──────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.global_log_level"))
    lines.append("#")
    lines.append("# global_log_level: debug")
    lines.append("")

    # ── Mission identity ──────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.mission"))
    lines.append("# mission:")
    lines.append('#   name: "My Mission"          # shown in radio menus and log messages')
    lines.append("#   export_path: null           # null = default DCS Saved Games path")
    lines.append("#   era: MODERN                 # MODERN | COLD_WAR | WW2")
    lines.append(f"#   language: en                # {t('generated.mission_yaml.field.language')}")
    lines.append("")

    # ── Security ──────────────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.security"))
    lines.append("# security:")
    lines.append("#   disabled: true              # true = no password required (default)")
    lines.append("#   password_hashes:            # add SHA-256 hashes to restrict access")
    lines.append('#     - "<SHA-256 hash>"')
    lines.append("")

    # ── Generic settings ──────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.settings"))
    lines.append("# settings:")
    lines.append('#   MY_SETTING: "value"')
    lines.append("")

    # ── Module configuration ──────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.modules"))
    lines.append("#")
    lines.append("lua_modules:")

    # Emit module entries in recommended order
    ordered_ids = _MODULE_INIT_ORDER
    all_module_map = {m["id"]: m for m in modules}

    # Emit all modules grouped by category, enabled ones uncommented, others commented
    all_ordered = [mid for mid in ordered_ids if mid in all_module_map]
    remaining = [mid for mid in all_module_map if mid not in set(ordered_ids)]

    current_category: str | None = None
    for mid in all_ordered + remaining:
        cat = _MODULE_TO_CATEGORY.get(mid)
        if cat and cat != current_category:
            current_category = cat
            mandatory_note = " (mandatory — cannot be disabled)" if cat == "Infrastructure" else ""
            lines.append(f"  # ── {cat}{mandatory_note} ──")
        is_enabled = mid in enabled_set
        yaml_key = f'"{mid}"' if not re.match(r"^[A-Za-z_]\w*$", mid) else mid
        if is_enabled:
            lines.append(f"  {yaml_key}:")
            lines.append("    enable: true")
            # Show init params example for known modules
            if mid in _MODULE_INIT_PARAMS:
                lines.append("    # init:")
                for yaml_k, default in _MODULE_INIT_PARAMS[mid]:
                    lines.append(f"    #   {yaml_k}: {_to_lua_scalar(default)}")
            # Show data subsections for special modules
            if mid == "ASSETS":
                lines.append("    # assets:  # list of asset entries")
                lines.append("    #   - sort: 1")
                lines.append('    #     name: "T1-Arco"')
                lines.append('    #     description: "Arco (KC-135)"')
                lines.append('    #     information: "Tacan 64Y\\nU290.50"')
            elif mid == "NAMEDPOINTS":
                lines.append("    # custom_points:  # list of custom POIs")
                lines.append('    #   - name: "Battle Area Alpha"')
                lines.append('    #     lat: "41.123456"')
                lines.append('    #     lon: "44.987654"')
        else:
            lines.append(f"  # {yaml_key}:")
            lines.append("  #   enable: false")

    # ── External modules ──────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.external"))
    lines += [
        "# external_modules:",
        "#   skynet:",
        "#     enabled: false",
        "#     include_red_in_radio: false",
        "#     debug_red: false",
        "#     include_blue_in_radio: false",
        "#     debug_blue: false",
        "#   ctld:",
        "#     enabled: false",
        "#     # ctld.xxx = value  (e.g. hoverPickup: true)",
        "#   csar:",
        "#     enabled: false",
        "#     # csar.xxx = value  (e.g. enableAllslots: true)",
    ]

    # ── QRA ───────────────────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.qra"))
    lines += [
        "# qra:",
        "#   silence_all: false",
        "#   definitions:",
        '#     - name: "Base QRA"',
        "#       coalition: RED           # RED | BLUE | NEUTRAL",
        "#       enemy_coalitions: [BLUE]",
        '#       trigger_zone: "QRA zone"',
        "#       zone_radius: 30000",
        "#       groups_by_enemy_count:",
        "#         - enemy_count: 1",
        '#           groups: ["Group1", "Group2"]',
        "#           random_pick: 1       # how many groups to pick randomly",
        "#       delay_before_rearming: 30",
        "#       delay_before_activating: 30",
        "#       # react_on_helicopters: true",
        '#       # airport_link: "Kutaisi"',
    ]

    # ── CAP missions ──────────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.cap"))
    lines += [
        "# cap_missions:",
        '#   - group_name: "CAP Group"',
        '#     menu_name: "CAP"',
        '#     briefing: "CAP mission briefing"',
        "#     default: false",
        "#     activated: true",
    ]

    # ── Combat missions ───────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.combat"))
    lines += [
        "# combat_missions:",
        '#   - name: "Mission Name"',
        '#     friendly_name: "Display Name"',
        "#     secured: false",
        "#     radio_menu_enabled: true",
        "#     briefing: |",
        "#       Multi-line briefing text here.",
        "#     elements:",
        '#       - name: "Element Name"',
        '#         groups: ["Group1", "Group2"]',
        "#         scalable: true",
    ]

    # ── Build pipeline ─────────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.pipeline"))
    lines += [
        "#",
        "# pipeline:",
        "#   presets: true             # src/presets.yaml",
        "#   waypoints: true           # src/waypoints.yaml",
        "#   aircraft_groups: true     # src/aircraft-templates.yaml",
        "#   weather: true             # src/versions.yaml",
    ]

    return "\n".join(lines) + "\n"
