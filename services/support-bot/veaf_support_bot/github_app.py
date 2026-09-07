"""The bot's GitHub identity: a dedicated App, and tokens that expire on their own.

## Why an App and not a token

A personal access token would be a long-lived credential sitting on the host, carrying every right
its owner has, and its leak would be invisible — nothing distinguishes the bot's writes from
David's. Reusing an existing token is worse: it can no longer be revoked without breaking whatever
else uses it.

A GitHub App fixes all three. It is installed on **one repository**, granted **one permission**
(*Issues: read and write*, plus the *Metadata: read-only* GitHub attaches to every App), and it
never holds a usable credential at rest: what sits on the host is a private key, which is only good
for signing a **ten-minute JWT**, which is only good for minting an **installation token that
expires in an hour**. Revoking the installation ends all of it in one click, and every issue the bot
opens is visibly authored by the App rather than by a person.

## The renewal, which is the part that must not be clever

:class:`AppCredentials` signs a JWT valid for ten minutes; :class:`GitHubApp` exchanges it for an
installation token and keeps that token until :data:`RENEW_MARGIN_SECONDS` before it expires. There
is no refresh loop and no background task: the token is minted **on the call that needs it**, so a
service idle for a day does not hold a stale credential and does not have to notice that it does.

## Credentials come from the environment, and their absence stops the startup

The App does not exist yet when this is written, and that is exactly why
:func:`credentials_from_config` raises rather than returning something half-built. The service
already exits 78 on invalid configuration; a missing key belongs there, not in the first user's
report — a bot that starts, collects a report and then discovers it cannot file it has lost the
report.

## What is never in an error message

A failure carries the HTTP status and GitHub's own message, never a header and never the key.
:func:`_scrub` removes any ``Bearer`` value the API happens to echo back, because the one place a
token reliably appears in a body is the message complaining about it.
"""

from __future__ import annotations

import base64
import json
import time
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

#: GitHub's REST root.
API_ROOT = "https://api.github.com"

#: ``Accept`` header the REST API asks callers to send.
API_ACCEPT = "application/vnd.github+json"

#: API version this client is written against.
API_VERSION = "2022-11-28"

#: Lifetime of the JWT the private key signs. GitHub refuses anything above ten minutes.
JWT_LIFETIME_SECONDS = 540

#: Clock skew allowance subtracted from the JWT's ``iat``. GitHub rejects a token issued in its own
#: future, and a host running a few seconds fast is common enough to plan for.
JWT_SKEW_SECONDS = 60

#: How long before an installation token expires it is replaced. A token that expires between the
#: check and the request is a failure that looks like a permission problem.
RENEW_MARGIN_SECONDS = 300.0

#: Seconds one API call is given.
REQUEST_TIMEOUT_SECONDS = 30.0


class GitHubError(RuntimeError):
    """A GitHub call did not do what was asked.

    Carries the status and GitHub's own message so the sentence posted in the thread says something
    an operator can act on — ``403`` on an installation that lost its permission reads very
    differently from ``422`` on a label that does not exist.

    Attributes:
        status: The HTTP status, or ``0`` when the call never reached GitHub.
    """

    def __init__(self, message: str, status: int = 0) -> None:
        """Initialize the error.

        Args:
            message: What went wrong, already scrubbed of anything secret.
            status: The HTTP status.
        """
        super().__init__(message)
        self.status = status


@dataclass(frozen=True)
class Response:
    """One HTTP answer, reduced to what this module reads.

    Attributes:
        status: The HTTP status code.
        body: The decoded body.
        headers: The response headers, used only for pagination.
    """

    status: int
    body: Any = None
    headers: Mapping[str, str] = field(default_factory=dict)


#: How a request is made. Injected so every test in this package runs without a network, and so the
#: one place that touches ``aiohttp`` stays a single function.
Transport = Callable[[str, str, Mapping[str, str], bytes | None], Awaitable[Response]]


def _scrub(text: str) -> str:
    """Remove anything credential-shaped from a message about to be logged or posted.

    Args:
        text: The message.

    Returns:
        The message with any ``Bearer <value>`` reduced to ``Bearer ***``.
    """
    out: list[str] = []
    for word in text.split(" "):
        out.append("***" if out and out[-1] in ("Bearer", "bearer", "token") else word)
    return " ".join(out)


# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------


@dataclass(frozen=True, repr=False)
class AppCredentials:
    """What the App needs to prove it is itself.

    Attributes:
        app_id: The App's numeric id, shown on its settings page.
        installation_id: The installation on the one repository it serves.
        private_key_pem: The PEM of the App's private key. **Secret**, and the only long-lived one
            the host holds — it cannot write anything by itself, it can only mint ten-minute JWTs.
    """

    app_id: str
    installation_id: str
    private_key_pem: str

    def __repr__(self) -> str:
        """Return a representation with the key masked.

        The dataclass-generated one would put a private key into any stack trace. The whole key, on
        one line, in a container log.

        Returns:
            A safe ``repr``.
        """
        return f"AppCredentials(app_id={self.app_id!r}, installation_id={self.installation_id!r}, private_key_pem=***)"

    def jwt(self, now: float | None = None) -> str:
        """Sign a short-lived JSON Web Token identifying the App.

        Args:
            now: Current Unix timestamp; defaults to the clock.

        Returns:
            The compact JWT.

        Raises:
            GitHubError: The key could not be loaded or is not an RSA key. Raised rather than
                returning an unusable token, so the failure names the key instead of arriving later
                as an opaque ``401``.
        """
        issued = int(time.time() if now is None else now) - JWT_SKEW_SECONDS
        header = {"alg": "RS256", "typ": "JWT"}
        payload = {"iat": issued, "exp": issued + JWT_LIFETIME_SECONDS, "iss": self.app_id}
        signing_input = b".".join((_b64url(_compact(header)), _b64url(_compact(payload))))
        return b".".join((signing_input, _b64url(self._sign(signing_input)))).decode("ascii")

    def _sign(self, message: bytes) -> bytes:
        """Sign bytes with the App's private key.

        Args:
            message: The JWT's signing input.

        Returns:
            The RS256 signature.

        Raises:
            GitHubError: The key is unusable.
        """
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import padding, rsa
        except ImportError as error:  # pragma: no cover - the dependency is declared
            raise GitHubError(f"the cryptography package is not installed ({error})") from error
        try:
            key = serialization.load_pem_private_key(self.private_key_pem.encode("utf-8"), password=None)
        except Exception as error:  # noqa: BLE001 - every load failure is one answer to the caller
            raise GitHubError(f"the GitHub App private key could not be read ({type(error).__name__})") from error
        if not isinstance(key, rsa.RSAPrivateKey):
            raise GitHubError("the GitHub App private key is not an RSA key")
        return key.sign(message, padding.PKCS1v15(), hashes.SHA256())


def _compact(document: Mapping[str, Any]) -> bytes:
    """Serialize a JWT part the way a JWT wants it.

    Args:
        document: The header or the payload.

    Returns:
        Compact UTF-8 JSON.
    """
    return json.dumps(document, separators=(",", ":"), sort_keys=True).encode("utf-8")


def _b64url(raw: bytes) -> bytes:
    """Encode bytes as unpadded base64url.

    Args:
        raw: The bytes.

    Returns:
        The encoded bytes.
    """
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def read_private_key(inline: str, path: str) -> str:
    """Resolve the private key from whichever of the two ways it was supplied.

    A file is the right way on a host with a secrets mount; the inline form is the only way inside a
    plain ``--env-file`` container, where it arrives with ``\\n`` escapes that a shell never expands.
    Both are accepted, and the escapes are undone.

    Args:
        inline: The PEM itself, possibly with literal ``\\n`` sequences.
        path: A file holding the PEM.

    Returns:
        The PEM.

    Raises:
        GitHubError: Neither was supplied, both were, or the file could not be read. *Both* is an
            error rather than a precedence rule: an operator who set the two does not know which one
            is live, and silently picking one is how a rotated key stays unrotated.
    """
    if inline and path:
        raise GitHubError("the GitHub App private key was given twice, inline and as a path; keep one")
    if inline:
        return inline.replace("\\n", "\n")
    if not path:
        raise GitHubError("the GitHub App private key is not configured")
    try:
        return Path(path).expanduser().read_text(encoding="utf-8")
    except OSError as error:
        raise GitHubError(f"the GitHub App private key file could not be read ({type(error).__name__})") from error


# ---------------------------------------------------------------------------
# The client
# ---------------------------------------------------------------------------


@dataclass
class _Token:
    """One installation token and when it stops working.

    Attributes:
        value: The token. Secret.
        expires_at: Unix timestamp of its expiry.
    """

    value: str
    expires_at: float

    def usable(self, now: float) -> bool:
        """Say whether the token is still worth sending.

        Args:
            now: Current Unix timestamp.

        Returns:
            ``True`` while more than :data:`RENEW_MARGIN_SECONDS` remain.
        """
        return bool(self.value) and now < self.expires_at - RENEW_MARGIN_SECONDS


class GitHubApp:
    """Authenticated access to one repository, with the token renewed as needed."""

    def __init__(
        self,
        credentials: AppCredentials,
        repository: str,
        transport: Transport,
        *,
        api_root: str = API_ROOT,
        redactor: Callable[[str], str] | None = None,
    ) -> None:
        """Initialize the client without contacting GitHub.

        Args:
            credentials: The App's identity.
            repository: ``owner/name`` of the one repository the App is installed on.
            transport: How a request is made.
            api_root: API root, overridable for a test or a GitHub Enterprise host.
            redactor: What every outgoing body passes through. ``None`` publishes bodies as they
                are, which is only ever right in a test — see :meth:`_scrubbed`.
        """
        self.credentials = credentials
        self.repository = repository
        self.api_root = api_root.rstrip("/")
        self._transport = transport
        self._redactor = redactor
        self._token: _Token | None = None

    def _scrubbed(self, payload: Any) -> Any:
        """Redact every string in an outgoing body, however deeply it is nested.

        This is where redaction *actually* happens, rather than in each caller that builds something
        publishable. Four leaks reached review across three pull requests of this lot, and each one
        took a path the callers' own guards did not cover: an archive's member list, a parser's
        error message, an attachment's file name, an attachment's bytes. Every one of them was
        published by a caller that believed somebody else had redacted.

        Putting it here makes the property structural: a new publishing path cannot be written
        without it, because there is no way to reach GitHub that does not come through this method.
        Callers still redact what they *quote* — the excerpt, the manifest — for their own reasons;
        this is the floor under all of them, and applying it twice is harmless.

        Args:
            payload: The body about to be sent.

        Returns:
            The same structure with every string redacted.

        Raises:
            GitHubError: Redaction is unavailable. Nothing is published: failing closed here is the
                whole point, and the message names no path — the reason published on a failure is
                itself something that has leaked before.
        """
        if self._redactor is None:
            return payload
        try:
            return _map_strings(payload, self._redactor)
        except GitHubError:
            raise
        except Exception as error:
            raise GitHubError(f"nothing was published: redaction is unavailable ({type(error).__name__})") from error

    async def token(self, now: float | None = None) -> str:
        """Return a usable installation token, minting one when the held one is near its end.

        Args:
            now: Current Unix timestamp; defaults to the clock.

        Returns:
            The token.

        Raises:
            GitHubError: The exchange failed.
        """
        moment = time.time() if now is None else now
        if self._token is not None and self._token.usable(moment):
            return self._token.value
        response = await self._call(
            "POST",
            f"/app/installations/{self.credentials.installation_id}/access_tokens",
            headers={"Authorization": f"Bearer {self.credentials.jwt(moment)}"},
        )
        body = response.body if isinstance(response.body, dict) else {}
        value = str(body.get("token") or "")
        if not value:
            raise GitHubError("GitHub returned an installation response with no token in it", response.status)
        self._token = _Token(value=value, expires_at=moment + _lifetime(body.get("expires_at"), moment))
        return value

    async def request(self, method: str, path: str, payload: Any = None) -> Response:
        """Make one authenticated call against the repository.

        Args:
            method: HTTP method.
            path: Path below :data:`API_ROOT`, e.g. ``"/repos/o/n/issues"``.
            payload: JSON body, or ``None``.

        Returns:
            The response.

        Raises:
            GitHubError: The call failed, or GitHub answered with an error status.
        """
        return await self._call(
            method, path, headers={"Authorization": f"Bearer {await self.token()}"}, payload=payload
        )

    async def _call(
        self,
        method: str,
        path: str,
        *,
        headers: Mapping[str, str],
        payload: Any = None,
    ) -> Response:
        """Make one call and turn a failing status into an exception.

        Args:
            method: HTTP method.
            path: Path below the API root.
            headers: Authorization header to add to the common ones.
            payload: JSON body, or ``None``.

        Returns:
            The response, when the status is a success.

        Raises:
            GitHubError: The transport failed, or the status is not a success.
        """
        body = None if payload is None else json.dumps(self._scrubbed(payload)).encode("utf-8")
        common = {
            "Accept": API_ACCEPT,
            "X-GitHub-Api-Version": API_VERSION,
            "User-Agent": "veaf-support-bot",
            **({"Content-Type": "application/json"} if body is not None else {}),
            **headers,
        }
        try:
            response = await self._transport(method, f"{self.api_root}{path}", common, body)
        except GitHubError:
            raise
        except Exception as error:  # noqa: BLE001 - one answer for every transport failure
            raise GitHubError(f"GitHub could not be reached ({type(error).__name__})") from error
        if 200 <= response.status < 300:
            return response
        raise GitHubError(f"GitHub answered {response.status}: {_scrub(_message_of(response.body))}", response.status)


def _map_strings(value: Any, transform: Callable[[str], str]) -> Any:
    """Apply *transform* to every string inside a JSON-shaped structure.

    Args:
        value: A string, a list, a mapping, or a scalar.
        transform: What to apply to each string.

    Returns:
        The same shape, with every string transformed. Keys are left alone: they are field names
        this service chose, never reporter-supplied text.
    """
    if isinstance(value, str):
        return transform(value)
    if isinstance(value, list):
        return [_map_strings(item, transform) for item in value]
    if isinstance(value, dict):
        return {key: _map_strings(item, transform) for key, item in value.items()}
    return value


def _message_of(body: Any) -> str:
    """Pull the human-readable part out of a GitHub error body.

    Args:
        body: The decoded body.

    Returns:
        A short sentence, never the whole document.
    """
    if isinstance(body, dict):
        message = str(body.get("message") or "").strip()
        errors = body.get("errors")
        if isinstance(errors, list) and errors:
            detail = "; ".join(str(item.get("message") or item) for item in errors if item)[:300]
            return f"{message} ({detail})" if message else detail
        if message:
            return message
    return str(body)[:300] if body else "no message"


def _lifetime(expires_at: Any, now: float) -> float:
    """Turn GitHub's ``expires_at`` into seconds from now.

    Args:
        expires_at: The ISO-8601 timestamp GitHub returned, or anything else.
        now: Current Unix timestamp.

    Returns:
        Seconds of life, defaulting to an hour when the field is missing or unreadable — which is
        the documented lifetime, and always shortened by :data:`RENEW_MARGIN_SECONDS` in use.
    """
    if isinstance(expires_at, str) and expires_at:
        try:
            moment = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
        except ValueError:
            return 3600.0
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=UTC)
        return max(0.0, moment.timestamp() - now)
    return 3600.0


async def aiohttp_transport(
    method: str,
    url: str,
    headers: Mapping[str, str],
    body: bytes | None,
) -> Response:
    """Make one HTTPS call with ``aiohttp``, the library ``discord.py`` already brings.

    Args:
        method: HTTP method.
        url: Absolute URL.
        headers: Request headers.
        body: Request body, or ``None``.

    Returns:
        The response, its body decoded as JSON when it is JSON and left as text otherwise.

    Raises:
        aiohttp.ClientError: The call failed at the transport level.
    """
    import aiohttp

    timeout = aiohttp.ClientTimeout(total=REQUEST_TIMEOUT_SECONDS)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.request(method, url, headers=dict(headers), data=body) as response:
            text = await response.text()
            try:
                decoded: Any = json.loads(text) if text else None
            except ValueError:
                decoded = text
            return Response(status=response.status, body=decoded, headers=dict(response.headers))
