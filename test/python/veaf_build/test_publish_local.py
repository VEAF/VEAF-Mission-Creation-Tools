"""Tests for the local-publish deploy (veaf_build.worker.deploy_published_locally)."""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from veaf_build.worker import deploy_published_locally


def _make_published_zip(path: Path) -> None:
    """Write a minimal published.zip mirroring the real layout (root-level exes + src/)."""
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("veaf-tools.exe", b"MZ-fake-exe")
        zf.writestr("veaf-tools-updater.exe", b"MZ-fake-updater")
        zf.writestr("veaf-version.json", '{"version": "9.9.9"}')
        zf.writestr("src/scripts/veaf/veaf-scripts.lua", "-- bundle\n")
        zf.writestr("src/defaults/mission-folder/mission.yaml", "modules:\n")


class TestPublishLocal(unittest.TestCase):
    def test_deploy_reproduces_updater_end_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            zip_path = tmp_path / "published.zip"
            _make_published_zip(zip_path)
            target = tmp_path / "ma-mission"

            moved = deploy_published_locally(zip_path, target)

            # published/ holds the extracted payload (scripts, defaults, version)
            self.assertTrue((target / "published" / "src" / "scripts" / "veaf" / "veaf-scripts.lua").is_file())
            self.assertTrue((target / "published" / "src" / "defaults" / "mission-folder" / "mission.yaml").is_file())
            self.assertTrue((target / "published" / "veaf-version.json").is_file())
            # the two executables are MOVED to the folder root, not left under published/
            self.assertEqual(sorted(moved), ["veaf-tools-updater.exe", "veaf-tools.exe"])
            self.assertTrue((target / "veaf-tools.exe").is_file())
            self.assertTrue((target / "veaf-tools-updater.exe").is_file())
            self.assertFalse((target / "published" / "veaf-tools.exe").exists())
            self.assertFalse((target / "published" / "veaf-tools-updater.exe").exists())

    def test_deploy_overwrites_existing_root_exe(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            zip_path = tmp_path / "published.zip"
            _make_published_zip(zip_path)
            target = tmp_path / "ma-mission"
            target.mkdir()
            (target / "veaf-tools.exe").write_bytes(b"old")

            deploy_published_locally(zip_path, target)
            self.assertEqual((target / "veaf-tools.exe").read_bytes(), b"MZ-fake-exe")


if __name__ == "__main__":
    unittest.main()
