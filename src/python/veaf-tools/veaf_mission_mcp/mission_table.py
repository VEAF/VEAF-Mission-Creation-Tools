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

#: Group categories a mission table may hold, in the order DCS writes them.
CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")


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


def numeric_first(key: Any) -> tuple[int, float, str]:
    """Sort key ordering numeric table keys numerically, before any non-numeric ones.

    Args:
        key: A table key.

    Returns:
        A sort tuple placing numeric keys first, in numeric order.
    """
    try:
        return (0, float(key), "")
    except (TypeError, ValueError):
        return (1, 0.0, str(key))


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
