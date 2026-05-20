import sys
from pathlib import Path

from veaf_libs.i18n import t

_BUILD_CONFIG_MARKER = "# ── Build configuration"


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
