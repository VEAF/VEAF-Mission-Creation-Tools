"""Build-time validation: config sections must reference groups that exist in the mission.

Several `mission.yaml` sections point at DCS groups that the mission maker must
have placed in the Mission Editor (ASSETS respawn, QRA deploy lists, CAP/combat
missions). If a declared group is missing from the `.miz`, the feature fails
silently at runtime (e.g. `veafAssets.respawn` → MiST "group not found"). This
module surfaces such mismatches as build-time warnings (IMC2-004 / IMC2-004b).
"""

from __future__ import annotations

from typing import Any

#: DCS unit-group categories carried under each country in the mission table.
_GROUP_CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")

#: veafCombatMission.addCapMission() prefixes this to the cap_missions group name
#: at runtime (since v5), so the maker's DCS group is named "OnDemand-<group_name>".
ONDEMAND_CAP_PREFIX = "OnDemand-"


def collect_mission_group_names(mission_content: dict[str, Any]) -> set[str]:
    """Return every group name present in the mission (all coalitions/countries/categories)."""
    names: set[str] = set()
    coalitions = mission_content.get("coalition") or {}
    if not isinstance(coalitions, dict):
        return names
    for coalition in coalitions.values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country") or []:
            if not isinstance(country, dict):
                continue
            for category in _GROUP_CATEGORIES:
                container = country.get(category) or {}
                if not isinstance(container, dict):
                    continue
                for group in container.get("group") or []:
                    if isinstance(group, dict) and (name := group.get("name")):
                        names.add(str(name))
    return names


def _module_cfg(modules: dict[str, Any], key: str) -> dict[str, Any]:
    """Return the config dict for an enabled module, or ``{}`` (disabled / shorthand)."""
    cfg = modules.get(key)
    if not isinstance(cfg, dict) or cfg.get("enabled") is False:
        return {}
    return cfg


def collect_declared_groups(mission_yaml: dict[str, Any]) -> list[tuple[str, str]]:
    """Collect ``(section, group_name)`` references that must exist as mission groups.

    Covers the sections that point at Mission-Editor-placed groups: ASSETS
    (asset name + linked), QRA (deploy lists), and the top-level ``cap_missions``
    / ``combat_missions``. Sections that reference *units* (Sanctuary) or
    *patterns/templates* (AirWaves) are intentionally excluded to avoid false
    positives.
    """
    refs: list[tuple[str, str]] = []
    modules = mission_yaml.get("modules") or {}

    assets_cfg = _module_cfg(modules, "ASSETS")
    for asset in assets_cfg.get("assets") or []:
        if not isinstance(asset, dict):
            continue
        if name := asset.get("name"):
            refs.append(("ASSETS", str(name)))
        linked = asset.get("linked")
        if isinstance(linked, str):
            refs.append(("ASSETS.linked", linked))
        elif isinstance(linked, list):
            refs.extend(("ASSETS.linked", str(g)) for g in linked)

    qra_cfg = _module_cfg(modules, "QRA")
    for qra_def in qra_cfg.get("definitions") or []:
        if not isinstance(qra_def, dict):
            continue
        for grp in qra_def.get("simple_groups") or []:
            refs.append(("QRA", str(grp)))
        for gbc in qra_def.get("groups_by_enemy_count") or []:
            if isinstance(gbc, dict):
                refs.extend(("QRA", str(g)) for g in gbc.get("groups") or [])

    for cap in mission_yaml.get("cap_missions") or []:
        if isinstance(cap, dict) and (g := cap.get("group_name")):
            # addCapMission() prefixes ONDEMAND_CAP_PREFIX at runtime, so the maker's
            # template group is named "OnDemand-<g>", not "<g>". Validate against the
            # prefixed name to avoid a false warning. str() guards a non-string YAML value.
            refs.append(("cap_missions", f"{ONDEMAND_CAP_PREFIX}{str(g)}"))

    for cm in mission_yaml.get("combat_missions") or []:
        if not isinstance(cm, dict):
            continue
        for elem in cm.get("elements") or []:
            if isinstance(elem, dict):
                refs.extend(("combat_missions", str(g)) for g in elem.get("groups") or [])

    return refs


def find_missing_declared_groups(
    mission_yaml: dict[str, Any], mission_content: dict[str, Any]
) -> list[tuple[str, str]]:
    """Return the ``(section, group_name)`` references absent from the mission groups."""
    present = collect_mission_group_names(mission_content)
    missing: list[tuple[str, str]] = []
    seen: set[str] = set()
    for section, group in collect_declared_groups(mission_yaml):
        # Report each missing group once (by name), keeping the first section it appears in.
        if group not in present and group not in seen:
            seen.add(group)
            missing.append((section, group))
    return missing


# ---------------------------------------------------------------------------
# Mission-Editor reference validation (FEAT-BUILD-VALIDATE-REFS)
#
# A mission.yaml also references trigger zones, units and airfields that the
# maker must have placed in the Mission Editor. Each finder returns
# ``(section, reference, level)`` where ``level`` is "error" or "warning".
# ---------------------------------------------------------------------------

#: Severity levels carried by the reference finders below.
LEVEL_ERROR = "error"
LEVEL_WARNING = "warning"


def collect_mission_zone_names(mission_content: dict[str, Any]) -> set[str]:
    """Return every trigger-zone name defined in the mission (``triggers.zones``)."""
    zones = (mission_content.get("triggers") or {}).get("zones") or []
    if isinstance(zones, dict):
        zones = list(zones.values())
    names: set[str] = set()
    for zone in zones if isinstance(zones, list) else []:
        if isinstance(zone, dict) and (name := zone.get("name")):
            names.add(str(name))
    return names


def collect_mission_unit_names(mission_content: dict[str, Any]) -> set[str]:
    """Return every unit name present in the mission (all coalitions/countries/categories)."""
    names: set[str] = set()
    coalitions = mission_content.get("coalition") or {}
    if not isinstance(coalitions, dict):
        return names
    for coalition in coalitions.values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country") or []:
            if not isinstance(country, dict):
                continue
            for category in _GROUP_CATEGORIES:
                container = country.get(category) or {}
                if not isinstance(container, dict):
                    continue
                for group in container.get("group") or []:
                    if not isinstance(group, dict):
                        continue
                    for unit in group.get("units") or []:
                        if isinstance(unit, dict) and (name := unit.get("name")):
                            names.add(str(name))
    return names


def find_missing_trigger_zone_refs(
    mission_yaml: dict[str, Any], mission_content: dict[str, Any]
) -> list[tuple[str, str, str]]:
    """Return ``(section, zone_name, level)`` for trigger-zone refs absent from the mission.

    AIRWAVES ``trigger_zone_name`` is optional when the zone also carries an explicit
    ``zone_center_coordinates`` + ``zone_radius`` (level "warning"); QRA ``trigger_zone``
    and a COMBATZONE *zone*'s ``zone_name`` are mandatory (level "error"). A COMBATZONE
    *operation*'s ``zone_name`` is **not** checked: at runtime ``VeafCombatOperation:initialize()``
    never resolves it as a trigger zone (it is only a label/radio-menu name), unlike a plain
    ``VeafCombatZone`` whose ``initialize()`` errors without its trigger zone.
    """
    present = collect_mission_zone_names(mission_content)
    modules = mission_yaml.get("modules") or {}
    issues: list[tuple[str, str, str]] = []

    for zone in _module_cfg(modules, "AIRWAVES").get("airwave_zones") or []:
        if not isinstance(zone, dict):
            continue
        tz = zone.get("trigger_zone_name")
        if not tz or str(tz) in present:
            continue
        has_fallback = bool(zone.get("zone_center_coordinates")) and bool(zone.get("zone_radius"))
        issues.append(("AIRWAVES", str(tz), LEVEL_WARNING if has_fallback else LEVEL_ERROR))

    for qra_def in _module_cfg(modules, "QRA").get("definitions") or []:
        if isinstance(qra_def, dict) and (tz := qra_def.get("trigger_zone")) and str(tz) not in present:
            issues.append(("QRA", str(tz), LEVEL_ERROR))

    for zone_def in _module_cfg(modules, "COMBATZONE").get("combat_zones") or []:
        if not isinstance(zone_def, dict) or zone_def.get("type") == "operation":
            continue  # an operation's zone_name is a label, not a required trigger zone
        if (zn := zone_def.get("zone_name")) and str(zn) not in present:
            issues.append(("COMBATZONE", str(zn), LEVEL_ERROR))

    return issues


def find_missing_sanctuary_units(
    mission_yaml: dict[str, Any], mission_content: dict[str, Any]
) -> list[tuple[str, str, str]]:
    """Return ``(section, name, "error")`` for SANCTUARY ``polygon_units`` absent from the mission.

    A name is accepted if it matches a **unit or a group**, mirroring the runtime:
    ``VeafSanctuaryZone:setPolygonFromUnits`` resolves each name with ``Unit.getByName`` and, failing
    that, ``Group.getByName(name):getUnit(1)`` — so the demo's polygon groups (named
    ``Sanctuary_Kutaisi_Polygon #NNN`` with a unit ``Ground-1-1`` inside) are valid, and a
    unit-names-only check flagged 16 real, working references as errors.
    """
    present = collect_mission_unit_names(mission_content) | collect_mission_group_names(mission_content)
    modules = mission_yaml.get("modules") or {}
    issues: list[tuple[str, str, str]] = []
    for zone in _module_cfg(modules, "SANCTUARY").get("sanctuary_zones") or []:
        if not isinstance(zone, dict):
            continue
        for unit in zone.get("polygon_units") or []:
            if str(unit) not in present:
                issues.append(("SANCTUARY", str(unit), LEVEL_ERROR))
    return issues


def find_unknown_airport_links(mission_yaml: dict[str, Any], theatre: str | None) -> list[tuple[str, str, str]]:
    """Return ``(section, airfield, "error")`` for QRA ``airport_link`` values unknown on the theatre.

    Skips entirely when the theatre has no airdrome table (the data is install-dependent),
    to avoid flagging every airfield on an uncovered map.
    """
    from veaf_libs.dcs_airdromes import airdromes_for_theatre  # noqa: PLC0415 - avoid import cycle at module load

    if not theatre:
        return []
    known = airdromes_for_theatre(theatre)
    if not known:
        return []
    modules = mission_yaml.get("modules") or {}
    issues: list[tuple[str, str, str]] = []
    for qra_def in _module_cfg(modules, "QRA").get("definitions") or []:
        if isinstance(qra_def, dict) and (al := qra_def.get("airport_link")) and str(al).strip().lower() not in known:
            issues.append(("QRA.airport_link", str(al), LEVEL_ERROR))
    return issues


def find_undeclared_operation_subzones(mission_yaml: dict[str, Any]) -> list[tuple[str, str, str]]:
    """Return ``(section, subzone, "error")`` for tasking-order refs not declared as combat_zones.

    A COMBATZONE operation's ``tasking_orders[].zone_name`` and ``dependencies[]`` must each
    name a non-operation ``combat_zones[]`` entry declared in the same mission.yaml, else the
    generated ``GetZone()`` resolves to ``nil`` at runtime.
    """
    modules = mission_yaml.get("modules") or {}
    combat_zones = _module_cfg(modules, "COMBATZONE").get("combat_zones") or []
    declared = {
        str(z.get("zone_name"))
        for z in combat_zones
        if isinstance(z, dict) and z.get("type", "zone") != "operation" and z.get("zone_name")
    }
    issues: list[tuple[str, str, str]] = []
    for z in combat_zones:
        if not isinstance(z, dict) or z.get("type") != "operation":
            continue
        op_name = str(z.get("zone_name") or z.get("friendly_name") or "operation")
        for order in z.get("tasking_orders") or []:
            if not isinstance(order, dict):
                continue
            refs: list[str] = []
            if zn := order.get("zone_name"):
                refs.append(str(zn))
            refs.extend(str(d) for d in order.get("dependencies") or [])
            for ref in refs:
                if ref not in declared:
                    issues.append((f"COMBATZONE.operation[{op_name}]", ref, LEVEL_ERROR))
    return issues
