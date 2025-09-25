"""
Worker module for the VEAF Presets Injector Package.
"""

from logging import Logger
from pathlib import Path
from typing import Optional
from miz_tools import read_miz, update_miz, DcsMission
from veaf_logger import VeafLogger

class ScriptsInjectorWorker:
    """
    Worker class that provides scripts injection features.
    """
    
    def __init__(self, logger: Optional[Logger] = None, development_mode: Optional[bool] = False, development_path: Optional[Path] = None, input_mission: Optional[Path] = None, output_mission: Optional[Path] = None):
        """
        Initialize the worker with optional parameters for both use cases.
        
        Args:
            logger: Logger instance for logging messages
            development_mode: Boolean indicating if development mode is enabled
            development_path: Path to the development scripts directory
            input_mission: Path to the input mission file
            output_mission: Path to the output mission file
        """
        self.logger: VeafLogger = logger
        self.development_mode = development_mode
        self.development_path = development_path
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.dcs_mission: DcsMission = None
        self.scripts = {}
        self.__post_init__()

    def __post_init__(self):
        """Initialize the object and validates its state."""

        if self.input_mission and (
            not self.input_mission.is_file() or self.input_mission.suffix != ".miz"
        ):
            self.logger.error(f"The input mission file '{self.input_mission}' does not exist or is not a .miz file", raise_exception=True)

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        self.logger.info(f"Reading mission file {self.input_mission}")
        self.dcs_mission = read_miz(self.input_mission)

    def set_mission_variables(self) -> None:  # sourcery skip: extract-method, low-code-quality
        """Changes the variables in the mission."""

        self.logger.info("Setting mission variables")

        # Set the variables in the dictionary
        if self.dcs_mission and self.dcs_mission.dictionary_lua:
            self.logger.debug("Set the variables in the dictionary")
            for key, value in self.dcs_mission.dictionary_lua.items():
                self.logger.debug(f"Processing key {key}: {value}")

                # search for mission config loading mode
                if value.endswith(" -- config"):
                    if self.development_mode:
                        self.logger.debug("Setting mission config loading to dynamic")
                        self.dcs_mission.dictionary_lua[key] = "return true -- config"
                    else:
                        self.logger.debug("Setting mission config loading to static")
                        self.dcs_mission.dictionary_lua[key] = "return false -- config"
                # search for mission scripts loading mode
                if value.endswith(" -- scripts"):
                    if self.development_mode:
                        self.logger.debug("Setting mission scripts loading to dynamic")
                        self.dcs_mission.dictionary_lua[key] = "return true -- scripts"
                    else:
                        self.logger.debug("Setting mission scripts loading to static")
                        self.dcs_mission.dictionary_lua[key] = "return false -- scripts"
        else:
            self.logger.error("The mission file does not contain 'dictionary'", raise_exception=True)

        # Set the variables in the mission
        if self.dcs_mission and self.dcs_mission.mission_lua:
            self.logger.debug("Set the variables in the mission")
            # Process the 'trig' part
            dcs_actions = self.dcs_mission.mission_lua.get("trig", {}).get("actions", {})
            if not dcs_actions:
                self.logger.error("The 'mission' file does not contain 'trig.actions'", raise_exception=True)
            for action_index, action in enumerate(dcs_actions):
                self.logger.debug(f"Processing action {action_index}: {action}")
                if action.startswith("a_do_script(\"VEAF_DYNAMIC_MISSIONPATH ="):
                    veaf_dynamic_mission_path = f"[[{(self.input_mission.parent / "..").resolve().as_posix()}]]"
                    self.logger.debug(f"Setting VEAF_DYNAMIC_MISSIONPATH to {veaf_dynamic_mission_path}")
                    dcs_actions[action_index] = f'a_do_script("VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}")'
                elif action.startswith("a_do_script(\"VEAF_DYNAMIC_PATH ="):
                    veaf_dynamic_mission_path = f"[[{(self.input_mission.parent / "../node_modules/veaf-mission-creation-tools").resolve().as_posix()}]]"
                    if self.development_path:
                        veaf_dynamic_mission_path = f"[[{self.development_path.resolve().as_posix()}]]"
                    self.logger.debug(f"Setting VEAF_DYNAMIC_PATH to {veaf_dynamic_mission_path}")
                    dcs_actions[action_index] = f'a_do_script("VEAF_DYNAMIC_PATH = {veaf_dynamic_mission_path}")'

            # Process the 'trigrules' part
            # TODO dynamically set the actions that load the scripts to the scripts list
            dcs_rules = self.dcs_mission.mission_lua.get("trigrules", {})
            if not dcs_rules:
                self.logger.error("The 'mission' file does not contain 'trigrules'", raise_exception=True)
            for rule in dcs_rules:
                rule_actions = rule.get("actions", {})
                for action_index, action in enumerate(rule_actions):
                    action_text = action.get("text", "")
                    self.logger.debug(f"Processing action {action_index}: {action}")
                    if action_text:
                        if action_text.startswith("VEAF_DYNAMIC_MISSIONPATH ="):
                            veaf_dynamic_mission_path = f"[[{(self.input_mission.parent / "..").resolve().as_posix()}]]"
                            self.logger.debug(f"Setting VEAF_DYNAMIC_MISSIONPATH to {veaf_dynamic_mission_path}")
                            rule_actions[action_index]["text"] = f'VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}'
                        elif action_text.startswith("VEAF_DYNAMIC_PATH ="):
                            veaf_dynamic_mission_path = f"[[{(self.input_mission.parent / "../node_modules/veaf-mission-creation-tools").resolve().as_posix()}]]"
                            if self.development_path:
                                veaf_dynamic_mission_path = f"[[{self.development_path.resolve().as_posix()}]]"
                            self.logger.debug(f"Setting VEAF_DYNAMIC_PATH to {veaf_dynamic_mission_path}")
                            rule_actions[action_index]["text"] = f'VEAF_DYNAMIC_PATH = {veaf_dynamic_mission_path}'

        else:
            self.logger.error("The mission file does not contain 'mission'", raise_exception=True)

        self.logger.debug("Mission variables set")

    
    def inject_scripts(self) -> None:  
        """Process all scripts and injects them in the mission."""

        # Determine the base scripts path
        base_scripts_path = None
        if self.development_mode and self.development_path:
            self.logger.info(f"Development mode is set; using {self.development_path}")
            base_scripts_path = self.development_path
        else:
            base_scripts_path = (self.input_mission.parent / "../node_modules/veaf-mission-creation-tools").resolve()
        if not base_scripts_path or not base_scripts_path.exists() or not base_scripts_path.is_dir():
            self.logger.error(f"The base scripts path '{base_scripts_path}' does not exist or is not a directory", raise_exception=True)

        self.logger.debug(f"Using base scripts path: {base_scripts_path}")

        # Search for all the scripts
        scripts_to_inject = [
            "src/scripts/veaf/veaf.lua",
            "src/scripts/veaf/veafTime.lua",
            "src/scripts/veaf/veafAirbases.lua",
            "src/scripts/veaf/veafWeather.lua",
            "src/scripts/veaf/veafAssets.lua",
            "src/scripts/veaf/veafCarrierOperations.lua",
            "src/scripts/veaf/veafCasMission.lua",
            "src/scripts/veaf/veafCombatMission.lua",
            "src/scripts/veaf/veafCombatZone.lua",
            "src/scripts/veaf/veafGrass.lua",
            "src/scripts/veaf/veafInterpreter.lua",
            "src/scripts/veaf/veafMarkers.lua",
            "src/scripts/veaf/veafMove.lua",
            "src/scripts/veaf/veafNamedPoints.lua",
            "src/scripts/veaf/veafRadio.lua",
            "src/scripts/veaf/veafSecurity.lua",
            "src/scripts/veaf/veafShortcuts.lua",
            "src/scripts/veaf/veafSpawn.lua",
            "src/scripts/veaf/veafTransportMission.lua",
            "src/scripts/veaf/dcsUnits.lua",
            "src/scripts/veaf/veafUnits.lua",
            "src/scripts/veaf/veafRemote.lua",
            "src/scripts/veaf/veafSkynetIadsHelper.lua",
            "src/scripts/veaf/veafSkynetIadsMonitor.lua",
            "src/scripts/veaf/veafSanctuary.lua",
            "src/scripts/veaf/veafHoundElintHelper.lua",
            "src/scripts/veaf/veafQraManager.lua",
            "src/scripts/veaf/veafAirwaves.lua",
            "src/scripts/veaf/veafEventHandler.lua",
            "src/scripts/veaf/veafCacheManager.lua",
            "src/scripts/veaf/veafGroundAI.lua",
            "src/scripts/community/AIEN.lua",
            "src/scripts/community/CSAR.lua",
            "src/scripts/community/CTLD.lua",
            "src/scripts/community/DCS-SimpleTextToSpeech.lua",
            "src/scripts/community/Hercules_Cargo.lua",
            "src/scripts/community/mist.lua",
            "src/scripts/community/skynet-iads-compiled.lua",
            "src/scripts/community/TheUniversalMission.lua",
            "src/scripts/community/WeatherMark.lua",
        ]
        self.logger.info(f"Processing {len(scripts_to_inject)} script{'s' if len(scripts_to_inject) > 1 else ''}")
        for script_relative_path in scripts_to_inject:
            script_path = base_scripts_path / script_relative_path
            if not script_path.exists() or not script_path.is_file():
                self.logger.error(f"The script file '{script_path}' does not exist or is not a file", raise_exception=True)
            self.logger.debug(f"Injecting script: {script_path}")
            with open(script_path, 'r', encoding='utf-8') as script_file:
                script_content = script_file.read()
                self.scripts[f"l10n/DEFAULT/{script_path.name}"] = script_content

        self.logger.debug(f"Read {len(self.scripts)} script{'s' if len(self.scripts) > 1 else ''}")
        self.logger.debug("Scipts injection prepared")
                    
    def write_mission(self) -> None:
        """Write the mission file."""

        self.logger.info("Writing mission file")
        update_miz(mission=self.dcs_mission, file_path=self.output_mission, additional_files=self.scripts)
        self.logger.debug("Writing mission file done")


    def work(self) -> None:
        """Main work function."""
       
        # Load the mission from the .miz file (unzip it) and process aircraft groups
        self.read_mission()

        # Set the mission variables (as needed)
        self.set_mission_variables()

        # Process all the aircraft groups
        self.inject_scripts()

        # Write the mission file
        self.write_mission()
