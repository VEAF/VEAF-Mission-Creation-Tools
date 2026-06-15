"""
Worker module for the VEAF Mission Builder Package.
"""

import re
import shutil
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

import luadata  # type: ignore[import-untyped]
import yaml
from mission_tools import (
    DEFAULT_SCRIPTS_LOCATION,
    DcsMission,
    collect_files_from_globs,
    create_miz,
    get_community_script_files,
    get_community_sound_files,
    get_mission_data_files,
    get_mission_script_files,
    get_optin_community_script_ids,
    is_community_script_enabled_by_default,
    read_miz,
    write_miz,
)
from veaf_libs import user_config as _user_config
from veaf_libs.base_worker import BaseWorker
from veaf_libs.build_profiles import resolve_profile
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.lua_config_generator import generate_config_lua
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.paths import resolve_path
from veaf_libs.progress import spinner_context
from veaf_libs.yaml_validator import validate_modules_semantics, validate_yaml_file

from mission_builder.coalition_placeholder import ensure_coalitions_populated
from mission_builder.era_detector import detect_era
from mission_builder.group_validation import find_missing_declared_groups

_DCS_BRIDGE_DOWNLOAD_URL = (
    "https://raw.githubusercontent.com/VEAF/VEAF-dcs-bridge/refs/heads/develop/src/lua/dcs-bridge.lua"
)

# Lua files that are always expected in src/scripts/ of a VEAF v6 mission folder.
# Any other .lua file found there is flagged as a potential v5 residue.
_EXPECTED_SCRIPTS: frozenset[str] = frozenset(
    {
        "veaf-config.lua",
        "mission-script.lua",
        "veafDynamicConfig.lua",
    }
)


@dataclass
class CustomScript:
    """A custom Lua script declared in the custom_scripts section of mission.yaml."""

    path: str
    generate_load_trigger: bool | None = field(default=None)


#: Lua calls that load another script file — the sign of a custom "loader" script.
#: Kept deliberately broad (no attempt to parse the loaded list): we only detect
#: that the file loads scripts, then point the user at the v6 `custom_scripts:` way.
_LUA_SCRIPT_LOADER_RE = re.compile(r"\b(?:loadfile|dofile|require)\b|a_do_script_file|do_script_file")


def lua_loads_other_scripts(text: str) -> bool:
    """Return True when *text* looks like a Lua script that loads other scripts."""
    return bool(_LUA_SCRIPT_LOADER_RE.search(text))


#: Community scripts that are hard dependencies of the VEAF scripts and are always
#: injected, regardless of (or despite) the `modules:` entry (MiST is used pervasively,
#: e.g. by veafAssets.respawn). Disabling one is warned and ignored.
MANDATORY_COMMUNITY_SCRIPTS: frozenset[str] = frozenset({"mist"})


def resolve_dynamic_mode(cli_override: bool | None, build_cfg: dict) -> bool:
    """Resolve the dynamic-loading flag (IMC2-008).

    Precedence: explicit CLI flag (``--dynamic-mode``/``--no-dynamic-mode``) wins;
    otherwise ``build.dynamic_loading`` from mission.yaml (profile-overridable);
    otherwise static loading (``False``).

    Args:
        cli_override: The CLI value (``None`` when neither flag was passed).
        build_cfg: The ``build:`` mapping from the (profile-resolved) mission.yaml.

    Returns:
        ``True`` for dynamic loading, ``False`` for static.
    """
    if cli_override is not None:
        return cli_override
    return bool(build_cfg.get("dynamic_loading", False))


def _as_enabled_dict(cfg: object) -> dict:
    """Coerce a module entry value into a config dict with an ``enabled`` flag.

    Precondition: ``validate_modules_semantics`` has already rejected
    unexpected scalar types (a module value must be bool, null, or a mapping),
    so any non-dict value reaching here is a deliberate bool/None shorthand.

    Args:
        cfg: A module entry value: a dict, a bool shorthand, or ``None`` (bare).

    Returns:
        A dict carrying at least ``enabled`` (defaulting to ``True``).
    """
    if isinstance(cfg, dict):
        result = dict(cfg)
        result.setdefault("enabled", True)
        return result
    if cfg is False:
        return {"enabled": False}
    return {"enabled": True}


def _extract_external_and_qra(modules_raw: dict, lua_mods: dict) -> tuple[dict, dict | None]:
    """Translate the unified ``modules:`` block into the generator's internals.

    ``SKYNET`` / ``CTLD`` / ``CSAR`` nested config maps to the internal
    ``external_modules`` shape; ``QRA`` config maps to the internal ``qra``
    section. The QRA-specific keys are stripped from the ``lua_modules`` entry so
    they are not emitted as ``setConfig`` calls. (MODULES-UNIFY: single source of
    truth — there is no top-level ``external_modules:`` / ``qra:`` any more.)

    Args:
        modules_raw: The raw ``modules:`` mapping from mission.yaml.
        lua_mods: The VEAF-module split (mutated in place for QRA).

    Returns:
        A ``(external_modules, qra)`` tuple; ``qra`` is ``None`` when absent.
    """
    external_modules: dict = {}
    qra: dict | None = None
    for mod_id, cfg in modules_raw.items():
        upper = mod_id.upper()
        if upper == "SKYNET":
            external_modules["skynet"] = _as_enabled_dict(cfg)
        elif upper in ("CTLD", "CSAR"):
            entry = _as_enabled_dict(cfg)
            settings = entry.pop("settings", None)
            if isinstance(settings, dict):
                entry.update(settings)
            external_modules[upper.lower()] = entry
        elif upper == "QRA" and isinstance(cfg, dict):
            qra = {key: cfg[key] for key in ("silence_all", "definitions") if key in cfg}
            qra_mod = lua_mods.get("QRA")
            if isinstance(qra_mod, dict):
                lua_mods["QRA"] = {k: v for k, v in qra_mod.items() if k not in ("silence_all", "definitions")}
    return external_modules, qra


def _normalize_mission_yaml(yaml_data: dict) -> dict:
    """Normalize legacy mission.yaml keys to the current unified format.

    - ``modules:`` (new) is split into ``lua_modules`` + ``community_scripts``
      for internal processing, and the nested per-module config for SKYNET /
      CTLD / CSAR / QRA is translated into the internal ``external_modules`` /
      ``qra`` representation.  If both ``modules:`` and the legacy keys are
      present, ``modules:`` takes precedence and a warning is emitted.
    - Deprecated ``lua_modules:`` / ``community_scripts:`` keys are accepted
      with a deprecation warning.

    Args:
        yaml_data: Parsed mission.yaml content dict.

    Returns:
        Normalized dict (shallow copy when changes are needed).
    """
    modules_raw = yaml_data.get("modules")
    has_legacy = yaml_data.get("lua_modules") is not None or yaml_data.get("community_scripts") is not None

    if modules_raw is not None:
        if has_legacy:
            logger.warning(t("builder.modules_conflict"))
        if not isinstance(modules_raw, dict):
            logger.warning(t("builder.modules_not_mapping", type=type(modules_raw).__name__))
            return yaml_data

        # IDs are lowercase in code; YAML may use uppercase (e.g. MIST).
        all_community_ids_lower = {s["id"].lower() for s in get_community_script_files()}
        lua_mods = {k: v for k, v in modules_raw.items() if k.lower() not in all_community_ids_lower}
        comm_scripts = {k.lower(): v for k, v in modules_raw.items() if k.lower() in all_community_ids_lower}

        result = dict(yaml_data)
        result["lua_modules"] = lua_mods
        result["community_scripts"] = comm_scripts
        external_modules, qra = _extract_external_and_qra(modules_raw, lua_mods)
        if external_modules:
            result["external_modules"] = external_modules
        if qra is not None:
            result["qra"] = qra
        return result

    if has_legacy:
        logger.warning(t("builder.modules_deprecated"))

    return yaml_data


class MissionBuilderWorker(BaseWorker):
    """
    Worker class that builds a mission, based on a folder containing the mission files, and on the VEAF Mission Creation Tools package.
    """

    def __init__(
        self,
        mission_folder: Path,
        output_mission: Path,
        dynamic_mode: bool | None,
        dev_mode_override: bool | None = None,
        scripts_path_override: str | Path | None = None,
        log_modules_filter: str | None = None,
        migrate_from_v5: bool = True,
        no_veaf_triggers: bool = False,
        profile_name: str | None = None,
    ):
        """
        Initialize the worker.  Config resolution priority: CLI override > mission.yaml > user config > code defaults.
        """

        self.output_mission = output_mission
        self.mission_folder = mission_folder
        # dynamic_mode is resolved below (CLI override > build.dynamic_loading > default)
        self.migrate_from_v5: bool = migrate_from_v5
        self.no_veaf_triggers: bool = no_veaf_triggers
        self.dcs_mission: DcsMission | None = None
        self.collected_community_script_files: dict[str, bytes] | None = None
        self.collected_community_sound_files: dict[str, bytes] | None = None
        self.collected_veaf_script_files: dict[str, bytes] | None = None
        self.collected_mission_script_files: dict[str, bytes] | None = None
        self.collected_mission_data_files: dict[str, bytes] | None = None

        # Make sure mission.yaml is present BEFORE we read it: if the user has no
        # mission.yaml, copy the default (which ships an active modules block) now.
        # Copying it later (in complete_src_folder_with_defaults, during work())
        # would be too late — the config below would already have been resolved
        # from an absent file → no veaf-config.lua and wrong module toggles.
        self._ensure_default_mission_yaml(scripts_path_override)

        # Read mission.yaml, then apply build profile (deep-merge)
        self.mission_yaml: dict = {}
        self.pipeline_cfg: dict = {}
        mission_yaml_path = mission_folder / "mission.yaml"
        if mission_yaml_path.exists():
            validate_yaml_file(mission_yaml_path)
            with mission_yaml_path.open("r", encoding="utf-8") as fh:
                raw_yaml: dict = yaml.safe_load(fh) or {}
            self.mission_yaml = resolve_profile(raw_yaml, profile_name)
            validate_modules_semantics(self.mission_yaml)
            self.mission_yaml = _normalize_mission_yaml(self.mission_yaml)
        build_cfg: dict = self.mission_yaml.get("build") or {}
        self.pipeline_cfg = self.mission_yaml.get("pipeline") or {}

        # Resolve dynamic loading: CLI override > mission.yaml (build.dynamic_loading,
        # profile-overridable) > default (static). Lets profiles (TEST/SERVER) switch it.
        self.dynamic_mode: bool = resolve_dynamic_mode(dynamic_mode, build_cfg)

        # Extract lua_modules and global_log_level from yaml
        lua_modules: dict | None = self.mission_yaml.get("lua_modules") or None
        if lua_modules:
            logger.info(t("builder.lua_modules_found", path=mission_yaml_path))
        global_log_level: str | None = self.mission_yaml.get("global_log_level") or None
        if global_log_level:
            logger.info(t("builder.log_level_found", level=global_log_level, path=mission_yaml_path))

        # Resolve dev_mode: CLI override > mission.yaml > default
        self.dev_mode: bool = (
            dev_mode_override if dev_mode_override is not None else bool(build_cfg.get("dev_mode", False))
        )
        if self.dev_mode:
            logger.info(t("builder.dev_mode_active"))

        # Resolve scripts_path: CLI override > mission.yaml > user config
        _uc_sp = _user_config.get_scripts_path()
        effective_scripts_path_str: str | Path | None = (
            scripts_path_override or build_cfg.get("scripts_path") or (str(_uc_sp) if _uc_sp else None)
        )
        if not effective_scripts_path_str and self.dynamic_mode:
            effective_scripts_path_str = mission_folder / "published"
        if effective_scripts_path_str:
            self.scripts_path: Path | None = resolve_path(path=effective_scripts_path_str, should_exist=True)
            if not self.scripts_path.exists():
                logger.error(
                    t("builder.scripts_folder_missing", path=self.scripts_path), exception_type=FileNotFoundError
                )
        else:
            self.scripts_path = None

        if self.dev_mode and not self.scripts_path:
            logger.error(
                t("builder.dev_mode_needs_scripts_path"),
                exception_type=ValueError,
            )

        # Dynamic mode: the framework loader must exist under the resolved scripts
        # path (DEV → individual scripts via VeafDynamicLoader.lua; PROD → bundle),
        # otherwise the built .miz fails to load scripts at runtime.
        if self.dynamic_mode:
            loader_root = self.scripts_path or (mission_folder / "published")
            relative_loader = self._dynamic_framework_load_path().lstrip("/")
            loader_file = loader_root / relative_loader
            if not loader_file.exists():
                logger.error(
                    t(
                        "builder.dynamic_loader_missing",
                        mode="dev" if self.dev_mode else "prod",
                        path=loader_file,
                    ),
                    exception_type=FileNotFoundError,
                )

        # Apply log_modules_filter: silence all modules not in the keep list
        if log_modules_filter is not None:
            keep_modules = {m.strip() for m in log_modules_filter.split(",") if m.strip()}
            all_module_ids = {m["id"] for m in get_modules()}
            if unknown := keep_modules - all_module_ids:
                logger.warning(t("builder.unknown_module_ids", ids=sorted(unknown)))
            lua_modules = lua_modules or {}
            for mod_id in all_module_ids:
                if mod_id not in keep_modules:
                    if mod_id not in lua_modules:
                        lua_modules[mod_id] = {}
                    lua_modules[mod_id].setdefault("logLevel", "error")
            logger.info(
                t(
                    "builder.log_modules_detail",
                    module=sorted(keep_modules) or "none",
                    count=len(all_module_ids) - len(keep_modules),
                )
            )

        # Normalize global_log_level
        _valid_levels = {"error", "warning", "info", "debug", "trace"}
        if global_log_level is not None:
            normalized = global_log_level.lower().strip()
            if normalized == "warn":
                normalized = "warning"
            if normalized not in _valid_levels:
                logger.warning(t("builder.invalid_log_level", level=global_log_level, valid=sorted(_valid_levels)))
                normalized = "info"
            global_log_level = normalized
        self.global_log_level: str | None = global_log_level
        self.lua_modules: dict | None = lua_modules

        # Parse custom_scripts section from mission.yaml
        self.custom_scripts: list[CustomScript] = []
        self.custom_scripts_generate_load_trigger: bool = True
        cs_raw = self.mission_yaml.get("custom_scripts")
        if cs_raw is not None and not isinstance(cs_raw, dict):
            logger.warning(t("builder.custom_scripts_not_mapping", type=type(cs_raw).__name__))
            cs_raw = None
        cs_section: dict = cs_raw or {}
        if cs_section:
            self.custom_scripts_generate_load_trigger = bool(cs_section.get("generate_load_trigger", True))
            for script_item in cs_section.get("scripts") or []:
                if isinstance(script_item, dict):
                    path = script_item.get("path", "")
                    per_script_trigger: bool | None = script_item.get("generate_load_trigger")
                else:
                    path = str(script_item)
                    per_script_trigger = None
                self.custom_scripts.append(CustomScript(path=Path(path).name, generate_load_trigger=per_script_trigger))

        # Parse community_scripts section from mission.yaml
        # None means "all enabled" (no section present); a set means only those ids are enabled.
        comm_raw = self.mission_yaml.get("community_scripts")
        if comm_raw is not None and not isinstance(comm_raw, dict):
            logger.warning(t("builder.community_scripts_not_mapping", type=type(comm_raw).__name__))
            comm_raw = None
        # Empty dict {} is treated the same as absent: opt-out scripts stay active,
        # opt-in scripts (e.g. TUM) stay disabled (see _active_community_scripts).
        optin_ids = get_optin_community_script_ids()
        if not comm_raw:
            self.enabled_community_script_ids: set[str] | None = None
        else:
            # Opt-out scripts start enabled; opt-in scripts (e.g. TUM) start disabled
            # and are only turned on by an explicit `<ID>: true`.
            all_community_scripts = get_community_script_files()
            all_ids = {s["id"] for s in all_community_scripts}
            self.enabled_community_script_ids = set(all_ids) - optin_ids
            for script_id, script_cfg in comm_raw.items():
                if script_id not in all_ids:
                    logger.warning(t("builder.unknown_community_script", id=script_id))
                    continue
                enabled = True
                if isinstance(script_cfg, dict):
                    enabled = bool(script_cfg.get("enabled", True))
                elif script_cfg is None:
                    enabled = False
                else:
                    enabled = bool(script_cfg)
                if script_id in MANDATORY_COMMUNITY_SCRIPTS:
                    # MiST is a hard dependency of the VEAF scripts — always inject it.
                    # A bare `MIST:` (None) is the mandatory default form (kept silently);
                    # an explicit disable is the user trying to turn it off → warn and keep.
                    explicitly_disabled = script_cfg is False or (
                        isinstance(script_cfg, dict) and script_cfg.get("enabled") is False
                    )
                    if explicitly_disabled:
                        logger.warning(t("builder.mandatory_community_kept", id=script_id))
                    enabled = True
                if enabled:
                    self.enabled_community_script_ids.add(script_id)
                else:
                    self.enabled_community_script_ids.discard(script_id)

        # Parse dcs_bridge section from mission.yaml
        dcsb_cfg: dict = self.mission_yaml.get("dcs_bridge") or {}
        self.dcs_bridge_enabled: bool = bool(dcsb_cfg.get("enabled", False))
        self.dcs_bridge_lua_path: str | None = dcsb_cfg.get("lua_path")
        self.dcs_bridge_bytes: bytes | None = None

        if self.mission_folder and not self.mission_folder.is_dir():
            logger.error(
                t("builder.folder_not_found", path=self.mission_folder),
                exception_type=FileNotFoundError,
            )

    def get_collected_veaf_script_files(self) -> dict[str, bytes]:
        if self.collected_veaf_script_files:
            return self.collected_veaf_script_files

        # Preprocess the veaf script files
        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")

        if self.dev_mode and self.scripts_path:
            # In dev mode, veaf-scripts.lua lives in build/ (compiled artifact)
            veaf_script_pattern = ("build/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
            expected_path = scripts_folder / "build" / "veaf-scripts.lua"
        else:
            veaf_script_pattern = ("src/scripts/veaf/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
            expected_path = scripts_folder / "src" / "scripts" / "veaf" / "veaf-scripts.lua"

        self.collected_veaf_script_files = collect_files_from_globs(
            base_folder=scripts_folder,
            file_patterns=[veaf_script_pattern],
        )

        if len(self.collected_veaf_script_files) < 1:
            logger.error(t("builder.scripts_not_found", path=expected_path))

        return self.collected_veaf_script_files

    def _active_community_scripts(self) -> list[dict[str, str]]:
        """Return community script descriptors filtered by enabled_community_script_ids."""
        all_scripts = get_community_script_files()
        if self.enabled_community_script_ids is None:
            # No community_scripts section: opt-out scripts active, opt-in (e.g. TUM) off.
            optin_ids = get_optin_community_script_ids()
            return [s for s in all_scripts if s["id"] not in optin_ids]
        return [s for s in all_scripts if s["id"] in self.enabled_community_script_ids]

    def _community_enabled(self, script_id: str) -> bool:
        """Return True if the given community script id is enabled for this build.

        Args:
            script_id: The community script id (e.g. ``"ctld"``).

        Returns:
            True when the id is enabled. With no ``community_scripts:`` section
            (``enabled_community_script_ids is None``), opt-out scripts are enabled
            and opt-in scripts (e.g. TUM) are not.
        """
        if self.enabled_community_script_ids is None:
            return is_community_script_enabled_by_default(script_id)
        return script_id in self.enabled_community_script_ids

    def _find_community_sound_resource_keys(self) -> list[str]:
        """Return mapResource keys whose value is a known CTLD/CSAR sound file.

        Used to locate the legacy "community sound preload" trigger's resources so
        they can be dropped when neither CTLD nor CSAR needs them.

        Returns:
            The matching mapResource keys (empty if the mission has no such sounds).
        """
        if not (self.dcs_mission and self.dcs_mission.map_resource_content):
            return []
        sound_files = {name for names in get_community_sound_files().values() for name in names}
        return [key for key, value in self.dcs_mission.map_resource_content.items() if str(value) in sound_files]

    def get_collected_community_script_files(self) -> dict[str, bytes]:
        if self.collected_community_script_files:
            return self.collected_community_script_files

        file_patterns: list[tuple[str, str]] = [(s["path"], s["dest"]) for s in self._active_community_scripts()]

        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")
        self.collected_community_script_files = collect_files_from_globs(
            base_folder=scripts_folder, file_patterns=file_patterns
        )
        if len(self.collected_community_script_files) < len(file_patterns):
            self.signal_missing_required_files_after_collection(
                file_patterns, self.collected_community_script_files, scripts_folder
            )
        return self.collected_community_script_files

    def signal_missing_required_files_after_collection(
        self, expected_files: list[tuple[str, str]], collected_files: dict[str, bytes], scripts_folder: Path
    ):
        """Signal missing files after collection with detailed information."""
        collected_file_paths = {Path(path).name for path in collected_files}
        missing_files = [
            Path(file_pattern[0]).name
            for file_pattern in expected_files
            if Path(file_pattern[0]).name not in collected_file_paths
        ]

        files_str = ", ".join(sorted(missing_files))
        message = t("builder.missing_files", folder=scripts_folder, files=files_str) + "\n" + t("builder.update_hint")
        logger.error(message=message)

    def get_collected_community_sound_files(self) -> dict[str, bytes]:
        """Collect the ``.ogg`` sounds required by the enabled CTLD/CSAR modules.

        CTLD and CSAR play their sounds by filename, so the files must sit in the
        mission's ``l10n/DEFAULT/``. The tool ships them under
        ``src/scripts/community/sounds/``; this returns the ones for enabled
        modules, keyed for ``l10n/DEFAULT``. Sounds the mission already provides
        win on merge (see :meth:`create_mission`). A required sound shipped by
        neither the tool nor the mission is reported so the maker can add it.

        Returns:
            Mapping of ``l10n/DEFAULT/<name>`` to file bytes (empty when no
            enabled module needs sounds).
        """
        if self.collected_community_sound_files is not None:
            return self.collected_community_sound_files

        required: set[str] = set()
        for script_id, names in get_community_sound_files().items():
            if self._community_enabled(script_id):
                required.update(names)

        if not required:
            self.collected_community_sound_files = {}
            return self.collected_community_sound_files

        scripts_folder: Path = self.scripts_path or (self.mission_folder / "published")
        file_patterns = [
            (f"src/scripts/community/sounds/{name}", DEFAULT_SCRIPTS_LOCATION) for name in sorted(required)
        ]
        collected = collect_files_from_globs(base_folder=scripts_folder, file_patterns=file_patterns)

        self._warn_missing_community_sounds(required, collected)
        self.collected_community_sound_files = collected
        return self.collected_community_sound_files

    def _warn_missing_community_sounds(self, required: set[str], collected: dict[str, bytes]) -> None:
        """Warn about required community sounds shipped by neither the tool nor the mission.

        The build merges the tool-shipped sounds with the mission's own files; a
        required sound present in neither will be absent at runtime (e.g. CTLD
        beacons "won't work"). The mission maker must then add it by hand.

        Args:
            required: Sound filenames required by the enabled community modules.
            collected: Sounds found among the tool-shipped assets.
        """
        # Match the exact l10n/DEFAULT destination, not just the basename: a sound
        # sitting elsewhere in the mission (e.g. kneeboard/beacon.ogg) does not make
        # it available to the scripts, which look it up in l10n/DEFAULT.
        provided = set(collected) | set(self.get_collected_mission_data_files())
        missing = sorted(name for name in required if f"{DEFAULT_SCRIPTS_LOCATION}/{name}" not in provided)
        if missing:
            logger.warning(t("builder.community_sounds_missing", files=", ".join(missing)))

    def get_collected_mission_script_files(self) -> dict[str, bytes]:
        if self.collected_mission_script_files:
            return self.collected_mission_script_files

        # Preprocess the mission files
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        )
        self.collected_mission_script_files = collect_files_from_globs(
            base_folder=self.mission_folder,
            file_patterns=get_mission_script_files(),
            alternative_folder=defaults_folder,
        )
        return self.collected_mission_script_files

    def get_collected_mission_data_files(self) -> dict[str, bytes]:
        if self.collected_mission_data_files:
            return self.collected_mission_data_files

        # Preprocess the mission files
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published")) / "src" / "defaults" / "mission-folder"
        )
        self.collected_mission_data_files = collect_files_from_globs(
            base_folder=self.mission_folder, file_patterns=get_mission_data_files(), alternative_folder=defaults_folder
        )
        return self.collected_mission_data_files

    def resolve_dcs_bridge_file(self) -> Path | None:
        """Resolve dcs-bridge.lua to a local Path, downloading it if no lua_path is configured.

        Returns:
            A Path to a temporary file containing the bridge Lua source, or None if
            dcs-bridge injection is disabled.

        Raises:
            FileNotFoundError: When lua_path is set but points to a non-existent file.
            RuntimeError: When auto-download from GitHub fails.
        """
        if not self.dcs_bridge_enabled:
            return None

        if self.dcs_bridge_lua_path:
            p = Path(self.dcs_bridge_lua_path)
            if not p.exists():
                logger.error(
                    t("builder.dcs_bridge_not_found", path=p),
                    exception_type=FileNotFoundError,
                )
            return p

        # Auto-download from GitHub
        logger.info(t("builder.dcs_bridge_downloading", url=_DCS_BRIDGE_DOWNLOAD_URL))
        try:
            with urllib.request.urlopen(_DCS_BRIDGE_DOWNLOAD_URL) as resp:
                content: bytes = resp.read()
        except urllib.error.URLError as exc:
            raise RuntimeError(f"dcs_bridge: failed to download dcs-bridge.lua: {exc}") from exc

        tmp = tempfile.NamedTemporaryFile(suffix=".lua", delete=False)
        tmp.write(content)
        tmp.flush()
        tmp.close()
        return Path(tmp.name)

    def inject_dcs_bridge_trigger(self, bridge_file: Path | None) -> None:
        """Inject a DO SCRIPT FILE trigger for dcs-bridge.lua at position 1 in the mission.

        The bridge is loaded before all other VEAF triggers so that it is available
        at the earliest possible point in mission startup.

        Also stores the bridge file bytes in self.dcs_bridge_bytes so that
        write_mission() can pass them to write_miz() as additional_files.

        Args:
            bridge_file: Path to the dcs-bridge.lua file, or None (no-op).
        """
        if bridge_file is None:
            return

        assert self.dcs_mission is not None
        assert self.dcs_mission.mission_content is not None

        bridge_bytes = bridge_file.read_bytes()
        self.dcs_bridge_bytes = bridge_bytes

        # Register in mapResource
        map_resource_key = "VEAF_MapKey_DcsBridge"
        self.dcs_mission.map_resource_content = self.dcs_mission.map_resource_content or {}
        self.dcs_mission.map_resource_content[map_resource_key] = "dcs-bridge.lua"

        # Build the new trigrule
        bridge_trigrule = {
            "comment": "dcs-bridge loading",
            "predicate": "triggerStart",
            "eventlist": "",
            "rules": [],
            "actions": [
                {"predicate": "a_do_script_file", "file": map_resource_key},
            ],
            "colorItem": "0x00ffffff",
        }

        # Shift all existing trigrules up by 1
        trigrules: dict = self.dcs_mission.mission_content["trigrules"]
        shifted = {k + 1: v for k, v in trigrules.items()}
        shifted[1] = bridge_trigrule
        self.dcs_mission.mission_content["trigrules"] = shifted

        # Shift all existing trig entries up by 1
        trig: dict = self.dcs_mission.mission_content["trig"]
        for category_name, category_data in trig.items():
            if isinstance(category_data, dict):
                trig[category_name] = {k + 1: v for k, v in category_data.items()}

        # Insert the bridge trigger at position 1 in each trig category
        trig["actions"][1] = f'a_do_script_file(getValueResourceByKey("{map_resource_key}"));'
        trig["conditions"][1] = "return true"
        trig["flag"][1] = True
        trig["funcStartup"][1] = "if mission.trig.conditions[1]() then mission.trig.actions[1]() end"

    def _ensure_default_mission_yaml(self, scripts_path_override: str | Path | None) -> None:
        """Copy the default mission.yaml into the mission folder if it is missing.

        Runs before the config is resolved in ``__init__``: the default ships an
        active ``modules:`` block, so resolving from an absent mission.yaml would
        produce an empty config (no veaf-config.lua, wrong module toggles). Mirrors
        the source-path logic of :meth:`complete_src_folder_with_defaults`.

        Args:
            scripts_path_override: The CLI/explicit scripts path, if any (dev mode).
        """
        mission_yaml_path = self.mission_folder / "mission.yaml"
        if mission_yaml_path.exists():
            return
        scripts_root = (
            Path(scripts_path_override) if scripts_path_override else (self.mission_folder / "published" / "src")
        )
        default_yaml = scripts_root / "defaults" / "mission-folder" / "mission.yaml"
        if default_yaml.is_file():
            shutil.copy(default_yaml, mission_yaml_path)
            logger.warning(t("builder.copied_from_defaults", file=mission_yaml_path, folder=default_yaml.parent))

    def complete_src_folder_with_defaults(self) -> None:
        defaults_folder: Path = (
            (self.scripts_path or (self.mission_folder / "published" / "src")) / "defaults" / "mission-folder"
        )
        # Map default filenames to the pipeline/module that owns them so that we
        # skip copying when the user has explicitly disabled the corresponding step.
        # Keys are bare filenames (no directory).  Values are dicts with either
        # "pipeline" (key in self.pipeline_cfg) or "lua_module" (key in
        # self.mission_yaml["lua_modules"]).
        _DEFAULT_FILE_MODULE_MAP: dict[str, dict[str, str]] = {
            "spawnables.yaml": {"pipeline": "spawnable_aircrafts"},
            "dynamic-slot-templates.yaml": {"pipeline": "dynamic_slot_templates"},
            "waypoints.yaml": {"pipeline": "waypoints"},
            "warehouses.yaml": {"pipeline": "warehouses"},
            "presets.yaml": {"pipeline": "presets"},
            "versions.yaml": {"pipeline": "weather"},
            "spawn-groups.yaml": {"pipeline": "spawn_data"},
        }
        for f in defaults_folder.rglob("*"):
            if f.is_file():
                mapping = _DEFAULT_FILE_MODULE_MAP.get(f.name)
                if mapping is not None and "pipeline" in mapping:
                    step_cfg = self.pipeline_cfg.get(mapping["pipeline"])
                    if step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False):
                        logger.debug(f"Skipping default '{f.name}': pipeline '{mapping['pipeline']}' is disabled")
                        dest = self.mission_folder / f.relative_to(defaults_folder).parent.as_posix() / f.name
                        if dest.exists():
                            logger.warning(
                                t(
                                    "builder.orphan_pipeline_file",
                                    file=dest.relative_to(self.mission_folder),
                                    step=mapping["pipeline"],
                                )
                            )
                        continue
                relative_path = f.relative_to(defaults_folder).parent.as_posix()
                target_path = self.mission_folder / relative_path / f.name
                if not target_path.exists():
                    target_path.parent.mkdir(parents=True, exist_ok=True)
                    logger.warning(t("builder.copied_from_defaults", file=target_path, folder=defaults_folder))
                    shutil.copy(f, target_path)

        # OLDSCRIPTS-002: warn about unexpected .lua files in src/scripts/
        # The glob src/scripts/*.lua in get_mission_script_files() picks up ALL .lua files in
        # that folder, including potential v5 residues (e.g. veafSecurity.lua, veafCommands.lua).
        # Those would be loaded as individual DCS mission scripts and may conflict with the
        # bundled veaf-scripts.lua loaded by the VEAF triggers.
        scripts_dir = self.mission_folder / "src" / "scripts"
        declared_custom_names = {cs.path for cs in self.custom_scripts}
        if scripts_dir.is_dir():
            for lua_file in scripts_dir.glob("*.lua"):
                if lua_file.name in _EXPECTED_SCRIPTS:
                    continue
                if lua_file.name in declared_custom_names:
                    logger.info(t("builder.custom_lua_included", file=lua_file.name))
                    continue
                logger.warning(t("builder.unexpected_lua_file", file=lua_file.name))
                # A script that itself loads other scripts (a v5-style custom loader)
                # cannot be auto-migrated reliably — point the user at the v6 way.
                try:
                    if lua_loads_other_scripts(lua_file.read_text(encoding="utf-8", errors="ignore")):
                        logger.warning(t("builder.custom_loader_hint", file=lua_file.name))
                except OSError:
                    pass

    def create_mission(self) -> None:
        """Creates the initial mission file from the mission folder."""

        logger.debug("Create the initial mission file from the mission folder")

        files = (
            self.get_collected_community_sound_files()
            | self.get_collected_community_script_files()
            | self.get_collected_veaf_script_files()
            | self.get_collected_mission_script_files()
            | self.get_collected_mission_data_files()
        )
        logger.debug(f"Preprocessed {len(files)} files")

        logger.debug("Creating the mission file")
        self.output_mission = create_miz(self.output_mission, files)
        logger.debug(f"Mission file created at {self.output_mission}")

    def read_mission(self) -> None:
        """Load the mission from the .miz file (unzip it) and process aircraft groups."""

        logger.debug(f"Reading mission file {self.output_mission}")
        try:
            self.dcs_mission = read_miz(self.output_mission)
            if self.dcs_mission.missing_components and "options" in self.dcs_mission.missing_components:
                logger.warning(t("builder.options_missing", path=self.mission_folder / "src"))
                self.dcs_mission.missing_components.remove("options")  # we've handled that one
            if self.dcs_mission.missing_components:
                message = f"These components are missing from '{self.mission_folder / 'src'}': {', '.join([f"'{item}'" for item in self.dcs_mission.missing_components])}; they are mandatory in a DCS mission!"
                logger.error(message=message, exception_type=RuntimeError)
        except KeyError:
            logger.error(t("builder.mission_read_error", path=self.output_mission))
            raise

    def validate_declared_groups(self) -> None:
        """Warn when a config-declared group (ASSETS, QRA, …) is absent from the mission.

        Such groups must be placed in the Mission Editor; a missing one makes the
        feature fail silently at runtime (e.g. ``veafAssets.respawn`` → MiST error).
        """
        if not self.mission_yaml or not self.dcs_mission or not self.dcs_mission.mission_content:
            return
        for section, group in find_missing_declared_groups(self.mission_yaml, self.dcs_mission.mission_content):
            logger.warning(t("builder.declared_group_missing", group=group, section=section))

    def ensure_coalitions_populated(self) -> None:
        """Inject a hidden placeholder ground unit into any empty side coalition.

        Lifts the historical "place one blue and one red ground group by hand"
        requirement: a side coalition with no unit would leave its DCS tables
        incomplete (injectors skip groups; DCS purges unit-less countries), so a
        single hidden placeholder ground group is added on the coalition
        bullseye. See :func:`coalition_placeholder.ensure_coalitions_populated`.
        """
        if not self.dcs_mission or not self.dcs_mission.mission_content:
            return
        for side in ensure_coalitions_populated(self.dcs_mission.mission_content):
            logger.info(t("builder.coalition_placeholder_injected", side=side))

    def clear_veaf_triggers(self) -> None:
        """
        Clears all the VEAF triggers from the current mission
        """

        def _find_veaf_triggers() -> list[str]:
            veaf_dict_keys_to_remove = []
            # Find the VEAF triggers in the dictionary
            if self.dcs_mission and self.dcs_mission.dictionary_content:
                logger.debug("Find the VEAF triggers in the dictionary")
                for map_key, map_value in self.dcs_mission.dictionary_content.items():
                    if map_key.startswith("VEAF_DictKey"):
                        # this is a VEAF trigger, remove it
                        logger.debug(f"Removing VEAF dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)
                    if self.migrate_from_v5 and map_value in [
                        "return false -- scripts",
                        "return false -- config",
                        "return true -- scripts",
                        "return true -- config",
                        "return VEAF_DYNAMIC_PATH~=nil",
                        "return VEAF_DYNAMIC_PATH==nil",
                        "return VEAF_DYNAMIC_MISSIONPATH~=nil",
                        "return VEAF_DYNAMIC_MISSIONPATH==nil",
                    ]:
                        # this is a legacy VEAF trigger, remove it
                        logger.debug(f"Removing legacy VEAF v5 dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)

            # Find the VEAF triggers in the mapResource
            if self.dcs_mission and self.dcs_mission.map_resource_content:
                logger.debug("Find the VEAF triggers in the mapResource")
                for map_key, map_value in self.dcs_mission.map_resource_content.items():
                    if map_key.startswith("VEAF_MapKey"):
                        # this is a VEAF trigger, remove it
                        logger.debug(f"Removing VEAF map key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)

            return veaf_dict_keys_to_remove

        veaf_dict_keys_to_remove = _find_veaf_triggers()

        # TRIGGERS-VERIFY-004: a legacy "community sound preload" trigger registers the
        # CTLD/CSAR beacon sounds via out_sound. When both CTLD and CSAR are disabled
        # those sounds are dead weight, so drop the trigger and its mapResource entries.
        # (Re-creating it when a module is enabled is the BUILD-COMMUNITY-SOUNDS lot.)
        if not self._community_enabled("ctld") and not self._community_enabled("csar"):
            veaf_dict_keys_to_remove.extend(self._find_community_sound_resource_keys())

        # Remove all these keys from the dictionary
        if self.dcs_mission and self.dcs_mission.dictionary_content:
            logger.debug("Clear the VEAF triggers from the dictionary")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.dictionary_content.get(dict_key):
                    logger.debug(f"Removing key {dict_key} from the dictionary")
                    del self.dcs_mission.dictionary_content[dict_key]

        # Remove all these keys from the mapResource
        if self.dcs_mission and self.dcs_mission.map_resource_content:
            logger.debug("Clear the VEAF triggers from the mapResource")
            for dict_key in veaf_dict_keys_to_remove:
                if self.dcs_mission.map_resource_content.get(dict_key):
                    logger.debug(f"Removing key {dict_key} from the mapResource")
                    del self.dcs_mission.map_resource_content[dict_key]

        # Remove all the triggers referencing these dictionary keys from the mission
        if self.dcs_mission and self.dcs_mission.mission_content:
            mission_triggers: dict = self.dcs_mission.mission_content.get("trig", {})
            trigger_indexes_to_remove = []
            for trigger_category_value in mission_triggers.values():
                if isinstance(trigger_category_value, list):
                    trigger_indexes_to_remove.extend(
                        [
                            trigger_index
                            for trigger_index, value in enumerate(trigger_category_value)
                            if any(s in str(value) for s in veaf_dict_keys_to_remove)
                        ]
                    )
                elif isinstance(trigger_category_value, dict):
                    trigger_indexes_to_remove.extend(
                        [
                            trigger_key
                            for trigger_key, value in trigger_category_value.items()
                            if any(s in str(value) for s in veaf_dict_keys_to_remove)
                        ]
                    )

            # remove duplicates
            trigger_indexes_to_remove = list(set(trigger_indexes_to_remove))

            # and now remove the triggers
            for trigger_category_index, trigger_category_value in mission_triggers.items():
                for trigger_index in trigger_indexes_to_remove:
                    if trigger_category_value.get(trigger_index):
                        del trigger_category_value[trigger_index]

            # and now remove the trigrules
            for trigger_index in trigger_indexes_to_remove:
                if self.dcs_mission.mission_content["trigrules"].get(trigger_index):
                    del self.dcs_mission.mission_content["trigrules"][trigger_index]

    def insert_all_veaf_triggers(self) -> None:
        """
        Create all the VEAF triggers in the mission.
        First, we'll update the dictionary.
        Then we'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        We'll also add 6 corresponding trigrules, shifting the existing ones accordingly
        """
        new_dictionary = self.update_dictionary_with_veaf_entries()
        new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file = (
            self.update_map_resource_with_veaf_entries()
        )
        self.insert_veaf_triggers(new_dictionary, new_map_resource_script_files, new_map_resource_mission_script_files)
        self.insert_veaf_trigrules(new_map_resource_key_by_file)

    def update_dictionary_with_veaf_entries(self) -> dict:
        """
        Update the dictionary for all the VEAF triggers in the mission.
        """

        new_dictionary = {
            "VEAF_DictKey_ActionText_12001": f"return {'true' if self.dynamic_mode else 'false'} -- VEAF scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12002": f"return {'true' if self.dynamic_mode else 'false'} -- Mission scripts loading mode (false = static, true = dynamic)",
            "VEAF_DictKey_ActionText_12003": "return VEAF_DYNAMIC_SCRIPTSPATH~=nil",
            "VEAF_DictKey_ActionText_12004": "return VEAF_DYNAMIC_SCRIPTSPATH==nil",
            "VEAF_DictKey_ActionText_12005": "return VEAF_DYNAMIC_MISSIONPATH~=nil",
            "VEAF_DictKey_ActionText_12006": "return VEAF_DYNAMIC_MISSIONPATH==nil",
        }

        # merge the new dictionary with the mission dictionary
        assert self.dcs_mission is not None
        self.dcs_mission.dictionary_content = new_dictionary | (self.dcs_mission.dictionary_content or {})

        return new_dictionary

    def _resolves_load_trigger(self, filename: str) -> bool:
        """Returns True if a DCS load trigger should be generated for this script file.

        Args:
            filename: The script filename (basename only).

        Returns:
            For declared scripts: the per-script override if set, otherwise the global default.
            For undeclared scripts (not in custom_scripts): always True — standard and unknown
            files are always loaded; the global default applies only to declared custom scripts.
        """
        for cs in self.custom_scripts:
            if cs.path == filename:
                if cs.generate_load_trigger is not None:
                    return cs.generate_load_trigger
                return self.custom_scripts_generate_load_trigger
        return True

    #: Path (relative to VEAF_DYNAMIC_SCRIPTSPATH) of the framework loader for each mode.
    #: DEV loads the individual veaf scripts via VeafDynamicLoader.lua (needs a repo
    #: checkout); PROD loads the concatenated bundle shipped in published.zip.
    _DYNAMIC_FRAMEWORK_LOADER_DEV = "/src/scripts/VeafDynamicLoader.lua"
    _DYNAMIC_FRAMEWORK_LOADER_PROD = "/src/scripts/veaf/veaf-scripts.lua"

    def _dynamic_framework_load_path(self) -> str:
        """Return the framework script to load dynamically, depending on dev vs prod mode."""
        return self._DYNAMIC_FRAMEWORK_LOADER_DEV if self.dev_mode else self._DYNAMIC_FRAMEWORK_LOADER_PROD

    def _ordered_mission_script_names(self) -> list[str]:
        """Ordered basenames of the mission scripts that get a load trigger.

        This is the single source of truth shared by the static load triggers and
        the generated ``veafDynamicConfig.lua`` (dynamic mode), guaranteeing both
        modes load the same files — including the mission maker's ``custom_scripts``.
        """
        return [
            Path(script_file_name).name
            for script_file_name in self.get_collected_mission_script_files()
            if self._resolves_load_trigger(Path(script_file_name).name)
            # veafDynamicConfig.lua IS the dynamic loader (loaded directly by the
            # dynamic mission trigger); it must never appear in the list it iterates,
            # or it would load itself in an infinite loop.
            and Path(script_file_name).name != "veafDynamicConfig.lua"
        ]

    def generate_veaf_dynamic_config(self) -> None:
        """Generate ``src/scripts/veafDynamicConfig.lua`` from the mission script list.

        In dynamic mode this file is loaded from disk and decides which mission
        scripts to load. Generating it from :meth:`_ordered_mission_script_names`
        (the same list used by the static triggers) guarantees the mission maker's
        ``custom_scripts`` are loaded dynamically too — the file is generated, not
        hand-edited (declare scripts in ``mission.yaml`` ``custom_scripts:``).
        """
        scripts = self._ordered_mission_script_names()
        scripts_lua = "\n".join(f'    "{name}",' for name in scripts)
        content = (
            "-- GENERATED by veaf-tools build — do NOT edit by hand.\n"
            "-- Declare your scripts in mission.yaml (custom_scripts:); this list mirrors\n"
            "-- the static load triggers so dynamic and static builds load the same files.\n"
            "local scriptsToLoad =\n"
            "{\n"
            f"{scripts_lua}\n"
            "}\n\n"
            "if (VEAF_DYNAMIC_MISSIONPATH) then\n"
            "    local sMissionScriptsPath = VEAF_DYNAMIC_MISSIONPATH .. [[src\\scripts\\]]\n"
            "    for _, script in ipairs(scriptsToLoad) do\n"
            "        local sPathToExec = sMissionScriptsPath .. script\n"
            '        veaf.loggers.get(veaf.Id):info("DynamicConfig: loading " .. sPathToExec)\n'
            "        assert(loadfile(sPathToExec))()\n"
            "    end\n"
            "else\n"
            '        veaf.loggers.get(veaf.Id):error("DynamicConfig: cannot load because the VEAF_DYNAMIC_MISSIONPATH is not set")\n'
            "end\n"
        )
        config_path = self.mission_folder / "src" / "scripts" / "veafDynamicConfig.lua"
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(content, encoding="utf-8")
        logger.debug(f"Generated {config_path} with {len(scripts)} mission script(s)")

    def update_map_resource_with_veaf_entries(self) -> tuple[dict, dict, dict]:
        """
        Update the map resource for all the VEAF triggers in the mission.
        """

        new_map_resource_key_by_file = {}
        new_map_resource_script_files = {}
        for map_resource_key_index, script_file_name in enumerate(
            self.get_collected_community_script_files() | self.get_collected_veaf_script_files()
        ):
            map_resource_key = f"VEAF_MapKey_ActionText_10{map_resource_key_index:03}"
            new_map_resource_key_by_file[script_file_name] = map_resource_key
            new_map_resource_script_files[map_resource_key] = Path(script_file_name).name

        new_map_resource_mission_script_files = {}
        trigger_key_index = 0
        for script_file_name in self.get_collected_mission_script_files():
            if not self._resolves_load_trigger(Path(script_file_name).name):
                continue
            map_resource_key = f"VEAF_MapKey_ActionText_11{trigger_key_index:03}"
            trigger_key_index += 1
            new_map_resource_key_by_file[script_file_name] = map_resource_key
            new_map_resource_mission_script_files[map_resource_key] = Path(script_file_name).name

        # merge the new mapResource with the mission mapResource
        assert self.dcs_mission is not None
        self.dcs_mission.map_resource_content = (
            new_map_resource_script_files
            | new_map_resource_mission_script_files
            | (self.dcs_mission.map_resource_content or {})
        )

        return new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file

    def insert_veaf_triggers(
        self, new_dictionary: dict, new_map_resource_script_files: dict, new_map_resource_mission_script_files: dict
    ) -> None:
        """
        Create all the VEAF triggers in the mission.
        We'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        """

        def transform_triggers_dcs_structure_to_new_structure(triggers) -> dict:
            """
            Converts DCS triggers structure to our new triggers structure
            DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
            Each of these categories is a LUA table with all the data for each trigger about this category.
            To properly insert our VEAF triggers to the mission triggers, we need to make sure that we move (shift) all the keys in each category in a coherent fashion.
            """
            # Let's create a better structure: a list of triggers which all have the corresponding categories.
            category_names = triggers.keys()
            result: dict = {}
            action_keys = sorted(
                triggers["actions"].keys()
            )  # this is the most complete category, it always contains all the triggers; this is important later
            for category_name in category_names:
                category_data = triggers[category_name]
                for trigger_key in action_keys:
                    if trigger_key not in result:
                        # create the new trigger in the new structure
                        result[trigger_key] = {}
                    if trigger_key in category_data:
                        # update the new trigger in the new structure to the category value
                        result[trigger_key][category_name] = category_data[trigger_key]
                    else:
                        # update the new trigger in the new structure to an empty value
                        result[trigger_key][category_name] = None

            return result

        def transform_triggers_new_structure_to_dcs_structure(triggers) -> dict:
            """
            Converts our new triggers structure back to DCS triggers structure
            DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
            Each of these categories is a LUA table with all the data for each trigger about this category.
            """

            result: dict = {}
            for trigger_key, trigger_data in triggers.items():
                for category_name, category_data in trigger_data.items():
                    if category_name not in result:
                        result[category_name] = {}
                    if category_data:
                        result[category_name][trigger_key] = category_data

            return result

        conditions_trigger = {
            idx + 1: f'return(c_predicate(getValueDictByKey("{new_dict_key}")) )'
            for idx, new_dict_key in enumerate(new_dictionary)
        }

        dynamic_script_loading_trigger = (
            'a_do_script("env.info(\\"DYNAMIC VEAF scripts loading from \\"..VEAF_DYNAMIC_SCRIPTSPATH)");'
        )
        for file in self._active_community_scripts():
            dynamic_script_loading_trigger += (
                f'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"{file["path"]}\\"))()");'
            )
        dynamic_script_loading_trigger += f'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"{self._dynamic_framework_load_path()}\\"))()");'

        static_script_loading_trigger = 'a_do_script("env.info(\\"STATIC VEAF scripts loading\\")");'
        for map_resource_key in new_map_resource_script_files:
            static_script_loading_trigger += f'a_do_script_file(getValueResourceByKey("{map_resource_key}"));'

        dynamic_mission_loading_trigger = 'a_do_script("env.info(\\"DYNAMIC Mission scripts loading from \\"..VEAF_DYNAMIC_MISSIONPATH)");a_do_script("assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \\"/src/scripts/veafDynamicConfig.lua\\"))()");'

        static_mission_loading_trigger = 'a_do_script("env.info(\\"STATIC Mission scripts loading\\")");'
        for map_resource_key in new_map_resource_mission_script_files:
            static_mission_loading_trigger += f'a_do_script_file(getValueResourceByKey("{map_resource_key}"));'

        VEAF_DYNAMIC_SCRIPTSPATH = (
            f"[[{self.scripts_path.resolve().as_posix()}/]]"
            if self.scripts_path
            else f"[[{(self.output_mission.parent / 'published').resolve().as_posix()}/]]"
        )
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_triggers = {
            "customStartup": {},
            "func": {},
            "custom": {},
            "events": {},
            "flag": {1: True, 2: True, 3: True, 4: True, 5: True, 6: True},
            "conditions": conditions_trigger,
            "actions": {
                1: f'a_do_script("VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}");',
                2: f'a_do_script("VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}");',
                3: f"{dynamic_script_loading_trigger}",
                4: f"{static_script_loading_trigger}",
                5: f"{dynamic_mission_loading_trigger}",
                6: f"{static_mission_loading_trigger}",
            },
            "funcStartup": {
                1: "if mission.trig.conditions[1]() then mission.trig.actions[1]() end",
                2: "if mission.trig.conditions[2]() then mission.trig.actions[2]() end",
                3: "if mission.trig.conditions[3]() then mission.trig.actions[3]() end",
                4: "if mission.trig.conditions[4]() then mission.trig.actions[4]() end",
                5: "if mission.trig.conditions[5]() then mission.trig.actions[5]() end",
                6: "if mission.trig.conditions[6]() then mission.trig.actions[6]() end",
            },
        }

        assert self.dcs_mission is not None
        assert self.dcs_mission.mission_content is not None
        mission_triggers = self.dcs_mission.mission_content["trig"]
        # DCS triggers structure is a bit weird: it has different categories (actions, conditions, custom, customStartup, events, flag. funcStartup. funcStartup).
        # Each of these categories is a LUA table with all the data for each trigger about this category.
        # To properly insert our VEAF triggers to the mission triggers, we need to make sure that we move (shift) all the keys in each category in a coherent fashion.

        # Let's create a better structure: a list of triggers which all have the corresponding categories.
        mission_triggers_new_structure = transform_triggers_dcs_structure_to_new_structure(mission_triggers)

        # Now let's transform our new triggers structure, too
        veaf_triggers_new_structure = transform_triggers_dcs_structure_to_new_structure(veaf_triggers)

        # Shift all the triggers up and update the LUA code if needed (whenever it contains "mission.trig.conditions[xx]" with xx the original trigger key)
        result_triggers_new_structure = {}
        nb_new_triggers = len(veaf_triggers_new_structure)
        for new_key, old_key in enumerate(sorted(mission_triggers_new_structure.keys()), start=nb_new_triggers + 1):
            result_trigger_new_structure = result_triggers_new_structure[new_key] = mission_triggers_new_structure[
                old_key
            ].copy()
            if new_key != old_key:
                for category_name, category_value in result_trigger_new_structure.items():
                    new_category_value = category_value  # default value, if there is no need for updating the LUA
                    if isinstance(category_value, str):
                        # update the LUA code to reflect the shift
                        new_category_value = re.sub(f"\\[{old_key}\\]", f"[{new_key}]", category_value)
                    result_trigger_new_structure[category_name] = new_category_value

        # Insert the new VEAF triggers at the beginning of our new structure
        for new_trigger_key, new_trigger_data in veaf_triggers_new_structure.items():
            result_triggers_new_structure[new_trigger_key] = new_trigger_data

        # Convert the new structure back to a valid DCS structure
        self.dcs_mission.mission_content["trig"] = transform_triggers_new_structure_to_dcs_structure(  # type: ignore[index]
            result_triggers_new_structure
        )

    def insert_veaf_trigrules(self, new_map_resource_key_by_file: dict) -> None:
        """
        Create all the VEAF trigrules in the mission.
        We'll add 6 trigrules corresponding to the 6 new triggers.
        All existing trigrules will be shifted 6 ranks up, changing the indexes in the LUA code.
        """

        VEAF_DYNAMIC_SCRIPTSPATH = (
            f"[[{self.scripts_path.resolve().as_posix()}/]]"
            if self.scripts_path
            else f"[[{(self.output_mission.parent / 'published').resolve().as_posix()}/]]"
        )
        veaf_dynamic_mission_path = f"[[{(self.output_mission.parent).resolve().as_posix()}/]]"

        veaf_community_scripts_map_keys = [
            new_map_resource_key_by_file.get(script_file_name, "")
            for script_file_name in self.get_collected_community_script_files()
        ]
        veaf_scripts_map_keys = [
            new_map_resource_key_by_file.get(script_file_name, "")
            for script_file_name in self.get_collected_veaf_script_files()
        ]

        veaf_mission_config_map_key = new_map_resource_key_by_file.get(
            f"{DEFAULT_SCRIPTS_LOCATION}/mission-script.lua", ""
        )
        # Optional generated config, loaded before mission-script.lua
        veaf_modules_config_map_key = new_map_resource_key_by_file.get(
            f"{DEFAULT_SCRIPTS_LOCATION}/veaf-config.lua", ""
        )

        static_script_loading_actions = [
            {"predicate": "a_do_script", "text": 'env.info("STATIC VEAF scripts loading")'}
        ]
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"} for file_path in veaf_community_scripts_map_keys
        )
        static_script_loading_actions.extend(
            {"predicate": "a_do_script_file", "file": f"{file_path}"} for file_path in veaf_scripts_map_keys
        )

        dynamic_script_loading_actions = [
            {
                "predicate": "a_do_script",
                "text": 'env.info("DYNAMIC VEAF scripts loading from "..VEAF_DYNAMIC_SCRIPTSPATH)',
            }
        ]
        dynamic_script_loading_actions.extend(
            {
                "predicate": "a_do_script",
                "text": f'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "{file["path"]}"))()',
            }
            for file in self._active_community_scripts()
        )
        dynamic_script_loading_actions.append(
            {
                "predicate": "a_do_script",
                "text": f'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "{self._dynamic_framework_load_path()}"))()',
            }
        )

        new_trigrules_list = [
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12001",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12001",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading method",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {"predicate": "a_do_script", "text": f"VEAF_DYNAMIC_SCRIPTSPATH = {VEAF_DYNAMIC_SCRIPTSPATH}"}
                ],
                "colorItem": "0x00ffffff",
            },
            {
                "rules": [
                    {
                        "flag": 1,
                        "text": "VEAF_DictKey_ActionText_12002",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12002",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading method",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {"predicate": "a_do_script", "text": f"VEAF_DYNAMIC_MISSIONPATH = {veaf_dynamic_mission_path}"}
                ],
                "colorItem": "0x00ffffff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12003",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12003",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": dynamic_script_loading_actions,
                "colorItem": "0x00ff80ff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12004",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12004",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "VEAF scripts loading - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": static_script_loading_actions,
                "colorItem": "0x00ff80ff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12005",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12005",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading - dynamic",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": 'env.info("DYNAMIC Mission scripts loading from "..VEAF_DYNAMIC_MISSIONPATH)',
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184,
                    },
                    # veafDynamicConfig.lua loads every mission script in order, veaf-config.lua
                    # first (it heads scriptsToLoad). Loading veaf-config.lua explicitly here too
                    # would run it twice → modules initialized twice → duplicated marker handlers.
                    {
                        "predicate": "a_do_script",
                        "text": 'assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua"))()',
                    },
                ],
                "colorItem": "0x8080ffff",
            },
            {
                "rules": [
                    {
                        "text": "VEAF_DictKey_ActionText_12006",
                        "KeyDict_text": "VEAF_DictKey_ActionText_12006",
                        "predicate": "c_predicate",
                    }
                ],
                "comment": "Mission scripts loading - static",
                "predicate": "triggerStart",
                "eventlist": "",
                "actions": [
                    {
                        "text": 'env.info("STATIC Mission scripts loading")',
                        "meters": 1000,
                        "predicate": "a_do_script",
                        "zone": 184,
                    },
                    # Load veaf-config.lua before mission-script.lua (if present)
                    *(
                        [{"predicate": "a_do_script_file", "file": f"{veaf_modules_config_map_key}"}]
                        if veaf_modules_config_map_key
                        else []
                    ),
                    {"predicate": "a_do_script_file", "file": f"{veaf_mission_config_map_key}"},
                ],
                "colorItem": "0x8080ffff",
            },
        ]

        # compress the dictionary keyset, leaving space for the VEAF trigrules
        assert self.dcs_mission is not None
        assert self.dcs_mission.mission_content is not None
        trigrules = self.dcs_mission.mission_content["trigrules"]
        new_trigrules = dict(enumerate(new_trigrules_list, start=1))
        nb_new_trigrules = len(new_trigrules)
        result_trigrules = {
            new_key: trigrules[old_key]
            for new_key, old_key in enumerate(sorted(trigrules.keys()), start=nb_new_trigrules + 1)
        }
        # insert the new elements
        for new_index, new_item in new_trigrules.items():
            result_trigrules[new_index] = new_item
        # set the new dictionary
        self.dcs_mission.mission_content["trigrules"] = result_trigrules  # type: ignore[index]

    def write_mission(self) -> None:
        """Write the mission file."""

        logger.debug("Writing mission file")
        assert self.dcs_mission is not None
        additional_files: dict[str, bytes] = {}
        if self.dcs_bridge_bytes is not None:
            from mission_tools import DEFAULT_SCRIPTS_LOCATION

            additional_files[f"{DEFAULT_SCRIPTS_LOCATION}/dcs-bridge.lua"] = self.dcs_bridge_bytes
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission, additional_files=additional_files)
        logger.debug("Writing mission file done")

    def _detect_era_from_base(self) -> str | None:
        """Auto-detect the mission era from the base mission's units and date.

        Reads the unpacked DCS ``mission`` table from ``src/mission/`` (available
        before the output ``.miz`` is built) and runs the era heuristic. Used only
        when ``mission.yaml`` does not set ``mission.era`` — a manual value always
        wins (ERA-AUTODETECT-002).

        Returns:
            The detected era, or ``None`` when the base mission cannot be read.
        """
        mission_file = self.mission_folder / "src" / "mission" / "mission"
        if not mission_file.exists():
            return None
        try:
            content = luadata.unserialize(mission_file.read_text(encoding="utf-8"), keep_as_dict=["trig", "trigrules"])
        except Exception as exc:  # noqa: BLE001 - era detection must never break the build
            logger.debug(f"era auto-detect: could not parse base mission {mission_file}: {exc}")
            return None
        if not isinstance(content, dict):
            return None
        return detect_era(content)

    def write_config_lua(self) -> None:
        """Write veaf-config.lua from mission_yaml (or legacy lua_modules / global_log_level)."""
        # Build a YAML dict to pass to the generator
        if self.mission_yaml:
            yaml_dict: dict = dict(self.mission_yaml)
            # Allow lua_modules / global_log_level params to override if mission_yaml doesn't have them
            if self.global_log_level and "global_log_level" not in yaml_dict:
                yaml_dict["global_log_level"] = self.global_log_level
            if self.lua_modules and "lua_modules" not in yaml_dict:
                yaml_dict["lua_modules"] = self.lua_modules
        else:
            yaml_dict = {}
            if self.global_log_level:
                yaml_dict["global_log_level"] = self.global_log_level
            if self.lua_modules:
                yaml_dict["lua_modules"] = self.lua_modules

        # ERA-AUTODETECT-002: fill in the era only when the user did not set it.
        mission_cfg = dict(yaml_dict.get("mission") or {})
        if not mission_cfg.get("era"):
            detected_era = self._detect_era_from_base()
            if detected_era:
                mission_cfg["era"] = detected_era
                yaml_dict["mission"] = mission_cfg
                logger.info(t("builder.era_detected", era=detected_era))

        if not yaml_dict:
            return

        scripts_dir = self.mission_folder / "src" / "scripts"
        scripts_dir.mkdir(parents=True, exist_ok=True)
        config_file = scripts_dir / "veaf-config.lua"
        content = generate_config_lua(yaml_dict)
        config_file.write_text(content, encoding="utf-8")
        logger.info(t("builder.veaf_config_generated", file=config_file))

    def work(self, silent: bool = False) -> Path:
        """Main work function."""

        # Complete the src folder with default files if they don't exist
        with spinner_context(t("builder.completing_defaults", folder=self.mission_folder), silent=silent):
            self.complete_src_folder_with_defaults()

        # Generate veaf-config.lua from mission_yaml / lua_modules / global_log_level if provided
        if self.mission_yaml or self.lua_modules or self.global_log_level:
            with spinner_context(t("builder.generating_config"), silent=silent):
                self.write_config_lua()
            # Invalidate cached mission script files so the new file is picked up
            self.collected_mission_script_files = None

        # Regenerate veafDynamicConfig.lua so dynamic mode loads the same mission
        # scripts (incl. custom_scripts) as the static triggers.
        with spinner_context(t("builder.generating_dynamic_config"), silent=silent):
            self.generate_veaf_dynamic_config()

        # Create the initial mission file
        with spinner_context(t("builder.creating_mission", output=self.output_mission), silent=silent):
            self.create_mission()

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        with spinner_context(t("builder.reading_mission", output=self.output_mission), silent=silent):
            self.read_mission()

        # Ensure each side coalition owns at least one unit (hidden placeholder if not)
        self.ensure_coalitions_populated()

        # Warn about config-declared groups (ASSETS, QRA, …) absent from the mission
        self.validate_declared_groups()

        # First, remove all the VEAF triggers
        with spinner_context(t("builder.clearing_triggers"), silent=silent):
            self.clear_veaf_triggers()

        # Then, add all the VEAF triggers we need
        if not self.no_veaf_triggers:
            with spinner_context(t("builder.updating_triggers"), silent=silent):
                self.insert_all_veaf_triggers()
        elif not silent:
            logger.info(t("builder.skip_veaf_triggers"))

        # Optionally inject dcs-bridge.lua before all other triggers
        if self.dcs_bridge_enabled:
            with spinner_context(t("builder.inject_dcs_bridge"), silent=silent):
                bridge_file = self.resolve_dcs_bridge_file()
                self.inject_dcs_bridge_trigger(bridge_file)

        # Write the mission file
        with spinner_context(t("builder.writing_mission", output=self.output_mission), silent=silent):
            self.write_mission()

        if not silent:
            logger.tech(t("builder.built", output=self.output_mission, folder=self.mission_folder))

        return self.output_mission
