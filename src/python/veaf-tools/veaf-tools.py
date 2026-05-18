"""
This program provides a command-line interface (CLI) tool for managing DCS missions.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools.log' file.

Usage:
- Run the script with 'veaf-tools.exe' to access the CLI.
- Use the 'about' command to learn about the VEAF and this program.
- Use the 'inject-presets' command to inject radio presets into a mission file.
- Use the 'build-mission' command to build a .miz file from a VEAF mission folder.

Example:
- To inject presets into a mission file:
      'python veaf-tools.py inject-presets --verbose --presets-file my_presets.yaml my_mission.miz my_output.miz'

All the commands feature both `--help` and `--readme` options that display online help.
"""

import shutil
from datetime import datetime
from pathlib import Path

import typer
import yaml
from aircrafts_injector import (
    AircraftGroupsExtractorREADME,
    AircraftGroupsExtractorWorker,
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
)
from mission_builder import MissionBuilderREADME, MissionBuilderWorker
from mission_converter import MissionConverterREADME, MissionConverterWorker
from mission_extractor import MissionExtractorREADME, MissionExtractorWorker
from presets_injector import PresetsInjectorREADME, PresetsInjectorWorker
from rich.markdown import Markdown
from rich.table import Table
from veaf_libs.logger import console, logger
from veaf_libs.lua_module_scanner import find_lua_scripts_dir, get_modules, scan_module_configs
from veaf_libs.tui import run_wizard
from veaf_libs.update_checker import check_for_updates
from waypoints_injector import (
    WaypointsExtractorREADME,
    WaypointsExtractorWorker,
    WaypointsInjectorREADME,
    WaypointsInjectorWorker,
)
from weather_injector import LuaToYamlConverter, WeatherInjectorWorker, WheatherInjectorREADME

VERSION: str = "6.0.4"
README_HELP: str = "Provide access to the README file."
PAUSE_HELP: str = "If set, the script will pause when finished and wait for the user to press a key."
VERBOSE_HELP: str = "If set, the script will output a lot of debug information."
PAUSE_MESSAGE: str = "Press Enter to exit..."

# String constants
DEFAULT_MISSION_FILE = "mission.miz"
DEFAULT_PRESETS_FILE = "./src/presets.yaml"
CONFIRM_DISPLAY_DOC = "Do you want to display the documentation?"
WORK_DONE_MESSAGE = "[bold blue]Work done![/bold blue]"

app = typer.Typer(no_args_is_help=True)


@app.callback()
def main_callback() -> None:
    """VEAF Tools — DCS World mission management CLI."""
    check_for_updates(VERSION, console)


def resolve_path(
    path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False
) -> Path:
    """Resolve and validate a file path."""
    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        logger.error(message="Either path or default_path must be provided", exception_type=ValueError)

    result = result.resolve()

    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:
            # It's a directory
            result.mkdir(exist_ok=True)

    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)

    return result


@app.command()
def prepare(
    mission_folder: str | None = typer.Argument(".", help="Folder to initialize as a VEAF mission folder."),
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help="Do not ask before replacing existing files."),
) -> None:
    """
    Prepares a mission folder by copying default files and build scripts.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Mission Folder Preparation v{VERSION}[/bold green]")

    if readme:
        console.print("[bold cyan]Prepare Command[/bold cyan]")
        console.print("This command initializes a mission folder with default files and build scripts.")
        console.print("\nDefault files are copied from: src/defaults/mission-folder/src")
        console.print("Build scripts are copied from: src/build-scripts")
        console.print("\nIf files already exist, you will be asked to confirm replacement (unless --force is used).")
        exit()

    try:
        # Resolve mission folder
        p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)

        logger.info(f"Initializing mission folder: {p_mission_folder}")

        # Get the installation source directory (where veaf-tools is running from)
        # This could be from published/ or from src/python/veaf-tools/
        install_source = Path(__file__).parent

        # Try to find src/defaults relative to the script location
        # First, check if we're in a published installation
        defaults_source = install_source.parent.parent.parent / "src" / "defaults" / "mission-folder" / "src"

        # If not found, check parent directories (for development installations)
        if not defaults_source.exists():
            # Try one more level up (if running from veaf-tools/ subdirectory)
            defaults_source = install_source.parent.parent.parent.parent / "src" / "defaults" / "mission-folder" / "src"

        # If still not found, look in a common relative location
        if not defaults_source.exists():
            # Try from current working directory
            defaults_source = Path.cwd().parent / "src" / "defaults" / "mission-folder" / "src"

        if not defaults_source.exists():
            logger.warning(f"Default files not found at: {defaults_source}")
            logger.warning("Attempting to continue with build scripts only...")
            defaults_source = None

        # Get build scripts source
        build_scripts_source = install_source.parent.parent.parent / "src" / "build-scripts"
        if not build_scripts_source.exists():
            build_scripts_source = install_source.parent.parent.parent.parent / "src" / "build-scripts"

        if not build_scripts_source.exists():
            build_scripts_source = Path.cwd().parent / "src" / "build-scripts"

        if not build_scripts_source.exists():
            logger.warning(f"Build scripts not found at: {build_scripts_source}")
            build_scripts_source = None

        files_installed = 0
        files_skipped = 0

        # Copy default files from src/defaults/mission-folder/src
        if defaults_source and defaults_source.exists():
            logger.info(f"Copying default files from {defaults_source}")
            for source_file in defaults_source.rglob("*"):
                if source_file.is_file():
                    relative_path = source_file.relative_to(defaults_source)
                    dest_file = p_mission_folder / relative_path

                    # Create destination directory if needed
                    dest_file.parent.mkdir(parents=True, exist_ok=True)

                    # Check if file already exists
                    if dest_file.exists():
                        should_replace = force
                        if not force:
                            should_replace = typer.confirm(
                                f"File already exists: {relative_path}\nReplace it?", default=False
                            )

                        if should_replace:
                            shutil.copy2(source_file, dest_file)
                            logger.debug(f"Replaced: {relative_path}")
                            files_installed += 1
                        else:
                            logger.debug(f"Skipped: {relative_path}")
                            files_skipped += 1
                    else:
                        shutil.copy2(source_file, dest_file)
                        logger.debug(f"Installed: {relative_path}")
                        files_installed += 1

        # Copy build scripts
        if build_scripts_source and build_scripts_source.exists():
            logger.info(f"Copying build scripts from {build_scripts_source}")
            for source_file in build_scripts_source.rglob("*"):
                if source_file.is_file():
                    relative_path = source_file.relative_to(build_scripts_source)
                    dest_file = p_mission_folder / relative_path

                    # Create destination directory if needed
                    dest_file.parent.mkdir(parents=True, exist_ok=True)

                    # Check if file already exists
                    if dest_file.exists():
                        should_replace = force
                        if not force:
                            should_replace = typer.confirm(
                                f"File already exists: {relative_path}\nReplace it?", default=False
                            )

                        if should_replace:
                            shutil.copy2(source_file, dest_file)
                            logger.debug(f"Replaced: {relative_path}")
                            files_installed += 1
                        else:
                            logger.debug(f"Skipped: {relative_path}")
                            files_skipped += 1
                    else:
                        shutil.copy2(source_file, dest_file)
                        logger.debug(f"Installed: {relative_path}")
                        files_installed += 1

        # Print summary
        console.print("\n[bold green]Preparation completed![/bold green]")
        console.print(f"  Files installed: [cyan]{files_installed}[/cyan]")
        if files_skipped > 0:
            console.print(f"  Files skipped: [yellow]{files_skipped}[/yellow]")
        console.print(f"\nMission folder ready at: [cyan]{p_mission_folder.resolve()}[/cyan]")

    except Exception as e:
        logger.error(f"Preparation failed: {e}")
        exit(1)


@app.command()
def about(
    modules: bool = typer.Option(False, "--modules", help="Show the list of embedded VEAF Lua modules."),
) -> None:
    """
    Shows information about the veaf-tools program.
    """
    if modules:
        mod_list = get_modules()
        if not mod_list:
            console.print(
                "[yellow]No module information available (run from a full repo checkout or built exe).[/yellow]"
            )
            return
        table = Table(title=f"VEAF Lua Modules ({len(mod_list)} total)")
        table.add_column("ID", style="cyan", no_wrap=True)
        table.add_column("Version", style="green")
        table.add_column("File", style="dim")
        for mod in mod_list:
            table.add_row(mod["id"], mod["version"], mod["filename"])
        console.print(table)
        return

    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print(
        "The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World."
    )
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)


@app.command(no_args_is_help=True)
def build(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    no_veaf_triggers: bool = typer.Option(
        False, help="If set, the VEAF triggers will not be injected in the resulting mission."
    ),
    dynamic_mode: bool = typer.Option(
        False,
        help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders).",
    ),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    migrate_from_v5: bool = typer.Option(
        True, help="If set, the builder will parse the mission for old v5 triggers and remove them."
    ),
    log_modules: str | None = typer.Option(
        None,
        help=(
            "Comma-separated list of module IDs to keep at full log level. "
            "All other modules are silenced to 'error' level. "
            "Example: --log-modules 'SPAWN - ,RADIO - '"
        ),
    ),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will build the mission with this name and the current date; can be set to a .miz file.",
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Builds a DCS mission based on a mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission builder v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(MissionBuilderREADME)
            console.print(md_render)
        exit()

    # Resolve input mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve output mission
    p_output_mission = resolve_path(path=mission_name_or_file)
    if p_output_mission.suffix.lower() != ".miz":
        p_output_mission = Path(f"{mission_name_or_file}_{datetime.now().strftime('%Y%m%d')}.miz")

    # Resolve development path
    if not scripts_path and dynamic_mode:
        # default value is the "published" subfolder of the mission folder
        scripts_path = p_mission_folder / "published"
    if scripts_path:
        p_scripts_path = resolve_path(path=scripts_path, should_exist=True)
        if not p_scripts_path.exists():
            logger.error(f"Development folder {p_scripts_path} does not exist!", exception_type=FileNotFoundError)
    else:
        p_scripts_path = None

    # Read mission.yaml: lua_modules (LUA-005) and global_log_level (LUA-007)
    lua_modules: dict | None = None
    global_log_level: str | None = None
    mission_yaml_path = p_mission_folder / "mission.yaml"
    if mission_yaml_path.exists():
        with mission_yaml_path.open("r", encoding="utf-8") as fh:
            mission_yaml = yaml.safe_load(fh) or {}
        lua_modules = mission_yaml.get("lua_modules") or None
        if lua_modules:
            logger.info(f"Found lua_modules section in {mission_yaml_path}; will generate veaf-modules-config.lua")
        global_log_level = mission_yaml.get("global_log_level") or None
        if global_log_level:
            logger.info(f"Found global_log_level={global_log_level!r} in {mission_yaml_path}")

    # Apply --log-modules filter: silence all modules not in the keep list (LUA-006)
    if log_modules is not None:
        keep_modules = {m.strip() for m in log_modules.split(",") if m.strip()}
        all_module_ids = {m["id"] for m in get_modules()}
        unknown = keep_modules - all_module_ids
        if unknown:
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

    # Call the worker class
    worker = MissionBuilderWorker(
        dynamic_mode=dynamic_mode,
        scripts_path=p_scripts_path,
        mission_folder=p_mission_folder,
        output_mission=p_output_mission,
        migrate_from_v5=migrate_from_v5,
        no_veaf_triggers=no_veaf_triggers,
        lua_modules=lua_modules,
        global_log_level=global_log_level,
    )
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def extract(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder where the mission files will be extracted."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts a DCS mission .miz file to a VEAF mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(MissionExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Call the worker class
    worker = MissionExtractorWorker(mission_folder=p_mission_folder, input_mission_path=p_input_mission)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def convert(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    dynamic_mode: bool = typer.Option(
        False,
        help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders).",
    ),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    mission_name: str = typer.Argument(
        help="Mission name; will extract from the mission with this name (most recent .miz file)"
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Converts a DCS mission to a VEAF mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission converter v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(MissionConverterREADME)
            console.print(md_render)
        exit()

    # Compute a file name from the mission name
    p_output_mission = Path(f"{mission_name}_{datetime.now().strftime('%Y%m%d')}.miz")

    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission = mission_name
    if files := list(p_mission_folder.glob(f"{mission_name}*.miz")):
        p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve development path
    if not scripts_path and dynamic_mode:
        # default value is the "published" subfolder of the mission folder
        scripts_path = p_mission_folder / "published"
    if scripts_path:
        p_scripts_path = resolve_path(path=scripts_path, should_exist=True)
        if not p_scripts_path.exists():
            logger.error(f"Development folder {p_scripts_path} does not exist!", exception_type=FileNotFoundError)
    else:
        p_scripts_path = None

    # Call the worker class
    worker = MissionConverterWorker(
        mission_folder=p_mission_folder,
        input_mission=p_input_mission,
        output_mission=p_output_mission,
        mission_name=mission_name,
        dynamic_mode=dynamic_mode,
        scripts_path=p_scripts_path,
        inject_presets=False,
        presets_file=None,
    )
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def inject_presets(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    input_mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject in the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    presets_file: str = typer.Option(DEFAULT_PRESETS_FILE, help="Configuration file containing the presets."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects radio presets read from a configuration file into aircraft groups from a DCS mission
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(PresetsInjectorREADME)
            console.print(md_render)
        exit()

    # Resolve input mission
    p_input_mission = input_mission_name_or_file
    if not input_mission_name_or_file.lower().endswith(".miz"):
        if files := list(Path.cwd().glob(f"{input_mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(path=presets_file, should_exist=True)
    if not p_presets_file.exists():
        logger.error(f"Configuration file {p_presets_file} does not exist!", exception_type=FileNotFoundError)

    # Call the worker class
    worker = PresetsInjectorWorker(
        presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def extract_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help="Interactive mode: select which groups to include."),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_yaml: str = typer.Option("aircraft-templates.yaml", help="Output YAML file path."),
    group_name_pattern: str = typer.Option(".*", help="Regular expression pattern to match aircraft group names."),
    only_airplanes: bool = typer.Option(False, help="Extract only airplanes."),
    only_helicopters: bool = typer.Option(False, help="Extract only helicopters."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    lua_input: str | None = typer.Option(
        None, help="Path to a Lua file (e.g., settings-templates.lua) to extract from instead of a .miz mission."
    ),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts aircraft groups matching a pattern from a DCS mission or Lua settings file and writes them to a YAML file.
    """

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(
            "Cannot use both --only-airplanes and --only-helicopters simultaneously.", exception_type=ValueError
        )

    # Convert boolean options to aircraft_type
    aircraft_type = "airplanes" if only_airplanes else ("helicopters" if only_helicopters else None)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Aircraft Groups Extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(AircraftGroupsExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve output YAML file
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_output_yaml = resolve_path(
        path=output_yaml, default_path=p_mission_folder / output_yaml, create_if_not_exist=True
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = AircraftGroupsExtractorWorker(
            input_lua=p_lua_input,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file (original behavior)
        if not p_mission_folder.exists():
            logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

        # Resolve input mission
        p_input_mission = mission_name_or_file
        if not mission_name_or_file.lower().endswith(".miz"):
            if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
                p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
        p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

        # Call the worker
        worker = AircraftGroupsExtractorWorker(
            input_mission=p_input_mission,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )

    worker.extract(interactive=interactive)

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def inject_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mode: str = typer.Option(
        "add", help="Injection mode: 'add' (add new groups) or 'replace' (replace existing groups)."
    ),
    template_file: str = typer.Option(
        "aircraft-templates.yaml", help="Path to the YAML file containing aircraft groups."
    ),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects aircraft groups from a YAML file into a DCS mission.
    Validates the YAML file before injection and stops if validation fails.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Aircraft Groups Injector v{VERSION}[/bold green]")

    # Validate mode
    if mode not in ("add", "replace"):
        logger.error(f"Invalid mode '{mode}'. Must be 'add' or 'replace'.", exception_type=ValueError)

    # Resolve mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve template YAML file
    p_template_file = resolve_path(path=template_file, should_exist=True)
    if not p_template_file.exists():
        logger.error(f"Template file {p_template_file} does not exist!", exception_type=FileNotFoundError)

    # STEP 1: Validate the YAML file (MANDATORY)
    logger.info("Step 1: Validating YAML file...")
    validator = AircraftGroupsYAMLValidator(p_template_file)
    is_valid, _ = validator.validate()

    # Display validation report
    console.print("\n" + validator.get_report())

    # If validation fails, stop here
    if not is_valid:
        console.print("[bold red]✗ YAML validation failed. Please fix the errors before injection.[/bold red]")
        if pause:
            input(PAUSE_MESSAGE)
        exit(1)

    console.print("[bold green]✓ YAML validation successful![/bold green]\n")

    # STEP 2: Inject aircraft groups
    logger.info(f"Step 2: Injecting aircraft groups using '{mode}' mode...")
    injector = AircraftGroupsInjectorWorker(
        input_yaml=p_template_file, target_mission=p_input_mission, output_mission=p_output_mission
    )
    result = injector.inject(mode=mode, silent=False)

    # Display injection results
    injector.display_results(result, verbose=verbose)

    if result.success:
        console.print(
            f"[bold green]✓ Successfully injected {result.groups_injected} group(s) into the mission![/bold green]"
        )
    else:
        console.print(f"[bold yellow]⚠ Injection completed: {result.message}[/bold yellow]")

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def extract_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help="Interactive mode: select which groups to extract."),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_yaml: str = typer.Option("waypoints.yaml", help="Output YAML file path."),
    group_name_pattern: str = typer.Option(".*", help="Regular expression pattern to match waypoint/group names."),
    only_airplanes: bool = typer.Option(False, help="Extract only airplanes."),
    only_helicopters: bool = typer.Option(False, help="Extract only helicopters."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    lua_input: str | None = typer.Option(
        None, help="Path to a Lua file (e.g., settings-waypoints.lua) to extract from instead of a .miz mission."
    ),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts waypoints matching a pattern from a DCS mission or Lua settings file and writes them to a YAML file.
    """

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(
            "Cannot use both --only-airplanes and --only-helicopters simultaneously.", exception_type=ValueError
        )

    # Convert boolean options to aircraft_type (using 'plane'/'helicopter' naming for waypoints)
    aircraft_type = "plane" if only_airplanes else ("helicopter" if only_helicopters else None)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Waypoints Extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(WaypointsExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve mission folder and output YAML file
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_output_yaml = resolve_path(
        path=output_yaml, default_path=p_mission_folder / output_yaml, create_if_not_exist=True
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = WaypointsExtractorWorker(
            input_lua=p_lua_input,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file
        if not p_mission_folder.exists():
            logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

        # Resolve input mission
        p_input_mission = mission_name_or_file
        if not mission_name_or_file.lower().endswith(".miz"):
            if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
                p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
        p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

        # Call the worker
        worker = WaypointsExtractorWorker(
            input_mission=p_input_mission,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )

    worker.extract(interactive=interactive)

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def inject_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    waypoints_file: str = typer.Option("waypoints.yaml", help="Path to the YAML file containing waypoint definitions."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects waypoints from a YAML file into a DCS mission.
    Only human-piloted aircraft groups will receive waypoints.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Waypoints Injector v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(WaypointsInjectorREADME)
            console.print(md_render)
        exit()

    # Resolve mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve waypoints YAML file
    p_waypoints_file = resolve_path(path=waypoints_file, should_exist=True)
    if not p_waypoints_file.exists():
        logger.error(f"Waypoints file {p_waypoints_file} does not exist!", exception_type=FileNotFoundError)

    # Call the worker class
    worker = WaypointsInjectorWorker(
        waypoints_file=p_waypoints_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command(no_args_is_help=True)
def inject_weather(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE, help="Mission name or .miz file to use as base for creating weather/time variants."
    ),
    config_file: str = typer.Option("missions.yaml", help="Path to YAML configuration file (or Lua file to convert)."),
    convert_lua: bool = typer.Option(False, "--convert-lua", help="Convert legacy Lua configuration to YAML and exit"),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Creates multiple versions of a DCS mission with different weather conditions and start times.
    Uses a YAML configuration file to define mission variants.
    Can also convert legacy Lua configurations to YAML format.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Weather and Time Versions v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(WheatherInjectorREADME)
            console.print(md_render)
        exit()

    p_config_file = resolve_path(path=config_file, should_exist=True)

    # Handle Lua conversion
    if convert_lua or p_config_file.suffix.lower() == ".lua":
        logger.info(f"Converting Lua configuration: {p_config_file}")
        if yaml_file := LuaToYamlConverter.convert_file(p_config_file):
            console.print("[bold green]Lua configuration converted to YAML:[/bold green]")
            console.print(f"  {yaml_file}")
            if typer.confirm("Do you want to create missions from this configuration?"):
                p_config_file = yaml_file
            else:
                if pause:
                    input(PAUSE_MESSAGE)
                return
        else:
            logger.error("Failed to convert Lua configuration")
            if pause:
                input(PAUSE_MESSAGE)
            return

    if not p_config_file.exists():
        logger.error(f"Configuration file {p_config_file} does not exist!", exception_type=FileNotFoundError)

    # Resolve mission file path
    p_mission_file = resolve_path(path=mission_name_or_file, should_exist=True)

    # Call the worker class
    worker = WeatherInjectorWorker(config_file=p_config_file, mission_file=p_mission_file)
    if created_files := worker.work():
        console.print(f"[bold green]Created {len(created_files)} mission files[/bold green]")
        for file_path in created_files:
            console.print(f"  - {file_path.name}")

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


@app.command()
def generate_config(
    output: str = typer.Option(".", help="Output directory for the generated missionconfig.lua template."),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Generates a missionconfig.lua template with all available module configuration options and their defaults.

    Place the generated file in your mission's src/scripts/ folder, rename it to veaf-modules-config.lua,
    then uncomment and adjust any entries you want to change from the defaults.
    Add veaf.initialize() at the end of your missionConfig.lua to activate the new config system.
    """
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Generate Config v{VERSION}[/bold green]")

    p_output = resolve_path(path=output, create_if_not_exist=True)

    modules = get_modules()
    lua_dir = find_lua_scripts_dir()
    configs = scan_module_configs(lua_dir) if lua_dir else {}

    if not modules:
        logger.error("No VEAF Lua module information available. Run from a full repo checkout.")
        return

    lines = [
        "-------------------------------------------------------------------------------------------------------------------------------------------------------------",
        "-- VEAF Module Configuration File - Template",
        "-- Generated by: veaf-tools generate-config",
        "--",
        "-- How to use:",
        "--   1. Copy this file to your mission's src/scripts/ folder as 'veaf-modules-config.lua'",
        "--   2. Uncomment and adjust any entries you want to change from the defaults",
        "--   3. To disable a module, set its 'enable' key to false",
        "--   4. Add veaf.initialize() at the end of your missionConfig.lua",
        "-------------------------------------------------------------------------------------------------------------------------------------------------------------",
        "",
    ]

    for module in modules:
        mid = module["id"]
        defaults = configs.get(mid, {"enable": True})
        lines.append(f"-- === {mid} ===")
        for key, value in defaults.items():
            lua_val = "true" if value else "false"
            lines.append(f'-- veaf.setConfig("{mid}", "{key}", {lua_val})')
        lines.append("")

    output_file = p_output / "missionconfig.lua"
    output_file.write_text("\n".join(lines), encoding="utf-8")
    console.print(f"[bold green]Generated:[/bold green] {output_file}")

    console.print(WORK_DONE_MESSAGE)
    if pause:
        input(PAUSE_MESSAGE)


if __name__ == "__main__":
    import sys

    # When launched with no arguments in an interactive terminal, run the wizard.
    if len(sys.argv) == 1 and sys.stdout.isatty():
        wizard_args = run_wizard()
        if wizard_args:
            sys.argv = sys.argv[:1] + wizard_args

    app()
