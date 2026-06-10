"""SECREV-002 — every helicopter group in a country must be extracted.

Regression: the pattern-match/capture block in ``find_matching_groups`` was
dedented one level out of the ``for group in groups_list`` loop, so only the
*last* helicopter group of each country was ever matched. Planes were unaffected.
"""

from __future__ import annotations

from pathlib import Path

from aircrafts_injector.aircrafts_injector_worker import AircraftGroupsExtractorWorker
from mission_tools.miz_tools import DcsMission


def _mission_with_helicopters() -> DcsMission:
    """One coalition, one country, two helicopter groups (and one plane group)."""
    content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "plane": {
                            "group": [
                                {"name": "Viper 1", "units": [{"type": "F-16C_50"}]},
                            ]
                        },
                        "helicopter": {
                            "group": [
                                {"name": "Huey 1", "units": [{"type": "UH-1H"}]},
                                {"name": "Apache 1", "units": [{"type": "AH-64D_BLK_II"}]},
                                {"name": "Kiowa 1", "units": [{"type": "OH58D"}]},
                            ]
                        },
                    }
                ]
            }
        }
    }
    return DcsMission(file_path=Path("dummy.miz"), mission_content=content)


def _extractor() -> AircraftGroupsExtractorWorker:
    worker = AircraftGroupsExtractorWorker(input_lua=Path("lua-input"))
    worker.dcs_mission = _mission_with_helicopters()
    return worker


def test_all_helicopter_groups_are_matched() -> None:
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    helo_names = {
        info["group_name"] for info in worker.matched_groups.values() if info["aircraft_category"] == "helicopters"
    }
    assert helo_names == {"Huey 1", "Apache 1", "Kiowa 1"}


def test_helicopter_and_plane_groups_coexist() -> None:
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    # 1 plane + 3 helicopters
    assert len(worker.matched_groups) == 4


def test_helicopter_only_filter_keeps_all_helicopters() -> None:
    worker = AircraftGroupsExtractorWorker(input_lua=Path("lua-input"), aircraft_type="helicopters")
    worker.dcs_mission = _mission_with_helicopters()
    worker.find_matching_groups(silent=True)
    assert len(worker.matched_groups) == 3
