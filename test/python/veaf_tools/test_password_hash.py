"""`password-hash`: the SHA-1 `security.password_hashes` takes, made by the user (FIX-COWORK-SESSION-FINDINGS 07)."""

import hashlib

from typer.testing import CliRunner
from veaf_tools.app import app
from veaf_tools.command_tree import group_of
from veaf_tools.commands.password_hash import password_sha1

runner = CliRunner()


def test_the_hash_is_veafsecuritys_lowercase_sha1() -> None:
    assert password_sha1("secret") == hashlib.sha1(b"secret").hexdigest()
    assert password_sha1("élan") == hashlib.sha1("élan".encode()).hexdigest()


def test_the_command_prints_the_hash_and_never_the_password() -> None:
    result = runner.invoke(app, ["password-hash"], input="Tr4kd4h!\nTr4kd4h!\n")
    assert result.exit_code == 0, result.output
    assert password_sha1("Tr4kd4h!") in result.output
    assert "Tr4kd4h!" not in result.output


def test_two_different_entries_are_asked_again() -> None:
    result = runner.invoke(app, ["password-hash"], input="one\ntwo\nthree\nthree\n")
    assert result.exit_code == 0, result.output
    assert password_sha1("three") in result.output


def test_it_is_filed_with_the_mission_commands() -> None:
    assert group_of("password-hash") == "mission"
