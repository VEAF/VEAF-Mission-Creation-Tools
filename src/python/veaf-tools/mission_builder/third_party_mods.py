"""Strip third-party aircraft mod requirements from a mission's ``requiredModules``.

DCS refuses to load a ``.miz`` if any mod listed in the mission table's
``requiredModules`` is missing from the player's install. For third-party (paid or
community) aircraft, VEAF wants the mission to load anyway — the pilot without the mod
just can't take that slot. This strips selected mod ids from ``requiredModules`` at
build time, driven by a bundled VEAF default list unioned with the per-mission
``mission.third_party_mods`` field.

Ported from the v5 per-mission ``build.cmd`` hack (a hardcoded block of
``replace.ps1`` calls, one per mod).
"""

from __future__ import annotations

import functools
import json
from collections.abc import Iterable

from veaf_libs.bundled_data import read_bundled_text


@functools.lru_cache(maxsize=1)
def default_third_party_mods() -> frozenset[str]:
    """Return (and cache) the bundled VEAF default list of third-party mod ids."""
    data = json.loads(read_bundled_text("mission_builder", "data", "third_party_mods.json"))
    return frozenset(data["mods"])


def strip_third_party_mods(mission_content: dict, extra_mods: Iterable[str] | None = None) -> list[str]:
    """Remove third-party mod requirements from a mission's ``requiredModules``.

    Removes every id in ``default_third_party_mods() ∪ extra_mods`` from
    ``mission_content["requiredModules"]`` (a ``{modId: modName}`` dict), in place.

    Args:
        mission_content: The parsed DCS ``mission`` table (mutated in place).
        extra_mods: Per-mission mod ids to strip on top of the VEAF default list
            (from ``mission.third_party_mods``). Unioned with the default, never
            replacing it.

    Returns:
        The mod ids actually removed, sorted — for the build log. Empty when
        ``requiredModules`` is absent, not a dict, or holds none of the ids.
    """
    required = mission_content.get("requiredModules")
    if not isinstance(required, dict):
        return []
    to_strip = default_third_party_mods() | set(extra_mods or [])
    removed = sorted(mod for mod in to_strip if mod in required)
    for mod in removed:
        del required[mod]
    return removed
