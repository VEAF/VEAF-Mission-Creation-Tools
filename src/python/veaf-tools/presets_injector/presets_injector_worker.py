"""
Worker module for the VEAF Presets Injector Package.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

from mission_tools import DcsMission, read_miz, write_miz, spinner_context

from .presets_manager import PresetsManager
from veaf_logger import VeafLogger

@dataclass
class Group:
    """Class for keeping track of DCS group."""
    group_dcs: Dict
    aircraft_type: str
    country: str
    coalition: str
    human_pilot: bool = False
    name: Optional[str] = None
    unit_type: Optional[str] = None

class PresetsInjectorWorker:
    """
    Worker class that provides presets injection features.
    """
    
    def __init__(self, logger: Optional[VeafLogger], presets_file: Optional[Path], input_mission: Optional[Path], output_mission: Optional[Path]):
        """
        Initialize the worker with optional parameters for both use cases.
        
        Args:
            logger: Logger instance for logging messages
            config_file: Path to the configuration file
            input_mission: Path to the input mission file
            output_mission: Path to the output mission file
        """
        self.logger: VeafLogger = logger
        self.presets_file = presets_file
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.groups = {}
        self.presets_manager:PresetsManager = self.load_config()
        self.dcs_mission: DcsMission = None

    def load_config(self) -> Any:
        """Load configuration from Lua file."""
        presets_manager = PresetsManager()
        try:
            presets_manager.read_yaml(self.presets_file)        
            return presets_manager
        except Exception as e:
            self.logger.error(f"Failed to load config file {self.presets_file}: {str(e)}", raise_exception=True)

    def add_group(self, group_dict: Dict, aircraft_type: str, country: str, coalition: str) -> None:
        group: Group = Group(
            group_dcs = group_dict,
            aircraft_type = aircraft_type,
            country = country,
            coalition = coalition
        )
        if name := group_dict.get("name"):
            group.name = name
            if units_list := group_dict.get("units"):
                for unit in units_list:
                    if unit_type := unit.get("type", ""):
                        group.unit_type = unit_type
                    unit_skill = unit.get("skill", "")
                    if unit_skill in ["Client", "Player"]:
                        group.human_pilot = True
                        self.logger.debug(f"Adding group {group.name} to the list of presets injection targets")
                        break

            self.groups[name] = group

    def read_mission(self, silent:bool=False) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        if not silent: self.logger.info(f"Reading mission file {self.input_mission}")
        self.dcs_mission = read_miz(self.input_mission)

        self.logger.debug("Searching for all aircraft groups")
        
        coalitions_dict = self.dcs_mission.mission_content.get("coalition")
        if not coalitions_dict:
            self.logger.error("cannot find key 'coalition'", True)
            return
            
        for coalition_name in coalitions_dict.keys():
            self._process_coalition(coalition_name, coalitions_dict[coalition_name])

    def _process_coalition(self, coalition_name: str, coalition_data: Dict) -> None:
        """Process all countries in a coalition."""
        self.logger.debug(f"Browsing countries in coalition {coalition_name}")
        
        countries_list = coalition_data.get("country")
        if not countries_list:
            self.logger.debugwarn(f"no key 'country' in /coalition/{coalition_name}")
            return
            
        for country_dict in countries_list:
            self._process_country(country_dict, coalition_name)

    def _process_country(self, country_dict: Dict, coalition_name: str) -> None:
        """Process a country's aircraft groups."""
        country_name = country_dict.get("name")
        if not country_name:
            self.logger.error(f"cannot find key 'name' in /coalition/{coalition_name}/country", True)
            return
            
        self.logger.debug(f"Browsing country {country_name}")
        
        # Process both helicopter and plane groups
        for aircraft_type in ["helicopter", "plane"]:
            self._process_aircraft_type(country_dict, aircraft_type, country_name, coalition_name)

    def _process_aircraft_type(self, country_dict: Dict, aircraft_type: str, country_name: str, coalition_name: str) -> None:
        """Process groups for a specific aircraft type (helicopter or plane)."""
        aircraft_data = country_dict.get(aircraft_type)
        if not aircraft_data:
            self.logger.debugwarn(f"no key '{aircraft_type}' in /coalition/{coalition_name}/country/{country_name}")
            return
            
        groups_list = aircraft_data.get("group")
        if not groups_list:
            self.logger.warning(f"cannot find key 'group' in /coalition/{coalition_name}/country/{country_name}/{aircraft_type}")
            return
            
        for group in groups_list:
            self.add_group(group, aircraft_type=aircraft_type, country=country_name, coalition=coalition_name)

    def process_groups(self, silent:bool=False) -> None:
        """Process all the aircraft groups."""
        if not silent: self.logger.info(f"Processing {len(self.groups)} aircraft group{'s' if len(self.groups) > 1 else ''}")

        nb_units_processed = 0
        for group in [g for g in self.groups.values() if g.human_pilot]: # Inject radio presets in all aircraft groups with at least one human pilot
            if preset_definition := self.presets_manager.get_radios_for(coalition=group.coalition, aircraft_type=group.aircraft_type, unit_type=group.unit_type):
                preset_definition.used_in_mission = True
                self.logger.debug(f"Injecting preset '{preset_definition}' into group '{group.name}' (type: {group.unit_type}, aircraft: {group.aircraft_type}, country: {group.country}, coalition: {group.coalition})")
                group.group_dcs["radioSet"] = True
                group.group_dcs["communication"] = False
                if units := group.group_dcs.get("units", {}):
                    for unit in [u for u in units if u.get("skill", "") in ["Client", "Player"]]:
                        nb_units_processed += 1
                        unit["Radio"] = preset_definition.to_dict()
                        if first_freq := preset_definition.get_freq_of_first_channel_of_first_radio():
                            group.group_dcs["frequency"] = first_freq
        if not silent: self.logger.info(f"Injected presets into {nb_units_processed} aircraft{'s' if nb_units_processed > 1 else ''}")
                    
    def write_mission(self, silent:bool=False) -> None:
        """Write the mission file."""

        if not silent: self.logger.info("Writing mission file")

        # Prepare saving kneeboard pages if generated
        additional_files = {}
        if self.presets_manager.presets_images:
            for preset_name, image in self.presets_manager.presets_images.items():
                additional_files[f"KNEEBOARD/IMAGES/presets-{preset_name}.png"] = image.getvalue()
            if not silent: self.logger.info(f"Added {len(self.presets_manager.presets_images)} kneeboard page{"s" if len(self.presets_manager.presets_images) > 1 else ""} to mission")

        # Save the mission
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission, additional_files=additional_files)

    def work(self, silent:bool=False) -> None:
        """Main work function."""

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        with spinner_context(f"Reading {self.input_mission}...", logger=self.logger, silent=silent):
            self.read_mission(silent)
       

        # Process all the aircraft groups
        with spinner_context("Processing groups...", logger=self.logger, silent=silent):
            self.process_groups(silent)

        # Generate kneeboard pages if needed
        with spinner_context("Generating preset images...", logger=self.logger, silent=silent):
            self.presets_manager.generate_presets_images(width=1200, height=None)

        # Write the mission file
        with spinner_context("Writing mission...", logger=self.logger, silent=silent):
            self.write_mission(silent)
