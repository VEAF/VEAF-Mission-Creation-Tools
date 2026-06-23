from pathlib import Path

import typer
from mission_tools import read_miz
from mission_tools.mission_exporter import export_mission
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
    DEFAULT_MISSION_FILE,
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)

#: Supported export formats.
_FORMATS = ("json", "yaml", "markdown")


@app.command(no_args_is_help=True, help=t("cmd.export.help"))
def export(
    mission_name_or_file: str = typer.Argument(DEFAULT_MISSION_FILE, help=t("cmd.export.opt.mission")),
    output: str | None = typer.Argument(None, help=t("cmd.export.opt.output")),
    format: str = typer.Option("json", "--format", "-f", help=t("cmd.export.opt.format")),
    compact: bool = typer.Option(False, "--compact", help=t("cmd.export.opt.compact")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Read a `.miz` with the pure-Python parser (no Lua execution) and export it.

    Args:
        mission_name_or_file: The `.miz` file to export.
        output: Optional output file; when omitted, the result is written to stdout.
        format: ``json`` (default), ``yaml`` or ``markdown``.
        compact: For JSON, emit without indentation.
        verbose: Verbose logging.
        pause: Pause when finished.
    """
    logger.set_verbose(verbose)
    console.print(t("cmd.export.title", version=VERSION))

    fmt = format.lower()
    if fmt not in _FORMATS:
        logger.error(t("cmd.export.bad_format", format=format, allowed=", ".join(_FORMATS)), exception_type=ValueError)

    p_input = resolve_path(path=mission_name_or_file, should_exist=True)
    if not p_input.is_file():
        logger.error(t("cmd.export.mission_not_found", path=p_input), exception_type=FileNotFoundError)

    # read_miz parses with luadata only — it never executes Lua.
    mission = read_miz(p_input)
    rendered = export_mission(mission, fmt, compact=compact)

    if output:
        out_path = Path(resolve_path(path=output))
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(rendered, encoding="utf-8")
        console.print(t("cmd.export.written", path=out_path, format=fmt))
    else:
        typer.echo(rendered)

    if pause:
        input(t("help.pause_msg"))
