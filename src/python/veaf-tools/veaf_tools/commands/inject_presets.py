from pathlib import Path

import typer
from presets_injector import PresetsInjectorREADME, PresetsInjectorWorker
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
    DEFAULT_MISSION_FILE,
    DEFAULT_PRESETS_FILE,
    PAUSE_HELP,
    README_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(no_args_is_help=True, help=t("cmd.inject_presets.help"))
def inject_presets(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    input_mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.inject_presets.opt.mission"),
    ),
    output_mission: str | None = typer.Argument(None, help=t("cmd.inject_presets.opt.output_mission")),
    presets_file: str = typer.Option(DEFAULT_PRESETS_FILE, help=t("cmd.inject_presets.opt.presets_file")),
    validate_report: str | None = typer.Option(None, help=t("cmd.inject_presets.opt.validate_report")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.inject_presets.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(PresetsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()

    # Resolve input mission
    assert input_mission_name_or_file is not None
    p_input_mission: str | Path | None = input_mission_name_or_file
    if not input_mission_name_or_file.lower().endswith(".miz"):
        if files := list(Path.cwd().glob(f"{input_mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(path=presets_file, should_exist=True)
    if not p_presets_file.exists():
        logger.error(t("cmd.inject_presets.config_not_found", path=p_presets_file), exception_type=FileNotFoundError)

    # Call the worker class
    worker = PresetsInjectorWorker(
        presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    if validate_report is not None:
        report_path = resolve_path(path=validate_report, default_path=Path("presets-validation-report.md"))
        worker.generate_validation_report(report_path)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
