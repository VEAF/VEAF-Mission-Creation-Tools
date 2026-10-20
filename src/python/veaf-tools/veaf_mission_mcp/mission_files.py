"""`read_mission_file` / `edit_mission_file` — a mission folder's YAML sources, for an AI with no file access.

An assistant in Claude Desktop's chat mode has the MCP actions and nothing else: asked to rename a
mission, it answered that no action could, and the authoring guide's checklist asks it to adapt four
`src/*.yaml` files it could not open either (FEAT-AI-ZERO-SETUP). These two actions give it the
folder's YAML sources, and only those: `mission.yaml` and `src/*.yaml`. An edit replaces one exact
passage, backed up first, and is refused when the file would no longer read as YAML.
"""

from pathlib import Path, PurePosixPath
from typing import Any

import yaml
from mission_tools.miz_backup import backup_before_write

from veaf_mission_mcp.mission_folder import mission_yaml_path

#: Lines a read returns by default: a whole `mission.yaml`, a slice of the 11 000-line slot catalogue.
DEFAULT_LINE_COUNT = 400

_REACHABLE = "only mission.yaml and the src/*.yaml files of the mission folder are reachable"


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
    relative = PurePosixPath(file.replace("\\", "/"))
    parts = relative.parts
    allowed = parts == ("mission.yaml",) or (
        len(parts) == 2 and parts[0] == "src" and relative.suffix in (".yaml", ".yml")
    )
    if relative.is_absolute() or Path(file).is_absolute() or ".." in parts or not allowed:
        raise ValueError(f"{file!r}: {_REACHABLE}")
    path = folder.joinpath(*parts)
    if not path.is_file():
        raise FileNotFoundError(f"{file!r} does not exist in the mission folder {folder}")
    return path


def read_mission_file(
    folder: Path, file: str, *, start_line: int = 1, line_count: int = DEFAULT_LINE_COUNT
) -> dict[str, Any]:
    """Read a slice of one of the mission folder's YAML sources.

    Args:
        folder: The mission folder.
        file: `mission.yaml` or `src/<name>.yaml`.
        start_line: The first line to return, 1-based.
        line_count: How many lines to return at most.

    Returns:
        `{"file", "first_line", "last_line", "total_lines", "content"}`; read on from `last_line + 1`
        while it is below `total_lines`.

    Raises:
        FileNotFoundError: No such mission folder or file.
        ValueError: A file outside the reachable set, or a start line or count below 1.
    """
    if start_line < 1 or line_count < 1:
        raise ValueError("start_line and line_count must be 1 or more")
    path = _resolve(folder, file)
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    chunk = lines[start_line - 1 : start_line - 1 + line_count]
    return {
        "file": file,
        "first_line": start_line,
        "last_line": start_line - 1 + len(chunk),
        "total_lines": len(lines),
        "content": "".join(chunk),
    }


def edit_mission_file(folder: Path, file: str, *, search: str, replace: str) -> dict[str, Any]:
    """Replace one exact passage of one of the mission folder's YAML sources.

    The passage must occur exactly once — enough of the surrounding lines to make it unique — and
    the result must still read as YAML; otherwise nothing is written.

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
        text = handle.read()
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
        handle.write(edited)
    return {"file": file, "backup": str(backup)}
