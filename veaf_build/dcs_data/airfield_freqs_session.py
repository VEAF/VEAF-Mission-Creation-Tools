"""The guided capture of airfield frequencies: one blank mission per theatre, the user loads it, we read.

``veaf-build update-dcs-data --airfield-freqs --capture`` drives the same journey as
``veaf-tools dcs clear-ground-sweep``: write the mission to load, tell the user what to do in DCS,
wait until DCS has that map loaded, capture, say what comes next — and at the end, that DCS can be
closed. The steps live here, the transport and the messages in the CLI, so a test can run the whole
journey against a fake DCS.

The transport is the fiddle hook's own (GUI) environment, not ``dcs-serve``: the terrain module
(``Terrain.GetTerrainConfig``) and ``DCS.getATCradiosData`` the Mission Editor reads live there, and
the mission scripting environment the bridge runs in has neither.
"""

from __future__ import annotations

import time
import zipfile
from collections.abc import Callable
from pathlib import Path
from typing import Any

from veaf_libs.blank_mission import (  # type: ignore[import-not-found]
    canonical_theatre_name,
    generate_blank_mission,
    is_theatre_supported,
)
from veaf_libs.dcs_fiddle_client import FiddleAuthError  # type: ignore[import-not-found]

from veaf_build.dcs_data import airfield_freqs as A

#: Runs in the hook's environment; ``none`` until a mission is loaded.
THEATRE_LUA = (
    "local ok, m = pcall(function() return DCS.getCurrentMission() end) "
    "if ok and m and m.mission and m.mission.theatre then return m.mission.theatre end return 'none'"
)

LuaExec = Callable[[str], Any]


def installed_theatres(dcs_path: Path) -> tuple[list[str], list[str]]:
    """Return the theatres installed in a DCS, by the name missions use.

    A terrain the blank-mission table does not know (a third-party map, one released after these
    tools) cannot get a mission to load, so it is set aside rather than failing the session halfway.

    Args:
        dcs_path: The DCS install.

    Returns:
        The capturable runtime names (``GermanyCW``, not the ``GermanyColdWar`` folder) of every terrain
        carrying a ``Radio.lua``, and the folders set aside; both sorted.
    """
    terrains = dcs_path / "Mods" / "terrains"
    if not terrains.is_dir():
        return [], []
    folders = sorted(p.name for p in terrains.iterdir() if (p / "Radio.lua").is_file())
    supported = sorted(canonical_theatre_name(f) for f in folders if is_theatre_supported(f))
    return supported, [f for f in folders if not is_theatre_supported(f)]


def theatres_to_capture(installed: list[str], requested: list[str], dumps_dir: Path = A.DUMPS_DIR) -> list[str]:
    """Choose the theatres this session captures.

    Args:
        installed: Output of :func:`installed_theatres`.
        requested: Theatres named by the user; empty means "every installed one not captured yet".
        dumps_dir: Where the committed captures are.

    Returns:
        The theatres, in order.

    Raises:
        ValueError: A requested theatre is not installed.
    """
    if requested:
        wanted = [canonical_theatre_name(t) for t in requested]
        missing = [t for t in wanted if t not in installed]
        if missing:
            raise ValueError(f"not installed in this DCS: {', '.join(missing)} (installed: {', '.join(installed)})")
        return wanted
    done = {p.stem for p in dumps_dir.glob("*.json")}
    return [t for t in installed if t not in done]


def write_capture_mission(theatre: str, missions_dir: Path) -> Path:
    """Write the empty mission to load for *theatre*.

    Args:
        theatre: Runtime theatre name.
        missions_dir: Where to write it — the DCS ``Missions`` folder, so the user finds it.

    Returns:
        The written ``.miz``.
    """
    missions_dir.mkdir(parents=True, exist_ok=True)
    path = missions_dir / f"veaf-capture-frequencies-{theatre}.miz"
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for member, content in generate_blank_mission(theatre).items():
            archive.writestr(member, content)
    return path


def wait_for_theatre(
    exec_lua: LuaExec,
    theatre: str,
    wait_seconds: float,
    *,
    on_other: Callable[[str], None] = lambda _t: None,
    poll_seconds: float = 3.0,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Wait until DCS has a mission loaded on *theatre*.

    An unreachable hook (DCS still starting, or at the main menu) and another map are both waited
    through: the user may be on the way. *on_other* is told once per other map seen.

    Args:
        exec_lua: The transport; raises on an unreachable hook.
        theatre: Runtime theatre name to wait for.
        wait_seconds: How long to wait.
        on_other: Called with the name of a map that is loaded but is not *theatre*.
        poll_seconds: Delay between two attempts.
        clock: Monotonic clock (injected by tests).
        sleep: Sleep function (injected by tests).

    Raises:
        TimeoutError: *theatre* was not loaded within *wait_seconds*; the message says what was seen.
    """
    deadline = clock() + wait_seconds
    last = "no answer from the hook"
    seen: set[str] = set()
    while True:
        try:
            current = str(exec_lua(THEATRE_LUA))
            if current == theatre:
                return
            last = "no mission loaded" if current == "none" else f"a mission on {current}"
            if current != "none" and current not in seen:
                seen.add(current)
                on_other(current)
        except FiddleAuthError:
            raise  # refused credentials stay refused: waiting would only hide the reason
        except RuntimeError as exc:
            last = str(exc)
        if clock() >= deadline:
            raise TimeoutError(f"{theatre} was not loaded within {wait_seconds:.0f} s (last seen: {last})")
        sleep(poll_seconds)


def capture_theatre(
    exec_lua: LuaExec, theatre: str, dcs_path: Path, dumps_dir: Path = A.DUMPS_DIR
) -> tuple[Path, list[dict[str, Any]], dict[int, str]]:
    """Capture the loaded theatre and write its dump.

    Args:
        exec_lua: The transport.
        theatre: The theatre expected to be loaded.
        dcs_path: The DCS install, for ``Beacons.lua``.
        dumps_dir: Where to write the dump.

    Returns:
        The dump path, the airdrome records and the TACAN channels.

    Raises:
        ValueError: The capture failed, or DCS answered for another theatre.
    """
    captured, records = A.parse_capture(exec_lua(A.CAPTURE_LUA))
    if captured != theatre:
        raise ValueError(f"DCS has {captured} loaded, not {theatre}")
    beacons = dcs_path / "Mods" / "terrains" / A.terrain_folder(theatre) / "Beacons.lua"
    tacans = A.parse_tacans(beacons.read_text(encoding="utf-8", errors="ignore")) if beacons.is_file() else {}
    return A.write_dump(theatre, records, tacans, dumps_dir), records, tacans
