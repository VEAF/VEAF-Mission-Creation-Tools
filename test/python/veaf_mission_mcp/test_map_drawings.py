"""`add_map_drawing` / `edit_map_drawing` — F10 map drawings that survive a rebuild.

Ticket 07 of `FEAT-MCP-MUTATION-ACTIONS`. Nothing in VMCT touched F10 drawings, so a briefing line,
an ingress corridor or a no-fly box was drawn by hand in the Mission Editor **and lost the moment the
mission was regenerated from its folder**. That is the argument for having it here rather than leaving
it to the editor: a drawing an agent places is part of the recipe.

**Everything asserted here was read out of this repository's own fixtures**, and one measurement
dominates the design:

> **`points` are RELATIVE to the drawing's `mapX`/`mapY` anchor**, the first one being `{0, 0}`.

A drawing written in absolute coordinates lands hundreds of kilometres away and nothing errors — so
the action takes the absolute coordinates a caller actually has and does the anchoring itself.

**Three shapes are shipped because three shapes were measured**: `Line` (with `lineMode` `segment` or
`segments`, and `closed` for a shape that joins up), `Polygon` in `rect` mode (`width`/`height`/
`angle`, no points at all), and `TextBox` (`text`/`font`/`fontSize`, no points either). The remaining
`polygonMode` values (`circle`, `oval`, `free`, `arrow`) and `primitiveType: "Icon"` are **absent from
every fixture**, so their field shapes are unknown — and the ticket's own rule is to read a real `.miz`
rather than assume. They are refused by name, with the measurement listed in `DCS-SESSION-TODO.md`.
"""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.map_drawings import add_map_drawing, edit_map_drawing

_MISSION_LUA = b"""
mission = {
  ["drawings"] = {
    ["options"] = {},
    ["layers"] = {
      [1] = {
        ["name"] = "Red",
        ["visible"] = true,
        ["objects"] = {},
      },
      [2] = {
        ["name"] = "Blue",
        ["visible"] = true,
        ["objects"] = {
          [1] = {
            ["visible"] = true,
            ["hiddenOnPlanner"] = false,
            ["mapX"] = 77107.0,
            ["mapY"] = -265060.0,
            ["primitiveType"] = "Line",
            ["closed"] = false,
            ["thickness"] = 8,
            ["colorString"] = "0xff0000ff",
            ["style"] = "solid",
            ["layerName"] = "Blue",
            ["name"] = "Line-1",
            ["lineMode"] = "segments",
            ["points"] = {
              [1] = {["x"] = 0, ["y"] = 0},
              [2] = {["x"] = 1000, ["y"] = 2000},
            },
          },
        },
      },
      [3] = {
        ["name"] = "Common",
        ["visible"] = true,
        ["objects"] = {},
      },
      [4] = {
        ["name"] = "Author",
        ["visible"] = true,
        ["objects"] = {},
      },
    },
  },
}
"""


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    """A `.miz` with the four drawing layers and one existing line on Blue."""
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


def _objects(miz_path: Path, layer: str) -> list[dict]:
    """Return one layer's drawing objects as written to disk."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    for entry in _values((content.get("drawings") or {}).get("layers")):
        if entry.get("name") == layer:
            return _values(entry.get("objects"))
    raise AssertionError(f"layer not found: {layer}")


class TestTheAnchoringTrap:
    """`points` are relative to `mapX`/`mapY`; absolute ones land a continent away in silence."""

    def test_the_anchor_is_the_first_point_given(self, miz: Path) -> None:
        drawing = add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}],
        )
        written = _objects(miz, "Blue")[-1]
        assert (written["mapX"], written["mapY"]) == (-300000.0, 600000.0)
        assert drawing["name"] == "FSCL"

    def test_the_first_point_becomes_the_origin(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}],
        )
        first = _values(_objects(miz, "Blue")[-1]["points"])[0]
        assert (first["x"], first["y"]) == (0, 0)

    def test_later_points_are_offsets_from_the_anchor(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}],
        )
        second = _values(_objects(miz, "Blue")[-1]["points"])[1]
        assert (second["x"], second["y"]) == (10000.0, 10000.0)


class TestLines:
    """A line, a corridor and a closed shape — the measured `Line` primitive."""

    def test_two_points_are_a_single_segment(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1000.0, "y": 0.0}],
        )
        assert _objects(miz, "Blue")[-1]["lineMode"] == "segment"

    def test_three_points_are_a_polyline(self, miz: Path) -> None:
        """Measured: DCS spells the multi-segment mode `segments`, plural."""
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="Corridor",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1000.0, "y": 0.0}, {"x": 2000.0, "y": 500.0}],
        )
        assert _objects(miz, "Blue")[-1]["lineMode"] == "segments"

    def test_a_closed_line_is_how_a_free_shape_is_drawn(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="Box",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1000.0, "y": 0.0}, {"x": 1000.0, "y": 1000.0}],
            closed=True,
        )
        assert _objects(miz, "Blue")[-1]["closed"] is True

    def test_a_line_needs_at_least_two_points(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="two"):
            add_map_drawing(miz, layer="Blue", shape="line", name="Nope", points=[{"x": 0.0, "y": 0.0}])

    def test_the_colour_and_thickness_can_be_given(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1000.0, "y": 0.0}],
            color="0x00ff00ff",
            thickness=4,
        )
        written = _objects(miz, "Blue")[-1]
        assert (written["colorString"], written["thickness"]) == ("0x00ff00ff", 4)


class TestRectAndTextBox:
    """The two shapes that carry no points at all."""

    def test_a_rect_is_a_polygon_with_width_and_height(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Red",
            shape="rect",
            name="No-fly box",
            position={"x": -23702.0, "y": 456782.0},
            width=53010.0,
            height=49550.0,
        )
        written = _objects(miz, "Red")[-1]
        assert (written["primitiveType"], written["polygonMode"]) == ("Polygon", "rect")

    def test_a_rect_carries_no_points(self, miz: Path) -> None:
        """Measured on a real one: a rect is width/height/angle around its anchor, not a point list."""
        add_map_drawing(
            miz,
            layer="Red",
            shape="rect",
            name="No-fly box",
            position={"x": 0.0, "y": 0.0},
            width=1000.0,
            height=2000.0,
        )
        assert "points" not in _objects(miz, "Red")[-1]

    def test_a_rect_needs_its_dimensions(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="width"):
            add_map_drawing(miz, layer="Red", shape="rect", name="Box", position={"x": 0.0, "y": 0.0})

    def test_a_textbox_carries_its_text(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Common",
            shape="textbox",
            name="Ingress",
            position={"x": -12007.0, "y": 448139.0},
            text="Ingress corridor",
        )
        assert _objects(miz, "Common")[-1]["text"] == "Ingress corridor"

    def test_a_textbox_gets_the_font_dcs_uses(self, miz: Path) -> None:
        """Taken from a real drawing rather than chosen: a font DCS lacks renders as nothing."""
        add_map_drawing(
            miz,
            layer="Common",
            shape="textbox",
            name="Ingress",
            position={"x": 0.0, "y": 0.0},
            text="Ingress",
        )
        assert _objects(miz, "Common")[-1]["font"] == "DejaVuLGCSansCondensed.ttf"

    def test_a_textbox_needs_its_text(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="text"):
            add_map_drawing(miz, layer="Common", shape="textbox", name="Empty", position={"x": 0.0, "y": 0.0})


class TestUnmeasuredShapesAreRefused:
    """The ticket's own rule: read a real `.miz` rather than assume a field shape."""

    @pytest.mark.parametrize("shape", ["circle", "oval", "arrow", "chevron", "icon"])
    def test_a_shape_absent_from_every_fixture_is_refused(self, miz: Path, shape: str) -> None:
        with pytest.raises(ValueError, match="not measured"):
            add_map_drawing(miz, layer="Blue", shape=shape, name="X", position={"x": 0.0, "y": 0.0})

    def test_the_refusal_names_the_shapes_that_do_work(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="rect"):
            add_map_drawing(miz, layer="Blue", shape="circle", name="X", position={"x": 0.0, "y": 0.0})


class TestLayers:
    """The layer decides who sees the drawing, so it is never a default."""

    @pytest.mark.parametrize("layer", ["Red", "Blue", "Common", "Author"])
    def test_each_layer_can_be_drawn_on(self, miz: Path, layer: str) -> None:
        add_map_drawing(
            miz,
            layer=layer,
            shape="line",
            name="X",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
        )
        assert len(_objects(miz, layer)) >= 1

    def test_the_object_records_its_own_layer_name(self, miz: Path) -> None:
        """Every real drawing carries `layerName` beside sitting inside that layer."""
        add_map_drawing(
            miz,
            layer="Red",
            shape="line",
            name="X",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
        )
        assert _objects(miz, "Red")[-1]["layerName"] == "Red"

    def test_an_unknown_layer_is_refused_naming_the_real_ones(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Neutral|Common"):
            add_map_drawing(
                miz,
                layer="Purple",
                shape="line",
                name="X",
                points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
            )

    def test_drawing_on_a_layer_leaves_the_others_alone(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Red",
            shape="line",
            name="X",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
        )
        assert len(_objects(miz, "Blue")) == 1

    def test_a_name_already_used_on_that_layer_is_refused(self, miz: Path) -> None:
        """Editing and removing address a drawing by name, so duplicates make both ambiguous."""
        with pytest.raises(ValueError, match="already"):
            add_map_drawing(
                miz,
                layer="Blue",
                shape="line",
                name="Line-1",
                points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
            )


class TestEditAndRemove:
    """Move, retitle, rename and drop an existing drawing."""

    def test_a_drawing_can_be_moved(self, miz: Path) -> None:
        edit_map_drawing(miz, layer="Blue", name="Line-1", position={"x": -1000.0, "y": -2000.0})
        written = _objects(miz, "Blue")[0]
        assert (written["mapX"], written["mapY"]) == (-1000.0, -2000.0)

    def test_moving_keeps_the_shape_since_points_are_relative(self, miz: Path) -> None:
        """The payoff of relative points: moving the anchor moves the whole drawing."""
        before = [(p["x"], p["y"]) for p in _values(_objects(miz, "Blue")[0]["points"])]
        edit_map_drawing(miz, layer="Blue", name="Line-1", position={"x": -1000.0, "y": -2000.0})
        after = [(p["x"], p["y"]) for p in _values(_objects(miz, "Blue")[0]["points"])]
        assert after == before

    def test_a_drawing_can_be_renamed(self, miz: Path) -> None:
        edit_map_drawing(miz, layer="Blue", name="Line-1", new_name="FSCL")
        assert _objects(miz, "Blue")[0]["name"] == "FSCL"

    def test_a_textbox_text_can_be_replaced(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Common",
            shape="textbox",
            name="Ingress",
            position={"x": 0.0, "y": 0.0},
            text="old",
        )
        edit_map_drawing(miz, layer="Common", name="Ingress", text="new")
        assert _objects(miz, "Common")[0]["text"] == "new"

    def test_setting_text_on_something_that_has_none_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="text"):
            edit_map_drawing(miz, layer="Blue", name="Line-1", text="nope")

    def test_a_drawing_can_be_removed(self, miz: Path) -> None:
        edit_map_drawing(miz, layer="Blue", name="Line-1", remove=True)
        assert _objects(miz, "Blue") == []

    def test_an_unknown_drawing_names_what_the_layer_holds(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Line-1"):
            edit_map_drawing(miz, layer="Blue", name="Nope", remove=True)

    def test_nothing_to_change_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="no change given"):
            edit_map_drawing(miz, layer="Blue", name="Line-1")


class TestSurvivesAndBacksUp:
    """The reason this is not left to the editor, plus the usual contract."""

    def test_a_drawing_survives_a_read_write_round_trip(self, miz: Path) -> None:
        """The rebuild the ticket cares about: a hand-drawn shape does not survive one, this does."""
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}],
        )
        mission = read_miz(miz)
        assert mission.mission_content is not None
        from mission_tools.miz_tools import write_miz

        write_miz(mission, miz)
        assert any(obj["name"] == "FSCL" for obj in _objects(miz, "Blue"))

    def test_a_mission_with_no_drawings_table_gains_one(self, tmp_path: Path) -> None:
        path = tmp_path / "bare.miz"
        with zipfile.ZipFile(path, "w") as zf:
            zf.writestr("mission", b"mission = {\n}\n")
            zf.writestr("options", b"options = {\n}\n")
            zf.writestr("warehouses", b"warehouses = {\n}\n")
            zf.writestr("theatre", b"Caucasus")
            zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
            zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
        add_map_drawing(
            path,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
        )
        assert len(_objects(path, "Blue")) == 1

    def test_a_backup_is_taken_before_the_write(self, miz: Path) -> None:
        add_map_drawing(
            miz,
            layer="Blue",
            shape="line",
            name="FSCL",
            points=[{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
        )
        assert len([path for path in miz.parent.glob("*.miz") if path != miz]) == 1

    def test_a_refused_drawing_leaves_the_mission_untouched(self, miz: Path) -> None:
        before = miz.read_bytes()
        with pytest.raises(ValueError):
            add_map_drawing(miz, layer="Blue", shape="circle", name="X", position={"x": 0.0, "y": 0.0})
        assert miz.read_bytes() == before
