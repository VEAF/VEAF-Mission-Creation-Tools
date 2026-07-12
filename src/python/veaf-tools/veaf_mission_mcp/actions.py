"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path

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
