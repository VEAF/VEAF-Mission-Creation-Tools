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


def _is_double_clicked() -> bool:
    """Return True if the process was launched by double-clicking (Explorer parent on Windows).

    This is used to auto-pause at the end of the build so the user can read the output
    when they run veaf-tools by double-clicking the .exe rather than from a terminal.
    Returns False on non-Windows systems and when stdout is redirected (CI / pipe).
    """
    if not sys.stdout.isatty():
        return False
    if sys.platform != "win32":
        return False
    parent = _get_parent_process_name_windows()
    if parent is None:
        return False
    return parent == "explorer.exe"


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
    """Prompt to replace an existing file. Returns (should_replace, yes_to_all)."""
    sys.stdout.write(t("file.already_exists", path=relative_path) + "\n")
    while True:
        sys.stdout.write(t("file.replace_prompt"))
        sys.stdout.flush()
        try:
            ch = _read_single_char().lower()
        except KeyboardInterrupt:
            sys.stdout.write("\n")
            return False, False
        sys.stdout.write(ch + "\n")
        if ch in ("a", "t"):  # 'a' (EN) or 't' for "tous" (FR)
            return True, True
        if ch in ("y", "o"):  # 'y' (EN) or 'o' for "oui" (FR)
            return True, False
        if ch in ("n", "\r", "\n", ""):
            return False, False
        sys.stdout.write(t("file.replace_hint") + "\n")


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
