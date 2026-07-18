import zipfile
from pathlib import Path

import pytest

from mission_tools.miz_tools import read_member
from veaf_mission_mcp.edit_veaf_config import (
    VEAF_CONFIG_ARCNAME,
    set_log_level,
    set_module_enabled,
    set_security_disabled,
    set_veaf_config,
)


def _miz_with_config(tmp_path: Path, config: bytes) -> Path:
    miz = tmp_path / "mission.miz"
    with zipfile.ZipFile(miz, "w") as zf:
        zf.writestr("mission", b"mission = {\n}\n")
        zf.writestr(VEAF_CONFIG_ARCNAME, config)
    return miz


def _config(miz: Path) -> str:
    return read_member(miz, VEAF_CONFIG_ARCNAME).decode("utf-8")


class TestSetLogLevel:
    def test_replaces_existing_line(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b'-- header\nveaf.ForcedLogLevel = "debug"\nveaf.config.x = 1\n')

        result = set_log_level(miz, "info")

        assert result == {"line": 'veaf.ForcedLogLevel = "info"', "inserted": False}
        assert 'veaf.ForcedLogLevel = "info"' in _config(miz)
        assert 'veaf.ForcedLogLevel = "debug"' not in _config(miz)
        assert "veaf.config.x = 1" in _config(miz)  # other lines untouched

    def test_inserts_when_absent(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"veaf.config.x = 1\n")

        result = set_log_level(miz, "trace")

        assert result["inserted"] is True
        assert _config(miz).startswith('veaf.ForcedLogLevel = "trace"\n')

    def test_rejects_unknown_level(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"")
        with pytest.raises(ValueError, match="Unknown log level"):
            set_log_level(miz, "verbose")

    def test_backs_up(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b'veaf.ForcedLogLevel = "debug"\n')
        set_log_level(miz, "info")
        assert len(list(miz.parent.glob("mission.*.miz"))) == 1


class TestSetModuleEnabled:
    def test_replaces_existing_module_line(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b'veaf.setConfig("QRA", "enable", true)\n')

        result = set_module_enabled(miz, "QRA", False)

        assert result["inserted"] is False
        assert 'veaf.setConfig("QRA", "enable", false)' in _config(miz)

    def test_only_touches_the_targeted_module(self, tmp_path: Path) -> None:
        miz = _miz_with_config(
            tmp_path, b'veaf.setConfig("QRA", "enable", true)\nveaf.setConfig("CTLD", "enable", true)\n'
        )

        set_module_enabled(miz, "QRA", False)

        assert 'veaf.setConfig("QRA", "enable", false)' in _config(miz)
        assert 'veaf.setConfig("CTLD", "enable", true)' in _config(miz)

    def test_inserts_when_absent(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"-- cfg\n")
        result = set_module_enabled(miz, "COMBATZONE", True)
        assert result["inserted"] is True
        assert 'veaf.setConfig("COMBATZONE", "enable", true)' in _config(miz)


class TestSetSecurityDisabled:
    def test_replaces_flag(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"veaf.SecurityDisabled = true\n")
        set_security_disabled(miz, False)
        assert "veaf.SecurityDisabled = false" in _config(miz)


class TestSetVeafConfig:
    def test_replaces_existing_key(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b'veaf.config.MISSION_NAME = "Old"\n')
        set_veaf_config(miz, "MISSION_NAME", "New")
        assert 'veaf.config.MISSION_NAME = "New"' in _config(miz)

    def test_renders_lua_scalars(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"-- cfg\n")
        set_veaf_config(miz, "MAX", 42)
        set_veaf_config(miz, "ENABLED", True)
        cfg = _config(miz)
        assert "veaf.config.MAX = 42" in cfg
        assert "veaf.config.ENABLED = true" in cfg

    def test_rejects_bad_key(self, tmp_path: Path) -> None:
        miz = _miz_with_config(tmp_path, b"")
        with pytest.raises(ValueError, match="Invalid veaf.config key"):
            set_veaf_config(miz, "bad key", 1)


class TestNoConfig:
    def test_raises_when_no_veaf_config(self, tmp_path: Path) -> None:
        miz = tmp_path / "m.miz"
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("mission", b"mission = {}\n")
        with pytest.raises(ValueError, match="no l10n/DEFAULT/veaf-config.lua|not a VEAF-built"):
            set_log_level(miz, "info")
