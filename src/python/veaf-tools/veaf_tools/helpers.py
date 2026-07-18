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


def should_auto_pause() -> bool:
    """Return whether a tool should pause for a keypress before exiting.

    True only for a genuine double-click launch (see :func:`_is_double_clicked`), and **never**
    when the ``VEAF_UPDATER_NO_PAUSE`` environment variable is set. A programmatic caller — the
    plugin's SessionStart bootstrap or ``scaffold_mission`` — exports that variable so the tool
    never blocks on an interactive ``input()`` prompt with no one to press a key (the cause of
    the plugin bootstrap hang).
    """
    if os.environ.get("VEAF_UPDATER_NO_PAUSE"):
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
    """Update (or append) the ``build:`` section in *mission.yaml*.

    Uses a text-based replacement so all other comments in the file are preserved.
    The section is identified by the ``_BUILD_CONFIG_MARKER`` header line.
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
    # Replace existing build: section if present (identified by the marker), or append
    idx = content.find("\n" + _BUILD_CONFIG_MARKER)
    if idx >= 0:
        content = content[:idx]
    content = content.rstrip("\n") + "\n" + new_section
    yaml_path.write_text(content, encoding="utf-8")
