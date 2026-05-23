from datetime import datetime
from pathlib import Path

import typer
import yaml
from aircrafts_injector import AircraftGroupsInjectorWorker, AircraftGroupsYAMLValidator
from mission_builder import MissionBuilderREADME, MissionBuilderWorker
from presets_injector import PresetsInjectorWorker
from rich.markdown import Markdown
from veaf_libs import user_config as _user_config
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.paths import resolve_path
from waypoints_injector import WaypointsInjectorWorker
from weather_injector import WeatherInjectorWorker

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
from veaf_tools.helpers import _update_build_config_in_yaml


@app.command(help=t("cmd.build.help"))
def build(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    no_veaf_triggers: bool = typer.Option(False, help=t("cmd.build.opt.no_veaf_triggers")),
    dynamic_mode: bool = typer.Option(
        False,
        help=t("cmd.build.opt.dynamic_mode"),
    ),
    dev_mode: bool | None = typer.Option(
        None,
        "--dev-mode/--no-dev-mode",
        help=t("cmd.build.opt.dev_mode"),
    ),
    scripts_path: str = typer.Option(
        None,
        help=t("cmd.build.opt.scripts_path"),
    ),
    migrate_from_v5: bool = typer.Option(True, help=t("cmd.build.opt.migrate_from_v5")),
    log_modules: str | None = typer.Option(
        None,
        help=t("cmd.build.opt.log_modules_detail"),
    ),
    mission_name_or_file: str | None = typer.Argument(
        DEFAULT_MISSION_FILE,
        help=t("cmd.build.opt.mission_name_or_file"),
    ),
    mission_folder: str | None = typer.Argument(".", help=t("cmd.build.opt.folder")),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:

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

    # Resolve dev_mode and scripts_path: CLI flags > mission.yaml > ~/veafmct.yaml > code defaults
    effective_dev_mode: bool = dev_mode if dev_mode is not None else bool(build_cfg.get("dev_mode", False))
    if effective_dev_mode:
        logger.info("Dev mode: VEAF scripts resolved from local dev repo (build/veaf-scripts.lua)")

    _uc_sp = _user_config.get_scripts_path()
    effective_scripts_path_str: str | None = (
        scripts_path or build_cfg.get("scripts_path") or (str(_uc_sp) if _uc_sp else None)
    )
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
