"""A theatre with no local grid is downloaded from the `terrain-data` release (FEAT-TERRAIN-DATA-DOWNLOAD)."""

from __future__ import annotations

import hashlib
import json
from array import array
from pathlib import Path

import pytest
import requests
from veaf_libs import terrain_data
from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.terrain_data import DOWNLOAD_URL, MANIFEST_NAME, build_manifest
from veaf_libs.terrain_elevation import ElevationGrid, grid_for_theatre, save_grid

# Bound at import, before the autouse fixture of conftest.py swaps the module attribute out: these tests
# are the ones that exercise the real download.
from veaf_libs.terrain_data import download_grid as real_download_grid  # isort: skip


def _grid_bytes(tmp_path: Path, theatre: str) -> bytes:
    path = tmp_path / "src" / f"{theatre}.terrain"
    save_grid(ElevationGrid(theatre, GridSpec(0.0, 0.0, 100.0, 3, 3), array("h", range(9))), path)
    return path.read_bytes()


def _manifest(entries: dict[str, bytes]) -> bytes:
    return json.dumps(
        {
            "format": 1,
            "grids": {
                name: {"file": f"{name}.terrain", "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                for name, data in entries.items()
            },
        }
    ).encode()


@pytest.fixture
def release(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> dict[str, object]:
    """A fake release: maps asset name to bytes, or to an exception to raise; records the requests."""
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    monkeypatch.setattr(terrain_data, "download_grid", real_download_grid)
    terrain_data.forget_attempts()
    assets: dict[str, object] = {"requested": []}

    def fake_fetch(url: str, *, max_bytes: int, headers: dict | None = None, timeout: float | None = None) -> bytes:  # noqa: ARG001
        assert url.startswith(DOWNLOAD_URL)
        name = url[len(DOWNLOAD_URL) :]
        assets["requested"].append(name)  # type: ignore[attr-defined]
        answer = assets.get(name)
        if isinstance(answer, Exception):
            raise answer
        if answer is None:
            raise requests.ConnectionError("no such asset")
        assert len(answer) <= max_bytes  # type: ignore[arg-type]
        return answer  # type: ignore[return-value]

    monkeypatch.setattr(terrain_data, "fetch_github_asset", fake_fetch)
    yield assets
    terrain_data.forget_attempts()


def _home_grid(tmp_path: Path, theatre: str) -> Path:
    return tmp_path / "home" / "terrain" / f"{theatre}.terrain"


def test_a_missing_grid_is_downloaded_checked_and_kept(tmp_path: Path, release: dict) -> None:
    data = _grid_bytes(tmp_path, "Syria")
    release[MANIFEST_NAME] = _manifest({"Syria": data})
    release["Syria.terrain"] = data

    grid = grid_for_theatre("syria")

    assert grid is not None and grid.theatre == "Syria"
    assert _home_grid(tmp_path, "Syria").read_bytes() == data
    terrain_data.forget_attempts()
    assert grid_for_theatre("Syria") is not None
    assert release["requested"] == [MANIFEST_NAME, "Syria.terrain"], "the second call reads the local file"


def test_a_grid_swept_on_the_workstation_is_never_downloaded_over(tmp_path: Path, release: dict) -> None:
    save_grid(
        ElevationGrid("Syria", GridSpec(0.0, 0.0, 100.0, 2, 2), array("h", [1, 2, 3, 4])), _home_grid(tmp_path, "Syria")
    )

    grid = grid_for_theatre("Syria")

    assert grid is not None and grid.grid.rows == 2
    assert release["requested"] == []


def test_a_wrong_checksum_writes_nothing(tmp_path: Path, release: dict) -> None:
    data = _grid_bytes(tmp_path, "Syria")
    # The asset is a valid Syria grid of the right size: only the checksum tells it is not the one published.
    manifest = json.loads(_manifest({"Syria": data}))
    manifest["grids"]["Syria"]["sha256"] = "0" * 64
    release[MANIFEST_NAME] = json.dumps(manifest).encode()
    release["Syria.terrain"] = data

    assert grid_for_theatre("Syria") is None
    assert not _home_grid(tmp_path, "Syria").exists()
    assert not list(_home_grid(tmp_path, "Syria").parent.glob("*.part"))


def test_a_grid_of_another_theatre_is_refused(tmp_path: Path, release: dict) -> None:
    data = _grid_bytes(tmp_path, "Normandy")
    release[MANIFEST_NAME] = _manifest({"Syria": data})
    release["Syria.terrain"] = data

    assert grid_for_theatre("Syria") is None
    assert not _home_grid(tmp_path, "Syria").exists()
    assert not list(_home_grid(tmp_path, "Syria").parent.glob("*.part"))


def test_a_theatre_not_published_answers_none(tmp_path: Path, release: dict) -> None:
    release[MANIFEST_NAME] = _manifest({"Syria": _grid_bytes(tmp_path, "Syria")})

    assert grid_for_theatre("Caucasus") is None
    assert release["requested"] == [MANIFEST_NAME]


def test_a_manifest_naming_another_file_is_refused(tmp_path: Path, release: dict) -> None:
    data = _grid_bytes(tmp_path, "Syria")
    manifest = json.loads(_manifest({"Syria": data}))
    manifest["grids"]["Syria"]["file"] = "../../Syria.terrain"
    release[MANIFEST_NAME] = json.dumps(manifest).encode()

    assert grid_for_theatre("Syria") is None
    assert release["requested"] == [MANIFEST_NAME]


def test_offline_is_tried_once_per_process(release: dict) -> None:
    release[MANIFEST_NAME] = requests.ConnectionError("offline")

    assert grid_for_theatre("Syria") is None
    assert grid_for_theatre("Syria") is None
    assert grid_for_theatre("PersianGulf") is None
    assert release["requested"] == [MANIFEST_NAME], "one failed manifest is enough for the whole process"


def test_the_manifest_lists_each_grid_with_its_size_and_checksum(tmp_path: Path) -> None:
    syria = tmp_path / "Syria.terrain"
    syria.write_bytes(_grid_bytes(tmp_path, "Syria"))

    manifest = build_manifest([syria])

    assert manifest == {
        "format": 1,
        "grids": {
            "Syria": {
                "file": "Syria.terrain",
                "bytes": syria.stat().st_size,
                "sha256": hashlib.sha256(syria.read_bytes()).hexdigest(),
            }
        },
    }


def test_the_manifest_refuses_a_file_named_after_another_theatre(tmp_path: Path) -> None:
    wrong = tmp_path / "Syria.terrain"
    wrong.write_bytes(_grid_bytes(tmp_path, "Normandy"))

    with pytest.raises(ValueError, match="Normandy"):
        build_manifest([wrong])


def test_a_grid_swept_while_downloading_is_kept(tmp_path: Path, release: dict, monkeypatch: pytest.MonkeyPatch) -> None:
    data = _grid_bytes(tmp_path, "Syria")
    release[MANIFEST_NAME] = _manifest({"Syria": data})
    release["Syria.terrain"] = data
    swept = ElevationGrid("Syria", GridSpec(0.0, 0.0, 100.0, 2, 2), array("h", [1, 2, 3, 4]))
    fetch = terrain_data.fetch_github_asset

    def sweep_meanwhile(url: str, **kwargs):  # noqa: ANN202, ANN003
        if url.endswith("Syria.terrain"):
            save_grid(swept, _home_grid(tmp_path, "Syria"))
        return fetch(url, **kwargs)

    monkeypatch.setattr(terrain_data, "fetch_github_asset", sweep_meanwhile)

    grid = grid_for_theatre("Syria")

    assert grid is not None and grid.grid.rows == 2, "the grid swept on the workstation wins"
    assert not list(_home_grid(tmp_path, "Syria").parent.glob("*.part"))


def test_a_grid_that_fails_to_download_answers_none(tmp_path: Path, release: dict) -> None:
    data = _grid_bytes(tmp_path, "Syria")
    release[MANIFEST_NAME] = _manifest({"Syria": data})
    release["Syria.terrain"] = requests.Timeout("read timed out")

    assert grid_for_theatre("Syria") is None
    assert not _home_grid(tmp_path, "Syria").exists()
