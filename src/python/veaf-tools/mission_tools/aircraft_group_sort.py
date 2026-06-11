"""Sort a DCS aircraft group into one of two reusable families (ADR 0002).

Lives in the low-level ``mission_tools`` package so both the aircraft injector
and the v5 converter can share it without a sibling-to-sibling dependency.
"""

from __future__ import annotations

from typing import Any

#: Runtime prefix that marks a spawnable aircraft group (cloned by veafSpawn).
SPAWNABLE_NAME_PREFIX = "veafSpawn-"

#: Sort kinds.
KIND_SPAWNABLE = "spawnable"
KIND_DYNAMIC_TEMPLATE = "dynamic_template"


def classify_aircraft_group(group: dict[str, Any]) -> str | None:
    """Sort an aircraft group into one of the two reusable families (ADR 0002).

    Args:
        group: A DCS aircraft group table.

    Returns:
        ``"dynamic_template"`` when the group carries the native DCS flag
        ``dynSpawnTemplate == true`` (the flag wins even for ``veafSpawn-`` names),
        ``"spawnable"`` when its name starts with ``veafSpawn-``, or ``None`` for
        an ordinary mission group that is not a reusable spawn asset.
    """
    if group.get("dynSpawnTemplate") is True:
        return KIND_DYNAMIC_TEMPLATE
    name = group.get("name", "")
    if isinstance(name, str) and name.startswith(SPAWNABLE_NAME_PREFIX):
        return KIND_SPAWNABLE
    return None
