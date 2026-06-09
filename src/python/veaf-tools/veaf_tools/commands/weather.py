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


@app.command(no_args_is_help=True, help=t("cmd.inject_weather.help"))
def inject_weather(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(DEFAULT_MISSION_FILE, help=t("cmd.inject_weather.opt.mission")),
    config_file: str = typer.Option("versions.yaml", help=t("cmd.inject_weather.opt.config_file")),
    convert_lua: bool = typer.Option(False, "--convert-lua", help=t("cmd.inject_weather.opt.convert_lua")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.inject_weather.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WeatherInjectorREADME)
            console.print(md_render)
        exit()

    p_config_file = resolve_path(path=config_file, should_exist=True)

    # Handle Lua conversion
    if convert_lua or p_config_file.suffix.lower() == ".lua":
        logger.info(t("cmd.weather.converting_lua", path=p_config_file))
        if yaml_file := LuaToYamlConverter.convert_file(p_config_file):
            console.print(t("cmd.inject_weather.lua_converted"))
            console.print(f"  {yaml_file}")
            if typer.confirm(t("cmd.inject_weather.confirm_create")):
                p_config_file = yaml_file
            else:
                if pause:
                    input(t("help.pause_msg"))
                return
        else:
            logger.error(t("cmd.weather.convert_failed", error="conversion failed"))
            if pause:
                input(t("help.pause_msg"))
            return

    if not p_config_file.exists():
        logger.error(t("cmd.weather.config_not_found", path=p_config_file), exception_type=FileNotFoundError)

    # Resolve mission file path
    p_mission_file = resolve_path(path=mission_name_or_file, should_exist=True)

    # Call the worker class
    worker = WeatherInjectorWorker(config_file=p_config_file, mission_file=p_mission_file)
    if created_files := worker.work():
        console.print(t("cmd.inject_weather.done", count=len(created_files)))
        for file_path in created_files:
            console.print(f"  - {file_path.name}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
