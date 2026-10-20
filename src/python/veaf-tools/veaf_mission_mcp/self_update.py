"""The MCP server keeps its own ``veaf-tools`` up to date (FEAT-AI-ZERO-SETUP).

The Claude Code plugin's start-up hook used to do it, for Claude Code only. The server does it now, for
every client: at start-up, at most once every 4 hours, it asks GitHub for the latest release and, when
it is newer, starts the updater in the background, in its own folder. The updater sets the running
``veaf-tools.exe`` aside and installs the new one, used from the client's next start.
"""

import os
import subprocess
from collections.abc import Callable
from datetime import datetime, timedelta
from pathlib import Path

from veaf_libs import platform_assets
from veaf_libs.update_checker import fetch_latest_version, is_newer
from veaf_tools.helpers import NO_PAUSE_ENV_VAR

THROTTLE = timedelta(hours=4)
CLAIM_PREFIX = "mcp-self-update."
#: A pre-release under test, pinned for the server and the missions it scaffolds: no self-update then.
PINNED_TAG_ENV_VAR = "VEAF_MCP_UPDATER_TAG"
PUBLISHED_LATEST_TAG = "published-latest"


def _launch_hidden(cmd: list[str], cwd: Path) -> None:
    """Start the updater in the background, in a hidden console.

    Hidden rather than console-less: the updater replaces itself through a ``cmd`` script it starts,
    which inherits the hidden console instead of opening a window over the user's conversation. It is
    what the plugin's ``Start-Process -WindowStyle Hidden`` did. Nothing reaches the server's stdout,
    which carries the MCP stream.

    Args:
        cmd: The updater and its arguments.
        cwd: The folder it installs into.
    """
    startupinfo = None
    creationflags = 0
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()  # type: ignore[attr-defined]
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW  # type: ignore[attr-defined]
        startupinfo.wShowWindow = 0  # SW_HIDE
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    subprocess.Popen(  # noqa: S603 — the updater sitting next to the running server, fixed arguments
        cmd,
        cwd=str(cwd),
        env={**os.environ, NO_PAUSE_ENV_VAR: "1"},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        startupinfo=startupinfo,
        creationflags=creationflags,
    )


def _claim_window(veaf_home: Path, now: datetime) -> bool:
    """Claim the check of the current 4-hour window, for this server only.

    Each window has its own claim file, created with an exclusive create: when two servers start
    together — Claude Desktop and Claude Code, two sessions — exactly one gets it, so a single
    updater runs in the folder. Claims of earlier windows are deleted.

    Args:
        veaf_home: Where the claim files are kept.
        now: The current time.

    Returns:
        True when this server holds the claim; False when another one already took this window. An
        unwritable folder counts as claimed: checking at every start beats never checking.
    """
    window = int(now.timestamp() // THROTTLE.total_seconds())
    claim = veaf_home / f"{CLAIM_PREFIX}{window}"
    try:
        veaf_home.mkdir(parents=True, exist_ok=True)
        claim.open("x").close()
    except FileExistsError:
        return False
    except OSError:
        return True
    for old in veaf_home.glob(f"{CLAIM_PREFIX}*"):
        if old != claim:
            old.unlink(missing_ok=True)
    return True


def start_update_if_due(
    current_version: str,
    exe: Path,
    veaf_home: Path,
    *,
    now: datetime | None = None,
    fetch_latest: Callable[[str], str] = fetch_latest_version,
    launch: Callable[[list[str], Path], None] = _launch_hidden,
) -> str:
    """Start the updater when a newer release exists, at most once per 4-hour window.

    The window is claimed before asking GitHub, so a PC offline asks once per window, not at every
    start.

    Args:
        current_version: The running version.
        exe: The running ``veaf-tools`` executable; the updater sits next to it.
        veaf_home: Where the window claims are kept.
        now: The current time (injected for tests).
        fetch_latest: Returns the latest release's version (injected for tests).
        launch: Starts the updater (injected for tests).

    Returns:
        What happened: `throttled`, `offline`, `up_to_date`, `no_updater` or `started`.
    """
    if not _claim_window(veaf_home, now or datetime.now()):
        return "throttled"
    try:
        latest = fetch_latest(current_version)
    except (OSError, ValueError):
        return "offline"
    if not is_newer(latest, current_version):
        return "up_to_date"
    updater = exe.parent / platform_assets.updater_binary_name()
    if not updater.is_file():
        return "no_updater"
    launch([str(updater), "--tag", PUBLISHED_LATEST_TAG], exe.parent)
    return "started"
