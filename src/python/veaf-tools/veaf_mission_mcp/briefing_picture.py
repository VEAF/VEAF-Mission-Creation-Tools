"""`set_briefing_picture` — embed an image and show it in a coalition's briefing.

A briefing picture is three things DCS keeps apart: the file in the archive's ``l10n/DEFAULT/``, a
resource key mapping to it in ``l10n/DEFAULT/mapResource``, and that key listed in the mission's
``pictureFileNameB`` (blue), ``pictureFileNameR`` (red) or ``pictureFileNameN`` (neutral). Nothing
wrote them, so the demo mission scripted all three (FIX-DEMO-MISSION-FINDINGS ticket 07).

The key is ``MCP_Picture_<stem>``: never ``VEAF_MapKey…``, which the build removes as its own.
"""

import shutil
from pathlib import Path
from typing import Any

import luadata
from mission_tools.mission_constants import DEFAULT_SCRIPTS_LOCATION
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import list_members, read_miz, write_miz

from veaf_mission_mcp.add_sound import _folder_l10n
from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission
from veaf_mission_mcp.mission_table import indexed

#: The image formats the Mission Editor offers for a briefing picture.
_PICTURE_SUFFIXES: tuple[str, ...] = (".png", ".jpg", ".jpeg")

#: The mission-table key holding each coalition's briefing pictures.
_SIDE_KEYS: dict[str, str] = {"blue": "pictureFileNameB", "red": "pictureFileNameR", "neutral": "pictureFileNameN"}


def set_briefing_picture(
    target: Path, *, source_path: str, side: str, resource_name: str | None = None
) -> dict[str, Any]:
    """Copy an image into a mission and add it to a coalition's briefing, backed up first.

    Args:
        target: The mission folder (durable, into ``src/mission/``) or a ``.miz``.
        source_path: The image to embed, ``.png`` or ``.jpg``.
        side: ``blue``, ``red`` or ``neutral`` — whose briefing shows it.
        resource_name: The file name inside the mission; the source's name when omitted.

    Returns:
        ``{"key", "file", "side", "pictures", "durable", "replaced"}`` — ``pictures`` is the side's
        resource keys after the change, in display order; ``replaced`` says a file of that name was
        already in the mission.

    Raises:
        ValueError: If the side is unknown, the file is not a ``.png`` / ``.jpg``, or the target is not
            a mission.
        FileNotFoundError: If the source does not exist.
    """
    if side not in _SIDE_KEYS:
        raise ValueError(f"unknown side {side!r}; expected one of {', '.join(_SIDE_KEYS)}")
    source = Path(source_path)
    if not source.is_file():
        raise FileNotFoundError(f"Picture not found: {source}")
    name = resource_name or source.name
    if Path(name).suffix.lower() not in _PICTURE_SUFFIXES or Path(name).name != name:
        raise ValueError(f"a briefing picture must be a plain .png or .jpg file name, got {name!r}")

    is_folder = target.is_dir()
    mission = load_folder_mission(target) if is_folder else read_miz(target)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {target}")
    resources = dict(mission.map_resource_content or {})

    # A `VEAF_MapKey…` entry is the build's own and is removed by the next build: never hand it out.
    existing = [key for key, value in resources.items() if str(value) == name and not key.startswith("VEAF_MapKey")]
    key = existing[0] if existing else _free_key(resources, Path(name).stem)
    resources[key] = name
    mission.map_resource_content = resources

    pictures = [str(entry) for entry in indexed(content.get(_SIDE_KEYS[side]))]
    if key not in pictures:
        pictures.append(key)
    content[_SIDE_KEYS[side]] = pictures

    if is_folder:
        l10n = _folder_l10n(target)
        l10n.mkdir(parents=True, exist_ok=True)
        destination = l10n / name
        replaced = destination.is_file()
        if replaced:
            backup_before_write(destination)
        shutil.copyfile(source, destination)
        save_folder_mission(mission, target)
    else:
        members = list_members(target)
        replaced = f"{DEFAULT_SCRIPTS_LOCATION}/{name}" in members
        additional_files = {f"{DEFAULT_SCRIPTS_LOCATION}/{name}": source.read_bytes()}
        # `write_miz` rewrites a `mapResource` member the archive already has; one it lacks has to be
        # supplied, as `add_sound` does.
        if f"{DEFAULT_SCRIPTS_LOCATION}/mapResource" not in members:
            additional_files[f"{DEFAULT_SCRIPTS_LOCATION}/mapResource"] = (
                "mapResource = \n"
                + luadata.serialize(resources, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)
            ).encode()
        backup_before_write(target)
        write_miz(mission, target, additional_files=additional_files)
    return {"key": key, "file": name, "side": side, "pictures": pictures, "durable": is_folder, "replaced": replaced}


def _free_key(resources: dict[str, Any], stem: str) -> str:
    """Return ``MCP_Picture_<stem>``, suffixed until no resource uses it."""
    key = f"MCP_Picture_{stem}"
    suffix = 2
    while key in resources:
        key = f"MCP_Picture_{stem}_{suffix}"
        suffix += 1
    return key
