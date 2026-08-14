"""Pre-build mission-folder validation (the ``veaf-tools validate`` command).

Aggregates design-time checks over a VEAF mission folder **without building**, turning
late DCS-side failures into clear errors/warnings up front. Unlike the build (which
aborts on the first problem), every check is collected into a :class:`ValidationIssue`
list, so a single run reports everything.

Checks:
  1. ``mission.yaml`` YAML syntax                                  (error)
  2. ``modules:`` semantics — unknown key, wrong type, removed section (error / warning)
  3. ``custom_scripts`` declared files exist on disk              (error)
  3b. ``config_override`` keys exist lexically in the injected corpus (error)
  4. Mission-Editor reference checks (:func:`validate_mission_content`): declared groups,
     trigger zones, SANCTUARY units, QRA airfields, COMBATZONE operation sub-zones (error,
     except an AIRWAVES trigger zone with a center/radius fallback → warning)
  5. presets / waypoints configured but no aircraft to apply them to (warning)
  6. ``TUM: true`` requires BLUFOR/REDFOR territory zones          (warning)

Checks 4-6 read the unpacked source mission table (``src/mission/mission``); when it is
absent they are skipped (reported once as a warning).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from veaf_libs.config_override import find_unknown_segments, read_corpus
from veaf_libs.conversion_profile import incompatible_modules_enabled
from veaf_libs.i18n import t
from veaf_libs.mission_table import CATEGORIES, indexed
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

    # 2c. radio user-menu schema (FEAT-RADIO-YAML-MENUS): closed action vocabulary
    issues += _check_radio_menus(yaml_data)

    # 3. custom_scripts files exist
    issues += _check_custom_scripts(folder, yaml_data)

    # 3b. config_override keys exist lexically in the injected Foothold corpus
    issues += _check_config_override(folder, yaml_data)

    # 3c. radio-menu `action: lua` references resolve to a defined maker function
    issues += _check_radio_lua_functions(folder, yaml_data)

    # 4-6. checks that need the source mission table
    mission, mission_error = _read_source_mission(folder)
    if mission is None:
        if mission_error:
            issues.append(ValidationIssue(ERROR, t("validate.source_mission_unreadable", error=mission_error)))
        else:
            issues.append(ValidationIssue(WARNING, t("validate.no_source_mission")))
        return issues

    issues += validate_mission_content(yaml_data, mission)
    issues += _check_has_player_slot(mission)
    issues += _check_presets_waypoints(folder, yaml_data, mission)
    issues += _check_tum_zones(yaml_data, mission)
    return issues


def validate_mission_content(yaml_data: dict, mission: dict) -> list[ValidationIssue]:
    """Validate every ``mission.yaml`` reference to a Mission-Editor object (FEAT-BUILD-VALIDATE-REFS).

    Covers declared groups (error), trigger zones (AIRWAVES optional → warning when a
    center/radius fallback is configured, else error; QRA / COMBATZONE → error), SANCTUARY
    ``polygon_units`` (error), QRA ``airport_link`` (error, skipped on an uncovered theatre),
    and COMBATZONE operation tasking-order sub-zones (error). Shared by the ``validate``
    command and the build (which runs it fail-at-end).

    Args:
        yaml_data: The parsed ``mission.yaml`` mapping.
        mission: The parsed DCS mission table (``triggers``, ``coalition``, ``theatre``…).

    Returns:
        Every :class:`ValidationIssue` found, in check order.
    """
    from mission_builder.group_validation import (
        find_missing_declared_groups,
        find_missing_sanctuary_units,
        find_missing_trigger_zone_refs,
        find_undeclared_operation_subzones,
        find_unknown_airport_links,
    )

    theatre = mission.get("theatre") if isinstance(mission, dict) else None
    issues: list[ValidationIssue] = []

    for section, group in find_missing_declared_groups(yaml_data, mission):
        issues.append(ValidationIssue(ERROR, t("validate.missing_group", group=group, section=section)))

    for section, zone, level in find_missing_trigger_zone_refs(yaml_data, mission):
        key = "validate.missing_trigger_zone_optional" if level == WARNING else "validate.missing_trigger_zone"
        issues.append(ValidationIssue(level, t(key, zone=zone, section=section)))

    for section, unit, level in find_missing_sanctuary_units(yaml_data, mission):
        issues.append(ValidationIssue(level, t("validate.missing_unit", unit=unit, section=section)))

    for section, airfield, level in find_unknown_airport_links(yaml_data, theatre):
        issues.append(ValidationIssue(level, t("validate.unknown_airfield", airfield=airfield, section=section)))

    for section, subzone, level in find_undeclared_operation_subzones(yaml_data):
        issues.append(ValidationIssue(level, t("validate.undeclared_subzone", subzone=subzone, section=section)))

    issues += _check_mission_is_playable(mission)

    return issues


def _check_mission_is_playable(mission: dict) -> list[ValidationIssue]:
    """Report a mission DCS would refuse, or that no pilot can enter.

    Added after a mission built for the 2026-08-14 DCS session passed this validator and built
    cleanly, and DCS then opened CHANGING COALITIONS with every country unassigned: `coalitions` was
    empty while `coalition` held units. Two tables describe the same fact — which countries a side
    owns, and what those countries field — and populating only the second gives units in a side that
    does not exist.

    Args:
        mission: The parsed DCS mission table.

    Returns:
        One error per side holding units but owning no country, plus one warning when the mission has
        no player slot at all.
    """
    if not isinstance(mission, dict):
        return []
    issues: list[ValidationIssue] = []

    # Only judge a mission that actually carries the table. A real DCS mission always does — even
    # empty, which is the broken state — while a partial table written for a test omits it, and
    # reporting those would be noise about a mission nobody flies.
    if "coalitions" not in mission:
        return issues
    assigned = mission.get("coalitions") or {}
    for side, side_content in (mission.get("coalition") or {}).items():
        if not isinstance(side_content, dict):
            continue
        countries = indexed(side_content.get("country"))
        has_units = any(
            indexed((country.get(category) or {}).get("group"))
            for country in countries
            if isinstance(country, dict)
            for category in CATEGORIES
        )
        if has_units and not indexed(assigned.get(side) if isinstance(assigned, dict) else None):
            issues.append(ValidationIssue(ERROR, t("validate.side_without_country", side=side)))

    return issues


def _check_has_player_slot(mission: dict) -> list[ValidationIssue]:
    """Warn when no pilot can enter the mission.

    Kept out of :func:`validate_mission_content` on purpose: the **build** runs that function too, and
    a template library or a server-side scenario legitimately has no slot — warning on every build of
    one would be noise. This belongs to the `validate` command, where a maker is asking the question.

    Args:
        mission: The parsed DCS mission table.

    Returns:
        One warning, or nothing.
    """
    if not isinstance(mission, dict) or _aircraft_counts(mission)[1] > 0:
        return []
    return [ValidationIssue(WARNING, t("validate.no_player_slot"))]


def _check_radio_menus(yaml_data: dict) -> list[ValidationIssue]:
    """Validate ``modules.RADIO.user_menus`` against the closed action vocabulary.

    Walks the menu tree and, for every command leaf, checks that its ``action`` is a
    known verb (:data:`~veaf_libs.lua_config_generator.RADIO_MENU_ACTIONS`) and that the
    action's required target key(s) are present. Sub-menus (nodes carrying ``menu``) are
    recursed into. Unknown actions or missing targets are reported as errors so the
    mistake surfaces here rather than as a broken F10 menu (or a build crash).

    Args:
        yaml_data: The parsed ``mission.yaml`` mapping.

    Returns:
        Every :class:`ValidationIssue` found, in tree order.
    """
    from veaf_libs.lua_config_generator import RADIO_MENU_ACTIONS

    # Accept both `modules` and the legacy `lua_modules` key, mirroring
    # collect_radio_lua_functions so validation and build see the same config.
    modules = yaml_data.get("lua_modules") or yaml_data.get("modules")
    radio = modules.get("RADIO") if isinstance(modules, dict) else None
    user_menus = radio.get("user_menus") if isinstance(radio, dict) else None
    if not isinstance(user_menus, dict):
        return []

    issues: list[ValidationIssue] = []

    def _walk(nodes: object) -> None:
        if not isinstance(nodes, list):
            return
        for node in nodes:
            if not isinstance(node, dict):
                continue
            if "menu" in node:
                _walk(node.get("items"))
                continue
            label = node.get("command", "?")
            action = node.get("action")
            if action not in RADIO_MENU_ACTIONS:
                issues.append(
                    ValidationIssue(ERROR, t("validate.radio_menu_unknown_action", action=action, command=label))
                )
                continue
            for key in RADIO_MENU_ACTIONS[action]:
                if node.get(key) is None:
                    issues.append(
                        ValidationIssue(
                            ERROR, t("validate.radio_menu_missing_target", action=action, param=key, command=label)
                        )
                    )

    _walk(user_menus.get("tree"))
    return issues


def _check_radio_lua_functions(folder: Path, yaml_data: dict) -> list[ValidationIssue]:
    """Each radio-menu ``action: lua`` must reference a function defined in the mission scripts.

    Mirrors the build's abort (FEAT-RADIO-YAML-MENUS): a reference with no matching
    definition in the concatenated ``src/scripts`` corpus is an error, so the maker
    catches the typo (or forgotten definition) before the F10 menu breaks at runtime.

    Args:
        folder: The mission folder.
        yaml_data: The parsed ``mission.yaml`` mapping.

    Returns:
        One error per undefined referenced function.
    """
    from veaf_libs.lua_config_generator import collect_radio_lua_functions, find_undefined_lua_functions

    if not collect_radio_lua_functions(yaml_data):
        return []
    corpus = read_corpus(folder / "src" / "scripts")
    return [
        ValidationIssue(ERROR, t("validate.radio_lua_function_missing", function=fn))
        for fn in find_undefined_lua_functions(yaml_data, corpus)
    ]


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


def _check_config_override(folder: Path, yaml_data: dict) -> list[ValidationIssue]:
    """Validate ``config_override``: its ``target`` resolves, and its key segments exist.

    Two distinct failures, both silent until now:

    - **target**: the build anchors the override right after the script named by ``target``
      and, when that name is absent, appends it **last** — after the setup script has read
      the globals, so the override loads but has no effect. An unresolvable target is
      therefore an error, not a cosmetic mismatch.
    - **values**: each dotted-path segment is validated lexically (whole-word identifier
      search) against the concatenated ``src/scripts/*.lua`` sources; a segment found
      nowhere is a typo or an upstream rename. See ADR 0008.
    """
    co = yaml_data.get("config_override")
    if not isinstance(co, dict):
        return []
    values = co.get("values")
    if not isinstance(values, dict) or not values:
        return []
    scripts_dir = folder / "src" / "scripts"
    issues = _check_config_override_target(scripts_dir, co.get("target"))
    corpus = read_corpus(scripts_dir)
    for key in values:
        for segment in find_unknown_segments({key: values[key]}, corpus):
            issues.append(
                ValidationIssue(ERROR, t("validate.config_override_unknown_segment", segment=segment, override_key=key))
            )
    return issues


def _check_config_override_target(scripts_dir: Path, target: object) -> list[ValidationIssue]:
    """The ``config_override.target`` must name a script present in *scripts_dir*.

    Matched on basename, like the build's own positioning. Absent target → no check (the
    override then simply loads in collection order, which is a deliberate choice).
    """
    if not target:
        return []
    name = Path(str(target)).name
    if (scripts_dir / name).is_file():
        return []
    return [ValidationIssue(ERROR, t("validate.config_override_target_missing", target=name))]


def _read_source_mission(folder: Path) -> tuple[dict | None, str | None]:
    """Parse the unpacked source mission table (``src/mission/mission``).

    VMR-062: this used to answer ``None`` for both "the file is not there" and "the file is there
    and will not parse", and the caller turned that into the *not found* warning — so a corrupt
    mission table disabled the reference checks while pointing the mission maker at a missing file.

    Args:
        folder: The mission folder to read from.

    Returns:
        ``(mission, error)``. ``mission`` is the parsed table, or ``None`` when it could not be
        read; ``error`` describes why when the file exists but is unusable, and is ``None`` when
        the file is simply absent.
    """
    mission_file = folder / "src" / "mission" / "mission"
    if not mission_file.is_file():
        return None, None
    try:
        import luadata  # type: ignore[import-untyped]

        content = luadata.unserialize(mission_file.read_text(encoding="utf-8"), keep_as_dict=["trig", "trigrules"])
    except Exception as exc:  # noqa: BLE001 - reported to the caller rather than silently skipped
        return None, str(exc) or exc.__class__.__name__
    if not isinstance(content, dict):
        return None, f"expected a table, got {type(content).__name__}"
    return content, None


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
