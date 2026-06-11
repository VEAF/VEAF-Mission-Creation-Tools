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
    """One coalition, one country, three helicopter groups (and one plane group).

    All groups are spawnable (``veafSpawn-`` prefix) so the ADR-0002 sort keeps
    every one of them — the regression here is about iteration not dropping
    groups, independent of the sort criterion.
    """
    content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "plane": {
                            "group": [
                                {"name": "veafSpawn-Viper 1", "units": [{"type": "F-16C_50"}]},
                            ]
                        },
                        "helicopter": {
                            "group": [
                                {"name": "veafSpawn-Huey 1", "units": [{"type": "UH-1H"}]},
                                {"name": "veafSpawn-Apache 1", "units": [{"type": "AH-64D_BLK_II"}]},
                                {"name": "veafSpawn-Kiowa 1", "units": [{"type": "OH58D"}]},
                            ]
                        },
                    }
                ]
            }
        }
    }
    return DcsMission(file_path=Path("dummy.miz"), mission_content=content)


def _extractor(**kwargs: object) -> AircraftGroupsExtractorWorker:
    worker = AircraftGroupsExtractorWorker(
        input_lua=Path("lua-input"), output_spawnables=Path("out-spawnables.yaml"), **kwargs
    )
    worker.dcs_mission = _mission_with_helicopters()
    return worker


def test_all_helicopter_groups_are_matched() -> None:
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    helo_names = {
        info["group_name"] for info in worker.matched_groups.values() if info["aircraft_category"] == "helicopters"
    }
    assert helo_names == {"veafSpawn-Huey 1", "veafSpawn-Apache 1", "veafSpawn-Kiowa 1"}


def test_helicopter_and_plane_groups_coexist() -> None:
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    # 1 plane + 3 helicopters
    assert len(worker.matched_groups) == 4


def test_helicopter_only_filter_keeps_all_helicopters() -> None:
    worker = _extractor(aircraft_type="helicopters")
    worker.find_matching_groups(silent=True)
    assert len(worker.matched_groups) == 3
