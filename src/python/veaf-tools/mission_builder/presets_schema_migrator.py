"""Upgrade a `presets.yaml` written against the v5 schema to the v6 one.

`convert-v5` declares ``src/presets.yaml`` as the file it *writes* when generating presets from a
v5 ``settings.lua``. Finding one already there, it left it alone — right for a v6 file, wrong for a
v5 one that shares the name and the file format while its **schema** is the one thing that changed.
The mission then built its ``.miz`` and died on the next step (FIX-CONVERT-V5-PRESETS-SCHEMA).

Detection is by **structure**, never by file name: a name says nothing about content, which is the
whole reason this slipped past.

The full mapping, established by walking a real v5 file (the repository's own demo mission) against
the shipped v6 default rather than from memory:

===============================================  ==================================================
v5                                               v6
===============================================  ==================================================
``presets_definition:``                          ``presets_collection:``
``presets_definition.<preset>``                  ``presets_collection.<collection>.<preset>``
a preset's ``radios.<slot>`` holds the radio     ``radios.<slot>`` holds the **name** of a radio
definition inline                                declared in ``radios_collection``
channel keys ``channel_01``, ``channel_02``      integer keys ``1``, ``2``
a channel's ``name``                             a channel's ``title``
``presets_assignments.coalitions.<side>``        ``presets_assignments.<side>``
===============================================  ==================================================

Almost nothing has to be invented: v6 accepts a channel written as ``{freq, title, mod}``, so the v5
frequencies carry over verbatim and no ``channels_collection`` is needed.

The one exception is a radio's ``type:``, which v6 makes **mandatory** and v5 never wrote. It is
inferred from the frequencies, and a radio whose channels straddle two bands says so instead of
choosing in silence. Worth recording how that was found: reading the code suggested ``type`` was
only consulted to resolve a channel *alias* — which converted channels do not have — so the first
version of this module left it out. The acceptance test at the bottom of the test file, which runs
the migrated demo mission through the real ``PresetsManager``, refused it immediately.
"""

from __future__ import annotations

import re
from typing import Any

#: Name given to the collection level v5 did not have. One collection holds every converted preset:
#: v5 had no grouping to preserve, so inventing several would be inventing information.
CONVERTED_COLLECTION_NAME = "converted_presets"

#: Name given to the collection level of the radios lifted out of the presets.
CONVERTED_RADIOS_COLLECTION_NAME = "converted_radios"

#: ``channel_01`` → ``1``. Anything else is left as it is rather than guessed at.
_CHANNEL_KEY_RE = re.compile(r"^channel[_-]?(\d+)$", re.IGNORECASE)

#: Upper bound (exclusive) of each band, in MHz, in the order they are tested. v6 requires a radio's
#: ``type:`` even when every channel carries an explicit frequency, so one has to be chosen. It is
#: only ever consulted to resolve a channel *alias* against ``channels_collection`` — converted
#: channels have no aliases — so the value cannot change which frequency is injected. It exists to
#: keep the file readable and to satisfy the reader.
_BANDS: tuple[tuple[float, str], ...] = ((108.0, "fm"), (225.0, "vhf"), (float("inf"), "uhf"))


def _band_of(freq: float) -> str:
    """Return the v6 radio ``type`` a frequency belongs to.

    Args:
        freq: A frequency in MHz.

    Returns:
        ``"fm"``, ``"vhf"`` or ``"uhf"``.
    """
    for upper, band in _BANDS:
        if freq < upper:
            return band
    return "uhf"  # pragma: no cover - the last bound is infinite


def _infer_radio_type(channels: Any, warnings: list[str], where: str) -> str:
    """Infer a radio's ``type`` from the frequencies its channels carry.

    Args:
        channels: The radio's channels, already migrated.
        warnings: Collected notes; appended to in place.
        where: Human-readable location, used in warnings.

    Returns:
        The inferred band, defaulting to ``"uhf"`` when nothing can be read.
    """
    freqs: list[float] = []
    if isinstance(channels, dict):
        for value in channels.values():
            freq = (
                value.get("freq") if isinstance(value, dict) else (value if isinstance(value, (int, float)) else None)
            )
            if isinstance(freq, (int, float)):
                freqs.append(float(freq))
    if not freqs:
        warnings.append(f"{where}: no frequency to read, 'type: uhf' assumed — check it")
        return "uhf"
    bands = {_band_of(freq) for freq in freqs}
    if len(bands) == 1:
        return bands.pop()
    # A v5 radio could hold whatever the author typed. Pick the band most of the channels are in and
    # say so, rather than choosing in silence.
    majority = max(bands, key=lambda band: sum(1 for freq in freqs if _band_of(freq) == band))
    warnings.append(
        f"{where}: channels span several bands ({', '.join(sorted(bands))}); 'type: {majority}' chosen — check it"
    )
    return majority


def is_v5_schema(data: Any) -> bool:
    """Whether *data* is a presets document written against the v5 schema.

    Two independent markers, either of which settles it: the v5 section name, and the extra
    ``coalitions`` level under the assignments. A file carrying only one of them (half-converted by
    hand, say) still counts — it cannot be read by v6 as it stands.

    Args:
        data: A parsed presets document.

    Returns:
        ``True`` when the document needs migrating.
    """
    if not isinstance(data, dict):
        return False
    if "presets_definition" in data or "presets_definitions" in data:
        return True
    assignments = data.get("presets_assignments")
    return isinstance(assignments, dict) and "coalitions" in assignments


def _channel_number(key: Any) -> Any:
    """Return the v6 integer channel key for a v5 one, or the key unchanged.

    Args:
        key: A channel key as written in the file.

    Returns:
        The integer channel number when the key is recognisable, else *key* itself.
    """
    if isinstance(key, int):
        return key
    match = _CHANNEL_KEY_RE.match(str(key))
    return int(match.group(1)) if match else key


def _migrate_channels(channels: Any, warnings: list[str], where: str) -> Any:
    """Renumber a radio's channels and rename ``name`` to ``title``.

    Args:
        channels: The v5 ``channels`` block.
        warnings: Collected, mission-maker-facing notes; appended to in place.
        where: Human-readable location, used in warnings.

    Returns:
        The v6 ``channels`` block.
    """
    if not isinstance(channels, dict):
        warnings.append(f"{where}: 'channels' is not a block, left as it is")
        return channels
    migrated: dict[Any, Any] = {}
    for key, value in channels.items():
        number = _channel_number(key)
        if number == key and not isinstance(key, int):
            warnings.append(f"{where}: channel key '{key}' is not a 'channel_NN' name, left as it is")
        if isinstance(value, dict):
            entry = {("title" if k == "name" else k): v for k, v in value.items()}
        else:
            entry = value
        migrated[number] = entry
    return migrated


def migrate(data: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    """Return *data* rewritten against the v6 schema, plus notes worth telling the maker.

    Args:
        data: A parsed v5 presets document.

    Returns:
        A ``(document, warnings)`` pair. The document is a new object; *data* is not modified.
    """
    warnings: list[str] = []
    result: dict[str, Any] = {}

    presets = data.get("presets_definition") or data.get("presets_definitions")
    radios_out: dict[str, Any] = {}
    presets_out: dict[str, Any] = {}

    if isinstance(presets, dict):
        for preset_name, preset in presets.items():
            if not isinstance(preset, dict):
                warnings.append(f"preset '{preset_name}' is not a block, skipped")
                continue
            radios = preset.get("radios")
            radio_refs: dict[Any, Any] = {}
            if isinstance(radios, dict):
                for slot, radio in radios.items():
                    if isinstance(radio, str):
                        # Already a reference; nothing to lift out.
                        radio_refs[slot] = radio
                        continue
                    if not isinstance(radio, dict):
                        warnings.append(f"preset '{preset_name}'.radios.{slot} is neither a name nor a block, skipped")
                        continue
                    # The radio name has to be unique across the whole collection, and a v5 file
                    # names its radios per preset ('radio_1' in every one of them), so the preset
                    # name goes into the key.
                    radio_name = f"{preset_name}_{slot}"
                    where = f"preset '{preset_name}'.radios.{slot}"
                    lifted = {k: v for k, v in radio.items() if k != "channels"}
                    lifted["channels"] = _migrate_channels(radio.get("channels"), warnings, where)
                    if "type" not in lifted:
                        lifted["type"] = _infer_radio_type(lifted["channels"], warnings, where)
                    radios_out[radio_name] = lifted
                    radio_refs[slot] = radio_name
            else:
                warnings.append(f"preset '{preset_name}' has no 'radios' block")
            migrated_preset = {k: v for k, v in preset.items() if k != "radios"}
            migrated_preset["radios"] = radio_refs
            presets_out[preset_name] = migrated_preset
    elif presets is not None:
        warnings.append("'presets_definition' is not a block, skipped")

    # Sections the v5 file already wrote at the v6 name are carried over untouched.
    for key, value in data.items():
        if key in ("presets_definition", "presets_definitions", "presets_assignments"):
            continue
        result[key] = value

    if radios_out:
        existing = result.get("radios_collection")
        result["radios_collection"] = {**(existing or {}), CONVERTED_RADIOS_COLLECTION_NAME: radios_out}
    if presets_out:
        existing = result.get("presets_collection")
        result["presets_collection"] = {**(existing or {}), CONVERTED_COLLECTION_NAME: presets_out}

    assignments = data.get("presets_assignments")
    if isinstance(assignments, dict):
        if "coalitions" in assignments:
            inner = assignments["coalitions"]
            if isinstance(inner, dict):
                others = {k: v for k, v in assignments.items() if k != "coalitions"}
                if others:
                    warnings.append(
                        "presets_assignments held keys beside 'coalitions' "
                        f"({', '.join(sorted(others))}); they were kept alongside the coalitions"
                    )
                result["presets_assignments"] = {**inner, **others}
            else:
                warnings.append("presets_assignments.coalitions is not a block, left as it is")
                result["presets_assignments"] = assignments
        else:
            result["presets_assignments"] = assignments
    elif assignments is not None:
        warnings.append("'presets_assignments' is not a block, left as it is")
        result["presets_assignments"] = assignments

    return result, warnings
