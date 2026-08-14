"""
Extracts DCS aircraft radio frequency specs from the dcs-lua-datamine GitHub repository
and generates:
  - src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml
  - the delimited blocks of doc/mission-maker/dcs-radio-specs.md **and** .en.md

The Markdown pages are hand-written and only their marked blocks are rewritten, each in its own
language. Until FIX-RADIO-SPECS-GENERATOR-LOCALE this module named a single output — the *French*
page — and wrote a whole page of *English* to it, destroying a hundred lines of hand-written prose
per run while `docs-check` stayed green.

Run manually whenever the pinned datamine ref is bumped (after a DCS patch):
    veaf-build update-dcs-data --radio   (or the `update-radio-specs` alias)

The datamine is cloned at a pinned ref (veaf_build.dcs_data.datamine.DATAMINE_REF)
so generation is reproducible and CI can detect stale artifacts.

Source: https://github.com/Quaggles/dcs-lua-datamine
"""

from __future__ import annotations

import re
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from veaf_build.dcs_data.datamine import DATAMINE_REF, clone_datamine

CATEGORIES = {
    "plane": "_G/db/Units/Planes/Plane",
    "helicopter": "_G/db/Units/Helicopters/Helicopter",
}

OUTPUT_YAML = Path(__file__).parent.parent / "src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml"
OVERRIDES_YAML = OUTPUT_YAML.with_name("dcs-radio-specs-overrides.yaml")
#: One page per language. The old single `OUTPUT_MD` was the French page, written in English.
OUTPUT_PAGES = {
    "fr": Path(__file__).parent.parent / "doc/mission-maker/dcs-radio-specs.md",
    "en": Path(__file__).parent.parent / "doc/mission-maker/dcs-radio-specs.en.md",
}

MODULATION_MAP = {0: "AM", 1: "FM", 2: "AM/FM"}


# ---------------------------------------------------------------------------
# Local clone helper
# ---------------------------------------------------------------------------


def clone_repo(dest: Path, ref: str = DATAMINE_REF) -> None:
    """Sparse-clone the Units subtree of dcs-lua-datamine at a pinned ref."""
    print(f"Cloning dcs-lua-datamine@{ref} into {dest}...")
    clone_datamine(dest, list(CATEGORIES.values()), ref)
    print("Clone complete.")


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class FrequencyRange:
    min_mhz: float
    max_mhz: float
    modulation: str = "AM/FM"


@dataclass
class AircraftRadio:
    name: str
    ranges: list[FrequencyRange] = field(default_factory=list)


@dataclass
class HumanRadio:
    """The range the DCS Mission Editor accepts in a group's *primary* frequency field.

    Distinct from ``panelRadio.range``, which bounds the radio set's preset channels: the
    FW-190A8 tunes presets across 38–156 MHz but its primary frequency is confined to
    38.4–42.4 MHz. Writing a primary outside this range makes the ME refuse to save the
    mission (FIX-PRIMARY-FREQ-HUMANRADIO).
    """

    min_mhz: float
    max_mhz: float
    default_mhz: float | None = None
    modulation: str = "AM/FM"


@dataclass
class AircraftSpec:
    dcs_id: str
    display_name: str
    category: str
    radios: list[AircraftRadio] = field(default_factory=list)
    human_radio: HumanRadio | None = None
    dcs_rejects_on_load: bool = False
    """DCS refuses to *load* a mission with an out-of-range preset here, not merely to save it.

    Set from the hand-maintained overlay; the datamine says nothing about it.
    """

    kneeboard_only: bool = False
    """The bands describe what a pilot dials into SRS, not hardware DCS can set.

    Flaming Cliffs airframes expose no settable radio, so a preset built for them belongs on a
    kneeboard and must never be written into the mission (FIX-RADIO-LAYOUT-GAPS ticket 03). Set from
    the hand-maintained overlay; the datamine has no radio for these types at all.
    """


# ---------------------------------------------------------------------------
# Hand-maintained overlay
# ---------------------------------------------------------------------------


def load_overrides(path: Path | None = None) -> dict:
    """Read the VEAF corrections merged over the generated specs.

    Args:
        path: Overlay file; defaults to the shipped ``dcs-radio-specs-overrides.yaml``.

    Returns:
        Mapping of DCS unit type to its corrections (empty when the file is absent).
    """
    path = path or OVERRIDES_YAML
    if not path.exists():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def apply_overrides(specs: list[AircraftSpec], overrides: dict) -> None:
    """Merge the hand-maintained corrections into the extracted specs, in place.

    Applied to the models rather than to the YAML dump so the generated Markdown reference
    describes the same radios the injector validates against.

    Args:
        specs: Specs extracted from the datamine.
        overrides: Mapping from :func:`load_overrides`.

    Raises:
        KeyError: An override corrects an aircraft absent from the extracted specs without
            declaring it in full, or adds a band to a radio the aircraft does not have. Both are
            typos or upstream renames, and doing nothing quietly would leave the overlay claiming
            to correct data it no longer touches.
    """
    by_id = {spec.dcs_id: spec for spec in specs}
    for dcs_id, correction in overrides.items():
        spec = by_id.get(dcs_id)
        if spec is None:
            declared = correction.get("add_aircraft")
            if not declared:
                raise KeyError(f"{dcs_id}: named by the radio-specs overlay but absent from the datamine extraction")
            spec = AircraftSpec(
                dcs_id=dcs_id,
                display_name=declared["name"],
                category=declared["category"],
                radios=[
                    AircraftRadio(
                        name=radio["name"],
                        ranges=[
                            FrequencyRange(
                                min_mhz=rng["min_mhz"],
                                max_mhz=rng["max_mhz"],
                                modulation=rng.get("modulation", "AM/FM"),
                            )
                            for rng in radio["ranges"]
                        ],
                    )
                    for radio in declared.get("radios", [])
                ],
            )
            specs.append(spec)
        for extra in correction.get("add_ranges", []):
            radio = next((r for r in spec.radios if r.name == extra["radio"]), None)
            if radio is None:
                raise KeyError(f"{dcs_id}: the overlay adds a band to radio {extra['radio']!r}, which it does not have")
            radio.ranges.append(
                FrequencyRange(
                    min_mhz=extra["min_mhz"],
                    max_mhz=extra["max_mhz"],
                    modulation=extra.get("modulation", "AM/FM"),
                )
            )
        if correction.get("dcs_rejects_on_load"):
            spec.dcs_rejects_on_load = True
        if correction.get("kneeboard_only"):
            spec.kneeboard_only = True


# ---------------------------------------------------------------------------
# Lua parser
# ---------------------------------------------------------------------------


def _extract_block(text: str, start_index: int) -> str:
    """Extract a balanced {...} block starting at start_index (must point to '{')."""
    depth = 0
    i = start_index
    start = -1
    while i < len(text):
        if text[i] == "{":
            if start == -1:
                start = i
            depth += 1
        elif text[i] == "}" and depth > 0:
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
        i += 1
    return ""


def _parse_ranges(range_block: str) -> list[FrequencyRange]:
    ranges = []
    for entry in re.finditer(r"\{([^{}]+)\}", range_block):
        entry_text = entry.group(1)
        min_match = re.search(r"min\s*=\s*([0-9.]+)", entry_text)
        max_match = re.search(r"max\s*=\s*([0-9.]+)", entry_text)
        mod_match = re.search(r"modulation\s*=\s*([0-9]+)", entry_text)
        if min_match and max_match:
            mod_int = int(mod_match.group(1)) if mod_match else None
            modulation = MODULATION_MAP.get(mod_int, "AM/FM") if mod_int is not None else "AM/FM"
            ranges.append(
                FrequencyRange(
                    min_mhz=float(min_match.group(1)),
                    max_mhz=float(max_match.group(1)),
                    modulation=modulation,
                )
            )
    return ranges


def parse_panel_radio(lua_content: str) -> list[AircraftRadio] | None:
    """Extract panelRadio entries from a DCS Lua aircraft file."""
    match = re.search(r"panelRadio\s*=\s*\{", lua_content)
    if not match:
        return None

    block = _extract_block(lua_content, match.end() - 1)
    if not block:
        return None

    radios: list[AircraftRadio] = []

    # Each top-level entry in panelRadio is one radio { name = ..., range = {...} }
    # We iterate over direct children by finding name= markers and their enclosing blocks
    pos = 1  # skip leading {
    while pos < len(block):
        # Find next { at depth 1
        if block[pos] == "{":
            radio_block = _extract_block(block, pos)
            if radio_block:
                range_match = re.search(r"range\s*=\s*\{", radio_block)
                if range_match:
                    range_block = _extract_block(radio_block, range_match.end() - 1)
                    ranges = _parse_ranges(range_block)
                    # Strip the channels block so we don't match channel names as radio name
                    channels_match = re.search(r"\bchannels\s*=\s*\{", radio_block)
                    search_text = radio_block
                    if channels_match:
                        channels_block = _extract_block(radio_block, channels_match.end() - 1)
                        search_text = radio_block.replace(channels_block, "", 1)
                    radio_name_match = re.search(r'\bname\s*=\s*"([^"]+)"', search_text)
                    if ranges and radio_name_match:
                        radios.append(AircraftRadio(name=radio_name_match.group(1), ranges=ranges))
            pos += len(radio_block) if radio_block else 1
        else:
            pos += 1

    return radios if radios else None


def parse_human_radio(lua_content: str) -> HumanRadio | None:
    """Extract the ``HumanRadio`` block from a DCS Lua aircraft file.

    Args:
        lua_content: Full text of the aircraft's datamine Lua file.

    Returns:
        The parsed :class:`HumanRadio`, or ``None`` when the block is absent or carries no
        ``minFrequency``/``maxFrequency`` pair (an unbounded primary — nothing to enforce).
    """
    match = re.search(r"\bHumanRadio\s*=\s*\{", lua_content)
    if not match:
        return None

    block = _extract_block(lua_content, match.end() - 1)
    if not block:
        return None

    min_match = re.search(r"\bminFrequency\s*=\s*([0-9.]+)", block)
    max_match = re.search(r"\bmaxFrequency\s*=\s*([0-9.]+)", block)
    if not (min_match and max_match):
        return None

    freq_match = re.search(r"\bfrequency\s*=\s*([0-9.]+)", block)
    mod_match = re.search(r"\bmodulation\s*=\s*([0-9]+)", block)
    modulation = MODULATION_MAP.get(int(mod_match.group(1)), "AM/FM") if mod_match else "AM/FM"
    return HumanRadio(
        min_mhz=float(min_match.group(1)),
        max_mhz=float(max_match.group(1)),
        default_mhz=float(freq_match.group(1)) if freq_match else None,
        modulation=modulation,
    )


def _outermost_string_field(lua_content: str, field: str) -> str | None:
    """Value of *field* at the shallowest indentation in the dump, or ``None``.

    A datamine dump is one table indented by tabs, so "outermost" is what "top level" means
    here — nothing sits in column 0 but the assignment itself. Taking the shallowest
    occurrence rather than the first is what keeps a nested homonym out: a pylon carries its
    own ``DisplayName``, and an engine block its own ``type``, hundreds of lines above the
    aircraft's.

    Args:
        lua_content: The whole dumped Lua file.
        field: Field name to look for.

    Returns:
        The field's value, or ``None`` when the file has no such field.
    """
    best: tuple[int, str] | None = None
    for match in re.finditer(rf'^([ \t]*){field}\s*=\s*"([^"]*)"', lua_content, re.MULTILINE):
        depth = len(match.group(1).expandtabs(4))
        if best is None or depth < best[0]:
            best = (depth, match.group(2))
    return best[1] if best else None


def parse_display_name(lua_content: str) -> str:
    """Extract the aircraft's readable name from a datamine dump.

    ``DisplayName`` is the field DCS shows in the Mission Editor ("F-16CM bl.50"); it is
    present in all 170 unit dumps at the pinned ref. ``type`` is **not** a display name — it
    holds the DCS id, identical to the file name in 168 of those 170 — so it is a last resort
    rather than the primary source. Reading it first, and with a pattern that also matched an
    indented one, is how the generated reference table came to list "TurboFan" and "TurboJet"
    under "Aircraft" on 72 of its 88 rows (FIX-DOCAUDIT-CODE 06).

    Args:
        lua_content: The whole dumped Lua file for one aircraft.

    Returns:
        The display name, or ``""`` when the dump carries none of the three fields — the
        caller substitutes the DCS id, so an empty answer must stay distinguishable.
    """
    for field_name in ("DisplayName", "Name", "type"):
        value = _outermost_string_field(lua_content, field_name)
        if value:
            return value
    return ""


# ---------------------------------------------------------------------------
# Main extraction
# ---------------------------------------------------------------------------


def extract_all_specs(clone_root: Path) -> list[AircraftSpec]:
    specs: list[AircraftSpec] = []

    for category, rel_path in CATEGORIES.items():
        folder = clone_root / rel_path
        lua_files = sorted(folder.glob("*.lua"))
        print(f"\n{category}: {len(lua_files)} files")

        for lua_file in lua_files:
            dcs_id = lua_file.stem
            print(f"  Parsing {dcs_id}...", end=" ", flush=True)
            try:
                content = lua_file.read_text(encoding="utf-8", errors="replace")
                radios = parse_panel_radio(content)
                if radios:
                    display_name = parse_display_name(content) or dcs_id
                    specs.append(
                        AircraftSpec(
                            dcs_id=dcs_id,
                            display_name=display_name,
                            category=category,
                            radios=radios,
                            human_radio=parse_human_radio(content),
                        )
                    )
                    print(f"OK ({len(radios)} radio{'s' if len(radios) > 1 else ''})")
                else:
                    print("no panelRadio (AI-only)")
            except Exception as e:
                print(f"ERROR: {e}", file=sys.stderr)

    specs.sort(key=lambda s: s.dcs_id.lower())
    return specs


# ---------------------------------------------------------------------------
# YAML output
# ---------------------------------------------------------------------------


def specs_to_yaml_dict(specs: list[AircraftSpec]) -> dict:
    result: dict = {}
    for spec in specs:
        entry: dict = {
            "name": spec.display_name,
            "category": spec.category,
            "radios": [
                {
                    "name": r.name,
                    "ranges": [
                        {"min_mhz": rng.min_mhz, "max_mhz": rng.max_mhz, "modulation": rng.modulation}
                        for rng in r.ranges
                    ],
                }
                for r in spec.radios
            ],
        }
        if spec.dcs_rejects_on_load:
            entry["dcs_rejects_on_load"] = True
        if spec.kneeboard_only:
            entry["kneeboard_only"] = True
        if spec.human_radio:
            entry["human_radio"] = {
                "min_mhz": spec.human_radio.min_mhz,
                "max_mhz": spec.human_radio.max_mhz,
                "default_mhz": spec.human_radio.default_mhz,
                "modulation": spec.human_radio.modulation,
            }
        result[spec.dcs_id] = entry
    return result


def write_yaml(specs: list[AircraftSpec], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    data = specs_to_yaml_dict(specs)
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS aircraft radio frequency specifications\n")
        f.write("# Generated from https://github.com/Quaggles/dcs-lua-datamine\n")
        f.write(f"# Source ref: {DATAMINE_REF}\n")
        f.write("# Re-run `veaf-build update-dcs-data --radio` to update after a pin bump.\n")
        f.write("#\n")
        f.write("# Structure:\n")
        f.write("#   <dcs_unit_type_id>:\n")
        f.write("#     name: Human-readable aircraft name\n")
        f.write("#     category: plane | helicopter\n")
        f.write("#     radios:\n")
        f.write("#       - name: Radio name as shown in DCS\n")
        f.write("#         ranges:\n")
        f.write("#           - min_mhz: 30.0\n")
        f.write("#             max_mhz: 87.975\n")
        f.write("#             modulation: FM | AM | AM/FM\n")
        f.write("#     human_radio:            # range the ME accepts as the group's PRIMARY frequency\n")
        f.write("#       min_mhz: 38.4         # narrower than `radios` for some airframes (FW-190: 38.4-42.4\n")
        f.write("#       max_mhz: 42.4         # vs a 38-156 preset range) — a primary outside it is rejected\n")
        f.write("#       default_mhz: 38.4     # DCS's own default, or null\n")
        f.write("#       modulation: FM | AM | AM/FM\n")
        f.write("#     dcs_rejects_on_load: true   # from dcs-radio-specs-overrides.yaml\n")
        f.write("#     kneeboard_only: true        # bands for the kneeboard only, never injected\n")
        f.write("#\n")
        f.write("# VEAF corrections live in dcs-radio-specs-overrides.yaml and are merged in here by\n")
        f.write("# the generator, so they survive a pin bump. Never edit THIS file by hand.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=True, default_flow_style=False)
    print(f"\nYAML written to {output}")


# ---------------------------------------------------------------------------
# Markdown output
# ---------------------------------------------------------------------------

_MOD_BADGE = {"AM": "AM", "FM": "FM", "AM/FM": "AM / FM"}


#: Where a generated block starts and ends inside a hand-written page. The generator replaces what
#: sits between them and touches nothing else, which is what lets the pages keep their prose.
#:
#: Before FIX-RADIO-SPECS-GENERATOR-LOCALE the generator wrote a *whole page* to a single output —
#: `doc/mission-maker/dcs-radio-specs.md`, the **French** page — in English, and never opened the
#: English one. Running it replaced 100 lines of hand-written French prose with 84 of generated
#: English, and `docs-check` stayed green throughout, because a French page full of English text is
#: not a defect the gate can express.
BLOCK_START = "<!-- BEGIN generated: {name} -->"
BLOCK_END = "<!-- END generated: {name} -->"

#: Per-language wording for everything the generated blocks contain. The tables are data, but their
#: headings and column names are prose and belong to the page's language.
LABELS: dict[str, dict[str, str]] = {
    "fr": {
        "planes": "Avions",
        "helicopters": "Hélicoptères",
        "aircraft": "Appareil",
        "dcs_id": "ID DCS",
        "radio": "Radio",
        "min": "Min (MHz)",
        "max": "Max (MHz)",
        "modulation": "Modulation",
        "restricted": "Appareils dont la fréquence principale est bridée",
        "primary_min": "Primaire min (MHz)",
        "primary_max": "Primaire max (MHz)",
        "default": "Défaut (MHz)",
        "none_restricted": "*Aucun appareil n'a de fréquence principale plus étroite que ses canaux préréglés.*",
        "source": "Source",
        "source_ref": "Révision source",
        "regenerate": "Régénérer avec `veaf-build update-dcs-data --radio` après un changement de révision.",
    },
    "en": {
        "planes": "Fixed-wing aircraft",
        "helicopters": "Helicopters",
        "aircraft": "Aircraft",
        "dcs_id": "DCS ID",
        "radio": "Radio",
        "min": "Min (MHz)",
        "max": "Max (MHz)",
        "modulation": "Modulation",
        "restricted": "Aircraft whose primary frequency is restricted",
        "primary_min": "Primary min (MHz)",
        "primary_max": "Primary max (MHz)",
        "default": "Default (MHz)",
        "none_restricted": "*No aircraft has a primary frequency narrower than its preset channels.*",
        "source": "Source",
        "source_ref": "Source ref",
        "regenerate": "Re-generate with `veaf-build update-dcs-data --radio` after a pin bump.",
    },
}


class MissingBlockError(RuntimeError):
    """A page does not carry the markers the generator writes between.

    Raised rather than skipped or overwritten whole: a generator that quietly does nothing is how a
    stale table ships, and overwriting the page is the defect this lot exists to remove.
    """


def _aircraft_table(specs: list[AircraftSpec], labels: dict[str, str]) -> list[str]:
    """Render the radio-range table for one category."""
    lines = [
        f"| {labels['aircraft']} | {labels['dcs_id']} | {labels['radio']} "
        f"| {labels['min']} | {labels['max']} | {labels['modulation']} |",
        "|----------|--------|-------|----------:|----------:|------------|",
    ]
    for spec in specs:
        first = True
        for radio in spec.radios:
            for rng in radio.ranges:
                name_col = f"**{spec.display_name}**" if first else ""
                id_col = f"`{spec.dcs_id}`" if first else ""
                radio_name = radio.name if rng == radio.ranges[0] else ""
                lines.append(
                    f"| {name_col} | {id_col} | {radio_name} "
                    f"| {rng.min_mhz:.3f} | {rng.max_mhz:.3f} | {_MOD_BADGE.get(rng.modulation, rng.modulation)} |"
                )
                first = False
    return lines


def build_tables_block(specs: list[AircraftSpec], language: str) -> list[str]:
    """Build the aircraft-tables block, in *language*.

    Args:
        specs: All extracted aircraft specs.
        language: ``"fr"`` or ``"en"``.

    Returns:
        The Markdown lines to place between the ``aircraft tables`` markers.
    """
    labels = LABELS[language]
    planes = [s for s in specs if s.category == "plane"]
    helis = [s for s in specs if s.category == "helicopter"]
    lines: list[str] = []
    for key, section_specs in (("planes", planes), ("helicopters", helis)):
        lines += [f"## {labels[key]}", ""]
        lines += _aircraft_table(section_specs, labels)
        lines.append("")
    return lines


def build_source_block(language: str) -> list[str]:
    """Build the provenance note, in *language*.

    Generated rather than hand-written because it carries the pinned datamine ref, which changes on
    every bump — the rule `CLAUDE.md` states for versions in a page header, applied to a ref.

    Args:
        language: ``"fr"`` or ``"en"``.

    Returns:
        The Markdown lines to place between the ``source note`` markers.
    """
    labels = LABELS[language]
    return [
        f"> **{labels['source']}**: [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)  ",
        f"> {labels['source_ref']}: `{DATAMINE_REF}`  ",
        f"> {labels['regenerate']}",
    ]


def build_primary_block(specs: list[AircraftSpec], language: str) -> list[str]:
    """Build the restricted-primary-frequency table, in *language*.

    The surrounding explanation is hand-written on each page and richer than anything generated
    here; this block is the exhaustive list, which is the part a mission maker cannot write by hand.

    Args:
        specs: All extracted aircraft specs.
        language: ``"fr"`` or ``"en"``.

    Returns:
        The Markdown lines to place between the ``primary frequency`` markers.
    """
    labels = LABELS[language]
    restricted: list[tuple[AircraftSpec, HumanRadio]] = []
    for spec in specs:
        hr = spec.human_radio
        if not hr:
            continue
        all_ranges = [rng for radio in spec.radios for rng in radio.ranges]
        if not all_ranges:
            continue
        if hr.min_mhz > min(r.min_mhz for r in all_ranges) or hr.max_mhz < max(r.max_mhz for r in all_ranges):
            restricted.append((spec, hr))
    if not restricted:
        return [labels["none_restricted"]]
    lines = [
        f"### {labels['restricted']}",
        "",
        f"| {labels['aircraft']} | {labels['dcs_id']} | {labels['primary_min']} "
        f"| {labels['primary_max']} | {labels['default']} | {labels['modulation']} |",
        "|----------|--------|------------------:|------------------:|--------------:|------------|",
    ]
    for spec, hr in sorted(restricted, key=lambda pair: pair[0].display_name):
        default = f"{hr.default_mhz:.3f}" if hr.default_mhz is not None else "—"
        lines.append(
            f"| **{spec.display_name}** | `{spec.dcs_id}` | {hr.min_mhz:.3f} "
            f"| {hr.max_mhz:.3f} | {default} | {_MOD_BADGE.get(hr.modulation, hr.modulation)} |"
        )
    return lines


def replace_block(page: Path, name: str, body: list[str]) -> None:
    """Replace one delimited block inside *page*, leaving every other line untouched.

    Args:
        page: The Markdown page to edit in place.
        name: The block's name, as it appears in its markers.
        body: The lines to put between the markers.

    Raises:
        MissingBlockError: The page has no such block, or only one of its two markers.
    """
    text = page.read_text(encoding="utf-8")
    start, end = BLOCK_START.format(name=name), BLOCK_END.format(name=name)
    if text.count(start) != 1 or text.count(end) != 1:
        raise MissingBlockError(f"{page.name}: expected exactly one '{name}' block, marked by {start} / {end}")
    head, rest = text.split(start, 1)
    _stale, tail = rest.split(end, 1)
    page.write_text(
        head + start + "\n" + "\n".join(body).rstrip("\n") + "\n" + end + tail,
        encoding="utf-8",
        newline="\n",
    )


def write_markdown(specs: list[AircraftSpec], pages: dict[str, Path]) -> None:
    """Refresh the generated blocks of every language's page.

    Args:
        specs: All extracted aircraft specs.
        pages: Language code to page path, e.g. ``{"fr": …, "en": …}``.

    Raises:
        MissingBlockError: A page is missing one of its blocks.
    """
    for language, page in pages.items():
        replace_block(page, "source note", build_source_block(language))
        replace_block(page, "aircraft tables", build_tables_block(specs, language))
        replace_block(page, "primary frequency", build_primary_block(specs, language))
        print(f"Generated blocks refreshed in {page} ({language})")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    """Clone dcs-lua-datamine, extract radio specs, and write YAML + Markdown outputs."""
    print("Extracting DCS radio specs from dcs-lua-datamine...")
    with tempfile.TemporaryDirectory() as tmp:
        clone_root = Path(tmp) / "dcs-lua-datamine"
        clone_repo(clone_root)
        specs = extract_all_specs(clone_root)
    print(f"\nTotal aircraft with player radio slots: {len(specs)}")
    overrides = load_overrides()
    if overrides:
        apply_overrides(specs, overrides)
        print(f"Applied {len(overrides)} VEAF correction(s) from {OVERRIDES_YAML.name}")
    write_yaml(specs, OUTPUT_YAML)
    write_markdown(specs, OUTPUT_PAGES)


if __name__ == "__main__":
    main()
