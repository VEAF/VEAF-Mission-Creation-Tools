"""`veaf-tools mcp` — start the LLM-assisted mission-editing MCP server.

Thin CLI entry that launches the existing `veaf_mission_mcp` stdio server, so the server ships
inside the already-built `veaf-tools` binary (no separate binary to build/vendor). A Claude plugin
declares this command in its `.mcp.json` to expose the mission-editing actions.
"""

from veaf_tools.app import app, t


@app.command(help=t("cmd.mcp.help"))
def mcp() -> None:
    """Start the veaf-mission-mcp server on stdio (blocks until the client disconnects)."""
    from veaf_mission_mcp.server import main as run_server

    run_server()
