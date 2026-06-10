"""SECREV-004 / SECREV-005 — safe extraction of untrusted ZIP archives."""

from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from veaf_libs.safe_zip import safe_extract_all


def _zip_with(tmp_path: Path, members: dict[str, bytes]) -> Path:
    archive = tmp_path / "archive.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        for name, data in members.items():
            zf.writestr(name, data)
    return archive


class TestHappyPath:
    def test_extracts_normal_archive(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"a.txt": b"hello", "sub/b.txt": b"world"})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf:
            safe_extract_all(zf, dest)
        assert (dest / "a.txt").read_bytes() == b"hello"
        assert (dest / "sub" / "b.txt").read_bytes() == b"world"


class TestZipSlip:
    def test_parent_traversal_rejected(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"../escape.txt": b"evil"})
        dest = tmp_path / "out"
        dest.mkdir()
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError):
            safe_extract_all(zf, dest)
        assert not (tmp_path / "escape.txt").exists()

    def test_absolute_path_rejected(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"/abs_evil.txt": b"evil"})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError):
            safe_extract_all(zf, dest)

    def test_nested_traversal_rejected(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"ok/../../escape.txt": b"evil"})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError):
            safe_extract_all(zf, dest)


class TestZipBomb:
    def test_too_many_entries_rejected(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {f"f{i}.txt": b"x" for i in range(5)})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError):
            safe_extract_all(zf, dest, max_entries=2)

    def test_total_uncompressed_size_capped(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"big.bin": b"A" * 5000})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError):
            safe_extract_all(zf, dest, max_total_bytes=1000)
        assert not dest.exists() or not list(dest.iterdir())

    def test_within_limits_extracts(self, tmp_path: Path) -> None:
        archive = _zip_with(tmp_path, {"small.bin": b"A" * 100})
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf:
            safe_extract_all(zf, dest, max_entries=10, max_total_bytes=10_000)
        assert (dest / "small.bin").read_bytes() == b"A" * 100
