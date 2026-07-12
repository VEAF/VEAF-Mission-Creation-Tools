import pytest
from veaf_mission_mcp import server
from veaf_mission_mcp.catalog import ActionNotFoundError


def test_capabilities_reports_server_name_and_a_version() -> None:
    result = server.capabilities()

    assert result["name"] == "veaf-mission-mcp"
    assert result["version"]


def test_list_catalog_is_empty_before_any_action_is_registered() -> None:
    assert server.list_catalog() == []


def test_describe_action_raises_a_clear_error_for_an_unknown_name() -> None:
    with pytest.raises(ActionNotFoundError):
        server.describe_action("does_not_exist")


def test_run_action_raises_a_clear_error_for_an_unknown_name() -> None:
    with pytest.raises(ActionNotFoundError):
        server.run_action("does_not_exist", {})
