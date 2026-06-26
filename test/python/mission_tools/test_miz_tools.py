"""Tests for mission_tools.miz_tools — read_miz / write_miz / create_miz / iter_groups."""

import io
import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import (
    DcsMission,
    Group,
    create_miz,
    extract_resources,
    read_mission_folder,
    read_miz,
    write_miz,
)

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


def _make_mission_folder(tmp_path: Path, *, nested: bool = False) -> Path:
    """Write a loose mission tree (extracted .miz, or VEAF ``src/mission`` when *nested*)."""
    base = tmp_path / "proj"
    root = base / "src" / "mission" if nested else base
    (root / "l10n" / "DEFAULT").mkdir(parents=True, exist_ok=True)
    (root / "mission").write_bytes(MINIMAL_MISSION_LUA)
    (root / "options").write_bytes(MINIMAL_OPTIONS_LUA)
    (root / "warehouses").write_bytes(MINIMAL_WAREHOUSES_LUA)
    (root / "theatre").write_bytes(b"Caucasus")
    (root / "l10n" / "DEFAULT" / "dictionary").write_bytes(b"dictionary = {\n}\n")
    (root / "l10n" / "DEFAULT" / "mapResource").write_bytes(b"mapResource = {\n}\n")
    return base


def _make_miz_with_resources(tmp_path: Path) -> Path:
    """A .miz carrying scripts and l10n assets alongside the data files."""
    miz_path = tmp_path / "rich.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("mission", MINIMAL_MISSION_LUA)
        zf.writestr("options", MINIMAL_OPTIONS_LUA)
        zf.writestr("warehouses", MINIMAL_WAREHOUSES_LUA)
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
        zf.writestr("l10n/DEFAULT/veaf-scripts.lua", b"-- script\n")
        zf.writestr("l10n/DEFAULT/beacon.ogg", b"OGGDATA")
        zf.writestr("l10n/DEFAULT/kneeboard.png", b"PNGDATA")
    return miz_path


# ---------------------------------------------------------------------------
# extract_resources
# ---------------------------------------------------------------------------


class TestExtractResources:
    def test_extracts_scripts_and_assets_only(self, tmp_path: Path) -> None:
        dest = tmp_path / "out"
        names = extract_resources(_make_miz_with_resources(tmp_path), dest)
        # Resources are extracted, preserving the archive layout.
        assert (dest / "l10n" / "DEFAULT" / "veaf-scripts.lua").is_file()
        assert (dest / "l10n" / "DEFAULT" / "beacon.ogg").is_file()
        assert (dest / "l10n" / "DEFAULT" / "kneeboard.png").is_file()
        # Data files already carried by the JSON export are skipped.
        assert not (dest / "mission").exists()
        assert not (dest / "l10n" / "DEFAULT" / "dictionary").exists()
        assert "mission" not in names
        assert "l10n/DEFAULT/veaf-scripts.lua" in names

    def test_returns_empty_when_no_resources(self, tmp_path: Path) -> None:
        dest = tmp_path / "out2"
        assert extract_resources(_make_minimal_miz(tmp_path), dest) == []


# ---------------------------------------------------------------------------
# read_mission_folder
# ---------------------------------------------------------------------------


class TestReadMissionFolder:
    def test_reads_extracted_tree_at_root(self, tmp_path: Path) -> None:
        result = read_mission_folder(_make_mission_folder(tmp_path))
        assert isinstance(result, DcsMission)
        assert result.mission_content == {"name": "TestMission"}
        assert result.theatre_content == "Caucasus"
        assert result.dictionary_content == {}
        assert result.map_resource_content == {}
        assert result.missing_components == []

    def test_reads_veaf_src_mission_layout(self, tmp_path: Path) -> None:
        result = read_mission_folder(_make_mission_folder(tmp_path, nested=True))
        assert result.mission_content == {"name": "TestMission"}
        assert result.theatre_content == "Caucasus"

    def test_matches_read_miz_export_object(self, tmp_path: Path) -> None:
        from mission_tools.mission_exporter import build_export_object

        folder_obj = build_export_object(read_mission_folder(_make_mission_folder(tmp_path)))
        miz_obj = build_export_object(read_miz(_make_minimal_miz(tmp_path)))
        assert folder_obj == miz_obj

    def test_raises_when_no_mission_file(self, tmp_path: Path) -> None:
        (tmp_path / "empty").mkdir()
        with pytest.raises(FileNotFoundError):
            read_mission_folder(tmp_path / "empty")


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
        assert mission.mission_content is not None
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


# ---------------------------------------------------------------------------
# iter_groups (DEEP-001)
# ---------------------------------------------------------------------------


def _make_mission_with_groups(tmp_path: Path) -> Path:
    """Build a .miz with a realistic coalition/country/group structure."""
    mission_lua = b"""mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Enfield 1-1",
                ["units"] = {
                  [1] = {
                    ["type"] = "F-16C_50",
                    ["skill"] = "Client",
                    ["name"] = "Enfield 1-1-1",
                  },
                },
              },
            },
          },
          ["helicopter"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Huey Flight",
                ["units"] = {
                  [1] = {
                    ["type"] = "UH-1H",
                    ["skill"] = "Average",
                    ["name"] = "Huey 1",
                  },
                },
              },
            },
          },
        },
      },
    },
    ["red"] = {
      ["country"] = {
        [1] = {
          ["name"] = "Russia",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Flanker 1",
                ["units"] = {
                  [1] = {
                    ["type"] = "Su-27",
                    ["skill"] = "High",
                    ["name"] = "Flanker 1-1",
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
"""
    miz_path = tmp_path / "groups.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("mission", mission_lua)
        zf.writestr("options", b"options = {}\n")
        zf.writestr("warehouses", b"warehouses = {}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {}\n")
    return miz_path


_REAL_MIZ = Path(__file__).parents[2] / "veaf-tools" / "test.miz"


class TestIterGroups:
    def test_yields_group_instances(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = list(mission.iter_groups())
        assert all(isinstance(g, Group) for g in groups)

    def test_correct_total_count(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = list(mission.iter_groups())
        # blue: 1 plane + 1 helo; red: 1 plane → 3 groups
        assert len(groups) == 3

    def test_human_pilot_detected(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Enfield 1-1"].human_pilot is True

    def test_non_human_group(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Huey Flight"].human_pilot is False
        assert groups["Flanker 1"].human_pilot is False

    def test_aircraft_type_set(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Enfield 1-1"].aircraft_type == "plane"
        assert groups["Huey Flight"].aircraft_type == "helicopter"

    def test_coalition_set(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Enfield 1-1"].coalition == "blue"
        assert groups["Flanker 1"].coalition == "red"

    def test_country_set(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Enfield 1-1"].country == "USA"
        assert groups["Flanker 1"].country == "Russia"

    def test_unit_type_set(self, tmp_path: Path) -> None:
        miz = _make_mission_with_groups(tmp_path)
        mission = read_miz(miz)
        groups = {g.name: g for g in mission.iter_groups()}
        assert groups["Enfield 1-1"].unit_type == "F-16C_50"

    def test_empty_mission_yields_nothing(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"))
        assert list(mission.iter_groups()) == []

    def test_no_coalition_key_yields_nothing(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"), mission_content={})
        assert list(mission.iter_groups()) == []

    @pytest.mark.skipif(not _REAL_MIZ.exists(), reason="test.miz fixture not available")
    def test_real_miz_smoke(self) -> None:
        mission = read_miz(_REAL_MIZ)
        groups = list(mission.iter_groups())
        assert len(groups) >= 1


# ---------------------------------------------------------------------------
# get/set_weather + get/set_options (DEEP-002)
# ---------------------------------------------------------------------------


class TestWeatherAccessors:
    def test_get_weather_returns_none_when_no_content(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"))
        assert mission.get_weather() is None

    def test_get_weather_returns_none_when_key_absent(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"), mission_content={})
        assert mission.get_weather() is None

    def test_get_weather_returns_dict(self) -> None:
        mission = DcsMission(
            file_path=Path("dummy.miz"),
            mission_content={"weather": {"temperature": 15}},
        )
        assert mission.get_weather() == {"temperature": 15}

    def test_set_weather_stores_dict(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"), mission_content={})
        mission.set_weather({"wind": {"speed_mps": 5}})
        assert mission.mission_content is not None
        assert mission.mission_content["weather"] == {"wind": {"speed_mps": 5}}

    def test_set_weather_noop_when_no_content(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"))
        mission.set_weather({"x": 1})  # must not raise
        assert mission.mission_content is None

    def test_set_weather_replaces_existing(self) -> None:
        mission = DcsMission(
            file_path=Path("dummy.miz"),
            mission_content={"weather": {"old_key": True}},
        )
        mission.set_weather({"new_key": 42})
        assert mission.get_weather() == {"new_key": 42}


class TestOptionsAccessors:
    def test_get_options_returns_none_by_default(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"))
        assert mission.get_options() is None

    def test_get_options_returns_stored_dict(self) -> None:
        opts = {"graphics": {"resolution": "1920x1080"}}
        mission = DcsMission(file_path=Path("dummy.miz"), options_content=opts)
        assert mission.get_options() == opts

    def test_set_options_stores_dict(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"))
        mission.set_options({"key": "value"})
        assert mission.get_options() == {"key": "value"}

    def test_set_options_replaces_existing(self) -> None:
        mission = DcsMission(file_path=Path("dummy.miz"), options_content={"old": 1})
        mission.set_options({"new": 2})
        assert mission.get_options() == {"new": 2}
