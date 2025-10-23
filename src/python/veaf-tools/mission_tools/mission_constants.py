from pathlib import Path


DEFAULT_SCRIPTS_LOCATION:str = "l10n/DEFAULT"

def get_legacy_script_files() -> list[(str, str)]: 
    """Get list of files that should be removed from any newly extracted mission; they are old VEAF files that are not used anymore"""

    return [
            # The community scripts
            ("src/scripts/community/HoundElint.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/NIOD.lua", DEFAULT_SCRIPTS_LOCATION),

            # The VEAF scripts
            ("src/scripts/veaf/veafHoundElintHelper.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/veaf/veaf-scripts-debug.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/veaf/veaf-scripts-trace.lua", DEFAULT_SCRIPTS_LOCATION),
    ]
def get_community_script_files() -> list[(str, str)]:
    """Get list of community LUA files. Those can be in node_modules/veaf-mission-creation-tools or in the scripts folder, depending on the --dynamic-mode option"""


    return [
            # The community scripts
            ("src/scripts/community/mist.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/DCS-SimpleTextToSpeech.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/WeatherMark.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/CTLD.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/AIEN.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/CSAR.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/Hercules_Cargo.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/skynet-iads-compiled.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/community/TheUniversalMission.lua", DEFAULT_SCRIPTS_LOCATION),
    ]

def get_veaf_script_files() -> list[(str, str)]:
    """Get list of VEAF script files.Those can be in node_modules/veaf-mission-creation-tools or in the scripts folder, depending on the --dynamic-mode option"""


    return [
            # The main VEAF scripts
            ("published/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
    ]

def get_mission_script_files() -> list[(str, str)]:
    """Get list of the mission files. Those are either in the mission folder or in the VEAF defaults folder"""

    return [
            # The mission scripts
            ("src/scripts/missionConfig.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/veafDynamicConfig.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/*.lua", DEFAULT_SCRIPTS_LOCATION),
    ]

def get_mission_data_files() -> list[(str, str)]:
    """Get list of the mission files. Those are either in the mission folder or in the VEAF defaults folder"""

    return [
            # The mission files
            ("src/mission/**", ""),

            # The options file
            ("src/options", ""),
    ]

def get_mission_files_to_cleanup_on_extract() -> list[tuple[str, bool]]:
    """Get list of the mission files that need to be cleaned up when extracting a mission file."""

    return [
            (f"{DEFAULT_SCRIPTS_LOCATION}/missionConfig.lua", True),
            (f"{DEFAULT_SCRIPTS_LOCATION}/veafDynamicConfig.lua", True),
            ("options", False),
            ("mission/Config", False),
            ("mission/Scripts", False),
            ("mission/track", False),
            ("mission/track_data", False)
    ]

def collect_files_from_globs(base_folder: Path, file_patterns: list[tuple[str, str]], alternative_folder: Path = None, logger = None) -> dict[str, bytes]:
    """
    Collect files from a base folder using file paths and glob patterns.
    Falls back to alternative_folder if files cannot be found in base_folder.
    
    Args:
        base_folder: The base directory to search from
        file_patterns: List of file paths or glob patterns (e.g., "src/scripts/*.lua", "src/mission/*")
        alternative_folder: Optional fallback folder to search if no files are found in base_folder
    
    Returns:
        Dictionary with:
            - key: relative file path from base_folder (with subfolders)
            - value: file contents as bytes
    """

    def _add_file_to_results(results:dict[str, bytes], file_path:Path, base_folder: Path):
        relative_path = file_path.relative_to(base_folder).parent.as_posix()
        relative_path = dest_location / relative_path / file_path.name
        if logger: logger.debug(f"Processing file {relative_path}")
        results[relative_path] = file_path.read_bytes()

    def _search_pattern_in_folder(search_folder: Path, pattern: str) -> dict[str, bytes]:
        """Search for files matching pattern in the given folder."""
        if not search_folder.exists():
            return {}
        
        pattern_path = search_folder / pattern
        folder = pattern_path.parent
        glob_pattern = pattern_path.name
        
        if not folder.exists():
            return {}
        
        matched_files = {}
        
        if "**" in pattern:
            parts = Path(pattern).parts
            if "**" in parts:
                glob_start_index = parts.index("**")
                pattern_search_folder = search_folder / Path(*parts[:glob_start_index]) if glob_start_index > 0 else search_folder
                remaining_pattern = str(Path(*parts[glob_start_index:]))
                if pattern_search_folder.exists():
                    for f in pattern_search_folder.rglob(remaining_pattern):
                        if f.is_file():
                            _add_file_to_results(matched_files, f, folder)
        else:
            matched_files = {}
            for f in folder.glob(glob_pattern):
                if f.is_file():
                    _add_file_to_results(matched_files, f, folder)
        
        return matched_files
    
    files_dict: dict[str, bytes] = {}
    
    for file_info in file_patterns:
        pattern = file_info[0]
        dest_location = Path(file_info[1])
        
        # Try to find files in base_folder first
        matched_files = _search_pattern_in_folder(base_folder, pattern)
        
        # If no files found and alternative_folder is provided, try there
        if not matched_files and alternative_folder is not None:
            if logger: logger.debug(f"No files found in {base_folder} for pattern {pattern}, trying alternative folder {alternative_folder}")
            matched_files = _search_pattern_in_folder(alternative_folder, pattern)
            if matched_files and logger: logger.warning(f"Used alternative folder '{alternative_folder}' to get '{pattern}' because nothing was found in '{base_folder}'")
        
        # Add matched files to result
        files_dict = files_dict | matched_files
    
    return files_dict
    
