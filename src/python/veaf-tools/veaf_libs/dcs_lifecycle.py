"""Drive a whole DCS run unattended: launch → load → assert → quit.

The first slice of ``FEAT-DCS-SMOKE-HARNESS`` deliberately stopped at "DCS must already be running":
the DCS-side calls this step rests on — ``net.load_mission`` and ``Sim.exitProcess`` — had never been
made from this repository, and writing them blind is the trap the whole lot exists to avoid. The probe
has since **measured** them on a live install (``FEAT-DCS-SMOKE-HARNESS`` ticket 02): ``net.load_mission``
is present and ``Sim.isServer()`` is true in single-player, which is what makes the SERVER-ONLY call
legitimate on a local instance; ``exitProcess`` is present. So this module writes the lifecycle the
probe cleared.

Everything the simulator touches goes through injectable seams (``launcher``, ``prober``, ``hook_exec``,
``sleeper``, ``clock``), so the orchestration — the state machine, the bounded waits, the guarantee that
a launched DCS is always terminated — is unit-tested with fakes. The real-DCS behaviour of the calls
themselves is what the live run confirms; a unit test cannot, which is the honest boundary this lot
keeps drawing.

Two measurements shape the waits and are cited where they bite:

- ``onSimulationFrame`` fires at ~28 Hz **with no mission loaded**, so the hook answers at the main menu
  and the launch wait can poll it rather than sleeping a fixed time.
- the sim-frame counter **freezes during the blocking mission load** (~24 s observed), so the load wait
  must watch the mission *name* appear, never a "no ticks for N seconds means it died" watchdog — that
  watchdog would fire on every healthy load.
"""

from __future__ import annotations

import subprocess
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

from veaf_libs.dcs_fiddle_client import (
    DEFAULT_FIDDLE_URL,
    ENV_HOOK,
    Capabilities,
    FiddleError,
    exec_lua,
    probe,
)
from veaf_libs.dcs_smoke import CHECKS, Check, Result, run
from veaf_libs.lua_literals import lua_quoted_string


class DcsLifecycleError(RuntimeError):
    """A lifecycle step could not complete — the message names which one."""


class Process(Protocol):
    """The slice of :class:`subprocess.Popen` the driver needs, so a fake can stand in."""

    def poll(self) -> int | None:
        """Return the exit code, or ``None`` while the process is still running."""

    def terminate(self) -> None:
        """Ask the process to exit."""

    def kill(self) -> None:
        """Force the process to exit."""


#: How the driver reaches DCS. Defaults wire the real simulator; tests pass fakes.
Launcher = Callable[[Path], Process]
Prober = Callable[..., Capabilities]
HookExec = Callable[..., object]


@dataclass
class LifecycleConfig:
    """What one unattended run needs to know.

    Args:
        dcs_exe: Path to ``DCS.exe`` to launch.
        mission: Path to the ``.miz`` to load once the hook answers.
        checks: The assertions to run once the mission is up.
        url: Base URL of the ``dcs-fiddle-server.lua`` hook.
        timeout: Per-request socket timeout for the hook, in seconds.
        launch_timeout: How long to wait for the hook to answer after launch, in seconds. DCS start-up
            is tens of seconds and varies with the map, so this is generous on purpose.
        load_timeout: How long to wait for the mission name to appear after ``net.load_mission``.
        quit_timeout: How long to wait for the process to exit after ``exitProcess`` before killing it.
        poll_interval: Seconds between readiness polls.
    """

    dcs_exe: Path
    mission: Path
    checks: tuple[Check, ...] = CHECKS
    url: str = DEFAULT_FIDDLE_URL
    timeout: float = 10.0
    launch_timeout: float = 180.0
    load_timeout: float = 180.0
    quit_timeout: float = 60.0
    poll_interval: float = 2.0


@dataclass
class RunReport:
    """What an unattended run produced, step by step.

    Args:
        steps: A human-readable line per step reached, in order — this is a tool someone reads at a
            workstation while debugging, so the trail matters as much as the verdict.
        result: The check outcomes, or ``None`` when the run never reached the assertion step.
        launched: Whether this run started the DCS process (and therefore owns quitting it).
        quit_clean: Whether DCS exited on its own after ``exitProcess`` rather than being killed.
        error: The step that failed, verbatim, or ``None`` on a clean run.
    """

    steps: list[str] = field(default_factory=list)
    result: Result | None = None
    launched: bool = False
    quit_clean: bool = False
    error: str | None = None

    @property
    def exit_code(self) -> int:
        """``0`` when the run reached the checks and every one passed, ``1`` otherwise."""
        if self.error is not None:
            return 1
        return self.result.exit_code if self.result else 1


#: Where ``DCS.exe`` sits relative to the install root the probe reports (``lfs.currentdir()``), most
#: specific first. ``lfs.currentdir()`` may already be the ``bin`` directory, so the root itself and a
#: bare path are both tried.
_DCS_EXE_CANDIDATES: tuple[str, ...] = ("bin/DCS.exe", "DCS.exe", "bin-mt/DCS.exe")


def find_dcs_executable(install_dir: str | Path | None) -> Path | None:
    """Locate ``DCS.exe`` under the install directory the probe reported.

    Args:
        install_dir: The directory ``lfs.currentdir()`` returned, or ``None`` when unknown.

    Returns:
        The path to ``DCS.exe`` if one of the known layouts exists, else ``None``. Returning ``None``
        rather than guessing keeps "no DCS here" a skip rather than a launch of something that is not
        there.
    """
    if not install_dir:
        return None
    root = Path(install_dir)
    for candidate in _DCS_EXE_CANDIDATES:
        exe = root / candidate
        if exe.is_file():
            return exe
    return None


def _default_launcher(dcs_exe: Path) -> Process:
    """Start DCS as a detached child process."""
    return subprocess.Popen([str(dcs_exe)])  # noqa: S603 - path is operator-supplied, not user input


def run_unattended(
    cfg: LifecycleConfig,
    *,
    launcher: Launcher = _default_launcher,
    prober: Prober = probe,
    hook_exec: HookExec = exec_lua,
    runner: Callable[..., Result] = run,
    sleeper: Callable[[float], None] = time.sleep,
    clock: Callable[[], float] = time.monotonic,
    allow_running: bool = False,
    **run_kwargs: object,
) -> RunReport:
    """Launch DCS, load *cfg.mission*, run the checks, and quit — unattended.

    Args:
        cfg: The run's parameters.
        launcher: Starts DCS and returns a handle; defaults to a real subprocess.
        prober: Reads capabilities from the hook; defaults to :func:`probe`.
        hook_exec: Runs Lua in the hook environment; defaults to :func:`exec_lua`.
        runner: Runs the checks; defaults to :func:`dcs_smoke.run`.
        sleeper: How to wait between polls; injectable so tests do not sleep.
        clock: Monotonic time source; injectable for the same reason.
        allow_running: When a DCS is already answering, proceed against it instead of refusing. Off by
            default: loading a mission into a session someone is already using is destructive, and the
            harness must not do that to a live cockpit without being told to.
        **run_kwargs: Forwarded to *runner* (e.g. ``serve_url``, ``api_key``) for the bridge checks.

    Returns:
        A :class:`RunReport`. A launched DCS is **always** terminated before returning, even on failure —
        a stuck instance holds a licence seat and the next run inherits the mess.
    """
    report = RunReport()
    process: Process | None = None

    # A DCS already up is not ours to hijack. Either use it (told to, and then we do not quit it) or
    # refuse — never load a mission over someone's live session by default.
    pre = prober(url=cfg.url, timeout=cfg.timeout)
    if pre.hook_alive:
        if not allow_running:
            report.error = (
                "a DCS is already running and answering the hook; refusing to load a mission over it. "
                "Pass allow_running to use the running instance."
            )
            report.steps.append(report.error)
            return report
        report.steps.append("a DCS is already running; using it (will not quit an instance we did not start)")

    try:
        if not pre.hook_alive:
            report.steps.append(f"launching {cfg.dcs_exe}")
            process = launcher(cfg.dcs_exe)
            report.launched = True
            caps = _wait_for_hook(cfg, prober, sleeper, clock)
            report.steps.append(f"hook answered: {caps.mission_name or 'main menu'}")
        else:
            caps = pre

        report.steps.append(f"loading {cfg.mission.name}")
        _load_mission(cfg, hook_exec)
        caps = _wait_for_mission(cfg, prober, sleeper, clock)
        report.steps.append(f"mission loaded: {caps.mission_name}")

        report.steps.append("running checks")
        report.result = runner(checks=cfg.checks, url=cfg.url, timeout=cfg.timeout, **run_kwargs)
        report.steps.append(
            f"checks: {len(report.result.outcomes) - len(report.result.failed)}/{len(report.result.outcomes)} passed"
            if not report.result.skipped
            else f"checks skipped: {report.result.skip_reason}"
        )
    except DcsLifecycleError as exc:
        report.error = str(exc)
        report.steps.append(f"failed: {exc}")
    finally:
        if report.launched and process is not None:
            report.quit_clean = _quit(cfg, process, hook_exec, sleeper, clock, report)

    return report


def _wait_for_hook(
    cfg: LifecycleConfig, prober: Prober, sleeper: Callable[[float], None], clock: Callable[[], float]
) -> Capabilities:
    """Poll the hook until it answers, bounded by ``launch_timeout``.

    The measurement that makes this a poll rather than a fixed sleep: ``onSimulationFrame`` ticks at the
    main menu, so the hook replies well before any mission exists.
    """
    deadline = clock() + cfg.launch_timeout
    while clock() < deadline:
        caps = prober(url=cfg.url, timeout=cfg.timeout)
        if caps.hook_alive:
            return caps
        sleeper(cfg.poll_interval)
    raise DcsLifecycleError(
        f"DCS did not answer the hook within {cfg.launch_timeout:.0f}s of launch — "
        "is dcs-fiddle-server.lua installed in Saved Games/DCS/Scripts/Hooks/?"
    )


def _load_mission(cfg: LifecycleConfig, hook_exec: HookExec) -> None:
    """Ask DCS to load the test mission through ``net.load_mission``.

    Called in the hook environment, where ``net.*`` lives. **Measured limitation (2026-08-15)**:
    ``net.load_mission`` is *present* and ``isServer()`` is true in single-player, but calling it from
    the main menu returns nil and **no mission becomes active** — ED documents it SERVER ONLY, and in
    practice it needs a running server (``net.start_server``), not just a local instance. So this call
    succeeds (returns nothing) yet loads nothing in single-player; :func:`_wait_for_mission` is what
    turns that into a legible failure. Loading a mission unattended in single-player is unsolved — see
    ``FEAT-DCS-SMOKE-HARNESS`` ticket 02 (option 3, a mission on the command line, is the next avenue).
    """
    lua = f"net.load_mission({lua_quoted_string(str(cfg.mission))}) return 'called'"
    try:
        hook_exec(lua, env=ENV_HOOK, url=cfg.url, timeout=cfg.timeout)
    except FiddleError as exc:
        raise DcsLifecycleError(f"net.load_mission({cfg.mission}) failed: {exc}") from exc


def _wait_for_mission(
    cfg: LifecycleConfig, prober: Prober, sleeper: Callable[[float], None], clock: Callable[[], float]
) -> Capabilities:
    """Poll until a mission name appears, bounded by ``load_timeout``.

    Watches the mission *name*, never a frame counter: the sim-frame counter freezes during the blocking
    load, so a "no ticks means it died" watchdog would fire on every healthy one.
    """
    deadline = clock() + cfg.load_timeout
    while clock() < deadline:
        caps = prober(url=cfg.url, timeout=cfg.timeout)
        if caps.mission_name:
            return caps
        sleeper(cfg.poll_interval)
    raise DcsLifecycleError(
        f"no mission became active within {cfg.load_timeout:.0f}s of net.load_mission — in single-player "
        "that call loads nothing (it needs a running server), so unattended --full load is unsolved here; "
        "load the mission by hand and use `smoke-test` (without --full) to assert against it"
    )


def _quit(
    cfg: LifecycleConfig,
    process: Process,
    hook_exec: HookExec,
    sleeper: Callable[[float], None],
    clock: Callable[[], float],
    report: RunReport,
) -> bool:
    """Ask DCS to quit, then make sure it is gone — killing it if it will not go.

    Returns:
        ``True`` when DCS exited on its own after ``exitProcess``, ``False`` when it had to be killed.

    ``exitProcess`` tears the process down mid-reply, so the transport call not returning is the normal
    case, not a failure — its error is swallowed. What matters is that the process is dead by the end.
    """
    report.steps.append("quitting DCS")
    try:
        # Either control-table name works (probe measured Sim and DCS are the same table), so try both.
        hook_exec(
            "if type(Sim) == 'table' and Sim.exitProcess then Sim.exitProcess() "
            "elseif type(DCS) == 'table' and DCS.exitProcess then DCS.exitProcess() end return 'quitting'",
            env=ENV_HOOK,
            url=cfg.url,
            timeout=cfg.timeout,
        )
    except FiddleError:
        pass  # exitProcess kills the process mid-reply; a lost reply here is expected, not an error.

    deadline = clock() + cfg.quit_timeout
    while clock() < deadline:
        if process.poll() is not None:
            report.steps.append("DCS exited cleanly")
            return True
        sleeper(cfg.poll_interval)

    report.steps.append(f"DCS did not exit within {cfg.quit_timeout:.0f}s — killing it")
    process.terminate()
    if process.poll() is None:
        process.kill()
    return False
