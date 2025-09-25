import logging
from typing import Optional, Self
from rich.console import Console
import typer

class VeafLogger:
    """Logging and console print system."""

    def __init__(self, logger_name: str, verbose: bool = False, console:Optional[Console] = None):
        self.verbose = verbose
        # Configure logging with better format
        logging.basicConfig(
            filename=f"{logger_name}.log",
            level=logging.DEBUG if self.verbose else logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            filemode='w'  # Overwrite log file on each run
        )
        self.logger = logging.getLogger(logger_name)
        self.console: Console = console

    def set_verbose(self, verbose: bool) -> Self:
        self.verbose = verbose
        self.set_level(logging.DEBUG if self.verbose else logging.INFO)
        return self

    def set_level(self, level):
        self.logger.setLevel(level=level)
        return self

    def error(self, message: str, raise_exception: bool = False) -> Self:
        """Log and display error message."""
        self.logger.error(message)
        self.console.print(message, style="red")
        if raise_exception:
            raise typer.Abort(message)
        return self

    def warning(self, message: str) -> Self:
        """Log and display warning message."""
        self.logger.warning(message)
        self.console.print(message, style="yellow")
        return self


    def info(self, message: str) -> Self:
        """Log and display info message."""
        self.logger.info(message)
        self.console.print(message, style="blue")
        return self

    def debug(self, message: str) -> Self:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose:
            self.console.print(message, style="grey69")
        return self
    
    def debugwarn(self, message: str) -> Self:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose:
            self.console.print(message, style="dark_khaki")
        return self