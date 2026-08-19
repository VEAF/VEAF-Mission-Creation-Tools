"""Mission-folder awareness for the composite builders (wave 8).

Composites edit the **durable source** of a mission folder — the exploded `src/mission/` (trigger
zones and groups) and `mission.yaml` (module config) — so a later `veaf-tools build` produces the
`.miz` (David's chosen model). This module wraps the folder's `.miz`-side read/save with a
timestamped backup, reusing the pure-Python `mission_tools` folder helpers (no Lua execution, no
zip). The `mission.yaml` side is handled by `edit_mission_yaml` / `mission_yaml_editor`.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import (
    DcsMission,
    read_mission_folder,
    read_miz,
    write_mission_folder,
    write_miz,
)


def _mission_file(folder_path: Path) -> Path:
    """Locate the folder's loose ``mission`` file (root or ``src/mission/``)."""
    for candidate in (folder_path, folder_path / "src" / "mission"):
        mission_file = candidate / "mission"
        if mission_file.is_file():
            return mission_file
    raise FileNotFoundError(f"No 'mission' file found under {folder_path} (looked in '.' and 'src/mission')")


def mission_yaml_path(folder_path: Path) -> Path:
    """Return the folder's ``mission.yaml`` path (the config side of the folder).

    Args:
        folder_path: The mission folder.

    Returns:
        Path to ``<folder>/mission.yaml``.

    Raises:
        FileNotFoundError: when the folder has no ``mission.yaml``.
    """
    path = folder_path / "mission.yaml"
    if not path.is_file():
        raise FileNotFoundError(f"No 'mission.yaml' in mission folder: {folder_path}")
    return path


def load_folder_mission(folder_path: Path) -> DcsMission:
    """Load a mission folder's exploded `.miz` side (`src/mission/`), no Lua executed.

    Args:
        folder_path: The mission folder (root or one containing ``src/mission/``).

    Returns:
        The parsed :class:`DcsMission`.

    Raises:
        FileNotFoundError: when no ``mission`` file can be located.
    """
    return read_mission_folder(folder_path)


def save_folder_mission(mission: DcsMission, folder_path: Path) -> dict[str, Any]:
    """Back up the folder's ``mission`` file, then write `mission`'s tables back to it.

    Args:
        mission: The (mutated) mission to persist.
        folder_path: The mission folder to write into.

    Returns:
        `{"mission_file": <path str>, "backup": <path str>}`.

    Raises:
        FileNotFoundError: when no ``mission`` file can be located.
        ValueError: when `mission.mission_content` is ``None``.
    """
    backup = backup_before_write(_mission_file(folder_path))
    written = write_mission_folder(mission, folder_path)
    return {"mission_file": str(written), "backup": str(backup)}


def open_mission(target: Path) -> tuple[DcsMission, dict[str, Any]]:
    """Read a mission from a `.miz` **or** a mission folder, whichever the caller pointed at.

    Args:
        target: A `.miz` archive, or a mission folder (root, or one holding ``src/mission/``).

    Returns:
        ``(mission, mission_content)``. The content is returned rather than left to the caller to
        fetch off the mission, because this function already refuses a mission without one — saying so
        in the signature spares every caller a re-check that only the type checker would read.

    Raises:
        ValueError: when the target is a directory that is not a mission folder, or a file that is
            not a readable mission — said in those words. Reading a folder as a zip raises
            ``[Errno 13] Permission denied``, which names neither the cause nor the fix.
    """
    if target.is_dir():
        try:
            mission = read_mission_folder(target)
        except FileNotFoundError as exc:
            raise ValueError(
                f"{target} is a directory but not a mission folder: no 'mission' file in it or in "
                "'src/mission'. Point at the mission folder itself, or at a .miz."
            ) from exc
    else:
        if not target.is_file():
            raise ValueError(f"No such mission: {target}")
        mission = read_miz(target)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {target}")
    return mission, mission.mission_content


def commit_mission(mission: DcsMission, target: Path) -> dict[str, Any]:
    """Write a mission back where it came from, backed up first.

    Args:
        mission: The (mutated) mission to persist.
        target: The same `.miz` or mission folder it was opened from.

    Returns:
        ``{"durable": <bool>}`` — true when the edit went into a folder's source, so it survives the
        next ``veaf-tools build``; false for a `.miz`, which the next build overwrites.
    """
    if target.is_dir():
        save_folder_mission(mission, target)
        return {"durable": True}
    backup_before_write(target)
    write_miz(mission, target)
    return {"durable": False}
