"""Redaction is the safety net under everything `doctor` invites a user to publish.

The block goes into a **public** issue, pasted by someone who will not reread it. Each test below
pins one thing that must never survive that paste — and, just as important, one thing that must
(a loopback address, a version number), because a redactor that eats the diagnosis is useless.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path
from unittest.mock import patch

from veaf_libs import redaction
from veaf_libs.redaction import (
    EMAIL_PLACEHOLDER,
    IP_PLACEHOLDER,
    SECRET_PLACEHOLDER,
    USER_PLACEHOLDER,
    redact,
    redact_path,
)

#: The repository root, three levels above ``test/python/veaf_libs/``.
_REPO_ROOT = Path(__file__).resolve().parents[3]

#: Where the identifier sweep below reads from: the Lua the tool ships and injects, the default
#: mission folder, and the test fixtures — i.e. every place real DCS names live in this repository.
_IDENTIFIER_SOURCES = (
    "src/scripts/**/*.lua",
    "src/defaults/**/*.yaml",
    "src/defaults/**/*.lua",
    "test/**/*.yaml",
    "test/**/*.json",
)

#: The shape the deleted entropy rule keyed on: a run of 16+ characters mixing letters and digits.
#: The sweep enumerates every string of that shape the repository actually contains rather than
#: sampling a few by hand — the point of the regression is that the hand-picked example
#: (``veafCombatMission``, 17 characters and no digit) could not match the rule it was guarding.
_IDENTIFIER = re.compile(r"(?<![\w-])(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{16,}(?![\w-])")


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

    def test_a_four_part_version_that_does_fit_in_four_octets_survives(self) -> None:
        # `2.9.29.27278` was saved only by its last group being above 255. `DCS/2.9.10.1` is a real
        # version that fits, and it became `DCS/<ip>` — the single most useful field of the report.
        self.assertEqual(redact("DCS/2.9.10.1 (x86_64; MT)"), "DCS/2.9.10.1 (x86_64; MT)")

    def test_an_address_in_a_url_is_still_an_address(self) -> None:
        # The rule that saves `DCS/2.9.10.1` keys on `<letter>/`; `//` is a URL, not a version.
        self.assertEqual(redact("http://10.1.2.3/status"), f"http://{IP_PLACEHOLDER}/status")

    def test_the_whole_loopback_block_is_kept(self) -> None:
        # 127.0.1.1 is the usual Debian entry in /etc/hosts, and just as diagnostic as 127.0.0.1.
        self.assertIn("127.0.1.1", redact("resolved to 127.0.1.1"))

    def test_an_ipv6_address_is_replaced(self) -> None:
        for address in ("fe80::1c2b:3d4e:5f60:7a8b", "2001:db8::ff00:42:8329", "2001:db8:0:0:0:0:2:1"):
            with self.subTest(address=address):
                self.assertEqual(redact(f"peer {address} closed"), f"peer {IP_PLACEHOLDER} closed")

    def test_the_ipv6_loopback_is_kept(self) -> None:
        self.assertIn("::1", redact("bridge listening on ::1"))

    def test_a_timestamp_is_not_an_ipv6_address(self) -> None:
        # Every record header carries one, so a lax IPv6 pattern would destroy the whole log.
        line = "2026-09-05 12:00:00,123 - veaf-tools - ERROR - boom"
        self.assertEqual(redact(line), line)

    def test_a_lua_goto_label_is_not_an_ipv6_address(self) -> None:
        self.assertEqual(redact("goto ::continue::"), "goto ::continue::")


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

    def test_a_label_buried_in_a_longer_name_still_counts(self) -> None:
        # `_` is a word character, so `\btoken\b` never matched inside `access_token`: an OAuth
        # config pasted whole used to come through untouched.
        for text in ("access_token=abc.def.ghi", "client_secret=s3cr3tvalue", "x-api-key: 0123456789abcdef"):
            with self.subTest(text=text):
                self.assertIn(SECRET_PLACEHOLDER, redact(text))

    def test_a_json_key_is_not_shielded_by_its_closing_quote(self) -> None:
        # `\s*[:=]` could not cross the `"` that ends the key, so every pasted JSON configuration
        # leaked its token.
        out = redact('{"token": "abc123def456", "user": "bob"}')
        self.assertNotIn("abc123def456", out)

    def test_credentials_inside_a_url_are_replaced(self) -> None:
        out = redact("postgres://admin:sup3rs3cret@db.example.org:5432/veaf")
        self.assertNotIn("sup3rs3cret", out)
        self.assertNotIn("admin", out)

    def test_the_known_shapes_are_caught_without_a_label(self) -> None:
        # These leak by being pasted on their own, with nothing naming them.
        #
        # Every sample is assembled from fragments rather than written whole: GitHub's push
        # protection scans this repository and rejected the commit that spelt the Slack webhook out,
        # which is a fair verdict on a file whose whole subject is credential shapes.
        known = (
            "ghp_" + "0123456789abcdefghijklmnop",
            "github_pat_" + "11ABCDEFG0abcdefghijklmnopqrstuvwxyz",
            "xoxb-" + "123456789012-abcdefghijkl",
            "sk-proj-" + "abcdefghijklmnopqrstuvwx",
            "AKIA" + "IOSFODNN7EXAMPLE",
            "AIza" + "SyA1234567890abcdefghijklmnopqrstuvw",
            "eyJhbGciOiJIUzI1NiJ9." + "eyJzdWIiOiIxMjM0NSJ9." + "dBjftJeZ4CVPmB92K27uhbUJU1p1r",
            "https://discord.com/api/webhooks/" + "123456789012345678/AbCdEf-gh_IJKlmnop",
            "https://hooks.slack.com/services/" + "T00000000/B00000000/" + "X" * 24,
            "-----BEGIN RSA " + "PRIVATE KEY-----",
        )
        for secret in known:
            with self.subTest(secret=secret[:24]):
                self.assertIn(SECRET_PLACEHOLDER, redact(f"config says {secret} and stops there"))


class TestDcsIdentifiersAreNotSecrets(unittest.TestCase):
    """The rule that made `doctor` useless: `unknown payload <redacted>` instead of the payload.

    An entropy rule — any 24+ character run mixing letters and digits — was measured over the real
    `veaf-tools.log` (last 3 MB, 1489 `ERROR` records): **74 substitutions, not one credential**,
    every hit a temporary directory or the name of the thing that failed. The report kept "something
    broke" and threw away "what". The guard that was supposed to prevent this asserted on
    `veafCombatMission` — 17 characters, no digit — so it could not fail whatever the rule did.

    These tests enumerate the family instead of sampling it.
    """

    #: Real strings, copied from the files the sweep below reads. Kept explicit as well as swept so
    #: the failure message names the shape that broke rather than one of five hundred tokens.
    NAMED = (
        "HVAR_USN_Mk28_Mod4_Corsair",  # a payload, as a mission-load failure names it
        "M261_INBOARD_DE_M151_C_M274",  # a pylon
        "2x9M120_Ataka_V_with_adapter",  # a store with a digit-leading part
        "DictKey_descriptionText_1",  # a mission dictionary key
        "FBC29BFE-3D24-4C64-B81D-941239D12249",  # a livery id
        "Tripack-Caucasus-2026-01-15.miz",  # a mission file name
        "veafCombatMission",  # the original, kept for the record
        "channel_list_blue_primary_1",  # a configuration key seen in the real log
        "test_the_run_fails_and_the_file_is_kept",  # a test name, as a traceback prints it
    )

    def test_named_identifiers_survive(self) -> None:
        for identifier in self.NAMED:
            with self.subTest(identifier=identifier):
                self.assertEqual(redact(identifier), identifier)

    def test_a_payload_error_keeps_what_failed(self) -> None:
        text = "unknown payload HVAR_USN_Mk28_Mod4_Corsair on pylon M261_INBOARD_DE_M151_C_M274"
        self.assertEqual(redact(text), text)

    def test_no_identifier_in_the_repository_is_taken_for_a_secret(self) -> None:
        """Sweep every identifier of the offending shape the repository actually contains."""
        identifiers: set[str] = set()
        for pattern in _IDENTIFIER_SOURCES:
            for path in _REPO_ROOT.glob(pattern):
                identifiers.update(_IDENTIFIER.findall(path.read_text(encoding="utf-8", errors="replace")))
        self.assertGreater(len(identifiers), 100, "the sweep found almost nothing: the sources moved")
        eaten = sorted(token for token in identifiers if redact(token) != token)
        self.assertEqual(eaten, [], f"{len(eaten)} DCS identifier(s) redacted as if they were secrets")


class TestTheAccountNameNeverSurvives(unittest.TestCase):
    """It survived 56 times in 1489 real records, on lines whose home path *was* redacted.

    The home-directory rule only fires directly under ``Users/``, ``home/`` or ``Documents and
    Settings/``. The account name turns up far from there — in a temporary directory, a host name,
    an environment dump — and it is the one personal string the machine always knows.
    """

    def setUp(self) -> None:
        patcher = patch.object(
            redaction,
            "_account_patterns",
            lambda: (re.compile(r"(?<![<\w])David(?![>\w])", re.IGNORECASE),),
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_a_temp_path_outside_the_home_loses_it(self) -> None:
        out = redact(r"C:\Users\David\AppData\Local\Temp\pytest-of-David\pytest-1898\test0")
        self.assertNotIn("David", out)

    def test_a_userprofile_expansion_loses_it(self) -> None:
        self.assertNotIn("David", redact(r"%USERPROFILE% = C:\Users\David"))

    def test_an_environment_dump_loses_it(self) -> None:
        self.assertNotIn("David", redact("USERNAME=David COMPUTERNAME=DAVID-BUREAU"))

    def test_a_unc_share_loses_it(self) -> None:
        self.assertNotIn("DAVID", redact(r"\\DAVID-BUREAU\partage\missions"))

    def test_a_home_that_is_not_under_users_loses_it(self) -> None:
        self.assertNotIn("david", redact(r"D:\david\dev\veaf"))

    def test_it_stays_idempotent(self) -> None:
        once = redact(r"C:\Users\David\Temp\pytest-of-David")
        self.assertEqual(redact(once), once)


class TestWhichAccountNamesAreReplaced(unittest.TestCase):
    """The name is matched as a literal, so a name that is also a common word needs a floor."""

    def _names_for(self, account: str) -> tuple[str, ...]:
        redaction._account_patterns.cache_clear()
        self.addCleanup(redaction._account_patterns.cache_clear)
        with (
            patch.object(Path, "home", staticmethod(lambda: Path(f"C:/Users/{account}"))),
            patch("getpass.getuser", return_value=account),
        ):
            return tuple(pattern.pattern for pattern in redaction._account_patterns())

    def test_a_two_letter_account_is_left_alone(self) -> None:
        # It appears inside ordinary words; replacing it would shred the text it protects.
        self.assertEqual(self._names_for("jd"), ())

    def test_an_ordinary_account_is_replaced(self) -> None:
        self.assertEqual(len(self._names_for("dpierron")), 1)

    def test_an_account_named_after_a_placeholder_is_left_alone(self) -> None:
        # `user` inside `<user>` would make redaction non-idempotent.
        self.assertEqual(self._names_for("user"), ())


class TestEmails(unittest.TestCase):
    def test_an_email_is_replaced(self) -> None:
        self.assertEqual(redact("reported by pilot@example.org"), f"reported by {EMAIL_PLACEHOLDER}")

    def test_an_address_that_ends_a_sentence_is_replaced_too(self) -> None:
        # The trailing lookahead refused to end the match before a `.`, so the most ordinary case
        # of all — a log line finishing on an address — survived whole.
        self.assertEqual(redact("write to david@example.com."), f"write to {EMAIL_PLACEHOLDER}.")


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
