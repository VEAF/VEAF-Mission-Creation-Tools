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


def test_veaf_tools_extra_data_bundles_conversion_profiles(tmp_path: Path) -> None:
    """Regression guard: the conversion profiles must ship, or `convert-other --profile
    foothold` dies with "unknown conversion profile" in the packaged executable — which it
    did from the day profiles were introduced until FEAT-FOOTHOLD-RELEASE-INTAKE.

    The stale veaf-tools.spec listed them, but the build does not use that file: it passes
    --add-data from `_veaf_tools_extra_data`, so this list is the one that matters.
    """
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    bundled = worker._veaf_tools_extra_data(None)
    dests = [dest for _src, dest in bundled]
    assert "veaf_libs/data/convert-profiles" in dests

    # The whole directory ships, so a new profile needs no build change.
    profiles_dir = next(src for src, dest in bundled if dest == "veaf_libs/data/convert-profiles")
    assert profiles_dir.is_dir()
    shipped = {p.stem for p in profiles_dir.glob("*.yaml")}
    assert {"foothold", "foothold-ww2"} <= shipped


def test_veaf_tools_extra_data_bundles_the_checklist_data(tmp_path: Path) -> None:
    """Both guided-checklist directories must ship, or the feature works from a checkout
    and fails from the executable — the failure mode the conversion profiles already had.

    The checklists are what a mission embeds; the cockpit-control indexes are what the
    resolver reads to turn an instructor's `throttle sur idle` into an argument number.
    Each is a whole directory, so a new checklist or a newly indexed aircraft needs no
    build change.
    """
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    bundled = worker._veaf_tools_extra_data(None)
    dests = [dest for _src, dest in bundled]
    assert "veaf_libs/data/checklists" in dests
    assert "veaf_libs/data/cockpit-controls" in dests

    indexes = next(src for src, dest in bundled if dest == "veaf_libs/data/cockpit-controls")
    assert "F-16C_50" in {p.stem for p in indexes.glob("*.yaml")}


def test_veaf_tools_extra_data_bundles_third_party_mods(tmp_path: Path) -> None:
    """Regression guard: third_party_mods.json must ship so the build's requiredModules
    stripping works in the packaged executable (FEAT-THIRD-PARTY-MODS)."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    bundled = [(src.name, dest) for src, dest in worker._veaf_tools_extra_data(None)]
    assert ("third_party_mods.json", "mission_builder/data") in bundled
