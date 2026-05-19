"""
This program provides a command-line interface (CLI) tool for managing DCS missions.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools.log' file.

Usage:
- Run the script with 'veaf-tools.exe' to access the CLI.
- Use the 'about' command to learn about the VEAF and this program.
- Use the 'inject-presets' command to inject radio presets into a mission file.
- Use the 'build-mission' command to build a .miz file from a VEAF mission folder.

Example:
- To inject presets into a mission file:
      'python veaf-tools.py inject-presets --verbose --presets-file my_presets.yaml my_mission.miz my_output.miz'

All the commands feature both `--help` and `--readme` options that display online help.
"""

import shutil
from datetime import datetime
from pathlib import Path

import typer
import yaml
from aircrafts_injector import (
    AircraftGroupsExtractorREADME,
    AircraftGroupsExtractorWorker,
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
)
from mission_builder import (
    PIPELINE_CANDIDATES,
    ConfigMigrator,
    ConversionReport,
    MigrationResult,
    MissionBuilderREADME,
    MissionBuilderWorker,
    V5Converter,
)
from mission_converter import MissionConverterREADME, MissionConverterWorker
from mission_extractor import MissionExtractorREADME, MissionExtractorWorker
from presets_injector import PresetsInjectorREADME, PresetsInjectorWorker
from rich.markdown import Markdown
from rich.table import Table
from veaf_libs.i18n import set_language, t
from veaf_libs.logger import console, logger
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.tui import run_wizard
from veaf_libs.update_checker import check_for_updates
from waypoints_injector import (
    WaypointsExtractorREADME,
    WaypointsExtractorWorker,
    WaypointsInjectorREADME,
    WaypointsInjectorWorker,
)
from weather_injector import LuaToYamlConverter, WeatherInjectorWorker, WheatherInjectorREADME

VERSION: str = "6.0.4"
README_HELP: str = t("help.readme")
PAUSE_HELP: str = t("help.pause")
VERBOSE_HELP: str = t("help.verbose")

# String constants
DEFAULT_MISSION_FILE = "mission.miz"
DEFAULT_PRESETS_FILE = "./src/presets.yaml"

app = typer.Typer(no_args_is_help=True)


@app.callback()
def main_callback(
    lang: str | None = typer.Option(None, "--lang", help=t("help.lang")),
) -> None:
    """VEAF Tools — DCS World mission management CLI."""
    if lang:
        set_language(lang)
    check_for_updates(VERSION, console)


def resolve_path(
    path: str | Path | None = None,
    default_path: str | Path | None = None,
    should_exist: bool = False,
    create_if_not_exist: bool = False,
) -> Path:
    """Resolve and validate a file path."""
    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        logger.error(message="Either path or default_path must be provided", exception_type=ValueError)

    result = result.resolve()

    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:
            # It's a directory
            result.mkdir(exist_ok=True)

    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)

    return result


def _read_single_char() -> str:
    """Read one character from the console without waiting for Enter (Windows/Unix)."""
    try:
        import msvcrt

        ch = msvcrt.getwch()
        if ch in ("\x00", "\xe0"):
            msvcrt.getwch()  # consume second byte of special key
            return ""
        if ch == "\x03":  # Ctrl-C
            raise KeyboardInterrupt
        return ch
    except ImportError:
        # Unix fallback (not expected in production, but keeps tests runnable)
        import termios
        import tty

        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            return sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)


def _ask_replace(relative_path: Path) -> tuple[bool, bool]:
    """Prompt to replace an existing file. Returns (should_replace, yes_to_all)."""
    sys.stdout.write(t("file.already_exists", path=relative_path) + "\n")
    while True:
        sys.stdout.write(t("file.replace_prompt"))
        sys.stdout.flush()
        try:
            ch = _read_single_char().lower()
        except KeyboardInterrupt:
            sys.stdout.write("\n")
            return False, False
        sys.stdout.write(ch + "\n")
        if ch in ("a", "t"):  # 'a' (EN) or 't' for "tous" (FR)
            return True, True
        if ch in ("y", "o"):  # 'y' (EN) or 'o' for "oui" (FR)
            return True, False
        if ch in ("n", "\r", "\n", ""):
            return False, False
        sys.stdout.write(t("file.replace_hint") + "\n")


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
        install_source = Path(__file__).parent

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


@app.command()
def about(
    modules: bool = typer.Option(False, "--modules", help="Show the list of embedded VEAF Lua modules."),
) -> None:
    """
    Shows information about the veaf-tools program.
    """
    if modules:
        mod_list = get_modules()
        if not mod_list:
            console.print(
                "[yellow]No module information available (run from a full repo checkout or built exe).[/yellow]"
            )
            return
        table = Table(title=f"VEAF Lua Modules ({len(mod_list)} total)")
        table.add_column("ID", style="cyan", no_wrap=True)
        table.add_column("Version", style="green")
        table.add_column("File", style="dim")
        for mod in mod_list:
            table.add_row(mod["id"], mod["version"], mod["filename"])
        console.print(table)
        return

    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print(
        "The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World."
    )
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)


# ── Build-config persistence helpers ─────────────────────────────────────────

_BUILD_CONFIG_MARKER = "# ── Build configuration"


def _update_build_config_in_yaml(yaml_path: Path, dev_mode: bool, scripts_path: Path | None) -> None:
    """Update (or append) the ``build:`` section in *mission.yaml*.

    Uses a text-based replacement so all other comments in the file are preserved.
    The section is identified by the ``_BUILD_CONFIG_MARKER`` header line.
    """
    lines: list[str] = [
        "",
        "# ── Build configuration ─────────────────────────────────────────────────────",
        "# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.",
        "# Note: scripts_path is usually machine-specific.",
        "#",
        "build:",
        f"  dev_mode: {'true' if dev_mode else 'false'}",
    ]
    if scripts_path:
        lines.append(f'  scripts_path: "{scripts_path.as_posix()}"')
    new_section = "\n".join(lines) + "\n"

    content = yaml_path.read_text(encoding="utf-8")
    # Replace existing build: section if present (identified by the marker), or append
    idx = content.find("\n" + _BUILD_CONFIG_MARKER)
    if idx >= 0:
        content = content[:idx]
    content = content.rstrip("\n") + "\n" + new_section
    yaml_path.write_text(content, encoding="utf-8")


@app.command()
def build(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    no_veaf_triggers: bool = typer.Option(
        False, help="If set, the VEAF triggers will not be injected in the resulting mission."
    ),
    dynamic_mode: bool = typer.Option(
        False,
        help="If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders).",
    ),
    dev_mode: bool | None = typer.Option(
        None,
        "--dev-mode/--no-dev-mode",
        help=(
            "Resolve VEAF scripts from a local dev repo (build/veaf-scripts.lua) instead of published/. "
            "Requires --scripts-path pointing to the VEAF-Mission-Creation-Tools repo root. "
            "This setting is persisted in mission.yaml (build.dev_mode)."
        ),
    ),
    scripts_path: str = typer.Option(
        None,
        help="Path to the VEAF and community scripts. Persisted in mission.yaml (build.scripts_path).",
    ),
    migrate_from_v5: bool = typer.Option(
        True, help="If set, the builder will parse the mission for old v5 triggers and remove them."
    ),
    log_modules: str | None = typer.Option(
        None,
        help=(
            "Comma-separated list of module IDs to keep at full log level. "
            "All other modules are silenced to 'error' level. "
            "Example: --log-modules 'SPAWN - ,RADIO - '"
        ),
    ),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will build the mission with this name and the current date; can be set to a .miz file.",
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Builds a DCS mission based on a mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission builder v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(MissionBuilderREADME)
            console.print(md_render)
        exit()

    # Resolve input mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve output mission
    p_output_mission = resolve_path(path=mission_name_or_file)
    if p_output_mission.suffix.lower() != ".miz":
        p_output_mission = Path(f"{mission_name_or_file}_{datetime.now().strftime('%Y%m%d')}.miz")

    # Read mission.yaml: lua_modules (LUA-005), global_log_level (LUA-007), pipeline (TOOL-pipeline), build
    lua_modules: dict | None = None
    global_log_level: str | None = None
    pipeline_cfg: dict = {}
    build_cfg: dict = {}
    mission_yaml: dict = {}
    mission_yaml_path = p_mission_folder / "mission.yaml"
    if mission_yaml_path.exists():
        with mission_yaml_path.open("r", encoding="utf-8") as fh:
            mission_yaml = yaml.safe_load(fh) or {}
        lua_modules = mission_yaml.get("lua_modules") or None
        if lua_modules:
            logger.info(f"Found lua_modules section in {mission_yaml_path}; will generate veaf-config.lua")
        global_log_level = mission_yaml.get("global_log_level") or None
        if global_log_level:
            logger.info(f"Found global_log_level={global_log_level!r} in {mission_yaml_path}")
        pipeline_cfg = mission_yaml.get("pipeline") or {}
        build_cfg = mission_yaml.get("build") or {}

    # Resolve dev_mode and scripts_path: CLI flags > mission.yaml defaults > code defaults
    effective_dev_mode: bool = dev_mode if dev_mode is not None else bool(build_cfg.get("dev_mode", False))
    if effective_dev_mode:
        logger.info("Dev mode: VEAF scripts resolved from local dev repo (build/veaf-scripts.lua)")

    effective_scripts_path_str: str | None = scripts_path or build_cfg.get("scripts_path") or None
    effective_scripts_input: str | Path | None = effective_scripts_path_str
    if not effective_scripts_input and dynamic_mode:
        # default value is the "published" subfolder of the mission folder
        effective_scripts_input = p_mission_folder / "published"
    if effective_scripts_input:
        p_scripts_path = resolve_path(path=effective_scripts_input, should_exist=True)
        if not p_scripts_path.exists():
            logger.error(f"Scripts folder {p_scripts_path} does not exist!", exception_type=FileNotFoundError)
    else:
        p_scripts_path = None

    if effective_dev_mode and not p_scripts_path:
        logger.error(
            "--dev-mode requires a scripts path. "
            "Pass --scripts-path <repo_root> or set build.scripts_path in mission.yaml.",
            exception_type=ValueError,
        )

    # Persist build settings to mission.yaml when relevant CLI flags were explicitly given
    if mission_yaml_path.exists() and (dev_mode is not None or scripts_path is not None):
        _update_build_config_in_yaml(
            mission_yaml_path,
            dev_mode=effective_dev_mode,
            scripts_path=p_scripts_path,
        )
        logger.info(f"Build settings persisted to {mission_yaml_path}")

    # Apply --log-modules filter: silence all modules not in the keep list (LUA-006)
    if log_modules is not None:
        keep_modules = {m.strip() for m in log_modules.split(",") if m.strip()}
        all_module_ids = {m["id"] for m in get_modules()}
        if unknown := keep_modules - all_module_ids:
            logger.warning(f"--log-modules: unknown module ID(s): {sorted(unknown)} — check spelling")
        lua_modules = lua_modules or {}
        for mod_id in all_module_ids:
            if mod_id not in keep_modules:
                if mod_id not in lua_modules:
                    lua_modules[mod_id] = {}
                lua_modules[mod_id].setdefault("logLevel", "error")
        logger.info(
            f"--log-modules: keeping full logging for {sorted(keep_modules) or 'none'}, "
            f"silencing {len(all_module_ids) - len(keep_modules)} other module(s)"
        )

    # Call the worker class
    worker = MissionBuilderWorker(
        dynamic_mode=dynamic_mode,
        scripts_path=p_scripts_path,
        dev_mode=effective_dev_mode,
        mission_folder=p_mission_folder,
        output_mission=p_output_mission,
        migrate_from_v5=migrate_from_v5,
        no_veaf_triggers=no_veaf_triggers,
        lua_modules=lua_modules,
        global_log_level=global_log_level,
        mission_yaml=mission_yaml if mission_yaml_path.exists() else None,
    )
    worker.work()

    # ── Auto-pipeline: run optional injection steps ───────────────────────────
    # Each step is auto-enabled when its config file is found in src/.
    # Override in mission.yaml under the `pipeline:` key.
    #   pipeline:
    #     presets: false              # disable even if src/presets.yaml exists
    #     waypoints:
    #       file: custom/wp.yaml     # use a non-default path
    #     aircraft_groups:
    #       mode: replace            # add (default) or replace
    #     weather: false

    def _step_file(key: str, *candidates: str) -> Path | None:
        """Return the resolved file for a pipeline step, or None to skip."""
        step_cfg = pipeline_cfg.get(key)
        if step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False):
            return None
        if isinstance(step_cfg, dict) and "file" in step_cfg:
            p = p_mission_folder / step_cfg["file"]
            return p if p.exists() else None
        for candidate in candidates:
            p = p_mission_folder / candidate
            if p.exists():
                return p
        return None

    presets_path = _step_file("presets", "src/presets.yaml")
    if presets_path:
        logger.info(f"Pipeline: injecting radio presets from {presets_path}")
        console.print(f"[bold blue]Pipeline: radio presets ({presets_path.name})[/bold blue]")
        PresetsInjectorWorker(
            presets_file=presets_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        ).work()

    waypoints_path = _step_file("waypoints", "src/waypoints.yaml", "waypoints.yaml")
    if waypoints_path:
        logger.info(f"Pipeline: injecting waypoints from {waypoints_path}")
        console.print(f"[bold blue]Pipeline: waypoints ({waypoints_path.name})[/bold blue]")
        WaypointsInjectorWorker(
            waypoints_file=waypoints_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        ).work()

    aircraft_path = _step_file(
        "aircraft_groups", "src/aircraft-templates.yaml", "src/templates.yaml", "aircraft-templates.yaml"
    )
    if aircraft_path:
        aircraft_mode = "add"
        step_cfg = pipeline_cfg.get("aircraft_groups")
        if isinstance(step_cfg, dict):
            aircraft_mode = step_cfg.get("mode", "add")
        validator = AircraftGroupsYAMLValidator(aircraft_path)
        is_valid, _ = validator.validate()
        if is_valid:
            logger.info(f"Pipeline: injecting aircraft groups from {aircraft_path} (mode={aircraft_mode})")
            console.print(
                f"[bold blue]Pipeline: aircraft groups ({aircraft_path.name}, mode={aircraft_mode})[/bold blue]"
            )
            AircraftGroupsInjectorWorker(
                input_yaml=aircraft_path,
                target_mission=p_output_mission,
                output_mission=p_output_mission,
            ).inject(mode=aircraft_mode, silent=True)
        else:
            logger.warning(f"Pipeline: aircraft groups YAML validation failed — skipping ({aircraft_path})")
            console.print("[bold yellow]Pipeline: aircraft groups validation failed, skipping[/bold yellow]")

    weather_path = _step_file("weather", "src/missions.yaml", "src/versions.yaml", "missions.yaml")
    if weather_path:
        logger.info(f"Pipeline: injecting weather variants from {weather_path}")
        console.print(f"[bold blue]Pipeline: weather variants ({weather_path.name})[/bold blue]")
        weather_worker = WeatherInjectorWorker(config_file=weather_path, mission_file=p_output_mission)
        if created_files := weather_worker.work():
            console.print(f"[bold green]Pipeline: created {len(created_files)} weather variant(s)[/bold green]")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True)
def extract(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    mission_folder: str | None = typer.Argument(".", help="Folder where the mission files will be extracted."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts a DCS mission .miz file to a VEAF mission folder.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools VEAF mission extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(MissionExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), create_if_not_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve input mission
    assert mission_name_or_file is not None
    p_input_mission: str | Path | None = mission_name_or_file
    if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Call the worker class
    worker = MissionExtractorWorker(mission_folder=p_mission_folder, input_mission_path=p_input_mission)
    worker.work()

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


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


@app.command(no_args_is_help=True)
def inject_presets(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    input_mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject in the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    presets_file: str = typer.Option(DEFAULT_PRESETS_FILE, help="Configuration file containing the presets."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects radio presets read from a configuration file into aircraft groups from a DCS mission
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Radio Presets Injector v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(PresetsInjectorREADME)
            console.print(md_render)
        exit()

    # Resolve input mission
    assert input_mission_name_or_file is not None
    p_input_mission: str | Path | None = input_mission_name_or_file
    if not input_mission_name_or_file.lower().endswith(".miz"):
        if files := list(Path.cwd().glob(f"{input_mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
    p_input_mission = resolve_path(path=p_input_mission, should_exist=True)

    # Resolve output mission
    p_output_mission = resolve_path(path=output_mission, default_path=p_input_mission)

    # Resolve presets configuration file
    p_presets_file = resolve_path(path=presets_file, should_exist=True)
    if not p_presets_file.exists():
        logger.error(f"Configuration file {p_presets_file} does not exist!", exception_type=FileNotFoundError)

    # Call the worker class
    worker = PresetsInjectorWorker(
        presets_file=p_presets_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


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


@app.command(no_args_is_help=True)
def extract_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    interactive: bool = typer.Option(False, help="Interactive mode: select which groups to extract."),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_yaml: str = typer.Option("waypoints.yaml", help="Output YAML file path."),
    group_name_pattern: str = typer.Option(".*", help="Regular expression pattern to match waypoint/group names."),
    only_airplanes: bool = typer.Option(False, help="Extract only airplanes."),
    only_helicopters: bool = typer.Option(False, help="Extract only helicopters."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    lua_input: str | None = typer.Option(
        None, help="Path to a Lua file (e.g., settings-waypoints.lua) to extract from instead of a .miz mission."
    ),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Extracts waypoints matching a pattern from a DCS mission or Lua settings file and writes them to a YAML file.
    """

    logger.set_verbose(verbose)

    # Validate exclusive options
    if only_airplanes and only_helicopters:
        logger.error(
            "Cannot use both --only-airplanes and --only-helicopters simultaneously.", exception_type=ValueError
        )

    # Convert boolean options to aircraft_type (using 'plane'/'helicopter' naming for waypoints)
    aircraft_type = "plane" if only_airplanes else ("helicopter" if only_helicopters else None)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Waypoints Extractor v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WaypointsExtractorREADME)
            console.print(md_render)
        exit()

    # Resolve mission folder and output YAML file
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    p_output_yaml = resolve_path(
        path=output_yaml, default_path=p_mission_folder / output_yaml, create_if_not_exist=True
    )

    # Handle Lua input or mission input
    if lua_input:
        # Extract from Lua file
        p_lua_input = resolve_path(path=lua_input, should_exist=True)
        worker = WaypointsExtractorWorker(
            input_lua=p_lua_input,
            output_yaml=p_output_yaml,
            group_name_pattern=group_name_pattern,
            aircraft_type=aircraft_type,
        )
    else:
        # Extract from mission file
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
        worker = WaypointsExtractorWorker(
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
def inject_waypoints(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help="Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file.",
    ),
    output_mission: str | None = typer.Argument(
        None, help="Mission file to save; defaults to the same as 'input_mission'."
    ),
    waypoints_file: str = typer.Option("waypoints.yaml", help="Path to the YAML file containing waypoint definitions."),
    mission_folder: str | None = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Injects waypoints from a YAML file into a DCS mission.
    Only human-piloted aircraft groups will receive waypoints.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Waypoints Injector v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WaypointsInjectorREADME)
            console.print(md_render)
        exit()

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

    # Resolve waypoints YAML file
    p_waypoints_file = resolve_path(path=waypoints_file, should_exist=True)
    if not p_waypoints_file.exists():
        logger.error(f"Waypoints file {p_waypoints_file} does not exist!", exception_type=FileNotFoundError)

    # Call the worker class
    worker = WaypointsInjectorWorker(
        waypoints_file=p_waypoints_file, input_mission=p_input_mission, output_mission=p_output_mission
    )
    worker.work()

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True)
def inject_weather(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE, help="Mission name or .miz file to use as base for creating weather/time variants."
    ),
    config_file: str = typer.Option("missions.yaml", help="Path to YAML configuration file (or Lua file to convert)."),
    convert_lua: bool = typer.Option(False, "--convert-lua", help="Convert legacy Lua configuration to YAML and exit"),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Creates multiple versions of a DCS mission with different weather conditions and start times.
    Uses a YAML configuration file to define mission variants.
    Can also convert legacy Lua configurations to YAML format.
    """

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools Weather and Time Versions v{VERSION}[/bold green]")

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(WheatherInjectorREADME)
            console.print(md_render)
        exit()

    p_config_file = resolve_path(path=config_file, should_exist=True)

    # Handle Lua conversion
    if convert_lua or p_config_file.suffix.lower() == ".lua":
        logger.info(f"Converting Lua configuration: {p_config_file}")
        if yaml_file := LuaToYamlConverter.convert_file(p_config_file):
            console.print("[bold green]Lua configuration converted to YAML:[/bold green]")
            console.print(f"  {yaml_file}")
            if typer.confirm("Do you want to create missions from this configuration?"):
                p_config_file = yaml_file
            else:
                if pause:
                    input(t("help.pause_msg"))
                return
        else:
            logger.error("Failed to convert Lua configuration")
            if pause:
                input(t("help.pause_msg"))
            return

    if not p_config_file.exists():
        logger.error(f"Configuration file {p_config_file} does not exist!", exception_type=FileNotFoundError)

    # Resolve mission file path
    p_mission_file = resolve_path(path=mission_name_or_file, should_exist=True)

    # Call the worker class
    worker = WeatherInjectorWorker(config_file=p_config_file, mission_file=p_mission_file)
    if created_files := worker.work():
        console.print(f"[bold green]Created {len(created_files)} mission files[/bold green]")
        for file_path in created_files:
            console.print(f"  - {file_path.name}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command()
def generate_config(
    output: str = typer.Option(".", help="Output directory for the generated mission.yaml template."),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Generates a mission.yaml template with all available module configuration options.

    The generated file can be placed at the root of your mission folder and renamed to
    ``mission.yaml``. Uncomment and adjust any section you want to configure.
    """
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Generate Config v{VERSION}[/bold green]")

    p_output = resolve_path(path=output, create_if_not_exist=True)

    modules = get_modules()
    if not modules:
        logger.error("No VEAF Lua module information available. Run from a full repo checkout.")
        return

    from veaf_libs.lua_config_generator import generate_mission_yaml_template

    content = generate_mission_yaml_template(modules=modules)
    output_file = p_output / "mission.yaml"
    output_file.write_text(content, encoding="utf-8")
    console.print(f"[bold green]Generated:[/bold green] {output_file}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True)
def migrate_config(
    input_file: str = typer.Argument(..., help="Path to the missionConfig.lua to migrate (v5 → v6)."),
    output: str | None = typer.Option(
        None,
        help="Output path for the migrated file. Defaults to <input>_v6.lua next to the input.",
    ),
    yaml_output: str | None = typer.Option(
        None,
        "--yaml-output",
        help="Write the lua_modules YAML snippet to this file instead of printing it.",
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Migrate a v5-style missionConfig.lua to the v6 format.

    Transformations applied:

    - ``doFile(...)`` calls loading VEAF scripts are commented out; the v6
      builder injects all scripts automatically via ``veaf-scripts.lua``.

    - Bare ``veafXxx.initialize(...)`` calls at the top level (outside an
      ``if veafXxx then … end`` guard) are wrapped in the guard.

    The command also outputs a ``lua_modules:`` YAML snippet that you can paste
    into your ``mission.yaml`` to document (and later fine-tune) which modules
    are enabled.
    """
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Migrate Config v{VERSION}[/bold green]")

    p_input = resolve_path(path=input_file, should_exist=True)
    if not p_input.exists():
        logger.error(f"Input file not found: {p_input}", exception_type=FileNotFoundError)
        return

    # Default output path: <stem>_v6.lua in the same directory.
    if output is None:
        p_output = p_input.parent / f"{p_input.stem}_v6{p_input.suffix}"
    else:
        p_output = resolve_path(path=output)

    console.print(f"Input : {p_input}")
    console.print(f"Output: {p_output}")

    content = p_input.read_text(encoding="utf-8")
    migrator = ConfigMigrator()
    result: MigrationResult = migrator.migrate(content)

    # Write the migrated Lua file.
    p_output.write_text(result.new_content, encoding="utf-8")

    # Report changes.
    if result.removed_dofiles:
        console.print(f"\n[yellow]Commented out {len(result.removed_dofiles)} doFile() call(s):[/yellow]")
        for item in result.removed_dofiles:
            console.print(f"  • {item}")

    if result.wrapped_calls:
        console.print(f"\n[yellow]Wrapped {len(result.wrapped_calls)} bare initialize() call(s):[/yellow]")
        for item in result.wrapped_calls:
            console.print(f"  • {item}")

    if result.warnings:
        console.print("\n[bold yellow]Warnings (manual review needed):[/bold yellow]")
        for w in result.warnings:
            console.print(f"  ⚠  {w}")

    if result.enabled_modules:
        console.print(
            f"\n[bold cyan]Modules found ({len(result.enabled_modules)}):[/bold cyan] "
            + ", ".join(result.enabled_modules)
        )
    else:
        console.print("\n[yellow]No VEAF module initialize() calls found.[/yellow]")

    # YAML snippet.
    if yaml_output:
        p_yaml = resolve_path(path=yaml_output)
        p_yaml.write_text(result.yaml_snippet, encoding="utf-8")
        console.print(f"\n[bold cyan]lua_modules YAML snippet written to:[/bold cyan] {p_yaml}")
    else:
        console.print("\n[bold cyan]lua_modules YAML snippet (paste into mission.yaml):[/bold cyan]")
        console.print(result.yaml_snippet)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True)
def convert_v5(
    mission_folder: str = typer.Argument(
        ".",
        help="Path to the VEAF mission folder to convert (where mission.yaml should be created).",
    ),
    force: bool = typer.Option(
        False,
        "--force",
        help="Overwrite existing mission.yaml without asking.",
    ),
    no_backup: bool = typer.Option(
        False,
        "--no-backup",
        help="Do not create a .bak copy of missionConfig.lua before migrating it.",
    ),
    no_convert_pipeline: bool = typer.Option(
        False,
        "--no-convert-pipeline",
        help=(
            "Skip automatic conversion of v5 pipeline config files "
            "(presets, waypoints, weather, aircraft groups). "
            "Files will be listed as needing manual conversion instead."
        ),
    ),
    report_file: str | None = typer.Option(
        None,
        "--report-file",
        help=("Save the conversion report to a Markdown file. Defaults to <mission_folder>/convert-v5-report.md."),
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """
    Convert a v5-style VEAF mission folder to v6 format.

    Runs all migration steps in a single pass:

    \\b
    1. Scans the mission folder for v5 artifacts (missionConfig.lua, pipeline
       config files such as presets.yaml, waypoints.yaml, …).
    2. Migrates missionConfig.lua in-place: comments out doFile() calls that
       load VEAF scripts (the v6 builder injects them automatically), and wraps
       bare veafXxx.initialize() calls in ``if veafXxx then … end`` guards.
    3. Generates mission.yaml with the correct lua_modules: and pipeline:
       sections derived from the analysis in steps 1 and 2.
    4. Prints a detailed conversion report and optionally saves it as Markdown.

    DCS trigger conversion (v5 → v6) is handled automatically by
    ``veaf-tools build`` — no manual action is required for that part.
    """
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Convert v5 Mission v{VERSION}[/bold green]")

    p_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_folder.is_dir():
        logger.error(f"Mission folder does not exist: {p_folder}", exception_type=FileNotFoundError)

    # If mission.yaml exists and --force was not given, ask interactively.
    mission_yaml = p_folder / "mission.yaml"
    overwrite_yaml = force
    if mission_yaml.exists() and not force:
        console.print(
            f"\n[yellow]mission.yaml already exists:[/yellow] {mission_yaml}\n"
            "  Use [bold]--force[/bold] to overwrite, or continue to skip generation."
        )
        if typer.confirm("  Overwrite existing mission.yaml?", default=False):
            overwrite_yaml = True

    # Run the converter
    converter = V5Converter(version=VERSION)

    # Build ICAO callback for realweather steps (lazy prompt, asked at most once)
    _icao_cache: list[str] = []

    def icao_cb(version_name: str) -> str:
        if not _icao_cache:
            console.print(f"\n[yellow]Weather version '[bold]{version_name}[/bold]' uses realweather.[/yellow]")
            icao = (
                typer.prompt(
                    "  Enter ICAO airport code (e.g. UGGG), or leave empty to fill in later",
                    default="",
                )
                .strip()
                .upper()
            )
            _icao_cache.append(icao)
        return _icao_cache[0]

    report: ConversionReport = converter.convert(
        mission_folder=p_folder,
        overwrite_mission_yaml=overwrite_yaml,
        backup=not no_backup,
        convert_pipeline=not no_convert_pipeline,
        icao_callback=icao_cb if not no_convert_pipeline else None,
    )

    # ── Console output ────────────────────────────────────────────────────────
    console.print(f"\n[bold cyan]Mission folder:[/bold cyan] {p_folder}")
    console.print("")

    # Scan summary table
    scan_table = Table(title="Scan Results", show_header=True)
    scan_table.add_column("Item", style="cyan")
    scan_table.add_column("Status")

    if report.missionconfig_path:
        rel = report.missionconfig_path.relative_to(p_folder)
        scan_table.add_row(str(rel), "[green]✓ Found — migrated[/green]")
    else:
        scan_table.add_row("src/scripts/missionConfig.lua", "[yellow]✗ Not found — skipped[/yellow]")

    if report.mission_yaml_existed and not report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", "[yellow]⚠ Already exists — not overwritten[/yellow]")
    elif report.mission_yaml_generated:
        scan_table.add_row("mission.yaml", "[green]✓ Generated[/green]")
    else:
        scan_table.add_row("mission.yaml", "[red]✗ Not generated[/red]")

    for step, v6_candidates in PIPELINE_CANDIDATES.items():
        if any(pf.step == step for pf in report.pipeline_files):
            pf = next(pf for pf in report.pipeline_files if pf.step == step)
            if pf.converted:
                scan_table.add_row(
                    pf.v5_source or pf.v6_target,
                    f"[green]✓ Converted → {pf.v6_target}[/green]",
                )
            elif pf.needs_conversion:
                scan_table.add_row(
                    pf.relative,
                    f"[yellow]⚠ v5 format — needs conversion to {pf.v6_target}[/yellow]",
                )
            else:
                scan_table.add_row(pf.relative, f"[green]✓ Found — added to pipeline:[/green] {step}")
        else:
            scan_table.add_row(v6_candidates[0], f"[dim]✗ Not found — {step} step will be skipped[/dim]")

    console.print(scan_table)
    console.print("")

    # Actions
    if report.actions:
        console.print("[bold cyan]Actions taken:[/bold cyan]")
        for action in report.actions:
            console.print(f"  [green]✓[/green] {action}")
        console.print("")

    # missionConfig detail
    if report.migration_result:
        mr = report.migration_result
        if mr.removed_dofiles:
            console.print(f"[yellow]Commented out {len(mr.removed_dofiles)} doFile() call(s):[/yellow]")
            for item in mr.removed_dofiles:
                console.print(f"  • {item}")
            console.print("")
        if mr.wrapped_calls:
            console.print(f"[yellow]Wrapped {len(mr.wrapped_calls)} bare initialize() call(s):[/yellow]")
            for item in mr.wrapped_calls:
                console.print(f"  • {item}")
            console.print("")
        if mr.enabled_modules:
            console.print(
                f"[bold cyan]Enabled modules ({len(mr.enabled_modules)}):[/bold cyan] " + ", ".join(mr.enabled_modules)
            )
            console.print("")

    # Warnings
    if report.warnings:
        console.print(f"[bold yellow]⚠  Warnings ({len(report.warnings)}):[/bold yellow]")
        for w in report.warnings:
            console.print(f"  [yellow]•[/yellow] {w}")
        console.print("")

    # Manual review
    if report.manual_review:
        console.print("[bold yellow]Manual review required:[/bold yellow]")
        for item in report.manual_review:
            console.print(f"  [yellow]→[/yellow] {item}")
        console.print("")

    # Next steps
    converted_files = [pf for pf in report.pipeline_files if pf.converted]
    needs_conversion = [pf for pf in report.pipeline_files if pf.needs_conversion]
    console.print("[bold cyan]Next steps:[/bold cyan]")
    step_num = 1
    console.print(f"  {step_num}. Review [cyan]mission.yaml[/cyan] and adjust module settings as needed.")
    step_num += 1
    if converted_files:
        console.print(
            f"  {step_num}. Review the {len(converted_files)} converted config file(s) in your mission folder."
        )
        step_num += 1
    if needs_conversion:
        console.print(
            f"  {step_num}. Manually convert the {len(needs_conversion)} v5 config file(s) listed above "
            "(or re-run without [bold]--no-convert-pipeline[/bold])."
        )
        step_num += 1
    console.print(f"  {step_num}. Run [cyan]veaf-tools build[/cyan] — DCS trigger conversion runs automatically.")
    step_num += 1
    console.print(f"  {step_num}. Test the mission in DCS.")
    step_num += 1
    if report.manual_review:
        console.print(f"  {step_num}. Clean up the items listed above once everything works.")
    console.print("")

    # ── Save report file ──────────────────────────────────────────────────────
    if report_file is not None:
        p_report = resolve_path(path=report_file)
    else:
        p_report = p_folder / "convert-v5-report.md"

    markdown_report = report.to_markdown()
    p_report.write_text(markdown_report, encoding="utf-8")
    console.print(f"[bold green]Conversion report saved:[/bold green] {p_report}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


if __name__ == "__main__":
    import sys

    # When launched with no arguments in an interactive terminal, run the wizard.
    if len(sys.argv) == 1 and sys.stdout.isatty():
        if wizard_args := run_wizard():
            sys.argv = sys.argv[:1] + wizard_args

    app()
