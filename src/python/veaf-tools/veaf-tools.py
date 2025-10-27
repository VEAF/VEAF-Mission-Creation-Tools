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

from pathlib import Path
from rich.markdown import Markdown
from typing import Optional

from veaf_logger import logger, console
from presets_injector import PresetsInjectorWorker, PresetsInjectorREADME
from mission_builder import MissionBuilderWorker, MissionBuilderREADME
from mission_extractor import MissionExtractorWorker, MissionExtractorREADME
from mission_converter import MissionConverterWorker, MissionConverterREADME
from mission_tools import spinner_context
import typer
from datetime import datetime

VERSION:str = "6.0.1"
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

def resolve_path(path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False) -> Path:
    
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
        if not result.suffix:  # It's a directory
            result.mkdir(exist_ok=True)
    
    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)
    
    return result

@app.command(no_args_is_help=True)
def about(
) -> None:
    """
    Shows information about the veaf-tools program
    """
    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print("The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World.")
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)

@app.command(no_args_is_help=True)
def inject_presets(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    input_mission_name_or_file: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission name; will inject in the mission with this name (most recent .miz file); can be set to a .miz file."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
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
    worker = PresetsInjectorWorker(presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause: input(PAUSE_MESSAGE)

@app.command(no_args_is_help=True)
def build(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    no_veaf_triggers: bool = typer.Option(False, help="If set, the VEAF triggers will not be injected in the resulting mission."),
    dynamic_mode: bool = typer.Option(False, help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders)."),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    migrate_from_v5: bool = typer.Option(True, help="If set, the builder will parse the mission for old v5 triggers and remove them."),
    mission_name_or_file: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission name; will build the mission with this name and the current date; can be set to a .miz file."),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder with the mission files."),
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
        # Compute a file name from the mission name
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

    # Call the worker class
    worker = MissionBuilderWorker(dynamic_mode=dynamic_mode, scripts_path=p_scripts_path, mission_folder=p_mission_folder, output_mission=p_output_mission, migrate_from_v5=migrate_from_v5, no_veaf_triggers=no_veaf_triggers)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause: input(PAUSE_MESSAGE)

@app.command(no_args_is_help=True)
def extract(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file."),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder where the mission files will be extracted."),
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
    if pause: input(PAUSE_MESSAGE)

@app.command(no_args_is_help=True)
def convert(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    dynamic_mode: bool = typer.Option(False, help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders)."),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    mission_name: str = typer.Argument(help="Mission name; will extract from the mission with this name (most recent .miz file)"),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder with the mission files."),
    inject_presets: bool = typer.Option(False, help="If set, presets will be injected into the mission from the presets.yaml file."),
    presets_file: str = typer.Option(None, help="Configuration file containing the presets; defaults to the presets.yaml file in the VEAF defaults folder."),
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


    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission = mission_name
    if files := list(p_mission_folder.glob(f"{mission_name}*.miz")):
        p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)
    
    # Compute a file name from the mission name
    p_output_mission = Path(f"{mission_name}_{datetime.now().strftime('%Y%m%d')}.miz")

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

    # Resolve presets configuration file
    if p_presets_file := presets_file:
        p_presets_file = resolve_path(path=presets_file, should_exist=True)
        if not p_presets_file.exists():
            logger.error(f"Configuration file {p_presets_file} does not exist!", exception_type=FileNotFoundError)

    # Call the worker class
    worker = MissionConverterWorker(mission_folder=p_mission_folder, input_mission=p_input_mission, output_mission=p_output_mission, mission_name=mission_name, dynamic_mode=dynamic_mode, scripts_path=p_scripts_path, inject_presets=inject_presets, presets_file=p_presets_file)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    if pause: input(PAUSE_MESSAGE)

if __name__ == "__main__":
    app()