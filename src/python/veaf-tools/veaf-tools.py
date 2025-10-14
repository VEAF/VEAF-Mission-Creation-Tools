"""
This program provides a command-line interface (CLI) tool for managing DCS missions.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools.log' file.

Usage:
- Run the script with 'veaf-tools.exe' to access the CLI.
- Use the 'about' command to learn about the VEAF and this program.
- Use the 'inject-presets' command to inject radio presets into a mission file.
- Use the 'inject-scripts' command to inject the VEAF scripts into a mission file (build).

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
from scripts_injector import ScriptsInjectorWorker, ScriptsInjectorREADME
from presets_injector import PresetsInjectorWorker, PresetsInjectorREADME
from mission_builder import MissionBuilderWorker, MissionBuilderREADME
import typer

VERSION:str = "0.1.0"

app = typer.Typer(no_args_is_help=True)
console = Console()
logger: VeafLogger = None  # Will be initialized in main

def resolve_path(path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False) -> Path:
    
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
        raise FileNotFoundError(f"Path does not exist: {result}")
    
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
    readme: bool = typer.Option(False, help="Provide access to the README file."),
    verbose: bool = typer.Option(False, help="If set, the script will output a lot of debug information."),
    input_mission: Optional[str] = typer.Argument("mission.miz", help="Mission file to edit."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
    presets_file: str = typer.Option("presets.yaml", help="Configuration file containing the presets."),
) -> None:
    """
    Injects radio presets read from a configuration file into aircraft groups from a DCS mission
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-presets-injector", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm("Do you want to display the documentation?"):
            md_render = Markdown(PresetsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    p_input_mission = resolve_path(path=input_mission, default_path=Path.cwd() / "mission.miz", should_exist=True)
    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(path=presets_file, default_path=Path.cwd() / "presets.yaml", should_exist=True)
    if not p_presets_file.exists():
        logger.error(f"Configuration file {p_presets_file} does not exist!", raise_exception=True)

    # Call the worker class
    worker = PresetsInjectorWorker(logger=logger, presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print("[bold blue]Work done![/bold blue]")
    # input("Press Enter to exit...")

@app.command()
def inject_scripts(
    readme: bool = typer.Option(False, help="Provide access to the README file."),
    verbose: bool = typer.Option(False, help="If set, the script will output a lot of debug information."),
    development_mode: bool = typer.Option(False, help="If set, the mission will dynamically load the scripts from the provided location (via --development-path or in the local node_modules and src/scripts folders)."),
    development_path: str = typer.Option(None, help="Path to the development version of the VEAF scripts."),
    input_mission: Optional[str] = typer.Argument("mission.miz", help="Mission file to edit."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
) -> None:
    """
    Injects VEAF scriots into an existing DCS mission
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF scripts injector v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-scripts-injector", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm("Do you want to display the documentation?"):
            md_render = Markdown(ScriptsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    p_input_mission = resolve_path(path=input_mission, default_path=Path.cwd() / "mission.miz", should_exist=True)
    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(output_mission, default_path=p_input_mission)

    # Resolve development path
    if development_path:
        p_development_path = resolve_path(path=development_path, should_exist=True)
        if not p_development_path.exists():
            logger.error(f"Input mission {p_development_path} does not exist!", raise_exception=True)
    else:
        p_development_path = None

    # Call the worker class
    worker = ScriptsInjectorWorker(logger=logger, development_mode=development_mode, development_path=p_development_path, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print("[bold blue]Work done![/bold blue]")
    # input("Press Enter to exit...")

@app.command()
def build_mission(
    readme: bool = typer.Option(False, help="Provide access to the README file."),
    verbose: bool = typer.Option(False, help="If set, the script will output a lot of debug information."),
    development_mode: bool = typer.Option(False, help="If set, the mission will dynamically load the scripts from the provided location (via --development-path or in the local node_modules and src/scripts folders)."),
    development_path: str = typer.Option(None, help="Path to the development version of the VEAF scripts."),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder with the mission files."),
    output_mission: Optional[str] = typer.Argument("mission.miz", help="Mission file to save."),
) -> None:
    """
    Builds a DCS mission based on a mission folder.
    """

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission builder v{VERSION}[/bold green]")

    logger = VeafLogger(logger_name="veaf-tools-mission-builder", console=console).set_verbose(verbose)

    if readme:
        if typer.confirm("Do you want to display the documentation?"):
            md_render = Markdown(ScriptsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(output_mission, default_path=p_mission_folder)

    # Resolve development path
    if not development_path and development_mode:
        # default value is the "/node_modules/veaf-mission-creation-tools" subfolder of the mission folder
        development_path = p_mission_folder / "node_modules" / "veaf-mission-creation-tools"
    if development_path:
        p_development_path = resolve_path(path=development_path, should_exist=True)
        if not p_development_path.exists():
            logger.error(f"Development folder {p_development_path} does not exist!", raise_exception=True)
    else:
        p_development_path = None

    # Call the worker class
    worker = MissionBuilderWorker(logger=logger, development_mode=development_mode, development_path=p_development_path, mission_folder=p_mission_folder, output_mission=p_output_mission)
    worker.work()

    console.print("[bold blue]Work done![/bold blue]")
    # input("Press Enter to exit...")

if __name__ == "__main__":
    app()