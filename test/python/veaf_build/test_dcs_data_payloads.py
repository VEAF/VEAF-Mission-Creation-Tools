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
