"""Run the in-DCS smoke checks against a running DCS.

Machine-only: it needs a DCS install, so it never runs in CI (GitHub runners have no DCS, licence or
GPU). It skips with an explanation rather than failing when there is nothing to talk to, because that
is the normal state of most machines and a tool that cries wolf there stops being run.
"""

import typer
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL
from veaf_libs.dcs_fiddle_client import DEFAULT_FIDDLE_URL, probe
from veaf_libs.dcs_smoke import format_result, run

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(name="smoke-test", help=t("cmd.smoke_test.help"))
def smoke_test(
    url: str = typer.Option(DEFAULT_FIDDLE_URL, "--url", help=t("cmd.smoke_test.opt.url")),
    timeout: float = typer.Option(10.0, "--timeout", help=t("cmd.smoke_test.opt.timeout")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.smoke_test.opt.serve_url")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.smoke_test.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.smoke_test.opt.config")),
    probe_only: bool = typer.Option(False, "--probe-only", help=t("cmd.smoke_test.opt.probe_only")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Probe a running DCS and assert VEAF runtime behaviour inside it."""
    logger.set_verbose(verbose)
    console.print(t("cmd.smoke_test.title", version=VERSION))

    if probe_only:
        caps = probe(url=url, timeout=timeout)
        for note in caps.notes:
            console.print(f"  - {note}")
        blocker = caps.blocking_reason()
        if blocker:
            # Named explicitly, and after the raw notes rather than instead of them: the notes are the
            # measurement, this line is the reading of it, and the reading is what people act on.
            console.print(f"\n[yellow]![/]  {blocker}")
        elif caps.can_drive_lifecycle:
            console.print(f"\n[green]✓[/]  {t('cmd.smoke_test.lifecycle_available')}")
        if not caps.hook_alive:
            raise typer.Exit(code=0)  # nothing running is not a failure
        return

    result = run(url=url, timeout=timeout, serve_url=serve_url, api_key=api_key, config=config)
    console.print(format_result(result))
    if result.exit_code:
        raise typer.Exit(code=result.exit_code)
