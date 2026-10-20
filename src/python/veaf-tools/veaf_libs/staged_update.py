"""An update of ``veaf-tools`` waits beside it until a start can take it (FIX-OPENCODE-TEST-FINDINGS 01).

A PyInstaller onefile executable reads its Python modules from its own file, **by path**, the first
time each is imported. The MCP server's self-update used to put a new ``veaf-tools.exe`` in place while
servers ran from it: their next first-time import read the new file at the old file's offsets and
failed (``Error -3 while decompressing data: incorrect header check``, reproduced 2026-10-20).

So the update is staged — downloaded beside the executable as ``veaf-tools.exe.staged`` — and
:func:`take_staged_update` puts it in place at a start, when no other process runs from that file.
The starting process sets itself aside, moves the staged executable in, and runs it as a child on the
same standard streams. It must import nothing once its file has changed: everything it needs is
imported at the top of this module.
"""

import ctypes
import os
import subprocess
import time
from collections.abc import Callable, Iterable
from pathlib import Path

STAGED_SUFFIX = ".staged"
#: Tells a PyInstaller executable started by another one to unpack itself afresh rather than reuse
#: the parent's unpacked folder — which, the path being the same, it would take for its own.
_RESET_ENV_VAR = "PYINSTALLER_RESET_ENVIRONMENT"
_PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


def staged_path(exe: Path) -> Path:
    """Return where an update of ``exe`` waits.

    Args:
        exe: The installed executable.

    Returns:
        ``exe`` with ``.staged`` appended to its name.
    """
    return exe.with_name(exe.name + STAGED_SUFFIX)


def _runs_from(image: str, exe: Path) -> bool:
    """Return whether a process image is ``exe`` or a copy of it set aside (``<name>.<n>.old``).

    A copy set aside still reads its modules by the original path, so it counts.
    """
    path = Path(image.removesuffix(" (deleted)"))
    if os.path.normcase(str(path.parent)) != os.path.normcase(str(exe.parent)):
        return False
    name, exe_name = os.path.normcase(path.name), os.path.normcase(exe.name)
    return name == exe_name or (name.startswith(exe_name + ".") and name.endswith(".old"))


def _windows_images() -> Iterable[tuple[int, str]]:
    """Yield ``(pid, image path)`` for every process this user may query, on Windows."""
    kernel32 = ctypes.WinDLL("kernel32")  # type: ignore[attr-defined]
    pids = (ctypes.c_ulong * 8192)()
    returned = ctypes.c_ulong()
    if not kernel32.K32EnumProcesses(pids, ctypes.sizeof(pids), ctypes.byref(returned)):
        raise OSError("EnumProcesses failed")
    buffer = ctypes.create_unicode_buffer(32768)
    for pid in pids[: returned.value // ctypes.sizeof(ctypes.c_ulong)]:
        handle = kernel32.OpenProcess(_PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not handle:
            continue  # another user's or a protected process: not one of ours
        try:
            size = ctypes.c_ulong(len(buffer))
            if kernel32.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)):
                yield pid, buffer.value
        finally:
            kernel32.CloseHandle(handle)


def _linux_images() -> Iterable[tuple[int, str]]:
    """Yield ``(pid, image path)`` for every process this user may read, on Linux."""
    for entry in Path("/proc").iterdir():
        if entry.name.isdigit():
            try:
                yield int(entry.name), os.readlink(entry / "exe")
            except OSError:
                continue


def running_copies(exe: Path, own_pids: set[int]) -> list[int] | None:
    """List the processes running from ``exe`` or from a copy of it set aside, except ``own_pids``.

    Args:
        exe: The installed executable.
        own_pids: This start's own processes — a onefile executable is two: the unpacking parent and
            the Python child.

    Returns:
        Their process ids, or None when this platform cannot tell (anything but Windows and Linux).
    """
    if os.name == "nt":
        images = _windows_images()
    elif Path("/proc/self/exe").exists():
        images = _linux_images()
    else:
        return None
    return sorted(pid for pid, image in images if pid not in own_pids and _runs_from(image, exe))


def _run_child(cmd: list[str]) -> int:
    """Run the new executable on this process's standard streams and return its exit code."""
    return subprocess.run(cmd, env={**os.environ, _RESET_ENV_VAR: "1"}, check=False).returncode  # noqa: S603


def take_staged_update(
    exe: Path,
    args: list[str],
    *,
    own_pids: set[int],
    list_running: Callable[[Path, set[int]], list[int] | None] = running_copies,
    launch: Callable[[list[str]], int] = _run_child,
) -> int | None:
    """Put a staged update in place and run it, when no other process runs from ``exe``.

    Args:
        exe: The running, installed executable.
        args: This start's command line after the program name, passed on unchanged.
        own_pids: This start's own processes.
        list_running: Lists the other processes running from ``exe`` (injected for tests).
        launch: Runs the new executable and returns its exit code (injected for tests).

    Returns:
        The new executable's exit code, for this process to exit with without importing anything
        more; None when nothing was swapped and this process carries on as it is.
    """
    staged = staged_path(exe)
    if not staged.is_file():
        return None
    try:
        if list_running(exe, own_pids) != []:
            return None
    except OSError:
        return None
    for leftover in exe.parent.glob(f"{exe.name}.*.old"):
        try:
            leftover.unlink()
        except OSError:
            pass  # still running: a later swap deletes it
    aside = exe.with_name(f"{exe.name}.{time.time_ns()}.old")
    try:
        exe.rename(aside)
    except OSError:
        return None
    try:
        os.replace(staged, exe)
    except OSError:
        aside.rename(exe)
        return None
    try:
        return launch([str(exe), *args])
    except OSError:
        os.replace(exe, staged)
        aside.rename(exe)
        return None
