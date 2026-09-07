"""Logs are the only thing anyone reads when this service misbehaves, so they are tested.

Two properties matter beyond "it writes something": the structured fields survive to the JSON line
(an alert filters on ``event``, not on prose), and reconfiguring does not double every line — a
duplicated handler is a classic way to make a log file twice as long and half as trustworthy.
"""

from __future__ import annotations

import io
import json
import logging
import unittest

from veaf_support_bot.logging_setup import (
    ROOT_LOGGER_NAME,
    JsonLineFormatter,
    TextLineFormatter,
    build_formatter,
    configure_logging,
    get_logger,
)


class LoggingTestCase(unittest.TestCase):
    """Captures the service tree's output and restores it afterwards."""

    def setUp(self) -> None:
        self.stream = io.StringIO()

    def tearDown(self) -> None:
        root = logging.getLogger(ROOT_LOGGER_NAME)
        for handler in list(root.handlers):
            root.removeHandler(handler)
            handler.close()

    def lines(self) -> list[str]:
        """Return the non-empty lines written so far.

        Returns:
            One entry per emitted record.
        """
        return [line for line in self.stream.getvalue().splitlines() if line.strip()]


class TestJsonOutput(LoggingTestCase):
    def test_a_record_becomes_one_json_object_per_line(self) -> None:
        configure_logging(level="INFO", log_format="json", stream=self.stream)

        get_logger("health").info("listening", extra={"event": "health.listening", "port": 8081})

        (line,) = self.lines()
        payload = json.loads(line)
        self.assertEqual(payload["message"], "listening")
        self.assertEqual(payload["level"], "INFO")
        self.assertEqual(payload["logger"], f"{ROOT_LOGGER_NAME}.health")
        self.assertEqual(payload["event"], "health.listening")
        self.assertEqual(payload["port"], 8081)
        self.assertTrue(payload["ts"].endswith("+00:00"), payload["ts"])

    def test_an_unserialisable_extra_does_not_lose_the_line(self) -> None:
        """Losing a log line is precisely how a silent failure stays silent."""
        configure_logging(log_format="json", stream=self.stream)

        get_logger("service").info("odd", extra={"event": "x", "thing": object()})

        payload = json.loads(self.lines()[0])
        self.assertIn("object object", payload["thing"])

    def test_an_exception_is_carried_in_the_payload(self) -> None:
        configure_logging(log_format="json", stream=self.stream)

        try:
            raise ValueError("boom")
        except ValueError:
            get_logger("service").exception("failed", extra={"event": "service.failed"})

        payload = json.loads(self.lines()[0])
        self.assertIn("ValueError: boom", payload["exception"])

    def test_the_record_s_own_attributes_stay_out_of_the_payload(self) -> None:
        configure_logging(log_format="json", stream=self.stream)

        get_logger("service").info("hello", extra={"event": "e"})

        payload = json.loads(self.lines()[0])
        self.assertNotIn("msg", payload)
        self.assertNotIn("args", payload)
        self.assertNotIn("pathname", payload)


class TestTextOutput(LoggingTestCase):
    def test_the_readable_format_appends_the_structured_fields(self) -> None:
        configure_logging(log_format="text", stream=self.stream)

        get_logger("service").warning("dry run", extra={"event": "service.dry_run", "port": 1})

        (line,) = self.lines()
        self.assertIn("WARNING", line)
        self.assertIn("dry run", line)
        self.assertIn("event=service.dry_run", line)
        self.assertIn("port=1", line)

    def test_build_formatter_picks_the_right_one(self) -> None:
        self.assertIsInstance(build_formatter("text"), TextLineFormatter)
        self.assertIsInstance(build_formatter("json"), JsonLineFormatter)

    def test_an_unknown_format_falls_back_to_json(self) -> None:
        """Production is what a mistake should land in, not a format nothing parses."""
        self.assertIsInstance(build_formatter("yaml"), JsonLineFormatter)


class TestConfiguration(LoggingTestCase):
    def test_reconfiguring_replaces_the_handler_rather_than_adding_one(self) -> None:
        configure_logging(log_format="json", stream=self.stream)
        configure_logging(log_format="json", stream=self.stream)

        get_logger("service").info("once", extra={"event": "e"})

        self.assertEqual(len(self.lines()), 1)

    def test_the_level_is_honoured(self) -> None:
        configure_logging(level="WARNING", log_format="json", stream=self.stream)

        get_logger("service").info("invisible", extra={"event": "e"})
        get_logger("service").warning("visible", extra={"event": "e"})

        self.assertEqual(len(self.lines()), 1)

    def test_the_service_tree_does_not_leak_into_the_root_logger(self) -> None:
        configure_logging(log_format="json", stream=self.stream)

        self.assertFalse(logging.getLogger(ROOT_LOGGER_NAME).propagate)

    def test_module_loggers_hang_off_the_service_tree(self) -> None:
        self.assertEqual(get_logger("health").name, f"{ROOT_LOGGER_NAME}.health")


if __name__ == "__main__":
    unittest.main()
