"""Elevation grids published on GitHub, downloaded when a theatre has none (FEAT-TERRAIN-DATA-DOWNLOAD).

A grid is swept in DCS (``veaf-tools dcs terrain-sweep``); a PC with no DCS open — a demo sandbox, another
mission maker's — has none. So the grids swept by the maintainers are published as the assets of a
GitHub release of their own, tag :data:`RELEASE_TAG`, separate from the tools' releases so some 26 MB
is not re-published with every version (David, 2026-10-20), with a manifest giving each one's size and
SHA-256.

A missing theatre is downloaded on first use into the VEAF home, next to the grids swept there, and
kept: it is never replaced, by a newer publication or otherwise. Delete the file to fetch it again.
"""

from __future__ import annotations

import hashlib
import json
import os
import tempfile
from functools import cache
from pathlib import Path
from typing import Any

import requests

from veaf_libs.atomic_replace import atomic_replace
from veaf_libs.github_download import GithubDownloadError, fetch_github_asset
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.terrain_elevation import grid_file_name, load_grid

RELEASE_TAG = "terrain-data"
MANIFEST_NAME = "terrain-data.json"
MANIFEST_FORMAT = 1
#: Release assets are served from this URL with no GitHub API call, so the API's 60 requests an hour
#: allowed with no token do not apply.
DOWNLOAD_URL = f"https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/{RELEASE_TAG}/"

_MAX_MANIFEST_BYTES = 1024 * 1024
#: The largest grid is PersianGulf, 10.0 MB at 250 m (measured 2026-10-20).
_MAX_GRID_BYTES = 64 * 1024 * 1024
#: Seconds to wait for a connection or the next bytes: offline, an answer must come quickly.
_TIMEOUT_SECONDS = 15.0

#: The theatres a download was tried for in this process: a failure is not retried at every placement.
_attempted: set[str] = set()


def build_manifest(paths: list[Path]) -> dict[str, Any]:
    """Describe grids for publication, after checking each one loads as the theatre it is named after.

    Args:
        paths: The ``<Theatre>.terrain`` files.

    Returns:
        ``{"format": 1, "grids": {theatre: {"file", "bytes", "sha256"}}}``.

    Raises:
        ValueError: If a file is not a grid, or holds another theatre than its name says.
    """
    grids: dict[str, dict[str, Any]] = {}
    for path in sorted(paths):
        theatre = load_grid(path).theatre
        if path.name != grid_file_name(theatre):
            raise ValueError(f"{path.name} holds the grid of {theatre}, expected {grid_file_name(theatre)}")
        data = path.read_bytes()
        grids[theatre] = {"file": path.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    return {"format": MANIFEST_FORMAT, "grids": grids}


@cache
def _published() -> dict[str, Any] | None:
    """Return the published grids, from the release's manifest; ``None`` when it cannot be read."""
    try:
        manifest = json.loads(
            fetch_github_asset(DOWNLOAD_URL + MANIFEST_NAME, max_bytes=_MAX_MANIFEST_BYTES, timeout=_TIMEOUT_SECONDS)
        )
    except (requests.RequestException, GithubDownloadError, ValueError) as e:
        logger.warning(t("terrain_data.no_manifest", url=DOWNLOAD_URL + MANIFEST_NAME, error=e), no_console=True)
        return None
    if not isinstance(manifest, dict) or manifest.get("format") != MANIFEST_FORMAT:
        logger.warning(t("terrain_data.bad_manifest", url=DOWNLOAD_URL + MANIFEST_NAME), no_console=True)
        return None
    grids = manifest.get("grids")
    return grids if isinstance(grids, dict) else None


def forget_attempts() -> None:
    """Forget the downloads tried and the manifest read, so the next call tries again (tests)."""
    _attempted.clear()
    _published.cache_clear()


def download_grid(theatre: str, target: Path) -> bool:
    """Download a theatre's published grid to ``target``, once per process.

    Written only once its size and SHA-256 match the manifest and it loads as that theatre's grid.

    Args:
        theatre: The theatre, as DCS spells it.
        target: Where the grid goes.

    Returns:
        Whether the grid is now at ``target``. ``False`` offline, when the theatre is not published,
        when a check fails, or when it was already tried in this process.
    """
    if theatre in _attempted:
        return False
    _attempted.add(theatre)
    published = _published()
    entry = published.get(theatre) if published else None
    if not isinstance(entry, dict):
        return False
    temporary: str | None = None
    try:
        if entry.get("file") != grid_file_name(theatre):
            raise ValueError(f"the manifest names {entry.get('file')!r} for {theatre}")
        size = int(entry["bytes"])
        data = fetch_github_asset(
            DOWNLOAD_URL + grid_file_name(theatre), max_bytes=min(size, _MAX_GRID_BYTES), timeout=_TIMEOUT_SECONDS
        )
        if len(data) != size or hashlib.sha256(data).hexdigest() != entry.get("sha256"):
            raise ValueError("size or SHA-256 differs from the manifest")
        target.parent.mkdir(parents=True, exist_ok=True)
        handle, temporary = tempfile.mkstemp(dir=target.parent, prefix=f"{theatre}.", suffix=".part")
        with os.fdopen(handle, "wb") as out:
            out.write(data)
        loaded = load_grid(Path(temporary)).theatre
        if loaded != theatre:
            raise ValueError(f"the file holds the grid of {loaded}")
        if target.exists():
            # Swept on the workstation while this downloaded: the local grid wins.
            return True
        atomic_replace(temporary, target)
        temporary = None
    except (requests.RequestException, GithubDownloadError, ValueError, KeyError, TypeError, OSError) as e:
        logger.warning(t("terrain_data.not_downloaded", theatre=theatre, error=e), no_console=True)
        return False
    finally:
        if temporary is not None:
            Path(temporary).unlink(missing_ok=True)
    logger.info(t("terrain_data.downloaded", theatre=theatre, path=target), no_console=True)
    return True
