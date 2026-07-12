"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path
from typing import Any

from veaf_mission_mcp.add_group import add_group
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
