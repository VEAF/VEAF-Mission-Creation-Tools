from pathlib import Path

import typer
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path
from weather_injector import LuaToYamlConverter, WeatherInjectorREADME, WeatherInjectorWorker

from veaf_tools.app import (
    DEFAULT_MISSION_FILE,
    PAUSE_HELP,
    README_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(no_args_is_help=True)
def inject_weather(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE, help="Mission name or .miz file to use as base for creating weather/time variants."
    ),
    config_file: str = typer.Option("missions.yaml", help="Path to YAML configuration file (or Lua file to convert)."),
    convert_lua: bool = typer.Option(False, "--convert-lua", help="Convert legacy Lua configuration to YAML and exit"),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Creates multiple versions of a DCS mission with different weather conditions and start times.
    Uses a YAML configuration file to define mission variants.
    Can also convert legacy Lua configurations to YAML format.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Weather and Time Versions v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WeatherInjectorREADME)
            console.print(md_render)
        exit()

    p_config_file = resolve_path(path=config_file, should_exist=True)

    # Handle Lua conversion
    if convert_lua or p_config_file.suffix.lower() == ".lua":
        logger.info(f"Converting Lua configuration: {p_config_file}")
        if yaml_file := LuaToYamlConverter.convert_file(p_config_file):
            console.print("[bold green]Lua configuration converted to YAML:[/bold green]")
            console.print(f"  {yaml_file}")
            if typer.confirm("Do you want to create missions from this configuration?"):
                p_config_file = yaml_file
            else:
                if pause:
                    input(t("help.pause_msg"))
                return
        else:
            logger.error("Failed to convert Lua configuration")
            if pause:
                input(t("help.pause_msg"))
            return

    if not p_config_file.exists():
        logger.error(f"Configuration file {p_config_file} does not exist!", exception_type=FileNotFoundError)

    # Resolve mission file path
    p_mission_file = resolve_path(path=mission_name_or_file, should_exist=True)

    # Call the worker class
    worker = WeatherInjectorWorker(config_file=p_config_file, mission_file=p_mission_file)
    if created_files := worker.work():
        console.print(f"[bold green]Created {len(created_files)} mission files[/bold green]")
        for file_path in created_files:
            console.print(f"  - {file_path.name}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
