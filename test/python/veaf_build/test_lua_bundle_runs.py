"""The static `veaf-scripts.lua` bundle loads and runs under Lua 5.1 (FIX-BUNDLE-LOCAL-LIMIT).

Every Lua test loads the source modules one by one, each in its own chunk. The build
concatenates them into one file instead, and Lua 5.1 refuses a chunk with more than 200
active locals: once the modules' top-level locals added up past that, DCS rejected the
whole bundle ("main function has more than 200 local variables") and no VEAF module
loaded, while every test stayed green. This test runs the bundle the build writes.

It needs a Lua 5.1 interpreter and is skipped without one, except when
`VEAF_REQUIRE_LUA51` is set — the CI Lua job sets it, so the check cannot vanish there.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest
import typer

from veaf_build.lua_tests import _find_lua
from veaf_build.worker import _PROJECT_ROOT, LUA_BUNDLE_SCRIPTS, bundle_body, bundle_section

_VEAF_SCRIPTS_DIR = _PROJECT_ROOT / "src" / "scripts" / "veaf"
_LUA_TEST_DIR = _PROJECT_ROOT / "test" / "lua"


def _lua51() -> str:
    """The Lua 5.1 interpreter, or skip — unless the environment requires it."""
    try:
        return _find_lua()
    except typer.BadParameter:
        if os.environ.get("VEAF_REQUIRE_LUA51"):
            raise
        pytest.skip("no Lua 5.1 interpreter")


def test_a_section_is_its_own_block() -> None:
    section = bundle_section("veafSample.lua", "local a = 1\n")
    lines = section.splitlines()
    start = lines.index("-- START script veafSample.lua")
    end = lines.index("-- END script veafSample.lua")
    body = [line for line in lines[start + 1 : end] if line and not line.startswith("--")]
    assert body == ["do", "local a = 1", "end"]


def test_the_body_starts_with_veaf_lua_then_follows_the_manifest(tmp_path: Path) -> None:
    (tmp_path / "veaf.lua").write_text("veaf = {}\n", encoding="utf-8")
    (tmp_path / LUA_BUNDLE_SCRIPTS[0]).write_text("-- first\n", encoding="utf-8")
    body = bundle_body(tmp_path, LUA_BUNDLE_SCRIPTS)
    assert body.index("START script veaf.lua") < body.index(f"START script {LUA_BUNDLE_SCRIPTS[0]}")
    # a module missing from the folder is left out, as the build always did
    assert f"START script {LUA_BUNDLE_SCRIPTS[1]}" not in body


def test_the_bundle_loads_and_runs_under_lua51(tmp_path: Path) -> None:
    lua = _lua51()
    bundle = tmp_path / "veaf-scripts.lua"
    bundle.write_text(bundle_body(_VEAF_SCRIPTS_DIR, LUA_BUNDLE_SCRIPTS), encoding="utf-8")
    runner = tmp_path / "run_bundle.lua"
    runner.write_text(
        'dofile("dcs_mocks.lua")\n'
        f"dofile([[{bundle.as_posix()}]])\n"
        'for _, name in ipairs({"veaf", "veafCampaign", "veafOpposition", "veafQraManager", "veafGroundAI"}) do\n'
        '  assert(_G[name], name .. " is not defined")\n'
        "end\n"
        'print("BUNDLE OK")\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [lua, str(runner)],
        cwd=_LUA_TEST_DIR,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
    )
    assert result.returncode == 0, result.stderr[-2000:]
    assert "BUNDLE OK" in result.stdout
