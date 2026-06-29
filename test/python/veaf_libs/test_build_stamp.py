"""Tests for veaf_libs.build_stamp — FEAT-LUA-BUILD-STAMP-001."""

from __future__ import annotations

import subprocess
import unittest
from unittest import mock

from veaf_libs import build_stamp


class TestGetBuildStamp(unittest.TestCase):
    def test_version_plus_commit(self) -> None:
        with (
            mock.patch.object(build_stamp, "_package_version", return_value="6.7.3"),
            mock.patch.object(build_stamp, "_commit", return_value="5815cbab"),
        ):
            self.assertEqual(build_stamp.get_build_stamp(), "6.7.3+5815cbab")

    def test_bare_version_when_no_commit(self) -> None:
        with (
            mock.patch.object(build_stamp, "_package_version", return_value="6.7.3"),
            mock.patch.object(build_stamp, "_commit", return_value=""),
        ):
            self.assertEqual(build_stamp.get_build_stamp(), "6.7.3")


class TestCommitResolution(unittest.TestCase):
    def test_commit_prefers_baked_version_module(self) -> None:
        fake_version = mock.Mock()
        fake_version.__commit__ = "deadbeef"
        with mock.patch.dict("sys.modules", {"veaf_tools._version": fake_version}):
            self.assertEqual(build_stamp._commit(), "deadbeef")

    def test_commit_falls_back_to_git(self) -> None:
        fake_version = mock.Mock(spec=[])  # no __commit__ attribute
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="abc1234\n", stderr="")
        with (
            mock.patch.dict("sys.modules", {"veaf_tools._version": fake_version}),
            mock.patch.object(build_stamp.subprocess, "run", return_value=completed),
        ):
            self.assertEqual(build_stamp._commit(), "abc1234")

    def test_commit_empty_when_git_fails(self) -> None:
        fake_version = mock.Mock(spec=[])
        with (
            mock.patch.dict("sys.modules", {"veaf_tools._version": fake_version}),
            mock.patch.object(build_stamp.subprocess, "run", side_effect=OSError("no git")),
        ):
            self.assertEqual(build_stamp._commit(), "")


if __name__ == "__main__":
    unittest.main()
