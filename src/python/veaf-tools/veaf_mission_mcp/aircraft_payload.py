"""Build the `payload` table an aircraft unit carries in a mission file.

Both aircraft-creating actions — `add_air_group` and `add_player_slot` — write the same table, and
both wrote ``fuel = 0`` until 2026-08-19. That is not "unspecified", it is **no fuel at all**:
measured on `verify-mission-c`, a KC-135 and its two F-15C escorts created at 20 000 ft pitched
straight into the ground the instant they appeared, engines out. A ground start hid it, DCS fuelling
a parked aircraft from the airfield's stock, which is why the parked player slots never showed it.

The honest default is **full internal fuel**, and the value is not invented here: `dcsUnits.yaml`
carries each type's ``M_fuel_max`` straight from the datamine (``F-15C: 6103``, ``F-14B: 7348``) —
the same numbers the shipped VEAF templates use.

A type the database does not know — a third-party mod, a misspelling — gets **no `fuel` key at all
and a warning naming it**, rather than a number nobody measured. That mirrors what these actions
already do when they cannot classify such a type (`FIX-MCP-AIRCRAFT-CATEGORY`): they warn and carry
on, because refusing would make the tooling unusable with mods. An absent key leaves DCS its own
default; ``fuel = 0`` was an explicit instruction to carry none, which is the whole defect.

The same table carried ``flare = 0, chaff = 0`` until 2026-09-28: an air-start client cannot rearm,
so every pilot of the GermanyCW-v6 arena went into a missile fight with an empty dispenser
(FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 01). The default is now the one the Mission Editor gives a
newly placed aircraft, read from the datamine's ``passivCounterm`` into ``dcsUnits.yaml`` — the
database, not the mission's own dynamic-slot templates, because a mission need not have a template
of the type, and the editor's default is what a mission maker placing the aircraft by hand gets.
A type with no dispenser (a warbird, a tanker) or unknown to the database keeps 0.
"""

import copy
from pathlib import Path
from typing import Any

import yaml
from veaf_libs.dcs_payloads import payload_pylons
from veaf_libs.dcs_units_data import get_unit_countermeasures, get_unit_fuel_capacity
from veaf_libs.mission_table import indexed
from veaf_libs.shipped_defaults import shipped_default_file

#: The WW2 fighters, which fight with their guns and carry no pylon; the bombers of the era (A-20G, B-17G,
#: Ju-88A4) do not, and are not here.
GUN_FIGHTERS: frozenset[str] = frozenset(
    {
        "SpitfireLFMkIX",
        "SpitfireLFMkIXCW",
        "P-51D",
        "P-51D-30-NA",
        "TF-51D",
        "P-47D-30",
        "P-47D-30bl1",
        "P-47D-40",
        "Bf-109K-4",
        "FW-190A8",
        "FW-190D9",
        "MosquitoFBMkVI",
        "I-16",
        "La-7",
        "F4U-1D",
        "F4U-1D_CW",
    }
)


def build_aircraft_payload(
    unit_type: str,
    *,
    fuel: float | None = None,
    fuel_fraction: float | None = None,
    chaff: int | None = None,
    flare: int | None = None,
) -> tuple[dict[str, Any], str | None]:
    """Build one aircraft's `payload` table, fuelled.

    Args:
        unit_type: The DCS aircraft type (e.g. ``"F-15C"``).
        fuel: Explicit fuel load in **kilograms**. Wins over the database value.
        fuel_fraction: Fraction of the type's internal capacity, in ``]0, 1]`` — ``0.8`` for the
            80 % load the shipped A-10C II template carries. Needs a type the database knows.
        chaff: Chaff count. Defaults to the type's Mission Editor default (0 when it has none).
        flare: Flare count. Defaults to the type's Mission Editor default (0 when it has none).

    Returns:
        ``(payload, warning)``. ``payload`` carries ``fuel`` in kg, or **no** ``fuel`` key when the
        type's capacity is unknown and the caller named none; ``warning`` is the message to surface
        in that case, and ``None`` otherwise.

    Raises:
        ValueError: If both ``fuel`` and ``fuel_fraction`` are given, if either is out of range, if
            ``fuel_fraction`` is asked for on a type whose capacity is unknown, or if a chaff or flare
            count is negative.
    """
    default_chaff, default_flare = get_unit_countermeasures(unit_type) or (0, 0)
    payload: dict[str, Any] = {
        "flare": _count("flare", flare, default_flare),
        "chaff": _count("chaff", chaff, default_chaff),
        "gun": 100,
        "pylons": {},
    }
    resolved, warning = _resolve_fuel(unit_type, fuel, fuel_fraction)
    if resolved is not None:
        # Written first so the table keeps the field order every other mission file uses.
        payload = {"fuel": resolved, **payload}
    return payload, warning


def resolve_loadout(unit_type: str, pylons: dict[Any, Any] | None, payload: str | None) -> dict[Any, Any] | None:
    """Return the loadout a flight was given: explicit ``pylons``, or a DCS loadout by name.

    Args:
        unit_type: The aircraft type, to look the named loadout up.
        pylons: An explicit loadout, ``{station: {"CLSID": ...}}``.
        payload: A DCS loadout's name, as the Mission Editor lists it (FIX-OPEN-TRAINING-SYRIA-FINDINGS
            ticket 09).

    Returns:
        The pylons table, or ``None`` when neither is given.

    Raises:
        ValueError: When both are given, or the name is not one of the type's loadouts.
    """
    if pylons and payload:
        raise ValueError("give either 'pylons' or 'payload', not both")
    if payload:
        return payload_pylons(unit_type, payload)
    return pylons or None


def normalize_pylons(pylons: dict[Any, Any] | list[Any]) -> dict[int, dict[str, Any]]:
    """Key a loadout by integer station number, the only form DCS reads.

    A JSON object's keys are always strings, so a loadout arriving through the MCP is
    ``{"4": {...}}``; written as-is, `luadata` renders ``["4"]``, a Lua entry DCS ignores, and the
    aircraft flies unarmed with no sign of why (caught in review of #993; `set_unit_properties`
    has handled the same trap since #726). A bare CLSID string is accepted as ``{"CLSID": ...}``.

    A loadout copied from a mission group (`loadout_from`) whose stations run 1..n with no gap comes
    back from the Lua parser as a list; its first entry is station 1 (FIX-MCP-SESSION-PREP-FINDINGS).

    Args:
        pylons: ``{station: {"CLSID": ...}}`` or ``{station: "<CLSID>"}``, keys int or numeric text,
            or a list of the same values for stations 1..n.

    Returns:
        The same loadout keyed by ``int``.

    Raises:
        ValueError: If a station is not an integer of 1 or more.
    """
    from veaf_mission_mcp.set_unit_properties import _station_number

    if isinstance(pylons, list):
        pylons = dict(enumerate(pylons, start=1))
    return {
        _station_number(station): {"CLSID": value} if isinstance(value, str) else value
        for station, value in pylons.items()
    }


def resolve_flight_loadout(
    folder_path: Path, content: dict[str, Any], spec: dict[str, Any], unit_type: str
) -> dict[Any, Any] | None:
    """Resolve a flight's loadout: explicit `pylons`, a DCS `payload` by name, or `loadout_from` a group.

    An interceptor created without weapons is the next silent failure after one created without
    fuel. The `veafSpawn-*` groups of the aircraft catalogues are a sourced place to take a loadout
    from, so `loadout_from` looks in the mission first, then in the folder's catalogues, then in the
    shipped ones.

    Args:
        folder_path: The mission folder.
        content: The parsed mission table.
        spec: A mapping that may carry `pylons`, `payload` and `loadout_from` — one of them at most.
        unit_type: The flight's aircraft type, to look a named `payload` up.

    Returns:
        The pylons table, or None when none is given.

    Raises:
        ValueError: If more than one is given, `payload` is not one of the type's DCS loadouts, or
            `loadout_from` names a group found nowhere, or one with no aircraft.
    """
    given = [key for key in ("pylons", "payload", "loadout_from") if spec.get(key)]
    if len(given) > 1:
        raise ValueError(f"give one loadout, not {' and '.join(given)}")
    if spec.get("pylons") or spec.get("payload"):
        return resolve_loadout(unit_type, spec.get("pylons"), spec.get("payload"))
    source = spec.get("loadout_from")
    if not source:
        return None
    group = _find_air_group_in_content(content, source) or _find_air_group_in_catalogues(folder_path, source)
    if group is None:
        raise ValueError(f"loadout_from: no aircraft group named {source!r} in the mission or the aircraft catalogues")
    units = [unit for unit in indexed(group.get("units")) if isinstance(unit, dict)]
    for unit in units:
        pylons = (unit.get("payload") or {}).get("pylons")
        if pylons:
            return copy.deepcopy(pylons)
    if units and unit_type in GUN_FIGHTERS:
        # A gun fighter's template has an empty pylons table on purpose (FIX-OPEN-TRAINING-NORMANDY-FINDINGS
        # ticket 02): copying "no pylons" is the answer. For any other type it is the defect of an empty
        # template (the J-11A of FIX-OPEN-TRAINING-MARIANAS-FINDINGS ticket 04), and stays a refusal.
        return None
    raise ValueError(f"loadout_from: the group {source!r} carries no pylons")


def _find_air_group_in_content(content: dict[str, Any], name: str) -> dict[str, Any] | None:
    """Return the plane or helicopter group of the mission table named `name`.

    Args:
        content: The parsed mission table.
        name: The exact group name.

    Returns:
        The group, or None when the mission has none by that name.
    """
    for coalition in (content.get("coalition") or {}).values():
        for country in indexed((coalition or {}).get("country")):
            for category in ("plane", "helicopter"):
                for group in indexed(((country or {}).get(category) or {}).get("group")):
                    if isinstance(group, dict) and group.get("name") == name:
                        return group
    return None


def _find_air_group_in_catalogues(folder_path: Path, name: str) -> dict[str, Any] | None:
    """Return the aircraft group named `name` from the aircraft catalogues, the folder's first.

    Looks in `src/spawnables.yaml` then `src/dynamic-slot-templates.yaml`, each in the folder and
    then in the shipped defaults — the order the build resolves them in.

    Args:
        folder_path: The mission folder.
        name: The exact group name.

    Returns:
        The group, or None when no catalogue has one by that name.
    """
    for relative in ("src/spawnables.yaml", "src/dynamic-slot-templates.yaml"):
        for path in (folder_path / relative, shipped_default_file(folder_path, relative)):
            if path is None or not path.is_file():
                continue
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            for family in ("airplanes", "helicopters"):
                sides = ((data.get(family) or {}).get("coalitions")) or {}
                for countries in sides.values():
                    for groups in (countries or {}).values():
                        if isinstance(groups, dict) and isinstance(groups.get(name), dict):
                            return groups[name]
    return None


def _count(label: str, value: int | None, default: int) -> int:
    """Return an explicit countermeasure count, validated, or the type's default."""
    if value is None:
        return default
    if int(value) < 0:
        raise ValueError(f"{label} must be >= 0, got {value}")
    return int(value)


def _resolve_fuel(
    unit_type: str, fuel: float | None, fuel_fraction: float | None
) -> tuple[float | int | None, str | None]:
    """Decide the fuel load in kg, refusing to invent one it was not given the means to compute."""
    if fuel is not None and fuel_fraction is not None:
        raise ValueError("give fuel (kg) or fuel_fraction, not both")

    if fuel is not None:
        if fuel < 0:
            raise ValueError(f"fuel must be >= 0 kg, got {fuel}")
        return fuel, None

    capacity = get_unit_fuel_capacity(unit_type)

    if fuel_fraction is not None:
        if not 0 < fuel_fraction <= 1:
            raise ValueError(f"fuel_fraction must be in ]0, 1], got {fuel_fraction}")
        if capacity is None:
            raise ValueError(
                f"No fuel capacity known for {unit_type!r}, so a fraction of it cannot be resolved — "
                "give fuel in kg instead."
            )
        return _round_kg(capacity * fuel_fraction), None

    if capacity is None:
        return None, (
            f"No fuel capacity known for {unit_type!r} (a third-party mod, or a misspelt type): the "
            "aircraft was created without a fuel load, leaving DCS its own default. Pass fuel in kg "
            "to state one."
        )
    return _round_kg(capacity), None


def _round_kg(value: float) -> float | int:
    """Return whole kilograms as an ``int``, keeping the mission file's own form (``6103``)."""
    rounded = round(value, 3)
    return int(rounded) if float(rounded).is_integer() else rounded
