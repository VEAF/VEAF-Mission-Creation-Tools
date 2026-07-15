import zipfile
from pathlib import Path

import pytest

from mission_tools.miz_tools import read_member
from veaf_mission_mcp.replace_in_files import replace_in_mission_files


def _make_miz(tmp_path: Path) -> Path:
    miz = tmp_path / "mission.miz"
    with zipfile.ZipFile(miz, "w") as zf:
        zf.writestr("mission", b'mission = {\n  ["x"] = 1,\n}\n')
        zf.writestr("l10n/DEFAULT/veaf-config.lua", b'veaf.ForcedLogLevel = "debug"\n')
        zf.writestr("l10n/DEFAULT/mission-script.lua", b"-- debug marker\nlocal x = 1\n")
        zf.writestr("l10n/DEFAULT/beacon.ogg", b"debug-bytes-not-lua")
    return miz


class TestReplaceInMissionFiles:
    def test_plain_replace_across_matching_lua(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        result = replace_in_mission_files(miz, search="debug", replace="info")

        assert result["total_replacements"] == 2  # one in veaf-config, one in mission-script
        assert set(result["files_changed"]) == {
            "l10n/DEFAULT/veaf-config.lua",
            "l10n/DEFAULT/mission-script.lua",
        }
        assert b'"info"' in read_member(miz, "l10n/DEFAULT/veaf-config.lua")

    def test_only_lua_members_are_touched_not_binaries(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        replace_in_mission_files(miz, search="debug", replace="info")

        # the .ogg contained "debug" but is not .lua → untouched
        assert read_member(miz, "l10n/DEFAULT/beacon.ogg") == b"debug-bytes-not-lua"

    def test_never_touches_the_mission_table(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)
        before = read_member(miz, "mission")

        replace_in_mission_files(miz, search="1", replace="9")

        assert read_member(miz, "mission") == before  # mission is outside l10n/DEFAULT/*.lua

    def test_files_glob_narrows_the_target(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        result = replace_in_mission_files(miz, search="debug", replace="info", files="veaf-*.lua")

        assert result["files_changed"] == ["l10n/DEFAULT/veaf-config.lua"]

    def test_regex_replace_with_backreference(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        result = replace_in_mission_files(
            miz, search=r'ForcedLogLevel = "(\w+)"', replace=r'ForcedLogLevel = "\1_X"', regex=True
        )

        assert result["total_replacements"] == 1
        assert b'ForcedLogLevel = "debug_X"' in read_member(miz, "l10n/DEFAULT/veaf-config.lua")

    def test_no_match_makes_no_change_and_no_backup(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        result = replace_in_mission_files(miz, search="not-present-anywhere", replace="x")

        assert result == {"files_changed": [], "total_replacements": 0}
        assert list(miz.parent.glob("mission.*.miz")) == []

    def test_backs_up_before_writing_when_changed(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        replace_in_mission_files(miz, search="debug", replace="info")

        assert len(list(miz.parent.glob("mission.*.miz"))) == 1

    def test_invalid_regex_raises(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        with pytest.raises(ValueError, match="Invalid regular expression"):
            replace_in_mission_files(miz, search="(unclosed", replace="x", regex=True)

    def test_raises_when_not_a_mission(self, tmp_path: Path) -> None:
        miz = tmp_path / "empty.miz"
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("l10n/DEFAULT/x.lua", b"debug")

        with pytest.raises(ValueError, match="Not a valid DCS mission archive"):
            replace_in_mission_files(miz, search="debug", replace="info")
