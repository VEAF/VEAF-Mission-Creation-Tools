"""Path resolution utilities shared between veaf-tools entry-points."""

from __future__ import annotations

from pathlib import Path


def resolve_path(
    path: str | Path | None = None,
    default_path: str | Path | None = None,
    should_exist: bool = False,
    create_if_not_exist: bool = False,
) -> Path:
    """Resolve and validate a file path.

    Args:
        path: Preferred path; if falsy, *default_path* is used.
        default_path: Fallback path when *path* is not provided.
        should_exist: If True, abort with an error when the resolved path does not exist.
        create_if_not_exist: If True, create the path (file parent or directory) when missing.

    Returns:
        The resolved, absolute :class:`~pathlib.Path`.
    """
    # Import here to avoid a circular dependency at module load time.
    from veaf_libs.logger import logger  # noqa: PLC0415

    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        logger.error("Either path or default_path must be provided", exception_type=ValueError)
        raise ValueError("unreachable")  # logger.error raises; this satisfies the type-checker

    result = result.resolve()

    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:
            result.mkdir(exist_ok=True)

    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)

    return result


def resolve_mission_file(
    folder: Path,
    name_or_file: str | Path | None = None,
    default_name: str = "mission.miz",
) -> Path:
    """Return the path to a ``.miz`` file inside *folder*.

    Resolution order:
    1. If *name_or_file* is an absolute ``.miz`` path → resolve it directly.
    2. If *name_or_file* has a ``.miz`` suffix → look for it relative to *folder*.
    3. Otherwise → glob ``{name_or_file}*.miz`` inside *folder* and return the
       most-recently modified match.
    4. If *name_or_file* is ``None``, *default_name* is used (step 2).

    Args:
        folder: Mission folder to search in.
        name_or_file: Mission name, filename, or path hint.  May be ``None``.
        default_name: Name to use when *name_or_file* is not provided.

    Returns:
        The resolved, absolute :class:`~pathlib.Path` to the ``.miz`` file.
    """
    if name_or_file is None:
        name_or_file = default_name

    candidate = Path(name_or_file)

    # Absolute .miz path — resolve directly.
    if candidate.is_absolute() and candidate.suffix.lower() == ".miz":
        return candidate.resolve()

    # Relative .miz path (e.g. "mission.miz" or "my_mission.miz").
    if candidate.suffix.lower() == ".miz":
        return resolve_path(path=folder / candidate, should_exist=True)

    # Stem / prefix — find the most-recent match.
    matches = list(folder.glob(f"{candidate.name}*.miz"))
    if matches:
        return max(matches, key=lambda f: f.stat().st_mtime)

    # Last resort: the named path (will fail downstream if actually missing).
    return resolve_path(path=folder / candidate, should_exist=True)
