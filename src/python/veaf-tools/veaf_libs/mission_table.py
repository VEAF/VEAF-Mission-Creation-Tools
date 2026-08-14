"""Readers for the quirks of a parsed DCS mission table.

Lives in ``veaf_libs`` rather than in the MCP because both layers read the same table and the
dependency runs MCP → veaf_libs: the validator needs these quirks as much as the editor actions do,
and a second copy would receive half the fixes (the lesson `REFACTOR-MARKER-PARSER` paid for).
``veaf_mission_mcp.mission_table`` re-exports them, so existing imports keep working.

The quirk that matters most here: **a 1-based Lua table arrives as a dict or as a list**, depending on
whether its keys happened to be contiguous — the parser flattens the contiguous case. A reader
handling only one shape is right about half the time and silently wrong the rest.
"""

from typing import Any

#: Group categories a mission table may hold, in the order DCS writes them.
CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")


def numeric_first(key: Any) -> tuple[int, float, str]:
    """Sort key ordering numeric table keys as numbers, then everything else as text.

    Waypoint 10 lands between 1 and 2 under a plain string sort, which is a route silently reordered.

    Args:
        key: A raw table key.

    Returns:
        A tuple ordering numbers before strings.
    """
    try:
        return (0, float(key), "")
    except (TypeError, ValueError):
        return (1, 0.0, str(key))


def indexed(container: Any) -> list[Any]:
    """Return a DCS 1-based table's values in key order, whether it arrived as a dict or a list.

    Args:
        container: The raw value, of whatever shape the Lua parser produced.

    Returns:
        The entries in table order (empty when there are none).
    """
    if isinstance(container, dict):
        return [container[key] for key in sorted(container, key=numeric_first)]
    if isinstance(container, list):
        return list(container)
    return []
