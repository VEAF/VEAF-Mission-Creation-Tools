"""SECREV-001 — `.miz` Lua parsing must not execute arbitrary code.

Two guarantees are tested:

1. **No execution**: a malicious ``.miz`` payload that, under the former
   ``lua.execute`` path, would run side effects (here: writing a sentinel file)
   must NOT do so when parsed through ``luadata.unserialize``.
2. **Equivalence**: rerouting parsing to the pure-Python state machine must
   produce output identical to the historical lupa-based path for every real
   ``.miz`` fixture shipped in the repository.
"""

from __future__ import annotations

import contextlib
import zipfile
from pathlib import Path

import luadata
import pytest
from luadata.serializer.unserialize import _lua_table_to_dict

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

_REPO_ROOT = Path(__file__).parents[3]
_MIZ_FIXTURES = sorted(_REPO_ROOT.glob("test/**/*.miz"))

# Lua members of a .miz that are pure-data tables, with the keep_as_dict policy
# that read_miz applies to each.
_LUA_MEMBERS: dict[str, list[str] | None] = {
    "mission": ["trig", "trigrules"],
    "options": None,
    "warehouses": None,
    "l10n/DEFAULT/dictionary": None,
    "l10n/DEFAULT/mapResource": None,
}


def _lua_reference(raw: str, keep_as_dict: list[str] | None) -> object:
    """Reference parser using the original (unsafe) lupa path, for comparison."""
    pytest.importorskip("lupa")
    try:
        from lupa.lua51 import LuaRuntime  # type: ignore[attr-defined]
    except ImportError:  # pragma: no cover - depends on installed lupa flavour
        try:
            from lupa.lua54 import LuaRuntime  # type: ignore[attr-defined,no-redef]
        except ImportError:  # pragma: no cover
            from lupa import LuaRuntime  # type: ignore[no-redef]
    lua = LuaRuntime(unpack_returned_tuples=False, encoding="utf-8", max_memory=0)
    lua.execute(raw)
    variable = raw.split("=")[0].strip()
    return _lua_table_to_dict(lua.globals()[variable], keep_as_dict=keep_as_dict, all_is_dict=False)


# ---------------------------------------------------------------------------
# 1. No arbitrary code execution
# ---------------------------------------------------------------------------


class TestNoCodeExecution:
    # The guarantee under test is "no execution", not "raises": the parser may
    # accept or reject the payload, but the sentinel file must never appear.

    def test_payload_does_not_run_side_effects(self, tmp_path: Path) -> None:
        sentinel = tmp_path / "pwned"
        # If parsed with lua.execute, io.open would create the sentinel file.
        payload = f'mission = {{}} io.open("{sentinel.as_posix()}", "w"):close()'
        with contextlib.suppress(Exception):
            luadata.unserialize(payload)
        assert not sentinel.exists(), "parsing executed embedded Lua code (RCE)"

    def test_function_call_value_is_not_executed(self, tmp_path: Path) -> None:
        sentinel = tmp_path / "pwned2"
        payload = f'mission = {{ ["x"] = os.execute("touch {sentinel.as_posix()}") }}'
        with contextlib.suppress(Exception):
            luadata.unserialize(payload)
        assert not sentinel.exists()


# ---------------------------------------------------------------------------
# 2. Behavioural equivalence with the historical lupa path
# ---------------------------------------------------------------------------


class TestEquivalenceWithLua:
    def test_empty_table_is_dict_like_lua(self) -> None:
        # Regression: the state machine returns [] for {}, lupa returns {}.
        assert luadata.unserialize("mission = {}") == _lua_reference("mission = {}", None)
        assert luadata.unserialize("mission = {}") == {}

    def test_keep_as_dict_forces_dict_subtree(self) -> None:
        raw = 'mission = { ["trig"] = { [1] = "a", [2] = "b" } }'
        result = luadata.unserialize(raw, keep_as_dict=["trig", "trigrules"])
        assert result == {"trig": {1: "a", 2: "b"}}
        assert result == _lua_reference(raw, ["trig", "trigrules"])

    def test_contiguous_int_keys_become_list_without_policy(self) -> None:
        raw = 'mission = { [1] = "a", [2] = "b" }'
        assert luadata.unserialize(raw) == ["a", "b"]

    @pytest.mark.skipif(not _MIZ_FIXTURES, reason="no .miz fixtures available")
    @pytest.mark.parametrize("miz_path", _MIZ_FIXTURES, ids=lambda p: p.name)
    def test_real_miz_members_match_lua(self, miz_path: Path) -> None:
        with zipfile.ZipFile(miz_path) as zf:
            names = set(zf.namelist())
            for member, keep_as_dict in _LUA_MEMBERS.items():
                if member not in names:
                    continue
                raw = zf.read(member).decode("utf-8")
                if "=" not in raw:
                    continue
                expected = _lua_reference(raw, keep_as_dict)
                actual = luadata.unserialize(raw, keep_as_dict=keep_as_dict)
                assert actual == expected, f"{miz_path.name}:{member} diverged from lupa output"
