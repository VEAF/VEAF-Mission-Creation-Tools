"""Declare the VEAF MCP server in the AI clients installed on this PC (``veaf-tools ai-setup``).

Each client reads the same two facts — the command (this ``veaf-tools.exe``) and its argument
(``mcp``) — from its own file. Declaring them by hand meant a JSON file per client and doubled
backslashes; this module writes them, merging into whatever the file already holds (FEAT-AI-ZERO-SETUP).
"""

import json
import os
import subprocess
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

from veaf_libs.atomic_replace import atomic_replace

#: The server's name in every client: what the tools are listed under (`mcp__veaf-mission-editor__…`).
SERVER_KEY = "veaf-mission-editor"

Status = Literal["configured", "not_found", "failed"]


@dataclass(frozen=True)
class ClientResult:
    """What `ai-setup` did for one client.

    Attributes:
        client: The client's name, as the user knows it.
        status: `configured`, `not_found` (the client is not installed) or `failed`.
        detail: The file or command written, or why it failed.
    """

    client: str
    status: Status
    detail: str = ""


def server_entry(exe: Path) -> dict[str, Any]:
    """Return the server declaration every client takes.

    Args:
        exe: The `veaf-tools` executable that runs the server.

    Returns:
        `{"command": <exe>, "args": ["mcp"]}`.
    """
    return {"command": str(exe), "args": ["mcp"]}


def merge_server_into_json(config_path: Path, exe: Path) -> None:
    """Declare the server in a client's JSON settings file, keeping everything else in it.

    Args:
        config_path: The settings file; created if missing.
        exe: The `veaf-tools` executable that runs the server.

    Raises:
        ValueError: The file is not a JSON object, or its `mcpServers` is not one. It is left as it is.
    """
    text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
    try:
        data = json.loads(text) if text.strip() else {}
    except json.JSONDecodeError as e:
        raise ValueError(f"{config_path} is not valid JSON: {e}") from e
    if not isinstance(data, dict):
        raise ValueError(f"{config_path} does not hold a JSON object")
    servers = data.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        raise ValueError(f"{config_path}: 'mcpServers' is not a JSON object")
    servers[SERVER_KEY] = server_entry(exe)
    config_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = config_path.with_name(f"{config_path.name}.veaf-tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    atomic_replace(tmp, config_path)


def _merge_result(client: str, config_path: Path, exe: Path) -> ClientResult:
    """Merge the server into `config_path` and say how it went."""
    try:
        merge_server_into_json(config_path, exe)
    except (OSError, ValueError) as e:
        return ClientResult(client, "failed", str(e))
    return ClientResult(client, "configured", str(config_path))


def setup_claude_desktop(exe: Path, *, appdata: Path) -> ClientResult:
    """Declare the server in Claude Desktop, the Claude application in chat mode.

    `%APPDATA%\\Claude\\claude_desktop_config.json` is the file its *Edit Config* opens. The Store
    install keeps its files under `Packages\\Claude_…\\LocalCache`, and `%APPDATA%\\Claude` is a link
    to that folder (measured 2026-10-20), so the one path serves both installs.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        appdata: The user's `%APPDATA%` folder.

    Returns:
        The outcome; `not_found` when `%APPDATA%\\Claude` does not exist.
    """
    folder = appdata / "Claude"
    if not folder.is_dir():
        return ClientResult("Claude Desktop", "not_found")
    return _merge_result("Claude Desktop", folder / "claude_desktop_config.json", exe)


def setup_gemini(exe: Path, *, home: Path) -> ClientResult:
    """Declare the server in Gemini CLI's user settings, `~/.gemini/settings.json`.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.

    Returns:
        The outcome; `not_found` when `~/.gemini` does not exist.
    """
    folder = home / ".gemini"
    if not folder.is_dir():
        return ClientResult("Gemini CLI", "not_found")
    return _merge_result("Gemini CLI", folder / "settings.json", exe)


def find_claude_cli(path_env: str | None = None) -> str | None:
    """Find Claude Code's own executable in the PATH folders, and only there.

    `shutil.which` also looks in the current folder on Windows, even given an explicit path (measured
    2026-10-20 with Python 3.13): a `claude.exe` dropped next to `veaf-tools.exe` would run. A
    `claude.cmd` (an npm install) is not taken either: `cmd.exe` would re-read the JSON passed to it.

    Args:
        path_env: The PATH to search; the process's own by default.

    Returns:
        The executable's path, or `None`.
    """
    name = "claude.exe" if os.name == "nt" else "claude"
    for folder in (os.environ.get("PATH", "") if path_env is None else path_env).split(os.pathsep):
        folder = folder.strip().strip('"')
        if not folder or folder == ".":
            continue
        candidate = Path(folder) / name
        if candidate.is_file():
            return str(candidate)
    return None


def setup_claude_code(
    exe: Path,
    *,
    home: Path,
    which: Callable[[], str | None] = find_claude_cli,
    run: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> ClientResult:
    """Declare the server in Claude Code, for every folder (its *user* scope).

    Claude Code rewrites `~/.claude.json` while it runs — and the AI that runs `ai-setup` may well be
    Claude Code itself — so its own `claude mcp` command does it when it is on the PATH. Without it
    (the Code tab of the Claude application installs none), the file is edited directly.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.
        which: Finds Claude Code's executable (injected for tests).
        run: Runs a command (injected for tests).

    Returns:
        The outcome; `not_found` when there is neither a `claude` command nor a `~/.claude.json`.
    """
    cli = which()
    if cli:
        options: dict[str, Any] = {"capture_output": True, "text": True, "timeout": 60, "check": False}
        # Re-running must replace an older declaration, and `add-json` refuses an existing name.
        run([cli, "mcp", "remove", "--scope", "user", SERVER_KEY], **options)
        try:
            added = run(
                [cli, "mcp", "add-json", "--scope", "user", SERVER_KEY, json.dumps(server_entry(exe))], **options
            )
        except (OSError, subprocess.SubprocessError) as e:
            return ClientResult("Claude Code", "failed", str(e))
        if added.returncode != 0:
            return ClientResult("Claude Code", "failed", (added.stderr or added.stdout or "").strip())
        return ClientResult("Claude Code", "configured", f"{cli} mcp add-json --scope user")
    config = home / ".claude.json"
    if not config.is_file():
        return ClientResult("Claude Code", "not_found")
    return _merge_result("Claude Code", config, exe)


def setup_all(exe: Path, *, home: Path, appdata: Path) -> list[ClientResult]:
    """Declare the server in every supported client.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.
        appdata: The user's `%APPDATA%` folder.

    Returns:
        One result per client, in a fixed order.
    """
    return [
        setup_claude_desktop(exe, appdata=appdata),
        setup_claude_code(exe, home=home),
        setup_gemini(exe, home=home),
    ]
