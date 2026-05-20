"""Tests for mission_tools.miz_tools — read_miz / write_miz / create_miz."""

import io
import zipfile
from pathlib import Path

import pytest

from mission_tools.miz_tools import DcsMission, create_miz, read_miz, write_miz

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

MINIMAL_MISSION_LUA = b'mission = {\n  ["name"] = "TestMission",\n}\n'
MINIMAL_OPTIONS_LUA = b"options = {\n}\n"
MINIMAL_WAREHOUSES_LUA = b"warehouses = {\n}\n"


def _make_minimal_miz(tmp_path: Path, *, include_theatre: bool = True) -> Path:
    """Build a minimal .miz archive and return its path."""
    miz_path = tmp_path / "test.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("mission", MINIMAL_MISSION_LUA)
        zf.writestr("options", MINIMAL_OPTIONS_LUA)
        zf.writestr("warehouses", MINIMAL_WAREHOUSES_LUA)
        if include_theatre:
            zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return miz_path


# ---------------------------------------------------------------------------
# read_miz
# ---------------------------------------------------------------------------


class TestReadMiz:
    def test_read_returns_dcsmission(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert isinstance(result, DcsMission)

    def test_read_sets_file_path(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert result.file_path == miz

    def test_read_mission_content_is_dict(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert result.mission_content is not None
        assert isinstance(result.mission_content, dict)

    def test_read_options_content_is_dict(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert result.options_content is not None
        assert isinstance(result.options_content, dict)

    def test_read_warehouses_content_is_dict(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert result.warehouses_content is not None
        assert isinstance(result.warehouses_content, dict)

    def test_read_theatre_content_when_present(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)  # theatre included by default
        result = read_miz(miz)
        assert result.theatre_content == "Caucasus"

    def test_read_no_missing_components_for_minimal(self, tmp_path: Path) -> None:
        miz = _make_minimal_miz(tmp_path)
        result = read_miz(miz)
        assert result.missing_components == []

    def test_read_notes_missing_file(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "sparse.miz"
        with zipfile.ZipFile(miz_path, "w") as zf:
            zf.writestr("mission", MINIMAL_MISSION_LUA)
        result = read_miz(miz_path)
        # options, warehouses, dictionary, mapResource are all missing
        assert "options" in result.missing_components


# ---------------------------------------------------------------------------
# create_miz
# ---------------------------------------------------------------------------


class TestCreateMiz:
    def test_creates_zip_file(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "created.miz"
        create_miz(miz_path, {"mission": MINIMAL_MISSION_LUA})
        assert miz_path.exists()

    def test_created_zip_is_valid(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "created.miz"
        create_miz(miz_path, {"mission": MINIMAL_MISSION_LUA})
        assert zipfile.is_zipfile(miz_path)

    def test_created_zip_contains_files(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "created.miz"
        files = {"mission": MINIMAL_MISSION_LUA, "options": MINIMAL_OPTIONS_LUA}
        create_miz(miz_path, files)
        with zipfile.ZipFile(miz_path) as zf:
            names = zf.namelist()
        assert "mission" in names
        assert "options" in names

    def test_create_with_empty_files_creates_empty_zip(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "empty.miz"
        create_miz(miz_path, {})
        assert zipfile.is_zipfile(miz_path)


# ---------------------------------------------------------------------------
# write_miz
# ---------------------------------------------------------------------------


class TestWriteMiz:
    def test_write_updates_existing_miz(self, tmp_path: Path) -> None:
        original = _make_minimal_miz(tmp_path)
        mission = read_miz(original)
        # Modify mission content and write back to a new path
        output = tmp_path / "output.miz"
        mission.mission_content["modified"] = True
        write_miz(mission, output)
        assert output.exists()
        assert zipfile.is_zipfile(output)

    def test_write_output_is_readable(self, tmp_path: Path) -> None:
        original = _make_minimal_miz(tmp_path)
        mission = read_miz(original)
        output = tmp_path / "roundtrip.miz"
        write_miz(mission, output)
        roundtrip = read_miz(output)
        assert roundtrip.mission_content is not None

    def test_write_additional_files_included(self, tmp_path: Path) -> None:
        original = _make_minimal_miz(tmp_path)
        mission = read_miz(original)
        output = tmp_path / "extra.miz"
        extra = {"extra/readme.txt": b"hello world"}
        write_miz(mission, output, additional_files=extra)
        with zipfile.ZipFile(output) as zf:
            names = zf.namelist()
        assert "extra/readme.txt" in names

    def test_write_without_explicit_path_uses_original(self, tmp_path: Path) -> None:
        original = _make_minimal_miz(tmp_path)
        mission = read_miz(original)
        write_miz(mission, None)
        # File should have been updated
        assert original.exists()
