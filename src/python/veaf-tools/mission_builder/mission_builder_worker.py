"""
Worker module for the VEAF Mission Builder Package.
"""

from pathlib import Path
from typing import List, Optional, Dict
from mission_tools import read_miz, write_miz, create_miz, DcsMission, get_community_script_files, get_mission_data_files, get_mission_script_files, get_veaf_script_files
from veaf_logger import VeafLogger

class MissionBuilderWorker:
    """
    Worker class that builds a mission, based on a folder containing the mission files, and on the VEAF Mission Creation Tools package.
    """
    
    def __init__(self,mission_folder: Path, output_mission: Path, logger: Optional[VeafLogger], dynamic_mode: Optional[bool] , scripts_path: Optional[Path], migrate_from_v5:bool = True):
        """
        Initialize the worker with parameters for both use cases.
        """
        
        self.logger: VeafLogger = logger
        self.output_mission = output_mission
        self.mission_folder = mission_folder
        self.dynamic_mode = dynamic_mode
        self.scripts_path = scripts_path
        self.dcs_mission: DcsMission = None
        self.migrate_from_v5:bool = migrate_from_v5
        self.collected_community_script_files: Optional[dict[str, bytes]] = None
        self.collected_veaf_script_files: Optional[dict[str, bytes]] = None
        self.collected_mission_script_files: Optional[dict[str, bytes]] = None
        self.collected_mission_data_files: Optional[dict[str, bytes]] = None
        
        if self.mission_folder and not self.mission_folder.is_dir():
            self.logger.error(f"The input mission folder '{self.mission_folder}' does not exist or is not a folder", raise_exception=True)

    def get_collected_veaf_script_files(self) -> dict[str, bytes]:
        if self.collected_veaf_script_files: return self.collected_veaf_script_files

        # Preprocess the veaf script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "node_modules" / "veaf-mission-creation-tools")
        self.collected_veaf_script_files = self.collect_files_from_globs(base_folder=scripts_folder, file_patterns=get_veaf_script_files())
        return self.collected_veaf_script_files
    
    def get_collected_community_script_files(self) -> dict[str, bytes]:
        if self.collected_community_script_files: return self.collected_community_script_files

        # Preprocess the community script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "node_modules" / "veaf-mission-creation-tools")
        self.collected_community_script_files = self.collect_files_from_globs(base_folder=scripts_folder, file_patterns=get_community_script_files())
        return self.collected_community_script_files
    
    def get_collected_mission_script_files(self) -> dict[str, bytes]:
        if self.collected_mission_script_files: return self.collected_mission_script_files

        # Preprocess the mission files
        self.collected_mission_script_files = self.collect_files_from_globs(base_folder=self.mission_folder, file_patterns=get_mission_script_files())
        return self.collected_mission_script_files

    def get_collected_mission_data_files(self) -> dict[str, bytes]:
        if self.collected_mission_data_files: return self.collected_mission_data_files

        # Preprocess the mission files
        self.collected_mission_data_files = self.collect_files_from_globs(base_folder=self.mission_folder, file_patterns=get_mission_data_files())
        return self.collected_mission_data_files

    def collect_files_from_globs(self, base_folder: Path, file_patterns: List[tuple[str, str]]) -> Dict[str, bytes]:
        """
        Collect files from a base folder using file paths and glob patterns.

        Args:
            base_folder: The base directory to search from
            file_patterns: List of file paths or glob patterns (e.g., "src/scripts/*.lua", "src/mission/*")

        Returns:
            Dictionary with:
                - key: relative file path from base_folder (with subfolders)
                - value: file contents as bytes

        Example:
            >>> base = Path("/project")
            >>> patterns = ["src/*.py", "config/settings.json"]
            >>> files = collect_files_from_globs(base, patterns)
            >>> # Returns: {"src/main.py": b"...", "src/utils.py": b"...", "config/settings.json": b"..."}
        """
        
        def _add_file_to_result_list(file_path:Path) -> None:
            relative_path = file_path.relative_to(folder).parent.as_posix()
            relative_path = dest_location / relative_path / file_path.name
            self.logger.debug(f"Processing file {relative_path}")
            files_dict[relative_path] = file_path.read_bytes()

        files_dict: Dict[str, bytes] = {}

        for file_info in file_patterns:
            pattern = file_info[0]
            dest_location = Path(file_info[1])

            # Convert pattern to Path and split into folder and glob parts
            pattern_path = base_folder / pattern
            folder = pattern_path.parent
            glob_pattern = pattern_path.name

            # Skip if the folder doesn't exist
            if not folder.exists():
                continue

            # Use rglob for recursive matching if pattern contains **
            if "**" in pattern:
                # For recursive globs, search from the appropriate parent
                parts = Path(pattern).parts
                if "**" in parts:
                    # Find the ** position and adjust folder accordingly
                    glob_start_index = parts.index("**")
                    search_folder = base_folder / Path(*parts[:glob_start_index]) if glob_start_index > 0 else base_folder
                    remaining_pattern = str(Path(*parts[glob_start_index:]))
                    if search_folder.exists():
                        for file_path in search_folder.rglob(remaining_pattern):
                            if file_path.is_file():
                                _add_file_to_result_list(file_path=file_path)
            else:
                # Use regular glob for non-recursive patterns
                for file_path in folder.glob(glob_pattern):
                    if file_path.is_file():
                        _add_file_to_result_list(file_path=file_path)

        return files_dict
        
    def create_mission(self) -> None:
        """Creates the initial mission file from the mission folder."""

        self.logger.debug("Create the initial mission file from the mission folder")
        
        files = self.get_collected_community_script_files() | self.get_collected_veaf_script_files() | self.get_collected_mission_script_files() | self.get_collected_mission_data_files()
        self.logger.debug(f"Preprocessed {len(files)} files")

        self.logger.debug("Creating the mission file")
        self.output_mission = create_miz(self.output_mission, files)
        self.logger.debug(f"Mission file created at {self.output_mission}")

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        self.logger.debug(f"Reading mission file {self.output_mission}")
        self.dcs_mission = read_miz(self.output_mission)
  
    def clear_veaf_triggers(self) -> None:
        """
        Clears all the VEAF triggers from the current mission
        """

        def _find_veaf_triggers() -> list[str]:
            veaf_dict_keys_to_remove = []
            # Find the VEAF triggers in the dictionary
            if self.dcs_mission and self.dcs_mission.dictionary_content:
                self.logger.debug("Find the VEAF triggers in the dictionary")
                for map_key, map_value in self.dcs_mission.dictionary_content.items():
                    if map_key.startswith("VEAF_DictKey"):
                        # this is a VEAF trigger, remove it
                        self.logger.debug(f"Removing VEAF dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)
                    if self.migrate_from_v5 and map_value in [
                                                "return false -- scripts",
                                                "return false -- config",
                                                "return true -- scripts",
                                                "return true -- config",
                                                "return VEAF_DYNAMIC_PATH~=nil",
                                                "return VEAF_DYNAMIC_PATH==nil",
                                                "return VEAF_DYNAMIC_MISSIONPATH~=nil",
                                                "return VEAF_DYNAMIC_MISSIONPATH==nil",
                                            ]:
                        # this is a legacy VEAF trigger, remove it
                        self.logger.debug(f"Removing legacy VEAF v5 dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)

            # Find the VEAF triggers in the mapResource
            if self.dcs_mission and self.dcs_mission.map_resource_content:
                self.logger.debug("Find the VEAF triggers in the mapResource")
                for map_key, map_value in self.dcs_mission.map_resource_content.items():
                    if map_key.startswith("VEAF_MapKey"):
                        # this is a VEAF trigger, remove it
                        self.logger.debug(f"Removing VEAF map key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)
        
            return veaf_dict_keys_to_remove

        veaf_dict_keys_to_remove = _find_veaf_triggers()

        # Remove all these keys from the dictionary
        if self.dcs_mission and self.dcs_mission.dictionary_content:
            self.logger.debug("Clear the VEAF triggers from the dictionary")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.dictionary_content.get(dict_key):
                    self.logger.debug(f"Removing key {dict_key} from the dictionary")
                    del self.dcs_mission.dictionary_content[dict_key]

        # Remove all these keys from the mapResource
        if self.dcs_mission and self.dcs_mission.map_resource_content:
            self.logger.debug("Clear the VEAF triggers from the mapResource")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.map_resource_content.get(dict_key):
                    self.logger.debug(f"Removing key {dict_key} from the mapResource")
                    del self.dcs_mission.map_resource_content[dict_key]

        # Remove all the triggers referencing these dictionary keys from the mission
        if self.dcs_mission and self.dcs_mission.mission_content:

            mission_triggers:dict = self.dcs_mission.mission_content.get("trig", {})
            trigger_indexes_to_remove = []
            for trigger_category_list in mission_triggers.values():
                trigger_indexes_to_remove.extend(
                    [
                        trigger_index
                        for trigger_index, value in enumerate(trigger_category_list)
                        if any(s in str(value) for s in veaf_dict_keys_to_remove)
                    ]
                )

            # remove duplicates
            trigger_indexes_to_remove = list(set(trigger_indexes_to_remove))

            # make a copy of the triggers, omitting the indexes in trigger_indexes_to_remove
            self.logger.debug("Removing VEAF triggers from the mission triggers")
            new_triggers = {
                trigger_category_key: [
                    value
                    for index, value in enumerate(trigger_category_list)
                    if index not in trigger_indexes_to_remove
                ]
                for trigger_category_key, trigger_category_list in mission_triggers.items()
            }
            # rebuild the special funcStartup trigger category
            self.logger.debug("Rebuilding the special funcStartup trigger category")
            new_triggers["funcStartup"] = []
            for i in range(1, len(new_triggers["conditions"])+1):
                new_triggers["funcStartup"].append(f"['if mission.trig.conditions[{i}]() then mission.trig.actions[{i}]() end']")

            self.dcs_mission.mission_content["trig"] = new_triggers
                                                 
            # make a copy of the trigger rules, omitting  the indexes in trigger_indexes_to_remove
            self.logger.debug("Removing VEAF rules from the mission triggers rules")
            mission_triggers_rules:dict = self.dcs_mission.mission_content.get("trigrules", {})
            new_trigrules = []
            new_trigrules.extend(
                value
                for index, value in enumerate(mission_triggers_rules)
                if index not in trigger_indexes_to_remove
            )
            self.dcs_mission.mission_content["trigrules"] = new_trigrules

    def create_veaf_triggers(self) -> None:
        """
        Create all the VEAF triggers in the missin
        """
        
        veaf_dynamic_scripts_path = f"[[{self.scripts_path.resolve().as_posix()}/]]" if self.scripts_path else f"[[{(self.output_mission.parent / "node_modules/veaf-mission-creation-tools").resolve().as_posix()}/]]" 
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        new_map_resource_key_by_file = {}
        new_map_resource_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(self.get_collected_community_script_files() | self.get_collected_veaf_script_files()):
            map_resource_key =  f"VEAF_MapKey_ActionText_10{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name.as_posix()] = map_resource_key
            new_map_resource_script_files[map_resource_key] = Path(script_file_name).name

        veaf_community_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_community_script_files()]
        veaf_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_veaf_script_files()]

        new_map_resource_mission_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(self.get_collected_mission_script_files()):
            map_resource_key =  f"VEAF_MapKey_ActionText_11{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name.as_posix()] = map_resource_key
            new_map_resource_mission_script_files[map_resource_key] = Path(script_file_name).name

        veaf_mission_config_map_key = new_map_resource_key_by_file.get("l10n/default/missionConfig.lua", "")

        new_dictionary = {
            "VEAF_DictKey_ActionText_12001": f"return {"true" if self.dynamic_mode else "false"} -- scripts",
            "VEAF_DictKey_ActionText_12002": f"return {"true" if self.dynamic_mode else "false"} -- config",
            "VEAF_DictKey_ActionText_12003": "return VEAF_DYNAMIC_PATH~=nil",
            "VEAF_DictKey_ActionText_12004": "return VEAF_DYNAMIC_PATH==nil",
            "VEAF_DictKey_ActionText_12005": "return VEAF_DYNAMIC_MISSIONPATH~=nil",
            "VEAF_DictKey_ActionText_12006": "return VEAF_DYNAMIC_MISSIONPATH==nil"
        }

        conditions_trigger = [
            f"return(c_predicate(getValueDictByKey(\"{new_dict_key}\")) )"
            for new_dict_key in new_dictionary
        ]

        dynamic_script_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC SCRIPTS LOADING\\\")\");"
        for file in get_community_script_files():
            dynamic_script_loading_trigger += f";a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"{file[0]}\\\"))()\")"

        static_script_loading_trigger = "a_do_script(\"env.info(\\\"STATIC SCRIPTS LOADING\\\")\");"
        for map_resource_key in new_map_resource_script_files:
            static_script_loading_trigger += f";a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"))"

        dynamic_mission_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC MISSION LOADING\\\")\");"
        for file in new_map_resource_mission_script_files.values():
            dynamic_mission_loading_trigger += f";a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"{file}\\\"))()\")"

        static_mission_loading_trigger = "a_do_script(\"env.info(\\\"STATIC MISSION LOADING\\\")\");"
        for map_resource_key in new_map_resource_mission_script_files:
            static_mission_loading_trigger += f";a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"))"

        new_triggers = {
            "customStartup": [],
            "func": [],
            "custom": [],
            "events": [],
            "flag": [
                True,
                True,
                True,
                True,
                True,
                True
            ],
            "conditions": conditions_trigger,
            "actions": [
                f"a_do_script(\"VEAF_DYNAMIC_PATH = {veaf_dynamic_scripts_path}\");",
                f"a_do_script(\"VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}\");",
                f"{dynamic_script_loading_trigger};",
                f"{static_script_loading_trigger}",
                f"{dynamic_mission_loading_trigger};",
                f"{static_mission_loading_trigger}",
            ],
            "funcStartup": [
                "if mission.trig.conditions[1]() then mission.trig.actions[1]() end",
                "if mission.trig.conditions[2]() then mission.trig.actions[2]() end",
                "if mission.trig.conditions[3]() then mission.trig.actions[3]() end",
                "if mission.trig.conditions[4]() then mission.trig.actions[4]() end",
                "if mission.trig.conditions[5]() then mission.trig.actions[5]() end",
                "if mission.trig.conditions[6]() then mission.trig.actions[6]() end",
            ]
        }

        static_script_loading_actions = [
            {
                "predicate": "a_do_script",
                "text": "env.info(\"STATIC SCRIPTS LOADING\")"
            }
        ]
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"}
            for file_path in veaf_community_scripts_map_keys
        )
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"}
            for file_path in veaf_scripts_map_keys
        )

        dynamic_script_loading_actions = [
            {
                "predicate": "a_do_script",
                "text": "env.info(\"DYNAMIC SCRIPTS LOADING\")"
            }
        ]
        dynamic_script_loading_actions.extend(
            {
                "predicate": "a_do_script",
                "text": f"assert(loadfile(VEAF_DYNAMIC_PATH .. \"{file[0]}\"))()",
            }
            for file in get_community_script_files()
        )
        dynamic_script_loading_actions.append(
            {
                "predicate": "a_do_script",
                "text": "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/VeafDynamicLoader.lua\"))()"
            }
        )

        new_trigrules = [
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12001",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12001",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "choose scripts loading method (false = static, true = dynamic)",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "predicate": "a_do_script",
                        "text": f"VEAF_DYNAMIC_PATH = {veaf_dynamic_scripts_path}"
                    }
                ],
                "colorItem": "0x00ffffff"
            },
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12002",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12002",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "choose config loading method (false = static, true = dynamic)",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "predicate": "a_do_script",
                        "text": f"VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}"
                    }
                ],
                "colorItem": "0x00ffffff"
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12003",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12003",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "mission start - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": dynamic_script_loading_actions,
                "colorItem": "0x00ff80ff"
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12004",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12004",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "mission start - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": static_script_loading_actions,
                "colorItem": "0x00ff80ff"
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12005",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12005",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "mission config - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": "env.info(\"DYNAMIC CONFIG LOADING\")",
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184
                    },
                    {
                        "predicate": "a_do_script",
                        "text": "assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \"/src/scripts/veafDynamicConfig.lua\"))()"
                    }
                ],
                "colorItem": "0x8080ffff"
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12006",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12006",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "mission config - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": "env.info(\"STATIC CONFIG LOADING\")",
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184
                    },
                    {
                        "predicate": "a_do_script_file",
                        "file": f"{veaf_mission_config_map_key}"
                    }
                ],
                "colorItem": "0x8080ffff"
            }
        ]

        # merge the new dictionary with the mission dictionary
        self.dcs_mission.dictionary_content = new_dictionary | self.dcs_mission.dictionary_content

        # merge the new mapResource with the mission mapResource
        self.dcs_mission.map_resource_content = new_map_resource_script_files | new_map_resource_mission_script_files | self.dcs_mission.map_resource_content

        # merge the new triggers with the mission triggers
        for trigger_category in self.dcs_mission.mission_content["trig"]:
            category = new_triggers.get(trigger_category, {})
            category.extend(self.dcs_mission.mission_content["trig"][trigger_category])
            self.dcs_mission.mission_content["trig"][trigger_category] = category

        # rebuild the special funcStartup trigger category
        self.logger.debug("Rebuilding the special funcStartup trigger category")
        self.dcs_mission.mission_content.get("trig", {})["funcStartup"] = []
        for i in range(1, len(self.dcs_mission.mission_content.get("trig", {})["conditions"])+1):
            self.dcs_mission.mission_content.get("trig", {})["funcStartup"].append(f"['if mission.trig.conditions[{i}]() then mission.trig.actions[{i}]() end']")

        # merge the new trigrules with the mission trigrules
        self.dcs_mission.mission_content["trigrules"] = new_trigrules + self.dcs_mission.mission_content.get("trigrules", {})
                    
    def write_mission(self) -> None:
        """Write the mission file."""

        self.logger.debug("Writing mission file")
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)
        self.logger.debug("Writing mission file done")

    def work(self) -> None:
        """Main work function."""

        # Create the initial mission file
        self.create_mission()

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        self.read_mission()

        # First, remove all the VEAF triggers
        self.clear_veaf_triggers()

        # Then, add all the VEAF triggers we need
        self.create_veaf_triggers()

        # Write the mission file
        self.write_mission()

        self.logger.info(f"Mission file '{self.output_mission}' built from folder '{self.mission_folder}'.")
