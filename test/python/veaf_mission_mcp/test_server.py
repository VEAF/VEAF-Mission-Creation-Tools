import asyncio
from pathlib import Path

import pytest
from mcp.server.mcpserver.exceptions import ToolError
from veaf_mission_mcp import server
from veaf_mission_mcp.catalog import ActionNotFoundError

# The tests below call the module functions directly, which proves the *catalog* works but says
# nothing about the server: every one of them would still pass while the MCP client connected and
# saw no tools at all — the failure `main()`'s comment warns about. The two that follow go through
# `mcp` itself, so a decorator that silently stopped registering (or an argument shape that stopped
# being accepted) fails here instead of in DCS. `asyncio.run` rather than pytest-asyncio: the
# listing API is a coroutine, and this needs no new dependency for two calls.


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


def _call_error(name: str, params: dict[str, object]) -> str:
    """Run an action through the MCP server and return the error text the client reads.

    In process, `call_tool` raises the `ToolError` whose message the client would receive.
    """
    with pytest.raises(ToolError) as caught:
        asyncio.run(server.mcp.call_tool("run_action", {"name": name, "params": params}))
    return str(caught.value)


def test_run_action_raises_a_clear_error_for_an_unknown_name() -> None:
    assert "does_not_exist" in _call_error("does_not_exist", {})


# FIX-SCRATCH-MISSION-FINDINGS ticket 19, point 7. `mcp` 2.x hands the client nothing but
# "Error executing tool run_action" for any exception other than its own `ToolError` — so a misnamed
# parameter, and every refusal an action words with care, reached the agent as that one line.


def test_a_misnamed_parameter_is_named_to_the_client(tmp_path: Path) -> None:
    message = _call_error("describe_map", {"miz_path": str(tmp_path)})
    assert "mission_path" in message
    assert "miz_path" in message


def test_a_missing_parameter_is_named_to_the_client() -> None:
    assert "mission_path" in _call_error("describe_map", {})


def test_an_action_refusal_reaches_the_client_with_its_message(tmp_path: Path) -> None:
    missing = tmp_path / "nowhere.miz"
    assert "nowhere.miz" in _call_error("describe_map", {"mission_path": str(missing)})


def test_run_action_dispatches_describe_mission_end_to_end(sample_miz: Path) -> None:
    result = server.run_action("describe_mission", {"miz_path": str(sample_miz)})

    assert {g["name"] for g in result["groups"]} == {"Blue Recon Flight", "Red Armor Section"}
    assert result["zones"][0]["name"] == "combatZone_Test"


def test_the_server_registers_the_four_discovery_tools() -> None:
    # Exact equality on purpose, not a subset: the module docstring commits to a **fixed** discovery
    # surface rather than one MCP tool per mission-editing action, so a fifth tool appearing is a
    # design change this test exists to surface. Relaxing this to a subset would let it through.
    names = {tool.name for tool in asyncio.run(server.mcp.list_tools())}

    assert names == {"capabilities", "list_catalog", "describe_action", "run_action"}


def test_calling_a_tool_through_the_server_returns_its_value() -> None:
    result = asyncio.run(server.mcp.call_tool("capabilities", {}))

    assert not result.is_error
    assert result.structured_content == {"name": "veaf-mission-mcp", "version": server.VERSION}
