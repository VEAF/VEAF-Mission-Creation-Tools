from pathlib import Path

import typer
from aircrafts_injector import (
    AircraftGroupsExtractorREADME,
    AircraftGroupsExtractorWorker,
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
)
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path

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


@app.command(no_args_is_help=True, help=t("cmd.extract_aircraft.help"))
def extract_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help=t("cmd.extract_aircraft.opt.interactive")),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.extract_aircraft.opt.mission"),
    ),
    kind: str = typer.Option("both", help=t("cmd.extract_aircraft.opt.kind")),
    output_spawnables: str = typer.Option("src/spawnables.yaml", help=t("cmd.extract_aircraft.opt.output_spawnables")),
    output_dynamic_templates: str = typer.Option(
        "src/dynamic-slot-templates.yaml", help=t("cmd.extract_aircraft.opt.output_dynamic_templates")
    ),
    group_name_pattern: str = typer.Option(".*", help=t("cmd.extract_aircraft.opt.pattern")),
    only_airplanes: bool = typer.Option(False, help=t("cmd.extract_aircraft.opt.only_airplanes")),
    only_helicopters: bool = typer.Option(False, help=t("cmd.extract_aircraft.opt.only_helicopters")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.extract_aircraft.opt.mission_folder")),
    lua_input: str | None = typer.Option(None, help=t("cmd.extract_aircraft.opt.lua_file")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(t("cmd.aircraft.exclusive_options"), exception_type=ValueError)
    if kind not in ("both", "spawnable", "dynamic-template"):
        logger.error(t("cmd.aircraft.invalid_kind", kind=kind), exception_type=ValueError)

    # Convert boolean options to aircraft_type
    aircraft_type = "airplanes" if only_airplanes else ("helicopters" if only_helicopters else None)

    # Set the title and version
    console.print(t("cmd.extract_aircraft.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(AircraftGroupsExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve output files (default: both families; --kind restricts to one)
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_spawnables = (
        resolve_path(
            path=output_spawnables, default_path=p_mission_folder / output_spawnables, create_if_not_exist=True
        )
        if kind in ("both", "spawnable")
        else None
    )
    p_dynamic = (
        resolve_path(
            path=output_dynamic_templates,
            default_path=p_mission_folder / output_dynamic_templates,
            create_if_not_exist=True,
        )
        if kind in ("both", "dynamic-template")
        else None
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = AircraftGroupsExtractorWorker(
            input_lua=p_lua_input,
            output_spawnables=p_spawnables,
            output_dynamic_templates=p_dynamic,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file (original behavior)
        if not p_mission_folder.exists():
            logger.error(t("cmd.aircraft.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

        # Resolve input mission
        assert mission_name_or_file is not None
        p_input_mission: str | Path | None = mission_name_or_file
        if not mission_name_or_file.lower().endswith(".miz"):
            if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
                p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
        p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

        # Call the worker
        worker = AircraftGroupsExtractorWorker(
            input_mission=p_input_mission,
            output_spawnables=p_spawnables,
            output_dynamic_templates=p_dynamic,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )

    worker.extract(interactive=interactive)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True, help=t("cmd.inject_aircraft.help"))
def inject_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mode: str = typer.Option("add", help=t("cmd.inject_aircraft.opt.mode")),
    template_file: str = typer.Option("src/spawnables.yaml", help=t("cmd.inject_aircraft.opt.yaml_file")),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.inject_aircraft.opt.mission"),
    ),
    output_mission: str | None = typer.Argument(None, help=t("cmd.inject_aircraft.opt.output_mission")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.inject_aircraft.opt.mission_folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.inject_aircraft.title", version=VERSION))

    # Validate mode
    if mode not in ("add", "replace"):
        logger.error(t("cmd.aircraft.invalid_mode", mode=mode), exception_type=ValueError)

    # Resolve mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(t("cmd.aircraft.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

    # Resolve input mission
    assert mission_name_or_file is not None
    p_input_mission: str | Path | None = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve template YAML file
    p_template_file = resolve_path(path=template_file, should_exist=True)
    if not p_template_file.exists():
        logger.error(t("cmd.aircraft.template_not_found", path=p_template_file), exception_type=FileNotFoundError)

    # STEP 1: Validate the YAML file (MANDATORY)
    logger.info(t("cmd.aircraft.step1_validating"))
    validator = AircraftGroupsYAMLValidator(p_template_file)
    is_valid, _ = validator.validate()

    # Display validation report
    console.print("\n" + validator.get_report())

    # If validation fails, stop here
    if not is_valid:
        console.print(t("cmd.inject_aircraft.validation_failed"))
        if pause:
            input(t("help.pause_msg"))
        exit(1)

    console.print(t("cmd.inject_aircraft.validation_ok") + "\n")

    # STEP 2: Inject aircraft groups
    logger.info(t("cmd.aircraft.step2_injecting", mode=mode))
    injector = AircraftGroupsInjectorWorker(
        input_yaml=p_template_file, target_mission=p_input_mission, output_mission=p_output_mission
    )
    result = injector.inject(mode=mode, silent=False)

    # Display injection results
    injector.display_results(result, verbose=verbose)

    if result.success:
        console.print(t("cmd.inject_aircraft.injected", count=result.groups_injected))
    else:
        console.print(t("cmd.inject_aircraft.partial", message=result.message))

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
