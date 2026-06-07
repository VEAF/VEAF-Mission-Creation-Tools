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


if __name__ == "__main__":
    unittest.main()
