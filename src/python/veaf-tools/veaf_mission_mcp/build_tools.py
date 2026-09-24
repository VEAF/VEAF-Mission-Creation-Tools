"""Close the authoring loop: validate a mission folder and build it into a playable `.miz` (wave 11).

`validate_mission` reuses the in-process pre-build linter; `build_mission` drives the real
`veaf-tools build` (its orchestration lives in the CLI command, and `scaffold_mission` has already
installed the binary in the folder). Together with scaffold/composites/placement, the MCP can now
go from an empty folder to a playable mission without leaving the assistant. See
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 11).
"""

import os
import subprocess
from pathlib import Path
from typing import Any

from veaf_libs import platform_assets
from veaf_tools.helpers import NO_PAUSE_ENV_VAR

#: Upper bound on a single ``veaf-tools build`` — generous (a full build with many presets is slow
#: on a fresh VM), but bounded so a stalled build surfaces as an error instead of a hung MCP call.
_BUILD_TIMEOUT = 900


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


def build_mission(folder_path: Path, profile: str | None = None) -> dict[str, Any]:
    """Build a mission folder into a playable `.miz` by driving ``veaf-tools build``.

    Runs the real build (its pipeline lives in the CLI command) in the folder — the binary
    ``scaffold_mission`` installed there, or ``veaf-tools`` on PATH.

    Args:
        folder_path: The mission folder to build.
        profile: A build profile (``LOCAL_TEST``, ``MODERN``…), passed as ``--profile``; the
            mission's own profiles when omitted.

    Returns:
        ``{folder, ok, message, log}`` on success — ``log`` is the build's whole output, where its
        warnings are; ``message`` keeps the last 1000 characters for older callers. The output used
        to be cut to those and decoded as cp1252 (« CrÃ©Ã© »), so the warnings the maker needed
        were gone (FIX-SCRATCH-MISSION-FINDINGS ticket 08).

    Raises:
        RuntimeError: when the build exits non-zero (message carries the build's stderr/stdout).
    """
    folder = Path(folder_path)
    cmd = [_veaf_tools_binary(folder), "build"]
    if profile:
        cmd += ["--profile", profile]
    # stdin is closed (DEVNULL) so the build never blocks forever on an interactive input()
    # inherited from the MCP server's stdio pipe — the JSON-RPC stdin never reaches EOF, so a
    # read there would hang indefinitely (the observed deadlock). The env flag suppresses any
    # exit pause, and timeout bounds a stalled build. Same fix as scaffold._run.
    try:
        result = subprocess.run(  # nosemgrep: python.lang.security.audit.dangerous-subprocess-use-audit
            cmd,
            cwd=str(folder),
            capture_output=True,
            text=True,
            # The exe writes UTF-8 whatever the console (measured 2026-09-24); decoding with the
            # locale's cp1252 is what produced « CrÃ©Ã© ».
            encoding="utf-8",
            errors="replace",
            stdin=subprocess.DEVNULL,
            timeout=_BUILD_TIMEOUT,
            env={**os.environ, NO_PAUSE_ENV_VAR: "1"},
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"build timed out after {_BUILD_TIMEOUT:.0f}s with no progress.") from exc
    if result.returncode != 0:
        raise RuntimeError(f"build failed (exit {result.returncode}): {(result.stderr or result.stdout).strip()}")
    log = (result.stdout or "").strip()
    return {"folder": str(folder), "ok": True, "message": log[-1000:], "log": log}
