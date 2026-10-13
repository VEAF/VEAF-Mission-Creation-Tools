"""Tests for the DCS default loadouts generator (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 09)."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from veaf_build.dcs_data import payloads as P

# The shape of MissionEditor/data/scripts/UnitPayloads/<type>.lua, trimmed from MiG-31.lua.
_MIG31 = """local unitPayloads = {
	["name"] = "MiG-31",
	["payloads"] = {
		[1] = {
			["name"] = "R-40T*2,R-33*4",
			["pylons"] = {
				[1] = {
					["CLSID"] = "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}",
					["num"] = 1,
				},
				[2] = {
					["CLSID"] = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}",
					["num"] = 2,
				},
			},
			["tasks"] = {
				[1] = 11,
			},
		},
		[2] = {
			["name"] = "R-40T*2,R-33*4",
			["pylons"] = {
				[1] = {
					["CLSID"] = "{SECOND}",
					["num"] = 1,
				},
			},
		},
	},
	["unitType"] = "MiG-31",
}
return unitPayloads
"""

_EMPTY = 'local unitPayloads = {\n\t["name"] = "A-50",\n\t["payloads"] = {\n\t},\n\t["unitType"] = "A-50",\n}\nreturn unitPayloads\n'


def test_a_file_gives_its_type_and_loadouts_keyed_by_station() -> None:
    parsed = P.parse_payload_file(_MIG31)
    assert parsed is not None
    unit_type, payloads = parsed
    assert unit_type == "MiG-31"
    # A name repeated within the file keeps its first loadout.
    assert payloads == {
        "R-40T*2,R-33*4": {1: "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}", 2: "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"}
    }


def test_the_type_is_the_files_unit_type_not_its_name(tmp_path: Path) -> None:
    folder = tmp_path / P.PAYLOADS_SUBDIR
    folder.mkdir(parents=True)
    (folder / "F-16C.lua").write_text(_MIG31.replace('["unitType"] = "MiG-31"', '["unitType"] = "F-16C bl.52d"'))
    (folder / "A-50.lua").write_text(_EMPTY)
    assert list(P.extract_payloads(tmp_path)) == ["F-16C bl.52d"]


def test_an_install_without_the_folder_is_refused(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="UnitPayloads"):
        P.extract_payloads(tmp_path)


def test_the_yaml_round_trips(tmp_path: Path) -> None:
    out = tmp_path / "payloads.yaml"
    P.write_payloads_yaml({"MiG-31": {"b": {2: "{X}", 1: "{Y}"}, "a": {1: "{Z}"}}}, out)
    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert data == {"MiG-31": {"a": {1: "{Z}"}, "b": {1: "{Y}", 2: "{X}"}}}
    assert list(data["MiG-31"]) == ["a", "b"]


# ── FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 01: the module aircraft keep theirs under CoreMods ──

_P51D = _MIG31.replace('"MiG-31"', '"P-51D"').replace("R-40T*2,R-33*4", "HVAR*6,Fuel75*2")

_REAL_LUA = """local unitPayloads = {
	["name"] = "F-14B",
	["payloads"] = {
		[1] = {
			["name"] = "AIM-54*2",
			["pylons"] = { [1] = { ["CLSID"] = "{A}" .. "B}", ["num"] = 1 } },
			["tasks"] = { [1] = CAP, [2] = Escort },
		},
	},
	["unitType"] = "F-14B",
}
return unitPayloads
"""

_IDENTIFIER_TASKS = _MIG31.replace("[1] = 11,", "[1] = CAP, [2] = Ground").replace('"MiG-31"', '"F-4E-45MC"')


def _module_folder(root: Path, module: str) -> Path:
    folder = root / "CoreMods" / "aircraft" / module / "UnitPayloads"
    folder.mkdir(parents=True)
    return folder


def test_a_module_aircraft_is_read_from_its_core_mods_folder(tmp_path: Path) -> None:
    (tmp_path / P.PAYLOADS_SUBDIR).mkdir(parents=True)
    (_module_folder(tmp_path, "WWII Units") / "P-51D.lua").write_text(_P51D)
    assert P.extract_payloads(tmp_path)["P-51D"]["HVAR*6,Fuel75*2"][1] == "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}"


def test_the_editors_folder_comes_first_and_a_module_adds_the_names_it_lacks(tmp_path: Path) -> None:
    folder = tmp_path / P.PAYLOADS_SUBDIR
    folder.mkdir(parents=True)
    (folder / "MiG-31.lua").write_text(_MIG31)
    (_module_folder(tmp_path, "Other") / "MiG-31.lua").write_text(
        _MIG31.replace("R-40T*2,R-33*4", "Extra").replace("{5F26DBC2", "{OTHER")
    )
    result = P.extract_payloads(tmp_path)["MiG-31"]
    assert set(result) == {"R-40T*2,R-33*4", "Extra"}
    assert result["R-40T*2,R-33*4"][1] == "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}"


def test_identifiers_in_a_tasks_table_do_not_stop_the_file(tmp_path: Path) -> None:
    (tmp_path / P.PAYLOADS_SUBDIR).mkdir(parents=True)
    (_module_folder(tmp_path, "F-4E") / "F-4E-45MC.lua").write_text(_IDENTIFIER_TASKS)
    assert "F-4E-45MC" in P.extract_payloads(tmp_path)


def test_a_file_that_computes_its_clsids_is_reported_not_lost_in_silence(tmp_path: Path) -> None:
    (tmp_path / P.PAYLOADS_SUBDIR).mkdir(parents=True)
    bad = _module_folder(tmp_path, "F14") / "F-14B.lua"
    bad.write_text(_REAL_LUA)
    skipped: list[Path] = []
    assert "F-14B" not in P.extract_payloads(tmp_path, skipped)
    assert skipped == [bad]
    with pytest.raises(Exception):  # noqa: B017, PT011 - luadata's own bare exception
        P.extract_payloads(tmp_path)
