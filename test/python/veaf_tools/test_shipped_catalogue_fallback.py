"""A mission folder with no aircraft catalogue of its own builds with the one the tool ships.

FEAT-DEFAULTS-CATALOGUE-FLOW ticket 01. `prepare` used to copy the 351 KB dynamic-slot catalogue
into every mission folder, and the build read that copy and nothing else. So the copy froze on the
day the folder was created: a folder prepared in June keeps its 104 templates forever, and the
`F-14BU Template` added on 2026-09-21 never reaches it however often its owner updates the tool.

The resolution order these tests pin down:

1. the mission folder's file, when it carries at least one group;
2. otherwise the catalogue shipped with the tool.

An **empty** file is the interesting case. It reads as "I add nothing to the shipped catalogue",
not as "I want nothing" — the latter is `dynamic_slot_templates: false` in `mission.yaml`, and
these tests hold that line apart from the fallback.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from veaf_tools.commands.build import resolve_aircraft_catalogue

_CANDIDATE = "src/dynamic-slot-templates.yaml"
_KEY = "dynamic_slot_templates"

_EMPTY = "airplanes:\n  coalitions: {}\nhelicopters:\n  coalitions: {}\n"


def _populated(name: str) -> str:
    return yaml.safe_dump({"airplanes": {"coalitions": {"blue": {"CJTF Blue": {name: {"name": name}}}}}})


class _Folder:
    """A mission folder with a shipped catalogue under `published/`, as the updater installs it."""

    def __init__(self, tmp: str) -> None:
        self.path = Path(tmp)
        shipped_dir = self.path / "published" / "src" / "defaults" / "mission-folder" / "src"
        shipped_dir.mkdir(parents=True)
        self.shipped = shipped_dir / "dynamic-slot-templates.yaml"
        self.shipped.write_text(_populated("F-14BU Template"), encoding="utf-8")
        (self.path / "src").mkdir()
        self.local = self.path / "src" / "dynamic-slot-templates.yaml"

    def resolve(self, cfg: dict | None = None) -> tuple[Path | None, bool]:
        return resolve_aircraft_catalogue(cfg or {}, self.path, _KEY, _CANDIDATE)


class TestTheShippedCatalogueIsTheFallback(unittest.TestCase):
    def test_no_local_file_uses_the_shipped_one(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp)
            path, shipped = folder.resolve()
        self.assertEqual(path, folder.shipped)
        self.assertTrue(shipped)

    def test_an_empty_local_file_uses_the_shipped_one_too(self) -> None:
        """The 62-byte skeleton means "I add nothing", not "I want nothing"."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp)
            folder.local.write_text(_EMPTY, encoding="utf-8")
            path, shipped = folder.resolve()
        self.assertEqual(path, folder.shipped)
        self.assertTrue(shipped)

    def test_a_populated_local_file_stands_alone(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp)
            folder.local.write_text(_populated("My Own Template"), encoding="utf-8")
            path, shipped = folder.resolve()
        self.assertEqual(path, folder.local)
        self.assertFalse(shipped)

    def test_a_disabled_step_injects_nothing_whatever_is_on_disk(self) -> None:
        for cfg in ({_KEY: False}, {_KEY: {"enabled": False}}):
            with self.subTest(cfg=cfg), TemporaryDirectory() as tmp:
                folder = _Folder(tmp)
                folder.local.write_text(_populated("My Own Template"), encoding="utf-8")
                path, shipped = folder.resolve(cfg)
                self.assertIsNone(path)
                self.assertFalse(shipped)

    def test_a_disabled_step_is_not_resurrected_by_the_fallback(self) -> None:
        """The regression the fallback could introduce: `false` with no local file at all."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp)
            path, _ = folder.resolve({_KEY: False})
        self.assertIsNone(path)

    def test_an_explicit_file_is_taken_at_its_word(self) -> None:
        """Naming a path is a choice; a typo there must skip the step, not inject 128 templates."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp)
            (folder.path / "custom").mkdir()
            (folder.path / "custom" / "mine.yaml").write_text(_populated("Mine"), encoding="utf-8")

            path, shipped = folder.resolve({_KEY: {"file": "custom/mine.yaml"}})
            self.assertEqual(path, folder.path / "custom" / "mine.yaml")
            self.assertFalse(shipped)

            missing, shipped_for_missing = folder.resolve({_KEY: {"file": "custom/typo.yaml"}})
            self.assertIsNone(missing)
            self.assertFalse(shipped_for_missing)

    def test_no_local_file_and_no_shipped_one_skips_the_step(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = Path(tmp) / "bare"
            (folder / "src").mkdir(parents=True)
            path, shipped = resolve_aircraft_catalogue({}, folder, _KEY, "src/nowhere.yaml")
        self.assertIsNone(path)
        self.assertFalse(shipped)


class TestTheRealShippedCatalogueIsReachable(unittest.TestCase):
    """Without `published/`, the dev checkout answers — and it is the file the build would inject."""

    def test_the_dev_checkout_catalogue_is_found_and_populated(self) -> None:
        with TemporaryDirectory() as tmp:
            path, shipped = resolve_aircraft_catalogue({}, Path(tmp), _KEY, _CANDIDATE)
        self.assertIsNotNone(path)
        self.assertTrue(shipped)
        assert path is not None
        self.assertEqual(path.name, "dynamic-slot-templates.yaml")
        self.assertGreater(path.stat().st_size, 100_000)


if __name__ == "__main__":
    unittest.main()
