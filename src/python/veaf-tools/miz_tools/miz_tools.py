"""
This module provides classes for reading and writing missions to and from .miz files.
"""


import contextlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional
import io
import luadata
import os
import shutil
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
        with io.TextIOWrapper(file, encoding='utf-8') as wrapper:
            return luadata.unserialize(wrapper.read())

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

import tempfile
import zipfile
import os
from pathlib import Path
from typing import Optional, Dict

def update_miz(mission: DcsMission, file_path: Optional[Path], additional_files: Optional[Dict]) -> DcsMission:
    """Update an existing mission in a .miz file with new data (zip it)."""
    
    def serialize(zip_file: zipfile.ZipFile, content: str, file_name: str, variable_name: Optional[str] = None) -> None:
        lua_content = luadata.serialize(content, indent='\t', indent_level=0, always_provide_keyname=True)
        zip_file.writestr(file_name, f"{variable_name} = \n{lua_content}" if variable_name else lua_content)

    if not file_path: 
        file_path = mission.file_path

    # Normalize additional_files to avoid None errors
    additional_files = additional_files or {}

    # Use NamedTemporaryFile for automatic cleanup
    temp_zip_path: Optional[str] = None
    with tempfile.NamedTemporaryFile(
            suffix='.miz',          # Proper extension
            prefix='veaf_mission_', # Identifiable prefix
            delete=False,           # Keep file after context manager exits
            dir=file_path.parent    # Same directory as target (for atomic moves)
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
                            if mission.mission_lua:
                                serialize(zip_file=zip_write, content=mission.mission_lua, 
                                       file_name="mission", variable_name="mission")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "options":
                            if mission.options_lua:
                                serialize(zip_file=zip_write, content=mission.options_lua, 
                                       file_name="options", variable_name="options")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "theatre":
                            if mission.theatre:
                                zip_write.writestr("theatre", mission.theatre)
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "warehouses":
                            if mission.warehouses_lua:
                                serialize(zip_file=zip_write, content=mission.warehouses_lua, 
                                       file_name="warehouses", variable_name="warehouses")
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "l10n/DEFAULT/dictionary":
                            if mission.dictionary_lua:
                                serialize(zip_file=zip_write, content=mission.dictionary_lua, 
                                       file_name="l10n/DEFAULT/dictionary", variable_name="dictionary")
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
            raise e

    # Move temp file to final location
    if temp_zip_path:
        os.replace(temp_zip_path, file_path)

    return mission
