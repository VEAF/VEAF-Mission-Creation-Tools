import shutil
from pathlib import Path

import typer
from veaf_libs.paths import resolve_path

from veaf_tools.app import README_HELP, VERBOSE_HELP, VERSION, app, console, logger
from veaf_tools.helpers import _ask_replace


@app.command()
def prepare(
    mission_folder: str | None = typer.Argument(".", help="Folder to initialize as a VEAF mission folder."),
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help="Do not ask before replacing existing files (same as pressing A)."),
) -> None:
    """
    Prepares a mission folder by copying default files and build scripts.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Mission Folder Preparation v{VERSION}[/bold green]")

    if readme:
        console.print("[bold cyan]Prepare Command[/bold cyan]")
        console.print("This command initializes a mission folder with default files and build scripts.")
        console.print("\nDefault files are copied from: src/defaults/mission-folder")
        console.print("Build scripts are copied from: src/build-scripts")
        console.print("\nIf files already exist, you will be asked to confirm replacement (unless --force is used).")
        exit()

    try:
        # Resolve mission folder
        p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)

        logger.info(f"Initializing mission folder: {p_mission_folder}")

        # Get the installation source directory (where veaf-tools is running from)
        # This could be from published/ or from src/python/veaf-tools/
        install_source = Path(__file__).parent.parent.parent

        # Try to find src/defaults relative to the script location
        # First, check if we're in a published installation
        defaults_source = install_source.parent.parent.parent / "src" / "defaults" / "mission-folder"

        # If not found, check parent directories (for development installations)
        if not defaults_source.exists():
            # Try one more level up (if running from veaf-tools/ subdirectory)
            defaults_source = install_source.parent.parent.parent.parent / "src" / "defaults" / "mission-folder"

        # If still not found, look in a common relative location
        if not defaults_source.exists():
            # Try from current working directory
            defaults_source = Path.cwd().parent / "src" / "defaults" / "mission-folder"

        if not defaults_source.exists():
            logger.warning(f"Default files not found at: {defaults_source}")
            logger.warning("Attempting to continue with build scripts only...")
            defaults_source = None  # type: ignore[assignment]

        # Get build scripts source
        build_scripts_source = install_source.parent.parent.parent / "src" / "build-scripts"
        if not build_scripts_source.exists():
            build_scripts_source = install_source.parent.parent.parent.parent / "src" / "build-scripts"

        if not build_scripts_source.exists():
            build_scripts_source = Path.cwd().parent / "src" / "build-scripts"

        if not build_scripts_source.exists():
            logger.warning(f"Build scripts not found at: {build_scripts_source}")
            build_scripts_source = None  # type: ignore[assignment]

        files_installed = 0
        files_skipped = 0
        yes_to_all = force

        # Copy default files from src/defaults/mission-folder
        if defaults_source and defaults_source.exists():
            logger.info(f"Copying default files from {defaults_source}")
            for source_file in defaults_source.rglob("*"):
                if source_file.is_file():
                    relative_path = source_file.relative_to(defaults_source)
                    dest_file = p_mission_folder / relative_path

                    # Create destination directory if needed
                    dest_file.parent.mkdir(parents=True, exist_ok=True)

                    # Check if file already exists
                    if dest_file.exists():
                        if not yes_to_all:
                            should_replace, yes_to_all = _ask_replace(relative_path)
                        else:
                            should_replace = True

                        if should_replace:
                            shutil.copy2(source_file, dest_file)
                            logger.debug(f"Replaced: {relative_path}")
                            files_installed += 1
                        else:
                            logger.debug(f"Skipped: {relative_path}")
                            files_skipped += 1
                    else:
                        shutil.copy2(source_file, dest_file)
                        logger.debug(f"Installed: {relative_path}")
                        files_installed += 1

        # Copy build scripts
        if build_scripts_source and build_scripts_source.exists():
            logger.info(f"Copying build scripts from {build_scripts_source}")
            for source_file in build_scripts_source.rglob("*"):
                if source_file.is_file():
                    relative_path = source_file.relative_to(build_scripts_source)
                    dest_file = p_mission_folder / relative_path

                    # Create destination directory if needed
                    dest_file.parent.mkdir(parents=True, exist_ok=True)

                    # Check if file already exists
                    if dest_file.exists():
                        if not yes_to_all:
                            should_replace, yes_to_all = _ask_replace(relative_path)
                        else:
                            should_replace = True

                        if should_replace:
                            shutil.copy2(source_file, dest_file)
                            logger.debug(f"Replaced: {relative_path}")
                            files_installed += 1
                        else:
                            logger.debug(f"Skipped: {relative_path}")
                            files_skipped += 1
                    else:
                        shutil.copy2(source_file, dest_file)
                        logger.debug(f"Installed: {relative_path}")
                        files_installed += 1

        # Print summary
        console.print("\n[bold green]Preparation completed![/bold green]")
        console.print(f"  Files installed: [cyan]{files_installed}[/cyan]")
        if files_skipped > 0:
            console.print(f"  Files skipped: [yellow]{files_skipped}[/yellow]")
        console.print(f"\nMission folder ready at: [cyan]{p_mission_folder.resolve()}[/cyan]")

    except Exception as e:
        logger.error(f"Preparation failed: {e}")
        exit(1)
