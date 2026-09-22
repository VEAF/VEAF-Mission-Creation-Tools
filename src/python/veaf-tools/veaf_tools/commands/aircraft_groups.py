from pathlib import Path
from typing import Any

import typer
import yaml
from aircrafts_injector import (
    AircraftGroupsExtractorREADME,
    AircraftGroupsExtractorWorker,
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
)
from aircrafts_injector.catalogue import GroupRef, iter_groups, load_catalogue, merge_missing
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path
from veaf_libs.shipped_defaults import shipped_default_file

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
    tn,
)
from veaf_tools.helpers import confirm


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
    merge: bool = typer.Option(False, help=t("cmd.extract_aircraft.opt.merge")),
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
        if confirm(t("help.confirm_doc"), unattended=True):
            md_render = Markdown(AircraftGroupsExtractorREADME)
            console.print(md_render)
        raise typer.Exit()

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
            merge=merge,
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
            merge=merge,
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
        raise typer.Exit(1)

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
        console.print(tn("cmd.inject_aircraft.injected", result.groups_injected))
    else:
        console.print(t("cmd.inject_aircraft.partial", message=result.message))

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


#: The two aircraft-group catalogues a mission folder can own, by ``--kind`` value.
_CATALOGUE_FILES: dict[str, str] = {
    "spawnable": "src/spawnables.yaml",
    "dynamic-template": "src/dynamic-slot-templates.yaml",
}


def _pull_delta(mine: dict[str, Any], shipped: dict[str, Any]) -> tuple[list[GroupRef], list[GroupRef]]:
    """Split the shipped catalogue into what the mission is missing and what it already owns.

    Args:
        mine: The mission folder's catalogue.
        shipped: The catalogue shipped with the tool.

    Returns:
        The missing refs and the shared ones, both in shipped-file order.
    """
    owned = {ref.name for ref, _ in iter_groups(mine)}
    missing = [ref for ref, _ in iter_groups(shipped) if ref.name not in owned]
    kept = [ref for ref, _ in iter_groups(shipped) if ref.name in owned]
    return missing, kept


def _report_delta(local: Path, mine: dict[str, Any], missing: list[GroupRef], kept: list[GroupRef], verbose: bool) -> None:
    """Print what the shipped catalogue has that *local* does not, grouped by coalition.

    Args:
        local: The mission folder's catalogue file, named as the report's heading.
        mine: Its parsed content, for the "yours" count.
        missing: The refs the mission does not have.
        kept: The refs present on both sides — listed as kept rather than hidden, so nobody
            wonders what the command did with them.
        verbose: Whether to name the kept entries as well as count them.
    """
    console.print(
        t(
            "cmd.pull_aircraft.file_header",
            file=local.name,
            mine=sum(1 for _ in iter_groups(mine)),
            missing=len(missing),
            kept=len(kept),
        )
    )
    current = ""
    for ref in missing:
        heading = f"{ref.category} / {ref.coalition} / {ref.country}"
        if heading != current:
            console.print(t("cmd.pull_aircraft.missing_header", location=heading))
            current = heading
        console.print(t("cmd.pull_aircraft.group_line", group=ref.name))
    if not missing:
        console.print(t("cmd.pull_aircraft.up_to_date"))
    if kept:
        console.print(tn("cmd.pull_aircraft.kept_note", len(kept)))
        if verbose:
            for ref in kept:
                console.print(t("cmd.pull_aircraft.group_line", group=ref.name))


def _write_catalogue(path: Path, catalogue: dict[str, Any]) -> None:
    """Write a catalogue back, in the encoding and layout the extractor uses.

    UTF-8 explicitly and ``allow_unicode=True``: a catalogue holds accented liveries and
    callsigns, and the process locale would write cp1252 on a French Windows while every reader
    opens it as UTF-8.

    Args:
        path: The file to write.
        catalogue: The merged catalogue.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as yaml_file:
        yaml.dump(catalogue, yaml_file, default_flow_style=False, sort_keys=True, allow_unicode=True)


@app.command(help=t("cmd.pull_aircraft.help"))
def pull_aircraft_groups(
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    kind: str = typer.Option("both", help=t("cmd.pull_aircraft.opt.kind")),
    add: list[str] = typer.Option([], "--add", help=t("cmd.pull_aircraft.opt.add")),
    add_new: bool = typer.Option(False, "--add-new", help=t("cmd.pull_aircraft.opt.add_new")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.pull_aircraft.opt.mission_folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)
    console.print(t("cmd.pull_aircraft.title", version=VERSION))

    if kind not in ("both", "spawnable", "dynamic-template"):
        logger.error(t("cmd.aircraft.invalid_kind", kind=kind), exception_type=ValueError)

    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(t("cmd.aircraft.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

    kinds = list(_CATALOGUE_FILES) if kind == "both" else [kind]

    # Read everything before writing anything: an unknown --add name must leave both files alone,
    # and with --kind both a name living in the other family is not unknown at all.
    families: list[tuple[Path, dict[str, Any], dict[str, Any]]] = []
    for family in kinds:
        relative = _CATALOGUE_FILES[family]
        shipped_path = shipped_default_file(p_mission_folder, relative)
        if shipped_path is None:
            console.print(t("cmd.pull_aircraft.no_shipped", file=Path(relative).name))
            continue
        families.append((p_mission_folder / relative, load_catalogue(p_mission_folder / relative), load_catalogue(shipped_path)))

    if not families:
        raise typer.Exit(1)

    if add:
        available = {ref.name for _, _, shipped in families for ref, _ in iter_groups(shipped)}
        if unknown := sorted(set(add) - available):
            console.print(t("cmd.pull_aircraft.unknown_names", names=", ".join(unknown)))
            raise typer.Exit(1)

    selection: set[str] | None
    if add_new:
        selection = None
    elif add:
        selection = set(add)
    else:
        selection = set()  # report-only: nothing is taken

    total_added = 0
    for local, mine, shipped in families:
        missing, kept = _pull_delta(mine, shipped)
        _report_delta(local, mine, missing, kept, verbose)
        if not add_new and not add:
            continue
        merged, added = merge_missing(mine, shipped, names=selection)
        if not added:
            console.print(t("cmd.pull_aircraft.nothing_added", file=local.name))
            continue
        _write_catalogue(local, merged)
        total_added += len(added)
        console.print(tn("cmd.pull_aircraft.added", len(added), file=local.name))

    if not add_new and not add:
        console.print(t("cmd.pull_aircraft.hint"))

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
