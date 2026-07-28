"""Tests for veaf_libs.mission_input — resolving a `.miz` or a release `.zip`.

Lekaa now ships Foothold as a release **zip** bundling the `.miz` with a config-manager
executable, a manual and a shortcut, so `convert-other` must accept the archive the user
downloaded (FEAT-FOOTHOLD-RELEASE-INTAKE-002).
"""

import unittest
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.mission_input import AmbiguousMissionInput, resolve_input_miz


def _zip(path: Path, members: dict[str, bytes]) -> Path:
    """Write a zip at *path* holding *members* (``arcname -> bytes``)."""
    with zipfile.ZipFile(path, "w") as zf:
        for name, payload in members.items():
            zf.writestr(name, payload)
    return path


class TestResolveMizPath(unittest.TestCase):
    def test_plain_miz_is_yielded_unchanged(self) -> None:
        with TemporaryDirectory() as td:
            miz = Path(td) / "mission.miz"
            miz.write_bytes(b"not really a miz")
            with resolve_input_miz(miz) as resolved:
                self.assertEqual(resolved, miz)

    def test_plain_miz_is_not_deleted_afterwards(self) -> None:
        # The user's own file must survive: only extracted copies are cleaned up.
        with TemporaryDirectory() as td:
            miz = Path(td) / "mission.miz"
            miz.write_bytes(b"payload")
            with resolve_input_miz(miz):
                pass
            self.assertTrue(miz.exists())

    def test_suffix_match_is_case_insensitive(self) -> None:
        with TemporaryDirectory() as td:
            miz = Path(td) / "Mission.MIZ"
            miz.write_bytes(b"payload")
            with resolve_input_miz(miz) as resolved:
                self.assertEqual(resolved, miz)


class TestResolveFromArchive(unittest.TestCase):
    def test_extracts_the_single_miz(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(
                Path(td) / "Foothold_CA_4.4.1.zip",
                {
                    "Foothold_CA_4.4.1.miz": b"mission bytes",
                    "Foothold Config Manager 1.8.5.exe": b"exe",
                    "Foothold_Manual_v1.8.pdf": b"pdf",
                    "Getting Started.url": b"url",
                },
            )
            with resolve_input_miz(archive) as resolved:
                self.assertEqual(resolved.name, "Foothold_CA_4.4.1.miz")
                self.assertEqual(resolved.read_bytes(), b"mission bytes")

    def test_finds_a_miz_nested_in_a_folder(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"Foothold_CA/mission.miz": b"m", "Foothold_CA/readme.txt": b"t"})
            with resolve_input_miz(archive) as resolved:
                self.assertEqual(resolved.name, "mission.miz")
                self.assertEqual(resolved.read_bytes(), b"m")

    def test_extracted_copy_is_cleaned_up(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"m.miz": b"m"})
            with resolve_input_miz(archive) as resolved:
                extracted = resolved
                self.assertTrue(extracted.exists())
            self.assertFalse(extracted.exists())
            self.assertFalse(extracted.parent.exists())

    def test_cleaned_up_even_when_the_body_raises(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"m.miz": b"m"})
            extracted: Path | None = None
            with self.assertRaises(RuntimeError):
                with resolve_input_miz(archive) as resolved:
                    extracted = resolved
                    raise RuntimeError("boom")
            assert extracted is not None
            self.assertFalse(extracted.exists())

    def test_only_the_miz_is_written_to_disk(self) -> None:
        # We never want the config-manager .exe landing anywhere on the user's disk.
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"m.miz": b"m", "Config Manager.exe": b"exe", "manual.pdf": b"pdf"})
            with resolve_input_miz(archive) as resolved:
                siblings = sorted(p.name for p in resolved.parent.rglob("*") if p.is_file())
                self.assertEqual(siblings, ["m.miz"])

    def test_no_miz_in_archive_raises_with_empty_candidates(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"readme.txt": b"t", "manual.pdf": b"p"})
            with self.assertRaises(AmbiguousMissionInput) as ctx:
                with resolve_input_miz(archive):
                    pass
            self.assertEqual(ctx.exception.candidates, ())

    def test_several_miz_raises_listing_them_sorted(self) -> None:
        # Never guess which mission the user meant.
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "r.zip", {"b.miz": b"b", "a.miz": b"a"})
            with self.assertRaises(AmbiguousMissionInput) as ctx:
                with resolve_input_miz(archive):
                    pass
            self.assertEqual(ctx.exception.candidates, ("a.miz", "b.miz"))

    def test_extraction_dir_is_short(self) -> None:
        # Windows path-length guard (see FIX-LONG-FILENAMES-WINDOWS): the temp dir must
        # not be derived from Foothold's very long asset names.
        long_name = "Foothold_SI_extended_4.4.1_Multi_Language_Coldwar-Modern_Vietnam"
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / f"{long_name}.zip", {f"{long_name}.miz": b"m"})
            with resolve_input_miz(archive) as resolved:
                self.assertNotIn(long_name, str(resolved.parent))


if __name__ == "__main__":
    unittest.main()
