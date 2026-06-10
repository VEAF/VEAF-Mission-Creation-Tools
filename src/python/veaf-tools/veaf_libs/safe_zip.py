"""Safe extraction of untrusted ZIP archives (Zip Slip + zip-bomb hardening).

`.miz` mission files and the updater's `published.zip` are untrusted archives.
``safe_extract_all`` validates every member before writing anything to disk:

- **Zip Slip** (SECREV-004): a member whose path is absolute or escapes the
  destination via ``..`` is rejected, and symlink entries are rejected outright
  (a symlink + a path through it would bypass the lexical check).
- **Zip bomb** (SECREV-005): the number of entries and the total declared
  uncompressed size are capped before extraction starts, and the cap is also
  enforced on the **actual** decompressed byte count during extraction, so a
  spoofed size header cannot bypass it.
"""

from __future__ import annotations

import stat
import zipfile
from pathlib import Path

# Caps applied before extracting an untrusted archive.
MAX_ARCHIVE_ENTRIES = 100_000
MAX_ARCHIVE_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024  # 2 GiB

_CHUNK_SIZE = 64 * 1024


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
        max_total_bytes: Maximum total uncompressed size allowed (checked on the
            declared sizes up front, and re-enforced on the actual decompressed
            bytes while extracting).

    Raises:
        ValueError: If the archive exceeds a cap or contains an unsafe entry.
    """
    dest = Path(dest_path).resolve()
    infos = zip_ref.infolist()

    if len(infos) > max_entries:
        raise ValueError(f"archive has too many entries ({len(infos)} > {max_entries})")

    declared_total = 0
    for info in infos:
        declared_total += info.file_size
        if declared_total > max_total_bytes:
            raise ValueError(f"archive uncompressed size exceeds the {max_total_bytes}-byte limit")
        # Reject symlinks: extracting one would let a later member traverse it
        # and write outside dest while passing the lexical path check.
        if stat.S_ISLNK(info.external_attr >> 16):
            raise ValueError(f"unsafe archive entry is a symlink: {info.filename!r}")
        target = (dest / info.filename).resolve()
        if target != dest and dest not in target.parents:
            raise ValueError(f"unsafe archive entry escapes destination: {info.filename!r}")

    # Extract manually so the byte cap holds for the real decompressed stream
    # (ZipInfo.file_size comes from the header and can be spoofed).
    written_total = 0
    for info in infos:
        target = (dest / info.filename).resolve()
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with zip_ref.open(info) as member, open(target, "wb") as out:
            while chunk := member.read(_CHUNK_SIZE):
                written_total += len(chunk)
                if written_total > max_total_bytes:
                    out.close()
                    target.unlink(missing_ok=True)
                    raise ValueError(f"archive decompressed size exceeds the {max_total_bytes}-byte limit")
                out.write(chunk)
