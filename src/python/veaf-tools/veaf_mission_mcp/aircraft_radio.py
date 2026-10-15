"""The radio frequency a new aircraft group is written with.

``add_air_group`` and ``add_player_slot`` used to write 251 MHz on every group. The Mission Editor
refuses to save a mission whose group frequency is outside the range the airframe's radio accepts, and
251 is outside a P-51D's (100-156 MHz) and a Fw 190's (38.4-42.4 MHz): the build, ``validate`` and
the tests never opened the file in the editor, so three client groups of the Normandy Open Training
could not be saved (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 13).
"""

from presets_injector.radio_frequency_validator import get_human_radio

#: The frequency of a type the radio specs do not know: a modern UHF aircraft's.
FALLBACK_FREQUENCY_MHZ = 251.0


def resolve_group_frequency(unit_type: str, frequency_mhz: float | None, *, skill: str) -> tuple[float, str | None]:
    """Return the frequency to write on a new group, and a warning when the one asked for is out of range.

    Args:
        unit_type: The aircraft type.
        frequency_mhz: The frequency the caller asked for, or ``None`` for the type's own default.
        skill: The group's skill; a ``Client`` or ``Player`` group is the one the editor refuses to save.

    Returns:
        ``(frequency, warning)``. ``None`` gives 251 when the airframe can tune it (and for a type with no
        spec), else the type's own ``default_mhz``; an explicit frequency is kept, and warned about when the airframe cannot tune it.

    Raises:
        ValueError: A ``Client`` or ``Player`` group asked for a frequency its airframe cannot tune.
    """
    human_radio = get_human_radio(unit_type)
    if frequency_mhz is None:
        # 251 stays wherever the airframe can tune it, so no modern mission changes frequency; only a
        # type that cannot (a warbird) takes its own default.
        if human_radio is None or human_radio.contains(FALLBACK_FREQUENCY_MHZ) or human_radio.default_mhz is None:
            return FALLBACK_FREQUENCY_MHZ, None
        return human_radio.default_mhz, None
    if human_radio is None or human_radio.min_mhz <= frequency_mhz <= human_radio.max_mhz:
        return frequency_mhz, None
    message = (
        f"{frequency_mhz} MHz is outside {unit_type}'s primary-frequency range "
        f"({human_radio.min_mhz}-{human_radio.max_mhz} MHz): the DCS Mission Editor refuses to save "
        "a mission whose group frequency falls outside it"
    )
    if skill in ("Client", "Player"):
        raise ValueError(message)
    return frequency_mhz, message
