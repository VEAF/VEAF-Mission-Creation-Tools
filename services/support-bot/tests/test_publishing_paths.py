"""Ticket 09: every path that publishes, derived from the code — not a list somebody maintains.

Four leaks of personal data reached review across three pull requests of this lot, and every one of
them took a path the hostile fixture did not carry: an archive's member listing, a parser's error
message, an attachment's own file name, an attachment's bytes carried into a comment, and the reason
published when redaction itself failed. Each fix added one more case to the fixture — which is
testing the leaks already found, not the ones not yet found.

So this file asserts two things, and neither of them is a list of callers:

1. **Everything that reaches the transport is redacted**, because the redaction happens *at* the
   transport (:meth:`GitHubApp._scrubbed`) rather than in each caller. The assertion sits on the
   bytes handed to the transport — #920's leak was at an argument of the network call, and a test on
   a function's return value would have passed right beside it.
2. **Nothing reaches GitHub any other way.** A syntax walk over the package finds every call that
   sends a body, and fails on one that does not go through :class:`GitHubApp`. That is what makes
   the first assertion hold for code nobody has written yet.

``TestTheNetWouldCatchOne`` adds an unredacted path on purpose and requires the net to fail. A net
nobody has seen catch anything is a net with a hole in it.
"""

from __future__ import annotations

import ast
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

from tests.test_github_app import PEM, credentials
from veaf_support_bot.github_app import GitHubApp, GitHubError, Response

#: The package under inspection.
PACKAGE = Path(__file__).resolve().parent.parent / "veaf_support_bot"

#: Personal data of the shape the redaction helper recognises, one per leak the lot has already had.
PERSONAL = {
    "home directory": r"C:\Users\Firstname Lastname\Saved Games\DCS",
    "address": "someone@example.invalid",
    "server": "192.168.1.44",
    "token": "ghp_0123456789abcdefghijklmnopqrstuvwxyz",
}


def fake_redactor(text: str) -> str:
    """Stand in for ``veaf_libs.redaction``, recognising exactly the fixtures above.

    A stand-in and not the real helper: this file is about **where** redaction happens, not about
    what the helper recognises — that is the tools' own test suite. Using a stand-in also means a
    leak here is unambiguous, since anything that comes out unchanged was never offered to it.

    Args:
        text: What is about to be published.

    Returns:
        The text with every fixture replaced.
    """
    for value in PERSONAL.values():
        text = text.replace(value, "[redacted]")
    return text


class _Recorder:
    """A transport that keeps every byte it was handed."""

    def __init__(self) -> None:
        """Initialize the recorder."""
        self.bodies: list[str] = []

    async def __call__(self, method: str, url: str, headers: Any, body: bytes | None) -> Response:
        """Record one call.

        Args:
            method: The HTTP method.
            url: The URL.
            headers: The request headers.
            body: The request body.

        Returns:
            A success.
        """
        if body is not None:
            self.bodies.append(body.decode("utf-8"))
        if url.endswith("/access_tokens"):
            return Response(201, {"token": "ghs-t", "expires_at": "2999-01-01T00:00:00Z"})
        return Response(201, {"number": 901, "html_url": "https://example.invalid/issues/901"})


def _app(recorder: _Recorder, redactor: Any = fake_redactor) -> GitHubApp:
    """Build a client over a recording transport.

    Args:
        recorder: What records the bodies.
        redactor: The redactor to install.

    Returns:
        The client.
    """
    return GitHubApp(credentials(), "VEAF/VEAF-Mission-Creation-Tools", recorder, redactor=redactor)


class TestWhatReachesTheTransport(unittest.IsolatedAsyncioTestCase):
    """The assertion is on the bytes, not on any function's return value."""

    async def test_a_body_is_redacted_on_its_way_out(self) -> None:
        recorder = _Recorder()

        await _app(recorder).request("POST", "/repos/o/n/issues", {"body": PERSONAL["home directory"]})

        self.assertNotIn("Firstname Lastname", recorder.bodies[0])
        self.assertIn("[redacted]", recorder.bodies[0])

    async def test_it_reaches_every_field_however_deeply_it_is_nested(self) -> None:
        """A leak in a list inside a dict is the shape three of the four already found had."""
        recorder = _Recorder()
        payload = {
            "title": PERSONAL["address"],
            "labels": [PERSONAL["token"], "bug"],
            "meta": {"attachments": [{"filename": PERSONAL["home directory"]}]},
            "number": 12,
            "draft": False,
        }

        await _app(recorder).request("POST", "/repos/o/n/issues", payload)

        sent = recorder.bodies[0]
        for name, value in PERSONAL.items():
            with self.subTest(kind=name):
                self.assertNotIn(value, sent)
        # Non-strings survive untouched: a redactor that stringified them would break the API.
        self.assertEqual(json.loads(sent)["number"], 12)
        self.assertIs(json.loads(sent)["draft"], False)

    async def test_redaction_that_cannot_run_publishes_nothing(self) -> None:
        """Fail closed. Redaction failing open is how a home directory reaches a public issue."""
        recorder = _Recorder()

        def _unavailable(text: str) -> str:
            raise RuntimeError("veaf_libs.redaction is not importable")

        with self.assertRaises(GitHubError):
            await _app(recorder, _unavailable).request("POST", "/repos/o/n/issues", {"body": "anything"})

        self.assertEqual(recorder.bodies, [], "the body reached the transport anyway")

    async def test_the_refusal_names_no_path_of_its_own(self) -> None:
        """#920's fix leaked the host's checkout path in the reason redaction had failed."""
        recorder = _Recorder()

        def _unavailable(text: str) -> str:
            raise RuntimeError(r"cannot import from C:\srv\veaf\checkout\veaf_libs")

        with self.assertRaises(GitHubError) as caught:
            await _app(recorder, _unavailable).request("POST", "/repos/o/n/issues", {"body": "x"})

        self.assertNotIn("srv", str(caught.exception))
        self.assertNotIn("checkout", str(caught.exception))


def _sending_calls() -> list[tuple[Path, int, str]]:
    """Find every call in the package that hands a body to something.

    Derived from the syntax tree rather than from a list of module names, which is the whole point:
    a new publishing path must be caught without anybody remembering to add it here.

    Returns:
        One ``(file, line, rendered call)`` per call that passes a body or a JSON payload.
    """
    return _sending_calls_in(PACKAGE)


def _sending_calls_in(root: Path) -> list[tuple[Path, int, str]]:
    """Run the walk over an arbitrary tree, so the walk itself can be put on trial.

    Args:
        root: The directory to walk.

    Returns:
        One ``(file, line, rendered call)`` per call that sends a body.
    """
    found: list[tuple[Path, int, str]] = []
    for path in sorted(root.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            # What makes a call an HTTP send is that it carries a body — `json=` or `data=` — not
            # what it is named. `exchange.post(...)` writes to Discord through a protocol this
            # service owns; `session.post(..., json=...)` reaches a network.
            sends_body = any(keyword.arg in ("json", "data") for keyword in node.keywords)
            door = isinstance(node.func, ast.Attribute) and node.func.attr == "request" and len(node.args) >= 3
            if sends_body or door:
                found.append((path, node.lineno, ast.unparse(node)[:120]))
    return found


class TestNothingReachesGitHubAnyOtherWay(unittest.TestCase):
    """The first assertion only holds while :class:`GitHubApp` is the only door."""

    def test_the_walk_actually_finds_the_calls(self) -> None:
        """Guards the guard: a walk that finds nothing would pass for ever."""
        rendered = [call for _, _, call in _sending_calls()]

        self.assertTrue(any("request(" in call for call in rendered), "the syntax walk found no API call")

    def test_every_body_bearing_call_goes_through_a_client(self) -> None:
        """Two clients own a network: the GitHub App, and the Worker. Nothing else may hold one."""
        offenders = [
            f"{path.name}:{line} sends a body outside a client: {call}"
            for path, line, call in _sending_calls()
            # `github_app.py` and `worker.py` are the two doors, each with its own guard: the App
            # redacts every outgoing body, and the Worker is handed only what a caller prepared.
            # Any other module reaching a network is a publishing path with no floor under it.
            if path.name not in ("github_app.py", "worker.py")
            and not call.startswith(("self._app.request(", "app.request("))
        ]

        self.assertEqual(offenders, [], "\n".join(offenders))

    def test_the_apps_own_send_is_the_one_place_redaction_happens(self) -> None:
        """If ``_call`` stops scrubbing, every assertion in this file becomes decorative."""
        source = (PACKAGE / "github_app.py").read_text(encoding="utf-8")

        self.assertIn("json.dumps(self._scrubbed(payload))", source)


class TestTheNetWouldCatchOne(unittest.IsolatedAsyncioTestCase):
    """A detector nobody has seen fail proves nothing at all."""

    async def test_an_unredacted_path_added_to_the_client_is_caught(self) -> None:
        recorder = _Recorder()
        app = _app(recorder)

        # The exact mistake this ticket exists to make impossible: a new method that talks to the
        # transport directly instead of going through `request`.
        async def _leaky() -> None:
            await app._call(  # noqa: SLF001 - standing in for a path somebody might add
                "POST",
                "/repos/o/n/issues/1/comments",
                headers={"Authorization": "Bearer x"},
                payload={"body": PERSONAL["home directory"]},
            )

        await _leaky()

        # `_call` scrubs too, so even this shortcut is clean — which is the property being asserted:
        # the floor is under the transport, not under the callers.
        self.assertNotIn("Firstname Lastname", recorder.bodies[-1])

    async def test_an_app_built_without_a_redactor_publishes_raw(self) -> None:
        """Proves the check is load-bearing: with the floor removed, the fixture goes straight out."""
        recorder = _Recorder()

        await _app(recorder, None).request("POST", "/repos/o/n/issues", {"body": PERSONAL["address"]})

        self.assertIn(PERSONAL["address"], recorder.bodies[0])

    def test_a_module_talking_to_a_network_on_its_own_is_named(self) -> None:
        """The ticket's own requirement: prove the net fails when a path is added, by adding one.

        The offending module is written to a temporary directory and the *same* walk is run over it,
        rather than dropping a file into the package — a test that leaves a landmine in the shipped
        tree is worse than the hole it guards.
        """
        with tempfile.TemporaryDirectory() as folder:
            leak = Path(folder) / "shortcut.py"
            leak.write_text(
                "async def publish(session, report):\n"
                '    await session.post("https://api.github.invalid/issues", json={"body": report})\n',
                encoding="utf-8",
            )

            found = _sending_calls_in(Path(folder))

            self.assertEqual([(path.name, line) for path, line, _ in found], [("shortcut.py", 2)])
            self.assertIn("session.post", found[0][2], "the failure must name the path, not just exist")

    def test_the_service_never_builds_one_that_way(self) -> None:
        """So the deployment cannot end up with the configuration the test above describes."""
        source = (PACKAGE / "service.py").read_text(encoding="utf-8")

        self.assertIn("build_github_app(config, build_redactor(config))", source)
        self.assertIn("redactor=redactor", source)


class TestThePemFixtureIsReal(unittest.TestCase):
    """Guards the guards above, which all sign a JWT before they can reach the transport."""

    def test_the_key_is_a_key(self) -> None:
        self.assertIn("PRIVATE KEY", PEM)


if __name__ == "__main__":
    unittest.main()
