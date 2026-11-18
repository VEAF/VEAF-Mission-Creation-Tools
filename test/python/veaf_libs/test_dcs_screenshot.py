"""DCS's own screenshot, asked through the bridge (FIX-RECON-OT-FINDINGS 03)."""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image
from veaf_libs.dcs_screenshot import (
    SCREENSHOT_LUA,
    ScreenshotError,
    default_screenshots_dir,
    grab_dcs_screenshot,
)


def test_the_order_is_the_screenshot_command() -> None:
    assert SCREENSHOT_LUA == "LoSetCommand(257) return 'ok'"


def test_the_default_folder_is_dcs_saved_games() -> None:
    assert default_screenshots_dir().parts[-3:] == ("Saved Games", "DCS", "Screenshots")


def test_the_new_screenshot_is_read_once_written_and_deleted(tmp_path: Path) -> None:
    old = tmp_path / "Screen_old.jpg"
    Image.new("RGB", (10, 10)).save(old)
    orders: list[str] = []
    looks = {"n": 0}

    def sleep(seconds: float) -> None:
        # DCS writes the file at the first look; it stops growing at the second
        looks["n"] += 1
        if looks["n"] == 1:
            Image.new("RGB", (640, 360), (200, 10, 10)).save(tmp_path / "Screen_new.jpg")

    image, size = grab_dcs_screenshot(orders.append, tmp_path, sleep)
    assert orders == [SCREENSHOT_LUA]
    assert size == (640, 360) and image.mode == "RGB"
    assert not (tmp_path / "Screen_new.jpg").exists()  # the folder does not fill up
    assert old.exists()  # what was there before is not touched
    assert looks["n"] == 2


def test_no_screenshot_is_an_error(tmp_path: Path) -> None:
    with pytest.raises(ScreenshotError, match="no screenshot"):
        grab_dcs_screenshot(lambda code: None, tmp_path / "missing", lambda seconds: None, timeout=2)
