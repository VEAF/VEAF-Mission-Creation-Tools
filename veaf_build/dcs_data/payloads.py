"""Generate the DCS default loadouts table (``payloads.yaml``) from a DCS World install.

The Mission Editor offers each AI aircraft its loadouts by name — « R-40T*2,R-33*4 » for a MiG-31 —
from ``MissionEditor/data/scripts/UnitPayloads/<type>.lua``. The datamine does not carry those files,
so they are read from an install, as ``--airfield-freqs`` and ``--cities`` read theirs, and the result
is committed. The Syria Open Training needed eight types the ``veafSpawn-*`` catalogue has no loadout
for, and read their pylons from these files by hand (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 09).

Each file is a Lua table ``{ name, unitType, payloads = { { name, pylons = { { CLSID, num } }, tasks } } }``,
parsed with ``luadata`` (no Lua executed). Keyed by ``unitType``, which is not always the file name
(``F-16C.lua`` holds ``F-16C bl.52d``). A name repeated within one file keeps its first loadout.

Run via ``veaf-build update-dcs-data --payloads --dcs-path <DCS World install>``.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import luadata
import yaml

#: Where the editor's per-type loadout files live in an install.
PAYLOADS_SUBDIR = Path("MissionEditor") / "data" / "scripts" / "UnitPayloads"

#: The committed artifact.
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/payloads.yaml"


def _listed(table: Any) -> list[Any]:
    """Return a Lua array as a list, whichever shape the parser gave it."""
    if isinstance(table, dict):
        return [table[key] for key in sorted(table, key=lambda k: (not isinstance(k, int), k))]
    return list(table or [])


def parse_payload_file(text: str) -> tuple[str, dict[str, dict[int, str]]] | None:
    """Parse one ``UnitPayloads/<type>.lua`` file.

    Args:
        text: The file's contents, ``local unitPayloads = { ... } return unitPayloads``.

    Returns:
        ``(unit type, {payload name: {station: CLSID}})``, or ``None`` for a file with no table or
        no ``unitType``. A type with no loadout gives an empty mapping.
    """
    if "{" not in text:
        return None
    table = luadata.unserialize(text[text.index("{") : text.rindex("}") + 1])
    if not isinstance(table, dict) or not table.get("unitType"):
        return None
    payloads: dict[str, dict[int, str]] = {}
    for payload in _listed(table.get("payloads")):
        name = str(payload.get("name", ""))
        if not name or name in payloads:
            continue
        payloads[name] = {
            int(pylon["num"]): str(pylon["CLSID"])
            for pylon in _listed(payload.get("pylons"))
            if isinstance(pylon, dict) and "num" in pylon and pylon.get("CLSID")
        }
    return str(table["unitType"]), payloads


def extract_payloads(dcs_path: Path) -> dict[str, dict[str, dict[int, str]]]:
    """Read every loadout file of an install.

    Args:
        dcs_path: The DCS World install folder.

    Returns:
        Unit type -> payload name -> station -> CLSID; types with no loadout left out.

    Raises:
        FileNotFoundError: If the install has no ``UnitPayloads`` folder.
    """
    folder = dcs_path / PAYLOADS_SUBDIR
    if not folder.is_dir():
        raise FileNotFoundError(f"No UnitPayloads folder in {dcs_path} (looked for {folder})")
    result: dict[str, dict[str, dict[int, str]]] = {}
    for path in sorted(folder.glob("*.lua")):
        parsed = parse_payload_file(path.read_text(encoding="utf-8", errors="replace"))
        if parsed is not None and parsed[1]:
            result[parsed[0]] = parsed[1]
    return result


def write_payloads_yaml(payloads: dict[str, dict[str, dict[int, str]]], output: Path) -> None:
    """Write the table, types and names sorted so a regeneration diffs cleanly.

    Args:
        payloads: Unit type -> payload name -> station -> CLSID.
        output: The destination file.
    """
    data = {
        unit_type: {name: dict(sorted(pylons.items())) for name, pylons in sorted(by_name.items())}
        for unit_type, by_name in sorted(payloads.items(), key=lambda item: item[0].lower())
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS default loadouts: unit type -> loadout name (as the Mission Editor lists it) -> station -> CLSID.\n")
        f.write("# Read from a DCS World install, MissionEditor/data/scripts/UnitPayloads/*.lua.\n")
        f.write("# Regenerate with `veaf-build update-dcs-data --payloads --dcs-path <DCS World install>`.\n")
        f.write("# DO NOT EDIT BY HAND.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(dcs_path: Path, output: Path | None = None) -> int:
    """Read an install's loadouts and write ``payloads.yaml``.

    Args:
        dcs_path: The DCS World install folder.
        output: The destination; defaults to :data:`DEFAULT_OUTPUT`.

    Returns:
        How many loadouts were written.
    """
    payloads = extract_payloads(dcs_path)
    write_payloads_yaml(payloads, output or DEFAULT_OUTPUT)
    return sum(len(by_name) for by_name in payloads.values())
