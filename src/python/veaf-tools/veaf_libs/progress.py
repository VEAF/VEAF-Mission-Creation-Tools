from collections.abc import Sized
from dataclasses import dataclass
from typing import Any, Iterable
from rich.console import Console
from rich.spinner import Spinner
from rich.live import Live
from rich.text import Text
from contextlib import contextmanager
from .logger import logger, console
from rich.live import Live
from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeRemainingColumn
from rich.highlighter import ReprHighlighter
import sys
import io

# Ensure UTF-8 output on Windows and other platforms
if sys.platform == "win32":
    # On Windows, reconfigure stdout to use UTF-8 if possible
    if sys.stdout and not sys.stdout.encoding or sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
        try:
            # Try to use UTF-8 for console output
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
        except Exception:
            pass  # Fall back to default if reconfiguration fails

highlighter = ReprHighlighter()

@dataclass
class SpinnerControl:
    done_message: str | None = None

@contextmanager
def spinner_context(message: str, done_message: str|None = None, silent: bool = False, 
                   msg_color: str = "bold blue", 
                   spinner_color: str = "bold magenta",
                   done_color: str = "bold blue"):
    """Context manager for work-in-progress spinner with done message"""
    if silent:
        control = SpinnerControl(done_message=done_message)
        yield control
    else:
        control = SpinnerControl(done_message=done_message)
        
        # Create Text with base style, then highlight (highlights override base for matched parts)
        styled_msg = Text(message, style=msg_color)
        highlighter.highlight(styled_msg)
        
        live = Live(
            Spinner("dots", text=styled_msg, style=spinner_color),
            console=console,
            refresh_per_second=12.5
        )
        live.start()
        show_done = True
        try:
            yield control
        except Exception:
            show_done = False
            raise
        finally:
            if show_done:            
                final_done_message = control.done_message or done_message
                if not final_done_message: 
                    final_done_message = "✓ Done " + message.removesuffix("...")[0].lower() + message.removesuffix("...")[1:] + "!"
                    if logger: logger.info(message, no_console=True)
                
                styled_done = Text(final_done_message, style=done_color)
                highlighter.highlight(styled_done)
                
                live.update(styled_done)
                live.stop()

@contextmanager
def progress_context(
    collection: Iterable[Any],
    message: str,
    done_message: str | None = None,
    silent: bool = False,
    total: int | None = None,
    msg_color: str = "bold blue",
    bar_color: str = "bold magenta",
    done_color: str = "bold blue"
):
    """Context manager for iterating over a collection with a progress bar."""
    if silent:
        yield iter(collection)
    else:
        if total is None:
            if isinstance(collection, Sized):
                total = len(collection)
            else:
                raise ValueError("Must provide 'total' for iterables without len()")
        
        # Create Text with base style, then highlight
        styled_msg = Text(message, style=msg_color)
        highlighter.highlight(styled_msg)
        
        progress = Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(complete_style=bar_color, finished_style=bar_color),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            TimeRemainingColumn(),
            console=console,
            refresh_per_second=12.5
        )
        
        task = progress.add_task(str(styled_msg), total=total)
        
        live = Live(progress, console=console, refresh_per_second=12.5)
        live.start()
        
        show_done = True
        try:
            def generator():
                for item in collection:
                    yield item
                    progress.update(task, advance=1)
            
            yield generator()
            
        except Exception:
            show_done = False
            raise
        finally:
            if show_done:
                if not done_message:
                    done_message = "✓ Done " + message.removesuffix("...")[0].lower() + message.removesuffix("...")[1:] + "!"
                
                styled_done = Text(done_message, style=done_color)
                highlighter.highlight(styled_done)
                
                live.update(styled_done)
            
            live.stop()