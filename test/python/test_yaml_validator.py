"""Unit tests for veaf_libs.yaml_validator."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import typer
from veaf_libs.yaml_validator import _hint_key, validate_yaml_file


class TestHintKey(unittest.TestCase):
    def test_tab_character(self) -> None:
        self.assertEqual(_hint_key("found character '\t' that cannot start any token"), "yaml.error.hint.tab")

    def test_cannot_start_any_token(self) -> None:
        self.assertEqual(_hint_key("cannot start any token"), "yaml.error.hint.tab")

    def test_missing_colon(self) -> None:
        self.assertEqual(_hint_key("could not find expected ':'"), "yaml.error.hint.colon")

    def test_block_mapping(self) -> None:
        self.assertEqual(_hint_key("expected <block end>, but found '<block mapping start>'"), "yaml.error.hint.indentation")

    def test_block_end(self) -> None:
        self.assertEqual(_hint_key("expected <block end>"), "yaml.error.hint.indentation")

    def test_block_sequence(self) -> None:
        self.assertEqual(_hint_key("while parsing a block sequence"), "yaml.error.hint.indentation")

    def test_generic_fallback(self) -> None:
        self.assertEqual(_hint_key("something completely unexpected"), "yaml.error.hint.generic")


class TestValidateYamlFile(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write(self, content: str) -> Path:
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix=".yaml", delete=False, encoding="utf-8", dir=self._tmp.name
        )
        f.write(content)
        f.close()
        return Path(f.name)

    def test_valid_yaml_passes(self) -> None:
        path = self._write("key: value\nother: 42\n")
        validate_yaml_file(path)  # must not raise

    def test_indentation_error_calls_logger(self) -> None:
        path = self._write("parent:\n  child: 1\n   bad: 2\n")
        with patch("veaf_libs.yaml_validator.logger") as mock_log:
            mock_log.error.side_effect = typer.Abort()
            with self.assertRaises(typer.Abort):
                validate_yaml_file(path)
            args = mock_log.error.call_args[0][0]
            self.assertIn("yaml.error.hint.indentation", _hint_key("expected <block end>"))
            self.assertIn(path.name, args)

    def test_tab_error_calls_logger(self) -> None:
        path = self._write("key: value\n\tchild: bad\n")
        with patch("veaf_libs.yaml_validator.logger") as mock_log:
            mock_log.error.side_effect = typer.Abort()
            with self.assertRaises(typer.Abort):
                validate_yaml_file(path)
            args = mock_log.error.call_args[0][0]
            self.assertIn(path.name, args)

    def test_error_message_contains_line_number(self) -> None:
        path = self._write("key: value\n  bad_indent: 1\n    worse: 2\n")
        with patch("veaf_libs.yaml_validator.logger") as mock_log:
            mock_log.error.side_effect = typer.Abort()
            with self.assertRaises(typer.Abort):
                validate_yaml_file(path)
            args = mock_log.error.call_args[0][0]
            # line number must appear in the message
            self.assertRegex(args, r"\d+")


class TestValidateModulesSemantics(unittest.TestCase):
    """MODULES-UNIFY-006 — semantic validation of the modules: block."""

    def _patched(self):  # type: ignore[no-untyped-def]
        from veaf_libs.yaml_validator import validate_modules_semantics

        patcher = patch("veaf_libs.yaml_validator.logger")
        mock_log = patcher.start()
        self.addCleanup(patcher.stop)
        mock_log.error.side_effect = typer.Abort()
        return mock_log, validate_modules_semantics

    def test_valid_modules_pass(self) -> None:
        mock_log, fn = self._patched()
        fn({"modules": {"RADIO": True, "MIST": True}})
        mock_log.error.assert_not_called()

    def test_unknown_module_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"modules": {"FOOBAR": True}})
        self.assertIn("FOOBAR", mock_log.error.call_args[0][0])

    def test_removed_external_modules_section_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"external_modules": {"skynet": {}}})

    def test_removed_qra_section_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"qra": {"definitions": []}})

    def test_wrong_module_value_type_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"modules": {"RADIO": [1, 2, 3]}})

    def test_bad_enabled_type_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"modules": {"RADIO": {"enabled": "yes"}}})

    def test_bad_settings_type_is_error(self) -> None:
        mock_log, fn = self._patched()
        with self.assertRaises(typer.Abort):
            fn({"modules": {"CTLD": {"enabled": True, "settings": True}}})

    def test_unknown_init_param_is_warning_not_error(self) -> None:
        mock_log, fn = self._patched()
        fn({"modules": {"RADIO": {"init": {"bogus": True}}}})
        mock_log.error.assert_not_called()
        mock_log.warning.assert_called_once()

    def test_known_init_param_no_warning(self) -> None:
        mock_log, fn = self._patched()
        fn({"modules": {"RADIO": {"init": {"help_menus": True}}}})
        mock_log.warning.assert_not_called()


if __name__ == "__main__":
    unittest.main()
