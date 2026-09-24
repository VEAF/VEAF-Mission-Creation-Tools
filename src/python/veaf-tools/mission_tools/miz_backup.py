"""Timestamped backup of a mission file before an in-place mutating write.

Pure safety net for the mission-editing MCP's editor-parity actions (see
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md``); git remains the actual long-term undo.

**Where the copies go.** A file inside a mission folder is backed up to that folder's
``.veaf-backups/``, not next to itself. They used to land beside the file — 45 to 51 copies of
``src/mission/mission`` in one GermanyCW-v6 session, in the directory the build packs and the
mission maker commits (FIX-SCRATCH-MISSION-FINDINGS ticket 08). The directory carries its own
``.gitignore`` so the copies never follow a commit, and only the most recent
:data:`MAX_BACKUPS_PER_FILE` of each file are kept. A ``.miz`` outside any mission folder keeps its
sibling backup: there is no folder to put it in.
"""

import re
import shutil
from datetime import datetime
from pathlib import Path

_TIMESTAMP_FORMAT = "%Y%m%d-%H%M%S"

#: The folder-level directory backups go to.
BACKUP_DIR_NAME = ".veaf-backups"

#: How many backups of one file a mission folder keeps; older ones are deleted.
MAX_BACKUPS_PER_FILE = 20

#: How far up from a file to look for the ``mission.yaml`` that marks a mission folder's root
#: (``src/mission/mission`` is two levels below it).
_MAX_FOLDER_DEPTH = 4


def backup_before_write(miz_file_path: Path, *, now: datetime | None = None) -> Path:
    """Copy `miz_file_path` to a timestamped backup before it gets overwritten.

    An LLM driving several editor-parity actions in a row can easily call this twice
    within the same second, so a same-second collision is disambiguated with a `-2`,
    `-3`, ... suffix rather than raised — every call must still produce a backup.

    Args:
        miz_file_path: The file about to be mutated in place (a `.miz`, a folder's `mission`,
            `warehouses` or `mission.yaml`).
        now: Clock to timestamp the backup with. Defaults to the current time; only
            overridden by tests.

    Returns:
        The backup file's path (e.g. `mission.miz` -> `mission.20260712-143012.miz`, or
        `mission.20260712-143012-2.miz` on a same-second collision) — in the mission folder's
        `.veaf-backups/`, or next to the file when it belongs to no mission folder.
    """
    folder = _mission_folder_of(miz_file_path)
    backup_dir = miz_file_path.parent if folder is None else _backup_dir(folder)
    timestamp = (now or datetime.now()).strftime(_TIMESTAMP_FORMAT)
    base_name = f"{miz_file_path.stem}.{timestamp}"
    backup_path = backup_dir / f"{base_name}{miz_file_path.suffix}"
    suffix = 2
    while backup_path.exists():
        backup_path = backup_dir / f"{base_name}-{suffix}{miz_file_path.suffix}"
        suffix += 1
    shutil.copy2(miz_file_path, backup_path)
    if folder is not None:
        _prune(backup_dir, miz_file_path)
    return backup_path


def _mission_folder_of(path: Path) -> Path | None:
    """Return the mission folder `path` belongs to — the nearest ancestor holding a `mission.yaml`."""
    for candidate in list(path.resolve().parents)[:_MAX_FOLDER_DEPTH]:
        if (candidate / "mission.yaml").is_file():
            return candidate
    return None


def _backup_dir(folder: Path) -> Path:
    """Return the folder's backup directory, created with a `.gitignore` that ignores it whole."""
    backup_dir = folder / BACKUP_DIR_NAME
    backup_dir.mkdir(exist_ok=True)
    ignore = backup_dir / ".gitignore"
    if not ignore.exists():
        ignore.write_text("*\n", encoding="utf-8", newline="\n")
    return backup_dir


def _prune(backup_dir: Path, source: Path) -> None:
    """Delete all but the newest :data:`MAX_BACKUPS_PER_FILE` backups of `source` in `backup_dir`.

    Matched on the exact ``<stem>.<timestamp>[-n]<suffix>`` shape, so the backups of `mission`
    and of `mission.yaml` are counted apart. The timestamp sorts chronologically as text.
    """
    pattern = re.compile(rf"^{re.escape(source.stem)}\.(\d{{8}}-\d{{6}})(?:-(\d+))?{re.escape(source.suffix)}$")
    backups: list[tuple[str, int, Path]] = []
    for path in backup_dir.iterdir():
        match = pattern.match(path.name)
        if match:
            backups.append((match.group(1), int(match.group(2) or 1), path))
    backups.sort()
    for _, _, path in backups[:-MAX_BACKUPS_PER_FILE]:
        path.unlink()
