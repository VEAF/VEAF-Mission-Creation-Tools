"""Tests for veaf_libs.user_config."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest
from veaf_libs import user_config
from veaf_libs.user_config import (
    _invalidate_cache,
    config_file_path,
    default_config_path,
    get,
    get_check_updates,
    get_lang,
    get_scripts_path,
    set_value,
    unset_value,
)

# Patch both the "find config file" helper and the cache for isolation.
_PATCH_FIND = "veaf_libs.user_config._find_config_file"


@pytest.fixture(autouse=True)
def clear_cache():
    """Ensure the module-level cache is cleared before and after each test."""
    _invalidate_cache()
    yield
    _invalidate_cache()


# ---------------------------------------------------------------------------
# _find_config_file
# ---------------------------------------------------------------------------


class TestFindConfigFile:
    def test_returns_primary_if_exists(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        primary = tmp_path / "veafmct.yaml"
        primary.write_text("lang: fr\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: primary)
        _invalidate_cache()
        assert get_lang() == "fr"

    def test_returns_none_when_no_file_exists(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert get_lang() is None

    def test_returns_none_when_no_file(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert config_file_path() is None


# ---------------------------------------------------------------------------
# get / _load (via monkeypatching _find_config_file)
# ---------------------------------------------------------------------------


class TestGet:
    def test_returns_default_when_no_config(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert get("lang") is None
        assert get("lang", "en") == "en"

    def test_returns_value_from_yaml(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr\ncheck_updates: false\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get("lang") == "fr"
        assert get("check_updates") is False

    def test_returns_default_for_missing_key(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get("check_updates", True) is True

    def test_corrupt_yaml_returns_default(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text(": not valid yaml: [unclosed", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get("lang") is None


# ---------------------------------------------------------------------------
# get_lang
# ---------------------------------------------------------------------------


class TestGetLang:
    def test_none_when_no_config(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert get_lang() is None

    def test_returns_lang(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_lang() == "fr"

    def test_normalises_to_two_chars(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr-FR\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_lang() == "fr"

    def test_normalises_uppercase(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: FR\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_lang() == "fr"

    def test_none_when_lang_empty(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: ''\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_lang() is None

    def test_none_when_lang_not_string(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: 42\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_lang() is None


# ---------------------------------------------------------------------------
# get_check_updates
# ---------------------------------------------------------------------------


class TestGetCheckUpdates:
    def test_true_when_no_config(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert get_check_updates() is True

    def test_false_when_set(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("check_updates: false\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_check_updates() is False

    def test_true_when_explicitly_set(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("check_updates: true\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_check_updates() is True

    def test_true_when_non_bool_value(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        # Non-bool values should default to True
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("check_updates: maybe\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_check_updates() is True


# ---------------------------------------------------------------------------
# get_scripts_path
# ---------------------------------------------------------------------------


class TestGetScriptsPath:
    def test_none_when_not_set(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: None)
        assert get_scripts_path() is None

    def test_none_when_null(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("scripts_path: null\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_scripts_path() is None

    def test_returns_path(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text(f"scripts_path: {tmp_path}\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        assert get_scripts_path() == tmp_path

    def test_expands_tilde(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("scripts_path: ~/some/path\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config._find_config_file", lambda: cfg)
        result = get_scripts_path()
        assert result is not None
        assert "~" not in str(result)


# ---------------------------------------------------------------------------
# default_config_path
# ---------------------------------------------------------------------------


class TestDefaultConfigPath:
    def test_returns_home_veafmct_yaml(self) -> None:
        path = default_config_path()
        assert path.name == "veafmct.yaml"
        assert path.parent == Path.home()


# ---------------------------------------------------------------------------
# set_value / unset_value
# ---------------------------------------------------------------------------


class TestSetValue:
    def test_creates_file_if_not_exists(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        target = tmp_path / "veafmct.yaml"
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: None)
        monkeypatch.setattr("veaf_libs.user_config.default_config_path", lambda: target)
        set_value("lang", "fr")
        assert target.exists()
        # Read file directly: the mock still returns None after creation, so get_lang() can't see it.
        import yaml  # type: ignore[import-untyped]

        data = yaml.safe_load(target.read_text(encoding="utf-8"))
        assert data["lang"] == "fr"

    def test_updates_existing_key(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: en\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: cfg)
        set_value("lang", "fr")
        assert get_lang() == "fr"

    def test_preserves_other_keys(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: en\ncheck_updates: false\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: cfg)
        set_value("lang", "fr")
        assert get_check_updates() is False

    def test_silently_ignores_write_error(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: None)
        monkeypatch.setattr("veaf_libs.user_config.default_config_path", lambda: Path("/nonexistent/path/x.yaml"))
        set_value("lang", "fr")  # must not raise


class TestUnsetValue:
    def test_returns_false_when_no_file(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: None)
        assert unset_value("lang") is False

    def test_returns_false_when_key_not_present(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("check_updates: true\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: cfg)
        assert unset_value("lang") is False

    def test_removes_key(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr\ncheck_updates: false\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: cfg)
        result = unset_value("lang")
        assert result is True
        assert get_lang() is None

    def test_preserves_other_keys_after_unset(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = tmp_path / "veafmct.yaml"
        cfg.write_text("lang: fr\ncheck_updates: false\n", encoding="utf-8")
        monkeypatch.setattr("veaf_libs.user_config.config_file_path", lambda: cfg)
        unset_value("lang")
        assert get_check_updates() is False
