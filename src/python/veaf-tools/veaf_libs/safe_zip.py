"""Safe extraction of untrusted ZIP archives (Zip Slip + zip-bomb hardening).

`.miz` mission files and the updater's `published.zip` are untrusted archives.
``safe_extract_all`` validates every member before writing anything to disk:

- **Zip Slip** (SECREV-004): a member whose path is absolute or escapes the
  destination via ``..`` is rejected, so an archive cannot overwrite files
  outside the extraction directory.
- **Zip bomb** (SECREV-005): the number of entries and the total declared
  uncompressed size are capped before extraction starts.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

# Caps applied before extracting an untrusted archive.
MAX_ARCHIVE_ENTRIES = 100_000
MAX_ARCHIVE_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024  # 2 GiB


def safe_extract_all(
    zip_ref: zipfile.ZipFile,
    dest_path: str | Path,
    *,
    max_entries: int = MAX_ARCHIVE_ENTRIES,
    max_total_bytes: int = MAX_ARCHIVE_UNCOMPRESSED_BYTES,
) -> None:
    """Validate every member, then extract the archive to ``dest_path``.

    Args:
        zip_ref: An open ``ZipFile`` to extract.
        dest_path: Destination directory.
        max_entries: Maximum number of archive members allowed.
        max_total_bytes: Maximum total declared uncompressed size allowed.

    Raises:
        ValueError: If the archive exceeds a cap or contains an unsafe path.
    """
    dest = Path(dest_path).resolve()
    infos = zip_ref.infolist()

    if len(infos) > max_entries:
        raise ValueError(f"archive has too many entries ({len(infos)} > {max_entries})")

    total = 0
    for info in infos:
        total += info.file_size
        if total > max_total_bytes:
            raise ValueError(f"archive uncompressed size exceeds the {max_total_bytes}-byte limit")
        target = (dest / info.filename).resolve()
        if target != dest and dest not in target.parents:
            raise ValueError(f"unsafe archive entry escapes destination: {info.filename!r}")

    zip_ref.extractall(dest)
