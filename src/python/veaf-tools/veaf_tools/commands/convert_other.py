from pathlib import Path

import typer
from mission_builder import ConversionReport, OtherMissionConverter
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(no_args_is_help=True, help=t("cmd.convert_other.help.long"))
def convert_other(
    input_miz: str = typer.Argument(
        "mission.miz",
        help=t("cmd.convert_other.opt.input_miz"),
    ),
    output_folder: str = typer.Argument(
        ".",
        help=t("cmd.convert_other.opt.output_folder"),
    ),
    force: bool = typer.Option(
        False,
        "--force",
        help=t("cmd.convert_other.opt.force"),
    ),
    report_file: str | None = typer.Option(
        None,
        "--report-file",
        help=t("cmd.convert_other.opt.report_file"),
    ),
    profile: str | None = typer.Option(
        None,
        "--profile",
        help=t("cmd.convert_other.opt.profile"),
    ),
    update: bool = typer.Option(
        False,
        "--update",
        help=t("cmd.convert_other.opt.update"),
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    logger.set_verbose(verbose)
    console.print(f"[bold green]{t('convert_other.command.banner', version=VERSION)}[/bold green]")

    p_input = resolve_path(path=input_miz, default_path=Path.cwd())
    if not p_input.is_file():
        logger.error(t("convert_other.command.miz_missing", path=p_input), exception_type=FileNotFoundError)

    p_output = resolve_path(path=output_folder, default_path=Path.cwd())

    converter = OtherMissionConverter(version=VERSION)
    report: ConversionReport = converter.convert(
        input_mission_path=p_input,
        output_mission_folder=p_output,
        force=force,
        profile_name=profile,
        update=update,
    )

    # ── Console output ────────────────────────────────────────────────────────
    console.print(f"\n[bold cyan]{t('convert_v5.command.folder_label')}[/bold cyan] {p_output}\n")

    if report.actions:
        console.print(f"[bold cyan]{t('convert_v5.console.actions_taken')}[/bold cyan]")
        for action in report.actions:
            console.print(f"  [green]✓[/green] {action}")
        console.print("")

    if report.manual_review:
        console.print(f"[bold yellow]{t('convert_v5.console.manual_review')}[/bold yellow]")
        for item in report.manual_review:
            console.print(f"  [yellow]→[/yellow] {item}")
        console.print("")

    # ── Save report file ──────────────────────────────────────────────────────
    p_report = resolve_path(path=report_file) if report_file is not None else p_output / "convert-other-report.md"
    p_report.write_text(report.to_markdown(), encoding="utf-8")
    console.print(f"[bold green]{t('convert_other.command.done', report=p_report)}[/bold green]")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
