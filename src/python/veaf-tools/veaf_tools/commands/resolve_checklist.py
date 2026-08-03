from pathlib import Path

import typer

from veaf_tools.app import (
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(name="resolve-checklist", no_args_is_help=True, help=t("cmd.resolve_checklist.help"))
def resolve_checklist(
    checklist_file: str = typer.Argument(..., help=t("cmd.resolve_checklist.opt.file")),
    dry_run: bool = typer.Option(False, "--dry-run", help=t("cmd.resolve_checklist.opt.dry_run")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Fill in the technical fields of every step written in plain words.

    An instructor writes `control: main pwr sur batt`; this turns it into the element,
    the animation argument and the value that means "in position", writing them beside
    the text in the same file. It refuses rather than guesses, and refusing one step
    leaves the whole file untouched: a half-resolved checklist looks finished.
    """
    from veaf_libs.checklist_resolver import ResolverError, apply_resolutions, resolve_checklist_file

    logger.set_verbose(verbose)
    console.print(t("cmd.resolve_checklist.title", version=VERSION))

    path = Path(checklist_file)
    if not path.is_file():
        console.print(f"[red]✗[/]  {t('cmd.resolve_checklist.no_file', path=path)}")
        raise typer.Exit(code=1)

    try:
        outcomes = resolve_checklist_file(path)
    except ResolverError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error

    if not outcomes:
        console.print(t("cmd.resolve_checklist.nothing_to_do"))
        _maybe_pause(pause)
        return

    refused = 0
    for outcome in outcomes:
        resolution = outcome.resolution
        if resolution.fields:
            summary = ", ".join(f"{name}: {value}" for name, value in resolution.fields.items())
            console.print(f"[green]✓[/]  {t('cmd.resolve_checklist.step', number=outcome.number)} {summary}")
            if resolution.note:
                console.print(f"   [yellow]•[/] {resolution.note}")
        else:
            refused += 1
            console.print(f"[red]✗[/]  {t('cmd.resolve_checklist.step', number=outcome.number)} {resolution.refusal}")

    if refused:
        console.print(t("cmd.resolve_checklist.refused", count=refused))
        _maybe_pause(pause)
        raise typer.Exit(code=1)

    if dry_run:
        console.print(t("cmd.resolve_checklist.dry_run", count=len(outcomes)))
        _maybe_pause(pause)
        return

    written = apply_resolutions(path, outcomes)
    console.print(t("cmd.resolve_checklist.written", count=written, path=path))
    _maybe_pause(pause)


def _maybe_pause(pause: bool) -> None:
    """Wait for a keypress when the user asked to keep the window open."""
    if pause:
        input(t("help.pause_msg"))
