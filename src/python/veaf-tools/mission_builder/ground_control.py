"""Set the mission's unattached roles and vehicle control from ``mission.ground_control``.

DCS keeps, in the mission table's ``groundControl``, how many players may take each role that
flies no aircraft (game master, tactical commander, JTAC, observer) on each side, and whether a
pilot may drive ground vehicles (``isPilotControlVehicles``). ``blank_mission.py`` writes zero
slots and no vehicle control; without this block a v6 mission has no game master slot unless
someone edits ``src/mission/mission`` by hand (FIX-OPEN-TRAINING-CAUCASUS-FINDINGS ticket 01).

The block is applied at every build. Absent, the mission's own ``groundControl`` is left alone,
so a mission that set it in the editor keeps it. Role passwords stay out of reach on purpose:
a password in ``mission.yaml`` would be committed in clear.
"""

from __future__ import annotations

from veaf_libs.i18n import t

#: ``mission.yaml`` role name → DCS ``groundControl.roles`` key.
ROLES: dict[str, str] = {
    "game_master": "instructor",
    "tactical_commander": "artillery_commander",
    "jtac": "forward_observer",
    "observer": "observer",
}
PILOT_CONTROL_VEHICLES = "pilot_control_vehicles"
SIDES = ("blue", "red")
_DCS_SIDES = ("blue", "neutrals", "red")


def _is_count(value: object) -> bool:
    """Return whether ``value`` is a slot count: a natural number, not a boolean."""
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def ground_control_errors(block: object) -> list[str]:
    """Return what is wrong with a ``mission.ground_control`` block, one message per fault.

    Args:
        block: The value of ``mission.ground_control``.

    Returns:
        The localized error messages; empty when the block is valid.
    """
    if not isinstance(block, dict):
        return [t("ground_control.not_a_mapping")]
    errors: list[str] = []
    for key, value in block.items():
        if key == PILOT_CONTROL_VEHICLES:
            if not isinstance(value, bool):
                errors.append(t("ground_control.not_a_boolean", setting=key))
        elif key not in ROLES:
            errors.append(t("ground_control.unknown_role", role=key, known=", ".join([*ROLES, PILOT_CONTROL_VEHICLES])))
        elif isinstance(value, dict):
            for side, count in value.items():
                if side not in SIDES:
                    errors.append(t("ground_control.unknown_side", role=key, side=side, known=", ".join(SIDES)))
                elif not _is_count(count):
                    errors.append(t("ground_control.not_a_count", role=f"{key}.{side}"))
        elif not _is_count(value):
            errors.append(t("ground_control.not_a_count", role=key))
    return errors


def apply_ground_control(mission_content: dict, block: dict) -> None:
    """Write a valid ``mission.ground_control`` block into the mission's ``groundControl``.

    A number sets the role on both sides; a ``{blue: n, red: m}`` mapping sets only the sides it
    names. A role, a side or ``pilot_control_vehicles`` the block does not name keeps the mission's
    value, and ``passwords`` is never touched.

    Args:
        mission_content: The parsed DCS ``mission`` table (mutated in place).
        block: The ``mission.ground_control`` block, already checked by :func:`ground_control_errors`.
    """
    ground_control = mission_content.setdefault("groundControl", {})
    ground_control.setdefault("isPilotControlVehicles", False)
    ground_control.setdefault("passwords", {})
    roles = ground_control.setdefault("roles", {})
    for dcs_role in ROLES.values():
        current = roles.setdefault(dcs_role, {})
        for side in _DCS_SIDES:
            current.setdefault(side, 0)

    for key, value in block.items():
        if key == PILOT_CONTROL_VEHICLES:
            ground_control["isPilotControlVehicles"] = value
            continue
        counts = value if isinstance(value, dict) else dict.fromkeys(SIDES, value)
        roles[ROLES[key]].update(counts)
