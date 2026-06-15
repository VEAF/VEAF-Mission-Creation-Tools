from pathlib import Path

from veaf_libs.i18n import t

DEFAULT_SCRIPTS_LOCATION: str = "l10n/DEFAULT"


def get_legacy_script_files() -> list[tuple[str, str]]:
    """Get list of files that should be removed from any newly extracted mission; they are old VEAF files that are not used anymore"""

    return [
        # The VEAF scripts
        ("src/scripts/veaf/veaf-scripts-debug.lua", DEFAULT_SCRIPTS_LOCATION),
        ("src/scripts/veaf/veaf-scripts-trace.lua", DEFAULT_SCRIPTS_LOCATION),
    ]


def get_community_script_files() -> list[dict[str, str]]:
    """Get list of community LUA files.

    Each entry is a dict with keys:
        - ``id``: stable identifier used in ``community_scripts:`` section of ``mission.yaml``
        - ``path``: source path relative to the scripts root
        - ``dest``: destination location inside the ``.miz`` archive

    Returns:
        List of community script descriptors.
    """

    return [
        {"id": "mist", "path": "src/scripts/community/mist.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "stts", "path": "src/scripts/community/DCS-SimpleTextToSpeech.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "ctld", "path": "src/scripts/community/CTLD.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "aien", "path": "src/scripts/community/AIEN.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "csar", "path": "src/scripts/community/CSAR.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "hercules", "path": "src/scripts/community/Hercules_Cargo.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "skynet", "path": "src/scripts/community/skynet-iads-compiled.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "tum", "path": "src/scripts/community/TheUniversalMission.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
    ]


def get_optin_community_script_ids() -> set[str]:
    """Community script ids that are OFF unless explicitly enabled (opt-in).

    Most community scripts are opt-out (active by default unless turned off). A few
    impose a mission-design contract and must never start on their own — e.g. TUM
    (TheUniversalMission) requires BLUFOR/REDFOR territory zones each owning an
    airbase, and raises a start-up error otherwise. Those are opt-in: a vanilla
    mission, a freshly converted v5 mission, or a ``modules:`` block that does not
    mention them leaves them disabled; only ``<ID>: true`` turns them on.
    """
    return {"tum"}


def is_community_script_enabled_by_default(script_id: str) -> bool:
    """Return whether a community script is active when not explicitly listed.

    This is the single source of truth for the "no ``community_scripts:`` section,
    or id not listed" case, shared by the builder enablement and the config
    generator so the two paths cannot drift apart: opt-out scripts default to
    enabled, opt-in scripts (see :func:`get_optin_community_script_ids`) default
    to disabled.

    Args:
        script_id: The community script id (e.g. ``"ctld"``, ``"tum"``).

    Returns:
        True when the script is on by default, False for opt-in scripts.
    """
    return script_id not in get_optin_community_script_ids()


def get_community_sound_files() -> dict[str, tuple[str, ...]]:
    """Sound assets required by community scripts, keyed by community script id.

    CTLD and CSAR play these ``.ogg`` files by name at runtime
    (``outSoundForCoalition("beacon.ogg")`` …), so the files must be packaged in
    the mission's ``l10n/DEFAULT/`` folder. The tool ships them under
    ``src/scripts/community/sounds/`` and the build injects the ones a mission
    is missing when the owning module is enabled.

    Returns:
        Mapping of community script id to the sound filenames it requires.
    """

    return {
        "ctld": ("beacon.ogg", "beaconsilent.ogg", "radiobeep.ogg"),
        "csar": ("beacon.ogg", "CSAR.ogg"),
    }


def get_veaf_script_files() -> list[tuple[str, str]]:
    """Get list of VEAF script files.Those can be in published or in the scripts folder, depending on the --dynamic-mode option"""

    return [
        # The main VEAF scripts
        ("src/scripts/veaf/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
    ]


def get_mission_script_files() -> list[tuple[str, str]]:
    """Get list of the mission files. Those are either in the mission folder or in the VEAF defaults folder"""

    return [
        # Optional generated module config; loaded BEFORE mission-script.lua
        ("src/scripts/veaf-config.lua", DEFAULT_SCRIPTS_LOCATION),
        # The mission scripts
        ("src/scripts/mission-script.lua", DEFAULT_SCRIPTS_LOCATION),
        ("src/scripts/veafDynamicConfig.lua", DEFAULT_SCRIPTS_LOCATION),
        ("src/scripts/*.lua", DEFAULT_SCRIPTS_LOCATION),
    ]


def get_mission_data_files() -> list[tuple[str, str]]:
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
        (f"{DEFAULT_SCRIPTS_LOCATION}/mission-script.lua", True),
        (f"{DEFAULT_SCRIPTS_LOCATION}/veafDynamicConfig.lua", True),
        ("options", False),
        ("mission/Config", False),
        ("mission/Scripts", False),
        ("mission/track", False),
        ("mission/track_data", False),
    ]


def collect_files_from_globs(
    base_folder: Path, file_patterns: list[tuple[str, str]], alternative_folder: Path | None = None, logger=None
) -> dict[str, bytes]:
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

    def _add_file_to_results(results: dict[str, bytes], file_path: Path, base_folder: Path) -> None:
        relative_path = file_path.relative_to(base_folder).parent.as_posix()
        key = (dest_location / relative_path / file_path.name).as_posix()
        if logger:
            logger.debug(f"Processing file {key}")
        results[key] = file_path.read_bytes()

    def _search_pattern_in_folder(search_folder: Path, pattern: str) -> dict[str, bytes]:
        """Search for files matching pattern in the given folder."""
        if not search_folder.exists():
            return {}

        pattern_path = search_folder / pattern
        folder = pattern_path.parent
        glob_pattern = pattern_path.name

        if not folder.exists():
            return {}

        matched_files: dict[str, bytes] = {}

        if "**" in pattern:
            parts = Path(pattern).parts
            if "**" in parts:
                glob_start_index = parts.index("**")
                pattern_search_folder = (
                    search_folder / Path(*parts[:glob_start_index]) if glob_start_index > 0 else search_folder
                )
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
            if logger:
                logger.debug(
                    f"No files found in {base_folder} for pattern {pattern}, trying alternative folder {alternative_folder}"
                )
            matched_files = _search_pattern_in_folder(alternative_folder, pattern)
            if matched_files and logger:
                logger.warning(
                    t("mission_tools.alternative_folder", alt=alternative_folder, file=pattern, orig=base_folder)
                )

        # Add matched files to result
        files_dict = files_dict | matched_files

    return files_dict
