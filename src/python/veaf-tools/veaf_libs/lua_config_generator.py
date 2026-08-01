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
                          (internal split of the unified ``modules:`` block)
- ``external_modules:`` — internal repr for Skynet-IADS / CTLD / CSAR, populated
                          from ``modules.SKYNET`` / ``modules.CTLD`` / ``modules.CSAR``
- ``qra:``              — internal repr for VeafQRA chains, populated from ``modules.QRA``
- ``cap_missions:``     — veafCombatMission.addCapMission() calls
- ``combat_missions:``  — veafCombatMission.AddMissionsWithSkillAndScale() calls
"""

from __future__ import annotations

import re
from collections.abc import Mapping, Sequence

from veaf_libs.checklists import Checklist, ChecklistStep
from veaf_libs.i18n import current_language, t
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
#:
#: A key whose default is ``None`` is **optional**: it is only passed when the mission declares
#: it, so a mission that never mentions it generates the exact same call as before the key
#: existed. That is how ``RADIO.create_menus`` stays additive.
_MODULE_INIT_PARAMS: dict[str, list[tuple[str, object]]] = {
    "RADIO": [("help_menus", True), ("create_menus", None)],
    "CARRIER": [("include_carrier_operations_radio", True)],
}

#: Init keys whose YAML meaning is the negation of the Lua parameter they feed.
#: ``create_menus: false`` → ``dontCreateMenus = true``: the YAML says what the mission-maker
#: wants, the Lua says what the function takes.
_NEGATED_INIT_KEYS: frozenset[str] = frozenset({"create_menus"})

#: YAML keys that are NOT forwarded as ``veaf.setConfig()`` calls.
_SKIP_SETCONFIG_KEYS: frozenset[str] = frozenset(
    {
        "enable",
        "enabled",
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


def yaml_syntax_header() -> list[str]:
    """Return the localized YAML syntax quick-reference block.

    Returns:
        List of comment lines to prepend to generated mission.yaml files.
    """
    return [
        t("yaml.syntax.title"),
        t("yaml.syntax.indentation"),
        t("yaml.syntax.quotes"),
        f"#   name: Mon-Vol-01            # OK — {t('yaml.syntax.quotes_ok')}",
        f'#   name: "Vol: Aller-Retour"   # {t("yaml.syntax.quotes_required")}',
        t("yaml.syntax.quotes_escapes"),
        f'#   briefing: "Intercept bandits\\nRTB when done"  # {t("yaml.syntax.quotes_escapes_example")}',
        t("yaml.syntax.multiline"),
        "#   briefing: |",
        f"#     {t('yaml.syntax.multiline_example')}",
        t("yaml.syntax.lists"),
        "#   groups:",
        "#     - MIG-29_SOLO",
        "#     - MIG-21_SOLO",
        t("yaml.syntax.booleans"),
        t("yaml.syntax.empty_value"),
        t("yaml.syntax.separator"),
    ]


# ---------------------------------------------------------------------------
# Shared mission.yaml preamble sections
#
# Single source of truth for the invariant (tier-independent) sections of a
# generated mission.yaml. Used by both the rich generator
# (``generate_mission_yaml_template`` / ``generate-config``) and the
# data-driven ``prepare`` template (``mission_template.generate_mission_yaml``),
# so the two scaffolds stay in lockstep instead of drifting copy by copy.
# ---------------------------------------------------------------------------


def global_log_level_section() -> list[str]:
    """Return the commented ``global_log_level:`` section (localized comment + example)."""
    return [
        *_yaml_comment("generated.mission_yaml.section.global_log_level"),
        "#",
        "# global_log_level: debug",
    ]


def mission_identity_section(live_name: str | None = None) -> list[str]:
    """Return the ``mission:`` identity section.

    Args:
        live_name: When given, ``name`` is emitted uncommented so the file is a
            ready-to-build scaffold (used by ``prepare``). When ``None``, the whole
            block is commented (used by ``generate-config``). The optional-field
            hints below ``name`` are always commented.

    Returns:
        The section's comment + body lines (no trailing blank line).
    """
    lines = list(_yaml_comment("generated.mission_yaml.section.mission"))
    if live_name is None:
        lines += [
            "# mission:",
            "#   name: My-Mission              # shown in radio menus and log messages",
        ]
    else:
        lines += [
            "mission:",
            f'  name: "{live_name}"',
        ]
    lines += [
        "#   export_path: null             # null = default DCS Saved Games path",
        "#   era: MODERN                   # MODERN | COLD_WAR | WW2",
        f"#   language: fr                  # {t('generated.mission_yaml.field.language')}",
        "#   silence_atc_on_all_airbases: false  # mission-wide option: silence ATC at every airbase",
    ]
    return lines


def security_section() -> list[str]:
    """Return the commented ``security:`` section (localized comment + example)."""
    return [
        *_yaml_comment("generated.mission_yaml.section.security"),
        "# security:",
        "#   disabled: true                # true = no password required (default)",
        "#   password_hashes:              # add SHA-256 hashes to restrict access",
        '#     - "<SHA-256 hash>"',
    ]


def pipeline_section() -> list[str]:
    """Return the commented build ``pipeline:`` section (localized comment + example)."""
    return [
        *_yaml_comment("generated.mission_yaml.section.pipeline"),
        "#",
        "# pipeline:",
        "#   presets: true                 # src/presets.yaml",
        "#   waypoints: true               # src/waypoints.yaml",
        "#   spawnable_aircrafts: true     # src/spawnables.yaml",
        "#   dynamic_slot_templates: true  # src/dynamic-slot-templates.yaml",
        "#   warehouses: true              # src/warehouses.yaml (Dynamic-Slot warehouses)",
        "#   spawn_data: true              # always on; src/spawn-groups.yaml extends the spawn DB",
        "#   weather: true                 # src/versions.yaml",
    ]


#: Cosmetic category groupings for YAML template and generated Lua output.
MODULE_CATEGORIES: dict[str, list[str]] = {
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
_MODULE_TO_CATEGORY: dict[str, str] = {mod_id: cat for cat, ids in MODULE_CATEGORIES.items() for mod_id in ids}

#: Modules that are mandatory (infrastructure tier).
#: These are always active; specifying ``enable`` (true or false) for them is an error.
MANDATORY_MODULES: frozenset[str] = frozenset({"UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"})

#: Community scripts that are mandatory (always injected, never disabled): MiST is a
#: hard VEAF dependency, so it is never emitted as a disabled ``enable=false`` flag.
_MANDATORY_COMMUNITY_SCRIPTS: frozenset[str] = frozenset({"mist"})


def yaml_module_entry(yaml_key: str, module_id: str, has_config: bool = False) -> list[str]:
    """Return the YAML lines for one enabled module entry in ``mission.yaml``.

    Args:
        yaml_key: The (possibly quoted) YAML key string, e.g. ``RADIO`` or ``"MY-MOD"``.
        module_id: The canonical module ID used to look up mandatory status.
        has_config: When ``True``, emit block style (``key:\\n  enabled: true``) so
            callers can append extra config keys underneath. When ``False`` (default),
            emit the compact shorthand ``key: true`` for optional modules.

    Returns:
        One line ``["  key:"]`` for mandatory modules (null value = always active),
        ``["  key: true"]`` for optional modules without extra config, or
        ``["  key:", "    enabled: true"]`` for optional modules with extra config.
    """
    if module_id in MANDATORY_MODULES:
        return [f"  {yaml_key}:"]
    if has_config:
        return [f"  {yaml_key}:", "    enabled: true"]
    return [f"  {yaml_key}: true"]


def _get_module_enabled(cfg: dict, default: bool = True) -> bool:
    """Read the enabled flag from a module config dict.

    Accepts both ``enabled`` (preferred) and the deprecated ``enable`` key.

    Args:
        cfg: Module configuration dict.
        default: Value returned when neither key is present.

    Returns:
        Boolean enabled state.
    """
    if "enabled" in cfg:
        return bool(cfg["enabled"])
    if "enable" in cfg:
        return bool(cfg["enable"])
    return default


def _normalize_module_cfg(value: object) -> dict:
    """Normalize a raw module config value to a dict.

    Handles the three valid forms in ``modules:`` / ``lua_modules:``:

    - ``None``  (bare ``MODULE:`` in YAML) → ``{}``  (mandatory: no config)
    - ``True`` / ``False`` scalar → ``{"enabled": <bool>}``
    - ``dict`` → returned as-is

    Args:
        value: Raw YAML value for the module key.

    Returns:
        Normalized dict suitable for further processing.
    """
    if value is None:
        return {}
    if isinstance(value, bool):
        return {"enabled": value}
    if isinstance(value, dict):
        return value
    return {}


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


def resolve_module_dependencies(enabled_ids: set[str]) -> list[str]:
    """Return module IDs required (transitively) by *enabled_ids* but absent from it.

    Walks the :data:`_MODULE_DEPS` graph so that, for example, enabling
    ``CASMISSION`` pulls in ``GROUNDAI`` and ``SPAWN`` (and their own
    dependencies). Pure and side-effect free — unlike :func:`_resolve_deps`,
    it neither mutates input nor logs — so callers such as ``convert-v5`` can
    pre-resolve dependencies when generating ``mission.yaml``.

    Args:
        enabled_ids: The module IDs that are explicitly enabled.

    Returns:
        Sorted list of additional module IDs that must be enabled to satisfy
        every declared dependency. Never contains an ID already in
        *enabled_ids*.
    """
    enabled = set(enabled_ids)
    added: set[str] = set()
    queue: list[str] = list(enabled)
    while queue:
        mod_id = queue.pop()
        for dep in _MODULE_DEPS.get(mod_id, []):
            if dep not in enabled and dep not in added:
                added.add(dep)
                queue.append(dep)
    return sorted(added)


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
    """Return a mapping of module ID → Lua variable (table) name from the module list.

    Uses the scanner's ``var_name`` (read from the ``<table>.Id = "..."`` line), NOT
    the filename stem: a module's public table may differ from its file, e.g.
    ``veafSpawnCore.lua`` defines ``veafSpawn`` and ``veafQraCore.lua`` defines
    ``veafQraManager``. Using the filename would emit ``veafSpawnCore.initialize()``
    (a nil global) and the module would never initialize.
    """
    result: dict[str, str] = {}
    for mod in get_modules():
        result[mod["id"]] = mod["var_name"] or mod["filename"].removesuffix(".lua")
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
        # Modules with typed positional args to initialize(). A spec whose default is None is
        # optional: omitted from the call unless the mission declares it, so adding one never
        # changes the output of a mission that does not use it.
        rendered: list[str] = []
        for init_key, default in _MODULE_INIT_PARAMS[mod_id]:
            if default is None and init_key not in init_cfg:
                continue
            value = init_cfg.get(init_key, default)
            if init_key in _NEGATED_INIT_KEYS:
                value = not value
            rendered.append(_to_lua_scalar(value))
        lines.append(f"    {var_name}.initialize({', '.join(rendered)})")

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
                if qra_def.get("radio_menu"):
                    lines.extend(
                        _emit_module_radio_menu(
                            qra_def.get("name", ""),
                            "qra",
                            ["start", "stop"],
                            qra_def.get("radio_menu_restrict_to_group"),
                        )
                    )

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

        # Activate zones flagged active_at_start, after initialize() so they are
        # already registered (FEAT-COMBATZONE-ACTIVATE).
        for zone_def in cz_zones:
            if zone_def.get("type", "zone") != "operation" and zone_def.get("active_at_start"):
                lines.append(f'    {var_name}.ActivateZone("{zone_def.get("zone_name", "")}", true)')

    elif mod_id == "AIRWAVES":
        airwave_zones: list = mod_cfg.get("airwave_zones") or []
        for zone in airwave_zones:
            lines.extend(_emit_airwave_zone(zone, indent="    "))
            if zone.get("radio_menu"):
                lines.extend(
                    _emit_module_radio_menu(
                        zone.get("name", ""),
                        "airwave",
                        ["start", "stop", "reset"],
                        zone.get("radio_menu_restrict_to_group"),
                    )
                )
        # No global initialize() — AirWaves is "use by construction"

    else:
        if mod_id not in _NO_INIT_MODULES:
            lines.append(f"    {var_name}.initialize()")

    # Mechanism 2 (FEAT-RADIO-YAML-MENUS): RADIO user menus, appended after the
    # module's own initialize() so veafRadio is ready.
    if mod_id == "RADIO":
        user_menus = mod_cfg.get("user_menus")
        if user_menus:
            lines.extend(_emit_user_menus(user_menus))


def _emit_combat_zone_def(zone_def: dict, var_name: str, indent: str = "    ") -> list[str]:
    """Emit a VeafCombatZone:new():...:initialize() builder chain."""
    lines: list[str] = []
    zone_name = zone_def.get("zone_name", "")
    lines.append(f"{indent}{var_name}.AddZone(")
    lines.append(f"{indent}    VeafCombatZone:new()")
    lines.append(f'{indent}    :setMissionEditorZoneName("{zone_name}")')
    if fn := zone_def.get("friendly_name"):
        lines.append(f'{indent}    :setFriendlyName("{fn}")')
    if rgn := zone_def.get("radio_group_name"):
        lines.append(f'{indent}    :setRadioGroupName("{rgn}")')
    if rmp := zone_def.get("radio_menu_prefix"):
        lines.append(f'{indent}    :setRadioMenuPrefix("{rmp}")')
    if br := zone_def.get("briefing"):
        br_lua = _lua_long_string(br.strip())
        lines.append(f"{indent}    :setBriefing({br_lua})")
    if zone_def.get("user_activation_disabled"):
        lines.append(f"{indent}    :disableUserActivation()")
    # `completable: false` stops the zone from auto-completing: the runtime never schedules
    # its watchdog. Needed for a zone holding no RED unit, since completion is decided on
    # the red count alone — such a zone would otherwise deactivate on the first check.
    if zone_def.get("completable", True) is False:
        lines.append(f"{indent}    :setCompletable(false)")
    # `enemy_coalition` picks the side whose units must die for the zone to complete, and
    # which tally the F10 report calls "enemies". RED is the runtime default, so it is not
    # emitted — existing generated configs stay byte-identical.
    enemy_coalition = zone_def.get("enemy_coalition")
    # `is not None` rather than truthiness: an empty or blank value is an authoring mistake
    # that must be reported, not silently skipped into the RED default.
    if enemy_coalition is not None:
        side = str(enemy_coalition).strip().upper()
        if side not in ("RED", "BLUE"):
            raise ValueError(f"combat zone {zone_name!r}: enemy_coalition must be RED or BLUE, got {enemy_coalition!r}")
        if side != "RED":
            lines.append(f"{indent}    :setEnemyCoalition(coalition.side.{side})")
    # `radio_menu_coalition` overrides who sees the zone's F10 menu; absent, the runtime shows it
    # to the side playing the zone (the opposite of `enemy_coalition`). ALL restores the global
    # menu, so it is passed as a string rather than a `coalition.side` constant.
    menu_coalition = zone_def.get("radio_menu_coalition")
    if menu_coalition is not None:
        menu_side = str(menu_coalition).strip().upper()
        if menu_side not in ("RED", "BLUE", "ALL"):
            raise ValueError(
                f"combat zone {zone_name!r}: radio_menu_coalition must be RED, BLUE or ALL, got {menu_coalition!r}"
            )
        if menu_side == "ALL":
            lines.append(f'{indent}    :setRadioMenuCoalition("all")')
        else:
            lines.append(f"{indent}    :setRadioMenuCoalition(coalition.side.{menu_side})")
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
    # The runtime AirWaveZone exposes only a single fixed inter-wave delay
    # (setDelayBetweenWaves); it has no random min/max range. Honour the
    # documented precedence (a configured min/max range overrides the fixed
    # delay) by collapsing the range to its minimum; the maximum has no runtime
    # equivalent and is dropped. A delay of 0 is a valid value (immediate next
    # wave), so test for presence rather than truthiness.
    delay = zone.get("min_seconds_between_waves")
    if delay is None:
        delay = zone.get("delay_between_waves")
    if delay is not None:
        lines.append(f"{indent}    :setDelayBetweenWaves({delay})")
    if max_alt := zone.get("max_altitude_ft"):
        lines.append(f"{indent}    :setMaximumAltitudeInFeet({max_alt})")
    if min_alt := zone.get("min_altitude_ft"):
        lines.append(f"{indent}    :setMinimumAltitudeInFeet({min_alt})")
    if mso := zone.get("max_seconds_outside_ia"):
        lines.append(f"{indent}    :setMaxSecondsOutsideOfZoneIA({mso})")
    # Map each YAML message key to a real AirWaveZone setter. The runtime has no
    # "all zones cleared" message, so message_end_all has no equivalent and is
    # intentionally not emitted.
    for msg_method, yaml_key in [
        ("setMessageStart", "message_start"),
        ("setMessageWaitForHumans", "message_wait_for_humans"),
        ("setMessageDeploy", "message_wave_deployed"),
        ("setMessageWon", "message_end_zone"),
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

    # `active_at_start: false` declares the QRA without arming it: the builder chain stops
    # before :start(). The QRA is still registered under its name by :setName(), so a
    # `qra.start` radio command (or a script) can arm it later.
    if qra_def.get("active_at_start", True):
        lines.append(f"{indent}    :start()")
    return lines


# ---------------------------------------------------------------------------
# YAML-declared radio menus (FEAT-RADIO-YAML-MENUS, ADR 0011)
# ---------------------------------------------------------------------------

#: Closed action vocabulary for YAML-declared radio-menu commands. Maps an action
#: name to the tuple of item keys it requires. ``lua`` references a maker function
#: (verified at build time elsewhere). Consumed by both the generator and the
#: schema validator so the two never drift.
RADIO_MENU_ACTIONS: dict[str, tuple[str, ...]] = {
    "qra.start": ("qra",),
    "qra.stop": ("qra",),
    "airwave.start": ("airwave",),
    "airwave.stop": ("airwave",),
    "airwave.reset": ("airwave",),
    "flag.on": ("flag",),
    "flag.off": ("flag",),
    "flag.set": ("flag", "value"),
    "flag.increment": ("flag",),
    "flag.decrement": ("flag",),
    "message": ("text",),
    "lua": ("function",),
}


def _lua_closure(body: str) -> str:
    """Wrap a Lua statement in a no-argument closure: ``function() <body> end``."""
    return f"function() {body} end"


def _emit_action_call(item: dict) -> str:
    """Return the Lua for a command's function argument (plus optional params).

    This is everything after the label inside ``veafRadio.command("label", …)``:
    a self-contained closure for the vocabulary actions, or a maker function
    reference followed by its parameters for the ``lua`` action.

    Args:
        item: A command node, e.g. ``{"command": "…", "action": "flag.on", "flag": "a"}``.

    Returns:
        A Lua expression string.

    Raises:
        ValueError: If the action is unknown or a required target key is missing.
    """
    action = item.get("action")
    if action not in RADIO_MENU_ACTIONS:
        raise ValueError(f"unknown radio-menu action: {action!r}")
    for key in RADIO_MENU_ACTIONS[action]:
        if item.get(key) is None:
            raise ValueError(f"radio-menu action {action!r} requires '{key}'")

    if action == "lua":
        fn = str(item["function"])
        args = item.get("args")
        if not args:
            return fn
        if not isinstance(args, list):
            raise ValueError(f"radio-menu action 'lua' args must be a list, got {type(args).__name__}")
        args_lua = ", ".join(_to_lua_scalar(a) for a in args)
        ref = f"{fn}, {{{args_lua}}}"
        return ref

    if action in ("qra.start", "qra.stop"):
        method = action.split(".", 1)[1]
        name = _to_lua_scalar(item["qra"])
        return _lua_closure(f"local o = veafQraManager.get({name}); if o then o:{method}() end")

    if action in ("airwave.start", "airwave.stop", "airwave.reset"):
        method = action.split(".", 1)[1]
        name = _to_lua_scalar(item["airwave"])
        return _lua_closure(f"local o = veafAirWaves.get({name}); if o then o:{method}() end")

    if action in ("flag.on", "flag.off", "flag.set"):
        value = {"flag.on": 1, "flag.off": 0}[action] if action != "flag.set" else item["value"]
        flag = _to_lua_scalar(item["flag"])
        return _lua_closure(f"veafSpawn.missionMasterSetFlag({flag}, {_to_lua_scalar(value)})")

    if action in ("flag.increment", "flag.decrement"):
        inc = 1 if action == "flag.increment" else -1
        flag = _to_lua_scalar(item["flag"])
        return _lua_closure(f"veafSpawn.missionMasterAddValueToFlag({flag}, {inc})")

    # message
    text = _emit_lua_string(str(item["text"]))
    return _lua_closure(f"trigger.action.outText({text}, 15)")


def _emit_menu_node(node: dict, indent: str) -> list[str]:
    """Recursively emit one ``menu`` or ``command`` node as Lua lines (no trailing comma)."""
    if "menu" in node:
        name = _emit_lua_string(str(node["menu"]))
        items = node.get("items") or []
        if not items:
            return [f"{indent}veafRadio.menu({name})"]
        lines = [f"{indent}veafRadio.menu({name},"]
        for i, child in enumerate(items):
            child_lines = _emit_menu_node(child, indent + "    ")
            if i < len(items) - 1:
                child_lines[-1] += ","
            lines.extend(child_lines)
        lines.append(f"{indent})")
        return lines
    call = _emit_action_call(node)
    label = _emit_lua_string(str(node.get("command", "")))
    return [f"{indent}veafRadio.command({label}, {call})"]


def _emit_user_menus(user_menus: dict, indent: str = "    ") -> list[str]:
    """Emit a ``veafRadio.createUserMenu(...)`` call from a ``user_menus`` block.

    Args:
        user_menus: A ``{tree: [...], restrict_to_group?: "<name>"}`` mapping.
        indent: Leading indentation for the top-level call.

    Returns:
        The generated Lua lines. When ``restrict_to_group`` is set, its DCS group
        name is passed as the second argument (resolved to a group id at runtime).
    """
    tree = user_menus.get("tree") or []
    group = user_menus.get("restrict_to_group")
    lines = [f"{indent}veafRadio.createUserMenu(", f"{indent}    veafRadio.mainmenu("]
    for i, node in enumerate(tree):
        node_lines = _emit_menu_node(node, indent + "        ")
        if i < len(tree) - 1:
            node_lines[-1] += ","
        lines.extend(node_lines)
    if group:
        lines.append(f"{indent}    ),")
        lines.append(f'{indent}    "{group}"')
    else:
        lines.append(f"{indent}    )")
    lines.append(f"{indent})")
    return lines


def _emit_module_radio_menu(name: str, target_key: str, verbs: list[str], group: str | None) -> list[str]:
    """Emit the per-module ``radio_menu`` shortcut (mechanism 1) for QRA / AirWaves.

    Builds a single submenu named after the object, holding one command per verb
    (``start``/``stop``/``reset``), then delegates to :func:`_emit_user_menus`.

    Args:
        name: The object name (QRA / AirWave), used as submenu title and action target.
        target_key: The action target key — ``"qra"`` or ``"airwave"``.
        verbs: The verbs to expose, e.g. ``["start", "stop"]``.
        group: Optional DCS group name the menu is restricted to.

    Returns:
        The generated Lua lines.
    """
    items = [
        {
            "command": t(f"generated.radio_menu.{verb}", name=name),
            "action": f"{target_key}.{verb}",
            target_key: name,
        }
        for verb in verbs
    ]
    user_menus: dict = {"tree": [{"menu": name, "items": items}]}
    if group:
        user_menus["restrict_to_group"] = group
    return _emit_user_menus(user_menus, indent="    ")


def collect_radio_lua_functions(mission_yaml: dict) -> list[str]:
    """Return the maker function names referenced by ``action: lua`` radio-menu items.

    Reads ``modules.RADIO.user_menus`` (accepting the ``modules`` or the legacy
    ``lua_modules`` key) and walks the menu tree.

    Args:
        mission_yaml: The parsed ``mission.yaml`` mapping.

    Returns:
        The referenced function symbols, in tree order (may contain duplicates).
    """
    modules = mission_yaml.get("lua_modules") or mission_yaml.get("modules") or {}
    radio = modules.get("RADIO") if isinstance(modules, dict) else None
    user_menus = radio.get("user_menus") if isinstance(radio, dict) else None
    if not isinstance(user_menus, dict):
        return []
    found: list[str] = []

    def _walk(nodes: object) -> None:
        if not isinstance(nodes, list):
            return
        for node in nodes:
            if not isinstance(node, dict):
                continue
            if "menu" in node:
                _walk(node.get("items"))
            elif node.get("action") == "lua" and node.get("function"):
                found.append(str(node["function"]))

    _walk(user_menus.get("tree"))
    return found


def _lua_defines_function(corpus: str, symbol: str) -> bool:
    """True if the Lua *corpus* defines *symbol* as a function.

    Recognises ``function <symbol>(`` / ``function <symbol>:`` and
    ``<symbol> = function`` for both plain and dotted (``table.fn``) names.
    """
    esc = re.escape(symbol)
    return re.search(rf"(function\s+{esc}\s*[(:])|({esc}\s*=\s*function)", corpus) is not None


def find_undefined_lua_functions(mission_yaml: dict, corpus: str) -> list[str]:
    """Return referenced ``action: lua`` functions **not** defined in the Lua *corpus*.

    Used at build time (abort) and by the ``validate`` command (error). The order of
    first appearance is preserved and duplicates are collapsed.

    Args:
        mission_yaml: The parsed ``mission.yaml`` mapping.
        corpus: The concatenated Lua source of the mission's scripts.

    Returns:
        The undefined function symbols, de-duplicated.
    """
    missing: list[str] = []
    for fn in collect_radio_lua_functions(mission_yaml):
        if fn not in missing and not _lua_defines_function(corpus, fn):
            missing.append(fn)
    return missing


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
    ``enabled: true`` and a ``logger.warning`` is emitted.  The loop repeats
    until no more changes are needed (handles transitive dependency chains).
    """
    changed = True
    while changed:
        changed = False
        for mod_id, deps in _MODULE_DEPS.items():
            cfg = effective.get(mod_id, {})
            if isinstance(cfg, dict) and not _get_module_enabled(cfg, True):
                continue  # explicitly disabled — skip dep check
            if mod_id not in effective:
                continue  # not requested — skip
            for dep in deps:
                dep_cfg = effective.get(dep, {})
                if isinstance(dep_cfg, dict) and not _get_module_enabled(dep_cfg, True):
                    logger.warning(t("generator.dep_auto_resolution_disabled", mod_id=mod_id, dep=dep))
                    dep_cfg["enabled"] = True
                    dep_cfg.pop("enable", None)
                    effective[dep] = dep_cfg
                    changed = True
                elif dep not in effective:
                    logger.warning(t("generator.dep_auto_resolution_missing", mod_id=mod_id, dep=dep))
                    effective[dep] = {"enabled": True}
                    changed = True
    return effective


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def _community_enabled(mission_yaml: dict, script_id: str) -> bool:
    """Return whether a community script is enabled, matching the build's enable rule.

    When the ``community_scripts`` section is absent or the id is not listed: an
    opt-out script is enabled, an opt-in script (e.g. TUM) is not. When listed, a
    dict uses its ``enabled`` flag (default true); ``None`` means disabled;
    otherwise the value's truthiness. Mirrors ``MissionBuilderWorker`` community
    parsing so the generated init matches what is actually injected.
    """
    from mission_tools.mission_constants import is_community_script_enabled_by_default

    comm = mission_yaml.get("community_scripts")
    if not isinstance(comm, dict) or not comm or script_id not in comm:
        return is_community_script_enabled_by_default(script_id)
    cfg = comm[script_id]
    if isinstance(cfg, dict):
        return bool(cfg.get("enabled", True))
    if cfg is None:
        return False
    return bool(cfg)


def _emit_check_table(check: dict[str, object]) -> str:
    """Render a step's resolved check descriptor as an inline Lua table.

    ``type`` leads, so a generated checklist reads the way the engine dispatches it.
    """
    ordered = ["type", *(key for key in check if key != "type")]
    fields = [f"{key} = {_emit_lua_value(check[key])}" for key in ordered if key in check]
    return "{" + ", ".join(fields) + "}"


def _emit_lua_value(value: object) -> str:
    """Render a scalar for embedding in a generated table, strings safely quoted."""
    return _emit_lua_string(value) if isinstance(value, str) else _to_lua_scalar(value)


def _emit_checklist_step(step: ChecklistStep) -> str:
    """Render one checklist step as an inline Lua table."""
    fields = [f"label = {_emit_lua_string(step.label)}"]
    if step.element is not None:
        fields.append(f"element = {_emit_lua_string(step.element)}")
    for carried in ("device", "command"):
        value = getattr(step, carried)
        if value is not None:
            fields.append(f"{carried} = {_to_lua_scalar(value)}")
    fields.append(f"check = {_emit_check_table(step.check_table())}")
    return "{" + ", ".join(fields) + "}"


def emit_checklists_lua(
    checklists: Sequence[Checklist],
    image_keys: Mapping[str, Sequence[str]] | None = None,
    indent: str = "    ",
) -> list[str]:
    """Render one ``veafAssist.registerChecklist()`` call per checklist.

    Args:
        checklists: The checklists the mission activates, already validated.
        image_keys: Per checklist id, the resource key of each progress state. Emitted
            so the engine indexes a list instead of rebuilding a name by concatenation;
            a checklist with no entry simply displays no picture.
        indent: Leading whitespace, so the block sits inside its ``if`` guard.

    Returns:
        The Lua lines (empty when there is nothing to register).
    """
    lines: list[str] = []
    for checklist in checklists:
        lines.append(f"{indent}veafAssist.registerChecklist({{")
        lines.append(f"{indent}    id = {_emit_lua_string(checklist.id)},")
        lines.append(f"{indent}    title = {_emit_lua_string(checklist.title)},")
        aircraft = ", ".join(_emit_lua_string(name) for name in checklist.aircraft)
        lines.append(f"{indent}    aircraft = {{{aircraft}}},")
        lines.append(f"{indent}    menu = {_emit_lua_string(checklist.menu)},")
        keys = (image_keys or {}).get(checklist.id)
        if keys:
            rendered = ", ".join(_emit_lua_string(key) for key in keys)
            lines.append(f"{indent}    images = {{{rendered}}},")
        lines.append(f"{indent}    steps = {{")
        for step in checklist.steps:
            lines.append(f"{indent}        {_emit_checklist_step(step)},")
        lines.append(f"{indent}    }},")
        lines.append(f"{indent}}})")
    return lines


def generate_config_lua(
    mission_yaml: dict,
    header: str | None = None,
    checklists: Sequence[Checklist] | None = None,
    checklist_images: Mapping[str, Sequence[str]] | None = None,
) -> str:
    """Render ``veaf-config.lua`` from the full *mission_yaml* content dict.

    Parameters
    ----------
    mission_yaml:
        Parsed content of ``mission.yaml`` (from ``yaml.safe_load``).
    header:
        Comment text prepended after the separator line. Defaults to the
        localised generated-file header from the i18n catalog.
    checklists:
        Guided checklists the mission activates. Emitted **before** the module
        initialisation block, so ``veafAssist.initialize()`` sees a populated
        catalogue when it builds its radio menu. Nothing is emitted when empty,
        which is what keeps a mission that activates none of them free of cost.
    checklist_images:
        Per checklist id, the resource key of each rendered progress state.

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
        if mission_cfg.get("silence_atc_on_all_airbases"):
            lines.append("veaf.silenceAtcOnAllAirbases()")
        lines.append("")

    # ── In-game message language ───────────────────────────────────────────
    # veaf.t() reads veaf.config.language. mission.yaml's mission.language is the
    # explicit per-mission choice; otherwise fall back to the tools' resolved
    # language (--lang / VEAF_LANG / user config / OS locale / "en"), so a mission
    # built by a French maker defaults to FR in-game and others to their locale.
    language = mission_cfg.get("language") or current_language()
    lines.append(f'veaf.config.language = "{language}"')
    lines.append("")

    # ── Security ──────────────────────────────────────────────────────────
    security_cfg: dict = mission_yaml.get("security") or {}
    if security_cfg:
        lines.append("-- ── Security ─────────────────────────────────────────────────────────────────")
        if "disabled" in security_cfg:
            lines.append(f"veaf.SecurityDisabled = {'true' if security_cfg['disabled'] else 'false'}")
        # Both levels, deliberately. Levels rank L0 (90) > L1 (10) > L9 (1), and the gates that
        # matter — marker authentication (checkPassword_L1), the sensitive spawns
        # (veafSpawnCore:142), transport missions — accept L1 or L0 only. Emitting L9 alone gave
        # a password that could not authenticate a marker whatever it was set to; the
        # hand-written v5 missions set both for this exact reason.
        for hash_val in security_cfg.get("password_hashes") or []:
            lines.append(f'veafSecurity.password_L1["{hash_val}"] = true')
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

    # ── Guided checklists ─────────────────────────────────────────────────
    # Registered before the module block: veafAssist.initialize() reads the catalogue
    # to build its radio menu, so the data has to be there first.
    if checklists:
        lines.append("-- ── Guided checklists (assistance) ───────────────────────────────────────────")
        lines.append("if veafAssist then")
        lines.extend(emit_checklists_lua(checklists, checklist_images))
        lines.append("end")
        lines.append("")

    # ── Module configuration + initialization ─────────────────────────────
    # Accept both `modules:` (new) and `lua_modules:` (legacy) keys.
    raw_lua_modules: dict = mission_yaml.get("lua_modules") or {}
    lua_modules: dict = {k: _normalize_module_cfg(v) for k, v in raw_lua_modules.items()}
    qra_section: dict = mission_yaml.get("qra") or {}
    cap_missions: list = mission_yaml.get("cap_missions") or []
    combat_missions_data: list = mission_yaml.get("combat_missions") or []
    external_modules: dict = mission_yaml.get("external_modules") or {}
    skynet_cfg: dict = external_modules.get("skynet") or {}

    if lua_modules:
        # ── MODUX-002: error on mandatory modules with any enable/enabled key ──
        effective_modules: dict = dict(lua_modules)
        for mandatory_id in MANDATORY_MODULES:
            mcfg = effective_modules.get(mandatory_id, {})
            if isinstance(mcfg, dict) and ("enable" in mcfg or "enabled" in mcfg):
                bad_val = mcfg.get("enabled", mcfg.get("enable"))
                logger.error(t("builder.mandatory_module_enable", module=mandatory_id, value=bad_val))

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

            enabled = _get_module_enabled(mod_cfg, True)
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

    # ── Community-script enable flags (FIX-VEAF-MODULE-GATING) ────────────
    # Tell the framework which community libs the mission disabled, so its runtime
    # integration gates (`if ctld and veaf.isEnabled("ctld")`) leave that lib's
    # global alone — e.g. when the mission ships its own version via custom_scripts.
    # MiST is mandatory and never disabled.
    from mission_tools.mission_constants import get_community_script_files

    disabled_community = [
        s["id"]
        for s in get_community_script_files()
        if s["id"] not in _MANDATORY_COMMUNITY_SCRIPTS and not _community_enabled(mission_yaml, s["id"])
    ]
    if disabled_community:
        lines.append("-- ── Community scripts disabled (VEAF leaves their globals alone) ──────────────")
        for sid in disabled_community:
            lines.append(f'veaf.setConfig("{sid}", "enable", false)')
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

    # No CTLD block: CTLD 2 is configured by the mission's ctld-config.yaml, injected as
    # CTLD_userConfig.lua right before CTLD.lua by the builder, and started by veaf.lua.
    # See docs/adr/0016-ctld2-sidecar-configuration.md.

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

    # TheUniversalMission (TUM) — community script with no config, only an init call.
    if _community_enabled(mission_yaml, "tum"):
        lines.append("-- ── TheUniversalMission (TUM) ────────────────────────────────────────────────")
        lines.append("-- Note: TheUniversalMission.lua must be loaded by mission-script.lua before this block.")
        lines.append("if TUM then")
        lines.append("    TUM.initialize()")
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
    from mission_tools.mission_constants import get_community_script_files

    if modules is None:
        modules = get_modules()
    enabled_set: set[str] = enabled_module_ids or set()

    lines: list[str] = []

    # ── File header ───────────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.header"))
    lines.append("")

    # ── YAML syntax quick reference (UX-005) ─────────────────────────────
    lines.extend(yaml_syntax_header())
    lines.append("")

    # ── Global log level ──────────────────────────────────────────────────
    lines.extend(global_log_level_section())
    lines.append("")

    # ── Mission identity ──────────────────────────────────────────────────
    lines.extend(mission_identity_section())
    lines.append("")

    # ── Security ──────────────────────────────────────────────────────────
    lines.extend(security_section())
    lines.append("")

    # ── Generic settings ──────────────────────────────────────────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.settings"))
    lines.append("# settings:")
    lines.append("#   MY_SETTING: my-value")
    lines.append("")

    # ── Module configuration (UX-003: unified modules: block) ────────────
    lines.extend(_yaml_comment("generated.mission_yaml.section.modules"))
    lines.append("#")
    lines.append("modules:")

    # Emit VEAF module entries in recommended order
    ordered_ids = _MODULE_INIT_ORDER
    all_module_map = {m["id"]: m for m in modules}
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
            lines.extend(yaml_module_entry(yaml_key, mid))
            # Show init params example for known modules
            if mid in _MODULE_INIT_PARAMS:
                lines.append("    # init:")
                for yaml_k, default in _MODULE_INIT_PARAMS[mid]:
                    lines.append(f"    #   {yaml_k}: {_to_lua_scalar(default)}")
            # Show data subsections for special modules
            if mid == "RADIO":
                lines += [
                    "    # user_menus:            # Mission-Master F10 menus in YAML (FEAT-RADIO-YAML-MENUS)",
                    '    #   restrict_to_group: "MM Ctrl"   # optional: DCS group name; absent = global menu',
                    "    #   tree:",
                    '    #     - menu: "Flags"',
                    "    #       items:",
                    '    #         - { command: "Enable ALPHA", action: flag.on, flag: "alpha" }',
                    '    #         - { command: "Start QRA North", action: qra.start, qra: "QRA-North" }',
                ]
            if mid == "ASSETS":
                lines.append("    # assets:  # list of asset entries")
                lines.append("    #   - sort: 1")
                lines.append("    #     name: T1-Arco")
                lines.append('#     #     description: "Arco (KC-135)"')
                lines.append('#     #     information: "Tacan 64Y\\nU290.50"')
            elif mid == "NAMEDPOINTS":
                lines.append("    # custom_points:  # list of custom POIs")
                lines.append("    #   - name: Battle Area Alpha")
                lines.append('    #     lat: "41.123456"')
                lines.append('    #     lon: "44.987654"')
            elif mid == "QRA":
                lines += [
                    "    # silence_all: false",
                    "    # definitions:",
                    "    #   - name: Base QRA",
                    "    #     coalition: RED           # RED | BLUE | NEUTRAL",
                    "    #     enemy_coalitions:",
                    "    #       - BLUE",
                    "    #     trigger_zone: QRA zone",
                    "    #     zone_radius: 30000",
                    "    #     groups_by_enemy_count:",
                    "    #       - enemy_count: 1",
                    "    #         groups:",
                    "    #           - Group1",
                    "    #         random_pick: 1",
                    "    #     delay_before_rearming: 30",
                    "    #     delay_before_activating: 30",
                    "    #     active_at_start: true    # false = declared but not armed (wait for qra.start)",
                ]
        else:
            lines.append(f"  # {yaml_key}:")
            lines.append("  #   enabled: false")

    # Emit community script entries in the same modules: block (UX-003).
    # SKYNET / CTLD / CSAR carry their config nested here too — there is no
    # separate external_modules: section any more (MODULES-UNIFY).
    for doc_line in _yaml_comment("generated.mission_yaml.section.external"):
        lines.append(f"  {doc_line}" if doc_line.startswith("#") else doc_line)
    lines.append("  # ── Community scripts ──")
    for script in get_community_script_files():
        sid = script["id"]
        upper = sid.upper()
        if upper == "SKYNET":
            lines += [
                f"  # {sid}:",
                "  #   enabled: false",
                "  #   include_red_in_radio: false",
                "  #   debug_red: false",
                "  #   include_blue_in_radio: false",
                "  #   debug_blue: false",
            ]
        elif upper == "CTLD":
            # CTLD 2 takes no settings here: its configuration is the mission's
            # ctld-config.yaml (ADR 0016). Advertising a settings: block would invite
            # writing values the build silently drops.
            lines += [
                f"  # {sid}: false            # configured in ctld-config.yaml (edit it with ctld-tools)",
            ]
        elif upper == "CSAR":
            lines += [
                f"  # {sid}:",
                "  #   enabled: false",
                f"  #   settings:                # {sid.lower()}.xxx = value pairs",
                "  #     enableAllslots: true",
            ]
        else:
            lines.append(f"  # {sid}: true")

    # ── CAP missions ──────────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.cap"))
    lines += [
        "# cap_missions:",
        "#   - group_name: CAP Group",
        "#     menu_name: CAP",
        "#     briefing: CAP mission briefing",
        "#     default: false",
        "#     activated: true",
    ]

    # ── Combat missions ───────────────────────────────────────────────────
    lines.append("")
    lines.extend(_yaml_comment("generated.mission_yaml.section.combat"))
    lines += [
        "# combat_missions:",
        "#   - name: Mission Name",
        "#     friendly_name: Display Name",
        "#     secured: false",
        "#     radio_menu_enabled: true",
        "#     briefing: |",
        "#       Multi-line briefing text here.",
        "#     elements:",
        "#       - name: Element Name",
        "#         groups:",
        "#           - Group1",
        "#           - Group2",
        "#         scalable: true",
    ]

    # ── Build pipeline ─────────────────────────────────────────────────────
    lines.append("")
    lines.extend(pipeline_section())

    return "\n".join(lines) + "\n"
