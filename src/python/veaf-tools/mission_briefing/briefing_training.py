"""The training versions in the mission briefing (FEAT-TRAINING-BRIEFING-PAGES).

When ``mission.yaml`` holds a ``training:`` block, the build writes one training version per role
beside the night's mission (:mod:`mission_builder.training_variants`). The briefing gets one page per
version: what it is for, what each declared element becomes in it, what is drawn again at every launch,
and which file to load.

The pages are computed with the build's own rules (:func:`~mission_builder.training_variants.plan_variant`)
on the source mission, so they say what the ``.miz`` holds and cannot drift from it.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from campaign_manager.briefing_deck import Block
from mission_builder.group_removal import iter_group_slots, matches_any
from mission_builder.training_variants import (
    AIR_DEFENCE_KEPT_ROLES,
    REMOVED_KINDS,
    ROLES,
    PoolCandidate,
    TrainingError,
    parse_training,
    plan_variant,
    profile_name,
    training_block,
)
from mission_tools.miz_tools import read_mission_folder
from veaf_libs.i18n import t

from mission_briefing.briefing_tables import Table, TablePage

#: The table's columns' shares of the page width: element, what it is, what it becomes.
_WIDTHS = (0.4, 0.22, 0.38)


def _labels(config: dict[str, Any]) -> tuple[dict[str, str], dict[str, str]]:
    """Combat zones by their friendly name, and on-demand CAPs by their menu name, keyed by what selects them."""
    raw_modules = config.get("modules")
    modules: dict[str, Any] = raw_modules if isinstance(raw_modules, dict) else {}
    combat = next((v for k, v in modules.items() if str(k).upper() == "COMBATZONE"), None)
    entries = combat.get("combat_zones") if isinstance(combat, dict) else None
    zones = {
        str(entry.get("zone_name")): str(entry.get("friendly_name") or entry.get("zone_name"))
        for entry in entries or []
        if isinstance(entry, dict) and entry.get("zone_name")
    }
    caps = {
        str(entry.get("group_name")): str(entry.get("menu_name") or entry.get("group_name"))
        for entry in config.get("cap_missions") or []
        if isinstance(entry, dict) and entry.get("group_name")
    }
    return zones, caps


def _candidate(candidate: PoolCandidate) -> str:
    """One candidate of a draw, as a pilot reads it."""
    if candidate.group:
        return candidate.group
    if candidate.command:
        return candidate.command
    return " + ".join(
        t("mission_briefing.training.units", count=spec.count, type=spec.type) for spec in candidate.units
    )


def _keeps_some(zone: str | None, names: list[str], removed: list[str]) -> bool:
    """Whether a version keeps a group of the zone — its air defences, when the targets are out."""
    if zone is None:
        return False
    return any(name.upper().startswith(zone.upper()) and name not in removed for name in names)


def _count(count: str) -> str:
    """A ``min-max`` count as a pilot reads it: ``2-3`` → ``2 à 3`` (the locale's word)."""
    low, _, high = count.partition("-")
    return t("mission_briefing.training.range", low=low, high=high) if high else low


def training_pages(folder: Path, warnings: list[str]) -> list[TablePage]:
    """One page per training version, or none when the mission declares no ``training:`` block.

    Args:
        folder: The mission folder (``mission.yaml`` + ``src/mission/``).
        warnings: Where a block the build would refuse is reported; the briefing goes on without the pages.

    Returns:
        The pages, in the order the build writes the versions.
    """
    yaml_path = folder / "mission.yaml"
    if not yaml_path.is_file():
        return []
    config = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    plan, errors = parse_training(training_block(config))
    if plan is None:
        if errors:
            warnings.append(t("mission_briefing.training.refused", error=errors[0]))
        return []
    try:
        mission = read_mission_folder(folder).mission_content or {}
    except (FileNotFoundError, ValueError) as exc:
        warnings.append(t("mission_briefing.training.refused", error=str(exc)))
        return []
    zones, caps = _labels(config)
    names = [str(group.get("name", "")) for _, _, _, group in iter_group_slots(mission)]
    columns = tuple(t(f"mission_briefing.training.column.{name}") for name in ("element", "kind", "status"))
    pages = []
    for role in ROLES:
        try:
            variant = plan_variant(role, config, mission)
        except TrainingError as exc:
            warnings.append(t("mission_briefing.training.refused", error=str(exc).splitlines()[0]))
            return []
        removed = REMOVED_KINDS[role]
        rows: list[tuple[str, str, str]] = []
        for element in plan.elements:
            if element.label:
                label = element.label
            elif element.zone is not None:
                label = zones.get(element.zone, element.zone)
            elif element.qra is not None:
                label = element.qra
            elif element.cap_mission is not None:
                label = caps.get(element.cap_mission, element.cap_mission)
            else:
                label = ", ".join(element.groups)
            if element.kind not in removed:
                status = "kept"
            elif element.groups:
                # What the build takes out, not what the kind says: CAP keeps an air defence declared a target.
                matched = [name for name in names if matches_any(name, element.groups)]
                status = "kept" if any(name not in variant.removed_groups for name in matched) else "removed"
            elif (
                element.kind == "a2g_target"
                and role in AIR_DEFENCE_KEPT_ROLES
                and _keeps_some(element.zone, names, variant.removed_groups)
            ):
                status = "targets_out"
            else:
                status = "removed"
            rows.append(
                (
                    label,
                    t(f"mission_briefing.training.kind.{element.kind}"),
                    t(f"mission_briefing.training.status.{status}"),
                )
            )
        kept_draws = {resolved.draw.name for resolved in variant.draws}
        for draw in plan.draws:
            if draw.label:
                label = t(
                    "mission_briefing.training.draw_named",
                    label=draw.label,
                    count=_count(draw.count),
                    size=len(draw.pool),
                )
            else:
                candidates = ", ".join(_candidate(candidate) for candidate in draw.pool)
                label = t("mission_briefing.training.draw", count=draw.count, candidates=candidates)
            status = "drawn" if draw.name in kept_draws else "draw_removed"
            rows.append(
                (label, t("mission_briefing.training.kind.vague"), t(f"mission_briefing.training.status.{status}"))
            )
        after = [
            Block(
                None,
                (
                    t(f"mission_briefing.training.purpose.{role}"),
                    t("mission_briefing.training.file", suffix=profile_name(role)),
                ),
            )
        ]
        pages.append(
            TablePage(
                t(f"mission_briefing.training.title.{role}"),
                [Table(None, columns, _WIDTHS, tuple(rows))],
                after,
            )
        )
    return pages
