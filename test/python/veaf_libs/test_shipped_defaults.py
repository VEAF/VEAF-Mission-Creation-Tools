"""Where a shipped default folder is found: beside the installed executable, else in the checkout."""

from pathlib import Path

from veaf_libs.shipped_defaults import shipped_defaults_dir

REPO_DEFAULTS = Path(__file__).resolve().parents[3] / "src" / "defaults"


def test_the_folder_installed_beside_the_executable_comes_first(tmp_path: Path) -> None:
    installed = tmp_path / "published" / "src" / "defaults" / "campaign-folder-persistent"
    installed.mkdir(parents=True)

    assert shipped_defaults_dir("campaign-folder-persistent", tmp_path) == installed


def test_the_checkout_is_the_fallback(tmp_path: Path) -> None:
    assert shipped_defaults_dir("campaign-folder-persistent", tmp_path) == REPO_DEFAULTS / "campaign-folder-persistent"


def test_a_folder_shipped_nowhere_is_none(tmp_path: Path) -> None:
    assert shipped_defaults_dir("no-such-folder", tmp_path) is None
