"""
Worker module for the VEAF Mission Extractor Package.
"""

from pathlib import Path
import shutil
from typing import Optional
from mission_tools import read_miz, write_miz, extract_miz, get_community_script_files, get_veaf_script_files, get_mission_files_to_cleanup_on_extract, get_legacy_script_files, spinner_context
from veaf_logger import logger
import tempfile

class MissionExtractorWorker:
    """
    Worker class that extracts a .miz mission file to a VEAF mission folder.
    """
    
    def __init__(self, mission_folder: Path, input_mission_path: Path):
        """
        Initialize the worker with parameters for both use cases.
        """
        
        self.input_mission_path = input_mission_path
        self.mission_folder = mission_folder

        if not (self.input_mission_path and self.input_mission_path.is_file()):
            logger.error(f"The input mission '{self.input_mission_path}' does not exist or is not a file", exception_type=FileNotFoundError)

        if self.mission_folder and not self.mission_folder.is_dir():
            logger.error(f"The output mission folder '{self.mission_folder}' does not exist or is not a folder", exception_type=FileNotFoundError)

    def extract_mission(self) -> None:
        """Extract the files from the .miz mission to the VEAF mission folder"""

        def rm_file_or_dir(path: Path):
            try:
                if path.exists():
                    if path.is_dir():
                        shutil.rmtree(path)
                    elif path.is_file():
                        path.unlink()
            except FileNotFoundError:
                pass # no need for error if the file is already non-existent
            except PermissionError:
                print(f"Permission denied to delete {path}")

        def mv_file_or_dir(path: Path, new_path: Path):
            try:
                if new_path:
                    new_parent = new_path.parent
                    if not new_parent.exists():
                        new_parent.mkdir(parents=True, exist_ok=True)
                if path and path.exists() :
                    shutil.move(path, new_path)
            except FileNotFoundError:
                pass # no need for error if the file is already non-existent
            except PermissionError:
                print(f"Permission denied to move {path} to {new_path}")

        # Create a temporary folder
        with tempfile.TemporaryDirectory() as temp_dir_name:
            temp_dir: Path = Path(temp_dir_name)

            # Normalize the mission to a temporary file
            temp_mission_file = temp_dir / "temp_mission.miz"
            logger.debug(f"Normalizing the mission file {self.input_mission_path} to a temporary file {temp_mission_file}")
            dcs_mission = read_miz(self.input_mission_path)
            write_miz(dcs_mission, temp_mission_file)

            # Extract the mission .miz file
            logger.debug(f"Extracting the mission file {temp_mission_file} to the folder {temp_dir}")
            extract_miz(miz_file_path=temp_mission_file, extracted_folder_path=temp_dir)

            # Delete the temporary mission file
            temp_mission_file.unlink()

            # Remove the VEAF, community, and legacy VEAF
            for file_in_mission in [Path(f[1]) / Path(f[0]).name for f in get_veaf_script_files() + get_community_script_files() + get_legacy_script_files() ]:
                file_in_temp: Path = temp_dir / file_in_mission
                rm_file_or_dir(file_in_temp)

            # Create the src and src/scripts folders if needed
            src_scripts_folder = self.mission_folder / "src" / "scripts"
            src_folder = src_scripts_folder.parent
            if not src_scripts_folder.exists(): src_scripts_folder.mkdir(parents=True, exist_ok=True)
            
            # Remove or move the extracted mission files (remove unwanted files or move files not present in the src folder)
            for file_in_mission, move_to_mission_src_folder_if_not_exist in get_mission_files_to_cleanup_on_extract():
                file_in_temp: Path = temp_dir / file_in_mission
                remove = True
                if move_to_mission_src_folder_if_not_exist:
                    file_in_mission_name = Path(file_in_mission).name
                    file_in_mission_src_folder: Path = src_folder / "scripts" / file_in_mission_name
                    remove = file_in_mission_src_folder.exists()
                if remove: 
                    rm_file_or_dir(file_in_temp) # delete temp file
                else:
                    mv_file_or_dir(file_in_temp, file_in_mission_src_folder)
                    
            # Remove or move the additional mission script files (remove LUA files present in the src/scripts folder or move files not present)
            temp_mission_dir = temp_dir / "l10n" / "DEFAULT"
            for file_in_temp in temp_mission_dir.glob("*.lua"):
                file_in_mission_src_folder: Path = src_scripts_folder / file_in_temp.name
                if file_in_mission_src_folder.exists():
                    rm_file_or_dir(file_in_temp) # delete temp file
                else:
                    mv_file_or_dir(file_in_temp, file_in_mission_src_folder)


            # Copy all the extracted files to the mission folder
            shutil.copytree(src=temp_dir, dst=self.mission_folder / "src" / "mission", dirs_exist_ok=True)


    def work(self, silent:bool=False) -> None:
        """Main work function."""

        # Extract the mission
        with spinner_context(f"Extracting mission {self.input_mission_path}...", done_message=f"Mission file '{self.input_mission_path}' extracted to '{self.mission_folder}'.", silent=silent):
            self.extract_mission()
