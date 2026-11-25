"""MCP server entry point for LLM-assisted mission editing (``veaf-mission-mcp``).

Exposes a fixed discovery surface — ``capabilities``, ``list_catalog``,
``describe_action``, ``run_action`` — instead of one MCP tool per mission-editing
action, mirroring the existing ``dcs-bridge`` MCP tool's shape. Concrete actions are
registered by :func:`veaf_mission_mcp.actions.register_default_actions`.
"""

import inspect
import os
import sys
import threading
from pathlib import Path
from typing import Any

from mcp.server import MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from mcp.shared.exceptions import MCPError
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_tools.app import VERSION

from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog, summary
from veaf_mission_mcp.response_budget import MAX_RESPONSE_CHARS, capped, to_text
from veaf_mission_mcp.self_update import PINNED_TAG_ENV_VAR, start_update_if_due

SERVER_NAME = "veaf-mission-mcp"

CATALOG = ActionCatalog()
register_default_actions(CATALOG)

# Short on purpose: a client puts a server's instructions in every session's prompt, so the 27 KB
# guide is pointed at rather than carried.
INSTRUCTIONS = (
    "VEAF DCS mission authoring server. Before any other action, read the VEAF authoring guide with "
    "run_action('describe_authoring_guide') and follow it: it holds the order of work and the naming "
    "conventions a mission needs to work in DCS. Then call run_action('describe_known_limitations'). "
    "When the user asks for a new mission, the guide says which mission prompt to load."
)

mcp = MCPServer(SERVER_NAME, instructions=INSTRUCTIONS)


@mcp.tool()
def capabilities() -> dict[str, str]:
    """Return static server identification.

    Returns:
        A dict with the server's ``name`` and ``version``.
    """
    return {"name": SERVER_NAME, "version": VERSION}


#: The most `list_catalog(full=True)` puts in one page, in characters, under the response ceiling.
_FULL_CATALOG_PAGE_CHARS = MAX_RESPONSE_CHARS - 1_000


def list_catalog(full: bool = False, offset: int = 0) -> list[dict[str, Any]] | dict[str, Any]:
    """List every action currently registered in the catalog.

    Every full schema at once was 67 388 characters: the client saved it to a file and the agent read
    it back in pieces (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 14). ``describe_action`` gives one.

    Args:
        full: Return the actions' full specs, one page at a time (``offset``, then ``next_offset``).
        offset: With ``full``, the first action of the page.

    Returns:
        One dict per registered action: ``{name, summary}`` — the description's first sentence — or,
        with ``full``, ``{actions: [{name, description, parameters_schema}], total, next_offset}``,
        ``next_offset`` null on the last page.
    """
    specs = CATALOG.list_catalog()
    if not full:
        return [{"name": spec.name, "summary": summary(spec.description)} for spec in specs]
    page: list[dict[str, Any]] = []
    size = 0
    index = max(offset, 0)
    while index < len(specs):
        entry = specs[index].model_dump()
        entry_size = len(to_text(entry))
        if page and size + entry_size > _FULL_CATALOG_PAGE_CHARS:
            break
        page.append(entry)
        size += entry_size
        index += 1
    return {"actions": page, "total": len(specs), "next_offset": index if index < len(specs) else None}


def describe_action(name: str) -> dict[str, Any]:
    """Describe one action's parameters.

    Args:
        name: The action's registered name.

    Returns:
        The action's spec (``name``, ``description``, ``parameters_schema``).
    """
    return CATALOG.describe_action(name).model_dump()


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


# The tools the client sees answer one text block of compact JSON, cut at the response ceiling, with no
# structured copy: `mcp` sent a list as one block per item plus a `structuredContent` copy, and every
# object indented (MCP-CONTEXT-BUDGET). The functions above stay the Python API.


def _list_catalog_tool(full: bool = False, offset: int = 0) -> str:
    return capped(to_text(list_catalog(full, offset)), "Read the next page with offset=next_offset.")


def _describe_action_tool(name: str) -> str:
    return capped(to_text(describe_action(name)))


def _run_action_tool(name: str, params: dict[str, Any] | None = None) -> str:
    text = to_text(run_action(name, params))
    if CATALOG.is_uncapped(name, params or {}):
        return text
    return capped(text, CATALOG.oversize_hint(name))


mcp.add_tool(_list_catalog_tool, name="list_catalog", description=inspect.getdoc(list_catalog), structured_output=False)
mcp.add_tool(
    _describe_action_tool, name="describe_action", description=inspect.getdoc(describe_action), structured_output=False
)
mcp.add_tool(_run_action_tool, name="run_action", description=inspect.getdoc(run_action), structured_output=False)


def self_update() -> str:
    """Start the updater when this executable is out of date (FEAT-AI-ZERO-SETUP).

    Only from the installed executable, only when the user left update checks on (`check_updates` in
    the user configuration), and never while a pre-release is pinned (`VEAF_MCP_UPDATER_TAG`): the
    server would leave the version the missions it scaffolds use. Never raises: an update is not worth a server that does not start.

    Returns:
        What happened, for the log: `not_frozen`, `pinned`, `disabled`, `failed`, or what
        :func:`start_update_if_due` answered.
    """
    if not getattr(sys, "frozen", False):
        return "not_frozen"
    if os.environ.get(PINNED_TAG_ENV_VAR):
        return "pinned"
    try:
        from veaf_libs.user_config import get_check_updates
        from veaf_libs.veaf_home import get_veaf_home

        if not get_check_updates():
            return "disabled"
        outcome = start_update_if_due(VERSION, Path(sys.executable).resolve(), get_veaf_home())
    except Exception as exc:  # noqa: BLE001 — see the docstring
        logger.warning(t("mcp.self_update_failed", error=f"{type(exc).__name__}: {exc}"))
        return "failed"
    logger.info(t("mcp.self_update", outcome=outcome))
    return outcome


def main() -> None:
    """Start the MCP server over stdio."""
    # stdout carries the MCP JSON-RPC stream — silence the Rich console so no log line ever
    # corrupts it (otherwise the client connects but sees no tools). Logs still go to the log
    # file / logging handlers (stderr).
    logger.mute_console()
    logger.info(f"Starting {SERVER_NAME} v{VERSION}")
    # In the background: a slow GitHub must never delay the client's handshake.
    threading.Thread(target=self_update, name="self-update", daemon=True).start()
    mcp.run()


if __name__ == "__main__":
    main()
