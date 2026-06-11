"""Content checks on the shipped default mission-folder scaffold (IMC-FEEDBACK-2)."""

from __future__ import annotations

from pathlib import Path

import yaml

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


class TestEmptyAircraftDefaults:
    """The default spawnables / dynamic-slot-templates must ship NO groups.

    A fresh mission inherits these files; if they carry a demo roster, every build
    injects dozens of late-activation client slots, and taking one shows the DCS
    "YOUR FLIGHT IS DELAYED TO START" message (FIX-DEFAULTS-AIRCRAFT-ROSTER).
    """

    def _group_count(self, name: str) -> int:
        data = yaml.safe_load((_DEFAULTS / "src" / name).read_text(encoding="utf-8")) or {}
        total = 0
        for kind in ("airplanes", "helicopters"):
            coalitions = (data.get(kind) or {}).get("coalitions") or {}
            for countries in coalitions.values():
                for groups in (countries or {}).values():
                    total += len(groups or {})
        return total

    def test_spawnables_default_is_empty(self) -> None:
        assert self._group_count("spawnables.yaml") == 0

    def test_dynamic_slot_templates_default_is_empty(self) -> None:
        assert self._group_count("dynamic-slot-templates.yaml") == 0
