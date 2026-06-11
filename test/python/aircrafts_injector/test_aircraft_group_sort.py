"""AIRCRAFT-INJECT — sort aircraft groups into spawnables (B) vs dynamic-slot templates (C).

Covers the ADR-0002 classifier and the two-file extraction (default both, with a
per-family restriction).
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml
from aircrafts_injector import (
    KIND_DYNAMIC_TEMPLATE,
    KIND_SPAWNABLE,
    AircraftGroupsExtractorWorker,
    classify_aircraft_group,
)
from mission_tools.miz_tools import DcsMission


class TestClassifyAircraftGroup:
    def test_dyn_spawn_template_flag(self) -> None:
        assert classify_aircraft_group({"name": "F-15 Template", "dynSpawnTemplate": True}) == KIND_DYNAMIC_TEMPLATE

    def test_veaf_spawn_prefix(self) -> None:
        assert classify_aircraft_group({"name": "veafSpawn-CAP"}) == KIND_SPAWNABLE

    def test_ordinary_group_ignored(self) -> None:
        assert classify_aircraft_group({"name": "Enemy SAM site"}) is None

    def test_flag_wins_over_prefix(self) -> None:
        # A group that is both → the native flag wins (ADR 0002).
        group = {"name": "veafSpawn-CAP", "dynSpawnTemplate": True}
        assert classify_aircraft_group(group) == KIND_DYNAMIC_TEMPLATE

    def test_false_flag_falls_back_to_prefix(self) -> None:
        assert classify_aircraft_group({"name": "veafSpawn-CAP", "dynSpawnTemplate": False}) == KIND_SPAWNABLE

    def test_missing_name_is_ignored(self) -> None:
        assert classify_aircraft_group({}) is None


def _mission() -> DcsMission:
    content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "plane": {
                            "group": [
                                {"name": "veafSpawn-CAP", "units": [{"type": "F-16C_50"}]},
                                {"name": "F-15 Template", "dynSpawnTemplate": True, "units": [{"type": "F-15ESE"}]},
                                {"name": "Ordinary AI", "units": [{"type": "F-16C_50"}]},
                            ]
                        },
                    }
                ]
            }
        }
    }
    return DcsMission(file_path=Path("dummy.miz"), mission_content=content)


def _run(worker: AircraftGroupsExtractorWorker) -> None:
    """Drive the non-interactive extraction path against a preset dcs_mission."""
    worker.find_matching_groups(silent=True)
    for info in worker.matched_groups.values():
        worker._add_group_to_templates(
            info["kind"], info["group"], info["aircraft_category"], info["coalition_name"], info["country_name"]
        )
    worker.write_yaml(silent=True)


class TestTwoFileExtraction:
    def test_default_writes_both_files_routed_correctly(self, tmp_path: Path) -> None:
        spawnables = tmp_path / "spawnables.yaml"
        dynamic = tmp_path / "dynamic-slot-templates.yaml"
        worker = AircraftGroupsExtractorWorker(
            input_lua=Path("lua-input"), output_spawnables=spawnables, output_dynamic_templates=dynamic
        )
        worker.dcs_mission = _mission()
        _run(worker)

        spawn_data = yaml.safe_load(spawnables.read_text())
        dyn_data = yaml.safe_load(dynamic.read_text())
        spawn_planes = spawn_data["airplanes"]["coalitions"]["blue"]["USA"]
        dyn_planes = dyn_data["airplanes"]["coalitions"]["blue"]["USA"]

        assert "veafSpawn-CAP" in spawn_planes
        assert "F-15 Template" not in spawn_planes
        assert "F-15 Template" in dyn_planes
        assert "veafSpawn-CAP" not in dyn_planes
        # Ordinary group routed nowhere
        assert "Ordinary AI" not in spawn_planes
        assert "Ordinary AI" not in dyn_planes

    def test_kind_restriction_writes_only_requested_file(self, tmp_path: Path) -> None:
        spawnables = tmp_path / "spawnables.yaml"
        worker = AircraftGroupsExtractorWorker(
            input_lua=Path("lua-input"), output_spawnables=spawnables, output_dynamic_templates=None
        )
        worker.dcs_mission = _mission()
        _run(worker)
        assert spawnables.exists()
        assert not (tmp_path / "dynamic-slot-templates.yaml").exists()

    def test_requires_at_least_one_output(self) -> None:
        with pytest.raises(ValueError):
            AircraftGroupsExtractorWorker(
                input_lua=Path("lua-input"), output_spawnables=None, output_dynamic_templates=None
            )
