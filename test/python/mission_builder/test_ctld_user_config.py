"""FEAT-CTLD2-INTEGRATION: the mission's CTLD configuration reaches CTLD 2.

CTLD 2 reads a complete YAML snapshot from ``ctld.configUser`` and starts itself on
load unless ``ctld.dontInitialize`` was set first. VMCT therefore generates a small
Lua wrapper from the mission's ``ctld-config.yaml`` and loads it **immediately before**
``CTLD.lua`` — in both load modes, from the same builder, so the two cannot diverge.

See docs/adr/0016-ctld2-sidecar-configuration.md.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import (
    CTLD_CONFIG_FILENAME,
    CTLD_USER_CONFIG_FILENAME,
    LuaAction,
    MissionBuilderWorker,
    _lua_long_bracket,
)

_MIZ_FOLDER = "l10n/DEFAULT"


def _make_worker(*, ctld_enabled: bool = True) -> MissionBuilderWorker:
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_folder = Path(tempfile.mkdtemp())
    worker.output_mission = worker.mission_folder / "out.miz"
    worker.scripts_path = None
    # No CTLD/CSAR sound to declare: these hand-built workers exercise the load triggers,
    # not the sound declaration (FIX-COMMUNITY-SOUNDS-PRUNED).
    worker.collected_community_sound_files = {}
    worker.collected_mission_data_files = {}
    worker.dev_mode = True
    worker._community_enabled = lambda script_id: ctld_enabled and script_id == "ctld"  # type: ignore[method-assign]
    return worker


def _collected(*names: str) -> dict[str, bytes]:
    return {f"{_MIZ_FOLDER}/{name}": b"-- " + name.encode() for name in names}


class TestLuaLongBracket(unittest.TestCase):
    """The snapshot is multi-line and quote-laden: only a long bracket can carry it."""

    def test_plain_text_uses_level_zero(self) -> None:
        self.assertEqual(_lua_long_bracket("a: 1\n"), "[[\na: 1\n]]")

    def test_leading_newline_is_added_because_lua_eats_it(self) -> None:
        """Lua drops one newline right after the opening bracket — so we add one."""
        wrapped = _lua_long_bracket("\nfirst line was blank\n")
        self.assertTrue(wrapped.startswith("[[\n\n"))

    def test_level_escalates_past_a_closing_sequence_in_the_payload(self) -> None:
        wrapped = _lua_long_bracket("desc: this ]] is not the end\n")
        self.assertTrue(wrapped.startswith("[=["))
        self.assertTrue(wrapped.endswith("]=]"))

    def test_level_escalates_again_when_the_next_level_also_collides(self) -> None:
        wrapped = _lua_long_bracket("a ]] b ]=] c\n")
        self.assertTrue(wrapped.startswith("[==["))
        self.assertTrue(wrapped.endswith("]==]"))


class TestGeneratedLua(unittest.TestCase):
    def test_defers_initialisation_even_without_a_config_file(self) -> None:
        """VEAF owns the init in every case — otherwise CTLD self-starts before veaf.lua."""
        worker = _make_worker()
        lua = worker._ctld_user_config_lua()
        assert lua is not None
        self.assertIn("ctld.dontInitialize = true", lua)
        self.assertNotIn("configUser", lua)

    def test_carries_the_snapshot_verbatim_when_the_file_exists(self) -> None:
        worker = _make_worker()
        (worker.mission_folder / CTLD_CONFIG_FILENAME).write_text(
            'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n', encoding="utf-8"
        )
        lua = worker._ctld_user_config_lua()
        assert lua is not None
        self.assertIn("ctld.configUser = [[", lua)
        self.assertIn("numberOfTroops: 10", lua)

    def test_nothing_generated_when_the_module_is_disabled(self) -> None:
        self.assertIsNone(_make_worker(ctld_enabled=False)._ctld_user_config_lua())


class TestStaticInjection(unittest.TestCase):
    """Insertion order is the contract: the static trigger replays these entries as-is."""

    def test_config_is_inserted_immediately_before_ctld(self) -> None:
        worker = _make_worker()
        result = worker._with_ctld_user_config(_collected("mist.lua", "CTLD.lua", "CSAR.lua"))
        self.assertEqual(
            [Path(k).name for k in result],
            ["mist.lua", CTLD_USER_CONFIG_FILENAME, "CTLD.lua", "CSAR.lua"],
        )

    def test_generated_entry_lands_beside_ctld_in_the_miz(self) -> None:
        worker = _make_worker()
        result = worker._with_ctld_user_config(_collected("CTLD.lua"))
        self.assertIn(f"{_MIZ_FOLDER}/{CTLD_USER_CONFIG_FILENAME}", result)

    def test_untouched_when_the_module_is_disabled(self) -> None:
        collected = _collected("mist.lua", "CTLD.lua")
        result = _make_worker(ctld_enabled=False)._with_ctld_user_config(collected)
        self.assertEqual(list(result), list(collected))

    def test_untouched_when_ctld_script_is_absent(self) -> None:
        """CTLD enabled but its script missing: collection already reported it."""
        collected = _collected("mist.lua")
        result = _make_worker()._with_ctld_user_config(collected)
        self.assertEqual(list(result), list(collected))


class TestDynamicMode(unittest.TestCase):
    def test_file_is_written_for_dynamic_mode_and_removed_when_disabled(self) -> None:
        worker = _make_worker()
        target = worker.mission_folder / "src" / "scripts" / CTLD_USER_CONFIG_FILENAME

        worker.generate_ctld_user_config()
        self.assertTrue(target.is_file())
        self.assertIn("dontInitialize", target.read_text(encoding="utf-8"))

        # Turning the module off must not leave a stale configuration behind: dynamic
        # mode loads off disk and would keep configuring a CTLD nobody asked for.
        worker._community_enabled = lambda script_id: False  # type: ignore[method-assign]
        worker.generate_ctld_user_config()
        self.assertFalse(target.exists())

    def test_dynamic_trigger_loads_the_config_before_ctld(self) -> None:
        worker = _make_worker()
        worker.get_collected_community_script_files = lambda: []  # type: ignore[method-assign]
        worker.get_collected_veaf_script_files = lambda: []  # type: ignore[method-assign]
        worker._active_community_scripts = lambda: [  # type: ignore[method-assign]
            {"path": "src/scripts/community/mist.lua"},
            {"path": "src/scripts/community/CTLD.lua"},
        ]
        specs = worker._build_veaf_trigger_specs({}, {})
        dynamic = next(s for s in specs if s.comment == "VEAF scripts loading - dynamic")
        loads = [a.lua for a in dynamic.actions if isinstance(a, LuaAction) and "loadfile" in a.lua]

        config_index = next(i for i, lua in enumerate(loads) if CTLD_USER_CONFIG_FILENAME in lua)
        ctld_index = next(i for i, lua in enumerate(loads) if lua.endswith('community/CTLD.lua"))()'))
        self.assertLess(config_index, ctld_index)
        self.assertIn("VEAF_DYNAMIC_MISSIONPATH", loads[config_index])


if __name__ == "__main__":
    unittest.main()
