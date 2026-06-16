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


def _resolve_template_modules(template: str) -> set[str]:
    """Resolve a ``--template`` value to the set of module ids to enable.

    Named tiers map to their fixed module set; ``custom`` opens an interactive
    multi-select. An unknown name aborts the CLI.

    Args:
        template: ``minimal`` / ``standard`` / ``full`` / ``custom``.

    Returns:
        The module ids to enable in the generated ``mission.yaml``.
    """
    from veaf_libs.mission_template import TIER_NAMES, tier_modules

    name = template.lower()
    if name in TIER_NAMES:
        return tier_modules(name)
    if name == "custom":
        return _select_custom_modules()
    logger.error(t("cmd.prepare.unknown_template", template=template, valid=", ".join((*TIER_NAMES, "custom"))))
    raise typer.Exit(code=1)


def _select_custom_modules() -> set[str]:
    """Interactively pick the modules to enable (``custom`` template)."""
    from InquirerPy import inquirer  # type: ignore[import-untyped]
    from veaf_libs.mission_template import SELECTABLE_MODULES, tier_modules

    preselected = tier_modules("standard")
    choices = [{"name": mod, "value": mod, "enabled": mod in preselected} for mod in SELECTABLE_MODULES]
    selected = inquirer.checkbox(
        message=t("cmd.prepare.custom_prompt"),
        choices=choices,
        instruction="(space = toggle, enter = confirm)",
    ).execute()
    return set(selected)


@app.command(help=t("cmd.prepare.help"), no_args_is_help=True)
def prepare(
    mission_folder: str | None = typer.Argument(".", help=t("cmd.prepare.opt.mission_folder")),
    template: str | None = typer.Option(None, "--template", "-t", help=t("cmd.prepare.opt.template")),
    list_templates: bool = typer.Option(False, "--list-templates", help=t("cmd.prepare.opt.list_templates")),
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help=t("cmd.prepare.opt.force")),
) -> None:
    from veaf_libs.mission_template import TIER_NAMES

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(t("cmd.prepare.title", version=VERSION))

    if list_templates:
        console.print(t("cmd.prepare.templates_list", templates=", ".join((*TIER_NAMES, "custom"))))
        return

    if readme:
        console.print(t("cmd.prepare.subtitle"))
        console.print(t("cmd.prepare.readme.intro"))
        exit()

    enabled_modules = _resolve_template_modules(template) if template else None

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

        # Apply the chosen template: regenerate mission.yaml from the selected module set
        # (overwrites the copied default). No --template keeps the shipped default as-is.
        if enabled_modules is not None:
            from veaf_libs.mission_template import generate_mission_yaml

            (p_mission_folder / "mission.yaml").write_text(generate_mission_yaml(enabled_modules), encoding="utf-8")
            console.print(t("cmd.prepare.template_applied", template=template, count=len(enabled_modules)))

        # Print summary
        console.print(t("cmd.prepare.done"))
        console.print(t("cmd.prepare.files_installed", count=files_installed))
        if files_skipped > 0:
            console.print(t("cmd.prepare.files_skipped", count=files_skipped))
        console.print(t("cmd.prepare.folder_ready", path=p_mission_folder.resolve()))
        console.print(t("cmd.prepare.next_steps"))

    except Exception as e:
        logger.error(t("cmd.prepare.failed", error=str(e)))
        exit(1)
