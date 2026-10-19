"""Set the mission's enforced options from ``mission.forced_options``.

DCS keeps, in the mission table's ``forcedOptions``, the options a mission imposes on every player
whatever their own settings say — labels, F10 map view, external views, wake turbulence… — the
*Mission options* panel of the Mission Editor. It stores them flat, DCS key → value
(``["labels"] = 0``, ``["optionsView"] = "optview_onlyallies"``), read in 107 real missions on
2026-10-19. ``blank_mission.py`` writes an empty table, and nothing else in VMCT could fill it.

The names below follow the editor's labels; the DCS keys, the coded values and the list of
enforceable options come from ``MissionEditor/modules/Options/optionsDb.lua`` (DCS 2.9.30, every
option declared ``:setEnforceable()``). The F10 view per role, ``optionsView = "optview_extended"``
plus ``optionsViewExtended``, comes from ``me_extendedF10ViewOptions.lua`` and the layout of its
dialog: no saved mission uses it, so what DCS does with it in game is checked in game
(FEAT-FORCED-MISSION-OPTIONS ticket 06).

The block is applied at every build. Absent, the mission's own ``forcedOptions`` is left alone; an
option the block does not name keeps the mission's value, so the block never clears one.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from veaf_libs.i18n import t


@dataclass(frozen=True)
class ForcedOption:
    """One enforceable option: its DCS key and the values ``mission.yaml`` may give it.

    Attributes:
        dcs_key: The key in the mission's ``forcedOptions``.
        choices: For an option DCS stores as a code, ``mission.yaml`` word → DCS value; empty for
            a boolean or a number.
        number_range: For a number, its inclusive bounds; ``None`` otherwise.
    """

    dcs_key: str
    choices: dict[str, object] = field(default_factory=dict)
    number_range: tuple[int, int] | None = None


#: The F10 map views, ``mission.yaml`` word → DCS ``optionsView`` value (editor labels in comments).
F10_VIEWS: dict[str, str] = {
    "all": "optview_all",  # ALL
    "fog_of_war": "optview_allies",  # FOG OF WAR
    "allies_only": "optview_onlyallies",  # ALLIES ONLY
    "map_only": "optview_onlymap",  # MAP ONLY
    "my_aircraft": "optview_myaircraft",  # MY A/C
}
F10_VIEW_EXTENDED = "optview_extended"

#: ``mission.yaml`` name → the option. Booleans unless they carry choices or a range.
OPTIONS: dict[str, ForcedOption] = {
    "labels": ForcedOption("labels", {"full": 1, "abbreviated": 2, "symbol_only": 3, "dot_neutral": 4, "none": 0}),
    "spotting_dot": ForcedOption("spottingDot", {"off": 0, "auto": 3, "one_pixel": 1, "two_pixels": 2}),
    "f10_view": ForcedOption("optionsView", dict(F10_VIEWS)),
    "f10_marks": ForcedOption("userMarks"),
    "external_views": ForcedOption("externalViews"),
    "padlock": ForcedOption("padlock"),
    "permit_crash": ForcedOption("permitCrash"),
    "easy_flight": ForcedOption("easyFlight"),
    "easy_communication": ForcedOption("easyCommunication"),
    "radio_assist": ForcedOption("radio"),
    "mini_hud": ForcedOption("miniHUD"),
    "cockpit_visual_recon_mode": ForcedOption("cockpitVisualRM"),
    "cockpit_status_bar": ForcedOption("cockpitStatusBarAllowed"),
    "battle_damage_assessment": ForcedOption("RBDAI"),
    "unlimited_fuel": ForcedOption("fuel"),
    "unlimited_weapons": ForcedOption("weapons"),
    "immortal": ForcedOption("immortal"),
    "g_effects": ForcedOption("geffect", {"none": "none", "reduced": "reduced", "realistic": "realistic"}),
    "g_warm_up": ForcedOption("gWarmUp"),
    "wake_turbulence": ForcedOption("wakeTurbulence"),
    "unrestricted_satnav": ForcedOption("unrestrictedSATNAV"),
    "birds": ForcedOption("birds", number_range=(0, 1000)),
    "civil_traffic": ForcedOption("civTraffic", {"off": "", "low": "low", "medium": "medium", "high": "high"}),
    "random_failures": ForcedOption("accidental_failures"),
}

F10_VIEW_BY_ROLE = "f10_view_by_role"

#: ``mission.yaml`` role → the editor's role number (``me_extendedF10ViewOptions_role_wgt.lua``).
ROLES: dict[str, int] = {
    "pilot": 1,
    "jtac": 2,  # Forward observer
    "tactical_commander": 3,
    "observer": 4,
    "spectator": 5,
    "airboss": 6,  # Airboss/LSO
}

#: The layer grid of the editor's dialog: bit = row × 3 + column.
LAYER_SIDES = ("allies", "enemies", "neutral")
LAYER_CATEGORIES = ("planes", "helicopters", "ground", "naval", "weapons")
LAYERS: dict[str, int] = {
    f"{side}_{category}": row * len(LAYER_SIDES) + column
    for row, category in enumerate(LAYER_CATEGORIES)
    for column, side in enumerate(LAYER_SIDES)
}


def _value_errors(name: str, option: ForcedOption, value: object) -> list[str]:
    """Return what is wrong with ``value`` for ``option``, at most one message."""
    if option.choices:
        if isinstance(value, str) and value in option.choices:
            return []
        return [t("forced_options.not_in_list", option=name, value=value, known=", ".join(option.choices))]
    if option.number_range:
        low, high = option.number_range
        if isinstance(value, int) and not isinstance(value, bool) and low <= value <= high:
            return []
        return [t("forced_options.out_of_range", option=name, low=low, high=high)]
    if isinstance(value, bool):
        return []
    return [t("forced_options.not_a_boolean", option=name)]


def _role_errors(roles: object) -> list[str]:
    """Return what is wrong with an ``f10_view_by_role`` block, one message per fault."""
    if not isinstance(roles, dict):
        return [t("forced_options.roles_not_a_mapping", known=", ".join(ROLES))]
    errors: list[str] = []
    for role, setting in roles.items():
        if role not in ROLES:
            errors.append(t("forced_options.unknown_role", role=role, known=", ".join(ROLES)))
            continue
        view, hide = (setting, []) if not isinstance(setting, dict) else (setting.get("view"), setting.get("hide", []))
        if isinstance(setting, dict) and set(setting) - {"view", "hide"}:
            errors.append(t("forced_options.role_keys", role=role))
        elif not (isinstance(view, str) and view in F10_VIEWS):
            errors.append(
                t(
                    "forced_options.not_in_list",
                    option=f"{F10_VIEW_BY_ROLE}.{role}",
                    value=view,
                    known=", ".join(F10_VIEWS),
                )
            )
        elif not isinstance(hide, list) or any(layer not in LAYERS for layer in hide):
            errors.append(t("forced_options.unknown_layer", role=role, known=", ".join(LAYERS)))
    return errors


def forced_options_errors(block: object) -> list[str]:
    """Return what is wrong with a ``mission.forced_options`` block, one message per fault.

    Args:
        block: The value of ``mission.forced_options``.

    Returns:
        The localized error messages; empty when the block is valid.
    """
    if not isinstance(block, dict):
        return [t("forced_options.not_a_mapping")]
    errors: list[str] = []
    for name, value in block.items():
        if name == F10_VIEW_BY_ROLE:
            errors += _role_errors(value)
        elif name in OPTIONS:
            errors += _value_errors(name, OPTIONS[name], value)
        else:
            errors.append(
                t("forced_options.unknown_option", option=name, known=", ".join([*OPTIONS, F10_VIEW_BY_ROLE]))
            )
    if "f10_view" in block and F10_VIEW_BY_ROLE in block:
        errors.append(t("forced_options.view_and_view_by_role"))
    return errors


def _extended_view(roles: dict) -> dict[int, dict]:
    """Build ``optionsViewExtended``: every role, those not named showing everything."""
    extended: dict[int, dict] = {}
    for role, number in ROLES.items():
        setting = roles.get(role, "all")
        view, hide = (setting, []) if not isinstance(setting, dict) else (setting["view"], setting.get("hide", []))
        hidden = {LAYERS[layer] for layer in hide}
        extended[number] = {
            "f10ViewOption": F10_VIEWS[view],
            "visibleUnitLayersMask": {bit: bit not in hidden for bit in range(len(LAYERS))},
        }
    return extended


def apply_forced_options(mission_content: dict, block: dict) -> None:
    """Write a valid ``mission.forced_options`` block into the mission's ``forcedOptions``.

    Args:
        mission_content: The parsed DCS ``mission`` table (mutated in place).
        block: The ``mission.forced_options`` block, already checked by :func:`forced_options_errors`.
    """
    forced = mission_content.setdefault("forcedOptions", {})
    for name, value in block.items():
        if name == F10_VIEW_BY_ROLE:
            forced["optionsView"] = F10_VIEW_EXTENDED
            forced["optionsViewExtended"] = _extended_view(value)
            continue
        option = OPTIONS[name]
        forced[option.dcs_key] = option.choices[value] if option.choices else value
