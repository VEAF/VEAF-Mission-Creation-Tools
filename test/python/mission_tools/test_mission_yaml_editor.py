"""Tests for the comment-preserving ``mission.yaml`` editor brick (wave 4)."""

from pathlib import Path

from mission_tools.mission_yaml_editor import load_yaml, save_yaml

SAMPLE = """\
# Top-of-file comment
modules:
  UNITS:
  SECURITY: true # inline comment
  CTLD: false
# trailing comment
"""


def _write_sample(tmp_path: Path) -> Path:
    path = tmp_path / "mission.yaml"
    path.write_text(SAMPLE, encoding="utf-8")
    return path


def test_roundtrip_preserves_comments_and_key_order(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    save_yaml(path, load_yaml(path))
    out = path.read_text(encoding="utf-8")
    assert "# Top-of-file comment" in out
    assert "# inline comment" in out
    assert "# trailing comment" in out
    assert out.index("UNITS") < out.index("SECURITY") < out.index("CTLD")


def test_noop_roundtrip_is_byte_stable(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    save_yaml(path, load_yaml(path))
    assert path.read_text(encoding="utf-8") == SAMPLE


def test_scalar_edit_touches_only_its_own_value(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    data = load_yaml(path)
    data["modules"]["SECURITY"] = False
    save_yaml(path, data)
    out = path.read_text(encoding="utf-8")
    assert "SECURITY: false" in out
    assert "# inline comment" in out  # the value's comment survives the edit
    assert "CTLD: false" in out  # an unrelated line is untouched
    assert "# Top-of-file comment" in out


def test_save_backs_up_before_writing(tmp_path: Path) -> None:
    path = _write_sample(tmp_path)
    backup = save_yaml(path, load_yaml(path))
    assert backup.exists()
    assert backup != path
    assert backup.suffix == ".yaml"
    assert backup.read_text(encoding="utf-8") == SAMPLE
