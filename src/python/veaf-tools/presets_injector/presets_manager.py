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

import io
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar, cast

import yaml
from PIL import Image, ImageDraw, ImageFont
from PIL.ImageFont import FreeTypeFont
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

    def __init__(self, name_or_number: int | str, freq: float, title: str | None = None, mod: int | None = None):
        self.freq: float = freq
        self.title: str | None = title
        self.mod: int | None = mod

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
        self, name: str, title: str | None = None, misc_data: str | None = None, collection_name: str | None = None
    ):
        self.name: str = name
        self.title: str | None = title
        self.misc_data: str | None = misc_data
        self.collection_name: str | None = collection_name
        self.frequencies: dict[str, float] = {}

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
        freqs = data.get("freqs")
        if not freqs:
            logger.error(message=f"'freqs' is mandatory for ChannelDefinition {name}", exception_type=ValueError)
            return ChannelDefinition(name=name, title=title, misc_data=misc_data)
        result = ChannelDefinition(name=name, title=title, misc_data=misc_data)
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
        channel_definition = None
        if channel_alias:
            for channel_collection in channel_collections.values():
                if channel_alias in channel_collection.channel_definitions:
                    channel_definition = channel_collection.channel_definitions[channel_alias]
                    channel_title = channel_definition.title
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
        self.add_channel(Channel(name_or_number=channel_name, freq=channel_freq, title=channel_title, mod=channel_mod))  # type: ignore[arg-type]
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
            logger.error(message=f"'radios' is mandatory for PresetDefinition {name}", exception_type=ValueError)
            return PresetDefinition(name=name)
        result = PresetDefinition(name=name, title=data.get("title") or "")
        for radio_name, radio_alias in radios.items():
            for radio_collection in radio_collections.values():
                if radio_alias in radio_collection.radio_definitions:
                    radio_definition = radio_collection.radio_definitions[radio_alias]
                    break
            else:
                logger.error(
                    message=f"'radio_alias' {radio_alias} in class PresetDefinition {name} was not found in any RadioCollection",
                    exception_type=ValueError,
                )
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
        for item_name in data:
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
        for coalition, coalition_data in data.items():
            for aircraft_type, type_data in coalition_data.items():
                for unit_type, preset_definition_name in type_data.items():
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
            band = ROLE_BANDS[role]
            radio = RadioDefinition(name=f"channel_list_{coalition}_{role}", radio_type=band, title=role)
            skipped: list[str] = []
            for channel_name, channel_data in (channels_data or {}).items():
                if not radio.add_channel_from_dict(channel_name, channel_data, channel_collections, strict=False):
                    skipped.append(str(channel_name))
            role_lists[role] = radio
            if skipped:
                role_dropped[role] = skipped
        channel_lists[coalition] = role_lists
        if role_dropped:
            dropped[coalition] = role_dropped
    return channel_lists, dropped


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


def _classify_radio(ranges: list[FrequencyRange]) -> str | None:
    """Classify one physical radio's role band from its frequency ranges.

    Returns "uhf" or "vhf" when the radio is unambiguously dedicated to that
    sub-band, "ambiguous" when its ranges reach into both (common on digital
    combo radios like the ARC-210, or on single-range radios spanning both
    windows like the Mi-8MT's R-863 or a warbird's FuG16 — the packer falls back
    to physical position for the former, and this range naturally resolves to a
    single band for the latter two), or None when the radio never reaches above
    the FM ceiling (an FM radio, or an unrelated low-band set like an HF/ADF
    radio — see the packer's module docstring for how that degrades safely).
    """
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
    role_by_index: dict[int, str] = {}

    for index, band in enumerate(bands):
        if band == "uhf" and ROLE_PRIMARY_1 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_1
        elif band == "vhf" and ROLE_PRIMARY_2 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_2

    for index, band in enumerate(bands):
        if band != "ambiguous" or index in role_by_index:
            continue
        if ROLE_PRIMARY_1 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_1
        elif ROLE_PRIMARY_2 not in role_by_index.values():
            role_by_index[index] = ROLE_PRIMARY_2

    fm_role = ROLE_FM_SUPPLEMENT if len(role_by_index) >= 2 else ROLE_FM_SUBSTITUTE
    fm_indices = [index for index, band in enumerate(bands) if band is None and index not in role_by_index]
    if fm_indices:
        role_by_index[fm_indices[0]] = fm_role
        if len(fm_indices) >= 2:
            role_by_index[fm_indices[1]] = ROLE_FM_SECONDARY

    return role_by_index


def _channel_list_for_role(role_lists: dict[str, RadioDefinition], role: str) -> RadioDefinition | None:
    """Look up *role*'s channel list, defaulting fm_secondary to fm_supplement (ADR 0010)."""
    source = role_lists.get(role)
    if source is None and role == ROLE_FM_SECONDARY:
        source = role_lists.get(ROLE_FM_SUPPLEMENT)
    return source


def pack_preset_for_type(
    channel_lists: dict[str, dict[str, RadioDefinition]], coalition: str, unit_type: str
) -> "PresetDefinition | None":
    """Project a mission-maker's Channel lists onto one aircraft type's physical radios.

    This is the packer's default projection (ADR 0010), used when no explicit
    per-type _Radio layout_ entry exists (added by a later lot): each physical
    radio is assigned a role by :func:`_assign_roles_by_position`, then filled
    with that role's channel list. An aircraft with no primary radio at all
    (single-radio HF/ADF sets, e.g. the MiG-15bis or Yak-52) still gets an
    ``fm_substitute`` guess on its only radio; since that content will not be in
    range, the existing frequency validator drops it and reports the mismatch —
    a safe, actionable degradation rather than a crash, pending an explicit
    layout entry for that type.

    Args:
        channel_lists: Parsed Channel lists, coalition -> role -> RadioDefinition
            (from :func:`parse_channel_lists`).
        coalition: "blue" or "red".
        unit_type: DCS unit type string.

    Returns:
        A :class:`PresetDefinition` with one radio per resolvable physical slot,
        or None if the aircraft is unknown or no role list has any content for it.
    """
    role_lists = channel_lists.get(coalition)
    if not role_lists:
        return None
    radios = get_radios(unit_type)
    if not radios:
        return None

    role_by_index = _assign_roles_by_position(radios)
    if not role_by_index:
        return None

    resolved: list[RadioDefinition | None] = []
    for index in range(len(radios)):
        role = role_by_index.get(index)
        source = _channel_list_for_role(role_lists, role) if role else None
        resolved.append(source if source and source.channels else None)

    if all(source is None for source in resolved):
        return None
    last_usable = max(index for index, source in enumerate(resolved) if source is not None)
    if any(source is None for source in resolved[:last_usable]):
        # A gap before the last usable radio is ambiguous — packing it would
        # silently renumber a later radio to the wrong physical slot. Leave it
        # to an explicit layout entry rather than guess.
        return None

    preset = PresetDefinition(name=f"packed_{coalition}_{unit_type}")
    for index, source in enumerate(resolved[: last_usable + 1], start=1):
        assert source is not None
        radio = RadioDefinition(name=f"radio_{index}", radio_type=source.radio_type, title=source.title)
        for channel in source.channels:
            radio.add_channel(
                Channel(name_or_number=channel.number, freq=channel.freq, title=channel.title, mod=channel.mod)
            )
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

    def read_yaml(self, yaml_path: Path):
        try:
            with open(yaml_path) as file:
                data = yaml.safe_load(file)

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
            logger.error(message=f"YAML file not found: {yaml_path}", exception_type=FileNotFoundError)
        except yaml.YAMLError as e:
            logger.error(message=f"Error parsing YAML file {yaml_path}: {str(e)}", exception_type=ValueError)
        except Exception as e:
            logger.error(message=f"Error loading presets from {yaml_path}: {str(e)}", exception_type=RuntimeError)

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

    def generate_presets_images(self, width: int = 1200, height: int | None = None):
        generator = RadioPresetsImageGenerator(self.preset_collections, width=width, height=height)
        self.presets_images = generator.generate_presets_images()


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
            channel_number = f"{j + 1:02d}"
            channel_name = channel.title if channel is not None else ""
            channel_frequency = f"{channel.freq:.2f}" if channel is not None else ""

            row_y = self.header_y + self.row_height + j * self.row_height

            # Alternate background colors (light gray and white)
            bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
            self.draw.rectangle(
                [self.table_x, row_y, self.table_x + self.table_width, row_y + self.row_height], fill=bg_color
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
            self.draw.text((self.table_x + 10, row_y + 5), channel_number, fill="black", font=self.get_preset_font())

            # Draw channel name
            self.draw.text(
                (self.table_x + self.column_width_channel + 10, row_y + 5),
                channel_name or "",
                fill="black",
                font=self.get_preset_font(),
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

            # Draw title row with specific background color
            title_color = self.radio_colors[i] if i < len(self.radio_colors) else (200, 200, 200)  # Default gray
            self.draw.rectangle(
                [self.table_x, table_y, self.table_x + self.table_width, table_y + self.header_height], fill=title_color
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
        # Define background colors for each radio table
        self.radio_colors = [(255, 0, 0), (0, 128, 0), (255, 165, 0)]  # Red, Green, Orange

        # Calculate dimensions based on content
        self.row_height = 30
        self.header_height = 55
        self.margin_between_tables = 30  # Margin between tables
        self.side_margin = 50  # Margin on sides
        self.top_margin = 80  # Space for collection title
        bottom_margin = 50  # Margin at bottom

        # Compute the highest channel across all radios
        self.max_channels = 0
        for radio in preset_definition.radios.values():
            for channel in radio.channels:
                if channel.number and channel.number > self.max_channels:
                    self.max_channels = channel.number

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

    def generate_presets_images(self) -> dict[str, io.BytesIO]:
        """
        Generate a PNG image showing the radio presets in the preset_manager as three arrays
        displayed side by side, with the name and frequency columns in each, and the radio
        name as the title of each.

        Args:
            width: Width of the generated image in pixels (default: 1200)
            height: Height of the generated image in pixels (default: automatically calculated)
        """

        presets_images = {}

        # Browse the preset collection and generate an image for each
        for preset_collection in self.preset_collections.values():
            for preset_name, preset_definition in preset_collection.preset_definitions.items():
                self.radio_count = len(preset_definition.radios)

                if self.radio_count > 0 and preset_definition.used_in_mission:
                    self.draw_preset_image(preset_definition)

                    self.draw_radios_in_preset_image(preset_definition)

                    # Store the image in the dictionary with the preset collection name as key
                    img_buffer = io.BytesIO()
                    self.image.save(
                        img_buffer, format="PNG", optimize=True
                    )  # Use PNG with optimization for line art/text
                    img_buffer.seek(0)
                    presets_images[preset_name] = img_buffer

        return presets_images
