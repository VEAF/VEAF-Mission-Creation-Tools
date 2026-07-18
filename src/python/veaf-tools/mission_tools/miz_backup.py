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

    An LLM driving several editor-parity actions in a row can easily call this twice
    within the same second, so a same-second collision is disambiguated with a `-2`,
    `-3`, ... suffix rather than raised — every call must still produce a backup.

    Args:
        miz_file_path: The `.miz` file about to be mutated in place.
        now: Clock to timestamp the backup with. Defaults to the current time; only
            overridden by tests.

    Returns:
        The backup file's path (e.g. `mission.miz` -> `mission.20260712-143012.miz`,
        or `mission.20260712-143012-2.miz` on a same-second collision; same directory).
    """
    timestamp = (now or datetime.now()).strftime(_TIMESTAMP_FORMAT)
    base_name = f"{miz_file_path.stem}.{timestamp}"
    backup_path = miz_file_path.with_name(f"{base_name}{miz_file_path.suffix}")
    suffix = 2
    while backup_path.exists():
        backup_path = miz_file_path.with_name(f"{base_name}-{suffix}{miz_file_path.suffix}")
        suffix += 1
    shutil.copy2(miz_file_path, backup_path)
    return backup_path
