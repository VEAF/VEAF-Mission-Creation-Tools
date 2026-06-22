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
