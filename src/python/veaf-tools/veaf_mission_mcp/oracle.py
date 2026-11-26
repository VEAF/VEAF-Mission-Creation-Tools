"""Domain-knowledge oracle — read-only DCS + VEAF authoring facts (wave 5).

The "brain" the LLM queries before authoring a mission: DCS unit types, VEAF spawn aliases, the
reserved group/unit naming conventions, and VEAF module lookup. Every fact is read from the SAME
canonical sources the build uses — the generated `dcsUnits.yaml`, `veaf-units.yaml`, and the Lua
module scanner — so the oracle cannot drift from what the tooling actually ships (see
`.backlog/archive/FEAT-MCP-MISSION-EDITOR.md`, wave 5).
"""

import re
from pathlib import Path
from typing import Any

import yaml
from mission_tools.mission_constants import get_community_script_files, is_community_script_enabled_by_default
from mission_tools.mission_yaml_editor import load_yaml
from veaf_libs import shortcut_eras
from veaf_libs.build_stamp import _package_version
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.dcs_payloads import payload_names, payload_pylons, payload_types
from veaf_libs.known_limitations import active_limitations, load_known_limitations
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.veaf_shortcuts_scanner import get_shortcuts

from veaf_mission_mcp.profile import is_compact

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
        `{"units": [{"type", "name", "category", "kind", "description", "attributes",
        "threat_range_m"?, "detection_range_m"?}, ...]}` — the ranges in metres where DCS gives one
        (``ThreatRange`` / ``DetectionRange``, what the Mission Editor draws its circles from).
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
        # Only where DCS has one: the Mission Editor's range circles (FIX-OPEN-TRAINING-SYRIA-FINDINGS 08).
        for key in ("threat_range_m", "detection_range_m"):
            if entry.get(key):
                unit[key] = entry[key]
        if category is not None and unit["category"] != category:
            continue
        if needle is not None and needle not in f"{unit['type']}{unit['name']}".lower():
            continue
        units.append(unit)
    return {"units": units}


def list_countries(name_contains: str | None = None) -> dict[str, Any]:
    """List the DCS countries a group can belong to, with the id `add_group` and its siblings take.

    The AI read `dcs-countries.yaml` out of the exe's unpacked files for Turkey, Syria, Russia and
    the USA (FIX-OPENCODE-TEST-FINDINGS 03).

    Args:
        name_contains: Optional case-insensitive text matched against the name, the Mission Editor's
            name and the short code.

    Returns:
        `{"countries": [{"id", "name", "short"?}, ...]}`, in id order.
    """
    needle = name_contains.lower() if name_contains else None
    countries: list[dict[str, Any]] = []
    for entry in _load_bundled_data_yaml("dcs-countries.yaml").get("countries") or []:
        spellings = " ".join(str(entry.get(key) or "") for key in ("name", "international", "short")).lower()
        if needle is not None and needle not in spellings:
            continue
        country: dict[str, Any] = {"id": int(entry["id"]), "name": entry["name"]}
        if entry.get("short"):
            country["short"] = entry["short"]
        countries.append(country)
    return {"countries": sorted(countries, key=lambda c: c["id"])}


def list_payloads(unit_type: str | None = None) -> dict[str, Any]:
    """List DCS's default loadouts for an aircraft type, by the names the Mission Editor offers.

    Args:
        unit_type: The exact DCS type; ``None`` lists the types that have loadouts.

    Returns:
        ``{"unit_type", "payloads": [{"name", "pylons": {station: CLSID}}, ...]}`` for a type — in the
        compact profile ``{"unit_type", "payloads": [name, ...]}`` — or ``{"types": [...]}`` without one
        (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 09).

    Raises:
        ValueError: For a type with no DCS loadout, naming the types that have some.
    """
    if unit_type is None:
        return {"types": payload_types()}
    names = payload_names(unit_type)
    if not names:
        raise ValueError(f"DCS has no named loadout for {unit_type!r}; types that have some: {payload_types()}")
    if is_compact():
        # The names alone: the actions take a loadout by its name, and the MiG-29A's pylons were 6 424
        # characters of CLSIDs in a local model's run (MCP-CONTEXT-BUDGET, run 7).
        return {"unit_type": unit_type, "payloads": list(names)}
    return {
        "unit_type": unit_type,
        "payloads": [
            {
                "name": name,
                "pylons": {station: entry["CLSID"] for station, entry in payload_pylons(unit_type, name).items()},
            }
            for name in names
        ],
    }


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


def list_shortcuts(name_contains: str | None = None, era: str | None = None) -> dict[str, Any]:
    """List the VEAF spawn aliases (the `-shilka`/`-sa8`… vocabulary).

    Three families, all part of the VEAF spawn vocabulary:

    - ``units`` / ``groups``: `veafUnits` aliases from the canonical `veaf_libs/data/veaf-units.yaml`
      (``_spawn unit <alias>`` / ``_spawn group <alias>``).
    - ``commands``: the high-level ``#command`` shortcuts declared in
      `veafShortcuts.buildDefaultList()` (``-samLR``, ``-armor``, random convoys…), scanned from the
      Lua source. These are what a combat-zone fake-unit carries as ``#command="-<alias> …"``.

    Every entry carries an ``era``, read from what it spawns (:mod:`veaf_libs.shortcut_eras`) rather than
    typed beside it: ``follows_era`` (``-aaa``, ``-samLR``, ``-armor``, ``-infantry``, ``-transport``,
    ``-combat``, ``-convoy``, ``-cas``: the units come from tables keyed by ``mission.era``), ``ww2``,
    ``post_ww2`` (a fixed modern or Cold War piece of equipment: ``-sa6``, ``-ewr``, ``-arty``), ``era_free``
    (spawns no equipment) or ``unknown`` (``-jtac``, ``-afac``, ``-cargo``: not measured, so not claimed).

    Args:
        name_contains: Optional case-insensitive substring matched against aliases + target.
        era: Optional mission era (``WW2``, ``COLD_WAR``, ``MODERN``): keeps what is worth offering in it — in a
            WW2 mission the ``follows_era``, ``era_free`` and ``ww2`` entries only.

    Returns:
        `{"units": [{"aliases", "unitType", "era"}, ...], "groups": [{"aliases", "groupName",
        "description", "era"}, ...], "commands": [{"aliases", "description", "veafCommand",
        "randomParameters", "category", "era"}, ...]}`. ``randomParameters`` maps each parameter drawn at
        random on every use to its ``{"min", "max"}`` range — `-samLR` and `-samSR` run the same
        command and differ only by their ``defense`` range. ``category`` is a coarse family
        (SAM/AAA/infantry/armor/artillery/naval/transport/air/ewr/other) so aliases can be
        enumerated by kind.
    """
    data = _load_bundled_data_yaml("veaf-units.yaml")
    needle = name_contains.lower() if name_contains else None
    if era is not None and era not in ("WW2", "COLD_WAR", "MODERN"):
        raise ValueError(f"era must be WW2, COLD_WAR or MODERN, got {era!r}")

    def _in_era(entry_era: str) -> bool:
        return era is None or shortcut_eras.fits_era(entry_era, era)

    def _matches(aliases: list[str], target: str) -> bool:
        if needle is None:
            return True
        return needle in f"{' '.join(aliases)} {target}".lower()

    units = [
        {
            "aliases": list(e.get("aliases") or []),
            "unitType": e.get("unitType", ""),
            "era": shortcut_eras.equipment_era([e.get("unitType", "")]),
        }
        for e in (data.get("units") or [])
        if _matches(list(e.get("aliases") or []), e.get("unitType", ""))
        and _in_era(shortcut_eras.equipment_era([e.get("unitType", "")]))
    ]
    groups = [
        {
            "aliases": list(e.get("aliases") or []),
            "groupName": e.get("groupName", ""),
            "description": e.get("description", ""),
            "era": shortcut_eras.equipment_era([u["type"] for u in e.get("units") or [] if "type" in u]),
        }
        for e in (data.get("groups") or [])
        if _matches(list(e.get("aliases") or []), e.get("groupName", ""))
        and _in_era(shortcut_eras.equipment_era([u["type"] for u in e.get("units") or [] if "type" in u]))
    ]
    commands = [
        {
            "aliases": list(e.get("aliases") or []),
            "description": e.get("description", ""),
            "veafCommand": e.get("veafCommand", ""),
            "randomParameters": dict(e.get("randomParameters") or {}),
            "category": _command_category(list(e.get("aliases") or []), e.get("description", "")),
            "era": shortcut_eras.era_of_command(e.get("veafCommand", "")),
        }
        for e in get_shortcuts()
        if _matches(list(e.get("aliases") or []), f"{e.get('description', '')} {e.get('veafCommand', '')}")
        and _in_era(shortcut_eras.era_of_command(e.get("veafCommand", "")))
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


def describe_known_limitations(
    kind: str | None = None,
    area: str | None = None,
    theatre: str | None = None,
    id: str | list[str] | None = None,  # noqa: A002 - the action's parameter name
    full: bool = False,
) -> dict[str, Any]:
    """Return what an author must know before building a mission, for the running version.

    Read from the one shipped file ``veaf_libs/data/known-limitations.yaml``: the limitations of
    veaf-tools not yet fixed in this version, and the DCS behaviours that raise no error and are
    wrong anyway (always returned — DCS is not ours to fix).

    Without ``id`` or ``full``, only a short listing comes back — ``id``, ``kind``, ``area``,
    ``theatres`` of each entry: the whole text is about 74 000 characters, more than a tool result can
    carry, and an author needs a tenth of it (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 10). In the
    compact profile, the ids alone, grouped by area: one object per entry was 13 008 characters, a
    local model's tenth of its context before its first action; the kebab-case ids read as phrases
    (MCP-CONTEXT-BUDGET). ``kind``, ``area`` and
    ``theatre`` narrow the listing and keep it short: three areas in full were 46 000 characters in
    one call, sent back with every later turn of the session (FIX-OPENCODE-TEST-FINDINGS 06). One or
    more ``id`` return those entries in full.

    Args:
        kind: Optional ``"tool"`` or ``"dcs"`` to return one kind only.
        area: Optional area (``spawning``, ``air-defence``, ``players``, ``radio``, ``ground-ai``,
            ``scripting``, ``mcp``, ``pipeline``, ``runtime``).
        theatre: Optional theatre: drops the entries that concern other theatres only. An entry with
            no ``theatres`` applies everywhere and is always kept.
        id: One entry id, or a list of them.
        full: Return every selected entry in full, whatever the filters.

    Returns:
        `{"veaf_tools_version", "detail": "short", "limitations": [{"id", "kind", "area", "theatres"?}],
        "areas": {area: count}}` for a short listing, `{"veaf_tools_version", "detail": "short", "by_area":
        {area: [id, ...]}}` in the compact profile;
        `{"veaf_tools_version", "detail": "full", "limitations": [...]}` otherwise, an entry being
        `{"id", "kind", "area", "title", "symptom", "workaround", "theatres"?, "cost"?, "measured"?,
        "fixed_in"?}`.

    Raises:
        ValueError: An ``id`` names no entry.
    """
    version = _package_version()
    entries = active_limitations(load_known_limitations(), version, kind=kind)
    ids = [id] if isinstance(id, str) else list(id or [])
    if ids:
        unknown = sorted(set(ids) - {entry["id"] for entry in entries})
        if unknown:
            raise ValueError(f"no known limitation with id {unknown}; read the short listing for the ids")
        entries = [entry for entry in entries if entry["id"] in ids]
    if area:
        entries = [entry for entry in entries if entry.get("area") == area]
    if theatre:
        wanted = theatre.strip().lower()
        entries = [
            entry
            for entry in entries
            if not entry.get("theatres") or wanted in {str(name).lower() for name in entry["theatres"]}
        ]
    short = not (full or ids)
    result: dict[str, Any] = {"veaf_tools_version": version, "detail": "short" if short else "full"}
    if short and is_compact():
        by_area: dict[str, list[str]] = {}
        for entry in entries:
            by_area.setdefault(entry["area"], []).append(entry["id"])
        result["by_area"] = by_area
    elif short:
        result["limitations"] = [
            {key: entry[key] for key in _LIMITATION_SUMMARY_FIELDS if key in entry} for entry in entries
        ]
        areas: dict[str, int] = {}
        for entry in entries:
            areas[entry["area"]] = areas.get(entry["area"], 0) + 1
        result["areas"] = areas
    else:
        result["limitations"] = [dict(entry) for entry in entries]
    return result


#: What the short listing keeps of an entry, in the standard profile. No title (FIX-LIMITATIONS-SHORT-LISTING):
#: with titles the listing reached 14 988 of the 15 000 characters a tool result holds; the kebab-case ids say
#: what an entry is about.
_LIMITATION_SUMMARY_FIELDS = ("id", "kind", "area", "theatres")


#: The mission prompts shipped in `data/mission-prompts/`, by the `kind` the action takes.
MISSION_PROMPT_KINDS: tuple[str, ...] = ("objective", "open-training", "persistent-campaign")
#: A prompt's file stem, by kind: `new-<kind>-mission` but for a campaign, which is no one mission.
_MISSION_PROMPT_STEMS = {"persistent-campaign": "new-persistent-campaign"}
MISSION_PROMPT_LANGS: tuple[str, ...] = ("en", "fr")


#: A guide section's heading: `## Title {#id}`, the id stable whatever the title says.
_GUIDE_HEADING = re.compile(r"^## (?P<title>.+?) \{#(?P<id>[a-z0-9-]+)\}[ \t]*$", re.MULTILINE)
#: The line under a guide section's heading saying when to read it: `<!-- when: ... -->`.
_GUIDE_WHEN = re.compile(r"^<!-- when: (?P<when>.+?) -->[ \t]*\n", re.MULTILINE)
#: The guide sections the compact profile's default answer carries whole: the calls of a simple mission with
#: their parameters, and the report; `start_here` stands for the first-message section, whose "every new
#: mission starts by choosing its kind, then loads its prompt" sent a local model to a 50 000-character
#: prompt (run 7). The others come by `section`, from the index. With the
#: recipe, a local model no longer described every action it might use: 19 describe_action were 30 555 of
#: the 106 857 characters of its run (MCP-CONTEXT-BUDGET, 2026-11-25).
GUIDE_ESSENTIAL_SECTIONS: tuple[str, ...] = ("recipe", "report-back")


def _guide_sections(text: str) -> tuple[str, list[dict[str, str]]]:
    """Split the authoring guide into its preamble and its `## ... {#id}` sections.

    Args:
        text: The guide's markdown.

    Returns:
        The text before the first section, then one `{"id", "title", "when", "text"}` per section, its
        text rendered as the model reads it: the heading without its id, no `when` line.

    Raises:
        ValueError: A `## ` heading without an id, or a section without its `when` line.
    """
    bare = [line for line in text.splitlines() if line.startswith("## ") and not _GUIDE_HEADING.match(line)]
    if bare:
        raise ValueError(f"guide headings without an id: {bare}")
    matches = list(_GUIDE_HEADING.finditer(text))
    preamble = text[: matches[0].start()] if matches else text
    sections: list[dict[str, str]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end() + 1 : end]
        when = _GUIDE_WHEN.match(body)
        if when is None:
            raise ValueError(f"guide section {match['id']!r} has no '<!-- when: ... -->' line")
        sections.append(
            {
                "id": match["id"],
                "title": match["title"],
                "when": when["when"],
                "text": f"## {match['title']}\n{body[when.end() :]}",
            }
        )
    return preamble, sections


#: Guidance to the model, in English as the whole guide: not a message to the user.
_COMPACT_ROUTING = (
    "A request that says what the mission holds (a zone, a SAM, a QRA, player slots, a date) is a simple "
    "mission, whatever word it uses (training, exercise, test): follow the recipe below and load no mission "
    "prompt. Load one only when the user asks for one of these by name or plainly wants it — an Open "
    "Training on a whole map, an objective mission with its briefing, a persistent campaign — and know "
    "its weight first, in characters: {sizes}. When a detail is missing, choose a sensible value and say "
    "so rather than ask. Pass the user's language as adapt_scaffold's 'language'; what a human reads keeps "
    "its accents, identifiers (mission, zone and group names) are ASCII."
)


def _compact_routing() -> str:
    """Say, first in the compact guide, when a mission prompt is worth its weight and when the recipe is enough.

    A local model asked for "a modern training mission" with a zone, a SAM and a QRA loaded the Open Training
    prompt: 12 pages, 77 622 of the run's 113 885 characters, and it filled 96 % of a 65 536-token context with
    a plan and questions, building nothing (MCP-CONTEXT-BUDGET, run 6, 2026-11-25). The sizes are read from the
    shipped prompts, so they stay true.

    Returns:
        The routing, one paragraph.
    """
    sizes = ", ".join(
        f"{kind} about {len(describe_mission_prompt(kind, 'en', part='all')['prompt']) // 1000} 000"
        for kind in MISSION_PROMPT_KINDS
    )
    return _COMPACT_ROUTING.format(sizes=sizes)


def describe_authoring_guide(section: str | list[str] | None = None) -> dict[str, Any]:
    """Return the VEAF mission authoring guide, the first thing an MCP client reads.

    With no argument it returns the whole guide, as it always has; in the compact profile, the sections
    every mission needs and an index of the others with when to read each: whole, it was 41 555
    characters, a sixth of a local model's context before its first action (MCP-CONTEXT-BUDGET).
    `section` reads one or more sections; `section="all"` the whole guide.

    Args:
        section: A section id, a list of them, or `"all"`.

    Returns:
        `{"guide": <markdown>}`; with no `section` in the compact profile, also `"sections"` — `{"id",
        "title", "when"}` of each section left out — and `"read_more"`, how to read one.

    Raises:
        ValueError: An unknown section id, named with the known ones.
    """
    preamble, sections = _guide_sections(read_bundled_text("veaf_mission_mcp", "data", "authoring-guide.md"))
    if section == "all" or (section is None and not is_compact()):
        return {"guide": preamble + "".join(entry["text"] for entry in sections)}
    if section is None:
        return {
            "start_here": _compact_routing(),
            "guide": preamble + "".join(entry["text"] for entry in sections if entry["id"] in GUIDE_ESSENTIAL_SECTIONS),
            "sections": [
                {key: entry[key] for key in ("id", "title", "when")}
                for entry in sections
                if entry["id"] not in GUIDE_ESSENTIAL_SECTIONS
            ],
            # The local model of run 5 still read 7 sections and 15 schemas the recipe made useless: 46 000
            # characters before its first action (MCP-CONTEXT-BUDGET, 2026-11-25).
            "read_more": "For a simple mission the recipe above is all you need: start with its first call, and "
            "neither read another section nor call describe_action for the recipe's actions. Read a section "
            "only for what the recipe does not cover (a QRA, a FARP, support aircraft, a briefing...): "
            "describe_authoring_guide with section=<id>.",
        }
    wanted = [section] if isinstance(section, str) else list(section)
    known = {entry["id"]: entry for entry in sections}
    unknown = [name for name in wanted if name not in known]
    if unknown:
        raise ValueError(f"Unknown guide section(s) {unknown}: expected 'all' or one of {', '.join(known)}.")
    return {"guide": "".join(known[name]["text"] for name in wanted)}


#: Where a mission prompt's part read after the user's approval starts (FIX-OPENCODE-TEST-FINDINGS 06).
_BUILD_PART_MARKER = "<!-- part: build -->\n"
#: The parts `describe_mission_prompt` takes; `all` is the whole text.
MISSION_PROMPT_PARTS: tuple[str, ...] = ("scenario", "build", "all")
#: A mission prompt's numbered heading, `## 4. Phase 2` or `### 4.6 Support`: the number is the section's
#: id, the same in French and English.
_PROMPT_HEADING = re.compile(r"^#{2,3} (?P<id>\d+(?:\.\d+)*)\.? (?P<title>.+)$", re.MULTILINE)
#: The text before a prompt's first numbered section.
PROMPT_INTRO_SECTION = "intro"
#: The most prompt text one page of the compact profile carries, in characters, under its response ceiling.
PROMPT_PAGE_CHARS = 7_000


def _prompt_sections(text: str, part: str | None) -> list[dict[str, str | None]]:
    """Split one part of a mission prompt into its numbered sections.

    Args:
        text: The part's markdown.
        part: The part's name, `None` for a prompt in one piece.

    Returns:
        One `{"id", "title", "text", "part"}` per section, in order; the text before the first numbered
        heading is the section `intro` when there is any.
    """
    matches = list(_PROMPT_HEADING.finditer(text))
    sections: list[dict[str, str | None]] = []
    head = text[: matches[0].start()] if matches else text
    if head.strip():
        sections.append({"id": PROMPT_INTRO_SECTION, "title": "", "text": head, "part": part})
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        sections.append({"id": match["id"], "title": match["title"], "text": text[match.start() : end], "part": part})
    return sections


def _whole_part(result: dict[str, Any], prompt: str, part: str | None) -> dict[str, Any]:
    """Return a prompt part whole, as the standard profile always has.

    Args:
        result: `{"kind", "lang"}`.
        prompt: The whole prompt.
        part: `scenario` (the default), `build`, or None.

    Returns:
        `{"kind", "lang", "prompt"}`, with `"part"` (and `"next_part"` after the scenario) for a prompt in two.
    """
    if _BUILD_PART_MARKER not in prompt:
        return {**result, "prompt": prompt}
    scenario, build = prompt.split(_BUILD_PART_MARKER, 1)
    if part == "build":
        return {**result, "prompt": build, "part": "build"}
    return {**result, "prompt": scenario, "part": "scenario", "next_part": "build"}


def describe_mission_prompt(
    kind: str, lang: str = "en", part: str | None = None, section: str | None = None
) -> dict[str, Any]:
    """Return the prompt that builds one kind of VEAF mission, one page at a time.

    They used to live in the repository's `.prompts/`, for the user to paste; shipped in the
    executable, a user only has to ask for a mission (FEAT-AI-ZERO-SETUP).

    A prompt whose design and build serve only once the user has approved a scenario is cut in two
    at a ``<!-- part: build -->`` line, and comes by default in its first part: sections 4-9 of the
    objective prompt, 21 000 of its 34 000 characters, were carried through every turn of the
    scenario discussion (FIX-OPENCODE-TEST-FINDINGS 06). The first part ends by saying how to load
    the second.

    A part comes whole; in the compact profile, or when `section` is given, by pages of whole numbered
    sections, :data:`PROMPT_PAGE_CHARS` at most but one section at least: the Open Training prompt was
    one 55 635-character answer (MCP-CONTEXT-BUDGET). Each page gives the part's index and the next
    section to read; `section` starts a page anywhere.

    Args:
        kind: `objective` (a mission played once, in one session), `open-training` (a VEAF
            training mission on a whole map) or `persistent-campaign` (one mission that runs on a server
            for weeks, its front moving on its own).
        lang: `en` or `fr`, the language the prompt is written in.
        part: `scenario` (the default for a prompt in two parts), `build`, or `all` — the whole text
            in one answer, when no `section` is given.
        section: The numbered section a page starts at (`0`, `2.1`, `4.6`…, or `intro`); the page stays
            in that section's part.

    Returns:
        `{"kind", "lang", "prompt": <markdown text>}`; a page also carries `"sections"` — `{"id", "title"}`
        of its part's sections — and `"next_section"` while the part goes on; for one part of a prompt
        in two, `"part"` too, and `"next_part"` on the scenario's last page.

    Raises:
        ValueError: An unknown kind, language, part or section.
    """
    if kind not in MISSION_PROMPT_KINDS:
        raise ValueError(f"Unknown mission kind {kind!r}: expected one of {', '.join(MISSION_PROMPT_KINDS)}.")
    if lang not in MISSION_PROMPT_LANGS:
        raise ValueError(f"Unknown language {lang!r}: expected one of {', '.join(MISSION_PROMPT_LANGS)}.")
    if part is not None and part not in MISSION_PROMPT_PARTS:
        raise ValueError(f"Unknown part {part!r}: expected one of {', '.join(MISSION_PROMPT_PARTS)}.")
    stem = _MISSION_PROMPT_STEMS.get(kind, f"new-{kind}-mission")
    prompt = read_bundled_text("veaf_mission_mcp", "data", "mission-prompts", f"{stem}.{lang}.md")
    result: dict[str, Any] = {"kind": kind, "lang": lang}
    if part == "all" and section is None:
        return {**result, "prompt": prompt}
    if section is None and not is_compact():
        return _whole_part(result, prompt, part)
    if _BUILD_PART_MARKER in prompt:
        scenario, build = prompt.split(_BUILD_PART_MARKER, 1)
        sections = _prompt_sections(scenario, "scenario") + _prompt_sections(build, "build")
    else:
        sections = _prompt_sections(prompt, None)
    if section is not None:
        start = next((index for index, entry in enumerate(sections) if entry["id"] == section), None)
        if start is None:
            known = ", ".join(str(entry["id"]) for entry in sections)
            raise ValueError(f"Unknown section {section!r} in the {kind} prompt: expected one of {known}.")
        current = sections[start]["part"]
    else:
        current = None if part == "all" else ("build" if part == "build" else sections[0]["part"])
        start = next(index for index, entry in enumerate(sections) if part == "all" or entry["part"] == current)
    in_part = [entry for entry in sections if part == "all" or entry["part"] == current]
    page: list[str] = []
    size = 0
    index = start
    while index < len(sections) and (part == "all" or sections[index]["part"] == current):
        text = str(sections[index]["text"])
        if page and size + len(text) > PROMPT_PAGE_CHARS:
            break
        page.append(text)
        size += len(text)
        index += 1
    result["prompt"] = "".join(page)
    result["sections"] = [{"id": entry["id"], "title": entry["title"]} for entry in in_part]
    if index < len(sections) and (part == "all" or sections[index]["part"] == current):
        result["next_section"] = sections[index]["id"]
    if current is not None and part != "all":
        result["part"] = current
        if current == "scenario" and "next_section" not in result:
            result["next_part"] = "build"
    return result


def _module_enabled(mission_yaml_path: Path, module_id: str) -> bool | None:
    """Return whether `module_id` is enabled in `mission_yaml_path`, or None if absent/unknown."""
    data = load_yaml(mission_yaml_path)
    modules: Any = data.get("modules") if hasattr(data, "get") else None
    if not hasattr(modules, "get"):
        return None
    # `ctld: false` (Foothold's scaffold) names the module CTLD as well
    value: Any = next((v for k, v in modules.items() if str(k).upper() == module_id.upper()), None)
    if isinstance(value, bool):
        return value
    if hasattr(value, "get"):
        enabled = value.get("enabled")
        return enabled if isinstance(enabled, bool) else None
    return None


#: Where the doc of a community script is, by its id; the modules page for the others.
_COMMUNITY_DOC = {
    "ctld": "doc/mission-maker/GUIDE.md#ctld-and-csar-integration",
    "csar": "doc/mission-maker/GUIDE.md#ctld-and-csar-integration",
}


def describe_module(module_id: str, mission_yaml_path: Path | None = None) -> dict[str, Any]:
    """Look a VEAF module up in the canonical module list and point to its doc.

    Uses `veaf_libs.lua_module_scanner.get_modules` (the same list the build uses) as the source
    of truth for which modules exist, then the community scripts the build ships (CTLD, CSAR, AIEN…:
    `describe_module CTLD` answered unknown, FEAT-OBJECTIVE-MISSION-V2 10). Deliberately a locator,
    not a schema validator: per-module keys live in the module's own doc page, which this returns a
    pointer to.

    Args:
        module_id: The module id (e.g. ``"QRA"``, ``"COMBATZONE"``), case-insensitive.
        mission_yaml_path: Optional `mission.yaml`; if given, reports the module's enabled state.

    Returns:
        `{"known": bool, "id", "kind", "version", "doc_page", "enabled"}` — `kind` is ``veaf`` or
        ``community``; `version` only for a VEAF module; `id`/`kind`/`doc_page` present only when known;
        `enabled` present only when `mission_yaml_path` is given.
    """
    wanted = module_id.upper()
    match = next((m for m in get_modules() if m["id"].upper() == wanted), None)
    result: dict[str, Any]
    if match is not None:
        result = {
            "known": True,
            "id": match["id"],
            "kind": "veaf",
            "version": match["version"],
            "doc_page": f"{_DOC_SCRIPTS_DIR}/{match['var_name']}.md",
        }
    else:
        script = next((s["id"] for s in get_community_script_files() if s["id"].upper() == wanted), None)
        if script is None:
            return {"known": False, "id": module_id}
        result = {
            "known": True,
            "id": script.upper(),
            "kind": "community",
            "doc_page": _COMMUNITY_DOC.get(script, "doc/mission-maker/GUIDE.md#configuring-modules"),
        }
    if mission_yaml_path is not None:
        result["enabled"] = _module_enabled(mission_yaml_path, result["id"])
        if result["enabled"] is None and result["kind"] == "community":
            # a community script nobody lists runs or not by its own default (opt-out, or opt-in like TUM)
            result["enabled"] = is_community_script_enabled_by_default(result["id"].lower())
    return result
