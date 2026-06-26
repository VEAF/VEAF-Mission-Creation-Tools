"""Export a parsed DCS mission to interoperable formats (JSON / YAML / Markdown).

The whole point of this module is **safety**: it serializes a `.miz` that was read with the
pure-Python ``luadata`` parser (via :func:`mission_tools.read_miz`) and **never executes Lua**.
It is the safe alternative to running a `.miz`'s ``mission`` file through a Lua interpreter
(an untrusted `.miz` can embed arbitrary Lua — an RCE risk; see FEAT-EXPORT-MISSION).

Formats:
  * ``json`` — the structured pivot (`{theatre, mission, dictionary, mapResource}`), machine-readable.
  * ``yaml`` — the same object, human-readable.
  * ``markdown`` — a human-friendly mission brief (overview, order of battle, zones, logic, scripts),
    inspired by the BFR ``dcs-mission-tools`` ``map-mission`` view.
"""

from __future__ import annotations

import json
from typing import Any

import yaml

from mission_tools.miz_tools import DcsMission

#: DCS unit-group categories carried under each country in the mission table.
_GROUP_CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")

#: Bumped on any breaking change to the export contract (``doc/developer/export-json-contract.md``).
SCHEMA_VERSION: int = 1


def _is_int_sequence(value: dict[Any, Any]) -> bool:
    """Return ``True`` when *value*'s keys are exactly the contiguous integers ``1..n`` (n ≥ 1)."""
    if not value:
        return False
    keys = value.keys()
    if not all(isinstance(k, int) and not isinstance(k, bool) for k in keys):
        return False
    return set(keys) == set(range(1, len(keys) + 1))


def _normalize_arrayness(value: Any) -> Any:
    """Map a parsed Lua value to its JSON contract shape (export-json-contract.md §2).

    ``read_miz`` parses ``mission`` with ``keep_as_dict=["trig", "trigrules"]``, which leaves those
    numerically-indexed subtrees as int-keyed **dicts** (load-bearing for the trigger-injection
    builder, which mutates them by 1-based index). This **export-only** pass turns any dict whose
    keys are exactly the contiguous integers ``1..n`` into a list, so it serializes to a JSON
    **array** and the BFR plugin's ``#t`` / ``ipairs`` work after decoding. Sparse, mixed and empty
    tables stay objects (with string keys); the plugin's decoder coerces integer-string keys back.

    The parser and the builder are not touched — this is a pure presentation transform on the export
    object.

    Args:
        value: A value from a :class:`DcsMission` content table (dict, list, or scalar).

    Returns:
        The value with contiguous int-keyed dicts turned into lists, recursively.
    """
    if isinstance(value, dict):
        if _is_int_sequence(value):
            return [_normalize_arrayness(value[i]) for i in range(1, len(value) + 1)]
        return {str(key): _normalize_arrayness(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_normalize_arrayness(item) for item in value]
    return value


def build_export_object(mission: DcsMission) -> dict[str, Any]:
    """Build the structured export object from a parsed mission.

    Args:
        mission: A :class:`DcsMission` read with :func:`mission_tools.read_miz` (pure-Python parse).

    Returns:
        ``{"schemaVersion", "theatre", "mission", "dictionary", "mapResource"}`` — the frozen
        contract (``doc/developer/export-json-contract.md``) the BFR plugin consumes as a drop-in,
        Lua-free alternative to its ``lua54.exe`` parsing. Numerically-indexed tables are emitted as
        JSON arrays (see :func:`_normalize_arrayness`).
    """
    return {
        "schemaVersion": SCHEMA_VERSION,
        "theatre": mission.theatre_content or None,
        "mission": _normalize_arrayness(mission.mission_content or {}),
        "dictionary": _normalize_arrayness(mission.dictionary_content or {}),
        "mapResource": _normalize_arrayness(mission.map_resource_content or {}),
    }


def to_json(obj: dict[str, Any], *, compact: bool = False) -> str:
    """Serialize the export object to JSON (``indent=2`` unless *compact*)."""
    if compact:
        return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    return json.dumps(obj, ensure_ascii=False, indent=2)


def to_yaml(obj: dict[str, Any]) -> str:
    """Serialize the export object to YAML (readable, keys preserved)."""
    return yaml.dump(obj, default_flow_style=False, sort_keys=False, allow_unicode=True)


# ---------------------------------------------------------------------------
# Markdown brief
# ---------------------------------------------------------------------------


def _resolve(text: Any, dictionary: dict[str, str]) -> str:
    """Resolve a ``DictKey_*`` reference through the dictionary; pass plain strings through."""
    if isinstance(text, str) and text.startswith("DictKey_"):
        return dictionary.get(text, text)
    return str(text) if text is not None else ""


def _order_of_battle(content: dict[str, Any]) -> list[str]:
    """One Markdown block per coalition: group counts per category + a few named groups."""
    lines: list[str] = []
    coalitions = content.get("coalition") or {}
    if not isinstance(coalitions, dict):
        return lines
    for side, coalition in coalitions.items():
        if not isinstance(coalition, dict):
            continue
        counts: dict[str, int] = {}
        sample: list[str] = []
        for country in coalition.get("country") or []:
            if not isinstance(country, dict):
                continue
            for category in _GROUP_CATEGORIES:
                container = country.get(category) or {}
                groups = container.get("group") if isinstance(container, dict) else None
                groups = list(groups.values()) if isinstance(groups, dict) else (groups or [])
                if not groups:
                    continue
                counts[category] = counts.get(category, 0) + len(groups)
                for group in groups:
                    if isinstance(group, dict) and len(sample) < 8:
                        units = group.get("units")
                        units = list(units.values()) if isinstance(units, dict) else (units or [])
                        utype = units[0].get("type", "?") if units and isinstance(units[0], dict) else "?"
                        sample.append(f"{group.get('name', '?')} ({utype})")
        if not counts:
            continue
        lines.append(f"### {side.capitalize()}")
        lines.append(", ".join(f"{n} {cat}{'s' if n > 1 else ''}" for cat, n in counts.items()))
        if sample:
            lines.append("")
            lines += [f"- {s}" for s in sample]
        lines.append("")
    return lines


def _zones(content: dict[str, Any]) -> list[str]:
    """List trigger-zone names."""
    zones = (content.get("triggers") or {}).get("zones") or []
    if isinstance(zones, dict):
        zones = list(zones.values())
    names = [str(z.get("name")) for z in zones if isinstance(z, dict) and z.get("name")]
    return [f"- {n}" for n in names] if names else ["*(none)*"]


def _mission_logic(content: dict[str, Any]) -> list[str]:
    """Summarize trigger rules, separating VEAF-injected from mission-specific ones."""
    rules = content.get("trigrules") or content.get("trig") or {}
    rule_list = rules.get("comment", []) if isinstance(rules, dict) else []
    if isinstance(rule_list, dict):
        rule_list = list(rule_list.values())
    comments = [str(c) for c in rule_list if c]
    veaf = [c for c in comments if c.upper().startswith("VEAF") or "VEAF" in c.upper()]
    other = [c for c in comments if c not in veaf]
    out = [f"- **{len(comments)} trigger rule(s)** — {len(veaf)} VEAF-injected, {len(other)} mission-specific"]
    out += [f"  - {c}" for c in other[:15]]
    return out


def _scripts(map_resource: dict[str, str]) -> list[str]:
    """List the Lua scripts referenced by the mission's map resources."""
    scripts = sorted({v for v in (map_resource or {}).values() if isinstance(v, str) and v.endswith(".lua")})
    return [f"- `{s}`" for s in scripts] if scripts else ["*(none)*"]


def to_markdown(mission: DcsMission) -> str:
    """Build a human-friendly Markdown mission brief from a parsed mission."""
    content = mission.mission_content or {}
    dictionary = mission.dictionary_content or {}
    map_resource = mission.map_resource_content or {}

    date = content.get("date") or {}
    date_str = f"{date.get('Year', '?')}-{date.get('Month', '?'):0>2}-{date.get('Day', '?'):0>2}" if date else "?"
    start = content.get("start_time")
    start_str = f"{start // 3600:02d}:{(start % 3600) // 60:02d}" if isinstance(start, int) else "?"
    title = _resolve(content.get("sortie"), dictionary) or "DCS mission"
    description = _resolve(content.get("descriptionText"), dictionary)

    md: list[str] = [f"# {title}", ""]
    md += ["## Overview", ""]
    md += [f"- **Theatre**: {mission.theatre_content or '?'}"]
    md += [f"- **Date / start**: {date_str} {start_str}"]
    if description:
        md += ["", "> " + description.replace("\n", "\n> ")]
    md += [""]

    md += ["## Order of battle", ""]
    oob = _order_of_battle(content)
    md += oob if oob else ["*(no groups)*", ""]

    md += ["## Zones", ""]
    md += _zones(content)
    md += ["", "## Mission logic", ""]
    md += _mission_logic(content)
    md += ["", "## Scripts", ""]
    md += _scripts(map_resource)
    md += [""]
    return "\n".join(md)


def export_mission(mission: DcsMission, fmt: str, *, compact: bool = False) -> str:
    """Render a parsed mission in *fmt* (``json`` / ``yaml`` / ``markdown``).

    Raises:
        ValueError: when *fmt* is not one of the supported formats.
    """
    if fmt == "json":
        return to_json(build_export_object(mission), compact=compact)
    if fmt == "yaml":
        return to_yaml(build_export_object(mission))
    if fmt == "markdown":
        return to_markdown(mission)
    raise ValueError(f"Unsupported export format: {fmt!r} (expected json, yaml or markdown)")
