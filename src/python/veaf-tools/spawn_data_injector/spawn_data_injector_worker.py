"""Inject the spawn-data Lua module into a built ``.miz`` (SPAWN-EXTERNALIZE-003).

``veafUnits.lua`` ships its ``UnitsDatabase`` / ``GroupsDatabase`` empty. At
mission build this step renders the framework spawn data (``veaf-units.yaml``),
merged with any per-mission data (SPAWN-EXTERNALIZE-004), into a Lua module that
assigns the two tables, embeds it as a mission map resource, and appends a
``a_do_script_file`` trigger that runs **after** the VEAF framework bundle has
loaded ``veafUnits.lua``. See ADR 0005.

The trigger is appended at the end of the trigger list (highest index), so it
runs after every framework and mission script load trigger. That is safe because
the spawn database is consumed at runtime (``_spawn`` commands, dynamic group
generation), never during script load.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml
from mission_tools import DEFAULT_SCRIPTS_LOCATION, read_miz, write_miz
from mission_tools.miz_tools import DcsMission
from veaf_libs.base_worker import BaseWorker
from veaf_libs.i18n import t
from veaf_libs.logger import logger

from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data, render_spawn_data_lua

#: Map-resource key and embedded filename for the generated spawn-data module.
_MAP_KEY = "VEAF_MapKey_SpawnData"
_RESOURCE_FILENAME = "veaf-spawn-data.lua"


@dataclass
class SpawnDataResult:
    """Outcome of a spawn-data injection run."""

    units: int
    groups: int


def merge_spawn_data(framework: dict[str, Any], mission: dict[str, Any] | None) -> dict[str, Any]:
    """Merge per-mission spawn data over the framework data (SPAWN-EXTERNALIZE-004).

    Entries are matched by alias: a mission entry sharing any alias with a
    framework entry **replaces** it; otherwise it is appended. Order is preserved
    (framework first, then new mission entries).

    Args:
        framework: The shipped framework spawn data (``{"units", "groups"}``).
        mission: The per-mission spawn data, or ``None``.

    Returns:
        The merged ``{"units": [...], "groups": [...]}``.
    """
    merged = {"units": list(framework.get("units") or []), "groups": list(framework.get("groups") or [])}
    if not mission:
        return merged
    for kind in ("units", "groups"):
        for entry in mission.get(kind) or []:
            aliases = {str(a).lower() for a in entry.get("aliases") or []}
            replaced = False
            for i, existing in enumerate(merged[kind]):
                if aliases & {str(a).lower() for a in existing.get("aliases") or []}:
                    merged[kind][i] = entry
                    replaced = True
                    break
            if not replaced:
                merged[kind].append(entry)
    return merged


def _next_trigger_index(mission_content: dict) -> int:
    """Return the next free 1-based trigger index (one past the current maximum)."""
    indices: list[int] = []
    trigrules = mission_content.get("trigrules") or {}
    indices.extend(int(k) for k in trigrules)
    trig = mission_content.get("trig") or {}
    for category in trig.values():
        if isinstance(category, dict):
            indices.extend(int(k) for k in category)
    return (max(indices) + 1) if indices else 1


def inject_spawn_data(mission: DcsMission, lua_text: str) -> dict[str, bytes]:
    """Embed the spawn-data module and append its load trigger, in place.

    Args:
        mission: The parsed mission (``mission_content`` / ``map_resource_content``
            are mutated).
        lua_text: The rendered spawn-data Lua module.

    Returns:
        The ``additional_files`` mapping to hand to :func:`write_miz` (the embedded
        resource bytes).
    """
    assert mission.mission_content is not None
    mission.map_resource_content = mission.map_resource_content or {}
    mission.map_resource_content[_MAP_KEY] = _RESOURCE_FILENAME

    index = _next_trigger_index(mission.mission_content)

    trigrules: dict = mission.mission_content.setdefault("trigrules", {})
    trigrules[index] = {
        "comment": "VEAF spawn-data loading",
        "predicate": "triggerStart",
        "eventlist": "",
        "rules": [],
        "actions": [{"predicate": "a_do_script_file", "file": _MAP_KEY}],
        "colorItem": "0x00ffffff",
    }

    trig: dict = mission.mission_content.setdefault("trig", {})
    trig.setdefault("actions", {})[index] = f'a_do_script_file(getValueResourceByKey("{_MAP_KEY}"));'
    trig.setdefault("conditions", {})[index] = "return true"
    trig.setdefault("flag", {})[index] = True
    trig.setdefault("funcStartup", {})[index] = (
        f"if mission.trig.conditions[{index}]() then mission.trig.actions[{index}]() end"
    )

    return {f"{DEFAULT_SCRIPTS_LOCATION}/{_RESOURCE_FILENAME}": lua_text.encode("utf-8")}


class SpawnDataInjectorWorker(BaseWorker):
    """Render and inject the spawn-data Lua module into a ``.miz``."""

    def __init__(
        self,
        input_mission: Path,
        output_mission: Path,
        mission_data_file: Path | None = None,
    ) -> None:
        """Initialize the worker.

        Args:
            input_mission: Source ``.miz``.
            output_mission: Destination ``.miz`` (may equal the source).
            mission_data_file: Optional per-mission spawn YAML to merge over the
                framework data (SPAWN-EXTERNALIZE-004).
        """
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.mission_data_file = mission_data_file

    def work(self) -> SpawnDataResult:
        """Render the merged spawn data and inject it into the mission.

        Returns:
            The run result (unit and group counts injected).
        """
        framework = load_framework_spawn_data()
        mission_data: dict[str, Any] | None = None
        if self.mission_data_file and self.mission_data_file.exists():
            mission_data = yaml.safe_load(self.mission_data_file.read_text(encoding="utf-8")) or {}
        data = merge_spawn_data(framework, mission_data)
        lua_text = render_spawn_data_lua(data)

        mission = read_miz(self.input_mission)
        additional_files = inject_spawn_data(mission, lua_text)
        write_miz(mission=mission, miz_file_path=self.output_mission, additional_files=additional_files)

        result = SpawnDataResult(units=len(data["units"]), groups=len(data["groups"]))
        logger.info(t("spawn_data.done", units=result.units, groups=result.groups))
        return result
