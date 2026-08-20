"""Domain-knowledge oracle — read-only DCS + VEAF authoring facts (wave 5).

The "brain" the LLM queries before authoring a mission: DCS unit types, VEAF spawn aliases, the
reserved group/unit naming conventions, and VEAF module lookup. Every fact is read from the SAME
canonical sources the build uses — the generated `dcsUnits.yaml`, `veaf-units.yaml`, and the Lua
module scanner — so the oracle cannot drift from what the tooling actually ships (see
`.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`, wave 5).
"""

from pathlib import Path
from typing import Any

import yaml
from mission_tools.mission_yaml_editor import load_yaml
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.veaf_shortcuts_scanner import get_shortcuts

_DOC_SCRIPTS_DIR = "doc/mission-maker/scripts"


def _load_bundled_data_yaml(filename: str) -> dict[str, Any]:
    """Load a bundled `veaf_libs/data/<filename>` YAML (source or PyInstaller run)."""
    return yaml.safe_load(read_bundled_text("veaf_libs", "data", filename)) or {}


def list_unit_types(
    category: str | None = None,
    name_contains: str | None = None,
) -> dict[str, Any]:
    """List DCS unit types from the canonical generated database.

    Reads the same `veaf_libs/data/dcsUnits.yaml` the build ships (`update-dcs-data`), so the
    LLM sees exactly the types available in-game.

    Args:
        category: Optional exact category filter (e.g. ``"Plane"``, ``"Armor"``).
        name_contains: Optional case-insensitive substring matched against type id + name.

    Returns:
        `{"units": [{"type", "name", "category", "kind", "description", "attributes"}, ...]}`.
    """
    raw = _load_bundled_data_yaml("dcsUnits.yaml").get("units") or []
    units: list[dict[str, Any]] = []
    needle = name_contains.lower() if name_contains else None
    for entry in raw:
        unit = {
            "type": entry.get("type", ""),
            "name": entry.get("name", ""),
            "category": entry.get("category", ""),
            "kind": entry.get("kind", ""),
            "description": entry.get("description", ""),
            "attributes": list(entry.get("attributes") or []),
        }
        if category is not None and unit["category"] != category:
            continue
        if needle is not None and needle not in f"{unit['type']}{unit['name']}".lower():
            continue
        units.append(unit)
    return {"units": units}


#: Ordered (category, keywords) rules to classify a `#command` alias — first match wins, so more
#: specific families come first. Derived from the alias + its description, so the assistant can
#: enumerate e.g. "all the SAM aliases" instead of substring-guessing. Uncategorized → "other".
_COMMAND_CATEGORY_RULES: list[tuple[str, tuple[str, ...]]] = [
    (
        "SAM",
        (
            "sam",
            "sa-",
            "sa2",
            "sa3",
            "sa6",
            "sa8",
            "sa10",
            "sa11",
            "sa13",
            "sa15",
            "sa19",
            "hq7",
            "manpad",
            "stinger",
            "igla",
            "avenger",
            "patriot",
            "hawk",
            "roland",
        ),
    ),
    ("AAA", ("aaa", "flak", "shilka", "zu-23", "zsu", "gepard")),
    ("artillery", ("arty", "artillery", "mortar", "grad", "msta", "smerch", "uragan", "mlrs")),
    ("armor", ("armor", "armour", "tank", " apc", "ifv")),
    ("infantry", ("infantry", "soldier", "squad", "manpads")),
    ("naval", ("ship", "boat", "naval", "carrier", "frigate", "cruiser", "destroyer")),
    ("transport", ("transport", "truck", "convoy", "logistic")),
    ("air", ("cap", "awacs", "tanker", "airplane", "helicopter", "drone", "afac")),
    ("ewr", ("ewr", "early warning")),
]


def _command_category(aliases: list[str], description: str) -> str:
    """Classify a `#command` alias into a coarse family (SAM/AAA/infantry/…) from its text."""
    haystack = f"{' '.join(aliases)} {description}".lower()
    for category, keywords in _COMMAND_CATEGORY_RULES:
        if any(keyword in haystack for keyword in keywords):
            return category
    return "other"


def list_shortcuts(name_contains: str | None = None) -> dict[str, Any]:
    """List the VEAF spawn aliases (the `-shilka`/`-sa8`… vocabulary).

    Three families, all part of the VEAF spawn vocabulary:

    - ``units`` / ``groups``: `veafUnits` aliases from the canonical `veaf_libs/data/veaf-units.yaml`
      (``_spawn unit <alias>`` / ``_spawn group <alias>``).
    - ``commands``: the high-level ``#command`` shortcuts declared in
      `veafShortcuts.buildDefaultList()` (``-samLR``, ``-armor``, random convoys…), scanned from the
      Lua source. These are what a combat-zone fake-unit carries as ``#command="-<alias> …"``.

    Args:
        name_contains: Optional case-insensitive substring matched against aliases + target.

    Returns:
        `{"units": [{"aliases", "unitType"}, ...], "groups": [{"aliases", "groupName",
        "description"}, ...], "commands": [{"aliases", "description", "veafCommand", "category"},
        ...]}`. ``category`` is a coarse family (SAM/AAA/infantry/armor/artillery/naval/transport/
        air/ewr/other) so aliases can be enumerated by kind.
    """
    data = _load_bundled_data_yaml("veaf-units.yaml")
    needle = name_contains.lower() if name_contains else None

    def _matches(aliases: list[str], target: str) -> bool:
        if needle is None:
            return True
        return needle in f"{' '.join(aliases)} {target}".lower()

    units = [
        {"aliases": list(e.get("aliases") or []), "unitType": e.get("unitType", "")}
        for e in (data.get("units") or [])
        if _matches(list(e.get("aliases") or []), e.get("unitType", ""))
    ]
    groups = [
        {
            "aliases": list(e.get("aliases") or []),
            "groupName": e.get("groupName", ""),
            "description": e.get("description", ""),
        }
        for e in (data.get("groups") or [])
        if _matches(list(e.get("aliases") or []), e.get("groupName", ""))
    ]
    commands = [
        {
            "aliases": list(e.get("aliases") or []),
            "description": e.get("description", ""),
            "veafCommand": e.get("veafCommand", ""),
            "category": _command_category(list(e.get("aliases") or []), e.get("description", "")),
        }
        for e in get_shortcuts()
        if _matches(list(e.get("aliases") or []), f"{e.get('description', '')} {e.get('veafCommand', '')}")
    ]
    return {"units": units, "groups": groups, "commands": commands}


_NAMING_CONVENTIONS: list[dict[str, Any]] = [
    {
        "id": "combat_zone_membership",
        "rule": "A group whose name starts with a combat-zone trigger-zone name, placed inside "
        "that zone, is captured and despawned at start (respawned on activation).",
        "module": "veafCombatZone",
        "reserved": True,
    },
    {
        "id": "spawn_template",
        "rule": "A group named 'veafSpawn-<name>' is auto-registered as a spawnable-aircraft template.",
        "module": "veafSpawn",
        "reserved": True,
    },
    {
        "id": "cap_template",
        "rule": "A CAP mission expects a late-activation template group named 'OnDemand-<missionName>'.",
        "module": "veafCombatMission",
        "reserved": True,
    },
    {
        "id": "coalition_placeholder",
        "rule": "'VEAF-placeholder-<side>' groups are injected by the build; do not author them.",
        "module": "coalition_placeholder (build)",
        "reserved": True,
    },
    {
        "id": "interpreter_command",
        "rule": "A unit/static name containing '#veafInterpreter[\"<cmd>\"]' runs that command "
        "and the carrying unit is destroyed at mission start.",
        "module": "veafInterpreter",
        "reserved": True,
    },
    {
        "id": "combat_zone_unit_markers",
        "rule": "Unit-name markers '#command=', '#spawngroup=', '#spawnradius=', '#spawncount=', "
        "'#spawnchance=', '#spawndelay=', '#alarm=' tune combat-zone spawn behaviour.",
        "module": "veafCombatZone",
        "reserved": True,
    },
    {
        "id": "qra_deploy_entry",
        "rule": "A QRA deploy entry starting with '[' or '-' is interpreted as a command, not a "
        "group name; a referenced group name must match a real ME group verbatim.",
        "module": "veafQraManager",
        "reserved": True,
    },
    {
        "id": "cas_runtime_group",
        "rule": "'Red CAS Group' / 'Blue CAS Group' are fixed runtime names used by the CAS mission module.",
        "module": "veafCasMission",
        "reserved": True,
    },
]


def describe_naming_conventions() -> dict[str, Any]:
    """Return the reserved VEAF group/unit naming conventions an author must respect.

    These are rules (not external data): a group/unit name matching one of them is interpreted
    specially by a VEAF module. An `add_group` caller should check a proposed name against them.

    Returns:
        `{"conventions": [{"id", "rule", "module", "reserved"}, ...]}`.
    """
    return {"conventions": [dict(convention) for convention in _NAMING_CONVENTIONS]}


def _module_enabled(mission_yaml_path: Path, module_id: str) -> bool | None:
    """Return whether `module_id` is enabled in `mission_yaml_path`, or None if absent/unknown."""
    data = load_yaml(mission_yaml_path)
    modules: Any = data.get("modules") if hasattr(data, "get") else None
    if not hasattr(modules, "get"):
        return None
    value = modules.get(module_id)
    if isinstance(value, bool):
        return value
    if hasattr(value, "get"):
        enabled = value.get("enabled")
        return enabled if isinstance(enabled, bool) else None
    return None


def describe_module(module_id: str, mission_yaml_path: Path | None = None) -> dict[str, Any]:
    """Look a VEAF module up in the canonical module list and point to its doc.

    Uses `veaf_libs.lua_module_scanner.get_modules` (the same list the build uses) as the source
    of truth for which modules exist. Deliberately a locator, not a schema validator: per-module
    keys live in the module's own doc page, which this returns a pointer to.

    Args:
        module_id: The module id (e.g. ``"QRA"``, ``"COMBATZONE"``), case-insensitive.
        mission_yaml_path: Optional `mission.yaml`; if given, reports the module's enabled state.

    Returns:
        `{"known": bool, "id", "version", "doc_page", "enabled"}` — `id`/`version`/`doc_page`
        present only when known; `enabled` present only when `mission_yaml_path` is given.
    """
    wanted = module_id.upper()
    match = next((m for m in get_modules() if m["id"].upper() == wanted), None)
    if match is None:
        return {"known": False, "id": module_id}
    result: dict[str, Any] = {
        "known": True,
        "id": match["id"],
        "version": match["version"],
        "doc_page": f"{_DOC_SCRIPTS_DIR}/{match['var_name']}.md",
    }
    if mission_yaml_path is not None:
        result["enabled"] = _module_enabled(mission_yaml_path, match["id"])
    return result
