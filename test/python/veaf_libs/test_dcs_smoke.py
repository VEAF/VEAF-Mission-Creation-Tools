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
