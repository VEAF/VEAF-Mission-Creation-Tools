from pathlib import Path

import typer
import yaml
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


@app.command(name="ctld-upgrade", help=t("cmd.ctld_upgrade.help"))
def ctld_upgrade(
    mission_folder: str | None = typer.Argument(".", help=t("cmd.ctld_upgrade.opt.mission_folder")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Bring a mission's ctld-config.yaml up to the vendored CTLD catalogue, adding only what it lacks."""
    from veaf_libs.ctld_config import (
        CTLD_CONFIG_FILENAME,
        find_catalogue_gap,
        read_default_config,
        upgrade_to_catalogue,
        vendored_ctld_lua,
    )

    logger.set_verbose(verbose)
    console.print(t("cmd.ctld_upgrade.title", version=VERSION))

    folder = Path(resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=False))
    config_path = folder / CTLD_CONFIG_FILENAME
    if not config_path.is_file():
        console.print(f"[red]✗[/]  {t('cmd.ctld_upgrade.no_config', file=config_path)}")
        raise typer.Exit(code=1)
    engine = vendored_ctld_lua(folder)
    catalogue = read_default_config(engine) if engine is not None else None
    if catalogue is None:
        console.print(f"[red]✗[/]  {t('cmd.ctld_upgrade.no_catalogue')}")
        raise typer.Exit(code=1)

    raw = config_path.read_bytes().decode("utf-8")
    newline = "\r\n" if "\r\n" in raw else "\n"
    current = raw.replace("\r\n", "\n")
    try:
        readable = isinstance(yaml.safe_load(current), dict)
    except yaml.YAMLError:
        readable = False
    if not readable:
        console.print(f"[red]✗[/]  {t('cmd.ctld_upgrade.unreadable', file=config_path)}")
        raise typer.Exit(code=1)
    gap = find_catalogue_gap(current, catalogue)
    if gap is None:
        console.print(t("cmd.ctld_upgrade.up_to_date", file=CTLD_CONFIG_FILENAME))
    else:
        config_path.write_bytes(upgrade_to_catalogue(current, catalogue).replace("\n", newline).encode("utf-8"))
        console.print(
            t(
                "cmd.ctld_upgrade.done",
                file=CTLD_CONFIG_FILENAME,
                mission=gap.mission_version or "?",
                catalogue=gap.catalogue_version or "?",
                keys=", ".join(f"{section}.{key}" for section, key in gap.missing) or "—",
            )
        )
        if gap.removed:
            console.print(f"[yellow]⚠[/]  {t('cmd.ctld_upgrade.removed', keys=', '.join(gap.removed))}")
        if gap.unused_features:
            console.print(f"[yellow]⚠[/]  {t('cmd.ctld_upgrade.unused', keys=', '.join(gap.unused_features))}")

    if pause:
        input(t("help.pause_msg"))
