"""
This module provides classes for reading and writing missions to and from .miz files.
"""


import contextlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional
import io
import luadata
import os
import zipfile
import tempfile
import os
from pathlib import Path
from typing import Optional, Dict
from veaf_logger import logger

@dataclass
class DcsMission:
    """Class representing a DCS mission."""
    file_path: Path
    mission_content: Optional[dict] = None
    options_content: Optional[dict] = None
    theatre_content: Optional[str] = ""
    warehouses_content: Optional[dict] = None
    dictionary_content: Optional[dict[str, str]] = None
    map_resource_content: Optional[dict[str, str]] = None
    missing_components: list = field(default_factory=list)

def read_miz(miz_file_path: Path) -> DcsMission:
    """Load the mission from the .miz file (unzip it and parse the lua files)."""
    
    def unserialize(file: str, keep_as_dict:list=None, all_is_dict:bool=False) -> Dict:
        with io.TextIOWrapper(file, encoding='utf-8') as wrapper:
            return luadata.unserialize(wrapper.read(), keep_as_dict=keep_as_dict, all_is_dict=all_is_dict)

    def read_file_in_archive(zip_file: zipfile.ZipFile, file_name: str, missing_components: list[str], keep_as_dict: list[str] = [], not_lua: bool = False) -> dict:
        if file_name in zip_file.namelist():
            with zip_file.open(file_name) as file:
                if not_lua:
                    return file.read().decode('utf-8')
                else:
                    return unserialize(file, keep_as_dict=keep_as_dict)
        else:
            return missing_components.append(file_name)

    result = DcsMission(file_path=miz_file_path)

    with zipfile.ZipFile(miz_file_path, 'r') as miz:
        result.mission_content = read_file_in_archive(miz, 'mission', result.missing_components, keep_as_dict=["trig", "trigrules"])
        result.options_content = read_file_in_archive(miz, 'options', result.missing_components)
        result.theatre_content = read_file_in_archive(miz, 'theatre', result.missing_components, not_lua=True)
        result.warehouses_content = read_file_in_archive(miz, 'warehouses', result.missing_components)
        result.dictionary_content = read_file_in_archive(miz, 'l10n/DEFAULT/dictionary', result.missing_components)
        result.map_resource_content = read_file_in_archive(miz, 'l10n/DEFAULT/mapResource', result.missing_components)

    return result

def create_miz(miz_file_path: Path, files: Dict[str, bytes]) -> Path:
    """Create an mission in a .miz file with new data (zip it)."""

    # Normalize files to avoid None errors
    files = files or {}

    if miz_file_path:
        with zipfile.ZipFile(miz_file_path, 'w') as zip_write:
            for file_name, file_content in files.items():
                zip_write.writestr(zinfo_or_arcname=str(file_name), data=file_content)

    return miz_file_path

def write_miz(mission: DcsMission, miz_file_path: Optional[Path], additional_files: Optional[Dict] = None) -> DcsMission:
    """Update an existing mission in a .miz file with new data (zip it)."""
    
    def serialize(zip_file: zipfile.ZipFile, content: str, file_name: str, variable_name: Optional[str] = None) -> None:
        lua_content = luadata.serialize(content, indent='  ', indent_level=0, always_provide_keyname=True, sort=True)
        zip_file.writestr(file_name, f"{variable_name} = \n{lua_content}" if variable_name else lua_content)

    if not miz_file_path: 
        miz_file_path = mission.file_path

    # Normalize additional_files to avoid None errors
    additional_files = additional_files or {}

    # Use NamedTemporaryFile for automatic cleanup
    temp_zip_path: Optional[str] = None
    with tempfile.NamedTemporaryFile(
            suffix='.miz',          # Proper extension
            prefix='veaf_mission_', # Identifiable prefix
            delete=False,           # Keep file after context manager exits
            dir=miz_file_path.parent    # Same directory as target (for atomic moves)
        ) as temp_file:
        temp_zip_path = temp_file.name

        try:
            # Read all files from the original mission file
            with zipfile.ZipFile(mission.file_path, 'r') as zip_read:
                file_list = zip_read.namelist()

                # Copy all files except the ones we're updating
                with zipfile.ZipFile(temp_zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_write:
                    for file_name in file_list:
                        if file_name == "mission":
                            if mission.mission_content:
                                serialize(zip_file=zip_write, content=mission.mission_content, 
                                       file_name="mission", variable_name="mission")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "options":
                            if mission.options_content:
                                serialize(zip_file=zip_write, content=mission.options_content, 
                                       file_name="options", variable_name="options")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "theatre":
                            if mission.theatre_content:
                                zip_write.writestr("theatre", mission.theatre_content)
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "warehouses":
                            if mission.warehouses_content:
                                serialize(zip_file=zip_write, content=mission.warehouses_content, 
                                       file_name="warehouses", variable_name="warehouses")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "l10n/DEFAULT/dictionary":
                            if mission.dictionary_content:
                                serialize(zip_file=zip_write, content=mission.dictionary_content, 
                                       file_name="l10n/DEFAULT/dictionary", variable_name="dictionary")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "l10n/DEFAULT/mapResource":
                            if mission.map_resource_content:
                                serialize(zip_file=zip_write, content=mission.map_resource_content, 
                                       file_name="l10n/DEFAULT/mapResource", variable_name="mapResource")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))                        
                        elif file_name in additional_files:
                            # Skip it - will be added from additional_files
                            pass
                        else:
                            # Copy existing file as-is
                            zip_write.writestr(file_name, zip_read.read(file_name))

                    # Add the additional files
                    for additional_file_name, additional_file_content in additional_files.items():
                        zip_write.writestr(additional_file_name, additional_file_content)

        except Exception as e:
            # Clean up temp file on error
            with contextlib.suppress(OSError):
                os.unlink(temp_zip_path)
            logger.exception(e)

    # Move temp file to final location
    if temp_zip_path:
        os.replace(temp_zip_path, miz_file_path)

    return mission

def extract_miz(miz_file_path: Path, extracted_folder_path: Path):
    """Extract the mission from the .miz file (unzip it)."""

    # Extract all files to a folder
    with zipfile.ZipFile(miz_file_path, 'r') as zip_ref:
        zip_ref.extractall(extracted_folder_path)
