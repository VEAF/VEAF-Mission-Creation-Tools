"""Generate an aircraft's cockpit-control index from a DCS installation.

Each flyable module describes its clickable cockpit in
``Mods/aircraft/<Module>/Cockpit/Scripts/clickabledata.lua``: one line per control,
naming its animation argument and — in the hint DCS shows on mouse-over — the control
and its positions. That is exactly what a checklist step needs, and exactly what an
instructor should not have to read. :mod:`veaf_libs.cockpit_controls` parses it; this
module writes the result as a committed YAML index, one file per aircraft, so the
resolver runs without a DCS install.

Install-dependent, like the airfield frequencies: the committed artifact is **not**
CI-guarded, and re-generating it after a DCS update is how the index follows the game.

Run via ``veaf-build update-dcs-data --cockpit-controls --dcs-path "…/DCS World"``.
"""

from __future__ import annotations

from pathlib import Path

import yaml
from veaf_libs.cockpit_controls import read_aircraft, read_dcs_version, to_index

# Committed artifacts consumed at design time by the checklist resolver.
DEFAULT_OUTPUT_DIR = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/cockpit-controls"

#: Module folder -> DCS type name, for the aircraft this project indexes. The two differ
#: often enough (``F-16C`` ships the ``F-16C_50``) that guessing one from the other is
#: wrong; the type name is what a mission file and ``Unit:getTypeName`` use, so it is what
#: the index is keyed on. Every name here was checked against the committed unit
#: catalogue (``veaf_libs/data/dcsUnits.yaml``) rather than read off the folder.
AIRCRAFT: dict[str, str] = {
    "F-16C": "F-16C_50",
    "FA-18C": "FA-18C_hornet",
    "A-10C_2": "A-10C_2",
    "AH-64D": "AH-64D_BLK_II",
    "F-15E": "F-15ESE",
    # Heatblur's F-14B(U) has no cockpit of its own: its clickabledata.lua is two lines
    # of `dofile` pointing back at the F-14B's, so both aircraft share one index.
    "F14": "F-14B",
}


def write_index_yaml(index: dict, output: Path) -> None:
    """Write one aircraft's control index, with a header saying where it came from.

    Args:
        index: The mapping from :func:`veaf_libs.cockpit_controls.to_index`.
        output: Destination YAML path (parent directories are created).
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# Clickable cockpit controls of the {index['aircraft']}.\n")
        f.write(f"# Generated from {index['module']}/Cockpit/Scripts/clickabledata.lua in a DCS install.\n")
        f.write("# `positions` is in HINT order, which is not value order: a switch whose hint\n")
        f.write("# reads MAIN PWR/BATT/OFF runs +1/0/-1. Never infer a value from a rank here.\n")
        f.write("# `readable` is false for buttons and spring-loaded switches: they have no\n")
        f.write("# position to poll, so a step on one has to be pilot-confirmed.\n")
        f.write("# Install-dependent, so NOT CI-guarded. Re-run\n")
        f.write("# `veaf-build update-dcs-data --cockpit-controls --dcs-path <DCS>` after a DCS update.\n\n")
        yaml.dump(index, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(dcs_path: Path, output_dir: Path | None = None, only: str | None = None) -> dict[str, tuple[int, int]]:
    """Index the cockpit of every known aircraft installed under ``dcs_path``.

    Args:
        dcs_path: Root of a DCS World installation.
        output_dir: Where the per-aircraft YAML files go. Defaults to
            :data:`DEFAULT_OUTPUT_DIR`.
        only: Index just this module folder, instead of every entry of :data:`AIRCRAFT`.

    Returns:
        Module folder -> (controls written, elements skipped). A module the install does
        not have is absent from the mapping rather than an error: nobody owns every DCS
        module. The skip count is returned rather than swallowed so a partial index
        cannot quietly pass for a complete one.

    Raises:
        KeyError: If ``only`` names a module :data:`AIRCRAFT` does not know.
    """
    if output_dir is None:
        output_dir = DEFAULT_OUTPUT_DIR
    wanted = {only: AIRCRAFT[only]} if only else AIRCRAFT
    dcs_version = read_dcs_version(dcs_path)
    written: dict[str, tuple[int, int]] = {}
    for module, aircraft in wanted.items():
        try:
            parsed = read_aircraft(dcs_path, module, aircraft)
        except FileNotFoundError:
            continue
        index = to_index(parsed, module=module, dcs_version=dcs_version)
        write_index_yaml(index, output_dir / f"{aircraft}.yaml")
        written[module] = (len(parsed.controls), parsed.skipped)
    return written
