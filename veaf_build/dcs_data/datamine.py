"""Shared helper to clone the ``Quaggles/dcs-lua-datamine`` repository.

All DCS-derived data providers clone this upstream at a **pinned** ref so that
generation is reproducible: re-running against the same ref always yields the
same artifact. CI relies on this (the per-PR consistency guard re-generates
against the pin and fails on any diff). To pick up a newer DCS data dump, bump
:data:`DATAMINE_REF`, re-run ``veaf-build update-dcs-data --all`` and commit the
resulting artifact changes.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

# A git ref/SHA only ever contains these characters; reject anything else before
# passing it to git (defense in depth — calls already use an argv list, no shell).
_REF_RE = re.compile(r"^[0-9A-Za-z._/-]+$")

DATAMINE_REPO = "https://github.com/Quaggles/dcs-lua-datamine.git"
"""Upstream repository providing dumped DCS database tables."""

DATAMINE_REF = "fe1d8008e6e8dc4c1c4e85558cd1b0b29a02da3f"
"""Pinned upstream commit. Bump (and regenerate) to refresh DCS data."""


def clone_datamine(dest: Path, sparse_paths: list[str], ref: str = DATAMINE_REF) -> None:
    """Sparse-clone the datamine repository at a pinned ref.

    Only the requested ``sparse_paths`` subtrees are materialized, and only the
    single ``ref`` commit is fetched (``--depth=1``), keeping the checkout small.

    Args:
        dest: Directory to clone into. Created if missing; must be empty.
        sparse_paths: Repository subtrees to check out, e.g.
            ``["_G/db/Countries"]``.
        ref: Commit SHA (or tag) to fetch and check out. Defaults to the pinned
            :data:`DATAMINE_REF`.

    Raises:
        ValueError: If *ref* or a sparse path is not a safe git argument.
        subprocess.CalledProcessError: If any underlying git command fails.
    """
    if not _REF_RE.match(ref):
        raise ValueError(f"Unsafe datamine ref: {ref!r}")
    for sparse_path in sparse_paths:
        if not _REF_RE.match(sparse_path):
            raise ValueError(f"Unsafe sparse path: {sparse_path!r}")

    dest.mkdir(parents=True, exist_ok=True)

    def run(*args: str) -> None:
        # argv list + no shell: inputs are validated above and cannot inject.
        subprocess.run(args, cwd=dest, check=True, capture_output=True)  # nosec B603

    run("git", "init", "-q")
    run("git", "remote", "add", "origin", DATAMINE_REPO)
    run("git", "sparse-checkout", "init", "--cone")
    run("git", "sparse-checkout", "set", *sparse_paths)
    run("git", "fetch", "-q", "--depth=1", "--filter=blob:none", "origin", ref)
    run("git", "checkout", "-q", "FETCH_HEAD")
