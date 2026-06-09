"""Single transient status line at the bottom of the console.

This module provides :class:`StatusLine`, a thin wrapper around a Rich
``Live`` region that shows *one* in-place line for low-importance progress
messages.  When enabled, successive messages overwrite the same line instead
of scrolling, which keeps the console output readable.  Permanent lines
printed through the same console (technical lines, chapter headers, warnings,
errors) appear *above* the live region and stay on screen.

When disabled — for example under ``--verbose`` or when stdout is not an
interactive terminal — the status line is inert: callers fall back to normal
scrolling output.

The module deliberately imports nothing from :mod:`veaf_libs.logger` or
:mod:`veaf_libs.progress` to avoid circular imports; it is a low-level
building block those modules depend on.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

from rich.console import Console
from rich.highlighter import ReprHighlighter
from rich.live import Live
from rich.text import Text

_highlighter = ReprHighlighter()


class StatusLine:
    """A single, overwriting status line backed by a Rich ``Live`` region.

    Attributes:
        enabled: When ``True``, :meth:`update` renders messages transiently on
            one line.  When ``False``, :meth:`update` is a no-op and returns
            ``False`` so the caller can print the message permanently instead.
    """

    def __init__(self, console: Console) -> None:
        """Initialise the status line.

        Args:
            console: The Rich console to render the live region on.  Must be the
                same console used for permanent output so that permanent lines
                appear above the live region.
        """
        self._console = console
        self._live: Live | None = None
        self._enabled = False
        self._suspended = False
        self._text = ""

    @property
    def enabled(self) -> bool:
        """Return whether transient rendering is active."""
        return self._enabled

    def configure(self, *, enabled: bool) -> None:
        """Enable or disable transient rendering.

        Disabling stops any active live region so subsequent output scrolls
        normally.

        Args:
            enabled: ``True`` to render messages on a single overwriting line.
        """
        if not enabled:
            self.stop()
        self._enabled = enabled

    def update(self, message: str, style: str = "cyan") -> bool:
        """Show ``message`` on the transient line.

        Args:
            message: The text to display.  Long messages are truncated with an
                ellipsis so the line never wraps.
            style: Rich style applied to the message.

        Returns:
            ``True`` if the message was rendered transiently; ``False`` when
            transient rendering is disabled and the caller should print the
            message permanently instead.
        """
        if not self._enabled:
            return False
        if self._suspended:
            # A nested Live (spinner or progress bar) currently owns the
            # display — Rich allows only one at a time. The message is still
            # written to the log file by the caller; skip the transient render
            # rather than starting a competing Live.
            return True
        self._text = message
        self._ensure_live()
        assert self._live is not None
        self._live.update(self._render(message, style))
        return True

    def clear(self) -> None:
        """Blank the transient line without stopping the live region."""
        self._text = ""
        if self._live is not None:
            self._live.update(Text(""))

    def stop(self) -> None:
        """Stop and remove the transient line.

        Safe to call when no live region is active.  Call once at program end
        so the last transient message does not linger on screen.
        """
        if self._live is not None:
            self._live.stop()
            self._live = None
        self._text = ""

    @contextmanager
    def suspend(self) -> Iterator[None]:
        """Temporarily stop the live region for another ``Live`` display.

        Rich allows only one live display at a time, so any code that creates
        its own ``Live`` (spinners, progress bars) must run inside this context
        when a status line might be active.  The live region is not restarted
        on exit; the next :meth:`update` re-creates it.

        Yields:
            ``None``.
        """
        self.stop()
        self._suspended = True
        try:
            yield
        finally:
            self._suspended = False

    def _render(self, message: str, style: str) -> Text:
        """Build the renderable for ``message`` (indented, non-wrapping).

        ``message`` may contain Rich console markup (e.g. ``[bold]x[/bold]``),
        which is interpreted just as ``console.print`` would; ``style`` is the
        base style applied to unmarked text.
        """
        text = Text("  ") + Text.from_markup(message, style=style)
        text.no_wrap = True
        text.overflow = "ellipsis"
        _highlighter.highlight(text)
        return text

    def _ensure_live(self) -> None:
        """Create and start the live region on first use."""
        if self._live is None:
            self._live = Live(
                Text(""),
                console=self._console,
                refresh_per_second=12.5,
                transient=True,
            )
            self._live.start()
