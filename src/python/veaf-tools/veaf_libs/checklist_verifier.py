"""Verify a resolved checklist against a real cockpit, one control at a time.

A resolved value is a hypothesis until the animation argument has been read with the
control physically in the wanted position. This runs that check: it boxes the control in
the pilot's cockpit, waits for them to move it, reads the argument, and compares.

**Assisted, not automatic.** The tool never throws a switch itself. Boxing a control is
the one thing it does to the pilot's aircraft, and that is the point of the exercise:
during the first session of this ticket the pilot could not find the hydraulic transfer
pump, and boxing it answered the question instantly. Waiting for a value to *change and
settle* — rather than for a keypress — is what makes it usable from inside a cockpit,
where nobody is holding the keyboard.

The automatic mode this ticket also imagined (`a_cockpit_perform_clickable_action`) is not
here, and the reason is measured rather than assumed: it needs the numeric device and
command ids, and those are nowhere in a module's readable files — searching the A-10C's
whole `Cockpit/Scripts` tree for the ids its own autostart uses returns the autostart and
nothing else.

See ``.backlog/FEAT-ASSIST-AUTHORING/tickets/04-in-game-verification.md``.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass

from veaf_libs.i18n import t

#: How close a reading has to be to the expected value to count as a match. Wider than a
#: checklist's own tolerance: this is asking "is it the same position", not "is the step
#: satisfied", and an argument DCS animates towards a target can sit a hair off it.
MATCH_TOLERANCE = 0.02

#: How long to wait for the pilot to move one control before giving up on that step.
DEFAULT_STEP_TIMEOUT = 60.0

#: How long a reading has to hold still before it counts. A switch animates over a few
#: frames, so the first value seen after a change is often mid-travel.
SETTLE_SECONDS = 0.6

#: Gap between polls. Fast enough not to feel laggy, slow enough not to flood the bridge.
POLL_INTERVAL = 0.25

#: Runs a chunk of Lua in the mission environment and returns what it printed. Injected so
#: the whole flow is testable without DCS: the real one posts to ``dcs-serve``.
LuaRunner = Callable[[str], str]


class VerificationError(RuntimeError):
    """Raised when the cockpit cannot be read at all — no bridge, no aircraft."""


@dataclass(frozen=True)
class StepReading:
    """What one control read as, against what the checklist expected.

    Attributes:
        number: The step's 1-based position.
        element: The cockpit element that was boxed.
        argument: The animation argument that was read.
        expected: The value the checklist claims means "in position".
        measured: What the cockpit actually reported, or ``None`` on timeout.
    """

    number: int
    element: str
    argument: int
    expected: float
    measured: float | None

    @property
    def timed_out(self) -> bool:
        """Whether the pilot never moved the control."""
        return self.measured is None

    @property
    def matches(self) -> bool:
        """Whether the cockpit agrees with the checklist."""
        return self.measured is not None and abs(self.measured - self.expected) <= MATCH_TOLERANCE


def read_argument(run_lua: LuaRunner, argument: int) -> float:
    """Read one animation argument through the export environment.

    Args:
        run_lua: Runs Lua in the mission environment.
        argument: The animation argument to read.

    Returns:
        Its current value.

    Raises:
        VerificationError: when there is no cockpit to read — the reply is anything but a
            number, which is what happens with no aircraft, no bridge, or a sanitised
            ``MissionScripting.lua``.
    """
    reply = run_lua(
        'local ok, res = pcall(function() return net.dostring_in("export", '
        f"\"local d = GetDevice(0) if not d then return 'nodevice' end return tostring(d:get_argument_value({argument}))\")"
        " end) return tostring(res)"
    )
    try:
        return float(str(reply).strip())
    except (TypeError, ValueError) as error:
        raise VerificationError(
            f"cannot read cockpit argument {argument} (got {reply!r}) — is a pilot sitting in the aircraft, "
            f"on this machine, with the bridge connected?"
        ) from error


def say(run_lua: LuaRunner, text: str, seconds: int = 20) -> None:
    """Show a message **in DCS**, where the person doing the work is looking.

    Everything this module prints to a console is invisible to a pilot sitting in a
    cockpit at full screen — which is the only person who can act on it. Measured on the
    bridge: ``trigger.action.outText`` reaches the screen from the mission environment,
    while ``a_out_text_delay`` through the trigger environment does not.
    """
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    run_lua(f'trigger.action.outText("{escaped}", {int(seconds)}) return "said"')


def highlight(run_lua: LuaRunner, element: str | None) -> None:
    """Box *element* in the pilot's cockpit, or clear the box when it is ``None``."""
    if element is None:
        run_lua('net.dostring_in("mission", "a_cockpit_remove_highlight(1)") return "cleared"')
    else:
        run_lua(f'net.dostring_in("mission", \'a_cockpit_highlight(1, "{element}")\') return "boxed"')


def wait_for_value(
    run_lua: LuaRunner,
    argument: int,
    expected: float,
    timeout: float = DEFAULT_STEP_TIMEOUT,
    sleep: Callable[[float], None] = time.sleep,
    now: Callable[[], float] = time.monotonic,
) -> float | None:
    """Wait for an argument to reach *expected*, and report where it ended up.

    Waiting on the value rather than on a keypress is what lets the pilot stay in the
    cockpit. Waiting for the **wanted** value rather than for any movement is what took a
    real session to learn: told to put a switch back and forth, the first version caught
    the first half of the trip and announced the checklist had the wrong value.

    A control already sitting in the wanted position is confirmed at once — asking someone
    to move a switch that is already correct is a way of telling them the tool is broken.

    Args:
        run_lua: Runs Lua in the mission environment.
        argument: The animation argument to watch.
        expected: The value that ends the wait.
        timeout: How long to wait before giving up, in seconds.
        sleep: Injected for tests.
        now: Injected for tests.

    Returns:
        ``expected`` once reached; otherwise the last settled value the pilot left it at,
        which is the interesting answer — it means the checklist is wrong. ``None`` when
        nothing ever moved.
    """
    start = read_argument(run_lua, argument)
    if abs(start - expected) <= MATCH_TOLERANCE:
        return start

    deadline = now() + timeout
    candidate: float | None = None
    stable_since = 0.0
    settled: float | None = None

    while now() < deadline:
        sleep(POLL_INTERVAL)
        current = read_argument(run_lua, argument)
        if abs(current - expected) <= MATCH_TOLERANCE:
            return current
        if abs(current - start) <= MATCH_TOLERANCE:
            candidate = None
            continue
        if candidate is None or abs(current - candidate) > MATCH_TOLERANCE:
            candidate = current
            stable_since = now()
        elif now() - stable_since >= SETTLE_SECONDS:
            settled = candidate
    return settled


def make_lua_runner(serve_url: str, api_key: str, timeout: float = 15.0) -> LuaRunner:
    """Return a :data:`LuaRunner` that posts to a running ``dcs-serve``.

    Args:
        serve_url: Base URL of the ``dcs-serve`` HTTP API.
        api_key: The superuser Bearer token.
        timeout: Per-request timeout, in seconds.

    Returns:
        A callable taking Lua and returning what DCS replied.
    """
    import json
    import urllib.error
    import urllib.request

    def run(code: str) -> str:
        body = json.dumps({"code": code, "timeout": timeout}).encode("utf-8")
        request = urllib.request.Request(  # noqa: S310 - local serve URL, user-provided
            f"{serve_url.rstrip('/')}/api/exec",
            data=body,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout + 5) as response:  # noqa: S310
                payload = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            raise VerificationError(
                f"cannot reach dcs-serve at {serve_url} (is it running, with the mission started?): {error}"
            ) from error
        return str(payload.get("result", "")) if isinstance(payload, dict) else ""

    return run


def verify_step(
    run_lua: LuaRunner,
    number: int,
    element: str,
    argument: int,
    expected: float,
    timeout: float = DEFAULT_STEP_TIMEOUT,
    instruction: str = "",
) -> StepReading:
    """Box one control, wait for the pilot to move it, and read what it became.

    Args:
        run_lua: Runs Lua in the mission environment.
        number: The step's 1-based position, for the report.
        element: The cockpit element to box.
        argument: The animation argument to read.
        expected: The value the checklist claims.
        timeout: How long to wait for the pilot.
        instruction: What to tell the pilot to do, shown **in DCS**. Without it the
            request only exists in a console the pilot cannot see.

    Returns:
        What was read, against what was expected.
    """
    highlight(run_lua, element)
    if instruction:
        say(run_lua, instruction, seconds=int(timeout))
    try:
        measured = wait_for_value(run_lua, argument, expected, timeout=timeout)
    finally:
        highlight(run_lua, None)

    reading = StepReading(number=number, element=element, argument=argument, expected=expected, measured=measured)
    if instruction:
        say(run_lua, _outcome_text(reading), seconds=6)
    return reading


def _outcome_text(reading: StepReading) -> str:
    """One line for the pilot, in game, saying whether to move on."""
    if reading.matches:
        return str(t("verifier.in_game.ok", value=reading.measured))
    if reading.timed_out:
        return str(t("verifier.in_game.nothing"))
    return str(t("verifier.in_game.mismatch", measured=reading.measured, expected=reading.expected))
