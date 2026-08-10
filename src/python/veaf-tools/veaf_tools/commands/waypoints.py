from pathlib import Path

import typer
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path
from waypoints_injector import (
    WaypointsExtractorREADME,
    WaypointsExtractorWorker,
    WaypointsInjectorREADME,
    WaypointsInjectorWorker,
)

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


@app.command(no_args_is_help=True, help=t("cmd.extract_waypoints.help"))
def extract_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help=t("cmd.extract_waypoints.opt.interactive")),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.extract_waypoints.opt.mission"),
    ),
    output_yaml: str = typer.Option("waypoints.yaml", help=t("cmd.extract_waypoints.opt.output_yaml")),
    group_name_pattern: str = typer.Option(".*", help=t("cmd.extract_waypoints.opt.pattern")),
    only_airplanes: bool = typer.Option(False, help=t("cmd.extract_waypoints.opt.only_airplanes")),
    only_helicopters: bool = typer.Option(False, help=t("cmd.extract_waypoints.opt.only_helicopters")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.extract_waypoints.opt.mission_folder")),
    lua_input: str | None = typer.Option(None, help=t("cmd.extract_waypoints.opt.lua_file")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(t("cmd.waypoints.exclusive_options"), exception_type=ValueError)

    # Convert boolean options to aircraft_type (using 'plane'/'helicopter' naming for waypoints)
    aircraft_type = "plane" if only_airplanes else ("helicopter" if only_helicopters else None)

    # Set the title and version
    console.print(t("cmd.extract_waypoints.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WaypointsExtractorREADME)
            console.print(md_render)
        raise typer.Exit()

    # Resolve mission folder and output YAML file
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_output_yaml = resolve_path(
        path=output_yaml, default_path=p_mission_folder / output_yaml, create_if_not_exist=True
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = WaypointsExtractorWorker(
            input_lua=p_lua_input,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file
        if not p_mission_folder.exists():
            logger.error(t("cmd.waypoints.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

        # Resolve input mission
        assert mission_name_or_file is not None
        p_input_mission: str | Path | None = mission_name_or_file
        if not mission_name_or_file.lower().endswith(".miz"):
            if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
                p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
        p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

        # Call the worker
        worker = WaypointsExtractorWorker(
            input_mission=p_input_mission,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )

    worker.extract(interactive=interactive)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True, help=t("cmd.inject_waypoints.help"))
def inject_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.inject_waypoints.opt.mission"),
    ),
    output_mission: str | None = typer.Argument(None, help=t("cmd.inject_waypoints.opt.output_mission")),
    waypoints_file: str = typer.Option("waypoints.yaml", help=t("cmd.inject_waypoints.opt.yaml_file")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.inject_waypoints.opt.mission_folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.inject_waypoints.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WaypointsInjectorREADME)
            console.print(md_render)
        raise typer.Exit()

    # Resolve mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(t("cmd.waypoints.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

    # Resolve input mission
    assert mission_name_or_file is not None
    p_input_mission: str | Path | None = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve waypoints YAML file
    p_waypoints_file = resolve_path(path=waypoints_file, should_exist=True)
    if not p_waypoints_file.exists():
        logger.error(t("cmd.waypoints.waypoints_not_found", path=p_waypoints_file), exception_type=FileNotFoundError)

    # Call the worker class
    worker = WaypointsInjectorWorker(
        waypoints_file=p_waypoints_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
