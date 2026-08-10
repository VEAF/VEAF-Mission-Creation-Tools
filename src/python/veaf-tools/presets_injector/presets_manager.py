"""
This module provides classes to manage radio presets.

- ChannelDefinition
  A radio channel definition, composed of information about the channel (name, title etc.) and about the radio (frequencies, modulations)
- Channels collection
  A list of channels that can be used as a source to define a radio
- RadioDefinition
  A set of channels that will end up as a radio in the .miz file
- Radios collection
  A list of radios that can be used to define presets
- PresetDefinition
  A named set of radios defining a preset definition for a specific aircraft or a group of aircrafts
- Preset assignment
  A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
"""

# TODO add modulation

import difflib
import io
import math
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, ClassVar, cast

import yaml
from PIL import Image, ImageColor, ImageDraw, ImageFont
from PIL.ImageFont import FreeTypeFont
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger

from .radio_frequency_validator import FrequencyRange, RadioSpec, get_radios

# ── Radio roles (ADR 0010: per-type radio-preset projection) ────────────────
# A Radio role is the functional slot a Channel list plays across all aircraft,
# independent of physical radio hardware. See CONTEXT.md.
ROLE_PRIMARY_1 = "primary_1"
ROLE_PRIMARY_2 = "primary_2"
ROLE_FM_SUBSTITUTE = "fm_substitute"
ROLE_FM_SUPPLEMENT = "fm_supplement"
ROLE_FM_SECONDARY = "fm_secondary"

# The band each role resolves its channel aliases against (see ChannelDefinition.frequencies).
ROLE_BANDS: dict[str, str] = {
    ROLE_PRIMARY_1: "uhf",
    ROLE_PRIMARY_2: "vhf",
    ROLE_FM_SUBSTITUTE: "fm",
    ROLE_FM_SUPPLEMENT: "fm",
    ROLE_FM_SECONDARY: "fm",
}


class Channel:
    """
    A radio channel data, containing all the information that will be stored in the DCS .miz file
    Can be either created from a RadioDefinition channel (when data is directly set on a radio channel) or read from a ChannelDefinition object in a ChannelCollection (when the RadioDefinition channel references an alias), or both (RadioDefinition channel sets an alias and overrides values for specific attributes)
    """

    def __init__(
        self,
        name_or_number: int | str,
        freq: float,
        title: str | None = None,
        mod: int | None = None,
        priority: int | None = None,
        color: str | None = None,
    ):
        self.freq: float = freq
        self.title: str | None = title
        self.mod: int | None = mod
        # ADR 0012: `priority` is a universal kneeboard-highlight rank (and the
        # AJS-37 layout's shortcut-routing key); `color` groups channels visually
        # on the kneeboard CH cell. Both optional, presentation-facing.
        self.priority: int | None = priority
        self.color: str | None = color

        self.number: int
        if isinstance(name_or_number, str):
            if name_or_number.lower().startswith("channel_"):
                self.number = int(name_or_number.lower().split("channel_")[-1])
            else:
                self.number = int(name_or_number)
        else:
            self.number = name_or_number


class ChannelDefinition:
    """
    A radio channel definition, composed of information about the channel (name, title etc.) and about the radio (frequencies, modulations)
    """

    def __init__(
        self,
        name: str,
        title: str | None = None,
        misc_data: str | None = None,
        collection_name: str | None = None,
        color: str | None = None,
    ):
        self.name: str = name
        self.title: str | None = title
        self.misc_data: str | None = misc_data
        self.collection_name: str | None = collection_name
        self.frequencies: dict[str, float] = {}
        # ADR 0012: a channel may carry an intrinsic `color` (grouping hint) here;
        # `priority` is deliberately NOT read from a channel definition (plan-only).
        self.color: str | None = color

    def add_freq(self, mode: str, freq: float | str):
        if not mode:
            logger.error(message="mode is mandatory", exception_type=ValueError)
        if not freq:
            logger.error(message="freq is mandatory", exception_type=ValueError)
        f_freq = freq if isinstance(freq, float) else float(freq)
        if not f_freq:
            logger.error(message="freq should be a float or a str representation of a float", exception_type=ValueError)
        self.frequencies[mode] = f_freq

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "ChannelDefinition":
        """
        Create a ChannelDefinition instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data

        Returns:
            ChannelDefinition: New instance
        """
        title = data.get("title")
        misc_data = data.get("data")
        color = data.get("color")
        freqs = data.get("freqs")
        if not freqs:
            logger.error(message=f"'freqs' is mandatory for ChannelDefinition {name}", exception_type=ValueError)
            return ChannelDefinition(name=name, title=title, misc_data=misc_data, color=color)
        result = ChannelDefinition(name=name, title=title, misc_data=misc_data, color=color)
        for freq_mode, freq_value in freqs.items():
            if freq_value is not None:  # skip intentionally undefined frequencies
                result.add_freq(mode=freq_mode, freq=freq_value)
        return result


class ChannelCollection:
    """
    A list of channels that can be used as a source to define a radio
    """

    def __init__(self, name: str):
        self.name = name
        self.channel_definitions: dict[str, ChannelDefinition] = {}

    def add_channel_definition(self, channel: ChannelDefinition):
        if not channel:
            logger.error(message="channel is mandatory", exception_type=ValueError)
        if not channel.name:
            logger.error(message="channel has no 'name' attribute", exception_type=ValueError)
        channel.collection_name = self.name
        self.channel_definitions[channel.name] = channel

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "ChannelCollection":
        """
        Create a ChannelCollection instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data

        Returns:
            ChannelCollection: New instance
        """

        result = ChannelCollection(name=name)
        for item_name in data:
            item = ChannelDefinition.from_dict(name=item_name, data=data[item_name])
            result.add_channel_definition(item)
        return result


class RadioDefinition:
    """
    A set of channels that will end up as a radio in the .miz file
    """

    def __init__(self, name: str, radio_type: str | None = None, title: str | None = None):
        self.name: str = name
        self.radio_type: str | None = radio_type
        self.title: str | None = title
        self.channels: list[Channel] = []
        self.collection_name: str | None = None
        # ADR 0012: optional per-slot pilot-facing CH labels for the kneeboard
        # (the AJS-37's Group 100-139 + Sp1/Sp2/Sp3/E/F/G/H); empty for types
        # whose CH column is just the channel number.
        self.display_labels: dict[int, str] = {}

    def add_channel(self, channel: Channel):
        if not channel:
            logger.error(message="channel is mandatory", exception_type=ValueError)
        self.channels.append(channel)

    def to_dict(self) -> dict[str, Any]:
        """
        Convert the radio to a dictionary representation.

        Returns:
            dict: Dictionary representation of the radio
        """

        result: dict[str, Any] = {
            "channelsNames": {(channel.number): channel.title for channel in self.channels}
            if any(channel.title for channel in self.channels)
            else {},
            "channels": {int(channel.number): channel.freq for channel in self.channels},
        }
        # Emit the per-channel modulation table only when at least one channel
        # carries an explicit modulation (AM/FM selection), matching the DCS
        # ``["Radio"][N]["modulations"]`` shape. Channels without an explicit
        # value default to 0 (AM) so the table stays parallel to ``channels``.
        if any(channel.mod is not None for channel in self.channels):
            result["modulations"] = {int(channel.number): int(channel.mod or 0) for channel in self.channels}
        return result

    def get_freq_of_first_channel(self) -> float | None:
        if self.channels:
            if first_channel := next(iter(self.channels)):
                return first_channel.freq
        return None

    def add_channel_from_dict(
        self,
        channel_name: str,
        channel_data: dict[str, Any],
        channel_collections: dict[str, ChannelCollection],
        *,
        strict: bool = True,
    ) -> bool:
        """Resolve and add one channel entry.

        Args:
            strict: When True (default, used by the legacy ``radios_collection``
                format), a channel alias lacking this radio's ``radio_type``
                frequency is a hard authoring error. When False (used by
                _Channel lists_, see ADR 0010), that case is not an error — the
                channel simply does not apply to this role's band and is
                silently skipped; the caller is told via the return value so it
                can record the drop.

        Returns:
            True if a channel was added, False if it was skipped (only possible
            when ``strict`` is False).
        """
        if not channel_data:
            return False
        channel_freq = None
        channel_alias = None
        channel_title = None
        channel_mod: int | None = None
        # ADR 0012: `priority`/`color` are read from the plan entry only. `color`
        # additionally falls back to the channel definition below; `priority`
        # never does (plan-only).
        channel_priority: int | None = None
        channel_color: str | None = None
        if isinstance(channel_data, str):
            # shortcut to only set the channel alias
            channel_alias = channel_data
        elif isinstance(channel_data, float | int):  # shortcut to only set the channel frequency
            channel_freq = channel_data
        else:
            channel_title = channel_data.get("title")
            channel_alias = channel_data.get("channel")
            channel_freq = channel_data.get("freq")
            channel_mod = channel_data.get("mod")
            channel_priority = channel_data.get("priority")
            channel_color = channel_data.get("color")
        channel_definition = None
        if channel_alias:
            for channel_collection in channel_collections.values():
                if channel_alias in channel_collection.channel_definitions:
                    channel_definition = channel_collection.channel_definitions[channel_alias]
                    channel_title = channel_definition.title
                    if channel_color is None:
                        channel_color = channel_definition.color
                    if self.radio_type not in channel_definition.frequencies:
                        if not strict:
                            return False
                        logger.error(
                            message=f"'freq' not defined and 'channel_alias' {channel_alias} in RadioDefinition {self.name} does not contain any frequency of type {self.radio_type}",
                            exception_type=ValueError,
                        )
                    else:
                        channel_freq = channel_definition.frequencies[self.radio_type]
                    break
            else:
                logger.error(
                    message=f"'channel_alias' {channel_alias} in RadioDefinition {self.name} was not found in any ChannelCollection",
                    exception_type=ValueError,
                )
        if channel_freq is None:
            logger.error(message=f"'freq' is mandatory for RadioDefinition {self.name}", exception_type=ValueError)
        self.add_channel(
            Channel(
                name_or_number=channel_name,
                freq=channel_freq,  # type: ignore[arg-type]
                title=channel_title,
                mod=channel_mod,
                priority=channel_priority,
                color=channel_color,
            )
        )
        return True

    @classmethod
    def from_dict(
        cls, name: str, data: dict[str, Any], channel_collections: dict[str, ChannelCollection]
    ) -> "RadioDefinition":
        """
        Create a RadioDefinition instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases

        Returns:
            RadioDefinition: New instance
        """
        title = data.get("title")
        radio_type = data.get("type")
        channels = data.get("channels")
        if not radio_type:
            logger.error(message=f"'type' is mandatory for RadioDefinition {name}", exception_type=ValueError)
        if not channels:
            logger.error(message=f"'channels' is mandatory for RadioDefinition {name}", exception_type=ValueError)
            return RadioDefinition(name=name, radio_type=radio_type, title=title)
        result = RadioDefinition(name=name, radio_type=radio_type, title=title)
        for channel_name, channel_data in channels.items():
            result.add_channel_from_dict(channel_name, channel_data, channel_collections)
        return result


class RadioCollection:
    """
    A list of radios that can be used to define presets
    """

    def __init__(self, name: str):
        self.name = name
        self.radio_definitions: dict[str, RadioDefinition] = {}

    def add_radio_definition(self, radio: RadioDefinition):
        if not radio:
            logger.error(message="radio is mandatory", exception_type=ValueError)
        if not radio.name:
            logger.error(message="radio has no 'name' attribute", exception_type=ValueError)
        radio.collection_name = self.name
        self.radio_definitions[radio.name] = radio

    @classmethod
    def from_dict(
        cls, name: str, data: dict[str, Any], channel_collections: dict[str, ChannelCollection]
    ) -> "RadioCollection":
        """
        Create a RadioDefinition instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases

        Returns:
            RadioDefinition: New instance
        """

        result = RadioCollection(name=name)
        for item_name in data:
            item = RadioDefinition.from_dict(
                name=item_name, data=data[item_name], channel_collections=channel_collections
            )
            result.add_radio_definition(item)
        return result


class PresetDefinition:
    """
    A named set of radios defining a preset definition for a specific aircraft or a group of aircrafts
    """

    EMPTY: ClassVar["PresetDefinition"]

    def __init__(self, name: str, title: str = ""):
        self.name = name
        self.radios: dict[str, RadioDefinition] = {}
        self.used_in_mission: bool = False
        self.collection_name: str | None = None
        self.title = title

    def add_radio(self, radio: RadioDefinition):
        if not radio:
            logger.error(message="radio_alias is mandatory", exception_type=ValueError)
        self.radios[radio.name] = radio

    def to_dict(self) -> dict[int, dict[str, Any]]:
        return {radio_number + 1: radio.to_dict() for radio_number, radio in enumerate(self.radios.values())}

    def get_freq_of_first_channel_of_first_radio(self) -> float | None:
        if self.radios:
            if first_radio := next(iter(self.radios.values())):
                return first_radio.get_freq_of_first_channel()
        return None

    @classmethod
    def from_dict(
        cls, name: str, data: dict[str, Any], radio_collections: dict[str, RadioCollection]
    ) -> "PresetDefinition":
        """
        Create a PresetDefinition instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data
            radio_collections: used to resolve the radio aliases

        Returns:
            PresetDefinition: New instance
        """
        radios = data.get("radios")
        if not radios:
            logger.error(message=t("presets.schema.radios_mandatory", name=name), exception_type=ValueError)
            return PresetDefinition(name=name)
        radios = _require_block(radios, f"preset '{name}'.radios", t("presets.schema.expected.radios"))
        result = PresetDefinition(name=name, title=data.get("title") or "")
        for radio_name, radio_alias in radios.items():
            if not isinstance(radio_alias, str):
                # The v5 layout defined each radio inline, right here. v6 names a radio declared in
                # `radios_collection` instead, so what arrives is a whole block rather than a name.
                logger.error(
                    message=t(
                        "presets.schema.radio_inline",
                        name=name,
                        slot=radio_name,
                        found=_describe(radio_alias),
                    ),
                    exception_type=ValueError,
                )
                # Same idiom as the _require_* helpers: state that nothing continues past here. A
                # `continue` would be worse than the raise — it would skip the radio in silence,
                # which is the failure mode this whole change exists to remove.
                raise AssertionError("unreachable")  # pragma: no cover - logger.error always raises
            for radio_collection in radio_collections.values():
                if radio_alias in radio_collection.radio_definitions:
                    radio_definition = radio_collection.radio_definitions[radio_alias]
                    break
            else:
                known = sorted(
                    alias
                    for radio_collection in radio_collections.values()
                    for alias in radio_collection.radio_definitions
                )
                matches = difflib.get_close_matches(str(radio_alias), known, n=1, cutoff=0.6)
                logger.error(
                    message=t(
                        "presets.schema.radio_unknown",
                        name=name,
                        slot=radio_name,
                        alias=radio_alias,
                        near=t("presets.schema.radio_unknown.near", near=matches[0]) if matches else "",
                        known=(
                            t("presets.schema.radio_unknown.known", known=", ".join(known))
                            if known
                            else t("presets.schema.radio_unknown.none")
                        ),
                    ),
                    exception_type=ValueError,
                )
                # `radio_definition` is unbound on this branch: the loop never matched. Saying so
                # explicitly is the point — the original code fell through to add_radio() here.
                raise AssertionError("unreachable")  # pragma: no cover - logger.error always raises
            result.add_radio(radio_definition)
        return result


PresetDefinition.EMPTY = PresetDefinition("empty")


class PresetCollection:
    """
    A list of presets that can be used to define presets
    """

    def __init__(self, name: str):
        self.name = name
        self.preset_definitions: dict[str, PresetDefinition] = {}

    def add_preset_definition(self, preset: PresetDefinition):
        if not preset:
            logger.error(message="preset is mandatory", exception_type=ValueError)
        if not preset.name:
            logger.error(message="preset has no 'name' attribute", exception_type=ValueError)
        preset.collection_name = self.name
        self.preset_definitions[preset.name] = preset

    @classmethod
    def from_dict(
        cls, name: str, data: dict[str, Any], radio_collections: dict[str, RadioCollection]
    ) -> "PresetCollection":
        """
        Create a PresetDefinition instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data
            radio_collections: used to resolve the radio aliases

        Returns:
            PresetDefinition: New instance
        """

        result = PresetCollection(name=name)
        _require_block(data, f"presets_collection.{name}", "a block of named presets")
        for item_name in data:
            _require_preset_body(data[item_name], f"presets_collection.{name}.{item_name}")
            item = PresetDefinition.from_dict(name=item_name, data=data[item_name], radio_collections=radio_collections)
            result.add_preset_definition(item)
        return result


@dataclass
class PresetAssignment:
    """
    A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
    """

    preset_definition: PresetDefinition | None
    coalition: str = "all"
    aircraft_type: str = "all"
    unit_type: str = "all"


#: Every section `PresetsManager.read_yaml` knows how to read. Anything else in a presets file is
#: reported rather than dropped (FIX-CONVERT-V5-PRESETS-SCHEMA ticket 01): silently ignoring a key
#: does not just lose data, it misdirects the diagnosis — a `presets_definition` block skipped
#: without a word surfaced one step later as "preset … not found in any PresetCollection", an error
#: accusing the assignments, which were correct.
PRESETS_SECTIONS: tuple[str, ...] = (
    "channels_collection",
    "radios_collection",
    "presets_collection",
    "presets_assignments",
    "channel_lists",
)

#: v5 section name -> its v6 equivalent. Used to turn "unknown section" into "this is the v5 name".
_V5_SECTION_RENAMES: dict[str, str] = {
    "presets_definition": "presets_collection",
    "presets_definitions": "presets_collection",
}


def _describe(value: Any) -> str:
    """Describe a YAML value the way a mission maker would read it, not as a Python type.

    Args:
        value: Any value parsed out of the presets file.

    Returns:
        A short phrase such as ``a list of 2 items`` or ``a block containing: blue, red``.
    """
    if value is None:
        return t("presets.schema.found.nothing")
    if isinstance(value, dict):
        keys = ", ".join(str(k) for k in list(value)[:4])
        more = ", …" if len(value) > 4 else ""
        return t("presets.schema.found.block", keys=f"{keys}{more}") if keys else t("presets.schema.found.empty_block")
    if isinstance(value, (list, tuple)):
        return tn("presets.schema.found.list", len(value))
    if isinstance(value, bool):
        return t("presets.schema.found.bool", value=str(value).lower())
    if isinstance(value, (int, float)):
        return t("presets.schema.found.number", value=value)
    return t("presets.schema.found.text", value=value)


def _require_block(value: Any, path: str, expected: str) -> dict:
    """Return *value* as a mapping, or raise a message naming the key, what was found and what fits.

    Args:
        value: The value found at *path*.
        path: Dotted key path inside the presets file, e.g. ``presets_assignments.blue``.
        expected: What the loader needs there, in plain words.

    Returns:
        The value, when it is a mapping.

    Raises:
        ValueError: Always, when it is not — via ``logger.error``, so the message reaches the user.
    """
    if isinstance(value, dict):
        return value
    logger.error(
        message=t("presets.schema.expected", path=path, expected=expected, found=_describe(value)),
        exception_type=ValueError,
    )
    raise AssertionError("unreachable")  # pragma: no cover - logger.error always raises


def _require_preset_name(value: Any, path: str) -> str:
    """Return *value* as a preset name, or raise a message a mission maker can act on.

    Args:
        value: The value found at *path*.
        path: Dotted key path inside the presets file.

    Returns:
        The preset name.

    Raises:
        ValueError: Always, when *value* is not text — via ``logger.error``.
    """
    if isinstance(value, str):
        return value
    # A block here is the commonest cause by far: the file still has the v5 nesting, so what should
    # be a preset name is another level of the tree.
    hint = t("presets.schema.preset_name.hint") if isinstance(value, dict) else ""
    logger.error(
        message=t("presets.schema.preset_name", path=path, found=_describe(value), hint=hint),
        exception_type=ValueError,
    )
    raise AssertionError("unreachable")  # pragma: no cover - logger.error always raises


def _require_preset_body(value: Any, path: str) -> dict:
    """Return *value* as a preset definition, or diagnose the v5 layout it usually is.

    `presets_collection` has **two** levels in v6 — a named collection, then the presets in it —
    where v5's `presets_definition` had one. A v5 file therefore presents a preset's own `title`
    and `radios` keys where the loader expects preset names, and the first of them is a plain
    string. That used to surface as ``'str' object has no attribute 'get'``.

    Args:
        value: The value found at *path*.
        path: Dotted key path inside the presets file.

    Returns:
        The preset definition block.

    Raises:
        ValueError: Always, when *value* is not a block — via ``logger.error``.
    """
    if isinstance(value, dict):
        return value
    logger.error(
        message=t("presets.schema.v5_preset_levels", path=path, found=_describe(value)),
        exception_type=ValueError,
    )
    raise AssertionError("unreachable")  # pragma: no cover - logger.error always raises


class PresetAssignmentCollection:
    """
    A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
    """

    def __init__(self):
        self.preset_assignments_dict: dict[str, dict[str, dict[str, PresetAssignment]]] = {}

    @classmethod
    def from_dict(
        cls, data: dict[str, Any], presets_collections: dict[str, PresetCollection]
    ) -> "PresetAssignmentCollection":
        """
        Create a PresetAssignmentCollection instance from a dictionary.

        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases

        Returns:
            PresetAssignmentCollection: New instance
        """

        result = PresetAssignmentCollection()
        _require_block(data, "presets_assignments", t("presets.schema.expected.assignments"))
        if "coalitions" in data:
            # The v5 layout, and by far the likeliest reason this walk would go wrong. Diagnose it
            # by name instead of failing one level deeper on a value that is "not a preset name".
            logger.error(message=t("presets.schema.v5_coalitions"), exception_type=ValueError)
        for coalition, coalition_data in data.items():
            coalition_data = _require_block(
                coalition_data,
                f"presets_assignments.{coalition}",
                t("presets.schema.expected.coalition"),
            )
            for aircraft_type, type_data in coalition_data.items():
                type_data = _require_block(
                    type_data,
                    f"presets_assignments.{coalition}.{aircraft_type}",
                    t("presets.schema.expected.category"),
                )
                for unit_type, preset_definition_name in type_data.items():
                    preset_definition_name = _require_preset_name(
                        preset_definition_name,
                        f"presets_assignments.{coalition}.{aircraft_type}.{unit_type}",
                    )
                    if preset_definition_name.lower() == "none":
                        preset_definition = None
                    elif preset_definition_name.lower() == "empty":
                        preset_definition = PresetDefinition.EMPTY
                    else:
                        for preset_collection in presets_collections.values():
                            if preset_definition_name in preset_collection.preset_definitions:
                                preset_definition = preset_collection.preset_definitions[preset_definition_name]
                                break
                        else:
                            logger.error(
                                message=f"preset name {preset_definition_name} in PresetAssignmentCollection was not found in any PresetCollection",
                                exception_type=ValueError,
                            )
                    preset_assignment = PresetAssignment(
                        coalition=coalition,
                        aircraft_type=aircraft_type,
                        unit_type=unit_type,
                        preset_definition=preset_definition,
                    )
                    if not result.preset_assignments_dict.get(coalition, {}):
                        result.preset_assignments_dict[coalition] = {}
                    preset_assignments_coalition_dict = result.preset_assignments_dict.get(coalition, {})
                    if not preset_assignments_coalition_dict.get(aircraft_type, {}):
                        preset_assignments_coalition_dict[aircraft_type] = {}
                    preset_assignments_aircraft_type_dict = preset_assignments_coalition_dict.get(aircraft_type, {})
                    preset_assignments_aircraft_type_dict[unit_type] = preset_assignment
        return result

    @staticmethod
    def _match_unit_type(d: dict[str, "PresetAssignment"], unit_type: str) -> "PresetAssignment | None":
        """Look up *unit_type* in *d* with exact-match priority, then regex pattern fallback.

        Args:
            d: Mapping of unit_type key → PresetAssignment (may contain regex patterns).
            unit_type: DCS aircraft type string to look up.

        Returns:
            The matching :class:`PresetAssignment`, or ``None`` if no key matches.
            The ``"all"`` wildcard key is intentionally excluded — callers handle it separately.
        """
        if unit_type in d:
            return d[unit_type]
        for key, assignment in d.items():
            if key == "all":
                continue
            try:
                if re.fullmatch(key, unit_type):
                    return assignment
            except re.error:
                pass
        return None

    def get_preset_for(
        self, coalition: str = "all", aircraft_type: str = "all", unit_type: str = "all"
    ) -> PresetAssignment | None:
        def _unit(d: dict[str, "PresetAssignment"]) -> "PresetAssignment | None":
            return self._match_unit_type(d, unit_type) or d.get("all")

        return (
            _unit(self.preset_assignments_dict.get(coalition, {}).get(aircraft_type, {}))
            or _unit(self.preset_assignments_dict.get(coalition, {}).get("all", {}))
            or _unit(self.preset_assignments_dict.get("all", {}).get(aircraft_type, {}))
            or _unit(self.preset_assignments_dict.get("all", {}).get("all", {}))
        )


def parse_channel_lists(
    data: dict[str, Any], channel_collections: dict[str, ChannelCollection]
) -> tuple[dict[str, dict[str, RadioDefinition]], dict[str, dict[str, list[str]]]]:
    """Parse the ``channel_lists`` block of ``presets.yaml`` (ADR 0010).

    Each channel list is represented as a :class:`RadioDefinition` (same shape as
    a legacy radio: an ordered list of channels resolved against a single band),
    with ``radio_type`` set to the role's band so alias resolution reuses
    ``RadioDefinition.add_channel_from_dict`` unchanged.

    Args:
        data: The ``channel_lists`` mapping: coalition -> role -> channels.
        channel_collections: Used to resolve channel aliases.

    Returns:
        A tuple of (channel_lists, dropped): ``channel_lists`` maps
        coalition -> role -> RadioDefinition; ``dropped`` maps
        coalition -> role -> list of channel names skipped because they had no
        frequency for that role's band (e.g. a UHF-only channel listed under
        ``primary_2``).
    """
    channel_lists: dict[str, dict[str, RadioDefinition]] = {}
    dropped: dict[str, dict[str, list[str]]] = {}
    for coalition, roles_data in data.items():
        role_lists: dict[str, RadioDefinition] = {}
        role_dropped: dict[str, list[str]] = {}
        for role, channels_data in (roles_data or {}).items():
            if role not in ROLE_BANDS:
                logger.error(
                    message=f"Unknown radio role '{role}' in channel_lists.{coalition} (expected one of {sorted(ROLE_BANDS)})",
                    exception_type=ValueError,
                )
                continue
            radio, skipped = _build_role_list(coalition, role, channels_data, channel_collections)
            role_lists[role] = radio
            if skipped:
                role_dropped[role] = skipped
        channel_lists[coalition] = role_lists
        if role_dropped:
            dropped[coalition] = role_dropped
    return channel_lists, dropped


def _build_role_list(
    coalition: str, role: str, channels_data: dict[str, Any] | None, channel_collections: dict[str, ChannelCollection]
) -> tuple[RadioDefinition, list[str]]:
    """Resolve one role's channels into a RadioDefinition, tracking dropped ones.

    Args:
        coalition: "blue" or "red" (only used to name the resulting RadioDefinition).
        role: One of the ``ROLE_BANDS`` keys.
        channels_data: The role's channel mapping from ``channel_lists.yaml``.
        channel_collections: Used to resolve channel aliases.

    Returns:
        The role's RadioDefinition, and the list of channel names skipped
        because they lacked a frequency for the role's band.
    """
    band = ROLE_BANDS[role]
    radio = RadioDefinition(name=f"channel_list_{coalition}_{role}", radio_type=band, title=role)
    skipped: list[str] = []
    for channel_name, channel_data in (channels_data or {}).items():
        if not radio.add_channel_from_dict(channel_name, channel_data, channel_collections, strict=False):
            skipped.append(str(channel_name))
    return radio, skipped


# Per-radio classification thresholds (MHz). Deliberately coarse: many modern
# radios (ARC-210, R-863…) report the union of every mode they support at once
# (verified against the real dcs-radio-specs.yaml — only 19 of 87 aircraft have
# radios that are cleanly single-band throughout), so an exact uhf/vhf boundary
# cannot be derived reliably for every aircraft. These thresholds only need to
# separate FM-capable radios from V/UHF-capable ones, and, among V/UHF-capable
# radios, tell apart one dedicated to a single sub-band from one whose data is
# genuinely ambiguous (handled by falling back to physical position below).
_FM_CEILING_MHZ = 95.0
_UHF_FLOOR_MHZ = 195.0

#: Below this, a "radio" is not a communication set at all — it is a radio-compass (ADF) or an
#: HF beacon receiver. 2 MHz separates them cleanly from the 20 MHz bottom of any FM comm radio,
#: so the threshold needs no per-type tuning. Without it, an ARK-19 or ARK-22 attracted the FM
#: role and had a 30-channel list projected onto it: every channel then reported out of range and
#: dropped, while the kneeboard advertised a radio the aircraft does not have.
#: `FIX-DYNSLOT-RADIO-UNITS` reasons about the same hazard from the other end — a primary
#: frequency below the VHF floor makes DCS refuse to save the mission.
_COMM_FLOOR_MHZ = 2.0


def _classify_radio(ranges: list[FrequencyRange]) -> str | None:
    """Classify one physical radio's role band from its frequency ranges.

    Returns "uhf" or "vhf" when the radio is unambiguously dedicated to that
    sub-band, "ambiguous" when its ranges reach into both (common on digital
    combo radios like the ARC-210, or on single-range radios spanning both
    windows like the Mi-8MT's R-863 or a warbird's FuG16 — the packer falls back
    to physical position for the former, and this range naturally resolves to a
    single band for the latter two), "non_comm" when every range sits below the
    comm floor (a radio-compass or HF beacon receiver, which must get no role at
    all), or None when the radio is a genuine FM set.
    """
    if ranges and all(r.max_mhz < _COMM_FLOOR_MHZ for r in ranges):
        return "non_comm"
    has_uhf = any(r.max_mhz >= _UHF_FLOOR_MHZ for r in ranges)
    has_vhf = any(r.min_mhz < _UHF_FLOOR_MHZ and r.max_mhz > _FM_CEILING_MHZ for r in ranges)
    if has_uhf and has_vhf:
        return "ambiguous"
    if has_uhf:
        return "uhf"
    if has_vhf:
        return "vhf"
    return None


def _assign_roles_by_position(radios: list[RadioSpec]) -> dict[int, str]:
    """Assign a Radio role to each physical radio index, ADR 0010's default projection.

    Radios unambiguously dedicated to one sub-band claim that role directly —
    this is what lets a deliberately "inverted" aircraft (e.g. the A-10, whose
    physical radio 1 is VHF and radio 2 is UHF) resolve correctly without an
    explicit per-type override. Radios whose data is genuinely ambiguous fill
    whichever primary slot remains, in physical order — the shipped default's
    own ``radio_1``/``radio_2`` convention for aircraft where hardware data alone
    cannot tell UHF and VHF apart (e.g. the FA-18C's two identical ARC-210s).
    Any radio that never reaches above the FM ceiling gets the FM role
    (``fm_supplement`` if two primaries were found, else ``fm_substitute``); a
    second such radio (e.g. the OH-58D's two FM sets) gets ``fm_secondary``.
    """
    bands = [_classify_radio(radio.ranges) for radio in radios]
    uhf_indices = [index for index, band in enumerate(bands) if band == "uhf"]
    vhf_indices = [index for index, band in enumerate(bands) if band == "vhf"]
    ambiguous_indices = [index for index, band in enumerate(bands) if band == "ambiguous"]
    fm_indices = [index for index, band in enumerate(bands) if band is None]

    role_by_index: dict[int, str] = {}

    # Radios unambiguously dedicated to one sub-band claim that role directly.
    if uhf_indices:
        role_by_index[uhf_indices[0]] = ROLE_PRIMARY_1
    if vhf_indices:
        role_by_index[vhf_indices[0]] = ROLE_PRIMARY_2

    # Ambiguous combo radios fill whichever primary slot remains, in physical order.
    for index in ambiguous_indices:
        if ROLE_PRIMARY_1 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_1
        elif ROLE_PRIMARY_2 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_2

    if fm_indices:
        fm_role = ROLE_FM_SUPPLEMENT if len(role_by_index) >= 2 else ROLE_FM_SUBSTITUTE
        role_by_index[fm_indices[0]] = fm_role
        if len(fm_indices) >= 2:
            role_by_index[fm_indices[1]] = ROLE_FM_SECONDARY

    return role_by_index


# ── Radio layout (ADR 0010: hand-maintained per-type override) ──────────────
# See data/dcs-radio-layouts.yaml's header comment for the full schema
# description. Kept separate from the auto-generated dcs-radio-specs.yaml.


@dataclass(frozen=True)
class HardcodedChannel:
    """One entry of the ``trailing_specials`` primitive (ADR 0010/0012).

    A special slot is either **airframe-constant** (``freq`` set, e.g. the
    AJS-37's FR24 E/F/G emergency channels) or **plan-sourced** (``priority``
    set: its frequency comes from the preset plan's channel tagged with that
    priority — ADR 0012, the AJS-37's FR22 Special 1/2/3 + FR24 H). Exactly one
    of ``freq`` / ``priority`` is expected.

    Attributes:
        freq: The fixed frequency in MHz (airframe constant), or None when the
            slot is plan-sourced via ``priority``.
        mod: Optional modulation (0=AM, 1=FM), same convention as ``Channel.mod``.
        priority: The plan priority whose channel fills this slot (ADR 0012), or
            None for an airframe constant. Plan-sourced specials are always AM.
        label: The pilot-facing name of this special slot (e.g. "Sp1", "H"),
            shown on the kneeboard CH column (consumed by the kneeboard renderer).
    """

    freq: float | None = None
    mod: int | None = None
    priority: int | None = None
    label: str | None = None


@dataclass(frozen=True)
class KeyedGroups:
    """Key-based multi-role mapping into one physical radio's Group block (ADR 0012).

    Several Radio roles share ONE physical radio, each channel placed at a DCS
    slot derived from its **declared key** (not renumbered): for a role with
    Group base ``B`` and a channel of key ``K``, its DCS Group is ``B + K`` and
    its slot is ``((B + K - min_group) mod block_size) + 1`` (``min_group`` being
    the lowest base). This reproduces the AJS-37's "channel N = Group 10N" pilot
    convention, including the wrap that recycles the otherwise-unused first slot
    (Group 100) for ``primary_2``'s 20th channel. Gaps in the keys are preserved;
    a key beyond its role's share of the block is dropped with a warning.

    Attributes:
        block_size: The number of data slots the block holds (the AJS-37's 40:
            Groups 100–139 → DCS slots 1–40).
        bases: Each role's first Group number, in placement order.
    """

    block_size: int
    bases: dict[str, int]


@dataclass(frozen=True)
class RadioLayoutRadio:
    """One physical radio's entry in a type's Radio layout.

    Attributes:
        role: The Radio role this physical radio carries (one of ROLE_BANDS).
            When ``keyed_groups`` is set, ``role`` still names the resulting
            radio's ``radio_type``/title (see :func:`_content_for_radio`).
        rotate_last_to_head: Channel-0 rotation primitive (ADR 0010): when True,
            the channel list's last entry is moved to the head (DCS channel slot
            1, the aircraft's "channel 0"), and the rest of the list follows in
            order into the remaining slots.
        keyed_groups: Key-based multi-role mapping (ADR 0012): when set, several
            Radio roles share this ONE physical radio, each channel placed at a
            DCS slot derived from its declared key (the AJS-37's Group 100–139
            block). Replaces the single-role lookup entirely for this radio.
        trailing_specials: Trailing specials primitive (ADR 0010/0012): a
            declared, ordered list of special slots appended after the radio's
            other content — each either an airframe constant (``freq``) or
            plan-sourced (``priority``), e.g. the AJS-37's FR22/FR24 specials.
            Overridable by the maker via the existing ``presets_assignments``
            bespoke-preset mechanism, checked before the packer runs at all.
        reserved_head_slots: Reserved head slot(s) primitive (ADR 0010): each
            entry is a 1-based index into the channel list that fills one
            leading DCS channel slot, in the declared order (e.g. ``[20]`` for a
            single "M" (manual) slot fed by the list's last entry, or ``[1, 20]``
            for the OH-58D FM radios' "C" then "M" slots). The rest of the list
            follows in its original order into the remaining slots. Mutually
            exclusive with ``rotate_last_to_head`` on the same radio.
        capacity: Slot capacity primitive (ADR 0010): the maximum number of
            channel slots this radio physically holds. When the radio's final
            composed channel count (after every other primitive has run,
            including ``trailing_specials``) exceeds ``capacity``, the excess is
            truncated from the END of the list (e.g. the AJS-37's 47-slot radio
            is already an exact fit; Tripack itself truncated its VHF list to
            fit 47 slots — see the exploration doc §7/§8.4). ``None`` (the
            default) means unbounded.
    """

    role: str
    rotate_last_to_head: bool = False
    keyed_groups: KeyedGroups | None = None
    trailing_specials: list[HardcodedChannel] | None = None
    reserved_head_slots: list[int] = field(default_factory=list)
    capacity: int | None = None


@dataclass(frozen=True)
class RadioLayoutEntry:
    """A type's full Radio layout: physical radio index (1-based) -> RadioLayoutRadio."""

    radios: dict[int, RadioLayoutRadio]


def parse_radio_layouts(data: dict[str, Any]) -> dict[str, RadioLayoutEntry]:
    """Parse the ``dcs-radio-layouts.yaml`` mapping into RadioLayoutEntry objects.

    Args:
        data: The parsed YAML mapping: unit_type (exact string or regex) -> {"radios": {index: {...}}}.

    Returns:
        Mapping of unit_type key -> RadioLayoutEntry, in the same key order as *data*
        (used for exact-then-regex resolution by :func:`get_radio_layout`).
    """
    layouts: dict[str, RadioLayoutEntry] = {}
    for unit_type_key, entry_data in data.items():
        radios_data = (entry_data or {}).get("radios") or {}
        radios: dict[int, RadioLayoutRadio] = {}
        for index, radio_data in radios_data.items():
            role = (radio_data or {}).get("role")
            if not role:
                logger.error(
                    message=f"'role' is mandatory for radio {index} in radio layout '{unit_type_key}'",
                    exception_type=ValueError,
                )
                continue
            if role not in ROLE_BANDS:
                logger.error(
                    message=f"Unknown radio role '{role}' for radio {index} in radio layout "
                    f"'{unit_type_key}' (expected one of {sorted(ROLE_BANDS)})",
                    exception_type=ValueError,
                )
                continue
            rotate_last_to_head = bool(radio_data.get("rotate_last_to_head", False))
            reserved_head_slots = _parse_reserved_head_slots(
                radio_data.get("reserved_head_slots"), index, unit_type_key
            )
            if rotate_last_to_head and reserved_head_slots:
                logger.error(
                    message=f"radio {index} in radio layout '{unit_type_key}' declares both "
                    "'rotate_last_to_head' and 'reserved_head_slots' — these primitives are mutually exclusive",
                    exception_type=ValueError,
                )
                continue
            radios[int(index)] = RadioLayoutRadio(
                role=role,
                rotate_last_to_head=rotate_last_to_head,
                keyed_groups=_parse_keyed_groups(radio_data.get("keyed_groups")),
                trailing_specials=_parse_hardcoded_channels(radio_data.get("trailing_specials")),
                reserved_head_slots=reserved_head_slots,
                capacity=_parse_capacity(radio_data.get("capacity"), index, unit_type_key),
            )
        layouts[unit_type_key] = RadioLayoutEntry(radios=radios)
    return layouts


def _parse_keyed_groups(data: dict[str, Any] | None) -> KeyedGroups | None:
    """Parse the ``keyed_groups`` mapping into a :class:`KeyedGroups`, or None (ADR 0012)."""
    if data is None:
        return None
    return KeyedGroups(
        block_size=int(data["block_size"]),
        bases={role: int(base) for role, base in (data.get("bases") or {}).items()},
    )


def _parse_hardcoded_channels(data: list[dict[str, Any]] | None) -> list[HardcodedChannel] | None:
    """Parse the ``trailing_specials`` list into HardcodedChannel objects, or None (ADR 0010/0012).

    Each entry must be **exactly one of** an airframe constant (``{freq, mod}``)
    or plan-sourced (``{priority}``); an optional ``label`` names the slot for the
    kneeboard. An entry with neither is a layout authoring error — logged and
    skipped rather than silently producing a frequency-less channel. An entry with
    both keeps ``priority`` (which wins at pack time) and warns.
    """
    if data is None:
        return None
    specials: list[HardcodedChannel] = []
    for item in data:
        if item is None:
            continue
        freq = item.get("freq")
        priority = item.get("priority")
        if (freq is None) == (priority is None):  # neither, or both
            logger.warning(t("presets_injector.radio_layout.invalid_special", special=str(item)))
            if freq is None and priority is None:
                continue
            freq = None  # both set → plan-sourced priority wins
        specials.append(
            HardcodedChannel(
                freq=float(freq) if freq is not None else None,
                mod=item.get("mod"),
                priority=priority,
                label=item.get("label"),
            )
        )
    return specials


def _parse_reserved_head_slots(data: list[Any] | None, radio_index: int | str, unit_type_key: str) -> list[int]:
    """Parse the ``reserved_head_slots`` list, skipping non-integer entries with a warning.

    A single malformed entry (e.g. a non-numeric string in the YAML) must not
    abort parsing the whole layout file — it is logged and skipped instead,
    same authoring-error-tolerance level as the out-of-range-index handling in
    :func:`_prepend_reserved_slots`.
    """
    result: list[int] = []
    for slot in data or []:
        try:
            result.append(int(slot))
        except (TypeError, ValueError):
            logger.warning(
                t(
                    "presets_injector.radio_layout.invalid_reserved_head_slot",
                    radio_index=radio_index,
                    unit_type_key=unit_type_key,
                    slot=slot,
                )
            )
    return result


def _parse_capacity(data: Any, radio_index: int | str, unit_type_key: str) -> int | None:
    """Parse the ``capacity`` value, ignoring a non-integer or non-positive value with a warning.

    Same authoring-error-tolerance level as :func:`_parse_reserved_head_slots`:
    a malformed ``capacity`` (e.g. a non-numeric string, or a zero/negative
    value that could never hold any channel) must not abort parsing the whole
    layout file — it is logged and treated as "no capacity limit" instead.
    """
    if data is None:
        return None
    try:
        capacity = int(data)
    except (TypeError, ValueError):
        logger.warning(
            t(
                "presets_injector.radio_layout.invalid_capacity",
                radio_index=radio_index,
                unit_type_key=unit_type_key,
                capacity=data,
            )
        )
        return None
    if capacity <= 0:
        logger.warning(
            t(
                "presets_injector.radio_layout.invalid_capacity",
                radio_index=radio_index,
                unit_type_key=unit_type_key,
                capacity=data,
            )
        )
        return None
    return capacity


_RADIO_LAYOUTS: dict[str, RadioLayoutEntry] | None = None


def _load_radio_layouts() -> dict[str, RadioLayoutEntry]:
    """Load and cache the bundled ``dcs-radio-layouts.yaml``."""
    global _RADIO_LAYOUTS
    if _RADIO_LAYOUTS is None:
        raw = read_bundled_text("presets_injector", "data", "dcs-radio-layouts.yaml")
        _RADIO_LAYOUTS = parse_radio_layouts(yaml.safe_load(raw) or {})
    return _RADIO_LAYOUTS


def get_radio_layout(layouts: dict[str, RadioLayoutEntry], unit_type: str) -> RadioLayoutEntry | None:
    """Resolve *unit_type* to its Radio layout entry: exact match, then regex fallback.

    Mirrors ``PresetAssignmentCollection._match_unit_type``'s resolution order.

    Args:
        layouts: Mapping of unit_type key (exact or regex) -> RadioLayoutEntry.
        unit_type: DCS aircraft type string to look up.

    Returns:
        The matching RadioLayoutEntry, or None if no key matches.
    """
    if unit_type in layouts:
        return layouts[unit_type]
    for key, entry in layouts.items():
        try:
            if re.fullmatch(key, unit_type):
                return entry
        except re.error as exc:
            logger.warning(t("presets_injector.radio_layout.invalid_regex_key", regex_key=key, error=str(exc)))
    return None


def _check_layout_radio_count(unit_type: str, layout: RadioLayoutEntry, radios: list[RadioSpec]) -> None:
    """Warn when the layout's declared radio indices disagree with the specs' actual count.

    A DCS patch changing an aircraft's radio count would silently desync a hand
    -maintained layout from the specs; this surfaces the drift instead (ADR 0010).

    Args:
        unit_type: DCS unit type string (for the warning message).
        layout: The type's parsed Radio layout entry.
        radios: The type's physical radios, from ``get_radios(unit_type)``.
    """
    declared_count = max(layout.radios) if layout.radios else 0
    if declared_count != len(radios):
        logger.warning(
            t(
                "presets_injector.radio_layout.count_mismatch",
                unit_type=unit_type,
                declared_count=declared_count,
                actual_count=len(radios),
            )
        )


def _role_by_index_from_layout(layout: RadioLayoutEntry) -> dict[int, str]:
    """Convert a RadioLayoutEntry's 1-based radio indices into a 0-based role_by_index mapping."""
    return {index - 1: radio.role for index, radio in layout.radios.items()}


def _rotate_last_to_head(source: RadioDefinition) -> RadioDefinition:
    """Return a copy of *source* with its channels renumbered by the channel-0 rotation primitive.

    The channel list's last entry moves to slot 1 (the aircraft's "channel 0"),
    then the rest of the list follows in order into slots 2..N (ADR 0010).

    Args:
        source: The role's channel list (channels in list order, not necessarily
            already numbered 1..N).

    Returns:
        A new RadioDefinition with the same radio_type/title, channels renumbered.
    """
    rotated = RadioDefinition(name=source.name, radio_type=source.radio_type, title=source.title)
    ordered = [*source.channels[-1:], *source.channels[:-1]]
    for slot, channel in enumerate(ordered, start=1):
        rotated.add_channel(_clone_channel(channel, slot))
    return rotated


def _prepend_reserved_slots(source: RadioDefinition, reserved_head_slots: list[int]) -> RadioDefinition:
    """Return a copy of *source* with reserved head slot(s) prepended (ADR 0010).

    Each entry in *reserved_head_slots* is a 1-based index into *source*'s
    channel list; it fills one leading DCS channel slot, in the declared order
    (e.g. ``[20]`` for a single "M" slot fed by the list's last entry, or
    ``[1, 20]`` for "C" then "M" on the OH-58D's FM radios).

    Only the index matching the list's actual **last** entry is a rotation — it
    is removed from its original position, the same convention as
    :func:`_rotate_last_to_head` (ADR 0010: "the list's last entry, by
    convention"), so a single reserved slot leaves the radio with exactly N
    slots for an N-entry list (e.g. OH-58D UHF/VHF: slot 1 = #20, slots 2..N =
    #1..#(N-1)). Any other reserved index (e.g. the OH-58D FM's "C" = #01) is a
    leading **duplicate** — it stays in its original tail position too (e.g.
    OH-58D FM: slot 1 = #01 ["C"], slot 2 = #20 ["M"], slots 3..N+1 = #1..#(N-1),
    where #01 reappears at slot 3 — matching the exploration doc's documented
    21-slot shape for a 20-entry list).

    Args:
        source: The role's channel list (channels in list order, not necessarily
            already numbered 1..N).
        reserved_head_slots: 1-based list-index(es) filling the leading slot(s),
            in order. An index that is not a valid 1-based position in the list
            (<= 0, or beyond the list's actual length) is skipped rather than
            raising (safe degradation for a shorter-than-expected maker list,
            mirroring :func:`pack_preset_for_type`'s HF-radio fallback).

    Returns:
        A new RadioDefinition with the same radio_type/title, channels renumbered.
    """
    result = RadioDefinition(name=source.name, radio_type=source.radio_type, title=source.title)
    last_position = len(source.channels) - 1
    valid_indices = [index for index in reserved_head_slots if 1 <= index <= len(source.channels)]
    reserved = [source.channels[index - 1] for index in valid_indices]
    # Only the last entry is removed from the tail (rotation semantics); any
    # other reserved index is a duplicate that stays in the tail too.
    rotated_positions = {index - 1 for index in valid_indices if index - 1 == last_position}
    tail = [channel for position, channel in enumerate(source.channels) if position not in rotated_positions]
    ordered = [*reserved, *tail]
    for slot, channel in enumerate(ordered, start=1):
        result.add_channel(_clone_channel(channel, slot))
    return result


def _channel_list_for_role(role_lists: dict[str, RadioDefinition], role: str) -> RadioDefinition | None:
    """Look up *role*'s channel list, defaulting fm_secondary to fm_supplement (ADR 0010)."""
    source = role_lists.get(role)
    if source is None and role == ROLE_FM_SECONDARY:
        source = role_lists.get(ROLE_FM_SUPPLEMENT)
    return source


def _clone_channel(channel: Channel, number: int) -> Channel:
    """Copy *channel* with a new slot *number*, preserving every attribute.

    The packer's primitives reslot channels; this keeps ``priority``/``color``
    (ADR 0012, presentation-facing) intact so they reach the kneeboard renderer.
    """
    return Channel(
        name_or_number=number,
        freq=channel.freq,
        title=channel.title,
        mod=channel.mod,
        priority=channel.priority,
        color=channel.color,
    )


# Deterministic role order for resolving a plan `priority` to a channel (ADR
# 0012): primary roles first so the UHF/VHF band preference wins on ties.
_PRIORITY_SEARCH_ORDER = (
    ROLE_PRIMARY_1,
    ROLE_PRIMARY_2,
    ROLE_FM_SUPPLEMENT,
    ROLE_FM_SUBSTITUTE,
    ROLE_FM_SECONDARY,
)


def _resolve_priority_channel(role_lists: dict[str, RadioDefinition], priority: int) -> Channel | None:
    """Return the plan channel tagged with *priority*, or None (ADR 0012).

    Scans the coalition's role lists in :data:`_PRIORITY_SEARCH_ORDER`; the
    channel's frequency is already band-resolved by its role (primary_1 → UHF,
    primary_2 → VHF). One channel per priority is expected — a duplicate warns
    and the first match (by role order) wins.
    """
    matches = [
        channel
        for role in _PRIORITY_SEARCH_ORDER
        for channel in (role_lists[role].channels if role in role_lists else [])
        if channel.priority == priority
    ]
    if not matches:
        return None
    if len(matches) > 1:
        logger.warning(
            t("presets_injector.radio_layout.priority_special_duplicate", priority=priority, count=len(matches))
        )
    return matches[0]


def _pack_keyed_groups(
    role_lists: dict[str, RadioDefinition],
    layout_radio: RadioLayoutRadio,
    unit_type: str,
    radio_index: int,
) -> RadioDefinition | None:
    """Key-based multi-role mapping into one radio's Group block (ADR 0012).

    Each role's channel is placed at ``slot = ((base + key - min_group) mod
    block_size) + 1`` (see :class:`KeyedGroups`), preserving key gaps and the
    Group-100 wrap. A key beyond its role's share of the block
    (``block_size // number_of_roles``) is dropped with a warning.

    Returns:
        The radio's RadioDefinition (sparse, channels numbered by slot), or None
        if no role had any placeable content.
    """
    keyed = layout_radio.keyed_groups
    assert keyed is not None  # only called when keyed_groups is set
    if not keyed.bases:
        return None
    min_group = min(keyed.bases.values())
    max_key = keyed.block_size // len(keyed.bases)
    slot_by: dict[int, Channel] = {}
    for role, base in keyed.bases.items():
        source = _channel_list_for_role(role_lists, role)
        if source is None:
            continue
        for channel in source.channels:
            key = channel.number
            if not 1 <= key <= max_key:
                logger.warning(
                    t(
                        "presets_injector.radio_layout.keyed_group_key_out_of_range",
                        unit_type=unit_type,
                        role=role,
                        channel_key=key,
                        max_key=max_key,
                    )
                )
                continue
            slot = ((base + key - min_group) % keyed.block_size) + 1
            slot_by[slot] = _clone_channel(channel, slot)
    if not slot_by:
        return None
    result = RadioDefinition(
        name=f"keyed_{unit_type}_{radio_index}", radio_type=ROLE_BANDS[layout_radio.role], title=layout_radio.role
    )
    for slot in sorted(slot_by):
        result.add_channel(slot_by[slot])
    return result


def _truncate_to_capacity(
    channels: list[Channel], capacity: int | None, unit_type: str, radio_index: int
) -> list[Channel]:
    """Slot capacity primitive (ADR 0010): drop excess channels from the END of the list.

    Applied as the LAST composition step, after every other primitive, since
    capacity is a property of the radio's total final slot count (e.g. the
    AJS-37's fused+dummy+specials radio is exactly 47 slots). Truncation is
    silent by design (exploration doc §8.4: verbose under `validate`, quiet
    under a normal `build`) — only a debug-level log line records it, no
    warning-level noise.

    Args:
        channels: The radio's fully composed channels, already numbered.
        capacity: The radio's declared maximum slot count, or None (unbounded).
        unit_type: DCS unit type string (for the debug log message).
        radio_index: 1-based physical radio index (for the debug log message).

    Returns:
        *channels* unchanged if within capacity (or capacity is None), else the
        first *capacity* entries, renumbered 1..capacity.
    """
    if capacity is None or len(channels) <= capacity:
        return channels
    dropped = channels[capacity:]
    logger.debug(
        t(
            "presets_injector.radio_layout.capacity_truncated",
            unit_type=unit_type,
            radio_index=radio_index,
            capacity=capacity,
            dropped_count=len(dropped),
        )
    )
    return [_clone_channel(channel, slot) for slot, channel in enumerate(channels[:capacity], start=1)]


def _content_for_radio(
    layout_radio: RadioLayoutRadio | None,
    role_lists: dict[str, RadioDefinition],
    base_source: RadioDefinition | None,
    unit_type: str,
    radio_index: int,
) -> RadioDefinition | None:
    """Materialize one physical radio's final channel map, applying all declared primitives.

    Composition order (ADR 0010/0012): the base content comes from either the
    ``keyed_groups`` key-based multi-role mapping (AJS-37) or the plain role
    list; then, for the plain-list path only, channel-0 rotation OR reserved head
    slot(s) (mutually exclusive, see ``RadioLayoutRadio``); then trailing
    specials are appended — at the block's fixed boundary for ``keyed_groups``
    (so E/F/G/H keep their absolute slots even if the data block has gaps), else
    right after the content; then slot capacity truncates the result. Each
    special is an airframe constant (``freq``) or plan-sourced (``priority``,
    resolved against *role_lists*, always AM; an unresolved priority leaves its
    slot empty). The Mi-24P needs only rotation; the OH-58D only reserved head
    slots; the AJS-37 keyed_groups + priority specials.

    Args:
        layout_radio: This radio's Radio layout entry, or None under the
            band-based default (no primitives apply).
        role_lists: This coalition's parsed Channel lists, role -> RadioDefinition
            (used to resolve ``keyed_groups`` and priority specials).
        base_source: The single role's channel list already resolved by the
            caller (used when ``keyed_groups`` is not declared; None when it is).
        unit_type: DCS unit type string (for the capacity truncation debug log).
        radio_index: 1-based physical radio index (for the capacity truncation
            debug log).

    Returns:
        The radio's final RadioDefinition, or None if it has no content at all.
    """
    if layout_radio is not None and layout_radio.keyed_groups is not None:
        content = _pack_keyed_groups(role_lists, layout_radio, unit_type, radio_index)
        if content is None:
            return None
        # keyed_groups already places channels at their final (possibly sparse)
        # slots; specials follow the block boundary, not the last used slot.
        channels = list(content.channels)
        specials_base = layout_radio.keyed_groups.block_size + 1
    else:
        if base_source is None:
            return None
        content = base_source
        if layout_radio is not None and layout_radio.rotate_last_to_head:
            content = _rotate_last_to_head(content)
        elif layout_radio is not None and layout_radio.reserved_head_slots:
            content = _prepend_reserved_slots(content, layout_radio.reserved_head_slots)
        channels = list(content.channels)
        specials_base = len(channels) + 1

    if layout_radio is not None and layout_radio.trailing_specials:
        channels = channels + _build_special_channels(layout_radio.trailing_specials, specials_base, role_lists)
    if layout_radio is not None:
        channels = _truncate_to_capacity(channels, layout_radio.capacity, unit_type, radio_index)

    result = RadioDefinition(name=content.name, radio_type=content.radio_type, title=content.title)
    for channel in channels:
        result.add_channel(channel)
    if layout_radio is not None:
        result.display_labels = _keyed_groups_display_labels(layout_radio, specials_base)
    return result


def _keyed_groups_display_labels(layout_radio: RadioLayoutRadio, specials_base: int) -> dict[int, str]:
    """Pilot-facing CH labels for a keyed_groups radio (ADR 0012): Group numbers + special names.

    Data slot ``i`` shows its DCS Group (``min_group + i - 1``, e.g. 100-139 for
    the AJS-37); each trailing special shows its declared ``label`` (Sp1/E/H…).
    Empty for a radio without ``keyed_groups`` (its CH column stays the number).
    """
    keyed = layout_radio.keyed_groups
    if keyed is None:
        return {}
    min_group = min(keyed.bases.values()) if keyed.bases else 100
    labels = {slot: str(min_group + slot - 1) for slot in range(1, keyed.block_size + 1)}
    for offset, special in enumerate(layout_radio.trailing_specials or []):
        if special.label:
            labels[specials_base + offset] = special.label
    return labels


def _build_special_channels(
    specials: list[HardcodedChannel], base_slot: int, role_lists: dict[str, RadioDefinition]
) -> list[Channel]:
    """Resolve the ``trailing_specials`` list into positioned Channels (ADR 0010/0012).

    Each special keeps its fixed absolute slot (``base_slot + offset``) so
    airframe constants (E/F/G) stay put even when a neighbouring plan-sourced
    slot is empty. A plan-sourced special whose priority resolves to no channel
    is skipped, leaving that slot empty; airframe constants always emit.
    """
    result: list[Channel] = []
    for offset, special in enumerate(specials):
        number = base_slot + offset
        if special.priority is not None:
            resolved = _resolve_priority_channel(role_lists, special.priority)
            if resolved is None:
                continue  # missing priority → empty slot
            result.append(Channel(name_or_number=number, freq=resolved.freq, title=resolved.title, mod=0))
        elif special.freq is not None:
            result.append(Channel(name_or_number=number, freq=special.freq, mod=special.mod))
        # else: malformed special (no freq, no priority) — already warned at parse; skip.
    return result


def _resolve_one_radio(
    role: str | None,
    layout_radio: RadioLayoutRadio | None,
    role_lists: dict[str, RadioDefinition],
    unit_type: str,
    radio_index: int,
) -> RadioDefinition | None:
    """Resolve one physical radio's final content, or None if it has nothing to carry.

    A radio has content either from its assigned role's plain channel list, or
    (when the layout declares ``keyed_groups``) from the key-based multi-role
    mapping — which does not need a single ``role``-matched list of its own,
    since its content comes from the named roles instead.

    Args:
        role: This radio's assigned Radio role, or None.
        layout_radio: This radio's Radio layout entry, or None.
        role_lists: This coalition's parsed Channel lists, role -> RadioDefinition.
        unit_type: DCS unit type string (for the capacity truncation debug log).
        radio_index: 1-based physical radio index (for the capacity truncation
            debug log).
    """
    base_source = _channel_list_for_role(role_lists, role) if role else None
    has_keyed_groups = bool(layout_radio and layout_radio.keyed_groups)
    if not has_keyed_groups and (base_source is None or not base_source.channels):
        return None
    return _content_for_radio(layout_radio, role_lists, base_source, unit_type, radio_index)


def _resolved_slots_for_type(
    channel_lists: dict[str, dict[str, RadioDefinition]], coalition: str, unit_type: str
) -> list[tuple[int, RadioDefinition]] | None:
    """Resolve which physical radio index gets which final channel map (ADR 0010).

    Localizes the packer's resolution policy — role assignment (an explicit
    _Radio layout_ entry if one exists, else the band-based default), content
    lookup and primitive application (:func:`_content_for_radio`), and the "gap
    before the last usable radio" safety check — separately from
    :func:`pack_preset_for_type`'s materialization into a `PresetDefinition`.

    Returns:
        Ordered (physical_index, content) pairs (0-based physical_index), or
        None if the aircraft is unknown, no role list has content for it, or a
        gap before the last usable radio makes the mapping ambiguous — packing
        it would silently renumber a later radio to the wrong physical slot, so
        it is left to an explicit layout entry rather than guessed.
    """
    role_lists = channel_lists.get(coalition)
    if not role_lists:
        return None
    radios = get_radios(unit_type)
    if not radios:
        return None

    layout = get_radio_layout(_load_radio_layouts(), unit_type)
    if layout is not None:
        _check_layout_radio_count(unit_type, layout, radios)
        role_by_index = _role_by_index_from_layout(layout)
        layout_radio_by_index = {index - 1: radio for index, radio in layout.radios.items()}
    else:
        role_by_index = _assign_roles_by_position(radios)
        layout_radio_by_index = {}
    if not role_by_index:
        return None

    resolved: list[RadioDefinition | None] = [
        _resolve_one_radio(role_by_index.get(index), layout_radio_by_index.get(index), role_lists, unit_type, index + 1)
        for index in range(len(radios))
    ]

    if all(source is None for source in resolved):
        return None
    last_usable = max(index for index, source in enumerate(resolved) if source is not None)
    if any(source is None for source in resolved[:last_usable]):
        return None

    return [(index, source) for index, source in enumerate(resolved[: last_usable + 1]) if source is not None]


def pack_preset_for_type(
    channel_lists: dict[str, dict[str, RadioDefinition]], coalition: str, unit_type: str
) -> "PresetDefinition | None":
    """Project a mission-maker's Channel lists onto one aircraft type's physical radios.

    This is the packer's projection (ADR 0010): each physical radio is assigned
    a role, either from an explicit per-type _Radio layout_ entry
    (`dcs-radio-layouts.yaml`) when one exists, or otherwise by
    :func:`_assign_roles_by_position`'s band-based default (both resolved by
    :func:`_resolved_slots_for_type`), then filled with that role's channel
    list — applying the layout's primitives when declared: channel-0 rotation
    or reserved head slot(s) (mutually exclusive with each other), radio fusion
    (concatenating several roles into one physical radio), a leading hardcoded
    dummy slot, and trailing hardcoded specials with their own modulations
    (see :func:`_content_for_radio`). An aircraft with no
    primary radio at all (single-radio HF/ADF sets, e.g. the MiG-15bis or
    Yak-52) still gets an ``fm_substitute`` guess on its only radio; since that
    content will not be in range, the existing frequency validator drops it and
    reports the mismatch — a safe, actionable degradation rather than a crash,
    pending an explicit layout entry for that type.

    Args:
        channel_lists: Parsed Channel lists, coalition -> role -> RadioDefinition
            (from :func:`parse_channel_lists`).
        coalition: "blue" or "red".
        unit_type: DCS unit type string.

    Returns:
        A :class:`PresetDefinition` with one radio per resolvable physical slot,
        or None if the aircraft is unknown or no role list has any content for it.
    """
    slots = _resolved_slots_for_type(channel_lists, coalition, unit_type)
    if not slots:
        return None

    preset = PresetDefinition(name=f"packed_{coalition}_{unit_type}")
    for physical_index, content in slots:
        radio = RadioDefinition(name=f"radio_{physical_index + 1}", radio_type=content.radio_type, title=content.title)
        for channel in content.channels:
            radio.add_channel(_clone_channel(channel, channel.number))  # keeps priority/color (ADR 0012)
        radio.display_labels = dict(content.display_labels)  # pilot-facing CH labels (ADR 0012)
        preset.add_radio(radio)
    return preset


class PresetsManager:
    """
    The presets manager has functions to manage the presets in DCS
    """

    def __init__(self):
        self.channel_collections: dict[str, ChannelCollection] = {}
        self.radio_collections: dict[str, RadioCollection] = {}
        self.preset_collections: dict[str, PresetCollection] = {}
        self.preset_assignments: PresetAssignmentCollection = PresetAssignmentCollection()
        self.presets_images: dict[str, io.BytesIO] | None = None
        self._cached_fonts: tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont] | None = None
        # ADR 0010: role-based channel lists, parsed from the optional `channel_lists`
        # block, and channels dropped because they lacked a role's band (reporting hook).
        self.channel_lists: dict[str, dict[str, RadioDefinition]] = {}
        self.channel_lists_dropped: dict[str, dict[str, list[str]]] = {}

    @staticmethod
    def _check_sections(data: Any) -> None:
        """Refuse a presets file whose top level is not a set of sections this loader reads.

        The loader used to be four ``if "<section>" in data`` blocks with no ``else``, so a section
        it did not recognise was never read and never mentioned. That silence is what made a v5
        ``presets_definition:`` block look like a problem with the *assignments*
        (FIX-CONVERT-V5-PRESETS-SCHEMA ticket 01).

        Args:
            data: The parsed YAML document.

        Raises:
            ValueError: The document is not a block, is empty, or names a section the loader does
                not read — via ``logger.error``, so the message reaches the user.
        """
        sections = ", ".join(PRESETS_SECTIONS)
        if data is None:
            logger.error(message=t("presets.schema.file_empty", sections=sections), exception_type=ValueError)
        _require_block(data, "the file", t("presets.schema.expected.file", sections=sections))

        unknown = [str(key) for key in data if str(key) not in PRESETS_SECTIONS]
        if not unknown:
            return

        details: list[str] = []
        for key in unknown:
            renamed = _V5_SECTION_RENAMES.get(key)
            if renamed:
                details.append(t("presets.schema.unknown.v5_rename", section=key, expected=renamed))
                continue
            near = difflib.get_close_matches(key, PRESETS_SECTIONS, n=1, cutoff=0.6)
            details.append(
                t("presets.schema.unknown.near", section=key, near=near[0])
                if near
                else t("presets.schema.unknown.plain", section=key)
            )
        logger.error(
            message=t("presets.schema.unknown_sections", details="; ".join(details), sections=sections),
            exception_type=ValueError,
        )

    def read_yaml(self, yaml_path: Path):
        try:
            with open(yaml_path) as file:
                data = yaml.safe_load(file)

            self._check_sections(data)

            # Load channel collections
            if "channels_collection" in data:
                collection = data["channels_collection"]
                for name in collection:
                    self.channel_collections[name] = ChannelCollection.from_dict(name=name, data=collection[name])

            # Load radio collections
            if "radios_collection" in data:
                collection = data["radios_collection"]
                for name in collection:
                    self.radio_collections[name] = RadioCollection.from_dict(
                        name=name, data=collection[name], channel_collections=self.channel_collections
                    )

            # Load preset collections
            if "presets_collection" in data:
                collection = data["presets_collection"]
                for name in collection:
                    self.preset_collections[name] = PresetCollection.from_dict(
                        name=name, data=collection[name], radio_collections=self.radio_collections
                    )

            # Load preset assignments
            if "presets_assignments" in data:
                collection = data["presets_assignments"]
                self.preset_assignments = PresetAssignmentCollection.from_dict(
                    data=collection, presets_collections=self.preset_collections
                )

            # Load channel lists (ADR 0010: role-based preset plan)
            if "channel_lists" in data:
                self.channel_lists, self.channel_lists_dropped = parse_channel_lists(
                    data=data["channel_lists"], channel_collections=self.channel_collections
                )

        except FileNotFoundError:
            logger.error(message=t("presets.schema.file_not_found", path=yaml_path), exception_type=FileNotFoundError)
        except yaml.YAMLError as e:
            logger.error(
                message=t("presets.schema.yaml_error", path=yaml_path, error=str(e)), exception_type=ValueError
            )
        except Exception as e:
            logger.error(
                message=t("presets.schema.load_error", path=yaml_path, error=str(e)), exception_type=RuntimeError
            )

    def write_yaml(self, yaml_path: Path):
        # TODO do this later when implementing the GUI editor
        pass

    def get_radios_for(self, coalition: str, aircraft_type: str, unit_type: str):
        # An explicit assignment (including an explicit "none") always wins over
        # the packer (ADR 0010: manual override). Only fall back to packing
        # `channel_lists` when NO assignment at all matched this aircraft.
        preset_assignment = self.preset_assignments.get_preset_for(
            coalition=coalition, aircraft_type=aircraft_type, unit_type=unit_type
        )
        if preset_assignment is not None:
            return preset_assignment.preset_definition
        return pack_preset_for_type(self.channel_lists, coalition, unit_type)

    def generate_type_images(
        self, injected: dict[tuple[str, str], "PresetDefinition"], width: int = 1200, height: int | None = None
    ):
        """Render per-type kneeboard images for the injected presets (ADR 0012)."""
        generator = RadioPresetsImageGenerator(self.preset_collections, width=width, height=height)
        self.presets_images = generator.generate_type_images(injected)


# ── Kneeboard rendering constants (ADR 0012) ────────────────────────────────
# All radio title bars are neutral grey (the red/green/orange per-radio coding
# is dropped); a channel's `priority` highlights its Name/Freq cells in orange
# (a "P<n>" marker in the Name cell); its `color` fills the CH cell.
_RADIO_TITLE_BG = (128, 128, 128)
_PRIORITY_HIGHLIGHT = (255, 165, 0)  # orange "highlighter"
# A single-radio preset taller than this many slots is split across columns so
# the page stays legible (the AJS-37's 47-slot radio → two columns).
_COLUMN_SPLIT_THRESHOLD = 25


def _radio_max_slot(radio: RadioDefinition) -> int:
    """Highest slot a radio occupies, counting labelled-but-empty slots (ADR 0012)."""
    slots = [channel.number for channel in radio.channels if channel.number]
    slots += list(radio.display_labels.keys())
    return max(slots, default=0)


def _split_radio_into_columns(radio: RadioDefinition, num_columns: int) -> list[RadioDefinition]:
    """Split one tall radio into *num_columns* side-by-side columns (ADR 0012).

    Each column is a RadioDefinition covering a contiguous slot range, its
    channels renumbered to column-local slots 1..N with ``display_labels`` carrying
    the real pilot label (Group number / special name), so gaps and labels render
    correctly. Reuses the normal multi-radio rendering path.
    """
    max_slot = _radio_max_slot(radio)
    rows_per_column = math.ceil(max_slot / num_columns)
    channel_by_slot = {channel.number: channel for channel in radio.channels}
    columns: list[RadioDefinition] = []
    for column_index in range(num_columns):
        first_slot = column_index * rows_per_column + 1
        last_slot = min(max_slot, (column_index + 1) * rows_per_column)
        if first_slot > last_slot:
            break
        column = RadioDefinition(
            name=f"{radio.name}_col{column_index + 1}", radio_type=radio.radio_type, title=radio.title
        )
        for real_slot in range(first_slot, last_slot + 1):
            local_slot = real_slot - first_slot + 1
            column.display_labels[local_slot] = radio.display_labels.get(real_slot, f"{real_slot:02d}")
            if real_slot in channel_by_slot:
                column.add_channel(_clone_channel(channel_by_slot[real_slot], local_slot))
        columns.append(column)
    return columns


def _resolve_kneeboard_color(color: str) -> tuple[int, int, int] | None:
    """Resolve a channel ``color`` (Pillow name or ``#RRGGBB[AA]``) to an RGB triple.

    Returns None (and warns) for an unrecognised value, so the CH cell simply
    keeps its default background — a soft degradation, not a build failure.
    """
    try:
        rgb = ImageColor.getrgb(color)
    except ValueError:
        logger.warning(t("presets_injector.kneeboard.unknown_color", color=color))
        return None
    return rgb[:3]


def _contrast_text_color(background: tuple[int, int, int]) -> str:
    """Return "white" or "black", whichever reads best on *background* (ITU-R BT.601 luma)."""
    red, green, blue = background
    luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    return "black" if luminance >= 128 else "white"


class RadioPresetsImageGenerator:
    def __init__(self, preset_collections: dict[str, PresetCollection], width: int = 1200, height: int | None = None):
        self.width = width
        self.height = height
        self.preset_collections = preset_collections
        self._cached_fonts: tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont] | None = None
        # Layout state shared between draw_* methods (set in draw_preset_image /
        # draw_radios_in_preset_image, read in draw_channels_in_preset_image).
        self.table_x: float = 0
        self.header_y: float = 0
        self.column_width_channel: float = 0
        self.column_width_name: float = 0

    def get_fonts(self) -> tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont]:
        if not self._cached_fonts:
            try:
                ARIAL = "arial.ttf"
                preset_font = ImageFont.truetype(ARIAL, 18)
                title_font = ImageFont.truetype(ARIAL, 30)
                collection_title_font = ImageFont.truetype(ARIAL, 40)
            except Exception:
                preset_font = cast(FreeTypeFont, ImageFont.load_default())
                title_font = cast(FreeTypeFont, ImageFont.load_default())
                collection_title_font = cast(FreeTypeFont, ImageFont.load_default())

            self._cached_fonts = (preset_font, title_font, collection_title_font)

        assert self._cached_fonts is not None
        return self._cached_fonts

    def get_preset_font(self) -> FreeTypeFont:
        return self.get_fonts()[0]

    def get_title_font(self) -> FreeTypeFont:
        return self.get_fonts()[1]

    def get_collection_title_font(self) -> FreeTypeFont:
        return self.get_fonts()[2]

    def draw_channels_in_preset_image(self, radio_definition: RadioDefinition):
        # Draw channels with alternating backgrounds
        for j in range(self.max_channels):
            # Skip empty rows if radio has fewer channels
            channel_index = 0
            while True:
                channel = (
                    radio_definition.channels[channel_index] if channel_index < len(radio_definition.channels) else None
                )
                channel_index += 1
                if not channel or channel.number == j + 1:
                    break
            # ADR 0012: the CH cell shows the type's pilot label when one exists
            # (the AJS-37's Group 100-139 / Sp1-H), else the plain slot number.
            channel_number = radio_definition.display_labels.get(j + 1, f"{j + 1:02d}")
            channel_name = channel.title if channel is not None else ""
            channel_frequency = f"{channel.freq:.2f}" if channel is not None else ""
            priority = channel.priority if channel is not None else None
            color = channel.color if channel is not None else None

            row_y = self.header_y + self.row_height + j * self.row_height
            ch_col_x = self.table_x + self.column_width_channel
            name_col_x = ch_col_x + self.column_width_name

            # Alternate background colors (light gray and white)
            bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
            self.draw.rectangle(
                [self.table_x, row_y, self.table_x + self.table_width, row_y + self.row_height], fill=bg_color
            )

            # ADR 0012: `color` fills the CH cell (channel-number text auto-contrasted);
            # `priority` highlights the Name & Freq cells orange (a "P<n>" marker below).
            number_text_color = "black"
            if color and (rgb := _resolve_kneeboard_color(color)) is not None:
                self.draw.rectangle([self.table_x, row_y, ch_col_x, row_y + self.row_height], fill=rgb)
                number_text_color = _contrast_text_color(rgb)
            if priority is not None:
                self.draw.rectangle(
                    [ch_col_x, row_y, self.table_x + self.table_width, row_y + self.row_height],
                    fill=_PRIORITY_HIGHLIGHT,
                )

            # Draw vertical lines between columns
            self.draw.line(
                [
                    self.table_x + self.column_width_channel,
                    row_y,
                    self.table_x + self.column_width_channel,
                    row_y + self.row_height,
                ],
                fill="black",
            )
            self.draw.line(
                [
                    self.table_x + self.column_width_channel + self.column_width_name,
                    row_y,
                    self.table_x + self.column_width_channel + self.column_width_name,
                    row_y + self.row_height,
                ],
                fill="black",
            )

            # Draw channel number
            self.draw.text(
                (self.table_x + 10, row_y + 5), channel_number, fill=number_text_color, font=self.get_preset_font()
            )

            # Draw channel name
            self.draw.text(
                (self.table_x + self.column_width_channel + 10, row_y + 5),
                channel_name or "",
                fill="black",
                font=self.get_preset_font(),
            )

            # ADR 0012: priority marker "P<n>", right-aligned in the Name cell.
            if priority is not None:
                marker = f"P{priority}"
                marker_width = self.draw.textlength(marker, font=self.get_preset_font())
                self.draw.text(
                    (name_col_x - marker_width - 10, row_y + 5), marker, fill="black", font=self.get_preset_font()
                )

            # Draw frequency
            self.draw.text(
                (self.table_x + self.column_width_channel + self.column_width_name + 10, row_y + 5),
                channel_frequency,
                fill="black",
                font=self.get_preset_font(),
            )

            # Draw horizontal line at bottom of row
            self.draw.line(
                [self.table_x, row_y + self.row_height, self.table_x + self.table_width, row_y + self.row_height],
                fill="black",
            )

    def draw_radios_in_preset_image(self, preset_definition: PresetDefinition):
        # Draw each radio as a table
        for i, radio in enumerate(preset_definition.radios.values()):
            if i >= 3:
                # Only draw up to 3 radios
                break

            # Calculate table position with margins
            self.table_x = self.side_margin + i * (self.table_width + self.margin_between_tables)
            table_y = self.top_margin  # Space for collection title

            # Define column widths
            self.column_width_channel = self.table_width * 0.13
            self.column_width_name = self.table_width * 0.67

            # Draw table background (optional, for better visibility)
            table_height = self.header_height + len(radio.channels) * self.row_height + 10
            self.draw.rectangle(
                [self.table_x, table_y, self.table_x + self.table_width, table_y + table_height], outline="black"
            )

            # Draw title row (grey for every radio — ADR 0012 drops the old
            # red/green/orange per-radio colour coding).
            self.draw.rectangle(
                [self.table_x, table_y, self.table_x + self.table_width, table_y + self.header_height],
                fill=_RADIO_TITLE_BG,
            )

            # Draw radio title (merged columns)
            radio_title = radio.title or radio.name
            title_bbox = self.draw.textbbox((0, 0), radio_title, font=self.get_title_font())
            title_width = title_bbox[2] - title_bbox[0]
            title_x_pos = self.table_x + (self.table_width - title_width) // 2
            title_y_pos = table_y + (self.header_height - (title_bbox[3] - title_bbox[1])) // 2
            self.draw.text((title_x_pos, title_y_pos), radio_title, fill="white", font=self.get_title_font())

            # Draw column headers
            self.header_y = table_y + self.header_height
            self.draw.rectangle(
                [self.table_x, self.header_y, self.table_x + self.table_width, self.header_y + self.row_height],
                fill=(200, 200, 200),
            )  # Gray header
            self.draw.line(
                [
                    self.table_x + self.column_width_channel,
                    self.header_y,
                    self.table_x + self.column_width_channel,
                    self.header_y + self.row_height,
                ],
                fill="black",
            )  # Vertical line
            self.draw.line(
                [
                    self.table_x + self.column_width_channel + self.column_width_name,
                    self.header_y,
                    self.table_x + self.column_width_channel + self.column_width_name,
                    self.header_y + self.row_height,
                ],
                fill="black",
            )  # Vertical line
            self.draw.text((self.table_x + 10, self.header_y + 5), "CH", fill="black", font=self.get_preset_font())
            self.draw.text(
                (self.table_x + self.column_width_channel + 10, self.header_y + 5),
                "Name",
                fill="black",
                font=self.get_preset_font(),
            )
            self.draw.text(
                (self.table_x + self.column_width_channel + self.column_width_name + 10, self.header_y + 5),
                "Freq.",
                fill="black",
                font=self.get_preset_font(),
            )
            self.draw.line(
                [
                    self.table_x,
                    self.header_y + self.row_height,
                    self.table_x + self.table_width,
                    self.header_y + self.row_height,
                ],
                fill="black",
            )  # Bottom line

            # Draw channels
            self.draw_channels_in_preset_image(radio_definition=radio)

    def draw_preset_image(self, preset_definition: PresetDefinition):
        # Calculate dimensions based on content
        self.row_height = 30
        self.header_height = 55
        self.margin_between_tables = 30  # Margin between tables
        self.side_margin = 50  # Margin on sides
        self.top_margin = 80  # Space for collection title
        bottom_margin = 50  # Margin at bottom

        # Compute the highest slot across all radios — including labelled-but-empty
        # slots (ADR 0012: the AJS-37 shows its full Group range even where a
        # channel is unset), so every labelled row is rendered.
        self.max_channels = 0
        for radio in preset_definition.radios.values():
            slots = [channel.number for channel in radio.channels if channel.number]
            slots += list(radio.display_labels.keys())
            self.max_channels = max([self.max_channels, *slots])

        # Find the radio with the most channels to determine image height
        image_height = self.top_margin + self.header_height + self.max_channels * self.row_height + bottom_margin
        image_height = self.height if self.height is not None else image_height

        # Calculate table widths and positions with margins
        image_width = self.width
        available_width = image_width - 2 * self.side_margin - (self.radio_count - 1) * self.margin_between_tables
        self.table_width = available_width // self.radio_count if self.radio_count > 0 else 400

        # Create image with light yellow background (like old paper)
        self.image = Image.new("RGB", (image_width, image_height), color=(255, 255, 224))  # Light yellow
        self.draw = ImageDraw.Draw(self.image)

        # Draw collection title
        # Get text dimensions for centering
        title_bbox = self.draw.textbbox((0, 0), preset_definition.title, font=self.get_collection_title_font())
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (image_width - title_width) // 2
        self.draw.text((title_x, 20), preset_definition.title, fill="black", font=self.get_collection_title_font())

    def generate_type_images(self, injected: dict[tuple[str, str], PresetDefinition]) -> dict[str, io.BytesIO]:
        """Render one kneeboard PNG per injected (coalition, aircraft type) (ADR 0012).

        Each image is keyed by its DCS kneeboard path
        ``KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png`` — coalition-suffixed
        only when the same type is injected for both coalitions (so the two pages
        do not collide in the shared per-type folder). A single-radio preset with
        many channels (the AJS-37's 47) is split across columns for legibility.

        Args:
            injected: The presets actually injected, keyed by (coalition, concrete
                unit_type). Built by the worker during ``process_groups``.

        Returns:
            Mapping of kneeboard-relative path -> PNG buffer.
        """
        coalitions_by_type: dict[str, set[str]] = {}
        for coalition, unit_type in injected:
            coalitions_by_type.setdefault(unit_type, set()).add(coalition)

        images: dict[str, io.BytesIO] = {}
        for (coalition, unit_type), preset in injected.items():
            if not preset.radios:
                continue
            render_preset = self._prepare_render_preset(preset, title=f"{unit_type} ({coalition})")
            self.radio_count = len(render_preset.radios)
            self.draw_preset_image(render_preset)
            self.draw_radios_in_preset_image(render_preset)
            img_buffer = io.BytesIO()
            self.image.save(img_buffer, format="PNG", optimize=True)
            img_buffer.seek(0)
            safe_type = unit_type.replace("/", "_").replace("\\", "_")
            suffix = f"-{coalition}" if len(coalitions_by_type[unit_type]) > 1 else ""
            images[f"KNEEBOARD/{safe_type}/IMAGES/presets{suffix}.png"] = img_buffer
        return images

    def _prepare_render_preset(self, preset: PresetDefinition, title: str) -> PresetDefinition:
        """Return a render-ready copy of *preset* with the given *title*.

        A single-radio preset taller than :data:`_COLUMN_SPLIT_THRESHOLD` slots is
        split into side-by-side columns (the AJS-37's 47-slot radio); everything
        else keeps its radios as the columns.
        """
        render = PresetDefinition(name=preset.name, title=title)
        radios = list(preset.radios.values())
        if len(radios) == 1 and _radio_max_slot(radios[0]) > _COLUMN_SPLIT_THRESHOLD:
            for column in _split_radio_into_columns(radios[0], num_columns=2):
                render.add_radio(column)
        else:
            for radio in radios:
                render.add_radio(radio)
        return render
