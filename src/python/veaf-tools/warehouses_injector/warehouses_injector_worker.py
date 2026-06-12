"""Apply a ``warehouses.yaml`` config to a mission's ``warehouses`` (DYNSLOT-WAREHOUSE).

Config shape (per coalition; an undeclared coalition is left untouched)::

    blue:
      defaults:                 # applied to every selected airport
        fuel: unlimited         # -> unlimitedFuel = true (omit to leave as-is)
        weapons: unlimited      # -> unlimitedMunitions = true
        aircrafts:              # aircraft types offered as dynamic slots
          UH-1H:   { amount: unlimited, template: "DST - UH-1H" }
          A-10C_2: { amount: 50 }            # template auto-matched by type
      airports:                 # optional; absent -> ALL airports of this coalition
        Senaki-Kolkhi: {}                    # name (resolved via the theatre) -> defaults
        24: { aircrafts: { Yak-52: { amount: 10 } } }   # id -> defaults + override

``template`` references a ``dynSpawnTemplate=true`` group by **name**; when omitted
it is auto-matched to a template group of the same **aircraft type** (same
coalition). The link is written as ``aircrafts[<type>].linkDynTempl = <groupId>``.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
from pathlib import Path

import yaml
from mission_tools import read_miz, write_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.base_worker import BaseWorker
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Config coalition keys mapped to the warehouses ``coalition`` field values.
_COALITION_FIELD = {"blue": "BLUE", "red": "RED", "neutral": "NEUTRAL"}


@dataclass
class WarehousesResult:
    """Outcome of a warehouse-wiring run."""

    airports_configured: int
    templates_linked: int


def _build_template_index(mission: DcsMission) -> dict[tuple[str, str, str], int]:
    """Index dynamic-spawn template groups by ``(coalition, "name"|"type", key)`` -> groupId.

    Args:
        mission: The parsed mission.

    Returns:
        A lookup mapping. The first template wins per (coalition, type).
    """
    index: dict[tuple[str, str, str], int] = {}
    for group in mission.iter_groups():
        if group.group_dcs.get("dynSpawnTemplate") is not True:
            continue
        group_id = group.group_dcs.get("groupId")
        if group_id is None:
            continue
        coalition = (group.coalition or "").lower()
        if group.name:
            index.setdefault((coalition, "name", group.name.lower()), int(group_id))
        if group.unit_type:
            index.setdefault((coalition, "type", group.unit_type.lower()), int(group_id))
    return index


def _resolve_template_group_id(
    index: dict[tuple[str, str, str], int],
    coalition_key: str,
    aircraft_type: str,
    template_name: str | None,
) -> int | None:
    """Resolve a template group id by explicit name, else by aircraft type."""
    coalition = coalition_key.lower()
    if template_name:
        return index.get((coalition, "name", template_name.lower()))
    return index.get((coalition, "type", aircraft_type.lower()))


def _resolve_airport_id(key: object, airports: dict, theatre: str) -> int | None:
    """Resolve an ``airports:`` key (id, numeric string, or airfield name) to an id."""
    if isinstance(key, int) and key in airports:
        return key
    text = str(key)
    if text.isdigit() and int(text) in airports:
        return int(text)
    resolved = airdrome_id_for_name(theatre, text)
    if resolved is not None and resolved in airports:
        return resolved
    return None


def _merge_settings(defaults: dict, override: dict | None) -> dict:
    """Deep-merge a per-airport override over the coalition defaults (aircrafts merged by type)."""
    merged = copy.deepcopy(defaults) if defaults else {}
    if not override:
        return merged
    for key, value in override.items():
        if key == "aircrafts" and isinstance(value, dict):
            aircrafts = merged.setdefault("aircrafts", {})
            for atype, acfg in value.items():
                aircrafts[atype] = {**aircrafts.get(atype, {}), **(acfg or {})}
        else:
            merged[key] = value
    return merged


def _apply_to_airport(
    airport: dict,
    settings: dict,
    template_index: dict[tuple[str, str, str], int],
    coalition_key: str,
) -> int:
    """Apply one airport's settings in place; return the number of templates linked."""
    airport["dynamicSpawn"] = True
    if settings.get("fuel") == "unlimited":
        airport["unlimitedFuel"] = True
    if settings.get("weapons") == "unlimited":
        airport["unlimitedMunitions"] = True

    linked = 0
    aircrafts_cfg = settings.get("aircrafts") or {}
    if aircrafts_cfg:
        stock = airport.setdefault("aircrafts", {})
        for aircraft_type, acfg in aircrafts_cfg.items():
            acfg = acfg or {}
            entry = stock.setdefault(aircraft_type, {})
            amount = acfg.get("amount")
            if amount == "unlimited":
                entry["unlimited"] = True
                entry.setdefault("initialAmount", 100)
            elif amount is not None:
                try:
                    entry["initialAmount"] = int(amount)
                    entry["unlimited"] = False
                except (TypeError, ValueError):
                    logger.warning(t("warehouses.invalid_amount", amount=amount, type=aircraft_type))
            group_id = _resolve_template_group_id(template_index, coalition_key, aircraft_type, acfg.get("template"))
            if group_id is not None:
                entry["linkDynTempl"] = group_id
                linked += 1
            elif acfg.get("template"):
                logger.warning(t("warehouses.template_not_found", template=acfg["template"], type=aircraft_type))
    return linked


def apply_warehouses(mission: DcsMission, config: dict) -> WarehousesResult:
    """Apply a ``warehouses.yaml`` config to a mission's warehouses in place.

    Args:
        mission: The parsed mission (its ``warehouses_content`` is mutated).
        config: The parsed ``warehouses.yaml`` (per-coalition mapping).

    Returns:
        Counts of airports configured and templates linked.
    """
    warehouses = mission.warehouses_content or {}
    airports = warehouses.get("airports") or {}
    if not airports:
        logger.warning(t("warehouses.no_airports"))
        return WarehousesResult(0, 0)

    theatre = str(mission.theatre_content or "")
    template_index = _build_template_index(mission)

    airports_configured = 0
    templates_linked = 0
    for coalition_key, field_value in _COALITION_FIELD.items():
        coalition_cfg = config.get(coalition_key)
        if not isinstance(coalition_cfg, dict):
            continue  # coalition not declared -> leave untouched
        defaults = coalition_cfg.get("defaults") or {}
        airports_cfg = coalition_cfg.get("airports")

        if airports_cfg:
            targets = {}
            for key, override in airports_cfg.items():
                airport_id = _resolve_airport_id(key, airports, theatre)
                if airport_id is None:
                    logger.warning(t("warehouses.airport_not_found", airport=key, theatre=theatre or "?"))
                    continue
                targets[airport_id] = _merge_settings(defaults, override if isinstance(override, dict) else {})
        else:
            # No explicit list -> all airports of this coalition get the defaults.
            targets = {
                aid: defaults for aid, a in airports.items() if str(a.get("coalition", "")).upper() == field_value
            }

        for airport_id, settings in targets.items():
            templates_linked += _apply_to_airport(airports[airport_id], settings, template_index, coalition_key)
            airports_configured += 1

    return WarehousesResult(airports_configured, templates_linked)


class WarehousesInjectorWorker(BaseWorker):
    """Apply a ``warehouses.yaml`` config to a ``.miz`` (Dynamic-Slot wiring)."""

    def __init__(self, config_file: Path, input_mission: Path, output_mission: Path) -> None:
        """Initialize the worker.

        Args:
            config_file: Path to ``warehouses.yaml``.
            input_mission: Source ``.miz``.
            output_mission: Destination ``.miz`` (may equal the source).
        """
        self.config_file = config_file
        self.input_mission = input_mission
        self.output_mission = output_mission

    def work(self) -> WarehousesResult:
        """Read the mission, apply the config, write it back.

        Returns:
            The run result (airports configured, templates linked).
        """
        config = yaml.safe_load(self.config_file.read_text(encoding="utf-8")) or {}
        mission = read_miz(self.input_mission)
        result = apply_warehouses(mission, config)
        write_miz(mission=mission, miz_file_path=self.output_mission)
        logger.info(t("warehouses.done", airports=result.airports_configured, templates=result.templates_linked))
        return result
