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
from presets_injector.presets_injector_worker import PresetsInjectorWorker
from scripts_injector.scripts_injector_worker import ScriptsInjectorWorker
from presets_injector.presets_injector_README import PresetsInjectorREADME
from scripts_injector.scripts_injector_README import ScriptsInjectorREADME
import sys
import typer

VERSION:str = "0.1.0"

app = typer.Typer(no_args_is_help=True)
console = Console()
logger: VeafLogger = None  # Will be initialized in main

def resolve_path(path: str, default_path: str = None, shouldExist: bool = False, createIfNotExist: bool = False) -> Path:
    result: Optional[Path] = None
    if not path and shouldExist:
        if default_path:
            result = default_path
    else:
        result = Path(path)

    if createIfNotExist and not result.exists():
        pass

    if result: result = result.resolve()
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
    p_input_mission = resolve_path(path=input_mission, default_path=Path.cwd() / "mission.miz", shouldExist=True)
    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(path=presets_file, default_path=Path.cwd() / "presets.yaml", shouldExist=True)
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
    p_input_mission = resolve_path(path=input_mission, default_path=Path.cwd() / "mission.miz", shouldExist=True)
    if not p_input_mission.exists():
        logger.error(f"Input mission {p_input_mission} does not exist!", raise_exception=True)

    # Resolve output mission
    p_output_mission = resolve_path(output_mission, default_path=p_input_mission)

    # Resolve development path
    if development_path:
        p_development_path = resolve_path(path=development_path, shouldExist=True)
        if not p_development_path.exists():
            logger.error(f"Input mission {p_development_path} does not exist!", raise_exception=True)
    else:
        p_development_path = None

    # Call the worker class
    worker = ScriptsInjectorWorker(logger=logger, development_mode=development_mode, development_path=p_development_path, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print("[bold blue]Work done![/bold blue]")
    # input("Press Enter to exit...")


if __name__ == "__main__":
    app()