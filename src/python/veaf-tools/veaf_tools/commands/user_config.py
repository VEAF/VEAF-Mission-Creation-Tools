import os
import sys

import typer
from veaf_libs import user_config as cfg
from veaf_libs.i18n import current_language

from veaf_tools.app import PAUSE_HELP, VERBOSE_HELP, VERSION, app, console, logger, t


@app.command(help=t("cmd.user_config.help"))
def user_config(
    set_value: str | None = typer.Option(None, "--set", help=t("cmd.user_config.opt.set")),
    unset_key: str | None = typer.Option(None, "--unset", help=t("cmd.user_config.opt.unset")),
    init: bool = typer.Option(False, "--init", help=t("cmd.user_config.opt.init")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools User Config v{VERSION}[/bold green]")

    if init:
        path = cfg.default_config_path()
        if path.exists():
            console.print(t("cmd.user_config.init_exists", path=path))
        else:
            import yaml  # type: ignore[import-untyped]

            default_data = {
                "lang": "en",
                "check_updates": True,
                "scripts_path": None,
            }
            path.write_text(yaml.dump(default_data, allow_unicode=True, default_flow_style=False), encoding="utf-8")
            cfg.invalidate_cache()
            console.print(t("cmd.user_config.init_created", path=path))
        if pause:
            input(t("help.pause_msg"))
        return

    if set_value is not None:
        if "=" not in set_value:
            console.print(f"[bold red]{t('cmd.user_config.set_invalid')}[/bold red]")
            raise typer.Exit(1)
        key, _, value = set_value.partition("=")
        key = key.strip()
        value = value.strip()
        # coerce booleans
        parsed_value: object = value
        if value.lower() in ("true", "yes", "1"):
            parsed_value = True
        elif value.lower() in ("false", "no", "0"):
            parsed_value = False
        elif value.lower() in ("null", "none", ""):
            parsed_value = None
        if not cfg.set_value(key, parsed_value):
            console.print(f"[bold red]{t('cmd.user_config.set_failed', name=key)}[/bold red]")
            raise typer.Exit(1)
        console.print(t("cmd.user_config.key_set", name=key, value=parsed_value))
        if pause:
            input(t("help.pause_msg"))
        return

    if unset_key is not None:
        removed = cfg.unset_value(unset_key)
        if removed:
            console.print(t("cmd.user_config.key_unset", name=unset_key))
        else:
            console.print(t("cmd.user_config.key_not_found", name=unset_key))
        if pause:
            input(t("help.pause_msg"))
        return

    # Default: show config file info and effective settings
    config_path = cfg.config_file_path()
    if config_path is None:
        console.print(f"[yellow]{t('cmd.user_config.no_file')}[/yellow]")
        console.print(t("cmd.user_config.default_path", path=cfg.default_config_path()))
    else:
        console.print(t("cmd.user_config.file_path", path=config_path))
        console.print(f"\n[bold]{t('cmd.user_config.contents')}[/bold]")
        console.print(config_path.read_text(encoding="utf-8"))

    # Effective settings
    console.print(f"\n[bold]{t('cmd.user_config.effective')}[/bold]")

    # Language with source
    active_lang = current_language()
    _argv = sys.argv[1:]
    if any(a == "--lang" or a.startswith("--lang=") for a in _argv):
        lang_source = "--lang"
    elif os.environ.get("VEAF_LANG"):
        lang_source = "VEAF_LANG"
    elif cfg.get_lang() is not None:
        actual_cfg_path = cfg.config_file_path()
        lang_source = str(actual_cfg_path) if actual_cfg_path is not None else "~/veafmct.yaml"
    else:
        lang_source = "OS/default"
    console.print(t("cmd.user_config.effective_lang", lang=active_lang, source=lang_source))

    check_updates = cfg.get_check_updates()
    state = t("cmd.user_config.state_on") if check_updates else t("cmd.user_config.state_off")
    console.print(t("cmd.user_config.effective_check_updates", state=state))

    scripts_path = cfg.get_scripts_path()
    if scripts_path is not None:
        console.print(t("cmd.user_config.effective_scripts_path", path=scripts_path))

    if pause:
        input(t("help.pause_msg"))
