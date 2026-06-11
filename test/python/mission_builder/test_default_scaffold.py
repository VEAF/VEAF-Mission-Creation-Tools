"""Content checks on the shipped default mission-folder scaffold (IMC-FEEDBACK-2)."""

from __future__ import annotations

from pathlib import Path

# repo root = .../<root>/test/python/mission_builder/this_file → parents[3]
_DEFAULTS = Path(__file__).resolve().parents[3] / "src" / "defaults" / "mission-folder"


class TestDefaultGitignore:
    """The scaffold .gitignore must exclude build output (IMC2-006)."""

    def _content(self) -> str:
        return (_DEFAULTS / ".gitignore").read_text(encoding="utf-8")

    def test_excludes_built_miz(self) -> None:
        assert "*.miz" in self._content()

    def test_excludes_missions_folder(self) -> None:
        assert "/missions/" in self._content()

    def test_no_stale_build_dir(self) -> None:
        # build.py only writes to <mission>/missions/, never a /build/ folder.
        assert "/build/" not in self._content()

    def test_still_excludes_published_and_exe(self) -> None:
        content = self._content()
        assert "/published/" in content
        assert "/veaf*.exe" in content


class TestNoReadmeShipped:
    """No README is shipped in the default scaffold (IMC2-002)."""

    def test_scaffold_has_no_readme(self) -> None:
        readmes = [p.name for p in _DEFAULTS.rglob("*") if p.is_file() and p.name.lower().startswith("readme")]
        assert readmes == [], f"unexpected README(s) in defaults scaffold: {readmes}"
