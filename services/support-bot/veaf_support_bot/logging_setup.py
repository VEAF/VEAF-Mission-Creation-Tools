"""Structured logging for the service.

The project rule is *never* :func:`print`, always the logger — and that rule is what this module
implements for a long-running process. It deliberately does **not** import
``veaf_libs.logger``, for two measurable reasons:

* ``veaf_libs.logger.Logger.error`` raises ``typer.Abort`` — it is a CLI abort, not a log call. A
  daemon that logged its first handled error would die on it.
* it writes to a file under ``VEAF_HOME`` and prints through Rich. A containerised service is read
  through its stdout, which a supervisor collects; a log file inside a container is a log nobody
  reads.

What is kept is the convention: one logger tree, levels used for what they mean, and no bare
``print``. Every record carries an ``event`` key so the lines can be filtered by machine rather than
grepped by prose.
"""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any, Final, TextIO

#: Root of the service's logger tree. Every module logger hangs off it.
ROOT_LOGGER_NAME: Final = "veaf-support-bot"

#: Attributes :class:`logging.LogRecord` sets itself. Anything else on a record came from the
#: caller's ``extra=`` and belongs in the structured payload.
_RESERVED: Final = frozenset(
    set(logging.LogRecord("", 0, "", 0, "", (), None).__dict__) | {"message", "asctime", "taskName"}
)


class JsonLineFormatter(logging.Formatter):
    """Render one log record as a single JSON object on one line."""

    def format(self, record: logging.LogRecord) -> str:
        """Return the record as a compact JSON line.

        Args:
            record: The record to render.

        Returns:
            A JSON object holding the timestamp, level, logger name, message, every ``extra`` field
            the caller passed, and the formatted traceback when there is one.
        """
        payload: dict[str, Any] = {
            "ts": datetime.fromtimestamp(record.created, tz=UTC).isoformat(timespec="milliseconds"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for key, value in record.__dict__.items():
            if key not in _RESERVED and not key.startswith("_"):
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        # default=str so an unexpected object in an `extra` degrades to its repr instead of killing
        # the log line — losing a log line is exactly how a silent death stays silent.
        return json.dumps(payload, ensure_ascii=False, default=str)


class TextLineFormatter(logging.Formatter):
    """Human-readable rendering, for a local run in a terminal."""

    def __init__(self) -> None:
        """Initialize the formatter with the service's line layout."""
        super().__init__(fmt="%(asctime)s %(levelname)-8s %(name)s %(message)s")

    def format(self, record: logging.LogRecord) -> str:
        """Return the record as a readable line with its structured fields appended.

        Args:
            record: The record to render.

        Returns:
            The formatted line, followed by ``key=value`` pairs for every ``extra`` field.
        """
        line = super().format(record)
        extras = {
            key: value for key, value in record.__dict__.items() if key not in _RESERVED and not key.startswith("_")
        }
        if extras:
            line += " " + " ".join(f"{key}={value}" for key, value in sorted(extras.items()))
        return line


def build_formatter(log_format: str) -> logging.Formatter:
    """Return the formatter matching a configured log format.

    Args:
        log_format: ``"json"`` or ``"text"``.

    Returns:
        The corresponding formatter; ``json`` for any unknown value, because production is the
        default a mistake should fall back to.
    """
    return TextLineFormatter() if log_format == "text" else JsonLineFormatter()


def configure_logging(level: str = "INFO", log_format: str = "json", stream: TextIO | None = None) -> logging.Logger:
    """Configure the service's logger tree.

    Idempotent: calling it twice replaces the handler rather than adding a second one, so a
    reconfiguration never doubles every line.

    Args:
        level: Level name (``INFO``, ``DEBUG``, …).
        log_format: ``"json"`` or ``"text"``.
        stream: Destination stream; defaults to ``sys.stdout`` — the one place a container
            supervisor looks.

    Returns:
        The configured root logger of the service tree.
    """
    logger = logging.getLogger(ROOT_LOGGER_NAME)
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
        handler.close()

    handler = logging.StreamHandler(stream if stream is not None else sys.stdout)
    handler.setFormatter(build_formatter(log_format))
    logger.addHandler(handler)
    logger.setLevel(level.upper())
    # The service owns its output: no bubbling up to a root logger someone else may have configured.
    logger.propagate = False
    return logger


def get_logger(name: str) -> logging.Logger:
    """Return a module logger under the service's tree.

    Args:
        name: Short module name, e.g. ``"health"``.

    Returns:
        The ``veaf-support-bot.<name>`` logger.
    """
    return logging.getLogger(f"{ROOT_LOGGER_NAME}.{name}")
