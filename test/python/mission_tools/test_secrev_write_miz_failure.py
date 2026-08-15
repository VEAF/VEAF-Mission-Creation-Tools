"""SECREV-2 / VMR-053 — a failed .miz write reported success.

`write_miz` wrapped its whole zip-building block in `except Exception: logger.exception(e)` and then
`return mission` **unconditionally**. None of its thirteen callers inspects the return value, so a
write that never happened looked exactly like one that did: the build reported success and left the
previous `.miz` in place, or no file at all.

Two smaller things in the same function: the `NamedTemporaryFile` handle stayed open while
`zipfile.ZipFile` wrote to that same path, and a failure of `os.replace` left the temp file behind.
"""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from mission_tools import miz_tools
from mission_tools.miz_tools import DcsMission, write_miz


def _a_miz(folder: Path, name: str = "in.miz") -> Path:
    miz = folder / name
    with zipfile.ZipFile(miz, "w") as archive:
        archive.writestr("mission", 'mission = { ["coalition"] = {}, }')
        archive.writestr("options", "options = {}")
    return miz


def _mission(miz: Path) -> DcsMission:
    return DcsMission(file_path=miz, mission_content={"coalition": {}}, options_content={})


def _temp_files(folder: Path) -> list[Path]:
    return sorted(folder.glob("veaf_mission_*"))


class TestAFailedWriteIsReported(unittest.TestCase):
    def test_a_serialization_failure_raises(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        with mock.patch.object(miz_tools.luadata, "serialize", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                write_miz(mission, out)

    def test_a_failed_write_leaves_no_temp_file_behind(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        with mock.patch.object(miz_tools.luadata, "serialize", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                write_miz(mission, out)
        self.assertEqual(_temp_files(folder), [], "the refused write left its temp file on disk")

    def test_a_failed_write_does_not_create_the_output(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        with mock.patch.object(miz_tools.luadata, "serialize", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                write_miz(mission, out)
        self.assertFalse(out.exists(), "a half-written mission must not appear at the target path")

    def test_a_failed_write_leaves_an_existing_output_untouched(self) -> None:
        # The case that made this dangerous: overwriting in place. The previous mission must
        # survive intact rather than be replaced by a broken archive.
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = _a_miz(folder, "out.miz")
        before = out.read_bytes()
        with mock.patch.object(miz_tools.luadata, "serialize", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                write_miz(mission, out)
        self.assertEqual(out.read_bytes(), before)

    def test_a_replace_failure_is_reported_and_cleans_up(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        with mock.patch.object(miz_tools.os, "replace", side_effect=OSError("target busy")):
            with self.assertRaises(OSError):
                write_miz(mission, out)
        self.assertEqual(_temp_files(folder), [], "a failed replace left its temp file on disk")


class TestASuccessfulWriteStillWorks(unittest.TestCase):
    """The control: every assertion above would also hold on a function that never writes."""

    def test_the_output_is_written_and_readable(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        write_miz(mission, out)
        self.assertTrue(out.exists())
        with zipfile.ZipFile(out, "r") as archive:
            self.assertIn("mission", archive.namelist())
            self.assertIn("coalition", archive.read("mission").decode("utf-8"))

    def test_a_successful_write_leaves_no_temp_file(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        write_miz(mission, folder / "out.miz")
        self.assertEqual(_temp_files(folder), [])

    def test_additional_files_are_added(self) -> None:
        folder = Path(tempfile.mkdtemp())
        mission = _mission(_a_miz(folder))
        out = folder / "out.miz"
        write_miz(mission, out, additional_files={"l10n/DEFAULT/extra.lua": b"-- extra"})
        with zipfile.ZipFile(out, "r") as archive:
            self.assertEqual(archive.read("l10n/DEFAULT/extra.lua"), b"-- extra")

    def test_writing_in_place_replaces_the_file(self) -> None:
        folder = Path(tempfile.mkdtemp())
        miz = _a_miz(folder)
        mission = _mission(miz)
        write_miz(mission, None)
        with zipfile.ZipFile(miz, "r") as archive:
            self.assertIn("mission", archive.namelist())
        self.assertEqual(_temp_files(folder), [])


if __name__ == "__main__":
    unittest.main()
