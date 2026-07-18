"""`replace_in_mission_files` — generic text/regex search-replace in a mission's embedded Lua.

Edits the **text** of the Lua files embedded in a `.miz` (the third action family: neither
the raw `mission.lua` tables nor the `mission.yaml` pipeline). Restricted to
`l10n/DEFAULT/**/*.lua` — a text replacement can't corrupt the `mission`/`options` tables or
binary resources. Backed up first; rewrites only the changed members verbatim.
"""

import fnmatch
import re
from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import list_members, read_member, rewrite_miz_members

_EMBEDDED_LUA_PREFIX = "l10n/DEFAULT/"


def replace_in_mission_files(
    miz_path: Path,
    *,
    search: str,
    replace: str,
    files: str = "*.lua",
    regex: bool = False,
) -> dict[str, Any]:
    """Search-and-replace across a mission's embedded `l10n/DEFAULT/**/*.lua` files.

    Args:
        miz_path: Path to the mission's source `.miz`.
        search: The text (or, if `regex`, the pattern) to find.
        replace: The replacement text (a regex backreference like `\\1` when `regex`).
        files: A glob matched against each candidate's path **relative to** `l10n/DEFAULT/`
            (e.g. `"*.lua"`, `"veaf-*.lua"`, `"scripts/*.lua"`). Only `.lua` members are ever
            eligible, whatever the glob.
        regex: If true, `search` is a Python regular expression (`re.sub`); otherwise a plain
            substring (`str.replace`).

    Returns:
        `{"files_changed": [<arcname>, ...], "total_replacements": <int>}`.

    Raises:
        ValueError: If the archive is not a valid mission, or `regex` and the pattern is invalid.
    """
    if "mission" not in list_members(miz_path):
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    pattern = _compile(search) if regex else None

    replacements: dict[str, bytes] = {}
    files_changed: list[str] = []
    total = 0
    for arcname in _candidate_files(miz_path, files):
        text = read_member(miz_path, arcname).decode("utf-8")
        if regex:
            new_text, count = pattern.subn(replace, text)  # type: ignore[union-attr]
        else:
            count = text.count(search)
            new_text = text.replace(search, replace)
        if count:
            replacements[arcname] = new_text.encode("utf-8")
            files_changed.append(arcname)
            total += count

    if replacements:
        backup_before_write(miz_path)
        rewrite_miz_members(miz_path, replacements)

    return {"files_changed": files_changed, "total_replacements": total}


def _compile(pattern: str) -> re.Pattern[str]:
    try:
        return re.compile(pattern)
    except re.error as exc:
        raise ValueError(f"Invalid regular expression: {exc}") from exc


def _candidate_files(miz_path: Path, files: str) -> list[str]:
    """Return embedded `l10n/DEFAULT/**/*.lua` members whose relative path matches `files`."""
    candidates: list[str] = []
    for arcname in list_members(miz_path):
        if not arcname.startswith(_EMBEDDED_LUA_PREFIX) or not arcname.endswith(".lua"):
            continue
        relative = arcname[len(_EMBEDDED_LUA_PREFIX) :]
        if fnmatch.fnmatch(relative, files):
            candidates.append(arcname)
    return candidates
