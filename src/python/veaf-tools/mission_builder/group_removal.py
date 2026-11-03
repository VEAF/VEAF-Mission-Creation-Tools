"""Remove Mission Editor groups from a mission table at build time (FEAT-ROLE-TRAINING-VARIANTS 02).

A build profile changes configuration only, so no profile could take an AI flight placed in the
Mission Editor, or a SAM placed by hand, out of its `.miz`. ``remove_groups:`` in a profile names the
groups to take out, by exact name or by ``fnmatch`` pattern (``"SA-10 *"``), whatever they are: a
group placed by hand, a ``#veafInterpreter`` carrier, a combat zone's member, a static.

The container a removal empties is dropped rather than left as ``group = {}``, as
``veaf_mission_mcp.remove_group`` does: the rest of the build reads either shape, the Mission Editor
writes the dropped one.
"""

from __future__ import annotations

import fnmatch
from collections.abc import Iterable
from typing import Any

from veaf_libs.mission_table import CATEGORIES, indexed


def matches_any(name: str, patterns: Iterable[str]) -> bool:
    """Whether a group name matches one of the patterns.

    Args:
        name: The group name.
        patterns: Exact names or ``fnmatch`` patterns, matched case-sensitively as DCS names are.

    Returns:
        True when one pattern matches.
    """
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in patterns)


def iter_group_slots(mission_content: dict[str, Any]) -> Iterable[tuple[str, dict[str, Any], str, dict[str, Any]]]:
    """Yield every group of the mission with where it lives.

    The containers are normalised to lists on the way, so a caller may mutate them.

    Args:
        mission_content: The parsed DCS ``mission`` table.

    Yields:
        ``(side, country, category, group)`` for each group dict.
    """
    for side, coalition in (mission_content.get("coalition") or {}).items():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                container = country.get(category)
                if not isinstance(container, dict):
                    continue
                for group in indexed(container.get("group")):
                    if isinstance(group, dict):
                        yield side, country, category, group


def group_names(mission_content: dict[str, Any]) -> list[str]:
    """Every group name of the mission, in table order.

    Args:
        mission_content: The parsed DCS ``mission`` table.

    Returns:
        The names; a group without one is skipped.
    """
    return [str(group["name"]) for _, _, _, group in iter_group_slots(mission_content) if group.get("name")]


def remove_groups(mission_content: dict[str, Any], patterns: Iterable[str]) -> tuple[list[str], list[str]]:
    """Remove every group whose name matches one of the patterns, in place.

    Args:
        mission_content: The parsed DCS ``mission`` table (mutated).
        patterns: Exact group names or ``fnmatch`` patterns.

    Returns:
        ``(removed, unmatched)``: the names removed, in table order, and the patterns that matched
        no group.
    """
    wanted = [str(pattern) for pattern in patterns if pattern]
    removed: list[str] = []
    used: set[str] = set()
    for coalition in (mission_content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                container = country.get(category)
                if not isinstance(container, dict):
                    continue
                kept = []
                for group in indexed(container.get("group")):
                    name = str(group.get("name", "")) if isinstance(group, dict) else ""
                    hits = [pattern for pattern in wanted if name and fnmatch.fnmatchcase(name, pattern)]
                    if hits:
                        removed.append(name)
                        used.update(hits)
                    else:
                        kept.append(group)
                if len(kept) == len(indexed(container.get("group"))):
                    continue  # nothing removed here: leave the container exactly as it was
                if kept:
                    container["group"] = kept
                else:
                    del country[category]
    return removed, [pattern for pattern in wanted if pattern not in used]
