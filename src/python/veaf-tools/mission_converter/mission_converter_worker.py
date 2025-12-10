"""
Worker module for the VEAF Mission Converter Package.
"""

from pathlib import Path
from typing import Optional
from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_extractor.mission_extractor_worker import MissionExtractorWorker
from presets_injector import PresetsInjectorWorker
from rich.console import Console
from rich.spinner import Spinner
from rich.live import Live
from rich.text import Text
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context, progress_context

class MissionConverterWorker:
    """
    Worker class that converts a DCS mission to a VEAF folder containing the mission files.
    """
    
    def __init__(self, mission_folder: Path, input_mission: Path, output_mission: Path, mission_name: str, dynamic_mode: Optional[bool] , scripts_path: Optional[Path], inject_presets: bool=False, presets_file: Path = None, scripts_variant: str = "standard"):
        """
        Initialize the worker with parameters for both use cases.
        """
        
        self.mission_folder = mission_folder
        self.dynamic_mode = dynamic_mode
        self.scripts_path = scripts_path
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.mission_name = mission_name
        self.mission_folder = mission_folder
        self.inject_presets = inject_presets
        self.presets_file = presets_file or self.mission_folder / "src" / "presets.yaml"
        self.scripts_variant = scripts_variant

        if not (self.input_mission and self.input_mission.is_file()):
            logger.error(f"The input mission '{self.input_mission}' does not exist or is not a file", exception_type=FileNotFoundError)

        if self.mission_folder and not self.mission_folder.is_dir():
            logger.error(f"The output mission folder '{self.mission_folder}' does not exist or is not a folder", exception_type=FileNotFoundError)

    def work(self) -> None:
        """Main work function."""

        # extract the DCS mission to the mission folder
        with spinner_context(f"Extracting {self.input_mission}..."):
            extractor = MissionExtractorWorker(mission_folder=self.mission_folder, input_mission_path=self.input_mission)
            extractor.work(silent=True)

        # build the newly extracted mission
        with spinner_context(f"Temporarily building {self.output_mission}..."):
            builder = MissionBuilderWorker(mission_folder=self.mission_folder, output_mission=self.output_mission, dynamic_mode=self.dynamic_mode, scripts_path=self.scripts_path, scripts_variant=self.scripts_variant)
            new_mission_path = builder.work(silent=True)

        # inject presets
        if self.inject_presets:
            with spinner_context(f"Injecting presets from {self.presets_file}..."):
                injector = PresetsInjectorWorker(presets_file=self.presets_file, input_mission=new_mission_path, output_mission=new_mission_path)
                injector.work(silent=True)

        with spinner_context(f"Finalizing and setting mission name to {self.mission_name}..."):
            # extract the newly built mission
            extractor = MissionExtractorWorker(mission_folder=self.mission_folder, input_mission_path=new_mission_path)
            extractor.work(silent=True)

            # change the mission name in the default missionConfig.lua file
            mission_config_file = self.mission_folder / "src" / "scripts" / "missionConfig.lua"
            content = mission_config_file.read_text()
            new_content = content.replace("Mission-Name-Not-Set", self.mission_name)
            mission_config_file.write_text(new_content)

            # delete the newly built mission
            new_mission_path.unlink()


        with spinner_context(f"Building {self.output_mission}..."):
            # rebuild the mission one last time
            builder.work(silent=True)

        logger.info(f"Mission file '{self.input_mission}' converted to folder '{self.mission_folder}'.")
        if self.inject_presets:
            logger.info(f"Presets injected from {self.presets_file}")
        logger.info(f"Mission has been built to file '{self.output_mission}'.")
