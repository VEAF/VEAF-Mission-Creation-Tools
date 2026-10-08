"""Tests for the pinned download of the dcs-world-schema reference database (FEAT-DCS-REFERENCE-DATA)."""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from veaf_build.dcs_data import reference as R


def test_the_download_is_written_when_its_digest_matches(tmp_path: Path) -> None:
    body = b"SQLite format 3\x00"
    path = R.download_reference(
        tmp_path,
        url="https://example.invalid/x/ref.sqlite",
        sha256=hashlib.sha256(body).hexdigest(),
        fetch=lambda _: body,
    )
    assert path == tmp_path / "ref.sqlite"
    assert path.read_bytes() == body


def test_a_download_with_another_digest_is_refused_and_not_written(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError, match="SHA-256"):
        R.download_reference(tmp_path, url="https://example.invalid/ref.sqlite", sha256="0" * 64, fetch=lambda _: b"x")
    assert not (tmp_path / "ref.sqlite").exists()


def test_the_pin_names_the_asset_of_the_release() -> None:
    assert R.REFERENCE_URL.endswith(f"/download/{R.REFERENCE_TAG}/{R.REFERENCE_ASSET}")
    assert len(R.REFERENCE_SHA256) == 64
