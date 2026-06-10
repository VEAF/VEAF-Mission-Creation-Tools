"""SECREV-004 / SECREV-005 — safe extraction of untrusted ZIP archives."""

from __future__ import annotations

import io
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

    def test_symlink_entry_rejected(self, tmp_path: Path) -> None:
        archive = tmp_path / "symlink.zip"
        with zipfile.ZipFile(archive, "w") as zf:
            link = zipfile.ZipInfo("link")
            link.external_attr = 0o120777 << 16  # symlink mode bits
            zf.writestr(link, "/etc")
            zf.writestr("link/inner.txt", b"evil")
        dest = tmp_path / "out"
        with zipfile.ZipFile(archive) as zf, pytest.raises(ValueError, match="symlink"):
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

    def test_spoofed_size_header_caught_on_actual_bytes(self, tmp_path: Path) -> None:
        """A lying file_size header must not bypass the byte cap.

        The cap is re-enforced on the actual decompressed stream, so we feed
        safe_extract_all a zip whose declared sizes pass the pre-check but whose
        real content exceeds the cap.
        """

        class _SpoofedZip:
            """Minimal ZipFile stand-in: header says 10 bytes, stream has 5000."""

            def infolist(self) -> list[zipfile.ZipInfo]:
                info = zipfile.ZipInfo("liar.bin")
                info.file_size = 10
                return [info]

            def open(self, info: zipfile.ZipInfo) -> io.BytesIO:
                return io.BytesIO(b"A" * 5000)

        dest = tmp_path / "out"
        with pytest.raises(ValueError, match="decompressed size"):
            safe_extract_all(_SpoofedZip(), dest, max_total_bytes=1000)  # type: ignore[arg-type]
        assert not (dest / "liar.bin").exists()
