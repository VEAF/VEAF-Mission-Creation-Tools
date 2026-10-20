"""``veaf-tools ai-setup`` — declare the VEAF MCP server in every AI client installed on this PC.

Installing the tools and running this command is all an AI assistant needs: the server it declares
serves the authoring guide, the known limitations and the mission prompts (FEAT-AI-ZERO-SETUP).
"""

import os
import sys
from pathlib import Path

import typer
from veaf_libs.ai_clients import setup_all

from veaf_tools.app import app, console, logger, t

_STATUS_STYLE = {"configured": "green", "not_found": "dim", "failed": "red"}


@app.command(name="ai-setup", help=t("cmd.ai_setup.help"))
def ai_setup() -> None:
    """Declare this executable's MCP server in Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI and OpenCode.

    Raises:
        typer.Exit: Exit code 1 when no client was found or one could not be configured.
    """
    if not getattr(sys, "frozen", False):
        # From `poetry run`, sys.executable is python.exe: a client would start an interpreter, not the server.
        logger.error(t("cmd.ai_setup.not_frozen"))
    exe = Path(sys.executable).resolve()
    appdata = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming")
    results = setup_all(exe, home=Path.home(), appdata=appdata)

    console.print(t("cmd.ai_setup.server", exe=str(exe)))
    for result in results:
        status = t(f"cmd.ai_setup.status.{result.status}")
        line = f"  {result.client}: {status}" + (f" — {result.detail}" if result.detail else "")
        console.print(line, style=_STATUS_STYLE[result.status], markup=False, highlight=False)

    configured = [r for r in results if r.status == "configured"]
    if not configured:
        console.print(t("cmd.ai_setup.none_found"), style="yellow")
    else:
        console.print(t("cmd.ai_setup.restart"), style="bold blue")
    if not configured or any(r.status == "failed" for r in results):
        raise typer.Exit(code=1)
