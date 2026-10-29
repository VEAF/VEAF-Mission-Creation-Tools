"""Run the in-DCS smoke checks against the mission running in DCS.

Machine-only: it needs a DCS install, so it never runs in CI (GitHub runners have no DCS, licence or
GPU). The user launches DCS and a mission built with ``dcs_bridge``; the command talks to it through
the VEAF bridge, starting ``dcs-serve`` when none runs.
"""

import typer
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL
from veaf_libs.dcs_bridge_session import DEFAULT_WAIT_SECONDS
from veaf_libs.dcs_smoke import CHECKS, SPOTTER_CHECKS, format_result, run

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.bridge import open_bridge


@app.command(name="smoke-test", help=t("cmd.smoke_test.help"))
def smoke_test(
    suite: str = typer.Option("default", "--suite", help=t("cmd.smoke_test.opt.suite")),
    timeout: float = typer.Option(10.0, "--timeout", help=t("cmd.smoke_test.opt.timeout")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.bridge.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.bridge.opt.dcs_serve")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.bridge.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.bridge.opt.config")),
    wait: int = typer.Option(DEFAULT_WAIT_SECONDS, "--wait", min=0, help=t("cmd.bridge.opt.wait")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Assert VEAF runtime behaviour inside the running mission."""
    logger.set_verbose(verbose)
    console.print(t("cmd.smoke_test.title", version=VERSION))
    checks = _resolve_suite(suite)
    bridge = open_bridge(serve_url, dcs_serve, api_key, config, wait)
    try:
        result = run(checks, lambda code: bridge.run(code, timeout=timeout))
    finally:
        bridge.close()
    console.print(format_result(result))
    if result.exit_code:
        raise typer.Exit(code=result.exit_code)


#: What ``--suite`` accepts. `spotter` asserts on a geometry only `demo-spotter-network` carries, so
#: it is opt-in: run against any other mission it would be two permanent failures.
_SUITES = {"default": CHECKS, "spotter": SPOTTER_CHECKS}


def _resolve_suite(name: str) -> tuple:
    """Return the checks named by ``--suite``, or end the run naming the ones that exist.

    An unknown name is refused rather than silently falling back to the default: a typo that quietly
    runs the wrong suite reports a green that answers a question nobody asked.

    Args:
        name: The value of ``--suite``.

    Returns:
        The matching tuple of checks.

    Raises:
        typer.Exit: When *name* is not a known suite.
    """
    checks = _SUITES.get(name)
    if checks is None:
        console.print(f"[red]![/]  {t('cmd.smoke_test.unknown_suite', suite=name, known=', '.join(_SUITES))}")
        raise typer.Exit(code=2)
    return checks
