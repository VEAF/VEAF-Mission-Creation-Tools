"""Tests for miz_backup.backup_before_write."""

from datetime import datetime
from pathlib import Path

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

    def test_a_same_second_collision_is_disambiguated_not_overwritten(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path, b"first")
        same_second = datetime(2026, 7, 12, 14, 30, 12)

        first = backup_before_write(miz_path, now=same_second)
        miz_path.write_bytes(b"second")
        second = backup_before_write(miz_path, now=same_second)

        assert first != second
        assert first.read_bytes() == b"first"
        assert second.read_bytes() == b"second"
        assert second.name == "mission.20260712-143012-2.miz"

    def test_a_third_same_second_collision_keeps_disambiguating(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path)
        same_second = datetime(2026, 7, 12, 14, 30, 12)

        backup_before_write(miz_path, now=same_second)
        backup_before_write(miz_path, now=same_second)
        third = backup_before_write(miz_path, now=same_second)

        assert third.name == "mission.20260712-143012-3.miz"

    def test_different_seconds_produce_distinct_backups(self, tmp_path: Path) -> None:
        miz_path = _make_miz(tmp_path)

        first = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 12))
        second = backup_before_write(miz_path, now=datetime(2026, 7, 12, 14, 30, 13))

        assert first != second
        assert first.exists()
        assert second.exists()


def test_a_file_under_l10n_default_is_backed_up_into_the_folder(tmp_path: Path) -> None:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 15: Caucasus v6 found `dictionary.<timestamp>` copies in
    `src/mission/l10n/DEFAULT/`, which the build packs into the `.miz`."""
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    l10n = tmp_path / "src" / "mission" / "l10n" / "DEFAULT"
    l10n.mkdir(parents=True)
    dictionary = l10n / "dictionary"
    dictionary.write_text("dictionary = {}\n", encoding="utf-8")

    backup_path = backup_before_write(dictionary, now=datetime(2026, 9, 28, 21, 16, 47))

    assert backup_path.parent == tmp_path / ".veaf-backups"
    assert sorted(p.name for p in l10n.iterdir()) == ["dictionary"]
