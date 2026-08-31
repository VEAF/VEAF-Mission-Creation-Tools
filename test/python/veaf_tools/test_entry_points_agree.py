"""The two entry points must expose the same commands — FIX-EXE-COMMAND-TREE ticket 01.

`veaf-tools` ships two ways: the `veaf-tools` console script (`veaf_tools.app:main`, what a
developer runs through Poetry) and `src/python/veaf-tools/veaf-tools.py`, the script
PyInstaller reads to build the executable **every mission maker** actually has. The second
used to be a hand-copied twin of the first, and it fell behind: `main()` gained
`build_cli_tree(app)` in 6.14.0 and the copy never did, so the themed tree that
`doc/CLI_REFERENCE` documents (`content extract-aircraft-groups`, …) worked from a checkout
and did not exist in the executable. Nothing broke loudly because the flat names survive as
hidden aliases.

So this compares the **whole command set**, not the presence of one group: a test asserting
`content` exists would go green again the day a sixth group is added to one side only, which
is precisely the failure being guarded. Each entry point is walked in its own subprocess —
`build_cli_tree` mutates the shared `app` in place, so two dumps in one process would not be
independent — with `Typer.__call__` swapped for a dump, so the CLI is built exactly as the
entry point builds it but never parses an argument or runs a command.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[3]
_SRC_DIR = _REPO_ROOT / "src" / "python" / "veaf-tools"
_FROZEN_ENTRY = _SRC_DIR / "veaf-tools.py"

_MARKER = "VEAF_COMMAND_PATHS "

#: Runs one entry point up to the moment it would hand control to Typer, then prints the full
#: command tree it built instead of executing it. Kept as a script because the point is to
#: exercise the real entry points, in a fresh interpreter, the way the shipped ones start.
_DUMPER = r'''
import json
import os
import runpy
import sys

import typer
import typer.main

MARKER = "VEAF_COMMAND_PATHS "


def _paths(command, prefix=()):
    """Every invokable command path under `command`, hidden aliases included.

    A group is recognised by holding sub-commands rather than by its class: under Click 8.3
    `TyperGroup` no longer derives from `click.Group`, so an isinstance check silently
    reported a tree of one nameless command.
    """
    children = getattr(command, "commands", None)
    if children:
        found = set()
        for name, sub in children.items():
            found |= _paths(sub, (*prefix, name))
        return found
    return {" ".join(prefix)}


def _dump_instead_of_running(self, *args, **kwargs):
    paths = sorted(_paths(typer.main.get_command(self)))
    sys.stdout.write(MARKER + json.dumps(paths) + "\n")
    raise SystemExit(0)


typer.Typer.__call__ = _dump_instead_of_running

target = os.environ["VEAF_ENTRY_POINT"]
# A command line with nothing to bridge to the wizard and nothing to run.
sys.argv = ["veaf-tools", "--help"]

if target == "console-script":
    from veaf_tools.app import main

    main()
else:
    # The frozen entry script, started the way the executable starts it.
    runpy.run_path(target, run_name="__main__")
'''


class TestEntryPointsAgree(unittest.TestCase):
    """Neither entry point can gain or lose a command without the other."""

    _tmp: tempfile.TemporaryDirectory[str]
    _dumper: Path
    _paths: dict[str, list[str]]

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        cls._dumper = Path(cls._tmp.name) / "dump_command_paths.py"
        cls._dumper.write_text(_DUMPER, encoding="utf-8")
        cls._paths = {}

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def _command_paths(self, entry: str) -> list[str]:
        """Return every command path one entry point exposes, sorted.

        Args:
            entry: ``"console-script"`` or the path to the frozen entry script.

        Returns:
            The command paths, e.g. ``["about", "build", "mission build", …]``.
        """
        if entry in self._paths:
            return self._paths[entry]

        env = os.environ.copy()
        env["VEAF_ENTRY_POINT"] = entry
        env["VEAF_UPDATER_NO_PAUSE"] = "1"  # never block on the double-click exit pause
        env["VEAF_LANG"] = "en"
        env["PYTHONIOENCODING"] = "utf-8"
        env["PYTHONPATH"] = os.pathsep.join([str(_SRC_DIR), env.get("PYTHONPATH", "")]).rstrip(os.pathsep)

        result = subprocess.run(
            [sys.executable, str(self._dumper)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=str(_REPO_ROOT),
            env=env,
            timeout=300,
            check=False,
        )
        line = next((ln for ln in result.stdout.splitlines() if ln.startswith(_MARKER)), None)
        self.assertIsNotNone(
            line,
            f"'{entry}' printed no command tree (exit {result.returncode})\n"
            f"--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}",
        )
        assert line is not None  # narrowed by the assertion above, for mypy
        paths = json.loads(line[len(_MARKER) :])
        self.assertGreater(len(paths), 20, f"'{entry}' exposed only {paths} — the dump is not measuring anything")
        self._paths[entry] = paths
        return paths

    def test_both_entry_points_expose_the_same_commands(self) -> None:
        """The defect itself: a divergence between the two, whatever its shape."""
        console = set(self._command_paths("console-script"))
        frozen = set(self._command_paths(str(_FROZEN_ENTRY)))

        missing_from_exe = sorted(console - frozen)
        extra_in_exe = sorted(frozen - console)
        self.assertEqual(
            (missing_from_exe, extra_in_exe),
            ([], []),
            "the two entry points disagree — the executable is not the CLI the documentation describes.\n"
            f"only `poetry run veaf-tools` has: {missing_from_exe}\n"
            f"only the executable has: {extra_in_exe}",
        )

    def test_the_executable_exposes_the_themed_tree(self) -> None:
        """The reported symptom, asserted in its own right so a failure names it."""
        frozen = set(self._command_paths(str(_FROZEN_ENTRY)))
        self.assertIn("content extract-aircraft-groups", frozen)
        self.assertIn("mission build", frozen)
        self.assertIn("convert v5", frozen, "the group drops its own word: `convert v5`, not `convert convert-v5`")

    def test_the_flat_names_still_work_from_both(self) -> None:
        """Every forum post, script and doc page that predates the tree keeps working."""
        for entry in ("console-script", str(_FROZEN_ENTRY)):
            paths = set(self._command_paths(entry))
            for flat in ("build", "extract-aircraft-groups", "convert-v5"):
                self.assertIn(flat, paths, f"'{flat}' no longer resolves from {entry}")


if __name__ == "__main__":
    unittest.main()
