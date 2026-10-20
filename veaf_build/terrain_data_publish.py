"""Publish the swept elevation grids as the ``terrain-data`` release (FEAT-TERRAIN-DATA-DOWNLOAD).

veaf-tools downloads a theatre's grid from that release when the workstation has none
(``veaf_libs.terrain_data``). The release is separate from the tools' releases and created **not
latest**, so GitHub's page keeps showing the tools; its assets are replaced in place (``--clobber``).
See ``doc/developer/terrain-data.md``.
"""

from __future__ import annotations

import json
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import Any

from veaf_libs.terrain_data import MANIFEST_NAME, RELEASE_TAG, build_manifest  # type: ignore[import-not-found]

REPOSITORY = "VEAF/VEAF-Mission-Creation-Tools"

Runner = Callable[..., subprocess.CompletedProcess]


def prepare(grid_dir: Path, out_dir: Path) -> tuple[list[Path], Path]:
    """Check every grid of a folder and write the manifest describing them.

    Args:
        grid_dir: The folder holding the ``<Theatre>.terrain`` files (sweep folders are ignored).
        out_dir: Where ``terrain-data.json`` is written.

    Returns:
        The grids, sorted, and the manifest's path.

    Raises:
        ValueError: If the folder holds no grid, or a grid fails :func:`build_manifest`'s checks.
    """
    files = sorted(grid_dir.glob("*.terrain"))
    if not files:
        raise ValueError(f"no .terrain file in {grid_dir}")
    manifest = build_manifest(files)
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return files, manifest_path


def publish(files: list[Path], manifest_path: Path, run: Runner = subprocess.run) -> None:
    """Create the release when missing, then upload the grids and, last, the manifest.

    The manifest goes last so it never names a grid not uploaded yet.

    Args:
        files: The grids.
        manifest_path: The manifest written by :func:`prepare`.
        run: ``subprocess.run``, or a test double.

    Raises:
        subprocess.CalledProcessError: If a ``gh`` command fails.
    """
    repo = ["--repo", REPOSITORY]
    exists = run(["gh", "release", "view", RELEASE_TAG, *repo], capture_output=True).returncode == 0
    if not exists:
        run(
            [
                "gh",
                "release",
                "create",
                RELEASE_TAG,
                *repo,
                "--latest=false",
                "--title",
                "Terrain data",
                "--notes",
                "Ground elevation grids swept in DCS, downloaded by veaf-tools when a theatre has none. "
                "Not a tools release.",
            ],
            check=True,
        )
    run(["gh", "release", "upload", RELEASE_TAG, *[str(f) for f in files], *repo, "--clobber"], check=True)
    run(["gh", "release", "upload", RELEASE_TAG, str(manifest_path), *repo, "--clobber"], check=True)


def describe(manifest_path: Path) -> list[dict[str, Any]]:
    """Return one row per grid of a manifest, for the summary table.

    Args:
        manifest_path: The manifest.

    Returns:
        ``{"theatre", "file", "bytes"}`` per grid, in the manifest's order.
    """
    grids = json.loads(manifest_path.read_text(encoding="utf-8"))["grids"]
    return [{"theatre": name, "file": entry["file"], "bytes": entry["bytes"]} for name, entry in grids.items()]
