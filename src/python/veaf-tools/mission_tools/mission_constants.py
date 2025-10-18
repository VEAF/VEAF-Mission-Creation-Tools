DEFAULT_SCRIPTS_LOCATION:str = "l10n/default"

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
    """Get list of the mission files. Those are always in the mission folder"""

    return [
            # The mission scripts
            ("src/scripts/missionConfig.lua", DEFAULT_SCRIPTS_LOCATION),
            ("src/scripts/veafDynamicConfig.lua", DEFAULT_SCRIPTS_LOCATION),
    ]

def get_mission_data_files() -> list[(str, str)]:
    """Get list of the mission files. Those are always in the mission folder"""

    return [
            # The mission files
            ("src/mission/**", ""),

            # The options file
            ("src/options", ""),
    ]

def get_mission_files_to_cleanup_on_extract() -> list[str]:
    """Get list of the mission files that need to be cleaned up when extracting a mission file."""

    return [
            "options",
            "Config",
            "Scripts",
            "track",
            "track_data"
    ]
