"""adapt_scaffold — steps 1 to 5 of the authoring guide in one action (MCP-CONTEXT-BUDGET).

The folder comes from `veaf-tools prepare --template standard --theatre caucasus`, in process: what
`scaffold_mission` lays down after its download, without the network.
"""

from pathlib import Path

import pytest
import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from mission_tools.miz_tools import read_mission_folder
from typer.testing import CliRunner
from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.adapt_scaffold import adapt_scaffold
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_tools.app import app


@pytest.fixture(scope="module")
def scaffold(tmp_path_factory: pytest.TempPathFactory) -> Path:
    folder = tmp_path_factory.mktemp("scaffold")
    result = CliRunner().invoke(app, ["prepare", "--template", "standard", "--theatre", "caucasus", str(folder), "--force"])
    assert result.exit_code == 0, result.output
    return folder


@pytest.fixture
def folder(scaffold: Path, tmp_path: Path) -> Path:
    import shutil

    copy = tmp_path / "mission"
    shutil.copytree(scaffold, copy)
    return copy


def _yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def test_every_file_of_the_guide_is_adapted_in_one_call(folder: Path) -> None:
    result = adapt_scaffold(
        folder,
        mission_name="Test-Beslan",
        era="COLD_WAR",
        date="1985-06-10",
        start_time="07:30",
        position={"latitude": 43.2, "longitude": 44.6},
        airfields=["Beslan", "mozdok", "Nalchik"],
        waypoints=[{"name": "Push", "x": -150000, "y": 830000}, {"name": "IP Beslan", "x": -155000, "y": 838000, "alt": 1500}],
        dynamic_slot_coalitions=["blue"],
        skynet=True,
    )

    assert len(result["changes"]) == 6
    presets = _yaml(folder / "src" / "presets.yaml")
    assert presets["channel_lists"]["blue"]["primary_2"] == {1: "Beslan", 2: "Mozdok", 3: "Nalchik"}
    assert [name for name in presets["channels_collection"] if name.startswith("airports-")] == ["airports-caucasus"]
    versions = _yaml(folder / "src" / "versions.yaml")
    assert versions["base_date"] == "1985-06-10"
    assert versions["position"] == {"latitude": 43.2, "longitude": 44.6, "timezone": "Etc/GMT-3"}
    assert (versions["versions"][0]["name"], versions["versions"][0]["time"]) == ("morning", "07:30")
    waypoints = _yaml(folder / "src" / "waypoints.yaml")
    assert list(waypoints["waypoints"]) == ["PUSH", "IP_BESLAN"]
    assert waypoints["waypoints"]["IP_BESLAN"]["alt"] == 1500
    assert waypoints["settings"]["every_player_flight"]["waypoints"] == ["PUSH", "IP_BESLAN"]
    slots = _yaml(folder / "src" / "dynamic-slot-templates.yaml")
    assert set(slots["airplanes"]["coalitions"]) == {"blue"}
    assert slots["airplanes"]["coalitions"]["blue"], "the shipped blue templates are copied"
    mission_yaml = _yaml(folder / "mission.yaml")
    assert (mission_yaml["mission"]["name"], mission_yaml["mission"]["era"]) == ("Test-Beslan", "COLD_WAR")
    assert mission_yaml["modules"]["SKYNET"] is True
    date = read_mission_folder(folder / "src" / "mission").mission_content["date"]
    assert (date["Year"], date["Month"], date["Day"]) == (1985, 6, 10)


def test_with_nothing_given_only_what_is_always_wrong_changes(folder: Path) -> None:
    before = {name: (folder / "src" / name).read_text(encoding="utf-8") for name in ("versions.yaml", "dynamic-slot-templates.yaml")}
    mission_before = (folder / "mission.yaml").read_text(encoding="utf-8")

    result = adapt_scaffold(folder)

    assert _yaml(folder / "src" / "waypoints.yaml")["waypoints"] == {}
    assert "BULLSEYE only" in result["changes"][2]
    assert [n for n in _yaml(folder / "src" / "presets.yaml")["channels_collection"] if n.startswith("airports-")] == [
        "airports-caucasus"
    ]
    for name, text in before.items():
        assert (folder / "src" / name).read_text(encoding="utf-8") == text
    assert (folder / "mission.yaml").read_text(encoding="utf-8") == mission_before


def test_the_presets_file_shrinks_to_its_theatre(folder: Path) -> None:
    """The scaffold's plan was 48 777 bytes, every theatre's airfields: what a model used to read."""
    size = (folder / "src" / "presets.yaml").stat().st_size
    adapt_scaffold(folder)
    assert (folder / "src" / "presets.yaml").stat().st_size < size / 3


def test_a_position_on_the_map_is_converted(folder: Path) -> None:
    adapt_scaffold(folder, position={"x": -158841, "y": 842000})
    position = _yaml(folder / "src" / "versions.yaml")["position"]
    assert 42.5 < position["latitude"] < 43.5 and 44 < position["longitude"] < 45


@pytest.mark.parametrize(
    ("kwargs", "message"),
    [
        ({"era": "VICTORIAN"}, "era must be one of"),
        ({"date": "10/06/1985"}, "is not YYYY-MM-DD"),
        ({"start_time": "7h30"}, "is not HH:MM"),
        ({"mission_name": "Mission-Été"}, "ASCII"),
        ({"position": {"latitude": 43}}, "position needs"),
        ({"waypoints": [{"x": 1, "y": 2}]}, "waypoints[0] needs a name"),
        ({"dynamic_slot_coalitions": ["green"]}, "not green"),
        ({"airfields": ["Batumi", "Nevatim"]}, "no airfield ['Nevatim'] on Caucasus"),
    ],
)
def test_a_bad_value_is_refused_before_anything_is_written(folder: Path, kwargs: dict, message: str) -> None:
    before = {path: path.read_bytes() for path in (folder / "src").glob("*.yaml")}
    with pytest.raises(ValueError, match=message.replace("[", r"\[").replace("]", r"\]")):
        adapt_scaffold(folder, **kwargs)
    assert {path: path.read_bytes() for path in (folder / "src").glob("*.yaml")} == before


def test_the_action_is_in_the_catalogue(folder: Path) -> None:
    catalog = ActionCatalog()
    register_default_actions(catalog)
    result = catalog.run_action("adapt_scaffold", {"mission_path": str(folder), "skynet": True})
    assert result["changes"][-1] == "mission.yaml: SKYNET on."
