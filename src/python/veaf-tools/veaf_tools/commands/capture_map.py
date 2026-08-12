"""Maker-facing commands to collect a theatre's airbase data over the dcs-bridge.

Two steps, so a non-developer can produce a `<theatre>.json` dump without any source
checkout, Python or Poetry — just the shipped `veaf-tools` executable, `dcs-serve.exe`
and a bridge mission:

- ``veaf-tools inject-bridge <mission.miz>`` — embed the bridge into a mission.
- ``veaf-tools capture-map --api-key <token>`` — with that mission running and
  ``dcs-serve`` up, write ``<theatre>.json`` (``{id, name, lat, lon, coalition}`` per airbase).
- ``veaf-tools capture-map --parking`` — additionally write ``parking/<theatre>.json``, every
  airfield's parking slots as the runtime reports them. Needed to place an aircraft *on a stand*
  rather than at coordinates: a parked unit carries two distinct numbers (``parking`` and
  ``parking_id``, measured at 28 and 24 on the same aircraft), and neither can be invented.
"""

from pathlib import Path

import typer
from veaf_libs.dcs_bridge_capture import (
    DEFAULT_SERVE_URL,
    capture_airbases,
    capture_parking,
    inject_bridge,
    resolve_api_key,
    resolve_bridge_lua,
    write_airbase_dump,
    write_parking_dump,
)

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(name="capture-map", help=t("cmd.capture_map.help"))
def capture_map(
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.capture_map.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.capture_map.opt.config")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.capture_map.opt.serve_url")),
    out_dir: str = typer.Option(".", "--out-dir", help=t("cmd.capture_map.opt.out_dir")),
    parking: bool = typer.Option(False, "--parking", help=t("cmd.capture_map.opt.parking")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Capture airbases from the running mission and write ``<theatre>.json``."""
    logger.set_verbose(verbose)
    console.print(t("cmd.capture_map.title", version=VERSION))
    console.print(t("cmd.capture_map.capturing", url=serve_url))
    try:
        key = resolve_api_key(api_key, config)
        theatre, airbases = capture_airbases(serve_url, key)
        out = write_airbase_dump(theatre, airbases, Path(out_dir))
    except (RuntimeError, OSError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    console.print(t("cmd.capture_map.done", theatre=theatre, count=len(airbases), path=str(out)))

    if not parking:
        return
    # Written to its own file, and after the airbases: a theatre with hundreds of airfields holds
    # thousands of slots, and a maker who got the airbase dump has already got something useful even
    # if this second, slower call times out.
    console.print(t("cmd.capture_map.capturing_parking"))
    try:
        parking_theatre, slots = capture_parking(serve_url, key)
        parking_out = write_parking_dump(parking_theatre, slots, Path(out_dir) / "parking")
    except (RuntimeError, OSError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    console.print(
        t(
            "cmd.capture_map.done_parking",
            airbases=len(slots),
            count=sum(len(entries) for entries in slots.values()),
            path=str(parking_out),
        )
    )


@app.command(name="inject-bridge", no_args_is_help=True, help=t("cmd.inject_bridge.help"))
def inject_bridge_command(
    mission: str = typer.Argument(..., help=t("cmd.inject_bridge.opt.mission")),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.inject_bridge.opt.bridge_lua")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Embed ``dcs-bridge.lua`` and a mission-start load trigger into *mission*."""
    logger.set_verbose(verbose)
    console.print(t("cmd.inject_bridge.title", version=VERSION))
    try:
        lua = resolve_bridge_lua(bridge_lua)
        res = inject_bridge(Path(mission), lua)
    except (RuntimeError, OSError, ValueError) as e:
        console.print(f"[red]{e}[/red]")
        raise typer.Exit(code=1) from e
    console.print(t("cmd.inject_bridge.done", mission=mission, index=res["trigger_index"]))
