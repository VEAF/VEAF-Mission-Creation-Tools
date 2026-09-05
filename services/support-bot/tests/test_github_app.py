"""The App's identity: a JWT that verifies, a token that renews, and no secret in any message.

The signature is checked against the public half of a key generated here — asserting that a JWT
"has three parts" would pass on a signature of zeroes.
"""

from __future__ import annotations

import base64
import json
import tempfile
import time
import unittest
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

from veaf_support_bot.github_app import (
    JWT_LIFETIME_SECONDS,
    RENEW_MARGIN_SECONDS,
    AppCredentials,
    GitHubApp,
    GitHubError,
    Response,
    read_private_key,
)

#: One key pair, generated once: RSA generation is slow enough to matter over a whole file.
_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)

#: Its PEM, as an operator would paste it.
PEM = _KEY.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
).decode("ascii")


def credentials() -> AppCredentials:
    """Build usable credentials.

    Returns:
        The credentials.
    """
    return AppCredentials(app_id="123456", installation_id="7890", private_key_pem=PEM)


def _decode(part: str) -> dict[str, Any]:
    """Decode one base64url JWT segment.

    Args:
        part: The segment.

    Returns:
        The decoded JSON object.
    """
    padded = part + "=" * (-len(part) % 4)
    return dict(json.loads(base64.urlsafe_b64decode(padded)))


class _Transport:
    """Records every call and replays a queued answer."""

    def __init__(self, *answers: Response | Exception) -> None:
        self.answers = list(answers)
        self.calls: list[tuple[str, str, Mapping[str, str], bytes | None]] = []

    async def __call__(
        self,
        method: str,
        url: str,
        headers: Mapping[str, str],
        body: bytes | None,
    ) -> Response:
        self.calls.append((method, url, dict(headers), body))
        answer = self.answers.pop(0) if self.answers else Response(200, {})
        if isinstance(answer, Exception):
            raise answer
        return answer


def _token_response(value: str = "ghs-a-token", seconds: int = 3600) -> Response:
    """Build the answer GitHub gives to an installation-token exchange.

    Args:
        value: The token.
        seconds: How long it lives.

    Returns:
        The response.
    """
    expires = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + seconds))
    return Response(201, {"token": value, "expires_at": expires})


class TestTheSignedAssertion(unittest.TestCase):
    """The JWT the private key signs."""

    def test_the_signature_verifies_against_the_public_key(self) -> None:
        header, payload, signature = credentials().jwt(now=1_000_000).split(".")
        signing_input = f"{header}.{payload}".encode("ascii")
        raw = base64.urlsafe_b64decode(signature + "=" * (-len(signature) % 4))
        _KEY.public_key().verify(raw, signing_input, padding.PKCS1v15(), hashes.SHA256())

    def test_it_is_short_lived_and_issued_slightly_in_the_past(self) -> None:
        _, payload, _ = credentials().jwt(now=1_000_000).split(".")
        claims = _decode(payload)
        self.assertLess(claims["iat"], 1_000_000, "a host running fast must not have its JWT refused")
        self.assertEqual(claims["exp"] - claims["iat"], JWT_LIFETIME_SECONDS)
        self.assertLessEqual(JWT_LIFETIME_SECONDS, 600, "GitHub refuses anything longer than ten minutes")

    def test_it_claims_the_app_and_declares_rs256(self) -> None:
        header, payload, _ = credentials().jwt(now=1_000_000).split(".")
        self.assertEqual(_decode(header)["alg"], "RS256")
        self.assertEqual(_decode(payload)["iss"], "123456")

    def test_an_unreadable_key_is_named_rather_than_producing_a_broken_token(self) -> None:
        broken = AppCredentials(app_id="1", installation_id="2", private_key_pem="not a pem at all")
        with self.assertRaises(GitHubError) as caught:
            broken.jwt()
        self.assertIn("could not be read", str(caught.exception))

    def test_a_non_rsa_key_is_refused(self) -> None:
        from cryptography.hazmat.primitives.asymmetric import ed25519

        pem = (
            ed25519.Ed25519PrivateKey.generate()
            .private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption(),
            )
            .decode("ascii")
        )
        with self.assertRaises(GitHubError):
            AppCredentials(app_id="1", installation_id="2", private_key_pem=pem).jwt()


class TestTheKeyNeverLeaks(unittest.TestCase):
    """A private key in a stack trace is a private key in a container log."""

    def test_the_repr_masks_it(self) -> None:
        shown = repr(credentials())
        self.assertNotIn("PRIVATE KEY", shown)
        self.assertIn("***", shown)

    def test_an_error_message_never_carries_a_bearer_value(self) -> None:
        transport = _Transport(Response(401, {"message": "Bad credentials for Bearer ghs-the-real-token"}))
        app = GitHubApp(credentials(), "o/n", transport)
        with self.assertRaises(GitHubError) as caught:
            _run(app.token())
        self.assertNotIn("ghs-the-real-token", str(caught.exception))


class TestResolvingTheKey(unittest.TestCase):
    """Two supported forms, and a refusal to guess between them."""

    def test_the_inline_form_expands_its_escaped_newlines(self) -> None:
        self.assertEqual(
            read_private_key("-----BEGIN-----\\nbody\\n-----END-----", ""), "-----BEGIN-----\nbody\n-----END-----"
        )

    def test_a_file_is_read(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "key.pem"
            path.write_text(PEM, encoding="utf-8")
            self.assertEqual(read_private_key("", str(path)), PEM)

    def test_setting_both_is_refused_rather_than_resolved_by_precedence(self) -> None:
        with self.assertRaises(GitHubError) as caught:
            read_private_key(PEM, "/some/path.pem")
        self.assertIn("keep one", str(caught.exception))

    def test_setting_neither_says_so(self) -> None:
        with self.assertRaises(GitHubError):
            read_private_key("", "")

    def test_a_missing_file_names_the_failure(self) -> None:
        with self.assertRaises(GitHubError) as caught:
            read_private_key("", str(Path(tempfile.gettempdir()) / "no-such-veaf-key.pem"))
        self.assertIn("could not be read", str(caught.exception))


class TestTheInstallationToken(unittest.TestCase):
    """Short-lived, renewed on the call that needs it, and never held past its margin."""

    def test_it_is_exchanged_with_the_jwt_and_reused_afterwards(self) -> None:
        transport = _Transport(_token_response())
        app = GitHubApp(credentials(), "o/n", transport)
        first = _run(app.token())
        second = _run(app.token())
        self.assertEqual(first, "ghs-a-token")
        self.assertEqual(second, first)
        self.assertEqual(len(transport.calls), 1, "a held token is not re-minted on every call")
        self.assertTrue(transport.calls[0][2]["Authorization"].startswith("Bearer eyJ"))

    def test_it_is_replaced_before_it_expires(self) -> None:
        transport = _Transport(_token_response("first", 3600), _token_response("second", 3600))
        app = GitHubApp(credentials(), "o/n", transport)
        now = time.time()
        self.assertEqual(_run(app.token(now)), "first")
        self.assertEqual(_run(app.token(now + 3600 - RENEW_MARGIN_SECONDS + 1)), "second")

    def test_a_response_with_no_token_is_an_error_not_an_empty_credential(self) -> None:
        app = GitHubApp(credentials(), "o/n", _Transport(Response(201, {"expires_at": "2030-01-01T00:00:00Z"})))
        with self.assertRaises(GitHubError):
            _run(app.token())

    def test_an_unparseable_expiry_falls_back_to_the_documented_hour(self) -> None:
        app = GitHubApp(credentials(), "o/n", _Transport(Response(201, {"token": "t", "expires_at": "not a date"})))
        self.assertEqual(_run(app.token()), "t")

    def test_a_missing_expiry_falls_back_to_the_documented_hour(self) -> None:
        app = GitHubApp(credentials(), "o/n", _Transport(Response(201, {"token": "t"})))
        self.assertEqual(_run(app.token()), "t")


class TestTheCalls(unittest.TestCase):
    """What every request carries, and what a failure becomes."""

    def test_a_request_carries_the_installation_token_and_the_api_version(self) -> None:
        transport = _Transport(_token_response(), Response(200, {"number": 1}))
        app = GitHubApp(credentials(), "o/n", transport)
        _run(app.request("GET", "/repos/o/n/issues"))
        _, url, headers, body = transport.calls[-1]
        self.assertEqual(url, "https://api.github.com/repos/o/n/issues")
        self.assertEqual(headers["Authorization"], "Bearer ghs-a-token")
        self.assertEqual(headers["X-GitHub-Api-Version"], "2022-11-28")
        self.assertIsNone(body)

    def test_a_payload_is_sent_as_json(self) -> None:
        transport = _Transport(_token_response(), Response(201, {"number": 1}))
        app = GitHubApp(credentials(), "o/n", transport)
        _run(app.request("POST", "/repos/o/n/issues", {"title": "t"}))
        _, _, headers, body = transport.calls[-1]
        self.assertEqual(headers["Content-Type"], "application/json")
        assert body is not None
        self.assertEqual(json.loads(body), {"title": "t"})

    def test_a_transport_failure_becomes_a_github_error(self) -> None:
        app = GitHubApp(credentials(), "o/n", _Transport(OSError("no route to host")))
        with self.assertRaises(GitHubError) as caught:
            _run(app.token())
        self.assertIn("could not be reached", str(caught.exception))

    def test_an_error_status_carries_githubs_own_message(self) -> None:
        transport = _Transport(
            _token_response(),
            Response(422, {"message": "Validation Failed", "errors": [{"message": "label does not exist"}]}),
        )
        app = GitHubApp(credentials(), "o/n", transport)
        with self.assertRaises(GitHubError) as caught:
            _run(app.request("POST", "/repos/o/n/issues", {"title": "t"}))
        self.assertEqual(caught.exception.status, 422)
        self.assertIn("label does not exist", str(caught.exception))

    def test_a_body_that_is_not_json_still_produces_a_message(self) -> None:
        transport = _Transport(_token_response(), Response(502, "<html>bad gateway</html>"))
        app = GitHubApp(credentials(), "o/n", transport)
        with self.assertRaises(GitHubError) as caught:
            _run(app.request("GET", "/x"))
        self.assertIn("bad gateway", str(caught.exception))

    def test_an_empty_body_still_produces_a_message(self) -> None:
        transport = _Transport(_token_response(), Response(500, None))
        app = GitHubApp(credentials(), "o/n", transport)
        with self.assertRaises(GitHubError) as caught:
            _run(app.request("GET", "/x"))
        self.assertIn("no message", str(caught.exception))


def _run(coroutine: Any) -> Any:
    """Run one coroutine to completion.

    Args:
        coroutine: What to run.

    Returns:
        Its result.
    """
    import asyncio

    return asyncio.run(coroutine)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
