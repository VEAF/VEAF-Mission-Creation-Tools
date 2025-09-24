"""
This program provides a command-line interface (CLI) tool for managing DCS missions.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools.log' file.

Usage:
- Run the script with 'veaf-tools.exe' to access the CLI.
- Use the 'about' command to learn about the VEAF and this program.
- Use the 'inject_presets' command to inject radio presets into a mission file.

Example:
- To inject presets into a mission file:
      'python veaf-tools.py inject-presets --verbose --presets-file my_presets.yaml my_mission.miz my_output.miz'
"""

from pathlib import Path
from rich.console import Console
from rich.markdown import Markdown
from typing import Optional
from typing import Optional
from xmlrpc.client import Boolean
import logging
import os
import presets_injector
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

class Logger:
    """Logging and console print system."""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        # Configure logging with better format
        logging.basicConfig(
            filename="veaf-tools.log",
            level=logging.DEBUG if self.verbose else logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            filemode='w'  # Overwrite log file on each run
        )
        self.logger = logging.getLogger("veaf-tools")

    def set_verbose(self, verbose: bool):
        self.verbose = verbose
        self.set_level(logging.DEBUG if self.verbose else logging.INFO)

    def set_level(self, level):
        self.logger.setLevel(level=level)

    def error(self, message: str, raise_exception: Boolean = False) -> None:
        """Log and display error message."""
        self.logger.error(message)
        console.print(message, style="red")
        if raise_exception:
            raise typer.Abort(message)

    def warning(self, message: str) -> None:
        """Log and display warning message."""
        self.logger.warning(message)
        console.print(message, style="yellow")


    def info(self, message: str) -> None:
        """Log and display info message."""
        self.logger.info(message)
        console.print(message, style="blue")


    def debug(self, message: str) -> None:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose:
            console.print(message, style="grey69")
    
    def debugwarn(self, message: str) -> None:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose:
            console.print(message, style="dark_khaki")

app = typer.Typer(no_args_is_help=True)
console = Console()
logger: Logger = Logger()  # Will be initialized in main()

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

    logger.set_verbose(verbose)

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

if __name__ == "__main__":
    app()