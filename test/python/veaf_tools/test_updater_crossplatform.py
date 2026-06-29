"""Cross-platform updater install path (UPDATER-CROSSPLATFORM).

On Unix the binaries are not in published.zip; the updater downloads the per-OS
release assets and makes them executable. The updater entry point has a hyphenated
filename (`veaf-tools-updater.py`), so it is loaded from disk via importlib here.
"""

from __future__ import annotations

import importlib.util
import io
import sys
import types
import zipfile
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_UPDATER_PATH = _REPO_ROOT / "src" / "python" / "veaf-tools" / "veaf-tools-updater.py"


@pytest.fixture(scope="module")
def updater_mod() -> types.ModuleType:
    """Load the hyphenated updater script as an importable module."""
    spec = importlib.util.spec_from_file_location("veaf_tools_updater_mod", _UPDATER_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _worker(updater_mod: types.ModuleType):
    return updater_mod.UpdateWorker(mission_folder=".", verify_checksum=False)


def _force_linux(updater_mod: types.ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    """Pin the platform helpers to Linux/x86_64 regardless of the host OS."""
    pa = updater_mod.platform_assets
    monkeypatch.setattr(pa, "is_windows", lambda system=None: False)
    monkeypatch.setattr(pa, "veaf_tools_asset_name", lambda *a, **k: "veaf-tools-linux-x86_64")
    monkeypatch.setattr(pa, "updater_asset_name", lambda *a, **k: "veaf-tools-updater-linux-x86_64")
    monkeypatch.setattr(pa, "veaf_tools_binary_name", lambda *a, **k: "veaf-tools")
    monkeypatch.setattr(pa, "updater_binary_name", lambda *a, **k: "veaf-tools-updater")


def _make_zip() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("README.md", "x")
    return buf.getvalue()


def test_install_unix_binaries_downloads_and_chmods(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker = _worker(updater_mod)
    _force_linux(updater_mod, monkeypatch)
    monkeypatch.setattr(worker, "download_asset", lambda url, name: b"BINARY:" + name.encode())
    monkeypatch.chdir(tmp_path)

    assets = [
        {"name": "veaf-tools-linux-x86_64", "browser_download_url": "http://x/tools"},
        {"name": "veaf-tools-updater-linux-x86_64", "browser_download_url": "http://x/updater"},
    ]
    worker._install_unix_binaries(assets)

    tools = tmp_path / "veaf-tools"
    updater = tmp_path / "veaf-tools-updater"
    assert tools.read_bytes() == b"BINARY:veaf-tools-linux-x86_64"
    assert updater.read_bytes() == b"BINARY:veaf-tools-updater-linux-x86_64"
    # The executable bit is only meaningful on a POSIX filesystem.
    if sys.platform != "win32":
        assert tools.stat().st_mode & 0o111
        assert updater.stat().st_mode & 0o111


def test_install_unix_binaries_offline_zip_skips(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker = _worker(updater_mod)
    monkeypatch.chdir(tmp_path)
    worker._install_unix_binaries(None)  # offline --zip-file: no assets to fetch
    assert not (tmp_path / "veaf-tools").exists()


def test_download_binary_asset_missing_returns_false(updater_mod: types.ModuleType, tmp_path: Path) -> None:
    worker = _worker(updater_mod)
    ok = worker._download_binary_asset([], "veaf-tools-linux-x86_64", tmp_path / "veaf-tools")
    assert ok is False
    assert not (tmp_path / "veaf-tools").exists()


def test_extract_and_install_routes_unix(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker = _worker(updater_mod)
    monkeypatch.setattr(updater_mod.platform_assets, "is_windows", lambda system=None: False)
    called: dict[str, object] = {}
    monkeypatch.setattr(worker, "_install_unix_binaries", lambda assets: called.setdefault("unix", assets))
    monkeypatch.setattr(worker, "_install_windows_binaries", lambda *a: called.setdefault("win", a))
    monkeypatch.setattr(worker, "_install_defaults", lambda *a: None)

    assets = [{"name": "veaf-tools-linux-x86_64"}]
    ok = worker.extract_and_install(_make_zip(), "6.7.3", tmp_path, release_assets=assets)

    assert ok is True
    assert "unix" in called and "win" not in called
    assert called["unix"] == assets


def test_extract_and_install_routes_windows(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker = _worker(updater_mod)
    monkeypatch.setattr(updater_mod.platform_assets, "is_windows", lambda system=None: True)
    called: dict[str, object] = {}
    monkeypatch.setattr(worker, "_install_unix_binaries", lambda assets: called.setdefault("unix", assets))
    monkeypatch.setattr(worker, "_install_windows_binaries", lambda *a: called.setdefault("win", a))
    monkeypatch.setattr(worker, "_install_defaults", lambda *a: None)

    ok = worker.extract_and_install(_make_zip(), "6.7.3", tmp_path)

    assert ok is True
    assert "win" in called and "unix" not in called
