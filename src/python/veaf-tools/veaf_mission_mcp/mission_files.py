"""`read_mission_file` / `edit_mission_file` — a mission folder's YAML sources, for an AI with no file access.

An assistant in Claude Desktop's chat mode has the MCP actions and nothing else: asked to rename a
mission, it answered that no action could, and the authoring guide's checklist asks it to adapt four
`src/*.yaml` files it could not open either (FEAT-AI-ZERO-SETUP). These two actions give it the
folder's YAML sources, and only those: `mission.yaml` and `src/*.yaml`. An edit replaces one exact
passage, backed up first, and is refused when the file would no longer read as YAML.

Both work on `\n` line ends whatever the file holds: a CRLF file read back with `\r\n` was copied back
with `\n`, and its multi-line passages were never found (FIX-OPENCODE-TEST-FINDINGS 02). An edit
writes the file's own line end back.
"""

import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any

import yaml
from mission_tools.miz_backup import backup_before_write
from veaf_libs.shipped_defaults import resolve_defaults_source

from veaf_mission_mcp.mission_folder import mission_yaml_path

#: Lines a read returns by default: a whole `mission.yaml`, a slice of the 11 000-line slot catalogue.
DEFAULT_LINE_COUNT = 400

_REACHABLE = "only mission.yaml and the src/*.yaml files of the mission folder are reachable"

#: A `src/` file name the actions accept: no drive, no separator, no `..`.
_SAFE_YAML_NAME = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9_.-]*\.ya?ml")


def _resolve(folder: Path, file: str) -> Path:
    """Return the path of `file` inside the mission folder, or refuse it.

    Args:
        folder: The mission folder.
        file: A path relative to it, `/` or `\\` separated.

    Returns:
        The file's path.

    Raises:
        FileNotFoundError: The folder has no `mission.yaml`.
        ValueError: `file` is absolute, climbs out, or is not `mission.yaml` or a `src/*.yaml`.
    """
    mission_yaml_path(folder)
    parts = PurePosixPath(file.replace("\\", "/")).parts
    # A strict name, so no drive (`C:x.yaml`), no `..`, no separator survives into the join; then the
    # resolved path must still sit where it was aimed, so a symbolic link cannot lead out.
    allowed = parts == ("mission.yaml",) or (
        len(parts) == 2 and parts[0] == "src" and _SAFE_YAML_NAME.fullmatch(parts[1]) is not None
    )
    if not allowed:
        raise ValueError(f"{file!r}: {_REACHABLE}")
    root = folder.resolve()
    path = root.joinpath(*parts).resolve()
    expected_parent = root if parts == ("mission.yaml",) else root / "src"
    if path.parent != expected_parent:
        raise ValueError(f"{file!r}: {_REACHABLE}")
    if not path.is_file():
        raise FileNotFoundError(f"{file!r} does not exist in the mission folder {folder}")
    return path


def _shipped_scaffold() -> Path:
    """Return the mission-folder scaffold shipped with the tools: the one `scaffold_mission` copies.

    Beside the installed executable, the updater puts it under `published/`; from a checkout, the
    repository's own.

    Raises:
        FileNotFoundError: Neither exists.
    """
    source = resolve_defaults_source(Path(sys.executable).parent)
    if source is None:
        raise FileNotFoundError("the scaffold shipped with the tools is not installed: run the updater")
    return source


def read_mission_file(
    folder: Path | None, file: str, *, start_line: int = 1, line_count: int = DEFAULT_LINE_COUNT
) -> dict[str, Any]:
    """Read a slice of one of the mission folder's YAML sources.

    Args:
        folder: The mission folder; None reads the scaffold shipped with the tools — the shipped
            dynamic-slot templates, presets plan, `mission.yaml` with its commented module examples —
            which the AI dug out of the exe's own files before a folder existed
            (FIX-OPENCODE-TEST-FINDINGS 03).
        file: `mission.yaml` or `src/<name>.yaml`.
        start_line: The first line to return, 1-based.
        line_count: How many lines to return at most.

    Returns:
        `{"file", "first_line", "last_line", "total_lines", "content"}`, with `\n` line ends whatever the
        file uses, and `"shipped": True` for the shipped scaffold; read on from `last_line + 1` while it
        is below `total_lines`.

    Raises:
        FileNotFoundError: No such mission folder or file.
        ValueError: A file outside the reachable set, or a start line or count below 1.
    """
    if start_line < 1 or line_count < 1:
        raise ValueError("start_line and line_count must be 1 or more")
    shipped = folder is None
    path = _resolve(_shipped_scaffold() if folder is None else folder, file)
    # Line feeds only: `splitlines` also breaks on form feeds and U+2028, and the slices would drift
    # from the lines an editor shows.
    with path.open(encoding="utf-8", newline="") as handle:
        lines = handle.read().replace("\r\n", "\n").split("\n")
    lines = [line + "\n" for line in lines[:-1]] + ([lines[-1]] if lines[-1] else [])
    chunk = lines[start_line - 1 : start_line - 1 + line_count]
    result: dict[str, Any] = {
        "file": file,
        "first_line": start_line,
        "last_line": start_line - 1 + len(chunk),
        "total_lines": len(lines),
        "content": "".join(chunk),
    }
    if shipped:
        result["shipped"] = True
    return result


def edit_mission_file(folder: Path, file: str, *, search: str, replace: str) -> dict[str, Any]:
    """Replace one exact passage of one of the mission folder's YAML sources.

    The passage must occur exactly once — enough of the surrounding lines to make it unique — and
    the result must still read as YAML; otherwise nothing is written. Line ends are compared
    normalised, and the file keeps its own: CRLF when it has any, LF otherwise.

    Args:
        folder: The mission folder.
        file: `mission.yaml` or `src/<name>.yaml`.
        search: The exact text to replace, line breaks and indentation included.
        replace: Its replacement.

    Returns:
        `{"file", "backup"}`, the backup taken before the write.

    Raises:
        FileNotFoundError: No such mission folder or file.
        ValueError: A file outside the reachable set, a passage found zero or several times, or a
            result that is no longer YAML.
    """
    path = _resolve(folder, file)
    with path.open(encoding="utf-8", newline="") as handle:
        raw = handle.read()
    line_end = "\r\n" if "\r\n" in raw else "\n"
    text = raw.replace("\r\n", "\n")
    search, replace = search.replace("\r\n", "\n"), replace.replace("\r\n", "\n")
    count = text.count(search) if search else 0
    if count == 0:
        raise ValueError(f"passage not found in {file!r}: read it first, and copy it exactly")
    if count > 1:
        raise ValueError(f"passage found {count} times in {file!r}: include surrounding lines to make it unique")
    edited = text.replace(search, replace, 1)
    try:
        yaml.safe_load(edited)
    except yaml.YAMLError as e:
        raise ValueError(f"the edit leaves {file!r} unreadable as YAML, nothing written: {e}") from e
    backup = backup_before_write(path)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(edited.replace("\n", line_end))
    return {"file": file, "backup": str(backup)}
