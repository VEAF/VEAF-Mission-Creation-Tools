"""Guards on the shape of the deployable, not on its behaviour.

Two of them exist because the repository has already been bitten by the same class of drift: a
version living in two files, and a secret committed by accident.
"""

from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tomllib
import unittest
from pathlib import Path

import veaf_support_bot

SERVICE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SERVICE_ROOT.parents[1]


def _service_pyproject() -> dict:
    """Return the service's parsed ``pyproject.toml``.

    Returns:
        The parsed document.
    """
    return tomllib.loads((SERVICE_ROOT / "pyproject.toml").read_text(encoding="utf-8"))


class TestVersion(unittest.TestCase):
    def test_the_package_and_the_project_agree(self) -> None:
        self.assertEqual(veaf_support_bot.__version__, _service_pyproject()["tool"]["poetry"]["version"])

    def test_the_service_version_is_its_own(self) -> None:
        """The service is deployed independently, so it is deliberately *not* the tools version.

        The tools, the Claude Code plugin and the Gemini extension move together (enforced by
        ``test/python/test_plugin_version.py``); dragging a bot fix into that lockstep would mean
        waiting for a release to restart a bot.
        """
        tools = tomllib.loads((REPO_ROOT / "pyproject.toml").read_text(encoding="utf-8"))

        self.assertNotEqual(veaf_support_bot.__version__, tools["tool"]["poetry"]["version"])


class TestNoSecretIsCommitted(unittest.TestCase):
    """The one file that names credentials must hold placeholders only."""

    def test_the_example_environment_holds_no_discord_token(self) -> None:
        # A Discord bot token is three base64url segments separated by dots, the first of which
        # decodes to the application id — at least 24 characters before the first dot.
        pattern = re.compile(r"[A-Za-z0-9_-]{24,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{25,}")
        text = (SERVICE_ROOT / ".env.example").read_text(encoding="utf-8")

        self.assertIsNone(pattern.search(text), ".env.example looks like it carries a real token")

    def test_git_really_ignores_the_real_environment_file(self) -> None:
        """Asks git, not the file: the rule lives in the *root* ``.gitignore``, and it has to.

        A nested ``services/support-bot/.gitignore`` would look right and do nothing — the root file
        ignores every nested ``.gitignore`` in this repository, so the rule would never be committed.
        Reading a pattern out of a file would not have caught that; ``git check-ignore`` does.
        """
        if shutil.which("git") is None:
            self.skipTest("git is not on PATH")

        ignored = subprocess.run(
            ["git", "check-ignore", "-q", "services/support-bot/.env"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=False,
        )
        self.assertEqual(ignored.returncode, 0, "services/support-bot/.env is NOT ignored by git")

    def test_git_does_not_ignore_the_documented_example(self) -> None:
        """The negation has to survive: an ignored example is a list nobody can read."""
        if shutil.which("git") is None:
            self.skipTest("git is not on PATH")

        ignored = subprocess.run(
            ["git", "check-ignore", "-q", "services/support-bot/.env.example"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=False,
        )
        self.assertEqual(ignored.returncode, 1, ".env.example is ignored — the operator's list is invisible")

    def test_no_environment_file_was_committed_next_to_the_example(self) -> None:
        """Asks git what is **tracked**, not the filesystem what exists.

        Listing the directory was wrong in the one situation that matters: the README tells the
        operator to copy ``.env.example`` to ``.env`` and fill it in, so a machine that actually
        runs the bot has one — and the whole suite failed there, on the first real run, for a file
        the documentation had asked for. What must never happen is that file being *committed*, and
        only git can answer that.
        """
        if shutil.which("git") is None:
            self.skipTest("git is not on PATH")

        listed = subprocess.run(
            ["git", "ls-files", "--", "services/support-bot/.env*"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        # Outside a git repository — an sdist, a tarball — the command fails, stdout is empty, and
        # the assertion below would pass having measured nothing.
        self.assertEqual(listed.returncode, 0, listed.stderr)
        tracked = sorted(
            pathlib.PurePosixPath(line).name
            for line in listed.stdout.splitlines()
            if line.strip() and pathlib.PurePosixPath(line).name != ".env.example"
        )
        self.assertEqual(tracked, [], f"an environment file is committed: {tracked}")

    def test_git_ignores_the_github_app_key(self) -> None:
        """The README asks for it inside a tracked directory, so only an ignore rule stops it.

        `compose.yml` mounts the key as a secret from beside itself — the natural place, and the one
        `git add -A` sweeps. The rule lives in the **root** ignore file, because a nested one here
        would look right and do nothing.
        """
        if shutil.which("git") is None:
            self.skipTest("git is not on PATH")

        ignored = subprocess.run(
            ["git", "check-ignore", "-q", "services/support-bot/github-app.pem"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=False,
        )
        self.assertEqual(ignored.returncode, 0, "the GitHub App key is NOT ignored by git")

    def test_no_private_key_reaches_a_layer(self) -> None:
        ignored = (SERVICE_ROOT / ".dockerignore").read_text(encoding="utf-8").splitlines()

        self.assertIn("*.pem", ignored)

    def test_git_ignores_the_quota_counters(self) -> None:
        """A local run writes them; they are runtime state, and they name Discord users.

        Same shape as the ``.env`` rule and for the same reason: the pattern has to live in the
        *root* ``.gitignore``, so the check asks git rather than reading a file.
        """
        if shutil.which("git") is None:
            self.skipTest("git is not on PATH")

        ignored = subprocess.run(
            ["git", "check-ignore", "-q", "services/support-bot/state/quota.json"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=False,
        )
        self.assertEqual(ignored.returncode, 0, "the quota counters are NOT ignored by git")

    def test_no_counters_were_committed(self) -> None:
        self.assertFalse(
            (SERVICE_ROOT / "state").exists() and any((SERVICE_ROOT / "state").iterdir()),
            "quota counters are sitting in the repository",
        )


class TestTheContainerRunsTheSameProgram(unittest.TestCase):
    """A "container mode" that differs from the direct run is a second program to debug."""

    def setUp(self) -> None:
        self.dockerfile = (SERVICE_ROOT / "Dockerfile").read_text(encoding="utf-8")

    def test_the_entrypoint_hands_over_to_the_documented_module(self) -> None:
        """The signal has to reach Python, whatever stands in front of it.

        The entry point is a shell script now — it clones the checkout the container owns, which
        nobody else can create — so the module is no longer the ``ENTRYPOINT`` line. What still has
        to be true is that the script **execs** it: without that word the shell keeps PID 1,
        swallows the SIGTERM ``docker stop`` sends, and the graceful shutdown never runs.

        Asserted on the script, not on a mention of the module in the Dockerfile: the previous form
        of this test went on passing after the change, matching the string in a comment.
        """
        script = (SERVICE_ROOT / "docker-entrypoint.sh").read_text(encoding="utf-8")

        self.assertIn('ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]', self.dockerfile)
        self.assertIn('exec python -m veaf_support_bot "$@"', script)

    def test_the_image_can_refresh_its_own_clone(self) -> None:
        """Without git, `/bug` and `/suggest` are not published — and nothing else says so.

        The service refreshes the clone it owns with `git fetch` and `git reset --hard`, and refuses
        a directory with no `.git`. The image shipped a whole lot without git, answering only
        `/ask`; the CI builds it and never asked. This is the static half — the CI runs
        `git --version` in the built image.
        """
        self.assertIn("install --no-install-recommends -y git", self.dockerfile)
        # Not just a mention of the path: the ENV line alone would satisfy that, and the directory,
        # its owner and its volume could all disappear with the test still green.
        self.assertIn("mkdir -p /app/state /app/checkout", self.dockerfile)
        self.assertIn('VOLUME ["/app/state", "/app/checkout"]', self.dockerfile)

    def test_the_image_declares_a_health_check(self) -> None:
        """Without it, "the container is running" is all a supervisor ever knows."""
        self.assertIn("HEALTHCHECK", self.dockerfile)
        self.assertIn("--healthcheck", self.dockerfile)

    def test_the_image_binds_an_address_reachable_from_the_host(self) -> None:
        self.assertIn("SUPPORT_BOT_HEALTH_HOST=0.0.0.0", self.dockerfile)

    def test_the_image_does_not_run_as_root(self) -> None:
        self.assertIn("USER veaf", self.dockerfile)

    def test_the_environment_file_never_reaches_a_layer(self) -> None:
        ignored = (SERVICE_ROOT / ".dockerignore").read_text(encoding="utf-8").splitlines()

        self.assertIn(".env", ignored)


def _variables_read_by_the_code() -> set[str]:
    """Return the variable names the package actually reads, without their prefix.

    Two shapes exist and both are matched: the configuration reader's ``reader.text("NAME")``
    lookups, and the probe's ``f"{ENV_PREFIX}NAME"`` ones.

    Returns:
        The variable names, prefix stripped.
    """
    package = SERVICE_ROOT / "veaf_support_bot"
    config_source = (package / "config.py").read_text(encoding="utf-8")
    other_sources = "\n".join(
        path.read_text(encoding="utf-8") for path in sorted(package.glob("*.py")) if path.name != "config.py"
    )
    return set(re.findall(r'reader\.\w+\(\s*"([A-Z0-9_]+)"', config_source)) | set(
        re.findall(r'ENV_PREFIX\}([A-Z0-9_]+)"', other_sources)
    )


def _variables_documented() -> set[str]:
    """Return the variable names ``.env.example`` documents, commented-out ones included.

    Returns:
        The variable names, prefix stripped.
    """
    from veaf_support_bot.config import ENV_PREFIX

    text = (SERVICE_ROOT / ".env.example").read_text(encoding="utf-8")
    return set(re.findall(rf"^#?{ENV_PREFIX}([A-Z0-9_]+)=", text, re.MULTILINE))


class TestDocumentedVariablesMatchTheCode(unittest.TestCase):
    """`.env.example` is the operator's only list; a variable missing from it does not exist."""

    def test_the_code_reads_something(self) -> None:
        """Guards the guard: an extractor that finds nothing would make both tests below vacuous."""
        self.assertGreaterEqual(len(_variables_read_by_the_code()), 8)

    def test_every_variable_the_code_reads_is_documented(self) -> None:
        missing = sorted(_variables_read_by_the_code() - _variables_documented())

        self.assertEqual(missing, [], f"read by the code but absent from .env.example: {missing}")

    def test_every_documented_variable_is_actually_read(self) -> None:
        stale = sorted(_variables_documented() - _variables_read_by_the_code())

        self.assertEqual(stale, [], f"documented but read by nothing: {stale}")


if __name__ == "__main__":
    unittest.main()
