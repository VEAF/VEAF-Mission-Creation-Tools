"""Close the authoring loop: validate a mission folder and build it into a playable `.miz` (wave 11).

`validate_mission` reuses the in-process pre-build linter; `build_mission` drives the real
`veaf-tools build` (its orchestration lives in the CLI command, and `scaffold_mission` has already
installed the binary in the folder). Together with scaffold/composites/placement, the MCP can now
go from an empty folder to a playable mission without leaving the assistant. See
``.backlog/archive/FEAT-MCP-MISSION-EDITOR.md`` (wave 11).
"""

import json
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Any

from veaf_libs import platform_assets
from veaf_libs.bundled_data import read_bundled_text
from veaf_tools.helpers import NO_PAUSE_ENV_VAR

from veaf_mission_mcp.profile import is_compact

#: Upper bound on a single ``veaf-tools build`` — generous (a full build with many presets is slow
#: on a fresh VM), but bounded so a stalled build surfaces as an error instead of a hung MCP call.
_BUILD_TIMEOUT = 900

#: Where the build's raw output is kept, in the mission folder.
BUILD_LOG_NAME = "build.log"

#: A progress line, `✓ <step> terminé !` / `✓ Done <step>!`: twenty of them, with no line end, glued to
#: the message that follows them.
_PROGRESS_DONE = re.compile(r"✓ [^!\n]*!")


#: The build's step lines that say nothing a reader acts on — a file read, a file written, a YAML file
#: valid — by their message key: three builds of a local model's run carried 14 of them each
#: (MCP-CONTEXT-BUDGET, run 8). Recognised in either language from the shipped locales; a warning never
#: matches.
_STEP_LINE_KEYS = (
    "aircraft_injector.validating_yaml",
    "aircraft_injector.yaml_valid",
    "aircraft_injector.loading_yaml",
    "aircraft_injector.yaml_loaded",
    "aircraft_injector.reading_mission",
    "aircraft_injector.mission_loaded",
    "aircraft_injector.writing_mission",
    "aircraft_injector.mission_written",
    "group_injector.reading_mission",
    "group_injector.writing_mission",
    "waypoints_injector.reading_mission",
    "waypoints_injector.mission_loaded",
    "presets_injector.processing_groups",
    "weather.loading_config",
    "msg.work_done",
)
_RICH_TAG = re.compile(r"\[/?[a-zA-Z][^\]]*\]")
_step_lines: re.Pattern[str] | None = None


def _step_line_pattern() -> re.Pattern[str]:
    """Build, once, the pattern of the step lines from their French and English templates."""
    global _step_lines
    if _step_lines is None:
        templates: list[str] = []
        for language in ("fr", "en"):
            messages = json.loads(read_bundled_text("veaf_libs", "locales", f"{language}.json"))
            templates += [str(messages[key]) for key in _STEP_LINE_KEYS if key in messages]
        alternatives = []
        for template in templates:
            text = _RICH_TAG.sub("", template).strip()
            parts = re.split(r"\{[^}]*\}", text)
            alternatives.append(".*".join(re.escape(part) for part in parts))
        _step_lines = re.compile(r"^\s*(?:" + "|".join(alternatives) + r")\s*$")
    return _step_lines


def drop_step_lines(log: str) -> str:
    """Remove the build's step lines that carry nothing (a file read or written, a YAML file valid).

    Args:
        log: A compacted build log.

    Returns:
        The log without those lines; every warning and count is kept.
    """
    pattern = _step_line_pattern()
    return "\n".join(line for line in log.splitlines() if not pattern.match(line))


def compact_build_log(log: str, folder: Path) -> str:
    """Return a build's output without what tells nothing: progress lines and the folder's own path.

    A build's output was 14 004 characters returned whole, a fifth of a local model's context; two thirds
    of it were the folder's absolute path, written at every step, and the progress lines
    (MCP-CONTEXT-BUDGET). Every message is kept, its warnings included.

    Args:
        log: The build's output, written unwrapped (``COLUMNS`` wide).
        folder: The mission folder the build ran in.

    Returns:
        The output with paths relative to the folder, no progress line and no blank line.
    """
    text = _PROGRESS_DONE.sub("\n", log)
    for root in dict.fromkeys((str(folder.resolve()), str(folder))):
        text = text.replace(root + os.sep, "").replace(root, ".")
    return "\n".join(line.rstrip() for line in text.splitlines() if line.strip())


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
        ``{folder, ok, log, log_file, missions}`` on success — ``log`` is the build's output, every
        message and warning, through :func:`compact_build_log`; ``log_file`` the raw output, written in
        the folder. The output used to be cut to its last 1000 characters and decoded as cp1252
        (« CrÃ©Ã© »), so the warnings the maker needed were gone (FIX-SCRATCH-MISSION-FINDINGS ticket
        08). ``missions`` lists the ``.miz`` the build wrote in the folder: the night's, and its
        training versions when ``mission.yaml`` has a ``training:`` block.

    Raises:
        RuntimeError: when the build exits non-zero (message carries the build's stderr/stdout).
    """
    folder = Path(folder_path)
    started = time.time() - 1  # a second's slack for file systems that round modification times
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
            # COLUMNS: Rich wraps at 80 columns, cutting the folder's path in two where it cannot be
            # recognised and removed (MCP-CONTEXT-BUDGET).
            env={**os.environ, NO_PAUSE_ENV_VAR: "1", "COLUMNS": "4000"},
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"build timed out after {_BUILD_TIMEOUT:.0f}s with no progress.") from exc
    if result.returncode != 0:
        raise RuntimeError(f"build failed (exit {result.returncode}): {(result.stderr or result.stdout).strip()}")
    log = (result.stdout or "").strip()
    log_file = folder / BUILD_LOG_NAME
    log_file.write_text(log + "\n", encoding="utf-8")
    # Which .miz this build wrote: a training: block makes it five (FEAT-ROLE-TRAINING-VARIANTS).
    missions = sorted(str(p) for p in folder.glob("*.miz") if p.stat().st_mtime >= started)
    return {
        "folder": str(folder),
        "ok": True,
        "log": drop_step_lines(compact_build_log(log, folder)) if is_compact() else compact_build_log(log, folder),
        "log_file": str(log_file),
        "missions": missions,
    }
