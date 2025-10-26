from rich.console import Console
from rich.spinner import Spinner
from rich.live import Live
from rich.text import Text
from contextlib import contextmanager
from veaf_logger import logger

console = Console()

@contextmanager
def spinner_context(message: str, done_message: str = None, silent: bool = False, 
                   msg_color: str = "bold blue", 
                   spinner_color: str = "bold magenta",
                   done_color: str = "bold blue"):
    """Context manager for work-in-progress spinner with done message"""
    if silent:
        yield
    else:
        styled_msg = Text(message, style=msg_color)
        live = Live(
            Spinner("dots", text=styled_msg, style=spinner_color),
            console=console,
            refresh_per_second=12.5
        )
        live.start()
        try:
            yield live
        finally:
            if not done_message: 
                done_message = "✓ Done " + message.removesuffix("...")[0].lower() + message.removesuffix("...")[1:] + "!"
                if logger: logger.info(message, no_console=True)
            styled_done = Text(done_message, style=done_color)
            live.update(Spinner("dots", text=styled_done, style=spinner_color))
            live.stop()