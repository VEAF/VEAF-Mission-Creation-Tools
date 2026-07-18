"""VEAF spawn-shortcut (``#command`` alias) scanner.

The high-level VEAF spawn shortcuts — ``-samLR``, ``-samSR``, ``-armor``, the random
convoys, ``-arty1``… — are declared only in ``veafShortcuts.buildDefaultList()``. Unlike
the ``veafUnits`` unit/group aliases (which have a hand-maintained ``veaf-units.yaml``),
these have no data file, so the oracle cannot see them. This scanner exposes them, from
three sources tried in order (mirroring :mod:`veaf_libs.lua_module_scanner`):

1. A JSON file bundled inside a PyInstaller executable (``sys._MEIPASS``).
2. A pre-generated ``veaf-shortcuts.json`` sitting next to this module.
3. A live scan of ``src/scripts/veaf/veafShortcuts.lua`` (development mode).

Use :func:`generate_shortcuts_json` from the build to produce the JSON that is then
bundled with PyInstaller (``--add-data``).
"""

from __future__ import annotations

import json
import re
import sys
from functools import lru_cache
from pathlib import Path
from typing import TypedDict

_BUNDLED_JSON_NAME = "veaf-shortcuts.json"
_LUA_FILE_SUBPATH = Path("src") / "scripts" / "veaf" / "veafShortcuts.lua"

# Each `veafShortcuts.AddAlias(...)` call declares one alias; the builder is fluent, so
# fields may sit on one line or several. Anchor on the AddAlias( call and pull fields by name.
_ALIAS_SPLIT_RE = re.compile(r"veafShortcuts\.AddAlias\s*\(")
_NAME_RE = re.compile(r':setName\(\s*"([^"]+)"')
_DESC_RE = re.compile(r':setDescription\(\s*"([^"]*)"')
_CMD_RE = re.compile(r':setVeafCommand\(\s*"([^"]*)"')
_HIDDEN_RE = re.compile(r":setHidden\(\s*true\s*\)")


class ShortcutAlias(TypedDict):
    aliases: list[str]  # the marker name(s), leading '-' kept (e.g. "-samLR")
    description: str
    veafCommand: str  # the `_spawn …` command it runs; "" for batch aliases


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _bundled_json_path() -> Path | None:
    """Return the path to the JSON bundled inside a PyInstaller exe, or None."""
    if hasattr(sys, "_MEIPASS"):
        candidate = Path(sys._MEIPASS) / _BUNDLED_JSON_NAME  # type: ignore[attr-defined]
        if candidate.exists():
            return candidate
    return None


def _pregenerated_json_path() -> Path | None:
    """Return the path to a pre-generated JSON next to this module, or None."""
    candidate = Path(__file__).parent / _BUNDLED_JSON_NAME
    return candidate if candidate.exists() else None


def _find_shortcuts_lua() -> Path | None:
    """Walk up the directory tree to locate ``src/scripts/veaf/veafShortcuts.lua``."""
    candidate = Path(__file__).parent
    for _ in range(12):
        lua_file = candidate / _LUA_FILE_SUBPATH
        if lua_file.is_file():
            return lua_file
        candidate = candidate.parent
    return None


def _build_default_list_body(content: str) -> str:
    """Return the source of ``buildDefaultList()`` only (aliases elsewhere are out of scope)."""
    start = content.find("function veafShortcuts.buildDefaultList()")
    if start == -1:
        return ""
    # End at the next top-level `function veafShortcuts.` declaration after the body starts.
    next_fn = content.find("\nfunction veafShortcuts.", start + 1)
    return content[start:next_fn] if next_fn != -1 else content[start:]


def _parse_aliases(content: str) -> list[ShortcutAlias]:
    """Parse the visible ``buildDefaultList()`` aliases from Lua *content*.

    Hidden aliases (``:setHidden(true)``) are excluded — they are internal (auth, debug)
    and not meant to be typed by a mission maker.
    """
    body = _build_default_list_body(content)
    if not body:
        return []

    aliases: list[ShortcutAlias] = []
    segments = _ALIAS_SPLIT_RE.split(body)
    for segment in segments[1:]:  # segments[0] is the text before the first AddAlias(
        name_match = _NAME_RE.search(segment)
        if not name_match:
            continue
        if _HIDDEN_RE.search(segment):
            continue
        desc_match = _DESC_RE.search(segment)
        cmd_match = _CMD_RE.search(segment)
        aliases.append(
            ShortcutAlias(
                aliases=[name_match.group(1)],
                description=desc_match.group(1) if desc_match else "",
                veafCommand=cmd_match.group(1) if cmd_match else "",
            )
        )
    return aliases


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


@lru_cache(maxsize=1)
def get_shortcuts() -> list[ShortcutAlias]:
    """Return the list of VEAF spawn shortcuts (the ``#command`` aliases).

    Sources tried in order: bundled JSON (PyInstaller) → pre-generated JSON → live
    scan of ``veafShortcuts.lua``. Cached: the source is immutable for a process run,
    so the file is read/parsed once (the oracle calls this on every ``list_shortcuts``).
    """
    path = _bundled_json_path() or _pregenerated_json_path()
    if path:
        return json.loads(path.read_text(encoding="utf-8"))

    lua_file = _find_shortcuts_lua()
    if lua_file:
        return _parse_aliases(lua_file.read_text(encoding="utf-8", errors="ignore"))

    return []


def generate_shortcuts_json(output_path: Path, lua_file: Path) -> int:
    """Scan *lua_file* and write the shortcut list to *output_path* as JSON.

    Called by the build before PyInstaller compilation so the JSON can be bundled with
    ``--add-data``.

    Returns:
        Number of aliases written.
    """
    aliases = _parse_aliases(lua_file.read_text(encoding="utf-8", errors="ignore")) if lua_file.is_file() else []
    output_path.write_text(json.dumps(aliases, indent=2, ensure_ascii=False), encoding="utf-8")
    return len(aliases)
