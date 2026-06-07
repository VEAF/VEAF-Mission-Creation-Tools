"""
Worker module for the VEAF Mission Builder Package.
"""

import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

import yaml
from mission_tools import (
    DEFAULT_SCRIPTS_LOCATION,
    DcsMission,
    collect_files_from_globs,
    create_miz,
    get_community_script_files,
    get_mission_data_files,
    get_mission_script_files,
    read_miz,
    write_miz,
)
from veaf_libs import user_config as _user_config
from veaf_libs.base_worker import BaseWorker
from veaf_libs.build_profiles import resolve_profile
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.lua_config_generator import generate_config_lua
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.paths import resolve_path
from veaf_libs.progress import spinner_context
from veaf_libs.yaml_validator import validate_yaml_file

# Lua files that are always expected in src/scripts/ of a VEAF v6 mission folder.
# Any other .lua file found there is flagged as a potential v5 residue.
_EXPECTED_SCRIPTS: frozenset[str] = frozenset(
    {
        "veaf-config.lua",
        "mission-script.lua",
        "veafDynamicConfig.lua",
    }
)


@dataclass
class CustomScript:
    """A custom Lua script declared in the custom_scripts section of mission.yaml."""

    path: str
    generate_load_trigger: bool | None = field(default=None)


class MissionBuilderWorker(BaseWorker):
    """
    Worker class that builds a mission, based on a folder containing the mission files, and on the VEAF Mission Creation Tools package.
    """

    def __init__(
        self,
        mission_folder: Path,
        output_mission: Path,
        dynamic_mode: bool | None,
        dev_mode_override: bool | None = None,
        scripts_path_override: str | Path | None = None,
        log_modules_filter: str | None = None,
        migrate_from_v5: bool = True,
        no_veaf_triggers: bool = False,
        profile_name: str | None = None,
    ):
        """
        Initialize the worker.  Config resolution priority: CLI override > mission.yaml > user config > code defaults.
        """

        self.output_mission = output_mission
        self.mission_folder = mission_folder
        self.dynamic_mode = dynamic_mode
        self.migrate_from_v5: bool = migrate_from_v5
        self.no_veaf_triggers: bool = no_veaf_triggers
        self.dcs_mission: DcsMission | None = None
        self.collected_community_script_files: dict[str, bytes] | None = None
        self.collected_veaf_script_files: dict[str, bytes] | None = None
        self.collected_mission_script_files: dict[str, bytes] | None = None
        self.collected_mission_data_files: dict[str, bytes] | None = None

        # Read mission.yaml, then apply build profile (deep-merge)
        self.mission_yaml: dict = {}
        self.pipeline_cfg: dict = {}
        mission_yaml_path = mission_folder / "mission.yaml"
        if mission_yaml_path.exists():
            validate_yaml_file(mission_yaml_path)
            with mission_yaml_path.open("r", encoding="utf-8") as fh:
                raw_yaml: dict = yaml.safe_load(fh) or {}
            self.mission_yaml = resolve_profile(raw_yaml, profile_name)
        build_cfg: dict = self.mission_yaml.get("build") or {}
        self.pipeline_cfg = self.mission_yaml.get("pipeline") or {}

        # Extract lua_modules and global_log_level from yaml
        lua_modules: dict | None = self.mission_yaml.get("lua_modules") or None
        if lua_modules:
            logger.info(f"Found lua_modules section in {mission_yaml_path}; will generate veaf-config.lua")
        global_log_level: str | None = self.mission_yaml.get("global_log_level") or None
        if global_log_level:
            logger.info(f"Found global_log_level={global_log_level!r} in {mission_yaml_path}")

        # Resolve dev_mode: CLI override > mission.yaml > default
        self.dev_mode: bool = (
            dev_mode_override if dev_mode_override is not None else bool(build_cfg.get("dev_mode", False))
        )
        if self.dev_mode:
            logger.info("Dev mode: VEAF scripts resolved from local dev repo (build/veaf-scripts.lua)")

        # Resolve scripts_path: CLI override > mission.yaml > user config
        _uc_sp = _user_config.get_scripts_path()
        effective_scripts_path_str: str | Path | None = (
            scripts_path_override or build_cfg.get("scripts_path") or (str(_uc_sp) if _uc_sp else None)
        )
        if not effective_scripts_path_str and dynamic_mode:
            effective_scripts_path_str = mission_folder / "published"
        if effective_scripts_path_str:
            self.scripts_path: Path | None = resolve_path(path=effective_scripts_path_str, should_exist=True)
            if not self.scripts_path.exists():
                logger.error(f"Scripts folder {self.scripts_path} does not exist!", exception_type=FileNotFoundError)
        else:
            self.scripts_path = None

        if self.dev_mode and not self.scripts_path:
            logger.error(
                "--dev-mode requires a scripts path. "
                "Pass --scripts-path <repo_root> or set build.scripts_path in mission.yaml.",
                exception_type=ValueError,
            )

        # Apply log_modules_filter: silence all modules not in the keep list
        if log_modules_filter is not None:
            keep_modules = {m.strip() for m in log_modules_filter.split(",") if m.strip()}
            all_module_ids = {m["id"] for m in get_modules()}
            if unknown := keep_modules - all_module_ids:
                logger.warning(f"--log-modules: unknown module ID(s): {sorted(unknown)} — check spelling")
            lua_modules = lua_modules or {}
            for mod_id in all_module_ids:
                if mod_id not in keep_modules:
                    if mod_id not in lua_modules:
                        lua_modules[mod_id] = {}
                    lua_modules[mod_id].setdefault("logLevel", "error")
            logger.info(
                f"--log-modules: keeping full logging for {sorted(keep_modules) or 'none'}, "
                f"silencing {len(all_module_ids) - len(keep_modules)} other module(s)"
            )

        # Normalize global_log_level
        _valid_levels = {"error", "warning", "info", "debug", "trace"}
        if global_log_level is not None:
            normalized = global_log_level.lower().strip()
            if normalized == "warn":
                normalized = "warning"
            if normalized not in _valid_levels:
                logger.warning(
                    f"global_log_level={global_log_level!r} is not a valid Lua log level "
                    f"(accepted: {sorted(_valid_levels)}); falling back to 'info'"
                )
                normalized = "info"
            global_log_level = normalized
        self.global_log_level: str | None = global_log_level
        self.lua_modules: dict | None = lua_modules

        # Parse custom_scripts section from mission.yaml
        self.custom_scripts: list[CustomScript] = []
        self.custom_scripts_generate_load_trigger: bool = True
        cs_section: dict = self.mission_yaml.get("custom_scripts") or {}
        if cs_section:
            self.custom_scripts_generate_load_trigger = bool(cs_section.get("generate_load_trigger", True))
            for script_item in cs_section.get("scripts") or []:
                if isinstance(script_item, dict):
                    path = script_item.get("path", "")
                    per_script_trigger: bool | None = script_item.get("generate_load_trigger")
                else:
                    path = str(script_item)
                    per_script_trigger = None
                self.custom_scripts.append(CustomScript(path=Path(path).name, generate_load_trigger=per_script_trigger))

        if self.mission_folder and not self.mission_folder.is_dir():
            logger.error(
                f"The input mission folder '{self.mission_folder}' does not exist or is not a folder",
                exception_type=FileNotFoundError,
            )

    def get_collected_veaf_script_files(self) -> dict[str, bytes]:
        if self.collected_veaf_script_files:
            return self.collected_veaf_script_files

        # Preprocess the veaf script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")

        if self.dev_mode and self.scripts_path:
            # In dev mode, veaf-scripts.lua lives in build/ (compiled artifact)
            veaf_script_pattern = ("build/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
            expected_path = scripts_folder / "build" / "veaf-scripts.lua"
        else:
            veaf_script_pattern = ("src/scripts/veaf/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
            expected_path = scripts_folder / "src" / "scripts" / "veaf" / "veaf-scripts.lua"

        self.collected_veaf_script_files = collect_files_from_globs(
            base_folder=scripts_folder,
            file_patterns=[veaf_script_pattern],
        )

        if len(self.collected_veaf_script_files) < 1:
            logger.error(f"VEAF scripts file not found at {expected_path}")

        return self.collected_veaf_script_files

    def get_collected_community_script_files(self) -> dict[str, bytes]:
        if self.collected_community_script_files:
            return self.collected_community_script_files

        # Preprocess the community script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")
        self.collected_community_script_files = collect_files_from_globs(
            base_folder=scripts_folder, file_patterns=get_community_script_files()
        )
        if len(self.collected_community_script_files) < len(get_community_script_files()):
            self.signal_missing_required_files_after_collection(
                get_community_script_files(), self.collected_community_script_files, scripts_folder
            )
        return self.collected_community_script_files

    def signal_missing_required_files_after_collection(
        self, expected_files: list[tuple[str, str]], collected_files: dict[str, bytes], scripts_folder: Path
    ):
        """Signal missing files after collection with detailed information."""
        collected_file_paths = {Path(path).name for path in collected_files}
        missing_files = [
            Path(file_pattern[0]).name
            for file_pattern in expected_files
            if Path(file_pattern[0]).name not in collected_file_paths
        ]

        message = f"Error: missing files from {scripts_folder}:\n"
        for missing_file in sorted(missing_files):
            message += f"  - {missing_file}\n"
        message = message.rstrip("\n")
        message += "\nTry updating the veaf-tools package using veaf-tools-updater.exe!"
        logger.error(message=message, raise_exception=False)
        exit()

    def get_collected_mission_script_files(self) -> dict[str, bytes]:
        if self.collected_mission_script_files:
            return self.collected_mission_script_files

        # Preprocess the mission files
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        )
        self.collected_mission_script_files = collect_files_from_globs(
            base_folder=self.mission_folder,
            file_patterns=get_mission_script_files(),
            alternative_folder=defaults_folder,
        )
        return self.collected_mission_script_files

    def get_collected_mission_data_files(self) -> dict[str, bytes]:
        if self.collected_mission_data_files:
            return self.collected_mission_data_files

        # Preprocess the mission files
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        )
        self.collected_mission_data_files = collect_files_from_globs(
            base_folder=self.mission_folder, file_patterns=get_mission_data_files(), alternative_folder=defaults_folder
        )
        return self.collected_mission_data_files

    def complete_src_folder_with_defaults(self) -> None:
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published" / "src")) / "defaults" / "mission-folder"
        )
        # Map default filenames to the pipeline/module that owns them so that we
        # skip copying when the user has explicitly disabled the corresponding step.
        # Keys are bare filenames (no directory).  Values are dicts with either
        # "pipeline" (key in self.pipeline_cfg) or "lua_module" (key in
        # self.mission_yaml["lua_modules"]).
        _DEFAULT_FILE_MODULE_MAP: dict[str, dict[str, str]] = {
            "spawnables.yaml": {"lua_module": "SPAWN"},
            "templates.yaml": {"lua_module": "SPAWN"},
            "waypoints.yaml": {"pipeline": "waypoints"},
            "presets.yaml": {"pipeline": "presets"},
            "versions.yaml": {"pipeline": "weather"},
            "missions.yaml": {"pipeline": "weather"},
        }
        for f in defaults_folder.rglob("*"):
            if f.is_file():
                mapping = _DEFAULT_FILE_MODULE_MAP.get(f.name)
                if mapping is not None:
                    if "pipeline" in mapping:
                        step_cfg = self.pipeline_cfg.get(mapping["pipeline"])
                        if step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False):
                            logger.debug(f"Skipping default '{f.name}': pipeline '{mapping['pipeline']}' is disabled")
                            dest = self.mission_folder / f.relative_to(defaults_folder).parent.as_posix() / f.name
                            if dest.exists():
                                logger.warning(
                                    f"Orphan file '{dest.relative_to(self.mission_folder)}': "
                                    f"pipeline '{mapping['pipeline']}' is disabled in mission.yaml "
                                    f"but the file still exists in your mission folder. "
                                    f"You can safely delete it."
                                )
                            continue
                    elif "lua_module" in mapping:
                        mod_cfg = (self.mission_yaml.get("lua_modules") or {}).get(mapping["lua_module"])
                        if isinstance(mod_cfg, dict) and mod_cfg.get("enable") is False:
                            logger.debug(
                                f"Skipping default '{f.name}': lua_module '{mapping['lua_module']}' is disabled"
                            )
                            dest = self.mission_folder / f.relative_to(defaults_folder).parent.as_posix() / f.name
                            if dest.exists():
                                logger.warning(
                                    f"Orphan file '{dest.relative_to(self.mission_folder)}': "
                                    f"lua_module '{mapping['lua_module']}' is disabled in mission.yaml "
                                    f"but the file still exists in your mission folder. "
                                    f"You can safely delete it."
                                )
                            continue
                # WEATHER-001: skip copying versions.yaml if legacy missions.yaml already exists
                if f.name == "versions.yaml":
                    legacy_weather = self.mission_folder / "src" / "missions.yaml"
                    if legacy_weather.exists():
                        logger.warning(
                            "Legacy weather config 'src/missions.yaml' found. "
                            "Skipping copy of default 'src/versions.yaml'. "
                            "Consider renaming 'missions.yaml' \u2192 'versions.yaml'."
                        )
                        continue
                relative_path = f.relative_to(defaults_folder).parent.as_posix()
                relative_path = self.mission_folder / relative_path / f.name
                if not relative_path.exists():
                    relative_path.parent.mkdir(parents=True, exist_ok=True)
                    logger.warning(f"Copied required file '{relative_path}' from default folder '{defaults_folder}'")
                    shutil.copy(f, relative_path)

        # OLDSCRIPTS-002: warn about unexpected .lua files in src/scripts/
        # The glob src/scripts/*.lua in get_mission_script_files() picks up ALL .lua files in
        # that folder, including potential v5 residues (e.g. veafSecurity.lua, veafCommands.lua).
        # Those would be loaded as individual DCS mission scripts and may conflict with the
        # bundled veaf-scripts.lua loaded by the VEAF triggers.
        scripts_dir = self.mission_folder / "src" / "scripts"
        declared_custom_names = {cs.path for cs in self.custom_scripts}
        if scripts_dir.is_dir():
            for lua_file in scripts_dir.glob("*.lua"):
                if lua_file.name in _EXPECTED_SCRIPTS:
                    continue
                if lua_file.name in declared_custom_names:
                    logger.info(
                        f"Custom Lua file 'src/scripts/{lua_file.name}' declared in mission.yaml "
                        f"and will be included in the mission."
                    )
                    continue
                logger.warning(
                    f"Unexpected Lua file 'src/scripts/{lua_file.name}' found in your mission folder. "
                    f"This file will be loaded as a DCS mission script and may conflict with "
                    f"the bundled veaf-scripts.lua. "
                    f"If this is a leftover v5 VEAF script, delete it. "
                    f"If it is an intentional custom script, declare it in the 'custom_scripts' section of mission.yaml."
                )

    def create_mission(self) -> None:
        """Creates the initial mission file from the mission folder."""

        logger.debug("Create the initial mission file from the mission folder")

        files = (
            self.get_collected_community_script_files()
            | self.get_collected_veaf_script_files()
            | self.get_collected_mission_script_files()
            | self.get_collected_mission_data_files()
        )
        logger.debug(f"Preprocessed {len(files)} files")

        logger.debug("Creating the mission file")
        self.output_mission = create_miz(self.output_mission, files)
        logger.debug(f"Mission file created at {self.output_mission}")

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        logger.debug(f"Reading mission file {self.output_mission}")
        try:
            self.dcs_mission = read_miz(self.output_mission)
            if self.dcs_mission.missing_components and "options" in self.dcs_mission.missing_components:
                logger.warning(
                    f"The 'options' file is missing from {self.mission_folder / 'src'}; it's a useful item of your source tree!"
                )
                self.dcs_mission.missing_components.remove("options")  # we've handled that one
            if self.dcs_mission.missing_components:
                message = f"These components are missing from '{self.mission_folder / 'src'}': {', '.join([f"'{item}'" for item in self.dcs_mission.missing_components])}; they are mandatory in a DCS mission!"
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
            mission_triggers: dict = self.dcs_mission.mission_content.get("trig", {})
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
                if self.dcs_mission.mission_content["trigrules"].get(trigger_index):
                    del self.dcs_mission.mission_content["trigrules"][trigger_index]

    def insert_all_veaf_triggers(self) -> None:
        """
        Create all the VEAF triggers in the mission.
        First, we'll update the dictionary.
        Then we'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        We'll also add 6 corresponding trigrules, shifting the existing ones accordingly
        """
        new_dictionary = self.update_dictionary_with_veaf_entries()
        new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file = (
            self.update_map_resource_with_veaf_entries()
        )
        self.insert_veaf_triggers(new_dictionary, new_map_resource_script_files, new_map_resource_mission_script_files)
        self.insert_veaf_trigrules(new_map_resource_key_by_file)

    def update_dictionary_with_veaf_entries(self) -> dict:
        """
        Update the dictionary for all the VEAF triggers in the mission.
        """

        new_dictionary = {
            "VEAF_DictKey_ActionText_12001": f"return {'true' if self.dynamic_mode else 'false'} -- VEAF scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12002": f"return {'true' if self.dynamic_mode else 'false'} -- Mission scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12003": "return VEAF_DYNAMIC_SCRIPTSPATH~=nil",
            "VEAF_DictKey_ActionText_12004": "return VEAF_DYNAMIC_SCRIPTSPATH==nil",
            "VEAF_DictKey_ActionText_12005": "return VEAF_DYNAMIC_MISSIONPATH~=nil",
            "VEAF_DictKey_ActionText_12006": "return VEAF_DYNAMIC_MISSIONPATH==nil",
        }

        # merge the new dictionary with the mission dictionary
        assert self.dcs_mission is not None
        self.dcs_mission.dictionary_content = new_dictionary | (self.dcs_mission.dictionary_content or {})

        return new_dictionary

    def _resolves_load_trigger(self, filename: str) -> bool:
        """Returns True if a DCS load trigger should be generated for this script file.

        Args:
            filename: The script filename (basename only).

        Returns:
            False only for custom scripts explicitly declared with generate_load_trigger: false.
            All other files (undeclared or declared without override) follow the global default.
        """
        for cs in self.custom_scripts:
            if cs.path == filename:
                if cs.generate_load_trigger is not None:
                    return cs.generate_load_trigger
                return self.custom_scripts_generate_load_trigger
        return True

    def update_map_resource_with_veaf_entries(self) -> tuple[dict, dict, dict]:
        """
        Update the map resource for all the VEAF triggers in the mission.
        """

        new_map_resource_key_by_file = {}
        new_map_resource_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(
            self.get_collected_community_script_files() | self.get_collected_veaf_script_files()
        ):
            map_resource_key = f"VEAF_MapKey_ActionText_10{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name] = map_resource_key
            new_map_resource_script_files[map_resource_key] = Path(script_file_name).name

        new_map_resource_mission_script_files = {}
        trigger_key_index = 0
        for script_file_name in self.get_collected_mission_script_files():
            if not self._resolves_load_trigger(Path(script_file_name).name):
                continue
            map_resource_key = f"VEAF_MapKey_ActionText_11{trigger_key_index:03}"
            trigger_key_index += 1
            new_map_resource_key_by_file[script_file_name] = map_resource_key
            new_map_resource_mission_script_files[map_resource_key] = Path(script_file_name).name

        # merge the new mapResource with the mission mapResource
        assert self.dcs_mission is not None
        self.dcs_mission.map_resource_content = (
            new_map_resource_script_files
            | new_map_resource_mission_script_files
            | (self.dcs_mission.map_resource_content or {})
        )

        return new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file

    def insert_veaf_triggers(
        self, new_dictionary: dict, new_map_resource_script_files: dict, new_map_resource_mission_script_files: dict
    ) -> None:
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
            action_keys = sorted(
                triggers["actions"].keys()
            )  # this is the most complete category, it always contains all the triggers; this is important later
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
            idx + 1: f'return(c_predicate(getValueDictByKey("{new_dict_key}")) )'
            for idx, new_dict_key in enumerate(new_dictionary)
        }

        dynamic_script_loading_trigger = (
            'a_do_script("env.info(\\"DYNAMIC VEAF scripts loading from \\"..VEAF_DYNAMIC_SCRIPTSPATH)");'
        )
        for file in get_community_script_files():
            dynamic_script_loading_trigger += (
                f'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"{file[0]}\\"))()");'
            )
        dynamic_script_loading_trigger += (
            'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"/src/scripts/VeafDynamicLoader.lua\\"))()");'
        )

        static_script_loading_trigger = 'a_do_script("env.info(\\"STATIC VEAF scripts loading\\")");'
        for map_resource_key in new_map_resource_script_files:
            static_script_loading_trigger += f'a_do_script_file(getValueResourceByKey("{map_resource_key}"));'

        dynamic_mission_loading_trigger = 'a_do_script("env.info(\\"DYNAMIC Mission scripts loading from \\"..VEAF_DYNAMIC_MISSIONPATH)");a_do_script("assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \\"/src/scripts/veafDynamicConfig.lua\\"))()");'

        static_mission_loading_trigger = 'a_do_script("env.info(\\"STATIC Mission scripts loading\\")");'
        for map_resource_key in new_map_resource_mission_script_files:
            static_mission_loading_trigger += f'a_do_script_file(getValueResourceByKey("{map_resource_key}"));'

        VEAF_DYNAMIC_SCRIPTSPATH = (
            f"[[{self.scripts_path.resolve().as_posix()}/]]"
            if self.scripts_path
            else f"[[{(self.output_mission.parent / 'published').resolve().as_posix()}/]]"
        )
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_triggers = {
            "customStartup": {},
            "func": {},
            "custom": {},
            "events": {},
            "flag": {1: True, 2: True, 3: True, 4: True, 5: True, 6: True},
            "conditions": conditions_trigger,
            "actions": {
                1: f'a_do_script("VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}");',
                2: f'a_do_script("VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}");',
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
            },
        }

        mission_triggers = self.dcs_mission.mission_content["trig"]  # type: ignore[index]
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
        for new_key, old_key in enumerate(sorted(mission_triggers_new_structure.keys()), start=nb_new_triggers + 1):
            result_trigger_new_structure = result_triggers_new_structure[new_key] = mission_triggers_new_structure[
                old_key
            ].copy()
            if new_key != old_key:
                for category_name, category_value in result_trigger_new_structure.items():
                    new_category_value = category_value  # default value, if there is no need for updating the LUA
                    if isinstance(category_value, str):
                        # update the LUA code to reflect the shift
                        new_category_value = re.sub(f"\\[{old_key}\\]", f"[{new_key}]", category_value)
                    result_trigger_new_structure[category_name] = new_category_value

        # Insert the new VEAF triggers at the beginning of our new structure
        for new_trigger_key, new_trigger_data in veaf_triggers_new_structure.items():
            result_triggers_new_structure[new_trigger_key] = new_trigger_data

        # Convert the new structure back to a valid DCS structure
        self.dcs_mission.mission_content["trig"] = transform_triggers_new_structure_to_dcs_structure(  # type: ignore[index]
            result_triggers_new_structure
        )

    def insert_veaf_trigrules(self, new_map_resource_key_by_file: dict) -> None:
        """
        Create all the VEAF trigrules in the mission.
        We'll add 6 trigrules corresponding to the 6 new triggers.
        All existing trigrules will be shifted 6 ranks up, changing the indexes in the LUA code.
        """

        VEAF_DYNAMIC_SCRIPTSPATH = (
            f"[[{self.scripts_path.resolve().as_posix()}/]]"
            if self.scripts_path
            else f"[[{(self.output_mission.parent / 'published').resolve().as_posix()}/]]"
        )
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_community_scripts_map_keys = [
            new_map_resource_key_by_file.get(script_file_name, "")
            for script_file_name in self.get_collected_community_script_files()
        ]
        veaf_scripts_map_keys = [
            new_map_resource_key_by_file.get(script_file_name, "")
            for script_file_name in self.get_collected_veaf_script_files()
        ]

        veaf_mission_config_map_key = new_map_resource_key_by_file.get(
            f"{DEFAULT_SCRIPTS_LOCATION}/mission-script.lua", ""
        )
        # Optional generated config, loaded before mission-script.lua
        veaf_modules_config_map_key = new_map_resource_key_by_file.get(
            f"{DEFAULT_SCRIPTS_LOCATION}/veaf-config.lua", ""
        )

        static_script_loading_actions = [
            {"predicate": "a_do_script", "text": 'env.info("STATIC VEAF scripts loading")'}
        ]
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"} for file_path in veaf_community_scripts_map_keys
        )
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"} for file_path in veaf_scripts_map_keys
        )

        dynamic_script_loading_actions = [
            {
                "predicate": "a_do_script",
                "text": 'env.info("DYNAMIC VEAF scripts loading from "..VEAF_DYNAMIC_SCRIPTSPATH)',
            }
        ]
        dynamic_script_loading_actions.extend(
            {
                "predicate": "a_do_script",
                "text": f'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "{file[0]}"))()',
            }
            for file in get_community_script_files()
        )
        dynamic_script_loading_actions.append(
            {
                "predicate": "a_do_script",
                "text": 'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "/src/scripts/VeafDynamicLoader.lua"))()',
            }
        )

        new_trigrules_list = [
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12001",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12001",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading method",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {"predicate": "a_do_script", "text": f"VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}"}
                ],
                "colorItem": "0x00ffffff",
            },
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12002",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12002",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading method",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {"predicate": "a_do_script", "text": f"VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}"}
                ],
                "colorItem": "0x00ffffff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12003",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12003",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": dynamic_script_loading_actions,
                "colorItem": "0x00ff80ff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12004",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12004",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": static_script_loading_actions,
                "colorItem": "0x00ff80ff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12005",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12005",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": 'env.info("DYNAMIC Mission scripts loading from "..VEAF_DYNAMIC_MISSIONPATH)',
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184,
                    },
                    # Load veaf-config.lua before mission-script.lua (if present)
                    {
                        "predicate": "a_do_script",
                        "text": 'local _f = loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veaf-config.lua"); if _f then _f() end',
                    },
                    {
                        "predicate": "a_do_script",
                        "text": 'assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua"))()',
                    },
                ],
                "colorItem": "0x8080ffff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12006",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12006",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": 'env.info("STATIC Mission scripts loading")',
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184,
                    },
                    # Load veaf-config.lua before mission-script.lua (if present)
                    *(
                        [{"predicate": "a_do_script_file", "file": f"{veaf_modules_config_map_key}"}]
                        if veaf_modules_config_map_key
                        else []
                    ),
                    {"predicate": "a_do_script_file", "file": f"{veaf_mission_config_map_key}"},
                ],
                "colorItem": "0x8080ffff",
            },
        ]

        # compress the dictionary keyset, leaving space for the VEAF trigrules
        trigrules = self.dcs_mission.mission_content["trigrules"]  # type: ignore[index]
        new_trigrules = dict(enumerate(new_trigrules_list, start=1))
        nb_new_trigrules = len(new_trigrules)
        result_trigrules = {
            new_key: trigrules[old_key]
            for new_key, old_key in enumerate(sorted(trigrules.keys()), start=nb_new_trigrules + 1)
        }
        # insert the new elements
        for new_index, new_item in new_trigrules.items():
            result_trigrules[new_index] = new_item
        # set the new dictionary
        self.dcs_mission.mission_content["trigrules"] = result_trigrules  # type: ignore[index]

    def write_mission(self) -> None:
        """Write the mission file."""

        logger.debug("Writing mission file")
        assert self.dcs_mission is not None
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)
        logger.debug("Writing mission file done")

    def write_config_lua(self) -> None:
        """Write veaf-config.lua from mission_yaml (or legacy lua_modules / global_log_level)."""
        # Build a YAML dict to pass to the generator
        if self.mission_yaml:
            yaml_dict: dict = dict(self.mission_yaml)
            # Allow lua_modules / global_log_level params to override if mission_yaml doesn't have them
            if self.global_log_level and "global_log_level" not in yaml_dict:
                yaml_dict["global_log_level"] = self.global_log_level
            if self.lua_modules and "lua_modules" not in yaml_dict:
                yaml_dict["lua_modules"] = self.lua_modules
        else:
            yaml_dict = {}
            if self.global_log_level:
                yaml_dict["global_log_level"] = self.global_log_level
            if self.lua_modules:
                yaml_dict["lua_modules"] = self.lua_modules

        if not yaml_dict:
            return

        scripts_dir = self.mission_folder / "src" / "scripts"
        scripts_dir.mkdir(parents=True, exist_ok=True)
        config_file = scripts_dir / "veaf-config.lua"
        content = generate_config_lua(yaml_dict)
        config_file.write_text(content, encoding="utf-8")
        logger.info(f"Generated '{config_file}' from mission.yaml")

    def work(self, silent: bool = False) -> Path:
        """Main work function."""

        # Complete the src folder with default files if they don't exist
        with spinner_context(t("builder.completing_defaults", folder=self.mission_folder), silent=silent):
            self.complete_src_folder_with_defaults()

        # Generate veaf-config.lua from mission_yaml / lua_modules / global_log_level if provided
        if self.mission_yaml or self.lua_modules or self.global_log_level:
            with spinner_context(t("builder.generating_config"), silent=silent):
                self.write_config_lua()
            # Invalidate cached mission script files so the new file is picked up
            self.collected_mission_script_files = None

        # Create the initial mission file
        with spinner_context(t("builder.creating_mission", output=self.output_mission), silent=silent):
            self.create_mission()

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        with spinner_context(t("builder.reading_mission", output=self.output_mission), silent=silent):
            self.read_mission()

        # First, remove all the VEAF triggers
        with spinner_context(t("builder.clearing_triggers"), silent=silent):
            self.clear_veaf_triggers()

        # Then, add all the VEAF triggers we need
        if not self.no_veaf_triggers:
            with spinner_context(t("builder.updating_triggers"), silent=silent):
                self.insert_all_veaf_triggers()
        elif not silent:
            logger.info(t("builder.skip_veaf_triggers"))

        # Write the mission file
        with spinner_context(t("builder.writing_mission", output=self.output_mission), silent=silent):
            self.write_mission()

        if not silent:
            logger.info(t("builder.built", output=self.output_mission, folder=self.mission_folder))

        return self.output_mission
