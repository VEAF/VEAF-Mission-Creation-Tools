"""Redaction is the safety net under everything `doctor` invites a user to publish.

The block goes into a **public** issue, pasted by someone who will not reread it. Each test below
pins one thing that must never survive that paste — and, just as important, one thing that must
(a loopback address, a version number), because a redactor that eats the diagnosis is useless.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from veaf_libs.redaction import (
    EMAIL_PLACEHOLDER,
    IP_PLACEHOLDER,
    SECRET_PLACEHOLDER,
    USER_PLACEHOLDER,
    redact,
    redact_path,
)


class TestWindowsUserPaths(unittest.TestCase):
    """The single most common leak: every Windows path carries the account name."""

    def test_a_windows_user_path_loses_the_account_name(self) -> None:
        out = redact(r"C:\Users\Jean Dupont\Saved Games\DCS\Logs\dcs.log")
        self.assertNotIn("Jean Dupont", out)
        self.assertIn(rf"C:\Users\{USER_PLACEHOLDER}\Saved Games", out)

    def test_the_rest_of_the_path_is_kept(self) -> None:
        # Where the file sits is the diagnostic half; only who owns it is personal.
        out = redact(r"C:\Users\dpierron\.veaf\veaf-tools.log")
        self.assertIn(r"\.veaf\veaf-tools.log", out)

    def test_a_posix_home_is_redacted_too(self) -> None:
        self.assertEqual(redact("/home/david/.veaf"), f"/home/{USER_PLACEHOLDER}/.veaf")

    def test_a_macos_home_is_redacted_too(self) -> None:
        self.assertEqual(redact("/Users/david/.veaf"), f"/Users/{USER_PLACEHOLDER}/.veaf")

    def test_several_occurrences_in_one_line(self) -> None:
        out = redact(r"copied C:\Users\Bob\a.miz to C:\Users\Bob\b.miz")
        self.assertNotIn("Bob", out)

    def test_redact_path_accepts_a_path_object(self) -> None:
        self.assertNotIn("Bob", redact_path(Path(r"C:\Users\Bob\mission.miz")))

    def test_redact_path_of_none_is_empty(self) -> None:
        self.assertEqual(redact_path(None), "")


class TestAddresses(unittest.TestCase):
    def test_an_ipv4_address_is_replaced(self) -> None:
        self.assertEqual(redact("connected to 192.168.1.42:10308"), f"connected to {IP_PLACEHOLDER}:10308")

    def test_loopback_is_kept_because_it_says_something(self) -> None:
        # "the bridge answered on 127.0.0.1" is a diagnosis; "<ip>" is not.
        self.assertIn("127.0.0.1", redact("bridge listening on 127.0.0.1:8080"))

    def test_a_four_part_version_number_is_not_an_address(self) -> None:
        # The regression this guards: `DCS/2.9.29.27278` is four dotted groups and would be
        # destroyed by a lazy dotted-quad pattern, taking the DCS version with it.
        self.assertIn("2.9.29.27278", redact("DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)"))

    def test_a_windows_build_number_survives(self) -> None:
        self.assertIn("10.0.26200", redact("Windows-11-10.0.26200-SP0"))


class TestSecrets(unittest.TestCase):
    def test_a_token_shaped_string_is_replaced(self) -> None:
        out = redact("session=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5")
        self.assertNotIn("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5", out)
        self.assertIn(SECRET_PLACEHOLDER, out)

    def test_a_labelled_token_is_replaced(self) -> None:
        self.assertEqual(redact("token=abcdef"), f"token={SECRET_PLACEHOLDER}")

    def test_a_password_is_replaced(self) -> None:
        self.assertIn(SECRET_PLACEHOLDER, redact('password: "hunter2"'))

    def test_a_bearer_scheme_does_not_shield_the_token(self) -> None:
        # The scheme word must be swallowed with the value; treating "Bearer" as the value would
        # leave the actual credential in the clear.
        out = redact("Authorization: Bearer sk-verylongsecretvalue")
        self.assertNotIn("sk-verylongsecretvalue", out)

    def test_a_github_token_prefix_is_replaced(self) -> None:
        self.assertNotIn("ghp_", redact("using ghp_0123456789abcdefghijklmnop for the release"))

    def test_ordinary_prose_is_left_alone(self) -> None:
        text = "Failed to evaluate time expression: unsupported operator"
        self.assertEqual(redact(text), text)

    def test_a_module_name_is_not_mistaken_for_a_secret(self) -> None:
        self.assertEqual(redact("veafCombatMission"), "veafCombatMission")


class TestEmails(unittest.TestCase):
    def test_an_email_is_replaced(self) -> None:
        self.assertEqual(redact("reported by pilot@example.org"), f"reported by {EMAIL_PLACEHOLDER}")


class TestEdges(unittest.TestCase):
    def test_empty_text_is_returned_as_is(self) -> None:
        self.assertEqual(redact(""), "")

    def test_redaction_is_idempotent(self) -> None:
        # The block may be redacted again downstream (FEAT-SUPPORT-BUG-INTAKE); a second pass must
        # not chew through the placeholders the first one produced.
        once = redact(r"C:\Users\Bob\a.log 10.1.2.3 token=abcdef pilot@example.org")
        self.assertEqual(redact(once), once)


if __name__ == "__main__":
    unittest.main()
