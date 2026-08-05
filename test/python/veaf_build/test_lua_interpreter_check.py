"""`_find_lua` must verify the interpreter is Lua 5.1 (FIX-LUA-RUNNER-VERSION-CHECK).

The runner used to take the first `lua` on PATH. On a machine where that is 5.4
the whole suite runs on an interpreter the VEAF scripts do not target (`unpack`
removed, `string.format('%d', ...)` rejecting a fractional number), producing
dozens of failures that look like regressions. The right answer is to refuse.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
import typer

from veaf_build import lua_tests

_BANNER_51 = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio"
_BANNER_54 = "Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio"


def _fake_which(available: dict[str, str]) -> object:
    def which(cmd: str) -> str | None:
        return available.get(cmd)

    return which


def _fake_run(banners: dict[str, str]) -> object:
    """Fake `subprocess.run` answering `<exe> -v` from a name → banner mapping."""

    def run(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        assert cmd[1] == "-v"
        banner = banners.get(cmd[0], "")
        # Lua 5.1 prints its banner on stderr; later versions on stdout.
        stdout = banner if "5.1" not in banner else ""
        stderr = banner if "5.1" in banner else ""
        return subprocess.CompletedProcess(cmd, 0, stdout, stderr)

    return run


@pytest.fixture(autouse=True)
def _no_windows_fallback(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Neutralise the hardcoded Windows fallback so tests are platform-agnostic."""
    monkeypatch.setattr(lua_tests, "_WINDOWS_LUA_FALLBACK", tmp_path / "absent" / "lua.exe")


def test_accepts_a_lua_51_interpreter(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lua_tests.shutil, "which", _fake_which({"lua": "/usr/bin/lua"}))
    monkeypatch.setattr(lua_tests.subprocess, "run", _fake_run({"lua": _BANNER_51}))

    assert lua_tests._find_lua() == "lua"


def test_rejects_a_lua_54_interpreter(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lua_tests.shutil, "which", _fake_which({"lua": "/usr/bin/lua"}))
    monkeypatch.setattr(lua_tests.subprocess, "run", _fake_run({"lua": _BANNER_54}))

    with pytest.raises(typer.BadParameter) as excinfo:
        lua_tests._find_lua()

    message = str(excinfo.value)
    assert "Lua 5.4.8" in message  # names what it found instead of failing blind
    assert "scoop install lua51" in message


def test_prefers_the_51_candidate_over_a_54_lua(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        lua_tests.shutil,
        "which",
        _fake_which({"lua51": "/scoop/shims/lua51", "lua": "/scoop/shims/lua"}),
    )
    monkeypatch.setattr(
        lua_tests.subprocess,
        "run",
        _fake_run({"lua51": _BANNER_51, "lua": _BANNER_54}),
    )

    assert lua_tests._find_lua() == "lua51"


def test_reports_when_no_interpreter_at_all(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lua_tests.shutil, "which", _fake_which({}))

    with pytest.raises(typer.BadParameter) as excinfo:
        lua_tests._find_lua()

    assert "No Lua interpreter found on PATH." in str(excinfo.value)


def test_windows_fallback_path_is_version_checked(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    fallback = tmp_path / "lua.exe"
    fallback.write_text("", encoding="utf-8")
    monkeypatch.setattr(lua_tests.sys, "platform", "win32")
    monkeypatch.setattr(lua_tests, "_WINDOWS_LUA_FALLBACK", fallback)
    monkeypatch.setattr(lua_tests.shutil, "which", _fake_which({}))
    monkeypatch.setattr(lua_tests.subprocess, "run", _fake_run({str(fallback): _BANNER_51}))

    assert lua_tests._find_lua() == str(fallback)


def test_an_unrunnable_candidate_is_rejected_not_crashed_on(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lua_tests.shutil, "which", _fake_which({"lua": "/usr/bin/lua"}))

    def boom(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        raise OSError("Exec format error")

    monkeypatch.setattr(lua_tests.subprocess, "run", boom)

    with pytest.raises(typer.BadParameter) as excinfo:
        lua_tests._find_lua()

    assert "not a usable Lua interpreter" in str(excinfo.value)
