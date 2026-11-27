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

#: Answers measured, compact profile: `scaffold_mission` over stdio on 2026-11-25 (before the lot); the build and
#: the inspection of the local model's run 8 (D:\tmp\test-mission8, a zone, a SA-8 and a QRA) through
#: `drop_step_lines` and `compact_inspection`, 2026-11-26 (5 083 and 2 878 characters before them).
MEASURED_CHARS = {"scaffold_mission": 252, "build_mission": 4_064, "inspect_built_mission": 1_281}


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
    # The recipe's call for the aircraft an airfield offers, which replaced a hand edit of `src/warehouses.yaml` and the
    # second build it cost (FIX-MCP-REPLAY-FINDINGS 02).
    sizes["list_airfield_aircraft"] = _run("list_airfield_aircraft", {"mission_path": folder, "airfield": "Mozdok"})
    # The recipe's tanker, call for call: a local model asked for an AWACS and two tankers read the guide eight times
    # and 14 schemas, 160 072 characters, and was cut off before placing them (2026-11-26).
    sizes["add_air_group"] = _run(
        "add_air_group",
        {
            "target": folder,
            "coalition": "blue",
            "country_id": 2,
            "country_name": "USA",
            "name": "Texaco-1",
            "unit_type": "KC135MPRS",
            "start": "air",
            "position": {"x": -120000, "y": 700000},
            "altitude_ft": 18000,
            "speed_kt": 300,
            "task": "Refueling",
            "frequency_mhz": 290.1,
        },
    )
    route = {"miz_path": folder, "group_name": "Texaco-1"}
    second_point = {"position": {"x": -120000, "y": 740000}, "altitude_ft": 18000, "speed_kt": 300}
    sizes["edit_route add"] = _run("edit_route", {**route, "operation": "add", **second_point})
    tasks = (
        {"task": "tanker"},
        {"task": "activate_beacon", "task_params": {"channel": 60, "mode": "Y", "callsign": "TX1", "aa": True}},
        {"task": "set_unlimited_fuel"},
        {"task": "orbit", "task_params": {"pattern": "Race-Track", "altitude_ft": 18000, "speed_kt": 300}},
    )
    for task in tasks:
        sizes[f"edit_route {task['task']}"] = _run("edit_route", {**route, "operation": "add_task", "index": 1, **task})
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
    sizes["list_payloads"] = _run("list_payloads", {"unit_type": "MiG-29A"})
    sizes["create_qra"] = _run(
        "create_qra",
        {
            "mission_path": folder,
            "name": "QRA-Nalchik",
            "coalition": "red",
            "country_id": 0,
            "country_name": "Russia",
            "trigger_zone": "QRA-Nalchik-Zone",
            "position": {"x": -158841, "y": 842000},
            "radius": 40000,
            "groups": [
                {
                    "name": "QRA-Nalchik-1",
                    "units": [{"type": "MiG-29A"}, {"type": "MiG-29A"}],
                    "airfield": "Nalchik",
                    "payload": "R-73*2,R-60M*2,R-27R*2",
                }
            ],
        },
    )
    sizes["validate_mission"] = _run("validate_mission", {"folder_path": folder})
    sizes.update(MEASURED_CHARS)

    total = sum(sizes.values())
    detail = ", ".join(f"{name} {size}" for name, size in sorted(sizes.items(), key=lambda item: -item[1]))
    assert total <= BUDGET_CHARS, f"the reference chain is {total} characters, over {BUDGET_CHARS}: {detail}"


#: The most characters the `more` section's chain may put in context, the guide read again included.
MORE_BUDGET_CHARS = 25_000


@pytest.mark.usefixtures("compact")
def test_the_more_section_s_chain_fits_its_budget(mission: Path) -> None:
    """Two QRAs with tiers, ground groups, a static, a JTAC and the briefing, with the `more` section's calls.

    Run 15 (2026-11-26, Cherry Studio and a local model at 65 536 tokens) asked for these on a built mission and
    wrote nothing in 93 calls: the guide covered none of them, and six compactions threw away each schema it read.
    """
    folder = str(mission)
    blue = {"mission_path": folder, "coalition": "blue", "country_id": 2, "country_name": "USA", "keep_position": True}
    sizes = {
        "guide": _run("describe_authoring_guide", {}),
        "guide more": _run("describe_authoring_guide", {"section": "more"}),
        "describe_mission": _run("describe_mission", {"mission_path": folder}),
        "list_payloads": _run("list_payloads", {"unit_type": "MiG-29S"}),
    }
    pair = [{"type": "MiG-29S"}, {"type": "MiG-29S"}]
    sizes["create_qra"] = _run(
        "create_qra",
        {
            "mission_path": folder,
            "name": "QRA-Beslan",
            "coalition": "red",
            "country_id": 0,
            "country_name": "Russia",
            "trigger_zone": "QRA-Beslan-Zone",
            "position": {"x": -158841, "y": 842000},
            "radius": 30000,
            "groups": [
                {"name": f"QRA-Beslan-{i}", "units": pair, "airfield": "Beslan", "payload": "R-73*2,R-60M*2,R-27R*2"}
                for i in (1, 2)
            ],
            "qra": {
                "groups_by_enemy_count": [
                    {"enemy_count": 1, "groups": ["QRA-Beslan-1"]},
                    {"enemy_count": 4, "groups": ["QRA-Beslan-1", "QRA-Beslan-2"]},
                ],
                "react_on_helicopters": False,
                "delay_before_activating": 900,
            },
        },
    )
    ground = (
        ("Abrams-1", "vehicle", [{"type": "M-1 Abrams", "count": 4}], {}),
        ("M109-1", "vehicle", [{"type": "M-109", "count": 4}], {"roe": "weapons_hold"}),
        ("PC-Brigade", "static", [{"type": ".Command Center"}], {}),
        ("JTAC-1", "vehicle", [{"type": "Hummer"}], {}),
    )
    for index, (name, category, units, extra) in enumerate(ground):
        position = {"x": -160000 + 300 * index, "y": 840000}
        sizes[f"add_group {name}"] = _run(
            "add_group", {**blue, "category": category, "name": name, "position": position, "units": units, **extra}
        )
    jtac = {"sort": 1, "name": "JTAC-1", "description": "JTAC", "jtac": 1511, "freq": 35.55, "mod": "FM"}
    sizes["set_mission_module"] = _run(
        "set_mission_module",
        {
            "mission_yaml_path": str(mission / "mission.yaml"),
            "module_id": "ASSETS",
            "value": {"enabled": True, "assets": [jtac]},
        },
    )
    sizes["set_briefing"] = _run(
        "set_briefing",
        {"mission_path": folder, "sortie": "Marteau du Golan", "situation": "Situation.", "blue_task": "Tâche."},
    )
    sizes["validate_mission"] = _run("validate_mission", {"folder_path": folder})
    sizes.update({key: MEASURED_CHARS[key] for key in ("build_mission", "inspect_built_mission")})

    total = sum(sizes.values())
    detail = ", ".join(f"{name} {size}" for name, size in sorted(sizes.items(), key=lambda item: -item[1]))
    assert total <= MORE_BUDGET_CHARS, f"the more chain is {total} characters, over {MORE_BUDGET_CHARS}: {detail}"
    assert "jtac: 1511" in (mission / "mission.yaml").read_text(encoding="utf-8")


@pytest.mark.usefixtures("compact")
def test_no_schema_comes_back_cut() -> None:
    """A schema is read whole or not at all: the largest one fits the schema ceiling."""
    for name in ("adapt_scaffold", "create_combat_zone", "scaffold_mission", "build_mission_briefing"):
        assert _answer("describe_action", {"name": name}) <= MAX_SCHEMA_CHARS
