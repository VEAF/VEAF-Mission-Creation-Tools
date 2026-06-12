"""Render ``src/scripts/veaf/dcsUnits.lua`` from the canonical ``dcsUnits.yaml``.

The YAML (see :mod:`veaf_build.dcs_data.units`) is the single source of truth;
this module turns it into the runtime Lua table the VEAF scripts load in DCS.

The runtime schema is intentionally lean (see ``veafUnits.lua``):

    dcsUnits.NavalStatics = { ["<type>"] = true, ... }
    dcsUnits.DcsUnitsDatabase = {
      ["<type>"] = {
        type = "<type>", name = "<name>", kind = "<kind>",
        description = "<desc>", attribute = { ["<flag>"] = true, ... },
      },
      ...
    }

``kind`` is one of ``air`` / ``naval`` / ``infantry`` / ``vehicle`` / ``static``
(``static`` replaces "none of the four booleans"). Output is deterministic
(sorted by type, sorted attributes) so the CI consistency guard can regenerate
and diff it.

Run via ``veaf-build update-dcs-data --units`` (renders right after the YAML).
"""

from __future__ import annotations

from pathlib import Path

import yaml

from veaf_build.dcs_data.datamine import DATAMINE_REF

DEFAULT_YAML = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/dcsUnits.yaml"
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/scripts/veaf/dcsUnits.lua"

_HEADER = """\
------------------------------------------------------------------
-- DCS World units database
-- By zip (2018)
--
-- Features:
-- ---------
-- * lists the DCS world units
--
-- See the documentation : https://veaf.github.io/documentation/
--
-- GENERATED from veaf_libs/data/dcsUnits.yaml by `veaf-build update-dcs-data --units`.
-- DO NOT EDIT BY HAND — edits are overwritten and CI fails on drift.
------------------------------------------------------------------

dcsUnits = {}

--- Identifier. All output in DCS.log will start with this.
dcsUnits.Id = "DCSUNITS"

--- Version (provenance: the datamine ref the data was generated from).
dcsUnits.Version = "datamine-%(ref_short)s"

dcsUnits.logger = veaf.loggers.new(dcsUnits.Id, dcsUnits.LogLevel)

-- Log version at loading time
veaf.loggers.get(dcsUnits.Id):info(veaf.loggers.get(dcsUnits.Id):getVersionInfo(dcsUnits.Version))
"""


def _lua_str(value: str) -> str:
    """Quote a Python string as a Lua double-quoted literal (escaping ``\\`` and ``"``)."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render(data: dict, ref: str = DATAMINE_REF) -> str:
    """Render the full ``dcsUnits.lua`` text from parsed YAML data.

    Args:
        data: Parsed ``dcsUnits.yaml`` (``{"units": [...], "naval_statics": [...]}``).
        ref: Datamine ref, stamped as the module version for provenance.

    Returns:
        The complete Lua source.
    """
    lines: list[str] = [_HEADER % {"ref_short": ref[:8]}]

    lines.append("\n-- Offshore statics DCS places on water (curated list).")
    lines.append("dcsUnits.NavalStatics = {")
    for static in sorted(data.get("naval_statics") or []):
        lines.append(f"  [{_lua_str(static)}] = true,")
    lines.append("}")

    lines.append("\n-- Raw DCS units database, keyed by DCS type id.")
    lines.append("dcsUnits.DcsUnitsDatabase = {")
    for unit in sorted(data.get("units") or [], key=lambda u: u["type"].lower()):
        lines.append(f"  [{_lua_str(unit['type'])}] = {{")
        lines.append(f"    type = {_lua_str(unit['type'])},")
        lines.append(f"    name = {_lua_str(unit['name'])},")
        lines.append(f"    kind = {_lua_str(unit['kind'])},")
        lines.append(f"    category = {_lua_str(unit['category'])},")
        lines.append(f"    description = {_lua_str(unit['description'])},")
        attributes = sorted(unit.get("attributes") or [])
        if attributes:
            lines.append("    attribute = {")
            for attr in attributes:
                lines.append(f"      [{_lua_str(attr)}] = true,")
            lines.append("    },")
        else:
            lines.append("    attribute = {},")
        lines.append("  },")
    lines.append("}")
    lines.append("")  # trailing newline
    return "\n".join(lines)


def generate(yaml_path: Path | None = None, output: Path | None = None, ref: str = DATAMINE_REF) -> int:
    """Render ``dcsUnits.lua`` from the committed YAML.

    Args:
        yaml_path: Source YAML. Defaults to the committed :data:`DEFAULT_YAML`.
        output: Destination Lua path. Defaults to the committed :data:`DEFAULT_OUTPUT`.
        ref: Datamine ref stamped as the module version.

    Returns:
        The number of units rendered.
    """
    yaml_path = yaml_path or DEFAULT_YAML
    output = output or DEFAULT_OUTPUT
    data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(data, ref))
    return len(data.get("units") or [])
