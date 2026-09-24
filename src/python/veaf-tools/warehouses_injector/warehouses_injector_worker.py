"""Apply a ``warehouses.yaml`` config to a mission's ``warehouses`` (DYNSLOT-WAREHOUSE).

Config shape (per coalition; an undeclared coalition is left untouched)::

    blue:
      defaults:                 # applied to every selected airport
        fuel: unlimited         # -> unlimitedFuel = true (omit to leave as-is)
        weapons: unlimited      # -> unlimitedMunitions = true
        hot_start: false        # -> allowHotStart = false (default: true, engines running)
        aircrafts:              # aircraft types offered as dynamic slots
          UH-1H:   { amount: unlimited, template: "DST - UH-1H" }
          A-10C_2: { amount: 50 }            # template auto-matched by type
      airports:                 # optional; absent -> ALL airports of this coalition
        Senaki-Kolkhi: {}                    # name (resolved via the theatre) -> defaults
        24: { aircrafts: { Yak-52: { amount: 10 } } }   # id -> defaults + override
      exclude_airports:         # optional; these never get slots, listed or not
        - Kobuleti                           # what set_airbase_coalition(dynamic_spawn=false) writes
      ships:                    # optional; absent -> ALL ships of this coalition
        CSG-74 Stennis: {}                   # unit name, or the unit id
      farps:                    # optional; absent -> ALL FARPs of this coalition
        FARP Kaspi MM54: {}

The three selector keys default **independently**: naming a ship says nothing about the FARPs,
which still get the coalition defaults.

``template`` references a ``dynSpawnTemplate=true`` group by **name**; when omitted
it is auto-matched to a template group of the same **aircraft type** (same
coalition). The link is written as
``aircrafts[<helicopters|planes>][<type>].linkDynTempl = <groupId>`` — DCS nests
dynamic-slot aircraft by category, and a flat entry is silently ignored.

Whatever the config asks for, a warehouse is only stocked with what it can **host**: DCS offers a
dynamic slot only where the aircraft fits, so a helipad-only field offers helicopters and nothing
else. For an airfield that comes from the bundled parking dumps (Caucasus, Persian Gulf, Syria) and
on a theatre with no dump nothing is filtered; for a ship or a FARP it comes from the unit type —
``AircraftCarrier`` takes planes and helicopters, ``HelicopterCarrier`` or a ``Heliport`` takes
helicopters, and a ship that is neither is left untouched.
"""

from __future__ import annotations

import copy
import functools
from dataclasses import dataclass
from pathlib import Path

import yaml
from mission_tools import read_miz, write_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.base_worker import BaseWorker
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import parkable_kinds
from veaf_libs.dcs_units_parser import parse_dcs_units
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger

#: Config coalition keys mapped to the warehouses ``coalition`` field values.
_COALITION_FIELD = {"blue": "BLUE", "red": "RED", "neutral": "NEUTRAL"}

#: DCS warehouses nest dynamic-slot aircraft under these sub-tables by category;
#: an aircraft entry placed at the wrong level (or flat) is ignored by DCS.
_CATEGORY_TO_WAREHOUSE = {"helicopter": "helicopters", "plane": "planes"}

#: Sub-table used when an aircraft type cannot be classified.
_DEFAULT_WAREHOUSE_CATEGORY = "planes"

#: Warehouse sub-table -> the parking kind :func:`veaf_libs.dcs_parking.parkable_kinds` reports.
_WAREHOUSE_TO_PARKING_KIND = {warehouse: kind for kind, warehouse in _CATEGORY_TO_WAREHOUSE.items()}

#: Config key -> the DCS units-DB category it selects, for the non-airfield warehouses.
#:
#: DCS keeps ships and FARPs in ``warehouses.warehouses``, keyed by the **unit id** of the object
#: carrying the warehouse, and offers dynamic slots there too. One key per family because that is
#: how a mission maker names them; both go through the same code below.
_OBJECT_KEY_TO_UNIT_CATEGORY = {"ships": "ship", "farps": "heliport"}

#: What an object can host, by DCS unit attribute. Measured 2026-09-22 against ``dcsUnits.yaml``:
#: 15 stock ships carry ``AircraftCarrier`` (Stennis, Tarawa, Kuznetsov, Invincible…), 19 more carry
#: only ``HelicopterCarrier`` — the Arleigh Burke among them, which does have a helipad — and 23
#: carry neither and host nothing. A ``Heliport`` (FARP, oil platform) takes helicopters.
#:
#: Read rather than guessed, because the cost of guessing is 64 plane types stocked on a frigate.
_CARRIER_ATTRIBUTE = "AircraftCarrier"
_HELICOPTER_CARRIER_ATTRIBUTE = "HelicopterCarrier"

#: Committed DCS units database (relative to this worker).
_DCS_UNITS_YAML = Path(__file__).resolve().parent.parent / "veaf_libs" / "data" / "dcsUnits.yaml"


@functools.lru_cache(maxsize=1)
def _dcs_unit_categories() -> dict[str, str]:
    """Map DCS aircraft type (lowercase) -> warehouse sub-table key, from the units DB.

    Used as a fallback to classify aircraft types that are not present as groups in
    the mission being built.
    """
    result: dict[str, str] = {}
    try:
        for unit in parse_dcs_units(_DCS_UNITS_YAML):
            key = _CATEGORY_TO_WAREHOUSE.get(unit.category.lower())
            if key:
                result[unit.type_id.lower()] = key
    except (OSError, ValueError):  # never break the build on a units-DB read issue
        return {}
    return result


def _build_mission_categories(mission: DcsMission) -> dict[str, str]:
    """Map aircraft type (lowercase) -> warehouse sub-table key, from the mission groups.

    Fallback for mod aircraft absent from the committed units DB. Only single-unit
    dynamic-spawn template groups are considered: a multi-unit group's reported
    ``unit_type`` is just its last unit, so the same type could otherwise be filed
    under both categories (planes and helicopters) depending on iteration order.
    """
    index: dict[str, str] = {}
    for group in mission.iter_groups():
        # Only single-unit templates: a multi-unit group's reported unit_type is
        # just its last unit, which would file the same type under both categories.
        if (
            group.unit_type
            and group.group_dcs.get("dynSpawnTemplate") is True
            and len(group.group_dcs.get("units") or []) == 1
        ):
            index[group.unit_type.lower()] = _CATEGORY_TO_WAREHOUSE.get(
                (group.aircraft_type or "").lower(), _DEFAULT_WAREHOUSE_CATEGORY
            )
    return index


def _warehouse_category(aircraft_type: str, mission_categories: dict[str, str]) -> str:
    """Resolve the warehouse sub-table ("helicopters"|"planes") for an aircraft type.

    The committed DCS units database is authoritative (unambiguous per type); the
    mission's dynamic-spawn templates are a fallback for mod aircraft absent from it.
    """
    key = aircraft_type.lower()
    category = _dcs_unit_categories().get(key) or mission_categories.get(key)
    if category:
        return category
    logger.warning(t("warehouses.unknown_category", type=aircraft_type))
    return _DEFAULT_WAREHOUSE_CATEGORY


@functools.lru_cache(maxsize=1)
def _object_capabilities() -> dict[str, tuple[str, frozenset[str]]]:
    """Map a DCS unit type (lowercase) -> (units-DB category, the parking kinds it can host).

    Only the types that can host something are worth an entry; everything else is left alone by
    the caller. See :data:`_CARRIER_ATTRIBUTE` for what was measured.

    Returns:
        Type id (lowercase) -> (units-DB category, parking kinds), empty if the DB cannot be read.
    """
    result: dict[str, tuple[str, frozenset[str]]] = {}
    try:
        units = list(parse_dcs_units(_DCS_UNITS_YAML))
    except (OSError, ValueError):  # never break the build on a units-DB read issue
        return {}
    for unit in units:
        category = unit.category.lower()
        if _CARRIER_ATTRIBUTE in unit.attributes:
            kinds = frozenset({"plane", "helicopter"})
        elif _HELICOPTER_CARRIER_ATTRIBUTE in unit.attributes or category == "heliport":
            kinds = frozenset({"helicopter"})
        else:
            continue
        result[unit.type_id.lower()] = (category, kinds)
    return result


@dataclass
class _WarehouseObject:
    """A ship or FARP that carries a warehouse, resolved back to the unit that holds it."""

    unit_id: int
    name: str
    unit_category: str
    parkable: frozenset[str]


def _resolve_warehouse_objects(mission: DcsMission) -> dict[int, _WarehouseObject]:
    """Index the mission's units by id, keeping only those that can host aircraft.

    The ``warehouses.warehouses`` table is keyed by unit id and carries no name, so targeting a
    carrier the way a mission maker names it means joining back to the mission. Ships live under
    ``country.ship`` and FARPs under ``country.static``, but the walk is category-agnostic on
    purpose: what an object can host is decided by its **type**, not by the table it sits in.

    Args:
        mission: The parsed mission, read only.

    Returns:
        Unit id -> the object it names, for the objects that can host aircraft. A type that hosts
        none is absent, which is what keeps a tanker or a cargo ship out of every selection.
    """
    objects: dict[int, _WarehouseObject] = {}
    capabilities = _object_capabilities()
    coalitions = (mission.mission_content or {}).get("coalition") or {}
    for coalition in coalitions.values() if isinstance(coalitions, dict) else []:
        for country in coalition.get("country") or []:
            for category_data in country.values():
                if not isinstance(category_data, dict) or "group" not in category_data:
                    continue
                for group in category_data.get("group") or []:
                    for unit in group.get("units") or []:
                        unit_id, unit_type = unit.get("unitId"), unit.get("type")
                        capability = capabilities.get(str(unit_type).lower())
                        if capability is None or not isinstance(unit_id, int):
                            continue
                        unit_category, parkable = capability
                        objects[unit_id] = _WarehouseObject(
                            unit_id=unit_id,
                            name=str(unit.get("name") or group.get("name") or ""),
                            unit_category=unit_category,
                            parkable=parkable,
                        )
    return objects


def _resolve_object_id(key: object, objects: dict[int, _WarehouseObject], category: str) -> int | None:
    """Resolve a ``ships:``/``farps:`` key (unit id, numeric string, or unit name) to a unit id."""
    candidates = {uid: obj for uid, obj in objects.items() if obj.unit_category == category}
    text = str(key)
    if isinstance(key, int) and key in candidates:
        return key
    if text.isdigit() and int(text) in candidates:
        return int(text)
    for unit_id, obj in candidates.items():
        if obj.name.lower() == text.lower():
            return unit_id
    return None


@dataclass
class WarehousesResult:
    """Outcome of a warehouse-wiring run."""

    airports_configured: int
    templates_linked: int
    objects_configured: int = 0
    """Ships and FARPs configured — the ``warehouses.warehouses`` table, apart from the airfields."""
    dead_links: int = 0
    """``linkDynTempl`` values left in the mission that no template group answers to."""
    templates_available: int = 0
    """Dynamic-spawn templates the mission holds, whether or not anything offers them."""


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


def _excluded_airports(excluded: object, airports: dict, theatre: str) -> dict[int, str]:
    """Resolve an ``exclude_airports:`` list to airport ids, warning about the ones nothing matches.

    Args:
        excluded: The raw ``exclude_airports`` value (a list of names or ids), or anything else.
        airports: The mission's ``warehouses.airports`` table.
        theatre: The mission's theatre, for name resolution.

    Returns:
        The ids to keep closed, each with the entry as the maker wrote it, for the messages.
    """
    if not isinstance(excluded, list):
        return {}
    ids: dict[int, str] = {}
    for key in excluded:
        airport_id = _resolve_airport_id(key, airports, theatre)
        if airport_id is None:
            logger.warning(t("warehouses.airport_not_found", airport=key, theatre=theatre or "?"))
        else:
            ids[airport_id] = str(key)
    return ids


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


def _coalition_template_types(mission: DcsMission) -> dict[str, list[str]]:
    """Map each coalition (lower-case) to the aircraft types owning a dynamic-spawn template.

    Types keep their original case (unlike :func:`_build_template_index`, which lower-cases its
    keys) because they become DCS warehouse `aircrafts` keys, which are case-sensitive.
    """
    types: dict[str, list[str]] = {}
    for group in mission.iter_groups():
        if group.group_dcs.get("dynSpawnTemplate") is not True:
            continue
        if group.group_dcs.get("groupId") is None or not group.unit_type:
            continue
        bucket = types.setdefault((group.coalition or "").lower(), [])
        if group.unit_type not in bucket:
            bucket.append(group.unit_type)
    return types


def _prune_unparkable_stock(warehouse: dict, parkable: frozenset[str] | None) -> None:
    """Drop the stock sub-tables this warehouse cannot host, in place.

    Skipping the write is not enough on a mission built before this check: the source ``.miz`` keeps
    whatever an earlier build wrote (measured on ``OpenTraining_Syria_20260830.miz``: 144 plane types
    still stocked at Lakatamia, which has nothing but helipads). What DCS can never offer is dead
    weight, so it goes. Only a warehouse the config targets is touched, and only where the capacity
    is known — an airfield's from the bundled parking dumps, a ship's or a FARP's from the unit type.

    Args:
        warehouse: The airport's or object's warehouse entry, mutated in place.
        parkable: Which kinds it can host, or ``None`` to leave everything alone.
    """
    if parkable is None:
        return
    stock = warehouse.get("aircrafts")
    if not isinstance(stock, dict):
        return
    for sub_table, kind in _WAREHOUSE_TO_PARKING_KIND.items():
        if kind not in parkable:
            stock.pop(sub_table, None)


def _apply_to_warehouse(
    warehouse: dict,
    settings: dict,
    template_index: dict[tuple[str, str, str], int],
    coalition_key: str,
    mission_categories: dict[str, str],
    auto_fill_types: list[str],
    parkable: frozenset[str] | None,
    template_group_ids: frozenset[int],
) -> int:
    """Apply one warehouse's settings in place; return the number of templates linked.

    Serves an airfield and a ship/FARP alike: the two DCS tables differ by how an entry is keyed
    and by how its capacity is known, not by what has to be written into it.

    Args:
        warehouse: The airport's or object's warehouse entry, mutated in place.
        settings: The merged settings for this warehouse.
        template_index: The dynamic-spawn template lookup.
        coalition_key: The config coalition key ("blue", "red", "neutral").
        mission_categories: Aircraft type -> warehouse sub-table, from the mission's templates.
        auto_fill_types: Aircraft types stocked when the config lists none.
        parkable: Which kinds it can host — for an airfield, from
            :func:`veaf_libs.dcs_parking.parkable_kinds`; for a ship or a FARP, from its unit type
            — or ``None`` to stock everything.
        template_group_ids: Every dynamic-spawn template the mission holds. Required rather than
            defaulted: it is what :func:`_drop_dead_links` keeps, so an empty value erases every
            link in the warehouse. A caller must not be able to do that by forgetting an argument.
    """
    warehouse["dynamicSpawn"] = True
    # A dynamic slot is worth little if the pilot cannot take it with the engines running: the DCS
    # Mission Editor writes `allowHotStart = false`, and an airfield the mission deliberately opened
    # to dynamic slots wants the opposite. `hot_start: false` in the config says otherwise.
    warehouse["allowHotStart"] = settings.get("hot_start", True) is not False
    if settings.get("fuel") == "unlimited":
        warehouse["unlimitedFuel"] = True
    if settings.get("weapons") == "unlimited":
        warehouse["unlimitedMunitions"] = True

    _prune_unparkable_stock(warehouse, parkable)

    linked = 0
    aircrafts_cfg = settings.get("aircrafts") or {}
    if not aircrafts_cfg:
        # No explicit aircraft list -> auto-fill: stock every dynamic template of this coalition
        # (unlimited), so a base just assigned to a side is playable out of the box. An explicit
        # `aircrafts:` in the config overrides this. Types keep their original case (the index is
        # lower-cased, which would mis-key the DCS warehouse), hence `auto_fill_types`.
        aircrafts_cfg = {atype: {"amount": "unlimited"} for atype in auto_fill_types}
    if aircrafts_cfg:
        stock = warehouse.setdefault("aircrafts", {})
        for aircraft_type, acfg in aircrafts_cfg.items():
            acfg = acfg or {}
            # DCS nests dynamic-slot aircraft under aircrafts.{helicopters,planes};
            # a flat entry is silently ignored (template never binds).
            category = _warehouse_category(aircraft_type, mission_categories)
            # DCS only offers what the airfield can park: a helipad-only field offers helicopters
            # whatever the stock says (measured in game on 2026-08-31 at Lakatamia and Naqoura, where
            # 149 plane types were stocked and none was ever offered). Silently drop what the terrain
            # cannot take — it is noise in the mission and an unreadable Resource Manager. `None`
            # means no parking data ships for this theatre, so nothing is filtered.
            if parkable is not None and _WAREHOUSE_TO_PARKING_KIND.get(category) not in parkable:
                continue
            entry = stock.setdefault(category, {}).setdefault(aircraft_type, {})
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
            else:
                # Nothing to link this type to, so a `linkDynTempl` an earlier build left behind has
                # to go: it points at a group id that may no longer exist, which DCS renders as
                # `Group template: None` and nothing reports (FIX-DYNSLOT-WIRING).
                entry.pop("linkDynTempl", None)
                if acfg.get("template"):
                    logger.warning(t("warehouses.template_not_found", template=acfg["template"], type=aircraft_type))

    _drop_dead_links(warehouse, template_group_ids)
    return linked


def _drop_dead_links(warehouse: dict, template_group_ids: frozenset[int]) -> None:
    """Remove every ``linkDynTempl`` of this warehouse that no template group answers to.

    The loop above only visits the types the config or the auto-fill names, so a link left by an
    earlier build on any **other** type survives it. Measured on ``test-import.miz``: 65 distinct
    link targets, not one of them a group the mission still holds, and 42 of those above its
    largest ``groupId`` — the fingerprint of template groups that existed and were deleted. DCS
    renders such a link as ``Group template: None``, which reads like a configuration choice.

    Args:
        warehouse: The warehouse entry, mutated in place.
        template_group_ids: The group ids of every dynamic-spawn template the mission holds.
    """
    stock = warehouse.get("aircrafts")
    if not isinstance(stock, dict):
        return
    for sub_table in stock.values():
        if not isinstance(sub_table, dict):
            continue
        for entry in sub_table.values():
            if isinstance(entry, dict) and entry.get("linkDynTempl") not in template_group_ids:
                entry.pop("linkDynTempl", None)


def apply_warehouses(mission: DcsMission, config: dict) -> WarehousesResult:
    """Apply a ``warehouses.yaml`` config to a mission's warehouses in place.

    Args:
        mission: The parsed mission (its ``warehouses_content`` is mutated).
        config: The parsed ``warehouses.yaml`` (per-coalition mapping).

    Returns:
        Counts of airports and objects configured, and of templates linked.
    """
    warehouses = mission.warehouses_content or {}
    airports = warehouses.get("airports") or {}
    objects_table = warehouses.get("warehouses") or {}
    if not airports and not objects_table:
        logger.warning(t("warehouses.no_airports"))
        return WarehousesResult(0, 0)

    theatre = str(mission.theatre_content or "")
    template_index = _build_template_index(mission)
    template_types = _coalition_template_types(mission)
    mission_categories = _build_mission_categories(mission)
    objects = _resolve_warehouse_objects(mission)
    template_group_ids = frozenset(
        int(group.group_dcs["groupId"])
        for group in mission.iter_groups()
        if group.group_dcs.get("dynSpawnTemplate") is True and isinstance(group.group_dcs.get("groupId"), int)
    )

    airports_configured = 0
    objects_configured = 0
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

        # FIX-SCRATCH-MISSION-FINDINGS ticket 15: `set_airbase_coalition(dynamic_spawn=false)` wrote
        # `dynamicSpawn = false`, and this loop turned it back on for every base of the side. The
        # action now records the base here, and the record wins over the default and the list alike.
        for airport_id, written in _excluded_airports(coalition_cfg.get("exclude_airports"), airports, theatre).items():
            if airport_id in targets and airports_cfg:
                logger.warning(t("warehouses.airport_listed_and_excluded", airport=written))
            targets.pop(airport_id, None)

        for airport_id, settings in targets.items():
            templates_linked += _apply_to_warehouse(
                airports[airport_id],
                settings,
                template_index,
                coalition_key,
                mission_categories,
                template_types.get(coalition_key, []),
                parkable_kinds(theatre, airport_id),
                template_group_ids,
            )
            airports_configured += 1

        # Ships and FARPs live in the other DCS warehouse table, keyed by the unit id of the object
        # that carries them. Same settings, same auto-fill; what differs is how a target is named
        # and how its capacity is known — from the unit type rather than from a parking dump.
        for config_key, unit_category in _OBJECT_KEY_TO_UNIT_CATEGORY.items():
            objects_cfg = coalition_cfg.get(config_key)
            if isinstance(objects_cfg, dict):
                object_targets = {}
                for key, override in objects_cfg.items():
                    unit_id = _resolve_object_id(key, objects, unit_category)
                    if unit_id is None or unit_id not in objects_table:
                        logger.warning(t("warehouses.object_not_found", object=key, kind=config_key))
                        continue
                    object_targets[unit_id] = _merge_settings(defaults, override if isinstance(override, dict) else {})
            else:
                # Key absent -> every object of that family on this side, as `airports:` behaves.
                # An object whose type hosts no aircraft is not in `objects` at all, so a tanker or
                # a cargo ship is never touched.
                object_targets = {
                    uid: defaults
                    for uid, obj in objects.items()
                    if obj.unit_category == unit_category
                    and uid in objects_table
                    and str(objects_table[uid].get("coalition", "")).upper() == field_value
                }

            for unit_id, settings in object_targets.items():
                templates_linked += _apply_to_warehouse(
                    objects_table[unit_id],
                    settings,
                    template_index,
                    coalition_key,
                    mission_categories,
                    template_types.get(coalition_key, []),
                    objects[unit_id].parkable,
                    template_group_ids,
                )
                objects_configured += 1

    dead_links = _audit_wiring(warehouses, template_group_ids)
    if dead_links:
        logger.warning(t("warehouses.dead_links", count=dead_links))
    if template_group_ids and not airports_configured and not objects_configured:
        logger.warning(t("warehouses.nothing_to_offer_from", templates=len(template_group_ids)))

    return WarehousesResult(
        airports_configured,
        templates_linked,
        objects_configured,
        dead_links=dead_links,
        templates_available=len(template_group_ids),
    )


def _audit_wiring(warehouses: dict, template_group_ids: frozenset[int]) -> int:
    """Count the ``linkDynTempl`` values, anywhere in the mission, that resolve to no template.

    The step only cleans the warehouses it targets, so a side the config does not declare keeps
    whatever an earlier build left there. Counting the rest is what turns "the Mission Editor shows
    Group template: None" from something a mission maker has to notice into something the build
    says out loud.

    Args:
        warehouses: The mission's whole ``warehouses`` table, read only.
        template_group_ids: The group ids of every dynamic-spawn template the mission holds.

    Returns:
        How many links resolve to no template.
    """
    dead = 0
    for table in ("airports", "warehouses"):
        entries = warehouses.get(table) or {}
        for entry in entries.values() if isinstance(entries, dict) else []:
            stock = (entry or {}).get("aircrafts")
            if not isinstance(stock, dict):
                continue
            for sub_table in stock.values():
                if not isinstance(sub_table, dict):
                    continue
                for aircraft in sub_table.values():
                    link = aircraft.get("linkDynTempl") if isinstance(aircraft, dict) else None
                    if link is not None and link not in template_group_ids:
                        dead += 1
    return dead


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
            The run result (airports and objects configured, templates linked).
        """
        config = yaml.safe_load(self.config_file.read_text(encoding="utf-8")) or {}
        mission = read_miz(self.input_mission)
        result = apply_warehouses(mission, config)
        write_miz(mission=mission, miz_file_path=self.output_mission)
        logger.info(
            t(
                "warehouses.done",
                airports=tn("pipeline.console.warehouses_airports", result.airports_configured),
                objects=tn("pipeline.console.warehouses_objects", result.objects_configured),
                templates=tn("pipeline.console.warehouses_templates", result.templates_linked),
            )
        )
        return result
