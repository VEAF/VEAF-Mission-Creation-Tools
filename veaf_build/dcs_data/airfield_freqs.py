"""Generate the airfield ATC-frequency table from a DCS installation.

Terrain-specific data living only in the DCS install, in each map's
``Mods/terrains/<Theatre>/Radio.lua`` — each airfield entry carries a ``callsign``
(display name) and a ``frequency`` block with HF/UHF/VHF_HI/VHF_LOW values in Hz.
VEAF maps ``UHF -> uhf``, ``VHF_HI -> vhf``, ``VHF_LOW -> fm`` (HF ignored, MHz).
This is the source for convert-v5's frequency->airfield alias reverse-lookup
(FEAT-CONVERTV5-FREQ-ALIASING, lot 3).

Like the airdrome table, this needs a DCS install path (``--dcs-path``) and is
therefore install-dependent: the committed artifact is **not** CI-guarded. Parsing
is a plain text read — DCS does not need to be running.

Run via ``veaf-build update-dcs-data --airfield-freqs --dcs-path "…/DCS World"``.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

# Committed artifact consumed at design time (convert-v5) to alias frequencies.
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/airfield-frequencies.yaml"

_TERRAINS_SUBDIR = "Mods/terrains"
_RADIO_FILE = "Radio.lua"

# One airfield entry: the first callsign display name, then its frequency block.
#   callsign = {{["nato"] = {_("Batumi"), "Batumi"}}, ...};
#   frequency = {[HF] = {MOD, 4250000.0}, [UHF] = {MOD, 260000000.0}, ...};
_ENTRY_RE = re.compile(
    r'callsign\s*=\s*\{\{\["[^"]+"\]\s*=\s*\{_\("([^"]+)"\).*?frequency\s*=\s*(\{.*?\})\s*;',
    re.DOTALL,
)
# [UHF] = {MODULATIONTYPE_AM, 260000000.000000}
_BAND_RE = re.compile(r"\[(UHF|VHF_HI|VHF_LOW)\]\s*=\s*\{[^,]+,\s*([\d.]+)\}")
_BAND_TO_VEAF = {"UHF": "uhf", "VHF_HI": "vhf", "VHF_LOW": "fm"}


def parse_radio(text: str) -> dict[str, dict[str, float]]:
    """Parse one terrain ``Radio.lua`` into ``{airfield name: {uhf, vhf, fm}}``.

    Frequencies are converted from Hz to MHz; the HF band is dropped. Only the first
    entry per airfield name is kept (sorted by name).

    Args:
        text: Raw contents of a terrain ``Radio.lua``.

    Returns:
        Airfield name -> band (``uhf``/``vhf``/``fm``) -> frequency in MHz.
    """
    by_name: dict[str, dict[str, float]] = {}
    for name, freq_block in _ENTRY_RE.findall(text):
        if name in by_name:
            continue
        bands = {_BAND_TO_VEAF[band]: round(float(val) / 1_000_000, 4) for band, val in _BAND_RE.findall(freq_block)}
        if bands:
            by_name[name] = bands
    return dict(sorted(by_name.items()))


def extract_all_airfield_freqs(dcs_path: Path) -> dict[str, dict[str, dict[str, float]]]:
    """Parse every installed terrain's ``Radio.lua`` under a DCS install.

    Args:
        dcs_path: Root of a DCS World installation.

    Returns:
        Theatre name -> {airfield name -> {band -> MHz}}. Terrains without a
        ``Radio.lua`` are skipped; one with no airfield entries maps to an empty dict.

    Raises:
        FileNotFoundError: If the ``Mods/terrains`` directory is missing.
    """
    terrains_dir = dcs_path / _TERRAINS_SUBDIR
    if not terrains_dir.is_dir():
        raise FileNotFoundError(f"DCS terrains directory not found: {terrains_dir}")
    result: dict[str, dict[str, dict[str, float]]] = {}
    for terrain_dir in sorted(p for p in terrains_dir.iterdir() if p.is_dir()):
        radio = terrain_dir / _RADIO_FILE
        if not radio.is_file():
            continue
        result[terrain_dir.name] = parse_radio(radio.read_text(encoding="utf-8", errors="ignore"))
    return result


def write_airfield_freqs_yaml(theatres: dict[str, dict[str, dict[str, float]]], output: Path) -> None:
    """Write the airfield-frequency table as a committed YAML artifact.

    Args:
        theatres: Theatre -> {airfield -> {band -> MHz}} mapping.
        output: Destination YAML path (parent directories are created).
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {"theatres": dict(sorted(theatres.items()))}
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS airfield ATC frequencies (MHz), per theatre.\n")
        f.write("# Generated from a DCS install's Mods/terrains/<Theatre>/Radio.lua.\n")
        f.write("# Bands: uhf (UHF), vhf (VHF_HI), fm (VHF_LOW); HF dropped.\n")
        f.write("# Install-dependent (terrain files), so NOT CI-guarded and may grow as\n")
        f.write("# maps are installed. Re-run `veaf-build update-dcs-data --airfield-freqs --dcs-path <DCS>`.\n")
        f.write("# Used by convert-v5 to alias hardcoded frequencies to airfield names.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(dcs_path: Path, output: Path | None = None) -> int:
    """Parse a DCS install's terrains and write the airfield-frequency table.

    Args:
        dcs_path: Root of a DCS World installation.
        output: Destination YAML path. Defaults to the committed :data:`DEFAULT_OUTPUT`.

    Returns:
        The total number of airfields written across all theatres.
    """
    if output is None:
        output = DEFAULT_OUTPUT
    theatres = extract_all_airfield_freqs(dcs_path)
    write_airfield_freqs_yaml(theatres, output)
    return sum(len(a) for a in theatres.values())
