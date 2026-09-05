"""Configuration is the half of this ticket that has to fail *loudly*.

The failure mode being closed here is the one the ticket names: a service that starts happily with a
missing variable and only breaks on the first user question. So the tests assert on two things a
reading of the code would not prove — that every problem is reported at once, and that no path
silently substitutes a default for a value the operator got wrong.
"""

from __future__ import annotations

import unittest

from veaf_support_bot.config import (
    DEFAULT_HEALTH_HOST,
    DEFAULT_HEALTH_PORT,
    DEFAULT_WORKER_CLIENT,
    DEFAULT_WORKER_ENDPOINT,
    REDACTED,
    ConfigurationError,
    SupportBotConfig,
)

#: The smallest environment that describes a runnable service.
MINIMAL = {
    "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
    "SUPPORT_BOT_DISCORD_GUILD_ID": "123456789012345678",
    # Required since ticket 02: the Worker refuses the `discord` client mode without it, so a
    # service missing it would start and answer every question with "my configuration is
    # incomplete" -- a deployment mistake that belongs at startup, not in a thread.
    "SUPPORT_BOT_WORKER_SECRET": "a-worker-secret",
}


class TestRequiredVariables(unittest.TestCase):
    def test_an_empty_environment_names_every_missing_variable(self) -> None:
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({})

        message = str(raised.exception)
        self.assertIn("SUPPORT_BOT_DISCORD_TOKEN", message)
        self.assertIn("SUPPORT_BOT_DISCORD_GUILD_ID", message)
        self.assertIn("SUPPORT_BOT_WORKER_SECRET", message)

    def test_problems_are_reported_together_not_one_per_restart(self) -> None:
        """One error listing everything, so a deployment is fixed in a single pass."""
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env(
                {
                    "SUPPORT_BOT_DISCORD_GUILD_ID": "not-a-number",
                    "SUPPORT_BOT_LOG_LEVEL": "CHATTY",
                    "SUPPORT_BOT_HEALTH_PORT": "70000",
                }
            )

        message = str(raised.exception)
        self.assertIn("5 configuration problem(s)", message)
        for expected in ("DISCORD_TOKEN", "DISCORD_GUILD_ID", "WORKER_SECRET", "LOG_LEVEL", "HEALTH_PORT"):
            self.assertIn(expected, message)

    def test_a_blank_value_counts_as_missing(self) -> None:
        """`SUPPORT_BOT_DISCORD_TOKEN=` in a unit file is a mistake, not a token."""
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_DISCORD_TOKEN": "   "})

        self.assertIn("SUPPORT_BOT_DISCORD_TOKEN is required", str(raised.exception))

    def test_a_guild_id_of_zero_is_refused(self) -> None:
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_DISCORD_GUILD_ID": "0"})

        self.assertIn("must be >= 1", str(raised.exception))


class TestDefaults(unittest.TestCase):
    def setUp(self) -> None:
        self.config = SupportBotConfig.from_env(MINIMAL)

    def test_the_minimal_environment_is_enough(self) -> None:
        self.assertEqual(self.config.discord_token, "a-token")
        self.assertEqual(self.config.discord_guild_id, 123456789012345678)

    def test_optional_values_fall_back_to_the_documented_defaults(self) -> None:
        self.assertEqual(self.config.worker_endpoint, DEFAULT_WORKER_ENDPOINT)
        self.assertEqual(self.config.worker_client, DEFAULT_WORKER_CLIENT)
        self.assertEqual(self.config.health_host, DEFAULT_HEALTH_HOST)
        self.assertEqual(self.config.health_port, DEFAULT_HEALTH_PORT)
        self.assertEqual(self.config.log_level, "INFO")
        self.assertEqual(self.config.log_format, "json")
        self.assertFalse(self.config.dry_run)

    def test_the_health_endpoint_is_not_public_by_default(self) -> None:
        """Binding 0.0.0.0 is the container's decision, taken in the Dockerfile, not a default."""
        self.assertEqual(self.config.health_host, "127.0.0.1")


class TestOverrides(unittest.TestCase):
    def test_every_optional_variable_is_read(self) -> None:
        config = SupportBotConfig.from_env(
            {
                **MINIMAL,
                "SUPPORT_BOT_WORKER_ENDPOINT": "https://preview.example.org/chat",
                "SUPPORT_BOT_WORKER_CLIENT": "discord-preview",
                "SUPPORT_BOT_HEALTH_HOST": "0.0.0.0",
                "SUPPORT_BOT_HEALTH_PORT": "9000",
                "SUPPORT_BOT_LOG_LEVEL": "debug",
                "SUPPORT_BOT_LOG_FORMAT": "TEXT",
                "SUPPORT_BOT_HEARTBEAT_SECONDS": "5",
                "SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS": "2.5",
                "SUPPORT_BOT_DRY_RUN": "yes",
            }
        )

        self.assertEqual(config.worker_endpoint, "https://preview.example.org/chat")
        self.assertEqual(config.worker_client, "discord-preview")
        self.assertEqual(config.health_host, "0.0.0.0")
        self.assertEqual(config.health_port, 9000)
        self.assertEqual(config.log_level, "DEBUG")
        self.assertEqual(config.log_format, "text")
        self.assertEqual(config.heartbeat_seconds, 5.0)
        self.assertEqual(config.shutdown_grace_seconds, 2.5)
        self.assertTrue(config.dry_run)

    def test_port_zero_is_allowed(self) -> None:
        """Asking the OS for an ephemeral port is how the tests bind without racing on a number."""
        config = SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_HEALTH_PORT": "0"})

        self.assertEqual(config.health_port, 0)


class TestMalformedValues(unittest.TestCase):
    """No silent substitution: a value the operator got wrong stops the startup."""

    def _refuses(self, variable: str, value: str, expected: str) -> None:
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({**MINIMAL, variable: value})
        self.assertIn(expected, str(raised.exception))

    def test_a_non_numeric_port(self) -> None:
        self._refuses("SUPPORT_BOT_HEALTH_PORT", "http", "is not an integer")

    def test_a_port_out_of_range(self) -> None:
        self._refuses("SUPPORT_BOT_HEALTH_PORT", "-1", "is not a TCP port")

    def test_an_unknown_log_level(self) -> None:
        self._refuses("SUPPORT_BOT_LOG_LEVEL", "LOUD", "is not one of")

    def test_an_unknown_log_format(self) -> None:
        self._refuses("SUPPORT_BOT_LOG_FORMAT", "xml", "is not one of")

    def test_a_non_boolean_flag_is_not_read_as_false(self) -> None:
        """`DRY_RUN=maybe` read as "off" would start a real bot when a smoke run was asked for."""
        self._refuses("SUPPORT_BOT_DRY_RUN", "maybe", "is not a boolean")

    def test_a_zero_heartbeat(self) -> None:
        self._refuses("SUPPORT_BOT_HEARTBEAT_SECONDS", "0", "must be > 0")

    def test_a_negative_grace_period(self) -> None:
        self._refuses("SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS", "-3", "must be > 0")

    def test_a_non_http_worker_endpoint(self) -> None:
        self._refuses("SUPPORT_BOT_WORKER_ENDPOINT", "ftp://example.org/chat", "is not an http(s) URL")

    def test_a_worker_endpoint_with_no_host(self) -> None:
        self._refuses("SUPPORT_BOT_WORKER_ENDPOINT", "https:///chat", "is not an http(s) URL")


class TestBooleanVocabulary(unittest.TestCase):
    def test_the_accepted_spellings(self) -> None:
        for value in ("1", "true", "TRUE", "Yes", "on"):
            with self.subTest(value=value):
                self.assertTrue(SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_DRY_RUN": value}).dry_run)
        for value in ("0", "false", "No", "OFF"):
            with self.subTest(value=value):
                self.assertFalse(SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_DRY_RUN": value}).dry_run)


class TestDryRun(unittest.TestCase):
    def test_a_dry_run_needs_no_credentials(self) -> None:
        """The container smoke test has no Discord identity, and must not have to invent one."""
        config = SupportBotConfig.from_env({"SUPPORT_BOT_DRY_RUN": "true"})

        self.assertTrue(config.dry_run)
        self.assertEqual(config.discord_token, "")
        self.assertEqual(config.discord_guild_id, 0)

    def test_a_dry_run_still_validates_what_it_is_given(self) -> None:
        with self.assertRaises(ConfigurationError):
            SupportBotConfig.from_env({"SUPPORT_BOT_DRY_RUN": "true", "SUPPORT_BOT_LOG_FORMAT": "xml"})


class TestTheTokenNeverLeaks(unittest.TestCase):
    """A credential printed once in a log or a traceback is a credential to rotate."""

    def setUp(self) -> None:
        self.config = SupportBotConfig.from_env(MINIMAL)

    def test_repr_is_redacted(self) -> None:
        rendered = repr(self.config)

        self.assertNotIn("a-token", rendered)
        self.assertNotIn("a-worker-secret", rendered)
        self.assertIn(REDACTED, rendered)

    def test_the_loggable_mapping_is_redacted(self) -> None:
        self.assertEqual(self.config.redacted()["discord_token"], REDACTED)

    def test_the_worker_secret_is_redacted_too(self) -> None:
        """It is a credential like the token: it is what proves the bot to the Worker."""
        self.assertEqual(self.config.redacted()["worker_secret"], REDACTED)

    def test_no_secret_survives_a_full_render_of_the_configuration(self) -> None:
        """Enumerated from the values, not from a list of the two that are secret today."""
        rendered = f"{self.config!r} {self.config.redacted()}"

        for secret in ("a-token", "a-worker-secret"):
            with self.subTest(secret=secret):
                self.assertNotIn(secret, rendered)

    def test_an_absent_token_is_not_masked_into_looking_present(self) -> None:
        """A dry run must read as "no token", not as "a token I am hiding from you"."""
        config = SupportBotConfig.from_env({"SUPPORT_BOT_DRY_RUN": "true"})

        self.assertEqual(config.redacted()["discord_token"], "")
        self.assertEqual(config.redacted()["worker_secret"], "")

    def test_no_reader_echoes_the_value_it_rejected(self) -> None:
        """The leak that was measured: a token pasted into the wrong variable, printed in full.

        The two Discord variables sit next to each other in ``.env.example``, both are long opaque
        strings copied out of the same Discord screen, and the message below is printed at
        ``CRITICAL`` on stdout — straight into a container log collector. Every reader that refuses a
        value is checked, not only the one the slip was measured on.
        """
        token = "MTIzNDU2Nzg5.SECRET-TOKEN-CANARY.abcdefg"
        rejecting = {
            "SUPPORT_BOT_DISCORD_GUILD_ID": "integer",
            "SUPPORT_BOT_HEALTH_PORT": "port",
            "SUPPORT_BOT_LOG_LEVEL": "choice",
            "SUPPORT_BOT_LOG_FORMAT": "choice",
            "SUPPORT_BOT_HEARTBEAT_SECONDS": "seconds",
            "SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS": "seconds",
            "SUPPORT_BOT_DRY_RUN": "flag",
            "SUPPORT_BOT_WORKER_ENDPOINT": "url",
            "SUPPORT_BOT_QUOTA_GLOBAL_PER_DAY": "integer",
            "SUPPORT_BOT_QUOTA_USER_PER_DAY": "integer",
            "SUPPORT_BOT_QUOTA_USER_PER_WINDOW": "integer",
            "SUPPORT_BOT_QUOTA_USER_WINDOW_SECONDS": "seconds",
        }
        for variable, reader in rejecting.items():
            with self.subTest(variable=variable, reader=reader):
                with self.assertRaises(ConfigurationError) as raised:
                    SupportBotConfig.from_env({**MINIMAL, variable: token})

                message = str(raised.exception)
                self.assertNotIn(token, message)
                self.assertNotIn("SECRET-TOKEN-CANARY", message)
                # Still diagnosable: the variable is named, and so is what was expected of it.
                self.assertIn(variable, message)

    def test_a_rejected_value_is_still_described_usefully(self) -> None:
        """Naming the variable is not enough — the operator needs to recognise their own mistake."""
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_HEALTH_PORT": '"8081"'})

        message = str(raised.exception)
        self.assertIn("is not an integer", message)
        self.assertIn("6 characters", message)
        self.assertIn("quotes included", message)

    def test_a_value_that_parsed_is_reported_as_parsed(self) -> None:
        """A number that got through ``int()`` is not a credential, and hiding it helps nobody."""
        with self.assertRaises(ConfigurationError) as raised:
            SupportBotConfig.from_env({**MINIMAL, "SUPPORT_BOT_HEALTH_PORT": "70000"})

        self.assertIn("SUPPORT_BOT_HEALTH_PORT=70000", str(raised.exception))

    def test_redacted_covers_every_field_of_the_configuration(self) -> None:
        """A field added later must appear in the startup log, not quietly go unreported."""
        from dataclasses import fields

        self.assertEqual(sorted(self.config.redacted()), sorted(f.name for f in fields(self.config)))


if __name__ == "__main__":
    unittest.main()
