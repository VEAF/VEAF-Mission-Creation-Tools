"""Convert a third-party (non-VEAF) ``.miz`` mission into a v6 mission folder.

This is the generic counterpart of ``convert-v5`` (which migrates a VEAF v5
mission): it adopts an externally-authored mission — the first client being
*Foothold* by Lekaa — onto the v6 toolchain. See ADR 0007.

This module holds the generic, author-agnostic building blocks. No "Foothold"
knowledge lives here; author-specific data is carried by a *conversion profile*
(FOOTHOLD-V6-002).
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from mission_extractor import MissionExtractorWorker
from mission_tools import read_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.i18n import t
from veaf_libs.lua_module_scanner import get_modules

from mission_builder.mission_builder_worker import lua_loads_other_scripts
from mission_builder.v5_converter import ConversionReport

#: Lua filename extension of a loaded script resource.
_LUA_SUFFIX = ".lua"


def _ordered_actions(trigrule: dict) -> list[dict]:
    """Return a trigrule's actions in order.

    DCS stores ``actions`` either as a list or as a dict keyed by numeric index;
    in the dict form the keys carry the order. Normalises both to an ordered list.
    """
    actions = trigrule.get("actions")
    if isinstance(actions, list):
        return [a for a in actions if isinstance(a, dict)]
    if isinstance(actions, dict):
        return [actions[key] for key in sorted(actions.keys()) if isinstance(actions[key], dict)]
    return []


@dataclass(frozen=True)
class DetectedLoader:
    """One script loaded by a native ``a_do_script_file`` trigger action.

    Attributes:
        script: The resolved script filename (e.g. ``"Moose_2026-04-28.lua"``).
        trigger_index: The ``trigrules`` index of the loader trigger.
        trigger_comment: The trigger's editor comment (e.g. ``"ScriptLoader 1"``).
    """

    script: str
    trigger_index: int
    trigger_comment: str


def detect_native_script_loaders(dcs_mission: DcsMission) -> list[DetectedLoader]:
    """List the scripts loaded by a mission's native triggers, in load order.

    Walks ``trigrules`` in index order and, within each, its ``actions`` in
    order; every ``a_do_script_file`` action whose ``mapResource`` entry resolves
    to a ``.lua`` file is reported. The resulting order is the runtime load order,
    ready to scaffold an ordered ``custom_scripts:`` block.

    Args:
        dcs_mission: The parsed third-party mission.

    Returns:
        The detected loaders, in load order (empty if none).
    """
    mission_content = dcs_mission.mission_content or {}
    trigrules = mission_content.get("trigrules") or {}
    map_resource = dcs_mission.map_resource_content or {}

    loaders: list[DetectedLoader] = []
    for index in sorted(trigrules.keys()):
        trigrule = trigrules[index]
        if not isinstance(trigrule, dict):
            continue
        comment = str(trigrule.get("comment", ""))
        for action in _ordered_actions(trigrule):
            if action.get("predicate") != "a_do_script_file":
                continue
            resolved = map_resource.get(action.get("file", ""))
            if resolved and str(resolved).lower().endswith(_LUA_SUFFIX):
                loaders.append(DetectedLoader(str(resolved), index, comment))
    return loaders


def _trigrule_loads_script(trigrule: dict, map_resource: dict[str, str]) -> bool:
    """Return True when *trigrule* has an action that loads a script.

    Either an ``a_do_script_file`` resolving to a ``.lua`` resource, or an
    ``a_do_script`` whose body loads other scripts (``loadfile``/``dofile``/…).
    """
    for action in _ordered_actions(trigrule):
        predicate = action.get("predicate")
        if predicate == "a_do_script_file":
            resolved = map_resource.get(action.get("file", ""))
            if resolved and str(resolved).lower().endswith(_LUA_SUFFIX):
                return True
        elif predicate == "a_do_script" and lua_loads_other_scripts(str(action.get("text", ""))):
            return True
    return False


def detect_native_loader_triggers(dcs_mission: DcsMission) -> list[tuple[int, str]]:
    """List the native triggers that load scripts, in trigrule-index order.

    These are the triggers the v6 build must strip (``strip_native_triggers``) so
    the scripts are not loaded twice once re-injected as ``custom_scripts``.

    Args:
        dcs_mission: The parsed third-party mission.

    Returns:
        ``(trigrule_index, comment)`` pairs for every script-loading trigger.
    """
    mission_content = dcs_mission.mission_content or {}
    trigrules = mission_content.get("trigrules") or {}
    map_resource = dcs_mission.map_resource_content or {}

    result: list[tuple[int, str]] = []
    for index in sorted(trigrules.keys()):
        trigrule = trigrules[index]
        if isinstance(trigrule, dict) and _trigrule_loads_script(trigrule, map_resource):
            result.append((index, str(trigrule.get("comment", ""))))
    return result


def _yaml_path(path: str) -> str:
    """Quote a YAML scalar path only when it contains a space."""
    return f'"{path}"' if " " in path else path


def _yaml_dquote(value: str) -> str:
    """Render a double-quoted YAML scalar, escaping embedded quotes."""
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_scaffold_yaml(
    loaders: list[DetectedLoader],
    strip_triggers: list[tuple[int, str]],
    now: datetime | None = None,
) -> str:
    """Build the scaffold ``mission.yaml`` content for an adopted mission.

    The scaffold is intentionally generic (no author-specific knowledge): the
    detected scripts become an ordered ``custom_scripts:`` block, the detected
    loader triggers are listed under ``strip_native_triggers:`` (the build strips
    them in a later lot), and every VEAF module is listed disabled so the
    mission-maker — or a conversion profile — turns on what the mission needs.

    Args:
        loaders: Detected scripts, in load order.
        strip_triggers: Detected native loader triggers ``(index, comment)``.
        now: Timestamp for the header (defaults to the current time).

    Returns:
        The ``mission.yaml`` text.
    """
    stamp = (now or datetime.now()).strftime("%Y-%m-%d %H:%M")
    lines: list[str] = [
        f"# mission.yaml — generated by veaf-tools convert-other on {stamp}",
        "# Third-party mission adopted onto the v6 toolchain. See ADR 0007.",
        "# Review before building: enable the VEAF modules you need and check the",
        "# custom_scripts load order below.",
        "",
        "global_log_level: info",
        "",
        "# Scripts found in the source mission's native load triggers, in load order.",
        "# Injected as custom_scripts and loaded by VEAF-generated triggers",
        "# (generate_load_trigger defaults to true).",
        "custom_scripts:",
        "  scripts:",
    ]
    for loader in loaders:
        lines.append(f"    - path: {_yaml_path(f'src/scripts/{loader.script}')}")
    lines.append("")

    lines += [
        "# Native load triggers detected in the source .miz. The build removes these",
        "# so the scripts above are not loaded twice.",
    ]
    if strip_triggers:
        lines.append("strip_native_triggers:")
        seen: set[str] = set()
        for index, comment in strip_triggers:
            label = comment.strip() or f"trigger #{index}"
            if label in seen:
                continue
            seen.add(label)
            lines.append(f"  - {_yaml_dquote(label)}")
    else:
        lines.append("strip_native_triggers: []")
    lines.append("")

    lines += [
        "# VEAF modules — all disabled by default. Enable what this mission needs.",
        "modules:",
    ]
    for module in get_modules():
        lines.append(f"  {module['id']}: false")
    lines.append("")

    return "\n".join(lines)


class OtherMissionConverter:
    """Adopt a third-party (non-VEAF) ``.miz`` mission into a v6 mission folder.

    The generic counterpart of :class:`~mission_builder.v5_converter.V5Converter`:
    it extracts the mission, detects the scripts loaded by its native triggers,
    and scaffolds a ``mission.yaml``. It holds no author-specific knowledge.
    """

    def __init__(self, version: str = "unknown") -> None:
        self._version = version

    def convert(
        self,
        input_mission_path: Path,
        output_mission_folder: Path,
        force: bool = False,
        backup: bool = True,
    ) -> ConversionReport:
        """Adopt *input_mission_path* into *output_mission_folder*.

        Args:
            input_mission_path: The third-party ``.miz`` to adopt.
            output_mission_folder: The v6 mission folder to create/populate.
            force: Overwrite an existing ``mission.yaml`` instead of skipping it.
            backup: Back up an existing ``mission.yaml`` to ``.bak`` before overwriting.

        Returns:
            The conversion report.
        """
        report = ConversionReport(mission_folder=output_mission_folder, version=self._version)
        output_mission_folder.mkdir(parents=True, exist_ok=True)

        # 1. Extract the .miz into the mission folder (scripts land in src/scripts/).
        MissionExtractorWorker(
            mission_folder=output_mission_folder,
            input_mission_path=input_mission_path,
            keep_community_scripts=True,
        ).work(silent=True)
        report.actions.append(t("convert_other.action.extracted", mission=input_mission_path.name))

        # 2. Detect the scripts and the native loader triggers from the source .miz.
        dcs_mission = read_miz(input_mission_path)
        loaders = detect_native_script_loaders(dcs_mission)
        strip_triggers = detect_native_loader_triggers(dcs_mission)

        # 3. Scaffold mission.yaml.
        dest = output_mission_folder / "mission.yaml"
        if dest.exists() and not force:
            report.mission_yaml_existed = True
            report.mission_yaml_skipped_reason = t("convert_other.action.yaml_skip")
            report.actions.append(t("convert_other.action.yaml_exists"))
        else:
            if dest.exists() and backup:
                shutil.copy2(dest, dest.with_name("mission.yaml.bak"))
            dest.write_text(build_scaffold_yaml(loaders, strip_triggers), encoding="utf-8")
            report.mission_yaml_generated = True
            report.mission_yaml_path = dest
            report.actions.append(
                t("convert_other.action.yaml_generated", scripts=len(loaders), triggers=len(strip_triggers))
            )

        # 4. Manual review items.
        report.manual_review.append(t("convert_other.review.enable_modules"))
        report.manual_review.append(t("convert_other.review.verify_order"))
        report.manual_review.append(t("convert_other.review.test_dcs"))
        return report
