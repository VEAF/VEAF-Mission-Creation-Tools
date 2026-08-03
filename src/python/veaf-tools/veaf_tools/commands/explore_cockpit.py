import time

import typer
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, resolve_api_key  # type: ignore[import-not-found]

from veaf_tools.app import (
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)

#: Gap between cockpit reads. A whole cockpit is one round trip, so this can be brisk
#: without flooding the bridge.
_POLL_INTERVAL = 0.5


@app.command(name="explore-cockpit", no_args_is_help=True, help=t("cmd.explore_cockpit.help"))
def explore_cockpit(
    aircraft: str = typer.Argument(..., help=t("cmd.explore_cockpit.opt.aircraft")),
    control: str | None = typer.Option(None, "--control", help=t("cmd.explore_cockpit.opt.control")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.explore_cockpit.opt.serve_url")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.explore_cockpit.opt.api_key")
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Name a control to see it boxed, or move one in the cockpit to have it named.

    Runs until you stop it with Ctrl-C. Each control you move is reported with its
    element, its animation argument and the value it just reached — measured, not
    inferred — ready to paste into a checklist step.

    Needs DCS running **on this machine**, with the bridge connected.
    """
    from veaf_libs.checklist_resolver import ResolverError, load_control_index, resolve_control
    from veaf_libs.checklist_verifier import VerificationError, highlight, make_lua_runner, say
    from veaf_libs.cockpit_explorer import arguments_of, identify, read_many

    logger.set_verbose(verbose)
    console.print(t("cmd.explore_cockpit.title", version=VERSION))

    try:
        index = load_control_index(aircraft)
    except ResolverError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error

    run_lua = make_lua_runner(serve_url, resolve_api_key(api_key))

    if control:
        resolution = resolve_control(control, index)
        if not resolution.candidates:
            console.print(f"[red]✗[/]  {resolution.refusal}")
            raise typer.Exit(code=1)
        best = resolution.candidates[0]
        entry = index["controls"][best.element]
        highlight(run_lua, best.element)
        console.print(t("cmd.explore_cockpit.boxed", element=best.element, hint=best.hint))
        console.print(f"    argument: {entry.get('argument')}")
        for name, value in (entry.get("values") or {}).items():
            console.print(f"    {name}: {value}")

    arguments = arguments_of(index)
    console.print(t("cmd.explore_cockpit.watching", count=len(arguments), aircraft=aircraft))

    try:
        previous = read_many(run_lua, arguments)
        while True:
            time.sleep(_POLL_INTERVAL)
            current = read_many(run_lua, arguments)
            for change in identify(previous, current, index):
                position = change.position or t("cmd.explore_cockpit.unnamed_position")
                console.print(
                    t(
                        "cmd.explore_cockpit.moved",
                        element=change.element,
                        hint=change.hint or "?",
                        position=position,
                        value=change.value,
                    )
                )
                console.print(f"[dim]{change.as_step()}[/dim]")
                # In game too: the person moving the switches is at full screen in a
                # cockpit and cannot see this console at all.
                say(
                    run_lua,
                    t(
                        "cmd.explore_cockpit.in_game",
                        hint=change.hint or change.element,
                        argument=change.argument,
                        value=change.value,
                    ),
                    seconds=12,
                )
            previous = current
    except KeyboardInterrupt:
        # Leaving on Ctrl-C is the documented way out; a traceback would be noise.
        console.print(f"\n{t('cmd.explore_cockpit.stopped')}")
    except VerificationError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    finally:
        _clear_box(run_lua)


def _clear_box(run_lua: object) -> None:
    """Take the box out of the pilot's cockpit, whatever ended the loop."""
    from veaf_libs.checklist_verifier import VerificationError, highlight

    try:
        highlight(run_lua, None)  # type: ignore[arg-type]
    except (VerificationError, OSError):
        # DCS may already be gone; leaving a box behind is not worth a second error.
        pass
