"""Unit tests for the in-DCS smoke harness.

There is no DCS here, and there will not be one in CI either — that is the defining constraint of
this harness, not an accident. So these tests stand a function in for the bridge and pin the checks
themselves: that their expectations cannot be satisfied by a sentinel, an error or a value the
transport destroyed, and that their Lua parses.
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import pytest
from veaf_libs import dcs_smoke as smoke
from veaf_libs.dcs_bridge_capture import BridgeLuaError
from veaf_libs.dcs_smoke import CHECKS, SPOTTER_CHECKS, Check, Outcome, Result, format_result, run
from veaf_libs.i18n import language

from veaf_build.lua_tests import _find_lua


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


class TestRun:
    """The runner over the bridge: one outcome per check, and a check that cannot run fails."""

    def test_every_check_is_sent_to_the_mission_and_reported(self):
        sent: list[str] = []

        def exec_lua(code: str) -> str:
            sent.append(code)
            return "table"

        checks = (
            Check("a", "return type(Disposition)", lambda v: v == "table", "why a"),
            Check("b", "return type(veaf)", lambda v: v == "function", "why b"),
        )
        result = run(checks, exec_lua)
        assert sent == ["return type(Disposition)", "return type(veaf)"]
        assert [(o.name, o.passed) for o in result.outcomes] == [("a", True), ("b", False)]
        assert result.exit_code == 1

    def test_a_check_that_cannot_run_fails_rather_than_vanishing(self):
        def exec_lua(code: str) -> str:
            raise BridgeLuaError("the Lua raised in the mission: boom")

        result = run((Check("a", "return x", lambda v: True, "why"),), exec_lua)
        assert not result.outcomes[0].passed
        assert "boom" in result.outcomes[0].detail

    def test_a_clean_run_exits_zero(self):
        result = run((Check("a", "return 'ok'", lambda v: v == "ok", "why"),), lambda code: "ok")
        assert result.exit_code == 0


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
    def test_failures_are_framed_as_measurements(self):
        result = Result(outcomes=[Outcome("a", True, "returned 1"), Outcome("b", False, "returned nil")])
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

    The interpreter comes from `veaf_build.lua_tests._find_lua`, which version-checks it, rather than
    from `shutil.which("lua")` as first written. Two interpreters sit on this machine — a scoop 5.5.0
    shim and the 5.1.5 in Program Files — and which one `which` answers depends on the PATH of the
    shell that launched pytest. It happened to answer 5.1.5, so this test was right by accident: a
    5.5 rejects perfectly valid 5.1 (it reads a `for` variable as const) and accepts syntax DCS would
    not, so the same test could just as well have reported failures that are not defects.
    """

    def test_all_of_them(self):
        try:
            lua_binary = _find_lua()
        except Exception as exc:  # typer.BadParameter when no 5.1 interpreter is installed
            pytest.skip(f"no Lua 5.1 interpreter: {exc}")
        # Both suites, not just the default one. `SPOTTER_CHECKS` lives outside `CHECKS` on purpose,
        # and a sweep that walks only the default list is exactly how an opt-in suite goes unchecked
        # until somebody runs it in front of a live DCS.
        for check in (*CHECKS, *SPOTTER_CHECKS):
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


class TestSpotterSuite:
    """FEAT-SPOTTER-NETWORK's rig checks, and why they are a suite of their own.

    They assert on a geometry only ``test/veaf-tools/demo-spotter-network`` carries — a MANPADS
    spotter 10 km from a battery it can inform, and a control battery 60 km away that no report can
    reach. Run against any other mission they would be two permanent failures, and a harness whose
    default run is always red is a harness nobody reads.
    """

    def _check(self, name: str) -> Check:
        return next(c for c in SPOTTER_CHECKS if c.name == name)

    def test_they_are_not_in_the_default_suite(self):
        assert not (set(c.name for c in CHECKS) & set(c.name for c in SPOTTER_CHECKS))

    def test_no_sentinel_and_no_lost_value_can_pass(self):
        # The rule this module is built on: a boolean and a table both arrive as `''`, so an
        # expectation that `''` satisfies cannot tell success from a value the transport destroyed.
        for check in SPOTTER_CHECKS:
            for reply in ("", "veaf-absent", "no-spotter-history", "no-such-site", "nil"):
                assert not check.expect(reply), f"{check.name} accepted {reply!r}"

    def test_the_two_halves_disagree_on_the_same_answer(self):
        # The point of the control: one check passes on a wake-up, the other passes on none. A run
        # where both are green for the same reading would mean the rig measured nothing.
        reached = self._check("spotter-relay-reached-the-network-battery")
        control = self._check("spotter-relay-did-not-reach-the-control-battery")
        assert reached.expect("woken:1") and not control.expect("woken:1")
        assert control.expect("woken:0") and not reached.expect("woken:0")

    def test_the_count_must_be_a_number(self):
        # `woken:` tags the count because `''` is what a lost value looks like; a malformed tail must
        # not slip through as a pass.
        reached = self._check("spotter-relay-reached-the-network-battery")
        for malformed in ("woken:", "woken:many", "woken:-1", "woken:1.5"):
            assert not reached.expect(malformed), malformed

    def test_the_chunk_names_the_site_it_was_built_for(self):
        assert "NetworkSa6" in self._check("spotter-relay-reached-the-network-battery").lua
        assert "ControlSa6" in self._check("spotter-relay-did-not-reach-the-control-battery").lua

    def test_the_cli_resolves_the_two_suites_and_refuses_a_typo(self):
        # A typo must end the run rather than fall back to the default: a suite chosen by accident
        # reports a green that answers a question nobody asked.
        import typer
        from veaf_tools.commands.smoke_test import _resolve_suite

        assert _resolve_suite("default") is CHECKS
        assert _resolve_suite("spotter") is SPOTTER_CHECKS
        with pytest.raises(typer.Exit):
            _resolve_suite("spoter")
