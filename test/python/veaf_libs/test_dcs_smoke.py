"""Unit tests for the in-DCS smoke harness and its transport.

There is no DCS here, and there will not be one in CI either — that is the defining constraint of
this harness, not an accident. So these tests fake the hook at the transport boundary and pin two
things: that the client speaks the contract read out of ``dcs-fiddle-server.lua`` (base64 in the path,
``?env=``, a JSON ``{result}`` or ``{error}`` reply), and that the runner **skips** rather than fails
when there is nothing to talk to. The second matters more than it looks: a tool that reports a red
result on every machine without DCS is a tool nobody runs.
"""

from __future__ import annotations

import base64
import io
import json
from typing import Any

import pytest
from veaf_libs import dcs_fiddle_client as client
from veaf_libs import dcs_smoke as smoke
from veaf_libs.dcs_fiddle_client import ENV_HOOK, ENV_MISSION, Capabilities, FiddleError, exec_lua, probe
from veaf_libs.dcs_smoke import CHECKS, Check, Outcome, Result, format_result, run


class _FakeResponse(io.BytesIO):
    """Minimal stand-in for what ``urlopen`` yields."""

    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


def _fake_hook(monkeypatch: pytest.MonkeyPatch, replies: dict[str, Any] | Exception) -> list[tuple[str, str]]:
    """Install a fake hook and record what it was asked.

    Args:
        monkeypatch: pytest fixture.
        replies: Either a mapping of decoded-Lua-substring → value to answer with, or an exception to
            raise for every request.

    Returns:
        A list of ``(decoded_lua, env)`` the client sent, in order.
    """
    seen: list[tuple[str, str]] = []

    def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
        url = request.full_url
        encoded, _, query = url.rpartition("/")[2].partition("?")
        decoded = base64.b64decode(encoded).decode("utf-8")
        env = query.removeprefix("env=")
        seen.append((decoded, env))
        if isinstance(replies, Exception):
            raise replies
        for needle, value in replies.items():
            if needle in decoded:
                return _FakeResponse(json.dumps({"result": value}).encode("utf-8"))
        return _FakeResponse(json.dumps({"result": None}).encode("utf-8"))

    monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
    return seen


class TestTransport:
    def test_lua_travels_base64_in_the_path_with_the_env_in_the_query(self, monkeypatch: pytest.MonkeyPatch):
        # The contract is the hook's, read from dcs-fiddle-server.lua rather than assumed.
        seen = _fake_hook(monkeypatch, {"1 + 1": 2})
        assert exec_lua("return 1 + 1", env=ENV_MISSION) == 2
        assert seen == [("return 1 + 1", ENV_MISSION)]

    def test_the_hook_env_is_requested_verbatim(self, monkeypatch: pytest.MonkeyPatch):
        # env=default is the only one that reaches net.*, so getting it wrong silently routes
        # lifecycle calls into the mission environment where they do not exist.
        seen = _fake_hook(monkeypatch, {"_VERSION": "Lua 5.1"})
        exec_lua("return _VERSION", env=ENV_HOOK)
        assert seen[0][1] == "default"

    def test_an_error_reply_raises(self, monkeypatch: pytest.MonkeyPatch):
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            return _FakeResponse(json.dumps({"error": "attempt to index a nil value"}).encode("utf-8"))

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        with pytest.raises(FiddleError, match="attempt to index a nil value"):
            exec_lua("return boom()")

    def test_a_non_json_reply_raises_and_shows_what_came_back(self, monkeypatch: pytest.MonkeyPatch):
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            return _FakeResponse(b"<html>not the hook</html>")

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        with pytest.raises(FiddleError, match="not JSON"):
            exec_lua("return 1")

    def test_an_unreachable_hook_says_what_to_start(self, monkeypatch: pytest.MonkeyPatch):
        _fake_hook(monkeypatch, OSError("connection refused"))
        with pytest.raises(FiddleError, match="dcs-fiddle-server.lua"):
            exec_lua("return 1")


class TestProbe:
    def test_no_dcs_is_reported_not_raised(self, monkeypatch: pytest.MonkeyPatch):
        # "DCS is not running" is the normal state of most machines, so it is an outcome.
        _fake_hook(monkeypatch, OSError("connection refused"))
        caps = probe()
        assert caps.hook_alive is False
        assert caps.notes and "cannot reach" in caps.notes[0]

    def test_it_measures_the_calls_this_repo_has_never_made(self, monkeypatch: pytest.MonkeyPatch):
        _fake_hook(
            monkeypatch,
            {
                "_VERSION": "alive: Lua 5.1",
                "net.load_mission": True,
                "DCS.exitProcess": False,
                "env.mission": "Syria",
            },
        )
        caps = probe()
        assert caps.hook_alive is True
        assert caps.can_load_mission is True
        assert caps.can_quit is False
        assert caps.mission_env_reachable is True
        assert caps.mission_name == "Syria"
        assert any("ABSENT" in note for note in caps.notes)


class TestRun:
    def test_no_hook_skips_with_an_explanation(self, monkeypatch: pytest.MonkeyPatch):
        _fake_hook(monkeypatch, OSError("connection refused"))
        result = run(timeout=0.1)
        assert result.skipped is True
        assert "main menu is enough" in result.skip_reason
        assert result.exit_code == 0, "a machine without DCS must not read as a failure"

    def test_a_hook_with_no_mission_skips_and_says_whether_loading_is_possible(self, monkeypatch: pytest.MonkeyPatch):
        # The mission environment only exists once a mission is loaded; that is information, not a
        # defect, and the message carries the fact the follow-up ticket needs.
        def fake_exec(code: str, env: str = ENV_MISSION, url: str = "", timeout: float = 0.0) -> Any:
            if env == ENV_MISSION:
                raise FiddleError("no mission")
            if "net.load_mission" in code:
                return True
            return "alive: Lua 5.1"

        monkeypatch.setattr(smoke, "exec_lua", fake_exec)
        monkeypatch.setattr(client, "exec_lua", fake_exec)
        result = run(timeout=0.1)
        assert result.skipped is True
        assert "no mission is loaded" in result.skip_reason
        assert result.exit_code == 0

    def test_checks_run_and_are_reported_individually(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            smoke, "probe", lambda **_: Capabilities(hook_alive=True, mission_env_reachable=True, notes=["fake"])
        )
        monkeypatch.setattr(smoke, "exec_lua", lambda code, **_: "table" if "Disposition" in code else "nope")
        checks = (
            Check("yes", "return type(Disposition)", lambda v: v == "table", "why"),
            Check("no", "return something_else", lambda v: v == "table", "why"),
        )
        result = run(checks=checks, timeout=0.1)
        assert [(o.name, o.passed) for o in result.outcomes] == [("yes", True), ("no", False)]
        assert result.exit_code == 1

    def test_a_check_that_cannot_run_fails_rather_than_vanishing(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            smoke, "probe", lambda **_: Capabilities(hook_alive=True, mission_env_reachable=True, notes=[])
        )

        def boom(code: str, **_: Any) -> Any:
            raise FiddleError("the Lua raised")

        monkeypatch.setattr(smoke, "exec_lua", boom)
        result = run(checks=(Check("x", "return 1", lambda v: True, "why"),), timeout=0.1)
        assert result.failed and "could not run" in result.failed[0].detail


class TestCheckExpectations:
    """The expectations themselves, since a wrong one turns a real answer into a wrong verdict."""

    def _check(self, name: str) -> Check:
        return next(c for c in CHECKS if c.name == name)

    def test_disposition_exists_wants_a_table(self):
        check = self._check("disposition-exists")
        assert check.expect("table") is True
        assert check.expect("nil") is False

    def test_getsimplezones_wants_a_function_not_the_no_singleton_sentinel(self):
        check = self._check("disposition-has-getsimplezones")
        assert check.expect("function") is True
        assert check.expect("no-singleton") is False

    def test_returns_points_accepts_a_count_and_rejects_a_raise(self):
        check = self._check("disposition-returns-points")
        assert check.expect(0) is True, "zero points is a measurement, not a failure"
        assert check.expect(3) is True
        assert check.expect("raised: bad argument") is False
        assert check.expect("no-singleton") is False

    def test_veaf_loaded_rejects_the_absent_sentinel(self):
        # The bug this pins: the sentinel is a non-empty string, so a plain truthiness test passed
        # when veaf was missing — the check would have gone green in exactly the case it exists for.
        check = self._check("veaf-loaded")
        assert check.expect("1.2.3") is True
        assert check.expect("veaf-absent") is False
        assert check.expect(None) is False
        assert check.expect("nil") is False

    def test_no_expectation_accepts_a_sentinel_or_a_raise(self):
        # Swept across every check, because this is a whole class of wrong verdict rather than one bug.
        for check in CHECKS:
            for bad in list(smoke.SENTINELS) + ["raised: bad argument #2"]:
                assert check.expect(bad) is False, f"{check.name} accepts the sentinel {bad!r}"

    def test_the_submenu_check_demands_the_submenu_was_actually_created(self):
        # The bug this pins (found by Sourcery on PR #659): the check used to return a constant
        # 'accepted' whenever pcall did not raise, discarding the inner result. So DCS quietly handing
        # back nil read as a pass — on the single question FEAT-COMBATZONE-MENU-COALITION has been
        # waiting on since July, which it would have unblocked in the wrong direction.
        check = self._check("coalition-scoped-submenu-accepted")
        assert check.expect(True) is True
        assert check.expect(False) is False, "a quietly rejected submenu must not pass"
        assert check.expect("accepted") is False, "the old constant must no longer satisfy it"
        assert check.expect("raised: invalid parent") is False

    def test_every_check_records_why_it_exists(self):
        # A check whose purpose nobody wrote down is a check nobody dares delete.
        assert all(c.why.strip() for c in CHECKS)


class TestReport:
    def test_a_skip_reads_as_a_skip(self):
        text = format_result(Result(skipped=True, skip_reason="no DCS"))
        assert text == "smoke: skipped — no DCS"

    def test_failures_are_framed_as_measurements(self):
        result = Result(
            capabilities=Capabilities(hook_alive=True, notes=["hook answered"]),
            outcomes=[Outcome("a", True, "returned 1"), Outcome("b", False, "returned nil")],
        )
        text = format_result(result)
        assert "1/2 checks passed" in text
        assert "[FAIL] b" in text
        assert "not necessarily a defect" in text
