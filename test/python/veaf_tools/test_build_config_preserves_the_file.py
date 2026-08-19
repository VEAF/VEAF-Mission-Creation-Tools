"""Tests that persisting `build:` does not eat the rest of `mission.yaml`.

`FIX-BUILD-YAML-TRUNCATION`. `_update_build_config_in_yaml` bounded its replacement at the end of the
**file** rather than at the end of its own section: `content = content[:idx]` discarded everything from
the build marker onward. Reproduced on 2026-08-19 with the shape that cost three evenings — a
`security:` block with its password hashes, and the maker's trailing comment, all gone in one call.

The fixtures here are that shape, not a synthetic one. Nothing in the suite covered it because every
existing test put `build:` last, which is where the first build leaves it — the damage starts the moment
a maker adds anything after it, which is the natural thing to do when the file ends there.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_tools.helpers import _update_build_config_in_yaml
from writer_preservation import assert_preserved, assert_round_trip_identical

_SECTION_AFTER_BUILD = """# A mission config a maker edits by hand.
theatre: Caucasus

modules:
  COMBATZONE:
    enabled: true

# ── Build configuration ─────────────────────────────────────────────────────
# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.
# Note: scripts_path is usually machine-specific.
#
build:
  dev_mode: false

# ── Security ────────────────────────────────────────────────────────────────
security:
  password_hashes:
    L1: ["deadbeef"]

# A trailing comment a maker wrote last.
"""

_BUILD_LAST = """theatre: Caucasus

# ── Build configuration ─────────────────────────────────────────────────────
# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.
# Note: scripts_path is usually machine-specific.
#
build:
  dev_mode: true
"""

_HEADER_WITHOUT_KEY = """theatre: Caucasus

# ── Build configuration ─────────────────────────────────────────────────────
# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.
#

security:
  password_hashes:
    L1: ["deadbeef"]
"""

_NO_MARKER = """theatre: Caucasus

security:
  password_hashes:
    L1: ["deadbeef"]
"""


def _yaml(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "mission.yaml"
    path.write_text(text, encoding="utf-8", newline="\n")
    return path


class TestASectionAfterBuildSurvives:
    """The reproduction itself."""

    def test_the_security_block_and_the_trailing_comment_are_kept(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        assert_preserved(
            path,
            lambda: _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None),
            "# ── Security",
            "security:",
            "password_hashes",
            "deadbeef",
            "# A trailing comment a maker wrote last.",
            label="_update_build_config_in_yaml",
        )

    def test_the_build_flag_is_still_updated(self, tmp_path: Path) -> None:
        # Preserving the tail is worthless if the section stops doing its job.
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        assert "dev_mode: true" in path.read_text(encoding="utf-8")
        assert "dev_mode: false" not in path.read_text(encoding="utf-8")

    def test_the_build_section_is_not_duplicated(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        assert path.read_text(encoding="utf-8").count("build:") == 1

    def test_the_sections_keep_their_order(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        text = path.read_text(encoding="utf-8")
        assert text.index("build:") < text.index("security:")

    def test_repeated_builds_do_not_accumulate_blank_lines(self, tmp_path: Path) -> None:
        # A maker builds many times a day; growing the file by a line each time is its own defect.
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        once = path.read_text(encoding="utf-8")
        for _ in range(3):
            _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        assert path.read_text(encoding="utf-8") == once


class TestTheWriterReproducesItsOwnInput:
    """The round-trip question, asked of the writer rather than of the defect."""

    def test_build_last_round_trips_identically(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _BUILD_LAST)
        assert_round_trip_identical(
            path,
            lambda: _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None),
            label="_update_build_config_in_yaml",
        )

    def test_a_file_with_a_section_after_build_round_trips_identically(self, tmp_path: Path) -> None:
        # Same file, written back with the settings it already declares: nothing may move.
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        assert_round_trip_identical(
            path,
            lambda: _update_build_config_in_yaml(path, dev_mode=False, scripts_path=None),
            label="_update_build_config_in_yaml",
        )

    def test_a_scripts_path_round_trips_identically(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _BUILD_LAST)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=Path("D:/dev/scripts"))
        assert_round_trip_identical(
            path,
            lambda: _update_build_config_in_yaml(path, dev_mode=True, scripts_path=Path("D:/dev/scripts")),
            label="_update_build_config_in_yaml",
        )


class TestTheShapesThatCouldGoWrong:
    def test_a_marker_with_no_build_key_does_not_eat_the_next_section(self, tmp_path: Path) -> None:
        # A maker deleted the key and kept the header. Consuming "the indented block" from there
        # would swallow `security:` — which is the original defect wearing a different hat.
        path = _yaml(tmp_path, _HEADER_WITHOUT_KEY)
        assert_preserved(
            path,
            lambda: _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None),
            "security:",
            "deadbeef",
            label="_update_build_config_in_yaml",
        )

    def test_a_file_with_no_marker_gets_the_section_appended(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, _NO_MARKER)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        text = path.read_text(encoding="utf-8")
        assert "build:" in text
        assert "deadbeef" in text
        assert text.index("security:") < text.index("build:")

    def test_an_empty_file_gets_the_section(self, tmp_path: Path) -> None:
        path = _yaml(tmp_path, "")
        _update_build_config_in_yaml(path, dev_mode=False, scripts_path=None)
        assert "dev_mode: false" in path.read_text(encoding="utf-8")

    def test_the_result_still_parses_as_yaml(self, tmp_path: Path) -> None:
        yaml = pytest.importorskip("yaml")
        path = _yaml(tmp_path, _SECTION_AFTER_BUILD)
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        parsed = yaml.safe_load(path.read_text(encoding="utf-8"))
        assert parsed["build"]["dev_mode"] is True
        assert parsed["security"]["password_hashes"]["L1"] == ["deadbeef"]
        assert parsed["modules"]["COMBATZONE"]["enabled"] is True


class TestLineEndings:
    """The second defect, found by the round-trip helper on its first use.

    `write_text` with no `newline` lets Python translate every `\n` to `os.linesep`, so on Windows a
    call meant to touch one section came back with **every line of the file changed** — measured
    2026-08-19: an LF fixture of 11 lines returned as 11 CRLF lines. Every `mission.yaml` in this
    repository is LF, and a maker's `git diff` after one `build --dev-mode` showed the whole file.
    """

    def test_an_lf_file_stays_lf(self, tmp_path: Path) -> None:
        path = tmp_path / "mission.yaml"
        path.write_bytes(_SECTION_AFTER_BUILD.encode("utf-8"))
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        assert b"\r\n" not in path.read_bytes()

    def test_the_appended_section_is_lf_too(self, tmp_path: Path) -> None:
        path = tmp_path / "mission.yaml"
        path.write_bytes(_NO_MARKER.encode("utf-8"))
        _update_build_config_in_yaml(path, dev_mode=True, scripts_path=None)
        assert b"\r\n" not in path.read_bytes()


class TestSaveYamlKeepsLineEndings:
    """`mission_yaml_editor.save_yaml` had the same construction, and the MCP composites use it."""

    def test_a_round_trip_through_save_yaml_stays_lf(self, tmp_path: Path) -> None:
        from mission_tools.mission_yaml_editor import load_yaml, save_yaml

        path = tmp_path / "mission.yaml"
        path.write_bytes(_SECTION_AFTER_BUILD.encode("utf-8"))
        save_yaml(path, load_yaml(path))
        assert b"\r\n" not in path.read_bytes()
