"""
API module for the VEAF Presets Injector Package.

This module provides a class that publishes an API with a single "work" function.
"""

from .presets_manager import PresetsManager
from dataclasses import dataclass
from logging import Logger
from pathlib import Path
from typing import Any, Dict, Optional
import io
import luadata
import os
import sys
import zipfile

@dataclass
class Group:
    """Class for keeping track of DCS group."""
    group_dcs: Dict
    aircraft_type: str
    country: str
    coalition: str
    name: str = None
    unit_type: str = None

class PresetsInjectorWorker:
    """
    Worker class that provides presets injection features.
    """
    
    def __init__(self, logger: Optional[Logger] = None, presets_file: Optional[Path] = None, input_mission: Optional[Path] = None, output_mission: Optional[Path] = None, presets_manager: Optional[PresetsManager] = None):
        """
        Initialize the API with optional parameters for both use cases.
        
        Args:
            logger: Logger instance for logging messages
            config_file: Path to the configuration file
            input_mission: Path to the input mission file
            output_mission: Path to the output mission file
            presets_manager: An optional PresetsManager instance
        """
        self.presets_manager = presets_manager or PresetsManager()
        self.logger = logger
        self.presets_file = presets_file
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.groups = {}
        self.presets_manager = self.load_config()
        self.lua_mission = None

    def load_config(self) -> Any:
        """Load configuration from Lua file."""
        presets_manager = PresetsManager()
        try:
            presets_manager.load_from_yaml(self.presets_file)        
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
                first_unit_dict = units_list[0] if len(units_list) > 0 else None
                if first_unit_dict:
                    if first_unit_type := first_unit_dict.get("type"):
                        group.unit_type = first_unit_type
            self.groups[name] = group

    def _process_groups(self, aircraft_type: str, country_dict: Dict, country_name: str, coalition_name: str) -> None:
        """Process groups for a country."""
        if dict := country_dict.get(aircraft_type):
            if groups_list := dict.get("group"):
                for group in groups_list:
                    self.add_group(group, aircraft_type=aircraft_type, country=country_name, coalition=coalition_name)
            else:
                self.logger.error(f"cannot find key 'group' in /coalition/{coalition_name}/country/{country_name}/{aircraft_type}", True)
        else:
            self.logger.debugwarn(f"no key '{aircraft_type}' in /coalition/{coalition_name}/country/{country_name}")

    def _process_country(self, country_dict: Dict, coalition_name: str) -> None:
        """Process a country's aircraft groups."""
        if country_name := country_dict.get("name"):
            self.logger.debug(f"Browsing country {country_name}")
            self._process_groups(aircraft_type="helicopter", country_dict=country_dict, country_name=country_name, coalition_name=coalition_name)
            self._process_groups(aircraft_type="plane", country_dict=country_dict, country_name=country_name, coalition_name=coalition_name)
        else:
            self.logger.error(f"cannot find key 'name' in /coalition/{coalition_name}/country", True)

    def _process_coalition(self, coalition_name: str, coalitions_dict: Dict) -> None:
        """Process all countries in a coalition."""
        self.logger.debug(f"Browsing countries in coalition {coalition_name}")
        if countries_list := coalitions_dict[coalition_name].get("country"):
            for country_dict in countries_list:
                self._process_country(country_dict, coalition_name)
        else:
            self.logger.debugwarn(f"no key 'country' in /coalition/{coalition_name}")

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        self.logger.info(f"Reading mission file {self.input_mission}")
        with zipfile.ZipFile(self.input_mission, 'r') as miz:
            with miz.open('mission') as mission:
                self.lua_mission = luadata.unserialize(io.TextIOWrapper(mission, encoding='utf-8').read())

                # Find and store all the aircraft groups
                self.logger.debug("Searching for all aircraft groups")
                if coalitions_dict := self.lua_mission.get("coalition"):
                    # Browse coalitions
                    for coalition_name in coalitions_dict.keys():
                        self._process_coalition(coalition_name, coalitions_dict)
                else:
                    self.logger.error("cannot find key 'coalition'", True)

    def process_groups(self) -> None:  
        """Process all the aircraft groups."""
        nb_groups_to_process = len(self.groups)
        self.logger.info(f"Processing {nb_groups_to_process} aircraft group{'s' if nb_groups_to_process > 1 else ''}")

        nb_groups_processed = 0
        for group_name in self.groups.keys(): # "Inject radio presets in all aircraft groups"
            group: Group = self.groups[group_name]
            preset = self.presets_manager.get_preset_assignment(coalition=group.coalition, aircraft_type=group.aircraft_type, group_type=group.unit_type) or self.presets_manager.get_preset_assignment(coalition=group.coalition, aircraft_type=group.aircraft_type) # sourcery skip: use-named-expression
            if preset:
                preset_collection = self.presets_manager.get_preset_collection(preset)
                if preset_collection:
                    nb_groups_processed += 1
                    preset_collection.used_in_mission = True
                    self.logger.debug(f"Injecting preset '{preset}' into group '{group.name}' (type: {group.unit_type}, aircraft: {group.aircraft_type}, country: {group.country}, coalition: {group.coalition})")
                    group.group_dcs["radioSet"] = True
                    if units := group.group_dcs["units"]:
                        for unit in units:
                            unit["Radio"] = {
                                int(radio_name) if radio_name.isdigit() else int(radio_name.split('_')[-1]): radio.to_dict() for radio_name, radio in preset_collection.radios.items()
                            }

        self.logger.info(f"Injected presets into {nb_groups_processed} aircraft group{'s' if nb_groups_processed > 1 else ''}")

                    
    def write_mission(self) -> None:
        """Write the mission file."""

        self.logger.info("Writing mission file")

        # Read all files from the original mission file
        with zipfile.ZipFile(self.input_mission, 'r') as zip_read:
            # Get list of all files in the ZIP
            file_list = zip_read.namelist()

            # Create a new ZIP file (temporary)
            temp_zip_path = f'{self.input_mission}.tmp'

            with zipfile.ZipFile(temp_zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_write:
                # Copy all files except the one we want to replace
                for file_name in file_list:
                    if file_name != "mission":
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                    else:
                        # Replace with new content
                        zip_write.writestr(file_name, f"mission = \n{luadata.serialize(self.lua_mission, indent='\t', indent_level=0, always_provide_keyname=True)}")

                # Save kneeboard pages if generated
                if self.presets_manager.presets_images:
                    for preset_collection_name, image in self.presets_manager.presets_images.items():
                        zip_write.writestr(f"/KNEEBOARD/IMAGES/presets-{preset_collection_name}.png", image.getvalue())
                nb_kneeboard_images = len(self.presets_manager.presets_images)
                self.logger.info(f"Added {nb_kneeboard_images} kneeboard page{"s" if nb_kneeboard_images > 1 else ""} to mission")

        # Replace original ZIP with the modified one
        os.replace(temp_zip_path, self.output_mission)

    def work(self) -> None:
        """Main work function."""
       
        # Load the mission from the .miz file (unzip it) and process aircraft groups
        self.read_mission()

        # Process all the aircraft groups
        self.process_groups()

        # Generate kneeboard pages if needed
        self.presets_manager.generate_presets_images(width=1200, height=None)

        # Write the mission file
        self.write_mission()
