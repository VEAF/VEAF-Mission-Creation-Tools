"""Tests for mission_tools.miz_tools member helpers (list/read/rewrite)."""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import list_members, read_member, rewrite_miz_members


def _make_miz(tmp_path: Path) -> Path:
    miz = tmp_path / "mission.miz"
    with zipfile.ZipFile(miz, "w") as zf:
        zf.writestr("mission", b"mission = {\n}\n")
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("l10n/DEFAULT/veaf-config.lua", b'veaf.ForcedLogLevel = "debug"\n')
        zf.writestr("l10n/DEFAULT/beacon.ogg", b"OGGDATA")
    return miz


class TestListMembers:
    def test_lists_every_archive_member(self, tmp_path: Path) -> None:
        members = list_members(_make_miz(tmp_path))
        assert set(members) == {"mission", "options", "l10n/DEFAULT/veaf-config.lua", "l10n/DEFAULT/beacon.ogg"}


class TestReadMember:
    def test_returns_member_bytes(self, tmp_path: Path) -> None:
        assert read_member(_make_miz(tmp_path), "l10n/DEFAULT/veaf-config.lua") == b'veaf.ForcedLogLevel = "debug"\n'


class TestRewriteMizMembers:
    def test_replaces_only_the_named_member(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        rewrite_miz_members(miz, {"l10n/DEFAULT/veaf-config.lua": b'veaf.ForcedLogLevel = "info"\n'})

        assert read_member(miz, "l10n/DEFAULT/veaf-config.lua") == b'veaf.ForcedLogLevel = "info"\n'
        # every other member is byte-identical
        assert read_member(miz, "mission") == b"mission = {\n}\n"
        assert read_member(miz, "options") == b"options = {\n}\n"
        assert read_member(miz, "l10n/DEFAULT/beacon.ogg") == b"OGGDATA"

    def test_preserves_the_full_member_set(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)
        before = set(list_members(miz))

        rewrite_miz_members(miz, {"options": b"options = {new}\n"})

        assert set(list_members(miz)) == before

    def test_adds_a_member_that_did_not_exist(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)

        rewrite_miz_members(miz, {"l10n/DEFAULT/extra.lua": b"-- extra\n"})

        assert "l10n/DEFAULT/extra.lua" in list_members(miz)
        assert read_member(miz, "l10n/DEFAULT/extra.lua") == b"-- extra\n"

    def test_does_not_reserialize_untouched_lua_tables(self, tmp_path: Path) -> None:
        # A mission table with unusual spacing must survive verbatim (no luadata normalisation).
        miz = tmp_path / "m.miz"
        quirky = b'mission = {\n    ["x"]   =   42,\n}\n'
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("mission", quirky)
            zf.writestr("l10n/DEFAULT/veaf-config.lua", b"-- cfg\n")

        rewrite_miz_members(miz, {"l10n/DEFAULT/veaf-config.lua": b"-- new cfg\n"})

        assert read_member(miz, "mission") == quirky


class TestRewriteSurvivesATransientLock:
    """The second atomic write of the same kind needs the same guard as `write_miz`."""

    def test_a_single_denied_rename_is_survived(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        import os

        miz = _make_miz(tmp_path)
        real_replace = os.replace
        calls: list[int] = []

        def flaky(src: object, dst: object) -> None:
            calls.append(1)
            if len(calls) == 1:
                raise PermissionError(5, "Access is denied")
            real_replace(src, dst)

        monkeypatch.setattr(os, "replace", flaky)
        monkeypatch.setattr("veaf_libs.atomic_replace.time.sleep", lambda _s: None)

        rewrite_miz_members(miz, {"options": b"options = {new}\n"})

        assert len(calls) == 2, "rewrite_miz_members did not retry the rename"
        assert read_member(miz, "options") == b"options = {new}\n"
        assert not list(tmp_path.glob("veaf_mission_*.miz")), "a temp file was left in the folder"
