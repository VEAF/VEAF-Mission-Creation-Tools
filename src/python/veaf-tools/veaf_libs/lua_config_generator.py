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
_SKIP_SETCONFIG_KEYS: frozenset[str] = frozenset({"enable", "logLevel", "init", "assets", "custom_points"})


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
    """Wrap *text* in Lua long-string brackets ``[[...]]`` or ``[==[...]==]``."""
    if "]]" not in text:
        return f"[[{text}]]"
    return f"[==[{text}]==]"


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
                parts.append(f'name = "{asset.get("name", "")}"')
                parts.append(f'description = "{asset.get("description", "")}"')
                info = str(asset.get("information", ""))
                parts.append(f'information = "{info}"')
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

    else:
        lines.append(f"    {var_name}.initialize()")


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
        lines.append("-- ── Module configuration + initialization ────────────────────────────────────")
        lines.append("")

        # Determine full ordered list: known order + unknown modules + INTERPRETER
        known_order_set = set(_MODULE_INIT_ORDER)
        all_module_ids = {m["id"] for m in get_modules()}
        extra_ids = [mid for mid in lua_modules if mid not in known_order_set and mid in all_module_ids]
        ordered_ids = [mid for mid in _MODULE_INIT_ORDER if mid != "INTERPRETER"] + extra_ids + ["INTERPRETER"]

        for mod_id in ordered_ids:
            mod_cfg: dict | None = lua_modules.get(mod_id)
            if mod_cfg is None:
                continue

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
        ctld_props = {k: v for k, v in ctld_cfg.items() if k != "enabled"}
        for key, value in ctld_props.items():
            lines.append(f"ctld.{key} = {_to_lua_scalar(value)}")
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

    # Emit enabled modules first (uncommented), then disabled (commented)
    enabled_found = [mid for mid in ordered_ids if mid in enabled_set and mid in all_module_map]
    disabled_found = [mid for mid in ordered_ids if mid not in enabled_set and mid in all_module_map]
    remaining = [mid for mid in all_module_map if mid not in set(ordered_ids)]

    if enabled_found:
        lines.append(f"  # {t('generated.mission_yaml.modules.active')}")
        for mid in enabled_found:
            yaml_key = f'"{mid}"' if not re.match(r"^[A-Za-z_]\w*$", mid) else mid
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

    if disabled_found or remaining:
        lines.append(f"  # {t('generated.mission_yaml.modules.other')}")
        for mid in disabled_found + remaining:
            yaml_key = f'"{mid}"' if not re.match(r"^[A-Za-z_]\w*$", mid) else mid
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
        "#   weather: true             # src/missions.yaml",
    ]

    return "\n".join(lines) + "\n"
