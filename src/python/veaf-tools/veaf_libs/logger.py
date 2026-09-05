import logging
import logging.handlers
import sys
from collections.abc import Callable
from pathlib import Path
from types import TracebackType
from typing import Self, cast

import typer
from rich.console import Console

from veaf_libs.console_status import StatusLine

#: Size at which the log file rolls over. Two megabytes is roughly a fortnight of ordinary use and
#: still opens instantly in any editor — the point of rotating is that someone actually reads it.
LOG_MAX_BYTES: int = 2 * 1024 * 1024

#: How many rolled-over files are kept beside the live one, so a crash from last week is still
#: readable. Three plus the live file caps the whole thing at 8 MB.
LOG_BACKUP_COUNT: int = 3


def configure_stdio_encoding() -> None:
    """Force stdout/stderr to UTF-8 so console output never crashes or truncates.

    Under a legacy Windows code page (cp1252), printing a glyph outside that page
    — an arrow ``→``, box-drawing from a code block, an emoji — raises
    ``UnicodeEncodeError`` mid-render, which silently truncates the output (e.g. a
    chatbot answer cut off mid-sentence). Reconfiguring the standard streams to
    UTF-8 with ``errors="replace"`` makes the encode total, so a render always
    completes.

    Idempotent and defensive: a stream without ``reconfigure`` (e.g. a captured
    test stream) or a failure to reconfigure is silently ignored.
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):
            # Fail-soft: a stream that refuses to reconfigure (already detached, or an
            # unusual platform) keeps its current encoding — a degraded glyph is
            # acceptable, a crash at CLI startup is not.
            pass


class Logger:
    """Logging and console print system."""

    def __init__(self, logger_name: str, verbose: bool = False, console: Console | None = None):
        # Create a specific logger instance
        self.verbose = verbose
        self.logger = logging.getLogger(logger_name)
        self.logger.setLevel(logging.DEBUG if verbose else logging.INFO)

        # Only add handlers if they don't exist
        if not self.logger.handlers:
            # Resolve log file path: prefer VEAF_HOME, fall back to CWD
            try:
                from veaf_libs.veaf_home import get_veaf_home

                log_path: Path = get_veaf_home() / f"{logger_name}.log"
            except Exception:
                log_path = Path(f"{logger_name}.log")

            # Rotating file handler with UTF-8 encoding. It used to append for ever, which is why
            # nobody looked at the file: by the time it mattered it was megabytes of history with the
            # interesting part somewhere in the middle.
            file_handler = logging.handlers.RotatingFileHandler(
                log_path,
                mode="a",
                maxBytes=LOG_MAX_BYTES,
                backupCount=LOG_BACKUP_COUNT,
                encoding="utf-8",
            )
            file_handler.setFormatter(logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s"))
            self.logger.addHandler(file_handler)

        self.console = console
        self.status: StatusLine | None = StatusLine(console) if console else None

    def set_verbose(self, verbose: bool) -> Self:
        self.verbose = verbose
        self.set_level(logging.DEBUG)
        # Transient single-line output only makes sense for an interactive,
        # non-verbose run. Derive interactivity from the Rich console's own
        # output stream (which may differ from sys.stdout, e.g. stderr or a
        # redirected file) so status-line behaviour matches the real
        # destination. Under --verbose or when piped, every message scrolls
        # normally so nothing is lost.
        if self.status:
            interactive = bool(self.console and self.console.is_terminal)
            self.status.configure(enabled=not verbose and interactive)
        return self

    def stop_status(self) -> Self:
        """Stop the transient status line (call once at program end)."""
        if self.status:
            self.status.stop()
        return self

    def mute_console(self) -> Self:
        """Silence Rich console output; keep the log file + logging handlers.

        A stdio MCP server speaks JSON-RPC on **stdout** — any Rich `console.print` there
        corrupts the stream and the client sees the server but no tools. Call this before
        `mcp.run()` so all logging stays on the log file / logging handlers (stderr) and never
        touches stdout.
        """
        if self.status:
            self.status.stop()
        self.console = None
        self.status = None
        return self

    def set_level(self, level):
        self.logger.setLevel(level=level)
        return self

    def exception(self, e: Exception):
        """Report an exception, writing its stack trace to the log file.

        The trace is what says **where** it broke, and it used to be dropped: this method called
        :meth:`error` with the message alone, so the file recorded that something failed and lost the
        only part a maintainer could act on. What reaches the console is unchanged — the trace goes to
        the file sink only.

        Args:
            e: The exception being reported. Its ``__cause__``/``__context__`` chain is written too.
        """
        self.error(str(e), exception_type=type(e), exc_info=e)

    def error(
        self,
        message: str,
        no_console: bool = False,
        raise_exception: bool = False,
        exception_type: type | None = typer.Abort,
        exc_info: BaseException | None = None,
    ) -> Self:
        """Log and display error message.

        Args:
            message: The message, shown in red on the console and written to the log file.
            no_console: True → write to the log file only.
            raise_exception: True → raise even when *exception_type* is ``None``.
            exception_type: What to raise; ``None`` with *raise_exception* false returns instead.
            exc_info: An exception whose stack trace is appended **to the log file only**.
        """
        self.logger.error(message, exc_info=exc_info)
        if self.console and not no_console:
            self.console.print(message, style="red")
        if raise_exception or exception_type:
            raise (exception_type or typer.Abort)(message)
        return self

    def warning(self, message: str, no_console: bool = False) -> Self:
        """Log and display warning message."""
        self.logger.warning(message)
        if self.console and not no_console:
            self.console.print(message, style="yellow")
        return self

    def info(self, message: str, no_console: bool = False) -> Self:
        """Log an info message; display it transiently when possible.

        The message is always written to the log file. On the console it is
        shown on the single overwriting status line when transient mode is
        active, otherwise printed as a normal scrolling line.
        """
        self.logger.info(message)
        if self.console and not no_console:
            if not (self.status and self.status.update(message, style="cyan")):
                self.console.print(message, style="cyan")
        return self

    def tech(self, message: str, no_console: bool = False) -> Self:
        """Log and display a permanent technical line.

        Use for output that must stay on screen: tool start-up, version,
        generated file names, final totals.
        """
        self.logger.info(message)
        if self.console and not no_console:
            self.console.print(message, style="cyan")
        return self

    def detail(self, message: str, no_console: bool = False) -> Self:
        """Log and display a permanent detail line, indented under its pipeline step.

        Same as :meth:`tech` but the console line is prefixed with two spaces, so a
        step's details read as an indented sub-list under its :meth:`step` header.
        The log file keeps the un-indented message.
        """
        self.logger.info(message)
        if self.console and not no_console:
            self.console.print(f"  {message}", style="cyan")
        return self

    def step(self, message: str, no_console: bool = False) -> Self:
        """Log and display a permanent chapter header for a major stage.

        The message carries its own Rich markup styling; it is rendered as a
        permanent line above the transient status line.
        """
        self.logger.info(message)
        if self.console and not no_console:
            if self.status:
                self.status.clear()
            self.console.print(message, style="bold blue")
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


#: Marks a hook this module installed, so a second call replaces nothing and chains nothing twice.
_EXCEPTHOOK_MARKER = "_veaf_excepthook"

ExceptHook = Callable[[type[BaseException], BaseException, TracebackType | None], None]


def install_excepthook(target: "Logger | None" = None) -> ExceptHook:
    """Journal an uncaught exception before it reaches the terminal.

    ``app()`` runs inside a ``try/finally`` with no ``except``, so a crash printed a traceback on
    stderr, scrolled away with the console buffer, and left **nothing** in the log — the one place
    ``veaf-tools doctor`` looks. This hook writes the trace to the file sink first, then hands the
    exception to whatever hook was already installed, so the user sees exactly what they saw before.

    ``KeyboardInterrupt`` and ``SystemExit`` are passed straight through: a Ctrl-C is not a crash,
    and journalling it as one would fill the log with noise the reader has to skip.

    Idempotent — calling it twice does not chain the hook twice.

    Args:
        target: The logger to journal through. Defaults to the module-level one.

    Returns:
        The installed hook, so a test can call it directly rather than crashing a process.
    """
    if getattr(sys.excepthook, _EXCEPTHOOK_MARKER, False):
        return cast(ExceptHook, sys.excepthook)
    log = target if target is not None else logger
    previous: ExceptHook = cast(ExceptHook, sys.excepthook)

    def hook(
        exc_type: type[BaseException],
        exc_value: BaseException,
        exc_traceback: TracebackType | None,
    ) -> None:
        if not issubclass(exc_type, (KeyboardInterrupt, SystemExit)):
            log.logger.critical(f"{exc_type.__name__}: {exc_value}", exc_info=(exc_type, exc_value, exc_traceback))
        previous(exc_type, exc_value, exc_traceback)

    setattr(hook, _EXCEPTHOOK_MARKER, True)
    sys.excepthook = hook
    return hook


console: Console = Console()
logger: Logger = Logger(logger_name="veaf-tools", console=console)
