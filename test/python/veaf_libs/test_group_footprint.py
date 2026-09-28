"""Tests for the worst-case footprint of a group, computed from the data `veafUnits.placeGroup` reads."""

import math
import random
import re
from pathlib import Path

import pytest
from veaf_libs import group_footprint as gf

_LUA = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf"


def _simulate_place_group(group: dict, spacing: float, rng: random.Random) -> float:
    """One draw of `veafUnits.placeGroup` (not a convoy), replayed: the farthest unit from the centre."""
    units = []
    for spec in group.get("units") or []:
        spec = spec if isinstance(spec, dict) else {"type": spec}
        number = spec.get("number", 1)
        copies = (
            rng.randint(int(number.get("min", 1)), int(number.get("max", 1)))
            if isinstance(number, dict)
            else int(number)
        )
        units += [dict(spec)] * copies
    disposition = group.get("disposition") or {
        "h": math.ceil(math.sqrt(len(units))),
        "w": math.ceil(math.sqrt(len(units))),
    }
    rows, cols = int(disposition["h"]), int(disposition["w"])
    cells: dict[int, dict] = {}
    for unit in units:
        if "cell" in unit:
            cells[int(unit["cell"])] = unit
    remaining = [c for c in range(1, rows * cols + 1) if c not in cells]
    for unit in units:
        if "cell" not in unit:
            cells[remaining.pop(rng.randrange(len(remaining)))] = unit
    col_w = [0.0] * cols
    row_h = [0.0] * rows
    size_of = {}
    for number, unit in cells.items():
        row, col = divmod(number - 1, cols)
        size = unit.get("size")
        width = height = float(size) if size is not None else gf.DEFAULT_CELL_METERS
        width, height = width * (1 + spacing), height * (1 + spacing)
        if not unit.get("fitToUnit"):
            width = height = max(width, height)
        size_of[number] = (width, height)
        col_w[col] = max(col_w[col], width)
        row_h[row] = max(row_h[row], height)
    lefts = [sum(col_w[:c]) - sum(col_w) / 2 for c in range(cols)]
    tops = [sum(row_h[:r]) - sum(row_h) / 2 for r in range(rows)]
    farthest = 0.0
    for number, unit in cells.items():
        row, col = divmod(number - 1, cols)
        z = lefts[col] + rng.uniform(col_w[col] / 10, col_w[col] * 0.9)
        x = tops[row] + rng.uniform(row_h[row] / 10, row_h[row] * 0.9)
        if unit.get("random") and spacing > 0:
            half = (spacing - 1) * gf.DEFAULT_CELL_METERS / 2
            z += rng.uniform(-abs(half), abs(half))
            x += rng.uniform(-abs(half), abs(half))
        farthest = max(farthest, math.hypot(x, z))
    return farthest


@pytest.mark.parametrize("alias", ["sa10", "sa11", "sa5", "hawk", "patriot", "sa2", "sa15_squad", "hq7"])
@pytest.mark.parametrize("spacing", [1.0, 5.0])
def test_the_bound_holds_every_draw_of_the_real_groups_and_stays_close(alias: str, spacing: float) -> None:
    group = gf._groups_by_alias()[alias]
    bound = gf.grid_radius(group, spacing)
    rng = random.Random(f"{alias}-{spacing}")
    worst = max(_simulate_place_group(group, spacing, rng) for _ in range(400))
    assert worst <= bound, f"{alias}: a draw reached {worst:.0f} m past the {bound:.0f} m bound"
    assert bound <= 1.6 * worst + 20, f"{alias}: {bound:.0f} m bound for draws reaching {worst:.0f} m"


def test_a_group_with_no_disposition_is_laid_out_on_a_square() -> None:
    group = {"units": [{"type": "a"}, {"type": "b"}, {"type": "c", "number": {"min": 1, "max": 2}}]}
    # Four units at most: a 2 x 2 grid of 10 m cells with no spacing.
    assert gf.grid_radius(group, spacing=0) == pytest.approx(math.hypot(10, 10))


def test_spacing_grows_every_cell_and_a_size_replaces_the_default() -> None:
    group = {"disposition": {"h": 1, "w": 2}, "units": [{"type": "a", "cell": 1}, {"type": "b", "cell": 2, "size": 30}]}
    # Cells of 10 * 2 and 30 * 2, both square.
    assert gf.grid_radius(group, spacing=1) == pytest.approx(math.hypot((20 + 60) / 2, 60 / 2))


def test_a_unit_without_a_cell_may_land_in_any_column_and_row() -> None:
    group = {"disposition": {"h": 1, "w": 3}, "units": [{"type": "a", "cell": 1}, {"type": "big", "size": 50}]}
    # The big unit adds its 50 m to the 10 m column already occupied, in a single row.
    assert gf.grid_radius(group, spacing=0) == pytest.approx(math.hypot((10 + 50) / 2, 50 / 2))


def test_the_s300_battery_at_the_spacing_of_its_shortcut() -> None:
    # `-sa10` is `_spawn group, name sa10, ..., spacing 1`: 13 x 10 cells of 20 m, and the random
    # escorts scatter by (spacing - 1) * 10 / 2 = 0.
    footprint = gf.command_footprint("-sa10")
    assert footprint.radius == pytest.approx(math.hypot(13 * 20 / 2, 10 * 20 / 2))


def test_the_default_spawn_spacing_is_five() -> None:
    footprint = gf.command_footprint("_spawn group, name sa10")
    grid = math.hypot(13 * 60 / 2, 10 * 60 / 2)
    assert footprint.radius == pytest.approx(grid + math.hypot(20, 20))


def test_options_written_after_a_shortcut_override_it() -> None:
    assert gf.command_footprint("-sa10, spacing 3").radius > gf.command_footprint("-sa10").radius
    assert gf.command_footprint("-sa10, radius 200").radius == pytest.approx(gf.command_footprint("-sa10").radius + 200)


def test_random_batteries_take_the_largest_they_can_draw() -> None:
    long_range = gf.command_footprint("-samVLR")
    assert long_range.radius == pytest.approx(
        max(
            gf.command_footprint(f"_spawn group, name {alias}, spacing 1").radius
            for alias in (
                "patriot",
                "hawk",
                "sa10",
                "sa5",
                "sa2",
                "generateAirDefenseGroup-RED-WW2-5",
                "generateAirDefenseGroup-BLUE-WW2-5",
            )
        )
    )
    assert gf.command_footprint("-samLR").radius is not None
    assert gf.command_footprint("-samLR", coalition="blue").radius is not None


def test_groups_assembled_from_dice_rolls_are_left_unknown_and_say_why() -> None:
    for command in (
        "-armor",
        "-infantry",
        "-combat",
        "-transport",
        "_spawn convoy",
        "_spawn group, name sa10, dest 1 2",
    ):
        footprint = gf.command_footprint(command)
        assert footprint.radius is None, command
        assert footprint.reason


def test_a_lone_unit_and_a_non_spawn_command() -> None:
    assert gf.command_footprint("-sa9").radius == 0
    assert gf.command_footprint("-smoke").radius is None, "a smoke is not a ground group"
    assert gf.command_footprint("-destroy").radius is None
    assert gf.command_footprint("_spawn group, name no-such-group").radius is None


def test_a_marker_adds_its_zone_spawn_radius() -> None:
    base = gf.command_footprint("-sa10").radius
    assert gf.marker_footprint('#command="-sa10"').radius == pytest.approx(base + gf.DEFAULT_ZONE_SPAWN_RADIUS)
    assert gf.marker_footprint('#command="-sa10" #spawnradius=100-300').radius == pytest.approx(base + 300)
    assert gf.marker_footprint("Unit #001") is None


def test_the_long_range_list_is_the_lua_table() -> None:
    source = (_LUA / "veafCasMission.lua").read_text(encoding="utf-8")
    block = source[source.index("veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS = {") :]
    block = block[: block.index("\n}\n")]
    assert set(re.findall(r'"([^"]+)"', block)) == set(gf.LONG_RANGE_AIR_DEFENSE_GROUPS)


def test_the_cell_and_zone_defaults_are_the_runtime_ones() -> None:
    units = (_LUA / "veafUnits.lua").read_text(encoding="utf-8")
    assert "veafUnits.DefaultCellWidth = 10\n" in units and "veafUnits.DefaultCellHeight = 10\n" in units
    zone = (_LUA / "veafCombatZone.lua").read_text(encoding="utf-8")
    assert "veafCombatZone.DefaultSpawnRadiusForUnits = 50\n" in zone
    # The box-reading block of processUnit is what makes a unit's real size irrelevant to the grid.
    assert "--[[\n    result.size = { x = veaf.round(dcsUnit.desc.box" in units


def test_isconvoy_does_not_change_the_layout_but_a_destination_does() -> None:
    assert gf.command_footprint("_spawn group, name sa10, isconvoy").radius is not None
    assert "convoy" in gf.command_footprint("_spawn group, name sa10, dest 1 2").reason
