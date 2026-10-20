"""`inspect_built_mission` — what a built `.miz` holds, without a shell (FIX-OPENCODE-TEST-FINDINGS 07).

The guide asked the AI to "open the built `.miz` and check"; with nothing but the actions, it unzipped it
and parsed the Lua tables in PowerShell. The action reads what the post-build check needs, compactly.
"""

import json
import shutil
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz, write_miz
from veaf_mission_mcp.inspect_built import inspect_built_mission

_TEST_DATA = Path(__file__).resolve().parents[2] / "veaf-tools"
#: A built mission: dynamic-slot templates, presets injected, warehouses wired, tankers and AWACS.
BUILT = _TEST_DATA / "demo-mission" / "veaf-demo-mission.miz"
#: A large built mission: every airfield of Caucasus stocked, 690 warehouse links.
LARGE = _TEST_DATA / "test.miz"


@pytest.fixture(scope="module")
def report() -> dict:
    return inspect_built_mission(BUILT)


def test_every_section_is_there(report: dict) -> None:
    assert {
        "miz",
        "theatre",
        "dynamic_slot_templates",
        "airbases",
        "farps_and_ships",
        "presets",
        "bullseye",
        "weather",
        "support",
        "counters",
    } <= set(report)


def test_each_held_airbase_says_its_side_and_the_types_it_offers(report: dict) -> None:
    mission = read_miz(BUILT)
    airports = (mission.warehouses_content or {})["airports"]
    offering = [a for a in airports.values() if a.get("dynamicSpawn") and str(a.get("coalition")).upper() != "NEUTRAL"]
    assert offering, "the fixture offers dynamic slots"
    assert len(report["airbases"]) >= len(offering)
    line = next(line for line in report["airbases"] if "dynamic slots on" in line)
    assert "(blue)" in line or "(red)" in line
    assert "linked" in line


def test_presets_are_given_per_radio_layout_with_the_types_carrying_it(report: dict) -> None:
    assert any(line.startswith("blue, 3 radios, ") and "A-10C_2" in line for line in report["presets"])
    assert all(":" in line for line in report["presets"])


def test_the_counters_make_a_zero_visible(report: dict) -> None:
    counters = report["counters"]
    assert set(counters) == {"presets_injected", "routes_on_player_groups", "warehouse_links", "dead_links", "variants"}
    assert counters["presets_injected"] > 0
    assert counters["warehouse_links"] > 0


def test_the_weather_and_the_bullseye_are_read(report: dict) -> None:
    assert report["weather"][0].startswith("main:") and " kt " in report["weather"][0]
    assert {"blue", "red"} <= set(report["bullseye"])


def test_tankers_and_awacs_carry_their_frequency(report: dict) -> None:
    assert any("tanker" in line and "MHz" in line for line in report["support"])
    assert any("AWACS" in line for line in report["support"])


def test_a_section_the_mission_lacks_is_said_absent(tmp_path: Path) -> None:
    """Nothing skipped: an empty section reads `absent`, so the AI cannot take silence for a pass."""
    miz = tmp_path / "bare.miz"
    shutil.copy2(BUILT, miz)
    mission = read_miz(miz)
    for side in (mission.mission_content or {})["coalition"].values():
        side.pop("bullseye", None)
        for country in side.get("country") or []:
            for category in ("plane", "helicopter"):
                country.pop(category, None)
    mission.warehouses_content = {"airports": {}, "warehouses": {}}
    write_miz(mission, miz)

    bare = inspect_built_mission(miz)

    for section in ("airbases", "farps_and_ships", "presets", "bullseye", "support"):
        assert bare[section] == "absent", section
    assert bare["counters"]["presets_injected"] == 0


def test_a_folder_resolves_to_its_built_miz_and_lists_its_weather_variants(tmp_path: Path) -> None:
    (tmp_path / "mission.yaml").write_text("mission:\n  name: test\n", encoding="utf-8")
    shutil.copy2(BUILT, tmp_path / "test_20261020.miz")
    (tmp_path / "missions").mkdir()
    shutil.copy2(BUILT, tmp_path / "missions" / "test_dawn.miz")

    result = inspect_built_mission(tmp_path)

    assert Path(result["miz"]).name == "test_20261020.miz"
    assert [line.split(":")[0] for line in result["weather"]] == ["main", "test_dawn"]
    assert result["counters"]["variants"] == 1


def test_an_unbuilt_folder_is_refused(tmp_path: Path) -> None:
    (tmp_path / "mission.yaml").write_text("mission:\n  name: test\n", encoding="utf-8")

    with pytest.raises(ValueError, match="build"):
        inspect_built_mission(tmp_path)


def test_the_answer_stays_small(report: dict) -> None:
    """Compact by design: one line per item, no raw table — it stays in the AI's context to the end.

    Listing every base's types made 40 000 characters; the shipped default mission, built, reads 5 000.
    """
    assert len(json.dumps(report, indent=2)) < 3_000
    assert len(json.dumps(inspect_built_mission(LARGE), indent=2)) < 15_000


def test_the_action_is_in_the_catalogue() -> None:
    from veaf_mission_mcp.server import CATALOG

    assert CATALOG.run_action("inspect_built_mission", {"mission_path": str(BUILT)})["theatre"]
