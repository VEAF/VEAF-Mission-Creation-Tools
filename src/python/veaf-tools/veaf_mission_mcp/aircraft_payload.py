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

from typing import Any

from veaf_libs.dcs_units_data import get_unit_countermeasures, get_unit_fuel_capacity


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


def normalize_pylons(pylons: dict[Any, Any]) -> dict[int, dict[str, Any]]:
    """Key a loadout by integer station number, the only form DCS reads.

    A JSON object's keys are always strings, so a loadout arriving through the MCP is
    ``{"4": {...}}``; written as-is, `luadata` renders ``["4"]``, a Lua entry DCS ignores, and the
    aircraft flies unarmed with no sign of why (caught in review of #993; `set_unit_properties`
    has handled the same trap since #726). A bare CLSID string is accepted as ``{"CLSID": ...}``.

    Args:
        pylons: ``{station: {"CLSID": ...}}`` or ``{station: "<CLSID>"}``, keys int or numeric text.

    Returns:
        The same loadout keyed by ``int``.

    Raises:
        ValueError: If a station is not an integer of 1 or more.
    """
    from veaf_mission_mcp.set_unit_properties import _station_number

    return {
        _station_number(station): {"CLSID": value} if isinstance(value, str) else value
        for station, value in pylons.items()
    }


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
