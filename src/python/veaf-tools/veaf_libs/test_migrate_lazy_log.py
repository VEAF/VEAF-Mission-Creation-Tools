"""Tests for migrate_lazy_log — pure regex line-transformation functions."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_libs.migrate_lazy_log import _is_comment_line, _migrate_file, _migrate_line, _should_skip


class TestIsCommentLine(unittest.TestCase):
    def test_lua_comment(self) -> None:
        self.assertTrue(_is_comment_line("-- this is a comment"))

    def test_indented_lua_comment(self) -> None:
        self.assertTrue(_is_comment_line("    -- indented comment"))

    def test_non_comment(self) -> None:
        self.assertFalse(_is_comment_line("local x = 1"))

    def test_empty_line(self) -> None:
        self.assertFalse(_is_comment_line(""))

    def test_line_with_comment_after_code(self) -> None:
        self.assertFalse(_is_comment_line("local x = 1 -- comment"))


class TestShouldSkip(unittest.TestCase):
    def test_comment_line_skipped(self) -> None:
        self.assertTrue(_should_skip("-- veaf.p(x)"))

    def test_veaf_p_definition_skipped(self) -> None:
        self.assertTrue(_should_skip("function veaf.p("))

    def test_veaf_lp_definition_skipped(self) -> None:
        self.assertTrue(_should_skip("function veaf.lp("))

    def test_veaf__p_definition_skipped(self) -> None:
        self.assertTrue(_should_skip("function veaf._p("))

    def test_format_text_internal_skipped(self) -> None:
        self.assertTrue(_should_skip("    pArgs[i] = veaf.p("))

    def test_text_equals_veaf_p_skipped(self) -> None:
        self.assertTrue(_should_skip("text = veaf.p("))

    def test_return_veaf_p_self_skipped(self) -> None:
        self.assertTrue(_should_skip("    return veaf.p(self._v)"))

    def test_normal_code_not_skipped(self) -> None:
        self.assertFalse(_should_skip('    logger:trace("msg", veaf.p(x))'))


class TestMigrateLine(unittest.TestCase):
    def test_trace_log_line_migrated(self) -> None:
        line = '    logger:trace("msg %s", veaf.p(someTable))\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 1)
        self.assertIn("veaf.lp(", new_line)
        self.assertNotIn("veaf.p(", new_line)

    def test_debug_log_line_migrated(self) -> None:
        line = '    veaf.loggers.get("MOD"):debug("val: %s", veaf.p(val))\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 1)
        self.assertIn("veaf.lp(", new_line)

    def test_comment_line_not_migrated(self) -> None:
        line = "-- logger:trace(veaf.p(x))\n"
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 0)
        self.assertEqual(new_line, line)

    def test_info_line_not_migrated(self) -> None:
        line = '    logger:info("msg %s", veaf.p(x))\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 0)
        self.assertEqual(new_line, line)

    def test_warn_line_not_migrated(self) -> None:
        line = '    logger:warn("msg %s", veaf.p(x))\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 0)
        self.assertEqual(new_line, line)

    def test_line_without_veaf_p_unchanged(self) -> None:
        line = '    logger:trace("constant message")\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 0)
        self.assertEqual(new_line, line)

    def test_continuation_arg_migrated(self) -> None:
        line = "    veaf.p(someTable),\n"
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 1)
        self.assertIn("veaf.lp(", new_line)

    def test_continuation_arg_with_close_paren(self) -> None:
        line = "    veaf.p(someTable))\n"
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 1)
        self.assertIn("veaf.lp(", new_line)

    def test_multiple_veaf_p_in_one_line(self) -> None:
        line = '    logger:debug("a=%s b=%s", veaf.p(a), veaf.p(b))\n'
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 2)
        self.assertEqual(new_line.count("veaf.lp("), 2)

    def test_skip_pattern_line_not_migrated(self) -> None:
        line = "function veaf.p(\n"
        new_line, count = _migrate_line(line)
        self.assertEqual(count, 0)


class TestMigrateFile(unittest.TestCase):
    def test_dry_run_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "test.lua"
            original = '    logger:trace("msg", veaf.p(x))\n'
            path.write_text(original, encoding="utf-8")
            count, residuals = _migrate_file(path, dry_run=True)
            self.assertEqual(count, 1)
            self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_write_mode_updates_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "test.lua"
            path.write_text('    logger:trace("msg", veaf.p(x))\n', encoding="utf-8")
            count, _ = _migrate_file(path, dry_run=False)
            self.assertEqual(count, 1)
            self.assertIn("veaf.lp(", path.read_text(encoding="utf-8"))

    def test_no_changes_file_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "clean.lua"
            original = 'logger:info("hello world")\n'
            path.write_text(original, encoding="utf-8")
            count, residuals = _migrate_file(path, dry_run=False)
            self.assertEqual(count, 0)
            self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_residuals_reported_for_non_log_veaf_p(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "residual.lua"
            # veaf.p() in a non-log context should be a residual
            path.write_text('local x = string.format("%s", veaf.p(y))\n', encoding="utf-8")
            count, residuals = _migrate_file(path, dry_run=True)
            self.assertEqual(count, 0)
            self.assertEqual(len(residuals), 1)

    def test_multiple_lines_processed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "multi.lua"
            content = (
                '    logger:trace("a=%s", veaf.p(a))\n'
                '    logger:debug("b=%s", veaf.p(b))\n'
                '    logger:info("c=%s", veaf.p(c))\n'
            )
            path.write_text(content, encoding="utf-8")
            count, _ = _migrate_file(path, dry_run=False)
            # trace and debug are migrated; info is not
            self.assertEqual(count, 2)


if __name__ == "__main__":
    unittest.main()
