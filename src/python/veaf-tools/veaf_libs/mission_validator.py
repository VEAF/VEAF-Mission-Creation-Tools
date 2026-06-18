"""Pre-build mission-folder validation (the ``veaf-tools validate`` command).

Aggregates design-time checks over a VEAF mission folder **without building**, turning
late DCS-side failures into clear errors/warnings up front. Unlike the build (which
aborts on the first problem), every check is collected into a :class:`ValidationIssue`
list, so a single run reports everything.

Checks:
  1. ``mission.yaml`` YAML syntax                                  (error)
  2. ``modules:`` semantics — unknown key, wrong type, removed section (error / warning)
  3. ``custom_scripts`` declared files exist on disk              (error)
  4. ASSETS/QRA groups declared in mission.yaml exist in the mission (warning)
  5. presets / waypoints configured but no aircraft to apply them to (warning)
  6. ``TUM: true`` requires BLUFOR/REDFOR territory zones          (warning)

Checks 4-6 read the unpacked source mission table (``src/mission/mission``); when it is
absent they are skipped (reported once as a warning).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from veaf_libs.conversion_profile import incompatible_modules_enabled
from veaf_libs.i18n import t
from veaf_libs.yaml_validator import check_yaml_syntax, collect_module_issues

ERROR = "error"
WARNING = "warning"

#: Trigger-zone name prefixes TheUniversalMission expects (one per coalition territory).
_TUM_ZONE_PREFIXES = ("BLUFOR", "REDFOR")
_GROUP_CATEGORIES = ("plane", "helicopter")


@dataclass(frozen=True)
class ValidationIssue:
    """A single validation finding: ``level`` is :data:`ERROR` or :data:`WARNING`."""

    level: str
    message: str


def validate_mission_folder(folder: Path) -> list[ValidationIssue]:
    """Run all pre-build checks over a mission folder and return the aggregated issues.

    Args:
        folder: The mission folder (the one that holds ``mission.yaml``).

    Returns:
        Every :class:`ValidationIssue` found, in check order. Empty means all clear.
    """
    issues: list[ValidationIssue] = []
    yaml_path = folder / "mission.yaml"
    if not yaml_path.is_file():
        return [ValidationIssue(ERROR, t("validate.no_mission_yaml", folder=folder))]

    # 1. YAML syntax — if it does not parse, no further check is meaningful.
    syntax_error = check_yaml_syntax(yaml_path)
    if syntax_error is not None:
        return [ValidationIssue(ERROR, syntax_error)]

    yaml_data: dict = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}

    # 2. modules: semantics
    errors, warnings = collect_module_issues(yaml_data)
    issues += [ValidationIssue(ERROR, m) for m in errors]
    issues += [ValidationIssue(WARNING, m) for m in warnings]

    # 2b. conversion-profile incompatibilities (e.g. CTLD on a Foothold mission)
    issues += [
        ValidationIssue(ERROR, t("validate.incompatible_module", module=m, profile=yaml_data.get("conversion_profile")))
        for m in incompatible_modules_enabled(yaml_data)
    ]

    # 3. custom_scripts files exist
    issues += _check_custom_scripts(folder, yaml_data)

    # 4-6. checks that need the source mission table
    mission = _read_source_mission(folder)
    if mission is None:
        issues.append(ValidationIssue(WARNING, t("validate.no_source_mission")))
        return issues

    issues += _check_declared_groups(yaml_data, mission)
    issues += _check_presets_waypoints(folder, yaml_data, mission)
    issues += _check_tum_zones(yaml_data, mission)
    return issues


def _check_custom_scripts(folder: Path, yaml_data: dict) -> list[ValidationIssue]:
    """Each ``custom_scripts.scripts[].path`` must exist on disk (else the build can't embed it)."""
    cs = yaml_data.get("custom_scripts")
    if not isinstance(cs, dict):
        return []
    issues: list[ValidationIssue] = []
    for item in cs.get("scripts") or []:
        path = item.get("path") if isinstance(item, dict) else item
        if not path:
            continue
        if not (folder / str(path)).is_file():
            issues.append(ValidationIssue(ERROR, t("validate.custom_script_missing", path=path)))
    return issues


def _read_source_mission(folder: Path) -> dict | None:
    """Parse the unpacked source mission table (``src/mission/mission``); ``None`` if absent/unreadable."""
    mission_file = folder / "src" / "mission" / "mission"
    if not mission_file.is_file():
        return None
    try:
        import luadata  # type: ignore[import-untyped]

        content = luadata.unserialize(mission_file.read_text(encoding="utf-8"), keep_as_dict=["trig", "trigrules"])
    except Exception:  # noqa: BLE001 - a parse failure just disables the mission-content checks
        return None
    return content if isinstance(content, dict) else None


def _check_declared_groups(yaml_data: dict, mission: dict) -> list[ValidationIssue]:
    """ASSETS/QRA groups declared in mission.yaml that are absent from the mission (must be placed in the ME)."""
    from mission_builder.group_validation import find_missing_declared_groups

    return [
        ValidationIssue(WARNING, t("validate.missing_group", group=group, section=section))
        for section, group in find_missing_declared_groups(yaml_data, mission)
    ]


def _aircraft_counts(mission: dict) -> tuple[int, int]:
    """Return ``(aircraft_group_count, player_unit_count)`` across all coalitions/countries."""
    groups = 0
    players = 0
    coalitions = mission.get("coalition") or {}
    if not isinstance(coalitions, dict):
        return (0, 0)
    for coalition in coalitions.values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country") or []:
            if not isinstance(country, dict):
                continue
            for category in _GROUP_CATEGORIES:
                container = country.get(category)
                if not isinstance(container, dict):
                    continue
                for group in container.get("group") or []:
                    if not isinstance(group, dict):
                        continue
                    groups += 1
                    for unit in group.get("units") or []:
                        if isinstance(unit, dict) and str(unit.get("skill")) in ("Client", "Player"):
                            players += 1
    return (groups, players)


def _pipeline_enabled(yaml_data: dict, step: str) -> bool:
    """Whether a pipeline step runs (enabled unless explicitly disabled — build's default)."""
    cfg = (yaml_data.get("pipeline") or {}).get(step)
    if cfg is False:
        return False
    if isinstance(cfg, dict) and cfg.get("enabled") is False:
        return False
    return True


def _check_presets_waypoints(folder: Path, yaml_data: dict, mission: dict) -> list[ValidationIssue]:
    """Warn when presets/waypoints are configured but the mission has no aircraft to apply them to.

    Coarse on purpose: the exact per-type/typePattern matching lives in the injectors. This
    catches the common failure (a config file present with no relevant aircraft); a fine-grained
    per-aircraft match would be a follow-up.
    """
    issues: list[ValidationIssue] = []
    groups, players = _aircraft_counts(mission)
    if _pipeline_enabled(yaml_data, "presets") and (folder / "src" / "presets.yaml").is_file() and players == 0:
        issues.append(ValidationIssue(WARNING, t("validate.presets_no_aircraft")))
    if _pipeline_enabled(yaml_data, "waypoints") and (folder / "src" / "waypoints.yaml").is_file() and groups == 0:
        issues.append(ValidationIssue(WARNING, t("validate.waypoints_no_aircraft")))
    return issues


def _module_enabled(yaml_data: dict, key: str) -> bool:
    """Whether a ``modules:`` entry is enabled (bool shorthand, bare null, or ``enabled``)."""
    modules = yaml_data.get("modules")
    if not isinstance(modules, dict) or key not in modules:
        return False
    cfg = modules[key]
    if isinstance(cfg, dict):
        return cfg.get("enabled", True) is not False
    return cfg is not False


def _zone_names(mission: dict) -> list[str]:
    """Return the trigger-zone names defined in the mission."""
    zones = ((mission.get("triggers") or {}).get("zones")) or []
    names: list[str] = []
    for zone in zones if isinstance(zones, list) else zones.values() if isinstance(zones, dict) else []:
        if isinstance(zone, dict) and (name := zone.get("name")):
            names.append(str(name))
    return names


def _check_tum_zones(yaml_data: dict, mission: dict) -> list[ValidationIssue]:
    """``TUM: true`` requires a BLUFOR and a REDFOR territory trigger zone, else it aborts at start-up."""
    if not _module_enabled(yaml_data, "TUM"):
        return []
    names_upper = [n.upper() for n in _zone_names(mission)]
    missing = [side for side in _TUM_ZONE_PREFIXES if not any(n.startswith(side) for n in names_upper)]
    if missing:
        return [ValidationIssue(WARNING, t("validate.tum_zones_missing", sides=", ".join(missing)))]
    return []
