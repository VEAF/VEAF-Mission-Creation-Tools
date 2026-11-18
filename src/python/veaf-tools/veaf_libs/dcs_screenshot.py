"""DCS's own screenshot, asked through the bridge: the DCS window may stay behind other windows.

The screen grab of :mod:`veaf_libs.dcs_window_capture` needs the DCS window in front and uncovered, so
whoever shoots loses the computer for the whole run. The screenshot command DCS binds to a key,
``iCommandScreenShot`` (257), sent with ``LoSetCommand`` from the ``export`` state, writes the rendered
frame to ``Saved Games\\DCS\\Screenshots`` whatever window is in front (idea of David, measured on the
eight Open Training missions, 2026-11-17: 203 photos, DCS in the background).
"""

from __future__ import annotations

import os
from collections.abc import Callable
from pathlib import Path
from typing import Any

from PIL import Image

#: ``iCommandScreenShot``, as ``LoSetCommand`` takes it.
SCREENSHOT_COMMAND = 257
#: The ``export``-state chunk that asks DCS for a screenshot.
SCREENSHOT_LUA = f"LoSetCommand({SCREENSHOT_COMMAND}) return 'ok'"
#: Seconds between two looks at the screenshots folder.
POLL_SECONDS = 0.5
#: Seconds DCS gets to write the file before the grab gives up.
TIMEOUT_SECONDS = 30.0


class ScreenshotError(RuntimeError):
    """DCS wrote no screenshot."""


def default_screenshots_dir() -> Path:
    """Return ``%USERPROFILE%\\Saved Games\\DCS\\Screenshots``, where DCS writes its screenshots."""
    return Path(os.path.expanduser("~")) / "Saved Games" / "DCS" / "Screenshots"


def _pictures(folder: Path) -> dict[Path, int]:
    """The screenshots in *folder*, with their size in bytes."""
    if not folder.is_dir():
        return {}
    return {p: p.stat().st_size for p in folder.iterdir() if p.suffix.lower() in (".jpg", ".png")}


def grab_dcs_screenshot(
    run_export: Callable[[str], Any],
    folder: Path,
    sleep: Callable[[float], None],
    timeout: float = TIMEOUT_SECONDS,
) -> tuple[Image.Image, tuple[int, int]]:
    """Ask DCS for a screenshot, wait for the file, read it and delete it.

    Args:
        run_export: Runs a chunk in the ``export`` state.
        folder: Where DCS writes its screenshots.
        sleep: Waits, seconds.
        timeout: Seconds to wait for the file.

    Returns:
        The picture, RGB, and its size — the whole rendered frame, F11 bar included.

    Raises:
        ScreenshotError: No new file appeared, or it never stopped growing, within *timeout*.
    """
    before = set(_pictures(folder))
    run_export(SCREENSHOT_LUA)
    waited = 0.0
    sizes: dict[Path, int] = {}
    while waited < timeout:
        sleep(POLL_SECONDS)
        waited += POLL_SECONDS
        now = {p: s for p, s in _pictures(folder).items() if p not in before}
        # a file is written when its size stopped changing between two looks
        done = [p for p, s in now.items() if s > 0 and sizes.get(p) == s]
        if done:
            path = max(done, key=lambda p: p.stat().st_mtime)
            with Image.open(path) as picture:
                image = picture.convert("RGB")
            path.unlink()
            return image, image.size
        sizes = now
    raise ScreenshotError(f"DCS wrote no screenshot in {folder} within {timeout:.0f} s")
