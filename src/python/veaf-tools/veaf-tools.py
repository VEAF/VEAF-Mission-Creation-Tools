from typing import Optional
from pathlib import Path
from rich.console import Console
from typing import Optional
from xmlrpc.client import Boolean
import logging
import typer
import typer
import presets_injector

VERSION:str = "0.1.0"

class Logger:
    """Logging and console print system."""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        # Configure logging with better format
        logging.basicConfig(
            filename="veaf-tools.log",
            level=logging.DEBUG if self.verbose else logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger("veaf-tools")

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
            console.print(message, style="grey")
    
app = typer.Typer()
console = Console()
logger: Logger = Logger()  # Will be initialized in main()

@app.command()
def inject_aircrafts(
    input_mission: Optional[str] = typer.Argument("mission.miz", help="Mission file to edit."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
    verbose: bool = typer.Option(False, help="If set, the script will output a lot of debug information."),
    config_file: str = typer.Option("presets.yaml", help="Configuration file containing the presets."),
) -> None:
    """
    Injects aircraft groups read from a configuration file into a DCS mission
    """

    pass



@app.command()
def inject_presets(
    input_mission: Optional[str] = typer.Argument("mission.miz", help="Mission file to edit."),
    output_mission: Optional[str] = typer.Argument(None, help="Mission file to save; defaults to the same as 'input_mission'."),
    verbose: bool = typer.Option(False, help="If set, the script will output a lot of debug information."),
    config_file: str = typer.Option("presets.yaml", help="Configuration file containing the presets."),
) -> None:
    """
    Injects radio presets read from a configuration file into aircraft groups from a DCS mission
    """

    # Set the title and version
    console.print(f"Starting [bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]\n")

    logger.set_level(logging.DEBUG if verbose else logging.INFO)

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
    if not config_file:
        p_config_file = Path.cwd() / "presets.yaml"
    else:
        p_config_file = Path(config_file)

    if not p_config_file.exists():
        logger.error(f"Configuration file {p_config_file} does not exist!")
        raise typer.Abort()
    p_config_file = p_config_file.resolve()

    # Call the worker class
    worker = presets_injector.PresetsInjectorWorker(logger=logger, config_file=p_config_file, input_mission=p_input_mission, output_mission=p_output_mission)
    worker.work()

    console.print(f"Quitting [bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]\n")
    # input("Press Enter to exit...")

if __name__ == "__main__":
    app()