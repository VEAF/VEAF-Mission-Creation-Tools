"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path
from typing import Any

from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.describe_mission import describe_mission
from veaf_mission_mcp.models import ActionSpec


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
