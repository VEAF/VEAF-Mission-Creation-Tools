"""Tests for the surface check at placement (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 04)."""

import zipfile
from array import array
from pathlib import Path

import pytest
from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.terrain_elevation import ElevationGrid, save_grid
from veaf_mission_mcp.add_farp import add_farp
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.set_group_properties import set_group_properties
from veaf_mission_mcp.surface import surface_warnings

#: North of this line (x above it) is land at 3 m, the height DCS gives ground under sea level; south of
#: it, the sea at 0.
_COAST_X = -275000.0
_SEA = {"x": -279000.0, "y": 685000.0}
_LAND = {"x": -271000.0, "y": 685000.0}


@pytest.fixture
def coast(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    grid = GridSpec(-280000.0, 680000.0, 100.0, 101, 101)
    heights = array("h")
    for r in range(grid.rows):
        for c in range(grid.cols):
            x, _y = grid.cell_position(r, c)
            heights.append(3 if x > _COAST_X else 0)
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    save_grid(ElevationGrid("Caucasus", grid, heights), tmp_path / "home" / "terrain" / "Caucasus.terrain")


def _unit(name: str, where: dict[str, float]) -> dict[str, object]:
    return {"name": name, **where}


class TestSurfaceWarnings:
    def test_a_ground_unit_in_the_sea_is_named(self, coast: None) -> None:
        warnings = surface_warnings("Caucasus", [_unit("Avenger-1", _SEA)], afloat=False, label="g")
        assert warnings == ["'Avenger-1' is in the sea: the ground reads 0 m there"]

    def test_three_metres_is_land(self, coast: None) -> None:
        assert surface_warnings("Caucasus", [_unit("Avenger-1", _LAND)], afloat=False, label="g") == []

    def test_a_ship_on_land_is_named_with_the_height(self, coast: None) -> None:
        warnings = surface_warnings("Caucasus", [_unit("Frigate", _LAND)], afloat=True, label="g")
        assert warnings == ["ship 'Frigate' is on land: the ground reads 3 m there"]

    def test_a_ship_at_sea_is_silent(self, coast: None) -> None:
        assert surface_warnings("Caucasus", [_unit("Frigate", _SEA)], afloat=True, label="g") == []

    def test_no_grid_says_it_was_not_checked(self) -> None:
        warnings = surface_warnings("Syria", [_unit("Avenger-1", _SEA)], afloat=False, label="group 'SAM'")
        assert warnings == ["group 'SAM': surface not checked: no elevation grid for Syria"]


@pytest.fixture
def sample_miz(tmp_path: Path) -> Path:
    """A Caucasus `.miz` whose mission table names its theatre, as every saved mission does."""
    miz = tmp_path / "coast.miz"
    lua = (
        b'mission = { ["theatre"] = "Caucasus", ["coalition"] = { ["blue"] = { ["country"] = { } }, '
        b'["red"] = { ["country"] = { } } }, ["triggers"] = { ["zones"] = { } } }'
    )
    with zipfile.ZipFile(miz, "w") as zf:
        zf.writestr("mission", lua)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return miz


class TestThroughTheActions:
    def test_add_group_warns_for_a_battery_in_the_sea(self, coast: None, sample_miz: Path) -> None:
        result = add_group(
            sample_miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            category="vehicle",
            name="SAM Paphos",
            position=_SEA,
            units=[{"type": "M1097 Avenger", "count": 1, "name": "Avenger-1"}],
            keep_position=True,
        )
        assert any("'Avenger-1' is in the sea" in w["warning"] for w in result["warnings"])

    def test_add_farp_warns_for_a_pad_in_the_sea(self, coast: None, sample_miz: Path) -> None:
        result = add_farp(sample_miz, name="FARP Sea", position=_SEA, coalition="blue", country_id=2, country_name="USA")
        assert any("'FARP Sea' is in the sea" in w for w in result["warnings"])

    def test_moving_a_ship_onto_land_warns(self, coast: None, sample_miz: Path) -> None:
        add_group(
            sample_miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            category="ship",
            name="Navy",
            position=_SEA,
            units=[{"type": "PERRY", "count": 1, "name": "Frigate"}],
        )
        result = set_group_properties(sample_miz, group_name="Navy", move_to=_LAND)
        assert any("ship 'Frigate' is on land" in w for w in result["warnings"])
