import logging
from typing import Optional
from typing_extensions import Self
from rich.console import Console
import typer
import sys

class Logger:
    """Logging and console print system."""

    def __init__(self, logger_name: str, verbose: bool = False, console:Optional[Console] = None):
        # Create a specific logger instance
        self.logger = logging.getLogger(logger_name)
        self.logger.setLevel(logging.DEBUG if verbose else logging.INFO)
        
        # Only add handlers if they don't exist
        if not self.logger.handlers:
            # File handler with UTF-8 encoding
            file_handler = logging.FileHandler(f"{logger_name}.log", mode='a', encoding='utf-8')
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

    def exception(self, e: Exception):
        self.error(str(e), exception_type=type(e))

    def error(self, message: str, no_console: bool = False, raise_exception: bool = False, exception_type: type = typer.Abort) -> Self:
        """Log and display error message."""
        self.logger.error(message)
        if self.console and not no_console:
            self.console.print(message, style="red")
        if raise_exception or exception_type:
            raise exception_type(message)
        return self

    def warning(self, message: str, no_console: bool = False) -> Self:
        """Log and display warning message."""
        self.logger.warning(message)
        if self.console and not no_console:
            self.console.print(message, style="yellow")
        return self

    def info(self, message: str, no_console: bool = False) -> Self:
        """Log and display info message."""
        self.logger.info(message)
        if self.console and not no_console:
            self.console.print(message, style="cyan")
        return self

    def debug(self, message: str, no_console: bool = False) -> Self:
        """Log debug message."""
        return self._do_debug(message, no_console, "grey69")
    
    def debugwarn(self, message: str, no_console: bool = False) -> Self:
        """Log debug message."""
        return self._do_debug(message, no_console, "dark_khaki")

    def _do_debug(self, message, no_console, style):
        self.logger.debug(message)
        if self.verbose and self.console and not no_console:
            self.console.print(message, style=style)
        return self
    
console: Console = Console()
logger: Logger = Logger(logger_name="veaf-tools", console=console)
