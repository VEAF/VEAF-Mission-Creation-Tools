"""Tests for `repair_static_shapes` (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 17)."""

from pathlib import Path

from mission_tools.miz_tools import read_mission_folder
from veaf_libs.mission_table import indexed
from veaf_mission_mcp.repair_static_shapes import repair_static_shapes

# Two statics placed before #1023, without a shape: a command centre (whose shape DCS needs, GermanyCW-v6
# journal §12) and a type the database gives none; a third already has its own.
_MISSION = """mission = {
  ["theatre"] = "Caucasus",
  ["coalition"] = {
    ["red"] = {
      ["country"] = {
        [1] = {
          ["id"] = 0,
          ["name"] = "Russia",
          ["static"] = {
            ["group"] = {
              [1] = {["name"] = "HQ", ["units"] = {[1] = {["name"] = "HQ", ["type"] = ".Command Center"}}},
              [2] = {["name"] = "Odd", ["units"] = {[1] = {["name"] = "Odd", ["type"] = "No such static"}}},
              [3] = {["name"] = "Kept", ["units"] = {[1] = {["name"] = "Kept", ["type"] = ".Command Center", ["shape_name"] = "Mine"}}},
            },
          },
        },
      },
    },
  },
}
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


def _shapes(folder: Path) -> dict[str, str | None]:
    content = read_mission_folder(folder).mission_content or {}
    country = indexed(content["coalition"]["red"]["country"])[0]
    units = [indexed(g["units"])[0] for g in indexed(country["static"]["group"])]
    return {u["name"]: u.get("shape_name") for u in units}


def test_a_missing_shape_is_filled_and_reported(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = repair_static_shapes(folder)
    assert result["filled"] == [{"unit": "HQ", "type": ".Command Center", "shape_name": "ComCenter"}]
    assert result["unknown"] == [{"unit": "Odd", "type": "No such static"}]
    assert result["written"] is True and result["durable"] is True
    assert _shapes(folder) == {"HQ": "ComCenter", "Odd": None, "Kept": "Mine"}


def test_nothing_to_fill_writes_nothing(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    repair_static_shapes(folder)
    before = (folder / "src" / "mission" / "mission").read_bytes()
    result = repair_static_shapes(folder)
    assert (result["filled"], result["written"]) == ([], False)
    assert (folder / "src" / "mission" / "mission").read_bytes() == before
