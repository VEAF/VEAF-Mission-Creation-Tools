"""`password-hash` — turn a password into the SHA-1 hash `mission.yaml` holds (FIX-COWORK-SESSION-FINDINGS 07).

`security.password_hashes` takes SHA-1 hashes, never a password in clear, and nothing in the tools made
one: a mission maker who is not a developer had no way to protect a mission. The command asks for the
password with the input hidden, twice, and prints only the hash. It is run by the user, never by an
assistant: a password typed into a conversation with an AI has left the PC.
"""

import hashlib

import typer

from veaf_tools.app import app, console, t


def password_sha1(password: str) -> str:
    """The hash `veafSecurity` compares with, as its Lua `sha1.hex` writes it: lowercase hexadecimal.

    Args:
        password: The password, as typed.

    Returns:
        The SHA-1 of its UTF-8 bytes.
    """
    return hashlib.sha1(password.encode("utf-8")).hexdigest()  # noqa: S324 - the format veafSecurity reads


@app.command(name="password-hash", help=t("cmd.password_hash.help"))
def password_hash() -> None:
    password = typer.prompt(
        t("cmd.password_hash.prompt"), hide_input=True, confirmation_prompt=t("cmd.password_hash.confirm")
    )
    if not password:
        console.print(t("cmd.password_hash.empty"), style="red")
        raise typer.Exit(1)
    console.print(t("cmd.password_hash.result", hash=password_sha1(password)))
    console.print(t("cmd.password_hash.where"))
