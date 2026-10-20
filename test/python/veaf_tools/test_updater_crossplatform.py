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


def test_download_binary_asset_download_failure_returns_false(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    worker = _worker(updater_mod)
    monkeypatch.setattr(worker, "download_asset", lambda url, name: None)  # network/download failure
    dest = tmp_path / "veaf-tools"
    assets = [{"name": "veaf-tools-linux-x86_64", "browser_download_url": "http://x"}]
    ok = worker._download_binary_asset(assets, "veaf-tools-linux-x86_64", dest)
    assert ok is False
    assert not dest.exists()


def test_install_unix_binaries_unsupported_platform_skips(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pa = updater_mod.platform_assets
    monkeypatch.setattr(pa, "veaf_tools_asset_name", lambda *a, **k: None)
    monkeypatch.setattr(pa, "updater_asset_name", lambda *a, **k: None)
    worker = _worker(updater_mod)
    monkeypatch.chdir(tmp_path)

    # Non-empty assets, but no prebuilt binary applies to this platform/arch.
    worker._install_unix_binaries([{"name": "something-else"}])
    assert not (tmp_path / "veaf-tools").exists()
    assert not (tmp_path / "veaf-tools-updater").exists()


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


def test_install_windows_binaries_sets_a_running_veaf_tools_aside(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The installed veaf-tools.exe is renamed aside rather than overwritten (FEAT-AI-ZERO-SETUP 01).

    An MCP server keeps veaf-tools.exe open for as long as its client runs, and Windows refuses to
    overwrite a running exe but lets it be renamed: overwriting is what left a server on 6.22.1 for
    five weeks while 6.30.0 sat unused in published/.
    """
    worker = _worker(updater_mod)
    monkeypatch.chdir(tmp_path)
    published = tmp_path / "published"
    published.mkdir()
    (published / "veaf-tools.exe").write_bytes(b"new")
    (tmp_path / "veaf-tools.exe").write_bytes(b"running")
    (tmp_path / "veaf-tools.exe.1.old").write_bytes(b"left by an earlier update")

    worker._install_windows_binaries(published)

    assert (tmp_path / "veaf-tools.exe").read_bytes() == b"new"
    set_aside = list(tmp_path.glob("veaf-tools.exe.*.old"))
    assert [p.read_bytes() for p in set_aside] == [b"running"]


def test_install_windows_binaries_keeps_a_leftover_it_cannot_delete(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A copy set aside earlier and still running cannot be deleted: the install goes on regardless."""
    worker = _worker(updater_mod)
    monkeypatch.chdir(tmp_path)
    published = tmp_path / "published"
    published.mkdir()
    (published / "veaf-tools.exe").write_bytes(b"new")
    (tmp_path / "veaf-tools.exe.1.old").write_bytes(b"still running")
    real_unlink = Path.unlink

    def locked_unlink(self: Path, missing_ok: bool = False) -> None:
        if self.name.endswith(".old"):
            raise PermissionError(13, "Access is denied")
        real_unlink(self, missing_ok=missing_ok)

    monkeypatch.setattr(Path, "unlink", locked_unlink)

    worker._install_windows_binaries(published)

    assert (tmp_path / "veaf-tools.exe").read_bytes() == b"new"
    assert (tmp_path / "veaf-tools.exe.1.old").exists()


def test_install_windows_binaries_replaces_the_running_updater_too(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The updater sets itself aside the same way (FEAT-AI-ZERO-SETUP).

    Run without a console window, the deferred `.cmd` script it used before did not put the new
    updater in place (measured 2026-10-20): `veaf-tools-updater.exe` stayed on the old version.
    """
    worker = _worker(updater_mod)
    monkeypatch.chdir(tmp_path)
    published = tmp_path / "published"
    published.mkdir()
    (published / "veaf-tools.exe").write_bytes(b"new tools")
    (published / "veaf-tools-updater.exe").write_bytes(b"new updater")
    (tmp_path / "veaf-tools-updater.exe").write_bytes(b"running updater")

    worker._install_windows_binaries(published)

    assert (tmp_path / "veaf-tools-updater.exe").read_bytes() == b"new updater"
    assert [p.read_bytes() for p in tmp_path.glob("veaf-tools-updater.exe.*.old")] == [b"running updater"]
    assert not (tmp_path / ".veaf-update-pending").exists()


def test_a_failed_move_puts_the_running_executable_back(
    updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Never leave the folder without veaf-tools.exe: every AI client would fail to start the server."""
    published = tmp_path / "published"
    published.mkdir()
    (published / "veaf-tools.exe").write_bytes(b"new")
    dest = tmp_path / "veaf-tools.exe"
    dest.write_bytes(b"running")

    def locked_move(*_args: object) -> None:
        raise PermissionError(13, "held by a virus scanner")

    monkeypatch.setattr(updater_mod.shutil, "move", locked_move)

    with pytest.raises(PermissionError):
        updater_mod._install_beside_running_exe(published / "veaf-tools.exe", dest)

    assert dest.read_bytes() == b"running"
    assert list(tmp_path.glob("veaf-tools.exe.*.old")) == []
