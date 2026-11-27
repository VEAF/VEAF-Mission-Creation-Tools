"""Declare the VEAF MCP server in the AI clients installed on this PC (``veaf-tools ai-setup``).

Each client reads the same two facts — the command (this ``veaf-tools.exe``) and its argument
(``mcp``) — from its own file. Declaring them by hand meant a JSON file per client and doubled
backslashes; this module writes them, merging into whatever the file already holds (FEAT-AI-ZERO-SETUP).
"""

import json
import os
import sqlite3
import subprocess
import time
import tomllib
import uuid
from collections.abc import Callable, Sequence
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


def merge_server_into_json(
    config_path: Path,
    exe: Path,
    *,
    servers_key: str = "mcpServers",
    entry: dict[str, Any] | None = None,
) -> None:
    """Declare the server in a client's JSON settings file, keeping everything else in it.

    Args:
        config_path: The settings file; created if missing.
        exe: The `veaf-tools` executable that runs the server.
        servers_key: The key the client keeps its servers under.
        entry: The declaration in the client's own shape; :func:`server_entry` by default.

    Raises:
        ValueError: The file is not a JSON object, or its servers key is not one. It is left as it is.
    """
    # utf-8-sig: Notepad, which the manual install had users edit this file with, may write a BOM.
    text = config_path.read_text(encoding="utf-8-sig") if config_path.exists() else ""
    try:
        data = json.loads(text) if text.strip() else {}
    except json.JSONDecodeError as e:
        raise ValueError(f"{config_path} is not valid JSON: {e}") from e
    if not isinstance(data, dict):
        raise ValueError(f"{config_path} does not hold a JSON object")
    servers = data.setdefault(servers_key, {})
    if not isinstance(servers, dict):
        raise ValueError(f"{config_path}: '{servers_key}' is not a JSON object")
    servers[SERVER_KEY] = entry if entry is not None else server_entry(exe)
    config_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = config_path.with_name(f"{config_path.name}.veaf-tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    atomic_replace(tmp, config_path)


def _merge_result(client: str, config_path: Path, exe: Path, **shape: Any) -> ClientResult:
    """Merge the server into `config_path` and say how it went.

    Args:
        client: The client's name, for the result.
        config_path: Its settings file.
        exe: The `veaf-tools` executable that runs the server.
        **shape: `servers_key` and `entry` for a client whose file differs from Claude's.

    Returns:
        `configured` with the file written, or `failed` with the reason; the file is then untouched.
    """
    try:
        merge_server_into_json(config_path, exe, **shape)
    except (OSError, ValueError) as e:
        return ClientResult(client, "failed", str(e))
    return ClientResult(client, "configured", str(config_path))


def setup_claude_desktop(exe: Path, *, appdata: Path, localappdata: Path | None = None) -> ClientResult:
    """Declare the server in Claude Desktop, the Claude application in chat mode.

    `%APPDATA%\\Claude\\claude_desktop_config.json` is the file its *Edit Config* opens. The Store
    install keeps its files under `Packages\\Claude_…\\LocalCache`, and `%APPDATA%\\Claude` is a link
    to that folder (measured 2026-10-20), so the one path serves both installs.

    A Store install that moved its data out of the package keeps them, that file included, in
    `%LOCALAPPDATA%\\Claude-Data\\claude_<package id>`, and `%APPDATA%\\Claude` then does not exist
    outside the package (measured on version 3.1623, 2026-10-20). That folder wins when it exists.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        appdata: The user's `%APPDATA%` folder.
        localappdata: The user's `%LOCALAPPDATA%` folder.

    Returns:
        The outcome; `not_found` when neither folder exists.
    """
    data = sorted(p for p in (localappdata / "Claude-Data").glob("claude_*") if p.is_dir()) if localappdata else []
    folder = data[0] if data else appdata / "Claude"
    if not folder.is_dir():
        return ClientResult("Claude Desktop", "not_found")
    return _merge_result("Claude Desktop", folder / "claude_desktop_config.json", exe)


def setup_gemini(exe: Path, *, home: Path) -> ClientResult:
    """Declare the server in Gemini CLI's user settings, `~/.gemini/settings.json`.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.

    Returns:
        The outcome; `not_found` without a `~/.gemini/settings.json` — Antigravity keeps its own files
        under `~/.gemini` too, so the folder alone does not mean Gemini CLI.
    """
    settings = home / ".gemini" / "settings.json"
    if not settings.is_file():
        return ClientResult("Gemini CLI", "not_found")
    return _merge_result("Gemini CLI", settings, exe)


def setup_antigravity(exe: Path, *, home: Path) -> ClientResult:
    """Declare the server in Antigravity, Google's agent, `~/.gemini/config/mcp_config.json`.

    Same `mcpServers` shape as Claude's (antigravity.google/docs/mcp, read 2026-10-20); the CLI and the
    IDE list the same path. Taken as installed when its `config` or `antigravity-cli` folder exists.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.

    Returns:
        The outcome; `not_found` when neither Antigravity folder exists.
    """
    gemini = home / ".gemini"
    if not (gemini / "config").is_dir() and not (gemini / "antigravity-cli").is_dir():
        return ClientResult("Antigravity", "not_found")
    return _merge_result("Antigravity", gemini / "config" / "mcp_config.json", exe)


def merge_server_into_codex_toml(config_path: Path, exe: Path) -> None:
    """Declare the server in Codex's `config.toml`, keeping every other line of it.

    No TOML writer ships with veaf-tools, so the server's own `[mcp_servers.<name>]` section is
    replaced in place, or appended; the result must read back as TOML before anything is written.

    Args:
        config_path: Codex's `config.toml`; created if missing.
        exe: The `veaf-tools` executable that runs the server.

    Raises:
        ValueError: The file, or the result, does not read as TOML. The file is left as it is.
    """
    text = config_path.read_text(encoding="utf-8-sig") if config_path.exists() else ""
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as e:
        raise ValueError(f"{config_path} is not valid TOML: {e}") from e
    header = f"[mcp_servers.{SERVER_KEY}]"
    # json.dumps writes a TOML basic string: backslashes and non-ASCII characters escaped alike.
    section = f'{header}\ncommand = {json.dumps(str(exe))}\nargs = ["mcp"]\n'
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
    if start is None:
        separator = "" if not text else ("\n" if text.endswith("\n") else "\n\n")
        edited = text + separator + section
    else:
        end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
        edited = "".join(lines[:start]) + section + ("\n" if end < len(lines) else "") + "".join(lines[end:])
    try:
        written = tomllib.loads(edited)["mcp_servers"][SERVER_KEY]
    except (tomllib.TOMLDecodeError, KeyError) as e:
        raise ValueError(f"declaring the server would break {config_path}: {e}") from e
    if written.get("command") != str(exe):
        raise ValueError(f"declaring the server would break {config_path}")
    config_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = config_path.with_name(f"{config_path.name}.veaf-tmp")
    tmp.write_text(edited, encoding="utf-8", newline="\n")
    atomic_replace(tmp, config_path)


def setup_codex(exe: Path, *, home: Path) -> ClientResult:
    """Declare the server in Codex, `~/.codex/config.toml`.

    The ChatGPT desktop app, the Codex CLI and its IDE extension share that file
    (learn.chatgpt.com/docs/extend/mcp, read 2026-10-20).

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.

    Returns:
        The outcome; `not_found` when `~/.codex` does not exist.
    """
    folder = home / ".codex"
    if not folder.is_dir():
        return ClientResult("Codex", "not_found")
    config = folder / "config.toml"
    try:
        merge_server_into_codex_toml(config, exe)
    except (OSError, ValueError) as e:
        return ClientResult("Codex", "failed", str(e))
    return ClientResult("Codex", "configured", str(config))


def setup_opencode(exe: Path, *, home: Path) -> ClientResult:
    """Declare the server in OpenCode's global config, `~/.config/opencode/opencode.json`.

    OpenCode keeps its servers under `mcp`, each `{"type": "local", "command": [...]}` with the
    command and its arguments in one list (opencode.ai/docs/mcp-servers, read 2026-10-20). It is
    taken as installed when either its config or its data folder exists: a first run creates the
    data folder, not always the config one. A user who keeps a commented `opencode.jsonc` gets a
    `failed` rather than a rewrite that would drop the comments.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.

    Returns:
        The outcome; `not_found` when neither OpenCode folder exists.
    """
    folder = home / ".config" / "opencode"
    if not folder.is_dir() and not (home / ".local" / "share" / "opencode").is_dir():
        return ClientResult("OpenCode", "not_found")
    config = folder / "opencode.json"
    if not config.exists() and (folder / "opencode.jsonc").exists():
        config = folder / "opencode.jsonc"
    entry = {"type": "local", "command": [str(exe), "mcp"], "enabled": True}
    return _merge_result("OpenCode", config, exe, servers_key="mcp", entry=entry)


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
        if not folder or not Path(folder).is_absolute():
            continue  # empty, ".", or relative: all of them resolve against the current folder
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
    (the Code tab of the Claude application installs none), or when it fails after removing the old
    declaration, the file is edited directly: a failed run never leaves Claude Code without the server.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.
        which: Finds Claude Code's executable (injected for tests).
        run: Runs a command (injected for tests).

    Returns:
        The outcome; `not_found` when there is neither a `claude` command nor a `~/.claude.json`.
    """
    config = home / ".claude.json"
    cli = which()
    if cli:
        options: dict[str, Any] = {"capture_output": True, "text": True, "timeout": 60, "check": False}
        try:
            # Re-running must replace an older declaration, and `add-json` refuses an existing name.
            run([cli, "mcp", "remove", "--scope", "user", SERVER_KEY], **options)
            added = run(
                [cli, "mcp", "add-json", "--scope", "user", SERVER_KEY, json.dumps(server_entry(exe))], **options
            )
            error = "" if added.returncode == 0 else (added.stderr or added.stdout or "").strip()
        except (OSError, subprocess.SubprocessError) as e:
            error = str(e)
        if not error:
            return ClientResult("Claude Code", "configured", f"{cli} mcp add-json --scope user")
        if not config.is_file():
            return ClientResult("Claude Code", "failed", error)
    elif not config.is_file():
        return ClientResult("Claude Code", "not_found")
    return _merge_result("Claude Code", config, exe)


#: The server's name in Cherry Studio: the one the starting backup of the local-model tutorial carries.
CHERRY_SERVER_NAME = "veaf"

#: What the server's `env` must hold in Cherry: the local model's 65 536-token context needs the compact answers.
CHERRY_SERVER_ENV = {"VEAF_MCP_PROFILE": "compact"}

#: The Cherry Studio version whose database layout `setup_cherry` was written and tested against.
CHERRY_TESTED_VERSION = "2.2.3"

#: The columns `setup_cherry` reads or writes, per table. In the two tables it inserts into, any other
#: NOT NULL column without a default would make the insert fail, or mean the layout changed: both are
#: refused before anything is written. `assistant` is only read.
_CHERRY_COLUMNS = {
    "mcp_server": {
        "id", "name", "type", "command", "args", "env", "is_active", "install_source", "is_trusted",
        "trusted_at", "installed_at", "created_at", "updated_at",
    },
    "assistant_mcp_server": {"assistant_id", "mcp_server_id", "created_at", "updated_at"},
    "assistant": {"id", "name", "deleted_at"},
}  # fmt: skip


def cherry_user_data(appdata: Path, home: Path) -> Path:
    """Find Cherry Studio's data folder: `%APPDATA%\\CherryStudio`, unless the user moved it.

    Cherry 2.x keeps a moved folder in `~/.cherrystudio/boot-config.json`, under the flat key
    `app.user_data_path`, as a map from Cherry's executable path to the folder
    (`src/main/core/preboot/userDataLocation.ts`, tag v2.2.3). Which executable runs is not known here,
    so only a map with a single folder is followed. Like Cherry, a moved folder that no longer exists
    falls back to the default one.

    Args:
        appdata: The user's `%APPDATA%` folder.
        home: The user's home folder.

    Returns:
        The data folder, whether it exists or not.

    Raises:
        ValueError: `boot-config.json` cannot be read, or names more than one folder.
    """
    boot = home / ".cherrystudio" / "boot-config.json"
    if boot.is_file():
        try:
            config = json.loads(boot.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as e:
            raise ValueError(f"{boot} cannot be read: {e}") from e
        moved = config.get("app.user_data_path") if isinstance(config, dict) else None
        if moved:
            folders = list(moved.values()) if isinstance(moved, dict) else []
            if len(folders) != 1 or not isinstance(folders[0], str):
                raise ValueError(f"{boot}: cannot tell which Cherry Studio data folder to use: {moved}")
            if Path(folders[0]).is_dir():
                return Path(folders[0])
    return appdata / "CherryStudio"


def cherry_is_running(
    user_data: Path,
    *,
    run: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
    windows: bool = os.name == "nt",
) -> bool:
    """Tell whether Cherry Studio is open.

    Its `lockfile` cannot be opened while it runs (measured 2026-11-26), and its process is listed by
    `tasklist`. A process list that cannot be read counts as open: writing under a running Cherry is the
    one thing to avoid.

    Args:
        user_data: Cherry's data folder, which holds its `lockfile`.
        run: Runs a command (injected for tests).
        windows: Whether to ask `tasklist` (injected for tests).

    Returns:
        True when Cherry is, or may be, running.
    """
    lock = user_data / "lockfile"
    if lock.exists():
        try:
            with lock.open("ab"):
                pass
        except PermissionError:
            return True
    if not windows:
        return False
    try:
        listed = run(
            ["tasklist", "/FI", "IMAGENAME eq Cherry Studio.exe", "/NH", "/FO", "CSV"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return True
    return "cherry studio.exe" in (listed.stdout or "").lower()


def _check_cherry_tables(con: sqlite3.Connection, tables: Sequence[str]) -> tuple[str, str, list[str]] | None:
    """Compare Cherry's tables with the layout `setup_cherry` writes.

    Args:
        con: The open database.
        tables: The tables to check.

    Returns:
        `None` when the layout is the expected one; otherwise the first table that differs, how
        (`missing` columns, or `new required` columns), and those columns.
    """
    for table in tables:
        info = con.execute(f"PRAGMA table_info({table})").fetchall()  # cid, name, type, notnull, default, pk
        columns = {row[1] for row in info}
        missing = sorted(_CHERRY_COLUMNS[table] - columns)
        if missing:
            return table, "missing", missing
        if table == "assistant":
            continue  # only read
        unfilled = sorted(row[1] for row in info if row[3] and row[4] is None and row[1] not in _CHERRY_COLUMNS[table])
        if unfilled:
            return table, "new required", unfilled
    return None


def _cherry_env(text: str | None) -> dict[str, Any]:
    """Merge the compact profile into a server's `env`, keeping its other variables.

    Args:
        text: The `env` column, JSON text or NULL.

    Returns:
        The merged variables.

    Raises:
        ValueError: The column is not a JSON object.
    """
    try:
        env = json.loads(text) if text else {}
    except json.JSONDecodeError as e:
        raise ValueError(f"the env of the '{CHERRY_SERVER_NAME}' server is not JSON: {e}") from e
    if not isinstance(env, dict):
        raise ValueError(f"the env of the '{CHERRY_SERVER_NAME}' server is not a JSON object")
    return {**env, **CHERRY_SERVER_ENV}


def _compact_json(value: Any) -> str:
    """Write JSON the way Cherry's `JSON.stringify` does: no spaces, non-ASCII kept.

    Args:
        value: The value to write.

    Returns:
        Its JSON text.
    """
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def setup_cherry(
    exe: Path,
    *,
    appdata: Path,
    home: Path,
    assistants: Sequence[str] = (),
    data_dir: Path | None = None,
    is_running: Callable[[Path], bool] = cherry_is_running,
    clock: Callable[[], float] = time.time,
) -> ClientResult:
    """Point Cherry Studio's `veaf` server at this executable, with the compact profile.

    Cherry 2.x keeps its MCP servers in its SQLite database, `<data>\\Data\\cherrystudio.sqlite`, table
    `mcp_server`, and the assistants that use one in `assistant_mcp_server` (CherryHQ/cherry-studio,
    tag v2.2.3). Nothing outside the database declares a server, so it is written directly — only with
    Cherry closed: its assistant form saves the whole set of links of an assistant, and would undo a
    write made under it.

    The server named `veaf` gets `command` = the executable, `args` = `["mcp"]`,
    `VEAF_MCP_PROFILE=compact` merged into its `env`, and is made an active `stdio` server; it is created
    when missing. No assistant is linked or unlinked unless named in `assistants`.
    The database is copied next to itself before any write.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        appdata: The user's `%APPDATA%` folder.
        home: The user's home folder.
        assistants: Names of assistants to link to the server; an unknown name is reported, not fatal.
        data_dir: Cherry's data folder, as given to Cherry's `--user-data-dir` (`--cherry-data-dir`); it
            replaces both `boot-config.json` and `%APPDATA%\\CherryStudio`.
        is_running: Tells whether Cherry is open (injected for tests).
        clock: The current time in seconds (injected for tests).

    Returns:
        The outcome; `not_found` when Cherry's default data folder does not exist, `failed` with the
        reason when a forced folder does not exist, Cherry is open or its database is not the one
        expected — nothing is then written.
    """
    client = "Cherry Studio"
    if data_dir is not None:
        user_data = data_dir
        if not user_data.is_dir():
            return ClientResult(client, "failed", f"{user_data} not found")
    else:
        try:
            user_data = cherry_user_data(appdata, home)
        except ValueError as e:
            return ClientResult(client, "failed", str(e))
        if not user_data.is_dir():
            return ClientResult(client, "not_found")
    if is_running(user_data):
        return ClientResult(client, "failed", "Cherry Studio is open: close Cherry Studio, then run again")
    db = user_data / "Data" / "cherrystudio.sqlite"
    if not db.is_file():
        return ClientResult(client, "failed", f"{db} not found: Cherry Studio 2.x must have been started once")
    try:
        return _write_cherry(db, exe, assistants, int(clock() * 1000), user_data)
    except (OSError, ValueError, sqlite3.Error) as e:
        return ClientResult(client, "failed", str(e))


def _write_cherry(db: Path, exe: Path, assistants: Sequence[str], now_ms: int, user_data: Path) -> ClientResult:
    """Check Cherry's database, back it up and write the `veaf` server, in one transaction.

    Args:
        db: `cherrystudio.sqlite`.
        exe: The `veaf-tools` executable that runs the server.
        assistants: Names of assistants to link to the server.
        now_ms: The current time in milliseconds, Cherry's timestamp unit.
        user_data: Cherry's data folder, for the version shown in a refusal.

    Returns:
        The outcome.

    Raises:
        ValueError: The `veaf` server's `env` is not a JSON object.
        sqlite3.Error: The database could not be read or written.
        OSError: The backup could not be written.
    """
    client = "Cherry Studio"
    con = sqlite3.connect(db, timeout=10, isolation_level=None)
    try:
        con.execute("PRAGMA foreign_keys = ON")
        tables = ["mcp_server", "assistant_mcp_server"] + (["assistant"] if assistants else [])
        gap = _check_cherry_tables(con, tables)
        if gap:
            table, how, gap_columns = gap
            version_log = user_data / "version.log"
            found = version_log.read_text(encoding="utf-8", errors="replace").strip() if version_log.is_file() else "?"
            return ClientResult(
                client,
                "failed",
                f"{db}: table {table}, {how} columns {gap_columns}. "
                f"This Cherry Studio ({found}) stores its servers differently from the version "
                f"ai-setup knows ({CHERRY_TESTED_VERSION}): declare the server by hand",
            )
        select = "SELECT id, command, args, env, type, is_active FROM mcp_server WHERE name = ?"
        rows = con.execute(select, (CHERRY_SERVER_NAME,)).fetchall()
        if len(rows) > 1:
            return ClientResult(
                client, "failed", f"{db}: {len(rows)} servers are named '{CHERRY_SERVER_NAME}': keep one in Cherry"
            )
        command, args = str(exe), _compact_json(["mcp"])
        env = _compact_json(_cherry_env(rows[0][3] if rows else None))
        server_id = rows[0][0] if rows else str(uuid.uuid4())
        # An inactive or non-stdio server (one imported through Cherry's link, say) would never start: repaired too.
        up_to_date = bool(rows) and rows[0][1:] == (command, args, env, "stdio", 1)

        links: list[str] = []
        unknown: list[str] = []
        for name in assistants:
            ids = [r[0] for r in con.execute("SELECT id FROM assistant WHERE name = ? AND deleted_at IS NULL", (name,))]
            if not ids:
                unknown.append(name)
            links += [
                i
                for i in ids
                if not con.execute(
                    "SELECT 1 FROM assistant_mcp_server WHERE assistant_id = ? AND mcp_server_id = ?", (i, server_id)
                ).fetchone()
            ]
        detail = str(db) + (f" (assistants not found: {', '.join(unknown)})" if unknown else "")
        if up_to_date and not links:
            return ClientResult(client, "configured", detail)

        stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(now_ms / 1000)) + f"-{now_ms % 1000:03d}"
        backup = db.with_name(f"{db.name}.veaf-backup-{stamp}")
        target = sqlite3.connect(backup)
        try:
            con.backup(target)  # reads the -wal too: one self-contained copy
        finally:
            target.close()

        # sqlite3's backup() never ends from inside a transaction (measured, Python 3.13): the write lock is
        # taken after it, and what the write relies on is read again under it.
        con.execute("BEGIN IMMEDIATE")
        if con.execute(select, (CHERRY_SERVER_NAME,)).fetchall() != rows:
            return ClientResult(
                client, "failed", f"{db} changed while ai-setup ran: close Cherry Studio, then run again"
            )
        if rows:
            con.execute(
                "UPDATE mcp_server SET command = ?, args = ?, env = ?, type = 'stdio', is_active = 1, updated_at = ?"
                " WHERE id = ?",
                (command, args, env, now_ms, server_id),
            )
        else:
            con.execute(
                "INSERT INTO mcp_server (id, name, type, command, args, env, is_active, install_source,"
                " is_trusted, trusted_at, installed_at, created_at, updated_at)"
                " VALUES (?, ?, 'stdio', ?, ?, ?, 1, 'manual', 1, ?, ?, ?, ?)",
                (server_id, CHERRY_SERVER_NAME, command, args, env, now_ms, now_ms, now_ms, now_ms),
            )
        con.executemany(
            "INSERT OR IGNORE INTO assistant_mcp_server (assistant_id, mcp_server_id, created_at, updated_at)"
            " VALUES (?, ?, ?, ?)",
            [(i, server_id, now_ms, now_ms) for i in links],
        )
        con.execute("COMMIT")
        return ClientResult(client, "configured", f"{detail}, backup {backup.name}")
    finally:
        if con.in_transaction:
            con.execute("ROLLBACK")  # a refusal, a no-op run or an error: nothing is written
        con.close()


def setup_all(
    exe: Path,
    *,
    home: Path,
    appdata: Path,
    localappdata: Path,
    cherry_assistants: Sequence[str] = (),
    cherry_data_dir: Path | None = None,
) -> list[ClientResult]:
    """Declare the server in every supported client.

    Args:
        exe: The `veaf-tools` executable that runs the server.
        home: The user's home folder.
        appdata: The user's `%APPDATA%` folder.
        localappdata: The user's `%LOCALAPPDATA%` folder.
        cherry_assistants: Cherry Studio assistants to link to the server (`--cherry-assistant`).
        cherry_data_dir: Cherry Studio's data folder, when not the default one (`--cherry-data-dir`).

    Returns:
        One result per client, in a fixed order.
    """
    return [
        setup_claude_desktop(exe, appdata=appdata, localappdata=localappdata),
        setup_claude_code(exe, home=home),
        setup_gemini(exe, home=home),
        setup_antigravity(exe, home=home),
        setup_codex(exe, home=home),
        setup_opencode(exe, home=home),
        setup_cherry(exe, appdata=appdata, home=home, assistants=cherry_assistants, data_dir=cherry_data_dir),
    ]
