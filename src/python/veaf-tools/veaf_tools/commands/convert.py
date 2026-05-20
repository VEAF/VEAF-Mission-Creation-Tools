from datetime import datetime
from pathlib import Path

import typer
from mission_converter import MissionConverterREADME, MissionConverterWorker
from rich.markdown import Markdown
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
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
def convert(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    dynamic_mode: bool = typer.Option(
        False,
        help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders).",
    ),
    scripts_path: str = typer.Option(None, help="Path to the VEAF and community scripts."),
    mission_name: str = typer.Argument(
        help="Mission name; will extract from the mission with this name (most recent .miz file)"
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Converts a DCS mission to a VEAF mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission converter v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(MissionConverterREADME)
            console.print(md_render)
        exit()

    # Compute a file name from the mission name
    p_output_mission = Path(f"{mission_name}_{datetime.now().strftime('%Y%m%d')}.miz")

    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    p_input_mission: str | Path = mission_name
    if files := list(p_mission_folder.glob(f"{mission_name}*.miz")):
        p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve development path
    effective_scripts_path: str | Path | None = scripts_path
    if not scripts_path and dynamic_mode:
        # default value is the "published" subfolder of the mission folder
        effective_scripts_path = p_mission_folder / "published"
    if effective_scripts_path:
        p_scripts_path = resolve_path(path=effective_scripts_path, should_exist=True)
        if not p_scripts_path.exists():
            logger.error(f"Development folder {p_scripts_path} does not exist!", exception_type=FileNotFoundError)
    else:
        p_scripts_path = None

    # Call the worker class
    worker = MissionConverterWorker(
        mission_folder=p_mission_folder,
        input_mission=p_input_mission,
        output_mission=p_output_mission,
        mission_name=mission_name,
        dynamic_mode=dynamic_mode,
        scripts_path=p_scripts_path,
        inject_presets=False,
        presets_file=None,
    )
    worker.work()

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
