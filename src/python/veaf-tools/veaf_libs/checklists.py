"""Guided-checklist definitions: the YAML format, its validation and its loading.

A *checklist* drives the in-game assistance module (``veafAssist``): it names the
cockpit element to box for each step, and how that step is validated — automatically
from an animation argument, or by the pilot confirming it. See
``.backlog/FEAT-ASSIST-CHECKLISTS/PRD.md``.

The YAML is **design-time only**. DCS has no YAML reader, so the build converts each
checklist into a Lua table embedded in the ``.miz``; the emission itself lives in
:mod:`veaf_libs.lua_config_generator`, the authoritative YAML-to-Lua path.

Two sources, later overriding earlier by ``id``:

1. the VMCT catalogue shipped under ``veaf_libs/data/checklists/``;
2. the ``checklists/`` folder of the mission, where a mission maker adds their own.

Sidecar files rather than blocks of ``mission.yaml``, per the call in
``docs/adr/0016-ctld2-sidecar-configuration.md``.
"""

from __future__ import annotations

from collections.abc import Collection, Mapping, Sequence
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator

from veaf_libs.bundled_data import bundled_dir, read_bundled_text
from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Folder holding the checklist files, both in the mission folder and in the catalogue.
CHECKLISTS_FOLDER_NAME = "checklists"

#: Half-width of the acceptance window when a step gives ``equals`` without ``tolerance``.
#: Sized for the 0/1 parameters that make up most of what an aircraft publishes (gear
#: down, flaps retracted, weight on wheels). A physical quantity — an altitude, a speed —
#: needs its own ``tolerance`` or a ``range``; 0.05 metres would never match.
DEFAULT_TOLERANCE = 0.05

#: Decimal places kept when resolving a window, so ``0.5 - 0.05`` emits ``0.45`` rather
#: than the binary-float noise Lua would then have to compare against.
_WINDOW_PRECISION = 6


class ChecklistError(ValueError):
    """A checklist file the build refuses: unreadable, invalid, or a duplicate id.

    Raised with a message naming the offending file, so a mission maker's typo surfaces
    at build time rather than as a Lua error in game.
    """


class ChecklistStep(BaseModel):
    """One line of a checklist: what to do, and how we know it is done.

    A step carries **exactly one** validation mode. ``param`` reads a live cockpit
    parameter and compares it against a window; ``check`` names a check the engine
    registered (the extension point for later checklists); ``confirm`` waits for the
    pilot to tick the line from the radio menu. A step declaring none of the three is a
    confirm step — but it must then at least box an ``element``, otherwise it says
    nothing at all.

    **There is deliberately no way to validate a step on the position of a cockpit
    control.** It cannot be read from the mission environment — measured in game, see
    ``docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md`` section 3 — so the old
    ``argument:`` field is rejected rather than silently never firing. What *is* readable
    is the **effect** a control produces: altitude, speed, heading, gear, canopy, flaps,
    fuel. That is what ``param`` reads.

    Attributes:
        label: i18n catalog key, or a literal string (``veaf.t()`` returns an unknown
            key unchanged, so a mission maker can write plain text).
        element: Cockpit element to box. Optional, and independent of the validation
            mode: a gauge can be boxed while the pilot is the one who says it is good.
        param: Cockpit parameter to read, e.g. ``BASE_SENSOR_NOSE_GEAR_DOWN``.
        equals: Target value of *param*; the window is ``equals ± tolerance``.
        tolerance: Half-width of the window around *equals*.
        range: Explicit ``[min, max]`` window, for a value with a wide span.
        confirm: Ticked by the pilot rather than measured.
        check: ``{type: <name>, …}`` — a named check with its parameters.
        argument: **Rejected.** Kept in the model only so the error can explain why.
        device: DCS cockpit device id, carried for a future demonstration mode.
        command: DCS cockpit command id, carried for a future demonstration mode.
    """

    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1)
    element: str | None = None
    param: str | None = None
    equals: float | None = None
    tolerance: float | None = None
    range: list[float] | None = None
    confirm: bool = False
    check: dict[str, Any] | None = None
    argument: int | None = None
    device: int | None = None
    command: int | None = None

    @model_validator(mode="after")
    def _exactly_one_validation_mode(self) -> ChecklistStep:
        """Reject a step whose validation modes conflict, or whose window is incomplete."""
        if self.argument is not None:
            raise ValueError(
                "a cockpit control's position cannot be read from the mission environment, so "
                "'argument' can never validate a step — use 'confirm: true', or 'param' on a value "
                "the aircraft publishes (see docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md)"
            )

        declared = [
            name
            for name, present in (
                ("param", self.param is not None),
                ("check", self.check is not None),
                ("confirm", self.confirm),
            )
            if present
        ]
        if len(declared) > 1:
            raise ValueError(f"a step declares exactly one validation mode, found {' + '.join(declared)}")

        if self.tolerance is not None and self.equals is None:
            raise ValueError("tolerance only makes sense with equals")
        if self.equals is not None and self.param is None:
            raise ValueError("equals needs the param it applies to")
        if self.range is not None and self.param is None:
            raise ValueError("range needs the param it applies to")
        if self.equals is not None and self.range is not None:
            raise ValueError("equals and range are mutually exclusive")
        if self.param is not None and self.equals is None and self.range is None:
            raise ValueError("a param step needs an acceptance window: equals or range")
        if self.range is not None and (len(self.range) != 2 or self.range[0] >= self.range[1]):
            raise ValueError("range is [min, max] with min < max")

        if self.check is not None and not str(self.check.get("type") or "").strip():
            raise ValueError("a named check needs a type")

        if self.element is None and not declared:
            raise ValueError("a step with no element and no validation mode says nothing")
        return self

    def check_table(self) -> dict[str, Any]:
        """Return the check the engine runs for this step, windows already resolved.

        Resolving ``equals``/``tolerance`` here keeps the runtime comparison a plain
        ``min <= value <= max`` — the arithmetic is design-time work.

        Returns:
            The check descriptor, always carrying a ``type``.
        """
        if self.check is not None:
            return dict(self.check)
        if self.param is None:
            return {"type": "confirm"}
        if self.equals is not None:
            tolerance = DEFAULT_TOLERANCE if self.tolerance is None else self.tolerance
            low, high = self.equals - tolerance, self.equals + tolerance
        else:
            # The validator guarantees a range whenever equals is absent.
            window = self.range or [0.0, 0.0]
            low, high = window[0], window[1]
        return {
            "type": "cockpit_param",
            "param": self.param,
            "min": round(low, _WINDOW_PRECISION),
            "max": round(high, _WINDOW_PRECISION),
        }


class Checklist(BaseModel):
    """A complete checklist: what it is called, what it applies to, and its steps.

    Attributes:
        id: Unique identifier, and the key a mission's own file overrides.
        title: i18n catalog key, or a literal string.
        aircraft: DCS type names the checklist applies to.
        menu: Slot under the ``Assistance`` radio menu.
        steps: The lines, in the order the pilot walks them.
    """

    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    aircraft: list[str] = Field(min_length=1)
    menu: str = Field(min_length=1)
    steps: list[ChecklistStep] = Field(min_length=1)

    @field_validator("aircraft")
    @classmethod
    def _known_aircraft_types(cls, value: list[str]) -> list[str]:
        """Reject a DCS type name absent from the shipped unit catalogue."""
        known = _known_unit_types()
        if not known:
            return value
        unknown = [name for name in value if name not in known]
        if unknown:
            raise ValueError(f"unknown DCS aircraft type(s): {', '.join(unknown)}")
        return value


@lru_cache(maxsize=1)
def _known_unit_types() -> frozenset[str]:
    """Return the DCS type ids of the shipped unit catalogue.

    Returns:
        The known type ids, or an empty set when the catalogue cannot be read — in
        which case type validation is skipped rather than rejecting every checklist.
    """
    try:
        raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcsUnits.yaml")) or {}
    except (OSError, ModuleNotFoundError, yaml.YAMLError):
        logger.warning(t("checklist.units_catalogue_unavailable"))
        return frozenset()
    return frozenset(str(entry["type"]) for entry in (raw.get("units") or []) if entry.get("type"))


def _format_validation_error(error: ValidationError) -> str:
    """Render a pydantic error as a one-line, field-by-field summary."""
    parts: list[str] = []
    for item in error.errors():
        location = ".".join(str(piece) for piece in item["loc"]) or "<root>"
        message = str(item["msg"]).removeprefix("Value error, ")
        parts.append(f"{location}: {message}")
    return "; ".join(parts)


def parse_checklist(raw: dict[str, Any], source: str) -> Checklist:
    """Validate one checklist definition.

    Args:
        raw: The parsed YAML mapping.
        source: File name quoted in the error message.

    Returns:
        The validated checklist.

    Raises:
        ChecklistError: if the definition breaks any rule of the format.
    """
    try:
        return Checklist.model_validate(raw)
    except ValidationError as error:
        raise ChecklistError(t("checklist.invalid", source=source, details=_format_validation_error(error))) from error


def _load_folder(folder: Path, into: dict[str, Checklist]) -> None:
    """Parse every checklist file of *folder* into *into*, later files overriding by id.

    Args:
        folder: Directory to read; a missing one simply contributes nothing.
        into: Accumulator, keyed by checklist id.

    Raises:
        ChecklistError: on an unreadable file, an invalid definition, or two files of
            this folder declaring the same id.
    """
    if not folder.is_dir():
        return
    seen: dict[str, str] = {}
    for path in sorted(folder.glob("*.y*ml")):
        try:
            raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except (OSError, yaml.YAMLError) as error:
            raise ChecklistError(t("checklist.unreadable", source=path.name, details=error)) from error
        if not isinstance(raw, dict):
            raise ChecklistError(t("checklist.invalid", source=path.name, details="expected a mapping"))
        checklist = parse_checklist(raw, source=path.name)
        if checklist.id in seen:
            raise ChecklistError(
                t("checklist.duplicate_id", id=checklist.id, first=seen[checklist.id], second=path.name)
            )
        seen[checklist.id] = path.name
        into[checklist.id] = checklist


def load_mission_checklists(mission_folder: Path) -> dict[str, Checklist]:
    """Load only the checklists a mission ships in its own ``checklists/`` folder.

    Kept separate from :func:`load_checklists` because "the mission maker put this file
    here" is what activates a checklist when ``mission.yaml`` gives no explicit list.

    Args:
        mission_folder: The mission folder.

    Returns:
        The mission's own checklists, keyed by ``id`` (empty when it has none).

    Raises:
        ChecklistError: on any invalid or duplicated definition.
    """
    result: dict[str, Checklist] = {}
    _load_folder(mission_folder / CHECKLISTS_FOLDER_NAME, result)
    return result


def select_activated(
    available: Mapping[str, Checklist],
    configured_ids: Sequence[str] | None,
    mission_ids: Collection[str] = (),
) -> list[Checklist]:
    """Return the checklists a mission activates, in a stable order.

    Two rules, and the second is the one that makes the common case need no configuration:

    - an explicit ``checklists:`` list in ``mission.yaml`` wins, and an id it names that
      no source provides is a build error rather than a silently missing menu entry;
    - with no list, the checklists the mission maker dropped in its own ``checklists/``
      folder are activated. **Never the whole VMCT catalogue** — every activated checklist
      costs images in the ``.miz``, so activating a catalogue by accident is not an option.

    Args:
        available: Every checklist that could be activated, catalogue and mission merged.
        configured_ids: The ``checklists:`` list, or ``None`` when the key is absent.
        mission_ids: Ids the mission ships in its own folder.

    Returns:
        The activated checklists, sorted by id.

    Raises:
        ChecklistError: when the configured list names an unknown id.
    """
    if configured_ids is None:
        chosen = {str(entry) for entry in mission_ids}
    else:
        chosen = {str(entry) for entry in configured_ids}
        unknown = sorted(entry for entry in chosen if entry not in available)
        if unknown:
            raise ChecklistError(
                t("checklist.unknown_id", ids=", ".join(unknown), known=", ".join(sorted(available)) or "none")
            )
    return [available[checklist_id] for checklist_id in sorted(chosen) if checklist_id in available]


def load_checklists(mission_folder: Path | None = None, catalogue_dir: Path | None = None) -> dict[str, Checklist]:
    """Load the checklists available to a mission: catalogue first, mission folder last.

    Args:
        mission_folder: The mission folder; its ``checklists/`` subfolder overrides the
            catalogue by ``id``. ``None`` loads the catalogue alone.
        catalogue_dir: The VMCT catalogue. Defaults to the shipped one.

    Returns:
        The checklists, keyed by ``id``.

    Raises:
        ChecklistError: on any invalid or duplicated definition.
    """
    if catalogue_dir is None:
        catalogue_dir = bundled_dir("veaf_libs", "data", CHECKLISTS_FOLDER_NAME)
    result: dict[str, Checklist] = {}
    _load_folder(catalogue_dir, result)
    if mission_folder is not None:
        _load_folder(mission_folder / CHECKLISTS_FOLDER_NAME, result)
    return result
