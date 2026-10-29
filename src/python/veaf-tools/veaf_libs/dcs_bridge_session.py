"""A session with the VEAF bridge, for a command that talks to the mission running in DCS.

The bridge is the one way ``veaf-tools`` reaches a running DCS (REFACTOR-BRIDGE-ONLY, 2026-10-29):
``dcs-bridge.lua``, embedded in the mission, connects to ``dcs-serve`` on this machine, and the command
sends its Lua through ``dcs-serve`` (``POST /api/exec``). The chunk runs in the **mission scripting
state**, where ``coalition``, ``env`` and the VEAF modules live; the other states (``export`` for the
F11 camera, ``gui`` for the Mission Editor's terrain data) are one ``net.dostring_in`` away.

A session is three steps a command would otherwise each write again:

1. make sure a ``dcs-serve`` answers — starting one on the loopback with a key of its own, in the same
   folder ``clear-ground-sweep`` uses, so every command finds the key of a server another one left running;
2. wait until the mission's bridge has connected to it. It retries with a back-off that doubles up to
   60 s **of mission time** while no server listens, so a server started after the mission can take a
   minute to be found;
3. stop the server it started, at the end.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from veaf_libs.dcs_bridge_capture import (
    BridgeAuthError,
    BridgeHttpError,
    BridgeLuaError,
    exec_in_state,
    exec_over_bridge,
    resolve_api_key,
)
from veaf_libs.dcs_serve_launcher import DcsServe, ensure_config, find_dcs_serve, is_serving
from veaf_libs.i18n import t

#: Seconds a command waits by default for the mission's bridge: the back-off is capped at 60 s of
#: mission time, plus the time it takes to load the mission.
DEFAULT_WAIT_SECONDS = 180

#: Seconds between two attempts while waiting.
POLL_SECONDS = 2.0


class DcsServeMissing(RuntimeError):
    """No ``dcs-serve`` answers, and none was found to start."""


def serve_workdir() -> Path:
    """The folder of the ``dcs-serve`` the tools start: its ``dcs-serve.yaml``, key and log.

    The one ``clear-ground-sweep`` already uses, so every command finds the key of a server another
    one started.

    Returns:
        ``<VEAF home>/clear-ground/dcs-serve``.
    """
    from veaf_libs.clear_ground_catalogue import local_catalogue_dir  # noqa: PLC0415

    return local_catalogue_dir() / "dcs-serve"


@dataclass
class BridgeSession:
    """A ``dcs-serve`` to talk to, its key, and the server this session started, if any.

    Args:
        serve_url: Base URL of the ``dcs-serve`` HTTP API.
        key: The superuser key it accepts.
        started: The server this session started — stopped by :meth:`close` — or ``None`` for one that
            was already running.
        config_path: The ``dcs-serve.yaml`` holding the key of a server started here.
    """

    serve_url: str
    key: str
    started: DcsServe | None = None
    config_path: Path | None = None

    def run(self, code: str, timeout: float = 30.0) -> str:
        """Run *code* in the mission scripting state and return its result as a string.

        Args:
            code: Lua source returning a value.
            timeout: Seconds the call may take.

        Returns:
            ``tostring`` of what the chunk returned, ``""`` for ``nil`` or ``false``.

        Raises:
            BridgeLuaError: The chunk raised.
            RuntimeError: ``dcs-serve`` is unreachable, refused the request, or got no reply.
        """
        return exec_over_bridge(self.serve_url, self.key, code, timeout)

    def run_in(self, state: str, code: str, timeout: float = 30.0) -> str:
        """Run *code* in another Lua state (``export``, ``gui``…) and return its string result.

        Args:
            state: The target state, as ``net.dostring_in`` names it.
            code: Lua source returning a string.
            timeout: Seconds the call may take.

        Returns:
            What the chunk returned.

        Raises:
            BridgeLuaError: The chunk failed in *state*.
            RuntimeError: As :meth:`run`.
        """
        return exec_in_state(self.serve_url, self.key, state, code, timeout)

    def close(self) -> None:
        """Stop the server this session started; leave alone one that was already running."""
        if self.started is not None:
            self.started.stop()
            self.started = None


def open_session(
    serve_url: str,
    dcs_serve: str | None = None,
    api_key: str | None = None,
    config: str | None = None,
    workdir: Path | None = None,
) -> BridgeSession:
    """Make sure a ``dcs-serve`` answers at *serve_url*, starting one with a key of its own if none does.

    Args:
        serve_url: Where the server is expected.
        dcs_serve: The executable to start, when the user named it.
        api_key: The key of a server the user started, if any.
        config: A ``dcs-serve.yaml`` to read that key from, if any.
        workdir: The folder of a server started here; :func:`serve_workdir` by default.

    Returns:
        The session; :attr:`BridgeSession.started` says whether a server was started.

    Raises:
        DcsServeMissing: No server answers and none can be found to start.
        RuntimeError: The server started here stopped at once or never answered, or no key was found.
    """
    workdir = workdir or serve_workdir()
    if is_serving(serve_url):
        own = workdir / "dcs-serve.yaml"
        # A server already running is most likely one the tools started earlier: its key is in our own
        # folder, and a `dcs-serve.yaml` lying in the current folder is somebody else's.
        if api_key is None and config is None and own.is_file():
            config = str(own)
        return BridgeSession(serve_url, resolve_api_key(api_key, config))
    exe = find_dcs_serve(dcs_serve)
    if exe is None:
        raise DcsServeMissing(t("bridge.serve_missing", url=serve_url))
    config_path, key = ensure_config(workdir, serve_url)
    server = DcsServe(exe, workdir)
    server.start(serve_url)
    return BridgeSession(serve_url, key, started=server, config_path=config_path)


def wait_for_mission(
    session: BridgeSession,
    wait_seconds: float = DEFAULT_WAIT_SECONDS,
    *,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
    poll_seconds: float = POLL_SECONDS,
) -> None:
    """Wait until the mission's bridge answers through *session*.

    "No mission yet" — a 503 or a 504 from ``dcs-serve`` — is waited through. A refused key, anything
    else answering on the port, and a ``dcs-serve`` that no longer answers are refused at once: waiting
    would not change them.

    Args:
        session: The session to wait on.
        wait_seconds: How long to wait.
        clock: Monotonic clock (injected by tests).
        sleep: Sleep function (injected by tests).
        poll_seconds: Delay between two attempts.

    Raises:
        RuntimeError: The key is refused, the port answers with something else, ``dcs-serve`` is gone,
            the bridge answered with a Lua error, or nothing answered within *wait_seconds* — each with
            a message saying what to do.
    """
    deadline = clock() + wait_seconds
    while True:
        try:
            if session.run("return 'ok'", timeout=10.0) == "ok":
                return
            last = "unexpected reply"
        except BridgeAuthError as exc:
            raise RuntimeError(t("bridge.key_refused", error=str(exc))) from exc
        except BridgeLuaError as exc:
            raise RuntimeError(str(exc)) from exc
        except BridgeHttpError as exc:
            # 503 is dcs-serve with no mission yet, the one thing worth waiting for.
            if exc.code != 503:
                raise RuntimeError(t("bridge.not_a_dcs_serve", url=session.serve_url, error=str(exc))) from exc
            last = str(exc)
        except RuntimeError as exc:
            if not is_serving(session.serve_url):
                raise RuntimeError(t("bridge.serve_gone", url=session.serve_url)) from exc
            last = str(exc)
        if clock() >= deadline:
            raise RuntimeError(t("bridge.gave_up", seconds=int(wait_seconds), error=last))
        sleep(poll_seconds)
