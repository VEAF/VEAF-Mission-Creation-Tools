"""Ask a writer whether it preserved what it did not mean to change.

Three defects of that family surfaced on 2026-08-17 alone, and all three were silent — each found by
accident rather than by a test:

===========================================  =============================================  ======
Writer                                       What it destroyed                              Caught
===========================================  =============================================  ======
``warehouses_bootstrap``                     the mission's own airfields, coalitions, stock yes
``coalition_placeholder``                    nothing — it raised, the lucky version         no
``_update_build_config_in_yaml``             any ``mission.yaml`` after the build marker    yes
===========================================  =============================================  ======

Two of the three would have been caught by one question asked of the writer itself rather than of the
defect: *invoked with nothing to change, do you reproduce your input byte for byte?* A writer that
cannot is destroying something, whatever it believes it is doing.

That is :func:`assert_round_trip_identical`. :func:`assert_preserved` is its companion for the case
where the writer **must** change one section: it still has to leave everything else alone.

Sweeping every writer in the repository with the identity check is deliberately not done here — see
``.backlog/FIX-BUILD-YAML-TRUNCATION/tickets/02-writer-preservation-helper.md``. The helper existing is
what makes that a cheap lot later rather than an open-ended audit now.
"""

from __future__ import annotations

import difflib
from collections.abc import Callable
from pathlib import Path

__all__ = ["assert_preserved", "assert_round_trip_identical"]

#: How many diff lines to show before truncating. Enough to name what was lost without burying it.
_DIFF_LINES = 40


def assert_round_trip_identical(path: Path, writer: Callable[[], object], *, label: str = "") -> None:
    """Assert that `writer`, given nothing to change, leaves `path` byte-identical.

    Args:
        path: The file the writer rewrites in place.
        writer: A no-argument callable invoking the writer with its **current** settings, so the only
            correct outcome is the file it was handed.
        label: Optional name for the writer, used in the failure message.

    Raises:
        AssertionError: If the bytes changed, with a unified diff naming the lines lost or added.
    """
    before = path.read_bytes()
    writer()
    after = path.read_bytes()
    if before == after:
        return

    who = label or path.name
    raise AssertionError(
        f"{who} did not reproduce its own input: it changed the file although nothing was asked of it.\n"
        f"{_diff(before, after, path.name)}"
    )


def assert_preserved(path: Path, mutate: Callable[[], object], *needles: str, label: str = "") -> None:
    """Assert that everything in `needles` is still in `path` after an intended change.

    The companion to :func:`assert_round_trip_identical` for a writer that legitimately rewrites one
    section: identity cannot hold, but the rest of the file must survive.

    Args:
        path: The file the writer rewrites in place.
        mutate: A no-argument callable performing the intended change.
        *needles: Substrings that must still be present afterwards — the content the writer had no
            business touching.
        label: Optional name for the writer, used in the failure message.

    Raises:
        AssertionError: If any needle is gone, naming every one that is.
    """
    before = path.read_text(encoding="utf-8")
    missing_upfront = [needle for needle in needles if needle not in before]
    assert not missing_upfront, (
        f"the fixture does not contain {missing_upfront!r} to begin with, so this test would pass "
        "whatever the writer does"
    )

    mutate()
    after = path.read_text(encoding="utf-8")
    lost = [needle for needle in needles if needle not in after]
    if not lost:
        return

    who = label or path.name
    raise AssertionError(
        f"{who} destroyed content it was not asked to change: {lost!r} are gone.\n"
        f"{_diff(before.encode('utf-8'), after.encode('utf-8'), path.name)}"
    )


def _diff(before: bytes, after: bytes, name: str) -> str:
    """Render a truncated unified diff, so a failure names the lost lines rather than merely differing."""
    lines = list(
        difflib.unified_diff(
            before.decode("utf-8", errors="replace").splitlines(keepends=True),
            after.decode("utf-8", errors="replace").splitlines(keepends=True),
            fromfile=f"{name} (before)",
            tofile=f"{name} (after)",
            n=1,
        )
    )
    shown = "".join(lines[:_DIFF_LINES])
    if len(lines) > _DIFF_LINES:
        shown += f"... ({len(lines) - _DIFF_LINES} more diff lines)\n"
    return shown
