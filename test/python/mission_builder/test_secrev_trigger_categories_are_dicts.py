"""SECREV-2 / VMR-050 — the two halves of clear_veaf_triggers disagreed about `trig`'s shape.

The collection loop handled a trigger category being either a dict or a **list**; the removal loop
right below it calls `.get()` on the same value, which a list does not have. So the list branch
could only ever lead to an `AttributeError` — and worse, list indexes are 0-based while the dict
keys are Lua's 1-based ones, so mixing the two would delete the wrong entries.

The finding offered a choice: make removal shape-aware, or drop the list branch if categories are
always dicts in practice. They are, and by construction rather than by luck — every path that fills
`DcsMission.mission_content` passes `keep_as_dict=["trig", "trigrules"]`, and that policy propagates
to the whole subtree. This pins that invariant, so the removed branch cannot come back as a
half-handled shape: if the invariant ever breaks, these tests break with it.
"""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from mission_tools.miz_tools import read_miz

MISSION_LUA = """mission =
{
    ["trig"] =
    {
        ["actions"] =
        {
            [1] = "a_do_script(\\"one\\")",
            [2] = "a_do_script(\\"two\\")",
        },
        ["conditions"] =
        {
            [1] = "return true",
            [2] = "return false",
        },
        ["funcStartup"] = {},
    },
    ["trigrules"] =
    {
        [1] = { ["comment"] = "first" },
        [2] = { ["comment"] = "second" },
    },
}
"""


def _miz_with(mission_lua: str) -> Path:
    folder = Path(tempfile.mkdtemp())
    miz = folder / "test.miz"
    with zipfile.ZipFile(miz, "w") as archive:
        archive.writestr("mission", mission_lua)
        archive.writestr("options", "options = {}")
        archive.writestr("warehouses", "warehouses = {}")
        archive.writestr("l10n/DEFAULT/dictionary", "dictionary = {}")
        archive.writestr("l10n/DEFAULT/mapResource", "mapResource = {}")
    return miz


class TestTriggerCategoriesStayDicts(unittest.TestCase):
    def test_a_contiguous_category_is_read_as_a_dict_not_a_list(self) -> None:
        # `actions` has keys 1..2 with no gap, which is exactly the shape luadata collapses to a
        # list unless keep_as_dict says otherwise.
        mission = read_miz(_miz_with(MISSION_LUA))
        assert mission.mission_content is not None
        actions = mission.mission_content["trig"]["actions"]
        self.assertIsInstance(actions, dict, f"a contiguous trig category came back as {type(actions).__name__}")
        self.assertEqual(sorted(actions), [1, 2], "the Lua 1-based keys must survive as keys")

    def test_trigrules_keeps_its_lua_keys(self) -> None:
        mission = read_miz(_miz_with(MISSION_LUA))
        assert mission.mission_content is not None
        trigrules = mission.mission_content["trigrules"]
        self.assertIsInstance(trigrules, dict)
        self.assertEqual(sorted(trigrules), [1, 2])

    def test_no_trig_category_is_a_list(self) -> None:
        mission = read_miz(_miz_with(MISSION_LUA))
        assert mission.mission_content is not None
        for name, category in mission.mission_content["trig"].items():
            self.assertNotIsInstance(
                category,
                list,
                f"trig category {name!r} is a list, which clear_veaf_triggers cannot delete from",
            )

    def test_a_non_trig_table_is_still_allowed_to_be_a_list(self) -> None:
        # The control: keep_as_dict is scoped, not global. If everything became a dict this test
        # would fail and the invariant above would be proving nothing in particular.
        mission = read_miz(
            _miz_with(
                MISSION_LUA.replace(
                    '    ["trigrules"]', '    ["someList"] = { [1] = "x", [2] = "y" },\n    ["trigrules"]'
                )
            )
        )
        assert mission.mission_content is not None
        self.assertIsInstance(mission.mission_content["someList"], list)


class TestAListShapedCategoryIsRefused(unittest.TestCase):
    """The invariant above is now enforced rather than assumed."""

    def _worker(self, trig: dict) -> object:
        import typer
        from mission_builder.mission_builder_worker import MissionBuilderWorker
        from mission_tools.miz_tools import DcsMission

        folder = Path(tempfile.mkdtemp())
        (folder / "mission.yaml").write_text("mission:\n  name: test\n", encoding="utf-8")
        worker = MissionBuilderWorker(mission_folder=folder, output_mission=folder / "out.miz", dynamic_mode=None)
        worker.dcs_mission = DcsMission(
            file_path=folder / "in.miz",
            mission_content={"trig": trig, "trigrules": {}},
            dictionary_content={},
            map_resource_content={},
        )
        self._typer = typer
        return worker

    def test_a_dict_category_builds(self) -> None:
        # The control: the normal shape must not trip the guard.
        worker = self._worker({"actions": {1: "a_do_script('x')"}})
        worker.clear_veaf_triggers()  # type: ignore[attr-defined]

    def test_a_list_category_refuses_to_build(self) -> None:
        worker = self._worker({"actions": ["a_do_script('x')"]})
        with self.assertRaises(self._typer.Abort):
            worker.clear_veaf_triggers()  # type: ignore[attr-defined]


if __name__ == "__main__":
    unittest.main()
