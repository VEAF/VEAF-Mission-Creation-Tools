"""
Worker module for the VEAF Presets Injector Package.
"""

from pathlib import Path
from typing import Any

from mission_tools import Group, write_miz
from veaf_libs.group_injector_worker import GroupInjectorWorker
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context

from .presets_manager import PresetDefinition, PresetsManager
from .radio_frequency_validator import ChannelFrequency, warn_invalid_channel_frequencies


class PresetsInjectorWorker(GroupInjectorWorker):
    """
    Worker class that provides presets injection features.
    """

    def __init__(self, presets_file: Path | None, input_mission: Path | None, output_mission: Path | None):
        self.presets_file = presets_file
        self.groups: dict[str, Group] = {}
        self.presets_manager: PresetsManager = PresetsManager()
        super().__init__(config_file=presets_file, input_mission=input_mission, output_mission=output_mission)

    def load_config(self) -> Any:
        """Load configuration from YAML file."""
        presets_manager = PresetsManager()
        try:
            if self.presets_file:
                presets_manager.read_yaml(self.presets_file)
        except Exception as e:
            logger.error(f"Failed to load config file {self.presets_file}: {str(e)}", exception_type=RuntimeError)
        self.presets_manager = presets_manager
        return presets_manager

    def add_group(self, group: Group) -> None:
        if group.name:
            self.groups[group.name] = group

    def process_group(self, group: Group) -> None:
        """Collect the group; actual preset injection happens in process_groups()."""
        self.add_group(group)

    def process_units(self, group: Group, preset_definition: PresetDefinition) -> int:
        nb_units_processed = 0
        if units := group.group_dcs.get("units", {}):
            for unit in [u for u in units if u.get("skill", "") in ["Client", "Player"]]:
                nb_units_processed += 1
                unit["Radio"] = preset_definition.to_dict()
                if preset_definition == PresetDefinition.EMPTY:
                    if "frequency" in group.group_dcs:
                        del group.group_dcs["frequency"]
                elif first_freq := preset_definition.get_freq_of_first_channel_of_first_radio():
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
            ]
            warn_invalid_channel_frequencies(
                group_name=group.name or "",
                unit_type=group.unit_type,
                channels=channel_freqs,
                coalition=group.coalition or "blue",
                aircraft_category=group.aircraft_type or "plane",
            )

        return nb_units_processed

    def process_groups(self, silent: bool = False) -> None:
        """Inject presets into all human-piloted groups."""
        if not silent:
            logger.info(f"Processing {len(self.groups)} aircraft group{'s' if len(self.groups) > 1 else ''}")

        nb_units_processed = 0
        for group in [g for g in self.groups.values() if g.human_pilot]:
            if preset_definition := self.presets_manager.get_radios_for(
                coalition=group.coalition, aircraft_type=group.aircraft_type, unit_type=group.unit_type
            ):
                preset_definition.used_in_mission = True
                logger.debug(
                    f"Injecting preset '{preset_definition}' into group '{group.name}' (type: {group.unit_type}, aircraft: {group.aircraft_type}, country: {group.country}, coalition: {group.coalition})"
                )
                group.group_dcs["radioSet"] = preset_definition != PresetDefinition.EMPTY
                group.group_dcs["communication"] = False
                nb_units_processed += self.process_units(group, preset_definition)

        if not silent:
            logger.info(f"Injected presets into {nb_units_processed} aircraft{'s' if nb_units_processed > 1 else ''}")

    def write_mission(self, silent: bool = False) -> None:
        """Write the mission file, including kneeboard pages if generated."""
        if not silent:
            logger.info("Writing mission file")

        additional_files = {}
        if self.presets_manager.presets_images:
            for preset_name, image in self.presets_manager.presets_images.items():
                additional_files[f"KNEEBOARD/IMAGES/presets-{preset_name}.png"] = image.getvalue()
            if not silent:
                logger.info(
                    f"Added {len(self.presets_manager.presets_images)} kneeboard page{'s' if len(self.presets_manager.presets_images) > 1 else ''} to mission"
                )

        assert self.dcs_mission is not None
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission, additional_files=additional_files)

    def work(self, silent: bool = False) -> None:  # type: ignore[override]
        """Main work function."""
        with spinner_context(f"Reading {self.input_mission}...", silent=silent):
            self.read_mission(silent)

        assert self.dcs_mission is not None
        for group in self.dcs_mission.iter_groups():
            self.process_group(group)

        with spinner_context("Processing groups...", silent=silent):
            self.process_groups(silent)

        with spinner_context("Generating preset images...", silent=silent):
            self.presets_manager.generate_presets_images(width=1200, height=None)

        with spinner_context("Writing mission...", silent=silent):
            self.write_mission(silent)
