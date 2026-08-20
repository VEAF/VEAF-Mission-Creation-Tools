"""Finish an atomic write, surviving the transient lock Windows puts on a fresh file.

Every atomic write in the tooling has the same shape: write a temp file beside the target, then
``os.replace`` it onto the target. On Windows that last step fails intermittently with
``PermissionError: [WinError 5] Access is denied`` — not because of anything the process did, but
because something outside it (a virus scanner, the search indexer) still holds a handle on the file
that was just written.

Measured on 2026-08-20 with a probe that involves no VEAF code at all — ``mkstemp``, write a 40 KB
zip, ``os.replace``, 300 times: the first attempt failed 8 times, the target was never read-only,
**one** retry 50 ms later cleared all 8, and nothing ever needed a third attempt. So the window is a
few tens of milliseconds and it closes on its own.

The retry is deliberately narrow: only ``PermissionError``, and the original exception is re-raised
when the attempts run out, so a genuine permission problem still fails and still names its own cause.
Nothing is retried on other errors, and a healthy write pays nothing at all — which is also why no
platform check is needed: the failure this guards against does not occur on Linux, so the CI never
sleeps.
"""

from __future__ import annotations

import contextlib
import os
import time
from pathlib import Path

from veaf_libs.logger import Logger

logger = Logger("atomic-replace")

#: How many times to attempt the rename. One retry sufficed in every measured case; the rest is
#: margin for a slower machine, and it is cheap because it is only ever paid on a real failure.
DEFAULT_ATTEMPTS = 5

#: Seconds to wait before the second attempt. Grows linearly with each further attempt, so five
#: attempts span roughly 0.75 s in total.
DEFAULT_DELAY = 0.05


def atomic_replace(
    source: Path | str,
    target: Path | str,
    *,
    attempts: int = DEFAULT_ATTEMPTS,
    delay: float = DEFAULT_DELAY,
) -> None:
    """Rename *source* onto *target*, retrying while the failure looks like a transient lock.

    Args:
        source: The temp file to move into place. It must sit on the same volume as *target*,
            which is what makes the rename atomic; callers create it in the target's own directory.
        target: The final path. Overwritten, as ``os.replace`` does.
        attempts: How many times to try the rename. Must be at least 1.
        delay: Seconds before the second attempt, multiplied by the attempt number for each one
            after that. Pass ``0.0`` in tests to keep them instant.

    Raises:
        PermissionError: The rename still failed after *attempts* tries. The exception is the
            **last** one raised by ``os.replace``, so its message and ``winerror`` are the real
            ones rather than a wrapper's.
        OSError: Any other failure of ``os.replace``, raised immediately — only the transient lock
            is worth waiting out.
    """
    last_error: PermissionError | None = None

    for attempt in range(1, max(attempts, 1) + 1):
        try:
            os.replace(source, target)
            if attempt > 1:
                # Worth a line: it says the guard earned its keep, and on which file.
                logger.debug(f"atomic_replace: {Path(target).name} took {attempt} attempts")
            return
        except PermissionError as error:
            last_error = error
            if attempt < attempts:
                time.sleep(delay * attempt)

    # Out of attempts: leave nothing of ours on disk, then report the real error. The cleanup comes
    # first because the caller may well swallow the exception, and a half-written `.miz` sitting
    # next to a mission is exactly the litter VMR-053 removed.
    with contextlib.suppress(OSError):
        os.unlink(source)

    assert last_error is not None  # unreachable: the loop only exits here after a PermissionError
    raise last_error
