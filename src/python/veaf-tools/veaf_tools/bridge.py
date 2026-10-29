"""Open the VEAF bridge for a command that talks to the mission running in DCS, saying what it does.

The steps live in :mod:`veaf_libs.dcs_bridge_session`; this is the part a person reads — which
``dcs-serve`` is used, that the command is waiting for the mission, and what to do when it fails.
"""

import typer
from veaf_libs.dcs_bridge_session import BridgeSession, open_session, wait_for_mission

from veaf_tools.app import console, t


def open_bridge(
    serve_url: str, dcs_serve: str | None, api_key: str | None, config: str | None, wait: int
) -> BridgeSession:
    """Make sure a ``dcs-serve`` runs, wait for the mission's bridge, and return the session.

    The caller closes the session (``finally: session.close()``), which stops a server started here.

    Args:
        serve_url: Where ``dcs-serve`` is expected.
        dcs_serve: The executable to start when none runs, if the user named it.
        api_key: The key of a server the user started, if any.
        config: A ``dcs-serve.yaml`` to read that key from, if any.
        wait: Seconds to wait for the mission's bridge.

    Returns:
        The open session.

    Raises:
        typer.Exit: Code 1, the reason printed, when no server can be had or the mission never answers.
    """
    try:
        session = open_session(serve_url, dcs_serve=dcs_serve, api_key=api_key, config=config)
    except RuntimeError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    if session.started is not None:
        console.print(t("bridge.serve_started", exe=str(session.started.exe), config=str(session.config_path)))
    else:
        console.print(t("bridge.serve_running", url=serve_url))
    try:
        with console.status(t("bridge.waiting", seconds=wait)):
            wait_for_mission(session, wait)
    except RuntimeError as error:
        session.close()
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    except BaseException:
        # Ctrl+C while waiting: the session is not handed back yet, so nobody else would stop the
        # dcs-serve started for it — and off Windows it runs in a process group of its own.
        session.close()
        raise
    console.print(t("bridge.connected"))
    return session
