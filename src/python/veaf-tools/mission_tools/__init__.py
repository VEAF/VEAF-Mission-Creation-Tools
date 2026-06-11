"""
VEAF Mission Mission Tools Package

This package provides tools to work on VEAF mission files.
"""

from .aircraft_group_sort import (
    KIND_DYNAMIC_TEMPLATE,
    KIND_SPAWNABLE,
    SPAWNABLE_NAME_PREFIX,
    classify_aircraft_group,
)
from .mission_constants import (
    DEFAULT_SCRIPTS_LOCATION,
    collect_files_from_globs,
    get_community_script_files,
    get_legacy_script_files,
    get_mission_data_files,
    get_mission_files_to_cleanup_on_extract,
    get_mission_script_files,
    get_veaf_script_files,
)
from .miz_tools import DcsMission, Group, create_miz, extract_miz, read_miz, write_miz

__all__ = [
    "classify_aircraft_group",
    "KIND_SPAWNABLE",
    "KIND_DYNAMIC_TEMPLATE",
    "SPAWNABLE_NAME_PREFIX",
    "read_miz",
    "write_miz",
    "create_miz",
    "extract_miz",
    "DcsMission",
    "Group",
    "DEFAULT_SCRIPTS_LOCATION",
    "get_community_script_files",
    "get_mission_data_files",
    "get_mission_script_files",
    "get_veaf_script_files",
    "get_mission_files_to_cleanup_on_extract",
    "get_legacy_script_files",
    "collect_files_from_globs",
]
