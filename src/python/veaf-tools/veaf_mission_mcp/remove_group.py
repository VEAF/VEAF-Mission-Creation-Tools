"""`remove_group` — take a group out of a mission, and say what that breaks.

The catalogue could add a group, move it, rename it and reconfigure it, but not **remove** it, while
`edit_zone` and `edit_map_drawing` both have a `remove: true`. So removal was done by hand, and that
is where every corrupted build of the 2026-08-18 verification session came from: deleting a Lua block
leaves the enclosing list numbered `1,3,4`, Lua loads that without complaint, and the build dies on
``AttributeError: 'int' object has no attribute 'get'`` at a line nowhere near the edit. The repair
attempt made it worse — a renumbering regex keyed on indentation alone also renumbered `units` and
`route.points`.

`FIX-GROUP-CONTAINER-SHAPE` owns the other half: making the build survive a container a hand edit
already holed. This module removes the reason to hand-edit in the first place, which is why it
**renumbers what it leaves behind** and drops the `group` key entirely rather than leaving the empty
container that lot opens on.

Three references break in silence when a group disappears, and none of them is a Lua error:

- a **combat zone captures groups by name prefix**, so a zone whose name starts the group's name
  loses a member;
- an **`Escort` task points at a group id**, and the escorting group keeps a task aimed at nothing;
- **`ASSETS`** names its assets by group name in `mission.yaml`, so the radio menu offers a group
  that is gone.

The action refuses nothing on their account — the mission maker may well be removing the group on
purpose — but it names each one it finds.
"""

from pathlib import Path
from typing import Any

import yaml
from veaf_libs.mission_table import CATEGORIES, indexed

from veaf_mission_mcp.mission_folder import commit_mission, open_mission
from veaf_mission_mcp.mission_table import group_names, listed


def remove_group(target: Path, *, group_name: str) -> dict[str, Any]:
    """Remove one group from a mission, renumbering the container it leaves behind.

    Args:
        target: The mission **folder** (durable) or a **`.miz`** (transient).
        group_name: The group's **exact** name — a fragment is refused, as `set_group_properties`
            refuses one: a removal landing on whichever group matched first is not recoverable.

    Returns:
        ``{"group", "category", "coalition", "country", "group_id", "remaining", "durable",
        "warnings"}`` — ``remaining`` being how many groups the category still holds.

    Raises:
        ValueError: If the target is not a readable mission, or no group carries that exact name.
    """
    mission, content = open_mission(target)

    found = _locate(content, group_name)
    if found is None:
        raise ValueError(
            f"No group named {group_name!r} in this mission. Groups present: {listed(group_names(content))}"
        )
    coalition_name, country, category, group = found
    group_id = group.get("groupId")

    warnings = _reference_warnings(content, target, group_name, group_id)
    remaining = _remove_and_renumber(country, category, group_name)
    durable = commit_mission(mission, target)["durable"]

    return {
        "group": group_name,
        "category": category,
        "coalition": coalition_name,
        "country": country.get("name"),
        "group_id": group_id,
        "remaining": remaining,
        "durable": durable,
        "warnings": warnings,
    }


def _locate(content: dict[str, Any], group_name: str) -> tuple[str, dict[str, Any], str, dict[str, Any]] | None:
    """Find the group and the country/category that hold it.

    Args:
        content: The parsed ``mission`` table.
        group_name: The exact group name.

    Returns:
        ``(coalition_name, country, category, group)``, or ``None`` when the name is absent.
    """
    for coalition_name, coalition in (content.get("coalition") or {}).items():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if isinstance(group, dict) and str(group.get("name", "")) == group_name:
                        return str(coalition_name), country, category, group
    return None


def _remove_and_renumber(country: dict[str, Any], category: str, group_name: str) -> int:
    """Drop the named group and rewrite the container's keys as a contiguous ``1..n``.

    A hole is the whole defect this action exists to prevent, so the container is rebuilt rather than
    patched: the survivors keep their table order and are re-keyed from 1. When nothing is left, the
    ``group`` key goes away instead of holding an empty table — the shape a downstream reader mistakes
    for a list.

    Args:
        country: The country table holding the category.
        category: The category key (``plane``, ``vehicle``, …).
        group_name: The group to drop.

    Returns:
        How many groups the category still holds.
    """
    category_table = country.get(category)
    if not isinstance(category_table, dict):
        return 0
    survivors = [
        group
        for group in indexed(category_table.get("group"))
        if not (isinstance(group, dict) and str(group.get("name", "")) == group_name)
    ]
    if survivors:
        category_table["group"] = {index: group for index, group in enumerate(survivors, start=1)}
    else:
        category_table.pop("group", None)
    return len(survivors)


def _reference_warnings(content: dict[str, Any], target: Path, group_name: str, group_id: Any) -> list[str]:
    """Name every reference to the group that will survive its removal, in silence.

    Args:
        content: The parsed ``mission`` table.
        target: The mission folder or `.miz`, so `mission.yaml` can be read when there is one.
        group_name: The group being removed.
        group_id: Its `groupId`, for the task references that point by id.

    Returns:
        One message per surviving reference; empty when nothing points at the group.
    """
    warnings: list[str] = []

    for zone_name in _capturing_zone_names(content, group_name):
        warnings.append(
            f"Combat zone {zone_name!r} captures groups by name prefix, so it loses {group_name!r} — "
            "check the zone still has the members it needs."
        )

    for holder, task_id in _tasks_pointing_at(content, group_id):
        warnings.append(
            f"Group {holder!r} has a {task_id} task pointing at group id {group_id}, which no longer "
            "exists — the task will do nothing."
        )

    warnings.extend(_asset_warnings(target, group_name))
    return warnings


def _capturing_zone_names(content: dict[str, Any], group_name: str) -> list[str]:
    """Trigger zones whose name prefixes the group's, i.e. that capture it by convention."""
    zones = (content.get("triggers") or {}).get("zones")
    return [
        str(zone["name"])
        for zone in indexed(zones)
        if isinstance(zone, dict) and zone.get("name") and group_name.startswith(str(zone["name"]))
    ]


def _tasks_pointing_at(content: dict[str, Any], group_id: Any) -> list[tuple[str, str]]:
    """Every ``(holder group name, task id)`` whose task params name `group_id`."""
    if group_id is None:
        return []
    hits: list[tuple[str, str]] = []
    for coalition in (content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if not isinstance(group, dict):
                        continue
                    for point in indexed((group.get("route") or {}).get("points")):
                        if isinstance(point, dict):
                            hits.extend(
                                (str(group.get("name", "")), task_id)
                                for task_id in _task_ids_naming(point.get("task"), group_id)
                            )
    return hits


def _task_ids_naming(task: Any, group_id: Any) -> list[str]:
    """Task ids inside `task` (which nests through ComboTask) carrying `groupId` == `group_id`."""
    if not isinstance(task, dict):
        return []
    found: list[str] = []
    params = task.get("params")
    if isinstance(params, dict):
        if params.get("groupId") == group_id:
            found.append(str(task.get("id", "task")))
        for nested in indexed(params.get("tasks")):
            found.extend(_task_ids_naming(nested, group_id))
    return found


def _asset_warnings(target: Path, group_name: str) -> list[str]:
    """`modules.ASSETS.assets[]` entries naming the group, when `mission.yaml` is reachable."""
    if not target.is_dir():
        # A `.miz` carries no `mission.yaml`; its VEAF config is already generated Lua, so there is
        # nothing to check rather than nothing found — said plainly instead of implied by silence.
        return []
    yaml_path = target / "mission.yaml"
    if not yaml_path.is_file():
        return []
    try:
        config = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError):
        return []
    assets = ((config.get("modules") or {}).get("ASSETS") or {}).get("assets") or []
    return [
        f"mission.yaml lists {group_name!r} under modules.ASSETS.assets, so the ASSETS radio menu will "
        "offer a group that no longer exists — remove that entry too."
        for asset in assets
        if isinstance(asset, dict) and str(asset.get("name", "")) == group_name
    ]
