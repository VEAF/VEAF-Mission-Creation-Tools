"""Resolve a mission-command input: a `.miz`, or a release archive holding one.

Third-party missions are increasingly distributed as a **release zip** rather than a bare
`.miz` — Lekaa's Foothold assets bundle the mission with a config-manager executable, the
manual and a shortcut. `resolve_input_miz` lets a command take either, so the user can pass
the file they downloaded instead of unzipping by hand first.

Only the `.miz` member is ever written to disk (never the bundled executable), into a short
temporary directory removed on the way out.
"""

from __future__ import annotations

import shutil
import tempfile
import zipfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from veaf_libs.safe_zip import safe_extract_all

#: Suffix of a DCS mission file.
MIZ_SUFFIX = ".miz"

#: Suffix of a release archive that may contain one.
ARCHIVE_SUFFIX = ".zip"

#: Prefix of the temporary extraction directory. Deliberately short: Foothold's asset
#: names are long and Windows caps full paths (see FIX-LONG-FILENAMES-WINDOWS).
_TEMP_PREFIX = "veafmiz"


class AmbiguousMissionInput(Exception):
    """An archive did not yield exactly one `.miz`.

    Attributes:
        archive: The archive that was inspected.
        candidates: The `.miz` members found, sorted. Empty when the archive holds none;
            two or more when it is ambiguous — the caller renders the message, since
            "none" and "which one?" read differently to the user.
    """

    def __init__(self, archive: Path, candidates: tuple[str, ...]) -> None:
        self.archive = archive
        self.candidates = candidates
        super().__init__(f"{archive} contains {len(candidates)} .miz members")


def _miz_members(zip_ref: zipfile.ZipFile) -> tuple[str, ...]:
    """Return the archive's `.miz` member names, sorted (directories excluded)."""
    return tuple(sorted(info.filename for info in zip_ref.infolist() if not info.is_dir() and _is_miz(info.filename)))


def _is_miz(name: str) -> bool:
    """Whether *name* looks like a `.miz` file (case-insensitive)."""
    return name.lower().endswith(MIZ_SUFFIX)


def is_archive(path: Path) -> bool:
    """Whether *path* is a release archive rather than a `.miz` (by suffix, case-insensitive)."""
    return path.suffix.lower() == ARCHIVE_SUFFIX


@contextmanager
def resolve_input_miz(path: Path) -> Iterator[Path]:
    """Yield a usable `.miz` path for *path*.

    A `.miz` is yielded as-is. A `.zip` is opened, its single `.miz` member extracted to a
    temporary directory (and only that member — the bundled executable and manual are
    ignored), and the extracted copy is removed when the context exits, on success or on
    error. The user's own file is never deleted.

    Args:
        path: The `.miz` or `.zip` the user passed.

    Yields:
        The path of a `.miz` to read.

    Raises:
        AmbiguousMissionInput: If *path* is an archive holding no `.miz`, or more than one.
        ValueError: If the archive fails the `safe_zip` hardening checks.
    """
    if not is_archive(path):
        yield path
        return

    with zipfile.ZipFile(path) as zip_ref:
        members = _miz_members(zip_ref)
        if len(members) != 1:
            raise AmbiguousMissionInput(path, members)
        member = members[0]
        temp_dir = Path(tempfile.mkdtemp(prefix=_TEMP_PREFIX))
        try:
            safe_extract_all(zip_ref, temp_dir, members={member})
            yield temp_dir / member
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)
