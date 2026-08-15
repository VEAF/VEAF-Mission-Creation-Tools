"""SECREV-2 / VMR-048 — commenting out an extracted block started at the match, not the line.

`_comment_out_span` prefixes every line of `content[start:end]` with the extraction marker. Its one
caller passes the offsets of a *regex match*, which need not sit at a line boundary — unlike
`_extract_inline_value`, which carefully expands to the whole line before commenting it.

Consequence at the tail: `end` lands right after the table's closing brace, so anything following
it **on that same line** ends up behind the `--` marker and stops being code. At the head, the
marker is inserted mid-line, which reads as if the leading statement had been extracted too.
"""

from __future__ import annotations

import unittest

from mission_builder.config_migrator import ConfigMigrator

MARKER = "-- [v6 extracted to mission.yaml]"


def _comment(content: str, start: int, end: int) -> str:
    return ConfigMigrator()._comment_out_span(content, start, end, "test.Table")


class TestCommentOutSpanKeepsSurroundingCode(unittest.TestCase):
    def test_a_span_on_its_own_lines_is_commented(self) -> None:
        # The baseline shape, which is what the caller produces in practice.
        content = "before()\nblock = {\n  1,\n}\nafter()\n"
        start = content.index("block")
        end = content.index("}") + 1
        result = _comment(content, start, end)
        self.assertIn(f"{MARKER} block = {{", result)
        self.assertIn("before()", result)
        self.assertTrue(any(line.strip() == "after()" for line in result.splitlines()), result)

    def test_code_following_the_closing_brace_stays_code(self) -> None:
        content = "block = {\n  1,\n} local keep = 1\n"
        start = content.index("block")
        end = content.index("}") + 1
        result = _comment(content, start, end)
        keep_line = next(line for line in result.splitlines() if "local keep = 1" in line)
        self.assertFalse(
            keep_line.lstrip().startswith("--"),
            f"the trailing statement was swallowed by the comment: {keep_line!r}",
        )

    def test_code_preceding_the_span_stays_code(self) -> None:
        content = "local keep = 1; block = {\n  1,\n}\n"
        start = content.index("block")
        end = content.index("}") + 1
        result = _comment(content, start, end)
        keep_line = next(line for line in result.splitlines() if "local keep = 1" in line)
        self.assertFalse(
            keep_line.lstrip().startswith("--"),
            f"the leading statement must not be commented out: {keep_line!r}",
        )
        self.assertNotIn(
            f"local keep = 1; {MARKER}",
            result,
            "the marker was inserted mid-line, so the leading statement reads as extracted",
        )

    def test_every_line_of_the_block_is_marked(self) -> None:
        # The control: the function must still do its actual job.
        content = "block = {\n  1,\n  2,\n}\n"
        start = content.index("block")
        end = content.index("}") + 1
        result = _comment(content, start, end)
        for fragment in ("block = {", "1,", "2,", "}"):
            self.assertTrue(
                any(line.strip().startswith(MARKER) and fragment in line for line in result.splitlines()),
                f"{fragment!r} was not commented out:\n{result}",
            )

    def test_the_result_is_still_valid_lua_shaped_text(self) -> None:
        # No line may carry active code after a marker on the same line.
        content = "local keep = 1; block = {\n  1,\n} local also = 2\n"
        start = content.index("block")
        end = content.index("}") + 1
        for line in _comment(content, start, end).splitlines():
            if MARKER in line:
                self.assertTrue(
                    line.lstrip().startswith("--"),
                    f"active code shares a line with the marker: {line!r}",
                )


if __name__ == "__main__":
    unittest.main()
