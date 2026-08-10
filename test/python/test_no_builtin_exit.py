"""CLI commands must raise `typer.Exit`, never call the `exit()` builtin (SECREV-2 / VMR-065).

`exit()` is not part of the language: it is installed by the `site` module, which is why it is absent
under `python -S` and cannot be relied on in a frozen executable — and veaf-tools ships as a
PyInstaller exe. It also bypasses Typer, which is what turns a command's exit into a clean result.

`typer.Exit` was already the idiom in this very directory (`ask.py`, `capture_map.py`, `prepare.py`
all use it), so the eight remaining `exit()` calls were leftovers. The finding named one of them.

Same approach as `test_no_bare_print.py`: parse, do not grep.
"""

from __future__ import annotations

import ast
import unittest
from pathlib import Path

_COMMANDS = Path(__file__).parents[2] / "src" / "python" / "veaf-tools" / "veaf_tools" / "commands"


def _builtin_exit_calls(path: Path) -> list[int]:
    """Return the line numbers of every bare `exit(...)` call in *path*.

    A qualified call such as `sys.exit()` is an `ast.Attribute`, not an `ast.Name`, so it is not
    reported — this is about the `site`-provided builtin only.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    return [
        node.lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in {"exit", "quit"}
    ]


class TestCommandsRaiseTyperExit(unittest.TestCase):
    def test_no_command_calls_the_builtin(self) -> None:
        offenders = [
            f"{path.name}:{line}" for path in sorted(_COMMANDS.glob("*.py")) for line in _builtin_exit_calls(path)
        ]

        self.assertEqual(
            offenders,
            [],
            "use `raise typer.Exit()`: exit() comes from the site module and is not guaranteed in a "
            "frozen exe:\n  " + "\n  ".join(offenders),
        )

    def test_the_scan_reaches_the_commands(self) -> None:
        # An empty offender list must mean "none found", not "nothing looked at".
        files = sorted(_COMMANDS.glob("*.py"))
        self.assertGreater(len(files), 10, "the scan should see the command modules")
        self.assertTrue(any(path.name == "build.py" for path in files))

    def test_the_detector_ignores_a_qualified_sys_exit(self) -> None:
        sample = Path(self.enterContext(__import__("tempfile").TemporaryDirectory())) / "sample.py"
        sample.write_text("import sys\nsys.exit(1)\nexit()\n", encoding="utf-8")

        self.assertEqual(_builtin_exit_calls(sample), [3], "only the bare call on line 3 counts")


if __name__ == "__main__":
    unittest.main()
