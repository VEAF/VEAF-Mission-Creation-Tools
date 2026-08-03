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


def highlight(run_lua: LuaRunner, element: str | None) -> None:
    """Box *element* in the pilot's cockpit, or clear the box when it is ``None``."""
    if element is None:
        run_lua('net.dostring_in("mission", "a_cockpit_remove_highlight(1)") return "cleared"')
    else:
        run_lua(f'net.dostring_in("mission", \'a_cockpit_highlight(1, "{element}")\') return "boxed"')


def wait_for_change(
    run_lua: LuaRunner,
    argument: int,
    timeout: float = DEFAULT_STEP_TIMEOUT,
    sleep: Callable[[float], None] = time.sleep,
    now: Callable[[], float] = time.monotonic,
) -> float | None:
    """Wait for an argument to move away from where it started, and settle.

    Waiting on a *change* rather than a keypress is what lets the pilot stay in the
    cockpit. Waiting for it to settle avoids catching a switch mid-animation.

    Args:
        run_lua: Runs Lua in the mission environment.
        argument: The animation argument to watch.
        timeout: How long to wait before giving up, in seconds.
        sleep: Injected for tests.
        now: Injected for tests.

    Returns:
        The settled value, or ``None`` if nothing moved before the timeout.
    """
    start = read_argument(run_lua, argument)
    deadline = now() + timeout
    candidate: float | None = None
    stable_since = 0.0

    while now() < deadline:
        sleep(POLL_INTERVAL)
        current = read_argument(run_lua, argument)
        if abs(current - start) <= MATCH_TOLERANCE:
            candidate = None
            continue
        if candidate is None or abs(current - candidate) > MATCH_TOLERANCE:
            candidate = current
            stable_since = now()
        elif now() - stable_since >= SETTLE_SECONDS:
            return candidate
    return None


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
) -> StepReading:
    """Box one control, wait for the pilot to move it, and read what it became.

    Args:
        run_lua: Runs Lua in the mission environment.
        number: The step's 1-based position, for the report.
        element: The cockpit element to box.
        argument: The animation argument to read.
        expected: The value the checklist claims.
        timeout: How long to wait for the pilot.

    Returns:
        What was read, against what was expected.
    """
    highlight(run_lua, element)
    try:
        measured = wait_for_change(run_lua, argument, timeout=timeout)
    finally:
        highlight(run_lua, None)
    return StepReading(number=number, element=element, argument=argument, expected=expected, measured=measured)
