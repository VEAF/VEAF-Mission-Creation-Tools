import shutil
from pathlib import Path

import typer
from veaf_libs.paths import resolve_path

from veaf_tools.app import README_HELP, VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.helpers import _ask_replace


@app.command(help=t("cmd.prepare.help"))
def prepare(
    mission_folder: str | None = typer.Argument(".", help="Folder to initialize as a VEAF mission folder."),
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help=t("cmd.prepare.opt.force")),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Mission Folder Preparation v{VERSION}[/bold green]")

    if readme:
        console.print("[bold cyan]Prepare Command[/bold cyan]")
        console.print("This command initializes a mission folder with default files.")
        console.print("\nDefault files are copied from: published/src/defaults/mission-folder")
        console.print("\nIf files already exist, you will be asked to confirm replacement (unless --force is used).")
        console.print("\nFor v5 migrations, do NOT run prepare — use convert-v5 directly on your existing v5 folder.")
        exit()

    try:
        # Resolve mission folder
        p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)

        logger.info(f"Initializing mission folder: {p_mission_folder}")

        # Resolve the defaults source directory.
        # __file__ is either:
        #   - published/veaf-tools/veaf_tools/commands/prepare.py  (installed)
        #   - src/python/veaf-tools/veaf_tools/commands/prepare.py  (dev)
        install_source = Path(__file__).parent.parent.parent  # published/veaf-tools/ or src/python/veaf-tools/

        # Installed: published/src/defaults/mission-folder
        defaults_source = install_source.parent / "src" / "defaults" / "mission-folder"

        # Dev: src/defaults/mission-folder
        if not defaults_source.exists():
            defaults_source = install_source.parent.parent / "defaults" / "mission-folder"

        if not defaults_source.exists():
            searched = [
                str(install_source.parent / "src" / "defaults" / "mission-folder"),
                str(install_source.parent.parent / "defaults" / "mission-folder"),
            ]
            logger.error(
                "Default files not found. Searched:\n  " + "\n  ".join(searched),
                raise_exception=True,
            )

        defaults_source_path: Path = defaults_source
        files_installed = 0
        files_skipped = 0
        yes_to_all = force

        # Copy default files from defaults source
        logger.info(f"Copying default files from {defaults_source_path}")
        for source_file in defaults_source_path.rglob("*"):
            if source_file.is_file():
                relative_path = source_file.relative_to(defaults_source_path)
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
