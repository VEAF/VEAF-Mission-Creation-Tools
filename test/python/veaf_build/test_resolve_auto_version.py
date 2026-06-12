"""Auto-computed release build number (BUILD-AUTOVERSION-001).

`resolve_auto_version` derives `X.Y.Z.BUILD` from the project base (pyproject) and
the previously published.zip version: same base → increment build number;
different base (or no published.zip) → build number 1.
"""

from __future__ import annotations

import json
import zipfile
from pathlib import Path

from veaf_build.worker import BuildAndReleaseWorker


def _worker(tmp_path: Path) -> BuildAndReleaseWorker:
    return BuildAndReleaseWorker(output_path=tmp_path)


def _write_published(tmp_path: Path, version: str) -> None:
    with zipfile.ZipFile(tmp_path / "published.zip", "w") as zf:
        zf.writestr("veaf-version.json", json.dumps({"version": version}))


def test_no_published_zip_starts_at_build_1(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    base = worker.get_version_from_file()
    assert worker.resolve_auto_version() == f"{base}.1"


def test_same_base_increments_build_number(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    base = worker.get_version_from_file()
    _write_published(tmp_path, f"{base}.3")
    assert worker.resolve_auto_version() == f"{base}.4"


def test_different_base_resets_to_build_1(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    base = worker.get_version_from_file()
    _write_published(tmp_path, "0.0.1.99")  # unrelated base
    assert worker.resolve_auto_version() == f"{base}.1"


def test_published_without_build_number_resets_to_1(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    base = worker.get_version_from_file()
    _write_published(tmp_path, base)  # no build segment
    assert worker.resolve_auto_version() == f"{base}.1"
