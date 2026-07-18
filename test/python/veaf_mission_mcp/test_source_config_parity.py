"""Tests for the wave-7 source-side (`mission.yaml`) config setters."""

from pathlib import Path

import pytest
from mission_tools.mission_yaml_editor import load_yaml

from veaf_mission_mcp.edit_mission_yaml import (
    set_mission_log_level,
    set_mission_security,
    set_mission_setting,
)

SAMPLE = """\
# VEAF mission config
theatre: Caucasus
modules:
  SECURITY: true
"""


def _write(tmp_path: Path) -> Path:
    path = tmp_path / "mission.yaml"
    path.write_text(SAMPLE, encoding="utf-8")
    return path


def test_set_log_level_sets_top_level_key(tmp_path: Path) -> None:
    path = _write(tmp_path)
    set_mission_log_level(path, "debug")
    assert load_yaml(path)["global_log_level"] == "debug"
    assert "# VEAF mission config" in path.read_text(encoding="utf-8")  # comment preserved


def test_set_log_level_rejects_unknown_level(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="log level"):
        set_mission_log_level(_write(tmp_path), "verbose")


def test_set_security_sets_disabled_flag(tmp_path: Path) -> None:
    path = _write(tmp_path)
    set_mission_security(path, disabled=False)
    assert load_yaml(path)["security"]["disabled"] is False


def test_set_security_writes_password_hashes(tmp_path: Path) -> None:
    path = _write(tmp_path)
    set_mission_security(path, disabled=True, password_hashes=["h1"], password_mm_hashes=["mm1"])
    security = load_yaml(path)["security"]
    assert security["disabled"] is True
    assert list(security["password_hashes"]) == ["h1"]
    assert list(security["password_mm_hashes"]) == ["mm1"]


def test_set_setting_creates_then_updates(tmp_path: Path) -> None:
    path = _write(tmp_path)
    first = set_mission_setting(path, "MISSILEGUARDIAN_range", 5)
    assert first["inserted"] is True
    assert load_yaml(path)["settings"]["MISSILEGUARDIAN_range"] == 5
    second = set_mission_setting(path, "MISSILEGUARDIAN_range", 9)
    assert second["inserted"] is False
    assert load_yaml(path)["settings"]["MISSILEGUARDIAN_range"] == 9
