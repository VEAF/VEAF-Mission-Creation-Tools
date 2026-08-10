"""
Worker module for the VEAF Presets Injector Package.
"""

import copy
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from mission_tools import Group, write_miz
from veaf_libs.group_injector_worker import GroupInjectorWorker
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context

from .presets_manager import PresetDefinition, PresetsManager
from .radio_frequency_validator import (
    ChannelFrequency,
    FrequencyIssue,
    collect_invalid_channel_frequencies,
    fits_human_radio,
    get_human_radio,
    get_valid_ranges,
    is_kneeboard_only,
    is_strict,
    validate_frequencies,
    validate_frequency,
    warn_invalid_channel_frequencies,
)

# FIX-DYNSLOT-RADIO-UNITS: a group's primary `frequency` is a VHF/UHF (or FM)
# radio. Anything below this is an ADF/HF channel (kHz, e.g. the Yak-52 ARK-15M
# at 0.625 MHz) that must never be promoted to the primary radio — DCS rejects
# the mission with "Fréquence invalide 0.625 MHz". Lowest real primary radio is
# FM at 30 MHz; ADF (≤ ~1.8 MHz) and HF sit well below.
_MIN_PRIMARY_RADIO_MHZ = 30.0


def _is_valid_primary_frequency(freq_mhz: float) -> bool:
    """Whether *freq_mhz* may be a group's primary radio frequency.

    A primary radio is VHF/UHF/FM; anything below ``_MIN_PRIMARY_RADIO_MHZ`` is an
    ADF/HF (kHz-range) channel that DCS rejects as a primary frequency. Used by the
    promotion guard, which has no per-aircraft context.
    """
    return freq_mhz >= _MIN_PRIMARY_RADIO_MHZ


def _is_valid_primary_frequency_for_unit(unit_type: str | None, freq_mhz: float) -> bool:
    """Whether *freq_mhz* may be *unit_type*'s primary radio frequency (build-time safety net).

    Like ``_is_valid_primary_frequency`` but spec-aware: a sub-VHF frequency is still
    valid when the aircraft's genuine primary radio is HF and DCS strictly validates it
    (e.g. the MiG-15bis RSI-6K at 3.75–5.0 MHz). DCS itself writes and accepts that
    frequency on extract, so the blanket floor would be a false positive. Aircraft DCS
    does not strictly validate (Yak-52 ARK-15M, Ka-50 ARK-22…) keep the floor, so an ADF
    channel mistakenly promoted to the primary is still caught.
    """
    if _is_valid_primary_frequency(freq_mhz):
        return True
    if unit_type is None:
        return False
    return is_strict(unit_type) and bool(validate_frequency(unit_type, freq_mhz))


@dataclass
class _PendingFreqWarning:
    """Aggregated data for a deferred radio-frequency warning keyed by unit_type."""

    group_names: list[str] = field(default_factory=list)
    channels: list[ChannelFrequency] = field(default_factory=list)
    coalition: str = "blue"
    aircraft_category: str = "plane"


class PresetsInjectorWorker(GroupInjectorWorker):
    """
    Worker class that provides presets injection features.
    """

    def __init__(
        self,
        presets_file: Path | None,
        input_mission: Path | None,
        output_mission: Path | None,
        generate_kneeboards: bool = True,
    ):
        self.presets_file = presets_file
        # When False, radio presets are still injected but no kneeboard PNG is
        # generated (FEAT-PRESETS-KNEEBOARD-TOGGLE / pipeline.presets.kneeboards).
        self.generate_kneeboards = generate_kneeboards
        self.groups: dict[str, Group] = {}
        self.presets_manager: PresetsManager = PresetsManager()
        # ADR 0012: presets actually injected, keyed by (coalition, concrete
        # unit_type) — drives one kneeboard PNG per aircraft type.
        self._injected_presets: dict[tuple[str, str], PresetDefinition] = {}
        # Pending frequency warnings keyed by unit_type; aggregated before emission.
        self._pending_freq_warnings: dict[str, _PendingFreqWarning] = {}
        # Resolved frequency issues populated after process_groups(); used by generate_validation_report().
        self._freq_issues: list[FrequencyIssue] = []
        # unit_type → channel-1 frequency that was *not* promoted to the group's primary
        # because it falls outside the airframe's HumanRadio range; reported once per type.
        self._skipped_primary_promotions: dict[str, float] = {}
        super().__init__(config_file=presets_file, input_mission=input_mission, output_mission=output_mission)

    def load_config(self) -> Any:
        """Load configuration from YAML file."""
        presets_manager = PresetsManager()
        try:
            if self.presets_file:
                presets_manager.read_yaml(self.presets_file)
        except Exception as e:
            logger.error(
                t("presets_injector.error.load_config", path=self.presets_file, error=str(e)),
                exception_type=RuntimeError,
            )
        self.presets_manager = presets_manager
        return presets_manager

    def add_group(self, group: Group) -> None:
        if group.name:
            self.groups[group.name] = group

    def process_group(self, group: Group) -> None:
        """Collect the group; actual preset injection happens in process_groups()."""
        self.add_group(group)

    def _drop_out_of_range_channels(self, group: Group, preset_definition: PresetDefinition) -> PresetDefinition:
        """Return a copy of the preset with channels out of range for the aircraft removed.

        DCS refuses to save a mission if *any* radio channel is outside the
        aircraft's valid frequency ranges. Rather than overwrite a partially
        compatible radio with an unsaveable set, the out-of-range channels are
        dropped and the in-range ones kept. Empty presets and unknown aircraft
        (no spec data) are returned unchanged.

        Args:
            group: The aircraft group being processed.
            preset_definition: The preset resolved for that group.

        Returns:
            The preset to inject — the original when nothing is out of range, else
            a filtered copy.
        """
        if preset_definition == PresetDefinition.EMPTY or not group.unit_type:
            return preset_definition
        if get_valid_ranges(group.unit_type) is None:
            return preset_definition
        all_freqs = [
            ch.freq
            for radio in preset_definition.radios.values()
            for ch in radio.channels
            if isinstance(ch.freq, (int, float))
        ]
        invalid = set(validate_frequencies(group.unit_type, all_freqs))
        if not invalid:
            return preset_definition
        filtered = copy.deepcopy(preset_definition)
        for radio in filtered.radios.values():
            radio.channels = [
                ch for ch in radio.channels if not (isinstance(ch.freq, (int, float)) and ch.freq in invalid)
            ]
        return filtered

    def process_units(self, group: Group, preset_definition: PresetDefinition) -> int:
        nb_units_processed = 0
        # Drop channels DCS would reject for this aircraft (keeps the mission saveable);
        # the original preset is still used below to report which channels were dropped.
        inject_preset = self._drop_out_of_range_channels(group, preset_definition)
        if units := group.group_dcs.get("units", {}):
            for unit in [u for u in units if u.get("skill", "") in ["Client", "Player"]]:
                nb_units_processed += 1
                unit["Radio"] = inject_preset.to_dict()
                if inject_preset == PresetDefinition.EMPTY:
                    if "frequency" in group.group_dcs:
                        del group.group_dcs["frequency"]
                elif first_freq := inject_preset.get_freq_of_first_channel_of_first_radio():
                    # FM-primary radios (Gazelle, Ka-50…) have HumanRadio in VHF/UHF range:
                    # injecting the FM channel freq would make the ME flag it as invalid.
                    # Likewise an ADF/HF channel (sub-VHF, e.g. ARK-15M 0.625 MHz) must
                    # not become the primary frequency — DCS rejects it (FIX-DYNSLOT-RADIO-UNITS).
                    # Finally the channel must fall inside the airframe's own HumanRadio range,
                    # which can be far narrower than its preset range (FW-190: 38.4–42.4 MHz
                    # primary vs 38–156 MHz presets — FIX-PRIMARY-FREQ-HUMANRADIO). When it does
                    # not, the key is left alone so the group keeps DCS's valid default.
                    first_radio_type = next(iter(inject_preset.radios.values())).radio_type
                    if first_radio_type != "fm" and _is_valid_primary_frequency(first_freq):
                        unit_type = group.unit_type
                        if unit_type and not fits_human_radio(unit_type, first_freq):
                            self._skipped_primary_promotions[unit_type] = first_freq
                        else:
                            group.group_dcs["frequency"] = first_freq

        if preset_definition != PresetDefinition.EMPTY and group.unit_type:
            channel_freqs = [
                ChannelFrequency(
                    freq_mhz=ch.freq,
                    radio_key=radio.name,
                    radio_collection=radio.collection_name or "",
                    radio_title=radio.title or radio.name,
                    channel=ch.number,
                    channel_title=ch.title or "",
                )
                for radio in preset_definition.radios.values()
                for ch in radio.channels
                if isinstance(ch.freq, (int, float))
            ]
            # Collect instead of warning immediately; emit aggregated per unit_type later.
            # Merge channel_freqs so subsequent groups with the same unit_type don't lose their invalids.
            key = group.unit_type
            if key not in self._pending_freq_warnings:
                self._pending_freq_warnings[key] = _PendingFreqWarning(
                    coalition=group.coalition or "blue",
                    aircraft_category=group.aircraft_type or "plane",
                )
            entry = self._pending_freq_warnings[key]
            entry.group_names.append(group.name or "")
            for ch in channel_freqs:
                if ch not in entry.channels:
                    entry.channels.append(ch)

        return nb_units_processed

    def _preset_radio_compatible(self, group: Group, preset_definition: PresetDefinition) -> bool:
        """Whether the resolved preset fits the aircraft's radio hardware.

        Returns ``False`` only when *every* preset frequency is out of range for a
        known aircraft — e.g. a UHF/VHF preset resolved (via an ``all`` fallback)
        for a Yak-52, whose only radio is the sub-MHz ARK-15M. Injecting such a
        preset would overwrite the correct radio with frequencies the DCS Mission
        Editor refuses to save, so the injection is skipped and the original radio
        kept. Empty presets and unknown aircraft (no spec data) are always
        treated as compatible.

        Args:
            group: The aircraft group being processed.
            preset_definition: The preset resolved for that group.

        Returns:
            ``True`` if at least one preset frequency is valid (or compatibility
            cannot be determined), ``False`` if the preset is wholly incompatible.
        """
        if preset_definition == PresetDefinition.EMPTY or not group.unit_type:
            return True
        if get_valid_ranges(group.unit_type) is None:
            return True
        freqs = [
            ch.freq
            for radio in preset_definition.radios.values()
            for ch in radio.channels
            if isinstance(ch.freq, (int, float))
        ]
        if not freqs:
            return True
        return len(validate_frequencies(group.unit_type, freqs)) < len(freqs)

    def process_groups(self, silent: bool = False) -> None:
        """Inject presets into all human-piloted groups."""
        if not silent:
            logger.info(tn("presets_injector.processing_groups", len(self.groups)))

        nb_units_processed = 0
        nb_groups_without_preset = 0
        for group in [g for g in self.groups.values() if g.human_pilot]:
            if preset_definition := self.presets_manager.get_radios_for(
                coalition=group.coalition,
                aircraft_type=group.aircraft_type,
                unit_type=group.unit_type if group.unit_type is not None else "all",
            ):
                if not self._preset_radio_compatible(group, preset_definition):
                    logger.warning(
                        t(
                            "presets_injector.skip_incompatible_radio",
                            group=group.name,
                            unit_type=group.unit_type,
                        )
                    )
                    continue
                preset_definition.used_in_mission = True
                # ADR 0012: record the injected preset per (coalition, concrete
                # unit_type) so the kneeboard step renders one page per type.
                if group.unit_type:
                    self._injected_presets[(group.coalition, group.unit_type)] = preset_definition
                if is_kneeboard_only(group.unit_type or ""):
                    # Flaming Cliffs: the plate is recorded above, and that is the whole deliverable.
                    # These airframes expose no settable radio — 110 FC3 player slots across 40 real
                    # VEAF missions carry no `Radio` table, against 2105 non-FC3 slots that do — so
                    # writing one would put data in the mission that DCS has nowhere to read
                    # (FIX-RADIO-LAYOUT-GAPS ticket 03, David's decision of 2026-08-10). Their pilots
                    # dial these frequencies into SRS by hand, off the plate.
                    logger.debug(
                        f"Kneeboard-only preset '{preset_definition}' for group '{group.name}' "
                        f"(type: {group.unit_type}): plate rendered, nothing written into the mission"
                    )
                    continue
                logger.debug(
                    f"Injecting preset '{preset_definition}' into group '{group.name}' (type: {group.unit_type}, aircraft: {group.aircraft_type}, country: {group.country}, coalition: {group.coalition})"
                )
                group.group_dcs["radioSet"] = preset_definition != PresetDefinition.EMPTY
                group.group_dcs["communication"] = False
                nb_units_processed += self.process_units(group, preset_definition)
            else:
                nb_groups_without_preset += 1

        if not silent and self._skipped_primary_promotions:
            details = ", ".join(
                f"{unit_type} ({freq} MHz, primary limited to {hr.min_mhz}–{hr.max_mhz} MHz)"
                if (hr := get_human_radio(unit_type))
                else f"{unit_type} ({freq} MHz)"
                for unit_type, freq in sorted(self._skipped_primary_promotions.items())
            )
            logger.detail(t("presets_injector.primary_freq_not_promoted", details=details))

        if not silent:
            logger.detail(tn("presets_injector.injected", nb_units_processed))
            # A bare "0 injected" reads like a failure; say how many human groups had no
            # matching preset in presets.yaml so the outcome is unambiguous.
            if nb_groups_without_preset:
                logger.detail(tn("presets_injector.no_preset", nb_groups_without_preset))

        # FIX-DYNSLOT-RADIO-UNITS: a primary `frequency` below the VHF floor
        # (ADF/HF, e.g. an ARK-15M 0.625 MHz mistakenly set as the radio) makes
        # DCS refuse to save the mission ("Fréquence invalide 0.625 MHz"). Fail
        # the build now, with the offending groups, rather than shipping a .miz
        # the Mission Editor rejects.
        invalid_primary = [
            (g.name, freq)
            for g in self.groups.values()
            if g.human_pilot
            and isinstance((freq := g.group_dcs.get("frequency")), (int, float))
            and not _is_valid_primary_frequency_for_unit(g.unit_type, freq)
        ]
        if invalid_primary:
            details = ", ".join(f"{name} ({freq} MHz)" for name, freq in invalid_primary)
            logger.error(
                t("presets_injector.invalid_primary_frequency", min=_MIN_PRIMARY_RADIO_MHZ, details=details),
                exception_type=ValueError,
            )

        # Emit one warning per unit_type, listing all affected groups together.
        if self._pending_freq_warnings:
            warned_unit_types: dict[str, _PendingFreqWarning] = {}
            for unit_type, entry in self._pending_freq_warnings.items():
                if warn_invalid_channel_frequencies(
                    group_names=entry.group_names,
                    unit_type=unit_type,
                    channels=entry.channels,
                    coalition=entry.coalition,
                    aircraft_category=entry.aircraft_category,
                ) and is_strict(unit_type):
                    warned_unit_types[unit_type] = entry
            if warned_unit_types:
                yaml_lines = []
                for unit_type, entry in warned_unit_types.items():
                    yaml_lines.extend(
                        [
                            f"      {entry.coalition}:",
                            f"        {entry.aircraft_category}:",
                            f"          {unit_type}: none",
                        ]
                    )
                yaml_block = "\n".join(yaml_lines)
                logger.warning(t("presets_injector.freq_warn.disable_tip", yaml_block=yaml_block))
            # Collect all issues (strict + non-strict) for the validation report before clearing.
            self._freq_issues = sorted(
                (
                    issue
                    for unit_type, entry in self._pending_freq_warnings.items()
                    if (
                        issue := collect_invalid_channel_frequencies(
                            group_names=entry.group_names,
                            unit_type=unit_type,
                            channels=entry.channels,
                            coalition=entry.coalition,
                            aircraft_category=entry.aircraft_category,
                        )
                    )
                    is not None
                ),
                key=lambda i: (not i.strict, i.unit_type),
            )
            self._pending_freq_warnings.clear()

    def collect_freq_issues(self) -> list[FrequencyIssue]:
        """Return the resolved frequency issues collected during the last process_groups() call.

        Issues are populated during process_groups() before the pending warnings are cleared,
        so this method is safe to call after work() has completed.

        Returns:
            List of FrequencyIssue, strict types first, then informational, both sorted by unit_type.
        """
        return self._freq_issues

    def generate_validation_report(self, output_path: Path) -> int:
        """Write a Markdown validation report of all radio frequency issues to output_path.

        Reports every aircraft type with out-of-range preset frequencies, split into two sections:
        - Critical (dcs_rejects_on_load): DCS will reject the mission at load.
        - Informational: DCS stores but ignores the frequencies.

        Args:
            output_path: Destination .md file.

        Returns:
            Total number of issues found (0 means all presets are valid).
        """
        from datetime import date

        issues = self.collect_freq_issues()
        strict_issues = [i for i in issues if i.strict]
        info_issues = [i for i in issues if not i.strict]

        lines: list[str] = [
            t("presets_injector.report.title"),
            "",
            f"{t('presets_injector.report.generated', date=date.today().isoformat())}  ",
            f"{t('presets_injector.report.presets_file', path=self.presets_file)}  ",
            t("presets_injector.report.mission", path=self.input_mission),
            "",
        ]

        def _render_issue(issue: FrequencyIssue) -> list[str]:
            groups_str = ", ".join(f"`{g}`" for g in issue.group_names)
            ranges_str = ", ".join(f"{r.min_mhz}–{r.max_mhz} MHz ({r.modulation})" for r in issue.valid_ranges)
            block = [
                f"### {issue.unit_type}",
                f"{t('presets_injector.report.groups', groups=groups_str)}  ",
                t("presets_injector.report.valid_ranges", ranges=ranges_str),
                "",
                t("presets_injector.report.table_header"),
                "|---------|-------|-----------------|------------|-------|",
            ]
            for ch in issue.invalid_channels:
                block.append(
                    f"| {ch.channel} | {ch.channel_title or '—'} | {ch.freq_mhz} | {ch.radio_collection} | {ch.radio_key} |"
                )
            block += [
                "",
                t("presets_injector.report.silence_hint"),
                "```yaml",
                "presets_assignments:",
                f"  {issue.coalition}:",
                f"    {issue.aircraft_category}:",
                f"      {issue.unit_type}: none",
                "```",
                "",
            ]
            return block

        if strict_issues:
            lines += [
                t("presets_injector.report.section_critical"),
                "",
                tn("presets_injector.report.affected_count", len(strict_issues)),
                "",
            ]
            for issue in strict_issues:
                lines += _render_issue(issue)

        if info_issues:
            lines += [
                t("presets_injector.report.section_info"),
                "",
                tn("presets_injector.report.affected_count", len(info_issues)),
                "",
            ]
            for issue in info_issues:
                lines += _render_issue(issue)

        if not issues:
            lines += [t("presets_injector.report.all_valid"), ""]

        output_path.write_text("\n".join(lines), encoding="utf-8")
        logger.info(tn("presets_injector.validation_report.written", len(issues), path=output_path))
        return len(issues)

    def write_mission(self, silent: bool = False) -> None:
        """Write the mission file, including kneeboard pages if generated."""
        if not silent:
            logger.info(t("group_injector.writing_mission"))

        additional_files = {}
        if self.presets_manager.presets_images:
            # ADR 0012: keys are full per-type kneeboard paths
            # (KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png).
            for kneeboard_path, image in self.presets_manager.presets_images.items():
                additional_files[kneeboard_path] = image.getvalue()
            if not silent:
                logger.info(tn("presets_injector.kneeboard_pages", len(self.presets_manager.presets_images)))

        assert self.dcs_mission is not None
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission, additional_files=additional_files)

    def work(self, silent: bool = False) -> None:  # type: ignore[override]
        """Main work function."""
        with spinner_context(t("group_injector.spinner.reading", path=self.input_mission), silent=silent):
            self.read_mission(silent)

        assert self.dcs_mission is not None
        for group in self.dcs_mission.iter_groups():
            self.process_group(group)

        with spinner_context(t("presets_injector.spinner.processing_groups"), silent=silent):
            self.process_groups(silent)

        if self.generate_kneeboards:
            with spinner_context(t("presets_injector.spinner.generating_images"), silent=silent):
                self.presets_manager.generate_type_images(self._injected_presets, width=1200, height=None)

        with spinner_context(t("group_injector.spinner.writing"), silent=silent):
            self.write_mission(silent)
