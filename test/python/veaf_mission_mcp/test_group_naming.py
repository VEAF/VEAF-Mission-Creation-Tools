"""Tests for wave-6 group-name validation (reserved-convention warnings)."""

from pathlib import Path

import pytest
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.group_naming import validate_group_name

_RED = {"coalition": "red", "country_id": 0, "country_name": "Russia", "category": "vehicle"}


def _conventions(result: dict) -> set[str]:
    return {w["convention"] for w in result["warnings"]}


def test_clean_name_has_no_warnings() -> None:
    assert validate_group_name("Blue Recon 2")["warnings"] == []


def test_spawn_template_prefix_warns() -> None:
    assert "spawn_template" in _conventions(validate_group_name("veafSpawn-Viper"))


def test_cap_template_prefix_warns() -> None:
    assert "cap_template" in _conventions(validate_group_name("OnDemand-Strike"))


def test_placeholder_prefix_warns() -> None:
    assert "coalition_placeholder" in _conventions(validate_group_name("VEAF-placeholder-blue"))


def test_interpreter_marker_warns() -> None:
    assert "interpreter_command" in _conventions(validate_group_name('x #veafInterpreter["_spawn convoy"]'))


@pytest.mark.parametrize(
    "marker",
    [
        "#command=",
        "#spawngroup=",
        "#spawnradius=",
        "#spawncount=",
        "#spawnchance=",
        "#spawndelay=",
        "#alarm=",
    ],
)
def test_every_combat_zone_unit_marker_warns(marker: str) -> None:
    """The whole reserved-marker family is flagged, not a sample of it."""
    assert "combat_zone_unit_markers" in _conventions(validate_group_name(f"convoy {marker}2"))


def test_leading_dash_warns_qra_deploy() -> None:
    assert "qra_deploy_entry" in _conventions(validate_group_name("-armor"))


def test_cas_fixed_name_warns() -> None:
    assert "cas_runtime_group" in _conventions(validate_group_name("Red CAS Group"))


def test_combat_zone_capture_trap_detected_against_miz(sample_miz: Path) -> None:
    result = validate_group_name("combatZone_Test-tanks", miz_path=sample_miz)
    caps = [w for w in result["warnings"] if w["convention"] == "combat_zone_capture"]
    assert caps and caps[0]["zone"] == "combatZone_Test"


def test_capture_trap_suppressed_for_intended_zone(sample_miz: Path) -> None:
    result = validate_group_name("combatZone_Test-tanks", miz_path=sample_miz, expected_combat_zone="combatZone_Test")
    assert not [w for w in result["warnings"] if w["convention"] == "combat_zone_capture"]


# --- add_group surfaces warnings -----------------------------------------------


def test_add_group_returns_warnings_for_colliding_name(sample_miz: Path) -> None:
    result = add_group(
        sample_miz,
        **_RED,
        name="OnDemand-Strike",
        position={"x": 1.0, "y": 2.0},
        units=[{"type": "T-72B", "count": 1}],
    )
    assert "cap_template" in {w["convention"] for w in result["warnings"]}


def test_add_group_for_combat_zone_does_not_warn_about_intended_zone(sample_miz: Path) -> None:
    result = add_group(
        sample_miz,
        **_RED,
        name="tanks",
        position={"x": 1.0, "y": 2.0},
        units=[{"type": "T-72B", "count": 1}],
        for_combat_zone="combatZone_Test",
    )
    assert not [w for w in result["warnings"] if w["convention"] == "combat_zone_capture"]


def test_add_group_clean_name_no_warnings(sample_miz: Path) -> None:
    result = add_group(
        sample_miz,
        **_RED,
        name="Plain Convoy",
        position={"x": 1.0, "y": 2.0},
        units=[{"type": "T-72B", "count": 1}],
    )
    assert result["warnings"] == []
