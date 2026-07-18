"""MCP server entry point for LLM-assisted mission editing (``veaf-mission-mcp``).

Exposes a fixed discovery surface — ``capabilities``, ``list_catalog``,
``describe_action``, ``run_action`` — instead of one MCP tool per mission-editing
action, mirroring the existing ``dcs-bridge`` MCP tool's shape. Concrete actions are
registered by :func:`veaf_mission_mcp.actions.register_default_actions`.
"""

from typing import Any

from mcp.server.fastmcp import FastMCP
from veaf_libs.logger import logger
from veaf_tools.app import VERSION

from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog

SERVER_NAME = "veaf-mission-mcp"

CATALOG = ActionCatalog()
register_default_actions(CATALOG)

mcp = FastMCP(SERVER_NAME)


@mcp.tool()
def capabilities() -> dict[str, str]:
    """Return static server identification.

    Returns:
        A dict with the server's ``name`` and ``version``.
    """
    return {"name": SERVER_NAME, "version": VERSION}


@mcp.tool()
def list_catalog() -> list[dict[str, Any]]:
    """List every action currently registered in the catalog.

    Returns:
        One dict per registered action (``name``, ``description``, ``parameters_schema``).
    """
    return [spec.model_dump() for spec in CATALOG.list_catalog()]


@mcp.tool()
def describe_action(name: str) -> dict[str, Any]:
    """Describe one action's parameters.

    Args:
        name: The action's registered name.

    Returns:
        The action's spec (``name``, ``description``, ``parameters_schema``).
    """
    return CATALOG.describe_action(name).model_dump()


@mcp.tool()
def run_action(name: str, params: dict[str, Any] | None = None) -> Any:
    """Run a registered action.

    Args:
        name: The action's registered name.
        params: Parameters forwarded to the action's handler.

    Returns:
        Whatever the action's handler returns.
    """
    return CATALOG.run_action(name, params or {})


def main() -> None:
    """Start the MCP server over stdio."""
    # stdout carries the MCP JSON-RPC stream — silence the Rich console so no log line ever
    # corrupts it (otherwise the client connects but sees no tools). Logs still go to the log
    # file / logging handlers (stderr).
    logger.mute_console()
    logger.info(f"Starting {SERVER_NAME} v{VERSION}")
    mcp.run()


if __name__ == "__main__":
    main()
