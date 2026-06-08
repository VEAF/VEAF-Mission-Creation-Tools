"""Convert v5 pipeline config files to v6 YAML format.

Each public function converts a single v5 source file to its v6 YAML equivalent.
Returns a list of warning strings; writes output and logs on success.

Public API
----------
convert_waypoints(v5_path, v6_path)
convert_weather(v5_path, v6_path, *, icao_callback=None)
convert_presets(v5_path, v6_path)
convert_aircraft_groups(v5_path, v6_path)
convert_pipeline_file(step, v5_path, v6_path, *, icao_callback=None)
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import luadata
import yaml
from veaf_libs.i18n import t
from veaf_libs.logger import logger

# ---------------------------------------------------------------------------
# YAML helper
# ---------------------------------------------------------------------------


def _yaml_dump(data: Any, path: Path) -> None:
    """Write *data* as YAML to *path*, creating parent directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        yaml.dump(data, fh, default_flow_style=False, sort_keys=False, allow_unicode=True)


# ---------------------------------------------------------------------------
# Lua table extraction helpers
# ---------------------------------------------------------------------------


def _extract_lua_table_text(content: str, table_name: str) -> str | None:
    """Extract the ``{…}`` body of ``table_name = {…}`` from *content*.

    Returns the brace-enclosed text (inclusive of braces) or ``None``.
    """
    pattern = rf"(?:^|[\n;])\s*{re.escape(table_name)}\s*=\s*\{{"
    match = re.search(pattern, content)
    if not match:
        return None

    # Start at the opening brace
    start = match.end() - 1
    depth = 0
    in_str = False
    sc: str | None = None
    esc = False

    for i in range(start, len(content)):
        c = content[i]
        if esc:
            esc = False
            continue
        if c == "\\" and in_str:
            esc = True
            continue
        if c in ('"', "'") and not in_str:
            in_str, sc = True, c
        elif in_str and c == sc:
            in_str = False
        elif not in_str:
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return content[start : i + 1]
    return None


def _extract_block_at(text: str, open_brace_pos: int) -> str | None:
    """Return the brace-enclosed text starting at *open_brace_pos*.

    Args:
        text: Source text containing the block.
        open_brace_pos: Index of the opening ``{`` character.

    Returns:
        Slice from the opening ``{`` to its matching ``}``, inclusive,
        or ``None`` if the braces are unmatched.
    """
    depth = 0
    in_str = False
    sc: str | None = None
    esc = False
    for i in range(open_brace_pos, len(text)):
        c = text[i]
        if esc:
            esc = False
            continue
        if c == "\\" and in_str:
            esc = True
            continue
        if c in ('"', "'") and not in_str:
            in_str, sc = True, c
        elif in_str and c == sc:
            in_str = False
        elif not in_str:
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return text[open_brace_pos : i + 1]
    return None


@dataclass
class _RadioEntry:
    """Per-aircraft entry parsed from the v5 ``radioSettings`` table."""

    entry_key: str
    aircraft: str
    is_pattern: bool
    coalition: str
    radio_sources: dict[int, str | None] = field(default_factory=dict)
    """Maps DCS radio index (1-based) to source: ``"uhf"``, ``"vhf"``, ``"fm"``,
    ``"warbird"``, or ``None`` for hardcoded frequencies."""


#: Ordered checks to identify which standard preset table a radio block references.
#: First match wins (warbird > fm > vhf > uhf).
_RADIO_SOURCE_CHECKS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"radioPresetsWarbird(?:Blue|Red)\s*\["), "warbird"),
    (re.compile(r'radioPresets(?:Blue|Red)\["##RADIO3_'), "fm"),
    (re.compile(r'radioPresets(?:Blue|Red)\["##RADIO2_'), "vhf"),
    (re.compile(r'radioPresets(?:Blue|Red)\["##RADIO1_'), "uhf"),
]


def _detect_radio_block_source(block_text: str) -> str | None:
    """Return which standard preset source *block_text* references, or ``None``.

    Args:
        block_text: Raw Lua text of a single radio ``[N] = { … }`` block.

    Returns:
        One of ``"uhf"``, ``"vhf"``, ``"fm"``, ``"warbird"``, or ``None``
        when the block uses only hardcoded frequency literals.
    """
    for pattern, source in _RADIO_SOURCE_CHECKS:
        if pattern.search(block_text):
            return source
    return None


def _parse_radio_settings_entries(content: str) -> list[_RadioEntry]:
    """Parse all entries from the v5 ``radioSettings`` table.

    Each entry describes one aircraft type / coalition combination and which
    standard preset source each DCS radio slot references.

    Args:
        content: Full text of the v5 ``radioSettings.lua`` file.

    Returns:
        List of :class:`_RadioEntry` instances, one per entry found.
        Entries without a ``type`` / ``typePattern`` field are skipped.
    """
    table_text = _extract_lua_table_text(content, "radioSettings")
    if not table_text:
        return []

    entries: list[_RadioEntry] = []
    entry_pattern = re.compile(r'\["([^"]+)"\]\s*=\s*\{')

    for m in entry_pattern.finditer(table_text):
        entry_key = m.group(1)
        block_start = m.end() - 1
        block_text = _extract_block_at(table_text, block_start)
        if not block_text:
            continue

        # Skip nested sub-tables (["Radio"], ["channels"], etc.) which lack type info
        m_type = re.search(r'\btype\s*=\s*"([^"]+)"', block_text)
        m_typepattern = re.search(r'\btypePattern\s*=\s*"([^"]+)"', block_text)
        if not m_type and not m_typepattern:
            continue

        aircraft = (m_type or m_typepattern).group(1)  # type: ignore[union-attr]
        is_pattern = m_typepattern is not None

        m_coal = re.search(r'\bcoalition\s*=\s*"([^"]+)"', block_text)
        if not m_coal:
            continue
        coalition = m_coal.group(1).lower()

        # Parse radio sources from ["Radio"] = { [N] = { … }, … }
        radio_sources: dict[int, str | None] = {}
        radio_section_m = re.search(r'\["Radio"\]\s*=\s*\{', block_text)
        if radio_section_m:
            radio_block = _extract_block_at(block_text, radio_section_m.end() - 1)
            if radio_block:
                for rm in re.finditer(r'\[(\d+)\]\s*=\s*\{', radio_block):
                    idx = int(rm.group(1))
                    sub_block = _extract_block_at(radio_block, rm.end() - 1)
                    if sub_block:
                        radio_sources[idx] = _detect_radio_block_source(sub_block)

        entries.append(
            _RadioEntry(
                entry_key=entry_key,
                aircraft=aircraft,
                is_pattern=is_pattern,
                coalition=coalition,
                radio_sources=radio_sources,
            )
        )

    return entries


def _parse_lua_table(content: str, table_name: str) -> dict[str, Any] | None:
    """Extract and parse a named Lua table from *content*.

    Returns a Python dict or ``None`` if extraction/parsing fails.
    ``luadata.unserialize`` returns the inner value of the assignment, so
    ``x = {k=v}`` → ``{k: v}`` directly.
    """
    table_text = _extract_lua_table_text(content, table_name)
    if not table_text:
        return None
    try:
        result = luadata.unserialize(f"__conv = {table_text}", all_is_dict=True)
        return result if isinstance(result, dict) else None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Waypoints
# ---------------------------------------------------------------------------


def convert_waypoints(v5_path: Path, v6_path: Path) -> list[str]:
    """Convert v5 ``waypointsSettings.lua`` → v6 ``waypoints.yaml``.

    Key changes from v5 to v6:
    - ``speed_locked`` is removed; if it was ``true``, ``speed_type: TAS`` is added.
    - ``nil`` fields (``type``, ``country``, …) are dropped.
    """
    warnings: list[str] = []
    content = v5_path.read_text(encoding="utf-8")

    waypoints_data = _parse_lua_table(content, "waypoints")
    settings_data = _parse_lua_table(content, "settings")

    if waypoints_data is None and settings_data is None:
        warnings.append(
            t("convert_v5.warn.parse_failed", filename=v5_path.name, exc="no 'waypoints' or 'settings' tables found")
        )
        return warnings

    # ── Waypoints ─────────────────────────────────────────────────────────────
    v6_wps: dict[str, Any] = {}
    for name, wp in (waypoints_data or {}).items():
        if not isinstance(wp, dict):
            continue
        v6_wp: dict[str, Any] = {}
        for k, v in wp.items():
            if k == "speed_locked":
                continue  # replaced by speed_type below
            if v is None:
                continue
            v6_wp[k] = v
        if wp.get("speed_locked"):
            v6_wp["speed_type"] = "TAS"
        v6_wps[str(name)] = v6_wp

    # ── Settings ──────────────────────────────────────────────────────────────
    v6_settings: dict[str, Any] = {}
    for name, setting in (settings_data or {}).items():
        if not isinstance(setting, dict):
            continue
        v6_s: dict[str, Any] = {}
        for k, v in setting.items():
            if v is None:
                continue
            v6_s[k] = v
        # Ensure waypoints sub-dict is always present
        if not isinstance(v6_s.get("waypoints"), dict):
            v6_s["waypoints"] = {}
        v6_settings[str(name)] = v6_s

    output: dict[str, Any] = {}
    if v6_wps:
        output["waypoints"] = v6_wps
    if v6_settings:
        output["settings"] = v6_settings

    if not output:
        warnings.append(f"{v5_path.name}: no waypoints or settings data found — nothing written")
        return warnings

    _yaml_dump(output, v6_path)
    logger.info(t("v5convert.waypoints_done", source=v5_path.name, target=v6_path.name))
    return warnings


# ---------------------------------------------------------------------------
# Weather
# ---------------------------------------------------------------------------

#: Simplified mapping from DCS cloud preset name to v6 cloud_type.
_CLOUD_PRESET_MAP: dict[str, str] = {
    "Preset1": "few",
    "Preset2": "few",
    "Preset3": "scattered",
    "Preset4": "scattered",
    "Preset5": "scattered",
    "Preset6": "scattered",
    "Preset7": "broken",
    "Preset8": "broken",
    "Preset9": "broken",
    "Preset10": "broken",
    "Preset11": "broken",
    "Preset12": "broken",
    "Preset13": "broken",
    "Preset14": "overcast",
    "Preset15": "overcast",
    "Preset16": "overcast",
    "Preset17": "overcast",
    "Preset18": "overcast",
}


def _normalize_date(raw: str) -> str:
    """Convert DCS date string ``'202206290710'`` → ``'2022-06-29'``.

    Passes through strings that are already in YYYY-MM-DD format.
    """
    if re.match(r"^\d{12}$", raw):
        return f"{raw[:4]}-{raw[4:6]}-{raw[6:8]}"
    return raw


def _parse_dcs_weather_lua(lua_path: Path) -> tuple[dict[str, Any], list[str]]:
    """Extract simplified weather parameters from a DCS weather ``.lua`` file.

    DCS weather files use the format::

        ["weather"] = {
            ["atmosphere_type"] = 0,
            ["season"] = { ["temperature"] = 23.2 },
            ["wind"] = { ["atGround"] = { ["speed"] = 4.5, ["dir"] = 150 } },
            ["visibility"] = { ["distance"] = 1593 },
            ["clouds"] = { ["preset"] = "Preset13", ["base"] = 3400, ... },
            ...
        }

    Returns ``(params_dict, warnings)``.
    """
    warnings: list[str] = []
    if not lua_path.exists():
        warnings.append(f"Weather file not found: {lua_path.name}")
        return {}, warnings

    try:
        content = lua_path.read_text(encoding="utf-8")

        # Locate the ["weather"] = { … } block
        m = re.search(r'\["weather"\]\s*=\s*\{', content)
        if not m:
            raise ValueError("['weather'] table not found")

        start = m.end() - 1
        depth = 0
        in_str = False
        sc: str | None = None
        esc = False
        table_text = ""

        for i in range(start, len(content)):
            c = content[i]
            if esc:
                esc = False
                continue
            if c == "\\" and in_str:
                esc = True
                continue
            if c in ('"', "'") and not in_str:
                in_str, sc = True, c
            elif in_str and c == sc:
                in_str = False
            elif not in_str:
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        table_text = content[start : i + 1]
                        break
        else:
            raise ValueError("Unterminated weather table")

        _wd_raw = luadata.unserialize(f"__w = {table_text}", all_is_dict=True) or {}
        wd: dict[str, Any] = _wd_raw if isinstance(_wd_raw, dict) else {}

    except Exception as exc:
        warnings.append(t("convert_v5.warn.parse_failed", filename=lua_path.name, exc=str(exc)))
        return {}, warnings

    params: dict[str, Any] = {}

    # Temperature
    season = wd.get("season") or {}
    if temp := season.get("temperature"):
        params["temperature"] = round(float(temp), 1)

    # Wind at ground level
    wind = wd.get("wind") or {}
    at_ground = wind.get("atGround") or {}
    if speed := at_ground.get("speed"):
        params["wind_speed"] = round(float(speed), 1)
    if direction := at_ground.get("dir"):
        params["wind_direction"] = round(float(direction), 1)

    # Visibility
    vis = wd.get("visibility") or {}
    if dist := vis.get("distance"):
        params["visibility"] = int(dist)

    # Clouds
    clouds = wd.get("clouds") or {}
    if preset := clouds.get("preset"):
        params["cloud_type"] = _CLOUD_PRESET_MAP.get(str(preset), "scattered")
    if base := clouds.get("base"):
        params["cloud_height"] = int(base)

    return params, warnings


def convert_weather(
    v5_path: Path,
    v6_path: Path,
    *,
    icao_callback: Callable[[str], str] | None = None,
) -> list[str]:
    """Convert v5 ``versions.json`` (or ``versions.lua``) → v6 ``versions.yaml``.

    Key renames:
    - ``position.lat/lon/tz`` → ``latitude/longitude/timezone``
    - ``targets`` → ``versions``; ``version`` → ``name``
    - ``moment`` → ``time`` (resolved from the ``moments`` dict)
    - ``realweather: true`` → ``airport_icao: <ICAO>`` (prompted via *icao_callback*)
    - ``weatherfile: x.lua`` → inline ``weather:`` block (DCS params extracted)
    - ``weather: "METAR …"`` → ``metar:``
    - ``date: "202206290710"`` → ``date: "2022-06-29"``
    """
    warnings: list[str] = []

    # ── Parse source ─────────────────────────────────────────────────────────
    if v5_path.suffix == ".json":
        try:
            v5_data: dict[str, Any] = json.loads(v5_path.read_text(encoding="utf-8"))
        except Exception as exc:
            warnings.append(t("convert_v5.warn.parse_failed", filename=v5_path.name, exc=str(exc)))
            return warnings
    else:
        # .lua format (older v5 missions) — delegate to LuaToYamlConverter
        from weather_injector.utils.lua_converter import LuaToYamlConverter  # noqa: PLC0415

        lua_content = v5_path.read_text(encoding="utf-8")
        v5_data = LuaToYamlConverter._parse_lua_config(lua_content) or {}
        if not v5_data:
            warnings.append(
                t("convert_v5.warn.parse_failed", filename=v5_path.name, exc="not a valid Lua weather config")
            )
            return warnings

    output: dict[str, Any] = {}

    # ── Position ─────────────────────────────────────────────────────────────
    pos = v5_data.get("position") or {}
    if pos:
        output["position"] = {
            "latitude": pos.get("lat", pos.get("latitude")),
            "longitude": pos.get("lon", pos.get("longitude")),
            "timezone": pos.get("tz", pos.get("timezone")),
        }

    # ── Moments lookup (v5 only) ──────────────────────────────────────────────
    moments: dict[str, str] = v5_data.get("moments") or {}

    # ── Versions ─────────────────────────────────────────────────────────────
    raw_versions: list[dict[str, Any]] = v5_data.get("targets") or v5_data.get("versions") or []
    v6_versions: list[dict[str, Any]] = []

    for target in raw_versions:
        ver: dict[str, Any] = {}
        ver["name"] = str(target.get("version") or target.get("name") or "unknown")

        # Time (resolve moment reference)
        moment_key = target.get("moment")
        if moment_key and moment_key in moments:
            ver["time"] = moments[str(moment_key)]
        elif "time" in target:
            ver["time"] = target["time"]

        # Date
        if raw_date := target.get("date"):
            ver["date"] = _normalize_date(str(raw_date))

        # Weather source
        if target.get("realweather"):
            icao = ""
            if icao_callback:
                icao = icao_callback(ver["name"])
            ver["airport_icao"] = icao.strip().upper() if icao else "TODO"
            if not icao:
                warnings.append(
                    f"Version '{ver['name']}': realweather=true — "
                    f"replace 'TODO' with the actual ICAO code in {v6_path.name}"
                )
            if target.get("clearsky"):
                ver["clearsky"] = True
        elif weatherfile := target.get("weatherfile"):
            lua_file = v5_path.parent / str(weatherfile)
            weather_params, lua_warns = _parse_dcs_weather_lua(lua_file)
            warnings.extend(f"Version '{ver['name']}': {w}" for w in lua_warns)
            ver["weather"] = weather_params or {}
        elif metar := target.get("weather"):
            ver["metar"] = str(metar)

        v6_versions.append(ver)

    output["versions"] = v6_versions

    _yaml_dump(output, v6_path)
    logger.info(t("v5convert.weather_done", source=v5_path.name, target=v6_path.name))
    return warnings


# ---------------------------------------------------------------------------
# Presets
# ---------------------------------------------------------------------------

#: Radio type by v5 radio number (1=UHF, 2=VHF, 3=FM).
_RADIO_TYPES: dict[int, str] = {1: "uhf", 2: "vhf", 3: "fm"}
#: Display title by v5 radio number.
_RADIO_TITLES: dict[int, str] = {1: "UHF", 2: "VHF", 3: "FM"}


def _parse_preset_table(content: str, table_name: str) -> dict[int, dict[int, dict[str, Any]]]:
    """Parse a v5 ``radioPresets*`` table.

    Returns ``{radio_num: {ch_num: {"freq": float, "title": str}}}``.
    Handles standard keys ``##RADIOx_NN##`` (frequency) and
    ``##RADIOx_NAME_NN##`` (channel title).
    """
    table_text = _extract_lua_table_text(content, table_name)
    if not table_text:
        return {}
    try:
        _raw = luadata.unserialize(f"__t = {table_text}", all_is_dict=True) or {}
        raw: dict[str, Any] = _raw if isinstance(_raw, dict) else {}
    except Exception:
        return {}

    result: dict[int, dict[int, dict[str, Any]]] = {}
    for key, value in raw.items():
        ks = str(key)
        m_name = re.match(r"^##RADIO(\d+)_NAME_(\d+)##$", ks)
        m_freq = re.match(r"^##RADIO(\d+)_(\d+)##$", ks)
        if m_name:
            rn, cn = int(m_name.group(1)), int(m_name.group(2))
            result.setdefault(rn, {}).setdefault(cn, {})["title"] = str(value)
        elif m_freq:
            rn, cn = int(m_freq.group(1)), int(m_freq.group(2))
            result.setdefault(rn, {}).setdefault(cn, {})["freq"] = float(value)
    return result


def _parse_custom_preset_table(content: str, table_name: str) -> list[float]:
    """Parse a v5 warbird ``radioPresetsWarbird*`` table.

    Returns a list of frequencies sorted by key name.
    Keys of the form ``##RADIO_FuG16_NN##`` are included;
    ``##…_NAME_##`` and ``##…_BASE##`` entries are skipped.
    """
    table_text = _extract_lua_table_text(content, table_name)
    if not table_text:
        return []
    try:
        _raw = luadata.unserialize(f"__t = {table_text}", all_is_dict=True) or {}
        raw: dict[str, Any] = _raw if isinstance(_raw, dict) else {}
    except Exception:
        return []

    freq_by_key: dict[str, float] = {}
    for key, value in raw.items():
        ks = str(key)
        if "NAME" in ks or "BASE" in ks:
            continue
        if isinstance(value, (int, float)):
            freq_by_key[ks] = float(value)
    return [v for _, v in sorted(freq_by_key.items())]


def convert_presets(v5_path: Path, v6_path: Path) -> list[str]:
    """Convert v5 ``radioSettings.lua`` → v6 ``presets.yaml``.

    Generates:

    - ``radios_collection:`` — one UHF/VHF/FM radio per coalition, plus
      optional warbird radio when ``radioPresetsWarbird*`` tables are found.
    - ``presets_collection:`` — one standard preset per coalition (plus warbird).
    - ``presets_assignments:`` — ``all`` → standard preset for planes and
      helicopters of each coalition.

    .. note::
        Per-aircraft overrides (warbirds, historic aircraft) are not extracted
        from ``radioSettings``.  A warning is emitted listing items to review.
    """
    warnings: list[str] = []
    content = v5_path.read_text(encoding="utf-8")

    radios_collection: dict[str, Any] = {}
    presets_collection: dict[str, Any] = {}
    presets_assignments: dict[str, Any] = {}

    for coalition in ("blue", "red"):
        cap = coalition.capitalize()
        table_name = f"radioPresets{cap}"
        radios_data = _parse_preset_table(content, table_name)
        if not radios_data:
            continue

        coalition_radios: dict[str, Any] = {}
        coalition_radio_names: dict[int, str] = {}

        for radio_num in sorted(radios_data.keys()):
            channels_data = radios_data[radio_num]
            rtype = _RADIO_TYPES.get(radio_num, f"radio{radio_num}")
            rtitle = _RADIO_TITLES.get(radio_num, f"Radio {radio_num}")
            radio_name = f"radio_{rtype}_{coalition}"
            coalition_radio_names[radio_num] = radio_name

            v6_channels: dict[int, Any] = {}
            for ch_num in sorted(channels_data.keys()):
                ch = channels_data[ch_num]
                freq = ch.get("freq")
                title = ch.get("title")
                if freq is None:
                    continue
                # FM channels often have generic placeholder names → store freq only
                if title and rtype != "fm":
                    v6_channels[ch_num] = {"title": title, "freq": float(freq)}
                else:
                    v6_channels[ch_num] = float(freq)

            coalition_radios[radio_name] = {
                "title": rtitle,
                "type": rtype,
                "channels": v6_channels,
            }

        radios_collection[f"{coalition}_radios"] = coalition_radios

        # Standard preset
        preset_name = f"{coalition}_standard"
        presets_collection.setdefault(f"{coalition}_presets", {})[preset_name] = {
            "title": f"{cap} coalition - standard (UHF/VHF/FM)",
            "radios": {f"radio_{n}": name for n, name in coalition_radio_names.items()},
        }
        presets_assignments[coalition] = {
            "plane": {"all": preset_name},
            "helicopter": {"all": preset_name},
        }

        # Warbird preset (optional)
        warbird_table = f"radioPresetsWarbird{cap}"
        warbird_freqs = _parse_custom_preset_table(content, warbird_table)
        if warbird_freqs:
            warbird_radio_name = f"radio_warbird_{coalition}"
            radios_collection[f"{coalition}_radios"][warbird_radio_name] = {
                "title": "Warbird",
                "type": "vhf",
                "channels": {i + 1: freq for i, freq in enumerate(warbird_freqs)},
            }
            warbird_preset_name = f"{coalition}_warbird"
            presets_collection[f"{coalition}_presets"][warbird_preset_name] = {
                "title": f"{cap} coalition - warbird",
                "radios": {"radio_1": warbird_radio_name},
            }

    if not radios_collection:
        warnings.append(t("convert_v5.warn.no_preset_tables", filename=v5_path.name))
        return warnings

    # Per-aircraft assignments extracted from radioSettings
    for entry in _parse_radio_settings_entries(content):
        if not entry.radio_sources or entry.coalition not in presets_assignments:
            continue

        radio1_source = entry.radio_sources.get(1)

        # Aircraft whose radio [1] is UHF are covered by the "all: standard" fallback
        if radio1_source == "uhf":
            continue

        if entry.is_pattern:
            # typePattern entries cannot be represented as exact keys in presets_assignments
            if radio1_source in ("warbird", "vhf"):
                recommended = (
                    f"{entry.coalition}_warbird"
                    if radio1_source == "warbird"
                    else f"{entry.coalition}_vhf_primary"
                )
                warnings.append(
                    t(
                        "convert_v5.warn.radio_type_pattern_skip",
                        aircraft=entry.aircraft,
                        coalition=entry.coalition,
                        preset=recommended,
                    )
                )
            continue

        if radio1_source == "warbird":
            target_preset = f"{entry.coalition}_warbird"
            if target_preset not in presets_collection.get(f"{entry.coalition}_presets", {}):
                continue
        elif radio1_source == "vhf":
            target_preset = f"{entry.coalition}_vhf_primary"
            vhf_radio_name = f"radio_vhf_{entry.coalition}"
            if vhf_radio_name not in radios_collection.get(f"{entry.coalition}_radios", {}):
                continue
            if target_preset not in presets_collection.get(f"{entry.coalition}_presets", {}):
                presets_collection.setdefault(f"{entry.coalition}_presets", {})[target_preset] = {
                    "title": f"{entry.coalition.capitalize()} coalition - VHF primary",
                    "radios": {"radio_1": vhf_radio_name},
                }
        elif radio1_source is None:
            # Fully hardcoded frequencies — no preset mapping possible
            warnings.append(
                t(
                    "convert_v5.warn.radio_hardcoded_skip",
                    aircraft=entry.aircraft,
                    coalition=entry.coalition,
                )
            )
            continue
        else:
            # FM-only or other — leave under the "all" fallback
            continue

        presets_assignments[entry.coalition].setdefault("plane", {})[entry.aircraft] = target_preset

    # Emit warbird warnings after processing all entries (so we know which were assigned)
    for coalition in ("blue", "red"):
        warbird_preset_name = f"{coalition}_warbird"
        if warbird_preset_name in presets_collection.get(f"{coalition}_presets", {}):
            warnings.append(
                t("convert_v5.warn.warbird_preset", preset=warbird_preset_name, coalition=coalition)
            )

    output: dict[str, Any] = {
        "radios_collection": radios_collection,
        "presets_collection": presets_collection,
        "presets_assignments": presets_assignments,
    }
    _yaml_dump(output, v6_path)
    logger.info(t("v5convert.presets_done", source=v5_path.name, target=v6_path.name))
    warnings.append(t("convert_v5.warn.review_presets", filename=v6_path.name))
    return warnings


# ---------------------------------------------------------------------------
# Aircraft groups
# ---------------------------------------------------------------------------


def convert_aircraft_groups(v5_path: Path, v6_path: Path) -> list[str]:
    """Convert v5 ``spawnableAircrafts/settings.lua`` → v6 ``templates.yaml``.

    Performs a structural conversion:

    - ``settings.categories.plane.coalitions.COALITION.countries.COUNTRY.groups.NAME``
      → ``airplanes.coalitions.COALITION.COUNTRY.NAME``
    - ``settings.categories.helicopter.…``
      → ``helicopters.coalitions.…``

    DCS group data (routes, tasks, units, …) is preserved as-is.

    .. warning::
        ``groupId`` / ``unitId`` values in the exported YAML are the original IDs
        from the source mission.  If you inject into a *different* mission these
        IDs will conflict.  Review and update them before injection.
    """
    warnings: list[str] = []
    try:
        content = v5_path.read_text(encoding="utf-8")
        _raw = luadata.unserialize(content, all_is_dict=True) or {}
        raw: dict[str, Any] = _raw if isinstance(_raw, dict) else {}
    except Exception as exc:
        warnings.append(t("convert_v5.warn.parse_failed", filename=v5_path.name, exc=str(exc)))
        return warnings

    if not isinstance(raw, dict):
        warnings.append(t("convert_v5.warn.unexpected_parse", filename=v5_path.name))
        return warnings

    # luadata.unserialize returns the inner value, so raw == contents of `settings`
    categories = raw.get("categories") or {}

    _CATEGORY_MAP: dict[str, str] = {"plane": "airplanes", "helicopter": "helicopters"}
    output: dict[str, Any] = {
        "airplanes": {"coalitions": {}},
        "helicopters": {"coalitions": {}},
    }

    for v5_cat, v6_cat in _CATEGORY_MAP.items():
        cat_data = categories.get(v5_cat) or {}
        coalitions_data = cat_data.get("coalitions") or {}
        for coalition, coalition_data in coalitions_data.items():
            if not isinstance(coalition_data, dict):
                continue
            countries_data = coalition_data.get("countries") or {}
            v6_coalition: dict[str, Any] = {}
            for country, country_data in countries_data.items():
                if not isinstance(country_data, dict):
                    continue
                groups = country_data.get("groups") or {}
                if groups:
                    v6_coalition[str(country)] = {str(k): v for k, v in groups.items()}
            if v6_coalition:
                output[v6_cat]["coalitions"][str(coalition)] = v6_coalition

    _yaml_dump(output, v6_path)
    logger.info(t("v5convert.aircraft_done", source=v5_path.name, target=v6_path.name))
    warnings.append(t("convert_v5.warn.aircraft_review", filename=v5_path.name))
    return warnings


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------


def convert_pipeline_file(
    step: str,
    v5_path: Path,
    v6_path: Path,
    *,
    icao_callback: Callable[[str], str] | None = None,
) -> list[str]:
    """Route *step* to the appropriate converter and return warnings."""
    if step == "waypoints":
        return convert_waypoints(v5_path, v6_path)
    if step == "weather":
        return convert_weather(v5_path, v6_path, icao_callback=icao_callback)
    if step == "presets":
        return convert_presets(v5_path, v6_path)
    if step == "aircraft_groups":
        return convert_aircraft_groups(v5_path, v6_path)
    return [t("convert_v5.warning.no_converter", step=step)]
