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


@app.command(no_args_is_help=True, help=t("cmd.convert.help"))
def convert(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    dynamic_mode: bool = typer.Option(
        False,
        help=t("cmd.convert.opt.dynamic_mode"),
    ),
    scripts_path: str = typer.Option(None, help=t("cmd.convert.opt.scripts_path")),
    mission_name: str = typer.Argument(help=t("cmd.convert.opt.mission")),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.convert.opt.mission_folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.convert.title", version=VERSION))

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
