"""SECREV-2 / VMR-011 — the updater's checksum verification must fail closed.

It used to warn and install anyway whenever the material it needed was absent: no
metadata asset, an undownloadable one, unparseable JSON, or a missing checksum key. An
attacker able to influence release metadata therefore did not need to defeat the
checksum — removing it was enough.

Each of those four paths is asserted here, plus the two that must still succeed, because
a fail-closed updater that refuses a *good* release strands mission makers on an old
version and cannot update itself out of the problem.

**How a refusal manifests**: `veaf_libs.logger.error` raises `typer.Abort` by default — it
is an abort, not a log line — so a refusal surfaces as that exception rather than as a
`False` return. That is also the mechanism behind the original bug: the author reached for
`logger.warning` precisely because `error` would have stopped the run, and got fail-open as
the side effect.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import types
from pathlib import Path

import pytest
import typer

_REPO_ROOT = Path(__file__).resolve().parents[3]
_UPDATER_PATH = _REPO_ROOT / "src" / "python" / "veaf-tools" / "veaf-tools-updater.py"

_ZIP = b"pretend this is published.zip"
_GOOD_SHA = hashlib.sha256(_ZIP).hexdigest()


@pytest.fixture(scope="module")
def updater_mod() -> types.ModuleType:
    """Load the hyphenated updater script as an importable module."""
    spec = importlib.util.spec_from_file_location("veaf_tools_updater_failclosed_mod", _UPDATER_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def worker(updater_mod: types.ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """A worker whose temp file lands in tmp_path rather than the repository root."""
    monkeypatch.chdir(tmp_path)
    return updater_mod.UpdateWorker(mission_folder=str(tmp_path), verify_checksum=True)


def _payload(updater_mod: types.ModuleType, *, with_metadata: bool = True) -> dict:
    assets = [{"name": "published.zip", "browser_download_url": "https://example/published.zip"}]
    if with_metadata:
        assets.append(
            {
                "name": updater_mod.PUBLISHED_METADATA_ASSET_NAME,
                "browser_download_url": "https://example/metadata.json",
            }
        )
    return {"assets": assets}


class TestRefusesWhenIntegrityMaterialIsMissing:
    def test_no_metadata_asset_refuses(self, updater_mod: types.ModuleType, worker) -> None:
        payload = _payload(updater_mod, with_metadata=False)
        with pytest.raises(typer.Abort):
            worker._checksum_verified(payload, _ZIP, "6.0.0")

    def test_undownloadable_metadata_refuses(
        self, updater_mod: types.ModuleType, worker, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: None)
        with pytest.raises(typer.Abort):
            worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")

    def test_unparseable_metadata_refuses(
        self, updater_mod: types.ModuleType, worker, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: b"{not json")
        with pytest.raises(typer.Abort):
            worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")

    def test_metadata_without_a_checksum_refuses(
        self, updater_mod: types.ModuleType, worker, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: json.dumps({"other": 1}).encode())
        with pytest.raises(typer.Abort):
            worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")

    def test_wrong_checksum_refuses(
        self, updater_mod: types.ModuleType, worker, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        body = json.dumps({"published_zip_sha256": "00" * 32}).encode()
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: body)
        with pytest.raises(typer.Abort):
            worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")


class TestStillAcceptsAGoodRelease:
    def test_matching_checksum_passes(
        self, updater_mod: types.ModuleType, worker, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        body = json.dumps({"published_zip_sha256": _GOOD_SHA}).encode()
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: body)
        assert worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0") is True

    def test_temp_file_is_cleaned_up_on_success(
        self, updater_mod: types.ModuleType, worker, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        body = json.dumps({"published_zip_sha256": _GOOD_SHA}).encode()
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: body)
        worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")
        assert list(tmp_path.glob("*.zip.tmp")) == []

    def test_temp_file_is_cleaned_up_on_refusal(
        self, updater_mod: types.ModuleType, worker, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """A refusal must not leave a stray .tmp behind in the mission folder."""
        body = json.dumps({"published_zip_sha256": "00" * 32}).encode()
        monkeypatch.setattr(worker, "download_asset", lambda *a, **k: body)
        with pytest.raises(typer.Abort):
            worker._checksum_verified(_payload(updater_mod), _ZIP, "6.0.0")
        assert list(tmp_path.glob("*.zip.tmp")) == []


class TestRefusalMessagesAreActionable:
    """Every refusal has to say what is wrong *and* what to do, or it strands people."""

    @pytest.mark.parametrize(
        "key",
        [
            "updater.err.no_metadata",
            "updater.err.metadata_download_failed",
            "updater.err.metadata_parse",
            "updater.err.no_checksum_in_metadata",
        ],
    )
    def test_message_names_the_escape_hatch(self, key: str) -> None:
        from veaf_libs.i18n import t

        for locale in ("en", "fr"):
            message = t(key, locale=locale)
            assert message != key, f"{key} missing from {locale}"
            assert "--no-verify-checksum" in message, f"{key} ({locale}) does not say what to do"
