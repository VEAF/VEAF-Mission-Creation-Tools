from pathlib import Path

import pytest
from veaf_mission_mcp import server
from veaf_mission_mcp.catalog import ActionNotFoundError


def test_capabilities_reports_server_name_and_a_version() -> None:
    result = server.capabilities()

    assert result["name"] == "veaf-mission-mcp"
    assert result["version"]


def test_list_catalog_includes_the_default_actions() -> None:
    names = {spec["name"] for spec in server.list_catalog()}

    assert "describe_mission" in names


def test_describe_action_returns_the_describe_mission_spec() -> None:
    spec = server.describe_action("describe_mission")

    assert spec["name"] == "describe_mission"
    assert "miz_path" in spec["parameters_schema"]["properties"]


def test_describe_action_raises_a_clear_error_for_an_unknown_name() -> None:
    with pytest.raises(ActionNotFoundError):
        server.describe_action("does_not_exist")


def test_run_action_raises_a_clear_error_for_an_unknown_name() -> None:
    with pytest.raises(ActionNotFoundError):
        server.run_action("does_not_exist", {})


def test_run_action_dispatches_describe_mission_end_to_end(sample_miz: Path) -> None:
    result = server.run_action("describe_mission", {"miz_path": str(sample_miz)})

    assert {g["name"] for g in result["groups"]} == {"Blue Recon Flight", "Red Armor Section"}
    assert result["zones"][0]["name"] == "combatZone_Test"
