"""``veaf-tools dcs terrain-sweep`` — sweep a theatre's ground elevation, guided (FEAT-TERRAIN-ELEVATION).

The clear-ground sweep's session (dcs-serve, empty survey mission, instructions, waiting), with
``land.getHeight`` as the probe, over the whole map. ``--measure-at`` sweeps fine reference patches
instead and compares the candidate spacings against them, which is how the default spacing was chosen.
"""

import json
from pathlib import Path

import typer
from rich.progress import BarColumn, MofNCompleteColumn, Progress, TextColumn, TimeElapsedColumn, TimeRemainingColumn
from veaf_libs.blank_mission import canonical_theatre_name
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL
from veaf_libs.dcs_serve_launcher import DcsServe
from veaf_libs.terrain_elevation import grid_file_name, local_grid_dir, save_grid
from veaf_libs.terrain_survey import (
    DEFAULT_BATCH_CELLS,
    DEFAULT_SPACING_METERS,
    TerrainSweepState,
    map_bounds,
    measure_resolution,
    plan_grid,
    sweep,
)

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.commands.clear_ground import _open_survey_session, _parse_point


@app.command(name="terrain-sweep", no_args_is_help=True, help=t("cmd.terrain_sweep.help"))
def terrain_sweep(
    theatre: str = typer.Argument(..., help=t("cmd.clear_ground.opt.theatre")),
    spacing: float = typer.Option(
        DEFAULT_SPACING_METERS, "--spacing", min=10.0, help=t("cmd.terrain_sweep.opt.spacing")
    ),
    bounds: str | None = typer.Option(None, "--bounds", help=t("cmd.terrain_sweep.opt.bounds")),
    measure_at: list[str] | None = typer.Option(None, "--measure-at", help=t("cmd.terrain_sweep.opt.measure_at")),
    out: str | None = typer.Option(None, "--out", help=t("cmd.terrain_sweep.opt.out")),
    survey_mission: str | None = typer.Option(
        None, "--survey-mission", help=t("cmd.clear_ground_sweep.opt.survey_mission")
    ),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.inject_bridge.opt.bridge_lua")),
    state_dir: str | None = typer.Option(None, "--state-dir", help=t("cmd.terrain_sweep.opt.state_dir")),
    restart: bool = typer.Option(False, "--restart", help=t("cmd.clear_ground_sweep.opt.restart")),
    batch: int = typer.Option(DEFAULT_BATCH_CELLS, "--batch", min=1, help=t("cmd.terrain_sweep.opt.batch")),
    wait: int = typer.Option(900, "--wait", min=0, help=t("cmd.clear_ground_sweep.opt.wait")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.capture_map.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.capture_map.opt.config")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.capture_map.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.clear_ground_sweep.opt.dcs_serve")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Sweep the ground elevation of *theatre*, guiding the user through DCS, and write its grid."""
    logger.set_verbose(verbose)
    console.print(t("cmd.terrain_sweep.title", version=VERSION))
    started: list[DcsServe] = []
    theatre = canonical_theatre_name(theatre)
    try:
        explicit = _parse_bounds(bounds) if bounds else None
        centres = [_parse_point(spec) for spec in measure_at or []]
        exec_lua = _open_survey_session(
            theatre, survey_mission, bridge_lua, serve_url, dcs_serve, api_key, config, wait, started
        )
        if centres:
            with console.status(t("cmd.terrain_sweep.measuring", count=len(centres))):
                report = measure_resolution(exec_lua, theatre, centres, batch_cells=batch)
            target = Path(out) if out else local_grid_dir() / f"resolution-{theatre}.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(report.to_dict(), indent=1), encoding="utf-8")
            for patch in report.patches:
                console.print(t("cmd.terrain_sweep.patch", **patch))
            for s in report.spacings:
                console.print(t("cmd.terrain_sweep.spacing_result", **s.to_dict()))
            console.print(t("cmd.terrain_sweep.measured", path=str(target)))
            return
        if explicit is None:
            extent, source = map_bounds(exec_lua, theatre)
            console.print(t(f"cmd.terrain_sweep.bounds_{source}", bounds=_format_bounds(extent)))
        else:
            extent = explicit
        grid = plan_grid(extent, spacing)
        state = TerrainSweepState(
            Path(state_dir) if state_dir else local_grid_dir() / f"sweep-{theatre}", theatre, grid
        )
        state.open(restart=restart)
        console.print(
            t("cmd.terrain_sweep.plan", rows=grid.rows, cols=grid.cols, cells=grid.size, pending=state.pending())
        )
        with Progress(
            TextColumn("{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TextColumn("{task.percentage:>3.0f}%"),
            TimeElapsedColumn(),
            TimeRemainingColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(theatre, total=grid.size, completed=state.done)
            sweep(
                state,
                exec_lua,
                batch_cells=batch,
                on_progress=lambda done, _total: progress.update(task, completed=done),
            )
        grid_path = Path(out) if out else local_grid_dir() / grid_file_name(theatre)
        elevation = state.elevation()
        save_grid(elevation, grid_path)
    except (RuntimeError, OSError, ValueError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    finally:
        for server in started:
            server.stop()
    console.print(
        t(
            "cmd.terrain_sweep.done",
            theatre=theatre,
            cells=grid.size,
            low=min(elevation.heights),
            high=max(elevation.heights),
            size=grid_path.stat().st_size // 1024,
            path=str(grid_path),
        )
    )


def _parse_bounds(spec: str) -> tuple[float, float, float, float]:
    """Parse ``--bounds min_x,min_y,max_x,max_y`` (mission coordinates).

    Args:
        spec: The option's value.

    Returns:
        The extent, with each pair ordered.

    Raises:
        ValueError: If the value is not four comma-separated numbers.
    """
    try:
        x1, y1, x2, y2 = (float(part) for part in spec.split(","))
    except ValueError as e:
        raise ValueError(t("cmd.terrain_sweep.bad_bounds", value=spec)) from e
    return min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)


def _format_bounds(extent: tuple[float, float, float, float]) -> str:
    """Write an extent the way ``--bounds`` takes it, so the user can pass it back."""
    return ",".join(f"{v:.0f}" for v in extent)
