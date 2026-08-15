"""Tests for the wave-4 VMCT actions editing the source ``mission.yaml``."""

from pathlib import Path

import pytest
from veaf_mission_mcp.edit_mission_yaml import describe_mission_config, set_mission_module

SAMPLE = """\
# VEAF mission config
modules:
  UNITS:
  SECURITY: true # keep security on
  CTLD: false
"""


def _write_sample(tmp_path: Path) -> Path:
    path = tmp_path / "mission.yaml"
    path.write_text(SAMPLE, encoding="utf-8")
    return path


def test_describe_reports_the_three_module_shapes(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    modules = describe_mission_config(path)["modules"]
    assert modules["UNITS"]["shape"] == "mandatory"
    assert modules["SECURITY"]["shape"] == "scalar"
    assert modules["SECURITY"]["enabled"] is True
    assert modules["CTLD"]["enabled"] is False


def test_set_scalar_toggle_touches_only_target(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    result = set_mission_module(path, "CTLD", True)
    assert result["inserted"] is False
    assert result["shape"] == "scalar"
    out = path.read_text(encoding="utf-8")
    assert "CTLD: true" in out
    assert "# keep security on" in out  # unrelated comment survives
    assert "# VEAF mission config" in out


def test_set_scalar_inserts_when_absent(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    result = set_mission_module(path, "GROUNDAI", True)
    assert result["inserted"] is True
    assert "GROUNDAI: true" in path.read_text(encoding="utf-8")


def test_set_extended_mapping_writes_wellformed_block(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    config = {
        "enabled": True,
        "combat_zones": [{"type": "zone", "zone_name": "CZ-Alpha"}],
    }
    result = set_mission_module(path, "COMBATZONE", config)
    assert result["shape"] == "extended"
    reloaded = describe_mission_config(path)["modules"]["COMBATZONE"]
    assert reloaded["shape"] == "extended"
    assert reloaded["enabled"] is True
    assert reloaded["config"]["combat_zones"][0]["zone_name"] == "CZ-Alpha"


def test_missing_modules_block_raises(tmp_path: Path) -> None:
    path = tmp_path / "mission.yaml"
    path.write_text("theatre: Caucasus\n", encoding="utf-8")
    with pytest.raises(ValueError, match="modules"):
        set_mission_module(path, "CTLD", True)
