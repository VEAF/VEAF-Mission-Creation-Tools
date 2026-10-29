"""Check a VEAF mission inside a running DCS: F10 labels, combat zones and missions, columns that drive.

Machine-only, like ``smoke-test``: it needs the mission running in DCS on this machine, launched by
the user. It switches every combat zone and combat mission on and off and leaves each as it found it.

``mission-check-prepare`` writes the test copy to launch — the mission with the VEAF bridge embedded —
and ``mission-check`` talks to it through that bridge, starting ``dcs-serve`` when none runs.
"""

import time
from pathlib import Path

import typer
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, resolve_bridge_lua
from veaf_libs.dcs_bridge_session import DEFAULT_WAIT_SECONDS
from veaf_libs.dcs_mission_check import (
    INVENTORY_LUA,
    check_mission_path,
    derive_check_mission,
    expected_duration,
    format_line,
    parse_inventory,
    run_checks,
    verdict,
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


@app.command(name="mission-check", help=t("cmd.mission_check.help"))
def mission_check(
    only: list[str] = typer.Option([], "--only", help=t("cmd.mission_check.opt.only")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.bridge.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.bridge.opt.dcs_serve")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.bridge.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.bridge.opt.config")),
    wait: int = typer.Option(DEFAULT_WAIT_SECONDS, "--wait", min=0, help=t("cmd.bridge.opt.wait")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Run the in-game checks and print one line per check, then the verdict."""
    logger.set_verbose(verbose)
    console.print(t("cmd.mission_check.title", version=VERSION))
    bridge = open_bridge(serve_url, dcs_serve, api_key, config, wait)
    try:
        entities = parse_inventory(bridge.run(INVENTORY_LUA))
        console.print(t("cmd.mission_check.expect", count=len(entities), minutes=expected_duration(len(entities))))
        report = run_checks(bridge.run, time.sleep, lambda line: console.print(format_line(line)), only=only or None)
    except RuntimeError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    finally:
        bridge.close()
    console.print(verdict(report))
    if not report.passed:
        raise typer.Exit(code=1)
