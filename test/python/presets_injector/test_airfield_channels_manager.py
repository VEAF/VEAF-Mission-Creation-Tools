"""Tests for choosing a mission's airfield channels (FEAT-AIRFIELD-CHANNELS-FROM-DCS ticket 02)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml
from mission_tools.miz_tools import DcsMission
from presets_injector import airfield_channels_manager as M

_REFERENCE: dict[int, dict[str, Any]] = {
    22: {"name": "Batumi", "uhf": 260.0, "vhf": 131.0, "fm": 40.4, "tacan": "16X"},
    18: {"name": "Sochi-Adler", "uhf": 256.0, "vhf": 127.0, "fm": 39.6},
    13: {"name": "Krasnodar-Center", "uhf": 251.0, "vhf": 122.0, "fm": 38.6},
    19: {"name": "Krasnodar-Pashkovsky", "uhf": 257.0, "vhf": 128.0, "fm": 39.8},
    31: {"name": "Vaziani", "uhf": 269.0, "vhf": 140.0, "fm": 42.2, "tacan": "22X"},
    24: {"name": "Kobuleti", "uhf": 262.0, "vhf": 133.0, "fm": 40.8, "tacan": "67X"},
}


def _slot_group(airdrome_id: int, units: int, *, template: bool = False) -> dict[str, Any]:
    group: dict[str, Any] = {
        "name": f"slot {airdrome_id}",
        "units": [{"type": "F-16C_50", "skill": "Client"} for _ in range(units)],
        "route": {"points": [{"type": "TakeOffParking", "airdromeId": airdrome_id}]},
    }
    if template:
        group["dynSpawnTemplate"] = True
    return group


def _mission(airports: dict[int, dict[str, Any]], groups: list[dict[str, Any]] | None = None) -> DcsMission:
    content = {"coalition": {"blue": {"country": [{"name": "CJTF Blue", "plane": {"group": groups or []}}]}}}
    return DcsMission(
        file_path=Path("mission"),
        mission_content=content,
        theatre_content="Caucasus",
        warehouses_content={"airports": airports},
    )


_AIRPORTS = {
    22: {"coalition": "BLUE", "dynamicSpawn": True},
    31: {"coalition": "BLUE", "dynamicSpawn": False},
    24: {"coalition": "BLUE", "dynamicSpawn": True},
    13: {"coalition": "RED", "dynamicSpawn": False},
    18: {"coalition": "NEUTRAL"},
}


def test_candidates_rank_held_with_slots_first_and_hide_neutral() -> None:
    mission = _mission(_AIRPORTS, [_slot_group(31, 4), _slot_group(24, 2, template=True)])
    got = M.list_candidates(mission, {}, {}, _REFERENCE)
    assert [(c.name, c.tier, c.parked_slots) for c in got] == [
        ("Vaziani", 0, 4),  # parked slots
        ("Batumi", 0, 0),  # dynamic slots
        ("Kobuleti", 0, 0),  # a template is not a parked slot, its dynamic slots still count
        ("Krasnodar-Center", 1, 0),  # red, no slot: offered on the same footing, lower
    ]
    assert got[1].freqs == {"uhf": 260.0, "vhf": 131.0, "fm": 40.4} and got[1].tacan == "16X"


def test_neutral_airfields_are_listed_on_request() -> None:
    got = M.list_candidates(_mission(_AIRPORTS), {}, {}, _REFERENCE, include_neutral=True)
    assert got[-1].name == "Sochi-Adler" and got[-1].tier == 2


def test_warehouses_yaml_decides_the_dynamic_slots_as_the_build_does() -> None:
    config = {"blue": {"defaults": {}, "exclude_airports": ["Batumi"]}, "red": {"airports": {"Krasnodar-Center": {}}}}
    got = {c.name: c.dynamic_slots for c in M.list_candidates(_mission(_AIRPORTS), config, {}, _REFERENCE)}
    assert got == {"Batumi": False, "Vaziani": True, "Kobuleti": True, "Krasnodar-Center": True}


def test_existing_alias_is_recognised_by_name_or_unambiguous_first_word() -> None:
    names = [e["name"] for e in _REFERENCE.values()]
    bases = {"Base-Sochi": {"title": "Sochi"}, "Base-Krasnodar": {"title": "Krasnodar"}, "VAZ": {"title": "Vaziani"}}
    assert M.match_existing(bases, "Sochi-Adler", names) == "Base-Sochi"
    assert M.match_existing(bases, "Vaziani", names) == "VAZ"
    assert M.match_existing(bases, "Krasnodar-Center", names) is None  # two Krasnodar: would be a guess


def test_plan_keeps_aliases_writes_real_frequencies_and_leaves_the_rest() -> None:
    bases = {
        "Base-Sochi": {"title": "Sochi", "freqs": {"uhf": 270.1, "vhf": 130.1}},
        "Base-FARP-London": {"title": "FARP London", "freqs": {"fm": 31.0}},
    }
    planned, untouched = M.plan_bases(bases, ["Sochi-Adler", 22], _REFERENCE, "Caucasus")
    assert planned == {
        "Base-Sochi": {"title": "Sochi-Adler", "freqs": {"uhf": 256.0, "vhf": 127.0, "fm": 39.6}},
        "Base-Batumi": {"title": "Batumi / 16X", "freqs": {"uhf": 260.0, "vhf": 131.0, "fm": 40.4}},
    }
    assert untouched == ["Base-FARP-London"]


_GERMANY: dict[int, dict[str, Any]] = {
    5: {"name": "Buchel", "uhf": 251.0, "tacan": "118X"},
    7: {"name": "Norvenich", "uhf": 252.0, "tacan": "77X"},
}


def test_accents_fold_when_matching_an_existing_channel() -> None:
    names = [e["name"] for e in _GERMANY.values()]
    bases = {"BCH": {"title": "Büchel"}, "Base-Nörvenich": {"title": "Norvenich / 77X"}}
    assert M.match_existing(bases, "Buchel", names) == "BCH"
    assert M.match_existing(bases, "Norvenich", names) == "Base-Nörvenich"


def test_plan_keeps_the_authors_spelling_and_refreshes_the_tacan() -> None:
    bases = {"BCH": {"title": "Büchel"}, "Base-Norvenich": {"title": "Nörvenich / 12X"}}
    planned, _ = M.plan_bases(bases, ["Buchel", "Norvenich"], _GERMANY, "GermanyCW")
    assert list(planned) == ["BCH", "Base-Norvenich"]  # matched, not duplicated as Base-Buchel
    assert planned["BCH"]["title"] == "Büchel / 118X"
    assert planned["Base-Norvenich"]["title"] == "Nörvenich / 77X"


def test_plan_keeps_an_accented_title_already_up_to_date() -> None:
    planned, _ = M.plan_bases({"Base-Buchel": {"title": "Büchel / 118X"}}, [5], _GERMANY, "GermanyCW")
    assert planned["Base-Buchel"]["title"] == "Büchel / 118X"


def test_plan_replaces_a_title_naming_something_else() -> None:
    planned, _ = M.plan_bases({"Base-Buchel": {"title": "Home plate"}}, [5], _GERMANY, "GermanyCW")
    assert planned["Base-Buchel"]["title"] == "Buchel / 118X"


def test_plan_refuses_an_airfield_dcs_does_not_declare() -> None:
    with pytest.raises(ValueError, match="Gotham"):
        M.plan_bases({}, ["Batumi", "Gotham"], _REFERENCE, "Caucasus")


_PLAN = {"Base-Sochi": {"title": "Sochi-Adler", "freqs": {"uhf": 256.0, "vhf": 127.0}}}

_PRESETS_CRLF = (
    "channel_lists:\r\n"
    "  blue:\r\n"
    "    primary_1:\r\n"
    "      01: { title: Guard/UHF, channel: Guard }   # kept as typed\r\n"
    "channels_collection:\r\n"
    "  tactical:\r\n"
    "    Guard: { title: Guard, freqs: { uhf: 243, vhf: 121.5 } }\r\n"
    "  bases:\r\n"
    "    Base-FARP-London:\r\n"
    "      title: FARP London\r\n"
    "      freqs: { fm: 31.0 }\r\n"
    "    Base-Sochi: # home field\r\n"
    "      title: Sochi\r\n"
    "      freqs: { uhf: 270.1, vhf: 130.1 }\r\n"
    "\r\n"
    "  flights:\r\n"
    "    Archer: { title: Archer, freqs: { vhf: 120.0 } }\r\n"
)


def test_rewrite_changes_only_the_lines_of_the_written_entries() -> None:
    out = M.rewrite_bases_text(_PRESETS_CRLF, _PLAN)
    assert out == _PRESETS_CRLF.replace(
        "      title: Sochi\r\n      freqs: { uhf: 270.1, vhf: 130.1 }\r\n",
        "      title: Sochi-Adler\r\n      freqs: { uhf: 256.0, vhf: 127.0 }\r\n",
    )
    assert M.rewrite_bases_text(out, _PLAN) == out


def test_rewrite_appends_a_new_entry_at_the_end_of_the_collection() -> None:
    plan = {"Base-Batumi": {"title": "Batumi / 16X", "freqs": {"uhf": 260.0}}}
    out = M.rewrite_bases_text(_PRESETS_CRLF, plan)
    assert out == _PRESETS_CRLF.replace(
        "      freqs: { uhf: 270.1, vhf: 130.1 }\r\n",
        "      freqs: { uhf: 270.1, vhf: 130.1 }\r\n    Base-Batumi:\r\n      title: Batumi / 16X\r\n"
        "      freqs: { uhf: 260.0 }\r\n",
    )
    assert yaml.safe_load(out)["channels_collection"]["flights"]["Archer"]["title"] == "Archer"


def test_rewrite_creates_the_collection_when_missing() -> None:
    text = "channels_collection:\n    flights:\n      Archer: {title: Archer, freqs: {vhf: 120.0}}\n"
    out = M.rewrite_bases_text(text, _PLAN)
    assert out.startswith(text)
    assert yaml.safe_load(out)["channels_collection"]["bases"]["Base-Sochi"]["freqs"] == {"uhf": 256.0, "vhf": 127.0}
    assert "{uhf: 256.0, vhf: 127.0}" in out  # the file's own flow style
    assert yaml.safe_load(M.rewrite_bases_text("channel_lists: {}\n", _PLAN))["channels_collection"]["bases"]


def _folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, mission: DcsMission) -> Path:
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "presets.yaml").write_text(
        "# the mission's radio plan\n"
        "channel_lists:\n"
        "  blue:\n"
        "    primary_1:\n"
        "      01: Base-Sochi  # home\n"
        "channels_collection:\n"
        "  flights:\n"
        "    Archer: { title: Archer, freqs: { vhf: 120.0 } }\n"
        "  bases:\n"
        "    Base-Sochi:\n"
        "      title: Sochi\n"
        "      freqs: { uhf: 270.1, vhf: 130.1 }\n",
        encoding="utf-8",
    )
    monkeypatch.setattr("mission_tools.miz_tools.read_mission_folder", lambda _folder: mission)
    monkeypatch.setattr(M, "load_reference", lambda _theatre: _REFERENCE)
    return tmp_path


def test_apply_writes_bases_only_and_is_idempotent(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = _folder(tmp_path, monkeypatch, _mission(_AIRPORTS))
    result = M.apply_airfield_channels(folder, ["Sochi-Adler", "Batumi"])
    assert result == {
        "written": True,
        "channels": ["Base-Sochi", "Base-Batumi"],
        "untouched": [],
        "not_on_a_radio": ["Base-Batumi"],
    }
    text = (folder / "src" / "presets.yaml").read_text(encoding="utf-8")
    assert "# the mission's radio plan" in text and "# home" in text
    data = yaml.safe_load(text)
    assert data["channels_collection"]["bases"]["Base-Sochi"]["freqs"] == {"uhf": 256.0, "vhf": 127.0, "fm": 39.6}
    assert data["channels_collection"]["flights"]["Archer"]["freqs"] == {"vhf": 120.0}

    again = M.apply_airfield_channels(folder, ["Sochi-Adler", "Batumi"])
    assert again["written"] is False
    assert (folder / "src" / "presets.yaml").read_text(encoding="utf-8") == text


def test_describe_lists_candidates_and_what_is_on_a_radio(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = _folder(tmp_path, monkeypatch, _mission(_AIRPORTS))
    report = M.describe_airfield_channels(folder)
    assert report["theatre"] == "Caucasus"
    assert report["bases_channels"] == ["Base-Sochi"] and report["on_a_radio"] == ["Base-Sochi"]
    assert report["candidates"][0]["name"] == "Batumi"


def test_apply_refuses_an_empty_choice(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = _folder(tmp_path, monkeypatch, _mission(_AIRPORTS))
    with pytest.raises(ValueError):
        M.apply_airfield_channels(folder, [])


def test_plan_keeps_the_keys_the_author_set_on_an_existing_entry() -> None:
    bases = {"Base-Sochi": {"title": "Sochi", "freqs": {"uhf": 270.1}, "color": "green", "priority": 1}}
    planned, _ = M.plan_bases(bases, ["Sochi-Adler"], _REFERENCE, "Caucasus")
    assert planned["Base-Sochi"]["color"] == "green" and planned["Base-Sochi"]["priority"] == 1
    out = M.rewrite_bases_text("channels_collection:\n  bases:\n    Base-Sochi:\n      title: Sochi\n", planned)
    entry = yaml.safe_load(out)["channels_collection"]["bases"]["Base-Sochi"]
    assert entry == {
        "title": "Sochi-Adler",
        "freqs": {"uhf": 256.0, "vhf": 127.0, "fm": 39.6},
        "color": "green",
        "priority": 1,
    }


def test_rewrite_opens_an_empty_flow_collection_into_a_block() -> None:
    for text in ("channels_collection:\n  bases: {}\n  flights: {}\n", "channels_collection: {}\n"):
        out = M.rewrite_bases_text(text, _PLAN)
        assert yaml.safe_load(out)["channels_collection"]["bases"]["Base-Sochi"]["title"] == "Sochi-Adler", text


def test_rewrite_refuses_a_one_line_collection_it_cannot_edit_line_by_line() -> None:
    with pytest.raises(ValueError, match="bases"):
        M.rewrite_bases_text("channels_collection:\n  bases: {Base-X: {title: X}}\n", _PLAN)


def test_the_cli_command_and_the_mcp_actions_reach_the_same_code(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from typer.testing import CliRunner
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog
    from veaf_tools import app as app_mod
    from veaf_tools.commands import airfield_channels as command

    calls: list[tuple[str, Path, Any]] = []
    result = {"written": True, "channels": ["Base-Batumi"], "untouched": [], "not_on_a_radio": []}
    report = {"theatre": "Caucasus", "candidates": [], "bases_channels": [], "on_a_radio": []}

    def fake_apply(folder: Path, airfields: list[Any]) -> dict[str, Any]:
        calls.append(("apply", folder, airfields))
        return result

    def fake_describe(folder: Path, include_neutral: bool = False) -> dict[str, Any]:
        calls.append(("describe", folder, include_neutral))
        return report

    for module in (command, __import__("veaf_mission_mcp.actions", fromlist=["x"])):
        monkeypatch.setattr(module, "apply_airfield_channels", fake_apply)
        monkeypatch.setattr(module, "describe_airfield_channels", fake_describe)

    runner = CliRunner()
    outcome = runner.invoke(app_mod.app, ["airfield-channels", "--apply", "Batumi", "--apply", "22", str(tmp_path)])
    assert outcome.exit_code == 0, outcome.output
    outcome = runner.invoke(app_mod.app, ["airfield-channels", "--neutral", str(tmp_path)])
    assert outcome.exit_code == 0, outcome.output

    catalog = ActionCatalog()
    register_default_actions(catalog)
    assert (
        catalog.run_action("set_airfield_channels", {"mission_path": str(tmp_path), "airfields": ["Batumi", 22]})
        == result
    )
    assert (
        catalog.run_action("describe_airfield_channels", {"mission_path": str(tmp_path), "include_neutral": True})
        == report
    )
    assert calls == [
        ("apply", tmp_path, ["Batumi", "22"]),
        ("describe", tmp_path, True),
        ("apply", tmp_path, ["Batumi", 22]),
        ("describe", tmp_path, True),
    ]
