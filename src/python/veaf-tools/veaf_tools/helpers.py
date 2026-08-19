import os
import sys
from pathlib import Path

from veaf_libs.i18n import t

_BUILD_CONFIG_MARKER = "# ── Build configuration"


def _get_parent_process_name_windows() -> str | None:
    """Return the lowercase name of the parent process on Windows using ctypes/Toolhelp32.

    Returns ``None`` if the name cannot be determined (snapshot failure, any exception).
    The Toolhelp32 API returns ANSI strings; decoded with ``mbcs`` to match the system locale.
    """
    try:
        import ctypes
        import ctypes.wintypes

        TH32CS_SNAPPROCESS = 0x00000002

        class PROCESSENTRY32(ctypes.Structure):
            _fields_ = [
                ("dwSize", ctypes.wintypes.DWORD),
                ("cntUsage", ctypes.wintypes.DWORD),
                ("th32ProcessID", ctypes.wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)),
                ("th32ModuleID", ctypes.wintypes.DWORD),
                ("cntThreads", ctypes.wintypes.DWORD),
                ("th32ParentProcessID", ctypes.wintypes.DWORD),
                ("pcPriClassBase", ctypes.c_long),
                ("dwFlags", ctypes.wintypes.DWORD),
                ("szExeFile", ctypes.c_char * 260),
            ]

        snapshot = ctypes.windll.kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)  # type: ignore[attr-defined]
        if snapshot == ctypes.wintypes.HANDLE(-1).value:
            return None
        try:
            entry = PROCESSENTRY32()
            entry.dwSize = ctypes.sizeof(PROCESSENTRY32)
            ppid = os.getppid()
            if not ctypes.windll.kernel32.Process32First(snapshot, ctypes.byref(entry)):  # type: ignore[attr-defined]
                return None
            while True:
                if entry.th32ProcessID == ppid:
                    # Toolhelp32 returns ANSI strings — decode with the system ANSI code page
                    return entry.szExeFile.decode("mbcs", errors="replace").lower()
                if not ctypes.windll.kernel32.Process32Next(snapshot, ctypes.byref(entry)):  # type: ignore[attr-defined]
                    break
        finally:
            ctypes.windll.kernel32.CloseHandle(snapshot)  # type: ignore[attr-defined]
        return None
    except Exception:  # noqa: BLE001
        return None


def _build_process_tree_windows() -> "tuple[dict[int,int], dict[int,str]]":
    """Return (pid→ppid, pid→name) maps for all running processes on Windows."""
    pid_to_ppid: dict[int, int] = {}
    pid_to_name: dict[int, str] = {}
    try:
        import ctypes
        import ctypes.wintypes

        TH32CS_SNAPPROCESS = 0x00000002

        class PROCESSENTRY32(ctypes.Structure):
            _fields_ = [
                ("dwSize", ctypes.wintypes.DWORD),
                ("cntUsage", ctypes.wintypes.DWORD),
                ("th32ProcessID", ctypes.wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)),
                ("th32ModuleID", ctypes.wintypes.DWORD),
                ("cntThreads", ctypes.wintypes.DWORD),
                ("th32ParentProcessID", ctypes.wintypes.DWORD),
                ("pcPriClassBase", ctypes.c_long),
                ("dwFlags", ctypes.wintypes.DWORD),
                ("szExeFile", ctypes.c_char * 260),
            ]

        snapshot = ctypes.windll.kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)  # type: ignore[attr-defined]
        if snapshot == ctypes.wintypes.HANDLE(-1).value:
            return pid_to_ppid, pid_to_name
        try:
            entry = PROCESSENTRY32()
            entry.dwSize = ctypes.sizeof(PROCESSENTRY32)
            if ctypes.windll.kernel32.Process32First(snapshot, ctypes.byref(entry)):  # type: ignore[attr-defined]
                while True:
                    name = entry.szExeFile.decode("mbcs", errors="replace").lower()
                    pid_to_name[entry.th32ProcessID] = name
                    pid_to_ppid[entry.th32ProcessID] = entry.th32ParentProcessID
                    if not ctypes.windll.kernel32.Process32Next(snapshot, ctypes.byref(entry)):  # type: ignore[attr-defined]
                        break
        finally:
            ctypes.windll.kernel32.CloseHandle(snapshot)  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001
        pass
    return pid_to_ppid, pid_to_name


_TERMINAL_PROCESSES = frozenset(
    {
        "cmd.exe",
        "powershell.exe",
        "pwsh.exe",
        "wt.exe",
        "windowsterminal.exe",
        "mintty.exe",
        "conemu64.exe",
        "conemu.exe",
    }
)


def _is_double_clicked() -> bool:
    """Return True if the process was launched by double-clicking (Explorer parent on Windows).

    Walks up the process tree to handle PyInstaller one-file exes, where the
    direct parent is the bootloader subprocess rather than explorer.exe.
    Returns False on non-Windows systems and when stdout is redirected (CI / pipe).
    """
    if not sys.stdout.isatty():
        return False
    if sys.platform != "win32":
        return False
    pid_to_ppid, pid_to_name = _build_process_tree_windows()
    if not pid_to_name:
        return False
    current = os.getpid()
    seen: set[int] = set()
    while current and current not in seen:
        seen.add(current)
        parent_pid = pid_to_ppid.get(current)
        if parent_pid is None:
            break
        parent_name = pid_to_name.get(parent_pid, "")
        if parent_name == "explorer.exe":
            return True
        if parent_name in _TERMINAL_PROCESSES:
            return False
        current = parent_pid
    return False


#: Environment variable a programmatic caller sets (to a truthy value) to force the exit pause
#: off. Referenced by :func:`should_auto_pause`, ``scaffold_mission``, and ``bootstrap.ps1``
#: (which cannot import this constant, so keep the string in sync there).
NO_PAUSE_ENV_VAR = "VEAF_UPDATER_NO_PAUSE"
_TRUTHY = frozenset({"1", "true", "yes", "on"})


def should_auto_pause() -> bool:
    """Return whether a tool should pause for a keypress before exiting.

    True only for a genuine double-click launch (see :func:`_is_double_clicked`), and **never**
    when :data:`NO_PAUSE_ENV_VAR` (``VEAF_UPDATER_NO_PAUSE``) is set to a truthy value
    (``1``/``true``/``yes``/``on``). A programmatic caller — the plugin's SessionStart bootstrap
    or ``scaffold_mission`` — exports it as ``"1"`` so the tool never blocks on an interactive
    ``input()`` prompt with no one to press a key (the cause of the plugin bootstrap hang). Any
    other value (including ``"0"``/unset) leaves the double-click behaviour unchanged.
    """
    if os.environ.get(NO_PAUSE_ENV_VAR, "").strip().lower() in _TRUTHY:
        return False
    return _is_double_clicked()


def _read_single_char() -> str:
    """Read one character from the console without waiting for Enter (Windows/Unix)."""
    try:
        import msvcrt

        ch = msvcrt.getwch()  # type: ignore[attr-defined]
        if ch in ("\x00", "\xe0"):
            msvcrt.getwch()  # type: ignore[attr-defined]  # consume second byte of special key
            return ""
        if ch == "\x03":  # Ctrl-C
            raise KeyboardInterrupt
        return ch
    except ImportError:
        # Unix fallback (not expected in production, but keeps tests runnable)
        import termios
        import tty

        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)  # type: ignore[attr-defined]
        try:
            tty.setraw(fd)  # type: ignore[attr-defined]
            return sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)  # type: ignore[attr-defined]


def _ask_replace(relative_path: Path) -> tuple[bool, bool]:
    """Ask whether to replace an existing file via a clear menu.

    Returns ``(should_replace, remember_for_rest)`` — when ``remember_for_rest`` is
    ``True`` the caller applies ``should_replace`` to every remaining file (the
    "replace all" / "keep all" choices). Non-interactive runs keep everything without
    prompting (``(False, True)``).
    """
    if not sys.stdin.isatty():
        return (False, True)

    from InquirerPy import inquirer  # type: ignore[import-untyped]
    from InquirerPy.base.control import Choice  # type: ignore[import-untyped]

    choice: tuple[bool, bool] = inquirer.select(
        message=t("file.replace_prompt", path=relative_path),
        choices=[
            Choice(value=(True, False), name=t("file.replace.this")),
            Choice(value=(False, False), name=t("file.keep.this")),
            Choice(value=(True, True), name=t("file.replace.all")),
            Choice(value=(False, True), name=t("file.keep.all")),
        ],
        default=(False, False),
    ).execute()
    return choice


def _update_build_config_in_yaml(yaml_path: Path, dev_mode: bool, scripts_path: Path | None) -> None:
    """Update (or append) the ``build:`` section in *mission.yaml*, touching nothing else.

    Uses a text-based replacement so every comment in the file is preserved — a load/mutate/dump
    would lose all of them, and ``mission.yaml`` is a heavily commented file makers edit by hand.

    The section is identified by the ``_BUILD_CONFIG_MARKER`` header line and **bounded** at its own
    end. It used to be bounded at the end of the *file*: ``content = content[:idx]`` discarded
    everything from the marker onward, so anything a maker wrote after ``build:`` was eaten by the
    next ``build --dev-mode``. Measured 2026-08-19 on the shape that cost three evenings — a
    ``security:`` block with its password hashes, and the maker's trailing comment, all gone in one
    call.

    Args:
        yaml_path: The ``mission.yaml`` to update in place.
        dev_mode: The persisted ``dev_mode`` flag.
        scripts_path: The persisted scripts path, omitted from the section when ``None``.
    """
    lines: list[str] = [
        "",
        "# ── Build configuration ─────────────────────────────────────────────────────",
        "# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.",
        "# Note: scripts_path is usually machine-specific.",
        "#",
        "build:",
        f"  dev_mode: {'true' if dev_mode else 'false'}",
    ]
    if scripts_path:
        lines.append(f'  scripts_path: "{scripts_path.as_posix()}"')
    new_section = "\n".join(lines) + "\n"

    content = yaml_path.read_text(encoding="utf-8")
    span = _build_section_span(content)
    if span is None:
        yaml_path.write_text(content.rstrip("\n") + "\n" + new_section, encoding="utf-8", newline="\n")
        return

    start, end = span
    head = content[:start].rstrip("\n")
    tail = content[end:].lstrip("\n")
    rebuilt = head + "\n" + new_section
    if tail:
        # The section carries its own leading blank line, so one separating blank is enough here too.
        rebuilt += "\n" + tail
    yaml_path.write_text(rebuilt, encoding="utf-8", newline="\n")


def _build_section_span(content: str) -> tuple[int, int] | None:
    """Locate the build section's own extent in *content*.

    The span runs from the marker line to the end of the ``build:`` block — the first line after it
    that is neither blank nor indented. That rule stops at a following section's comment header, which
    sits at column 0 and is precisely what must be preserved.

    Args:
        content: The whole ``mission.yaml`` text.

    Returns:
        ``(start, end)`` character offsets, or ``None`` when the file carries no marker.
    """
    marker_at = content.find(_BUILD_CONFIG_MARKER)
    if marker_at < 0:
        return None

    lines = content.splitlines(keepends=True)
    offsets: list[int] = []
    running = 0
    for line in lines:
        offsets.append(running)
        running += len(line)

    first = next(i for i, offset in enumerate(offsets) if offset + len(lines[i]) > marker_at)

    # The header is a run of comment (and blank) lines; the key itself follows it.
    index = first
    while index < len(lines) and (not lines[index].strip() or lines[index].lstrip().startswith("#")):
        index += 1

    if index < len(lines) and lines[index].startswith("build:"):
        index += 1
        # The block's own body: indented entries, plus blank lines between them.
        while index < len(lines) and (not lines[index].strip() or lines[index][:1].isspace()):
            index += 1
    # Otherwise the marker has no `build:` key under it — a maker deleted the key and kept the header.
    # Only the header run is replaced; consuming "the indented block" would eat the next section.

    end = offsets[index] if index < len(lines) else len(content)
    return offsets[first], end
