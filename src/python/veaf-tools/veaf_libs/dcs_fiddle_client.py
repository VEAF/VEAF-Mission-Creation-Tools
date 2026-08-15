"""Client for the ``dcs-fiddle-server.lua`` hook — the harness's single transport.

The hook is installed under ``Saved Games/DCS/Scripts/Hooks/`` and serves HTTP on
``127.0.0.1:12081``. Its contract, read from the script rather than assumed:

- The Lua to run is **base64 in the URL path**, with the target environment in ``?env=``.
- ``env=default`` runs it in the hook's own environment via ``loadstring``. That is where
  ``net.*`` lives, so it is how the harness drives DCS itself.
- Any other value goes through ``net.dostring_in(env, code)``.
- The reply is ``net.lua2json`` of ``{result=…}`` on success or ``{error=…}`` on failure.

``env=mission`` was assumed to be the mission *scripting* environment where the VEAF scripts run. **It
is not** — measured 2026-08-06, it is the **trigger** state, which has no ``env`` table. See
:data:`ENV_MISSION`. Reaching the scripts takes one more hop, and which hop works is measured rather
than assumed: see :data:`SCRIPTING_ROUTES` and :func:`exec_in_scripting`.

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

**Read ED's own documentation before adding a call here**: ``<install>/API/Sim_ControlAPI.md``, which
ships with DCS. Three things in it contradict what this module originally assumed, and each is a fact
the probe now measures rather than a belief the code acts on:

- The control table is documented as ``Sim.*``, not ``DCS.*``. ``DCS`` evidently still answers — the
  fiddle hook calls ``DCS.setUserCallbacks`` and works — but which name to use is now measured.
- ``net.load_mission`` is documented **SERVER ONLY**. It is the single call the "load the test
  mission" step rests on, so whether it does anything in a local single-player instance decides the
  shape of that step rather than being a detail inside it.
- ``net.dostring_in`` is marked **OBSOLETE and UNSAFE**, and documented as allowed only for the states
  listed in ``Config/autoexec.cfg`` (``net.allow_unsafe_api`` / ``net.allow_dostring_in``). Every
  assertion runs through it, so that reading would mean no mission-environment transport at all on a
  stock install. **Measured 2026-08-06 and it does not hold**: on a DCS whose ``autoexec.cfg`` lists
  neither key, ``net.dostring_in`` is present and callable from the hook environment. The gate evidently
  governs something narrower than the plain reading — so the harness keeps checking for the function
  instead of checking for the config, and the probe reports what it found rather than what was expected.

**And the transport lies about failure.** ``net.dostring_in(state, string) -> string`` returns a Lua
error **as its string result**, with HTTP 200 and a ``{result=…}`` body, so a failure in the mission
environment is shaped exactly like a successful answer. :data:`LUA_ERROR` is how they are told apart, and
the probe measures what each Lua type looks like after the crossing, because a transport that stringifies
everything makes a check expecting a number or ``True`` unpassable however correct its Lua is.
"""

from __future__ import annotations

import base64
import json
import os
import re
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from veaf_libs.i18n import t
from veaf_libs.lua_literals import lua_quoted_string

#: A Lua error message, as it comes back from ``net.dostring_in`` — **as the result, not as an error**.
#:
#: Measured 2026-08-06 on a live DCS at the main menu: asking the mission environment for
#: ``env.mission.theatre`` with no mission loaded returned the string
#: ``:1: attempt to index global 'env' (a nil value)`` with HTTP 200 and a ``{result=…}`` body. ED
#: documents ``net.dostring_in(state, string) -> string``, and the hook returns that string verbatim, so
#: **a failure in the mission environment is indistinguishable from a successful string result** unless
#: something looks at its shape. The probe duly reported "mission environment answered".
#:
#: This is the third time this lot has been bitten by a truthy failure — the sentinel strings, the
#: submenu check returning a constant, and now this. Same lesson each time: in this transport, "it came
#: back" is not "it worked".
LUA_ERROR = re.compile(r'^(?:\[string "[^"]*"\])?:\d+:\s')

#: Where the hook listens, hardcoded in ``dcs-fiddle-server.lua`` (``create_server("127.0.0.1", 12081)``).
DEFAULT_FIDDLE_URL = "http://127.0.0.1:12081"

#: The Basic-auth username the vendored hook checks (``FIDDLE.USERNAME = 'veaf'``). Fixed, because the
#: secret is the per-session password, not the username.
FIDDLE_USERNAME = "veaf"

#: Environment variable that overrides the session password, for a machine whose token file is not
#: where this client looks (see :func:`resolve_fiddle_token`).
ENV_FIDDLE_TOKEN = "DCS_FIDDLE_TOKEN"

#: Where the hook writes the per-session password, and where this client reads it. A fixed path in the
#: user's home rather than under a ``Saved Games`` write directory, because a workstation can carry
#: several write directories (one per aircraft profile) and only the running DCS knows which is live —
#: so a writedir-relative path would leave the client guessing. The hook computes the same path from
#: ``USERPROFILE`` (see ``dcs-fiddle-server.lua``); ``FIX-SECREV2-EXPIRED-DEFERRALS`` ticket 02.
FIDDLE_TOKEN_FILENAME = "dcs-fiddle-token.txt"

#: Set once per process by the CLI (:func:`set_session_token`) from the resolved password, so every
#: hook call carries the Basic-auth header without threading the value through :func:`probe` and the
#: rest. ``None`` sends no ``Authorization`` header, which is correct against a hook that predates the
#: auth and keeps unit tests hermetic — they never touch the filesystem for it.
_session_token: str | None = None


def resolve_fiddle_token(explicit: str | None = None, path: str | os.PathLike[str] | None = None) -> str | None:
    """Find the hook's per-session password: explicit value, then env var, then the token file.

    Args:
        explicit: A password passed on the command line; wins when set.
        path: Explicit path to the token file; defaults to :data:`FIDDLE_TOKEN_FILENAME` in the user's
            home, which is where the hook writes it.

    Returns:
        The password, or ``None`` when none is configured or the file is absent — a missing password is
        not an error here, it is reported by the hook rejecting the request, which names the real cause.
    """
    if explicit:
        return explicit
    from_env = os.environ.get(ENV_FIDDLE_TOKEN)
    if from_env:
        return from_env.strip() or None
    token_file = Path(path) if path else Path.home() / FIDDLE_TOKEN_FILENAME
    try:
        return token_file.read_text(encoding="utf-8").strip() or None
    except OSError:
        return None


def set_session_token(token: str | None) -> None:
    """Set the password every hook call authenticates with for the rest of this process.

    Args:
        token: The resolved per-session password, or ``None`` to send no ``Authorization`` header.
    """
    global _session_token
    _session_token = token


def _basic_auth_header(password: str) -> str:
    """Return the ``Authorization: Basic`` value for :data:`FIDDLE_USERNAME` and *password*."""
    raw = f"{FIDDLE_USERNAME}:{password}".encode()
    return "Basic " + base64.b64encode(raw).decode("ascii")


#: The hook's own environment: ``loadstring`` there, and the only one holding ``net.*``.
ENV_HOOK = "default"

#: The state ``net.dostring_in("mission", …)`` reaches. **Not** where ``veaf`` lives.
#:
#: Measured 2026-08-06 with `Smerch Hunt II` loaded and a pilot in the cockpit: a chunk sent here
#: returned ``:1: attempt to index global 'env' (a nil value)``. The chunk *ran* — that is a Lua runtime
#: error from inside the target state, not a refusal — so this state simply has no ``env``. It is the
#: **trigger** state, the one holding ``a_do_script`` and the ``a_*`` actions, which is also what
#: `FEAT-ASSIST-CHECKLISTS` ticket 01 found when it located ``a_cockpit_highlight`` "one
#: ``net.dostring_in`` away". The hook's own bootstrap says the same thing in one line:
#: ``net.dostring_in("mission", 'a_do_script("dofile(…)")')`` — it reaches the scripting state *through*
#: ``a_do_script`` rather than directly.
#:
#: So every check shipped in the first slice was aimed one state short of the scripts it asserts about.
ENV_MISSION = "mission"

#: The state name ED's own example passes to ``net.dostring_in`` — ``net.dostring_in("scripting", …)``.
#: A candidate route rather than a fact: the config key that permits it is spelled ``"mission"``, so the
#: config vocabulary and the state vocabulary do not line up and only a measurement settles which works.
ENV_SCRIPTING = "scripting"


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


def exec_lua(
    code: str,
    env: str = ENV_MISSION,
    url: str = DEFAULT_FIDDLE_URL,
    timeout: float = 10.0,
    token: str | None = None,
) -> Any:
    """Run *code* in *env* through the hook and return whatever it produced.

    Args:
        code: Lua source. Keep it an expression-returning chunk — the hook returns the value of
            the chunk, so ``return`` is what carries data back.
        env: :data:`ENV_HOOK` for the hook's own environment, :data:`ENV_MISSION` for the mission's.
        url: Base URL of the hook.
        timeout: Socket timeout in seconds.
        token: The hook's per-session password, sent as HTTP Basic auth (username :data:`FIDDLE_USERNAME`).
            Defaults to the process-wide :data:`_session_token` set by :func:`set_session_token`; ``None``
            sends no ``Authorization`` header, which a pre-auth hook accepts.

    Returns:
        The decoded ``result`` value. It is whatever ``net.lua2json`` made of the Lua value, so a
        table comes back as a dict or a list.

    Raises:
        FiddleError: The hook is unreachable, rejected the credentials, replied with a non-200, replied
            with something that is not JSON, or reported that the Lua raised.
    """
    request = urllib.request.Request(f"{url.rstrip('/')}/{_encode(code)}?env={env}")  # noqa: S310 - local hook
    tok = token if token is not None else _session_token
    if tok:
        request.add_header("Authorization", _basic_auth_header(tok))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 - local hook
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            raise FiddleError(
                f"the DCS hook rejected the credentials ({exc.code}). It writes a fresh per-session "
                f"password to {Path.home() / FIDDLE_TOKEN_FILENAME} at each launch — is that the current "
                f"session's file, or set {ENV_FIDDLE_TOKEN}?"
            ) from exc
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

    result = payload["result"]
    # Only the hook's own environment reports a failure as a failure: there the hook `loadstring`s the
    # chunk and its pcall turns a raise into `{error=…}`. Every other environment goes through
    # `net.dostring_in`, which returns a *string* — the error text included, with a 200 and a
    # `{result=…}` body. So the shape of the reply is the only thing that can tell them apart.
    if env != ENV_HOOK and isinstance(result, str) and LUA_ERROR.match(result):
        raise FiddleError(f"the Lua failed in the {env} environment: {result}")
    return result


#: One Lua chunk, run in the hook environment, gathering every lifecycle fact the harness needs.
#:
#: One chunk rather than one request per fact, because these are read together and a partial answer
#: is what produced a misleading diagnosis before: knowing ``net.load_mission`` exists is useless
#: without knowing whether this instance counts as a server, and knowing the mission environment
#: refused is useless without knowing whether ``net.dostring_in`` is even permitted here.
#:
#: Every lookup is defensive and every call is ``pcall``-wrapped: this runs against a live simulator
#: whose API this repository is still learning, and a chunk that raises measures nothing at all.
_FACTS_LUA = """
local facts = {}
facts.lua = _VERSION

-- ED documents the control table as Sim.* (API/Sim_ControlAPI.md); DCS.* is what every hook in the
-- wild still calls. Report both rather than picking one, and say whether they are the same table.
local hasSim, hasDCS = type(Sim) == 'table', type(DCS) == 'table'
facts.control_table = hasSim and (hasDCS and 'Sim+DCS' or 'Sim') or (hasDCS and 'DCS' or 'none')
facts.control_aliased = (hasSim and hasDCS and Sim == DCS) and true or false
local C = hasSim and Sim or (hasDCS and DCS or nil)

local function fn(tbl, name)
    return (type(tbl) == 'table' and type(tbl[name]) == 'function') and true or false
end
local function ask(f, ...)
    if type(f) ~= 'function' then return 'absent' end
    local ok, value = pcall(f, ...)
    if not ok then return 'raised: ' .. tostring(value) end
    if value == nil then return 'nil' end
    return value
end

facts.exit_process = fn(C, 'exitProcess')
facts.stop_mission = fn(C, 'stopMission')
facts.set_pause = fn(C, 'setPause')
facts.set_user_callbacks = fn(C, 'setUserCallbacks')
facts.get_log_history = fn(C, 'getLogHistory')
facts.load_mission = fn(net, 'load_mission')
facts.load_next_mission = fn(net, 'load_next_mission')
facts.dostring_in = fn(net, 'dostring_in')

if C then
    facts.mission_name = ask(C.getMissionName)
    facts.mission_filename = ask(C.getMissionFilename)
    facts.is_server = ask(C.isServer)
    facts.is_multiplayer = ask(C.isMultiplayer)
end

-- Which install and which Saved Games folder this instance is actually using. Asked rather than
-- guessed: a workstation can carry half a dozen write directories (one per aircraft profile), and
-- only the running process knows which one it was started with.
facts.write_dir = ask(type(lfs) == 'table' and lfs.writedir)
facts.install_dir = ask(type(lfs) == 'table' and lfs.currentdir)
return facts
"""


@dataclass
class Capabilities:
    """What a running DCS actually lets the harness do.

    Every field is measured, not assumed — the harness has to know these before it can drive
    anything, and this repository had called none of them.
    """

    hook_alive: bool = False
    mission_env_reachable: bool = False
    #: ``net.load_mission`` — how the harness would load the test mission. **SERVER ONLY** per ED's
    #: documentation, so its presence is necessary and not sufficient; see :attr:`is_server`.
    can_load_mission: bool = False
    #: ``Sim.exitProcess`` / ``DCS.exitProcess`` — how the harness would quit afterwards.
    can_quit: bool = False
    #: ``Sim.stopMission`` — unloading without killing the process, so several missions can be run.
    can_stop_mission: bool = False
    #: ``Sim.setUserCallbacks`` — how the harness would learn that a load *finished*, by registering
    #: ``onMissionLoadEnd`` instead of watching a frame counter that freezes during the load.
    can_set_callbacks: bool = False
    #: ``net.dostring_in`` — the **only** transport to the mission environment, and the one ED marks
    #: obsolete and gates behind ``autoexec.cfg``. Without it there are no assertions at all.
    can_dostring_in: bool = False
    #: Which control table answered: ``Sim``, ``DCS``, ``Sim+DCS`` or ``none``.
    control_table: str = "none"
    #: Whether ``Sim`` and ``DCS`` are literally the same table, when both exist.
    control_aliased: bool = False
    #: ``Sim.isServer()`` — documented true in single-player too, which is what would make
    #: ``net.load_mission`` usable locally. Measured, because that reading is not obvious.
    is_server: bool | None = None
    is_multiplayer: bool | None = None
    #: Present only when a mission is loaded; tells the runner whether to load one.
    mission_name: str | None = None
    #: The ``.miz`` behind the loaded mission, when DCS will say.
    mission_filename: str | None = None
    #: What this instance was started with — answers "which of my Saved Games folders is live".
    write_dir: str | None = None
    install_dir: str | None = None
    #: Why the mission environment did not answer, verbatim. Kept because the three causes — no
    #: mission, no ``dostring_in`` permission, a hook that speaks a different contract — need
    #: different repairs and used to be reported as the first one.
    mission_env_error: str | None = None
    #: How to reach the state the VEAF scripts run in, or ``None`` when nothing reached it. ``env=mission``
    #: is **not** it — that is the trigger state — so this is what a check has to be sent through.
    scripting_route: ScriptingRoute | None = None
    #: Whether the hook's scripting route can actually see a **VEAF** global (``veaf``). Measured, not
    #: inferred from ``env``: ``env`` is a table in *every* scripting state, loaded or bare, so it says
    #: nothing about whether the mission's scripts ran here. They do not — the hook reaches a bare
    #: scripting state — which is exactly why a VEAF assertion goes through the mission bridge instead.
    hook_sees_veaf: bool = False
    #: What each Lua type *looks like* once it has crossed the mission-environment transport, keyed by
    #: the type the Lua returned. Measured because ED documents ``net.dostring_in`` as returning a
    #: **string**: if that holds, a check expecting a number or ``True`` can never pass, and two of the
    #: six shipped checks expect exactly that. Only filled when a mission is loaded.
    mission_env_shapes: dict[str, str] = field(default_factory=dict)
    #: What the probe observed, in order — the readable half of the answer.
    notes: list[str] = field(default_factory=list)

    @property
    def can_drive_lifecycle(self) -> bool:
        """Whether this instance can be told to load a mission and then quit.

        Both halves are required for an unattended run: loading without quitting leaves DCS holding
        a licence seat, and quitting without loading has nothing to assert against.
        """
        return self.can_load_mission and self.can_quit

    def blocking_reason(self) -> str | None:
        """The one thing to fix first, or ``None`` when the harness can proceed.

        Returns:
            A sentence naming the obstacle, ordered so the answer is the *root* cause rather than
            the first symptom: no hook at all, then no permission to reach the mission, then no
            mission. Reporting these in the wrong order is what sent the previous version's user
            looking for a mission to load when the real problem was a missing ``autoexec.cfg`` entry.
        """
        if not self.hook_alive:
            return t("smoke.block.no_hook")
        if not self.can_dostring_in:
            return t("smoke.block.no_dostring_in")
        if not self.mission_env_reachable:
            return t("smoke.block.no_mission_env")
        return None


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
        facts = exec_lua(_FACTS_LUA, env=ENV_HOOK, url=url, timeout=timeout)
    except FiddleError as exc:
        caps.notes.append(str(exc))
        return caps
    caps.hook_alive = True

    if not isinstance(facts, dict):
        # A hook that answers but does not return a table is a hook speaking a different contract —
        # say so, rather than reading every absent fact as a missing DCS function.
        caps.notes.append(t("smoke.probe.wrong_contract", reply=repr(facts)))
        return caps

    caps.control_table = str(facts.get("control_table", "none"))
    caps.control_aliased = bool(facts.get("control_aliased"))
    caps.can_load_mission = bool(facts.get("load_mission"))
    caps.can_quit = bool(facts.get("exit_process"))
    caps.can_stop_mission = bool(facts.get("stop_mission"))
    caps.can_set_callbacks = bool(facts.get("set_user_callbacks"))
    caps.can_dostring_in = bool(facts.get("dostring_in"))
    caps.is_server = _as_bool(facts.get("is_server"))
    caps.is_multiplayer = _as_bool(facts.get("is_multiplayer"))
    caps.mission_name = _as_text(facts.get("mission_name"))
    caps.mission_filename = _as_text(facts.get("mission_filename"))
    caps.write_dir = _as_text(facts.get("write_dir"))
    caps.install_dir = _as_text(facts.get("install_dir"))

    caps.notes.append(f"hook environment answered: {facts.get('lua', '?')}")
    caps.notes.append(
        f"control table: {caps.control_table}" + (" (Sim and DCS are the same table)" if caps.control_aliased else "")
    )
    for label, present in (
        ("net.load_mission", caps.can_load_mission),
        ("net.dostring_in", caps.can_dostring_in),
        (f"{caps.control_table}.exitProcess", caps.can_quit),
        (f"{caps.control_table}.stopMission", caps.can_stop_mission),
        (f"{caps.control_table}.setUserCallbacks", caps.can_set_callbacks),
    ):
        caps.notes.append(f"{label}: {'present' if present else 'ABSENT'}")
    # net.load_mission is documented SERVER ONLY, and ED also documents isServer() as true in
    # single-player. Both halves are printed together so the reader can see whether that reading holds
    # on this install instead of inferring it.
    caps.notes.append(f"isServer={caps.is_server}, isMultiplayer={caps.is_multiplayer}")
    caps.notes.append(f"mission loaded: {caps.mission_name or 'none'} ({caps.mission_filename or 'no filename'})")
    caps.notes.append(f"install dir: {caps.install_dir or 'unknown'}")
    caps.notes.append(f"write dir: {caps.write_dir or 'unknown'}")

    # The mission environment can fail to answer for three different reasons wanting three different
    # repairs, so the raw error is kept and the diagnosis names which one it is.
    try:
        theatre = exec_lua(
            "return env.mission and env.mission.theatre or nil", env=ENV_MISSION, url=url, timeout=timeout
        )
    except FiddleError as exc:
        caps.mission_env_error = str(exc)
        if not caps.can_dostring_in:
            caps.notes.append("mission environment unreachable because net.dostring_in is not permitted here")
        elif not caps.mission_name:
            caps.notes.append("mission environment unreachable because no mission is loaded")
        else:
            caps.notes.append(
                f"mission environment unreachable although {caps.mission_name!r} is loaded and "
                f"net.dostring_in exists — this is the case worth investigating: {exc}"
            )
    else:
        caps.mission_env_reachable = True
        caps.notes.append(f"mission environment answered; theatre={theatre}")

    # Whichever way that went, find out how to reach the state the VEAF scripts are in — `env=mission`
    # is the trigger state and has no `env`, so a check aimed there asserts about the wrong Lua.
    if caps.mission_name:
        caps.scripting_route, route_notes = _find_scripting_route(url=url, timeout=timeout)
        caps.notes += route_notes
        if caps.scripting_route:
            caps.mission_env_shapes = _measure_shapes(caps.scripting_route, url=url, timeout=timeout)
            for lua_type, seen in caps.mission_env_shapes.items():
                caps.notes.append(f"a Lua {lua_type} crosses the {caps.scripting_route.name} route as {seen}")
            # The honest discriminator: does that route actually see the mission's scripts? `env` being a
            # table does not answer it (a bare scripting state has `env` too), so probe a VEAF global.
            # It comes back absent — the hook reaches a bare scripting state — which is why VEAF
            # assertions ride the mission bridge, not this route.
            try:
                veaf_type = exec_in_scripting("return type(veaf)", caps.scripting_route, url=url, timeout=timeout)
            except FiddleError:
                veaf_type = "unreachable"
            caps.hook_sees_veaf = veaf_type == "table"
            caps.notes.append(
                f"hook route sees veaf: {caps.hook_sees_veaf} (type(veaf)={veaf_type!r}) — "
                "a VEAF assertion goes through the mission bridge, not the hook"
            )

    return caps


def _find_scripting_route(url: str, timeout: float) -> tuple[ScriptingRoute | None, list[str]]:
    """Try each candidate route until one reaches the state holding ``env``.

    The test is ``return type(env)`` and the answer has to *be* ``table``: a route that runs the chunk
    somewhere without ``env`` returns a Lua error, which this transport hands back as an ordinary string,
    so "something came back" proves nothing. That is the same trap three times over now.

    Args:
        url: Base URL of the hook.
        timeout: Per-request socket timeout in seconds.

    Returns:
        The first route that worked and a note per attempt, or ``None`` with every attempt recorded —
        a route search that fails silently would leave the harness looking broken for no stated reason.
    """
    notes: list[str] = []
    for route in SCRIPTING_ROUTES:
        probe_lua = route.wrap("return type(env)")
        try:
            value = exec_lua(probe_lua, env=route.env, url=url, timeout=timeout)
        except FiddleError as exc:
            notes.append(f"route {route.name}: refused ({exc})")
            continue
        if value == "table":
            # `env` is a table here, but that only proves this is *a* scripting state, not that the
            # mission's scripts ran in it — probe() checks a VEAF global separately for that.
            notes.append(f"route {route.name}: reaches a scripting state (env is a table)")
            return route, notes
        notes.append(f"route {route.name}: ran but env is {value!r}, so this is not the scripting state")
    notes.append(
        "no route reached the scripting state, so no assertion about the VEAF scripts can run yet — "
        "this is the finding, not a harness defect"
    )
    return None, notes


def exec_in_scripting(code: str, route: ScriptingRoute, url: str = DEFAULT_FIDDLE_URL, timeout: float = 10.0) -> Any:
    """Run *code* where the VEAF scripts live, via the route the probe found.

    Args:
        code: Lua source, returning a value.
        route: The route :func:`probe` measured as working.
        url: Base URL of the hook.
        timeout: Socket timeout in seconds.

    Returns:
        Whatever the chunk returned, after the same Lua-error check every reply gets.

    Raises:
        FiddleError: As :func:`exec_lua`.
    """
    return exec_lua(route.wrap(code), env=route.env, url=url, timeout=timeout)


@dataclass(frozen=True)
class ScriptingRoute:
    """One candidate way of running a chunk where the VEAF scripts actually live.

    Args:
        name: Short identifier, printed in the probe report.
        env: The ``?env=`` value to send.
        wrap: Turns a caller's chunk into what has to be sent for this route.
        why: What this route bets on, so a negative result is informative rather than puzzling.
    """

    name: str
    env: str
    wrap: Callable[[str], str]
    why: str


#: The routes to the scripting state, in the order worth trying.
#:
#: ``a_do_script`` first, because it is the one ED **documents as the current way** — the same paragraph
#: that marks ``net.dostring_in`` obsolete says "you can return values from ``a_do_script()`` directly:
#: ``local a, b, c = a_do_script("return 1,2,3")``" — and because the hook already proves the trigger
#: state is reachable by using exactly that call to bootstrap itself.
SCRIPTING_ROUTES: tuple[ScriptingRoute, ...] = (
    ScriptingRoute(
        name="a_do_script",
        env=ENV_MISSION,
        wrap=lambda code: f"return a_do_script({lua_quoted_string(code)})",
        why="ED's documented current path: reach the scripting state from the trigger state, which is "
        "where env=mission lands. The hook bootstraps itself this way.",
    ),
    ScriptingRoute(
        name="dostring_in-scripting",
        env=ENV_SCRIPTING,
        wrap=lambda code: code,
        why="ED's own net.dostring_in example passes 'scripting'. Worth trying because the config key "
        "that permits it is spelled 'mission', so the two vocabularies disagree.",
    ),
)


#: Four one-liners whose *reply shape* settles what a mission-environment check may expect back.
#: Trivial on purpose: they cannot fail for any reason other than the transport itself.
_SHAPE_PROBES: tuple[tuple[str, str], ...] = (
    ("number", "return 3"),
    ("boolean", "return true"),
    ("string", "return 'x'"),
    ("table", "return {1, 2}"),
)


def _measure_shapes(route: ScriptingRoute, url: str, timeout: float) -> dict[str, str]:
    """Ask what each Lua type becomes after crossing the mission-environment transport.

    ED documents ``net.dostring_in(state, string) -> string``. If that is literal, then a check
    expecting a number or ``True`` back from the mission environment can never pass however correct its
    Lua is — and two of the six shipped checks expect precisely that. Rather than reason about it, the
    probe returns four trivial values and reports what arrives.

    Args:
        route: The route that reaches the scripting state.
        url: Base URL of the hook.
        timeout: Per-request socket timeout in seconds.

    Returns:
        Lua type name → a readable description of what Python received, including its Python type, so
        the answer is unambiguous. Failures are recorded rather than raised: a shape that could not be
        measured is itself worth reading.
    """
    shapes: dict[str, str] = {}
    for lua_type, code in _SHAPE_PROBES:
        try:
            value = exec_in_scripting(code, route, url=url, timeout=timeout)
        except FiddleError as exc:
            shapes[lua_type] = f"could not measure: {exc}"
        else:
            shapes[lua_type] = f"{value!r} (Python {type(value).__name__})"
    return shapes


def _as_bool(value: Any) -> bool | None:
    """Read a tri-state answer from the probe, where "absent" and "nil" are not ``False``.

    Args:
        value: What the Lua reported for one fact.

    Returns:
        The boolean DCS gave, or ``None`` when it could not say. Collapsing "could not ask" into
        ``False`` is how a harness concludes it is not a server when it simply never found out.
    """
    if isinstance(value, bool):
        return value
    if isinstance(value, str) and value in {"absent", "nil"} or value is None:
        return None
    if isinstance(value, str) and value.startswith("raised:"):
        return None
    return bool(value)


def _as_text(value: Any) -> str | None:
    """Read a string answer from the probe, mapping its "nothing here" markers to ``None``.

    Args:
        value: What the Lua reported for one fact.

    Returns:
        The text, or ``None`` for ``absent`` / ``nil`` / a raise — so a caller can test truthiness
        without accidentally treating the four-character string ``"nil"`` as a mission name.
    """
    if value is None or not isinstance(value, str):
        return str(value) if value not in (None, False) else None
    if value in {"absent", "nil"} or value.startswith("raised:"):
        return None
    return value
