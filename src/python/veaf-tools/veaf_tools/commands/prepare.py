import shutil
from pathlib import Path

import typer
from veaf_libs.ctld_config import CTLD_CONFIG_FILENAME
from veaf_libs.paths import resolve_path

from veaf_tools.app import README_HELP, VERBOSE_HELP, VERSION, app, console, logger, t, tn
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


def _scaffold_ctld_config(mission_folder: Path, defaults_source_path: Path) -> None:
    """Seed ``ctld-config.yaml`` from the vendored CTLD engine's own catalogue.

    CTLD 2 takes a **complete** configuration snapshot, so the mission maker's file
    starts as a copy of the shipped defaults and is then edited in ``ctld-tools``.
    Reading the catalogue out of ``CTLD.lua`` rather than storing a copy here is what
    keeps it current across CTLD upgrades (ADR 0016).

    An existing file is never touched, not even with ``--force``: it is the mission
    maker's configuration, not a scaffold artifact.

    Args:
        mission_folder: The folder being prepared.
        defaults_source_path: The resolved ``<root>/defaults/mission-folder`` directory,
            whose grandparent holds ``scripts/community/CTLD.lua``.
    """
    from veaf_libs.ctld_config import apply_veaf_overrides, read_default_config

    destination = mission_folder / CTLD_CONFIG_FILENAME
    if destination.exists():
        logger.debug(f"Never-overwrite: {CTLD_CONFIG_FILENAME}")
        return

    catalogue = read_default_config(defaults_source_path.parents[1] / "scripts" / "community" / "CTLD.lua")
    if catalogue is None:
        logger.warning(t("cmd.prepare.ctld_config_unavailable", file=CTLD_CONFIG_FILENAME))
        return

    destination.write_text(apply_veaf_overrides(catalogue), encoding="utf-8")
    console.print(t("cmd.prepare.ctld_config_created", file=CTLD_CONFIG_FILENAME))


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
    while True:
        if name in TIER_NAMES:
            return tier_modules(name)
        if name == "custom":
            modules = _select_custom_modules()
            if modules is not None:
                return modules
            # Back (Ctrl-B / Esc Esc): step up one level to the template choice.
            choice = _prompt_template_choice()
            if choice is None:  # backed out of the template choice too → quit
                console.print(t("tui.cancelled"))
                raise typer.Exit(0)
            name = choice.lower()
            continue
        logger.error(t("cmd.prepare.unknown_template", template=template, valid=", ".join((*TIER_NAMES, "custom"))))
        raise typer.Exit(code=1)


def _prompt_template_choice() -> str | None:
    """Re-ask which template to use; return the chosen name, or ``None`` to quit.

    Shown when the user backs out of the ``custom`` module picker — the level
    above the picker is the template selection itself.
    """
    from InquirerPy import inquirer  # type: ignore[import-untyped]
    from veaf_libs.mission_template import TIER_NAMES
    from veaf_libs.tui import _skip_keybindings, _touch_prompt_shown

    _touch_prompt_shown()
    return inquirer.select(
        message=t("cmd.prepare.template_prompt"),
        choices=[*TIER_NAMES, "custom"],
        default="standard",
        mandatory=False,
        keybindings=_skip_keybindings(),
        long_instruction=t("tui.nav_hint"),
    ).execute()


def _select_custom_modules() -> set[str] | None:
    """Interactively pick the modules to enable (``custom`` template).

    Modules are listed in catalog order, grouped by category, each tagged with the lowest
    tier it belongs to; the ``standard`` set is pre-checked.

    Returns:
        The chosen module ids, or ``None`` if the user backed out (Ctrl-B / Esc Esc).
    """
    from InquirerPy import inquirer  # type: ignore[import-untyped]
    from InquirerPy.base.control import Choice  # type: ignore[import-untyped]
    from InquirerPy.separator import Separator  # type: ignore[import-untyped]
    from veaf_libs.mission_template import (
        SELECTABLE_MODULES,
        module_category,
        module_lowest_tier,
        tier_modules,
    )
    from veaf_libs.tui import _skip_keybindings, _touch_prompt_shown

    preselected = tier_modules("standard")
    choices: list = []
    current_category = ""
    for mod in SELECTABLE_MODULES:
        category = module_category(mod)
        if category != current_category:
            choices.append(Separator(f"── {category} ──"))
            current_category = category
        tier = module_lowest_tier(mod) or "opt-in"
        choices.append(Choice(value=mod, name=f"{mod}  · {tier}", enabled=mod in preselected))
    _touch_prompt_shown()
    selected = inquirer.checkbox(
        message=t("cmd.prepare.custom_prompt"),
        choices=choices,
        instruction="(space = toggle, enter = confirm)",
        long_instruction=t("tui.nav_hint"),
        mandatory=False,
        keybindings=_skip_keybindings(),
    ).execute()
    if selected is None:  # Ctrl-B / Esc Esc → back out of the picker
        return None
    return set(selected)


@app.command(help=t("cmd.prepare.help"), no_args_is_help=True)
def prepare(
    mission_folder: str | None = typer.Argument(".", help=t("cmd.prepare.opt.mission_folder")),
    template: str | None = typer.Option(None, "--template", "-t", help=t("cmd.prepare.opt.template")),
    list_templates: bool = typer.Option(False, "--list-templates", help=t("cmd.prepare.opt.list_templates")),
    theatre: str | None = typer.Option(None, "--theatre", help=t("cmd.prepare.opt.theatre")),
    list_theatres: bool = typer.Option(False, "--list-theatres", help=t("cmd.prepare.opt.list_theatres")),
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

    if list_theatres:
        from veaf_libs.blank_mission import supported_theatres

        console.print(t("cmd.prepare.theatres_list", theatres=", ".join(supported_theatres())))
        return

    # Validate the theatre up front (before copying anything) so an unknown one fails cleanly.
    # Reuse the library's case-insensitive check — the single source of truth for supported maps.
    if theatre is not None:
        from veaf_libs.blank_mission import is_theatre_supported, supported_theatres

        if not is_theatre_supported(theatre):
            logger.error(t("cmd.prepare.unknown_theatre", theatre=theatre, valid=", ".join(supported_theatres())))
            raise typer.Exit(code=1)

    if readme:
        console.print(t("cmd.prepare.subtitle"))
        console.print(t("cmd.prepare.readme.intro"))
        raise typer.Exit()

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
        # Remembered overwrite decision for existing files: None = ask each time,
        # True = replace all, False = keep all. --force starts in "replace all".
        auto_replace: bool | None = True if force else None

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

                    if auto_replace is None:
                        should_replace, remember = _ask_replace(relative_path)
                        if remember:
                            auto_replace = should_replace
                    else:
                        should_replace = auto_replace

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
            console.print(tn("cmd.prepare.template_applied", len(enabled_modules), template=template))

            # A template that enables CTLD gets the matching ctld-config.yaml, seeded from
            # the vendored engine's own catalogue. Scaffold only: the build never writes
            # this file, so a mission maker's edits are theirs (ADR 0016).
            if "CTLD" in {module.upper() for module in enabled_modules}:
                _scaffold_ctld_config(p_mission_folder, defaults_source_path)

        # Lay down a synthetic blank mission for the chosen theatre into src/mission/, so the folder
        # builds without a DCS round-trip. Never clobber an existing mission unless --force.
        if theatre is not None:
            from veaf_libs.blank_mission import generate_blank_mission

            mission_dir = p_mission_folder / "src" / "mission"
            if (mission_dir / "mission").exists() and not force:
                console.print(t("cmd.prepare.theatre_skipped", path=mission_dir))
            else:
                for member_path, content in generate_blank_mission(theatre).items():
                    dest = mission_dir / member_path
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(content)
                console.print(t("cmd.prepare.theatre_applied", theatre=theatre))

        # Print summary
        console.print(t("cmd.prepare.done"))
        console.print(t("cmd.prepare.files_installed", count=files_installed))
        if files_skipped > 0:
            console.print(t("cmd.prepare.files_skipped", count=files_skipped))
        console.print(t("cmd.prepare.folder_ready", path=p_mission_folder.resolve()))
        console.print(t("cmd.prepare.next_steps"))

    except Exception as e:
        # No exit after this: `logger.error` raises typer.Abort unless told otherwise, so the call
        # that used to follow was unreachable (found while replacing the exit() builtins for
        # SECREV-2 / VMR-065).
        logger.error(t("cmd.prepare.failed", error=str(e)))
