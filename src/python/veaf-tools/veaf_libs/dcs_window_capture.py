"""Grab the DCS window's picture, as the screen shows it.

Measured on 2026-10-28 while shooting "Marteau du Golan":

- ``ImageGrab.grab(all_screens=True)`` returns the DCS window **black** — it is a DirectX surface —
  while ``ImageGrab.grab()`` of the primary screen returns it as displayed. So DCS must sit on the
  primary screen, and the grab is cropped to the window's client area afterwards.
- Right after the camera moves, the first frames can still be black while the scenery loads; the
  grab is retried until the picture has some light in it.
- The process must be DPI-aware, or the client rectangle comes back scaled and the crop misses.

Windows only, and only meaningful with DCS on screen, hence no unit test: the geometry and the
retry decision are separated out (:func:`client_box`, :func:`is_black`) and those are tested.
"""

from __future__ import annotations

import sys
import time
from collections.abc import Callable

from PIL import Image

#: The title DCS gives its window.
DCS_WINDOW_TITLE = "Digital Combat Simulator"


class CaptureError(RuntimeError):
    """The DCS window could not be found or kept returning a black picture."""


def client_box(origin: tuple[int, int], size: tuple[int, int]) -> tuple[int, int, int, int]:
    """Return the crop box of a client area from its screen origin and size.

    Args:
        origin: Top-left corner of the client area, screen pixels.
        size: Width and height of the client area.

    Returns:
        ``(left, top, right, bottom)``.
    """
    return origin[0], origin[1], origin[0] + size[0], origin[1] + size[1]


def is_black(image: Image.Image) -> bool:
    """Tell whether a grab has no light in it at all.

    Args:
        image: The grab.

    Returns:
        True when every channel's maximum is 0.
    """
    extrema = image.getextrema()
    if isinstance(extrema[0], tuple):
        return all(high == 0 for _, high in extrema)  # type: ignore[misc]
    return extrema[1] == 0


def dcs_client_box() -> tuple[int, int, int, int]:  # pragma: no cover - needs the DCS window
    """Find the DCS window and return its client area on screen.

    Returns:
        ``(left, top, right, bottom)``.

    Raises:
        CaptureError: Not on Windows, or no DCS window.
    """
    if sys.platform != "win32":
        raise CaptureError("grabbing the DCS window works on Windows only")
    import ctypes  # noqa: PLC0415
    from ctypes import wintypes  # noqa: PLC0415

    user32 = ctypes.windll.user32
    user32.SetProcessDPIAware()
    hwnd = user32.FindWindowW(None, DCS_WINDOW_TITLE)
    if not hwnd:
        raise CaptureError(f"no window titled {DCS_WINDOW_TITLE!r}: is DCS running, not minimised?")
    rect = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    point = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(point))
    return client_box((point.x, point.y), (rect.right, rect.bottom))


def grab_dcs(
    retry: Callable[[], None],
    attempts: int = 8,
    pause: float = 2.0,
    ignore_bottom: int = 0,
) -> tuple[Image.Image, tuple[int, int]]:  # pragma: no cover - needs the DCS window
    """Grab the DCS client area from the primary screen, retrying while it is black.

    Args:
        retry: Called before each new attempt — the shooter puts the camera back, which also nudges
            DCS into drawing the frame.
        attempts: How many grabs before giving up.
        pause: Seconds between attempts.
        ignore_bottom: Pixels at the bottom left out of the blackness test — the F11 bar, whose text
            is drawn over a frame that is otherwise still black (measured: four shots of eleven came out
            entirely black once the bar was cut off).

    Returns:
        The grab and the client area's ``(width, height)``.

    Raises:
        CaptureError: Every attempt was black.
    """
    from PIL import ImageGrab  # noqa: PLC0415

    box = dcs_client_box()
    size = (box[2] - box[0], box[3] - box[1])
    for _ in range(attempts):
        image = ImageGrab.grab().crop(box)
        if not is_black(image.crop((0, 0, image.width, image.height - ignore_bottom))):
            return image, size
        time.sleep(pause)
        retry()
    raise CaptureError("the DCS window stays black: it must be on the primary screen, visible, and not covered")
