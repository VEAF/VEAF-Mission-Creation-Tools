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

import importlib.resources
import json
import re
import sys
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import luadata
import yaml
from mission_tools import KIND_DYNAMIC_TEMPLATE, KIND_SPAWNABLE, classify_aircraft_group
from presets_injector.presets_manager import PresetDefinition, pack_preset_for_type, parse_channel_lists
from veaf_libs.i18n import t, tn
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


#: A parsed channel value: either a resolved reference ``(table_var, token)``
#: such as ``("radioPresetsBlue", "##RADIO1_20##")`` or a hardcoded frequency.
_ChannelValue = tuple[str, str] | float


@dataclass
class _RadioSlot:
    """One DCS radio slot (``["Radio"][N]``) parsed from a ``radioSettings`` entry."""

    source: str | None
    """Detected standard preset source (``"uhf"``/``"vhf"``/``"fm"``/``"warbird"``) or ``None``."""
    channels: list[tuple[int, _ChannelValue]] = field(default_factory=list)
    """Ordered ``(dcs_channel_index, value)`` pairs (value is a token ref or literal)."""
    modulations: dict[int, int] = field(default_factory=dict)
    """Maps DCS channel index to its modulation flag (``0`` = AM, ``1`` = FM)."""
    unparsed: int = 0
    """Count of ``[idx] = …`` assignments whose value was neither a preset token
    nor a numeric literal (e.g. an unsupported Lua expression) and was dropped."""


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
    radio_slots: dict[int, _RadioSlot] = field(default_factory=dict)
    """Maps DCS radio index (1-based) to its fully parsed slot (channels + modulations)."""


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


#: Matches a v5 preset reference like ``radioPresetsBlue["##RADIO1_20##"]``.
_CHANNEL_REF_RE = re.compile(r'(\w+)\s*\[\s*"(##[^"]+##)"\s*\]')


def _extract_named_subblock(block_text: str, key: str) -> str | None:
    """Return the ``{…}`` body of ``["key"] = {…}`` inside *block_text*, or ``None``."""
    m = re.search(rf'\["{re.escape(key)}"\]\s*=\s*\{{', block_text)
    if not m:
        return None
    return _extract_block_at(block_text, m.end() - 1)


def _parse_slot_channels(slot_block: str) -> tuple[list[tuple[int, _ChannelValue]], int]:
    """Parse the ``["channels"]`` sub-table of a radio slot.

    Args:
        slot_block: Raw Lua text of a single ``["Radio"][N] = { … }`` slot.

    Returns:
        A ``(channels, unparsed)`` tuple where *channels* are ordered
        ``(channel_index, value)`` pairs (value is a ``(table_var, token)``
        reference or a hardcoded ``float``), and *unparsed* counts assignments
        whose value matched neither shape (an unsupported Lua expression).
    """
    channels_block = _extract_named_subblock(slot_block, "channels")
    if not channels_block:
        return [], 0
    result: list[tuple[int, _ChannelValue]] = []
    unparsed = 0
    for m in re.finditer(r"\[(\d+)\]\s*=\s*([^\n,}]+)", channels_block):
        idx = int(m.group(1))
        raw = m.group(2).strip().rstrip(",").strip()
        ref = _CHANNEL_REF_RE.match(raw)
        if ref:
            result.append((idx, (ref.group(1), ref.group(2))))
            continue
        try:
            result.append((idx, float(raw)))
        except ValueError:
            unparsed += 1
    return result, unparsed


def _parse_slot_modulations(slot_block: str) -> dict[int, int]:
    """Parse the ``["modulations"]`` sub-table of a radio slot into ``{index: flag}``."""
    mods_block = _extract_named_subblock(slot_block, "modulations")
    if not mods_block:
        return {}
    return {int(m.group(1)): int(m.group(2)) for m in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", mods_block)}


def _token_channel_number(token: str) -> tuple[str, int] | None:
    """Return ``(token_type, channel_number)`` for a preset token, or ``None``.

    Handles standard tokens (``##RADIO1_20##`` → ``("radio1", 20)``) and warbird
    tokens (``##RADIO_FuG16_01##`` → ``("FuG16", 1)``). ``BASE``/``NAME`` and any
    other shape return ``None``.
    """
    m = re.match(r"^##RADIO(\d+)_(\d+)##$", token)
    if m:
        return f"radio{m.group(1)}", int(m.group(2))
    m = re.match(r"^##RADIO_([A-Za-z0-9]+)_(\d+)##$", token)
    if m:
        return m.group(1), int(m.group(2))
    return None


def _slot_is_clean(slot: _RadioSlot) -> bool:
    """Return True when a slot is a plain 1:1 image of a single standard preset table.

    A *clean* slot only references preset tokens (no hardcoded literals), uses a
    single token type, and maps DCS channel index ``i`` to that table's channel
    ``i`` contiguously from 1 — i.e. no rotation, offset, mixing, or extras.
    """
    if not slot.channels:
        return False
    token_type: str | None = None
    for position, (idx, value) in enumerate(slot.channels, start=1):
        if not isinstance(value, tuple):
            return False  # hardcoded literal
        parsed = _token_channel_number(value[1])
        if parsed is None:
            return False  # BASE / NAME / unparseable token
        this_type, channel_number = parsed
        if idx != position or channel_number != idx:
            return False  # offset or rotation
        if token_type is None:
            token_type = this_type
        elif token_type != this_type:
            return False  # mixed token types within one slot
    return True


def _entry_is_standard(entry: _RadioEntry) -> bool:
    """Return True when every radio slot is clean and carries no active modulation."""
    if not entry.radio_slots:
        return False
    for slot in entry.radio_slots.values():
        if not _slot_is_clean(slot):
            return False
        if any(flag != 0 for flag in slot.modulations.values()):
            return False
    return True


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
        m_type = re.search(r'\btype\s*=\s*[\'"]([^\'"]+)[\'"]', block_text)
        m_typepattern = re.search(r'\btypePattern\s*=\s*[\'"]([^\'"]+)[\'"]', block_text)
        if not m_type and not m_typepattern:
            continue

        aircraft = (m_type or m_typepattern).group(1)  # type: ignore[union-attr]
        is_pattern = m_typepattern is not None

        m_coal = re.search(r'\bcoalition\s*=\s*[\'"]([^\'"]+)[\'"]', block_text)
        if not m_coal:
            continue
        coalition = m_coal.group(1).lower()

        # Parse radio sources from ["Radio"] = { [N] = { … }, … }
        radio_sources: dict[int, str | None] = {}
        radio_slots: dict[int, _RadioSlot] = {}
        radio_section_m = re.search(r'\["Radio"\]\s*=\s*\{', block_text)
        if radio_section_m:
            radio_block = _extract_block_at(block_text, radio_section_m.end() - 1)
            if radio_block:
                for rm in re.finditer(r"\[(\d+)\]\s*=\s*\{", radio_block):
                    idx = int(rm.group(1))
                    sub_block = _extract_block_at(radio_block, rm.end() - 1)
                    if sub_block:
                        source = _detect_radio_block_source(sub_block)
                        channels, unparsed = _parse_slot_channels(sub_block)
                        radio_sources[idx] = source
                        radio_slots[idx] = _RadioSlot(
                            source=source,
                            channels=channels,
                            modulations=_parse_slot_modulations(sub_block),
                            unparsed=unparsed,
                        )

        entries.append(
            _RadioEntry(
                entry_key=entry_key,
                aircraft=aircraft,
                is_pattern=is_pattern,
                coalition=coalition,
                radio_sources=radio_sources,
                radio_slots=radio_slots,
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
        warnings.append(t("convert_v5.warn.waypoints_empty", filename=v5_path.name))
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
        warnings.append(t("convert_v5.warn.weather_file_not_found", filename=lua_path.name))
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

    # Temperature — use `is not None` so legitimate 0 values are not dropped.
    season = wd.get("season") or {}
    temp = season.get("temperature")
    if temp is not None:
        params["temperature"] = round(float(temp), 1)

    # Wind at ground level (0 speed = calm, 0 dir = due North are valid)
    wind = wd.get("wind") or {}
    at_ground = wind.get("atGround") or {}
    speed = at_ground.get("speed")
    if speed is not None:
        params["wind_speed"] = round(float(speed), 1)
    direction = at_ground.get("dir")
    if direction is not None:
        params["wind_direction"] = round(float(direction), 1)

    # Visibility
    vis = wd.get("visibility") or {}
    dist = vis.get("distance")
    if dist is not None:
        params["visibility"] = int(dist)

    # Clouds
    clouds = wd.get("clouds") or {}
    if preset := clouds.get("preset"):
        params["cloud_type"] = _CLOUD_PRESET_MAP.get(str(preset), "scattered")
    base = clouds.get("base")
    if base is not None:
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
                warnings.append(t("convert_v5.warn.realweather_todo", name=ver["name"], filename=v6_path.name))
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


def _load_helicopter_types() -> set[str]:
    """Return the set of DCS unit type names classified as helicopters in dcs-radio-specs.yaml."""
    bundle_path = Path(getattr(sys, "_MEIPASS", "")) / "presets_injector" / "data" / "dcs-radio-specs.yaml"
    if bundle_path.exists():
        raw = bundle_path.read_text(encoding="utf-8")
    else:
        pkg = importlib.resources.files("presets_injector.data")
        raw = (pkg / "dcs-radio-specs.yaml").read_text(encoding="utf-8")  # type: ignore[arg-type]
    specs: dict[str, Any] = yaml.safe_load(raw) or {}
    return {name for name, info in specs.items() if isinstance(info, dict) and info.get("category") == "helicopter"}


def _detect_category(aircraft: str, is_pattern: bool, helicopter_types: set[str]) -> list[str]:
    """Return the list of assignment categories for an aircraft entry.

    Args:
        aircraft: Exact DCS unit type name or regex pattern (when ``is_pattern`` is True).
        is_pattern: Whether ``aircraft`` is a ``typePattern`` regex.
        helicopter_types: Set of known DCS helicopter unit type names.

    Returns:
        A list containing ``"helicopter"``, ``"plane"``, or both.
    """
    if is_pattern:
        helis_matched = any(_safe_fullmatch(aircraft, h) for h in helicopter_types)
        # Since we cannot enumerate all plane types, conservatively assign to both
        # categories when the pattern matches at least one helicopter.
        if helis_matched:
            return ["helicopter", "plane"]
        return ["plane"]
    return ["helicopter"] if aircraft in helicopter_types else ["plane"]


def _safe_fullmatch(pattern: str, text: str) -> bool:
    """Return True if ``pattern`` fully matches ``text``, False on error or no match."""
    try:
        return bool(re.fullmatch(pattern, text))
    except re.error:
        return False


#: v5 preset table variable names that hold token → frequency mappings.
_PRESET_TABLE_VARS: tuple[str, ...] = (
    "radioPresetsBlue",
    "radioPresetsRed",
    "radioPresetsWarbirdBlue",
    "radioPresetsWarbirdRed",
)


def _parse_token_freqs(content: str, table_name: str) -> dict[str, float]:
    """Parse a v5 preset table into a flat ``{token: frequency}`` map.

    Only numeric entries are kept, so ``##RADIOx_NAME_yy##`` string titles are
    skipped while ``##RADIO_FuG16_BASE##`` numeric literals are retained.
    """
    table_text = _extract_lua_table_text(content, table_name)
    if not table_text:
        return {}
    try:
        _raw = luadata.unserialize(f"__t = {table_text}", all_is_dict=True) or {}
        raw: dict[str, Any] = _raw if isinstance(_raw, dict) else {}
    except Exception:
        return {}
    return {str(k): float(v) for k, v in raw.items() if isinstance(v, (int, float))}


def _build_token_resolver(content: str) -> dict[str, dict[str, float]]:
    """Return ``{table_var: {token: frequency}}`` for every v5 preset table."""
    return {var: _parse_token_freqs(content, var) for var in _PRESET_TABLE_VARS}


def _resolve_channel_value(value: _ChannelValue, resolver: dict[str, dict[str, float]]) -> float | None:
    """Resolve a parsed channel value to its frequency, or ``None`` if unresolvable."""
    if isinstance(value, tuple):
        table_var, token = value
        return resolver.get(table_var, {}).get(token)
    return value


def _aircraft_slug(aircraft: str) -> str:
    """Build a YAML-safe identifier fragment from an aircraft type or pattern."""
    slug = re.sub(r"[^a-z0-9]+", "_", aircraft.lower()).strip("_")
    return slug or "aircraft"


#: Maps a detected radio-block source to a v6 radio ``type``.
_DEDICATED_TYPE_BY_SOURCE: dict[str | None, str] = {
    "uhf": "uhf",
    "vhf": "vhf",
    "fm": "fm",
    "warbird": "vhf",
    None: "uhf",
}


def _resolve_dedicated_channels(
    entry: _RadioEntry, resolver: dict[str, dict[str, float]]
) -> tuple[dict[int, dict[int, Any]], int]:
    """Resolve *entry*'s exact v5 ``["Radio"]`` table into v6 channel maps, per slot.

    Pure resolution step shared by :func:`_emit_dedicated_preset` (writes the
    result into the legacy per-aircraft preset) and the preset-plan
    factorability check (ticket 08: compares this exact map against the
    packer's projection to decide whether an aircraft needs the legacy
    fallback).

    Args:
        entry: The aircraft's parsed ``radioSettings`` entry.
        resolver: ``{table_var: {token: frequency}}`` built by
            :func:`_build_token_resolver`.

    Returns:
        A ``(slots, dropped)`` tuple: *slots* maps radio slot index -> v6
        channel map (``{ch_idx: freq}`` or ``{ch_idx: {"freq":, "mod":}}`` when
        the slot has modulations), empty slots omitted; *dropped* counts
        channels that could not be converted (unresolved token or unparsed
        expression).
    """
    slots: dict[int, dict[int, Any]] = {}
    dropped = 0
    for slot_idx in sorted(entry.radio_slots.keys()):
        slot = entry.radio_slots[slot_idx]
        has_mods = bool(slot.modulations)
        dropped += slot.unparsed

        v6_channels: dict[int, Any] = {}
        for ch_idx, value in slot.channels:
            freq = _resolve_channel_value(value, resolver)
            if freq is None:
                dropped += 1
                continue
            if has_mods:
                v6_channels[ch_idx] = {"freq": freq, "mod": int(slot.modulations.get(ch_idx, 0))}
            else:
                v6_channels[ch_idx] = freq

        # Skip empty radios so a slot that yielded no usable channel never produces
        # a hollow radio definition.
        if v6_channels:
            slots[slot_idx] = v6_channels
    return slots, dropped


def _emit_dedicated_preset(
    entry: _RadioEntry,
    resolver: dict[str, dict[str, float]],
    radios_collection: dict[str, Any],
    presets_collection: dict[str, Any],
    presets_assignments: dict[str, Any],
    helicopter_types: set[str],
    warnings: list[str],
) -> None:
    """Emit a per-aircraft preset that reproduces a bespoke v5 ``["Radio"]`` table.

    Each radio slot becomes a dedicated radio whose channels carry the exact
    frequencies from the v5 table (resolving preset tokens, keeping hardcoded
    literals). When a slot defines a ``modulations`` table, every channel also
    carries its ``mod`` flag so the AM/FM selection round-trips.
    """
    coalition = entry.coalition
    cap = coalition.capitalize()
    slug = _aircraft_slug(entry.aircraft)
    preset_name = f"{coalition}_{slug}"
    radios_key = f"{coalition}_radios"
    presets_key = f"{coalition}_presets"

    coalition_radios = radios_collection.setdefault(radios_key, {})
    preset_radios: dict[str, str] = {}

    resolved_slots, dropped = _resolve_dedicated_channels(entry, resolver)
    for slot_idx, v6_channels in resolved_slots.items():
        radio_name = f"radio_{coalition}_{slug}_{slot_idx}"
        rtype = _DEDICATED_TYPE_BY_SOURCE[entry.radio_slots[slot_idx].source]
        coalition_radios[radio_name] = {
            "title": f"{entry.aircraft} radio {slot_idx}",
            "type": rtype,
            "channels": v6_channels,
        }
        preset_radios[f"radio_{slot_idx}"] = radio_name

    if dropped:
        warnings.append(
            tn(
                "convert_v5.warn.radio_channels_dropped",
                dropped,
                aircraft=entry.aircraft,
                coalition=coalition,
            )
        )

    # Nothing usable was parsed — do not emit an empty preset or assignment.
    if not preset_radios:
        return

    presets_collection.setdefault(presets_key, {})[preset_name] = {
        "title": f"{cap} coalition - {entry.aircraft} (iso-functional)",
        "radios": preset_radios,
    }

    for cat in _detect_category(entry.aircraft, entry.is_pattern, helicopter_types):
        presets_assignments[coalition].setdefault(cat, {})[entry.aircraft] = preset_name


# ---------------------------------------------------------------------------
# Preset plan generation (ADR 0010 ticket 08: convert-v5 generates a preset
# plan by default, falling back to the ADR 0003 per-aircraft copy when a
# bespoke aircraft's exact v5 channel map cannot be reproduced by the packer).
# ---------------------------------------------------------------------------

#: Maps a v5 physical radio number to the Channel-list role(s) (ADR 0010) fed
#: by its preset table. RADIO3 (FM) is exposed under both FM roles so the
#: packer resolves regardless of whether a given airframe's layout assigns it
#: `fm_substitute` (helicopters) or `fm_supplement` (attack aircraft) — the
#: mission only declares one FM channel list, not one per airframe shape.
_ROLES_BY_RADIO_NUM: dict[int, list[str]] = {
    1: ["primary_1"],
    2: ["primary_2"],
    3: ["fm_substitute", "fm_supplement"],
}


def _build_channel_lists_for_coalition(radios_data: dict[int, dict[int, dict[str, Any]]]) -> dict[str, Any]:
    """Build one coalition's ``channel_lists`` role -> channels mapping (ADR 0010).

    Args:
        radios_data: This coalition's parsed ``radioPresets*`` table, as
            returned by :func:`_parse_preset_table` (``{radio_num: {ch_num:
            {"freq":, "title":}}}``).

    Returns:
        A ``{role: {channel_name: freq}}`` mapping (``RadioDefinition.
        add_channel_from_dict``'s plain-float shortcut), ready to nest under
        ``channel_lists.<coalition>`` in the output YAML.
    """
    roles: dict[str, Any] = {}
    for radio_num, roles_for_radio in _ROLES_BY_RADIO_NUM.items():
        channels_data = radios_data.get(radio_num, {})
        role_channels: dict[str, Any] = {}
        for ch_num in sorted(channels_data.keys()):
            freq = channels_data[ch_num].get("freq")
            if freq is None:
                continue
            role_channels[f"{ch_num:02d}"] = float(freq)
        if not role_channels:
            continue
        # Each role gets its own dict copy (not the same shared instance) so a
        # future caller mutating one role's channels (e.g. an override merge)
        # cannot silently leak into the other FM role sharing this content.
        for role in roles_for_radio:
            roles[role] = dict(role_channels)
    return roles


def _normalize_channel(value: Any) -> tuple[float, int]:
    """Normalize a v6 channel value (a plain freq or a ``{"freq":, "mod":}`` dict) to ``(freq, mod)``."""
    if isinstance(value, dict):
        return float(value["freq"]), int(value.get("mod", 0))
    return float(value), 0


def _dedicated_matches_packed(
    dedicated_slots: dict[int, dict[int, Any]], packed_preset: PresetDefinition | None
) -> bool:
    """Compare the exact legacy v5 channel map against the packer's projection (ticket 08).

    An aircraft "factors" into the preset plan when the packer, fed the
    mission's shared Channel lists, reproduces *exactly* the same physical
    radios and channels the legacy per-aircraft conversion would have
    emitted — same radio count, same channel count and order per radio, same
    frequency and modulation per channel. Any divergence (a quirk the phase-1
    `Radio layout` primitives don't happen to encode for this exact mission,
    e.g. a maker channel list longer than the airframe's physical slot count)
    means the packed preset is not provably faithful, so the caller must keep
    the legacy per-aircraft override (ADR 0003's "no data loss" prime
    directive: prefer the safe fallback over a guess).

    Args:
        dedicated_slots: This aircraft's exact v5 channel maps, per radio slot
            (from :func:`_resolve_dedicated_channels`).
        packed_preset: The packer's projection for this aircraft/coalition
            (from :func:`presets_manager.pack_preset_for_type`), or ``None``.

    Returns:
        True if every dedicated radio slot has an exact packed counterpart
        (same channels, in order, same frequency/modulation), False otherwise.
    """
    if packed_preset is None:
        return False
    if len(packed_preset.radios) != len(dedicated_slots):
        return False
    for slot_idx, v6_channels in dedicated_slots.items():
        # pack_preset_for_type names each radio "radio_{physical_index + 1}"
        # (a 1-based physical slot index) — the same convention _RadioEntry's
        # v5 ["Radio"][N] slot numbering already uses, so this is a stable key
        # rather than relying on both sequences happening to iterate in the
        # same order.
        packed_radio = packed_preset.radios.get(f"radio_{slot_idx}")
        if packed_radio is None or len(packed_radio.channels) != len(v6_channels):
            return False
        packed_by_number = {channel.number: (channel.freq, channel.mod or 0) for channel in packed_radio.channels}
        for ch_idx, value in v6_channels.items():
            if packed_by_number.get(ch_idx) != _normalize_channel(value):
                return False
    return True


def convert_presets(v5_path: Path, v6_path: Path) -> list[str]:
    """Convert v5 ``radioSettings.lua`` → v6 ``presets.yaml``.

    Generates:

    - ``radios_collection:`` — one UHF/VHF/FM radio per coalition, plus
      optional warbird radio when ``radioPresetsWarbird*`` tables are found.
    - ``presets_collection:`` — one standard preset per coalition (plus warbird).
    - ``presets_assignments:`` — ``all`` → standard preset for planes and
      helicopters of each coalition.

    Per-aircraft and per-pattern assignments are extracted from ``radioSettings``:

    - Exact ``type`` entries and ``typePattern`` regex entries are both written
      as keys in ``presets_assignments`` (the v6 injector supports regex keys).
    - **Standard** layouts (every radio slot is a plain 1:1 image of a standard
      preset table) keep the lightweight shared assignment: UHF-primary via the
      ``all`` fallback, VHF/FM-primary via ``{coalition}_vhf_primary`` /
      ``{coalition}_fm_primary``, warbird via ``{coalition}_warbird``.
    - **Bespoke** layouts (channel rotations, offsets, hardcoded specials,
      active modulations, or extra radios) get a dedicated per-aircraft preset
      that reproduces the exact channel→frequency map plus modulations, making
      the conversion iso-functional with the v5 mission (see ADR 0003).

    **Preset plan (ADR 0010, ticket 08)**: when a coalition has a
    ``radioPresets*`` table, its ``RADIO1_*``/``RADIO2_*``/``RADIO3_*``
    channels are also emitted as a ``channel_lists`` block (``primary_1`` /
    ``primary_2`` / ``fm_substitute``+``fm_supplement``) — the new preset-plan
    format that the phase-1 packer (``presets_injector.presets_manager``)
    projects onto every aircraft's physical radios by default. A bespoke
    aircraft's dedicated preset (above) is only kept when the packer's
    projection, fed this mission's Channel lists, does **not** reproduce its
    exact v5 channel map (mismatched primitive, capacity, or genuinely
    divergent per-aircraft frequencies) — the override then wins over the
    packer (ADR 0010), so both formats coexist in the same file. A mission
    with no ``radioPresets*`` table at all gets no ``channel_lists`` — 100%
    legacy behaviour, unchanged.
    """
    warnings: list[str] = []
    content = v5_path.read_text(encoding="utf-8")
    helicopter_types = _load_helicopter_types()

    radios_collection: dict[str, Any] = {}
    presets_collection: dict[str, Any] = {}
    presets_assignments: dict[str, Any] = {}
    channel_lists_yaml: dict[str, Any] = {}

    for coalition in ("blue", "red"):
        cap = coalition.capitalize()
        table_name = f"radioPresets{cap}"
        radios_data = _parse_preset_table(content, table_name)
        if not radios_data:
            continue

        coalition_channel_lists = _build_channel_lists_for_coalition(radios_data)
        if coalition_channel_lists:
            channel_lists_yaml[coalition] = coalition_channel_lists

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

    # Preset plan (ADR 0010): parse the channel_lists YAML into the packer's
    # internal representation once, used below to check whether each bespoke
    # aircraft's exact v5 channel map is already reproduced by the plan.
    channel_lists, _ = parse_channel_lists(channel_lists_yaml, channel_collections={})

    # Per-aircraft assignments extracted from radioSettings
    token_resolver = _build_token_resolver(content)
    for entry in _parse_radio_settings_entries(content):
        if not entry.radio_sources or entry.coalition not in presets_assignments:
            continue

        # Bespoke radio layouts (rotations, offsets, hardcoded specials, active
        # modulations, extra radios) cannot be expressed by a shared preset —
        # emit a dedicated per-aircraft preset that reproduces the exact map,
        # UNLESS the preset-plan packer already reproduces it exactly (ticket
        # 08), in which case the plan alone covers this aircraft.
        if not _entry_is_standard(entry):
            dedicated_slots, _dropped = _resolve_dedicated_channels(entry, token_resolver)
            packed = pack_preset_for_type(channel_lists, entry.coalition, entry.aircraft)
            if _dedicated_matches_packed(dedicated_slots, packed):
                continue
            warnings.append(
                t(
                    "convert_v5.warn.preset_plan_fallback",
                    aircraft=entry.aircraft,
                    coalition=entry.coalition,
                )
            )
            _emit_dedicated_preset(
                entry,
                token_resolver,
                radios_collection,
                presets_collection,
                presets_assignments,
                helicopter_types,
                warnings,
            )
            continue

        radio1_source = entry.radio_sources.get(1)

        # Aircraft whose radio [1] is UHF are covered by the "all: standard" fallback
        if radio1_source == "uhf":
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
        elif radio1_source == "fm":
            target_preset = f"{entry.coalition}_fm_primary"
            fm_radio_name = f"radio_fm_{entry.coalition}"
            if fm_radio_name not in radios_collection.get(f"{entry.coalition}_radios", {}):
                continue
            if target_preset not in presets_collection.get(f"{entry.coalition}_presets", {}):
                presets_collection.setdefault(f"{entry.coalition}_presets", {})[target_preset] = {
                    "title": f"{entry.coalition.capitalize()} coalition - FM primary",
                    "radios": {"radio_1": fm_radio_name},
                }
        else:
            continue

        for cat in _detect_category(entry.aircraft, entry.is_pattern, helicopter_types):
            presets_assignments[entry.coalition].setdefault(cat, {})[entry.aircraft] = target_preset

    # Emit warbird warnings after processing all entries (so we know which were assigned)
    for coalition in ("blue", "red"):
        warbird_preset_name = f"{coalition}_warbird"
        if warbird_preset_name in presets_collection.get(f"{coalition}_presets", {}):
            warnings.append(t("convert_v5.warn.warbird_preset", preset=warbird_preset_name, coalition=coalition))

    output: dict[str, Any] = {
        "radios_collection": radios_collection,
        "presets_collection": presets_collection,
        "presets_assignments": presets_assignments,
    }
    if channel_lists_yaml:
        output["channel_lists"] = channel_lists_yaml
    _yaml_dump(output, v6_path)
    logger.info(t("v5convert.presets_done", source=v5_path.name, target=v6_path.name))
    warnings.append(t("convert_v5.warn.review_presets", filename=v6_path.name))
    return warnings


# ---------------------------------------------------------------------------
# Aircraft groups
# ---------------------------------------------------------------------------


#: Name of the dynamic-slot-template (C) file, sibling of the spawnables (B) file.
_DYNAMIC_TEMPLATES_FILENAME = "dynamic-slot-templates.yaml"


def convert_aircraft_groups(v5_path: Path, v6_path: Path) -> list[str]:
    """Convert v5 ``spawnableAircrafts/settings.lua`` → **two** v6 YAML files.

    Each aircraft group is sorted (ADR 0002) into one of two families and written
    to its own file:

    - **spawnable aircraft groups** (name prefix ``veafSpawn-``) → *v6_path*
      (``src/spawnables.yaml``);
    - **dynamic-slot templates** (``dynSpawnTemplate == true``, flag wins) →
      the sibling ``src/dynamic-slot-templates.yaml``.

    Groups that are neither are ignored (ordinary mission groups). DCS group data
    (routes, tasks, units, …) is preserved as-is.

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

    # luadata.unserialize returns the inner value, so raw == contents of `settings`.
    # Two real v5 export layouts exist (two veafSpawnableAircraftsEditor generations);
    # both must convert (FIX-CONVERT-SPAWNABLES-FLAT-FORMAT):
    #   - nested: settings.categories.<cat>.coalitions.<coa>.countries.<cty>.groups[<name>]
    #   - flat:   settings.<collection>.{coalition, country, category, groups[<idx>].name}
    # The presence of the `categories` wrapper distinguishes them; both feed one output.
    _CATEGORY_MAP: dict[str, str] = {"plane": "airplanes", "helicopter": "helicopters"}

    def _empty() -> dict[str, Any]:
        return {"airplanes": {"coalitions": {}}, "helicopters": {"coalitions": {}}}

    outputs: dict[str, dict[str, Any]] = {KIND_SPAWNABLE: _empty(), KIND_DYNAMIC_TEMPLATE: _empty()}

    def _route(v6_cat: str, coalition: str, country: str, name: str, group: dict[str, Any]) -> None:
        """Classify *group* and store it (unchanged) in the right output family."""
        group_for_sort = dict(group)
        group_for_sort.setdefault("name", name)
        kind = classify_aircraft_group(group_for_sort)
        if kind is None:
            return
        coalitions_out = outputs[kind][v6_cat]["coalitions"]
        coalitions_out.setdefault(coalition, {}).setdefault(country, {})[name] = group

    if "categories" in raw:
        categories = raw.get("categories") or {}
        for v5_cat, v6_cat in _CATEGORY_MAP.items():
            cat_data = categories.get(v5_cat) or {}
            coalitions_data = cat_data.get("coalitions") or {}
            for coalition, coalition_data in coalitions_data.items():
                if not isinstance(coalition_data, dict):
                    continue
                countries_data = coalition_data.get("countries") or {}
                for country, country_data in countries_data.items():
                    if not isinstance(country_data, dict):
                        continue
                    # The group key is its name.
                    for name, group in (country_data.get("groups") or {}).items():
                        if isinstance(group, dict):
                            _route(v6_cat, str(coalition), str(country), str(name), group)
    else:
        # Flat layout: each top-level entry is a named collection with scalar metadata.
        for collection in raw.values():
            if not isinstance(collection, dict):
                continue
            v6_cat_flat = _CATEGORY_MAP.get(str(collection.get("category", "")).lower())
            if v6_cat_flat is None:
                continue
            coalition = str(collection.get("coalition", ""))
            country = str(collection.get("country", ""))
            groups = collection.get("groups") or {}
            # `groups` is keyed by numeric index; the name lives inside each group.
            group_iter = groups.values() if isinstance(groups, dict) else groups
            for group in group_iter:
                if not isinstance(group, dict):
                    continue
                name = group.get("name")
                if isinstance(name, str) and name:
                    _route(v6_cat_flat, coalition, country, name, group)

    dynamic_path = v6_path.parent / _DYNAMIC_TEMPLATES_FILENAME
    _yaml_dump(outputs[KIND_SPAWNABLE], v6_path)
    _yaml_dump(outputs[KIND_DYNAMIC_TEMPLATE], dynamic_path)
    logger.info(t("v5convert.aircraft_done", source=v5_path.name, target=f"{v6_path.name} + {dynamic_path.name}"))
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
