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

from veaf_libs.dcs_fiddle_client import (
    DEFAULT_FIDDLE_URL,
    ENV_MISSION,
    Capabilities,
    FiddleError,
    exec_lua,
    probe,
)
from veaf_libs.i18n import t


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
    """

    name: str
    lua: str
    expect: Callable[[Any], bool]
    why: str
    env: str = ENV_MISSION


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


def _is_truthy(value: Any) -> bool:
    """Whether DCS reported something usable rather than nil, false, empty or a sentinel."""
    if isinstance(value, str) and (value in SENTINELS or value.startswith("raised:")):
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
        lua=(
            "if type(Disposition) ~= 'table' or type(Disposition.getSimpleZones) ~= 'function' then "
            "return 'no-singleton' end "
            "local ok, r = pcall(Disposition.getSimpleZones, {x=0, y=0, z=0}, 1852, 100, 10) "
            "if not ok then return 'raised: ' .. tostring(r) end "
            "return type(r) == 'table' and #r or 'not-a-table'"
        ),
        expect=lambda v: isinstance(v, (int, float)),
        why="Its return shape is unmeasured, which is why acceptableGroundPoint type-checks each "
        "candidate. Confirms whether that guard is paranoia or necessity.",
    ),
    Check(
        name="veaf-loaded",
        lua="return type(veaf) == 'table' and veaf.MAIN_VERSION or 'veaf-absent'",
        expect=_is_truthy,
        why="Sanity: proves the assertions run where the VEAF scripts do, not in an empty "
        "environment that would make every other check vacuously pass.",
    ),
    Check(
        name="findspawnpoint-exists",
        lua="return type(veaf) == 'table' and type(veaf.findSpawnPoint) or 'veaf-absent'",
        expect=lambda v: v == "function",
        why="The helper FEAT-SCENERY-AWARE-SPAWN shipped. Catches a mission built from a stale "
        "script bundle before any result is trusted.",
    ),
    Check(
        name="coalition-scoped-submenu-accepted",
        # The result of the inner function is what carries the answer, so it must be *returned*, not
        # discarded. An earlier version bound pcall's second value to `err`, ignored it on success and
        # returned a constant 'accepted' — so DCS quietly handing back nil would have read as a pass,
        # on the single question FEAT-COMBATZONE-MENU-COALITION has been waiting on. A check that
        # passes when the thing it checks failed is worse than no check: it would have unblocked that
        # lot in the wrong direction. Caught in review (Sourcery, PR #659).
        lua=(
            "local ok, created = pcall(function() "
            "local root = missionCommands.addSubMenu('VEAF-SMOKE-ROOT') "
            "local scoped = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "
            "'VEAF-SMOKE-SCOPED', root) "
            "missionCommands.removeItem(root) "
            "return scoped ~= nil end) "
            "if not ok then return 'raised: ' .. tostring(created) end "
            "return created"
        ),
        expect=lambda v: v is True,
        why="FEAT-COMBATZONE-MENU-COALITION has been waiting-human since July on exactly this: does "
        "DCS accept a coalition-scoped submenu under a global parent? The unit tests pin which API "
        "is called, not DCS's reaction.",
    ),
)


def run(
    checks: tuple[Check, ...] = CHECKS,
    url: str = DEFAULT_FIDDLE_URL,
    timeout: float = 10.0,
) -> Result:
    """Probe DCS, then run *checks* against it.

    Args:
        checks: The assertions to evaluate.
        url: Base URL of the ``dcs-fiddle-server.lua`` hook.
        timeout: Per-request socket timeout in seconds.

    Returns:
        A :class:`Result`. When DCS is not running, or no mission is loaded, it is **skipped** rather
        than failed: this tool is expected to be run on machines and in situations where there is
        nothing to talk to, and a gate that cries wolf there would stop being run.
    """
    result = Result()
    caps = probe(url=url, timeout=timeout)
    result.capabilities = caps

    if not caps.hook_alive:
        result.skipped = True
        result.skip_reason = t("smoke.skip.no_hook")
        return result

    if not caps.mission_env_reachable:
        result.skipped = True
        result.skip_reason = t(
            "smoke.skip.no_mission",
            load_mission=t("smoke.available") if caps.can_load_mission else t("smoke.not_available"),
        )
        return result

    for check in checks:
        try:
            value = exec_lua(check.lua, env=check.env, url=url, timeout=timeout)
        except FiddleError as exc:
            result.outcomes.append(Outcome(check.name, False, f"could not run: {exc}"))
            continue
        passed = check.expect(value)
        result.outcomes.append(Outcome(check.name, passed, f"returned {value!r}"))
    return result


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
