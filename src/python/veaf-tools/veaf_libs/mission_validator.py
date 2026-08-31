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

    issues += _check_sequence_holes(mission)
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
    issues += _check_waypoint_locks(mission)

    return issues


def _country_id(value: object) -> int | None:
    """Return a DCS country id as an int, or ``None`` when the value is not usable as one.

    The two tables being compared are written by different producers, so an id can arrive as an int,
    a float, or a string; comparing them raw would call 2 and "2" different countries.

    Args:
        value: A raw ``id`` field, or an entry of ``coalitions.<side>``.

    Returns:
        The id as an int, or ``None`` when it cannot be read as one.
    """
    if not isinstance(value, (int, float, str)):
        return None
    try:
        return int(value)
    except ValueError:
        return None


def _check_mission_is_playable(mission: dict) -> list[ValidationIssue]:
    """Report a mission DCS would refuse, or that no pilot can enter.

    Added after a mission built for the 2026-08-14 DCS session passed this validator and built
    cleanly, and DCS then opened CHANGING COALITIONS with every country unassigned: `coalitions` was
    empty while `coalition` held units. Two tables describe the same fact — which countries a side
    owns, and what those countries field — and populating only the second gives units in a side that
    does not exist.

    DCS's requirement is an inclusion, not merely a non-empty list: **every** country owning units
    under `coalition.<side>.country` must appear in `coalitions.<side>`. Checking only the empty case
    would stay silent on one country assigned out of three — the shape the defect fixed by PR #868
    would have taken had it been "fixed" by declaring a single country. A country owning nothing is
    never required: DCS does not care, and demanding it would light up good missions.

    Args:
        mission: The parsed DCS mission table.

    Returns:
        One error per side whose unit-owning countries are not all listed in ``coalitions``.
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
        owners: set[int] = set()
        has_units = False
        for country in indexed(side_content.get("country")):
            if not isinstance(country, dict):
                continue
            if not any(indexed((country.get(category) or {}).get("group")) for category in CATEGORIES):
                continue
            has_units = True
            owner_id = _country_id(country.get("id"))
            if owner_id is not None:
                owners.add(owner_id)
        if not has_units:
            continue

        raw_listed = indexed(assigned.get(side) if isinstance(assigned, dict) else None)
        if not raw_listed:
            issues.append(ValidationIssue(ERROR, t("validate.side_without_country", side=side)))
            continue
        listed = {country_id for country_id in map(_country_id, raw_listed) if country_id is not None}
        missing = owners - listed
        if missing:
            issues.append(
                ValidationIssue(
                    ERROR,
                    t(
                        "validate.side_missing_countries",
                        side=side,
                        missing=sorted(missing),
                        listed=sorted(listed),
                    ),
                )
            )

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


def _iter_routed_groups(mission: dict):
    """Yield ``(group_name, points)`` for every group of the mission that has a route.

    Args:
        mission: The parsed mission table.

    Yields:
        The group's name and its list of route points, skipping anything shaped unexpectedly rather
        than raising — a validator that dies on odd data reports nothing at all about the rest.
    """
    coalitions = mission.get("coalition")
    if not isinstance(coalitions, dict):
        return
    for coalition in coalitions.values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country") or []:
            if not isinstance(country, dict):
                continue
            for kind in ("plane", "helicopter", "vehicle", "ship"):
                block = country.get(kind)
                if not isinstance(block, dict):
                    continue
                for group in block.get("group") or []:
                    if not isinstance(group, dict):
                        continue
                    points = ((group.get("route") or {}).get("points")) or []
                    if isinstance(points, list) and points:
                        yield str(group.get("name", "?")), points


def _check_waypoint_locks(mission: dict) -> list[ValidationIssue]:
    """Report routes the DCS Mission Editor refuses to save.

    DCS rejects a mission whose route asks for two contradictory things, and it reports them naming the
    *route* rather than the flag. Two shapes:

    * a waypoint fixing its **speed** while the waypoints around it fix their **arrival time** —
      *"All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!"*;
    * a route where **no** waypoint has a locked time — *"Route has no waypoints with locked time!"*.

    Found on 2026-08-22 the only way it could be: `veaf-tools mission validate` reported "no defect" on
    `verify-mission-a` seconds before the editor refused to open it. `ETA_locked` appeared nowhere in
    this file. The bad data was a hand-copied waypoint rather than a tooling bug, and an enumerated
    sweep of both verification missions found exactly one offender — so the defect here is the
    **silence**: a mission that will not open costs a session, and the tool whose job is to say "this is
    sound" said it was.

    The second shape is the symmetric twin of `FIX-WAYPOINTS-ETA-LOCKED`, which taught the MCP to repair
    its own edits and left the validator blind to the same thing in data it did not write.

    Args:
        mission: The parsed source mission table.

    Returns:
        One warning per offending route. Warnings rather than errors: this is real data DCS has already
        accepted into a file, and refusing to build it would be a worse outcome than saying so.
    """
    issues: list[ValidationIssue] = []
    for name, points in _iter_routed_groups(mission):
        locked_time = [i for i, p in enumerate(points, 1) if isinstance(p, dict) and p.get("ETA_locked")]
        if not locked_time:
            issues.append(ValidationIssue(WARNING, t("validate.route_no_locked_time", group=name)))
            continue
        if len(locked_time) < 2:
            continue
        # A locked speed anywhere between two locked times is the contradiction DCS names.
        for index, point in enumerate(points, 1):
            if not isinstance(point, dict) or not point.get("speed_locked"):
                continue
            if any(i < index for i in locked_time) and any(i >= index for i in locked_time):
                issues.append(
                    ValidationIssue(
                        WARNING,
                        t("validate.route_contradictory_locks", group=name, waypoint=index),
                    )
                )
                break
    return issues


def _check_sequence_holes(mission: dict) -> list[ValidationIssue]:
    """Name every sequence table whose keys are not a contiguous ``1..N``.

    The build closes these holes on load, and it is right to — a holed container is what a hand edit
    or a third-party tool leaves behind, and eight readers used to die on it. But closing one *changes
    the file*, and on 2026-08-18 three holes surfaced at three unrelated subsystems with a message
    (``AttributeError: 'int' object has no attribute 'get'``) that named none of them. So they are
    reported here, by path, rather than repaired in silence.

    Args:
        mission: The parsed source mission table. Normalised in place — this is the validator's own
            copy, which it never writes back.

    Returns:
        One warning per holed table, empty for a well-formed mission.
    """
    from mission_tools.sequence_normalisation import normalise_mission_sequences

    return [
        ValidationIssue(
            WARNING,
            t(
                "validate.holed_sequence",
                path=hole.path,
                keys=", ".join(str(k) for k in hole.keys),
                count=len(hole.keys),
            ),
        )
        for hole in normalise_mission_sequences(mission)
    ]
