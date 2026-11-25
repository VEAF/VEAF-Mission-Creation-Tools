"""In the compact profile, the reference chain stays inside a local model's context (MCP-CONTEXT-BUDGET).

On 2026-11-25 a local model at 65 000 tokens of context, driving the MCP through `llama-server`, could not
go from an empty folder to a built mission: the tool answers of the chain were 177 186 characters. This
test replays the chain through the MCP server in process and fails when its answers, the tool schemas
included, pass the budget — the guard against the next section, listing or log that grows back.

Three answers need what a test does not have — the network (`scaffold_mission`) and the installed
executable (`build_mission`, `inspect_built_mission`): their sizes are the ones measured by the stdio
replay of 2026-11-25, after this lot. The folder is laid down by `prepare`, as the scaffold does.
"""

import asyncio
import json
import shutil
from pathlib import Path

import pytest
import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
from typer.testing import CliRunner
from veaf_mission_mcp import server
from veaf_mission_mcp.response_budget import MAX_SCHEMA_CHARS
from veaf_tools.app import app

#: The most characters the chain's answers may put in the model's context, tool schemas included.
BUDGET_CHARS = 50_000

#: Answers measured over stdio on 2026-11-25 (`scaffold_mission` copied: 252 characters, before the lot).
MEASURED_CHARS = {"scaffold_mission": 252, "build_mission": 5_826, "inspect_built_mission": 2_869}


@pytest.fixture(scope="module")
def mission(tmp_path_factory: pytest.TempPathFactory) -> Path:
    scaffold = tmp_path_factory.mktemp("scaffold")
    result = CliRunner().invoke(
        app, ["prepare", "--template", "standard", "--theatre", "caucasus", str(scaffold), "--force"]
    )
    assert result.exit_code == 0, result.output
    folder = tmp_path_factory.mktemp("budget") / "mission"
    shutil.copytree(scaffold, folder)
    return folder


def _answer(tool: str, arguments: dict) -> int:
    """Call one tool through the MCP server and return the characters its answer puts in context."""
    result = asyncio.run(server.mcp.call_tool(tool, arguments))
    assert not result.is_error, "".join(getattr(block, "text", "") for block in result.content)
    text = "".join(getattr(block, "text", "") for block in result.content)
    copy = json.dumps(result.structured_content, ensure_ascii=False) if result.structured_content else ""
    return len(text) + len(copy)


def _run(name: str, params: dict) -> int:
    return _answer("run_action", {"name": name, "params": params})


@pytest.mark.usefixtures("compact")
def test_the_reference_chain_fits_the_budget(mission: Path) -> None:
    folder = str(mission)
    tools = asyncio.run(server.mcp.list_tools())
    sizes = {
        "instructions": len(server.mcp.instructions or ""),
        "tools/list": len(json.dumps([tool.model_dump(exclude_none=True) for tool in tools], ensure_ascii=False)),
        "guide": _run("describe_authoring_guide", {}),
        "limitations": _run("describe_known_limitations", {}),
        "catalogue": _answer("list_catalog", {}),
    }
    # The guide's recipe gives the chain's calls with their parameters: no describe_action for them.
    sizes["geocode"] = _run("geocode", {"theatre": "Caucasus", "query": "Beslan"})
    sizes["adapt_scaffold"] = _run(
        "adapt_scaffold",
        {
            "folder_path": folder,
            "mission_name": "Test-Beslan",
            "era": "MODERN",
            "language": "fr",
            "date": "2024-06-10",
            "start_time": "07:30",
            "position": {"x": -158841, "y": 842000},
            "airfields": ["Beslan", "Mozdok", "Nalchik", "Vaziani"],
            "dynamic_slot_coalitions": ["blue"],
        },
    )
    sizes["set_airbase_coalition"] = _run(
        "set_airbase_coalition", {"mission_path": folder, "name": "Mozdok", "coalition": "blue"}
    )
    # One section of the index, for margin: the recipe should make it unneeded.
    sizes["guide combat-zone-vs-qra"] = _run("describe_authoring_guide", {"section": "combat-zone-vs-qra"})
    sizes["create_combat_zone"] = _run(
        "create_combat_zone",
        {
            "folder_path": folder,
            "zone_name": "CZ-Beslan",
            "position": {"x": -158841, "y": 842000},
            "radius": 6000,
            "coalition": "red",
            "country_id": 0,
            "country_name": "Russia",
            "groups": [
                {"name": "armor-1", "command": "-armor", "units": [{"type": "T-72B"}]},
                {"name": "sam-1", "command": "-sa8", "units": [{"type": "T-72B"}]},
            ],
        },
    )
    sizes["validate_mission"] = _run("validate_mission", {"folder_path": folder})
    sizes.update(MEASURED_CHARS)

    total = sum(sizes.values())
    detail = ", ".join(f"{name} {size}" for name, size in sorted(sizes.items(), key=lambda item: -item[1]))
    assert total <= BUDGET_CHARS, f"the reference chain is {total} characters, over {BUDGET_CHARS}: {detail}"


@pytest.mark.usefixtures("compact")
def test_no_schema_comes_back_cut() -> None:
    """A schema is read whole or not at all: the largest one fits the schema ceiling."""
    for name in ("adapt_scaffold", "create_combat_zone", "scaffold_mission", "build_mission_briefing"):
        assert _answer("describe_action", {"name": name}) <= MAX_SCHEMA_CHARS
