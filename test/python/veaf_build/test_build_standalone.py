"""Standalone single-binary build path (FEAT-CROSSPLATFORM-BINARIES).

`build-standalone` builds only the `veaf-tools` executable — no updater, no
release package — so the per-OS CI jobs can publish one Linux/macOS binary each.
These tests stub out the PyInstaller call and the dist/version side effects so
they assert orchestration only, never invoking PyInstaller.
"""

from __future__ import annotations

import ast
import subprocess
from pathlib import Path

import pytest

from veaf_build import worker as worker_module
from veaf_build.worker import BuildAndReleaseWorker

# Arbitrary version: these tests assert build orchestration, not the version string,
# so any non-empty value works (kept decoupled from the project's actual version).
_TEST_VERSION = "0.0.0"


def _recording_worker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[BuildAndReleaseWorker, list[dict[str, object]]]:
    """Return a worker whose side-effecting steps are stubbed, and the live list of
    PyInstaller calls it records — every argument, not just the executable name."""
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    monkeypatch.setattr(worker, "_prepare_dist", lambda: None)
    monkeypatch.setattr(worker, "_scan_lua_modules", lambda: None)
    monkeypatch.setattr(worker, "_write_version_py", lambda path: None)
    monkeypatch.setattr(worker, "_restore_version_py", lambda path: None)

    calls: list[dict[str, object]] = []

    def _record(
        name: str,
        entry_point: Path,
        extra_data: list[tuple[Path, str]] | None = None,
        hidden_imports: list[str] | None = None,
        collect_submodules: list[str] | None = None,
    ) -> None:
        calls.append(
            {
                "name": name,
                "entry_point": entry_point,
                "extra_data": extra_data,
                "hidden_imports": hidden_imports or [],
                "collect_submodules": collect_submodules or [],
            }
        )

    monkeypatch.setattr(worker, "_build_pyinstaller_executable", _record)
    return worker, calls


def test_standalone_builds_only_veaf_tools(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_tools_standalone()
    assert [call["name"] for call in calls] == ["veaf-tools"]


def test_full_build_builds_both_executables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_python_executables()
    assert [call["name"] for call in calls] == ["veaf-tools", "veaf-tools-updater"]


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


def _lazy_packages_on_disk(worker: BuildAndReleaseWorker) -> set[str]:
    """Return the shipped packages whose `__init__.py` resolves its exports lazily.

    Detection is by **AST**: a module-level `__getattr__` in an `__init__.py` is exactly the
    PEP 562 hook Python calls for a name the package does not define, and it is the whole of
    PyInstaller's blind spot — whatever the body then does to produce the module. Parsing
    rather than grepping means a reformatted signature, a mention in a docstring or a switch
    from `import_module` to another import mechanism cannot fool it.

    Scanning for the pattern rather than reading a declared list is the point: what broke
    6.15.0 was making a package lazy **without realising** the build had to follow, so a guard
    the author must opt into would have missed it exactly as the build did.
    """
    veaf_tools_dir = worker.src_dir / "python" / "veaf-tools"
    lazy = set()
    for init in veaf_tools_dir.glob("*/__init__.py"):
        tree = ast.parse(init.read_text(encoding="utf-8"), filename=str(init))
        if any(isinstance(node, ast.FunctionDef) and node.name == "__getattr__" for node in tree.body):
            lazy.add(init.parent.name)
    return lazy


def test_veaf_tools_build_collects_every_lazy_package(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Every lazily-resolved package must be collected wholesale into the executable.

    This is the test 6.15.0 shipped without. `mission_builder` became lazy (PEP 562) in
    #757, PyInstaller stopped seeing any of its submodules — no `import` statement names
    them any more — and the executable died on its **first command**, before doing any
    work: `ModuleNotFoundError: No module named 'mission_builder.mission_builder_README'`,
    reported by Tripack after updating to 6.15. Nothing in the suite noticed, because
    every test runs from the checkout where the lazy import resolves fine.
    """
    worker, calls = _recording_worker(tmp_path, monkeypatch)
    lazy = _lazy_packages_on_disk(worker)
    assert lazy, "the pattern scan found no lazy package — check it still matches the code it guards"

    worker.build_veaf_tools_standalone()
    veaf_tools_call = next(call for call in calls if call["name"] == "veaf-tools")
    collected = set(veaf_tools_call["collect_submodules"])  # type: ignore[call-overload]
    assert lazy <= collected, f"lazy packages missing from the exe: {sorted(lazy - collected)}"


def test_every_lazy_export_target_ships(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Each submodule `mission_builder` can hand out must be reachable in the executable.

    Reads the package's own export table, so adding an export that the build does not
    cover fails here rather than in a mission maker's terminal.
    """
    from mission_builder import _EXPORTS

    worker, calls = _recording_worker(tmp_path, monkeypatch)
    worker.build_veaf_tools_standalone()
    veaf_tools_call = next(call for call in calls if call["name"] == "veaf-tools")
    collected = set(veaf_tools_call["collect_submodules"])  # type: ignore[call-overload]
    hidden = set(veaf_tools_call["hidden_imports"])  # type: ignore[call-overload]

    for symbol, relative_module in _EXPORTS.items():
        module = f"mission_builder{relative_module}"
        covered = "mission_builder" in collected or module in hidden
        assert covered, f"{symbol} resolves to {module}, which the executable would not contain"


def test_pyinstaller_command_passes_collect_submodules(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """The declared packages must reach PyInstaller as `--collect-submodules` arguments.

    Guards the wiring, not the list: passing the packages and forgetting to translate them
    into arguments would leave the executable just as broken.
    """
    worker = BuildAndReleaseWorker(version=_TEST_VERSION, output_path=tmp_path)
    monkeypatch.setattr(worker, "_write_exe_version_file", lambda name: None)
    recorded: list[list[str]] = []

    def _fake_run(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        recorded.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, "", "")

    monkeypatch.setattr(worker_module.subprocess, "run", _fake_run)
    entry_point = tmp_path / "entry.py"
    entry_point.write_text("", encoding="utf-8")
    worker._build_pyinstaller_executable("veaf-tools", entry_point, collect_submodules=["mission_builder"])

    cmd = recorded[0]
    assert "--collect-submodules" in cmd
    assert cmd[cmd.index("--collect-submodules") + 1] == "mission_builder"
