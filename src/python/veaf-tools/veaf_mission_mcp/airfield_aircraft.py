"""Which aircraft types an airfield can offer as dynamic slots (FIX-MCP-REPLAY-FINDINGS ticket 02).

The build stocks an airfield's warehouse from the dynamic-slot template catalogue — the mission's own
`src/dynamic-slot-templates.yaml`, else the one shipped with the tool, kept to the mission's era — and links
each stocked type to its template. The key a `warehouses.yaml` entry carries is the template's **unit type**
(`F-16C_50`, `AV8BNA`), not the name a pilot says (`F-16C`, `AV-8B`). A local model that wrote the latter by
hand got warnings at the first build and rebuilt. This module answers with the catalogue's own spelling, so
there is no second table to keep in step.
"""

from pathlib import Path
from typing import Any

import yaml
from aircrafts_injector.catalogue import CatalogueUnreadable, filter_by_era, iter_groups, load_catalogue
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import parkable_kinds

from veaf_mission_mcp.mission_folder import load_folder_mission

#: A catalogue category → the kind of stand an airfield needs to offer its aircraft.
_CATEGORY_TO_KIND: dict[str, str] = {"airplanes": "plane", "helicopters": "helicopter"}
#: The sides a catalogue's templates belong to.
_SIDES: tuple[str, ...] = ("blue", "red")
_CATALOGUE_FILE = "src/dynamic-slot-templates.yaml"


def _mission_yaml(folder: Path) -> dict[str, Any]:
    """Read a mission folder's `mission.yaml`; an absent or unreadable one is an empty mapping."""
    try:
        parsed = yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _first_type(group: Any) -> str:
    """Return the aircraft type of a template group: the type of its first unit."""
    units = group.get("units") if isinstance(group, dict) else None
    first = next(iter(units.values() if isinstance(units, dict) else units or []), None)
    return str(first.get("type") or "") if isinstance(first, dict) else ""


def list_airfield_aircraft(folder_path: Path, airfield: str, coalition: str | None = None) -> dict[str, Any]:
    """Return the aircraft types an airfield can offer as dynamic slots, spelled as the build validates them.

    The catalogue is the one the build injects: the mission folder's own `src/dynamic-slot-templates.yaml`
    when it holds templates, else the shipped one — the latter kept to the mission's era (`mission.era`),
    as the build does; a maker's own file is taken as written. An airfield is stocked with its owner's
    templates, so without `coalition` the answer is for the owner, or for both sides while it has none.
    DCS offers a slot only for an aircraft the airfield has a stand for, so a helipad-only field answers
    helicopters only.

    Args:
        folder_path: The mission folder (`mission.yaml` + `src/mission/`).
        airfield: The airfield's display name (e.g. ``"Ramat David"``), case-insensitive.
        coalition: ``"blue"`` or ``"red"`` to ask for one side; ``None`` for the airfield's owner.

    Returns:
        ``{airfield, airdrome_id, owner, parks, era, aircraft}`` — `owner` is ``blue``, ``red`` or
        ``neutral``; `parks` the kinds of aircraft the airfield has stands for (``None`` when no parking
        data ships for it, and nothing is left out); `era` the mission's era or ``None``; `aircraft`
        ``{side: {unit_type: template_name}}``, the `unit_type` being the key a `warehouses.yaml`
        ``aircrafts:`` entry takes.

    Raises:
        ValueError: The airfield is unknown for the mission's theatre, the coalition is not blue or red,
            or the catalogue file cannot be read.
        FileNotFoundError: The folder holds no mission.
    """
    from veaf_tools.commands.build import resolve_aircraft_catalogue

    if coalition is not None and coalition.strip().lower() not in _SIDES:
        raise ValueError(f"coalition must be one of {list(_SIDES)}, got '{coalition}'.")

    mission = load_folder_mission(folder_path)
    theatre = mission.theatre_content or ""
    airdrome_id = airdrome_id_for_name(theatre, airfield)
    if airdrome_id is None:
        raise ValueError(f"Unknown airfield '{airfield}' for theatre '{theatre or '?'}'.")

    airports = (mission.warehouses_content or {}).get("airports")
    entry = airports.get(airdrome_id) if isinstance(airports, dict) else None
    owner = str((entry or {}).get("coalition") or "neutral").lower()
    if coalition is not None:
        sides: tuple[str, ...] = (coalition.strip().lower(),)
    else:
        sides = (owner,) if owner in _SIDES else _SIDES

    mission_yaml = _mission_yaml(folder_path)
    era = str((mission_yaml.get("mission") or {}).get("era") or "").upper() or None
    path, is_shipped = resolve_aircraft_catalogue(
        mission_yaml.get("pipeline") or {}, folder_path, "dynamic_slot_templates", _CATALOGUE_FILE
    )
    try:
        catalogue = load_catalogue(path) if path else {}
    except CatalogueUnreadable as exc:
        raise ValueError(f"The dynamic-slot template catalogue cannot be read: {exc}") from exc
    if is_shipped and era:
        catalogue, _ = filter_by_era(catalogue, era)

    kinds = parkable_kinds(theatre, airdrome_id)
    aircraft: dict[str, dict[str, str]] = {side: {} for side in sides}
    for ref, group in iter_groups(catalogue):
        unit_type = _first_type(group)
        side = ref.coalition
        if side not in aircraft or not unit_type:
            continue
        if kinds is not None and _CATEGORY_TO_KIND.get(ref.category) not in kinds:
            continue
        aircraft[side].setdefault(unit_type, ref.name)  # the build links the first template of a type
    return {
        "airfield": airfield,
        "airdrome_id": airdrome_id,
        "owner": owner if owner in _SIDES else "neutral",
        "parks": sorted(kinds) if kinds is not None else None,
        "era": era,
        "aircraft": aircraft,
    }
