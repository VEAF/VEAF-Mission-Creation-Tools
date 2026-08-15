"""`edit_zone` — reshape, move, rename, link and remove a trigger zone.

Ticket 06 of `FEAT-MCP-MUTATION-ACTIONS`. `add_trigger_zone` creates a **circular** zone and nothing
edited one afterwards, so adjusting a VEAF combat zone meant deleting and rebuilding it.

**Two things were measured before writing anything**, as the ticket demanded:

- **A polygon zone's shape**, read out of `test/veaf-tools/demo-mission/veaf-demo-mission.miz`
  (`czBatumi`): `type: 2` with a `verticies` list — DCS's own spelling, kept as-is — while `x`, `y`
  and `radius` stay present. So a polygon is not a circle with extra fields, and the circle's fields
  are not removed when it becomes one.
- **What `veafCombatZone` actually handles.** `veafCombatZone.lua` branches on exactly two types:
  `0` → `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. There is
  **no `else`**, so a zone of any other type silently finds no units at all — which is worse than
  refusing to make one. The action is therefore scoped to 0 and 2.

**David's call on vertex count (2026-08-12)**: accept 3 or more, since "follow the ridge line" is the
use case and the VEAF runtime handles an arbitrary polygon through mist — but **warn** whenever the
count is not 4, because the DCS Mission Editor has no tool to draw or reshape a non-quad zone. The
open question of whether the editor *preserves* one was settled in game on 2026-08-15: a 6-vertex zone
came back byte-identical through a save, so the action warns but does not refuse above four.
"""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.edit_zone import edit_zone

_MISSION_LUA = b"""
mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["ship"] = {
            ["group"] = {
              [1] = {
                ["name"] = "CSG-1",
                ["groupId"] = 30,
                ["units"] = {
                  [1] = {
                    ["name"] = "Stennis",
                    ["type"] = "Stennis",
                    ["unitId"] = 77,
                    ["x"] = -320000.0,
                    ["y"] = 620000.0,
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  ["triggers"] = {
    ["zones"] = {
      [1] = {
        ["name"] = "czKobuleti",
        ["x"] = -328302.0,
        ["y"] = 631221.0,
        ["radius"] = 3048,
        ["zoneId"] = 166,
        ["type"] = 0,
        ["hidden"] = false,
        ["color"] = {1, 1, 1, 0.15},
        ["properties"] = {},
      },
      [2] = {
        ["name"] = "czBatumi",
        ["x"] = -356734.0,
        ["y"] = 617270.0,
        ["radius"] = 4572,
        ["zoneId"] = 670,
        ["type"] = 2,
        ["hidden"] = false,
        ["color"] = {1, 1, 1, 0.15},
        ["properties"] = {},
        ["verticies"] = {
          [1] = {["x"] = -359753.0, ["y"] = 614918.0},
          [2] = {["x"] = -355602.0, ["y"] = 622688.0},
          [3] = {["x"] = -352849.0, ["y"] = 617192.0},
          [4] = {["x"] = -358731.0, ["y"] = 614282.0},
        },
      },
    },
  },
}
"""


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    """A `.miz` holding one circular zone, one real quad zone, and a ship to link to."""
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _values(container: object) -> list:
    """Return a DCS table's entries whether it came back as a 1-based dict or a list."""
    if isinstance(container, dict):
        return list(container.values())
    return list(container) if isinstance(container, list) else []


def _zone(miz_path: Path, name: str) -> dict:
    """Return one zone as written to disk."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    for zone in _values((content.get("triggers") or {}).get("zones")):
        if zone.get("name") == name:
            return zone
    raise AssertionError(f"zone not found: {name}")


def _zone_names(miz_path: Path) -> list[str]:
    """Return every zone name as written to disk."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    return [zone.get("name") for zone in _values((content.get("triggers") or {}).get("zones"))]


class TestReshape:
    """A circle becomes a polygon and back, using DCS's own field names."""

    def test_a_circle_becomes_a_quad(self, miz: Path) -> None:
        edit_zone(
            miz,
            zone_name="czKobuleti",
            vertices=[
                {"x": -328000.0, "y": 631000.0},
                {"x": -327000.0, "y": 632000.0},
                {"x": -326000.0, "y": 631000.0},
                {"x": -327000.0, "y": 630000.0},
            ],
        )
        assert _zone(miz, "czKobuleti")["type"] == 2

    def test_the_vertices_land_under_dcs_own_spelling(self, miz: Path) -> None:
        """`verticies` is how DCS spells it; correcting the typo would write a field it ignores."""
        edit_zone(
            miz,
            zone_name="czKobuleti",
            vertices=[
                {"x": -328000.0, "y": 631000.0},
                {"x": -327000.0, "y": 632000.0},
                {"x": -326000.0, "y": 631000.0},
                {"x": -327000.0, "y": 630000.0},
            ],
        )
        assert len(_values(_zone(miz, "czKobuleti")["verticies"])) == 4

    def test_becoming_a_polygon_keeps_the_circle_fields(self, miz: Path) -> None:
        """Measured on a real quad zone: `x`, `y` and `radius` stay present alongside `verticies`."""
        edit_zone(
            miz,
            zone_name="czKobuleti",
            vertices=[
                {"x": -328000.0, "y": 631000.0},
                {"x": -327000.0, "y": 632000.0},
                {"x": -326000.0, "y": 631000.0},
                {"x": -327000.0, "y": 630000.0},
            ],
        )
        zone = _zone(miz, "czKobuleti")
        assert (zone["radius"], zone["x"]) == (3048, -328302.0)

    def test_a_ridge_line_of_six_points_is_accepted(self, miz: Path) -> None:
        """David's call: the use case is following terrain, and mist handles any polygon."""
        vertices = [{"x": -328000.0 + i * 500, "y": 631000.0 + i * 300} for i in range(6)]
        edit_zone(miz, zone_name="czKobuleti", vertices=vertices)
        assert len(_values(_zone(miz, "czKobuleti")["verticies"])) == 6

    def test_a_vertex_count_other_than_four_warns_about_the_editor(self, miz: Path) -> None:
        """The ME cannot edit a non-quad zone by hand; it *preserves* one through a save, measured
        in game 2026-08-15, so the action warns but does not refuse above four (ticket 04)."""
        vertices = [{"x": -328000.0 + i * 500, "y": 631000.0 + i * 300} for i in range(6)]
        result = edit_zone(miz, zone_name="czKobuleti", vertices=vertices)
        assert any("editor" in warning.lower() for warning in result["warnings"])
        # It is written, not refused: the shape survives a save.
        assert result["changed"]["vertices"]["to"] == 6

    def test_three_vertices_a_ridge_line_warns_but_is_accepted(self, miz: Path) -> None:
        # The docstring's ridge-line example: fewer than four is as valid as more, and equally
        # uneditable by hand in the ME — so it warns and is still written.
        vertices = [{"x": -328000.0, "y": 631000.0}, {"x": -327000.0, "y": 632000.0}, {"x": -326000.0, "y": 631000.0}]
        result = edit_zone(miz, zone_name="czKobuleti", vertices=vertices)
        assert any("editor" in warning.lower() for warning in result["warnings"])
        assert result["changed"]["vertices"]["to"] == 3

    def test_exactly_four_vertices_does_not_warn(self, miz: Path) -> None:
        result = edit_zone(
            miz,
            zone_name="czKobuleti",
            vertices=[
                {"x": -328000.0, "y": 631000.0},
                {"x": -327000.0, "y": 632000.0},
                {"x": -326000.0, "y": 631000.0},
                {"x": -327000.0, "y": 630000.0},
            ],
        )
        assert not any("editor" in warning.lower() for warning in result["warnings"])

    def test_fewer_than_three_vertices_is_refused(self, miz: Path) -> None:
        """Two points are a line, and `mist.getUnitsInPolygon` would contain nothing."""
        with pytest.raises(ValueError, match="three"):
            edit_zone(miz, zone_name="czKobuleti", vertices=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}])

    def test_a_vertex_missing_a_coordinate_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="x"):
            edit_zone(
                miz,
                zone_name="czKobuleti",
                vertices=[{"x": 0.0, "y": 0.0}, {"y": 1.0}, {"x": 2.0, "y": 2.0}],
            )

    def test_a_polygon_can_go_back_to_a_circle(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czBatumi", make_circular=True, radius=5000)
        zone = _zone(miz, "czBatumi")
        assert (zone["type"], zone.get("verticies")) == (0, None)

    def test_reshaping_reports_the_type_change(self, miz: Path) -> None:
        result = edit_zone(miz, zone_name="czBatumi", make_circular=True)
        assert result["changed"]["type"] == {"from": 2, "to": 0}


class TestMoveResizeRename:
    """The cheap half, and the one refusal that protects the runtime."""

    def test_a_zone_moves_to_a_target(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", position={"x": -320000.0, "y": 630000.0})
        zone = _zone(miz, "czKobuleti")
        assert (zone["x"], zone["y"]) == (-320000.0, 630000.0)

    def test_moving_a_polygon_carries_its_vertices(self, miz: Path) -> None:
        """Otherwise the shape stays behind and the zone covers terrain nobody chose."""
        before = [(v["x"], v["y"]) for v in _values(_zone(miz, "czBatumi")["verticies"])]
        edit_zone(miz, zone_name="czBatumi", position={"x": -350000.0, "y": 617270.0})
        after = [(v["x"], v["y"]) for v in _values(_zone(miz, "czBatumi")["verticies"])]
        deltas = {(round(a[0] - b[0], 3), round(a[1] - b[1], 3)) for a, b in zip(after, before, strict=True)}
        assert len(deltas) == 1

    def test_a_zone_can_be_resized(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", radius=6000)
        assert _zone(miz, "czKobuleti")["radius"] == 6000

    def test_a_radius_of_zero_or_less_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="radius"):
            edit_zone(miz, zone_name="czKobuleti", radius=0)

    def test_a_zone_can_be_renamed(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", new_name="czKobuletiNorth")
        assert "czKobuletiNorth" in _zone_names(miz)

    def test_renaming_onto_an_existing_zone_is_refused(self, miz: Path) -> None:
        """Zones are referenced **by name** from mission.yaml, so two of a name is an ambiguity."""
        with pytest.raises(ValueError, match="already"):
            edit_zone(miz, zone_name="czKobuleti", new_name="czBatumi")

    def test_renaming_warns_that_references_do_not_follow(self, miz: Path) -> None:
        """A combat zone is wired by zone name in `mission.yaml` and by group-name prefix."""
        result = edit_zone(miz, zone_name="czKobuleti", new_name="czKobuletiNorth")
        assert any("reference" in warning.lower() for warning in result["warnings"])


class TestLinkAndRemove:
    """Following a carrier, and dropping a zone."""

    def test_a_zone_can_be_linked_to_a_unit(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", link_unit="Stennis")
        assert _zone(miz, "czKobuleti")["linkUnit"] == 77

    def test_linking_stores_the_unit_id_not_its_name(self, miz: Path) -> None:
        """DCS links by `unitId`; writing the name would be a field it ignores."""
        edit_zone(miz, zone_name="czKobuleti", link_unit="Stennis")
        assert isinstance(_zone(miz, "czKobuleti")["linkUnit"], int)

    def test_linking_to_a_missing_unit_is_refused_naming_it(self, miz: Path) -> None:
        """The ticket left this open; refusing is the choice — a dangling link is silent in game."""
        with pytest.raises(ValueError, match="Nimitz"):
            edit_zone(miz, zone_name="czKobuleti", link_unit="Nimitz")

    def test_a_link_can_be_removed(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", link_unit="Stennis")
        edit_zone(miz, zone_name="czKobuleti", link_unit="")
        assert "linkUnit" not in _zone(miz, "czKobuleti")

    def test_a_zone_can_be_removed(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", remove=True)
        assert _zone_names(miz) == ["czBatumi"]

    def test_removing_reports_what_went(self, miz: Path) -> None:
        result = edit_zone(miz, zone_name="czKobuleti", remove=True)
        assert result["changed"]["removed"]["zone_id"] == 166

    def test_removing_warns_that_a_combat_zone_may_reference_it(self, miz: Path) -> None:
        result = edit_zone(miz, zone_name="czKobuleti", remove=True)
        assert any("reference" in warning.lower() for warning in result["warnings"])

    def test_remove_refuses_to_combine_with_another_change(self, miz: Path) -> None:
        """Editing a zone and deleting it in one call cannot both be what the caller meant."""
        with pytest.raises(ValueError, match="remove"):
            edit_zone(miz, zone_name="czKobuleti", remove=True, radius=5000)


class TestResultAndBackup:
    """Same contract as its siblings."""

    def test_an_unknown_zone_names_what_exists(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="czBatumi"):
            edit_zone(miz, zone_name="czNope", radius=1000)

    def test_nothing_to_change_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="no change given"):
            edit_zone(miz, zone_name="czKobuleti")

    def test_the_result_carries_previous_values(self, miz: Path) -> None:
        result = edit_zone(miz, zone_name="czKobuleti", radius=6000)
        assert result["changed"]["radius"] == {"from": 3048, "to": 6000}

    def test_a_backup_is_taken_before_the_write(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", radius=6000)
        assert len([path for path in miz.parent.glob("*.miz") if path != miz]) == 1

    def test_a_refused_edit_leaves_the_mission_untouched(self, miz: Path) -> None:
        before = miz.read_bytes()
        with pytest.raises(ValueError):
            edit_zone(miz, zone_name="czKobuleti", radius=-5)
        assert miz.read_bytes() == before

    def test_the_zone_reads_back_after_the_write(self, miz: Path) -> None:
        edit_zone(miz, zone_name="czKobuleti", radius=6000)
        assert read_miz(miz).mission_content is not None
