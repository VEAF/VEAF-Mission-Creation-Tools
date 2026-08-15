"""Build-time Mission-Editor reference validation is non-blocking (FEAT-BUILD-VALIDATE-REFS).

The build collects missing references and reports them as a prominent end-of-build
warning summary; it must never abort (blocking would deny the maker the `.miz` to fix).
"""

from __future__ import annotations

import unittest

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_builder_factory import make_worker


class _FakeMission:
    def __init__(self, content: dict) -> None:
        self.mission_content = content


class TestReferenceValidationNonBlocking(unittest.TestCase):
    def _worker(self, mission_yaml: dict, mission_content: dict) -> MissionBuilderWorker:
        return make_worker(mission_yaml=mission_yaml, dcs_mission=_FakeMission(mission_content))

    def test_validate_references_collects_without_aborting(self) -> None:
        worker = self._worker({"cap_missions": [{"group_name": "Ghost"}]}, {"coalition": {}})
        worker.validate_references()  # must not raise
        self.assertEqual(len(worker._reference_issues), 1)

    def test_report_reference_issues_does_not_raise(self) -> None:
        worker = self._worker({"cap_missions": [{"group_name": "Ghost"}]}, {"coalition": {}})
        worker.validate_references()
        worker.report_reference_issues()  # prominent warning summary, never aborts

    def test_clean_mission_has_no_issues(self) -> None:
        worker = self._worker({}, {"coalition": {}, "triggers": {"zones": []}})
        worker.validate_references()
        self.assertEqual(worker._reference_issues, [])
        worker.report_reference_issues()  # no-op, must not raise


if __name__ == "__main__":
    unittest.main()
