"""Dynamic-loading resolution: CLI override > build.dynamic_loading > default (IMC2-008)."""

from __future__ import annotations

from mission_builder.mission_builder_worker import resolve_dynamic_mode


class TestResolveDynamicMode:
    def test_default_is_static(self) -> None:
        assert resolve_dynamic_mode(None, {}) is False

    def test_mission_yaml_enables(self) -> None:
        assert resolve_dynamic_mode(None, {"dynamic_loading": True}) is True

    def test_mission_yaml_disables(self) -> None:
        assert resolve_dynamic_mode(None, {"dynamic_loading": False}) is False

    def test_cli_true_overrides_yaml_false(self) -> None:
        assert resolve_dynamic_mode(True, {"dynamic_loading": False}) is True

    def test_cli_false_overrides_yaml_true(self) -> None:
        assert resolve_dynamic_mode(False, {"dynamic_loading": True}) is False
