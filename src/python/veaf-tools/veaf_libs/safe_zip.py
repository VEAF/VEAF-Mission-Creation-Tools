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
from collections.abc import Container
from pathlib import Path

# Caps applied before extracting an untrusted archive.
MAX_ARCHIVE_ENTRIES = 100_000
MAX_ARCHIVE_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024  # 2 GiB

#: Cap for a single member read straight into memory (``read_miz`` and friends).
#: Deliberately far smaller than the on-disk cap: a `mission` file is a Lua table, and the
#: largest real ones seen in this project are tens of megabytes, so 256 MiB is generous
#: while still bounding what an untrusted `.miz` can make us allocate.
MAX_MEMBER_UNCOMPRESSED_BYTES = 256 * 1024 * 1024  # 256 MiB

_CHUNK_SIZE = 64 * 1024


def safe_extract_all(
    zip_ref: zipfile.ZipFile,
    dest_path: str | Path,
    *,
    max_entries: int = MAX_ARCHIVE_ENTRIES,
    max_total_bytes: int = MAX_ARCHIVE_UNCOMPRESSED_BYTES,
    members: Container[str] | None = None,
) -> None:
    """Validate every member, then extract the archive to ``dest_path``.

    Args:
        zip_ref: An open ``ZipFile`` to extract.
        dest_path: Destination directory.
        max_entries: Maximum number of archive members allowed.
        max_total_bytes: Maximum total uncompressed size allowed (checked on the
            declared sizes up front, and re-enforced on the actual decompressed
            bytes while extracting).
        members: When provided, only members whose filename is in this container are
            written to disk. The **whole** archive is still validated (caps, Zip Slip,
            symlinks) regardless, so a selective extraction never weakens the hardening.

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
        if members is not None and info.filename not in members:
            continue
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


def safe_read_member(
    zip_ref: zipfile.ZipFile,
    name: str,
    *,
    max_bytes: int = MAX_MEMBER_UNCOMPRESSED_BYTES,
) -> bytes:
    """Read one archive member into memory, refusing anything over ``max_bytes``.

    ``safe_extract_all`` protects the disk; this protects memory. ``read_miz`` pulls
    ``mission``, ``options``, ``warehouses`` and friends in with a bare
    ``zip_file.open(name).read()``, so a small archive declaring — or streaming — a huge
    member could exhaust RAM without ever writing a file (VMR-009).

    Both the declared size and the real stream are checked. The header check refuses
    cheaply, before allocating; the streaming check is what actually holds, because
    ``ZipInfo.file_size`` comes from the archive and can be spoofed.

    Args:
        zip_ref: An open ``ZipFile``.
        name: Member to read.
        max_bytes: Maximum uncompressed size accepted for this member.

    Returns:
        The member's uncompressed bytes.

    Raises:
        KeyError: If the member is not in the archive. Absence is not a cap violation,
            and callers already distinguish the two (a `.miz` legitimately lacks members).
        ValueError: If the member exceeds ``max_bytes``, by header or by stream.
    """
    info = zip_ref.getinfo(name)  # raises KeyError when absent
    if info.file_size > max_bytes:
        raise ValueError(
            f"archive member {name!r} declares {info.file_size} bytes, which exceeds the {max_bytes}-byte limit"
        )

    chunks: list[bytes] = []
    total = 0
    with zip_ref.open(info) as member:
        while chunk := member.read(_CHUNK_SIZE):
            total += len(chunk)
            if total > max_bytes:
                raise ValueError(f"archive member {name!r} decompresses past the {max_bytes}-byte limit")
            chunks.append(chunk)
    return b"".join(chunks)
