from pathlib import Path

import typer
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


@app.command(help=t("cmd.validate.help"))
def validate(
    mission_folder: str | None = typer.Argument(".", help=t("cmd.validate.opt.mission_folder")),
    strict: bool = typer.Option(False, "--strict", help=t("cmd.validate.opt.strict")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Lint a mission folder before build: report config/runtime issues, exit non-zero on error."""
    from veaf_libs.mission_validator import ERROR, WARNING, validate_mission_folder

    logger.set_verbose(verbose)
    console.print(t("cmd.validate.title", version=VERSION))

    p_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=False)
    if not Path(p_folder).is_dir():
        console.print(f"[red]✗[/]  {t('builder.folder_not_found', path=p_folder)}")
        raise typer.Exit(code=1)

    issues = validate_mission_folder(Path(p_folder))
    errors = [i for i in issues if i.level == ERROR]
    warnings = [i for i in issues if i.level == WARNING]

    for issue in warnings:
        console.print(f"[yellow]⚠[/]  {issue.message}")
    for issue in errors:
        console.print(f"[red]✗[/]  {issue.message}")

    if not issues:
        console.print(t("cmd.validate.ok"))
    else:
        console.print(
            t(
                "cmd.validate.summary",
                errors=tn("cmd.validate.errors_frag", len(errors)),
                warnings=tn("cmd.validate.warnings_frag", len(warnings)),
            )
        )

    if pause:
        input(t("help.pause_msg"))

    if errors or (strict and warnings):
        raise typer.Exit(code=1)
