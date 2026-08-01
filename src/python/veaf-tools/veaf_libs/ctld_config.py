"""The CTLD 2 configuration catalogue, read out of the vendored engine.

CTLD 2 embeds its own defaults in the deliverable as a long-bracket Lua string
(``ctld.configDefault``), and reads a mission's configuration from a **complete**
YAML snapshot: a missing setting falls back to the default, but a missing list is
an intentional removal. A mission's ``ctld-config.yaml`` therefore starts as a copy
of that catalogue rather than as a diff.

Reading it from the vendored ``CTLD.lua`` — instead of keeping a copy in this repo —
is what keeps the two in step: a CTLD release that adds a crate section or an
aircraft type is picked up by the next scaffold, with nothing to update here.

See docs/adr/0016-ctld2-sidecar-configuration.md.
"""

from __future__ import annotations

import re
from pathlib import Path

#: The mission's CTLD 2 configuration: a complete YAML snapshot, authored in
#: ctld-tools, living beside mission.yaml.
CTLD_CONFIG_FILENAME = "ctld-config.yaml"

#: The Lua wrapper the build generates from it, loaded immediately before CTLD.lua.
#: Same name as CTLD's own template, so a mission maker opening the .miz recognises it.
CTLD_USER_CONFIG_FILENAME = "CTLD_userConfig.lua"

#: ``ctld.configDefault = [[ … ]]``, at whatever bracket level the build chose.
#: The level is captured so the closing sequence matched is the matching one — a
#: level-1 document contains ``]]`` freely.
_CONFIG_DEFAULT_RE = re.compile(r"ctld\.configDefault\s*=\s*\[(=*)\[\r?\n(.*?)\]\1\]", re.DOTALL)


def extract_default_config(ctld_lua: str) -> str | None:
    """Extract the default configuration YAML from a CTLD 2 deliverable.

    Args:
        ctld_lua: The full text of ``CTLD.lua``.

    Returns:
        The YAML document, or ``None`` when the assignment is absent — which is what
        a CTLD v1 script, or a future version that stopped embedding its defaults,
        looks like. Callers must treat ``None`` as "cannot scaffold", never as empty.
    """
    match = _CONFIG_DEFAULT_RE.search(ctld_lua)
    return match.group(2) if match else None


def read_default_config(ctld_lua_path: Path) -> str | None:
    """Extract the default configuration YAML from a ``CTLD.lua`` file.

    Args:
        ctld_lua_path: Path to the vendored CTLD deliverable.

    Returns:
        The YAML document, or ``None`` when the file is missing or carries no
        ``ctld.configDefault``.
    """
    if not ctld_lua_path.is_file():
        return None
    return extract_default_config(ctld_lua_path.read_text(encoding="utf-8", errors="replace"))
