"""Timestamped backup of a `.miz` before an in-place mutating write.

Pure safety net for the mission-editing MCP's editor-parity actions (see
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md``): no retention or cleanup policy, git
remains the actual long-term undo.
"""

import shutil
from datetime import datetime
from pathlib import Path

_TIMESTAMP_FORMAT = "%Y%m%d-%H%M%S"


def backup_before_write(miz_file_path: Path, *, now: datetime | None = None) -> Path:
    """Copy `miz_file_path` to a timestamped sibling before it gets overwritten.

    Args:
        miz_file_path: The `.miz` file about to be mutated in place.
        now: Clock to timestamp the backup with. Defaults to the current time; only
            overridden by tests.

    Returns:
        The backup file's path (e.g. `mission.miz` -> `mission.20260712-143012.miz`,
        same directory).

    Raises:
        FileExistsError: If a backup for the same second already exists.
    """
    timestamp = (now or datetime.now()).strftime(_TIMESTAMP_FORMAT)
    backup_path = miz_file_path.with_name(f"{miz_file_path.stem}.{timestamp}{miz_file_path.suffix}")
    if backup_path.exists():
        raise FileExistsError(f"Backup already exists for this second: {backup_path}")
    shutil.copy2(miz_file_path, backup_path)
    return backup_path
