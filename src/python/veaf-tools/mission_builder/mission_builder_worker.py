"""
Worker module for the VEAF Mission Builder Package.
"""

import fnmatch
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
from veaf_libs.build_profiles import pipeline_step_enabled_anywhere, resolve_profile
from veaf_libs.build_stamp import get_build_stamp
from veaf_libs.checklist_images import ChecklistImages, render_all
from veaf_libs.checklists import Checklist, load_checklists, load_mission_checklists, select_activated
from veaf_libs.config_override import (
    OVERRIDE_SCRIPT_NAME,
    find_unknown_segments,
    read_corpus,
    render_override_lua,
)
from veaf_libs.conversion_profile import incompatible_modules_enabled
from veaf_libs.ctld_config import CTLD_CONFIG_FILENAME, CTLD_USER_CONFIG_FILENAME
from veaf_libs.dcs_countries import all_country_ids
from veaf_libs.i18n import current_language, t, tn
from veaf_libs.logger import logger
from veaf_libs.lua_config_generator import enabled_module_config, find_undefined_lua_functions, generate_config_lua
from veaf_libs.lua_i18n import load_runtime_catalog
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.paths import resolve_path
from veaf_libs.progress import spinner_context
from veaf_libs.yaml_validator import validate_modules_semantics, validate_yaml_file

from mission_builder.coalition_placeholder import ensure_coalitions_populated
from mission_builder.era_detector import detect_era
from mission_builder.third_party_mods import strip_third_party_mods
from mission_builder.warehouses_bootstrap import ensure_airports_populated

_DCS_BRIDGE_DOWNLOAD_URL = (
    "https://raw.githubusercontent.com/VEAF/VEAF-dcs-bridge/refs/heads/develop/src/lua/dcs-bridge.lua"
)

#: Upper bound on the auto-downloaded bridge (SECREV-2 / VMR-034). Measured at 13 237 bytes on
#: 2026-08-10, so 2 MiB leaves ~150x for growth while still refusing an absurd response.
_DCS_BRIDGE_MAX_BYTES = 2 * 1024 * 1024


def _lua_long_bracket(text: str) -> str:
    """Wrap *text* in a Lua long-bracket literal, escaping nothing.

    A YAML snapshot is multi-line and quote-laden, so a quoted Lua string is not an
    option — the trig emitter escapes double quotes but not newlines. Long brackets
    take the text verbatim; the only hazard is the closing sequence appearing inside,
    which is why the level grows until it cannot collide.

    A leading newline is added after the opening bracket: Lua drops a first newline
    immediately following it, and without one a snapshot starting with a blank line
    would silently lose it.

    Args:
        text: The literal content (typically a YAML document).

    Returns:
        The ``[==[ … ]==]`` literal, at the lowest safe level.
    """
    level = 0
    while f"]{'=' * level}]" in text:
        level += 1
    equals = "=" * level
    return f"[{equals}[\n{text}]{equals}]"


# Lua files that are always expected in src/scripts/ of a VEAF v6 mission folder.
# Any other .lua file found there is flagged as a potential v5 residue.
_EXPECTED_SCRIPTS: frozenset[str] = frozenset(
    {
        "veaf-config.lua",
        "mission-script.lua",
        "veafDynamicConfig.lua",
        CTLD_USER_CONFIG_FILENAME,
        OVERRIDE_SCRIPT_NAME,
    }
)


@dataclass
class CustomScript:
    """A custom Lua script declared in the custom_scripts section of mission.yaml.

    Attributes:
        path: The script's base name.
        generate_load_trigger: Per-script override of the section's default.
        delay_seconds: Wall-clock delay before loading, or ``None`` for the shared
            ``triggerStart``. ``None`` and ``0`` are deliberately different: zero would be a
            delayed trigger firing on the first tick, i.e. one more trigger for the same result.
    """

    path: str
    generate_load_trigger: bool | None = field(default=None)
    delay_seconds: float | None = field(default=None)


def _parse_custom_scripts(cs_raw: object) -> tuple[bool, list[CustomScript]]:
    """Parse the ``custom_scripts`` section of ``mission.yaml``.

    Extracted from ``__init__`` so the validation below can be tested against the real code
    rather than against a copy of it — the pre-existing parsing test had to replicate the loop,
    which is how a copy comes to disagree with its original.

    Args:
        cs_raw: The raw ``custom_scripts`` value, of whatever type the YAML happened to hold.

    Returns:
        ``(generate_load_trigger, scripts)`` — the section default and the declared scripts,
        in declaration order.
    """
    if cs_raw is not None and not isinstance(cs_raw, dict):
        logger.warning(t("builder.custom_scripts_not_mapping", type=type(cs_raw).__name__))
        cs_raw = None
    cs_section: dict = cs_raw or {}
    if not cs_section:
        return True, []

    generate_load_trigger = bool(cs_section.get("generate_load_trigger", True))
    scripts: list[CustomScript] = []
    for script_item in cs_section.get("scripts") or []:
        if isinstance(script_item, dict):
            path = script_item.get("path", "")
            per_script_trigger: bool | None = script_item.get("generate_load_trigger")
            delay = _parse_delay_seconds(script_item.get("delay_seconds"), Path(str(path)).name)
        else:
            path = str(script_item)
            per_script_trigger = None
            delay = None
        scripts.append(
            CustomScript(path=Path(path).name, generate_load_trigger=per_script_trigger, delay_seconds=delay)
        )
    return generate_load_trigger, scripts


def _parse_delay_seconds(raw: object, script_name: str) -> float | None:
    """Validate a ``delay_seconds`` value, warning and returning ``None`` when unusable.

    A bad delay never costs the script: it loads in the shared trigger, which is what it did
    before the key existed. Dropping the whole entry over a mistyped delay would silently remove
    a script the mission needs — a worse outcome than losing the staging.

    Args:
        raw: The declared value, of any type.
        script_name: Base name of the script, so the warning names the culprit.

    Returns:
        The delay in seconds, or ``None`` when absent or unusable.
    """
    if raw is None:
        return None
    # bool is an int in Python, and `delay_seconds: true` is a mistake, not a one-second delay.
    if isinstance(raw, bool) or not isinstance(raw, (int, float)):
        logger.warning(t("builder.custom_script_delay_invalid", script=script_name, value=raw))
        return None
    if raw <= 0:
        logger.warning(t("builder.custom_script_delay_not_positive", script=script_name, value=raw))
        return None
    return float(raw)


# --- Unified VEAF load-trigger specification -------------------------------------
# A VEAF load trigger is written into BOTH the DCS ``trig`` table (compiled form)
# and the ``trigrules`` table (editor form). Historically each was hand-built
# separately and drifted (see CUSTOM-SCRIPTS-TRIGGERS / C6). They are now derived
# from a single ordered list of VeafTriggerSpec so the two forms can never diverge.


@dataclass(frozen=True)
class LuaAction:
    """A raw Lua statement run by an action.

    The ``lua`` is the logical (unescaped) statement. The ``trig`` emitter wraps it
    as ``a_do_script("<escaped>")``; the ``trigrules`` emitter stores it raw in
    ``text``.
    """

    lua: str


@dataclass(frozen=True)
class FileAction:
    """Load an embedded script by its mapResource key (``a_do_script_file``)."""

    map_key: str


@dataclass(frozen=True)
class SoundAction:
    """Play an embedded sound to one country (``a_out_sound_c``).

    Emitted for one reason only: to make the ``.ogg`` a resource the Mission Editor **declares**.
    CTLD and CSAR play these by filename at runtime, from a script the editor never reads, so
    without this the files are orphans and an editor save deletes them
    (`FIX-COMMUNITY-SOUNDS-PRUNED`). ``country_id`` is deliberately a country the mission does not
    use, so the sound is never audible.
    """

    map_key: str
    country_id: int


@dataclass(frozen=True)
class VeafTriggerSpec:
    """One VEAF trigger, source of truth for both the trig and trigrules forms.

    Attributes:
        dict_key: Dictionary entry holding this trigger's Lua condition.
        comment: What the Mission Editor shows in its trigger list.
        color_item: The editor's colour for the row.
        rule_has_flag: Whether the editor rule carries ``flag = 1``.
        actions: What the trigger does, in order.
        delay_seconds: When set, the trigger becomes a ``triggerOnce`` gated on
            ``c_time_after`` instead of a ``triggerStart``. The three consequences in the
            compiled ``trig`` form were read out of an upstream `.miz`: the trigger lives in
            ``func`` rather than ``funcStartup``, its condition ANDs ``c_time_after``, and its
            action string ends by clearing its own ``func`` entry so it fires once.
    """

    dict_key: str
    comment: str
    color_item: str
    rule_has_flag: bool
    actions: list[LuaAction | FileAction | SoundAction]
    delay_seconds: float | None = None


#: Dictionary keys of the 6 VEAF load triggers, in order. Shared by the dictionary
#: population (:meth:`update_dictionary_with_veaf_entries`) and the trigger specs
#: (:meth:`_build_veaf_trigger_specs`) so a trigger's condition can never point at a
#: dictionary entry the other half forgot to write.
_VEAF_TRIGGER_DICT_KEYS: tuple[str, ...] = (
    "VEAF_DictKey_ActionText_12001",
    "VEAF_DictKey_ActionText_12002",
    "VEAF_DictKey_ActionText_12003",
    "VEAF_DictKey_ActionText_12004",
    "VEAF_DictKey_ActionText_12005",
    "VEAF_DictKey_ActionText_12006",
    # The 7th is the CTLD/CSAR sound declaration, emitted only when sounds are injected
    # (FIX-COMMUNITY-SOUNDS-PRUNED). Its dictionary entry is written unconditionally, which is
    # inert when the trigger is absent.
    "VEAF_DictKey_ActionText_12007",
)

#: Dictionary keys of the deferred mission-script triggers, one per distinct ``delay_seconds``
#: (FEAT-CUSTOM-SCRIPT-LOAD-DELAY). Numbered from 12008 so the seven fixed keys above keep
#: theirs, and generated on demand: a mission staging nothing declares none of these triggers,
#: though their dictionary entries are written anyway — inert, exactly like the 7th.
_VEAF_DELAY_TRIGGER_DICT_KEY_BASE = 12008

#: Distinct delays a single mission may declare. Twelve is far above anything observed (Foothold
#: stages twice) and exists so a generated mission cannot collide with the dictionary keys of
#: whatever is added after 12008 — a bound stated here rather than discovered by a key clash.
_VEAF_MAX_DELAY_GROUPS = 12


def _delay_trigger_dict_key(group_index: int) -> str:
    """Return the dictionary key of the *group_index*-th deferred trigger (0-based)."""
    return f"VEAF_DictKey_ActionText_{_VEAF_DELAY_TRIGGER_DICT_KEY_BASE + group_index}"


def format_delay_seconds(delay: float) -> str:
    """Render a delay for a human to read: ``12`` rather than ``12.0``, ``0.5`` kept.

    Public and shared with :mod:`mission_builder.other_converter`, which scaffolds the same value
    into a ``mission.yaml``. Two copies would let the build and the scaffold render one delay two
    ways, and the pair only has to disagree once to be confusing (Sourcery, #720).

    Args:
        delay: The delay in seconds.

    Returns:
        The shortest faithful rendering.
    """
    return str(int(delay)) if float(delay).is_integer() else str(delay)


def _emit_trig_condition(spec: VeafTriggerSpec) -> str:
    """Emit the compiled ``trig`` condition of *spec*.

    ``c_predicate`` is what makes a *static* trigger inert in a *dynamic* build (its dictionary
    entry reads ``return VEAF_DYNAMIC_MISSIONPATH==nil``), so a deferred trigger keeps it and ANDs
    the delay. Dropping it would load the deferred script in dynamic mode too, i.e. twice.

    Args:
        spec: The trigger.

    Returns:
        The Lua condition body.
    """
    predicate = f'c_predicate(getValueDictByKey("{spec.dict_key}"))'
    if spec.delay_seconds is None:
        return f"return({predicate} )"
    # Named rather than returned inline: this is generated Lua, but the i18n gate flags any
    # returned literal over 15 characters containing a space as untranslated user prose, and
    # exempting this file would grow a list the quality policy only ever shrinks.
    condition = f"return({predicate} and c_time_after({format_delay_seconds(spec.delay_seconds)}) )"
    return condition


#: Module id of the guided-assistance module, whose config selects the checklists to
#: activate and therefore the images to render into the ``.miz``.
_ASSIST_MODULE_ID = "ASSIST"

#: How a mission wants its checklists shown. ``picture`` renders one image per progress
#: state and embeds them — nice, and the F-16C's six steps already cost 68 KB. ``text``
#: renders **nothing**: the engine sends the current instruction as a message instead,
#: which is the whole reason the option exists.
_ASSIST_DISPLAY_PICTURE = "picture"
_ASSIST_DISPLAY_TEXT = "text"
_ASSIST_DISPLAY_MODES = frozenset({_ASSIST_DISPLAY_PICTURE, _ASSIST_DISPLAY_TEXT})


def _emit_trig_action_string(actions: list[LuaAction | FileAction | SoundAction]) -> str:
    """Emit the compiled ``trig`` form of a trigger's actions: one concatenated string.

    Each action becomes a ``;``-terminated Lua call. ``LuaAction`` is wrapped in
    ``a_do_script("…")`` with its inner double quotes escaped; ``FileAction`` becomes
    ``a_do_script_file(getValueResourceByKey("<key>"))``.

    Args:
        actions: The ordered actions of one :class:`VeafTriggerSpec`.

    Returns:
        The concatenated Lua string stored under the trigger's ``actions[idx]``.
    """
    parts: list[str] = []
    for action in actions:
        if isinstance(action, FileAction):
            parts.append(f'a_do_script_file(getValueResourceByKey("{action.map_key}"));')
        elif isinstance(action, SoundAction):
            parts.append(f'a_out_sound_c({action.country_id}, getValueResourceByKey("{action.map_key}"), 0);')
        else:
            escaped = action.lua.replace('"', '\\"')
            parts.append(f'a_do_script("{escaped}");')
    return "".join(parts)


def _emit_trigrule_actions(actions: list[LuaAction | FileAction | SoundAction]) -> list[dict]:
    """Emit the Mission Editor ``trigrules`` form of a trigger's actions: action dicts.

    ``LuaAction`` becomes ``{"predicate": "a_do_script", "text": <raw lua>}``;
    ``FileAction`` becomes ``{"predicate": "a_do_script_file", "file": <key>}``.

    Args:
        actions: The ordered actions of one :class:`VeafTriggerSpec`.

    Returns:
        The list stored under the trigrule's ``actions``.
    """
    result: list[dict] = []
    for action in actions:
        if isinstance(action, FileAction):
            result.append({"predicate": "a_do_script_file", "file": action.map_key})
        elif isinstance(action, SoundAction):
            # `meters` and `zone`, which the editor also writes on this predicate, are shared
            # leftovers from other actions and are omitted: a dangling zone id is worse than an
            # absent optional field. The compiled call takes three arguments and no zone.
            result.append(
                {
                    "predicate": "a_out_sound_c",
                    "countrylist": action.country_id,
                    "file": action.map_key,
                    "start_delay": 0,
                }
            )
        else:
            result.append({"predicate": "a_do_script", "text": action.lua})
    return result


#: Lua calls that load another script file — the sign of a custom "loader" script.
#: Kept deliberately broad (no attempt to parse the loaded list): we only detect
#: that the file loads scripts, then point the user at the v6 `custom_scripts:` way.
_LUA_SCRIPT_LOADER_RE = re.compile(r"\b(?:loadfile|dofile|require)\b|a_do_script_file|do_script_file")


def lua_loads_other_scripts(text: str) -> bool:
    """Return True when *text* looks like a Lua script that loads other scripts."""
    return bool(_LUA_SCRIPT_LOADER_RE.search(text))


def strip_native_load_triggers(dcs_mission: "DcsMission", labels: list[str]) -> None:
    """Remove native load triggers whose comment matches one of *labels* (glob).

    For a third-party mission adopted via ``convert-other``, the scripts are
    re-injected as ``custom_scripts``; their original native load triggers must be
    removed (``strip_native_triggers:``) so nothing is loaded twice. Mutates
    *dcs_mission* in place: drops the matching ``trigrules`` entries, the matching
    indices from every compiled ``trig`` category, and the ``mapResource`` keys of
    their ``a_do_script_file`` actions. No-op when *labels* is empty.

    Args:
        dcs_mission: The mission being built (mutated in place).
        labels: ``strip_native_triggers`` values — trigrule comments or globs.
    """
    if not labels or not dcs_mission.mission_content:
        return
    mission_content = dcs_mission.mission_content
    trigrules = mission_content.get("trigrules") or {}

    indices_to_remove: list = []
    map_keys_to_remove: list[str] = []
    for index, trigrule in list(trigrules.items()):
        if not isinstance(trigrule, dict):
            continue
        comment = str(trigrule.get("comment", ""))
        if not any(fnmatch.fnmatch(comment, label) for label in labels):
            continue
        indices_to_remove.append(index)
        actions = trigrule.get("actions")
        action_values = (
            actions if isinstance(actions, list) else list(actions.values()) if isinstance(actions, dict) else []
        )
        for action in action_values:
            if isinstance(action, dict) and action.get("predicate") == "a_do_script_file" and action.get("file"):
                map_keys_to_remove.append(action["file"])

    if not indices_to_remove:
        return

    for index in indices_to_remove:
        trigrules.pop(index, None)
    for category in (mission_content.get("trig") or {}).values():
        if isinstance(category, dict):
            for index in indices_to_remove:
                category.pop(index, None)
    if dcs_mission.map_resource_content:
        for key in map_keys_to_remove:
            dcs_mission.map_resource_content.pop(key, None)
    logger.info(tn("builder.stripped_native_triggers", len(indices_to_remove)))


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
        # Raw (pre-profile) mission.yaml — kept so the orphan-file check can reason
        # about every build context (base + all profiles), not just the resolved one.
        self._raw_yaml: dict = {}
        mission_yaml_path = mission_folder / "mission.yaml"
        if mission_yaml_path.exists():
            validate_yaml_file(mission_yaml_path)
            with mission_yaml_path.open("r", encoding="utf-8") as fh:
                raw_yaml: dict = yaml.safe_load(fh) or {}
            self._raw_yaml = raw_yaml
            self.mission_yaml = resolve_profile(raw_yaml, profile_name)
            validate_modules_semantics(self.mission_yaml)
            self.mission_yaml = _normalize_mission_yaml(self.mission_yaml)
            # A conversion-profile mission must not enable a module the profile marks
            # incompatible (e.g. CTLD on a Foothold mission) — fail fast, last rampart.
            if bad := incompatible_modules_enabled(self.mission_yaml):
                logger.error(
                    t(
                        "builder.incompatible_modules",
                        modules=", ".join(bad),
                        profile=self.mission_yaml.get("conversion_profile"),
                    ),
                    exception_type=ValueError,
                )
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
                tn(
                    "builder.log_modules_detail",
                    len(all_module_ids) - len(keep_modules),
                    module=sorted(keep_modules) or "none",
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
        self.custom_scripts_generate_load_trigger, self.custom_scripts = _parse_custom_scripts(
            self.mission_yaml.get("custom_scripts")
        )

        # Parse config_override section from mission.yaml (FOOTHOLD-V6-004).
        # target = the upstream config script the override layers on top of (its
        # basename anchors the load position); values = the globals to reassign.
        self.config_override_target: str | None = None
        self.config_override_values: dict = {}
        co_raw = self.mission_yaml.get("config_override")
        if isinstance(co_raw, dict):
            co_target = co_raw.get("target")
            self.config_override_target = Path(str(co_target)).name if co_target else None
            co_values = co_raw.get("values")
            if isinstance(co_values, dict):
                self.config_override_values = co_values

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
        #: Set only when the bridge was auto-downloaded, so it can be cleaned up without ever
        #: touching a `lua_path` the mission maker supplied (SECREV-2 / VMR-049).
        self._dcs_bridge_temp_file: Path | None = None

        # Guided checklists (FEAT-ASSIST-CHECKLISTS): resolved in write_config_lua, then
        # embedded as .miz resources. Empty when the ASSIST module activates none.
        self.checklist_images: list[ChecklistImages] = []

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
        self.collected_community_script_files = self._with_ctld_user_config(self.collected_community_script_files)
        return self.collected_community_script_files

    def _ctld_user_config_lua(self) -> str | None:
        """Build the Lua that hands the mission's CTLD configuration to CTLD 2.

        CTLD 2 reads a complete YAML snapshot from ``ctld.configUser`` and, unless
        ``ctld.dontInitialize`` is set first, starts itself on load. VEAF owns the
        init instead (ADR 0016), so the flag is emitted whether or not the mission
        carries a configuration file.

        Returns:
            The Lua source, or ``None`` when the CTLD module is disabled.
        """
        if not self._community_enabled("ctld"):
            return None

        lines = [
            "-- Generated by veaf-tools — do not edit.",
            "-- Hands the mission's CTLD configuration to CTLD 2 and defers its start-up",
            "-- to the VEAF framework (see docs/adr/0016-ctld2-sidecar-configuration.md).",
            "ctld = ctld or {}",
            "ctld.dontInitialize = true",
        ]
        config_file = self.mission_folder / CTLD_CONFIG_FILENAME
        if config_file.is_file():
            yaml_text = config_file.read_text(encoding="utf-8")
            lines.append(f"ctld.configUser = {_lua_long_bracket(yaml_text)}")
        else:
            logger.info(t("builder.ctld_no_config", file=CTLD_CONFIG_FILENAME))
        return "\n".join(lines) + "\n"

    def _with_ctld_user_config(self, collected: dict[str, bytes]) -> dict[str, bytes]:
        """Return *collected* with the generated CTLD user config inserted before CTLD.lua.

        Order is what matters: the static load trigger replays these entries in
        insertion order, so the configuration must sit immediately before the engine
        it configures. The generated entry borrows CTLD.lua's own destination folder so
        both land side by side in the ``.miz``.

        Args:
            collected: The community scripts collected for this build, in load order.

        Returns:
            A new dict, or *collected* unchanged when there is nothing to inject.
        """
        lua = self._ctld_user_config_lua()
        if lua is None:
            return collected
        ctld_key = next((key for key in collected if Path(key).name == "CTLD.lua"), None)
        if ctld_key is None:
            # CTLD enabled but its script is absent: the collection step already
            # reported it. Nothing to configure.
            return collected

        config_key = f"{Path(ctld_key).parent.as_posix()}/{CTLD_USER_CONFIG_FILENAME}"
        result: dict[str, bytes] = {}
        for key, value in collected.items():
            if key == ctld_key:
                result[config_key] = lua.encode("utf-8")
            result[key] = value
        return result

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
                # Read one byte past the cap so an oversized body is detected rather than streamed
                # into memory whole (SECREV-2 / VMR-034). The URL is a constant on a VEAF repository
                # over https, so there is no attacker-chosen host here and pinning a hash would
                # defeat the point — the bridge deliberately tracks its `develop` branch. The size
                # cap is what remains: this content is Lua that DCS will execute, and a runaway
                # response should fail with a clear message instead of filling the process.
                content: bytes = resp.read(_DCS_BRIDGE_MAX_BYTES + 1)
        except urllib.error.URLError as exc:
            raise RuntimeError(f"dcs_bridge: failed to download dcs-bridge.lua: {exc}") from exc

        if len(content) > _DCS_BRIDGE_MAX_BYTES:
            raise RuntimeError(
                f"dcs_bridge: dcs-bridge.lua is larger than the {_DCS_BRIDGE_MAX_BYTES} byte limit — refusing it"
            )

        tmp = tempfile.NamedTemporaryFile(suffix=".lua", delete=False)
        tmp.write(content)
        tmp.flush()
        tmp.close()
        # Remembered so `inject_dcs_bridge_trigger` can remove it once its bytes are read
        # (SECREV-2 / VMR-049 — every auto-download used to leave a stray .lua behind). Recording
        # *which* file we created is the point: the same argument also carries a `lua_path` the
        # mission maker provided, and deleting that would be a data-loss bug.
        self._dcs_bridge_temp_file = Path(tmp.name)
        return self._dcs_bridge_temp_file

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
        # The content now lives in memory and goes into the .miz from there, so a file we
        # downloaded ourselves has no reason to survive (SECREV-2 / VMR-049). Only ours —
        # never a path the mission maker gave us.
        if self._dcs_bridge_temp_file is not None and bridge_file == self._dcs_bridge_temp_file:
            self._dcs_bridge_temp_file.unlink(missing_ok=True)
            self._dcs_bridge_temp_file = None

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

        # Shift all existing trig entries up by 1.
        #
        # VMR-005: the shift alone is not enough, and shifting without this rewrite is what the
        # finding reported. `funcStartup` values are Lua **strings** carrying their own indices —
        # `if mission.trig.conditions[1]() then mission.trig.actions[1]() end` — so a trigger moved
        # from key 1 to key 2 kept calling `conditions[1]`, which by then is the bridge's. Every
        # previously inserted trigger fired the wrong pair. `insert_veaf_triggers` already gets
        # this right; the same `[old]` → `[new]` substitution is applied here, per entry, so each
        # string is only ever rewritten with its own key and neighbours cannot collide.
        trig: dict = self.dcs_mission.mission_content["trig"]
        for category_name, category_data in trig.items():
            if isinstance(category_data, dict):
                trig[category_name] = {
                    old_key + 1: (
                        re.sub(f"\\[{old_key}\\]", f"[{old_key + 1}]", value) if isinstance(value, str) else value
                    )
                    for old_key, value in category_data.items()
                }

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
                        # Only warn for a genuine orphan: a file no build context uses. If the
                        # step is disabled merely by the current profile but enabled by the base
                        # or another profile, the file is legitimate — stay silent (FIX-BUILD-PROFILES).
                        if dest.exists() and not pipeline_step_enabled_anywhere(self._raw_yaml, mapping["pipeline"]):
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

    def validate_references(self) -> None:
        """Collect every ``mission.yaml`` reference to a Mission-Editor object that is missing.

        Covers trigger zones / groups / units / airfields and undeclared COMBATZONE
        sub-zones. **Non-blocking**: findings are stored and reported as a single
        prominent warning summary at the very end of the build (see
        :meth:`report_reference_issues`) — blocking the build would deny the maker the
        `.miz` they need to fix the references in the Mission Editor and iterate.
        """
        self._reference_issues = []
        if not self.mission_yaml or not self.dcs_mission or not self.dcs_mission.mission_content:
            return
        from veaf_libs.mission_validator import validate_mission_content

        self._reference_issues = validate_mission_content(self.mission_yaml, self.dcs_mission.mission_content)

    def report_reference_issues(self) -> None:
        """Print the end-of-build summary of missing Mission-Editor references (non-blocking).

        The `.miz` is built regardless; this summary, framed so it stands out in the
        build output, makes the missing references impossible to overlook so the maker
        can fix them in the Mission Editor before the next run.
        """
        issues = getattr(self, "_reference_issues", None)
        if not issues:
            return
        bar = "─" * 72
        logger.warning(bar)
        logger.warning(tn("builder.reference_issues_header", len(issues)))
        for issue in issues:
            logger.warning(f"  • {issue.message}")
        logger.warning(bar)

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

    def ensure_airports_populated(self) -> None:
        """Give the mission a warehouse entry for every airfield of its theatre that lacks one.

        A `.miz` keeps each airfield's coalition and stock in ``warehouses.airports``, keyed by
        airdrome id. A mission built from a blank source has that table empty, and DCS then has no
        usable airfield: a slot parked on a ramp can be selected but never taken. Opening the
        mission in the DCS Mission Editor writes the entries, which is why such a mission "works
        when launched from the editor" — this does it at build time instead.

        The table is **completed**, not filled only when empty: one ``set_airbase_coalition`` call
        leaves a single entry, and stopping there would ship a mission with one airfield out of the
        theatre's. An entry that already exists keeps its own values and is completed key by key.
        See :func:`warehouses_bootstrap.ensure_airports_populated`.
        """
        if not self.dcs_mission or self.dcs_mission.warehouses_content is None:
            return
        theatre = str(self.dcs_mission.theatre_content or "")
        added = ensure_airports_populated(self.dcs_mission.warehouses_content, theatre=theatre)
        if added:
            logger.info(t("builder.warehouses_airports_populated", count=added, theatre=theatre))

    def strip_third_party_mod_requirements(self, silent: bool = False) -> None:
        """Make third-party aircraft mods non-blocking in the built mission.

        Strips the VEAF default third-party mods — unioned with the per-mission
        ``mission.third_party_mods`` list — from the mission's ``requiredModules``,
        so a pilot who lacks a mod can still load the mission (that slot is just
        unavailable). See :func:`third_party_mods.strip_third_party_mods`.

        Args:
            silent: When true, do not log the stripped mods.
        """
        if not self.dcs_mission or not self.dcs_mission.mission_content:
            return
        extra_mods = (self.mission_yaml.get("mission") or {}).get("third_party_mods") or []
        removed_mods = strip_third_party_mods(self.dcs_mission.mission_content, extra_mods)
        if removed_mods and not silent:
            logger.detail(t("builder.stripped_third_party_mods", mods=", ".join(removed_mods)))

    def clear_veaf_triggers(self) -> None:
        """
        Clears all the VEAF triggers from the current mission
        """

        # Legacy v5 trigger keys neutralised by migrate_from_v5, tracked so we can
        # nudge the maker to promote src/mission/ to v6 on disk (FEAT-MIGRATE-MISSION-V6).
        legacy_v5_keys: list[str] = []

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
                    if (
                        self.migrate_from_v5
                        # A v6 trigger is never a legacy v5 one: the MISSIONPATH conditions
                        # are regenerated verbatim by the v6 triggers (same dict keys), so
                        # match on the key, not just the value (FIX-V5-NUDGE-FALSE-POSITIVE).
                        and map_key not in _VEAF_TRIGGER_DICT_KEYS
                        and map_value
                        in [
                            "return false -- scripts",
                            "return false -- config",
                            "return true -- scripts",
                            "return true -- config",
                            "return VEAF_DYNAMIC_PATH~=nil",
                            "return VEAF_DYNAMIC_PATH==nil",
                            "return VEAF_DYNAMIC_MISSIONPATH~=nil",
                            "return VEAF_DYNAMIC_MISSIONPATH==nil",
                        ]
                    ):
                        # this is a legacy VEAF trigger, remove it
                        logger.debug(f"Removing legacy VEAF v5 dictionary key {map_key}={map_value}")
                        veaf_dict_keys_to_remove.append(map_key)
                        legacy_v5_keys.append(map_key)

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
            # VMR-050: every category is a dict, by construction — each read of mission_content
            # passes keep_as_dict=["trig", "trigrules"], and that policy covers the whole subtree
            # (pinned by test_secrev_trigger_categories_are_dicts.py). The collection loop used to
            # also handle a list-shaped category, which the removal loop below would have raised on
            # (`list.get`) — and which could never have been right anyway: a trigger index is shared
            # across categories, so mixing 0-based list positions with Lua's 1-based keys would
            # delete other triggers. So the shape is checked rather than half-handled.
            for trigger_category_name, trigger_category_value in mission_triggers.items():
                if not isinstance(trigger_category_value, dict):
                    # Fail closed: `logger.error` raises typer.Abort. Carrying on would leave the
                    # mission's VEAF triggers half-removed, which is worse than refusing to build.
                    logger.error(
                        t(
                            "builder.trig_category_not_a_dict",
                            category=trigger_category_name,
                            kind=type(trigger_category_value).__name__,
                        )
                    )
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

        # DEPRECATION (FEAT-MIGRATE-MISSION-V6): migrate_from_v5 had to neutralise legacy
        # v5 triggers in memory. Once src/mission/ is promoted to v6 on disk (convert-v5),
        # this step becomes unnecessary — nudge the maker to promote and drop the debt.
        if legacy_v5_keys:
            logger.warning(tn("builder.migrate_from_v5_deprecated", len(legacy_v5_keys)))

    def insert_all_veaf_triggers(self) -> None:
        """
        Create all the VEAF triggers in the mission.
        First, we'll update the dictionary.
        Then we'll add 6 triggers, all Mission Start with the right actions, conditions and funcStartup sub-categories.
        All existing triggers (all their items within the sub-categories) will be shifted 6 ranks up, changing the indexes in the LUA code.
        We'll also add 6 corresponding trigrules, shifting the existing ones accordingly
        """
        self.update_dictionary_with_veaf_entries()
        new_map_resource_script_files, new_map_resource_mission_script_files, _ = (
            self.update_map_resource_with_veaf_entries()
        )
        # Single ordered source of truth — both the compiled trig form and the editor
        # trigrules form are derived from this one list, so they can never diverge.
        specs = self._build_veaf_trigger_specs(new_map_resource_script_files, new_map_resource_mission_script_files)
        self.insert_veaf_triggers(specs)
        self.insert_veaf_trigrules(specs)

    def update_dictionary_with_veaf_entries(self) -> dict:
        """
        Update the dictionary for all the VEAF triggers in the mission.
        """

        mode = "true" if self.dynamic_mode else "false"
        keys = _VEAF_TRIGGER_DICT_KEYS
        new_dictionary = {
            keys[0]: f"return {mode} -- VEAF scripts loading mode (false = static, true = dynamic)",
            keys[1]: f"return {mode} -- Mission scripts loading mode (false = static, true = dynamic)",
            keys[2]: "return VEAF_DYNAMIC_SCRIPTSPATH~=nil",
            keys[3]: "return VEAF_DYNAMIC_SCRIPTSPATH==nil",
            keys[4]: "return VEAF_DYNAMIC_MISSIONPATH~=nil",
            keys[5]: "return VEAF_DYNAMIC_MISSIONPATH==nil",
            keys[6]: "return true -- declare the CTLD/CSAR sounds so the Mission Editor keeps them",
        }
        # The deferred mission-script triggers share the static-mission predicate: they must be
        # inert in a dynamic build, where veafDynamicConfig.lua schedules the same scripts itself.
        # Written for every possible group, not only the declared ones — an unused entry is inert,
        # and this way a trigger can never read a dictionary key the other half forgot.
        for group_index in range(_VEAF_MAX_DELAY_GROUPS):
            new_dictionary[_delay_trigger_dict_key(group_index)] = (
                "return VEAF_DYNAMIC_MISSIONPATH==nil -- deferred mission scripts (static mode only)"
            )

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

    def _ordered_mission_script_files(self) -> list[str]:
        """Ordered collected paths of the mission scripts that get a load trigger.

        Single source of truth shared by the static load triggers (mapResource +
        the static mission trigger) and the generated ``veafDynamicConfig.lua``
        (dynamic mode), guaranteeing both modes load the same files — including the
        mission maker's ``custom_scripts``.

        ``veafDynamicConfig.lua`` IS the dynamic loader (loaded directly by the
        dynamic mission trigger); it must never appear in the list it iterates (it
        would load itself in a loop) nor in the static list, so it is excluded here
        — in one place for every consumer.

        ``CTLD_userConfig.lua`` is excluded for the opposite reason: it is loaded
        *before* CTLD.lua by the script trigger, and the mission-script trigger runs
        after the whole framework — loading it there too would hand CTLD its
        configuration long after it has read it.
        """
        excluded = {"veafDynamicConfig.lua", CTLD_USER_CONFIG_FILENAME}
        files = [
            script_file_name
            for script_file_name in self.get_collected_mission_script_files()
            if self._resolves_load_trigger(Path(script_file_name).name) and Path(script_file_name).name not in excluded
        ]
        return self._position_config_override(self._apply_custom_scripts_order(files))

    def _apply_custom_scripts_order(self, files: list[str]) -> list[str]:
        """Return *files* with the declared ``custom_scripts`` in their declaration order.

        The collected mission scripts arrive in glob/collection order; the maker's
        intended load order is the ``custom_scripts:`` declaration order
        (FOOTHOLD-V6-008). Declared scripts are reordered **among the slots they
        already occupy**, so the positions of undeclared files (VEAF infra
        ``veaf-config.lua`` / ``mission-script.lua``, unknowns, the generated
        override) are preserved. A declared script absent from *files* (file not on
        disk) is skipped.

        Matching is by basename: ``custom_scripts`` paths are stored as basenames
        (see ``__init__``) and every mission script lives in ``src/scripts/`` (one
        directory), so basenames are unique and unambiguous here.

        *files* is not mutated; a reordered copy is returned.

        Args:
            files: The collected mission-script paths, in collection order.

        Returns:
            A new list with the declared scripts reordered (the same list contents
            when there is no ``custom_scripts`` or fewer than two are present).
        """
        declared: list[str] = []
        seen: set[str] = set()
        for cs in self.custom_scripts:  # cs.path is already a basename (set in __init__)
            if cs.path not in seen:
                seen.add(cs.path)
                declared.append(cs.path)
        if not declared:
            return files
        declared_set = set(declared)
        slots = [i for i, f in enumerate(files) if Path(f).name in declared_set]
        if len(slots) <= 1:
            return files
        by_name = {Path(files[i]).name: files[i] for i in slots}
        ordered = [by_name[name] for name in declared if name in by_name]
        result = list(files)
        for slot, path in zip(slots, ordered):
            result[slot] = path
        return result

    def _position_config_override(self, files: list[str]) -> list[str]:
        """Move the rendered config-override script to right after its target.

        The override must reassign the upstream globals **after** the config script
        defines them and **before** the setup script reads them (ADR 0008). It is
        positioned by file name, independent of the glob/collection order. When the
        target is not in the list, the override is appended so it still loads.

        Args:
            files: The collected mission-script paths, in collection order.

        Returns:
            The paths with the override repositioned (unchanged when there is no
            config_override).
        """
        if not self.config_override_values or not self.config_override_target:
            return files
        rest = [f for f in files if Path(f).name != OVERRIDE_SCRIPT_NAME]
        override = next((f for f in files if Path(f).name == OVERRIDE_SCRIPT_NAME), None)
        if override is None:
            return files
        target_idx = next((i for i, f in enumerate(rest) if Path(f).name == self.config_override_target), None)
        rest.insert(target_idx + 1 if target_idx is not None else len(rest), override)
        return rest

    def render_config_override(self) -> None:
        """Render ``config_override:`` to :data:`OVERRIDE_SCRIPT_NAME`, validated lexically.

        Build-blocking: aborts (``RuntimeError``) when an override key segment is
        found nowhere in the injected mission scripts — a typo or an upstream
        rename. The file is written only after validation passes, so an aborted
        build leaves no stale override. See ADR 0008.
        """
        if not self.config_override_values:
            return
        scripts_dir = self.mission_folder / "src" / "scripts"
        unknown = find_unknown_segments(self.config_override_values, read_corpus(scripts_dir))
        if unknown:
            logger.error(
                t("builder.config_override_unknown_segments", segments=", ".join(unknown)),
                exception_type=RuntimeError,
            )
        scripts_dir.mkdir(parents=True, exist_ok=True)
        override_file = scripts_dir / OVERRIDE_SCRIPT_NAME
        override_file.write_text(render_override_lua(self.config_override_values), encoding="utf-8")
        logger.info(tn("builder.config_override_generated", len(self.config_override_values), file=override_file))

    def _ordered_mission_script_names(self) -> list[str]:
        """Ordered basenames of the mission scripts — see :meth:`_ordered_mission_script_files`."""
        return [Path(p).name for p in self._ordered_mission_script_files()]

    def generate_ctld_user_config(self) -> None:
        """Write ``src/scripts/CTLD_userConfig.lua`` for dynamic mode.

        Static mode embeds the same Lua directly in the ``.miz`` (see
        :meth:`_with_ctld_user_config`); dynamic mode loads scripts off disk, so the
        generated file has to exist there too. Both come from the same builder, so the
        two modes cannot configure CTLD differently.

        The file is removed when CTLD is disabled, so a mission that turns the module
        off does not keep loading a stale configuration in dynamic mode.
        """
        config_file = self.mission_folder / "src" / "scripts" / CTLD_USER_CONFIG_FILENAME
        lua = self._ctld_user_config_lua()
        if lua is None:
            config_file.unlink(missing_ok=True)
            return
        config_file.parent.mkdir(parents=True, exist_ok=True)
        config_file.write_text(lua, encoding="utf-8")
        logger.debug(f"Generated {config_file}")

    def generate_veaf_dynamic_config(self) -> None:
        """Generate ``src/scripts/veafDynamicConfig.lua`` from the mission script list.

        In dynamic mode this file is loaded from disk and decides which mission
        scripts to load. Generating it from :meth:`_ordered_mission_script_names`
        (the same list used by the static triggers) guarantees the mission maker's
        ``custom_scripts`` are loaded dynamically too — the file is generated, not
        hand-edited (declare scripts in ``mission.yaml`` ``custom_scripts:``).
        """
        scripts = self._ordered_mission_script_names()
        delay_by_name = {
            script.path: script.delay_seconds for script in self.custom_scripts if script.delay_seconds is not None
        }
        scripts_lua = "\n".join(
            f'    {{ name = "{name}", delay = {format_delay_seconds(delay_by_name[name])} }},'
            if name in delay_by_name
            else f'    {{ name = "{name}" }},'
            for name in scripts
        )
        content = (
            "-- GENERATED by veaf-tools build — do NOT edit by hand.\n"
            "-- Declare your scripts in mission.yaml (custom_scripts:); this list mirrors\n"
            "-- the static load triggers so dynamic and static builds load the same files.\n"
            "-- A `delay` mirrors `delay_seconds:`, which in static mode is a triggerOnce with\n"
            "-- c_time_after; here it is a scheduled load, so both modes stage alike.\n"
            "local scriptsToLoad =\n"
            "{\n"
            f"{scripts_lua}\n"
            "}\n\n"
            "if (VEAF_DYNAMIC_MISSIONPATH) then\n"
            "    local sMissionScriptsPath = VEAF_DYNAMIC_MISSIONPATH .. [[src\\scripts\\]]\n"
            "    for _, script in ipairs(scriptsToLoad) do\n"
            "        local sPathToExec = sMissionScriptsPath .. script.name\n"
            "        if script.delay then\n"
            '            veaf.loggers.get(veaf.Id):info("DynamicConfig: loading " .. sPathToExec .. " in " .. script.delay .. "s")\n'
            "            timer.scheduleFunction(function()\n"
            '                veaf.loggers.get(veaf.Id):info("DynamicConfig: loading (delayed) " .. sPathToExec)\n'
            "                assert(loadfile(sPathToExec))()\n"
            "            end, {}, timer.getTime() + script.delay)\n"
            "        else\n"
            '            veaf.loggers.get(veaf.Id):info("DynamicConfig: loading " .. sPathToExec)\n'
            "            assert(loadfile(sPathToExec))()\n"
            "        end\n"
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
        # Single source of truth: same ordered, filtered list as the static mission
        # trigger and veafDynamicConfig.lua (excludes veafDynamicConfig.lua itself).
        for trigger_key_index, script_file_name in enumerate(self._ordered_mission_script_files()):
            map_resource_key = f"VEAF_MapKey_ActionText_11{trigger_key_index:03}"
            new_map_resource_key_by_file[script_file_name] = map_resource_key
            new_map_resource_mission_script_files[map_resource_key] = Path(script_file_name).name

        # merge the new mapResource with the mission mapResource. The checklist pictures
        # go in the same member — DCS resolves getValueResourceByKey against
        # l10n/DEFAULT/mapResource, not the mission table (see FIX-MAPRESOURCE-KEY).
        assert self.dcs_mission is not None
        self.dcs_mission.map_resource_content = (
            new_map_resource_script_files
            | new_map_resource_mission_script_files
            | self._checklist_resources()
            | (self.dcs_mission.map_resource_content or {})
        )

        return new_map_resource_script_files, new_map_resource_mission_script_files, new_map_resource_key_by_file

    def _veaf_dynamic_paths(self) -> tuple[str, str]:
        """Return the (scripts, mission) dynamic-load paths as Lua long-bracket literals.

        Both are absolute, ``/``-terminated paths wrapped in ``[[ ]]`` so they need no
        escaping when emitted into a Lua statement. The scripts path falls back to the
        output mission's ``published/`` folder when no explicit scripts path is set.

        Returns:
            A ``(scripts_path, mission_path)`` tuple of ``[[…/]]`` literals.
        """
        scripts_root = self.scripts_path or (self.output_mission.parent / "published")
        scripts_path = f"[[{scripts_root.resolve().as_posix()}/]]"
        mission_path = f"[[{self.output_mission.parent.resolve().as_posix()}/]]"
        return scripts_path, mission_path

    def _unused_country_id(self) -> int:
        """Return a DCS country id that the mission's coalitions do not contain.

        The CTLD/CSAR sound declaration has to name *some* country. Naming one the mission uses
        would make its pilots hear beacons at mission start, so the id is chosen by looking at the
        mission rather than hardcoded — a constant is correct only until someone uses that country.

        Returns:
            The **highest** known DCS country id absent from every coalition. High deliberately:
            the low ids are the countries missions actually use — 0 Russia, 1 Ukraine, 2 USA,
            3 Turkey — so picking the lowest free id would hand out Turkey on a Syria map and play
            beacons at its pilots. The top of the table (92 New Zealand, 90 Ecuador, 89 Peru) is
            where nobody is. Falls back to the lowest known id if a mission somehow uses them all,
            which keeps the build running rather than failing over a cosmetic detail.
        """
        used: set[int] = set()
        content = (self.dcs_mission.mission_content if self.dcs_mission else None) or {}
        for side in (content.get("coalition") or {}).values():
            countries = (side or {}).get("country") or []
            entries = countries.values() if isinstance(countries, dict) else countries
            for country in entries:
                if isinstance(country, dict) and country.get("id") is not None:
                    used.add(int(country["id"]))
        known = all_country_ids()
        # `max` over the free ids: deterministic, so two builds of the same mission emit the same
        # trigger and a rebuild shows no spurious diff, and biased away from the countries missions
        # actually use.
        return max(known - used, default=min(known))

    def _build_sound_declaration_actions(self) -> list[SoundAction]:
        """Declare every sound the mission carries that nothing else references.

        The Mission Editor keeps the resources its own table declares and prunes the rest. A
        ``.ogg`` played by a script at runtime — CTLD's ``outSound("beacon.ogg")``, CSAR's beacon —
        is invisible to that scan, so an editor save **deletes** it (measured on the demo mission:
        four files gone, `FIX-COMMUNITY-SOUNDS-PRUNED`).

        The rule is deliberately about **orphans**, not about CTLD/CSAR: the sounds that triggered
        this came from the *mission's own* ``src/mission/l10n/DEFAULT/`` with both modules disabled,
        so keying on the tool-injected set would have missed the very case that was measured. A
        sound already present in ``mapResource`` — a briefing clip with its own trigger, say — is
        left alone; it is not an orphan and needs nothing.

        Returns:
            One :class:`SoundAction` per orphan sound, in file-name order; empty when the mission
            carries none, in which case no trigger is emitted at all.
        """
        candidates = set(self.get_collected_community_sound_files()) | set(self.get_collected_mission_data_files())
        prefix = f"{DEFAULT_SCRIPTS_LOCATION}/"
        sounds = sorted(p for p in candidates if p.startswith(prefix) and p.lower().endswith(".ogg"))
        # Nothing to declare is the common case (a mission with no sound at all), and it must not
        # need a loaded mission to establish — so the early exit comes before touching dcs_mission.
        if not sounds:
            return []

        assert self.dcs_mission is not None
        already_declared = {str(v) for v in (self.dcs_mission.map_resource_content or {}).values()}
        orphans = [p for p in sounds if Path(p).name not in already_declared]
        if not orphans:
            return []

        self.dcs_mission.map_resource_content = self.dcs_mission.map_resource_content or {}
        country_id = self._unused_country_id()
        actions: list[SoundAction] = []
        for index, path in enumerate(orphans):
            map_key = f"VEAF_MapKey_Sound_{index}"
            # The bare file name, not the l10n/DEFAULT/ path: CTLD calls outSound("beacon.ogg").
            self.dcs_mission.map_resource_content[map_key] = Path(path).name
            actions.append(SoundAction(map_key=map_key, country_id=country_id))
        return actions

    def _build_veaf_trigger_specs(
        self, new_map_resource_script_files: dict, new_map_resource_mission_script_files: dict
    ) -> list[VeafTriggerSpec]:
        """Build the 6 ordered VEAF load triggers — the single source for both forms.

        The order matches :data:`_VEAF_TRIGGER_DICT_KEYS`: set the two dynamic-path
        globals (each runs only in its dynamic mode), then load the VEAF scripts
        (dynamic vs static) and the mission scripts (dynamic vs static). The
        static-mission trigger loads the **full** ordered mission-script list — the
        same one the dynamic loader iterates — so ``custom_scripts`` are honoured in
        both modes and the two emitted forms reference exactly the same files.

        Args:
            new_map_resource_script_files: mapResource keys → VEAF/community script names.
            new_map_resource_mission_script_files: mapResource keys → mission script names.

        Returns:
            The 6 specs, in trigger order.
        """
        scripts_path, mission_path = self._veaf_dynamic_paths()
        keys = _VEAF_TRIGGER_DICT_KEYS

        # Build-traceability stamp (package version + git sha) set as a plain global
        # BEFORE any framework file loads, so veaf.lua can read it into veaf.BuildVersion
        # and log it. Set in both load paths (dynamic and static) so it is always present.
        build_stamp_action = LuaAction(f'VEAF_BUILD_VERSION = "{get_build_stamp()}"')

        dynamic_scripts: list[LuaAction | FileAction | SoundAction] = [
            build_stamp_action,
            LuaAction('env.info("DYNAMIC VEAF scripts loading from "..VEAF_DYNAMIC_SCRIPTSPATH)'),
        ]
        # Dynamic mode loads the community scripts off disk. The CTLD configuration is a
        # build artifact, not a repository file, so it is written into the mission folder
        # (like veafDynamicConfig.lua) and loaded through VEAF_DYNAMIC_MISSIONPATH — but
        # it must still come immediately before CTLD.lua, exactly as in static mode.
        for file in self._active_community_scripts():
            # Keyed on the file name, like the static path (_with_ctld_user_config), so
            # both orderings are decided by the same criterion.
            if Path(file["path"]).name == "CTLD.lua" and self._ctld_user_config_lua() is not None:
                dynamic_scripts.append(
                    LuaAction(
                        f'assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/{CTLD_USER_CONFIG_FILENAME}"))()'
                    )
                )
            dynamic_scripts.append(LuaAction(f'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "{file["path"]}"))()'))
        dynamic_scripts.append(
            LuaAction(f'assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. "{self._dynamic_framework_load_path()}"))()')
        )

        # The map-resource dicts are populated in load order (community→VEAF scripts
        # for the first, _ordered_mission_script_files() for the second), and dicts
        # preserve insertion order, so iterating them keeps the scripts in load order
        # (e.g. veaf-config.lua before mission-script.lua).
        static_scripts: list[LuaAction | FileAction | SoundAction] = [
            build_stamp_action,
            LuaAction('env.info("STATIC VEAF scripts loading")'),
        ]
        static_scripts += [FileAction(key) for key in new_map_resource_script_files]

        # Mission scripts declaring `delay_seconds` leave the shared triggerStart for a
        # triggerOnce of their own, grouped by delay (FEAT-CUSTOM-SCRIPT-LOAD-DELAY).
        immediate_keys, delay_groups = self._split_delayed_mission_scripts(new_map_resource_mission_script_files)

        static_mission: list[LuaAction | FileAction | SoundAction] = [
            LuaAction('env.info("STATIC Mission scripts loading")')
        ]
        static_mission += [FileAction(key) for key in immediate_keys]

        specs = [
            VeafTriggerSpec(
                keys[0],
                "VEAF scripts loading method",
                "0x00ffffff",
                True,
                [LuaAction(f"VEAF_DYNAMIC_SCRIPTSPATH = {scripts_path}")],
            ),
            VeafTriggerSpec(
                keys[1],
                "Mission scripts loading method",
                "0x00ffffff",
                True,
                [LuaAction(f"VEAF_DYNAMIC_MISSIONPATH = {mission_path}")],
            ),
            VeafTriggerSpec(keys[2], "VEAF scripts loading - dynamic", "0x00ff80ff", False, dynamic_scripts),
            VeafTriggerSpec(keys[3], "VEAF scripts loading - static", "0x00ff80ff", False, static_scripts),
            VeafTriggerSpec(
                keys[4],
                "Mission scripts loading - dynamic",
                "0x8080ffff",
                False,
                [
                    LuaAction('env.info("DYNAMIC Mission scripts loading from "..VEAF_DYNAMIC_MISSIONPATH)'),
                    LuaAction('assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua"))()'),
                ],
            ),
            VeafTriggerSpec(keys[5], "Mission scripts loading - static", "0x8080ffff", False, static_mission),
        ]

        # One deferred trigger per distinct delay, in increasing delay order so the editor's
        # trigger list reads as the staging it reproduces.
        for group_index, (delay, group_keys) in enumerate(sorted(delay_groups.items())):
            specs.append(
                VeafTriggerSpec(
                    _delay_trigger_dict_key(group_index),
                    f"Mission scripts loading - static, delayed {format_delay_seconds(delay)}s",
                    "0x8080ffff",
                    False,
                    [
                        LuaAction(
                            f'env.info("STATIC Mission scripts loading - delayed {format_delay_seconds(delay)}s")'
                        ),
                        *(FileAction(key) for key in group_keys),
                    ],
                    delay_seconds=delay,
                )
            )

        # The sound declaration is last and conditional: with no orphan sound there is nothing to
        # protect from the editor's pruning, and an empty trigger would be noise.
        sound_actions = self._build_sound_declaration_actions()
        if sound_actions:
            specs.append(VeafTriggerSpec(keys[6], "Declare mission sounds", "0xffff00ff", False, list(sound_actions)))
        return specs

    def _split_delayed_mission_scripts(self, mission_script_files: dict) -> tuple[list[str], dict[float, list[str]]]:
        """Split the mission-script resource keys into immediate ones and per-delay groups.

        The declared **order of the mission-file list is preserved inside each group**, since that
        list is already the resolved load order (``_ordered_mission_script_files``).

        Ordering rule, and it is documented rather than enforced: **the delay decides, not the
        position in the list.** A script at +12 s loads after every undelayed one wherever it sits.
        Refusing a list where a delayed script precedes an undelayed one was the alternative; it
        would reject perfectly workable files — a maker may well group their scripts by topic
        instead of by delay — so a build warning names the pair instead. That is the only case
        where reading the list top to bottom disagrees with what actually happens.

        Args:
            mission_script_files: Resource key → script base name, in load order.

        Returns:
            ``(immediate keys, {delay: keys})``.
        """
        delay_by_name = {
            script.path: script.delay_seconds for script in self.custom_scripts if script.delay_seconds is not None
        }
        if not delay_by_name:
            return list(mission_script_files), {}

        immediate: list[str] = []
        groups: dict[float, list[str]] = {}
        seen_immediate_after_delay: list[tuple[str, str]] = []
        last_delayed_name: str | None = None
        for key, name in mission_script_files.items():
            delay = delay_by_name.get(name)
            if delay is None:
                immediate.append(key)
                if last_delayed_name is not None:
                    seen_immediate_after_delay.append((last_delayed_name, name))
            else:
                groups.setdefault(delay, []).append(key)
                last_delayed_name = name

        if seen_immediate_after_delay:
            pairs = "; ".join(f"{delayed} → {immediate_name}" for delayed, immediate_name in seen_immediate_after_delay)
            logger.warning(t("builder.custom_script_delay_out_of_order", pairs=pairs))

        if len(groups) > _VEAF_MAX_DELAY_GROUPS:
            # This ABORTS the build: `veaf_libs.logger.error` raises `typer.Abort`, it does not merely
            # log (see its `exception_type` default). Spelled out because the line reads like a log
            # line that falls through to the `return` below — Sourcery read it that way on #720 and
            # reported orphan triggers. Aborting is the right outcome and the alternative is worse:
            # truncating would build a mission quietly missing scripts the maker declared. A test
            # pins that a 13th group raises rather than emitting a spec whose dictionary key is
            # absent.
            logger.error(t("builder.custom_script_delay_too_many", count=len(groups), maximum=_VEAF_MAX_DELAY_GROUPS))
        return immediate, groups

    def insert_veaf_triggers(self, specs: list[VeafTriggerSpec]) -> None:
        """Insert the compiled ``trig`` form of the VEAF triggers, derived from *specs*.

        Each spec becomes one trigger (Mission Start): its actions are emitted as a
        single concatenated Lua string, its condition references the spec's dictionary
        key, and its ``funcStartup`` wires the two together. All existing triggers are
        shifted up by ``len(specs)`` ranks, with their inter-trigger ``[idx]`` Lua
        references rewritten to match.

        Args:
            specs: The ordered VEAF trigger specs from :meth:`_build_veaf_trigger_specs`.
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

        nb = len(specs)
        indexed = list(enumerate(specs, start=1))
        # A deferred trigger is a triggerOnce, and DCS compiles that differently from the
        # triggerStart every other VEAF trigger is. Three differences, all read out of an upstream
        # `.miz` rather than guessed: it is dispatched from `func` (evaluated every tick) instead
        # of `funcStartup` (evaluated once), its condition ANDs `c_time_after`, and its action
        # string clears its own `func` entry — that is what makes the "Once".
        dispatch = "if mission.trig.conditions[{i}]() then mission.trig.actions[{i}]() end"
        veaf_triggers = {
            "customStartup": {},
            "func": {i: dispatch.format(i=i) for i, spec in indexed if spec.delay_seconds is not None},
            "custom": {},
            "events": {},
            "flag": {i: True for i in range(1, nb + 1)},
            "conditions": {i: _emit_trig_condition(spec) for i, spec in indexed},
            "actions": {
                i: _emit_trig_action_string(spec.actions)
                + (f" mission.trig.func[{i}]=nil;" if spec.delay_seconds is not None else "")
                for i, spec in indexed
            },
            "funcStartup": {i: dispatch.format(i=i) for i, spec in indexed if spec.delay_seconds is None},
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

    def insert_veaf_trigrules(self, specs: list[VeafTriggerSpec]) -> None:
        """Insert the Mission Editor ``trigrules`` form of the VEAF triggers, from *specs*.

        Each spec becomes one trigrule: its actions are emitted as editor action dicts
        and its rule references the spec's dictionary key (with the ``flag`` field only
        for the path-setting triggers). Deriving from the same *specs* as
        :meth:`insert_veaf_triggers` guarantees the editor and compiled forms load the
        identical, fully-ordered set of scripts — closing the static-mission drift that
        previously dropped ``custom_scripts`` from the editor form. All existing
        trigrules are shifted up by ``len(specs)`` ranks.

        Args:
            specs: The ordered VEAF trigger specs from :meth:`_build_veaf_trigger_specs`.
        """
        new_trigrules_list = [
            {
                "rules": [
                    {
                        **({"flag": 1} if spec.rule_has_flag else {}),
                        "text": spec.dict_key,
                        "KeyDict_text": spec.dict_key,
                        "predicate": "c_predicate",
                    },
                    # A second rule, ANDed by the editor, for a deferred trigger. Only `seconds` is
                    # written: an upstream mission also carries `coalitionlist`/`unitType`/`zone`
                    # there, but those are leftovers of the editor's form and `zone` names a zone of
                    # *that* mission — copying it would point at a zone we do not have.
                    *(
                        [{"predicate": "c_time_after", "seconds": spec.delay_seconds}]
                        if spec.delay_seconds is not None
                        else []
                    ),
                ],
                "comment": spec.comment,
                "predicate": "triggerStart" if spec.delay_seconds is None else "triggerOnce",
                "eventlist": "",
                "actions": _emit_trigrule_actions(spec.actions),
                "colorItem": spec.color_item,
            }
            for spec in specs
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
        if self.dcs_bridge_bytes is not None or self.checklist_images:
            from mission_tools import DEFAULT_SCRIPTS_LOCATION

            if self.dcs_bridge_bytes is not None:
                additional_files[f"{DEFAULT_SCRIPTS_LOCATION}/dcs-bridge.lua"] = self.dcs_bridge_bytes
            for entry in self.checklist_images:
                for filename, payload in entry.files.items():
                    additional_files[f"{DEFAULT_SCRIPTS_LOCATION}/{filename}"] = payload
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

        # FEAT-RADIO-YAML-MENUS (ADR 0011): a radio-menu `action: lua` references a
        # maker function that must be defined in the mission scripts; abort the build
        # if it is missing rather than emit a menu that errors at runtime.
        missing_fns = find_undefined_lua_functions(yaml_dict, read_corpus(scripts_dir))
        if missing_fns:
            logger.error(
                t("builder.radio_lua_functions_missing", functions=", ".join(missing_fns)),
                exception_type=RuntimeError,
            )

        checklists = self._resolve_checklists(yaml_dict)
        image_keys = {entry.checklist_id: entry.resource_keys for entry in self.checklist_images}

        config_file = scripts_dir / "veaf-config.lua"
        content = generate_config_lua(yaml_dict, checklists=checklists, checklist_images=image_keys)
        config_file.write_text(content, encoding="utf-8")
        logger.info(t("builder.veaf_config_generated", file=config_file))

    def _resolve_checklists(self, yaml_dict: dict) -> list[Checklist]:
        """Resolve the guided checklists this mission activates, and render their images.

        The rendering happens here rather than at write time because the emitted Lua has
        to carry the resource keys the images will be embedded under, and both come from
        the same resolution.

        Args:
            yaml_dict: The effective ``mission.yaml`` mapping.

        Returns:
            The activated checklists (empty when the ASSIST module is off or activates
            none). :attr:`checklist_images` is filled to match.
        """
        self.checklist_images = []
        assist_cfg = enabled_module_config(yaml_dict, _ASSIST_MODULE_ID)
        if assist_cfg is None:
            return []

        available = load_checklists(mission_folder=self.mission_folder)
        mission_ids = load_mission_checklists(self.mission_folder)
        configured = assist_cfg.get("checklists")
        checklists = select_activated(available, configured, mission_ids)
        if not checklists:
            return []

        display = str(assist_cfg.get("display") or _ASSIST_DISPLAY_PICTURE).lower()
        if display not in _ASSIST_DISPLAY_MODES:
            logger.error(
                t("checklist.unknown_display", value=display, valid=", ".join(sorted(_ASSIST_DISPLAY_MODES))),
                exception_type=ValueError,
            )
        if display == _ASSIST_DISPLAY_TEXT:
            # The whole point of text mode: nothing rendered, nothing embedded, nothing in
            # mapResource. The engine reads a checklist with no `images` as a text one.
            logger.info(t("checklist.text_mode", n=len(checklists)))
            return checklists

        # The picture's text must read like the pilot's messages, so it is resolved through
        # the runtime catalog, in the mission's language — the same resolution veaf.t()
        # will do in game.
        scripts_root = self.scripts_path or (self.mission_folder / "published")
        catalog = load_runtime_catalog(scripts_root)
        language = (yaml_dict.get("mission") or {}).get("language") or current_language()
        self.checklist_images = render_all(checklists, catalog, language)
        return checklists

    def _checklist_resources(self) -> dict[str, str]:
        """Return the ``mapResource`` entries of the rendered checklist images.

        Returns:
            Mapping of resource key to file name, empty when no checklist is activated.
        """
        resources: dict[str, str] = {}
        for entry in self.checklist_images:
            resources.update(entry.resources())
        return resources

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

        # Render the partial config-override script (FOOTHOLD-V6-004): validated
        # lexically, loaded between the upstream config and setup. Build-blocking.
        if self.config_override_values:
            with spinner_context(t("builder.generating_config"), silent=silent):
                self.render_config_override()
            self.collected_mission_script_files = None

        # Regenerate veafDynamicConfig.lua so dynamic mode loads the same mission
        # scripts (incl. custom_scripts) as the static triggers.
        with spinner_context(t("builder.generating_dynamic_config"), silent=silent):
            self.generate_veaf_dynamic_config()
            self.generate_ctld_user_config()

        # Create the initial mission file
        with spinner_context(t("builder.creating_mission", output=self.output_mission), silent=silent):
            self.create_mission()

        # Load the mission from the .miz file (unzip it) and process aircraft groups
        with spinner_context(t("builder.reading_mission", output=self.output_mission), silent=silent):
            self.read_mission()

        # Ensure each side coalition owns at least one unit (hidden placeholder if not)
        self.ensure_coalitions_populated()

        # Ensure the theatre's airfields exist in the warehouses table (a slot parked on a ramp
        # cannot be taken otherwise); a mission that already declares them is left alone
        self.ensure_airports_populated()

        # Collect missing Mission-Editor references (zones/groups/units/airfields) on the
        # freshly-read source mission; reported as a summary at the end (non-blocking).
        self.validate_references()

        # First, remove all the VEAF triggers
        with spinner_context(t("builder.clearing_triggers"), silent=silent):
            self.clear_veaf_triggers()

        # Strip the third-party native load triggers a conversion declared (so the
        # scripts re-injected as custom_scripts are not loaded twice).
        if self.dcs_mission is not None:
            strip_native_load_triggers(self.dcs_mission, self.mission_yaml.get("strip_native_triggers") or [])

        # Make third-party aircraft mods non-blocking: strip them from requiredModules so a
        # pilot without the mod can still load the mission (the slot is just unavailable).
        self.strip_third_party_mod_requirements(silent=silent)

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
            logger.detail(t("builder.built", output=self.output_mission, folder=self.mission_folder))

        # End-of-build summary of missing Mission-Editor references (non-blocking).
        self.report_reference_issues()

        return self.output_mission
