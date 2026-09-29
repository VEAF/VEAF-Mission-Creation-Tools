"""Every text file veaf-tools opens must name its encoding, and that encoding is UTF-8.

`open(path)` without `encoding=` decodes with the locale's code page: cp1252 on a French or English
Windows, which is where mission makers run veaf-tools. A UTF-8 `presets.yaml` read that way turns
"Nörvenich" into "NÃ¶rvenich", and the injector wrote that name into 127 cockpit radio channels and
every kneeboard page of the GermanyCW Open Training (2026-09-29). The CI runs on Linux, where the
locale is UTF-8, so no behavioural test could see it there: this scan is what can.

Same approach as `test_no_bare_print.py`: parse, do not grep.
"""

from __future__ import annotations

import ast
import builtins
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

_SOURCES = Path(__file__).parents[2] / "src" / "python" / "veaf-tools"


def _text_opens_without_encoding(path: Path) -> list[int]:
    """Return the line numbers of every builtin `open(...)` call in *path* that opens a text file without `encoding=`.

    Binary modes (a literal mode containing "b") need no encoding. Method calls such as `zip_ref.open()`
    are `ast.Attribute` calls and are not reported: only the builtin decodes with the locale.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    lines = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "open"):
            continue
        if any(kw.arg == "encoding" for kw in node.keywords):
            continue
        mode = (
            node.args[1] if len(node.args) > 1 else next((kw.value for kw in node.keywords if kw.arg == "mode"), None)
        )
        if isinstance(mode, ast.Constant) and isinstance(mode.value, str) and "b" in mode.value:
            continue
        lines.append(node.lineno)
    return lines


class TestTextFilesOpenedAsUtf8(unittest.TestCase):
    def test_no_text_file_is_opened_with_the_locale_encoding(self) -> None:
        offenders = [
            f"{path.relative_to(_SOURCES).as_posix()}:{line}"
            for path in sorted(_SOURCES.rglob("*.py"))
            for line in _text_opens_without_encoding(path)
        ]

        self.assertEqual(
            offenders,
            [],
            'pass encoding="utf-8": without it Windows decodes with cp1252 and accented names come out '
            "garbled:\n  " + "\n  ".join(offenders),
        )

    def test_the_scan_reaches_the_sources(self) -> None:
        # An empty offender list must mean "none found", not "nothing looked at".
        files = {path.name for path in _SOURCES.rglob("*.py")}
        self.assertGreater(len(files), 100, "the scan should see the veaf-tools modules")
        self.assertIn("presets_manager.py", files)

    def test_the_detector_ignores_binary_modes_and_methods(self) -> None:
        sample = Path(self.enterContext(tempfile.TemporaryDirectory())) / "sample.py"
        sample.write_text(
            'open(p, "rb")\nz.open(n)\nopen(p, encoding="utf-8")\nopen(p)\nopen(p, mode="w")\n', encoding="utf-8"
        )

        self.assertEqual(_text_opens_without_encoding(sample), [4, 5])


class TestPresetsReadOnACp1252Windows(unittest.TestCase):
    """The defect itself: a presets file read where the locale is cp1252 keeps its accented titles."""

    def test_an_accented_channel_title_survives_a_cp1252_locale(self) -> None:
        from presets_injector import presets_manager

        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "presets.yaml"
        path.write_text(
            textwrap.dedent(
                """\
                channels_collection:
                  bases:
                    Base-Norvenich:
                      title: Nörvenich
                      freqs: { uhf: 270.4 }
                """
            ),
            encoding="utf-8",
        )

        def cp1252_locale_open(file, mode="r", *args, **kwargs):  # what open() does on a French Windows
            if "b" not in mode:
                kwargs.setdefault("encoding", "cp1252")
            return builtins.open(file, mode, *args, **kwargs)

        with mock.patch.object(presets_manager, "open", cp1252_locale_open, create=True):
            manager = presets_manager.PresetsManager()
            manager.read_yaml(path)

        channel = manager.channel_collections["bases"].channel_definitions["Base-Norvenich"]
        self.assertEqual(channel.title, "Nörvenich")


if __name__ == "__main__":
    unittest.main()
