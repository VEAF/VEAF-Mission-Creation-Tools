"""Check a VEAF mission inside a running DCS: F10 labels, combat zones and missions, columns that drive.

Machine-only, like ``smoke-test``: it needs the mission running in DCS on this machine, launched by
the user. It switches every combat zone and combat mission on and off and leaves each as it found it.
"""

import time

import typer
from veaf_libs.dcs_fiddle_client import (
    DEFAULT_FIDDLE_URL,
    FiddleError,
    exec_lua,
    resolve_fiddle_token,
    set_session_token,
)
from veaf_libs.dcs_mission_check import (
    INVENTORY_LUA,
    expected_duration,
    format_line,
    parse_inventory,
    run_checks,
    verdict,
)
from veaf_libs.dcs_recon import ENV_SERVER

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(name="mission-check", help=t("cmd.mission_check.help"))
def mission_check(
    only: list[str] = typer.Option([], "--only", help=t("cmd.mission_check.opt.only")),
    url: str = typer.Option(DEFAULT_FIDDLE_URL, "--url", help=t("cmd.recon.opt.url")),
    fiddle_token: str | None = typer.Option(
        None, "--fiddle-token", envvar="DCS_FIDDLE_TOKEN", help=t("cmd.recon.opt.fiddle_token")
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Run the in-game checks and print one line per check, then the verdict."""
    logger.set_verbose(verbose)
    console.print(t("cmd.mission_check.title", version=VERSION))
    set_session_token(resolve_fiddle_token(fiddle_token))

    def run(code: str) -> str:
        result = exec_lua(code, env=ENV_SERVER, url=url, timeout=30.0)
        return "" if result is None else str(result)

    try:
        entities = parse_inventory(run(INVENTORY_LUA))
        console.print(t("cmd.mission_check.expect", count=len(entities), minutes=expected_duration(len(entities))))
        report = run_checks(run, time.sleep, lambda line: console.print(format_line(line)), only=only or None)
    except FiddleError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    console.print(verdict(report))
    if not report.passed:
        raise typer.Exit(code=1)
