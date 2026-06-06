import re
from datetime import datetime
from pathlib import Path

import typer
import yaml
from aircrafts_injector import AircraftGroupsInjectorWorker, AircraftGroupsYAMLValidator
from mission_builder import MissionBuilderREADME, MissionBuilderWorker
from presets_injector import PresetsInjectorWorker
from rich.markdown import Markdown
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
    profile: str | None = typer.Option(
        None,
        "--profile",
        "-p",
        help=t("cmd.build.opt.profile"),
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
    console.print(t("cmd.build.title", version=VERSION))

    if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(MissionBuilderREADME)
            console.print(md_render)
        exit()

    # Resolve input mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    # Resolve output mission — peek mission.yaml for name only
    p_output_mission = resolve_path(path=mission_name_or_file)
    if p_output_mission.suffix.lower() != ".miz":
        p_output_mission = Path(f"{mission_name_or_file}_{datetime.now().strftime('%Y%m%d')}.miz")
    mission_base_name: str = p_output_mission.stem

    mission_yaml_path = p_mission_folder / "mission.yaml"
    if mission_name_or_file == DEFAULT_MISSION_FILE and mission_yaml_path.exists():
        with mission_yaml_path.open("r", encoding="utf-8") as fh:
            _peek_yaml: dict = yaml.safe_load(fh) or {}
        _yaml_mission_name: str | None = (_peek_yaml.get("mission") or {}).get("name")
        if _yaml_mission_name:
            _safe_name = re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", _yaml_mission_name).strip(" .")
            if not _safe_name:
                logger.warning(
                    f"mission.name {_yaml_mission_name!r} contains only invalid filename characters; using 'mission'"
                )
                _safe_name = "mission"
            p_output_mission = p_mission_folder / f"{_safe_name}_{datetime.now().strftime('%Y%m%d')}.miz"
            mission_base_name = _safe_name

    # Build the mission
    worker = MissionBuilderWorker(
        dynamic_mode=dynamic_mode,
        dev_mode_override=dev_mode,
        scripts_path_override=scripts_path,
        log_modules_filter=log_modules,
        mission_folder=p_mission_folder,
        output_mission=p_output_mission,
        migrate_from_v5=migrate_from_v5,
        no_veaf_triggers=no_veaf_triggers,
        profile_name=profile,
    )
    worker.work()

    # Persist build settings to mission.yaml when relevant CLI flags were explicitly given
    if mission_yaml_path.exists() and (dev_mode is not None or scripts_path is not None):
        _update_build_config_in_yaml(
            mission_yaml_path,
            dev_mode=worker.dev_mode,
            scripts_path=worker.scripts_path,
        )
        logger.info(f"Build settings persisted to {mission_yaml_path}")

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
        step_cfg = worker.pipeline_cfg.get(key)
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
        console.print(t("pipeline.console.presets", file=presets_path.name))
        PresetsInjectorWorker(
            presets_file=presets_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        ).work()

    waypoints_path = _step_file("waypoints", "src/waypoints.yaml", "waypoints.yaml")
    if waypoints_path:
        logger.info(f"Pipeline: injecting waypoints from {waypoints_path}")
        console.print(t("pipeline.console.waypoints", file=waypoints_path.name))
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
        step_cfg = worker.pipeline_cfg.get("aircraft_groups")
        if isinstance(step_cfg, dict):
            aircraft_mode = step_cfg.get("mode", "add")
        validator = AircraftGroupsYAMLValidator(aircraft_path)
        is_valid, _ = validator.validate()
        if is_valid:
            logger.info(f"Pipeline: injecting aircraft groups from {aircraft_path} (mode={aircraft_mode})")
            console.print(t("pipeline.console.aircraft", file=aircraft_path.name, mode=aircraft_mode))
            AircraftGroupsInjectorWorker(
                input_yaml=aircraft_path,
                target_mission=p_output_mission,
                output_mission=p_output_mission,
            ).inject(mode=aircraft_mode, silent=True)
        else:
            logger.warning(f"Pipeline: aircraft groups YAML validation failed — skipping ({aircraft_path})")
            console.print(t("pipeline.console.aircraft_invalid"))
    else:
        _orphan = p_mission_folder / "src" / "aircraft-templates.yaml"
        if _orphan.exists():
            logger.warning(
                "Orphan file 'src/aircraft-templates.yaml': "
                "pipeline 'aircraft_groups' is disabled or skipped "
                "but the file still exists in your mission folder. "
                "You can safely delete it, or enable 'aircraft_groups' in mission.yaml."
            )

    weather_path = _step_file("weather", "src/missions.yaml", "src/versions.yaml", "missions.yaml")
    if weather_path:
        logger.info(f"Pipeline: injecting weather variants from {weather_path}")
        console.print(t("pipeline.console.weather", file=weather_path.name))
        weather_worker = WeatherInjectorWorker(
            config_file=weather_path,
            mission_file=p_output_mission,
            output_dir=p_mission_folder / "missions",
            mission_base_name=mission_base_name,
        )
        if created_files := weather_worker.work():
            console.print(t("pipeline.console.weather_done", count=len(created_files)))

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
