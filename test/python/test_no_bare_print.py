"""The shipped package must not call `print()` — CLAUDE.md forbids it, and nothing checked.

`veaf_libs.logger` exists so output can be muted (the MCP server silences the console because stdout
carries its JSON-RPC stream) and routed to the log file. A bare `print()` bypasses both.

The rule was written down and never enforced, so it drifted: SECREV-2 / VMR-052 found one in the
extractor worker, and looking properly found a **second** one the finding did not mention. A rule with
no gate is a preference.

Parsed rather than grepped: a regex counts `print(` inside a comment, a docstring or a longer name
like `pprint(`, which is how a gate ends up either lying or ignored.
"""

from __future__ import annotations

import ast
import unittest
from pathlib import Path

_PACKAGE_ROOT = Path(__file__).parents[2] / "src" / "python" / "veaf-tools"

#: Third-party vendored library — not our code, and excluded from ruff and mypy for the same reason.
_EXCLUDED_PARTS = {"luadata"}

#: One deliberate exemption, named rather than pattern-matched so adding another is a visible choice.
#: `migrate_lazy_log.py` is a one-shot migration run by hand as `python -m veaf_libs.migrate_lazy_log`;
#: it is not wired to any CLI command, and its console output *is* the deliverable — it reports which
#: lines it could not migrate. SECREV-2 / VMR-115 reached the same conclusion about the same file.
_EXEMPT_FILES = {"migrate_lazy_log.py"}


def _python_files() -> list[Path]:
    return sorted(
        path
        for path in _PACKAGE_ROOT.rglob("*.py")
        if not _EXCLUDED_PARTS.intersection(path.parts)
        and "__pycache__" not in path.parts
        and path.name not in _EXEMPT_FILES
    )


def _print_calls(path: Path) -> list[int]:
    """Return the line numbers of every direct `print(...)` call in *path*."""
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    return [
        node.lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "print"
    ]


class TestNoBarePrintInTheShippedPackage(unittest.TestCase):
    def test_the_package_uses_the_logger_only(self) -> None:
        offenders = [
            f"{path.relative_to(_PACKAGE_ROOT).as_posix()}:{line}"
            for path in _python_files()
            for line in _print_calls(path)
        ]

        self.assertEqual(
            offenders,
            [],
            "print() bypasses veaf_libs.logger, which the MCP server relies on to keep stdout clean:\n  "
            + "\n  ".join(offenders),
        )

    def test_the_scan_actually_reaches_the_source(self) -> None:
        # Without this, an empty offender list could mean "nothing found" or "nothing looked at" —
        # the failure mode that let a coverage rule pass while extracting zero names.
        files = _python_files()
        self.assertGreater(len(files), 50, "the scan should see the whole package")
        self.assertTrue(
            any(path.name == "mission_extractor_worker.py" for path in files),
            "the file VMR-052 was found in must be in scope",
        )

    def test_the_detector_recognises_a_print_call(self) -> None:
        # Proving the gate can fail, on a file we write rather than on the tree we are policing.
        sample = Path(self.enterContext(__import__("tempfile").TemporaryDirectory())) / "sample.py"
        sample.write_text(
            "# print('in a comment')\n"
            '"""print(\'in a docstring\')"""\n'
            "import pprint\n"
            "pprint.pprint('not a bare print')\n"
            "print('this one counts')\n",
            encoding="utf-8",
        )

        self.assertEqual(_print_calls(sample), [5], "only the real call on line 5 may be reported")


if __name__ == "__main__":
    unittest.main()
