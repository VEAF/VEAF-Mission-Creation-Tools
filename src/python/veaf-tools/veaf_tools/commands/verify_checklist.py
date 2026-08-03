from pathlib import Path

import typer
import yaml
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, resolve_api_key  # type: ignore[import-not-found]

from veaf_tools.app import (
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(name="verify-checklist", no_args_is_help=True, help=t("cmd.verify_checklist.help"))
def verify_checklist(
    checklist_file: str = typer.Argument(..., help=t("cmd.verify_checklist.opt.file")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.verify_checklist.opt.serve_url")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.verify_checklist.opt.api_key")
    ),
    timeout: float = typer.Option(60.0, "--timeout", help=t("cmd.verify_checklist.opt.timeout")),
    write: bool = typer.Option(False, "--write", help=t("cmd.verify_checklist.opt.write")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Check a resolved checklist against a real cockpit, one control at a time.

    Each measurable step boxes its control in the pilot's aircraft and waits for them to
    move it; the animation argument is then read and compared with what the checklist
    claims. Nothing is ever thrown by the tool — boxing the control is all it does.

    Needs DCS running **on this machine**, with the bridge connected: the read goes
    through Export.lua's environment, which is local to the pilot.
    """
    from veaf_libs.checklist_verifier import VerificationError, make_lua_runner, verify_step
    from veaf_libs.checklists import ChecklistError, parse_checklist

    logger.set_verbose(verbose)
    console.print(t("cmd.verify_checklist.title", version=VERSION))

    path = Path(checklist_file)
    if not path.is_file():
        console.print(f"[red]✗[/]  {t('cmd.verify_checklist.no_file', path=path)}")
        raise typer.Exit(code=1)

    try:
        checklist = parse_checklist(yaml.safe_load(path.read_text(encoding="utf-8")) or {}, str(path))
    except ChecklistError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error

    measurable = [
        (number, step)
        for number, step in enumerate(checklist.steps, start=1)
        if step.argument is not None and step.equals is not None and step.element
    ]
    if not measurable:
        console.print(t("cmd.verify_checklist.nothing_to_verify"))
        _maybe_pause(pause)
        return

    run_lua = make_lua_runner(serve_url, resolve_api_key(api_key))
    console.print(t("cmd.verify_checklist.intro", count=len(measurable)))

    readings = []
    try:
        for number, step in measurable:
            console.print(t("cmd.verify_checklist.prompt", number=number, label=_plain(step.label)))
            reading = verify_step(
                run_lua,
                number=number,
                element=str(step.element),
                argument=int(step.argument or 0),
                expected=float(step.equals or 0.0),
                timeout=timeout,
            )
            readings.append(reading)
            if reading.timed_out:
                console.print(f"   [yellow]•[/] {t('cmd.verify_checklist.timed_out')}")
            elif reading.matches:
                console.print(f"   [green]✓[/] {t('cmd.verify_checklist.match', value=reading.measured)}")
            else:
                console.print(
                    f"   [red]✗[/] {t('cmd.verify_checklist.mismatch', expected=reading.expected, measured=reading.measured)}"
                )
    except VerificationError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error

    matched = [r for r in readings if r.matches]
    console.print(t("cmd.verify_checklist.summary", matched=len(matched), total=len(readings)))

    if write and matched:
        _mark_verified(path, [r.number for r in matched])
        console.print(t("cmd.verify_checklist.written", count=len(matched), path=path))

    _maybe_pause(pause)
    if any(not r.matches and not r.timed_out for r in readings):
        raise typer.Exit(code=1)


def _plain(label: object) -> str:
    """Render a step's label for the console, whichever form it was written in."""
    if isinstance(label, dict):
        return str(label.get("fr") or label.get("en") or next(iter(label.values()), ""))
    return str(label)


def _mark_verified(path: Path, numbers: list[int]) -> None:
    """Write `verified: true` on the steps a cockpit agreed with, keeping the file's shape."""
    from ruamel.yaml import YAML

    editor = YAML()
    editor.preserve_quotes = True
    editor.indent(mapping=2, sequence=4, offset=2)
    editor.width = 4096
    with path.open(encoding="utf-8") as handle:
        document = editor.load(handle)
    for number in numbers:
        document["steps"][number - 1]["verified"] = True
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        editor.dump(document, handle)


def _maybe_pause(pause: bool) -> None:
    """Wait for a keypress when the user asked to keep the window open."""
    if pause:
        input(t("help.pause_msg"))
