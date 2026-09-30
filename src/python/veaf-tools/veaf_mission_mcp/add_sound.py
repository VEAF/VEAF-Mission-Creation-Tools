"""`add_sound` — embed a sound file in a mission, so a unit can transmit it.

A radio beacon is a unit whose route carries ``TransmitMessage``, and that task names its sound by a
**resource key**: the file sits in the archive's ``l10n/DEFAULT/`` and ``l10n/DEFAULT/mapResource``
maps the key to its name. Nothing wrote either, so the beacons of the GermanyCW-v6 mission were
copied by hand, ``mapResource`` included (FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 04).

The key is ``MCP_Sound_<stem>``: never ``VEAF_MapKey…``, which the build removes as its own.
"""

import shutil
from pathlib import Path
from typing import Any

import luadata
from mission_tools.mission_constants import DEFAULT_SCRIPTS_LOCATION
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import list_members, read_miz, write_miz

from veaf_mission_mcp.mission_folder import load_folder_mission

#: What DCS plays from a mission: the two formats the Mission Editor offers for a sound.
_SOUND_SUFFIXES: tuple[str, ...] = (".ogg", ".wav")


def add_sound(target: Path, *, source_path: str, resource_name: str | None = None) -> dict[str, Any]:
    """Copy a sound into a mission and declare it, backed up first.

    Args:
        target: The mission folder (durable, into ``src/mission/l10n/DEFAULT``) or a ``.miz``.
        source_path: The sound file to embed, ``.ogg`` or ``.wav``.
        resource_name: The file name inside the mission; the source's name when omitted.

    Returns:
        ``{"key", "file", "durable", "replaced"}`` — ``key`` is what ``edit_route``'s
        ``transmit_message`` takes; ``replaced`` says a file of that name was already there.

    Raises:
        ValueError: If the source is not a ``.ogg`` / ``.wav`` file, or the target is not a mission.
        FileNotFoundError: If the source does not exist.
    """
    source = Path(source_path)
    if not source.is_file():
        raise FileNotFoundError(f"Sound file not found: {source}")
    name = resource_name or source.name
    if Path(name).suffix.lower() not in _SOUND_SUFFIXES or Path(name).name != name:
        raise ValueError(f"a sound must be a plain .ogg or .wav file name, got {name!r}")

    is_folder = target.is_dir()
    mission = load_folder_mission(target) if is_folder else read_miz(target)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {target}")
    resources = dict(mission.map_resource_content or {})

    # A `VEAF_MapKey…` entry is the build's own and is removed by the next build: never hand it out.
    existing = [key for key, value in resources.items() if str(value) == name and not key.startswith("VEAF_MapKey")]
    key = existing[0] if existing else _free_key(resources, Path(name).stem)
    resources[key] = name
    serialized = "mapResource = \n" + luadata.serialize(
        resources, indent="  ", indent_level=0, always_provide_keyname=True, sort=True
    )

    if is_folder:
        l10n = _folder_l10n(target)
        l10n.mkdir(parents=True, exist_ok=True)
        destination = l10n / name
        replaced = destination.is_file()
        for path in (destination, l10n / "mapResource"):
            if path.is_file():
                backup_before_write(path)
        shutil.copyfile(source, destination)
        (l10n / "mapResource").write_text(serialized, encoding="utf-8", newline="\n")
    else:
        members = list_members(target)
        replaced = f"{DEFAULT_SCRIPTS_LOCATION}/{name}" in members
        mission.map_resource_content = resources
        additional_files = {f"{DEFAULT_SCRIPTS_LOCATION}/{name}": source.read_bytes()}
        # `write_miz` rewrites a `mapResource` member the archive already has; one it lacks has to be
        # supplied, or the key is lost — and supplying it when present would write it twice.
        if f"{DEFAULT_SCRIPTS_LOCATION}/mapResource" not in members:
            additional_files[f"{DEFAULT_SCRIPTS_LOCATION}/mapResource"] = serialized.encode()
        backup_before_write(target)
        write_miz(mission, target, additional_files=additional_files)
    return {"key": key, "file": name, "durable": is_folder, "replaced": replaced}


def _folder_l10n(folder: Path) -> Path:
    """Return the folder's ``l10n/DEFAULT`` beside its loose ``mission`` file."""
    for candidate in (folder / "src" / "mission", folder):
        if (candidate / "mission").is_file():
            return candidate / DEFAULT_SCRIPTS_LOCATION
    raise ValueError(f"{folder} is a directory but not a mission folder")


def _free_key(resources: dict[str, Any], stem: str) -> str:
    """Return ``MCP_Sound_<stem>``, suffixed until no resource uses it."""
    key = f"MCP_Sound_{stem}"
    suffix = 2
    while key in resources:
        key = f"MCP_Sound_{stem}_{suffix}"
        suffix += 1
    return key
