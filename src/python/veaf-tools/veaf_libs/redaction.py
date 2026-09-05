"""Strip personal data out of anything the tool invites a user to publish.

Whatever ``veaf-tools doctor`` prints is designed to be pasted into a **public** GitHub issue or a
Discord thread by someone who will not reread it. A Windows path carries the account name
(``C:\\Users\\Firstname Lastname\\...``), a server log carries addresses, and a configuration file
carries tokens. Redaction therefore happens **before** the text is shown, not at the moment it is
published — by then it is too late and the publisher is a different program.

This module is deliberately the only implementation: ``FEAT-SUPPORT-LOG-ANALYSIS`` bounds a log
excerpt and ``FEAT-SUPPORT-BUG-INTAKE`` attaches files to an issue, and both reuse
:func:`redact` rather than growing a second set of patterns that would drift.

The rules err on the side of over-redaction. A version number that gets mistaken for an address is
a cosmetic loss; an account name that survives is a real one.
"""

from __future__ import annotations

import re
from pathlib import Path

#: What replaces a user account name inside a home-directory path.
USER_PLACEHOLDER = "<user>"

#: What replaces an IPv4 address.
IP_PLACEHOLDER = "<ip>"

#: What replaces an e-mail address.
EMAIL_PLACEHOLDER = "<email>"

#: What replaces anything shaped like a credential.
SECRET_PLACEHOLDER = "<redacted>"

# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

#: ``C:\Users\Firstname Lastname\`` and its POSIX equivalents. The account name may contain spaces,
#: so it is matched up to the next separator rather than as a word.
_HOME_DIR = re.compile(
    r"(?P<prefix>(?:[A-Za-z]:[\\/])?(?:Users|home|Documents and Settings)[\\/])(?P<user>[^\\/\r\n]+)",
    re.IGNORECASE,
)

#: A strict dotted quad: each group is a real octet, so a four-part version number such as
#: ``2.9.29.27278`` (last group above 255) is not mistaken for an address. The lookarounds stop the
#: pattern from biting a longer dotted run out of the middle of a version string.
_OCTET = r"(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)"
_IPV4 = re.compile(rf"(?<![\w.]){_OCTET}(?:\.{_OCTET}){{3}}(?![\w.])")

#: Loopback and wildcard carry no personal information and are useful to keep: seeing that the
#: bridge answered on ``127.0.0.1`` is diagnostic, seeing ``<ip>`` is not.
_IP_KEEP: frozenset[str] = frozenset({"127.0.0.1", "0.0.0.0", "255.255.255.255"})

_EMAIL = re.compile(r"(?<![\w.])[\w.+-]+@[\w-]+(?:\.[\w-]+)+(?![\w.])")

#: ``token=...``, ``password: ...``, ``Authorization: Bearer …`` — the value runs to the next
#: separator, and an authentication scheme in front of it is swallowed with it rather than being
#: mistaken for the value itself (which would leave the actual token in the clear).
_LABELLED_SECRET = re.compile(
    r"(?P<label>\b(?:token|password|passwd|secret|api[_-]?key|apikey|authorization|auth)\b\s*[:=]\s*)"
    r"(?P<value>(?:bearer|basic|token)\s+)?"
    r"(?:\"[^\"\r\n]*\"|'[^'\r\n]*'|[^\s,;)\]}\r\n]+)",
    re.IGNORECASE,
)

#: Well-known credential prefixes, redacted whole whatever their length.
_KNOWN_TOKEN = re.compile(
    r"\b(?:gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|xox[abposr]-[A-Za-z0-9-]{10,})"
)

#: A long opaque run mixing letters and digits: what a key, a hash or a session id looks like. The
#: length floor keeps ordinary words, file names and version strings out.
_OPAQUE_MIN_LEN = 24
_OPAQUE = re.compile(
    r"(?<![\w-])"
    r"(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[A-Za-z])"
    rf"[A-Za-z0-9_-]{{{_OPAQUE_MIN_LEN},}}"
    r"(?![\w-])"
)


def _redact_home_dirs(text: str) -> str:
    """Replace the account-name segment of every home directory in *text*."""
    return _HOME_DIR.sub(lambda m: f"{m.group('prefix')}{USER_PLACEHOLDER}", text)


def _redact_ips(text: str) -> str:
    """Replace every routable IPv4 address in *text*, keeping loopback and wildcard."""
    return _IPV4.sub(lambda m: m.group(0) if m.group(0) in _IP_KEEP else IP_PLACEHOLDER, text)


def _redact_secrets(text: str) -> str:
    """Replace credential-shaped material: labelled values, known prefixes, long opaque runs."""
    text = _LABELLED_SECRET.sub(lambda m: f"{m.group('label')}{SECRET_PLACEHOLDER}", text)
    text = _KNOWN_TOKEN.sub(SECRET_PLACEHOLDER, text)
    return _OPAQUE.sub(SECRET_PLACEHOLDER, text)


def redact(text: str) -> str:
    """Return *text* with personal and secret material replaced by placeholders.

    Applied in a fixed order — home directories, e-mail addresses, credentials, then addresses —
    because a later rule must not chew through a placeholder an earlier one produced.

    Args:
        text: Any text about to be shown to a user for publication.

    Returns:
        The same text with account names, e-mail addresses, credentials and routable IPv4
        addresses replaced. Loopback addresses are kept: they are diagnostic and carry nothing.
    """
    if not text:
        return text
    redacted = _redact_home_dirs(text)
    redacted = _EMAIL.sub(EMAIL_PLACEHOLDER, redacted)
    redacted = _redact_secrets(redacted)
    return _redact_ips(redacted)


def redact_path(path: Path | str | None) -> str:
    """Return a printable, redacted form of *path*.

    Args:
        path: A filesystem path, or ``None``.

    Returns:
        The redacted path, or an empty string when *path* is ``None``.
    """
    if path is None:
        return ""
    return redact(str(path))
