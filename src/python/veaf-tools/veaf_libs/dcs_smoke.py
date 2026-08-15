"""Assert VEAF runtime behaviour inside a real DCS, unattended.

``poetry run test-lua`` runs against ``test/lua/dcs_mocks.lua`` — a DCS we wrote ourselves, which can
only confirm what we already believed. Anything beyond it has been ending up in a queue waiting for a
person to fly it: the ``Disposition`` probe, the coalition-scoped submenu question, Foothold's
staggered script loading, and the guided checklists, which were signed off by someone sitting in a
cockpit. This module is how those get answered by a machine instead.

**Assertions are data.** A check is a :class:`Check` — a name, a Lua snippet, and what its result must
look like. Adding one is adding an entry, not editing a driver, which is what keeps
``FEAT-DCS-SMOKE-HARNESS`` ticket 03 to a list rather than a refactor.

**Scope of this first slice**: DCS must already be running (the main menu is enough — the hook answers
there, which is the measurement that makes any of this possible). Launching and quitting DCS are not
here: they are OS-level process work whose DCS-side calls this repository has never made, and shipping
them unexercised would be the kind of plausible-looking code that costs more than it saves. The probe
reports whether they are available, so the follow-up has its facts.

This never runs in CI: GitHub runners have no DCS, no licence and no GPU. It is a local tool, and it
skips rather than fails when there is nothing to talk to.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, exec_over_bridge, resolve_api_key
from veaf_libs.dcs_fiddle_client import (
    DEFAULT_FIDDLE_URL,
    ENV_MISSION,
    LUA_ERROR,
    Capabilities,
    FiddleError,
    exec_in_scripting,
    probe,
)
from veaf_libs.i18n import t

#: The two transports, and why a check chooses one over the other (ticket 04). The fiddle **hook**
#: reaches a bare scripting state — DCS's own globals (``Disposition``, ``missionCommands``,
#: ``coalition``) are there, the mission's scripts are not. The mission **bridge** (``dcs-serve`` →
#: ``dcs-bridge.lua``, injected into the mission) runs where ``veaf`` lives. So a DCS-native check goes
#: through the hook, and a VEAF assertion goes through the bridge, or it reads ``veaf-absent`` forever.
TRANSPORT_HOOK = "hook"
TRANSPORT_BRIDGE = "bridge"


@dataclass(frozen=True)
class Check:
    """One assertion, evaluated inside DCS.

    Args:
        name: Short identifier, printed in the report.
        lua: Lua chunk to run. It must ``return`` something for the expectation to inspect.
        expect: Called with the decoded result; returns ``True`` when the check passes.
        why: What knowing this answers, and for which lot. A check whose purpose nobody recorded is a
            check nobody dares delete.
        env: Which environment to run in; the mission one by default.
        transport: ``TRANSPORT_HOOK`` for a DCS-native check, ``TRANSPORT_BRIDGE`` for one that needs
            the ``veaf`` global (see the transport constants above). Defaults to the hook.
    """

    name: str
    lua: str
    expect: Callable[[Any], bool]
    why: str
    env: str = ENV_MISSION
    transport: str = TRANSPORT_HOOK


@dataclass
class Outcome:
    """What running one check produced."""

    name: str
    passed: bool
    detail: str


@dataclass
class Result:
    """Everything a run produced."""

    skipped: bool = False
    skip_reason: str = ""
    capabilities: Capabilities | None = None
    outcomes: list[Outcome] = field(default_factory=list)

    @property
    def failed(self) -> list[Outcome]:
        """The checks that did not pass."""
        return [o for o in self.outcomes if not o.passed]

    @property
    def exit_code(self) -> int:
        """``0`` when every check passed or the run was skipped, ``1`` otherwise."""
        return 1 if self.failed else 0


#: Sentinels a check's Lua returns instead of raising, so a missing prerequisite is legible rather
#: than an opaque error. They are **truthy strings**, so any expectation must reject them explicitly —
#: an early version of the veaf-loaded check used a plain truthiness test and therefore passed in
#: exactly the situation it existed to catch.
SENTINELS: frozenset[str] = frozenset({"nil", "veaf-absent", "no-singleton", "not-a-table"})

#: **A check's Lua must return a string. Always.**
#:
#: Measured 2026-08-06 across the working route, and it is the rule everything else here follows from:
#:
#: =============  ==========================
#: Lua returns    Python receives
#: =============  ==========================
#: ``'x'``        ``'x'``
#: ``3``          ``'3'``   (a *string*)
#: ``true``       ``''``    (**destroyed**)
#: ``{1, 2}``     ``''``    (**destroyed**)
#: =============  ==========================
#:
#: So a boolean and a table are indistinguishable from each other and from a chunk that returned
#: nothing. Two of the six checks shipped in the first slice were therefore unpassable by construction —
#: one expected a number, one expected ``True`` — and the second was worse than unpassable: it was
#: **inconclusive on the very question it existed to settle**, because the answer it wanted was a boolean
#: and every boolean arrives as ``''``.
#:
#: Hence :data:`TRANSPORT_LOSS`, swept against every expectation in the tests: an expectation that ``''``
#: can satisfy is an expectation that cannot tell success from a value the transport threw away.
TRANSPORT_LOSS: frozenset[str] = frozenset({""})


def _is_truthy(value: Any) -> bool:
    """Whether DCS reported something usable rather than nil, false, empty, a sentinel or an error.

    Args:
        value: What the check's Lua returned.

    Returns:
        ``True`` only for a value that means the thing being checked is there.

    The error case is the one that keeps coming back. ``net.dostring_in`` returns a Lua failure **as its
    string result**, so an error message reaches this function looking like an ordinary answer — truthy,
    not a sentinel, not prefixed ``raised:``. Measured on a live DCS: ``:1: attempt to index global
    'env' (a nil value)``. This check exists to catch a missing ``veaf``, and it would have gone green on
    exactly the reply that proves nothing ran.
    """
    if isinstance(value, str) and (value in SENTINELS or value.startswith("raised:") or LUA_ERROR.match(value)):
        return False
    return bool(value)


#: The checks that answer questions currently waiting on a human. Each cites the lot it unblocks.
#:
#: `Disposition` is the richest and the reason FEAT-SCENERY-AWARE-SPAWN is still open: ADR 0018
#: records its scenery avoidance as *asserted, not measured*, because the probe was deferred. These
#: entries measure the parts that do not need a village to stand next to; the avoidance itself needs a
#: mission placed near one, which is what the committed smoke mission is for.
CHECKS: tuple[Check, ...] = (
    Check(
        name="disposition-exists",
        lua="return type(Disposition)",
        expect=lambda v: v == "table",
        why="ADR 0018 depends on an undocumented singleton nobody here has called. FEAT-SCENERY-AWARE-SPAWN ticket 01.",
    ),
    Check(
        name="disposition-has-getsimplezones",
        lua="return type(Disposition) == 'table' and type(Disposition.getSimpleZones) or 'no-singleton'",
        expect=lambda v: v == "function",
        why="The one function tier 1 of veaf.findSpawnPoint calls. If it is absent, that tier is "
        "dead weight to delete rather than a bug to debug.",
    ),
    Check(
        name="disposition-returns-points",
        # `#r` is a number, and a number crosses this transport as a string — so the count is tagged
        # rather than returned bare. Tagged because `''` is what a lost value looks like: `count:0` says
        # "asked, got nothing", and an empty reply says "the answer never made it", which are different
        # facts about `Disposition` and were previously the same reply.
        lua=(
            "if type(Disposition) ~= 'table' or type(Disposition.getSimpleZones) ~= 'function' then "
            "return 'no-singleton' end "
            "local ok, r = pcall(Disposition.getSimpleZones, {x=0, y=0, z=0}, 1852, 100, 10) "
            "if not ok then return 'raised: ' .. tostring(r) end "
            "if type(r) ~= 'table' then return 'not-a-table' end "
            "return 'count:' .. tostring(#r)"
        ),
        expect=lambda v: isinstance(v, str) and v.startswith("count:") and v[6:].isdigit(),
        why="Its return shape is unmeasured, which is why acceptableGroundPoint type-checks each "
        "candidate. Confirms whether that guard is paranoia or necessity.",
    ),
    Check(
        name="veaf-loaded",
        lua="return type(veaf) == 'table' and veaf.MAIN_VERSION or 'veaf-absent'",
        expect=_is_truthy,
        why="Sanity: proves the assertions run where the VEAF scripts do, not in an empty "
        "environment that would make every other check vacuously pass.",
        transport=TRANSPORT_BRIDGE,
    ),
    Check(
        name="findspawnpoint-exists",
        lua="return type(veaf) == 'table' and type(veaf.findSpawnPoint) or 'veaf-absent'",
        expect=lambda v: v == "function",
        why="The helper FEAT-SCENERY-AWARE-SPAWN shipped. Catches a mission built from a stale "
        "script bundle before any result is trusted.",
        transport=TRANSPORT_BRIDGE,
    ),
    Check(
        name="coalition-scoped-submenu-accepted",
        # The result of the inner function is what carries the answer, so it must be *returned*, not
        # discarded. An earlier version bound pcall's second value to `err`, ignored it on success and
        # returned a constant 'accepted' — so DCS quietly handing back nil would have read as a pass,
        # on the single question FEAT-COMBATZONE-MENU-COALITION has been waiting on. A check that
        # passes when the thing it checks failed is worse than no check: it would have unblocked that
        # lot in the wrong direction. Caught in review (Sourcery, PR #659).
        #
        # Then it went wrong a second way, and the first run in a live mission is what showed it: the
        # answer was a **boolean**, and a boolean crosses this transport as `''`. So the check came back
        # empty and could not distinguish "DCS refused" from "the reply was destroyed" — inconclusive on
        # the one question the lot has been waiting on since July, which is not better than the previous
        # false pass, only quieter. The verdict is now a word, per TRANSPORT_LOSS.
        lua=(
            "local ok, verdict = pcall(function() "
            "local root = missionCommands.addSubMenu('VEAF-SMOKE-ROOT') "
            "local scoped = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "
            "'VEAF-SMOKE-SCOPED', root) "
            "missionCommands.removeItem(root) "
            "if scoped == nil then return 'refused-nil' end "
            "return 'created' end) "
            "if not ok then return 'raised: ' .. tostring(verdict) end "
            "return verdict"
        ),
        expect=lambda v: v == "created",
        why="FEAT-COMBATZONE-MENU-COALITION has been waiting-human since July on exactly this: does "
        "DCS accept a coalition-scoped submenu under a global parent? The unit tests pin which API "
        "is called, not DCS's reaction.",
    ),
)


def run(
    checks: tuple[Check, ...] = CHECKS,
    url: str = DEFAULT_FIDDLE_URL,
    timeout: float = 10.0,
    serve_url: str = DEFAULT_SERVE_URL,
    api_key: str | None = None,
    config: str | None = None,
    bridge_timeout: float = 10.0,
) -> Result:
    """Probe DCS, then run *checks* against it over the transport each one names.

    DCS-native checks ride the fiddle **hook**; VEAF assertions ride the mission **bridge**
    (``dcs-serve``), because the hook's scripting state does not run the mission's scripts (ticket 04).

    Args:
        checks: The assertions to evaluate.
        url: Base URL of the ``dcs-fiddle-server.lua`` hook.
        timeout: Per-request socket timeout for the hook, in seconds.
        serve_url: Base URL of the ``dcs-serve`` HTTP API, for the bridge checks.
        api_key: The ``dcs-serve`` superuser token; resolved from a nearby config when omitted.
        config: Explicit path to a ``dcs-serve.yaml`` / ``dcs-client.yaml`` holding the key.
        bridge_timeout: Per-request timeout for the bridge, in seconds.

    Returns:
        A :class:`Result`. When DCS is not running, or no mission is loaded, it is **skipped** rather
        than failed: this tool is expected to be run where there is nothing to talk to, and a gate that
        cries wolf there would stop being run. A VEAF check whose bridge is absent **fails** naming
        ``dcs-serve`` rather than reporting ``veaf-absent``, because the bridge is a stated prerequisite
        of a VEAF assertion run, not "nothing to talk to".
    """
    result = Result()
    caps = probe(url=url, timeout=timeout)
    result.capabilities = caps

    if not caps.hook_alive:
        result.skipped = True
        result.skip_reason = t("smoke.skip.no_hook")
        return result

    if not caps.can_dostring_in:
        # Not "no mission loaded", which is what this used to say and what sent the reader looking for
        # the wrong fix: ED gates net.dostring_in behind autoexec.cfg, and every assertion below rides
        # on it, so no amount of loading a mission makes this run.
        result.skipped = True
        result.skip_reason = t("smoke.skip.no_dostring_in")
        return result

    if not caps.mission_name:
        result.skipped = True
        result.skip_reason = t(
            "smoke.skip.no_mission",
            load_mission=t("smoke.available") if caps.can_load_mission else t("smoke.not_available"),
        )
        return result

    if not caps.scripting_route:
        # A mission is running and nothing reaches even a bare scripting state, so a hook check would be
        # asserting about the wrong Lua. Skipping is the honest outcome — running them anyway yields
        # `env` errors that this transport hands back as ordinary strings, which is exactly how the
        # first slice came to report "mission environment answered" for a chunk that had crashed.
        result.skipped = True
        result.skip_reason = t(
            "smoke.skip.no_scripting_route", mission=caps.mission_name, error=caps.mission_env_error or "?"
        )
        return result

    # Resolve the bridge once, and only if a VEAF check needs it. Its absence is a failure to report,
    # not a reason to skip the whole run: the hook checks still answer.
    bridge = _resolve_bridge(checks, serve_url, api_key, config, bridge_timeout)

    for check in checks:
        if check.transport == TRANSPORT_BRIDGE:
            result.outcomes.append(_run_bridge_check(check, bridge, serve_url, bridge_timeout))
        else:
            result.outcomes.append(_run_hook_check(check, caps, url, timeout))
    return result


def _run_hook_check(check: Check, caps: Capabilities, url: str, timeout: float) -> Outcome:
    """Run a DCS-native check through the hook's scripting route."""
    try:
        # Sent through the measured route, not to `env=mission`: that is the trigger state, and a
        # check aimed there asks about Lua the VEAF scripts do not live in.
        value = exec_in_scripting(check.lua, caps.scripting_route, url=url, timeout=timeout)  # type: ignore[arg-type]
    except FiddleError as exc:
        return Outcome(check.name, False, f"could not run: {exc}")
    return Outcome(check.name, check.expect(value), f"returned {value!r}")


def _resolve_bridge(
    checks: tuple[Check, ...], serve_url: str, api_key: str | None, config: str | None, timeout: float
) -> str | tuple[str, str]:
    """Return ``(serve_url, key)`` when the bridge is reachable, or a message saying why it is not.

    Only attempts anything when a VEAF check is present. The reachability probe is a trivial chunk, so
    a failure means the transport, not the assertion.
    """
    if not any(c.transport == TRANSPORT_BRIDGE for c in checks):
        # Never displayed: with no bridge check, nothing consumes this. A token, not prose, so it is
        # not mistaken for a user-facing message.
        return "bridge-not-requested"
    try:
        key = resolve_api_key(api_key, config)
    except RuntimeError as exc:
        return t("smoke.bridge.no_key", error=str(exc))
    try:
        exec_over_bridge(serve_url, key, "return 'ok'", timeout)
    except RuntimeError as exc:
        return t("smoke.bridge.unreachable", url=serve_url, error=str(exc))
    return (serve_url, key)


def _run_bridge_check(check: Check, bridge: str | tuple[str, str], serve_url: str, timeout: float) -> Outcome:
    """Run a VEAF check through the mission bridge, or report the bridge's absence by name."""
    if not isinstance(bridge, tuple):
        # The bridge is the stated prerequisite: say `dcs-serve`, never let the check read `veaf-absent`
        # and send someone debugging the mission instead of starting the bridge.
        return Outcome(check.name, False, bridge)
    _, key = bridge
    try:
        value = exec_over_bridge(serve_url, key, check.lua, timeout)
    except RuntimeError as exc:
        return Outcome(check.name, False, f"could not run over the bridge: {exc}")
    return Outcome(check.name, check.expect(value), f"returned {value!r}")


def format_result(result: Result) -> str:
    """Render *result* for someone reading it at a workstation.

    Args:
        result: What :func:`run` produced.

    Returns:
        A human-readable multi-line report.
    """
    if result.skipped:
        return t("smoke.skipped", reason=result.skip_reason)

    lines = []
    if result.capabilities:
        lines.append(t("smoke.capabilities"))
        lines += [f"  - {note}" for note in result.capabilities.notes]
        lines.append("")

    lines.append(t("smoke.passed", passed=len(result.outcomes) - len(result.failed), total=len(result.outcomes)))
    for outcome in result.outcomes:
        lines.append(f"  [{'ok' if outcome.passed else 'FAIL'}] {outcome.name}: {outcome.detail}")
    if result.failed:
        lines.append("")
        lines.append(t("smoke.failure_is_a_measurement"))
    return "\n".join(lines)
