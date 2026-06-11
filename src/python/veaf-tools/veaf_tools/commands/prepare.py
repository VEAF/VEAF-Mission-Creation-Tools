import shutil
from pathlib import Path

import typer
from veaf_libs.paths import resolve_path

from veaf_tools.app import README_HELP, VERBOSE_HELP, VERSION, app, console, logger, t
from veaf_tools.helpers import _ask_replace


def _defaults_source_candidates(mission_folder: Path) -> list[Path]:
    """Ordered locations to look for the default mission-folder scaffold.

    The defaults ship in ``published.zip`` and are installed by the updater into
    ``<mission>/published/`` — so that is the primary location and the only one
    that works from the packaged exe (where ``__file__`` lives in a PyInstaller
    temp dir). The dev-checkout path is the fallback.

    Args:
        mission_folder: The folder being prepared.

    Returns:
        Candidate ``defaults/mission-folder`` directories, most-preferred first.
    """
    return [
        # Installed by the updater from published.zip
        mission_folder / "published" / "src" / "defaults" / "mission-folder",
        # Dev checkout: <repo>/src/defaults/mission-folder
        Path(__file__).resolve().parents[4] / "defaults" / "mission-folder",
    ]


def _resolve_defaults_source(mission_folder: Path) -> Path | None:
    """Return the first existing default-scaffold directory, or ``None``."""
    for candidate in _defaults_source_candidates(mission_folder):
        if candidate.is_dir():
            return candidate
    return None


@app.command(help=t("cmd.prepare.help"))
def prepare(
    mission_folder: str | None = typer.Argument(".", help=t("cmd.prepare.opt.mission_folder")),
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help=t("cmd.prepare.opt.force")),
) -> None:

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.prepare.title", version=VERSION))

    if readme:
        console.print(t("cmd.prepare.subtitle"))
        console.print(t("cmd.prepare.readme.intro"))
        exit()

    try:
        # Resolve mission folder
        p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)

        logger.info(t("cmd.prepare.initializing", path=p_mission_folder))

        # Resolve the defaults from the target mission folder's published/ (installed
        # by the updater from published.zip) — this is the only location that works
        # from the packaged exe; the dev checkout is the fallback.
        defaults_source = _resolve_defaults_source(p_mission_folder)
        if defaults_source is None:
            searched = [str(c) for c in _defaults_source_candidates(p_mission_folder)]
            logger.error(
                t("cmd.prepare.defaults_not_found", paths="\n  ".join(searched)),
                raise_exception=True,
            )

        defaults_source_path: Path = defaults_source  # type: ignore[assignment]
        files_installed = 0
        files_skipped = 0
        yes_to_all = force

        # Files that must never be overwritten, even with --force, to preserve user customizations
        NEVER_OVERWRITE: frozenset[str] = frozenset({".gitignore"})

        # Copy default files from defaults source
        logger.info(t("cmd.prepare.copying_defaults", path=defaults_source_path))
        for source_file in defaults_source_path.rglob("*"):
            if source_file.is_file():
                relative_path = source_file.relative_to(defaults_source_path)
                dest_file = p_mission_folder / relative_path

                # Create destination directory if needed
                dest_file.parent.mkdir(parents=True, exist_ok=True)

                # Check if file already exists
                if dest_file.exists():
                    if source_file.name in NEVER_OVERWRITE:
                        logger.debug(f"Never-overwrite: {relative_path}")
                        files_skipped += 1
                        continue

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
        console.print(t("cmd.prepare.done"))
        console.print(t("cmd.prepare.files_installed", count=files_installed))
        if files_skipped > 0:
            console.print(t("cmd.prepare.files_skipped", count=files_skipped))
        console.print(t("cmd.prepare.folder_ready", path=p_mission_folder.resolve()))

    except Exception as e:
        logger.error(t("cmd.prepare.failed", error=str(e)))
        exit(1)
