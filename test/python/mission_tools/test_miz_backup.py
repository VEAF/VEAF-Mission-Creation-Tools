"""Tests for miz_backup.backup_before_write."""

from datetime import datetime
from pathlib import Path

import pytest
from mission_tools.miz_backup import backup_before_write


def _make_miz(tmp_path: Path, content: bytes = b"fake miz content") -> Path:
    miz_path = tmp_path / "mission.miz"
    miz_path.write_bytes(content)
    return miz_path


class TestBackupBeforeWrite:
    def test_backup_is_byte_identical_to_source(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path, b"some mission bytes")

        backup_path = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 12))

        assert backup_path.read_bytes() == b"some mission bytes"

    def test_backup_filename_uses_a_sortable_timestamp(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path)

        backup_path = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 12))

        assert backup_path.name == "mission.20260712-143012.miz"
        assert backup_path.parent == tmp_path

    def test_backup_leaves_the_source_file_untouched(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path, b"original")

        backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 12))

        assert miz_path.read_bytes() == b"original"

    def test_backup_raises_on_a_same_second_collision(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path)
        same_second = datetime(2026, 7, 12, 14, 30, 12)
        backup_before_write(miz_path, now=same_second)

        with pytest.raises(FileExistsError):
            backup_before_write(miz_path, now=same_second)

    def test_different_seconds_produce_distinct_backups(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path)

        first = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 12))
        second = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 13))

        assert first != second
        assert first.exists()
        assert second.exists()
