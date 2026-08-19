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
"""

from typing import Any

from veaf_libs.dcs_units_data import get_unit_fuel_capacity


def build_aircraft_payload(
    unit_type: str,
    *,
    fuel: float | None = None,
    fuel_fraction: float | None = None,
) -> tuple[dict[str, Any], str | None]:
    """Build one aircraft's `payload` table, fuelled.

    Args:
        unit_type: The DCS aircraft type (e.g. ``"F-15C"``).
        fuel: Explicit fuel load in **kilograms**. Wins over the database value.
        fuel_fraction: Fraction of the type's internal capacity, in ``]0, 1]`` — ``0.8`` for the
            80 % load the shipped A-10C II template carries. Needs a type the database knows.

    Returns:
        ``(payload, warning)``. ``payload`` carries ``fuel`` in kg, or **no** ``fuel`` key when the
        type's capacity is unknown and the caller named none; ``warning`` is the message to surface
        in that case, and ``None`` otherwise.

    Raises:
        ValueError: If both ``fuel`` and ``fuel_fraction`` are given, if either is out of range, or
            if ``fuel_fraction`` is asked for on a type whose capacity is unknown.
    """
    payload: dict[str, Any] = {"flare": 0, "chaff": 0, "gun": 100, "pylons": {}}
    resolved, warning = _resolve_fuel(unit_type, fuel, fuel_fraction)
    if resolved is not None:
        # Written first so the table keeps the field order every other mission file uses.
        payload = {"fuel": resolved, **payload}
    return payload, warning


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
