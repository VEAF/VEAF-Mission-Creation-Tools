"""
This module provides classes for reading and writing missions to and from .miz files.
"""

import contextlib
import io
import os
import tempfile
import zipfile
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import IO, Any

import luadata
from veaf_libs.logger import logger

from .mission_constants import DEFAULT_SCRIPTS_LOCATION


@dataclass
class Group:
    """Canonical representation of a DCS aircraft/helicopter group."""

    group_dcs: dict
    aircraft_type: str  # "helicopter" | "plane"
    country: str
    coalition: str
    human_pilot: bool = False
    name: str | None = None
    unit_type: str | None = None


@dataclass
class DcsMission:
    """Class representing a DCS mission."""

    file_path: Path
    mission_content: dict | None = None
    options_content: dict | None = None
    theatre_content: str | None = ""
    warehouses_content: dict | None = None
    dictionary_content: dict[str, str] | None = None
    map_resource_content: dict[str, str] | None = None
    missing_components: list = field(default_factory=list)

    def iter_groups(self) -> Iterator[Group]:
        """Iterate over all aircraft/helicopter groups in the mission.

        Yields Group instances for every group found under
        coalition → country → {helicopter,plane} → group.
        """
        if not self.mission_content:
            return
        coalitions = self.mission_content.get("coalition")
        if not coalitions:
            return
        for coalition_name, coalition_data in coalitions.items():
            countries = coalition_data.get("country") or []
            for country_dict in countries:
                country_name = country_dict.get("name", "")
                for aircraft_type in ("helicopter", "plane"):
                    aircraft_data = country_dict.get(aircraft_type)
                    if not aircraft_data:
                        continue
                    groups_list = aircraft_data.get("group") or []
                    for group_dict in groups_list:
                        group = Group(
                            group_dcs=group_dict,
                            aircraft_type=aircraft_type,
                            country=country_name,
                            coalition=coalition_name,
                        )
                        group.name = group_dict.get("name")
                        units_list = group_dict.get("units") or []
                        for unit in units_list:
                            if unit_type := unit.get("type", ""):
                                group.unit_type = unit_type
                            if unit.get("skill", "") in ("Client", "Player"):
                                group.human_pilot = True
                                break
                        yield group

    # ------------------------------------------------------------------
    # Convenience accessors (DEEP-002)
    # ------------------------------------------------------------------

    def get_weather(self) -> dict | None:
        """Return the weather dict from mission_content, or None."""
        return self.mission_content.get("weather") if self.mission_content else None

    def set_weather(self, data: dict) -> None:
        """Replace the weather dict in mission_content."""
        if self.mission_content is not None:
            self.mission_content["weather"] = data

    def get_options(self) -> dict | None:
        """Return options_content."""
        return self.options_content

    def set_options(self, data: dict) -> None:
        """Replace options_content."""
        self.options_content = data


def read_miz(miz_file_path: Path) -> DcsMission:
    """Load the mission from the .miz file (unzip it and parse the lua files)."""

    def unserialize(
        file: IO[bytes], keep_as_dict: list[str] | None = None, all_is_dict: bool = False
    ) -> dict[str, Any]:
        with io.TextIOWrapper(file, encoding="utf-8") as wrapper:  # type: ignore[arg-type]
            return luadata.unserialize(wrapper.read(), keep_as_dict=keep_as_dict, all_is_dict=all_is_dict)  # type: ignore[return-value]

    def read_file_in_archive(
        zip_file: zipfile.ZipFile,
        file_name: str,
        missing_components: list[str],
        keep_as_dict: list[str] | None = None,
        not_lua: bool = False,
    ) -> dict[str, Any] | str | None:
        if file_name in zip_file.namelist():
            with zip_file.open(file_name) as file:
                if not_lua:
                    return file.read().decode("utf-8")
                else:
                    return unserialize(file, keep_as_dict=keep_as_dict)
        else:
            missing_components.append(file_name)
            return None

    result = DcsMission(file_path=miz_file_path)

    with zipfile.ZipFile(miz_file_path, "r") as miz:
        result.mission_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "mission", result.missing_components, keep_as_dict=["trig", "trigrules"]
        )
        result.options_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "options", result.missing_components
        )
        result.theatre_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "theatre", result.missing_components, not_lua=True
        )
        result.warehouses_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "warehouses", result.missing_components
        )
        result.dictionary_content = read_file_in_archive(  # type: ignore[assignment]
            miz, f"{DEFAULT_SCRIPTS_LOCATION}/dictionary", result.missing_components
        )
        result.map_resource_content = read_file_in_archive(  # type: ignore[assignment]
            miz, f"{DEFAULT_SCRIPTS_LOCATION}/mapResource", result.missing_components
        )

    return result


def create_miz(miz_file_path: Path, files: dict[str, bytes]) -> Path:
    """Create an mission in a .miz file with new data (zip it)."""

    # Normalize files to avoid None errors
    files = files or {}

    if miz_file_path:
        with zipfile.ZipFile(miz_file_path, "w") as zip_write:
            for file_name, file_content in files.items():
                zip_write.writestr(zinfo_or_arcname=str(file_name), data=file_content)

    return miz_file_path


def write_miz(mission: DcsMission, miz_file_path: Path | None, additional_files: dict | None = None) -> DcsMission:
    """Update an existing mission in a .miz file with new data (zip it)."""

    def serialize(zip_file: zipfile.ZipFile, content: Any, file_name: str, variable_name: str | None = None) -> None:
        lua_content = luadata.serialize(content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)  # type: ignore[arg-type]
        zip_file.writestr(file_name, f"{variable_name} = \n{lua_content}" if variable_name else lua_content)

    if not miz_file_path:
        miz_file_path = mission.file_path

    # Normalize additional_files to avoid None errors
    additional_files = additional_files or {}

    # Use NamedTemporaryFile for automatic cleanup
    temp_zip_path: str | None = None
    with tempfile.NamedTemporaryFile(
        suffix=".miz",  # Proper extension
        prefix="veaf_mission_",  # Identifiable prefix
        delete=False,  # Keep file after context manager exits
        dir=miz_file_path.parent,  # Same directory as target (for atomic moves)
    ) as temp_file:
        temp_zip_path = temp_file.name

        try:
            # Read all files from the original mission file
            with zipfile.ZipFile(mission.file_path, "r") as zip_read:
                file_list = zip_read.namelist()

                # Copy all files except the ones we're updating
                with zipfile.ZipFile(temp_zip_path, "w", zipfile.ZIP_DEFLATED) as zip_write:
                    for file_name in file_list:
                        if file_name == "mission":
                            if mission.mission_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.mission_content,
                                    file_name="mission",
                                    variable_name="mission",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "options":
                            if mission.options_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.options_content,
                                    file_name="options",
                                    variable_name="options",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "theatre":
                            if mission.theatre_content:
                                zip_write.writestr("theatre", mission.theatre_content)
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "warehouses":
                            if mission.warehouses_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.warehouses_content,
                                    file_name="warehouses",
                                    variable_name="warehouses",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == f"{DEFAULT_SCRIPTS_LOCATION}/dictionary":
                            if mission.dictionary_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.dictionary_content,
                                    file_name=f"{DEFAULT_SCRIPTS_LOCATION}/dictionary",
                                    variable_name="dictionary",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == f"{DEFAULT_SCRIPTS_LOCATION}/mapResource":
                            if mission.map_resource_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.map_resource_content,
                                    file_name=f"{DEFAULT_SCRIPTS_LOCATION}/mapResource",
                                    variable_name="mapResource",
                                )
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
            temp_zip_path = None  # Prevent replacing the original with a broken temp file

    # Move temp file to final location (only if write succeeded)
    if temp_zip_path:
        os.replace(temp_zip_path, miz_file_path)

    return mission


def extract_miz(miz_file_path: Path, extracted_folder_path: Path):
    """Extract the mission from the .miz file (unzip it)."""

    # Extract all files to a folder
    with zipfile.ZipFile(miz_file_path, "r") as zip_ref:
        zip_ref.extractall(extracted_folder_path)
