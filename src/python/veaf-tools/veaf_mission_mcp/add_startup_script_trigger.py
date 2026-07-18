"""`add_startup_script_trigger` — editor-parity write action: add a mission-start script trigger.

Adds a ``triggerStart`` trigger that runs a script, the way a Mission Maker would in the
DCS editor's Triggers tab — for outfitting a **vanilla or CTLD** mission with scripting
without the editor. Three modes:

- **inline** — run inline Lua (``a_do_script``).
- **file_static** — embed a ``.lua`` file into the ``.miz`` (``l10n/DEFAULT`` resource +
  ``mapResource`` entry) and load it (``a_do_script_file``).
- **file_dynamic** — load a ``.lua`` from a runtime disk path (``a_do_script`` with
  ``loadfile``), nothing embedded.

Generalizes ``mission_builder.mission_builder_worker.inject_dcs_bridge_trigger`` and the
VEAF static/dynamic loading mechanism (ADR 0004). Unlike that helper — which inserts at
index 1 and renumbers every existing trigger — this **appends** at the next free index, so
no existing trig/trigrules entry is renumbered. Mutation goes through the backup helper;
not deduplicated.
"""

import json
from pathlib import Path
from typing import Any

from mission_tools.mission_constants import DEFAULT_SCRIPTS_LOCATION
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

# The trig categories a triggerStart DO-SCRIPT trigger writes into.
_TRIG_CATEGORIES = ("actions", "conditions", "flag", "funcStartup")


def add_startup_script_trigger(
    miz_path: Path,
    *,
    mode: str,
    comment: str,
    inline_lua: str | None = None,
    source_path: str | None = None,
    runtime_path: str | None = None,
    resource_name: str | None = None,
) -> dict[str, Any]:
    """Add a mission-start script trigger to a mission's source `.miz`, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        mode: ``"inline"``, ``"file_static"`` or ``"file_dynamic"``.
        comment: The trigger's editor label.
        inline_lua: Lua to run (required for ``mode="inline"``).
        source_path: Path to the `.lua` file to embed (required for ``mode="file_static"``).
        runtime_path: Disk path DCS will `loadfile` at runtime (required for
            ``mode="file_dynamic"``).
        resource_name: Basename to embed the static file under in `l10n/DEFAULT`
            (defaults to the source file's name).

    Returns:
        `{"trigger_index": <int>, "comment": <str>}`.

    Raises:
        ValueError: If the archive is not a valid mission, or the mode's required
            argument is missing.
        FileNotFoundError: If ``mode="file_static"`` and ``source_path`` does not exist.
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    index, additional_files = apply_startup_script_trigger(
        mission.mission_content,
        mode=mode,
        comment=comment,
        inline_lua=inline_lua,
        source_path=source_path,
        runtime_path=runtime_path,
        resource_name=resource_name,
    )

    backup_before_write(miz_path)
    write_miz(mission, miz_path, additional_files=additional_files or None)

    return {"trigger_index": index, "comment": comment}


def apply_startup_script_trigger(
    content: dict[str, Any],
    *,
    mode: str,
    comment: str,
    inline_lua: str | None = None,
    source_path: str | None = None,
    runtime_path: str | None = None,
    resource_name: str | None = None,
) -> tuple[int, dict[str, bytes]]:
    """Mutate a parsed `mission` table in place, adding the startup script trigger.

    Pure (no I/O beyond reading the static source file's bytes); the ``.miz`` read/backup/
    write is handled by :func:`add_startup_script_trigger`.

    Args:
        content: The parsed DCS `mission` table (mutated in place).
        mode: ``"inline"``, ``"file_static"`` or ``"file_dynamic"``.
        comment: The trigger's editor label.
        inline_lua: Lua to run (required for ``mode="inline"``).
        source_path: Path to the `.lua` file to embed (required for ``mode="file_static"``).
        runtime_path: Disk path DCS `loadfile`'s at runtime (required for ``mode="file_dynamic"``).
        resource_name: Basename to embed the static file under (defaults to the source name).

    Returns:
        ``(trigger_index, additional_files)`` — the assigned trigger index and any files to
        embed into the archive (``arcname → bytes``, empty unless static-file mode).
    """
    action_trigrule, action_compiled, additional_files = _build_action(
        mode, content, inline_lua, source_path, runtime_path, resource_name
    )
    index = _next_trigger_index(content)
    _append_trigrule(content, index, comment, action_trigrule)
    _append_trig(content, index, action_compiled)
    return index, additional_files


def _build_action(
    mode: str,
    content: dict[str, Any],
    inline_lua: str | None,
    source_path: str | None,
    runtime_path: str | None,
    resource_name: str | None,
) -> tuple[dict[str, Any], str, dict[str, bytes]]:
    """Build the (trigrule action, compiled trig action string, files-to-embed) for a mode."""
    if mode == "inline":
        if inline_lua is None:
            raise ValueError("mode='inline' requires inline_lua")
        return (
            {"predicate": "a_do_script", "text": inline_lua},
            f"a_do_script({_lua_literal(inline_lua)});",
            {},
        )
    if mode == "file_dynamic":
        if runtime_path is None:
            raise ValueError("mode='file_dynamic' requires runtime_path")
        loader = f"assert(loadfile([[{runtime_path}]]))()"
        return (
            {"predicate": "a_do_script", "text": loader},
            f"a_do_script({_lua_literal(loader)});",
            {},
        )
    if mode == "file_static":
        if source_path is None:
            raise ValueError("mode='file_static' requires source_path")
        src = Path(source_path)
        if not src.is_file():
            raise FileNotFoundError(f"Script file not found: {src}")
        basename = resource_name or src.name
        key = _allocate_map_resource_key(content, basename)
        arcname = f"{DEFAULT_SCRIPTS_LOCATION}/{basename}"
        return (
            {"predicate": "a_do_script_file", "file": key},
            f'a_do_script_file(getValueResourceByKey("{key}"));',
            {arcname: src.read_bytes()},
        )
    raise ValueError(f"Unknown mode: {mode!r} (expected 'inline', 'file_static' or 'file_dynamic')")


def _lua_literal(text: str) -> str:
    """Return `text` as a double-quoted Lua string literal, safely escaped.

    JSON string escaping (`"`, `\\`, `\\n`, `\\t`, `\\r`) is a valid subset of Lua string
    escaping, so `json.dumps` produces a correct Lua literal for the inline-script case.
    """
    return json.dumps(text, ensure_ascii=False)


def _allocate_map_resource_key(content: dict[str, Any], basename: str) -> str:
    """Return a fresh, unique `mapResource` key for an embedded script."""
    resources = content.setdefault("mapResource", {})
    stem = Path(basename).stem
    key = f"MCP_MapKey_{stem}"
    suffix = 2
    while key in resources:
        key = f"MCP_MapKey_{stem}_{suffix}"
        suffix += 1
    resources[key] = basename
    return key


def _next_trigger_index(content: dict[str, Any]) -> int:
    """Return the next free 1-based trigger index across `trigrules` and every `trig` category."""
    max_index = 0
    trigrules = content.get("trigrules")
    if isinstance(trigrules, dict):
        max_index = max([max_index, *(_as_int(k) for k in trigrules)])
    trig = content.get("trig")
    if isinstance(trig, dict):
        for category in trig.values():
            if isinstance(category, dict):
                max_index = max([max_index, *(_as_int(k) for k in category)])
    return max_index + 1


def _as_int(key: Any) -> int:
    try:
        return int(key)
    except (TypeError, ValueError):
        return 0


def _append_trigrule(content: dict[str, Any], index: int, comment: str, action: dict[str, Any]) -> None:
    """Append the editor-form trigger rule at `index`."""
    trigrules = content.setdefault("trigrules", {})
    trigrules[index] = {
        "comment": comment,
        "predicate": "triggerStart",
        "eventlist": "",
        "rules": [],
        "actions": [action],
        "colorItem": "0x00ffffff",
    }


def _append_trig(content: dict[str, Any], index: int, action_compiled: str) -> None:
    """Append the compiled runtime trigger entries at `index`, always-true condition."""
    trig = content.setdefault("trig", {})
    for category in _TRIG_CATEGORIES:
        trig.setdefault(category, {})
    trig["actions"][index] = action_compiled
    trig["conditions"][index] = "return true"
    trig["flag"][index] = True
    trig["funcStartup"][index] = f"if mission.trig.conditions[{index}]() then mission.trig.actions[{index}]() end"
