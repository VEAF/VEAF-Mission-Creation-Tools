"""Strip personal data out of anything the tool invites a user to publish.

Whatever ``veaf-tools doctor`` prints is designed to be pasted into a **public** GitHub issue or a
Discord thread by someone who will not reread it. A Windows path carries the account name
(``C:\\Users\\Firstname Lastname\\...``), a server log carries addresses, and a configuration file
carries tokens. Redaction therefore happens **before** the text is shown, not at the moment it is
published — by then it is too late and the publisher is a different program.

This module is deliberately the only implementation: ``FEAT-SUPPORT-LOG-ANALYSIS`` bounds a log
excerpt and ``FEAT-SUPPORT-BUG-INTAKE`` attaches files to an issue, and both reuse
:func:`redact` rather than growing a second set of patterns that would drift.

**What is redacted, and what deliberately is not.** The first version of this module also replaced
any run of 24+ characters mixing letters and digits, on the theory that a key looks random. Measured
against the machine the feature was written on — the last 3 MB of the real ``veaf-tools.log``,
1489 ``ERROR`` records — that rule fired **74 times and caught not one credential**: every hit was a
temporary directory name or the name of the object that failed. Measured against the repository's
own data files it matched **169 DCS GUIDs and 493 other identifiers**, among them
``HVAR_USN_Mk28_Mod4_Corsair`` and ``M261_INBOARD_DE_M151_C_M274`` — exactly the strings a
mission-load failure names. ``unknown payload <redacted>`` keeps *that* something failed and throws
away *what*, which is the opposite of the point.

So there is no entropy rule here. A secret is recognised by **context** (an assignment to a
credential-shaped key, including one embedded in a longer name such as ``access_token``) or by a
**known shape** (a GitHub token prefix, a JWT, a webhook URL, credentials inside a URL). An
unlabelled, unrecognised blob of randomness is left alone, on purpose: over-redaction that destroys
the diagnosis is not the safe side of this trade.

Personal identity is a different matter and is over-redacted freely: the account name is replaced
wherever it appears, not only under ``Users/``, because it turns up in temporary paths, host names
and environment dumps far from any home directory.
"""

from __future__ import annotations

import getpass
import re
from functools import lru_cache
from pathlib import Path

#: What replaces a user account name, in a home-directory path or anywhere else.
USER_PLACEHOLDER = "<user>"

#: What replaces an IP address, v4 or v6.
IP_PLACEHOLDER = "<ip>"

#: What replaces an e-mail address.
EMAIL_PLACEHOLDER = "<email>"

#: What replaces anything shaped like a credential.
SECRET_PLACEHOLDER = "<redacted>"

#: The bare words inside the placeholders above. An account name equal to one of them would make
#: redaction non-idempotent (``<user>`` → ``<<user>>``), so such a name is left alone.
_PLACEHOLDER_WORDS: frozenset[str] = frozenset({"user", "ip", "email", "redacted"})

#: Shortest account name replaced on sight. A two-letter name (``jd``) appears inside ordinary words
#: and would shred the text it is meant to protect.
MIN_ACCOUNT_NAME_LEN = 3

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
#: ``2.9.29.27278`` (last group above 255) is not mistaken for an address. The second lookbehind
#: covers the version numbers that *do* fit in four octets: ``DCS/2.9.10.1`` used to become
#: ``DCS/<ip>``, taking the single most useful field of the report with it. A dotted quad directly
#: behind ``<letter>/`` is a version string; behind ``//`` (a URL) it is still an address.
_OCTET = r"(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)"
_IPV4 = re.compile(rf"(?<![\w.])(?<![A-Za-z]/){_OCTET}(?:\.{_OCTET}){{3}}(?![\w.])")

#: IPv6, in the two forms that cannot be confused with anything else in a log: eight full groups, or
#: a ``::`` compression. A three-group run without ``::`` is deliberately *not* matched — that is
#: what a timestamp (``12:00:00``) looks like, and every record header carries one.
_HEXTET = r"[A-Fa-f0-9]{1,4}"
_IPV6 = re.compile(
    r"(?<![\w:.])"
    r"(?:"
    rf"{_HEXTET}(?::{_HEXTET}){{7}}"
    rf"|(?:{_HEXTET}:){{1,7}}:(?:{_HEXTET}(?::{_HEXTET}){{0,6}})?"
    rf"|::{_HEXTET}(?::{_HEXTET}){{0,7}}"
    r")"
    r"(?:%[A-Za-z0-9._-]+)?"
    r"(?![\w:.])"
)

#: Addresses that carry no personal information and are useful to keep: seeing that the bridge
#: answered on ``127.0.0.1`` is diagnostic, seeing ``<ip>`` is not. The whole ``127.0.0.0/8`` block
#: is loopback — ``127.0.1.1``, the usual Debian entry in ``/etc/hosts``, belongs here too.
_IP_KEEP_EXACT: frozenset[str] = frozenset({"0.0.0.0", "255.255.255.255", "::1", "::"})

#: The trailing lookahead stops at a word character only: an address that ends a sentence
#: (``write to david@example.com.``) used to survive whole because the final full stop refused the
#: match.
_EMAIL = re.compile(r"(?<![\w.])[\w.+-]+@[\w-]+(?:\.[\w-]+)+(?![\w-])")

#: The words that make what follows them a credential.
_SECRET_WORD = (
    r"(?:token|password|passwd|pwd|passphrase|secret|api[_-]?key|apikey"
    r"|authorization|auth|credentials?|session|cookie|private[_-]?key|access[_-]?key)"
)

#: ``token=…``, ``password: …``, ``Authorization: Bearer …``, ``access_token=…``,
#: ``client_secret=…``, ``"token": "…"``. Three things the first version got wrong, all measured:
#: ``_`` is a word character, so ``\btoken\b`` never matched inside ``access_token``; the separator
#: could not cross a JSON key's closing quote, so every pasted configuration leaked; and an
#: authentication scheme in front of the value has to be swallowed *with* it, or the scheme word is
#: taken for the value and the real credential stays in the clear.
_LABELLED_SECRET = re.compile(
    r"(?P<label>"
    r"(?<![\w-])"
    r"[\"']?"  # a JSON key's opening quote
    r"(?:[A-Za-z0-9]+[_-])*"  # access_ , client_ , x_api_
    rf"{_SECRET_WORD}"
    r"(?:[_-][A-Za-z0-9]+)*"  # _id , _value
    r"[\"']?"  # a JSON key's closing quote
    r"\s*[:=]\s*"
    r")"
    r"(?:(?:bearer|basic|token|digest)\s+)?"
    r"(?:\"[^\"\r\n]*\"|'[^'\r\n]*'|[^\s,;)\]}\r\n]+)",
    re.IGNORECASE,
)

#: Credential shapes that identify themselves whatever the surrounding text: they are the ones that
#: leak by being pasted alone, without the key that named them.
_KNOWN_TOKEN = re.compile(
    "|".join(
        (
            r"\bgh[pousr]_[A-Za-z0-9]{16,}",  # GitHub personal / OAuth / server / refresh
            r"\bgithub_pat_[A-Za-z0-9_]{20,}",  # GitHub fine-grained PAT
            r"\bxox[abposr]-[A-Za-z0-9-]{10,}",  # Slack
            r"\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{16,}",  # OpenAI / Anthropic style
            r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b",  # AWS access key id
            r"\bAIza[0-9A-Za-z_-]{35,}",  # Google API key
            r"\beyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}",  # JWT
            r"https://discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_-]+",
            r"https://hooks\.slack\.com/services/[A-Za-z0-9/_+-]+",
            r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
        )
    )
)

#: ``https://user:password@host`` — the one place a credential hides without a key naming it.
_URL_CREDENTIALS = re.compile(r"(?<=://)[^\s/:@]{1,64}:[^\s/@]{1,128}(?=@)")


@lru_cache(maxsize=1)
def _account_patterns() -> tuple[re.Pattern[str], ...]:
    """Compile a matcher for each name this account is known by, longest first.

    The account name is the one personal string the machine always knows, and the home-directory
    rule only catches it directly under ``Users/``. Measured on 1489 real ``ERROR`` records it
    survived **56 times** in ``…\\Temp\\pytest-of-David\\…``, on lines where ``C:\\Users\\<user>``
    three segments earlier *had* been redacted. Replacing the literal covers that, and with it
    ``%USERPROFILE%`` expansions, a ``USERNAME=`` environment dump, a UNC share named after the
    machine's owner, and a home directory that is not under ``Users`` at all.

    Returns:
        One compiled, case-insensitive pattern per distinct name. Empty when the account cannot be
        named, or is named something too short or too placeholder-like to replace safely.
    """
    names: set[str] = set()
    for producer in (lambda: Path.home().name, getpass.getuser):
        try:
            name = producer()
        except Exception:  # pragma: no cover - a machine that cannot name its own user
            continue
        if name and len(name) >= MIN_ACCOUNT_NAME_LEN and name.lower() not in _PLACEHOLDER_WORDS:
            names.add(name)
    return tuple(
        # `<` and `>` are excluded on either side so a second pass does not chew through the
        # placeholder the first one wrote.
        re.compile(rf"(?<![<\w]){re.escape(name)}(?![>\w])", re.IGNORECASE)
        for name in sorted(names, key=len, reverse=True)
    )


def _redact_home_dirs(text: str) -> str:
    """Replace the account-name segment of every home directory in *text*."""
    return _HOME_DIR.sub(lambda m: f"{m.group('prefix')}{USER_PLACEHOLDER}", text)


def _redact_account_name(text: str) -> str:
    """Replace every literal occurrence of the current account name in *text*."""
    for pattern in _account_patterns():
        text = pattern.sub(USER_PLACEHOLDER, text)
    return text


def _keep_ip(value: str) -> bool:
    """Say whether an address is one worth keeping in a diagnostic."""
    return value.startswith("127.") or value in _IP_KEEP_EXACT


def _replace_ip(match: re.Match[str]) -> str:
    """Return the placeholder, unless the address is one worth keeping."""
    return match.group(0) if _keep_ip(match.group(0)) else IP_PLACEHOLDER


def _redact_ips(text: str) -> str:
    """Replace every routable address in *text*, keeping loopback and wildcard."""
    return _IPV6.sub(_replace_ip, _IPV4.sub(_replace_ip, text))


def _redact_secrets(text: str) -> str:
    """Replace credential-shaped material: labelled values and known shapes."""
    text = _LABELLED_SECRET.sub(lambda m: f"{m.group('label')}{SECRET_PLACEHOLDER}", text)
    return _KNOWN_TOKEN.sub(SECRET_PLACEHOLDER, text)


def redact(text: str) -> str:
    """Return *text* with personal and secret material replaced by placeholders.

    Applied in a fixed order — URL credentials, home directories, e-mail addresses, labelled and
    known credentials, the bare account name, then addresses — because a later rule must not chew
    through what an earlier one produced. ``user:password@host`` comes first because the e-mail rule
    would otherwise eat ``password@host`` and leave the user name behind; e-mail comes before the
    account name so ``david@example.org`` becomes ``<email>`` rather than ``<user>@example.org``.

    Args:
        text: Any text about to be shown to a user for publication.

    Returns:
        The same text with account names, e-mail addresses, credentials and routable IP addresses
        replaced. Loopback addresses are kept: they are diagnostic and carry nothing.
    """
    if not text:
        return text
    redacted = _URL_CREDENTIALS.sub(SECRET_PLACEHOLDER, text)
    redacted = _redact_home_dirs(redacted)
    redacted = _EMAIL.sub(EMAIL_PLACEHOLDER, redacted)
    redacted = _redact_secrets(redacted)
    redacted = _redact_account_name(redacted)
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
