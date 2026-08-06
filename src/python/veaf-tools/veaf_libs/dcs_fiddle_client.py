"""Client for the ``dcs-fiddle-server.lua`` hook — the harness's single transport.

The hook is installed under ``Saved Games/DCS/Scripts/Hooks/`` and serves HTTP on
``127.0.0.1:12081``. Its contract, read from the script rather than assumed:

- The Lua to run is **base64 in the URL path**, with the target environment in ``?env=``.
- ``env=default`` runs it in the hook's own environment via ``loadstring``. That is where
  ``net.*`` lives, so it is how the harness drives DCS itself.
- Any other value goes through ``net.dostring_in(env, code)``. ``env=mission`` therefore reaches
  the mission scripting environment where the VEAF scripts run, which is where assertions belong.
- The reply is ``net.lua2json`` of ``{result=…}`` on success or ``{error=…}`` on failure.

Why this hook and not the ``dcs-serve`` bridge that :mod:`veaf_libs.dcs_bridge_capture` talks to:
``onSimulationFrame`` fires **with no mission loaded** — measured at ~28 Hz, 2 305 ticks before any
mission existed, and verified end to end with this hook answering at the main menu (see
``docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md``). A mission-scoped bridge cannot answer
before the mission it lives in exists, so it cannot be what loads it.

**What has not been verified here.** The transport and both environments are established. The
specific DCS hook functions the harness wants to *call* — loading a mission, quitting — are not:
this repository has never called them, and no DCS install was available while writing this. That is
why :func:`probe` exists and why the runner refuses to proceed on a negative probe rather than
failing somewhere less legible.
"""

from __future__ import annotations

import base64
import json
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any

#: Where the hook listens, hardcoded in ``dcs-fiddle-server.lua`` (``create_server("127.0.0.1", 12081)``).
DEFAULT_FIDDLE_URL = "http://127.0.0.1:12081"

#: The hook's own environment: ``loadstring`` there, and the only one holding ``net.*``.
ENV_HOOK = "default"

#: The mission scripting environment, reached through ``net.dostring_in``. Where ``veaf`` lives.
ENV_MISSION = "mission"


class FiddleError(RuntimeError):
    """The hook could not be reached, or the Lua it ran raised."""


def _encode(code: str) -> str:
    """Base64-encode Lua for the URL path, as the hook decodes it.

    Args:
        code: Lua source.

    Returns:
        The base64 text to put in the path.
    """
    return base64.b64encode(code.encode("utf-8")).decode("ascii")


def exec_lua(code: str, env: str = ENV_MISSION, url: str = DEFAULT_FIDDLE_URL, timeout: float = 10.0) -> Any:
    """Run *code* in *env* through the hook and return whatever it produced.

    Args:
        code: Lua source. Keep it an expression-returning chunk — the hook returns the value of
            the chunk, so ``return`` is what carries data back.
        env: :data:`ENV_HOOK` for the hook's own environment, :data:`ENV_MISSION` for the mission's.
        url: Base URL of the hook.
        timeout: Socket timeout in seconds.

    Returns:
        The decoded ``result`` value. It is whatever ``net.lua2json`` made of the Lua value, so a
        table comes back as a dict or a list.

    Raises:
        FiddleError: The hook is unreachable, replied with a non-200, replied with something that is
            not JSON, or reported that the Lua raised.
    """
    request = urllib.request.Request(f"{url.rstrip('/')}/{_encode(code)}?env={env}")  # noqa: S310 - local hook
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 - local hook
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        raise FiddleError(f"the DCS hook replied {exc.code} — is dcs-fiddle-server.lua installed?") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise FiddleError(
            f"cannot reach the DCS hook at {url}: {exc}. DCS must be running (the main menu is enough) "
            "with dcs-fiddle-server.lua in Saved Games/DCS/Scripts/Hooks/."
        ) from exc

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        raise FiddleError(f"the DCS hook replied with something that is not JSON: {body[:200]!r}") from exc

    if isinstance(payload, dict) and "error" in payload:
        raise FiddleError(f"the Lua raised in the {env} environment: {payload['error']}")
    if not isinstance(payload, dict) or "result" not in payload:
        raise FiddleError(f"the DCS hook reply carries neither result nor error: {body[:200]!r}")
    return payload["result"]


@dataclass
class Capabilities:
    """What a running DCS actually lets the harness do.

    Every field is measured, not assumed. The harness has to know these before it can drive
    anything, and this repository had never called the last three.
    """

    hook_alive: bool = False
    mission_env_reachable: bool = False
    #: ``net.load_mission`` — how the harness would load the test mission from the main menu.
    can_load_mission: bool = False
    #: ``DCS.exitProcess`` — how it would quit afterwards.
    can_quit: bool = False
    #: Present only when a mission is loaded; tells the runner whether to load one.
    mission_name: str | None = None
    #: What the probe observed, in order — the readable half of the answer.
    notes: list[str] = field(default_factory=list)


def probe(url: str = DEFAULT_FIDDLE_URL, timeout: float = 10.0) -> Capabilities:
    """Ask a running DCS what the harness can do to it.

    Deliberately the first thing the runner does, and it is the same discipline as the
    ``Disposition`` probe in ``FEAT-SCENERY-AWARE-SPAWN``: measure before building on top. Each
    answer here is a fact this repository did not have.

    Args:
        url: Base URL of the hook.
        timeout: Socket timeout in seconds.

    Returns:
        A :class:`Capabilities` describing what answered. A probe that cannot reach the hook returns
        ``hook_alive=False`` rather than raising, because "DCS is not running" is an expected
        outcome, not an error.
    """
    caps = Capabilities()
    try:
        alive = exec_lua('return "alive: " .. _VERSION', env=ENV_HOOK, url=url, timeout=timeout)
    except FiddleError as exc:
        caps.notes.append(str(exc))
        return caps
    caps.hook_alive = True
    caps.notes.append(f"hook environment answered: {alive}")

    for attr, expression, label in (
        (
            "can_load_mission",
            "return type(net) == 'table' and type(net.load_mission) == 'function'",
            "net.load_mission",
        ),
        ("can_quit", "return type(DCS) == 'table' and type(DCS.exitProcess) == 'function'", "DCS.exitProcess"),
    ):
        try:
            setattr(caps, attr, bool(exec_lua(expression, env=ENV_HOOK, url=url, timeout=timeout)))
        except FiddleError as exc:
            caps.notes.append(f"could not test {label}: {exc}")
        else:
            caps.notes.append(f"{label}: {'present' if getattr(caps, attr) else 'ABSENT'}")

    # The mission environment only exists once a mission is loaded, so a failure here is
    # information ("no mission yet"), not a defect.
    try:
        name = exec_lua("return env.mission and env.mission.theatre or nil", env=ENV_MISSION, url=url, timeout=timeout)
    except FiddleError as exc:
        caps.notes.append(f"mission environment not reachable (no mission loaded?): {exc}")
    else:
        caps.mission_env_reachable = True
        caps.mission_name = str(name) if name else None
        caps.notes.append(f"mission environment answered; theatre={caps.mission_name}")

    return caps
