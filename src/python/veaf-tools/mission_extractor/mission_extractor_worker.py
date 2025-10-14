"""
Worker module for the VEAF Mission Extractor Package.
"""

from pathlib import Path
import shutil
from typing import Optional
from mission_tools import read_miz, write_miz, extract_miz, get_community_script_files, get_mission_data_files, get_mission_script_files, get_veaf_script_files, DEFAULT_SCRIPTS_LOCATION, get_mission_files_to_cleanup_on_extract, get_legacy_script_files
from veaf_logger import VeafLogger
import tempfile

class MissionExtractorWorker:
    """
    Worker class that extracts a .miz mission fole to a VEAF mission folder.
    """
    
    def __init__(self, mission_folder: Path, input_mission_path: Path, logger: Optional[VeafLogger]):
        """
        Initialize the worker with parameters for both use cases.
        """
        
        self.logger: VeafLogger = logger
        self.input_mission_path = input_mission_path
        self.mission_folder = mission_folder

        if not (self.input_mission_path and self.input_mission_path.is_file()):
            self.logger.error(f"The input mission '{self.input_mission_path}' does not exist or is not a file", raise_exception=True)
        
        if self.mission_folder and not self.mission_folder.is_dir():
            self.logger.error(f"The output mission folder '{self.mission_folder}' does not exist or is not a folder", raise_exception=True)

    def extract_mission(self) -> None:
        """Extract the files from the .miz mission to the VEAF mission folder"""

        def rm_file_or_dir(path: Path):
            try:
                if path.exists():
                    if path.is_dir():
                        shutil.rmtree(path)
                        print(f"Deleted {path}")
                    elif path.is_file():
                        path.unlink()
            except FileNotFoundError:
                pass # no need for error if the file is already non-existent
            except PermissionError:
                print(f"Permission denied to delete {path}")

        # Create a temporary folder
        with tempfile.TemporaryDirectory() as temp_dir_name:
            temp_dir: Path = Path(temp_dir_name)

            # Extract the mission .miz file
            self.logger.debug(f"Extracting the mission file {self.input_mission_path} to the folder {temp_dir}")
            extract_miz(miz_file_path=self.input_mission_path, extracted_folder_path=temp_dir)

            # Remove the VEAF, community, legacy VEAF and mission script files
            for file_in_mission in [Path(f[1]) / Path(f[0]).name for f in get_veaf_script_files() + get_community_script_files() + get_mission_script_files() + get_legacy_script_files() ]:
                file_in_temp: Path = temp_dir / file_in_mission
                rm_file_or_dir(file_in_temp)

            # Remove the additional mission script files
            src_folder = self.mission_folder / "src"
            if src_folder.exists() and src_folder.is_dir():
                for file_in_src in src_folder.glob("*.lua"):
                    file_in_temp: Path = temp_dir / DEFAULT_SCRIPTS_LOCATION / file_in_src.name
                    rm_file_or_dir(file_in_temp)
            
            # Cleanup the extracted mission (remove unwanted files)
            for file_in_mission in get_mission_files_to_cleanup_on_extract():
                file_in_temp: Path = temp_dir / file_in_mission
                rm_file_or_dir(file_in_temp)

            # Copy all the extracted files to the mission folder
            shutil.copytree(src=temp_dir, dst=self.mission_folder / "src" / "mission", dirs_exist_ok=True)


    def work(self) -> None:
        """Main work function."""

        # Extract the mission
        self.extract_mission()

        self.logger.info(f"Mission file '{self.input_mission_path}' extracted to '{self.mission_folder}'.")
