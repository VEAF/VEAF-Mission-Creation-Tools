"""`set_group_properties` — move, rename and reconfigure a group the mission already contains.

Ticket 03 of ``FEAT-MCP-MUTATION-ACTIONS``. **Move** carries the whole design of this module, and it
is not "set x and y":

- A group is units in a formation **plus** possibly a route. Moving it translates every unit, every
  waypoint *and* the group's own anchor by one delta — anything else shears the formation or detaches
  the route from the units it belongs to, and neither shows up until somebody flies the mission.
- The delta comes from the **geodesic** offset ``FEAT-GEO-PLACEMENT`` already ships
  (:func:`veaf_libs.coordinates.offset_latlon`), not from adding metres to ``x``: a DCS theatre is
  the real world projected, so "5 km east" is a lat/lon question and
  `ADR 0015 <../../docs/adr/0015-geographic-placement.md>`_ owns the conversion.

**Frequency** is gated on the airframe's ``HumanRadio`` bound from ``dcs-radio-specs.yaml``, reusing
the presets injector's validator rather than re-deriving it: ``FIX-PRIMARY-FREQ-HUMANRADIO``
established that the Mission Editor **refuses to save** a mission whose primary frequency falls
outside that bound, a failure that surfaces in the editor with nothing pointing back to the write.

**Rename** runs the reserved-convention check the MCP already owns, and refuses by default: a group
renamed onto a combat zone's trigger-zone name is *despawned at mission start*, silently. Renaming
*into* a convention is a legitimate intent, so ``acknowledge_conventions`` lets it through — the
point is that it must be deliberate.

What this action **cannot** do, measured rather than overlooked: check the destination's surface.
There is no terrain data on the Python side — ``land.getSurfaceType`` is a runtime API and only its
schema ships here — which is precisely why ``FEAT-SCENERY-AWARE-SPAWN`` solved that problem at
runtime. A move therefore warns that it could not look, rather than validating and lying.
"""

from pathlib import Path
from typing import Any

from presets_injector.radio_frequency_validator import get_human_radio
from veaf_libs import coordinates

from veaf_mission_mcp.group_naming import validate_group_name
from veaf_mission_mcp.mission_folder import commit_mission, open_mission
from veaf_mission_mcp.mission_table import find_group, group_names, indexed

#: DCS stores a group's modulation as an integer; a mission maker says AM or FM.
_MODULATIONS: dict[str, int] = {"AM": 0, "FM": 1}

#: Mission-table keys for the plain boolean flags, mapped from this action's parameter names.
_FLAG_KEYS: dict[str, str] = {
    "late_activation": "lateActivation",
    "hidden": "hidden",
    "uncontrolled": "uncontrolled",
}


def set_group_properties(
    miz_path: Path,
    *,
    group_name: str,
    new_name: str | None = None,
    move_to: dict[str, float] | None = None,
    move_bearing: float | None = None,
    move_distance_m: float | None = None,
    frequency_mhz: float | None = None,
    modulation: str | None = None,
    late_activation: bool | None = None,
    hidden: bool | None = None,
    uncontrolled: bool | None = None,
    acknowledge_conventions: bool = False,
) -> dict[str, Any]:
    """Change one named group, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        group_name: The group's **exact** name.
        new_name: A new name. Refused when it triggers a reserved VEAF convention, unless
            ``acknowledge_conventions`` is set. Unit names are deliberately left alone.
        move_to: Absolute destination for the group's anchor, ``{"x": ..., "y": ...}``. Mutually
            exclusive with the bearing form.
        move_bearing: Bearing in degrees (clockwise from north), with ``move_distance_m``.
        move_distance_m: Distance in metres along ``move_bearing``.
        frequency_mhz: The group's primary frequency, in MHz. Refused when the airframe declares a
            ``HumanRadio`` range that excludes it — the editor would refuse to save the mission.
        modulation: ``AM`` or ``FM``.
        late_activation: Whether the group starts late-activated.
        hidden: Whether the group is hidden on the map.
        uncontrolled: Whether an aircraft group starts uncontrolled (engines off).
        acknowledge_conventions: Allow a rename that triggers a reserved convention. The warnings
            are still reported.

    Returns:
        ``{group, changed, warnings}`` — ``changed`` maps each touched field to its previous and new
        value, ``position`` carrying the delta a move applied.

    Raises:
        ValueError: If the archive is not a valid mission, the group does not exist, no property was
            given, the two move forms are combined (or a bearing given without a distance), the new
            name collides or breaks a convention, the frequency falls outside the airframe's bound,
            the modulation is unknown, or the theatre has no coordinate projection.
    """
    flags = {"late_activation": late_activation, "hidden": hidden, "uncontrolled": uncontrolled}
    if all(
        value is None
        for value in (new_name, move_to, move_bearing, move_distance_m, frequency_mhz, modulation, *flags.values())
    ):
        raise ValueError(
            "no property given — pass at least one of new_name, move_to, move_bearing + "
            "move_distance_m, frequency_mhz, modulation, late_activation, hidden, uncontrolled"
        )
    if move_to is not None and (move_bearing is not None or move_distance_m is not None):
        raise ValueError("give either move_to or move_bearing + move_distance_m, not both")
    if (move_bearing is None) != (move_distance_m is None):
        raise ValueError("move_bearing and move_distance_m must be given together (or neither)")

    mission, content = open_mission(miz_path)

    group = find_group(content, group_name)
    existing_names = group_names(content)

    changed: dict[str, Any] = {}
    warnings: list[str] = []
    if new_name is not None:
        _apply_rename(group, new_name, existing_names, miz_path, acknowledge_conventions, changed, warnings)
    if move_to is not None or move_bearing is not None:
        _apply_move(
            group,
            mission.theatre_content,
            move_to=move_to,
            bearing=move_bearing,
            distance_m=move_distance_m,
            changed=changed,
            warnings=warnings,
        )
    if frequency_mhz is not None:
        _apply_frequency(group, frequency_mhz, changed)
    if modulation is not None:
        _apply_modulation(group, modulation, changed)
    for field, value in flags.items():
        if value is not None:
            key = _FLAG_KEYS[field]
            changed[field] = {"from": bool(group.get(key)), "to": value}
            group[key] = value

    durable = commit_mission(mission, miz_path)["durable"]

    return {"group": new_name or group_name, "changed": changed, "warnings": warnings, "durable": durable}


def _apply_rename(
    group: dict[str, Any],
    new_name: str,
    existing_names: list[str],
    miz_path: Path,
    acknowledge: bool,
    changed: dict[str, Any],
    warnings: list[str],
) -> None:
    """Rename the group, refusing a collision and — by default — a reserved convention.

    Unit names are deliberately **not** cascaded: they carry VEAF markers of their own
    (``#command=``, ``#veafInterpreter[...]``), and rewriting them from a group rename would edit
    those markers blind.

    Args:
        group: The group table to mutate.
        new_name: The proposed name.
        existing_names: Every group name in the mission, for the collision check.
        miz_path: The mission, so the convention check can see its trigger zones.
        acknowledge: Whether the caller accepts a convention-triggering name.
        changed: The report to record the change in.
        warnings: The warning list to append the conventions to.

    Raises:
        ValueError: On a name collision, or on a convention the caller has not acknowledged.
    """
    if new_name in existing_names and new_name != group.get("name"):
        raise ValueError(
            f"a group named {new_name!r} already exists — two groups sharing a name makes every "
            "later edit ambiguous, including undoing this one"
        )
    convention_warnings = validate_group_name(new_name, miz_path=miz_path)["warnings"]
    for warning in convention_warnings:
        warnings.append(f"{warning['convention']}: {warning['message']}")
    if convention_warnings and not acknowledge:
        hit = "; ".join(f"{w['convention']}: {w['message']}" for w in convention_warnings)
        raise ValueError(
            f"{new_name!r} triggers a reserved VEAF naming convention, which changes what the "
            f"runtime does with this group: {hit} Pass acknowledge_conventions=true if that is "
            "what you intend."
        )
    changed["name"] = {"from": group.get("name"), "to": new_name}
    group["name"] = new_name


def _apply_move(
    group: dict[str, Any],
    theatre: str | None,
    *,
    move_to: dict[str, float] | None,
    bearing: float | None,
    distance_m: float | None,
    changed: dict[str, Any],
    warnings: list[str],
) -> None:
    """Translate the group's anchor, every unit and every waypoint by one delta.

    Args:
        group: The group table to mutate.
        theatre: The mission's theatre, needed for the geodesic offset.
        move_to: Absolute destination for the anchor.
        bearing: Bearing in degrees, with `distance_m`.
        distance_m: Distance in metres along `bearing`.
        changed: The report to record the move in.
        warnings: The warning list, told that the surface could not be checked.

    Raises:
        ValueError: If the group has no position, or the theatre has no projection for a
            bearing-based move.
    """
    anchor = _anchor(group)
    if anchor is None:
        raise ValueError(f"group {group.get('name')!r} has no position to move from")
    origin_x, origin_y = anchor

    if move_to is not None:
        target_x, target_y = float(move_to["x"]), float(move_to["y"])
    else:
        assert bearing is not None and distance_m is not None  # noqa: S101 - guarded by the caller
        if not theatre or not coordinates.is_theatre_supported(theatre):
            raise ValueError(
                f"theatre {theatre!r} has no coordinate projection, so a bearing and a distance "
                "cannot be resolved; pass move_to with explicit x/y instead"
            )
        lat, lon = coordinates.xy_to_latlon(theatre, origin_x, origin_y)
        moved_lat, moved_lon = coordinates.offset_latlon(lat, lon, float(bearing), float(distance_m))
        target_x, target_y = coordinates.latlon_to_xy(theatre, moved_lat, moved_lon)

    delta_x, delta_y = target_x - origin_x, target_y - origin_y
    _translate(group, delta_x, delta_y)

    changed["position"] = {
        "from": {"x": origin_x, "y": origin_y},
        "to": {"x": target_x, "y": target_y},
        "delta": {"x": delta_x, "y": delta_y},
    }
    warnings.append(
        "the destination's surface was not checked: DCS terrain is not available design-time "
        "(land.getSurfaceType is a runtime API), so a ground group can land in water or on a slope "
        "without this action noticing — verify it in the editor"
    )


def _anchor(group: dict[str, Any]) -> tuple[float, float] | None:
    """Return the point a move is measured from: the group's own anchor, else its first unit.

    A group table normally carries ``x``/``y``, but an adopted mission does not always, and the
    first unit's position is what the editor falls back to when drawing the group.

    Args:
        group: The group table.

    Returns:
        ``(x, y)``, or None when neither the group nor any unit has a position.
    """
    if group.get("x") is not None and group.get("y") is not None:
        return float(group["x"]), float(group["y"])
    for unit in indexed(group.get("units")):
        if isinstance(unit, dict) and unit.get("x") is not None and unit.get("y") is not None:
            return float(unit["x"]), float(unit["y"])
    return None


def _translate(group: dict[str, Any], delta_x: float, delta_y: float) -> None:
    """Shift the group's anchor, all its units and all its waypoints by the same delta.

    Args:
        group: The group table to mutate.
        delta_x: Northing delta, in metres.
        delta_y: Easting delta, in metres.
    """
    for holder in (group, *indexed(group.get("units")), *indexed((group.get("route") or {}).get("points"))):
        if not isinstance(holder, dict):
            continue
        if holder.get("x") is not None:
            holder["x"] = float(holder["x"]) + delta_x
        if holder.get("y") is not None:
            holder["y"] = float(holder["y"]) + delta_y


def _apply_frequency(group: dict[str, Any], frequency_mhz: float, changed: dict[str, Any]) -> None:
    """Set the group's primary frequency, refused when an airframe cannot tune it.

    Every unit type in the group is checked, not just the first: a mixed group would otherwise pass
    on its first member and be refused by the editor because of another.

    Args:
        group: The group table to mutate.
        frequency_mhz: The frequency, in MHz.
        changed: The report to record the change in.

    Raises:
        ValueError: If a unit type in the group declares a primary range excluding the frequency.
    """
    for unit in indexed(group.get("units")):
        if not isinstance(unit, dict):
            continue
        unit_type = unit.get("type")
        if not unit_type:
            continue
        human_radio = get_human_radio(str(unit_type))
        if human_radio is None:
            continue
        if not human_radio.min_mhz <= frequency_mhz <= human_radio.max_mhz:
            raise ValueError(
                f"{frequency_mhz} MHz is outside {unit_type}'s primary-frequency range "
                f"({human_radio.min_mhz}-{human_radio.max_mhz} MHz): the DCS Mission Editor refuses "
                "to save a mission whose group frequency falls outside it"
            )
    changed["frequency"] = {"from": group.get("frequency"), "to": frequency_mhz}
    group["frequency"] = frequency_mhz


def _apply_modulation(group: dict[str, Any], modulation: str, changed: dict[str, Any]) -> None:
    """Set the group's modulation from its readable name.

    Args:
        group: The group table to mutate.
        modulation: ``AM`` or ``FM``, case-insensitively.
        changed: The report to record the change in.

    Raises:
        ValueError: If `modulation` is neither.
    """
    key = modulation.strip().upper()
    if key not in _MODULATIONS:
        raise ValueError(f"unknown modulation {modulation!r}; expected one of {', '.join(_MODULATIONS)}")
    changed["modulation"] = {"from": group.get("modulation"), "to": key}
    group["modulation"] = _MODULATIONS[key]
