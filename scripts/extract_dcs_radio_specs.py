"""
Standalone script to extract DCS aircraft radio frequency specs from the
dcs-lua-datamine GitHub repository and generate:
  - src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml
  - doc/mission-maker/dcs-radio-specs.md

Run manually whenever DCS is updated with new aircraft or changed radio specs:
    python scripts/extract_dcs_radio_specs.py

Requires: requests, pyyaml (both available in the Poetry environment).
Source: https://github.com/Quaggles/dcs-lua-datamine
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import yaml

REPO_URL = "https://github.com/Quaggles/dcs-lua-datamine.git"
CATEGORIES = {
    "plane": "_G/db/Units/Planes/Plane",
    "helicopter": "_G/db/Units/Helicopters/Helicopter",
}

OUTPUT_YAML = Path(__file__).parent.parent / "src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml"
OUTPUT_MD = Path(__file__).parent.parent / "doc/mission-maker/dcs-radio-specs.md"

MODULATION_MAP = {0: "AM", 1: "FM", 2: "AM/FM"}


# ---------------------------------------------------------------------------
# Local clone helper
# ---------------------------------------------------------------------------


def clone_repo(dest: Path) -> None:
    """Shallow-clone dcs-lua-datamine into dest (no history, faster)."""
    print(f"Cloning {REPO_URL} into {dest}...")
    subprocess.run(
        ["git", "clone", "--depth=1", "--filter=blob:none", "--sparse", REPO_URL, str(dest)],
        check=True,
        capture_output=True,
    )
    # Sparse-checkout only the Units subtree we need
    subprocess.run(
        ["git", "sparse-checkout", "set", "_G/db/Units/Planes/Plane", "_G/db/Units/Helicopters/Helicopter"],
        cwd=dest,
        check=True,
        capture_output=True,
    )
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
class AircraftSpec:
    dcs_id: str
    display_name: str
    category: str
    radios: list[AircraftRadio] = field(default_factory=list)


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
                name_match = re.search(r'name\s*=\s*"([^"]+)"', radio_block)
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


def parse_display_name(lua_content: str) -> str:
    # 'type = "..."' holds the aircraft's DCS display name at the top level of the file.
    match = re.search(r'^\s*type\s*=\s*"([^"]+)"', lua_content, re.MULTILINE)
    if match:
        return match.group(1)
    # Fallback: username field
    match = re.search(r'^\s*username\s*=\s*"([^"]+)"', lua_content, re.MULTILINE)
    return match.group(1) if match else ""


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
                    specs.append(AircraftSpec(dcs_id=dcs_id, display_name=display_name, category=category, radios=radios))
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
        result[spec.dcs_id] = {
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
    return result


def write_yaml(specs: list[AircraftSpec], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    data = specs_to_yaml_dict(specs)
    with open(output, "w", encoding="utf-8") as f:
        f.write("# DCS aircraft radio frequency specifications\n")
        f.write("# Generated from https://github.com/Quaggles/dcs-lua-datamine\n")
        f.write("# Re-run scripts/extract_dcs_radio_specs.py to update after a DCS patch.\n")
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
        f.write("#             modulation: FM | AM | AM/FM\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=True, default_flow_style=False)
    print(f"\nYAML written to {output}")


# ---------------------------------------------------------------------------
# Markdown output
# ---------------------------------------------------------------------------

_MOD_BADGE = {"AM": "AM", "FM": "FM", "AM/FM": "AM / FM"}


def write_markdown(specs: list[AircraftSpec], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)

    planes = [s for s in specs if s.category == "plane"]
    helis = [s for s in specs if s.category == "helicopter"]

    lines: list[str] = [
        "# DCS Radio Frequency Specifications",
        "",
        "Reference table of valid radio frequency ranges for all DCS player-flyable aircraft.",
        "Used by `inject-presets` to validate that frequencies defined in `presets.yaml` are",
        "compatible with the target aircraft's radio hardware.",
        "",
        "> **Source**: [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)  ",
        "> Re-generate with `python scripts/extract_dcs_radio_specs.py` after a DCS patch.",
        "",
        "---",
        "",
    ]

    for section_title, section_specs in [("Fixed-wing aircraft", planes), ("Helicopters", helis)]:
        lines += [f"## {section_title}", ""]
        lines += [
            "| Aircraft | DCS ID | Radio | Min (MHz) | Max (MHz) | Modulation |",
            "|----------|--------|-------|----------:|----------:|------------|",
        ]
        for spec in section_specs:
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
        lines.append("")

    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Markdown written to {output}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("Extracting DCS radio specs from dcs-lua-datamine...")
    with tempfile.TemporaryDirectory() as tmp:
        clone_root = Path(tmp) / "dcs-lua-datamine"
        clone_repo(clone_root)
        specs = extract_all_specs(clone_root)
    print(f"\nTotal aircraft with player radio slots: {len(specs)}")
    write_yaml(specs, OUTPUT_YAML)
    write_markdown(specs, OUTPUT_MD)
