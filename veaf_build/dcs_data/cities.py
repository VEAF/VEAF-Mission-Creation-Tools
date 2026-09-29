"""Generate the city lists ``veafNamedPoints`` adds as hidden named points, from DCS installs.

Each terrain ships its towns in ``Mods/terrains/<folder>/Map/towns.lua`` (``["Berlin"] = {
latitude = …, longitude = …, display_name = _("Berlin")}``), and names itself in the folder's
``entry.lua`` (``local self_ID = "GermanyCW"``) — the value a mission's ``env.mission.theatre``
carries, which is not the folder name (``GermanyColdWar``, ``Sinai`` → ``SinaiMap``).

The terrain files are not in the datamine, so the committed :data:`DEFAULT_YAML` is merged from
whatever installs are given: a theatre found in one of them is replaced, a theatre found in none
is kept as it stands. No single install holds every map, and a list captured once from an install
that is gone stays valid until an install that has the map replaces it.

``veafCities.lua`` is rendered from the YAML alone, so CI can check the two stay in step.

Run via ``veaf-build update-dcs-data --cities --dcs-path <DCS World> [--dcs-path <another>]``.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

DEFAULT_YAML = Path(__file__).parent / "cities.yaml"
DEFAULT_LUA = Path(__file__).parent.parent.parent / "src/scripts/veaf/veafCities.lua"

_TERRAINS_SUBDIR = "Mods/terrains"
_TOWNS_FILE = "Map/towns.lua"
_ENTRY_FILE = "entry.lua"

_SELF_ID_RE = re.compile(r'self_ID\s*=\s*"([^"]+)"')
#: ``["Berlin"] = { latitude = 52.517036, longitude = 13.388860, display_name = _("Berlin")},``
_TOWN_RE = re.compile(
    r'\[\s*"[^"]*"\s*\]\s*=\s*\{\s*latitude\s*=\s*(-?[\d.]+)\s*,\s*longitude\s*=\s*(-?[\d.]+)\s*,'
    r'\s*display_name\s*=\s*_\(\s*"([^"]*)"\s*\)'
)

_HEADER = """\
------------------------------------------------------------------
-- VEAF cities: the towns of each theatre, added by veafNamedPoints as hidden named points.
--
-- GENERATED from veaf_build/dcs_data/cities.yaml by `veaf-build update-dcs-data --cities`.
-- DO NOT EDIT BY HAND — edits are overwritten and a test fails on drift.
------------------------------------------------------------------

veafCities = {}
"""


def parse_towns(text: str) -> dict[str, tuple[float, float]]:
    """Parse one terrain's ``towns.lua`` into ``{display name: (latitude, longitude)}``.

    DCS's own files hold duplicate keys, and Lua keeps the last one; so does this.

    Args:
        text: Raw contents of a ``Map/towns.lua``.

    Returns:
        Display name -> ``(latitude, longitude)``, in file order.
    """
    towns: dict[str, tuple[float, float]] = {}
    for latitude, longitude, name in _TOWN_RE.findall(text):
        towns.pop(name, None)
        towns[name] = (float(latitude), float(longitude))
    return towns


def theatre_id(entry_text: str) -> str | None:
    """Return the theatre name a terrain's ``entry.lua`` declares (``self_ID``), or ``None``."""
    match = _SELF_ID_RE.search(entry_text)
    return match.group(1) if match else None


def extract_cities(dcs_path: Path) -> dict[str, dict[str, tuple[float, float]]]:
    """Read every installed terrain's towns under a DCS install.

    Args:
        dcs_path: Root of a DCS World installation (or a copy of its ``Mods/terrains`` tree).

    Returns:
        Theatre name -> towns. A terrain without ``towns.lua`` or without a ``self_ID`` is skipped.

    Raises:
        FileNotFoundError: If the ``Mods/terrains`` directory is missing.
    """
    terrains_dir = dcs_path / _TERRAINS_SUBDIR
    if not terrains_dir.is_dir():
        raise FileNotFoundError(f"DCS terrains directory not found: {terrains_dir}")
    result: dict[str, dict[str, tuple[float, float]]] = {}
    for terrain_dir in sorted(p for p in terrains_dir.iterdir() if p.is_dir()):
        towns_file, entry_file = terrain_dir / _TOWNS_FILE, terrain_dir / _ENTRY_FILE
        if not towns_file.is_file() or not entry_file.is_file():
            continue
        theatre = theatre_id(entry_file.read_text(encoding="utf-8", errors="ignore"))
        if theatre:
            result[theatre] = parse_towns(towns_file.read_text(encoding="utf-8", errors="ignore"))
    return result


def load_yaml(path: Path) -> dict[str, dict[str, tuple[float, float]]]:
    """Load the committed city lists; an absent file is an empty table."""
    if not path.is_file():
        return {}
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    theatres = raw.get("theatres") or {}
    return {
        theatre: {name: (float(lat), float(lon)) for name, (lat, lon) in (towns or {}).items()}
        for theatre, towns in theatres.items()
    }


def write_yaml(theatres: dict[str, dict[str, tuple[float, float]]], path: Path) -> None:
    """Write the city lists, theatres and towns sorted so a regeneration diffs cleanly.

    Args:
        theatres: Theatre name -> towns.
        path: Destination YAML.
    """
    data = {
        "theatres": {
            theatre: {name: [lat, lon] for name, (lat, lon) in sorted(towns.items())}
            for theatre, towns in sorted(theatres.items())
        }
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Towns of each DCS theatre: name -> [latitude, longitude].\n")
        f.write("# Read from Mods/terrains/<folder>/Map/towns.lua, keyed by the terrain's self_ID.\n")
        f.write("# Install-dependent: a theatre is replaced when an install given to the generator has it,\n")
        f.write("# and kept otherwise. Re-run `veaf-build update-dcs-data --cities --dcs-path <DCS>`.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=None, width=200)


def _lua_str(value: str) -> str:
    """Quote a Python string as a Lua double-quoted literal."""
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_lua(theatres: dict[str, dict[str, tuple[float, float]]]) -> str:
    """Render ``veafCities.lua``: one table per theatre, in the shape ``addCitiesFromList`` reads.

    Args:
        theatres: Theatre name -> towns.

    Returns:
        The complete Lua source.
    """
    lines = [_HEADER]
    for theatre, towns in sorted(theatres.items()):
        lines.append(f"veafCities[{_lua_str(theatre)}] = {{")
        for name, (lat, lon) in sorted(towns.items()):
            lines.append(
                f"  [{_lua_str(name)}] = {{ latitude = {lat:.6f}, longitude = {lon:.6f}, display_name = {_lua_str(name)} }},"
            )
        lines.append("}")
    lines.append("")
    return "\n".join(lines)


def generate(dcs_paths: list[Path], yaml_path: Path | None = None, lua_path: Path | None = None) -> dict[str, int]:
    """Merge the towns of the given installs into the committed lists, and render the Lua.

    Args:
        dcs_paths: DCS installs to read; may be empty, which only re-renders the Lua.
        yaml_path: The committed YAML. Defaults to :data:`DEFAULT_YAML`.
        lua_path: The rendered Lua. Defaults to :data:`DEFAULT_LUA`.

    Returns:
        Theatre name -> town count, for the theatres the installs replaced.
    """
    yaml_path = yaml_path or DEFAULT_YAML
    lua_path = lua_path or DEFAULT_LUA
    theatres = load_yaml(yaml_path)
    replaced: dict[str, int] = {}
    for dcs_path in dcs_paths:
        for theatre, towns in extract_cities(dcs_path).items():
            theatres[theatre] = towns
            replaced[theatre] = len(towns)
    write_yaml(theatres, yaml_path)
    lua_path.parent.mkdir(parents=True, exist_ok=True)
    with open(lua_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render_lua(load_yaml(yaml_path)))
    return replaced
