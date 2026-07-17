"""Close the authoring loop: validate a mission folder and build it into a playable `.miz` (wave 11).

`validate_mission` reuses the in-process pre-build linter; `build_mission` drives the real
`veaf-tools build` (its orchestration lives in the CLI command, and `scaffold_mission` has already
installed the binary in the folder). Together with scaffold/composites/placement, the MCP can now
go from an empty folder to a playable mission without leaving the assistant. See
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 11).
"""

import subprocess
from pathlib import Path
from typing import Any

from veaf_libs import platform_assets


def validate_mission(folder_path: Path) -> dict[str, Any]:
    """Lint a mission folder before build, in-process.

    Args:
        folder_path: The mission folder (holds `mission.yaml` + `src/mission/`).

    Returns:
        ``{folder, ok, errors: [msg], warnings: [msg]}`` — ``ok`` is ``True`` when there are no
        error-level issues.
    """
    from veaf_libs.mission_validator import ERROR, WARNING, validate_mission_folder

    issues = validate_mission_folder(folder_path)
    errors = [issue.message for issue in issues if issue.level == ERROR]
    warnings = [issue.message for issue in issues if issue.level == WARNING]
    return {"folder": str(folder_path), "ok": not errors, "errors": errors, "warnings": warnings}


def _veaf_tools_binary(folder: Path) -> str:
    """Resolve the veaf-tools binary: the folder's installed one, else the name on PATH."""
    installed = folder / platform_assets.veaf_tools_binary_name()
    return str(installed) if installed.exists() else platform_assets.veaf_tools_binary_name()


def build_mission(folder_path: Path) -> dict[str, Any]:
    """Build a mission folder into a playable `.miz` by driving ``veaf-tools build``.

    Runs the real build (its pipeline lives in the CLI command) in the folder — the binary
    ``scaffold_mission`` installed there, or ``veaf-tools`` on PATH.

    Args:
        folder_path: The mission folder to build.

    Returns:
        ``{folder, ok, message}`` on success.

    Raises:
        RuntimeError: when the build exits non-zero (message carries the build's stderr/stdout).
    """
    folder = Path(folder_path)
    cmd = [_veaf_tools_binary(folder), "build"]
    result = subprocess.run(  # nosemgrep: python.lang.security.audit.dangerous-subprocess-use-audit
        cmd, cwd=str(folder), capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"build failed (exit {result.returncode}): {(result.stderr or result.stdout).strip()}")
    return {"folder": str(folder), "ok": True, "message": (result.stdout or "").strip()[-1000:]}
