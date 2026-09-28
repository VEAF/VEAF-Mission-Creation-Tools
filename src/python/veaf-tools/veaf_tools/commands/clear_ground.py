"""``veaf-tools dcs clear-ground-sweep`` — sweep a theatre for ground clear of scenery, guided.

One command, start to finish (FEAT-CLEAR-GROUND-AT-AUTHORING):

1. write a survey mission holding **no unit at all**, carrying the dcs-bridge — the probe counts
   vehicles as obstacles, so any unit on the map would be swept as scenery;
2. tell the user what to do in DCS, and wait for them;
3. wait for the bridge to answer, and check the mission is the empty one, on the right theatre;
4. probe the ground around the airfields (and the combat zones of a mission, or given points),
   showing progress, resuming a sweep that was interrupted;
5. write the catalogue, and say DCS can be closed.
"""

import json
import time
from pathlib import Path

import typer
from rich.progress import BarColumn, MofNCompleteColumn, Progress, TextColumn, TimeElapsedColumn, TimeRemainingColumn
from veaf_libs.blank_mission import canonical_theatre_name
from veaf_libs.clear_ground_catalogue import catalogue_file_name, local_catalogue_dir, save_catalogue
from veaf_libs.clear_ground_check import check_mission, ground_units
from veaf_libs.clear_ground_survey import (
    DEFAULT_BATCH_CELLS,
    LuaExec,
    SurveyError,
    SweepState,
    build_survey_mission,
    check_survey_mission,
    combat_zones_of,
    plan_sweep,
    sweep,
)
from veaf_libs.dcs_bridge_capture import (
    DEFAULT_SERVE_URL,
    BridgeAuthError,
    BridgeHttpError,
    exec_over_bridge,
    resolve_api_key,
    resolve_bridge_lua,
)
from veaf_libs.dcs_serve_launcher import DcsServe, ensure_config, find_dcs_serve, is_serving
from veaf_libs.diagnostics import find_dcs_write_dirs

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.helpers import is_interactive

#: Seconds one call may take. A 10 000-cell batch takes 1.5 s measured; the rest is headroom for a
#: loaded workstation.
_CALL_TIMEOUT_SECONDS = 120.0
#: Seconds between two attempts to reach the mission while waiting for it.
_POLL_SECONDS = 3.0


@app.command(name="clear-ground-sweep", no_args_is_help=True, help=t("cmd.clear_ground_sweep.help"))
def clear_ground_sweep(
    theatre: str = typer.Argument(..., help=t("cmd.clear_ground.opt.theatre")),
    mission: str | None = typer.Option(None, "--zones-from", help=t("cmd.clear_ground_sweep.opt.zones_from")),
    around: list[str] | None = typer.Option(None, "--around", help=t("cmd.clear_ground_sweep.opt.around")),
    airfields: bool = typer.Option(True, "--airfields/--no-airfields", help=t("cmd.clear_ground_sweep.opt.airfields")),
    out: str | None = typer.Option(None, "--out", help=t("cmd.clear_ground_sweep.opt.out")),
    survey_mission: str | None = typer.Option(
        None, "--survey-mission", help=t("cmd.clear_ground_sweep.opt.survey_mission")
    ),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.inject_bridge.opt.bridge_lua")),
    state_dir: str | None = typer.Option(None, "--state-dir", help=t("cmd.clear_ground_sweep.opt.state_dir")),
    restart: bool = typer.Option(False, "--restart", help=t("cmd.clear_ground_sweep.opt.restart")),
    batch: int = typer.Option(DEFAULT_BATCH_CELLS, "--batch", min=1, help=t("cmd.clear_ground_sweep.opt.batch")),
    wait: int = typer.Option(900, "--wait", min=0, help=t("cmd.clear_ground_sweep.opt.wait")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.capture_map.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.capture_map.opt.config")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.capture_map.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.clear_ground_sweep.opt.dcs_serve")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Sweep *theatre* for clear ground, guiding the user through DCS, and write its catalogue."""
    logger.set_verbose(verbose)
    console.print(t("cmd.clear_ground_sweep.title", version=VERSION))
    started: list[DcsServe] = []
    # DCS spells the theatre one way, and the mission it runs, the airfield data and the catalogue's
    # file name all use that spelling: `caucasus` must not sweep nothing and be saved under a name
    # nothing reads.
    theatre = canonical_theatre_name(theatre)
    try:
        zones = combat_zones_of(Path(mission)) if mission else []
        zones += [(spec, *_parse_point(spec)) for spec in around or []]
        layers = plan_sweep(theatre, zones=zones, airfields=airfields)
        if not layers:
            raise SurveyError(t("cmd.clear_ground_sweep.nothing_to_sweep"))
        exec_lua = _open_survey_session(
            theatre, survey_mission, bridge_lua, serve_url, dcs_serve, api_key, config, wait, started
        )

        state = SweepState(
            Path(state_dir) if state_dir else local_catalogue_dir() / f"sweep-{theatre}", theatre, layers
        )
        state.open(restart=restart)
        total = sum(layer.grid.size for layer in layers)
        console.print(t("cmd.clear_ground_sweep.plan", layers=len(layers), cells=total, pending=state.pending()))
        with Progress(
            TextColumn("{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TextColumn("{task.percentage:>3.0f}%"),
            TimeElapsedColumn(),
            TimeRemainingColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(theatre, total=total, completed=total - state.pending())

            def on_progress(done: int, _total: int, layer_name: str) -> None:
                progress.update(task, completed=done, description=layer_name)

            sweep(state, exec_lua, batch_cells=batch, on_progress=on_progress)
        catalogue_path = Path(out) if out else local_catalogue_dir() / catalogue_file_name(theatre)
        save_catalogue(state.catalogue(), catalogue_path)
    except (RuntimeError, OSError, ValueError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    finally:
        for server in started:
            server.stop()
    console.print(t("cmd.clear_ground_sweep.done", theatre=theatre, cells=total, path=str(catalogue_path)))


@app.command(name="clear-ground-check", no_args_is_help=True, help=t("cmd.clear_ground_check.help"))
def clear_ground_check(
    mission: str = typer.Argument(..., help=t("cmd.clear_ground_check.opt.mission")),
    survey_mission: str | None = typer.Option(
        None, "--survey-mission", help=t("cmd.clear_ground_sweep.opt.survey_mission")
    ),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.inject_bridge.opt.bridge_lua")),
    wait: int = typer.Option(900, "--wait", min=0, help=t("cmd.clear_ground_sweep.opt.wait")),
    report: str | None = typer.Option(None, "--report", help=t("cmd.clear_ground_check.opt.report")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.capture_map.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.capture_map.opt.config")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.capture_map.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.clear_ground_sweep.opt.dcs_serve")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Check in DCS whether the ground units of *mission* stand in scenery, without spawning them."""
    logger.set_verbose(verbose)
    console.print(t("cmd.clear_ground_check.title", version=VERSION))
    started: list[DcsServe] = []
    try:
        theatre, units, _markers = ground_units(Path(mission))
        if not units:
            raise SurveyError(t("cmd.clear_ground_check.no_units", mission=mission))
        exec_lua = _open_survey_session(
            theatre, survey_mission, bridge_lua, serve_url, dcs_serve, api_key, config, wait, started
        )
        result = check_mission(Path(mission), exec_lua)
        if report:
            Path(report).write_text(json.dumps(result.to_dict(), indent=1), encoding="utf-8")
    except (RuntimeError, OSError, ValueError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    finally:
        for server in started:
            server.stop()
    # The same criterion as `result.criterion`, in the user's language; the JSON report keeps the English.
    console.print(t("cmd.clear_ground_check.criterion"))
    for group, count in sorted(result.blocked_groups.items()):
        console.print(t("cmd.clear_ground_check.group_not_clear", group=group, count=count))
    if result.unknown:
        console.print(t("cmd.clear_ground_check.unknown", count=result.unknown))
    for unit in result.disagreements:
        console.print(
            t("cmd.clear_ground_check.disagreement", unit=unit.unit, probed=unit.probed, predicted=unit.predicted)
        )
    console.print(
        t(
            "cmd.clear_ground_check.done",
            units=len(result.units),
            blocked=result.blocked,
            groups=len(result.blocked_groups),
            disagreements=len(result.disagreements),
            markers=result.markers_skipped,
        )
    )


def _open_survey_session(
    theatre: str,
    survey_mission: str | None,
    bridge_lua: str | None,
    serve_url: str,
    dcs_serve: str | None,
    api_key: str | None,
    config: str | None,
    wait: int,
    started: list[DcsServe],
) -> LuaExec:
    """Everything before the probing: server, survey mission, instructions, and waiting for DCS.

    Args:
        theatre: The theatre, as DCS spells it.
        survey_mission: Where to write the survey mission, or ``None`` for the DCS Missions folder.
        bridge_lua: A local ``dcs-bridge.lua``, or ``None`` to download it.
        serve_url: Where ``dcs-serve`` is expected.
        dcs_serve: The ``dcs-serve`` executable to start when none runs.
        api_key: The key of a server the user started, if any.
        config: A ``dcs-serve.yaml`` to read that key from, if any.
        wait: How long to wait for the mission, in seconds.
        started: Receives the server started here, so the caller stops it at the end.

    Returns:
        The transport to the running, empty survey mission.
    """
    key, serve_line = _prepare_dcs_serve(serve_url, dcs_serve, api_key, config, started)

    def exec_lua(code: str) -> str:
        return exec_over_bridge(serve_url, key, code, timeout=_CALL_TIMEOUT_SECONDS)

    target = Path(survey_mission) if survey_mission else _default_survey_mission(theatre)
    build_survey_mission(theatre, target, resolve_bridge_lua(bridge_lua))
    console.print(t("cmd.clear_ground_sweep.instructions", path=str(target.resolve()), serve=serve_line))
    if is_interactive():
        console.input(t("cmd.clear_ground_sweep.press_enter"))
    _wait_for_survey_mission(exec_lua, theatre, wait, serve_url)
    return exec_lua


def _prepare_dcs_serve(
    serve_url: str, dcs_serve: str | None, api_key: str | None, config: str | None, started: list[DcsServe]
) -> tuple[str, str]:
    """Make sure a ``dcs-serve`` answers, starting one with a key of our own if none does.

    Args:
        serve_url: Where the server is expected.
        dcs_serve: The executable, when the user named it.
        api_key: The key, when the user gave it (for a server they started themselves).
        config: A ``dcs-serve.yaml`` to read the key from, likewise.
        started: Receives the server started here, so the caller stops it at the end.

    Returns:
        The API key, and the line telling the user how the server was obtained.

    Raises:
        RuntimeError: If no server answers and none can be found to start.
    """
    workdir = local_catalogue_dir() / "dcs-serve"
    if is_serving(serve_url):
        own = workdir / "dcs-serve.yaml"
        # A server already running is most likely one this command started earlier: its key is in our
        # own folder, and a `dcs-serve.yaml` lying in the current folder is somebody else's.
        if api_key is None and config is None and own.is_file():
            config = str(own)
        return resolve_api_key(api_key, config), t("cmd.clear_ground_sweep.serve_running", url=serve_url)
    exe = find_dcs_serve(dcs_serve)
    if exe is None:
        raise RuntimeError(t("cmd.clear_ground_sweep.serve_missing", url=serve_url))
    config_path, key = ensure_config(workdir, serve_url)
    server = DcsServe(exe, workdir)
    server.start(serve_url)
    started.append(server)
    return key, t("cmd.clear_ground_sweep.serve_started", exe=str(exe), config=str(config_path))


def _default_survey_mission(theatre: str) -> Path:
    """Where the survey mission goes: the missions folder of the DCS the user played last.

    That is the folder the Mission Editor opens on, so the user finds it without browsing. With no
    DCS on this machine, the current folder.

    Args:
        theatre: The theatre, as DCS spells it.

    Returns:
        The path of the survey mission.
    """
    name = f"veaf-survey-{theatre}.miz"
    write_dirs = find_dcs_write_dirs()
    return write_dirs[0] / "Missions" / name if write_dirs else Path(name)


def _wait_for_survey_mission(exec_lua: LuaExec, theatre: str, wait_seconds: int, serve_url: str) -> None:
    """Wait until the survey mission answers, then check it is the empty one on *theatre*.

    "No mission yet" (a refused connection, a 503 or a 504 from ``dcs-serve``) is retried. A mission
    on another theatre or holding units, a refused key, or anything else answering on the port is
    refused at once — waiting would not change it.

    Args:
        exec_lua: The transport.
        theatre: The theatre the survey mission must be on.
        wait_seconds: How long to wait for a first answer.
        serve_url: Where ``dcs-serve`` is expected, for the messages.

    Raises:
        SurveyError: The mission answered and is not the survey mission.
        RuntimeError: The key is refused, the port answers with something else, or nothing answered
            within *wait_seconds*.
    """
    deadline = time.monotonic() + wait_seconds
    with console.status(t("cmd.clear_ground_sweep.waiting")):
        while True:
            try:
                check_survey_mission(exec_lua, theatre)
                break
            except SurveyError:
                raise
            except BridgeAuthError as e:
                # A refused key stays refused: waiting would only hide the reason for fifteen minutes.
                raise RuntimeError(t("cmd.clear_ground_sweep.key_refused", error=str(e))) from e
            except BridgeHttpError as e:
                # 503 is dcs-serve with no mission yet, the one thing worth waiting for. Any other
                # status is something else on the port, and waiting would not change it either.
                if e.code != 503:
                    raise RuntimeError(t("cmd.clear_ground_sweep.not_a_dcs_serve", url=serve_url, error=str(e))) from e
                if time.monotonic() >= deadline:
                    raise RuntimeError(t("cmd.clear_ground_sweep.gave_up", seconds=wait_seconds, error=str(e))) from e
                time.sleep(_POLL_SECONDS)
            except RuntimeError as e:
                if time.monotonic() >= deadline:
                    raise RuntimeError(t("cmd.clear_ground_sweep.gave_up", seconds=wait_seconds, error=str(e))) from e
                time.sleep(_POLL_SECONDS)
    console.print(t("cmd.clear_ground_sweep.connected", theatre=theatre))


def _parse_point(spec: str) -> tuple[float, float]:
    """Parse ``--around x,y`` (mission coordinates) into a point.

    Args:
        spec: The option's value.

    Returns:
        The point, as mission ``(x, y)``.

    Raises:
        ValueError: If the value is not two comma-separated numbers.
    """
    try:
        x, y = (float(part) for part in spec.split(","))
    except ValueError as e:
        raise ValueError(t("cmd.clear_ground_sweep.bad_point", value=spec)) from e
    return x, y
