"""Which response profile the server runs: `standard` (the default) or `compact` (MCP-CONTEXT-BUDGET).

`standard` answers as the server always has, for Claude and every large-context client: the whole guide,
a whole prompt, a whole file slice, every answer uncut. `compact` is for a local model at about 65 000
tokens of context: the guide and the prompts by section, an 8 000-character ceiling on every answer,
shorter listings. A cut answer or a guide read section by section costs a large-context client round
trips and nothing in return, so the economy is opt-in, never the default.

The profile is read from the environment at every call, so the MCP configuration that launches the server
chooses it: the tutorial's `llama-server` configuration carries `"env": {"VEAF_MCP_PROFILE": "compact"}`,
and the user sets nothing.
"""

import os

#: The environment variable that selects the profile.
PROFILE_ENV_VAR = "VEAF_MCP_PROFILE"
#: The profiles, the default first.
PROFILES: tuple[str, ...] = ("standard", "compact")


def current_profile() -> str:
    """Return the profile the server answers in.

    Returns:
        `compact` when the environment asks for it, `standard` otherwise (an unknown value included).
    """
    value = os.environ.get(PROFILE_ENV_VAR, "").strip().lower()
    return value if value in PROFILES else PROFILES[0]


def is_compact() -> bool:
    """Return whether the server answers in the compact profile."""
    return current_profile() == "compact"
