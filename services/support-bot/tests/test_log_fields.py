"""Every ``extra=`` key in the package, checked against the names ``LogRecord`` already owns.

A structured log line is built by handing ``logging`` a mapping, and ``logging`` **raises** when one
of its keys is a field the record already has — ``thread``, ``module``, ``process``, ``message`` and
a dozen more. It is a ``KeyError`` at the call site, so the line that raises is usually the one
reporting something else going wrong, and in this service that means a relay round or an intake step
dying on its own log statement.

That is what happened: ``extra={"thread": thread_id}`` in the relay passed every test of its own
module — no handler is configured there, so nothing builds a record — and failed the moment the full
suite ran with logging set up. Which is to say: the shape of bug that reaches production.

So the list is **derived from the code** rather than sampled. This walks the package's syntax tree,
collects every literal key of every ``extra=`` mapping, and fails naming the file, the line and the
key. A new log line with a bad field fails here, whether or not anybody wrote a test for the branch
it sits in.
"""

from __future__ import annotations

import ast
import logging
import unittest
from pathlib import Path

#: The package under inspection.
PACKAGE = Path(__file__).resolve().parent.parent / "veaf_support_bot"


def reserved_names() -> frozenset[str]:
    """Return every attribute a fresh :class:`logging.LogRecord` already carries.

    Read off a real record rather than typed out from the documentation: the set has grown across
    Python versions — ``taskName`` arrived in 3.12 — and a hand-written list would be a second
    source of truth that silently falls behind the interpreter the service runs on.

    Returns:
        The reserved field names.
    """
    record = logging.LogRecord("n", logging.INFO, "p", 1, "m", None, None)
    # `message` and `asctime` are not attributes of a fresh record, but `Formatter` sets them while
    # rendering — passing either as an extra produces a line that lies about itself.
    return frozenset(vars(record)) | {"message", "asctime"}


def extra_keys() -> list[tuple[Path, int, str]]:
    """Collect every literal key passed as ``extra=`` in the package.

    Returns:
        One ``(file, line, key)`` per key found.
    """
    found: list[tuple[Path, int, str]] = []
    for path in sorted(PACKAGE.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            for keyword in node.keywords:
                if keyword.arg != "extra" or not isinstance(keyword.value, ast.Dict):
                    continue
                for key in keyword.value.keys:
                    if isinstance(key, ast.Constant) and isinstance(key.value, str):
                        found.append((path, key.lineno, key.value))
    return found


class TestNoLogFieldCollidesWithLogging(unittest.TestCase):
    def test_the_sweep_actually_found_the_log_lines(self) -> None:
        """Guards the guard: a walk that finds nothing would pass for ever."""
        keys = extra_keys()

        self.assertGreater(len(keys), 50, "the syntax walk found almost no log fields — it is broken")
        self.assertIn("event", {key for _, _, key in keys})

    def test_no_extra_overwrites_a_record_field(self) -> None:
        reserved = reserved_names()

        offenders = [
            f"{path.name}:{line} passes extra={{'{key}': ...}}, which LogRecord already owns"
            for path, line, key in extra_keys()
            if key in reserved
        ]

        self.assertEqual(offenders, [], "\n".join(offenders))

    def test_the_check_would_catch_one(self) -> None:
        """Proves the assertion above can fail — a detector nobody has seen fail proves nothing."""
        self.assertIn("thread", reserved_names())
        self.assertIn("module", reserved_names())


if __name__ == "__main__":
    unittest.main()
