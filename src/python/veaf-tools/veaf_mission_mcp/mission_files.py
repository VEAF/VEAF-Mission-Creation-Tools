"""`read_mission_file` / `edit_mission_file` — a mission folder's YAML sources, for an AI with no file access.

An assistant in Claude Desktop's chat mode has the MCP actions and nothing else: asked to rename a
mission, it answered that no action could, and the authoring guide's checklist asks it to adapt four
`src/*.yaml` files it could not open either (FEAT-AI-ZERO-SETUP). These two actions give it the
folder's YAML sources, and only those: `mission.yaml` and `src/*.yaml`. An edit replaces one exact
passage, backed up first, and is refused when the file would no longer read as YAML.

A campaign folder — `campaign.yaml` and no `mission.yaml` — gives `campaign.yaml` and `briefing.yaml`
instead: without them an AI could start a campaign from the shipped example and never rewrite it
(FEAT-PERSISTENT-CAMPAIGN-AI). An edit with an empty passage creates a reachable file not there yet.

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
_CAMPAIGN_REACHABLE = "only campaign.yaml and briefing.yaml of the campaign folder are reachable"

#: The files of a campaign folder the actions reach.
_CAMPAIGN_FILES = (("campaign.yaml",), ("briefing.yaml",))

#: A `src/` file name the actions accept: no drive, no separator, no `..`.
_SAFE_YAML_NAME = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9_.-]*\.ya?ml")


def _is_campaign_folder(folder: Path) -> bool:
    """A campaign folder holds `campaign.yaml` and no `mission.yaml`."""
    return (folder / "campaign.yaml").is_file() and not (folder / "mission.yaml").is_file()


def _resolve(folder: Path, file: str, *, must_exist: bool = True) -> Path:
    """Return the path of `file` inside the mission or campaign folder, or refuse it.

    Args:
        folder: The mission folder, or a campaign folder.
        file: A path relative to it, `/` or `\\` separated.
        must_exist: Refuse a file that is not there yet.

    Returns:
        The file's path.

    Raises:
        FileNotFoundError: The folder is neither a mission folder nor a campaign folder, or the file
            does not exist and `must_exist` is set.
        ValueError: `file` is absolute, climbs out, or is not `mission.yaml` or a `src/*.yaml` — in a
            campaign folder, not `campaign.yaml` or `briefing.yaml`.
    """
    parts = PurePosixPath(file.replace("\\", "/")).parts
    if _is_campaign_folder(folder):
        allowed, reachable = parts in _CAMPAIGN_FILES, _CAMPAIGN_REACHABLE
    else:
        mission_yaml_path(folder)
        # A strict name, so no drive (`C:x.yaml`), no `..`, no separator survives into the join; then the
        # resolved path must still sit where it was aimed, so a symbolic link cannot lead out.
        allowed = parts == ("mission.yaml",) or (
            len(parts) == 2 and parts[0] == "src" and _SAFE_YAML_NAME.fullmatch(parts[1]) is not None
        )
        reachable = _REACHABLE
    if not allowed:
        raise ValueError(f"{file!r}: {reachable}")
    root = folder.resolve()
    path = root.joinpath(*parts).resolve()
    expected_parent = root if len(parts) == 1 else root / "src"
    if path.parent != expected_parent:
        raise ValueError(f"{file!r}: {reachable}")
    if must_exist and not path.is_file():
        raise FileNotFoundError(f"{file!r} does not exist in the folder {folder}")
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
    """Replace one exact passage of one of the mission folder's YAML sources, or create one.

    The passage must occur exactly once — enough of the surrounding lines to make it unique — and
    the result must still read as YAML; otherwise nothing is written. Line ends are compared
    normalised, and the file keeps its own: CRLF when it has any, LF otherwise. An empty passage
    creates a reachable file that is not there yet, `replace` its content; it never touches one that is.

    Args:
        folder: The mission folder, or a campaign folder.
        file: `mission.yaml` or `src/<name>.yaml`; `campaign.yaml` or `briefing.yaml` in a campaign
            folder.
        search: The exact text to replace, line breaks and indentation included; empty to create the file.
        replace: Its replacement, or the new file's content.

    Returns:
        `{"file", "backup"}`, the backup taken before the write; `{"file", "created": True}` for a file
        created.

    Raises:
        FileNotFoundError: No such folder, or no such file with a passage to replace.
        ValueError: A file outside the reachable set, a passage found zero or several times, or a
            result that is no longer YAML.
    """
    path = _resolve(folder, file, must_exist=bool(search))
    search, replace = search.replace("\r\n", "\n"), replace.replace("\r\n", "\n")
    if not search and not path.exists():
        _check_yaml(file, replace)
        path.parent.mkdir(exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as handle:
            handle.write(replace)
        return {"file": file, "created": True}
    with path.open(encoding="utf-8", newline="") as handle:
        raw = handle.read()
    line_end = "\r\n" if "\r\n" in raw else "\n"
    text = raw.replace("\r\n", "\n")
    count = text.count(search) if search else 0
    if count == 0:
        raise ValueError(f"passage not found in {file!r}: read it first, and copy it exactly")
    if count > 1:
        raise ValueError(f"passage found {count} times in {file!r}: include surrounding lines to make it unique")
    edited = text.replace(search, replace, 1)
    _check_yaml(file, edited)
    backup = backup_before_write(path)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(edited.replace("\n", line_end))
    return {"file": file, "backup": str(backup)}


def _check_yaml(file: str, text: str) -> None:
    """Refuse a text that does not read as YAML, before anything is written.

    Raises:
        ValueError: `text` is not YAML.
    """
    try:
        yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise ValueError(f"the edit leaves {file!r} unreadable as YAML, nothing written: {e}") from e
