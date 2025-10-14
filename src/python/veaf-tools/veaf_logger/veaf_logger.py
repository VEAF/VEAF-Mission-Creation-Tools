import logging
from typing import Optional
from typing_extensions import Self
from rich.console import Console
import typer

class VeafLogger:
    """Logging and console print system."""

    def __init__(self, logger_name: str, verbose: bool = False, console:Optional[Console] = None):
        # Create a specific logger instance
        self.logger = logging.getLogger(logger_name)
        self.logger.setLevel(logging.DEBUG if verbose else logging.INFO)
        
        # Only add handlers if they don't exist
        if not self.logger.handlers:
            # File handler
            file_handler = logging.FileHandler(f"{logger_name}.log", mode='w')
            file_handler.setFormatter(
                logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            )
            self.logger.addHandler(file_handler)

        self.console = console

    def set_verbose(self, verbose: bool) -> Self:
        self.verbose = verbose
        self.set_level(logging.DEBUG)
        return self

    def set_level(self, level):
        self.logger.setLevel(level=level)
        return self

    def error(self, message: str, raise_exception: bool = False) -> Self:
        """Log and display error message."""
        self.logger.error(message)
        if self.console:
            self.console.print(message, style="red")
        if raise_exception:
            raise typer.Abort(message)
        return self

    def warning(self, message: str) -> Self:
        """Log and display warning message."""
        self.logger.warning(message)
        if self.console:
            self.console.print(message, style="yellow")
        return self

    def info(self, message: str) -> Self:
        """Log and display info message."""
        self.logger.info(message)
        if self.console:
            self.console.print(message, style="blue")
        return self

    def debug(self, message: str) -> Self:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose and self.console:
            self.console.print(message, style="grey69")
        return self
    
    def debugwarn(self, message: str) -> Self:
        """Log debug message."""
        self.logger.debug(message)
        if self.verbose and self.console:
            self.console.print(message, style="dark_khaki")
        return self