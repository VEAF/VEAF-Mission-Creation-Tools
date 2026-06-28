from pathlib import Path

import typer
from mission_builder import PIPELINE_CANDIDATES, ConversionReport, V5Converter, promote_mission_to_v6
from rich.table import Table
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
    tn,
)


@app.command(help=t("cmd.convert_v5.help.long"))
def convert_v5(
    mission_folder: str = typer.Argument(
        ".",
        help=t("cmd.convert_v5.opt.folder"),
    ),
    force: bool = typer.Option(
        False,
        "--force",
        help=t("cmd.convert_v5.opt.force"),
    ),
    no_backup: bool = typer.Option(
        False,
        "--no-backup",
        help=t("cmd.convert_v5.opt.no_backup"),
    ),
    no_convert_pipeline: bool = typer.Option(
        False,
        "--no-convert-pipeline",
        help=t("cmd.convert_v5.opt.no_pipeline"),
    ),
    no_promote: bool = typer.Option(
        False,
        "--no-promote",
        help=t("cmd.convert_v5.opt.no_promote"),
    ),
    report_file: str | None = typer.Option(
        None,
        "--report-file",
        help=t("cmd.convert_v5.opt.report_file"),
    ),
    icao: str = typer.Option(
        "",
        "--icao",
        help=t("cmd.convert_v5.opt.icao"),
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    logger.set_verbose(verbose)
    console.print(f"[bold green]{t('convert_v5.command.banner', version=VERSION)}[/bold green]")

    p_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_folder.is_dir():
        logger.error(t("convert_v5.command.folder_missing", path=p_folder), exception_type=FileNotFoundError)

    # If mission.yaml exists and --force was not given, ask interactively.
    mission_yaml = p_folder / "mission.yaml"
    overwrite_yaml = force
    if mission_yaml.exists() and not force:
        console.print(
            f"\n[yellow]{t('convert_v5.command.yaml_exists_notice')}[/yellow] {mission_yaml}\n"
            f"  {t('convert_v5.command.yaml_exists_help')}"
        )
        if typer.confirm(f"  {t('convert_v5.command.yaml_exists_confirm')}", default=False):
            overwrite_yaml = True

    # Run the converter
    converter = V5Converter(version=VERSION)

    # Build ICAO callback for realweather steps.
    # No interactive prompt — use --icao on the command line, or edit the generated file manually.
    _icao_value = icao.strip().upper()

    def icao_cb(version_name: str) -> str:
        if not _icao_value:
            console.print(
                f"\n[yellow]{t('convert_v5.command.realweather_notice', name=version_name)}[/yellow]\n"
                f"  {t('convert_v5.command.realweather_empty_icao')}\n"
                f"  {t('convert_v5.command.realweather_hint')}"
            )
        return _icao_value

    report: ConversionReport = converter.convert(
        mission_folder=p_folder,
        overwrite_mission_yaml=overwrite_yaml,
        backup=not no_backup,
        convert_pipeline=not no_convert_pipeline,
        icao_callback=icao_cb if not no_convert_pipeline else None,
    )

    # ── Console output ────────────────────────────────────────────────────────
    console.print(f"\n[bold cyan]{t('convert_v5.command.folder_label')}[/bold cyan] {p_folder}")
    console.print("")

    # Scan summary table
    scan_table = Table(title=t("convert_v5.scan.title"), show_header=True)
    scan_table.add_column(t("convert_v5.scan.col.item"), style="cyan")
    scan_table.add_column(t("convert_v5.scan.col.status"))

    if report.missionconfig_path:
        rel = report.missionconfig_path.relative_to(p_folder)
        scan_table.add_row(str(rel), f"[green]{t('convert_v5.scan.missionconfig.found')}[/green]")
    else:
        scan_table.add_row(
            "src/scripts/missionConfig.lua", f"[yellow]{t('convert_v5.scan.missionconfig.not_found')}[/yellow]"
        )

    if report.mission_yaml_existed and not report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", f"[yellow]{t('convert_v5.scan.yaml.existed')}[/yellow]")
    elif report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", f"[green]{t('convert_v5.scan.yaml.generated')}[/green]")
    else:
        scan_table.add_row("mission.yaml", f"[red]{t('convert_v5.scan.yaml.not_generated')}[/red]")

    for step, v6_candidates in PIPELINE_CANDIDATES.items():
        if any(pf.step == step for pf in report.pipeline_files):
            pf = next(pf for pf in report.pipeline_files if pf.step == step)
            if pf.converted:
                scan_table.add_row(
                    pf.v5_source or pf.v6_target,
                    f"[green]{t('convert_v5.scan.pipeline.converted', target=pf.v6_target)}[/green]",
                )
            elif pf.needs_conversion:
                scan_table.add_row(
                    pf.relative,
                    f"[yellow]{t('convert_v5.scan.pipeline.v5_format', target=pf.v6_target)}[/yellow]",
                )
            else:
                scan_table.add_row(pf.relative, f"[green]{t('convert_v5.scan.pipeline.found', step=step)}[/green]")
        else:
            scan_table.add_row(v6_candidates[0], f"[dim]{t('convert_v5.scan.pipeline.not_found', step=step)}[/dim]")

    console.print(scan_table)
    console.print("")

    # Actions
    if report.actions:
        console.print(f"[bold cyan]{t('convert_v5.console.actions_taken')}[/bold cyan]")
        for action in report.actions:
            console.print(f"  [green]✓[/green] {action}")
        console.print("")

    # missionConfig detail
    if report.migration_result:
        mr = report.migration_result
        # The doFile / bare-initialize() edits apply to the migrated buffer convert-v5
        # never writes (the original missionConfig.lua is deleted and replaced by the
        # generated mission-script.lua), so they are not echoed here. Only the detected
        # modules, which drive mission.yaml, are shown (CONVERT-V5-INIT-COMMENTED-NOISE).
        if mr.enabled_modules:
            console.print(
                f"[bold cyan]{t('convert_v5.console.enabled_modules', n=len(mr.enabled_modules))}[/bold cyan] "
                + ", ".join(mr.enabled_modules)
            )
            console.print("")

    # Warnings
    if report.warnings:
        console.print(f"[bold yellow]{t('convert_v5.console.warnings', n=len(report.warnings))}[/bold yellow]")
        for w in report.warnings:
            console.print(f"  [yellow]•[/yellow] {w}")
        console.print("")

    # Manual review
    if report.manual_review:
        console.print(f"[bold yellow]{t('convert_v5.console.manual_review')}[/bold yellow]")
        for item in report.manual_review:
            console.print(f"  [yellow]→[/yellow] {item}")
        console.print("")

    # Legacy v5 files triaged (CONVERT-V5-CLEANUP-FILES)
    if report.secret_tooling_files:
        secret = ", ".join(report.secret_tooling_files)
        console.print(f"  [yellow]⚠[/yellow] {t('report.legacy_files.secret', files=secret)}")
        console.print("")
    if report.unrecognized_files:
        console.print(
            f"[bold cyan]{t('report.legacy_files.unrecognized', n=len(report.unrecognized_files))}[/bold cyan]"
        )
        for item in report.unrecognized_files:
            console.print(f"  [dim]•[/dim] {item}")
        console.print("")

    # Next steps
    converted_files = [pf for pf in report.pipeline_files if pf.converted]
    needs_conversion = [pf for pf in report.pipeline_files if pf.needs_conversion]
    console.print(f"[bold cyan]{t('convert_v5.console.next_steps')}[/bold cyan]")
    step_num = 1
    console.print(f"  {step_num}. {t('convert_v5.console.next_steps.review_yaml')}")
    step_num += 1
    if converted_files:
        console.print(f"  {step_num}. {tn('convert_v5.console.next_steps.review_converted', len(converted_files))}")
        step_num += 1
    if needs_conversion:
        console.print(f"  {step_num}. {tn('convert_v5.console.next_steps.convert_manual', len(needs_conversion))}")
        step_num += 1
    console.print(f"  {step_num}. {t('convert_v5.console.next_steps.build')}")
    step_num += 1
    console.print(f"  {step_num}. {t('convert_v5.console.next_steps.test')}")
    step_num += 1
    if report.manual_review:
        console.print(f"  {step_num}. {t('convert_v5.console.next_steps.cleanup')}")
    console.print("")

    # ── Promote src/mission/ to v6 on disk (default on; --no-promote to skip) ──
    # Runs after the conversion summary so the output reads conversion → promotion.
    # The internal base build + extract is silent; non-blocking — a failure leaves
    # the converted configs intact and is surfaced here and in the saved report.
    if not no_promote:
        report.promotion_attempted = True
        console.print(f"[bold cyan]{t('convert_v5.promote.start')}[/bold cyan]")
        promotion = promote_mission_to_v6(p_folder, version=VERSION, silent=True)
        if promotion.promoted:
            backup_rel = (
                promotion.backup_path.relative_to(p_folder)
                if promotion.backup_path
                else Path("backup_v5") / "src" / "mission"
            )
            report.promotion_done = True
            report.promotion_backup = str(backup_rel).replace("\\", "/")
            console.print(f"  [green]✓[/green] {t('convert_v5.promote.done', backup=report.promotion_backup)}")
        else:
            report.promotion_reason = promotion.reason
            console.print(f"  [yellow]⚠[/yellow] {promotion.reason}")
        console.print("")

    # ── Save report file ──────────────────────────────────────────────────────
    if report_file is not None:
        p_report = resolve_path(path=report_file)
    else:
        backup_v5 = p_folder / "backup_v5"
        backup_v5.mkdir(parents=True, exist_ok=True)
        p_report = backup_v5 / "convert-v5-report.md"

    markdown_report = report.to_markdown()
    p_report.write_text(markdown_report, encoding="utf-8")
    console.print(f"[bold green]{t('convert_v5.command.report_saved', path=p_report)}[/bold green]")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
