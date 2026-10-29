"""Reconnaissance photos of a mission's objectives, taken in a running DCS.

Four steps, four commands, because a person sits between each: ``recon-prepare`` writes the shooting
copy of the mission, which the mission maker launches in DCS; ``recon-plan`` lists what is on the map
into a shots file they edit (the engagement heading is theirs to give); ``recon-shoot`` moves the F11
camera and grabs the window; ``recon-render`` makes the photos. Nothing here launches DCS or touches
a session the user did not start.

``recon-plan`` and ``recon-shoot`` talk to the mission through the VEAF bridge that ``recon-prepare``
embeds in the shooting copy (REFACTOR-BRIDGE-ONLY): ``dcs-serve`` is started when none runs.
"""

import json
import time
from pathlib import Path
from typing import Any

import typer
import yaml
from veaf_libs.coordinates import is_theatre_supported, to_dms, xy_to_latlon
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL, resolve_bridge_lua
from veaf_libs.dcs_bridge_session import DEFAULT_WAIT_SECONDS
from veaf_libs.dcs_recon import (
    COALITIONS,
    ENV_EXPORT,
    INFO_BAR_PX,
    UNITS_LUA,
    briefing_sidecar,
    derive_recon_mission,
    load_plan,
    parse_units,
    plan_from_units,
    recon_mission_path,
    shoot_plan,
)

from veaf_tools.app import VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.bridge import open_bridge


def _latlon(theatre: str, x: float, z: float) -> tuple[float, float] | None:
    """Latitude and longitude of a DCS point, or ``None`` on a theatre without a conversion."""
    return xy_to_latlon(theatre, x, z) if is_theatre_supported(theatre) else None


@app.command(name="recon-prepare", no_args_is_help=True, help=t("cmd.recon_prepare.help"))
def recon_prepare(
    mission: Path = typer.Argument(..., exists=True, dir_okay=False, help=t("cmd.recon_prepare.opt.mission")),
    time_of_day: str = typer.Option("11:30", "--time", help=t("cmd.recon_prepare.opt.time")),
    out: Path | None = typer.Option(None, "--out", help=t("cmd.recon_prepare.opt.out")),
    bridge_lua: str | None = typer.Option(None, "--bridge-lua", help=t("cmd.bridge.opt.bridge_lua")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Write the shooting copy of a built mission, the bridge embedded."""
    logger.set_verbose(verbose)
    console.print(t("cmd.recon_prepare.title", version=VERSION))
    target = out or recon_mission_path(mission)
    try:
        changes = derive_recon_mission(mission, target, time_of_day, resolve_bridge_lua(bridge_lua))
    except ValueError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=2) from error
    except (RuntimeError, OSError) as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    console.print(t("cmd.recon_prepare.written", path=target))
    for change in changes:
        console.print(f"  - {change}")
    console.print(t("cmd.recon_prepare.next", path=target.name))


@app.command(name="recon-plan", help=t("cmd.recon_plan.help"))
def recon_plan(
    out: Path = typer.Option(Path("shots.yaml"), "--out", help=t("cmd.recon_plan.opt.out")),
    coalition: str = typer.Option("red", "--coalition", help=t("cmd.recon_plan.opt.coalition")),
    operation: str = typer.Option("", "--operation", help=t("cmd.recon_plan.opt.operation")),
    force: bool = typer.Option(False, "--force", help=t("cmd.recon_plan.opt.force")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.bridge.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.bridge.opt.dcs_serve")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.bridge.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.bridge.opt.config")),
    wait: int = typer.Option(DEFAULT_WAIT_SECONDS, "--wait", min=0, help=t("cmd.bridge.opt.wait")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """List what is on the map into a shots file to edit."""
    logger.set_verbose(verbose)
    console.print(t("cmd.recon_plan.title", version=VERSION))
    if coalition not in COALITIONS:
        console.print(f"[red]✗[/]  {t('cmd.recon_plan.bad_coalition', coalition=coalition)}")
        raise typer.Exit(code=2)
    if out.exists() and not force:
        console.print(f"[red]✗[/]  {t('cmd.recon_plan.exists', path=out)}")
        raise typer.Exit(code=2)
    bridge = open_bridge(serve_url, dcs_serve, api_key, config, wait)
    try:
        units = parse_units(bridge.run(UNITS_LUA))
    except RuntimeError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    finally:
        bridge.close()
    plan = plan_from_units(units, COALITIONS[coalition], operation)
    out.write_text(yaml.safe_dump(plan, allow_unicode=True, sort_keys=False), encoding="utf-8")
    console.print(t("cmd.recon_plan.written", path=out, count=len(plan["shots"])))
    console.print(t("cmd.recon_plan.next"))


@app.command(name="recon-shoot", help=t("cmd.recon_shoot.help"))
def recon_shoot(
    shots: Path = typer.Option(Path("shots.yaml"), "--shots", exists=True, help=t("cmd.recon.opt.shots")),
    raw_dir: Path = typer.Option(Path("docs/build/recon/raw"), "--raw-dir", help=t("cmd.recon.opt.raw_dir")),
    only: list[str] = typer.Option([], "--only", help=t("cmd.recon.opt.only")),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help=t("cmd.bridge.opt.serve_url")),
    dcs_serve: str | None = typer.Option(None, "--dcs-serve", help=t("cmd.bridge.opt.dcs_serve")),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help=t("cmd.bridge.opt.api_key")
    ),
    config: str | None = typer.Option(None, "--config", help=t("cmd.bridge.opt.config")),
    wait: int = typer.Option(DEFAULT_WAIT_SECONDS, "--wait", min=0, help=t("cmd.bridge.opt.wait")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Move the F11 camera onto each shot and grab the DCS window."""
    from veaf_libs.dcs_window_capture import CaptureError, grab_dcs  # noqa: PLC0415

    logger.set_verbose(verbose)
    console.print(t("cmd.recon_shoot.title", version=VERSION))
    try:
        plan = load_plan(shots)
    except ValueError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=2) from error
    console.print(t("cmd.recon_shoot.expect", count=len(plan.shots)))
    bridge = open_bridge(serve_url, dcs_serve, api_key, config, wait)
    try:
        taken = shoot_plan(
            plan,
            raw_dir,
            run_server=bridge.run,
            run_export=lambda code: bridge.run_in(ENV_EXPORT, code, timeout=10.0),
            grab=lambda retry: grab_dcs(retry, ignore_bottom=INFO_BAR_PX),
            latlon_of=_latlon,
            sleep=time.sleep,
            progress=lambda line: console.print(f"  {line}"),
            only=only or None,
        )
    except (RuntimeError, CaptureError) as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=1) from error
    finally:
        bridge.close()
    console.print(t("cmd.recon_shoot.done", count=len(taken), path=raw_dir))


@app.command(name="recon-render", help=t("cmd.recon_render.help"))
def recon_render(
    shots: Path = typer.Option(Path("shots.yaml"), "--shots", exists=True, help=t("cmd.recon.opt.shots")),
    raw_dir: Path = typer.Option(Path("docs/build/recon/raw"), "--raw-dir", help=t("cmd.recon.opt.raw_dir")),
    out_dir: Path = typer.Option(Path("docs/recon"), "--out-dir", help=t("cmd.recon_render.opt.out_dir")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Render the raw shots into reconnaissance photos, with an index for the briefing."""
    from veaf_libs.recon_render import render_shot  # noqa: PLC0415

    logger.set_verbose(verbose)
    console.print(t("cmd.recon_render.title", version=VERSION))
    try:
        plan = load_plan(shots)
    except ValueError as error:
        console.print(f"[red]✗[/]  {error}")
        raise typer.Exit(code=2) from error
    present = [s for s in plan.shots if (raw_dir / f"{s.name}.png").exists() and (raw_dir / f"{s.name}.json").exists()]
    if not present:
        console.print(f"[red]✗[/]  {t('cmd.recon_render.nothing', path=raw_dir)}")
        raise typer.Exit(code=1)
    index: list[dict[str, Any]] = []
    for number, shot in enumerate(present, start=1):
        meta = json.loads((raw_dir / f"{shot.name}.json").read_text(encoding="utf-8"))
        image = out_dir / f"{shot.name}.jpg"
        render_shot(
            raw_dir / f"{shot.name}.png",
            meta,
            image,
            plan.operation,
            number,
            len(present),
            progress=lambda line: console.print(f"  {line}"),
        )
        target = meta["target"]
        if target.get("lat") is not None:
            target["dms"] = to_dms(target["lat"], target["lon"])
        meta["image"] = image.name
        meta.update(briefing_sidecar(meta, number))
        (out_dir / f"{shot.name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        index.append({"name": shot.name, "title": shot.title, "image": image.name, "metadata": f"{shot.name}.json"})
    (out_dir / "recon.json").write_text(
        json.dumps({"operation": plan.operation, "shots": index}, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    console.print(t("cmd.recon_render.done", count=len(index), path=out_dir))
