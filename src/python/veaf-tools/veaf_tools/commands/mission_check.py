"""Check a VEAF mission: its wind against its briefing, then, inside a running DCS, F10 labels, combat zones
and missions, columns that drive.

The wind check (FEAT-MISSION-WIND-CHECK) needs no DCS: given the built mission, it compares every wind the
briefing announces with the wind DCS's model simulates, and runs first, so the verdict is there even when
the game is not.

Machine-only, like ``smoke-test``: it needs the mission running in DCS on this machine, launched by
the user. It switches every combat zone and combat mission on and off and leaves each as it found it.

``mission-check-prepare`` writes the test copy to launch — the mission with the VEAF bridge embedded —
and ``mission-check`` talks to it through that bridge, starting ``dcs-serve`` when none runs.
"""

import time
from pathlib import Path

import typer
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, resolve_bridge_lua
from veaf_libs.dcs_bridge_session import DEFAULT_WAIT_SECONDS, BridgeSession
from veaf_libs.dcs_mission_check import (
    INVENTORY_LUA,
    Report,
    check_mission_path,
    derive_check_mission,
    expected_duration,
    format_line,
    parse_inventory,
    run_checks,
    verdict,
)
from veaf_libs.dcs_wind import MODEL_DCS_VERSION
from veaf_libs.mission_wind_check import (
    check_built_mission,
    judge_measure,
    measure_lua,
    parse_measure,
    wind_places,
    write_measure,
)

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.bridge import open_bridge


@app.command(name="mission-check-prepare", no_args_is_help=True, help=t("cmd.mission_check_prepare.help"))
def mission_check_prepare(
    mission: Path = typer.Argument(..., exists=True, dir_okay=False, help=t("cmd.mission_check_prepare.opt.mission")),
    out: Path | None = typer.Option(None, "--out", help=t("cmd.mission_check_prepare.opt.out")),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.bridge.opt.bridge_lua")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Write the test copy of a built mission, the bridge embedded."""
    logger.set_verbose(verbose)
    console.print(t("cmd.mission_check_prepare.title", version=VERSION))
    target = out or check_mission_path(mission)
    try:
        derive_check_mission(mission, target, resolve_bridge_lua(bridge_lua))
    except ValueError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=2) from error
    except (RuntimeError, OSError) as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    console.print(t("cmd.mission_check_prepare.written", path=target))
    console.print(t("cmd.mission_check_prepare.next", path=target.name))


def _resolve_mission(mission: Path) -> tuple[Path, Path | None]:
    """The built ``.miz`` and its mission folder, from either.

    Args:
        mission: A built ``.miz`` or a mission folder.

    Returns:
        The ``.miz``, and the folder when there is one (it holds ``mission.yaml``).

    Raises:
        typer.Exit: Code 2, when a folder holds no built ``.miz``.
    """
    from campaign_manager.mission_picture import find_built_mission  # noqa: PLC0415

    if mission.is_dir():
        miz = find_built_mission(mission)
        if miz is None:
            console.print(f"[red]✗[/]  {mission} holds no built .miz: build it first")
            raise typer.Exit(code=2)
        return miz, mission
    folder = mission.parent if (mission.parent / "mission.yaml").is_file() else None
    return mission, folder


def _wind_check(miz: Path, folder: Path | None, report: Report) -> None:
    """Run the wind check, without DCS, into *report*, printing each line."""
    console.print(t("cmd.mission_check.wind_title", version=MODEL_DCS_VERSION))
    for ok, text in check_built_mission(miz, folder).lines:
        line = report.add(None if ok == "warn" else ok, "wind", text, warning=ok == "warn")  # type: ignore[arg-type]
        console.print(format_line(line))


def _measure_wind(bridge: BridgeSession, miz: Path, report: Report) -> None:
    """Read the wind in the running test copy and compare it with the model (``--measure-wind``)."""
    from mission_tools.miz_tools import read_miz  # noqa: PLC0415
    from veaf_libs.terrain_elevation import grid_for_theatre  # noqa: PLC0415

    mission = read_miz(miz)
    content = mission.mission_content or {}
    theatre = (mission.theatre_content or "").strip() or None
    grid = grid_for_theatre(theatre) if theatre else None
    places, _ = wind_places(content, theatre, ground_at=grid.elevation_at if grid else None)
    setting = (content.get("weather") or {}).get("wind") or {}
    version, readings = parse_measure(bridge.run(measure_lua(places)), places, setting)
    for ok, text in judge_measure(version, readings):
        console.print(format_line(report.add(ok, "wind", text)))
    target = check_mission_path(miz).with_suffix(".wind.json")
    write_measure(target, version, readings)
    console.print(t("cmd.mission_check.measure_written", path=target))


@app.command(name="mission-check", help=t("cmd.mission_check.help"))
def mission_check(
    mission: Path | None = typer.Argument(None, exists=True, help=t("cmd.mission_check.opt.mission")),
    only: list[str] = typer.Option([], "--only", help=t("cmd.mission_check.opt.only")),
    wind_only: bool = typer.Option(False, "--wind-only", help=t("cmd.mission_check.opt.wind_only")),
    measure_wind: bool = typer.Option(False, "--measure-wind", help=t("cmd.mission_check.opt.measure_wind")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.bridge.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.bridge.opt.dcs_serve")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.bridge.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.bridge.opt.config")),
    wait: int = typer.Option(DEFAULT_WAIT_SECONDS, "--wait", min=0, help=t("cmd.bridge.opt.wait")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Run the wind check when a mission is given, then the in-game checks, one line each, then the verdict."""
    logger.set_verbose(verbose)
    console.print(t("cmd.mission_check.title", version=VERSION))
    report = Report()
    miz: Path | None = None
    if mission is not None:
        miz, folder = _resolve_mission(mission)
        _wind_check(miz, folder, report)
    elif measure_wind or wind_only:
        console.print(f"[red]✗[/]  {t('cmd.mission_check.measure_needs_mission')}")
        raise typer.Exit(code=2)
    if not wind_only:
        try:
            bridge = open_bridge(serve_url, dcs_serve, api_key, config, wait)
        except typer.Exit:
            if mission is None:
                raise
            # The wind verdict stands without the game; the rest waits for it.
            console.print(t("cmd.mission_check.rest_needs_game"))
            _finish(report)
            return
        try:
            if measure_wind and miz is not None:
                _measure_wind(bridge, miz, report)
            entities = parse_inventory(bridge.run(INVENTORY_LUA))
            console.print(t("cmd.mission_check.expect", count=len(entities), minutes=expected_duration(len(entities))))
            run_checks(
                bridge.run, time.sleep, lambda line: console.print(format_line(line)), only=only or None, report=report
            )
        except RuntimeError as error:
            console.print(f"[red]✗[/]  {error}")
            raise typer.Exit(code=1) from error
        finally:
            bridge.close()
    _finish(report)


def _finish(report: Report) -> None:
    """Print the verdict, and exit 1 when a check failed — a warning never does."""
    console.print(verdict(report))
    if not report.passed:
        raise typer.Exit(code=1)
