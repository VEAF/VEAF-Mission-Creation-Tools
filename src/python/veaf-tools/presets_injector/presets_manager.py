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

from .radio_frequency_validator import FrequencyRange, RadioSpec, get_aircraft_name, get_radios

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


@dataclass(frozen=True)
class DroppedChannel:
    """A channel a role's list cannot carry: it has no frequency in that role's band.

    The injector skips it, so no aircraft gets it; it used to be skipped in silence, while the
    mission's README advertised it (FIX-OPEN-TRAINING-CAUCASUS-FINDINGS ticket 05).

    Attributes:
        key: The channel's key in the list (``"12"``).
        name: Its alias's title, else the alias, else the key.
        band: The band the role needs and the channel lacks (``"vhf"``).
    """

    key: str
    name: str
    band: str


def parse_channel_lists(
    data: dict[str, Any], channel_collections: dict[str, ChannelCollection]
) -> tuple[dict[str, dict[str, RadioDefinition]], dict[str, dict[str, list[DroppedChannel]]]]:
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
        coalition -> role -> each :class:`DroppedChannel` skipped because it had no
        frequency for that role's band (e.g. a UHF-only channel listed under
        ``primary_2``).
    """
    channel_lists: dict[str, dict[str, RadioDefinition]] = {}
    dropped: dict[str, dict[str, list[DroppedChannel]]] = {}
    for coalition, roles_data in data.items():
        role_lists: dict[str, RadioDefinition] = {}
        role_dropped: dict[str, list[DroppedChannel]] = {}
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
) -> tuple[RadioDefinition, list[DroppedChannel]]:
    """Resolve one role's channels into a RadioDefinition, tracking dropped ones.

    Args:
        coalition: "blue" or "red" (only used to name the resulting RadioDefinition).
        role: One of the ``ROLE_BANDS`` keys.
        channels_data: The role's channel mapping from ``channel_lists.yaml``.
        channel_collections: Used to resolve channel aliases.

    Returns:
        The role's RadioDefinition, and the channels skipped because they lacked a
        frequency for the role's band.
    """
    band = ROLE_BANDS[role]
    radio = RadioDefinition(name=f"channel_list_{coalition}_{role}", radio_type=band, title=role)
    skipped: list[DroppedChannel] = []
    for channel_name, channel_data in (channels_data or {}).items():
        # An empty entry is skipped too, but it lacks no band: it is not a drop to report.
        if (
            not radio.add_channel_from_dict(channel_name, channel_data, channel_collections, strict=False)
            and channel_data
        ):
            skipped.append(
                DroppedChannel(str(channel_name), _channel_label(channel_name, channel_data, channel_collections), band)
            )
    return radio, skipped


def _channel_label(channel_name: object, channel_data: Any, channel_collections: dict[str, ChannelCollection]) -> str:
    """Return how a pilot would know a list entry: its alias's title, else the alias, else its key.

    Args:
        channel_name: The entry's key in the list.
        channel_data: The entry: an alias, or a mapping with ``channel`` (and maybe ``title``).
        channel_collections: Where the alias is defined.

    Returns:
        The entry's display name.
    """
    alias = channel_data if isinstance(channel_data, str) else (channel_data or {}).get("channel")
    if isinstance(channel_data, dict) and channel_data.get("title"):
        return str(channel_data["title"])
    for collection in channel_collections.values():
        definition = collection.channel_definitions.get(alias) if alias else None
        if definition is not None and definition.title:
            return str(definition.title)
    return str(alias or channel_name)


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
        head_labels: What the cockpit shows on each reserved head slot, in the
            same order (e.g. ``["C", "M"]``): the kneeboard prints them on those
            slots and numbers the presets that follow from 01.
        capacity: Slot capacity primitive (ADR 0010): the maximum number of
            channel slots this radio physically holds. When the radio's final
            composed channel count (after every other primitive has run,
            including ``trailing_specials``) exceeds ``capacity``, the excess is
            truncated from the END of the list (e.g. the AJS-37's 47-slot radio
            is already an exact fit; Tripack itself truncated its VHF list to
            fit 47 slots — see the exploration doc §7/§8.4). ``None`` (the
            default) means unbounded.
        kneeboard_title: The radio's heading on the kneeboard, replacing the
            set's name from the specs (the AJS-37's ``FR22 / FR24``). ``None``
            keeps the specs name.
    """

    role: str
    rotate_last_to_head: bool = False
    keyed_groups: KeyedGroups | None = None
    trailing_specials: list[HardcodedChannel] | None = None
    reserved_head_slots: list[int] = field(default_factory=list)
    capacity: int | None = None
    head_labels: list[str] = field(default_factory=list)
    kneeboard_title: str | None = None


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
                head_labels=[str(label) for label in radio_data.get("head_labels") or []],
                kneeboard_title=str(radio_data["kneeboard_title"]) if radio_data.get("kneeboard_title") else None,
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
            in order. An index beyond a shorter list takes the list's last entry
            (the head slot exists in the cockpit whatever the list's length); an
            index <= 0 is skipped rather than raising. See
            :func:`_reserved_head_indices`.

    Returns:
        A new RadioDefinition with the same radio_type/title, channels renumbered.
    """
    result = RadioDefinition(name=source.name, radio_type=source.radio_type, title=source.title)
    last_position = len(source.channels) - 1
    valid_indices = _reserved_head_indices(reserved_head_slots, len(source.channels))
    reserved = [source.channels[index - 1] for index in valid_indices]
    # Only the last entry is removed from the tail (rotation semantics); any
    # other reserved index is a duplicate that stays in the tail too.
    rotated_positions = {index - 1 for index in valid_indices if index - 1 == last_position}
    tail = [channel for position, channel in enumerate(source.channels) if position not in rotated_positions]
    ordered = [*reserved, *tail]
    for slot, channel in enumerate(ordered, start=1):
        result.add_channel(_clone_channel(channel, slot))
    return result


def _reserved_head_indices(reserved_head_slots: list[int], length: int) -> list[int]:
    """The 1-based list indices that fill the reserved head slots of a *length*-entry list.

    An index beyond the list stands for "the list's last entry" (20 is the last of a full list): the head
    slot exists in the cockpit whatever the list's length, so it takes the last entry rather than being
    dropped, which shifted every preset by one (GermanyCW OH-58D VHF, 16 entries, 2026-09-29). Indices
    below 1 are skipped; a clamp that lands on an index already taken is not repeated.

    Args:
        reserved_head_slots: The layout's declared indices, in order.
        length: Number of entries in the channel list.

    Returns:
        The indices to use, in order.
    """
    indices: list[int] = []
    for index in reserved_head_slots:
        if index < 1 or length < 1:
            continue
        index = min(index, length)
        if index not in indices:
            indices.append(index)
    return indices


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
        # the pilot numbering of the plain-list content; the trailing specials, if any, keep their own labels
        content_slots = min(specials_base - 1, len(channels))
        if layout_radio.keyed_groups is None and layout_radio.rotate_last_to_head:
            result.display_labels = _rotation_display_labels(content_slots)
        elif layout_radio.keyed_groups is None and layout_radio.reserved_head_slots and base_source is not None:
            heads = len(_reserved_head_indices(layout_radio.reserved_head_slots, len(base_source.channels)))
            result.display_labels = _reserved_head_display_labels(layout_radio.head_labels, heads, content_slots)
        if layout_radio.keyed_groups is None and result.display_labels:
            for offset, special in enumerate(layout_radio.trailing_specials or []):
                if special.label:
                    result.display_labels[specials_base + offset] = special.label
    return result


def _reserved_head_display_labels(head_labels: list[str], heads: int, slot_count: int) -> dict[int, str]:
    """Pilot-facing CH labels for a radio with reserved head slots (the OH-58D's "C"/"M").

    The head slots show their cockpit name; the presets after them are numbered from 01, which is what the
    pilot selects. Without them the kneeboard printed the DCS slot, one more than the preset (two on FM).

    Args:
        head_labels: The cockpit names of the head slots, in order (may be shorter than *heads*).
        heads: Number of head slots actually placed.
        slot_count: Number of slots the radio carries.

    Returns:
        Slot -> label.
    """
    labels = {slot: f"{slot - heads:02d}" for slot in range(heads + 1, slot_count + 1)}
    for slot in range(1, heads + 1):
        labels[slot] = head_labels[slot - 1] if slot <= len(head_labels) else f"{slot:02d}"
    return labels


def _rotation_display_labels(slot_count: int) -> dict[int, str]:
    """Pilot-facing CH labels for a channel-0 rotation radio: DCS slot ``N`` is the selector's channel ``N-1``.

    Without them the kneeboard printed the DCS slot, one more than the number the pilot dials (the Mi-24P's
    R-863 reads channel 12 where the kneeboard said 13, GermanyCW, 2026-09-29).

    Args:
        slot_count: Number of slots the radio carries.

    Returns:
        Slot -> two-digit channel label, from "00".
    """
    return {slot: f"{slot - 1:02d}" for slot in range(1, slot_count + 1)}


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
    (see :func:`_content_for_radio`). An aircraft whose only radio is an **HF**
    set above the comm floor — the MiG-15bis RSI-6K at 3.75–5.0 MHz — still gets
    an ``fm_substitute`` guess there; the content will not be in range, so the
    frequency validator drops it and reports the mismatch, a safe and actionable
    degradation rather than a crash, pending an explicit layout entry.

    A **radio-compass** is different and gets no role at all: every range below
    ``_COMM_FLOOR_MHZ`` classifies as ``"non_comm"`` (ticket 01 of
    `FIX-RADIO-LAYOUT-GAPS`), so the Yak-52's ARK-15M, the Ka-50's ARK-22 and the
    MiG-29 Fulcrum's ARK-19 attract no channel list. Projecting one onto a
    navigation instrument produced a full page of dropped channels and a
    kneeboard advertising a radio the aircraft does not have.

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
        self.channel_lists_dropped: dict[str, dict[str, list[DroppedChannel]]] = {}

    def dropped_channel_warnings(self) -> list[str]:
        """Return one warning per channel a list cannot carry, for the build, the report and ``validate``.

        Returns:
            The localized messages, in file order; empty when every listed channel fits its list.
        """
        return [
            t(
                "presets.dropped_channel",
                coalition=coalition,
                role=role,
                channel=channel.key,
                name=channel.name,
                band=channel.band.upper(),
            )
            for coalition, roles in self.channel_lists_dropped.items()
            for role, channels in roles.items()
            for channel in channels
        ]

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
            with open(yaml_path, encoding="utf-8") as file:
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

    def generate_type_images(self, injected: dict[tuple[str, str], "PresetDefinition"]) -> None:
        """Render per-type kneeboard pages for the injected presets, plus the shared calibration page.

        The calibration page is added only when at least one presets page is: a mission with no
        kneeboard gets no page telling the pilot how to set one up.

        Args:
            injected: The presets actually injected, keyed by (coalition, concrete unit_type).
        """
        images = RadioPresetsImageGenerator(self.preset_collections).generate_type_images(injected)
        if images:
            images[KNEEBOARD_CALIBRATION_PATH] = render_calibration_page()
        self.presets_images = images


# ── Kneeboard rendering (ADR 0012, FEAT-KNEEBOARD-PRESETS-REDESIGN) ──────────
# DCS maps a kneeboard image onto the whole kneeboard window, never keeping its proportions
# (`KNEEBOARD/indicator/init.lua`, `image_page_template`: texture coordinates 0..1 on the full quad).
# The cockpit kneeboard is 0.142 x 0.214 (`declare_kneeboard_device.lua`) and the default 2D window
# measured 2:3 too (2026-10-18), so every page is drawn at 2:3 — twice ED's 768 px width, for VR.
KNEEBOARD_PAGE_SIZE = (1536, 2304)
# One page for the whole mission, in the folder every aircraft shows.
KNEEBOARD_CALIBRATION_PATH = "KNEEBOARD/IMAGES/00-veaf-calibration.png"

_PAGE_W, _PAGE_H = KNEEBOARD_PAGE_SIZE
_MARGIN = 56
_GUTTER = 36
_HEADER_H = 150
_FOOTER_H = 50
_BLOCK_TITLE_H = 72
_COL_HEAD_H = 44
_BLOCK_HEAD_H = _BLOCK_TITLE_H + _COL_HEAD_H
_ROW_H = 52
_BLOCK_GAP = 28
_BODY_TOP = _MARGIN + _HEADER_H + 10
_COLUMN_H = _PAGE_H - _MARGIN - _HEADER_H - 30 - _FOOTER_H - _MARGIN
_COLUMN_W = (_PAGE_W - 2 * _MARGIN - _GUTTER) // 2
_CH_W = 92
_MOD_W = 70
# A block does not start at the foot of a column with fewer rows than this.
_MIN_ROWS_AT_FOOT = 4
# The kneeboard window draws its own controls over the page (David's A-10C II screenshot, 2026-10-18,
# page shown 830 px wide): the chapter tabs and their close cross cover the top-left corner up to
# x = 111 and y = 129..177 page pixels, and the UP/DN buttons the bottom-right from x = 1463 and y = 2174.
# The header texts start after the tabs and the footer ends before the buttons.
_HEADER_TEXT_X = 150
_FOOTER_RIGHT_X = _PAGE_W - 130

_PAPER = (252, 251, 246)
_INK = (20, 22, 26)
_MUTED = (110, 114, 122)
_HEADER_BG = (34, 45, 58)
_HEADER_SUBTITLE = (190, 200, 212)
_RADIO_TITLE_BG = (66, 78, 92)
_RADIO_BAND_TEXT = (205, 212, 220)
_COLUMN_HEAD_BG = (222, 225, 230)
_ZEBRA = (240, 241, 236)
_RULE = (190, 193, 198)
# A channel's `priority` highlights its row from the name cell on; its `color` fills the CH cell.
_PRIORITY_HIGHLIGHT = (255, 196, 70)
_COALITION_BG = {"blue": (40, 96, 196), "red": (196, 46, 46)}

_FONT_SIZES = {
    "title": 64,
    "subtitle": 30,
    "badge": 30,
    "radio": 36,
    "band": 26,
    "column": 22,
    "ch": 30,
    "name": 30,
    "freq": 32,
    "mod": 24,
    "footer": 22,
    "calibration": 40,
    "calibration_lead": 40,
}
_BOLD_FONTS = {"title", "badge", "radio", "column", "ch", "freq", "calibration_lead"}


@dataclass(frozen=True)
class KneeboardRow:
    """One row of a radio block: the CH cell's text and the channel on that slot, if any."""

    label: str
    channel: Channel | None


@dataclass(frozen=True)
class KneeboardBlock:
    """One radio on the page: its heading, its band and its rows."""

    title: str
    band: str
    show_mod: bool
    rows: list[KneeboardRow]


@dataclass(frozen=True)
class KneeboardSegment:
    """The part of a block drawn in one column; ``continued`` when the block began in an earlier one."""

    block: KneeboardBlock
    rows: list[KneeboardRow]
    continued: bool


def _radio_max_slot(radio: RadioDefinition) -> int:
    """Highest slot a radio occupies, counting labelled-but-empty slots (ADR 0012)."""
    slots = [channel.number for channel in radio.channels if channel.number]
    slots += list(radio.display_labels.keys())
    return max(slots, default=0)


def _ch_label(radio: RadioDefinition, slot: int) -> str:
    """The text of a kneeboard row's CH cell: the radio's pilot label for *slot*, else the slot number.

    A radio that carries labels (the AJS-37's Groups, the Mi-24P's channel 0, the OH-58D's "M") gets an empty
    cell past its labelled slots: printing the DCS slot there ("21" right after "19" on the OH-58D) would read
    as one more preset.

    Args:
        radio: The radio the row belongs to.
        slot: The row's 1-based DCS slot.

    Returns:
        The label, the zero-padded slot number, or "".
    """
    if slot in radio.display_labels:
        return radio.display_labels[slot]
    return "" if radio.display_labels else f"{slot:02d}"


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


def _format_freq(freq: float) -> str:
    """Format a frequency in MHz with two decimals, three when the third one is set (8.33 kHz channels).

    Args:
        freq: The frequency, in MHz.

    Returns:
        ``121.50`` for 121.5, ``127.525`` for 127.525.
    """
    text = f"{freq:.3f}"
    return text[:-1] if text.endswith("0") else text


def _kneeboard_rows(radio: RadioDefinition) -> list[KneeboardRow]:
    """The rows of one radio, up to its last channel or labelled slot; the gaps before it stay.

    Args:
        radio: The radio to lay out.

    Returns:
        One row per slot from 1 to the radio's highest slot.
    """
    by_slot = {channel.number: channel for channel in radio.channels}
    return [KneeboardRow(_ch_label(radio, slot), by_slot.get(slot)) for slot in range(1, _radio_max_slot(radio) + 1)]


def _radio_heading(
    index: int, spec: RadioSpec | None, layout_radio: RadioLayoutRadio | None, radio: RadioDefinition
) -> str:
    """The heading of a radio block: its position, then the cockpit set's name.

    The layout's ``kneeboard_title`` wins, then the specs name (``COMM 1: ARC-210`` reads
    ``COMM 1 · ARC-210``), then the radio's own title for a type the specs do not know.

    Args:
        index: The radio's 1-based physical position.
        spec: The specs entry for that position, if known.
        layout_radio: The layout entry for that position, if any.
        radio: The radio itself.

    Returns:
        The heading, e.g. ``1. COMM 1 · ARC-210``.
    """
    if layout_radio is not None and layout_radio.kneeboard_title:
        name = layout_radio.kneeboard_title
    elif spec is not None and spec.name:
        set_name, _, model = spec.name.partition(":")
        name = f"{set_name.strip()} · {model.strip()}" if model.strip() else set_name.strip()
    else:
        name = radio.title or radio.name
    return f"{index}. {name}"


def _radio_band(spec: RadioSpec | None) -> str:
    """The band a radio tunes, from its lowest to its highest frequency.

    Args:
        spec: The radio's specs entry, if known.

    Returns:
        ``225–399.975 MHz``, or "" when the specs give no range.
    """
    if spec is None or not spec.ranges:
        return ""
    low = min(frequency_range.min_mhz for frequency_range in spec.ranges)
    high = max(frequency_range.max_mhz for frequency_range in spec.ranges)
    return f"{low:g}–{high:g} MHz"


def _kneeboard_blocks(unit_type: str, preset: PresetDefinition) -> list[KneeboardBlock]:
    """The radio blocks of a preset, in the physical order the injector writes them.

    Args:
        unit_type: The concrete DCS unit type the preset was injected into.
        preset: The injected preset.

    Returns:
        One block per radio that has at least one row.
    """
    specs = get_radios(unit_type) or []
    layout = get_radio_layout(_load_radio_layouts(), unit_type)
    blocks: list[KneeboardBlock] = []
    for index, radio in enumerate(preset.radios.values(), start=1):
        rows = _kneeboard_rows(radio)
        if not rows:
            continue
        spec = specs[index - 1] if index <= len(specs) else None
        layout_radio = layout.radios.get(index) if layout is not None else None
        blocks.append(
            KneeboardBlock(
                title=_radio_heading(index, spec, layout_radio, radio),
                band=_radio_band(spec),
                show_mod=len({channel.mod or 0 for channel in radio.channels}) > 1,
                rows=rows,
            )
        )
    return blocks


def _paginate_blocks(
    blocks: list[KneeboardBlock], column_height: int = _COLUMN_H
) -> list[list[list[KneeboardSegment]]]:
    """Flow radio blocks into pages of two columns.

    A block that does not fit in what is left of a column moves whole to the next one when it fits
    there; only a block taller than a column is split, its next segment marked ``continued``. A
    block never starts at the foot of a column with fewer than :data:`_MIN_ROWS_AT_FOOT` rows.

    Args:
        blocks: The blocks, in order.
        column_height: The height of a column, in pixels.

    Returns:
        Pages, each a list of two columns, each a list of segments.
    """
    full_column = (column_height - _BLOCK_HEAD_H) // _ROW_H
    pages: list[list[list[KneeboardSegment]]] = [[[], []]]
    column, used = 0, 0
    for block in blocks:
        rows = list(block.rows)
        continued = False
        while rows:
            room = (column_height - used - _BLOCK_HEAD_H) // _ROW_H
            fits_elsewhere = used > 0 and len(rows) <= full_column
            if room < min(_MIN_ROWS_AT_FOOT, len(rows)) or (room < len(rows) and fits_elsewhere):
                column, used = column + 1, 0
                if column == 2:
                    pages.append([[], []])
                    column = 0
                continue
            taken, rows = rows[:room], rows[room:]
            pages[-1][column].append(KneeboardSegment(block, taken, continued))
            used += _BLOCK_HEAD_H + len(taken) * _ROW_H + _BLOCK_GAP
            continued = True
    return pages


def _page_path(unit_type: str, suffix: str, page: int) -> str:
    """The kneeboard path of one page: ``presets[-<coalition>].png``, then ``…_<n>.png`` for the next ones.

    ``_`` sorts after ``.``, so ``presets_2.png`` comes after ``presets.png`` in a name-ordered folder.

    Args:
        unit_type: The DCS unit type, ``/`` and ``\\`` replaced to make a folder name.
        suffix: ``-<coalition>`` when the type flies for both sides, else "".
        page: The 1-based page number.

    Returns:
        The path inside the ``.miz``.
    """
    safe_type = unit_type.replace("/", "_").replace("\\", "_")
    page_suffix = "" if page == 1 else f"_{page}"
    return f"KNEEBOARD/{safe_type}/IMAGES/presets{suffix}{page_suffix}.png"


def _load_fonts() -> dict[str, FreeTypeFont]:
    """Load the page fonts: Arial, or Pillow's embedded font (which has the accented letters) without it.

    Returns:
        The fonts by role, at the sizes of :data:`_FONT_SIZES`.
    """
    fonts: dict[str, FreeTypeFont] = {}
    for role, size in _FONT_SIZES.items():
        try:
            fonts[role] = ImageFont.truetype("arialbd.ttf" if role in _BOLD_FONTS else "arial.ttf", size)
        except OSError:
            fonts[role] = cast(FreeTypeFont, ImageFont.load_default(size))
    return fonts


def _draw_target(draw: ImageDraw.ImageDraw, center: tuple[float, float], size: float, ink: Any, width: int) -> None:
    """Draw a circle inscribed in a square, with its cross: both read true only in a 2:3 window.

    Args:
        draw: The page being drawn.
        center: The target's centre, in pixels.
        size: The square's side, in pixels.
        ink: The line colour.
        width: The line width, in pixels.
    """
    x, y = center
    half = size / 2
    draw.rectangle([x - half, y - half, x + half, y + half], outline=ink, width=width)
    draw.ellipse([x - half, y - half, x + half, y + half], outline=ink, width=width)
    draw.line([x - half, y, x + half, y], fill=ink, width=max(1, width // 2))
    draw.line([x, y - half, x, y + half], fill=ink, width=max(1, width // 2))


def _draw_header(draw: ImageDraw.ImageDraw, fonts: dict[str, FreeTypeFont], title: str, subtitle: str) -> None:
    """Draw the dark band at the top of a page, with its title and subtitle.

    Args:
        draw: The page being drawn.
        fonts: The page fonts by role.
        title: The large text (the aircraft's name).
        subtitle: The line under it.
    """
    draw.rectangle([0, 0, _PAGE_W, _MARGIN + _HEADER_H - 20], fill=_HEADER_BG)
    draw.text((_HEADER_TEXT_X, _MARGIN + 10), title, font=fonts["title"], fill="white", anchor="lt")
    draw.text((_HEADER_TEXT_X, _MARGIN + 90), subtitle, font=fonts["subtitle"], fill=_HEADER_SUBTITLE, anchor="lt")


def _encode(image: Image.Image) -> io.BytesIO:
    """Encode a page as an optimised 256-colour PNG.

    In full colour the Caucasus OT's 95 pages weighed 17 MB, which doubled its ``.miz`` (2026-10-18);
    the page holds flat fills and anti-aliased text, and a 256-colour palette brings it from 230 kB
    to 97 kB with no visible change.

    Args:
        image: The page.

    Returns:
        The PNG buffer, rewound.
    """
    buffer = io.BytesIO()
    image.quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(buffer, format="PNG", optimize=True)
    buffer.seek(0)
    return buffer


def render_calibration_page() -> io.BytesIO:
    """Render the shared calibration page: a square grid and three targets the pilot makes round.

    Returns:
        The PNG buffer.
    """
    fonts = _load_fonts()
    image = Image.new("RGB", KNEEBOARD_PAGE_SIZE, _PAPER)
    draw = ImageDraw.Draw(image)
    _draw_header(
        draw,
        fonts,
        t("presets_injector.kneeboard.calibration.title"),
        t("presets_injector.kneeboard.calibration.subtitle"),
    )
    cell = 128
    left = (_PAGE_W - (_PAGE_W - 2 * _MARGIN) // cell * cell) // 2
    top = _BODY_TOP + 30
    bottom = top + (_PAGE_H - 420 - top) // cell * cell
    for x in range(left, _PAGE_W - left + 1, cell):
        draw.line([x, top, x, bottom], fill=_RULE, width=2)
    for y in range(top, bottom + 1, cell):
        draw.line([left, y, _PAGE_W - left, y], fill=_RULE, width=2)
    for size in (1024, 640, 256):
        _draw_target(draw, (_PAGE_W // 2, (top + bottom) // 2), size, _INK, width=6)
    for line_index, key in enumerate(("line1", "line2", "line3")):
        text = t(f"presets_injector.kneeboard.calibration.{key}")
        font = fonts["calibration"] if line_index else fonts["calibration_lead"]
        draw.text((_PAGE_W // 2, bottom + 60 + line_index * 56), text, font=font, fill=_INK, anchor="mt")
    draw.text(
        (_PAGE_W // 2, _PAGE_H - _MARGIN),
        t("presets_injector.kneeboard.calibration.footer"),
        font=fonts["footer"],
        fill=_MUTED,
        anchor="mb",
    )
    return _encode(image)


class RadioPresetsImageGenerator:
    """Render the presets kneeboard pages of the injected (coalition, type) pairs."""

    def __init__(self, preset_collections: dict[str, PresetCollection]) -> None:
        self.preset_collections = preset_collections
        self._fonts: dict[str, FreeTypeFont] | None = None

    def get_fonts(self) -> dict[str, FreeTypeFont]:
        """The page fonts by role, loaded once.

        Returns:
            The fonts by role.
        """
        if self._fonts is None:
            self._fonts = _load_fonts()
        return self._fonts

    def generate_type_images(self, injected: dict[tuple[str, str], PresetDefinition]) -> dict[str, io.BytesIO]:
        """Render the kneeboard pages of each injected (coalition, aircraft type) (ADR 0012).

        Pages go in the type's DCS folder, ``KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png``,
        coalition-suffixed only when the same type is injected for both coalitions; a preset that
        overflows one page continues on ``presets[-<coalition>]_2.png``.

        Args:
            injected: The presets actually injected, keyed by (coalition, concrete unit_type).

        Returns:
            Mapping of kneeboard-relative path -> PNG buffer.
        """
        coalitions_by_type: dict[str, set[str]] = {}
        for coalition, unit_type in injected:
            coalitions_by_type.setdefault(unit_type, set()).add(coalition)

        images: dict[str, io.BytesIO] = {}
        for (coalition, unit_type), preset in injected.items():
            blocks = _kneeboard_blocks(unit_type, preset)
            if not blocks:
                continue
            pages = _paginate_blocks(blocks)
            has_priority = any(
                row.channel is not None and row.channel.priority is not None for block in blocks for row in block.rows
            )
            suffix = f"-{coalition}" if len(coalitions_by_type[unit_type]) > 1 else ""
            for page_number, columns in enumerate(pages, start=1):
                image = self._draw_page(unit_type, coalition, columns, page_number, len(pages), has_priority)
                images[_page_path(unit_type, suffix, page_number)] = _encode(image)
        return images

    def _draw_page(
        self,
        unit_type: str,
        coalition: str,
        columns: list[list[KneeboardSegment]],
        page_number: int,
        page_count: int,
        has_priority: bool,
    ) -> Image.Image:
        """Draw one presets page: header, the two columns of radio blocks, footer.

        Args:
            unit_type: The DCS unit type the page is for.
            coalition: The coalition it was injected for.
            columns: The page's two columns of segments.
            page_number: This page's 1-based number.
            page_count: How many pages the preset takes.
            has_priority: Whether a channel of the preset has a priority, which brings the legend.

        Returns:
            The page.
        """
        fonts = self.get_fonts()
        image = Image.new("RGB", KNEEBOARD_PAGE_SIZE, _PAPER)
        draw = ImageDraw.Draw(image)
        _draw_header(draw, fonts, get_aircraft_name(unit_type) or unit_type, t("presets_injector.kneeboard.subtitle"))
        badge = coalition.upper()
        badge_w = draw.textlength(badge, font=fonts["badge"]) + 48
        badge_x = _PAGE_W - _MARGIN - badge_w
        draw.rounded_rectangle(
            [badge_x, _MARGIN + 14, _PAGE_W - _MARGIN, _MARGIN + 70],
            radius=28,
            fill=_COALITION_BG.get(coalition, _MUTED),
        )
        draw.text((badge_x + badge_w / 2, _MARGIN + 42), badge, font=fonts["badge"], fill="white", anchor="mm")

        for column_index, segments in enumerate(columns):
            x = _MARGIN + column_index * (_COLUMN_W + _GUTTER)
            y = _BODY_TOP
            for segment in segments:
                y = self._draw_segment(draw, x, y, segment)

        if has_priority:
            legend = t("presets_injector.kneeboard.priority_legend")
            draw.text((_MARGIN, _PAGE_H - _MARGIN), legend, font=fonts["footer"], fill=_MUTED, anchor="lb")
        footer = t("presets_injector.kneeboard.page", unit_type=unit_type, page=page_number, count=page_count)
        draw.text((_FOOTER_RIGHT_X, _PAGE_H - _MARGIN), footer, font=fonts["footer"], fill=_MUTED, anchor="rb")
        return image

    def _draw_segment(self, draw: ImageDraw.ImageDraw, x: int, y: int, segment: KneeboardSegment) -> int:
        """Draw one segment of a radio block at (x, y).

        Args:
            draw: The page being drawn.
            x: The column's left edge.
            y: The segment's top.
            segment: The segment to draw.

        Returns:
            The y where the next segment starts.
        """
        fonts = self.get_fonts()
        block = segment.block
        right = x + _COLUMN_W
        draw.rounded_rectangle([x, y, right, y + _BLOCK_TITLE_H], radius=10, fill=_RADIO_TITLE_BG)
        draw.rectangle([x, y + _BLOCK_TITLE_H - 10, right, y + _BLOCK_TITLE_H], fill=_RADIO_TITLE_BG)
        title = block.title
        if segment.continued:
            title = f"{title}  {t('presets_injector.kneeboard.continued')}"
        middle = y + _BLOCK_TITLE_H // 2
        draw.text((x + 20, middle), title, font=fonts["radio"], fill="white", anchor="lm")
        if block.band and not segment.continued:
            draw.text((right - 20, middle), block.band, font=fonts["band"], fill=_RADIO_BAND_TEXT, anchor="rm")
        y += _BLOCK_TITLE_H

        mod_w = _MOD_W if block.show_mod else 0
        name_x = x + _CH_W
        freq_right = right - mod_w - 18
        middle = y + _COL_HEAD_H // 2
        draw.rectangle([x, y, right, y + _COL_HEAD_H], fill=_COLUMN_HEAD_BG)
        draw.text((x + _CH_W // 2, middle), "CH", font=fonts["column"], fill=_MUTED, anchor="mm")
        name_header = t("presets_injector.kneeboard.column.name")
        draw.text((name_x + 16, middle), name_header, font=fonts["column"], fill=_MUTED, anchor="lm")
        draw.text((freq_right, middle), "MHz", font=fonts["column"], fill=_MUTED, anchor="rm")
        if block.show_mod:
            draw.text((right - mod_w // 2, middle), "MOD", font=fonts["column"], fill=_MUTED, anchor="mm")
        rows_top = y
        y += _COL_HEAD_H

        for row_index, row in enumerate(segment.rows):
            self._draw_row(draw, x, y, row, row_index % 2 == 1, mod_w)
            y += _ROW_H
            draw.line([x, y, right, y], fill=_RULE)
        draw.line([name_x, rows_top, name_x, y], fill=_RULE)
        return y + _BLOCK_GAP

    def _draw_row(self, draw: ImageDraw.ImageDraw, x: int, y: int, row: KneeboardRow, shaded: bool, mod_w: int) -> None:
        """Draw one channel row: CH cell (filled with the channel's colour), name, frequency, modulation.

        Args:
            draw: The page being drawn.
            x: The column's left edge.
            y: The row's top.
            row: The row to draw.
            shaded: Whether the row gets the zebra background.
            mod_w: The width of the modulation column, 0 when the radio has none.
        """
        fonts = self.get_fonts()
        right = x + _COLUMN_W
        name_x = x + _CH_W
        freq_right = right - mod_w - 18
        freq_w = draw.textlength("399.975", font=fonts["freq"])
        middle = y + _ROW_H // 2
        channel = row.channel
        if shaded:
            draw.rectangle([x, y, right, y + _ROW_H], fill=_ZEBRA)
        if channel is None:
            draw.text((x + _CH_W // 2, middle), row.label, font=fonts["ch"], fill=_MUTED, anchor="mm")
            draw.text((name_x + 16, middle), "—", font=fonts["name"], fill=_RULE, anchor="lm")
            return
        if channel.priority is not None:
            draw.rectangle([name_x, y, right, y + _ROW_H], fill=_PRIORITY_HIGHLIGHT)
        ch_text_color: Any = _INK
        if channel.color and (rgb := _resolve_kneeboard_color(channel.color)) is not None:
            draw.rectangle([x, y, name_x, y + _ROW_H], fill=rgb)
            ch_text_color = _contrast_text_color(rgb)
        draw.text((x + _CH_W // 2, middle), row.label, font=fonts["ch"], fill=ch_text_color, anchor="mm")

        marker_w = 0.0
        if channel.priority is not None:
            marker = f"P{channel.priority}"
            marker_w = draw.textlength(marker, font=fonts["column"]) + 16
            draw.text((freq_right - freq_w - 16, middle), marker, font=fonts["column"], fill=_INK, anchor="rm")
        name = channel.title or ""
        max_name_w = freq_right - freq_w - marker_w - name_x - 40
        if draw.textlength(name, font=fonts["name"]) > max_name_w:
            while name and draw.textlength(f"{name}…", font=fonts["name"]) > max_name_w:
                name = name[:-1]
            name = f"{name}…"
        draw.text((name_x + 16, middle), name, font=fonts["name"], fill=_INK, anchor="lm")
        draw.text((freq_right, middle), _format_freq(channel.freq), font=fonts["freq"], fill=_INK, anchor="rm")
        if mod_w:
            modulation = "FM" if channel.mod == 1 else "AM"
            draw.text((right - mod_w // 2, middle), modulation, font=fonts["mod"], fill=_MUTED, anchor="mm")
