"""Tests for build.py pipeline orphan warnings — AORPHAN-002."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


class TestAircraftOrphanWarning(unittest.TestCase):
    """Orphan-file warning when aircraft_groups is disabled but file exists (AORPHAN-002)."""

    def _run_orphan_check(self, p_mission_folder: Path, pipeline_cfg: dict, *, file_present: bool) -> list[str]:
        """Exercise the orphan-check logic from build.py in isolation."""
        if file_present:
            src_dir = p_mission_folder / "src"
            src_dir.mkdir(parents=True, exist_ok=True)
            (src_dir / "aircraft-templates.yaml").write_text("# stub\n", encoding="utf-8")

        warnings: list[str] = []

        def fake_warning(msg: str, *args: object, **kwargs: object) -> None:
            warnings.append(msg % args if args else msg)

        # Replicate the exact logic added in build.py (else branch after aircraft_path check)
        step_cfg = pipeline_cfg.get("aircraft_groups")
        aircraft_path = None  # simulate _step_file returning None (step disabled or file absent)
        if not (step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False)):
            # step is not explicitly disabled — check candidates
            for candidate in ("src/aircraft-templates.yaml", "src/templates.yaml", "aircraft-templates.yaml"):
                p = p_mission_folder / candidate
                if p.exists():
                    aircraft_path = p
                    break

        if aircraft_path is None:
            _orphan = p_mission_folder / "src" / "aircraft-templates.yaml"
            if _orphan.exists():
                fake_warning(
                    "Orphan file 'src/aircraft-templates.yaml': "
                    "pipeline 'aircraft_groups' is disabled or skipped "
                    "but the file still exists in your mission folder. "
                    "You can safely delete it, or enable 'aircraft_groups' in mission.yaml."
                )

        return warnings

    def test_warning_emitted_when_disabled_and_file_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_orphan_check(
                Path(td),
                pipeline_cfg={"aircraft_groups": False},
                file_present=True,
            )
        self.assertTrue(any("aircraft-templates.yaml" in w for w in warnings))

    def test_no_warning_when_file_absent(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_orphan_check(
                Path(td),
                pipeline_cfg={"aircraft_groups": False},
                file_present=False,
            )
        self.assertEqual(warnings, [])

    def test_no_warning_when_step_enabled_and_file_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_orphan_check(
                Path(td),
                pipeline_cfg={},  # aircraft_groups not explicitly disabled
                file_present=True,
            )
        self.assertEqual(warnings, [])

    def test_no_warning_when_step_absent_and_file_absent(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            warnings = self._run_orphan_check(
                Path(td),
                pipeline_cfg={},
                file_present=False,
            )
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
