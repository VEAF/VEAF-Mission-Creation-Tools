"""A prompt must never turn a successful run into a failure (FIX-ABOUT-NONINTERACTIVE).

``veaf-tools about`` asked "open the website?" unconditionally. With no keyboard — a CI job, a
batch file, a piped invocation — Click cannot read the answer, prints ``Aborted.`` and exits **1**.
The exit code was reported twice as a defect of the Windows executable; it was this prompt, on a
binary that was otherwise fine.

These tests pin both halves: no terminal → no prompt and a clean exit, a terminal → the question is
still asked and its answer still honoured.
"""

from __future__ import annotations

import contextlib
import unittest
from unittest.mock import patch

from typer.testing import CliRunner
from veaf_tools.helpers import confirm, is_interactive


class _Stream:
    """A stand-in for ``sys.stdin`` / ``sys.stdout`` with a chosen ``isatty``."""

    def __init__(self, tty: bool) -> None:
        self._tty = tty

    def isatty(self) -> bool:
        return self._tty


def _streams(*, stdin: bool, stdout: bool):
    return (
        patch("veaf_tools.helpers.sys.stdin", _Stream(stdin)),
        patch("veaf_tools.helpers.sys.stdout", _Stream(stdout)),
    )


class TestIsInteractive(unittest.TestCase):
    """Both channels are needed: one to show the question, one to read the answer."""

    def test_true_when_both_streams_are_a_terminal(self) -> None:
        with contextlib.ExitStack() as stack:
            for ctx in _streams(stdin=True, stdout=True):
                stack.enter_context(ctx)
            self.assertTrue(is_interactive())

    def test_false_when_stdin_is_redirected(self) -> None:
        # `veaf-tools about < /dev/null`: nobody can answer.
        with contextlib.ExitStack() as stack:
            for ctx in _streams(stdin=False, stdout=True):
                stack.enter_context(ctx)
            self.assertFalse(is_interactive())

    def test_false_when_stdout_is_captured(self) -> None:
        # `veaf-tools about > out.txt`: the question would go to the file and the run would hang
        # waiting for an answer to a question nobody saw.
        with contextlib.ExitStack() as stack:
            for ctx in _streams(stdin=True, stdout=False):
                stack.enter_context(ctx)
            self.assertFalse(is_interactive())

    def test_survives_a_stream_that_has_no_isatty(self) -> None:
        """A replaced stream (a windowed PyInstaller build) may not expose ``isatty`` at all."""

        class _Bare:
            pass

        with patch("veaf_tools.helpers.sys.stdin", _Bare()):
            self.assertFalse(is_interactive())


class TestConfirm(unittest.TestCase):
    def test_does_not_ask_without_a_terminal(self) -> None:
        with (
            patch("veaf_tools.helpers.is_interactive", return_value=False),
            patch("veaf_tools.helpers.typer.confirm") as asked,
        ):
            self.assertFalse(confirm("open?"))
            asked.assert_not_called()

    def test_unattended_answer_defaults_to_the_prompt_default(self) -> None:
        with patch("veaf_tools.helpers.is_interactive", return_value=False):
            self.assertTrue(confirm("open?", default=True))
            self.assertFalse(confirm("open?", default=False))

    def test_unattended_answer_can_differ_from_the_prompt_default(self) -> None:
        # `--readme` asks for the documentation explicitly; unattended it is printed even though a
        # hurried human gets "no" on a bare Enter.
        with patch("veaf_tools.helpers.is_interactive", return_value=False):
            self.assertTrue(confirm("show the doc?", default=False, unattended=True))

    def test_asks_when_a_terminal_is_attached(self) -> None:
        with (
            patch("veaf_tools.helpers.is_interactive", return_value=True),
            patch("veaf_tools.helpers.typer.confirm", return_value=True) as asked,
        ):
            self.assertTrue(confirm("open?", default=False, unattended=True))
            asked.assert_called_once_with("open?", default=False)

    def test_honours_a_no_from_the_user(self) -> None:
        with (
            patch("veaf_tools.helpers.is_interactive", return_value=True),
            patch("veaf_tools.helpers.typer.confirm", return_value=False),
        ):
            self.assertFalse(confirm("open?", unattended=True))


class TestAboutCommand(unittest.TestCase):
    """The command the report was filed against."""

    def setUp(self) -> None:
        from veaf_tools import app as app_mod
        from veaf_tools.commands import about as about_mod  # noqa: F401  (registers the command)

        self.app = app_mod.app
        self.runner = CliRunner()

    def test_exits_zero_and_prints_its_content_without_a_terminal(self) -> None:
        with patch("veaf_tools.helpers.is_interactive", return_value=False):
            result = self.runner.invoke(self.app, ["about"], input="")
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("veaf.org", result.output)
        self.assertNotIn("Aborted", result.output)

    def test_does_not_launch_the_browser_without_a_terminal(self) -> None:
        with (
            patch("veaf_tools.helpers.is_interactive", return_value=False),
            patch("veaf_tools.commands.about.typer.launch") as launch,
        ):
            result = self.runner.invoke(self.app, ["about"], input="")
        self.assertEqual(result.exit_code, 0, result.output)
        launch.assert_not_called()

    def test_still_opens_the_site_when_a_human_answers_yes(self) -> None:
        with (
            patch("veaf_tools.helpers.is_interactive", return_value=True),
            patch("veaf_tools.helpers.typer.confirm", return_value=True),
            patch("veaf_tools.commands.about.typer.launch") as launch,
        ):
            result = self.runner.invoke(self.app, ["about"])
        self.assertEqual(result.exit_code, 0, result.output)
        launch.assert_called_once_with("https://www.veaf.org")


class TestReadmeOption(unittest.TestCase):
    """``--readme`` carried the same abort: same prompt, same exit 1, seven commands."""

    def setUp(self) -> None:
        from veaf_tools import app as app_mod
        from veaf_tools.commands import (  # noqa: F401  (registers the commands)
            aircraft_groups,
            build,
            extract,
            inject_presets,
            waypoints,
            weather,
        )

        self.app = app_mod.app
        self.runner = CliRunner()

    def test_every_readme_exits_zero_without_a_terminal(self) -> None:
        commands = [
            "extract",
            "inject-presets",
            "extract-aircraft-groups",
            "build",
            "inject-waypoints",
            "extract-waypoints",
            "inject-weather",
        ]
        for name in commands:
            with self.subTest(command=name):
                with patch("veaf_tools.helpers.is_interactive", return_value=False):
                    result = self.runner.invoke(self.app, [name, "--readme"], input="")
                # A wrong command name surfaces here as exit 2 / "No such command".
                self.assertEqual(result.exit_code, 0, result.output)
                self.assertNotIn("Aborted", result.output)


if __name__ == "__main__":
    unittest.main()
