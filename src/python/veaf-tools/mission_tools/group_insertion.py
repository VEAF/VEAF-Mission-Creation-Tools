"""Reusable id bookkeeping, country lookup and group insertion for a DCS mission.

Generalizes the group-insertion logic first proven in
``mission_builder.coalition_placeholder`` (placeholder ground units) so any caller —
that module included — can append a group to a mission without duplicating the
id-allocation/country-lookup bookkeeping.
"""

import copy
from typing import Any

from veaf_libs.i18n import t
from veaf_libs.logger import logger

GROUP_CATEGORIES: tuple[str, ...] = ("vehicle", "plane", "helicopter", "ship", "static")


def max_ids(mission_content: dict[str, Any]) -> tuple[int, int]:
    """Return the highest groupId and unitId currently used in the mission.

    Args:
        mission_content: The parsed DCS `mission` table.

    Returns:
        `(max_group_id, max_unit_id)`.
    """
    max_group_id = 0
    max_unit_id = 0
    for coalition in mission_content.get("coalition", {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country", []):
            for category in GROUP_CATEGORIES:
                for group in country.get(category, {}).get("group", []):
                    max_group_id = max(max_group_id, int(group.get("groupId", 0) or 0))
                    for unit in group.get("units", []):
                        max_unit_id = max(max_unit_id, int(unit.get("unitId", 0) or 0))
    return max_group_id, max_unit_id


def coerce_country_list(coalition: dict[str, Any]) -> list[Any]:
    """Normalize a coalition's `country` field to a list (in place).

    An empty DCS `country = {}` table deserializes to a dict (all_is_dict), not a
    list, which breaks the unit-count / id scans and the group append. A dict is
    coerced keeping its values; anything else (malformed) is replaced by an empty
    list with a warning rather than silently iterated/discarded.

    Args:
        coalition: The coalition dict to normalize (mutated in place).

    Returns:
        The coalition's `country` list.
    """
    countries = coalition.get("country")
    if isinstance(countries, list):
        return countries
    if isinstance(countries, dict):
        countries = list(countries.values())
    else:
        if countries is not None:
            logger.warning(t("builder.coalition_country_unexpected", type=type(countries).__name__))
        countries = []
    coalition["country"] = countries
    return countries


def find_or_add_country(coalition: dict[str, Any], country_id: int, country_name: str) -> dict[str, Any]:
    """Return the coalition country with `country_id`, creating it if absent.

    Args:
        coalition: The coalition dict to search (mutated in place if the country
            doesn't exist yet).
        country_id: The DCS numeric country id.
        country_name: The DCS country name, used only if the country is created.

    Returns:
        The country dict.
    """
    countries = coerce_country_list(coalition)
    for country in countries:
        if country.get("id") == country_id:
            return country
    country = {"id": country_id, "name": country_name}
    countries.append(country)
    return country


def add_group(
    mission_content: dict[str, Any],
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    category: str,
    group: dict[str, Any],
) -> int:
    """Insert `group` into the mission, allocating a fresh groupId/unitId.

    Mirrors what a Mission Maker does by hand in the DCS Mission Editor: appends
    `group` under the given coalition/country/category. Not deduplicated — calling
    this twice with the same `group` produces two distinct groups.

    Args:
        mission_content: The parsed DCS `mission` table (mutated in place).
        coalition: `"blue"`, `"red"` or `"neutral"`.
        country_id: The DCS numeric country id (e.g. 0 for Russia).
        country_name: The DCS country name (e.g. `"Russia"`), used only if the
            country does not exist yet in this coalition.
        category: One of `GROUP_CATEGORIES` (`"vehicle"`, `"plane"`, ...).
        group: The group dict to insert (`name`, `units`, `route`, ...). Only
            `groupId` and each unit's `unitId` are overwritten; everything else is
            taken as-is.

    Returns:
        The freshly-assigned `groupId`.

    Raises:
        ValueError: If `category` is not a recognized group category.
        KeyError: If `coalition` does not exist in the mission.
    """
    if category not in GROUP_CATEGORIES:
        raise ValueError(f"Unknown group category: {category!r} (expected one of {GROUP_CATEGORIES})")
    coalitions = mission_content.get("coalition") or {}
    if coalition not in coalitions or not isinstance(coalitions[coalition], dict):
        raise KeyError(f"Unknown coalition: {coalition!r}")
    coalition_dict = coalitions[coalition]

    next_group_id, next_unit_id = (n + 1 for n in max_ids(mission_content))

    group = copy.deepcopy(group)
    group["groupId"] = next_group_id
    units = group.get("units") or []
    if isinstance(units, dict):
        units = list(units.values())
    for unit in units:
        unit["unitId"] = next_unit_id
        next_unit_id += 1
    group["units"] = units

    country = find_or_add_country(coalition_dict, country_id, country_name)
    container = country.setdefault(category, {})
    groups = container.setdefault("group", [])
    if isinstance(groups, dict):
        groups = list(groups.values())
        container["group"] = groups
    groups.append(group)

    return next_group_id
