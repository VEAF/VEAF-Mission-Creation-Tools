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


@app.command(no_args_is_help=True)
def extract_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help="Interactive mode: select which groups to include."),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_yaml: str = typer.Option("aircraft-templates.yaml", help="Output YAML file path."),
    group_name_pattern: str = typer.Option(".*", help="Regular expression pattern to match aircraft group names."),
    only_airplanes: bool = typer.Option(False, help="Extract only airplanes."),
    only_helicopters: bool = typer.Option(False, help="Extract only helicopters."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    lua_input: str | None = typer.Option(
        None, help="Path to a Lua file (e.g., settings-templates.lua) to extract from instead of a .miz mission."
    ),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts aircraft groups matching a pattern from a DCS mission or Lua settings file and writes them to a YAML file.
    """

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(
            "Cannot use both --only-airplanes and --only-helicopters simultaneously.", exception_type=ValueError
        )

    # Convert boolean options to aircraft_type
    aircraft_type = "airplanes" if only_airplanes else ("helicopters" if only_helicopters else None)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Aircraft Groups Extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(AircraftGroupsExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve output YAML file
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_output_yaml = resolve_path(
        path=output_yaml, default_path=p_mission_folder / output_yaml, create_if_not_exist=True
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = AircraftGroupsExtractorWorker(
            input_lua=p_lua_input,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file (original behavior)
        if not p_mission_folder.exists():
            logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

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
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )

    worker.extract(interactive=interactive)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True)
def inject_aircraft_groups(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mode: str = typer.Option(
        "add", help="Injection mode: 'add' (add new groups) or 'replace' (replace existing groups)."
    ),
    template_file: str = typer.Option(
        "aircraft-templates.yaml", help="Path to the YAML file containing aircraft groups."
    ),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects aircraft groups from a YAML file into a DCS mission.
    Validates the YAML file before injection and stops if validation fails.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Aircraft Groups Injector v{VERSION}[/bold green]")

    # Validate mode
    if mode not in ("add", "replace"):
        logger.error(f"Invalid mode '{mode}'. Must be 'add' or 'replace'.", exception_type=ValueError)

    # Resolve mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

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
        logger.error(f"Template file {p_template_file} does not exist!", exception_type=FileNotFoundError)

    # STEP 1: Validate the YAML file (MANDATORY)
    logger.info("Step 1: Validating YAML file...")
    validator = AircraftGroupsYAMLValidator(p_template_file)
    is_valid, _ = validator.validate()

    # Display validation report
    console.print("\n" + validator.get_report())

    # If validation fails, stop here
    if not is_valid:
        console.print("[bold red]✗ YAML validation failed. Please fix the errors before injection.[/bold red]")
        if pause:
            input(t("help.pause_msg"))
        exit(1)

    console.print("[bold green]✓ YAML validation successful![/bold green]\n")

    # STEP 2: Inject aircraft groups
    logger.info(f"Step 2: Injecting aircraft groups using '{mode}' mode...")
    injector = AircraftGroupsInjectorWorker(
        input_yaml=p_template_file, target_mission=p_input_mission, output_mission=p_output_mission
    )
    result = injector.inject(mode=mode, silent=False)

    # Display injection results
    injector.display_results(result, verbose=verbose)

    if result.success:
        console.print(
            f"[bold green]✓ Successfully injected {result.groups_injected} group(s) into the mission![/bold green]"
        )
    else:
        console.print(f"[bold yellow]⚠ Injection completed: {result.message}[/bold yellow]")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
