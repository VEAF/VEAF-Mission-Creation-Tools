"""Importing the config migrator must not drag the cockpit-checklist model in (#725, ticket 05).

Reported by Sharko as a side note worth more than the bug itself: since 6.14.0, anything importing
`ConfigMigrator` outside the packaged environment needs **pydantic**, where `typer` + `pyyaml` used
to be enough. That is what an outside measurement harness — the very thing holding us honest on
this lot — has to install to keep running.

The chain was one hop deeper than the report said: `config_migrator` imports
`lua_config_generator`, which imports `checklists`, which imports pydantic. The migrator needed
exactly one symbol from that module, so the symbol moved rather than the dependency staying.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

_PKG_ROOT = Path(__file__).resolve().parents[3] / "src" / "python" / "veaf-tools"

_PROBE = (
    "import sys;"
    "from mission_builder.config_migrator import ConfigMigrator;"
    "sys.exit(1 if 'pydantic' in sys.modules else 0)"
)


def test_importing_the_migrator_does_not_load_pydantic() -> None:
    # A fresh interpreter, deliberately: run in-process, this passes for the wrong reason as soon
    # as any other test has already imported pydantic, and would pin nothing at all.
    completed = subprocess.run(
        [sys.executable, "-c", _PROBE],
        cwd=_PKG_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert completed.returncode == 0, (
        f"importing ConfigMigrator loaded pydantic (exit {completed.returncode}).\n{completed.stderr}"
    )
