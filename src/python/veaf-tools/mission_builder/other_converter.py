"""Convert a third-party (non-VEAF) ``.miz`` mission into a v6 mission folder.

This is the generic counterpart of ``convert-v5`` (which migrates a VEAF v5
mission): it adopts an externally-authored mission — the first client being
*Foothold* by Lekaa — onto the v6 toolchain. See ADR 0007.

This module holds the generic, author-agnostic building blocks. No "Foothold"
knowledge lives here; author-specific data is carried by a *conversion profile*
(FOOTHOLD-V6-002).
"""

from __future__ import annotations

import hashlib
import shutil
from dataclasses import dataclass, replace
from datetime import datetime
from pathlib import Path

from mission_extractor import MissionExtractorWorker
from mission_tools import read_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.conversion_profile import ConversionProfile, load_profile
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger
from veaf_libs.mission_template import render_modules_block, tier_modules

from mission_builder.mission_builder_worker import lua_loads_other_scripts
from mission_builder.v5_converter import ConversionReport

#: Lua filename extension of a loaded script resource.
_LUA_SUFFIX = ".lua"


def _dcs_index_sort_key(key: object) -> tuple[int, int, str]:
    """Stable sort key for DCS table indices: numeric keys first (in numeric order),
    then any non-numeric keys, so ``sorted`` never raises on mixed key types."""
    text = str(key)
    try:
        return (0, int(text), "")
    except ValueError:
        return (1, 0, text)


def _ordered_actions(trigrule: dict) -> list[dict]:
    """Return a trigrule's actions in order.

    DCS stores ``actions`` either as a list or as a dict keyed by numeric index;
    in the dict form the keys carry the order. Normalises both to an ordered list.
    """
    actions = trigrule.get("actions")
    if isinstance(actions, list):
        return [a for a in actions if isinstance(a, dict)]
    if isinstance(actions, dict):
        return [
            actions[key] for key in sorted(actions.keys(), key=_dcs_index_sort_key) if isinstance(actions[key], dict)
        ]
    return []


@dataclass(frozen=True)
class ScriptUpdateDiff:
    """How the third-party scripts changed between the adopted folder and a fresh upstream ``.miz``.

    Attributes:
        added: Scripts present upstream but not yet in the folder (new this update).
        removed: Scripts in the folder no longer produced by the upstream mission.
        updated: Scripts present in both whose content changed.
    """

    added: tuple[str, ...] = ()
    removed: tuple[str, ...] = ()
    updated: tuple[str, ...] = ()

    def is_empty(self) -> bool:
        """Whether nothing changed (no add/remove/update)."""
        return not (self.added or self.removed or self.updated)


def _sha256(path: Path) -> str:
    """Return the hex SHA-256 of *path*'s bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _is_plain_filename(name: str) -> bool:
    """Whether *name* is a bare filename that stays inside the folder it is joined to.

    Used on profile-supplied replacement names before they reach the filesystem (SECREV-2 /
    VMR-035). ``Path.name`` is the reliable test on both platforms: it strips any directory part,
    so a value carrying one cannot survive the comparison. A Windows drive prefix (``C:x.lua``)
    keeps its colon in ``name`` and is rejected the same way.

    Args:
        name: The candidate filename, as written in the conversion profile.

    Returns:
        True when joining *name* to a directory yields a direct child of it.
    """
    if not name or name in {".", ".."}:
        return False
    if "/" in name or "\\" in name or ":" in name:
        return False
    return Path(name).name == name


def snapshot_scripts(scripts_dir: Path) -> dict[str, str]:
    """Map each ``*.lua`` basename under *scripts_dir* to its content hash (empty if absent)."""
    if not scripts_dir.is_dir():
        return {}
    return {p.name: _sha256(p) for p in scripts_dir.glob("*.lua")}


def diff_scripts(before: dict[str, str], after: dict[str, str], upstream: set[str]) -> ScriptUpdateDiff:
    """Compute the add/remove/update diff of an ``--update`` re-import.

    Args:
        before: ``{name: hash}`` of the folder's scripts before the refresh.
        after: ``{name: hash}`` of the folder's scripts after the refresh.
        upstream: The script basenames the fresh upstream ``.miz`` provides
            (normalised), i.e. those it actually loads.

    Returns:
        The diff. *added* = upstream scripts absent before; *removed* = scripts
        present before but no longer in the upstream set; *updated* = scripts in
        both the upstream set and *before* whose hash changed.
    """
    added = tuple(sorted(upstream - before.keys()))
    removed = tuple(sorted(before.keys() - upstream))
    updated = tuple(sorted(n for n in (upstream & before.keys()) if before.get(n) != after.get(n)))
    return ScriptUpdateDiff(added=added, removed=removed, updated=updated)


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
    for index in sorted(trigrules.keys(), key=_dcs_index_sort_key):
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
    for index in sorted(trigrules.keys(), key=_dcs_index_sort_key):
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


def _yaml_scalar(value: object) -> str:
    """Render a Python value as a YAML scalar (bool → true/false, str quoted if needed)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    text = str(value)
    return _yaml_dquote(text) if (" " in text or not text) else text


def _config_override_block(profile: ConversionProfile) -> list[str]:
    """Render a commented ``config_override`` scaffold from *profile*, or nothing."""
    spec = profile.config_override
    if spec is None:
        return []
    lines = [
        "# Partial override of the untouched upstream config. Uncomment and adjust;",
        f"# layered on top of {spec.target} (only restates what you change). See ADR 0008.",
        "# config_override:",
        f"#   target: {_yaml_path(spec.target)}",
        "#   values:",
    ]
    for key, value in spec.defaults.items():
        lines.append(f"#     {key}: {_yaml_scalar(value)}")
    lines.append("")
    return lines


def _disabled_community_lines(profile: ConversionProfile) -> list[str]:
    """Render the profile's disabled community scripts as ``modules:`` body entries.

    Foothold-style missions ship their own community libraries as ``custom_scripts``,
    so VEAF's bundled copies must stay off (FOOTHOLD-V6-009). The entries are emitted
    **inside** the unified ``modules:`` block (indented), because a separate
    ``community_scripts:`` block is the deprecated form and is silently ignored when
    ``modules:`` is present. Returns nothing when the profile disables none.
    """
    if not profile.disabled_community_scripts:
        return []
    lines = [
        "  # ── Community scripts OFF ──",
        f"  # Disabled by the '{profile.name}' profile: this mission ships its own",
        "  # (Moose, its own CTLD, AIEN, …); VEAF's bundled versions stay off.",
    ]
    lines += [f"  {script_id}: false" for script_id in profile.disabled_community_scripts]
    return lines


def build_scaffold_yaml(
    loaders: list[DetectedLoader],
    strip_triggers: list[tuple[int, str]],
    profile: ConversionProfile | None = None,
    now: datetime | None = None,
) -> str:
    """Build the scaffold ``mission.yaml`` content for an adopted mission.

    The detected scripts become an ordered ``custom_scripts:`` block and the
    detected loader triggers a ``strip_native_triggers:`` list (the build strips
    them in a later lot). Without a *profile* the ``modules:`` block is seeded with
    the ``minimal`` tier; with one, it reflects the profile's modules, a
    ``conversion_profile:`` marker is written (so ``validate``/build can enforce
    its incompatibilities), a commented ``config_override`` scaffold is added, and
    the profile's bundled community scripts are turned off.

    Args:
        loaders: Detected scripts, in load order (already name-normalised).
        strip_triggers: Detected native loader triggers ``(index, comment)``.
        profile: The conversion profile applied, or ``None`` for a generic scaffold.
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
    ]
    if profile is not None:
        lines += [
            "# Marks this mission as adopted with the named profile; validate/build",
            "# enforce the profile's module incompatibilities.",
            f"conversion_profile: {profile.name}",
            "",
        ]
    lines += [
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

    lines.extend(_config_override_block(profile) if profile else [])

    if profile is not None:
        enabled = set(profile.modules)
        lines += [
            f"# VEAF modules — from the '{profile.name}' conversion profile.",
            "modules:",
        ]
    else:
        enabled = tier_modules("minimal")
        lines += [
            "# VEAF modules — the 'minimal' tier (infra + RADIO/SPAWN/SHORTCUTS/INTERPRETER).",
            "# Enable more as this mission needs them.",
            "modules:",
        ]
    lines.extend(render_modules_block(enabled))
    # Disabled community scripts go inside the modules: block (see _disabled_community_lines).
    lines.extend(_disabled_community_lines(profile) if profile else [])
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
        profile_name: str | None = None,
        update: bool = False,
    ) -> ConversionReport:
        """Adopt *input_mission_path* into *output_mission_folder*.

        Args:
            input_mission_path: The third-party ``.miz`` to adopt.
            output_mission_folder: The v6 mission folder to create/populate.
            force: Overwrite an existing ``mission.yaml`` instead of skipping it.
            backup: Back up an existing ``mission.yaml`` to ``.bak`` before overwriting.
            profile_name: A conversion profile (bundled name or path) tailoring the
                scaffold (modules, name normalisation, config_override). ``None`` for
                a generic scaffold seeded with the ``minimal`` tier.
            update: Re-import a fresher upstream ``.miz`` (FOOTHOLD-V6-005): refresh
                the third-party scripts and mission base, **preserve** the tuned
                ``mission.yaml`` (never scaffold), and report the scripts added,
                removed, and updated upstream.

        Returns:
            The conversion report.
        """
        report = ConversionReport(mission_folder=output_mission_folder, version=self._version)
        output_mission_folder.mkdir(parents=True, exist_ok=True)
        profile = load_profile(profile_name) if profile_name else None
        scripts_dir = output_mission_folder / "src" / "scripts"

        # In update mode, snapshot the existing scripts before the refresh overwrites them.
        before = snapshot_scripts(scripts_dir) if update else {}

        # 1. Extract the .miz (scripts land in src/scripts/). Update refreshes in place.
        MissionExtractorWorker(
            mission_folder=output_mission_folder,
            input_mission_path=input_mission_path,
            keep_community_scripts=True,
            refresh=update,
        ).work(silent=True)
        report.actions.append(t("convert_other.action.extracted", mission=input_mission_path.name))

        # 2. Detect the scripts and the native loader triggers from the source .miz.
        dcs_mission = read_miz(input_mission_path)
        loaders = detect_native_script_loaders(dcs_mission)
        strip_triggers = detect_native_loader_triggers(dcs_mission)

        # 2b. Profile name-normalisation: rename the extracted file and the loader
        #     entry so custom_scripts paths stay stable across upstream versions.
        if profile is not None:
            loaders = self._normalize_script_names(loaders, profile, scripts_dir, overwrite=update)

        if update:
            self._report_update(report, scripts_dir, before, loaders)
        else:
            self._scaffold_mission_yaml(report, output_mission_folder, loaders, strip_triggers, profile, force, backup)

        # 4. Manual review items.
        report.manual_review.append(t("convert_other.review.enable_modules"))
        report.manual_review.append(t("convert_other.review.verify_order"))
        report.manual_review.append(t("convert_other.review.test_dcs"))
        return report

    @staticmethod
    def _scaffold_mission_yaml(
        report: ConversionReport,
        output_mission_folder: Path,
        loaders: list[DetectedLoader],
        strip_triggers: list[tuple[int, str]],
        profile: ConversionProfile | None,
        force: bool,
        backup: bool,
    ) -> None:
        """Write (or skip) the scaffold ``mission.yaml`` for a first-time adoption."""
        dest = output_mission_folder / "mission.yaml"
        if dest.exists() and not force:
            report.mission_yaml_existed = True
            report.mission_yaml_skipped_reason = t("convert_other.action.yaml_skip")
            report.actions.append(t("convert_other.action.yaml_exists"))
        else:
            if dest.exists() and backup:
                shutil.copy2(dest, dest.with_name("mission.yaml.bak"))
            dest.write_text(build_scaffold_yaml(loaders, strip_triggers, profile), encoding="utf-8")
            report.mission_yaml_generated = True
            report.mission_yaml_path = dest
            report.actions.append(
                t(
                    "convert_other.action.yaml_generated",
                    scripts=tn("convert_other.scripts_frag", len(loaders)),
                    triggers=tn("convert_other.triggers_frag", len(strip_triggers)),
                )
            )

    @staticmethod
    def _report_update(
        report: ConversionReport,
        scripts_dir: Path,
        before: dict[str, str],
        loaders: list[DetectedLoader],
    ) -> None:
        """Preserve the tuned ``mission.yaml`` and report the upstream script diff."""
        after = snapshot_scripts(scripts_dir)
        upstream = {loader.script for loader in loaders}
        diff = diff_scripts(before, after, upstream)

        report.mission_yaml_existed = True
        report.mission_yaml_skipped_reason = t("convert_other.update.yaml_preserved")
        report.actions.append(t("convert_other.update.yaml_preserved"))
        if diff.is_empty():
            report.actions.append(t("convert_other.update.no_changes"))
        if diff.added:
            report.actions.append(tn("convert_other.update.added", len(diff.added), names=", ".join(diff.added)))
        if diff.updated:
            report.actions.append(tn("convert_other.update.updated", len(diff.updated), names=", ".join(diff.updated)))
        if diff.removed:
            report.manual_review.append(
                tn("convert_other.update.removed", len(diff.removed), names=", ".join(diff.removed))
            )

    @staticmethod
    def _normalize_script_names(
        loaders: list[DetectedLoader],
        profile: ConversionProfile,
        scripts_dir: Path,
        overwrite: bool = False,
    ) -> list[DetectedLoader]:
        """Rename extracted scripts per *profile* and return loaders with new names.

        Renames ``scripts_dir/<original>`` to ``scripts_dir/<normalised>`` when the
        profile maps it (and the source file is present), so the on-disk file and
        the ``custom_scripts`` path agree. With *overwrite* (``--update``), an
        existing normalised target is replaced by the fresh copy; otherwise it is
        kept (first-time adoption never clobbers an existing file).
        """
        result: list[DetectedLoader] = []
        for loader in loaders:
            new_name = profile.normalize_script_name(loader.script)
            if new_name != loader.script:
                if not _is_plain_filename(new_name):
                    # A profile is data, and it can be supplied by path rather than by bundled name,
                    # so its replacement string is not necessarily ours (SECREV-2 / VMR-035). Left
                    # unchecked, `scripts_dir / "../../x.lua"` renames a script outside the mission's
                    # scripts folder. Refuse and keep the original name rather than guess an intent.
                    logger.warning(t("convert_other.rename_rejected", name=new_name, original=loader.script))
                    result.append(loader)
                    continue
                src = scripts_dir / loader.script
                dst = scripts_dir / new_name
                if src.is_file():
                    if dst.exists() and overwrite:
                        dst.unlink()
                    if not dst.exists():
                        src.rename(dst)
            result.append(replace(loader, script=new_name))
        return result
