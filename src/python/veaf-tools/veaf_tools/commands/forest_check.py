"""``veaf-tools dcs forest-check`` — list the ground vehicles of a mission standing in a forest.

Reads the forests from the map files of the DCS install (FEAT-FOREST-CHECK); the game is not launched.
"""

import json
from pathlib import Path

import typer
from veaf_libs.dcs_forests import SurfaceFormatError, check_mission_forests

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(name="forest-check", no_args_is_help=True, help=t("cmd.forest_check.help"))
def forest_check(
    mission: str = typer.Argument(..., help=t("cmd.forest_check.opt.mission")),
    dcs_dir: str | None = typer.Option(None, "--dcs-dir", help=t("cmd.forest_check.opt.dcs_dir")),
    report: str | None = typer.Option(None, "--report", help=t("cmd.forest_check.opt.report")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """List the ground vehicles of *mission* standing in a forest, from the map files of DCS."""
    logger.set_verbose(verbose)
    console.print(t("cmd.forest_check.title", version=VERSION))
    try:
        result = check_mission_forests(Path(mission), Path(dcs_dir) if dcs_dir else None)
        if report:
            Path(report).write_text(json.dumps(result.to_dict(), indent=1), encoding="utf-8")
    except (OSError, SurfaceFormatError, ValueError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    console.print(t("cmd.forest_check.source", theatre=result.theatre, path=result.surface_file))
    for group, count in sorted(result.groups.items()):
        console.print(t("cmd.forest_check.group_in_forest", group=group, count=count))
    console.print(
        t(
            "cmd.forest_check.done",
            units=result.units_checked,
            in_forest=len(result.in_forest),
            groups=len(result.groups),
            markers=result.markers_skipped,
        )
    )
