"""`veaf-build terrain-data` publishes the swept grids as the `terrain-data` release (FEAT-TERRAIN-DATA-DOWNLOAD)."""

from __future__ import annotations

import json
import subprocess
from array import array
from pathlib import Path

import pytest
from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.terrain_elevation import ElevationGrid, save_grid

from veaf_build import terrain_data_publish as publish


def _grid(directory: Path, theatre: str, file_name: str | None = None) -> Path:
    path = directory / (file_name or f"{theatre}.terrain")
    save_grid(ElevationGrid(theatre, GridSpec(0.0, 0.0, 100.0, 2, 2), array("h", [1, 2, 3, 4])), path)
    return path


class _Gh:
    """Records the `gh` calls; `release view` answers whether the release exists."""

    def __init__(self, exists: bool) -> None:
        self.exists = exists
        self.calls: list[list[str]] = []

    def __call__(self, args: list[str], **kwargs: object) -> subprocess.CompletedProcess:  # noqa: ARG002
        self.calls.append(args)
        code = 0 if args[:3] != ["gh", "release", "view"] or self.exists else 1
        return subprocess.CompletedProcess(args, code)


def test_the_plan_lists_the_grids_and_writes_the_manifest(tmp_path: Path) -> None:
    grids = tmp_path / "terrain"
    _grid(grids, "Syria")
    _grid(grids, "Normandy")
    (grids / "sweep-Syria").mkdir()

    files, manifest_path = publish.prepare(grids, tmp_path / "dist")

    assert [f.name for f in files] == ["Normandy.terrain", "Syria.terrain"]
    assert sorted(json.loads(manifest_path.read_text(encoding="utf-8"))["grids"]) == ["Normandy", "Syria"]


def test_a_folder_with_no_grid_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="no .terrain"):
        publish.prepare(tmp_path, tmp_path / "dist")


def test_a_missing_release_is_created_not_latest_then_grids_before_manifest(tmp_path: Path) -> None:
    files = [_grid(tmp_path, "Syria")]
    manifest = tmp_path / "terrain-data.json"
    manifest.write_text("{}", encoding="utf-8")
    gh = _Gh(exists=False)

    publish.publish(files, manifest, run=gh)

    create = next(c for c in gh.calls if c[:3] == ["gh", "release", "create"])
    assert "terrain-data" in create and "--latest=false" in create
    uploads = [c for c in gh.calls if c[:3] == ["gh", "release", "upload"]]
    assert [Path(a).name for a in uploads[0] if a.endswith(".terrain")] == ["Syria.terrain"]
    assert uploads[-1][4] == str(manifest), "the manifest goes last, once the grids it names are there"
    assert all("--clobber" in c for c in uploads)


def test_an_existing_release_is_not_created_again(tmp_path: Path) -> None:
    gh = _Gh(exists=True)
    manifest = tmp_path / "terrain-data.json"
    manifest.write_text("{}", encoding="utf-8")

    publish.publish([_grid(tmp_path, "Syria")], manifest, run=gh)

    assert not [c for c in gh.calls if c[:3] == ["gh", "release", "create"]]
