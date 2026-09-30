"""FIX-SECURED-FORALL-AND-UPDATER-BAT ticket 02 — the deferred update script and the mission path.

The updater replaces its own executable through a batch file run after it exits. That file used to
start with `cd /d "<mission folder>"`, written by `Path.write_text()` in the ANSI code page (cp1252 on
a French Windows), while cmd reads a batch file in the console code page (cp850): an accented mission
folder made the `cd` fail and the update abort. Measured 2026-09-29: `Mission élève Nörvenich` failed
in cp1252; `oem` fixed it but could not even encode `Misja Łódź`.

The script now names no path at all — `cd /d "%~dp0.."` lets cmd resolve its own location — so it is
pure ASCII and no code page can garble it.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import types
from pathlib import Path
from unittest import mock

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_UPDATER_PATH = _REPO_ROOT / "src" / "python" / "veaf-tools" / "veaf-tools-updater.py"


@pytest.fixture(scope="module")
def updater_mod() -> types.ModuleType:
    """Load the hyphenated updater script as an importable module."""
    spec = importlib.util.spec_from_file_location("veaf_tools_updater_batch_mod", _UPDATER_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mission_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """An accented mission folder, including a letter cp850 cannot encode, as the working directory."""
    folder = tmp_path / "Mission élève Łódź"
    folder.mkdir()
    monkeypatch.chdir(folder)
    return folder


def _generate_script(updater_mod: types.ModuleType, mission_folder: Path) -> tuple[Path, mock.MagicMock]:
    """Run `_launch_deferred_update` with the launch mocked out, and return the script it wrote."""
    pending_dir = mission_folder / updater_mod.UPDATE_PENDING_DIR
    pending_dir.mkdir()
    worker = updater_mod.UpdateWorker(mission_folder=str(mission_folder))
    with mock.patch.object(updater_mod.subprocess, "Popen") as popen:
        worker._launch_deferred_update(pending_dir, pending_dir / f"{updater_mod.VEAF_TOOLS_EXE}.new")
    return pending_dir / "apply-update.cmd", popen


def test_the_script_is_written_and_launched(updater_mod: types.ModuleType, mission_folder: Path) -> None:
    # The method swallows any exception into a warning, so "launched" is what proves it was written.
    script, popen = _generate_script(updater_mod, mission_folder)

    assert script.is_file()
    popen.assert_called_once()


def test_the_script_is_ascii_and_names_no_path(updater_mod: types.ModuleType, mission_folder: Path) -> None:
    script, _ = _generate_script(updater_mod, mission_folder)
    content = script.read_bytes().decode("ascii")  # raises if anything non-ASCII slipped in

    assert 'cd /d "%~dp0.."' in content
    assert mission_folder.name not in content


def test_delayed_expansion_starts_after_the_cd(updater_mod: types.ModuleType, mission_folder: Path) -> None:
    # Delayed expansion rewrites a "!" in a path; enabled before the cd, it made the cd fail.
    content = _generate_script(updater_mod, mission_folder)[0].read_text(encoding="ascii")

    assert content.index('cd /d "%~dp0.."') < content.index("setlocal enabledelayedexpansion")


@pytest.mark.skipif(os.name != "nt", reason="runs the batch file with cmd.exe")
def test_cmd_enters_the_accented_mission_folder(
    updater_mod: types.ModuleType, mission_folder: Path, tmp_path: Path
) -> None:
    script, _ = _generate_script(updater_mod, mission_folder)

    # Started from elsewhere, so only the script's own `cd` can put it in the mission folder. Its last
    # step removes `.\.veaf-update-pending`, relative to where it stands; a failed cd exits before it.
    # The exit code says nothing: that step deletes the script's own folder, and cmd then fails to read
    # the next line ("The system cannot find the path specified", exit 1) -- harmless in production,
    # where the script runs detached with its output discarded.
    result = subprocess.run(str(script), shell=True, cwd=str(tmp_path), capture_output=True, timeout=60)

    assert b"ERROR" not in result.stdout, result.stdout
    assert not (mission_folder / updater_mod.UPDATE_PENDING_DIR).exists()
