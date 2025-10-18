"""
Worker module for the VEAF Mission Builder Package.
"""

from pathlib import Path
import re
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
            for trigger_category_value in mission_triggers.values():
                if isinstance(trigger_category_value, list):
                    trigger_indexes_to_remove.extend(
                        [
                            trigger_index
                            for trigger_index, value in enumerate(trigger_category_value)
                            if any(s in str(value) for s in veaf_dict_keys_to_remove)
                        ]
                    )
                elif isinstance(trigger_category_value, dict):
                    trigger_indexes_to_remove.extend(
                        [
                            trigger_key
                            for trigger_key, value in trigger_category_value.items()
                            if any(s in str(value) for s in veaf_dict_keys_to_remove)
                        ]
                    )

            # remove duplicates
            trigger_indexes_to_remove = list(set(trigger_indexes_to_remove))

            # and now remove the triggers
            for trigger_category_index, trigger_category_value in mission_triggers.items():
                for trigger_index in trigger_indexes_to_remove:
                    if trigger_category_value.get(trigger_index): 
                        del trigger_category_value[trigger_index]                       

            # and now remove the trigrules
            for trigger_index in trigger_indexes_to_remove:
                if self.dcs_mission.mission_content["trigrules"].get(trigger_index): del self.dcs_mission.mission_content["trigrules"][trigger_index]

    def insert_all_veaf_triggers(self) -> None:
        """
        Create all the VEAF triggers in the mission.
        First, we'll update the dictionary.
        Then we'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        We'll also add 6 corresponding trigrules, shifting the existing ones accordingly
        """
        new_dictionary = self.update_dictionary_with_veaf_entries()
        new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file = self.update_map_resource_with_veaf_entries()
        self.insert_veaf_triggers(new_dictionary, new_map_resource_script_files, new_map_resource_mission_script_files)
        self.insert_veaf_trigrules(new_map_resource_key_by_file)

    def update_dictionary_with_veaf_entries(self) -> dict:
        """
        Update the dictionary for all the VEAF triggers in the mission.
        """

        new_dictionary = {
            "VEAF_DictKey_ActionText_12001": f"return {"true" if self.dynamic_mode else "false"} -- VEAF scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12002": f"return {"true" if self.dynamic_mode else "false"} -- Mission scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12003": "return VEAF_DYNAMIC_SCRIPTSPATH~=nil",
            "VEAF_DictKey_ActionText_12004": "return VEAF_DYNAMIC_SCRIPTSPATH==nil",
            "VEAF_DictKey_ActionText_12005": "return VEAF_DYNAMIC_MISSIONPATH~=nil",
            "VEAF_DictKey_ActionText_12006": "return VEAF_DYNAMIC_MISSIONPATH==nil"
        }

        # merge the new dictionary with the mission dictionary
        self.dcs_mission.dictionary_content = new_dictionary | self.dcs_mission.dictionary_content

        return new_dictionary

    def update_map_resource_with_veaf_entries(self) -> tuple[dict, dict, dict]:
        """
        Update the map resource for all the VEAF triggers in the mission.
        """

        new_map_resource_key_by_file = {}
        new_map_resource_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(self.get_collected_community_script_files() | self.get_collected_veaf_script_files()):
            map_resource_key =  f"VEAF_MapKey_ActionText_10{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name.as_posix()] = map_resource_key
            new_map_resource_script_files[map_resource_key] = Path(script_file_name).name

        new_map_resource_mission_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(self.get_collected_mission_script_files()):
            map_resource_key =  f"VEAF_MapKey_ActionText_11{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name.as_posix()] = map_resource_key
            new_map_resource_mission_script_files[map_resource_key] = Path(script_file_name).name

        # merge the new mapResource with the mission mapResource
        self.dcs_mission.map_resource_content = new_map_resource_script_files | new_map_resource_mission_script_files | self.dcs_mission.map_resource_content

        return new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file

    def insert_veaf_triggers(self, new_dictionary:dict, new_map_resource_script_files:dict, new_map_resource_mission_script_files:dict) -> None:
        """
        Create all the VEAF triggers in the mission.
        We'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        """

        def transform_triggers_dcs_structure_to_new_structure(triggers) -> dict:
            """
            Converts DCS triggers structure to our new triggers structure
            DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
            Each of these categories is a LUA table with all the data for each trigger about this category.
            To properly insert our VEAF triggers to the mission triggers, we need to make sure that we move (shift) all the keys in each category in a coherent fashion.
            """
            # Let's create a better structure: a list of triggers which all have the corresponding categories.
            category_names = triggers.keys()
            result = {}
            action_keys = sorted(triggers["actions"].keys()) # this is the most complete category, it always contains all the triggers; this is important later
            for category_name in category_names:
                if category_data := triggers[category_name]:
                    for trigger_key in action_keys:
                        if trigger_key in category_data:
                            if trigger_key not in result:
                                # create the new trigger in the new structure
                                result[trigger_key] = {}
                            # update the new trigger in the new structure
                            result[trigger_key][category_name] = category_data[trigger_key]        
            return result

        def transform_triggers_new_structure_to_dcs_structure(triggers) -> dict:
            """
            Converts our new triggers structure back to DCS triggers structure
            DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
            Each of these categories is a LUA table with all the data for each trigger about this category.
            """

            result = {}
            for trigger_key, trigger_data in triggers.items():
                for category_name, category_data in trigger_data.items():
                    if category_name not in result:
                        result[category_name] = {}
                    result[category_name][trigger_key] = category_data

            return result

        conditions_trigger = {
            idx + 1: f"return(c_predicate(getValueDictByKey(\"{new_dict_key}\")) )"
            for idx, new_dict_key in enumerate(new_dictionary)
        }

        dynamic_script_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC VEAF scripts loading\\\")\");"
        for file in get_community_script_files():
            dynamic_script_loading_trigger += f"a_do_script(\"assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\\"{file[0]}\\\"))()\");"
        dynamic_script_loading_trigger += "a_do_script(\"assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\\"/src/scripts/VeafDynamicLoader.lua\\\"))()\");"

        static_script_loading_trigger = "a_do_script(\"env.info(\\\"STATIC VEAF scripts loading\\\")\");"
        for map_resource_key in new_map_resource_script_files:
            static_script_loading_trigger += f"a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"));"

        dynamic_mission_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC Mission scripts loading\\\")\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \"/src/scripts/veafDynamicConfig.lua\"))()\");"

        static_mission_loading_trigger = "a_do_script(\"env.info(\\\"STATIC Mission scripts loading\\\")\");"
        for map_resource_key in new_map_resource_mission_script_files:
            static_mission_loading_trigger += f"a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"));"

        VEAF_DYNAMIC_SCRIPTSPATH = f"[[{self.scripts_path.resolve().as_posix()}/]]" if self.scripts_path else f"[[{(self.output_mission.parent / "node_modules/veaf-mission-creation-tools").resolve().as_posix()}/]]"
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_triggers = {
            "customStartup": {},
            "func": {},
            "custom": {},
            "events": {},
            "flag": {
                1: True,
                2: True,
                3: True,
                4: True,
                5: True,
                6: True
            },
            "conditions": conditions_trigger,
            "actions": {
                1: f"a_do_script(\"VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}\");",
                2: f"a_do_script(\"VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}\");",
                3: f"{dynamic_script_loading_trigger}",
                4: f"{static_script_loading_trigger}",
                5: f"{dynamic_mission_loading_trigger}",
                6: f"{static_mission_loading_trigger}",
            },
            "funcStartup": {
                1: "if mission.trig.conditions[1]() then mission.trig.actions[1]() end",
                2: "if mission.trig.conditions[2]() then mission.trig.actions[2]() end",
                3: "if mission.trig.conditions[3]() then mission.trig.actions[3]() end",
                4: "if mission.trig.conditions[4]() then mission.trig.actions[4]() end",
                5: "if mission.trig.conditions[5]() then mission.trig.actions[5]() end",
                6: "if mission.trig.conditions[6]() then mission.trig.actions[6]() end",
            }
        }
        
        mission_triggers = self.dcs_mission.mission_content["trig"]
        # DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
        # Each of these categories is a LUA table with all the data for each trigger about this category.
        # To properly insert our VEAF triggers to the mission triggers, we need to make sure that we move (shift) all the keys in each category in a coherent fashion.

        # Let's create a better structure: a list of triggers which all have the corresponding categories.
        mission_triggers_new_structure = transform_triggers_dcs_structure_to_new_structure(mission_triggers)

        # Now let's transform our new triggers structure, too
        veaf_triggers_new_structure = transform_triggers_dcs_structure_to_new_structure(veaf_triggers)

        # Shift all the triggers up and update the LUA code if needed (whenever it contains "mission.trig.conditions[xx]" with xx the original trigger key)
        result_triggers_new_structure = {}
        nb_new_triggers = len(veaf_triggers_new_structure)
        for new_key, old_key in enumerate(sorted(mission_triggers_new_structure.keys()), start=nb_new_triggers+1):
            result_trigger_new_structure = result_triggers_new_structure[new_key] = mission_triggers_new_structure[old_key].copy()
            if new_key != old_key:
                for category_name, category_value in result_trigger_new_structure.items():
                    new_category_value = category_value # default value, if there is no need for updating the LUA
                    if isinstance(category_value, str):
                        # update the LUA code to reflect the shift
                        new_category_value = re.sub(f"\\[{old_key}\\]", f"[{new_key}]", category_value)
                    result_trigger_new_structure[category_name] = new_category_value

        # Insert the new VEAF triggers at the beginning of our new structure
        for new_trigger_key, new_trigger_data in veaf_triggers_new_structure.items():
            result_triggers_new_structure[new_trigger_key] = new_trigger_data
        
        # Convert the new structure back to a valid DCS structure
        self.dcs_mission.mission_content["trig"] = transform_triggers_new_structure_to_dcs_structure(result_triggers_new_structure)

    def insert_veaf_trigrules(self, new_map_resource_key_by_file:dict) -> None:
        """
        Create all the VEAF trigrules in the mission.
        We'll add 6 trigrules corresponding to the 6 new triggers.
        All existing trigrules will be shifted 6 ranks up, changing the indexes in the LUA code.
        """
        
        VEAF_DYNAMIC_SCRIPTSPATH = f"[[{self.scripts_path.resolve().as_posix()}/]]" if self.scripts_path else f"[[{(self.output_mission.parent / "node_modules/veaf-mission-creation-tools").resolve().as_posix()}/]]"
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_community_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_community_script_files()]
        veaf_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_veaf_script_files()]

        veaf_mission_config_map_key = new_map_resource_key_by_file.get("l10n/default/missionConfig.lua", "")

        static_script_loading_actions = [
            {
                "predicate": "a_do_script",
                "text": "env.info(\"STATIC VEAF scripts loading\")"
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
                "text": "env.info(\"DYNAMIC VEAF scripts loading\")"
            }
        ]
        dynamic_script_loading_actions.extend(
            {
                "predicate": "a_do_script",
                "text": f"assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \"{file[0]}\"))()",
            }
            for file in get_community_script_files()
        )
        dynamic_script_loading_actions.append(
            {
                "predicate": "a_do_script",
                "text": "assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \"/src/scripts/VeafDynamicLoader.lua\"))()"
            }
        )

        new_trigrules_list = [
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12001",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12001",
                        "predicate": "c_predicate"
                    }
                ],
                "comment": "VEAF scripts loading method",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "predicate": "a_do_script",
                        "text": f"VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}"
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
                "comment": "Mission scripts loading method",
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
                "comment": "VEAF scripts loading - dynamic",
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
                "comment": "VEAF scripts loading - static",
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
                "comment": "Mission scripts loading - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": "env.info(\"DYNAMIC Mission scripts loading\")",
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
                "comment": "Mission scripts loading - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": "env.info(\"STATIC Mission scripts loading\")",
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

        # compress the dictionary keyset, leaving space for the VEAF trigrules
        trigrules = self.dcs_mission.mission_content["trigrules"]
        new_trigrules = dict(enumerate(new_trigrules_list, start=1))
        nb_new_trigrules = len(new_trigrules)
        result_trigrules = {
            new_key: trigrules[old_key]
            for new_key, old_key in enumerate(
                sorted(trigrules.keys()), start=nb_new_trigrules + 1
            )
        }
        # insert the new elements
        for new_index, new_item in new_trigrules.items():
            result_trigrules[new_index] = new_item
        # set the new dictionary
        self.dcs_mission.mission_content["trigrules"] = result_trigrules
        
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
        self.insert_all_veaf_triggers()

        # Write the mission file
        self.write_mission()

        self.logger.info(f"Mission file '{self.output_mission}' built from folder '{self.mission_folder}'.")
