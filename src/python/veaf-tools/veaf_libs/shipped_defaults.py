"""Where the defaults shipped with the tool live, for whoever needs to read them.

``prepare`` has always resolved this scaffold to copy it into a mission folder. Since
FEAT-DEFAULTS-CATALOGUE-FLOW the build reads it too — a mission folder with no aircraft
catalogue of its own falls back to the shipped one — and so does the ``pull-aircraft-groups``
command. Three callers, one resolution order, hence this module.
"""

from __future__ import annotations

from pathlib import Path


def defaults_source_candidates(mission_folder: Path) -> list[Path]:
    """Ordered locations to look for the default mission-folder scaffold.

    The defaults ship in ``published.zip`` and are installed by the updater into
    ``<mission>/published/`` — so that is the primary location and the only one that works
    from the packaged exe (where ``__file__`` lives in a PyInstaller temp dir). The
    dev-checkout path is the fallback.

    Args:
        mission_folder: The folder being prepared or built.

    Returns:
        Candidate ``defaults/mission-folder`` directories, most-preferred first.
    """
    return [
        # Installed by the updater from published.zip
        mission_folder / "published" / "src" / "defaults" / "mission-folder",
        # Dev checkout: <repo>/src/defaults/mission-folder
        Path(__file__).resolve().parents[3] / "defaults" / "mission-folder",
    ]


def resolve_defaults_source(mission_folder: Path) -> Path | None:
    """Return the first existing default-scaffold directory, or ``None``.

    Args:
        mission_folder: The folder being prepared or built.

    Returns:
        The scaffold directory, or ``None`` when neither candidate exists.
    """
    for candidate in defaults_source_candidates(mission_folder):
        if candidate.is_dir():
            return candidate
    return None


def shipped_default_file(mission_folder: Path, relative: str) -> Path | None:
    """Return one file of the shipped scaffold, or ``None`` when it is not there.

    Args:
        mission_folder: The folder being prepared or built.
        relative: The file's path inside the scaffold, e.g. ``src/spawnables.yaml``.

    Returns:
        The existing shipped file, or ``None``.
    """
    source = resolve_defaults_source(mission_folder)
    if source is None:
        return None
    candidate = source / relative
    return candidate if candidate.is_file() else None
