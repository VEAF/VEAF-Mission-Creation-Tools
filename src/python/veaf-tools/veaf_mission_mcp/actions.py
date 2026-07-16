"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path
from typing import Any

from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.composites import create_combat_zone
from veaf_mission_mcp.describe_mission import describe_mission
from veaf_mission_mcp.edit_mission_yaml import (
    describe_mission_config,
    set_mission_log_level,
    set_mission_module,
    set_mission_security,
    set_mission_setting,
)
from veaf_mission_mcp.edit_veaf_config import (
    set_log_level,
    set_module_enabled,
    set_security_disabled,
    set_veaf_config,
)
from veaf_mission_mcp.group_naming import validate_group_name
from veaf_mission_mcp.models import ActionSpec
from veaf_mission_mcp.oracle import (
    describe_module,
    describe_naming_conventions,
    list_shortcuts,
    list_unit_types,
)
from veaf_mission_mcp.replace_in_files import replace_in_mission_files


def register_default_actions(catalog: ActionCatalog) -> None:
    """Register every action shipped by this server into `catalog`.

    Args:
        catalog: The catalog to populate.
    """
    catalog.register(
        ActionSpec(
            name="describe_mission",
            description=(
                "List the groups and trigger zones currently present in a mission's source "
                ".miz, for situational awareness before an editor-parity write."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                },
                "required": ["miz_path"],
            },
        ),
        handler=lambda params: describe_mission(Path(params["miz_path"])),
    )
    catalog.register(
        ActionSpec(
            name="add_group",
            description=(
                "Insert a ground/vehicle group into a mission's source .miz, in place, backed up "
                "first. Mirrors adding a group by hand in the DCS Mission Editor -- not "
                "deduplicated, calling this twice creates two groups."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer", "description": "DCS numeric country id."},
                    "country_name": {"type": "string", "description": "DCS country name (e.g. 'Russia')."},
                    "category": {
                        "type": "string",
                        "enum": ["vehicle", "plane", "helicopter", "ship", "static"],
                    },
                    "name": {"type": "string", "description": "The group's name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The group's anchor position.",
                    },
                    "units": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "description": "DCS unit type, e.g. 'BTR-80'."},
                                "count": {"type": "integer", "default": 1},
                            },
                            "required": ["type"],
                        },
                        "description": "Unit types are the calling LLM's decision, not this action's.",
                    },
                    "route": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                        "description": "Optional waypoints; defaults to a single stationary point at `position`.",
                    },
                    "patrol": {
                        "type": "boolean",
                        "default": False,
                        "description": "Loop the route's last waypoint back to the first.",
                    },
                    "for_combat_zone": {
                        "type": "string",
                        "description": "Combat-zone trigger-zone name to prefix the group name with "
                        "(so the zone picks it up). Idempotent.",
                    },
                    "late_activation": {
                        "type": "boolean",
                        "default": False,
                        "description": "Mark the group late-activation (QRA interceptors, CAP templates).",
                    },
                    "as_spawn_template": {
                        "type": "boolean",
                        "default": False,
                        "description": "Prefix the name with 'veafSpawn-' (spawnable-aircraft template).",
                    },
                },
                "required": [
                    "miz_path",
                    "coalition",
                    "country_id",
                    "country_name",
                    "category",
                    "name",
                    "position",
                    "units",
                ],
            },
        ),
        handler=_handle_add_group,
    )
    catalog.register(
        ActionSpec(
            name="add_trigger_zone",
            description=(
                "Insert a named circular trigger zone into a mission's source .miz, in place, "
                "backed up first. This is the zone a VEAF combat zone references; combine with "
                "add_group to lay down a full combat zone. Not deduplicated."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "name": {"type": "string", "description": "The zone's name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The zone centre.",
                    },
                    "radius": {"type": "number", "description": "The zone radius, in metres."},
                    "hidden": {"type": "boolean", "default": False},
                    "color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "RGBA fill [r, g, b, a] (0..1). Defaults to translucent white.",
                    },
                },
                "required": ["miz_path", "name", "position", "radius"],
            },
        ),
        handler=_handle_add_trigger_zone,
    )
    catalog.register(
        ActionSpec(
            name="add_startup_script_trigger",
            description=(
                "Add a mission-start trigger that runs a script — for outfitting a vanilla or "
                "CTLD mission with scripting without the DCS editor. Modes: 'inline' (run Lua), "
                "'file_static' (embed a .lua into the .miz and load it), 'file_dynamic' (load a "
                ".lua from a runtime disk path). Backed up first; not deduplicated."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "mode": {"type": "string", "enum": ["inline", "file_static", "file_dynamic"]},
                    "comment": {"type": "string", "description": "The trigger's editor label."},
                    "inline_lua": {"type": "string", "description": "Lua to run (mode='inline')."},
                    "source_path": {
                        "type": "string",
                        "description": "Path to the .lua file to embed (mode='file_static').",
                    },
                    "runtime_path": {
                        "type": "string",
                        "description": "Disk path DCS loadfile's at runtime (mode='file_dynamic').",
                    },
                    "resource_name": {
                        "type": "string",
                        "description": "Basename to embed the static file under (defaults to the source name).",
                    },
                },
                "required": ["miz_path", "mode", "comment"],
            },
        ),
        handler=_handle_add_startup_script_trigger,
    )
    catalog.register(
        ActionSpec(
            name="replace_in_mission_files",
            description=(
                "Generic text/regex search-replace across a mission's embedded Lua files "
                "(restricted to l10n/DEFAULT/**/*.lua — never the raw mission/options tables or "
                "binaries). Edits the built .miz in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "search": {"type": "string", "description": "Text (or regex if `regex`) to find."},
                    "replace": {"type": "string", "description": "Replacement (regex backrefs allowed if `regex`)."},
                    "files": {
                        "type": "string",
                        "default": "*.lua",
                        "description": "Glob against each .lua's path relative to l10n/DEFAULT/ (e.g. 'veaf-*.lua').",
                    },
                    "regex": {"type": "boolean", "default": False},
                },
                "required": ["miz_path", "search", "replace"],
            },
        ),
        handler=_handle_replace_in_mission_files,
    )
    catalog.register(
        ActionSpec(
            name="set_log_level",
            description="Set the global VEAF log level (veaf.ForcedLogLevel) in a built mission, without a rebuild.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "level": {"type": "string", "enum": ["error", "warning", "info", "debug", "trace"]},
                },
                "required": ["miz_path", "level"],
            },
        ),
        handler=lambda p: set_log_level(Path(p["miz_path"]), p["level"]),
    )
    catalog.register(
        ActionSpec(
            name="set_module_enabled",
            description="Enable/disable a VEAF module (veaf.setConfig(<MOD>, 'enable', <bool>)) in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "module_id": {"type": "string", "description": "Module id, e.g. 'QRA', 'COMBATZONE'."},
                    "enabled": {"type": "boolean"},
                },
                "required": ["miz_path", "module_id", "enabled"],
            },
        ),
        handler=lambda p: set_module_enabled(Path(p["miz_path"]), p["module_id"], p["enabled"]),
    )
    catalog.register(
        ActionSpec(
            name="set_security_disabled",
            description="Set the VEAF security flag (veaf.SecurityDisabled) in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "disabled": {"type": "boolean", "description": "true = no password required."},
                },
                "required": ["miz_path", "disabled"],
            },
        ),
        handler=lambda p: set_security_disabled(Path(p["miz_path"]), p["disabled"]),
    )
    catalog.register(
        ActionSpec(
            name="set_veaf_config",
            description="Set an arbitrary veaf.config.<key> scalar value in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "key": {"type": "string", "description": "The config key (bare Lua identifier)."},
                    "value": {"description": "A scalar (bool/int/float/string)."},
                },
                "required": ["miz_path", "key", "value"],
            },
        ),
        handler=lambda p: set_veaf_config(Path(p["miz_path"]), p["key"], p["value"]),
    )
    catalog.register(
        ActionSpec(
            name="describe_mission_config",
            description=(
                "List the modules block of a mission's source mission.yaml (the declarative "
                "VMCT config the build consumes), and each module's state (mandatory / "
                "enabled scalar / extended config mapping). Read-only; the VMCT counterpart "
                "of describe_mission."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                },
                "required": ["mission_yaml_path"],
            },
        ),
        handler=lambda p: describe_mission_config(Path(p["mission_yaml_path"])),
    )
    catalog.register(
        ActionSpec(
            name="validate_group_name",
            description=(
                "Check a proposed group name against the reserved VEAF naming conventions "
                "(veafSpawn-/OnDemand-/VEAF-placeholder- prefixes, #veafInterpreter/#command "
                "markers, QRA deploy syntax, fixed CAS names). With a miz_path, also flags the "
                "combat-zone capture trap. Read-only; call before add_group."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "The proposed group name."},
                    "miz_path": {
                        "type": "string",
                        "description": "Optional .miz to check the combat-zone capture trap against.",
                    },
                    "expected_combat_zone": {
                        "type": "string",
                        "description": "A combat zone the group is intentionally attached to (suppresses its capture warning).",
                    },
                },
                "required": ["name"],
            },
        ),
        handler=lambda p: validate_group_name(
            p["name"],
            miz_path=Path(p["miz_path"]) if p.get("miz_path") else None,
            expected_combat_zone=p.get("expected_combat_zone"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_module",
            description=(
                "Enable/disable a VEAF module or set its extended config block in a mission's "
                "source mission.yaml, comments preserved, backed up first. Pass `value` as a "
                "boolean for the scalar form (MODULE: true/false) or as an object for the "
                "extended block (e.g. a COMBATZONE/CTLD config). Inserts the key if absent."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "module_id": {"type": "string", "description": "Module key, e.g. 'CTLD', 'COMBATZONE'."},
                    "value": {
                        "type": ["boolean", "object"],
                        "description": "Boolean toggle, or an object for the extended config block.",
                    },
                },
                "required": ["mission_yaml_path", "module_id", "value"],
            },
        ),
        handler=lambda p: set_mission_module(Path(p["mission_yaml_path"]), p["module_id"], p["value"]),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_log_level",
            description=(
                "Set the global VEAF log level in the source mission.yaml (global_log_level). "
                "Source/recipe counterpart of set_log_level (which edits the built veaf-config.lua)."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "level": {"type": "string", "enum": ["error", "warning", "info", "debug", "trace"]},
                },
                "required": ["mission_yaml_path", "level"],
            },
        ),
        handler=lambda p: set_mission_log_level(Path(p["mission_yaml_path"]), p["level"]),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_security",
            description=(
                "Set the security: block in the source mission.yaml (disabled flag + optional "
                "JTF/Mission-Master password hashes). Source counterpart of set_security_disabled, "
                "and covers the hashes the built-side action does not."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "disabled": {"type": "boolean", "description": "true = no password required."},
                    "password_hashes": {"type": "array", "items": {"type": "string"}},
                    "password_mm_hashes": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["mission_yaml_path", "disabled"],
            },
        ),
        handler=lambda p: set_mission_security(
            Path(p["mission_yaml_path"]),
            p["disabled"],
            password_hashes=p.get("password_hashes"),
            password_mm_hashes=p.get("password_mm_hashes"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_setting",
            description=(
                "Set an arbitrary settings.<key> in the source mission.yaml (rendered to "
                "veaf.config.<key> at build). Source counterpart of set_veaf_config."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "key": {"type": "string", "description": "The setting key."},
                    "value": {"description": "The value (scalar or structure)."},
                },
                "required": ["mission_yaml_path", "key", "value"],
            },
        ),
        handler=lambda p: set_mission_setting(Path(p["mission_yaml_path"]), p["key"], p["value"]),
    )
    catalog.register(
        ActionSpec(
            name="create_combat_zone",
            description=(
                "Lay down a complete VEAF combat zone in a mission FOLDER, in one pass, editing "
                "both worlds durably (no build): a circular trigger zone + groups placed inside it "
                "(names auto-prefixed with the zone so it captures them) in src/mission, and a "
                "modules.COMBATZONE.combat_zones[] entry appended in mission.yaml."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (mission.yaml + src/mission/).",
                    },
                    "zone_name": {"type": "string", "description": "The combat zone's trigger-zone name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The zone centre.",
                    },
                    "radius": {"type": "number", "description": "The zone radius, in metres."},
                    "groups": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "units": {"type": "array", "items": {"type": "object"}},
                                "position": {
                                    "type": "object",
                                    "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                                },
                            },
                            "required": ["name", "units"],
                        },
                        "description": "Groups placed inside the zone; names are auto-prefixed with zone_name.",
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "category": {"type": "string", "default": "vehicle"},
                    "combat_zone": {"type": "object", "description": "Optional extra combat_zones[] keys."},
                },
                "required": [
                    "folder_path",
                    "zone_name",
                    "position",
                    "radius",
                    "groups",
                    "coalition",
                    "country_id",
                    "country_name",
                ],
            },
        ),
        handler=_handle_create_combat_zone,
    )
    catalog.register(
        ActionSpec(
            name="list_unit_types",
            description=(
                "List DCS unit types from the canonical generated database (the same the build "
                "ships). Filter by category and/or a name substring. Read-only knowledge for the "
                "LLM to pick concrete unit types."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "category": {"type": "string", "description": "Exact category, e.g. 'Plane', 'Armor'."},
                    "name_contains": {"type": "string", "description": "Case-insensitive substring on id+name."},
                },
            },
        ),
        handler=lambda p: list_unit_types(category=p.get("category"), name_contains=p.get("name_contains")),
    )
    catalog.register(
        ActionSpec(
            name="list_shortcuts",
            description=(
                "List the VEAF spawn aliases (the '-shilka'/'-sa8'… vocabulary) from the "
                "canonical veaf-units.yaml: unit aliases and composite group aliases. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "name_contains": {"type": "string", "description": "Case-insensitive substring on aliases+target."},
                },
            },
        ),
        handler=lambda p: list_shortcuts(name_contains=p.get("name_contains")),
    )
    catalog.register(
        ActionSpec(
            name="describe_naming_conventions",
            description=(
                "Return the reserved VEAF group/unit naming conventions (combat-zone membership, "
                "veafSpawn-/OnDemand- prefixes, #veafInterpreter/#command markers, QRA deploy "
                "entries, …). Check a proposed group name against these before add_group."
            ),
            parameters_schema={"type": "object", "properties": {}},
        ),
        handler=lambda _p: describe_naming_conventions(),
    )
    catalog.register(
        ActionSpec(
            name="describe_module",
            description=(
                "Look a VEAF module up in the canonical module list and point to its doc page; "
                "optionally report whether it is enabled in a given mission.yaml. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "module_id": {"type": "string", "description": "Module id, e.g. 'QRA', 'COMBATZONE'."},
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Optional mission.yaml to report the enabled state from.",
                    },
                },
                "required": ["module_id"],
            },
        ),
        handler=lambda p: describe_module(
            p["module_id"],
            mission_yaml_path=Path(p["mission_yaml_path"]) if p.get("mission_yaml_path") else None,
        ),
    )


def _handle_replace_in_mission_files(params: dict[str, Any]) -> dict[str, Any]:
    return replace_in_mission_files(
        Path(params["miz_path"]),
        search=params["search"],
        replace=params["replace"],
        files=params.get("files", "*.lua"),
        regex=params.get("regex", False),
    )


def _handle_add_group(params: dict[str, Any]) -> dict[str, Any]:
    return add_group(
        Path(params["miz_path"]),
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        category=params["category"],
        name=params["name"],
        position=params["position"],
        units=params["units"],
        route=params.get("route"),
        patrol=params.get("patrol", False),
        for_combat_zone=params.get("for_combat_zone"),
        late_activation=params.get("late_activation", False),
        as_spawn_template=params.get("as_spawn_template", False),
    )


def _handle_create_combat_zone(params: dict[str, Any]) -> dict[str, Any]:
    return create_combat_zone(
        Path(params["folder_path"]),
        zone_name=params["zone_name"],
        position=params["position"],
        radius=params["radius"],
        groups=params["groups"],
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        category=params.get("category", "vehicle"),
        combat_zone=params.get("combat_zone"),
    )


def _handle_add_trigger_zone(params: dict[str, Any]) -> dict[str, Any]:
    return add_trigger_zone(
        Path(params["miz_path"]),
        name=params["name"],
        position=params["position"],
        radius=params["radius"],
        hidden=params.get("hidden", False),
        color=params.get("color"),
    )


def _handle_add_startup_script_trigger(params: dict[str, Any]) -> dict[str, Any]:
    return add_startup_script_trigger(
        Path(params["miz_path"]),
        mode=params["mode"],
        comment=params["comment"],
        inline_lua=params.get("inline_lua"),
        source_path=params.get("source_path"),
        runtime_path=params.get("runtime_path"),
        resource_name=params.get("resource_name"),
    )
