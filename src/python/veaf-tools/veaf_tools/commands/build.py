import re
from datetime import datetime
from pathlib import Path

import typer
import yaml
from aircrafts_injector import AircraftGroupsInjectorWorker, AircraftGroupsYAMLValidator
from mission_builder import MissionBuilderREADME, MissionBuilderWorker
from presets_injector import PresetsInjectorWorker
from rich.markdown import Markdown
from spawn_data_injector import SpawnDataInjectorWorker
from veaf_libs.paths import resolve_path
from veaf_libs.yaml_validator import validate_yaml_file
from warehouses_injector import WarehousesInjectorWorker
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


def _resolve_output_mission(
    mission_name_or_file: str | None,
    p_mission_folder: Path,
    default_mission_file: str,
) -> tuple[Path, str]:
    """Resolve the output ``.miz`` path and its base name for a build.

    - An explicit ``*.miz`` argument is used as-is (absolute, or relative to the
      current directory).
    - A bare mission name yields ``<sanitized-name>_<date>.miz`` anchored in
      *p_mission_folder* (absolute). When the argument is the default and a
      ``mission.yaml`` is present, its ``mission.name`` field supplies the name.

    Anchoring a bare-name output in the mission folder keeps the path absolute so
    every pipeline step (build, presets, weather, …) agrees on its location.

    Args:
        mission_name_or_file: The CLI argument (mission name, ``.miz`` file, or
            the default sentinel).
        p_mission_folder: The resolved mission folder.
        default_mission_file: The sentinel default value (e.g. ``mission.miz``).

    Returns:
        A tuple of (output mission path, mission base name).
    """
    name_source: str = mission_name_or_file or default_mission_file

    # When the default is used, prefer the mission.yaml name if available.
    if name_source == default_mission_file:
        mission_yaml_path = p_mission_folder / "mission.yaml"
        if mission_yaml_path.exists():
            validate_yaml_file(mission_yaml_path)
            with mission_yaml_path.open("r", encoding="utf-8") as fh:
                peek_yaml: dict = yaml.safe_load(fh) or {}
            if yaml_name := (peek_yaml.get("mission") or {}).get("name"):
                name_source = str(yaml_name)

    # An explicit .miz file is used directly; a bare name becomes
    # "<name>_<date>.miz" inside the mission folder.
    if name_source.lower().endswith(".miz"):
        p_output_mission = resolve_path(path=name_source)
        return p_output_mission, p_output_mission.stem

    safe_name = re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", name_source).strip(" .")
    if not safe_name:
        logger.warning(t("cmd.build.invalid_mission_name", name=repr(name_source)))
        safe_name = "mission"
    p_output_mission = p_mission_folder / f"{safe_name}_{datetime.now().strftime('%Y%m%d')}.miz"
    return p_output_mission, safe_name


def resolve_pipeline_step_file(pipeline_cfg: dict, mission_folder: Path, key: str, *candidates: str) -> Path | None:
    """Resolve the input file for a pipeline step, or ``None`` to skip it.

    A step is skipped when it is ``false`` or ``{enabled: false}``. A custom
    ``{file: …}`` path wins; otherwise the first existing default candidate is used.

    Args:
        pipeline_cfg: The ``pipeline:`` mapping from mission.yaml.
        mission_folder: The mission folder the candidates are resolved against.
        key: The pipeline step key (e.g. ``spawnable_aircrafts``).
        candidates: Default file paths (relative to *mission_folder*), tried in order.

    Returns:
        The resolved existing path, or ``None`` when the step is disabled or no file exists.
    """
    step_cfg = pipeline_cfg.get(key)
    if step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False):
        return None
    if isinstance(step_cfg, dict) and "file" in step_cfg:
        p = mission_folder / step_cfg["file"]
        return p if p.exists() else None
    for candidate in candidates:
        p = mission_folder / candidate
        if p.exists():
            return p
    return None


@app.command(help=t("cmd.build.help"))
def build(
    readme: bool = typer.Option(False, help=README_HELP),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    no_veaf_triggers: bool = typer.Option(False, help=t("cmd.build.opt.no_veaf_triggers")),
    dynamic_mode: bool | None = typer.Option(
        None,
        "--dynamic-mode/--no-dynamic-mode",
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
        logger.error(t("cmd.build.folder_not_found", path=p_mission_folder), exception_type=FileNotFoundError)

    # Resolve the output mission path and base name (mission.yaml-aware).
    p_output_mission, mission_base_name = _resolve_output_mission(
        mission_name_or_file, p_mission_folder, DEFAULT_MISSION_FILE
    )

    mission_yaml_path = p_mission_folder / "mission.yaml"

    # Build the mission
    logger.step(t("pipeline.console.build"))
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
        logger.info(t("cmd.build.settings_persisted", path=mission_yaml_path))

    # ── Auto-pipeline: run optional injection steps ───────────────────────────
    # Each step is auto-enabled when its config file is found in src/.
    # Override in mission.yaml under the `pipeline:` key.
    #   pipeline:
    #     presets: false                 # disable even if src/presets.yaml exists
    #     waypoints:
    #       file: custom/wp.yaml         # use a non-default path
    #     spawnable_aircrafts:
    #       mode: replace                # add (default) or replace
    #     dynamic_slot_templates: false  # disable dynamic-slot-templates.yaml injection
    #     weather: false

    def _step_file(key: str, *candidates: str) -> Path | None:
        """Return the resolved file for a pipeline step, or None to skip."""
        return resolve_pipeline_step_file(worker.pipeline_cfg, p_mission_folder, key, *candidates)

    presets_path = _step_file("presets", "src/presets.yaml")
    if presets_path:
        logger.info(t("pipeline.injecting_presets", path=presets_path))
        logger.step(t("pipeline.console.presets", file=presets_path.name))
        presets_worker = PresetsInjectorWorker(
            presets_file=presets_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        )
        presets_worker.work()
        report_path = p_mission_folder / "presets-validation-report.md"
        issue_count = presets_worker.generate_validation_report(report_path)
        if issue_count == 0 and report_path.exists():
            report_path.unlink()

    waypoints_path = _step_file("waypoints", "src/waypoints.yaml", "waypoints.yaml")
    if waypoints_path:
        logger.info(t("pipeline.injecting_waypoints", path=waypoints_path))
        logger.step(t("pipeline.console.waypoints", file=waypoints_path.name))
        WaypointsInjectorWorker(
            waypoints_file=waypoints_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        ).work()

    def _inject_aircraft_step(step_key: str, candidate: str) -> None:
        """Inject one aircraft-group family file (spawnables or dynamic-slot templates)."""
        path = _step_file(step_key, candidate)
        if not path:
            return
        mode = "add"
        step_cfg = worker.pipeline_cfg.get(step_key)
        if isinstance(step_cfg, dict):
            mode = step_cfg.get("mode", "add")
        validator = AircraftGroupsYAMLValidator(path)
        is_valid, _ = validator.validate()
        if is_valid:
            logger.info(t("pipeline.injecting_aircraft_mode", path=path, mode=mode))
            logger.step(t("pipeline.console.aircraft", file=path.name, mode=mode))
            result = AircraftGroupsInjectorWorker(
                input_yaml=path,
                target_mission=p_output_mission,
                output_mission=p_output_mission,
            ).inject(mode=mode, silent=False)
            logger.tech(t("pipeline.console.aircraft_done", count=result.groups_injected))
        else:
            logger.warning(t("cmd.build.aircraft_validation_failed", path=path))
            console.print(t("pipeline.console.aircraft_invalid"))

    # Two independent steps (ADR 0002): spawnable aircraft groups and dynamic-slot templates.
    _inject_aircraft_step("spawnable_aircrafts", "src/spawnables.yaml")
    _inject_aircraft_step("dynamic_slot_templates", "src/dynamic-slot-templates.yaml")

    # Warn about pre-v6 files that are no longer injected (hard break — see ADR 0002).
    for _legacy in ("src/aircraft-templates.yaml", "src/templates.yaml"):
        if (p_mission_folder / _legacy).exists():
            logger.warning(t("cmd.build.orphan_aircraft_file", file=_legacy))

    # Dynamic-Slot warehouse wiring — must run after aircraft injection so the
    # dynSpawnTemplate groups (and their groupIds) exist for linkDynTempl.
    warehouses_path = _step_file("warehouses", "src/warehouses.yaml", "warehouses.yaml")
    if warehouses_path:
        logger.info(t("pipeline.injecting_warehouses", path=warehouses_path))
        logger.step(t("pipeline.console.warehouses", file=warehouses_path.name))
        wh_result = WarehousesInjectorWorker(
            config_file=warehouses_path,
            input_mission=p_output_mission,
            output_mission=p_output_mission,
        ).work()
        logger.tech(
            t(
                "pipeline.console.warehouses_done",
                airports=wh_result.airports_configured,
                templates=wh_result.templates_linked,
            )
        )

    # Spawn-data injection — always on (the framework spawn DB must ship), unless
    # explicitly disabled. Merges an optional per-mission src/spawn-groups.yaml /
    # src/spawn-units.yaml over the framework data. Runs before weather so every
    # weather variant embeds the data. See ADR 0005.
    spawn_step_cfg = worker.pipeline_cfg.get("spawn_data")
    spawn_disabled = spawn_step_cfg is False or (
        isinstance(spawn_step_cfg, dict) and spawn_step_cfg.get("enabled") is False
    )
    if not spawn_disabled:
        spawn_data_path = _step_file("spawn_data", "src/spawn-groups.yaml")
        logger.step(t("pipeline.console.spawn_data"))
        spawn_result = SpawnDataInjectorWorker(
            input_mission=p_output_mission,
            output_mission=p_output_mission,
            mission_data_file=spawn_data_path,
        ).work()
        if spawn_data_path:
            logger.info(t("pipeline.injecting_spawn_data", path=spawn_data_path))
        logger.tech(t("pipeline.console.spawn_data_done", units=spawn_result.units, groups=spawn_result.groups))

    weather_path = _step_file("weather", "src/versions.yaml", "versions.yaml")
    if weather_path:
        logger.info(t("pipeline.injecting_weather", path=weather_path))
        logger.step(t("pipeline.console.weather", file=weather_path.name))
        weather_worker = WeatherInjectorWorker(
            config_file=weather_path,
            mission_file=p_output_mission,
            output_dir=p_mission_folder / "missions",
            mission_base_name=mission_base_name,
        )
        if created_files := weather_worker.work():
            logger.tech(t("pipeline.console.weather_done", count=len(created_files)))

    logger.tech(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
