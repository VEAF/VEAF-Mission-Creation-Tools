from pathlib import Path

import typer
from mission_builder import PIPELINE_CANDIDATES, ConversionReport, V5Converter
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
)


@app.command(no_args_is_help=True, help=t("cmd.convert_v5.help.long"))
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
    console.print(f"[bold green]veaf-tools Convert v5 Mission v{VERSION}[/bold green]")

    p_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_folder.is_dir():
        logger.error(f"Mission folder does not exist: {p_folder}", exception_type=FileNotFoundError)

    # If mission.yaml exists and --force was not given, ask interactively.
    mission_yaml = p_folder / "mission.yaml"
    overwrite_yaml = force
    if mission_yaml.exists() and not force:
        console.print(
            f"\n[yellow]mission.yaml already exists:[/yellow] {mission_yaml}\n"
            "  Use [bold]--force[/bold] to overwrite, or continue to skip generation."
        )
        if typer.confirm("  Overwrite existing mission.yaml?", default=False):
            overwrite_yaml = True

    # Run the converter
    converter = V5Converter(version=VERSION)

    # Build ICAO callback for realweather steps.
    # No interactive prompt — use --icao on the command line, or edit the generated file manually.
    _icao_value = icao.strip().upper()

    def icao_cb(version_name: str) -> str:
        if not _icao_value:
            console.print(
                f"\n[yellow]Weather version '[bold]{version_name}[/bold]' uses realweather.[/yellow]\n"
                "  ICAO left empty in generated config.\n"
                "  Pass [bold]--icao UGGG[/bold] (replace with your airport code) to set it automatically."
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
    console.print(f"\n[bold cyan]Mission folder:[/bold cyan] {p_folder}")
    console.print("")

    # Scan summary table
    scan_table = Table(title="Scan Results", show_header=True)
    scan_table.add_column("Item", style="cyan")
    scan_table.add_column("Status")

    if report.missionconfig_path:
        rel = report.missionconfig_path.relative_to(p_folder)
        scan_table.add_row(str(rel), "[green]✓ Found — migrated[/green]")
    else:
        scan_table.add_row("src/scripts/missionConfig.lua", "[yellow]✗ Not found — skipped[/yellow]")

    if report.mission_yaml_existed and not report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", "[yellow]⚠ Already exists — not overwritten[/yellow]")
    elif report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", "[green]✓ Generated[/green]")
    else:
        scan_table.add_row("mission.yaml", "[red]✗ Not generated[/red]")

    for step, v6_candidates in PIPELINE_CANDIDATES.items():
        if any(pf.step == step for pf in report.pipeline_files):
            pf = next(pf for pf in report.pipeline_files if pf.step == step)
            if pf.converted:
                scan_table.add_row(
                    pf.v5_source or pf.v6_target,
                    f"[green]✓ Converted → {pf.v6_target}[/green]",
                )
            elif pf.needs_conversion:
                scan_table.add_row(
                    pf.relative,
                    f"[yellow]⚠ v5 format — needs conversion to {pf.v6_target}[/yellow]",
                )
            else:
                scan_table.add_row(pf.relative, f"[green]✓ Found — added to pipeline:[/green] {step}")
        else:
            scan_table.add_row(v6_candidates[0], f"[dim]✗ Not found — {step} step will be skipped[/dim]")

    console.print(scan_table)
    console.print("")

    # Actions
    if report.actions:
        console.print("[bold cyan]Actions taken:[/bold cyan]")
        for action in report.actions:
            console.print(f"  [green]✓[/green] {action}")
        console.print("")

    # missionConfig detail
    if report.migration_result:
        mr = report.migration_result
        if mr.removed_dofiles:
            console.print(f"[yellow]Commented out {len(mr.removed_dofiles)} doFile() call(s):[/yellow]")
            for item in mr.removed_dofiles:
                console.print(f"  • {item}")
            console.print("")
        if mr.wrapped_calls:
            console.print(f"[yellow]Wrapped {len(mr.wrapped_calls)} bare initialize() call(s):[/yellow]")
            for item in mr.wrapped_calls:
                console.print(f"  • {item}")
            console.print("")
        if mr.enabled_modules:
            console.print(
                f"[bold cyan]Enabled modules ({len(mr.enabled_modules)}):[/bold cyan] " + ", ".join(mr.enabled_modules)
            )
            console.print("")

    # Warnings
    if report.warnings:
        console.print(f"[bold yellow]⚠  Warnings ({len(report.warnings)}):[/bold yellow]")
        for w in report.warnings:
            console.print(f"  [yellow]•[/yellow] {w}")
        console.print("")

    # Manual review
    if report.manual_review:
        console.print("[bold yellow]Manual review required:[/bold yellow]")
        for item in report.manual_review:
            console.print(f"  [yellow]→[/yellow] {item}")
        console.print("")

    # Next steps
    converted_files = [pf for pf in report.pipeline_files if pf.converted]
    needs_conversion = [pf for pf in report.pipeline_files if pf.needs_conversion]
    console.print("[bold cyan]Next steps:[/bold cyan]")
    step_num = 1
    console.print(f"  {step_num}. Review [cyan]mission.yaml[/cyan] and adjust module settings as needed.")
    step_num += 1
    if converted_files:
        console.print(
            f"  {step_num}. Review the {len(converted_files)} converted config file(s) in your mission folder."
        )
        step_num += 1
    if needs_conversion:
        console.print(
            f"  {step_num}. Manually convert the {len(needs_conversion)} v5 config file(s) listed above "
            "(or re-run without [bold]--no-convert-pipeline[/bold])."
        )
        step_num += 1
    console.print(f"  {step_num}. Run [cyan]veaf-tools build[/cyan] — DCS trigger conversion runs automatically.")
    step_num += 1
    console.print(f"  {step_num}. Test the mission in DCS.")
    step_num += 1
    if report.manual_review:
        console.print(f"  {step_num}. Clean up the items listed above once everything works.")
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
    console.print(f"[bold green]Conversion report saved:[/bold green] {p_report}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
