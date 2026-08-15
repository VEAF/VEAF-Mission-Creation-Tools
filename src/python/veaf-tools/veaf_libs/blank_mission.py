"""Synthesize a minimal, loadable DCS blank mission for a given theatre (no DCS round-trip).

Starting a VEAF mission otherwise requires a `.miz` created in the DCS Mission Editor for the
target theatre. This module builds one in Python instead: a generic, theatre-agnostic ``mission``
skeleton composed with per-theatre constants (theatre name, map centre/zoom, default per-coalition
bullseye) from ``data/theatre-defaults.yaml``. See ``.backlog/FEAT-BLANK-MISSION-THEATRE/PRD.md``.

The output is the exploded ``src/mission/`` file set a VEAF mission folder expects, ready for
``veaf-tools build`` and the MCP composites. Coalitions ship empty (no groups/countries): the maker
fills them in, or every group-adding path does — ``mission_tools.group_insertion.add_group`` calls
``assign_country_to_side`` so ``coalitions.<side>`` is populated in step with ``coalition.<side>``,
which is what keeps a from-scratch mission loadable.
"""

from functools import lru_cache
from typing import Any

import luadata  # type: ignore[import-untyped]
import yaml

from veaf_libs.bundled_data import read_bundled_text

#: DCS mission format version emitted in the skeleton (matches current-era ME saves).
_MISSION_VERSION = 23
#: Relative paths of the exploded mission file set produced for ``src/mission/``.
_DICTIONARY_PATH = "l10n/DEFAULT/dictionary"
_MAP_RESOURCE_PATH = "l10n/DEFAULT/mapResource"


#: Alternate theatre spellings some tooling emits → the canonical `dcs-maps` key (lowercased).
#: Mirrors ``veaf_libs.coordinates._THEATRE_ALIASES``.
_THEATRE_ALIASES: dict[str, str] = {"sinai": "sinaimap", "germanycoldwar": "germanycw"}


@lru_cache(maxsize=1)
def _theatre_table() -> dict[str, dict[str, Any]]:
    """Load the per-theatre constants table (lowercased keys). Cached — the data is static."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "theatre-defaults.yaml")) or {}
    return {str(k).lower(): v for k, v in raw.items()}


def _resolve_key(theatre: str) -> str:
    """Lowercase + alias-resolve a theatre name to its canonical key."""
    key = theatre.lower()
    return _THEATRE_ALIASES.get(key, key)


def supported_theatres() -> list[str]:
    """Return the theatre names for which a blank can be synthesized (as declared, sorted)."""
    return sorted(entry["name"] for entry in _theatre_table().values())


def is_theatre_supported(theatre: str) -> bool:
    """Return whether a blank can be generated for `theatre` (case-insensitive, alias-aware)."""
    return _resolve_key(theatre) in _theatre_table()


def _resolve_theatre(theatre: str) -> dict[str, Any]:
    """Return the constants for ``theatre`` (case-insensitive, alias-aware), or raise ``ValueError``."""
    table = _theatre_table()
    entry = table.get(_resolve_key(theatre))
    if entry is None:
        supported = ", ".join(sorted(e["name"] for e in table.values()))
        raise ValueError(f"Unsupported theatre '{theatre}' (supported: {supported}).")
    return entry


def _coalition(name: str, bullseye: dict[str, float]) -> dict[str, Any]:
    """Build an empty coalition block (named, with a bullseye, no countries)."""
    return {"name": name, "bullseye": {"x": bullseye["x"], "y": bullseye["y"]}, "country": {}, "nav_points": {}}


def _mission_skeleton(theatre: dict[str, Any]) -> dict[str, Any]:
    """Compose the generic mission table with a theatre's constants (empty of groups)."""
    bullseye = theatre["bullseye"]
    return {
        "coalition": {
            "blue": _coalition("blue", bullseye["blue"]),
            "red": _coalition("red", bullseye["red"]),
            "neutrals": _coalition("neutrals", bullseye["neutrals"]),
        },
        "coalitions": {"blue": {}, "red": {}, "neutrals": {}},
        "date": {"Day": 1, "Month": 6, "Year": 2016},
        "start_time": 43200,
        "theatre": theatre["name"],
        "map": dict(theatre["map"]),
        "weather": {
            "atmosphere_type": 0,
            "clouds": {"base": 0, "density": 0, "iprecptns": 0, "preset": "Preset1", "thickness": 200},
            "cyclones": {},
            "enable_dust": False,
            "enable_fog": False,
            "fog": {"thickness": 0, "visibility": 0},
            "groundTurbulence": 0,
            "qnh": 760,
            "season": {"temperature": 20},
            "type_weather": 0,
            "visibility": {"distance": 80000},
            "wind": {
                "at8000": {"dir": 0, "speed": 0},
                "at2000": {"dir": 0, "speed": 0},
                "atGround": {"dir": 0, "speed": 0},
            },
        },
        "triggers": {"zones": {}},
        "trig": {
            "actions": {},
            "conditions": {},
            "custom": {},
            "customStartup": {},
            "events": {},
            "flag": {},
            "func": {},
            "funcStartup": {},
        },
        "trigrules": {},
        "result": {
            "blue": {"conditions": {}, "actions": {}, "func": {}},
            "red": {"conditions": {}, "actions": {}, "func": {}},
            "offline": {"conditions": {}, "actions": {}, "func": {}},
            "total": 0,
        },
        "groundControl": {
            "isPilotControlVehicles": False,
            "passwords": {},
            "roles": {
                "artillery_commander": {"blue": 0, "neutrals": 0, "red": 0},
                "forward_observer": {"blue": 0, "neutrals": 0, "red": 0},
                "instructor": {"blue": 0, "neutrals": 0, "red": 0},
                "observer": {"blue": 0, "neutrals": 0, "red": 0},
            },
        },
        "forcedOptions": {},
        "failures": {},
        "goals": {},
        "drawings": {
            # The ME draw panel sorts these layers on load, so the five standard named layers must
            # be present (an empty `layers` makes it compare nil values and abort the mission load).
            "layers": {
                1: {"name": "Red", "objects": {}, "visible": True},
                2: {"name": "Blue", "objects": {}, "visible": True},
                3: {"name": "Neutral", "objects": {}, "visible": True},
                4: {"name": "Common", "objects": {}, "visible": True},
                5: {"name": "Author", "objects": {}, "visible": True},
            },
            "options": {
                # Role keys are DCS's own literal spellings — "Spectrator" is DCS's (misspelled)
                # key, kept verbatim so the mission format matches what the ME reads/writes.
                "hiddenOnF10Map": {
                    role: {"Blue": False, "Neutral": False, "Red": False}
                    for role in (
                        "ArtilleryCommander",
                        "ForwardObserver",
                        "Instructor",
                        "Observer",
                        "Pilot",
                        "Spectrator",
                    )
                }
            },
        },
        "descriptionText": "",
        "descriptionBlueTask": "",
        "descriptionRedTask": "",
        "descriptionNeutralsTask": "",
        "pictureFileNameB": {},
        "pictureFileNameR": {},
        "pictureFileNameN": {},
        "sortie": "",
        "version": _MISSION_VERSION,
        "requiredModules": {},
        "maxDictId": 0,
        "currentKey": 0,
    }


def _serialize(content: dict[str, Any], variable_name: str) -> bytes:
    """Serialize a Lua table to ``<name> = \\n<lua>`` bytes (mirrors ``write_miz``)."""
    lua = luadata.serialize(content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)
    return f"{variable_name} = \n{lua}".encode()


def generate_blank_mission(theatre: str) -> dict[str, bytes]:
    """Generate the exploded ``src/mission/`` file set for a blank mission on ``theatre``.

    Args:
        theatre: The DCS theatre name (case-insensitive; must be in ``theatre-defaults.yaml``).

    Returns:
        A mapping of ``src/mission``-relative path to file bytes: ``mission``, ``options``,
        ``warehouses``, ``theatre``, and the ``l10n/DEFAULT/{dictionary,mapResource}`` pair.

    Raises:
        ValueError: when ``theatre`` is not in the supported set.
    """
    entry = _resolve_theatre(theatre)
    return {
        "mission": _serialize(_mission_skeleton(entry), "mission"),
        "options": _serialize({}, "options"),
        "warehouses": _serialize({"airports": {}, "warehouses": {}, "weapons": {}}, "warehouses"),
        "theatre": entry["name"].encode("utf-8"),
        _DICTIONARY_PATH: _serialize({}, "dictionary"),
        _MAP_RESOURCE_PATH: _serialize({}, "mapResource"),
    }
