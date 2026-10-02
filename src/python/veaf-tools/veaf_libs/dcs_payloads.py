"""DCS's default loadouts by name — the list the Mission Editor offers for an AI aircraft.

Read from the shipped ``payloads.yaml``, which ``veaf-build update-dcs-data --payloads`` generates from
an install's ``MissionEditor/data/scripts/UnitPayloads`` (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 09).
"""

from functools import lru_cache
from typing import Any

import yaml

from veaf_libs.bundled_data import read_bundled_text


@lru_cache(maxsize=1)
def _payloads() -> dict[str, dict[str, dict[int, str]]]:
    """Load (and cache) unit type -> loadout name -> station -> CLSID."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "payloads.yaml")) or {}
    return {
        str(unit_type): {str(name): {int(k): str(v) for k, v in (pylons or {}).items()} for name, pylons in names.items()}
        for unit_type, names in raw.items()
    }


def payload_types() -> list[str]:
    """Return every unit type that has DCS loadouts, sorted."""
    return sorted(_payloads(), key=str.lower)


def payload_names(unit_type: str) -> list[str]:
    """Return the loadout names DCS offers for a type, in the editor's alphabetical order.

    Args:
        unit_type: The exact DCS unit type (``MiG-31``, ``F-16C bl.50``).

    Returns:
        The names; empty for a type DCS gives no loadout (a module, a transport).
    """
    return sorted(_payloads().get(unit_type, {}))


def payload_pylons(unit_type: str, name: str) -> dict[int, dict[str, Any]]:
    """Return a DCS loadout as the pylons table a mission file stores.

    Args:
        unit_type: The exact DCS unit type.
        name: The loadout's name, exactly as the Mission Editor lists it.

    Returns:
        ``{station: {"CLSID": ...}}``.

    Raises:
        ValueError: For a type with no DCS loadout, or a name the type does not have — listing
            what there is.
    """
    by_name = _payloads().get(unit_type)
    if not by_name:
        raise ValueError(
            f"payload: DCS has no named loadout for {unit_type!r} (a module aircraft keeps its own); "
            "use 'pylons' or 'loadout_from' instead"
        )
    pylons = by_name.get(name)
    if pylons is None:
        raise ValueError(f"payload: {unit_type!r} has no loadout named {name!r}; its loadouts: {payload_names(unit_type)}")
    return {station: {"CLSID": clsid} for station, clsid in pylons.items()}
