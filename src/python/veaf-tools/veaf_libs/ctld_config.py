"""The CTLD 2 configuration catalogue, read out of the vendored engine.

CTLD 2 embeds its own defaults in the deliverable as a long-bracket Lua string
(``ctld.configDefault``), and reads a mission's configuration from a **complete**
YAML snapshot: a missing setting falls back to the default, but a missing list is
an intentional removal. A mission's ``ctld-config.yaml`` therefore starts as a copy
of that catalogue rather than as a diff.

Reading it from the vendored ``CTLD.lua`` — instead of keeping a copy in this repo —
is what keeps the two in step: a CTLD release that adds a crate section or an
aircraft type is picked up by the next scaffold, with nothing to update here.

See docs/adr/0016-ctld2-sidecar-configuration.md.
"""

from __future__ import annotations

import io
import re
from dataclasses import dataclass
from pathlib import Path

import yaml

#: The mission's CTLD 2 configuration: a complete YAML snapshot, authored in
#: ctld-tools, living beside mission.yaml.
CTLD_CONFIG_FILENAME = "ctld-config.yaml"

#: The Lua wrapper the build generates from it, loaded immediately before CTLD.lua.
#: Same name as CTLD's own template, so a mission maker opening the .miz recognises it.
CTLD_USER_CONFIG_FILENAME = "CTLD_userConfig.lua"

#: ``ctld.configDefault = [[ … ]]``, at whatever bracket level the build chose.
#: The level is captured so the closing sequence matched is the matching one — a
#: level-1 document contains ``]]`` freely.
_CONFIG_DEFAULT_RE = re.compile(r"ctld\.configDefault\s*=\s*\[(=*)\[\r?\n(.*?)\]\1\]", re.DOTALL)

#: What a VEAF mission expects on top of the CTLD defaults, applied when scaffolding.
#:
#: CTLD 2 ships both lists empty — the right default for the wider world, since a
#: non-empty one would change behaviour for every existing mission. VEAF missions have
#: relied on the equivalent behaviour for years, through `autoInitializeAllLogistic` and
#: `autoInitializeAllPickupZones` in `veaf.lua`: any carrier or FARP ammo dump is a
#: logistic point, any carrier is a troop pickup point.
#:
#: Type ids, not display names: `getTypeName()` returns the id. `FARP Ammo Storage`,
#: which the v1 list carried, is the *display* name of `FARP Ammo Dump Coating` (DCS sets
#: `swapped_names` on that object), so it never matched anything and is not carried over.
VEAF_CONFIG_OVERRIDES: dict[str, list[str]] = {
    "logisticUnitTypes": [
        "LHA_Tarawa",
        "Stennis",
        "CVN_71",
        "KUZNECOW",
        "FARP Ammo Dump Coating",
    ],
    "troopZoneShipTypes": [
        "LHA_Tarawa",
        "Stennis",
        "CVN_71",
        "KUZNECOW",
    ],
}

#: CTLD's sample lists, emptied when scaffolding. The engine's catalogue names `extract1` …
#: `extract25` and `logistic1` … `logistic10`, which no VEAF mission holds: GermanyCW-v6 logged 35
#: « not found » warnings at start (2026-09-28). Kept apart from :data:`VEAF_CONFIG_OVERRIDES`,
#: which the build **merges** into a mission's lists — these are only a starting value, and a
#: mission maker who fills them in ctld-tools keeps what they wrote.
VEAF_EMPTIED_LISTS: tuple[str, ...] = ("extractableGroups", "logisticUnits")


def extract_default_config(ctld_lua: str) -> str | None:
    """Extract the default configuration YAML from a CTLD 2 deliverable.

    Args:
        ctld_lua: The full text of ``CTLD.lua``.

    Returns:
        The YAML document, or ``None`` when the assignment is absent — which is what
        a CTLD v1 script, or a future version that stopped embedding its defaults,
        looks like. Callers must treat ``None`` as "cannot scaffold", never as empty.
    """
    match = _CONFIG_DEFAULT_RE.search(ctld_lua)
    return match.group(2) if match else None


def read_default_config(ctld_lua_path: Path) -> str | None:
    """Extract the default configuration YAML from a ``CTLD.lua`` file.

    Args:
        ctld_lua_path: Path to the vendored CTLD deliverable.

    Returns:
        The YAML document, or ``None`` when the file is missing or carries no
        ``ctld.configDefault``.
    """
    if not ctld_lua_path.is_file():
        return None
    return extract_default_config(ctld_lua_path.read_text(encoding="utf-8", errors="replace"))


def manage_logistics_enabled(mission_yaml: dict) -> bool:
    """Return whether the build should merge the VEAF logistic types in at injection time.

    ``modules.CTLD.manage_logistics``, defaulting to **true**: the behaviour VEAF missions
    relied on for years is the one a mission maker gets without asking. The short form
    ``CTLD: true`` therefore means the same as ``{enabled: true, manage_logistics: true}``.

    Reads the normalized ``community_scripts`` shape, which is what ``modules:`` becomes.

    Args:
        mission_yaml: The normalized mission.yaml content.

    Returns:
        True when automatic logistics management is on.
    """
    community = mission_yaml.get("community_scripts")
    config = community.get("ctld") if isinstance(community, dict) else None
    if isinstance(config, dict):
        return bool(config.get("manage_logistics", True))
    return True


def merge_veaf_logistics(catalogue: str) -> tuple[str, dict[str, list[str]]]:
    """Return *catalogue* with the VEAF logistic types merged into what it already declares.

    **Union, never overwrite.** Replacing the mission's own lists would rebuild the defect
    ADR 0016 removed: in v1 the VEAF wrapper wrote over the values a mission maker had
    written, silently. A maker who adds a modded carrier in ctld-tools keeps it here, and
    still gets the carriers and FARP ammo dumps VEAF has always registered. Removing one of
    *those* is what ``manage_logistics: false`` is for.

    Order is preserved — the mission's entries first, VEAF's appended when absent — so the
    diff a maker sees in their editor stays readable.

    A key the catalogue does not define is **skipped, not created**, for the reason
    :func:`apply_veaf_overrides` skips it: an engine older than this list will not read it.

    Args:
        catalogue: The mission's ctld-config.yaml content.

    Returns:
        The merged document, and what was added per key (empty when nothing was).
    """
    from ruamel.yaml import YAML

    yaml = YAML()
    yaml.preserve_quotes = True
    document = yaml.load(catalogue)

    added: dict[str, list[str]] = {}
    for key, veaf_values in VEAF_CONFIG_OVERRIDES.items():
        for section_name in ("mm_facing", "advanced"):
            section = document.get(section_name)
            if section is None or key not in section:
                continue
            current = section[key]
            existing = list(current) if isinstance(current, list) else []
            missing = [value for value in veaf_values if value not in existing]
            if missing:
                section[key] = existing + missing
                added[key] = missing
            break

    stream = io.StringIO()
    yaml.dump(document, stream)
    return stream.getvalue(), added


def _end_of_line_comment_start(line: str) -> int | None:
    """Return where an end-of-line comment starts in *line*, or ``None`` when it has none.

    A ``#`` opens a comment when it stands outside quotes and follows whitespace — the YAML rule,
    which keeps ``"Bravo # 2"`` and ``a#b`` as values. A whole-line comment is not reported: CTLD
    reads those fine.

    Args:
        line: One line of the configuration, without its line ending.

    Returns:
        The index of the ``#``, or ``None``.
    """
    if line.lstrip().startswith("#"):
        return None
    quote: str | None = None
    escaped = False
    for index, char in enumerate(line):
        if quote == '"':
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quote = None
        elif quote == "'":
            # A doubled '' inside single quotes closes and reopens: toggling twice is a no-op.
            if char == "'":
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char == "#" and index > 0 and line[index - 1] in " \t":
            return index
    return None


def strip_end_of_line_comments(catalogue: str) -> str:
    """Return *catalogue* without its end-of-line comments.

    CTLD 2 reads its configuration with its own YAML reader (``CTLDConfig.parseYAML``), which skips
    a whole-line comment but keeps an end-of-line one as part of the value:
    ``jtacLaserCodeMax: 1686   # …`` became the string ``"1686   # …"``, and CTLD's JTAC init failed
    on ``'for' limit must be a number`` (FIX-DEMO-MISSION-FINDINGS ticket 03). Standard YAML, and
    therefore ``validate`` and the build, read ``1686``. Applied to the copy handed to the engine,
    never to the mission maker's file.

    Args:
        catalogue: The configuration about to be injected.

    Returns:
        The same document, each end-of-line comment and the blanks before it removed.
    """
    out: list[str] = []
    for line in catalogue.splitlines(keepends=True):
        body = line.rstrip("\r\n")
        start = _end_of_line_comment_start(body)
        if start is None:
            out.append(line)
        else:
            out.append(body[:start].rstrip() + line[len(body) :])
    return "".join(out)


def logistics_lists_are_empty(catalogue: str) -> bool:
    """Return whether the catalogue declares no logistic type and no troop pickup ship type.

    The shape that costs a mission every editor-placed FARP and carrier. Answered from the
    document rather than from the engine, because CTLD cannot tell an empty list from an
    absent one — both mean "register nothing" to it, and only the file distinguishes them.

    Args:
        catalogue: The mission's ctld-config.yaml content.

    Returns:
        True when every key VEAF would manage is missing or empty.
    """
    from ruamel.yaml import YAML

    yaml = YAML()
    document = yaml.load(catalogue)
    if not isinstance(document, dict):
        return True
    for key in VEAF_CONFIG_OVERRIDES:
        for section_name in ("mm_facing", "advanced"):
            section = document.get(section_name)
            if section is not None and key in section and section[key]:
                return False
    return True


#: The two sections a configuration splits its settings into. CTLD merges them, so a setting
#: counts as present whichever one holds it.
_SECTIONS = ("mm_facing", "advanced")


@dataclass(frozen=True)
class CatalogueGap:
    """What separates a mission's ``ctld-config.yaml`` from the vendored catalogue.

    Attributes:
        mission_version: The mission's ``configVersion``, ``None`` when it has none.
        catalogue_version: The vendored catalogue's ``configVersion``.
        missing: ``(section, key)`` of each setting the catalogue has and the mission lacks, lists
            excepted: CTLD runs it on its default, and :func:`upgrade_to_catalogue` writes it in.
        removed: Each setting the mission has and the catalogue no longer knows: CTLD ignores it.
        unused_features: Dotted path of each key the catalogue adds inside a table the mission
            holds (``capabilitiesByType.UH-1H.crateSpawnSector``). CTLD reads such a table whole,
            with no fallback, so the mission keeps the older behaviour; adding them changes the
            game, which is the maker's call.
    """

    mission_version: str | None
    catalogue_version: str | None
    missing: tuple[tuple[str, str], ...]
    removed: tuple[str, ...]
    unused_features: tuple[str, ...]


def _load_mapping(text: str) -> dict | None:
    """Parse a configuration with the standard reader, ``None`` when it is not a mapping."""
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError:
        return None
    return document if isinstance(document, dict) else None


def _settings(document: dict) -> dict[str, tuple[str, object]]:
    """Return every setting of a configuration, keyed by name, with the section that holds it."""
    settings: dict[str, tuple[str, object]] = {}
    for section_name in _SECTIONS:
        section = document.get(section_name)
        if isinstance(section, dict):
            for key, value in section.items():
                settings.setdefault(str(key), (section_name, value))
    return settings


def _new_keys(mission: dict, catalogue: dict, path: str) -> list[str]:
    """Return the dotted path of each key *catalogue* has below *path* and *mission* lacks."""
    found: list[str] = []
    for key, value in catalogue.items():
        here = f"{path}.{key}"
        if key not in mission:
            found.append(here)
        elif isinstance(value, dict) and isinstance(mission[key], dict):
            found += _new_keys(mission[key], value, here)
    return found


def find_catalogue_gap(mission_config: str, catalogue: str) -> CatalogueGap | None:
    """Compare a mission's configuration with the vendored catalogue, when their versions differ.

    The catalogue a release vendors moves on (2.0.0 → 2.2.0 in 6.29.0), and a mission's file stays
    at the version it was scaffolded against; CTLD only says so on screen, to the players
    (FIX-OPEN-TRAINING-CAUCASUS-FINDINGS ticket 02). Same version: nothing to report.

    Args:
        mission_config: The mission's ``ctld-config.yaml`` content.
        catalogue: The vendored catalogue, as :func:`read_default_config` returns it.

    Returns:
        The gap, or ``None`` when the versions match or either document is not a mapping.
    """
    mission = _load_mapping(mission_config)
    reference = _load_mapping(catalogue)
    if mission is None or reference is None:
        return None
    mission_version = mission.get("configVersion")
    catalogue_version = reference.get("configVersion")
    if mission_version == catalogue_version:
        return None

    mission_settings = _settings(mission)
    catalogue_settings = _settings(reference)
    missing = tuple(
        (section, key)
        for key, (section, value) in catalogue_settings.items()
        if key not in mission_settings and not isinstance(value, list)
    )
    removed = tuple(key for key in mission_settings if key not in catalogue_settings)
    unused: list[str] = []
    for key, (_, value) in catalogue_settings.items():
        own = mission_settings.get(key, (None, None))[1]
        if isinstance(value, dict) and isinstance(own, dict):
            unused += _new_keys(own, value, key)
    return CatalogueGap(
        mission_version=None if mission_version is None else str(mission_version),
        catalogue_version=None if catalogue_version is None else str(catalogue_version),
        missing=missing,
        removed=removed,
        unused_features=tuple(unused),
    )


def upgrade_to_catalogue(mission_config: str, catalogue: str) -> str:
    """Write the settings a mission lacks at their catalogue default, and take the catalogue's version.

    Each missing setting (:attr:`CatalogueGap.missing`) goes into the section the catalogue puts it
    in, after the setting that precedes it there. No existing value changes; lists are not touched
    (a missing list is an intentional removal) nor are keys inside a table the mission holds
    (:attr:`CatalogueGap.unused_features`). Round-trips through ruamel, like
    :func:`apply_veaf_overrides`, so comments and ordering survive.

    Args:
        mission_config: The mission's ``ctld-config.yaml`` content.
        catalogue: The vendored catalogue.

    Returns:
        The upgraded document; *mission_config* unchanged when there is no gap.
    """
    gap = find_catalogue_gap(mission_config, catalogue)
    if gap is None:
        return mission_config

    from ruamel.yaml import YAML
    from ruamel.yaml.comments import CommentedMap
    from ruamel.yaml.scalarstring import DoubleQuotedScalarString
    from ruamel.yaml.util import load_yaml_guess_indent

    # Dump with the file's own indentation and no line folding: the maker commits this file, and a
    # reformatted one would bury the few added lines (a list indented `- ` under its key by an editor
    # came back re-indented, a long string folded at 80 columns).
    _, mapping_indent, sequence_offset = load_yaml_guess_indent(mission_config)
    ruamel = YAML()
    ruamel.preserve_quotes = True
    ruamel.width = 4096
    if mapping_indent is not None and sequence_offset is not None:
        ruamel.indent(mapping=mapping_indent, sequence=sequence_offset + 2, offset=sequence_offset)
    document = ruamel.load(mission_config)
    reference = YAML().load(catalogue)

    for section_name, key in gap.missing:
        if document.get(section_name) is None:
            document[section_name] = CommentedMap()
        section = document[section_name]
        catalogue_keys = list(reference[section_name])
        preceding = [k for k in catalogue_keys[: catalogue_keys.index(key)] if k in section]
        position = list(section).index(preceding[-1]) + 1 if preceding else 0
        section.insert(position, key, reference[section_name][key])

    if gap.catalogue_version is not None:
        version = DoubleQuotedScalarString(gap.catalogue_version)
        if "configVersion" in document:
            document["configVersion"] = version
        else:
            document.insert(0, "configVersion", version)

    stream = io.StringIO()
    ruamel.dump(document, stream)
    return stream.getvalue()


def vendored_ctld_lua(mission_folder: Path) -> Path | None:
    """Return the ``CTLD.lua`` the tools vendor, as seen from a mission folder, or ``None``.

    The same file ``prepare`` scaffolds ``ctld-config.yaml`` from: next to the shipped defaults.

    Args:
        mission_folder: The mission folder.

    Returns:
        The vendored engine, or ``None`` when it cannot be found.
    """
    from veaf_libs.shipped_defaults import resolve_defaults_source

    defaults = resolve_defaults_source(mission_folder)
    if defaults is None:
        return None
    candidate = defaults.parents[1] / "scripts" / "community" / "CTLD.lua"
    return candidate if candidate.is_file() else None


def apply_veaf_overrides(catalogue: str) -> str:
    """Return *catalogue* with the VEAF starting values applied.

    Round-trips through ruamel so the catalogue keeps its comments, its ordering and its
    formatting: the mission maker reads this file in ctld-tools, and a reformatted
    document would make every later diff unreadable.

    A key VEAF wants but the catalogue does not define is **skipped**, not created: it
    would mean the vendored engine is older than this override list, and inventing a
    setting the engine will not read helps nobody. The mismatch surfaces as the missing
    behaviour, not as a broken config.

    CTLD's sample ``extractableGroups`` / ``logisticUnits`` lists are emptied too
    (:data:`VEAF_EMPTIED_LISTS`).

    Args:
        catalogue: The default configuration YAML, as read from the engine.

    Returns:
        The same document with the VEAF overrides applied.
    """
    from ruamel.yaml import YAML

    yaml = YAML()
    yaml.preserve_quotes = True
    document = yaml.load(catalogue)

    starting_values: dict[str, list[str]] = {**VEAF_CONFIG_OVERRIDES, **{key: [] for key in VEAF_EMPTIED_LISTS}}
    for key, value in starting_values.items():
        for section_name in ("mm_facing", "advanced"):
            section = document.get(section_name)
            if section is not None and key in section:
                section[key] = value
                break

    stream = io.StringIO()
    yaml.dump(document, stream)
    return stream.getvalue()
