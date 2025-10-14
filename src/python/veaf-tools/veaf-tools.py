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
from rich.console import Console
from rich.markdown import Markdown
from typing import Optional
from veaf_logger import VeafLogger
from presets_injector import PresetsInjectorWorker, PresetsInjectorREADME
from mission_builder import MissionBuilderWorker, MissionBuilderREADME
from mission_extractor import MissionExtractorWorker, MissionExtractorREADME
import typer
from datetime import datetime

VERSION:str = "0.2.0"
README_HELP: str = "Provide access to the README file."
VERBOSE_HELP: str = "If set, the script will output a lot of debug information."

# String constants
DEFAULT_MISSION_FILE = "mission.miz"
DEFAULT_PRESETS_FILE = "presets.yaml"
CONFIRM_DISPLAY_DOC = "Do you want to display the documentation?"
WORK_DONE_MESSAGE = "[bold blue]Work done![/bold blue]"

app = typer.Typer(no_args_is_help=True)
console = Console()

def resolve_path(logger:VeafLogger, path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False) -> Path:
    
    """Resolve and validate a file path."""
    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        raise ValueError("Either path or default_path must be provided")
    
    result = result.resolve()
    
    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:  # It's a directory
            result.mkdir(exist_ok=True)
    
    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)
    
    return result

@app.command()
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

@app.command()
def inject_presets(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    input_mission: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission file to edit."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
    presets_file: str = typer.Option(DEFAULT_PRESETS_FILE, help="Configuration file containing the presets."),
) -> None:
    """
    Injects radio presets read from a configuration file into aircraft groups from a DCS mission
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-presets-injector", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm(CONFIRM_DISPLAY_DOC):
            md_render = Markdown(PresetsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    p_input_mission = resolve_path(logger=logger, path=input_mission, default_path=Path.cwd() / DEFAULT_MISSION_FILE, should_exist=True)
    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(logger=logger, path=output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(logger=logger, path=presets_file, default_path=Path.cwd() / "presets.yaml", should_exist=True)
    if not p_presets_file.exists():
        logger.error(f"Configuration file {p_presets_file} does not exist!", raise_exception=True)

    # Call the worker class
    worker = PresetsInjectorWorker(logger=logger, presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    # input("Press Enter to exit...")

@app.command()
def build_mission(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    dynamic_mode: bool = typer.Option(False, help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local node_modules and src/scripts folders)."),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    migrate_from_v5: bool = typer.Option(True, help="If set, the builder will parse the mission for old v5 triggers and remove them."),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder with the mission files."),
    mission_name_or_file: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission name; will build the mission with this name and the current date; can be set to a .miz file."),
) -> None:
    """
    Builds a DCS mission based on a mission folder.
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission builder v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-mission-builder", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm("Do you want to display the documentation?"):
            md_render = Markdown(MissionBuilderREADME)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission folder
    p_mission_folder = resolve_path(logger=logger, path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(logger=logger, path=mission_name_or_file)
    if p_output_mission.suffix.lower() != ".miz":
        # Compute a file name from the mission name
        p_output_mission = Path(f"{mission_name_or_file}_{datetime.now().strftime('%Y%m%d')}.miz")

    # Resolve development path
    if not scripts_path and dynamic_mode:
        # default value is the "/node_modules/veaf-mission-creation-tools" subfolder of the mission folder
        scripts_path = p_mission_folder / "node_modules" / "veaf-mission-creation-tools"
    if scripts_path:
        p_scripts_path = resolve_path(logger=logger, path=scripts_path, should_exist=True)
        if not p_scripts_path.exists():
            logger.error(f"Development folder {p_scripts_path} does not exist!", raise_exception=True)
    else:
        p_scripts_path = None

    # Call the worker class
    worker = MissionBuilderWorker(logger=logger, dynamic_mode=dynamic_mode, scripts_path=p_scripts_path, mission_folder=p_mission_folder, output_mission=p_output_mission, migrate_from_v5=migrate_from_v5)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    # input("Press Enter to exit...")

@app.command()
def extract_mission(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: Optional[str] = typer.Argument(DEFAULT_MISSION_FILE, help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file."),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder where the mission files will be extracted."),
) -> None:
    """
    Extracts a DCS mission .miz file to a VEAF mission folder.
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission extractor v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-mission-extractor", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm("Do you want to display the documentation?"):
            md_render = Markdown(MissionExtractorREADME)
            console.print(md_render)
        raise typer.Exit()

    # Resolve output mission folder
    p_mission_folder = resolve_path(logger=logger, path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", raise_exception=True)

    # Resolve input mission
    p_input_mission = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(logger=logger, path=p_input_mission, should_exist=True)
    
    # Call the worker class
    worker = MissionExtractorWorker(logger=logger, mission_folder=p_mission_folder, input_mission_path=p_input_mission)
    worker.work()

    console.print(WORK_DONE_MESSAGE)
    # input("Press Enter to exit...")

if __name__ == "__main__":
    app()