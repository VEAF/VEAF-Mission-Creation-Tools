from pathlib import Path

import typer
from presets_injector.airfield_channels_manager import apply_airfield_channels, describe_airfield_channels
from veaf_libs.paths import resolve_path

from veaf_tools.app import PAUSE_HELP, VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(help=t("cmd.airfield_channels.help"))
def airfield_channels(
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    apply: list[str] = typer.Option([], "--apply", help=t("cmd.airfield_channels.opt.apply")),
    neutral: bool = typer.Option(False, "--neutral", help=t("cmd.airfield_channels.opt.neutral")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.airfield_channels.opt.mission_folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)
    console.print(t("cmd.airfield_channels.title", version=VERSION))

    folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)

    if apply:
        try:
            result = apply_airfield_channels(folder, list(apply))
        except (ValueError, FileNotFoundError) as exc:
            logger.error(str(exc))  # aborts the command cleanly
            return
        console.print(
            t("cmd.airfield_channels.written", channels=", ".join(result["channels"]))
            if result["written"]
            else t("cmd.airfield_channels.unchanged")
        )
        if result["untouched"]:
            console.print(t("cmd.airfield_channels.untouched", channels=", ".join(result["untouched"])))
        if result["not_on_a_radio"]:
            console.print(t("cmd.airfield_channels.not_on_a_radio", channels=", ".join(result["not_on_a_radio"])))
    else:
        try:
            report = describe_airfield_channels(folder, include_neutral=neutral)
        except (ValueError, FileNotFoundError) as exc:
            logger.error(str(exc))  # aborts the command cleanly
            return
        console.print(t("cmd.airfield_channels.header", theatre=report["theatre"], count=len(report["candidates"])))
        for c in report["candidates"]:
            freqs = " / ".join(f"{band} {value}" for band, value in c["freqs"].items())
            console.print(
                t(
                    "cmd.airfield_channels.row",
                    name=c["name"],
                    id=c["airdrome_id"],
                    coalition=c["coalition"],
                    dynamic=t("cmd.airfield_channels.yes") if c["dynamic_slots"] else "-",
                    parked=c["parked_slots"],
                    freqs=freqs,
                    tacan=c["tacan"] or "-",
                    channel=c["channel"] or "-",
                )
            )
        console.print(t("cmd.airfield_channels.hint", folder=folder))

    if pause:
        input(t("help.pause_msg"))
