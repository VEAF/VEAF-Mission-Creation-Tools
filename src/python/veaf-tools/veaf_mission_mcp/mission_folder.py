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
from mission_tools.miz_tools import DcsMission, read_mission_folder, write_mission_folder


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
