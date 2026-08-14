"""Shared readers for the quirks of a parsed DCS mission table.

Extracted when a third action needed them, on the lesson `REFACTOR-MARKER-PARSER` paid for: copied
code receives half the fixes. Three quirks, each of which has already produced a bug somewhere:

- **A 1-based Lua table arrives as a dict or as a list**, depending on whether its keys happened to
  be contiguous — the parser flattens the contiguous case. A reader that handles only one shape is
  right about half the time and silently wrong the rest, which is exactly how `describe_units` came
  to document its pylon numbering so loudly.
- **Numeric keys sort as numbers, not as strings**, or waypoint 10 lands between 1 and 2.
- **Finding a group means saying what exists when it misses**, so a calling agent can retry without
  re-reading the whole mission.
"""

from typing import Any

# The three quirk readers moved to `veaf_libs.mission_table` when the mission validator needed
# them too: the dependency runs MCP -> veaf_libs, and a second copy would receive half the fixes.
# Re-exported here so every existing import keeps working.
from veaf_libs.mission_table import CATEGORIES, indexed, numeric_first  # noqa: E402

__all__ = ["CATEGORIES", "find_group", "group_names", "indexed", "listed", "numeric_first"]


def listed(names: list[str], limit: int = 20) -> str:
    """Render `names` for an error message, capped so a Foothold-sized mission stays readable.

    Args:
        names: The names to list.
        limit: How many to show before summarising the count.

    Returns:
        A quoted, comma-separated list, or ``none``.
    """
    if not names:
        return "none"
    shown = ", ".join(repr(name) for name in names[:limit])
    return shown if len(names) <= limit else f"{shown}, ... ({len(names)} total)"


def group_names(mission_content: dict[str, Any]) -> list[str]:
    """Return every group name in the mission, in table order.

    Args:
        mission_content: The parsed ``mission`` table.

    Returns:
        The names, including duplicates if the mission holds any.
    """
    names: list[str] = []
    for coalition in (mission_content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if isinstance(group, dict):
                        names.append(str(group.get("name", "")))
    return names


def find_group(mission_content: dict[str, Any], group_name: str) -> dict[str, Any]:
    """Return the group named `group_name`, or raise naming what exists.

    The group's own dict is returned, so a caller mutates the mission rather than a copy. The name
    must match **exactly**: `describe_units` filters on a fragment, but an edit landing on whichever
    group matched first is not recoverable.

    Args:
        mission_content: The parsed ``mission`` table.
        group_name: The exact group name to find.

    Returns:
        The group table.

    Raises:
        ValueError: If no group carries that exact name.
    """
    for coalition in (mission_content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if isinstance(group, dict) and str(group.get("name", "")) == group_name:
                        return group
    raise ValueError(
        f"No group named {group_name!r} in this mission. Groups present: {listed(group_names(mission_content))}"
    )
