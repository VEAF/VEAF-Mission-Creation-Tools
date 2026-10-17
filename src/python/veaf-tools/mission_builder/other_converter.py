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
import re
import shutil
from dataclasses import dataclass, replace
from datetime import datetime
from pathlib import Path

import yaml
from mission_extractor import MissionExtractorWorker
from mission_tools import read_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.conversion_profile import ConversionProfile, load_profile
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger
from veaf_libs.mission_template import render_modules_block, tier_modules

from mission_builder.mission_builder_worker import format_delay_seconds, lua_loads_other_scripts
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


#: Where a converted mission records what its upstream release loads. Written beside
#: ``convert-other-report.md``, in the mission folder, and meant to be committed with it.
STATE_FILE = "convert-other-state.yaml"


def read_upstream_manifest(mission_folder: Path) -> set[str]:
    """Return the script names the previous conversion recorded as coming from upstream.

    Args:
        mission_folder: The mission folder.

    Returns:
        The recorded script base names, or an empty set when no manifest exists — which is the
        case for every mission adopted before this file did, and the reason an empty set has to
        mean "do not touch anything" rather than "upstream shipped nothing".
    """
    state = mission_folder / STATE_FILE
    if not state.is_file():
        return set()
    try:
        parsed = yaml.safe_load(state.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError):
        return set()
    scripts = parsed.get("upstream_scripts") if isinstance(parsed, dict) else None
    return {str(name) for name in scripts or []}


def write_upstream_manifest(mission_folder: Path, loaders: list[DetectedLoader]) -> None:
    """Record the scripts *loaders* says this release loads.

    Without it, a script that disappeared from a release is indistinguishable from one the
    mission maker wrote: both sit in ``src/scripts/``, both are listed in ``custom_scripts:``,
    and neither is in the fresh upstream set. Deleting on those grounds alone would eat the
    maker's work, so the converter writes down what each release brought.

    Args:
        mission_folder: The mission folder.
        loaders: The loaders detected in the release just converted.
    """
    names = sorted({loader.script for loader in loaders})
    body = [
        "# Written by veaf-tools convert-other. Commit it with the mission.",
        "#",
        "# What the upstream release loads, so the next --update can tell a script the release",
        "# dropped (deleted, since the build would otherwise embed the previous version) from a",
        "# script you added yourself (left strictly alone).",
        "upstream_scripts:",
    ]
    body += [f"  - {_yaml_path(name)}" for name in names]
    (mission_folder / STATE_FILE).write_text("\n".join(body) + "\n", encoding="utf-8")


@dataclass(frozen=True)
class DetectedLoader:
    """One script loaded by a native ``a_do_script_file`` trigger action.

    Attributes:
        script: The resolved script filename (e.g. ``"Moose_2026-04-28.lua"``).
        trigger_index: The ``trigrules`` index of the loader trigger.
        trigger_comment: The trigger's editor comment (e.g. ``"ScriptLoader 1"``).
        delay_seconds: The loader trigger's ``c_time_after`` seconds, when it has one.
            Upstream missions stage their loading this way — Foothold at +3 s and +12 s —
            and without recording it the adoption flattens the staging silently.
    """

    script: str
    trigger_index: int
    trigger_comment: str
    delay_seconds: float | None = None


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
        delay = _trigrule_delay_seconds(trigrule)
        for action in _ordered_actions(trigrule):
            if action.get("predicate") != "a_do_script_file":
                continue
            resolved = map_resource.get(action.get("file", ""))
            if resolved and str(resolved).lower().endswith(_LUA_SUFFIX):
                loaders.append(DetectedLoader(str(resolved), index, comment, delay))
    return loaders


_PATH_LINE = re.compile(r"^(?P<indent>[ \t]*)-[ \t]+path:[ \t]*(?P<value>.+?)[ \t]*$")
_DELAY_LINE = re.compile(r"^(?P<indent>[ \t]*)delay_seconds:[ \t]*(?P<value>.+?)[ \t]*$")


def _unquote(value: str) -> str:
    """Strip the quotes YAML needs around a path that contains a space."""
    return value[1:-1] if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'" else value


def _as_delay(value: str) -> float | None:
    """Parse a declared ``delay_seconds`` value, or ``None`` when it is not a number."""
    try:
        return float(value)
    except ValueError:
        return None


def apply_upstream_delays(mission_yaml_path: Path | None, loaders: list[DetectedLoader]) -> list[str]:
    """Write the upstream load staging into a preserved ``mission.yaml``, in place.

    ``--update`` preserves the tuned file, which is why the staging was never written into any of
    the five VEAF Foothold missions: ``delay_seconds`` arrived after they were adopted, so every
    refresh detected the mismatch and none of them could fix it. A delay is upstream's decision
    rather than the maker's tuning, so this reconciles it — and names every line it wrote, since
    an edit to a preserved file that the report stays silent about would be this lot's own defect
    in a new costume.

    The file is edited as **text**, one line at a time: parsing and re-emitting it would drop the
    comments, the ordering and the quoting the maker relies on, and flip the line endings the
    batch normalised.

    Args:
        mission_yaml_path: The preserved ``mission.yaml``.
        loaders: The loaders detected in the fresh upstream mission.

    Returns:
        One human-readable line per delay written, added or removed, in file order. Empty when
        the file already matched upstream — in which case it is not rewritten at all.
    """
    if mission_yaml_path is None or not mission_yaml_path.is_file():
        return []
    upstream = {loader.script: loader.delay_seconds for loader in loaders}
    try:
        raw = mission_yaml_path.read_text(encoding="utf-8", newline="")
    except OSError:
        return []

    lines = raw.splitlines(keepends=True)
    result: list[str] = []
    changes: list[str] = []
    index = 0
    inside = False
    while index < len(lines):
        line = lines[index]
        index += 1
        result.append(line)

        # Stay strictly inside `custom_scripts:`. `strip_native_triggers:` right below it is a
        # list too, and editing an entry there would corrupt the mission for no reason at all.
        bare = line.rstrip("\r\n")
        if bare[:1] not in (" ", "\t") and bare.strip():
            inside = bare.strip() == "custom_scripts:"
            continue

        match = _PATH_LINE.match(bare) if inside else None
        if match is None:
            continue

        script = Path(_unquote(match.group("value"))).name
        eol = line[len(line.rstrip("\r\n")) :] or "\n"

        # A `delay_seconds:` indented under this entry belongs to it.
        declared_line, declared = None, None
        if index < len(lines):
            follower = _DELAY_LINE.match(lines[index].rstrip("\r\n"))
            if follower is not None and len(follower.group("indent")) > len(match.group("indent")):
                declared_line, declared = lines[index], _as_delay(follower.group("value"))
                index += 1

        if script not in upstream:
            # Upstream never shipped it, so it is the maker's script and its staging is theirs.
            if declared_line is not None:
                result.append(declared_line)
            continue

        wanted = upstream[script]
        if wanted is not None:
            result.append(f"{match.group('indent')}  delay_seconds: {format_delay_seconds(wanted)}{eol}")
        if wanted != declared:
            changes.append(
                t(
                    "convert_other.update.delay_synced",
                    script=script,
                    declared="none" if declared is None else format_delay_seconds(declared),
                    upstream="none" if wanted is None else format_delay_seconds(wanted),
                )
            )

    if changes:
        with open(mission_yaml_path, "w", encoding="utf-8", newline="") as handle:
            handle.write("".join(result))
    return changes


#: A ``.lua`` filename assigned in an exploded ``mapResource`` table.
_MAP_RESOURCE_LUA = re.compile(r'=\s*"([^"]+\.lua)"', re.IGNORECASE)


def read_previous_upstream_scripts(mission_folder: Path, profile: ConversionProfile | None) -> set[str]:
    """Return the scripts the release this folder was last refreshed from loaded.

    The manifest says it when present. Every mission adopted before the manifest existed has
    none, and on its first refresh could not tell a script the previous release shipped from one
    the mission maker added — so a renamed upstream script was kept as the maker's. The exploded
    mission base still names them: its ``mapResource`` lists the scripts that release embedded.
    Read it **before** the extraction overwrites it.

    Args:
        mission_folder: The mission folder.
        profile: The conversion profile, whose name normalisation the recorded names went through.

    Returns:
        The script base names, normalised as ``custom_scripts`` writes them; empty when neither
        the manifest nor an exploded ``mapResource`` exists.
    """
    recorded = read_upstream_manifest(mission_folder)
    if recorded:
        return recorded
    map_resource = mission_folder / "src" / "mission" / "l10n" / "DEFAULT" / "mapResource"
    try:
        text = map_resource.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return set()
    names = {Path(match).name for match in _MAP_RESOURCE_LUA.findall(text)}
    if profile is not None:
        names = {profile.normalize_script_name(name) for name in names}
    return names


@dataclass
class _ScriptEntry:
    """One ``- path:`` item of the ``custom_scripts:`` list, with the lines that belong to it."""

    script: str
    lines: list[str]


def reconcile_custom_scripts(
    mission_yaml_path: Path | None, loaders: list[DetectedLoader], was_upstream: set[str]
) -> list[str]:
    """Make a preserved ``custom_scripts:`` list load what the upstream release loads, in place.

    The upstream entries are rewritten in the release's load order: a script it no longer loads
    and the previous release did is dropped, a script it newly loads is added (with its upstream
    ``delay_seconds``). Anything else is the mission maker's and is kept, after the upstream
    entries and in its own order, with its lines untouched. Foothold 5.3.0 renamed
    ``zoneCommander.lua`` to ``zoneCommanderv2.lua`` on all ten maps; preserving the list as it was
    kept the old engine loaded beside the new config.

    Edited as text, like :func:`apply_upstream_delays`, so comments, quoting and line endings
    survive. Delays of entries already present are left to :func:`apply_upstream_delays`.

    Args:
        mission_yaml_path: The preserved ``mission.yaml``.
        loaders: The loaders detected in the fresh upstream mission, in load order.
        was_upstream: The scripts the previous release loaded (see
            :func:`read_previous_upstream_scripts`).

    Returns:
        One human-readable line per kind of change, in a stable order. Empty when the list already
        matched — in which case the file is not rewritten.
    """
    if mission_yaml_path is None or not mission_yaml_path.is_file():
        return []
    try:
        raw = mission_yaml_path.read_text(encoding="utf-8", newline="")
    except OSError:
        return []

    lines = raw.splitlines(keepends=True)
    # The `custom_scripts:` block runs until the next column-0 line, comments included: the
    # comment above `strip_native_triggers:` belongs to that block, not to this one.
    start = next((i for i, line in enumerate(lines) if line.rstrip("\r\n") == "custom_scripts:"), None)
    if start is None:
        return []
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i][:1] not in (" ", "\t") and lines[i].strip()),
        len(lines),
    )
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1  # trailing blank lines stay outside the rewritten region

    header: list[str] = []
    entries: list[_ScriptEntry] = []
    pending: list[str] = []
    item_indent = ""
    for line in lines[start + 1 : end]:
        bare = line.rstrip("\r\n")
        match = _PATH_LINE.match(bare)
        if match is not None:
            item_indent = match.group("indent")
            entries.append(_ScriptEntry(Path(_unquote(match.group("value"))).name, [*pending, line]))
            pending = []
        elif entries and bare.strip() and len(bare) - len(bare.lstrip()) > len(item_indent):
            entries[-1].lines.append(line)
        elif entries:
            pending.append(line)
        else:
            header.append(line)
    if not entries:
        return []

    eol = "\r\n" if raw.count("\r\n") * 2 > raw.count("\n") else "\n"
    upstream = [loader for loader in dict((loader.script, loader) for loader in loaders).values()]
    upstream_names = {loader.script for loader in upstream}
    existing = {entry.script: entry for entry in entries}

    rebuilt: list[_ScriptEntry] = []
    added: list[str] = []
    for loader in upstream:
        if loader.script in existing:
            rebuilt.append(existing[loader.script])
            continue
        new_lines = [f"{item_indent}- path: {_yaml_path(f'src/scripts/{loader.script}')}{eol}"]
        if loader.delay_seconds is not None:
            new_lines.append(f"{item_indent}  delay_seconds: {format_delay_seconds(loader.delay_seconds)}{eol}")
        rebuilt.append(_ScriptEntry(loader.script, new_lines))
        added.append(loader.script)
    dropped = [e.script for e in entries if e.script not in upstream_names and e.script in was_upstream]
    rebuilt += [e for e in entries if e.script not in upstream_names and e.script not in was_upstream]

    result = [*lines[: start + 1], *header, *(line for entry in rebuilt for line in entry.lines), *pending]
    result += lines[end:]
    if result == lines:
        return []

    changes: list[str] = []
    if added:
        changes.append(tn("convert_other.update.scripts_listed", len(added), names=", ".join(added)))
    if dropped:
        changes.append(tn("convert_other.update.scripts_unlisted", len(dropped), names=", ".join(dropped)))
    if not added and not dropped:
        changes.append(t("convert_other.update.scripts_reordered"))
    with open(mission_yaml_path, "w", encoding="utf-8", newline="") as handle:
        handle.write("".join(result))
    return changes


def _trigrule_delay_seconds(trigrule: dict) -> float | None:
    """Return a loader trigger's ``c_time_after`` delay in seconds, or ``None``.

    Only a positive delay is reported: ``c_time_after`` with 0 seconds says the same thing as
    no rule at all, and emitting ``delay_seconds: 0`` would scaffold a trigger for nothing.

    Args:
        trigrule: One ``trigrules`` entry.

    Returns:
        The delay in seconds, or ``None`` when the trigger has no usable time rule.
    """
    rules = trigrule.get("rules")
    if not isinstance(rules, dict):
        # DCS writes rules as a 1-based table, which luadata may hand back as either shape.
        rules = dict(enumerate(rules or [], start=1)) if isinstance(rules, list) else {}
    for rule in rules.values():
        if isinstance(rule, dict) and rule.get("predicate") == "c_time_after":
            seconds = rule.get("seconds")
            if isinstance(seconds, bool) or not isinstance(seconds, (int, float)):
                continue
            if seconds > 0:
                return float(seconds)
    return None


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
        if loader.delay_seconds is not None:
            # The upstream trigger was gated on c_time_after, so reproduce the staging rather
            # than flattening it into the shared triggerStart.
            lines.append(f"      delay_seconds: {format_delay_seconds(loader.delay_seconds)}")
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

        # In update mode, snapshot the existing scripts — and what the previous release loaded,
        # which the exploded base still names — before the refresh overwrites them.
        before = snapshot_scripts(scripts_dir) if update else {}
        was_upstream = read_previous_upstream_scripts(output_mission_folder, profile) if update else set()

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
            self._report_update(report, scripts_dir, before, loaders, output_mission_folder, was_upstream)
        else:
            self._scaffold_mission_yaml(report, output_mission_folder, loaders, strip_triggers, profile, force, backup)

        # Last, so `_report_update` compares against the *previous* release's manifest.
        write_upstream_manifest(output_mission_folder, loaders)

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
        mission_folder: Path,
        was_upstream: set[str],
    ) -> None:
        """Preserve the tuned ``mission.yaml`` and report the upstream script diff.

        Args:
            report: The report being filled.
            scripts_dir: Where the extracted scripts landed.
            before: Script fingerprints taken before the extraction.
            loaders: The upstream loaders detected in this version.
            mission_folder: The mission folder, holding the preserved ``mission.yaml`` (its
                ``custom_scripts`` list and ``delay_seconds`` are reconciled with upstream's).
            was_upstream: The scripts the previous release loaded, read before the extraction.
        """
        mission_yaml_path = mission_folder / "mission.yaml"
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

        # A script the *previous* release shipped and this one does not is stale: leaving it on
        # disk is what made `validate` pass while the build embedded the old version of a renamed
        # script. Anything else the upstream never shipped is the mission maker's, and is only
        # reported.
        stale = tuple(name for name in diff.removed if name in was_upstream)
        theirs = tuple(name for name in diff.removed if name not in was_upstream)
        for name in stale:
            (scripts_dir / name).unlink(missing_ok=True)
        if stale:
            report.actions.append(tn("convert_other.update.removed_stale", len(stale), names=", ".join(stale)))
        if theirs:
            report.manual_review.append(tn("convert_other.update.removed", len(theirs), names=", ".join(theirs)))

        # The list itself is upstream's too: a script the release renamed must leave custom_scripts
        # and its successor enter it, or the build loads the previous engine beside the new config.
        for change in reconcile_custom_scripts(mission_yaml_path, loaders, was_upstream):
            report.actions.append(change)

        # A staging change is as much an upstream change as an added script, and it is the one
        # nothing else would reveal: the tuned mission.yaml is preserved, so an upstream delay
        # that moved stays silently wrong until someone re-reads the source triggers. Detecting it
        # was never the problem — this reconciles it, and reports every line it wrote.
        for change in apply_upstream_delays(mission_yaml_path, loaders):
            report.actions.append(change)

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
