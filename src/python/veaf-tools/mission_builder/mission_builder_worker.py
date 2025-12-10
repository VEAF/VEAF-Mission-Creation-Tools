"""
Worker module for the VEAF Mission Builder Package.
"""

from pathlib import Path
import re
import shutil
from typing import Optional
from mission_tools import read_miz, write_miz, create_miz, DcsMission, get_community_script_files, get_mission_data_files, get_mission_script_files, get_veaf_script_files, collect_files_from_globs, DEFAULT_SCRIPTS_LOCATION
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context, progress_context

class MissionBuilderWorker:
    """
    Worker class that builds a mission, based on a folder containing the mission files, and on the VEAF Mission Creation Tools package.
    """
    
    def __init__(self,mission_folder: Path, output_mission: Path, dynamic_mode: Optional[bool] , scripts_path: Optional[Path], migrate_from_v5:bool = True, no_veaf_triggers: bool = False, scripts_variant: str = "standard"):
        """
        Initialize the worker with parameters for both use cases.
        """
        
        self.output_mission = output_mission
        self.mission_folder = mission_folder
        self.dynamic_mode = dynamic_mode
        self.scripts_path = scripts_path
        self.dcs_mission: DcsMission = None
        self.migrate_from_v5: bool = migrate_from_v5
        self.no_veaf_triggers: bool = no_veaf_triggers
        self.scripts_variant: str = scripts_variant
        self.collected_community_script_files: Optional[dict[str, bytes]] = None
        self.collected_veaf_script_files: Optional[dict[str, bytes]] = None
        self.collected_mission_script_files: Optional[dict[str, bytes]] = None
        self.collected_mission_data_files: Optional[dict[str, bytes]] = None
        
        if self.mission_folder and not self.mission_folder.is_dir():
            logger.error(f"The input mission folder '{self.mission_folder}' does not exist or is not a folder", exception_type=FileNotFoundError)

    def get_collected_veaf_script_files(self) -> dict[str, bytes]:
        if self.collected_veaf_script_files: return self.collected_veaf_script_files

        # Preprocess the veaf script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")
        
        # Select the appropriate script variant
        if self.scripts_variant == "debug":
            script_filename = "veaf-scripts-debug.lua"
        elif self.scripts_variant == "trace":
            script_filename = "veaf-scripts-trace.lua"
        else:  # "standard" or default
            script_filename = "veaf-scripts.lua"
        
        # Build file patterns for collect_files_from_globs
        # We need to use the variant name in the glob pattern
        variant_patterns = [
            (f"src/scripts/veaf/{script_filename}", DEFAULT_SCRIPTS_LOCATION)
        ]
        
        self.collected_veaf_script_files = collect_files_from_globs(base_folder=scripts_folder, file_patterns=variant_patterns)
        
        # If the variant file is not found, fallback to standard (but log a warning)
        if len(self.collected_veaf_script_files) == 0 and self.scripts_variant != "standard":
            logger.warning(f"Scripts variant '{self.scripts_variant}' not found, falling back to 'standard'")
            self.collected_veaf_script_files = collect_files_from_globs(base_folder=scripts_folder, file_patterns=[("src/scripts/veaf/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)])
        
        if len(self.collected_veaf_script_files) < 1:
            logger.error(f"VEAF scripts file not found at {scripts_folder}/src/scripts/veaf/{script_filename}")
        
        return self.collected_veaf_script_files
    
    def get_collected_community_script_files(self) -> dict[str, bytes]:
        if self.collected_community_script_files: return self.collected_community_script_files

        # Preprocess the community script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")
        self.collected_community_script_files = collect_files_from_globs(base_folder=scripts_folder, file_patterns=get_community_script_files())
        if len(self.collected_community_script_files) < len(get_community_script_files()):
            self.signal_missing_required_files_after_collection(get_community_script_files(), self.collected_community_script_files, scripts_folder)
        return self.collected_community_script_files

    def signal_missing_required_files_after_collection(self, expected_files: list[tuple[str, str]], collected_files: dict[str, bytes], scripts_folder: Path):
        """Signal missing files after collection with detailed information."""
        collected_file_paths = {Path(path).name for path in collected_files}
        missing_files = [Path(file_pattern[0]).name for file_pattern in expected_files if Path(file_pattern[0]).name not in collected_file_paths]

        message = f"Error: missing files from {scripts_folder}:\n"
        for missing_file in sorted(missing_files):
            message += f"  - {missing_file}\n"
        message = message.rstrip("\n")
        message += "\nTry updating the veaf-tools package using veaf-tools-updater.exe!"
        logger.error(message=message, raise_exception=False)
        exit()
    
    def get_collected_mission_script_files(self) -> dict[str, bytes]:
        if self.collected_mission_script_files: return self.collected_mission_script_files

        # Preprocess the mission files
        defaults_folder: Path = (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        self.collected_mission_script_files = collect_files_from_globs(base_folder=self.mission_folder, file_patterns=get_mission_script_files(), alternative_folder=defaults_folder)
        return self.collected_mission_script_files

    def get_collected_mission_data_files(self) -> dict[str, bytes]:
        if self.collected_mission_data_files: return self.collected_mission_data_files

        # Preprocess the mission files
        defaults_folder: Path = (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        self.collected_mission_data_files = collect_files_from_globs(base_folder=self.mission_folder, file_patterns=get_mission_data_files(), alternative_folder=defaults_folder)
        return self.collected_mission_data_files
       
    def complete_src_folder_with_defaults(self) -> None:
        defaults_folder: Path = (self.scripts_path or (self.mission_folder / "published")) / "defaults" / "mission-folder"
        for f in defaults_folder.rglob("*"):
            if f.is_file():
                relative_path = f.relative_to(defaults_folder).parent.as_posix()
                relative_path = self.mission_folder / relative_path / f.name
                if not relative_path.exists():
                    relative_path.parent.mkdir(parents=True, exist_ok=True)
                    logger.warning(f"Copied required file '{relative_path}' from default folder '{defaults_folder}'")
                    shutil.copy(f, relative_path)

    def create_mission(self) -> None:
        """Creates the initial mission file from the mission folder."""

        logger.debug("Create the initial mission file from the mission folder")
        
        files = self.get_collected_community_script_files() | self.get_collected_veaf_script_files() | self.get_collected_mission_script_files() | self.get_collected_mission_data_files()
        logger.debug(f"Preprocessed {len(files)} files")

        logger.debug("Creating the mission file")
        self.output_mission = create_miz(self.output_mission, files)
        logger.debug(f"Mission file created at {self.output_mission}")

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        logger.debug(f"Reading mission file {self.output_mission}")
        try:
            self.dcs_mission = read_miz(self.output_mission)
            if self.dcs_mission.missing_components and 'options' in self.dcs_mission.missing_components:
                logger.warning(f"The 'options' file is missing from {self.mission_folder / "src"}; it's a useful item of your source tree!")
                self.dcs_mission.missing_components.remove('options') # we've handled that one
            if self.dcs_mission.missing_components:
                message = f"These components are missing from '{self.mission_folder / "src"}': {', '.join([f"'{item}'" for item in self.dcs_mission.missing_components])}; they are mandatory in a DCS mission!"
                logger.error(message=message, exception_type=RuntimeError)
        except KeyError:
            logger.error(f"An error occured while reading the {self.output_mission} file; is this a valid DCS mission?")
            raise
  
    def clear_veaf_triggers(self) -> None:
        """
        Clears all the VEAF triggers from the current mission
        """

        def _find_veaf_triggers() -> list[str]:
            veaf_dict_keys_to_remove = []
            # Find the VEAF triggers in the dictionary
            if self.dcs_mission and self.dcs_mission.dictionary_content:
                logger.debug("Find the VEAF triggers in the dictionary")
                for map_key, map_value in self.dcs_mission.dictionary_content.items():
                    if map_key.startswith("VEAF_DictKey"):
                        # this is a VEAF trigger, remove it
                        logger.debug(f"Removing VEAF dictionary key {map_key}={map_value}")
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
                        logger.debug(f"Removing legacy VEAF v5 dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)

            # Find the VEAF triggers in the mapResource
            if self.dcs_mission and self.dcs_mission.map_resource_content:
                logger.debug("Find the VEAF triggers in the mapResource")
                for map_key, map_value in self.dcs_mission.map_resource_content.items():
                    if map_key.startswith("VEAF_MapKey"):
                        # this is a VEAF trigger, remove it
                        logger.debug(f"Removing VEAF map key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)
        
            return veaf_dict_keys_to_remove

        veaf_dict_keys_to_remove = _find_veaf_triggers()

        # Remove all these keys from the dictionary
        if self.dcs_mission and self.dcs_mission.dictionary_content:
            logger.debug("Clear the VEAF triggers from the dictionary")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.dictionary_content.get(dict_key):
                    logger.debug(f"Removing key {dict_key} from the dictionary")
                    del self.dcs_mission.dictionary_content[dict_key]

        # Remove all these keys from the mapResource
        if self.dcs_mission and self.dcs_mission.map_resource_content:
            logger.debug("Clear the VEAF triggers from the mapResource")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.map_resource_content.get(dict_key):
                    logger.debug(f"Removing key {dict_key} from the mapResource")
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
                category_data = triggers[category_name]
                for trigger_key in action_keys:
                    if trigger_key not in result:
                        # create the new trigger in the new structure
                        result[trigger_key] = {}
                    if trigger_key in category_data:
                        # update the new trigger in the new structure to the category value
                        result[trigger_key][category_name] = category_data[trigger_key]        
                    else:
                        # update the new trigger in the new structure to an empty value
                        result[trigger_key][category_name] = None

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
                    if category_data:
                        result[category_name][trigger_key] = category_data

            return result

        conditions_trigger = {
            idx + 1: f"return(c_predicate(getValueDictByKey(\"{new_dict_key}\")) )"
            for idx, new_dict_key in enumerate(new_dictionary)
        }

        dynamic_script_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC VEAF scripts loading from \\\"..VEAF_DYNAMIC_SCRIPTSPATH)\");"
        for file in get_community_script_files():
            dynamic_script_loading_trigger += f"a_do_script(\"assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\\"{file[0]}\\\"))()\");"
        dynamic_script_loading_trigger += "a_do_script(\"assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\\"/src/scripts/VeafDynamicLoader.lua\\\"))()\");"

        static_script_loading_trigger = "a_do_script(\"env.info(\\\"STATIC VEAF scripts loading\\\")\");"
        for map_resource_key in new_map_resource_script_files:
            static_script_loading_trigger += f"a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"));"

        dynamic_mission_loading_trigger = "a_do_script(\"env.info(\\\"DYNAMIC Mission scripts loading from \\\"..VEAF_DYNAMIC_MISSIONPATH)\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \\\"/src/scripts/veafDynamicConfig.lua\\\"))()\");"

        static_mission_loading_trigger = "a_do_script(\"env.info(\\\"STATIC Mission scripts loading\\\")\");"
        for map_resource_key in new_map_resource_mission_script_files:
            static_mission_loading_trigger += f"a_do_script_file(getValueResourceByKey(\"{map_resource_key}\"));"

        VEAF_DYNAMIC_SCRIPTSPATH = f"[[{self.scripts_path.resolve().as_posix()}/]]" if self.scripts_path else f"[[{(self.output_mission.parent / "published").resolve().as_posix()}/]]"
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
        
        VEAF_DYNAMIC_SCRIPTSPATH = f"[[{self.scripts_path.resolve().as_posix()}/]]" if self.scripts_path else f"[[{(self.output_mission.parent / "published").resolve().as_posix()}/]]"
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_community_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_community_script_files()]
        veaf_scripts_map_keys = [new_map_resource_key_by_file.get(script_file_name.as_posix(), "") for script_file_name in self.get_collected_veaf_script_files()]

        veaf_mission_config_map_key = new_map_resource_key_by_file.get(f"{DEFAULT_SCRIPTS_LOCATION}/missionConfig.lua", "")

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
                "text": "env.info(\"DYNAMIC VEAF scripts loading from \"..VEAF_DYNAMIC_SCRIPTSPATH)"
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
                        "text": "env.info(\"DYNAMIC Mission scripts loading from \"..VEAF_DYNAMIC_MISSIONPATH)",
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

        logger.debug("Writing mission file")
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)
        logger.debug("Writing mission file done")

    def work(self, silent: bool = False) -> Path:
        """Main work function."""

        # Complete the src folder with default files if they don't exist
        with spinner_context(f"Completing folder {self.mission_folder} with defaults...", silent=silent):
            self.complete_src_folder_with_defaults()

        # Create the initial mission file
        with spinner_context(f"Creating mission {self.output_mission}...", silent=silent):
            self.create_mission()

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        with spinner_context(f"Reading mission {self.output_mission}...", silent=silent):
            self.read_mission()

        # First, remove all the VEAF triggers
        with spinner_context("Clearing the existing VEAF triggers...", silent=silent):
            self.clear_veaf_triggers()

        # Then, add all the VEAF triggers we need
        if not self.no_veaf_triggers:
            with spinner_context("Creating the new VEAF triggers...", silent=silent):
                self.insert_all_veaf_triggers()
        elif not silent: 
            logger.info("Skipping VEAF triggers because option '--no-veaf-triggers' was set...")

        # Write the mission file
        with spinner_context(f"Writing final mission {self.output_mission}...", silent=silent):
            self.write_mission()

        if not silent: logger.info(f"Mission file '{self.output_mission}' built from folder '{self.mission_folder}'.")

        return self.output_mission
