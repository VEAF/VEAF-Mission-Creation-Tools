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
import logging
import os
import presets_injector
import scripts_injector
import sys
import typer

VERSION:str = "0.1.0"

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    
    return os.path.join(base_path, relative_path)

app = typer.Typer(no_args_is_help=True)
console = Console()
logger: VeafLogger = None  # Will be initialized in main

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
            md_render = Markdown(presets_injector.README)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    if not input_mission:
        p_input_mission = Path.cwd() / "mission.miz"
    else:
        p_input_mission = Path(input_mission)

    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!")
        raise typer.Abort()
    p_input_mission = p_input_mission.resolve()

    # Resolve output mission
    p_output_mission = Path(output_mission) if output_mission else p_input_mission
    p_output_mission = p_output_mission.resolve()

    # Resolve input mission
    if not presets_file:
        p_presets_file = Path.cwd() / "presets.yaml"
    else:
        p_presets_file = Path(presets_file)

    if not p_presets_file.exists():
        logger.error(f"Configuration file {p_presets_file} does not exist!")
        raise typer.Abort()
    p_presets_file = p_presets_file.resolve()

    # Call the worker class
    worker = presets_injector.PresetsInjectorWorker(logger=logger, presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission)
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
            md_render = Markdown(scripts_injector.README)
            console.print(md_render)
        raise typer.Exit()


    # Resolve input mission
    if not input_mission:
        p_input_mission = Path.cwd() / "mission.miz"
    else:
        p_input_mission = Path(input_mission)

    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!")
        raise typer.Abort()
    p_input_mission = p_input_mission.resolve()

    # Resolve output mission
    p_output_mission = Path(output_mission) if output_mission else p_input_mission
    p_output_mission = p_output_mission.resolve()

    # Resolve development path
    p_development_path = Path(development_path) if development_path else None

    # Call the worker class
    worker = scripts_injector.ScriptsInjectorWorker(logger=logger, development_mode=development_mode, development_path=p_development_path, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print("[bold blue]Work done![/bold blue]")
    # input("Press Enter to exit...")


if __name__ == "__main__":
    app()