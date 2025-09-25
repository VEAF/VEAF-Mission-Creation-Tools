"""
This module provides classes for reading and writing missions to and from .miz files.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional
import io
import luadata
import os
import zipfile

@dataclass
class DcsMission:
    """Class representing a DCS mission."""
    file_path: Path
    mission_lua: Dict = None
    options_lua: Dict = None
    theatre: str = None
    warehouses_lua: Dict = None
    dictionary_lua: Dict[str, str] = None

def read_miz(file_path: Path) -> DcsMission:
    """Load the mission from the .miz file (unzip it)."""
    
    def unserialize(file: str) -> Dict:
        return luadata.unserialize(io.TextIOWrapper(file, encoding='utf-8').read())

    result = DcsMission(file_path=file_path)

    with zipfile.ZipFile(file_path, 'r') as miz:
        with miz.open('mission') as file:
            result.mission_lua = unserialize(file)
        with miz.open('options') as file:
            result.options_lua = unserialize(file)
        with miz.open('theatre') as file:
            result.theatre = file.read().decode('utf-8')
        with miz.open('warehouses') as file:
            result.warehouses_lua = unserialize(file)
        with miz.open('l10n/DEFAULT/dictionary') as file:
            result.dictionary_lua = unserialize(file)

    return result

def update_miz(mission: DcsMission, file_path: Optional[Path], additional_files: Optional[Dict]) -> DcsMission:
    """Update an existing mission in a .miz file with new data (zip it)."""

    def serialize(zip_file: zipfile.ZipFile, content: str, file_name: str, variable_name: Optional[str] = None) -> None:
        lua_content = luadata.serialize(content, indent='\t', indent_level=0, always_provide_keyname=True)
        zip_file.writestr(file_name, f"{variable_name} = \n{lua_content}" if variable_name else lua_content)

    if not file_path: file_path = mission.file_path

    # Create a new ZIP file (temporary)
    temp_zip_path = f'{file_path}.tmp'

    # Read all files from the original mission file
    with zipfile.ZipFile(mission.file_path, 'r') as zip_read:
        # Get list of all files in the ZIP
        file_list = zip_read.namelist()

        # Copy all files except the one present in the mission object
        with zipfile.ZipFile(temp_zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_write:
            for file_name in file_list:
                if file_name == "mission":
                    if mission.mission_lua:
                        # Replace with new content
                        serialize(zip_file=zip_write, content=mission.mission_lua, file_name="mission", variable_name="mission")
                    else:
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                elif file_name == "options":
                    if mission.options_lua:
                        # Replace with new content
                        serialize(zip_file=zip_write, content=mission.options_lua, file_name="options", variable_name="options")
                    else:
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                elif file_name == "theatre":
                    if mission.theatre:
                        # Replace with new content
                        zip_write.writestr("theatre", mission.theatre)
                    else:
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                elif file_name == "warehouses":
                    if mission.warehouses_lua:
                        # Replace with new content
                        serialize(zip_file=zip_write, content=mission.warehouses_lua, file_name="warehouses", variable_name="warehouses")
                    else:
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                elif file_name == "l10n/DEFAULT/dictionary":
                    if mission.dictionary_lua:
                        # Replace with new content
                        serialize(zip_file=zip_write, content=mission.dictionary_lua, file_name="l10n/DEFAULT/dictionary", variable_name="dictionary")
                    else:
                        # Copy existing file as-is
                        zip_write.writestr(file_name, zip_read.read(file_name))
                else:
                    # Copy existing file as-is
                    zip_write.writestr(file_name, zip_read.read(file_name))
        
            # Add the additional files
            for additional_file_name, additional_file_content in (additional_files or {}).items():
                zip_write.writestr(additional_file_name, additional_file_content)

    # Replace original ZIP with the modified one
    os.replace(temp_zip_path, file_path)