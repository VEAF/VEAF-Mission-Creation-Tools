"""Standalone single-binary build path (FEAT-CROSSPLATFORM-BINARIES).

`build-standalone` builds only the `veaf-tools` executable — no updater, no
release package — so the per-OS CI jobs can publish one Linux/macOS binary each.
These tests stub out the PyInstaller call and the dist/version side effects so
they assert orchestration only, never invoking PyInstaller.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from veaf_build.worker import BuildAndReleaseWorker

# Arbitrary version: these tests assert build orchestration, not the version string,
# so any non-empty value works (kept decoupled from the project's actual version).
_TEST_VERSION = "0.0.0"


def _isolated_worker(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[BuildAndReleaseWorker, list[str]]:
    """Return a worker whose side-effecting steps are stubbed and the PyInstaller
    call recorded by executable name."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    monkeypatch.setattr(worker, "_prepare_dist", lambda: None)
    monkeypatch.setattr(worker, "_scan_lua_modules", lambda: None)
    monkeypatch.setattr(worker, "_write_version_py", lambda path: None)
    monkeypatch.setattr(worker, "_restore_version_py", lambda path: None)

    built: list[str] = []

    def _record(
        name: str,
        entry_point: Path,
        extra_data: list[tuple[Path, str]] | None = None,
        hidden_imports: list[str] | None = None,
    ) -> None:
        built.append(name)

    monkeypatch.setattr(worker, "_build_pyinstaller_executable", _record)
    return worker, built


def test_standalone_builds_only_veaf_tools(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, built = _isolated_worker(tmp_path, monkeypatch)
    worker.build_veaf_tools_standalone()
    assert built == ["veaf-tools"]


def test_full_build_builds_both_executables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, built = _isolated_worker(tmp_path, monkeypatch)
    worker.build_python_executables()
    assert built == ["veaf-tools", "veaf-tools-updater"]


def test_veaf_tools_extra_data_bundles_locales(tmp_path: Path) -> None:
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    dests = [dest for _src, dest in worker._veaf_tools_extra_data(None)]
    assert "veaf_libs/locales" in dests


def test_veaf_tools_extra_data_bundles_both_radio_yaml_files(tmp_path: Path) -> None:
    """Regression guard: dcs-radio-layouts.yaml was missing here (FIX-VEAF-BUILD-RADIO-LAYOUT-DATA),
    breaking convert-v5's radio preset conversion in the packaged executable only."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    sources = [src.name for src, _dest in worker._veaf_tools_extra_data(None)]
    assert "dcs-radio-specs.yaml" in sources
    assert "dcs-radio-layouts.yaml" in sources


def test_veaf_tools_extra_data_bundles_airfield_frequencies(tmp_path: Path) -> None:
    """Regression guard: airfield-frequencies.yaml must ship so convert-v5 freq aliasing
    works in the packaged executable (FEAT-AIRFIELD-FREQS-DATA)."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    sources = [src.name for src, _dest in worker._veaf_tools_extra_data(None)]
    assert "airfield-frequencies.yaml" in sources


def test_veaf_tools_extra_data_bundles_third_party_mods(tmp_path: Path) -> None:
    """Regression guard: third_party_mods.json must ship so the build's requiredModules
    stripping works in the packaged executable (FEAT-THIRD-PARTY-MODS)."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    bundled = [(src.name, dest) for src, dest in worker._veaf_tools_extra_data(None)]
    assert ("third_party_mods.json", "mission_builder/data") in bundled
