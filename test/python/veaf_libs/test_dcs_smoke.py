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
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import pytest
from veaf_libs import dcs_fiddle_client as client
from veaf_libs import dcs_smoke as smoke
from veaf_libs.dcs_fiddle_client import ENV_HOOK, ENV_MISSION, Capabilities, FiddleError, exec_lua, probe
from veaf_libs.dcs_smoke import CHECKS, Check, Outcome, Result, format_result, run
from veaf_libs.i18n import language


@pytest.fixture(autouse=True)
def _pinned_language() -> Any:
    """Assert against the English catalogue regardless of whose machine this runs on.

    Four of these tests compare report text literally, and ``t()`` resolves the language from the
    ambient environment — ``VEAF_LANG``, then ``~/veafmct.yaml``, then the OS locale. So they passed in
    CI, where nothing sets a language, and failed on a French workstation: green where nobody looks and
    red where the person who has DCS works, on the one suite that only they can finish. Pinning the
    locale here is the fix; asserting on translated prose without saying which translation is the bug.
    """
    with language("en"):
        yield


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

    def test_an_empty_table_reply_is_a_nil_result_not_an_error(self, monkeypatch: pytest.MonkeyPatch):
        # The omltcat fork serialises `{result = nil}` as `[]` — a chunk that returned nothing, such as
        # net.load_mission or exitProcess. Measured 2026-08-15: rejecting it broke the whole lifecycle.
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            return _FakeResponse(json.dumps([]).encode("utf-8"))

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        assert exec_lua("net.load_mission('x')", env=ENV_HOOK) is None

    def test_a_lua_error_returned_as_a_result_still_raises(self, monkeypatch: pytest.MonkeyPatch):
        # Measured on a live DCS at the main menu: net.dostring_in returns a Lua failure as its string
        # *result*, HTTP 200, {result=…} body. So the mission environment reports a crash in the exact
        # shape of a successful answer, and the probe duly said "mission environment answered".
        _fake_hook(monkeypatch, {"env.mission": ":1: attempt to index global 'env' (a nil value)"})
        with pytest.raises(FiddleError, match="failed in the mission environment"):
            exec_lua("return env.mission.theatre", env=ENV_MISSION)

    def test_a_chunk_named_error_is_recognised_too(self, monkeypatch: pytest.MonkeyPatch):
        # The other form Lua produces, when the chunk carries a name.
        _fake_hook(monkeypatch, {"boom": '[string "boom"]:3: bad argument #1'})
        with pytest.raises(FiddleError, match="bad argument"):
            exec_lua("return boom()", env=ENV_MISSION)

    def test_prose_that_merely_mentions_a_line_number_is_not_an_error(self, monkeypatch: pytest.MonkeyPatch):
        # The detector keys on the shape Lua actually emits — a leading `:N: `. A legitimate result that
        # merely contains a colon and a digit must survive, or the harness starts inventing failures.
        _fake_hook(monkeypatch, {"describe": "Syria: 3 airbases"})
        assert exec_lua("return describe()", env=ENV_MISSION) == "Syria: 3 airbases"

    def test_the_hook_environment_is_left_alone(self, monkeypatch: pytest.MonkeyPatch):
        # There the hook loadstrings the chunk and its own pcall turns a raise into {error=…}, so a
        # result that happens to look like an error message is a result.
        _fake_hook(monkeypatch, {"quote": ":1: not actually an error here"})
        assert exec_lua("return quote()", env=ENV_HOOK) == ":1: not actually an error here"


#: What a healthy DCS returns from the facts chunk. Named so each test can bend one fact and leave the
#: rest realistic — the bugs worth pinning here are all "one thing is missing", not "nothing answers".
_HEALTHY_FACTS: dict[str, Any] = {
    "lua": "Lua 5.1",
    "control_table": "Sim+DCS",
    "control_aliased": True,
    "exit_process": True,
    "stop_mission": True,
    "set_pause": True,
    "set_user_callbacks": True,
    "get_log_history": True,
    "load_mission": True,
    "load_next_mission": True,
    "dostring_in": True,
    "mission_name": "smoke",
    "mission_filename": "C:/missions/smoke.miz",
    "is_server": True,
    "is_multiplayer": False,
    "write_dir": "C:/Users/x/Saved Games/DCS/",
    "install_dir": "C:/jeux/DCS World",
}


def _facts_hook(monkeypatch: pytest.MonkeyPatch, **overrides: Any) -> list[tuple[str, str]]:
    """Fake a hook returning the facts table, with *overrides* applied.

    Args:
        monkeypatch: pytest fixture.
        **overrides: Facts to replace; pass ``None`` to drop a key entirely, which is what a DCS
            missing that function actually produces.

    Returns:
        The ``(lua, env)`` pairs the client sent.
    """
    facts = dict(_HEALTHY_FACTS)
    for key, value in overrides.items():
        if value is None:
            facts.pop(key, None)
        else:
            facts[key] = value
    return _fake_hook(monkeypatch, {"facts.control_table": facts, "env.mission": "Syria"})


class TestProbe:
    def test_no_dcs_is_reported_not_raised(self, monkeypatch: pytest.MonkeyPatch):
        # "DCS is not running" is the normal state of most machines, so it is an outcome.
        _fake_hook(monkeypatch, OSError("connection refused"))
        caps = probe()
        assert caps.hook_alive is False
        assert caps.notes and "cannot reach" in caps.notes[0]

    def test_it_measures_the_calls_this_repo_has_never_made(self, monkeypatch: pytest.MonkeyPatch):
        _facts_hook(monkeypatch)
        caps = probe()
        assert caps.hook_alive is True
        assert caps.can_load_mission is True
        assert caps.can_quit is True
        assert caps.can_stop_mission is True
        assert caps.can_set_callbacks is True
        assert caps.can_dostring_in is True
        assert caps.mission_env_reachable is True
        assert caps.can_drive_lifecycle is True
        assert caps.blocking_reason() is None

    def test_it_reports_which_control_table_answered(self, monkeypatch: pytest.MonkeyPatch):
        # ED documents Sim.*; every hook in the wild calls DCS.*. Which one is live is measured, and
        # the previous probe hardcoded DCS.exitProcess — so a DCS that had dropped the alias would have
        # been reported as unable to quit rather than as renamed.
        _facts_hook(monkeypatch, control_table="Sim", control_aliased=False)
        caps = probe()
        assert caps.control_table == "Sim"
        assert caps.control_aliased is False
        assert any("Sim.exitProcess: present" in note for note in caps.notes)

    def test_a_missing_dostring_in_is_the_blocker_not_the_missing_mission(self, monkeypatch: pytest.MonkeyPatch):
        # The misdiagnosis this pins. ED gates net.dostring_in behind autoexec.cfg, and every assertion
        # rides on it, so reporting "no mission loaded" sends the reader to load a mission that will
        # change nothing. The root cause has to win over the first symptom.
        _facts_hook(monkeypatch, dostring_in=None, mission_name=None)
        caps = probe()
        assert caps.can_dostring_in is False
        blocker = caps.blocking_reason()
        assert blocker is not None
        assert "autoexec.cfg" in blocker
        assert "no mission" not in blocker

    def test_a_loaded_mission_that_still_refuses_is_called_out_as_the_odd_case(self, monkeypatch: pytest.MonkeyPatch):
        # dostring_in present, a mission loaded, and the mission environment still silent: that is the
        # combination no explanation covers, so it must not be filed under either of the known two.
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            query = request.full_url.rpartition("/")[2].partition("?")[2]
            if query.removeprefix("env=") == ENV_HOOK:
                return _FakeResponse(json.dumps({"result": _HEALTHY_FACTS}).encode("utf-8"))
            raise OSError("connection reset")

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        caps = probe()
        assert caps.mission_env_error is not None
        assert any("worth investigating" in note for note in caps.notes)
        assert caps.scripting_route is None
        assert any("no route reached the scripting state" in note for note in caps.notes)

    def test_could_not_ask_is_not_the_same_as_false(self, monkeypatch: pytest.MonkeyPatch):
        # isServer decides whether the SERVER-ONLY net.load_mission can be used at all. Reading a
        # failed call as "not a server" would retire that option on no evidence.
        _facts_hook(monkeypatch, is_server="raised: not available here", is_multiplayer="absent")
        caps = probe()
        assert caps.is_server is None
        assert caps.is_multiplayer is None

    def test_it_measures_what_each_lua_type_becomes_after_the_crossing(self, monkeypatch: pytest.MonkeyPatch):
        # ED documents net.dostring_in as returning a *string*. If that is literal, a check expecting a
        # number or True can never pass however correct its Lua is — and two of the six shipped checks
        # expect exactly that. So the shapes are measured rather than reasoned about.
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            url = request.full_url
            encoded, _, query = url.rpartition("/")[2].partition("?")
            decoded = base64.b64decode(encoded).decode("utf-8")
            if query.removeprefix("env=") == ENV_HOOK:
                return _FakeResponse(json.dumps({"result": _HEALTHY_FACTS}).encode("utf-8"))
            # A transport that stringifies everything, which is what the documentation describes. The
            # chunks arrive wrapped by the route, so match on what they contain rather than on equality.
            replies = {"type(env)": "table", "return 3": "3", "return true": "true", "return {1, 2}": "table: 0x1"}
            answer = next((v for needle, v in replies.items() if needle in decoded), "x")
            return _FakeResponse(json.dumps({"result": answer}).encode("utf-8"))

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        caps = probe()
        assert caps.scripting_route is not None
        assert set(caps.mission_env_shapes) == {"number", "boolean", "string", "table"}
        assert "Python str" in caps.mission_env_shapes["number"], "a stringified number is the finding"
        assert any("crosses the a_do_script route" in note for note in caps.notes)

    def test_a_shape_that_cannot_be_measured_is_recorded_not_raised(self, monkeypatch: pytest.MonkeyPatch):
        # A shape probe that fails is itself information, and it must not take the whole probe down: the
        # lifecycle facts gathered before it are the reason anyone ran this.
        calls = {"n": 0}

        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            query = request.full_url.rpartition("/")[2].partition("?")[2]
            if query.removeprefix("env=") == ENV_HOOK:
                return _FakeResponse(json.dumps({"result": _HEALTHY_FACTS}).encode("utf-8"))
            calls["n"] += 1
            if calls["n"] == 1:  # the theatre question, so the mission environment counts as reachable
                return _FakeResponse(json.dumps({"result": "Syria"}).encode("utf-8"))
            raise OSError("connection reset")

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        caps = probe()
        assert caps.mission_env_reachable is True
        assert all("could not measure" in seen for seen in caps.mission_env_shapes.values())

    def test_it_reports_the_write_dir_it_was_told_rather_than_guessing(self, monkeypatch: pytest.MonkeyPatch):
        # A workstation can hold half a dozen Saved Games folders, one per aircraft profile. Only the
        # running process knows which it was started with, so the harness asks instead of picking.
        _facts_hook(monkeypatch, write_dir="C:/Users/x/Saved Games/DCS_F14/")
        caps = probe()
        assert caps.write_dir == "C:/Users/x/Saved Games/DCS_F14/"
        assert any("DCS_F14" in note for note in caps.notes)

    def test_a_hook_answering_something_other_than_a_table_says_so(self, monkeypatch: pytest.MonkeyPatch):
        # There are several forks of this hook in circulation. One that answers but does not speak the
        # contract must not read as a DCS missing every function it was asked about.
        _fake_hook(monkeypatch, {"facts.control_table": "not a table at all"})
        caps = probe()
        assert caps.hook_alive is True
        assert caps.can_quit is False
        assert any("different contract" in note for note in caps.notes)


def _ready(**overrides: Any) -> Capabilities:
    """A DCS the runner can actually assert against: mission running, route found.

    Args:
        **overrides: Fields to change.

    Returns:
        Capabilities past every rung of the skip ladder, so a test can exercise the checks themselves.
    """
    caps = Capabilities(
        hook_alive=True,
        can_dostring_in=True,
        mission_env_reachable=True,
        mission_name="m",
        scripting_route=client.SCRIPTING_ROUTES[0],
    )
    for key, value in overrides.items():
        setattr(caps, key, value)
    return caps


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
            return dict(_HEALTHY_FACTS, mission_name="nil", mission_filename="nil")

        monkeypatch.setattr(client, "exec_lua", fake_exec)
        result = run(timeout=0.1)
        assert result.skipped is True
        assert "no mission is loaded" in result.skip_reason
        assert result.exit_code == 0

    def test_a_loaded_mission_with_no_route_does_not_ask_for_a_mission(self, monkeypatch: pytest.MonkeyPatch):
        # David loaded `Smerch Hunt II`, sat in the cockpit, and was told "no mission is loaded". The
        # message has to name the real obstacle — nothing reached the state the scripts live in — and
        # quote what DCS said, since that string is the only evidence the reader has.
        monkeypatch.setattr(
            smoke,
            "probe",
            lambda **_: Capabilities(
                hook_alive=True,
                can_dostring_in=True,
                mission_env_reachable=False,
                mission_name="tempMission",
                scripting_route=None,
                mission_env_error=":1: attempt to index global 'env' (a nil value)",
                notes=[],
            ),
        )
        result = run(timeout=0.1)
        assert result.skipped is True
        assert result.exit_code == 0
        assert "tempMission" in result.skip_reason
        assert "trigger" in result.skip_reason, "the reader needs to know which state env=mission is"
        assert "attempt to index global" in result.skip_reason, "the reader needs what DCS said"
        assert "not a harness defect" in result.skip_reason

    def test_checks_are_sent_through_the_measured_route_not_to_env_mission(self, monkeypatch: pytest.MonkeyPatch):
        # The defect this pins is the whole reason the first slice could never have worked: `env=mission`
        # is the trigger state, so a check sent there asks about Lua the VEAF scripts do not live in.
        route = client.SCRIPTING_ROUTES[0]
        monkeypatch.setattr(
            smoke,
            "probe",
            lambda **_: Capabilities(
                hook_alive=True, can_dostring_in=True, mission_name="m", scripting_route=route, notes=[]
            ),
        )
        sent: list[tuple[str, str]] = []

        def fake_exec(code: str, env: str = ENV_MISSION, url: str = "", timeout: float = 0.0) -> Any:
            sent.append((code, env))
            return "table"

        monkeypatch.setattr(client, "exec_lua", fake_exec)
        run(checks=(Check("x", "return type(veaf)", lambda v: v == "table", "why"),), timeout=0.1)
        assert len(sent) == 1
        code, env = sent[0]
        assert code.startswith("return a_do_script("), "the chunk has to be wrapped by the route"
        assert "return type(veaf)" in code
        assert env == ENV_MISSION, "a_do_script is called *from* the trigger state"

    def test_a_gated_dostring_in_skips_with_the_autoexec_fix_rather_than_the_mission_one(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        # Same shape as the probe test, one layer up: the runner must not tell someone to load a
        # mission when loading one cannot possibly help.
        def fake_exec(code: str, env: str = ENV_MISSION, url: str = "", timeout: float = 0.0) -> Any:
            if env == ENV_MISSION:
                raise FiddleError("net.dostring_in is nil")
            facts = dict(_HEALTHY_FACTS)
            del facts["dostring_in"]
            return facts

        monkeypatch.setattr(client, "exec_lua", fake_exec)
        result = run(timeout=0.1)
        assert result.skipped is True
        assert "autoexec.cfg" in result.skip_reason
        assert result.exit_code == 0, "a permission this harness cannot grant itself is not a failure"

    def test_checks_run_and_are_reported_individually(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            smoke,
            "probe",
            lambda **_: _ready(notes=["fake"]),
        )
        monkeypatch.setattr(
            smoke, "exec_in_scripting", lambda code, _route, **__: "table" if "Disposition" in code else "nope"
        )
        checks = (
            Check("yes", "return type(Disposition)", lambda v: v == "table", "why"),
            Check("no", "return something_else", lambda v: v == "table", "why"),
        )
        result = run(checks=checks, timeout=0.1)
        assert [(o.name, o.passed) for o in result.outcomes] == [("yes", True), ("no", False)]
        assert result.exit_code == 1

    def test_a_check_that_cannot_run_fails_rather_than_vanishing(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            smoke,
            "probe",
            lambda **_: _ready(),
        )

        def boom(code: str, _route: Any = None, **__: Any) -> Any:
            raise FiddleError("the Lua raised")

        monkeypatch.setattr(smoke, "exec_in_scripting", boom)
        result = run(checks=(Check("x", "return 1", lambda v: True, "why"),), timeout=0.1)
        assert result.failed and "could not run" in result.failed[0].detail


class TestTransportSplit:
    """A VEAF assertion rides the mission bridge; a DCS-native one rides the hook (ticket 04)."""

    def test_a_veaf_check_goes_through_the_bridge_not_the_hook(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(smoke, "probe", lambda **_: _ready())
        monkeypatch.setattr(smoke, "resolve_api_key", lambda *a, **k: "KEY")
        bridge_calls: list[str] = []

        def fake_bridge(serve_url: str, key: str, code: str, timeout: float = 10.0) -> str:
            bridge_calls.append(code)
            return "table" if "'ok'" not in code else "ok"

        # A hook that would answer 'veaf-absent' — the very trap the split removes.
        monkeypatch.setattr(smoke, "exec_over_bridge", fake_bridge)
        monkeypatch.setattr(smoke, "exec_in_scripting", lambda *a, **k: "veaf-absent")

        check = Check("veaf", "return type(veaf)", lambda v: v == "table", "why", transport=smoke.Transport.BRIDGE)
        result = run(checks=(check,), timeout=0.1)
        assert result.outcomes[0].passed, "the bridge sees veaf where the hook does not"
        assert "return type(veaf)" in bridge_calls  # it went to the bridge

    def test_a_veaf_check_fails_naming_dcs_serve_when_the_bridge_is_absent(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(smoke, "probe", lambda **_: _ready())
        monkeypatch.setattr(smoke, "resolve_api_key", lambda *a, **k: "KEY")

        def unreachable(*a: Any, **k: Any) -> str:
            raise RuntimeError("cannot reach dcs-serve")

        monkeypatch.setattr(smoke, "exec_over_bridge", unreachable)
        check = Check("veaf", "return type(veaf)", lambda v: v == "table", "why", transport=smoke.Transport.BRIDGE)
        result = run(checks=(check,), timeout=0.1)
        assert not result.outcomes[0].passed
        detail = result.outcomes[0].detail
        assert "dcs-serve" in detail and "veaf-absent" not in detail, "name the transport, not the symptom"

    def test_a_missing_api_key_names_dcs_serve_too(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(smoke, "probe", lambda **_: _ready())

        def no_key(*a: Any, **k: Any) -> str:
            raise RuntimeError("no API key found")

        monkeypatch.setattr(smoke, "resolve_api_key", no_key)
        check = Check("veaf", "return type(veaf)", lambda v: v == "table", "why", transport=smoke.Transport.BRIDGE)
        result = run(checks=(check,), timeout=0.1)
        assert not result.outcomes[0].passed and "dcs-serve" in result.outcomes[0].detail

    def test_a_hook_check_never_touches_the_bridge(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(smoke, "probe", lambda **_: _ready())
        monkeypatch.setattr(smoke, "exec_in_scripting", lambda code, _route, **__: "table")

        def must_not_call(*a: Any, **k: Any) -> str:
            raise AssertionError("a hook check must not open the bridge")

        monkeypatch.setattr(smoke, "exec_over_bridge", must_not_call)
        # no VEAF check present, so the bridge is never resolved
        check = Check("d", "return type(Disposition)", lambda v: v == "table", "why")
        result = run(checks=(check,), timeout=0.1)
        assert result.outcomes[0].passed

    def test_the_shipped_veaf_checks_are_tagged_for_the_bridge(self):
        by_name = {c.name: c for c in CHECKS}
        assert by_name["veaf-loaded"].transport == smoke.Transport.BRIDGE
        assert by_name["findspawnpoint-exists"].transport == smoke.Transport.BRIDGE
        assert by_name["disposition-exists"].transport == smoke.Transport.HOOK


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

    def test_returns_points_rejects_a_raise(self):
        # Superseded by test_the_point_count_survives_as_a_tagged_string for the positive cases: this
        # check used to accept a bare int, which measurement showed can never arrive.
        check = self._check("disposition-returns-points")
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

    def test_no_expectation_can_be_satisfied_by_a_value_the_transport_destroyed(self):
        # Measured: a Lua boolean and a Lua table both cross as ''. So an expectation that '' satisfies
        # cannot tell success from a reply that never made it — which is what happened to the
        # coalition-submenu check, left inconclusive on the single question its lot has waited on since
        # July. Every check must return a string; this sweep is what enforces it.
        for check in CHECKS:
            for lost in smoke.TRANSPORT_LOSS:
                assert check.expect(lost) is False, f"{check.name} is satisfied by a destroyed value"

    def test_the_point_count_survives_as_a_tagged_string(self):
        # `#r` is a number and numbers cross as strings, so the old `isinstance(v, (int, float))` could
        # never pass. Tagged rather than bare so `count:0` ("asked, got nothing") stays distinguishable
        # from '' ("the answer was destroyed") — two different facts about Disposition.
        check = self._check("disposition-returns-points")
        assert check.expect("count:10") is True
        assert check.expect("count:0") is True, "zero points is a measurement, not a failure"
        assert check.expect("10") is False, "an untagged number is the shape that used to be ambiguous"
        assert check.expect("count:") is False
        assert check.expect("no-singleton") is False

    def test_the_submenu_verdict_is_a_word_not_a_boolean(self):
        check = self._check("coalition-scoped-submenu-accepted")
        assert check.expect("created") is True
        assert check.expect("refused-nil") is False, "DCS handing back nil is the negative answer"
        assert check.expect(True) is False, "a boolean can never arrive, so it must not satisfy this"

    def test_no_expectation_accepts_a_sentinel_a_raise_or_a_lua_error(self):
        # Swept across every check, because this is a whole class of wrong verdict rather than one bug.
        # The Lua-error entries are the third instance of that class: net.dostring_in hands a failure
        # back as a truthy string that is not a sentinel and does not start with "raised:", so
        # `veaf-loaded` — whose whole job is to notice an empty environment — went green on it.
        errors = [":1: attempt to index global 'env' (a nil value)", '[string "c"]:2: attempt to call a nil value']
        for check in CHECKS:
            for bad in list(smoke.SENTINELS) + ["raised: bad argument #2"] + errors:
                assert check.expect(bad) is False, f"{check.name} accepts {bad!r}"

    def test_the_submenu_check_still_refuses_the_two_shapes_that_once_passed_wrongly(self):
        # Two historical bugs on the same check, kept as regressions. First (Sourcery, PR #659): it
        # returned a constant 'accepted' whenever pcall did not raise, discarding the inner result, so a
        # nil from DCS read as a pass. Second: the verdict was a boolean, and every boolean crosses this
        # transport as '' — so it answered nothing at all. Positive case in
        # test_the_submenu_verdict_is_a_word_not_a_boolean.
        check = self._check("coalition-scoped-submenu-accepted")
        assert check.expect("accepted") is False, "the old constant must no longer satisfy it"
        assert check.expect(False) is False
        assert check.expect("raised: invalid parent") is False

    def test_every_check_records_why_it_exists(self):
        # A check whose purpose nobody wrote down is a check nobody dares delete.
        assert all(c.why.strip() for c in CHECKS)

    def test_no_check_asks_for_a_field_the_scripts_never_define(self):
        # `veaf-loaded` read `veaf.MAIN_VERSION`, which has never existed anywhere in the Lua — the
        # field is `veaf.BuildVersion`. Lua's `a and b or c` falls through to `c` when `b` is nil, so
        # the check returned its "VEAF is absent" sentinel *unconditionally*, from 2026-08-05 to
        # 2026-08-22, against missions where VEAF was plainly loaded. It surfaced only because
        # `findspawnpoint-exists` answered 'function' on the same run: two results side by side, flatly
        # contradictory, and one of them had to be wrong.
        #
        # A check that cannot pass is the same defect class as a check that cannot fail. Both return a
        # confident verdict about something they never measured.
        scripts = Path(__file__).parents[3] / "src" / "scripts" / "veaf"
        definition = re.compile(r"^\s*(?:function\s+)?(veaf[A-Za-z0-9_]*)[.:]([A-Za-z0-9_]+)\s*(?:\(|=)", re.M)
        defined: set[tuple[str, str]] = set()
        for path in sorted(scripts.glob("veaf*.lua")):
            for match in definition.finditer(path.read_text(encoding="utf-8", errors="replace")):
                defined.add((match.group(1), match.group(2)))
        assert len(defined) > 500, "the sweep read far fewer symbols than expected"

        tables = {table for table, _ in defined}
        reference = re.compile(r"\b(veaf[A-Za-z0-9_]*)\.([A-Za-z0-9_]+)")
        # Pin the pattern itself. The first version of this line was written through a shell
        # heredoc that turned `\b` into a literal backspace (0x08), so the regex looked for a
        # control character, matched nothing, and this test passed on the very defect it exists
        # for. Invisible at a grep, too: a terminal renders 0x08 by eating the character before
        # it, so the line looked correct.
        assert reference.pattern.startswith("\\b"), "the word-boundary escape was mangled"
        missing: dict[str, list[str]] = {}
        for check in CHECKS:
            for match in reference.finditer(check.lua):
                table, name = match.group(1), match.group(2)
                if table in tables and (table, name) not in defined:
                    missing.setdefault(f"{table}.{name}", []).append(check.name)
        assert missing == {}, f"checks reading fields the scripts never define: {missing}"


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


class TestEveryChunkCompiles:
    """Every check's Lua must parse in real Lua 5.1 before it ever reaches DCS.

    The chunks are built by string concatenation, so a missing space between two fragments or an
    unbalanced `end` is a syntax error that surfaces only as a failed check in a live session — one
    round-trip through David's DCS to learn something `luac` answers instantly. `poetry run test-lua`
    already requires the interpreter, so this asks for nothing new.
    """

    def test_all_of_them(self):
        lua_binary = shutil.which("lua") or shutil.which("lua5.1")
        if not lua_binary:
            pytest.skip("no lua interpreter on PATH")
        for check in CHECKS:
            with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8", delete=False) as handle:
                # wrapped in a function so the chunk's `return` statements are legal
                handle.write("return function() " + check.lua + " end")
                path = handle.name
            try:
                result = subprocess.run(
                    [lua_binary, "-e", f"local f, e = loadfile([[{path}]]) print(f and 'OK' or e)"],
                    capture_output=True,
                    text=True,
                )
                answer = (result.stdout or result.stderr).strip()
                assert answer == "OK", f"{check.name} does not parse: {answer}"
            finally:
                os.unlink(path)


class TestCsarOverWater:
    """FEAT-SMOKE-CSAR-WATER — #245 answered by an assertion rather than a pilot.

    Deciding where a CSAR survivor ends up needs a few scripting calls and no aircraft: trigger an
    ejection, find the survivor, ask what is underneath. These tests cover the parts that are decidable
    without DCS — the verdict logic and the shape of the chunk. The measurement itself needs a running
    DCS and is recorded in the lot's PRD.
    """

    def _check(self, name: str) -> smoke.Check:
        return next(c for c in CHECKS if c.name == name)

    def test_open_sea_passes_only_when_the_survivor_is_lost(self):
        # David's arbitration on #245: nothing dry within 500 m means he counts as dead. So out at sea
        # "no survivor" is the correct outcome, and any placement at all is the failure — including a dry
        # one, which would mean he was moved further than the rule allows.
        check = self._check("csar-avoids-water-open-sea")
        assert check.expect("mode:open lost:1") is True
        assert check.expect("mode:open lost:0 surface:3 dry:0") is False
        assert check.expect("mode:open lost:0 surface:1 dry:1") is False

    def test_a_coast_passes_only_when_a_survivor_stands_on_dry_ground(self):
        # The mirror image, and the failure the open-sea check structurally cannot see: with land within
        # 150 m the pilot is inside the rescue radius, so losing him is a defect, not the rule.
        check = self._check("csar-avoids-water-coast")
        assert check.expect("mode:coast lost:0 surface:1 dry:1") is True
        assert check.expect("mode:coast lost:0 surface:3 dry:0") is False
        assert check.expect("mode:coast lost:1") is False, "a rescuable pilot was written off"

    def test_the_two_modes_disagree_about_the_same_reply(self):
        # The point of splitting the verdict. One expectation for both modes would have to accept one of
        # the two failures, and that is how a half-working rule passes: whichever half it breaks, some
        # check goes green. Pinned as a property rather than as two separate assertions.
        lost = "lost:1"
        assert self._check("csar-avoids-water-open-sea").expect(f"mode:open {lost}") is True
        assert self._check("csar-avoids-water-coast").expect(f"mode:coast {lost}") is False

    def test_a_rescue_beyond_its_own_radius_fails_in_either_mode(self):
        # The radius *is* the rule, so exceeding it is a defect whichever mode notices. Tolerant of the
        # field being absent — an older mission's reply must still parse — but never lenient when it is
        # present, which is what stops the bound from drifting unnoticed.
        coast = self._check("csar-avoids-water-coast")
        assert coast.expect("mode:coast lost:0 surface:1 dry:1 moved:480 radius:500") is True
        assert coast.expect("mode:coast lost:0 surface:1 dry:1 moved:900 radius:500") is False
        assert coast.expect("mode:coast lost:0 surface:1 dry:1") is True, "absent field must still parse"

    def test_the_reply_carries_enough_to_tell_two_causes_apart(self):
        # Written after two round-trips spent on the same reply. `surface:1 dry:1` from the open-sea check
        # is consistent with two very different stories — a spot the sweep misjudged, or a fix reaching
        # past its own radius — and the reply could not distinguish them, so each hypothesis cost a run in
        # someone else's DCS. These fields separate them in one.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert "moved:" in lua, f"{name} does not report how far the survivor travelled"
            assert "radius:" in lua, f"{name} does not report the bound it was measured against"
            assert "asked:" in lua, f"{name} does not report the surface at the ejection point"
            assert "wrapped:" in lua, f"{name} cannot say whether the replacement was installed"

    def test_the_measurement_goes_through_addcsar_not_the_raw_placement(self):
        # This is the defect the 2026-08-22 run exposed. The chunk called `csar.spawnGroup`, the raw
        # placement *underneath* `csar.addCsar` — and FIX-CSAR-SPAWNS-ON-WATER replaces `addCsar`. So the
        # check bypassed the fix and reported `surface:3 dry:0` against a working product: a wrong verdict
        # on a correct behaviour, which is worse than no verdict because it reads as a regression.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert "pcall(csar.addCsar," in lua, f"{name} must exercise the replaced entry point"
            assert "pcall(csar.spawnGroup," not in lua, f"{name} bypasses the fix it is meant to measure"

    def test_the_survivor_and_csars_bookkeeping_are_both_cleaned_up(self):
        # Destroying the group alone leaves a woundedGroups entry, and CSAR then announces a survivor
        # that no longer exists for the rest of the mission — contaminating every later check and every
        # repeat run.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert "g:destroy()" in lua, f"{name} leaks a CSAR pilot"
            assert "csar.woundedGroups[name] = nil" in lua, f"{name} leaks a wounded-pilot entry"

    def test_every_could_not_ask_answer_fails_rather_than_passing_vacuously(self):
        # The failure mode this whole module is written against: a check that goes green when it never
        # managed to ask closes #245 on nothing at all. Swept over both modes, because the open-sea
        # verdict is the looser of the two and is where a sentinel could slip through.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            check = self._check(name)
            for reply in (
                "csar-absent",
                "no-airbases",
                "no-water-found-open",
                "no-group",
                "no-unit",
                "raised: attempt to index a nil value",
                "",
                "dry:1",  # untagged: no mode, so not an answer from this check
                "lost:1",  # no mode either: could have come from anywhere
                "mode:open",  # a mode with no verdict at all
                "mode:bogus lost:1",
            ):
                assert check.expect(reply) is False, f"{name} accepts {reply!r}"

    def test_both_positions_are_checked_because_they_ask_different_questions(self):
        # Open sea is the reported case; the coast is the one that tells us whether CSAR goes through
        # veaf.findSpawnPoint at all. A pass at sea with a failure inshore means it has its own path.
        names = {c.name for c in CHECKS}
        assert "csar-avoids-water-open-sea" in names
        assert "csar-avoids-water-coast" in names

    def test_the_two_chunks_classify_the_spot_differently(self):
        openly = self._check("csar-avoids-water-open-sea").lua
        coast = self._check("csar-avoids-water-coast").lua
        assert openly != coast, "both modes generated the same chunk, so one of them asks nothing"
        assert "if not dry_in_radius then" in openly
        assert "if land_near then" in coast
        assert "mode:open" in openly and "mode:coast" in coast

    def test_open_sea_is_defined_against_the_rescue_radius_the_product_owns(self):
        # The 2026-08-22 failure. "Open sea" was eight samples at 150 m, while the fix searches for dry
        # ground out to 500 m — so a spot 300 m off a coast satisfied both, the survivor was correctly
        # moved ashore, and the check called that a defect. `surface:1 dry:1` on the open-sea check was a
        # correct product reported as broken.
        #
        # Two properties, and the first matters more: the radius is *read from the product*. A test that
        # copies a distance the product owns drifts from it the first time the product changes, and the
        # drift shows up as a false failure nobody trusts.
        openly = self._check("csar-avoids-water-open-sea").lua
        assert "veaf.CSAR_SURVIVOR_SEARCH_RADIUS_METRES" in openly, "the radius must be read, not copied"
        assert "for rr = 100, R * 2, 100 do" in openly, "one ring cannot prove an absence over an area"
        # The 2x margin is not padding. `findSpawnPoint` draws random candidates, so near a marginal
        # spot it succeeds on some runs and not others: the same harness answered `lost:0` then
        # `lost:1` with no code change in between (2026-08-22). Sampling only out to the radius makes
        # the check flicker against a correct product.

    def test_the_surface_is_read_with_the_easting_in_y(self):
        # docs/agents/dcs-coordinates.md: `land.getSurfaceType` takes a vec2 whose `y` is the easting,
        # while `getPoint()` is a vec3 whose `y` is the altitude. Passing `y = p.y` reads the surface a
        # hundred kilometres away and reports it cheerfully — no error, just a wrong answer. This is the
        # one line of the chunk that cannot be checked any other way without DCS.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert "{x = p.x, y = p.z}" in lua, f"{name} must feed the easting as the vec2 y"
            assert "y = p.y" not in lua, f"{name} passes an altitude where an easting belongs"

    def test_no_coordinate_is_hard_coded_so_the_check_travels_between_theatres(self):
        # The smoke mission's theatre is not this check's business: it anchors on the first airbase and
        # sweeps for water. A literal coordinate would silently pass or fail depending on the map.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert "world.getAirbases()" in lua
            assert "getPoint()" in lua

    def test_the_spawned_group_is_cleaned_up_exactly_once_unconditionally(self):
        # It runs inside a real mission: a check that leaves a group behind changes what the next one
        # measures. This asserted `count >= 2` while the chunk had a destroy per exit path — a shape
        # assertion that the better structure broke, since wrapping the reads in a pcall leaves exactly
        # one destroy that always runs. One unconditional call is stronger than several conditional ones.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            assert lua.count("g:destroy()") == 1, f"{name}: one destroy, not one per exit path"

    def test_a_malformed_or_partial_reply_fails(self):
        # The gap Sourcery found: accepting anything that started with `mode:` and carried `dry:1` meant a
        # truncated bridge reply passed while proving nothing — in the check meant to settle #245.
        #
        # Asserted against the **coast** check on purpose. Only that mode reads `surface` and `dry` at
        # all, since open sea is satisfied by `lost:1` alone. Pointed at the open-sea check these replies
        # would still fail, but for the wrong reason — a missing `lost` rather than the malformed field
        # each line is here to pin. That is how a rejection test quietly stops testing what it documents.
        check = self._check("csar-avoids-water-coast")
        for reply in (
            "mode:bogus lost:0 surface:1 dry:1",  # a mode no check emits
            "mode:coast lost:0 dry:1",  # no surface: nothing was actually read
            "mode:coast lost:0 surface: dry:1",  # surface present but empty
            "mode:coast lost:0 surface:water dry:1",  # surface not a number DCS returned
            "mode:coast lost:0 surface:1 dry:yes",  # verdict not a flag
            "mode:coast lost:0 surface:1",  # no verdict at all
            "mode:coast surface:1 dry:1",  # no `lost`: the survivor's fate is unstated
            "mode:coast lost:maybe surface:1 dry:1",  # `lost` not a flag
            "surface:1 dry:1",  # no mode
        ):
            assert check.expect(reply) is False, f"{reply!r} must not pass"

    def test_only_the_two_real_modes_are_accepted(self):
        # The verdict function is shared by both checks, so it must recognise both mode words and no
        # others — a typo in the generated chunk would otherwise read as a legitimate answer.
        check = self._check("csar-avoids-water-coast")
        assert check.expect("mode:coast lost:0 surface:1 dry:1") is True
        assert check.expect("mode:lake lost:0 surface:1 dry:1") is False
        assert check.expect("mode:open lost:1") is True, "the verdict is shared by both checks"

    def test_the_group_is_destroyed_even_if_a_reading_raises(self):
        # A leaked CSAR pilot contaminates every later check and every repeat run, so the destroy must not
        # sit behind a call that can raise. Asserting on the shape is all that is possible without DCS:
        # the reads are inside a pcall, and the destroy comes after it, unconditionally.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            lua = self._check(name).lua
            reads = lua.index("local measured, result = pcall(function()")
            destroy = lua.index("g:destroy()", reads)
            assert "getUnits()" in lua[reads:destroy], f"{name}: the reads must be inside the pcall"
            assert "getSurfaceType" in lua[reads:destroy]
            # nothing between the pcall closing and the destroy that could return first
            between = lua[lua.index("end) ", reads) : destroy]
            assert "return" not in between, f"{name}: something can return before the group is destroyed"

    def test_it_runs_where_the_mission_scripts_do(self):
        # `csar` is a mission-environment global loaded by mission-script.lua, so the hook environment
        # would report `csar-absent` for a mission that has it — a false negative on the whole lot.
        for name in ("csar-avoids-water-open-sea", "csar-avoids-water-coast"):
            assert self._check(name).transport is smoke.Transport.BRIDGE
