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
from pathlib import Path

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


def apply_veaf_overrides(catalogue: str) -> str:
    """Return *catalogue* with the VEAF starting values applied.

    Round-trips through ruamel so the catalogue keeps its comments, its ordering and its
    formatting: the mission maker reads this file in ctld-tools, and a reformatted
    document would make every later diff unreadable.

    A key VEAF wants but the catalogue does not define is **skipped**, not created: it
    would mean the vendored engine is older than this override list, and inventing a
    setting the engine will not read helps nobody. The mismatch surfaces as the missing
    behaviour, not as a broken config.

    Args:
        catalogue: The default configuration YAML, as read from the engine.

    Returns:
        The same document with the VEAF overrides applied.
    """
    from ruamel.yaml import YAML

    yaml = YAML()
    yaml.preserve_quotes = True
    document = yaml.load(catalogue)

    for key, value in VEAF_CONFIG_OVERRIDES.items():
        for section_name in ("mm_facing", "advanced"):
            section = document.get(section_name)
            if section is not None and key in section:
                section[key] = value
                break

    stream = io.StringIO()
    yaml.dump(document, stream)
    return stream.getvalue()
