"""VEAF group-name conventions: derive correct names, and flag reserved-pattern collisions.

Two concerns, one cohesive module (wave 6):

- :func:`resolve_group_name` — turn a caller's *intent* into a convention-correct name
  (combat-zone prefix, ``veafSpawn-`` template prefix).
- :func:`validate_group_name` — check a proposed name against the reserved VEAF naming
  conventions (the same set the wave-5 oracle ``describe_naming_conventions`` reports) and return
  warnings, so the calling LLM can relay them to the user. The MCP server never converses itself.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz

_SPAWN_TEMPLATE_PREFIX = "veafSpawn-"
_CAP_PREFIX = "OnDemand-"
_PLACEHOLDER_PREFIX = "VEAF-placeholder-"
_INTERPRETER_MARKER = '#veafInterpreter["'
_CZ_UNIT_MARKERS = (
    "#command=",
    "#spawngroup=",
    "#spawnradius=",
    "#spawncount=",
    "#spawnchance=",
    "#spawndelay=",
)
_CAS_FIXED_NAMES = ("Red CAS Group", "Blue CAS Group")


def resolve_group_name(
    name: str,
    *,
    for_combat_zone: str | None = None,
    as_spawn_template: bool = False,
) -> str:
    """Derive a convention-correct group name from the caller's intent.

    A combat-zone member's name must start with the zone's name; a spawnable-aircraft template's
    name must start with ``veafSpawn-``. Both checks are idempotent — an already-correct name is
    returned unchanged.

    Args:
        name: The base name the caller proposes.
        for_combat_zone: If set, ensure the name starts with this combat-zone trigger-zone name
            (case-insensitive check, matching the runtime membership rule).
        as_spawn_template: If true, ensure the name starts with ``veafSpawn-``.

    Returns:
        The resolved name.
    """
    resolved = name
    if as_spawn_template and not resolved.startswith(_SPAWN_TEMPLATE_PREFIX):
        resolved = f"{_SPAWN_TEMPLATE_PREFIX}{resolved}"
    if for_combat_zone and not resolved.lower().startswith(for_combat_zone.lower()):
        resolved = f"{for_combat_zone}-{resolved}"
    return resolved


def validate_group_name(
    name: str,
    *,
    miz_path: Path | None = None,
    expected_combat_zone: str | None = None,
) -> dict[str, Any]:
    """Flag reserved VEAF naming conventions a proposed group name would trigger.

    Args:
        name: The proposed group name.
        miz_path: Optional mission `.miz`; if given, checks the name against the mission's trigger
            zones for the combat-zone capture trap (a group named ``<zone>...`` inside that zone is
            despawned at start).
        expected_combat_zone: A combat-zone name the caller *intends* to attach the group to —
            its capture match is suppressed (it's deliberate, not a warning).

    Returns:
        `{"warnings": [{"convention": <id>, "message": <str>, ["zone": <str>]}, ...]}`.
    """
    warnings: list[dict[str, Any]] = []

    def warn(convention: str, message: str, **extra: Any) -> None:
        warnings.append({"convention": convention, "message": message, **extra})

    if name.startswith(_SPAWN_TEMPLATE_PREFIX):
        warn("spawn_template", "Name starts with 'veafSpawn-' — will be registered as a spawnable-aircraft template.")
    if name.startswith(_CAP_PREFIX):
        warn("cap_template", "Name starts with 'OnDemand-' — reserved for CAP-mission templates.")
    if name.startswith(_PLACEHOLDER_PREFIX):
        warn("coalition_placeholder", "Name starts with 'VEAF-placeholder-' — reserved for build-injected groups.")
    if _INTERPRETER_MARKER in name:
        warn(
            "interpreter_command",
            "Name contains a #veafInterpreter[...] marker — the unit is destroyed and the command runs at start.",
        )
    if any(marker in name for marker in _CZ_UNIT_MARKERS):
        warn("combat_zone_unit_markers", "Name contains a combat-zone spawn marker (#command=/#spawn*=).")
    if name[:1] in ("[", "-"):
        warn(
            "qra_deploy_entry",
            "Name starts with '[' or '-' — would be read as a command, not a group name, if referenced in a QRA deploy list.",
        )
    if name in _CAS_FIXED_NAMES:
        warn("cas_runtime_group", f"'{name}' is a fixed runtime name used by the CAS mission module.")

    if miz_path is not None:
        expected = (expected_combat_zone or "").lower()
        for zone in _trigger_zone_names(miz_path):
            if zone.lower() == expected:
                continue
            if name.lower().startswith(zone.lower()):
                warn(
                    "combat_zone_capture",
                    f"Name starts with trigger-zone '{zone}' — if that zone backs a combat zone and "
                    f"the group sits inside it, the group is captured and despawned at start.",
                    zone=zone,
                )

    return {"warnings": warnings}


def _trigger_zone_names(miz_path: Path) -> list[str]:
    """Return the names of the mission's trigger zones (empty if unreadable)."""
    try:
        content = read_miz(miz_path).mission_content
    except (OSError, ValueError):
        return []
    if not isinstance(content, dict):
        return []
    zones = content.get("triggers", {}).get("zones", [])
    values = zones.values() if isinstance(zones, dict) else zones
    return [z["name"] for z in values if isinstance(z, dict) and "name" in z]
