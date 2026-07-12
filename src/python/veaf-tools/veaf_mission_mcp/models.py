"""Data models for the mission-editing MCP action catalog."""

from typing import Any

from pydantic import BaseModel


class ActionSpec(BaseModel):
    """Describes one action registered in the catalog.

    Attributes:
        name: Unique action identifier, as used by ``describe_action``/``run_action``.
        description: Human-readable summary of what the action does.
        parameters_schema: JSON Schema for the ``params`` object accepted by ``run_action``.
    """

    name: str
    description: str
    parameters_schema: dict[str, Any]
