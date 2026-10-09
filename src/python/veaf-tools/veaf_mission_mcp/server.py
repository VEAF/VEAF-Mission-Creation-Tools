"""MCP server entry point for LLM-assisted mission editing (``veaf-mission-mcp``).

Exposes a fixed discovery surface — ``capabilities``, ``list_catalog``,
``describe_action``, ``run_action`` — instead of one MCP tool per mission-editing
action, mirroring the existing ``dcs-bridge`` MCP tool's shape. Concrete actions are
registered by :func:`veaf_mission_mcp.actions.register_default_actions`.
"""

from typing import Any

from mcp.server import MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from mcp.shared.exceptions import MCPError
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_tools.app import VERSION

from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog, summary

SERVER_NAME = "veaf-mission-mcp"

CATALOG = ActionCatalog()
register_default_actions(CATALOG)

# Short on purpose: Claude Code puts a server's instructions in every session's prompt, where the
# plugin's skill already is. A client without the plugin is pointed at the same text instead.
INSTRUCTIONS = (
    "VEAF DCS mission authoring server. Before any other action, read the VEAF authoring guide and "
    "follow it: it holds the order of work and the naming conventions a mission needs to work in DCS. "
    "If you have the veaf-mission-authoring skill, load that skill: it is the guide. Otherwise call "
    "run_action('describe_authoring_guide'). Then call run_action('describe_known_limitations')."
)

mcp = MCPServer(SERVER_NAME, instructions=INSTRUCTIONS)


@mcp.tool()
def capabilities() -> dict[str, str]:
    """Return static server identification.

    Returns:
        A dict with the server's ``name`` and ``version``.
    """
    return {"name": SERVER_NAME, "version": VERSION}


@mcp.tool()
def list_catalog(full: bool = False) -> list[dict[str, Any]]:
    """List every action currently registered in the catalog.

    Every full schema at once was 67 388 characters: the client saved it to a file and the agent read
    it back in pieces (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 14). ``describe_action`` gives one.

    Args:
        full: Return every action's full spec, as before.

    Returns:
        One dict per registered action: ``{name, summary}`` — the description's first sentence — or,
        with ``full``, ``{name, description, parameters_schema}``.
    """
    if full:
        return [spec.model_dump() for spec in CATALOG.list_catalog()]
    return [{"name": spec.name, "summary": summary(spec.description)} for spec in CATALOG.list_catalog()]


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

    Raises:
        ToolError: For any failure of the action, carrying its type and message. `mcp` 2.x shows the
            client only "Error executing tool run_action" for any other exception, which is how a
            misnamed parameter, and every refusal an action words for the agent, reached it as that
            one line (FIX-SCRATCH-MISSION-FINDINGS ticket 19).
    """
    try:
        return CATALOG.run_action(name, params or {})
    except (ToolError, MCPError):
        raise
    except Exception as exc:
        logger.warning(t("mcp.run_action_failed", name=name, error=f"{type(exc).__name__}: {exc}"))
        raise ToolError(f"{type(exc).__name__}: {exc}") from exc


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
