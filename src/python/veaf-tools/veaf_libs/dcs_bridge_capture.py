"""Shared dcs-bridge helpers to collect a theatre's airbase data at runtime.

Used by both the maker-facing ``veaf-tools`` CLI (``capture-map`` / ``inject-bridge``)
and the dev ``veaf-build update-dcs-data --airdromes`` regeneration:

- :func:`resolve_bridge_lua` — locate/download ``dcs-bridge.lua``.
- :func:`inject_bridge` — embed it + a start trigger into any ``.miz`` (editor-parity).
- :func:`capture_airbases` — with that mission running and ``dcs-serve`` up, run
  ``world.getAirbases()`` over the bridge (``POST /api/exec``) and return the theatre
  plus one ``{id, name, lat, lon, coalition}`` record per airbase.
- :func:`write_airbase_dump` — persist a capture as ``<theatre>.json``.

Names are exact ``Airbase:getName()`` values (what ``airport_link`` / ``Airbase.getByName``
expect). ``coalition`` reflects the *running mission* (0/neutral in an empty bridge
mission), not a fixed map property — kept for completeness.
"""

from __future__ import annotations

import json
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import yaml

# Kept in sync with mission_builder_worker's bridge download URL.
DCS_BRIDGE_DOWNLOAD_URL = (
    "https://raw.githubusercontent.com/VEAF/VEAF-dcs-bridge/refs/heads/develop/src/lua/dcs-bridge.lua"
)

DEFAULT_SERVE_URL = "http://127.0.0.1:8080"

#: Config files `dcs-serve` / `dcs-client` write their generated `api_key` into. Looked up
#: (in this order) in the working directory then next to the running executable, so a maker
#: never has to copy the key by hand — the kit ships the exe alongside `dcs-serve.yaml`.
API_KEY_CONFIG_FILES = ("dcs-serve.yaml", "dcs-client.yaml")


def _candidate_config_dirs() -> list[Path]:
    """Return the directories searched for a bridge config, most specific first."""
    dirs = [Path.cwd()]
    # When frozen by PyInstaller, sys.executable is the .exe the maker double-clicks;
    # the kit puts dcs-serve.yaml right next to it.
    exe_dir = Path(sys.executable).parent if getattr(sys, "frozen", False) else None
    if exe_dir and exe_dir not in dirs:
        dirs.append(exe_dir)
    return dirs


def resolve_api_key(api_key: str | None = None, config: str | None = None) -> str:
    """Resolve the dcs-serve API key, reading a bridge config file when not given.

    Resolution order: explicit *api_key*, then the ``api_key`` field of *config* when
    provided, then the first :data:`API_KEY_CONFIG_FILES` found in the working directory
    or next to the executable.

    Args:
        api_key: Key passed explicitly (wins when set; also fed by ``DCS_BRIDGE_API_KEY``).
        config: Explicit path to a ``dcs-serve.yaml`` / ``dcs-client.yaml``.

    Returns:
        The resolved API key.

    Raises:
        FileNotFoundError: If *config* is given but does not exist.
        RuntimeError: If no key could be found, or the config carries no ``api_key``.
    """
    if api_key:
        return api_key

    if config:
        cfg_path = Path(config)
        if not cfg_path.is_file():
            raise FileNotFoundError(f"config file not found: {cfg_path}")
        candidates = [cfg_path]
    else:
        candidates = [d / name for d in _candidate_config_dirs() for name in API_KEY_CONFIG_FILES]

    for path in candidates:
        if not path.is_file():
            continue
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        key = str(data.get("api_key") or "").strip()
        if key:
            return key
        if config:  # explicitly pointed at a file that has no key: say so
            raise RuntimeError(f"no 'api_key' field in {path}")

    searched = ", ".join(str(p) for p in candidates)
    raise RuntimeError(
        "no API key found — start dcs-serve once so it writes its dcs-serve.yaml next to this "
        f"program, or pass --api-key. Looked in: {searched}"
    )


# Field separator for the capture snippet's rows (a name never contains a tab).
_SEP = "\t"

# Lua run over the bridge. First line: the theatre. Then one tab-separated
# `id, name, lat, lon, coalition` row per AIRDROME airbase (helipads included).
_CAPTURE_LUA = """
local out = { tostring(env.mission.theatre) }
local rows = {}
for _, ab in ipairs(world.getAirbases()) do
  local ok, desc = pcall(function() return ab:getDesc() end)
  if ok and desc and desc.category == Airbase.Category.AIRDROME then
    local p = ab:getPoint()
    local lat, lon = coord.LOtoLL(p)
    rows[#rows + 1] = {
      id = ab:getID(),
      line = string.format("%d\\t%s\\t%.6f\\t%.6f\\t%d", ab:getID(), ab:getName(), lat, lon, ab:getCoalition()),
    }
  end
end
table.sort(rows, function(a, b) return a.id < b.id end)
for _, r in ipairs(rows) do out[#out + 1] = r.line end
return table.concat(out, "\\n")
"""


def resolve_bridge_lua(lua_path: str | None) -> Path:
    """Resolve ``dcs-bridge.lua`` to a local path, downloading it when none is given.

    Args:
        lua_path: Explicit path to a local ``dcs-bridge.lua``, or ``None`` to
            auto-download the pinned URL into a temp file.

    Returns:
        Path to the bridge Lua source.

    Raises:
        FileNotFoundError: If *lua_path* is set but does not exist.
        RuntimeError: If the auto-download fails.
    """
    if lua_path:
        p = Path(lua_path)
        if not p.exists():
            raise FileNotFoundError(f"dcs-bridge.lua not found: {p}")
        return p
    try:
        with urllib.request.urlopen(DCS_BRIDGE_DOWNLOAD_URL) as resp:  # noqa: S310 - fixed trusted URL
            content: bytes = resp.read()
    except urllib.error.URLError as exc:
        raise RuntimeError(f"failed to download dcs-bridge.lua: {exc}") from exc
    tmp = tempfile.NamedTemporaryFile(suffix=".lua", delete=False)
    tmp.write(content)
    tmp.close()
    return Path(tmp.name)


def inject_bridge(miz_path: Path, bridge_lua: Path) -> dict[str, object]:
    """Embed ``dcs-bridge.lua`` and a mission-start load trigger into a ``.miz`` (in place).

    The mission is backed up first (by the underlying editor-parity helper).

    Args:
        miz_path: The mission ``.miz`` to turn into a bridge mission.
        bridge_lua: Local path to the ``dcs-bridge.lua`` to embed.

    Returns:
        ``{"trigger_index": <int>, "comment": <str>}``.
    """
    from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger  # noqa: PLC0415

    return add_startup_script_trigger(
        miz_path,
        mode="file_static",
        comment="dcs-bridge loading",
        source_path=str(bridge_lua),
        resource_name="dcs-bridge.lua",
    )


def _parse_capture(result: str) -> tuple[str, list[dict[str, Any]]]:
    """Parse the capture snippet's raw result into ``(theatre, airbases)``."""
    if not result or result.startswith("Error:"):
        raise RuntimeError(f"bridge exec failed or empty (mission running with the bridge?): {result!r}")
    lines = result.splitlines()
    theatre = lines[0].strip()
    airbases: list[dict[str, Any]] = []
    for line in lines[1:]:
        if not line.strip():
            continue
        parts = line.split(_SEP)
        if len(parts) != 5:
            continue
        id_str, name, lat, lon, coal = parts
        airbases.append(
            {
                "id": int(id_str),
                "name": name,
                "lat": round(float(lat), 6),
                "lon": round(float(lon), 6),
                "coalition": int(coal),
            }
        )
    if not theatre or not airbases:
        raise RuntimeError(f"unexpected capture result (no theatre or no airbases): {result!r}")
    return theatre, airbases


def capture_airbases(serve_url: str, api_key: str, timeout: float = 30.0) -> tuple[str, list[dict[str, Any]]]:
    """Capture the running mission's airbases over the bridge (`POST /api/exec`).

    Args:
        serve_url: Base URL of the ``dcs-serve`` HTTP API (e.g. ``http://127.0.0.1:8080``).
        api_key: The superuser Bearer token (``dcs-serve.yaml`` / ``dcs-client.yaml``).
        timeout: HTTP request timeout, in seconds.

    Returns:
        ``(theatre, airbases)`` — the DCS theatre string and one
        ``{id, name, lat, lon, coalition}`` record per airbase (sorted by id).

    Raises:
        RuntimeError: If the server is unreachable, returns a non-200, or the Lua
            snippet errors / yields an empty result.
    """
    body = json.dumps({"code": _CAPTURE_LUA, "timeout": timeout}).encode("utf-8")
    req = urllib.request.Request(  # noqa: S310 - user-provided local serve URL
        f"{serve_url.rstrip('/')}/api/exec",
        data=body,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 504:
            raise RuntimeError(
                "dcs-serve got no reply from DCS (504) — is the mission started and the bridge connected?"
            ) from exc
        if exc.code in (401, 403):
            raise RuntimeError(
                f"dcs-serve refused the request (HTTP {exc.code}) — is the API key a superuser?"
            ) from exc
        raise RuntimeError(f"dcs-serve returned HTTP {exc.code} ({exc.reason})") from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise RuntimeError(
            f"cannot reach dcs-serve at {serve_url} (is dcs-serve running and the mission started?): {exc}"
        ) from exc

    result = str(payload.get("result", "")) if isinstance(payload, dict) else ""
    return _parse_capture(result)


def write_airbase_dump(theatre: str, airbases: list[dict[str, Any]], out_dir: Path) -> Path:
    """Write a capture as ``<theatre>.json`` (pretty, stable key order).

    Args:
        theatre: DCS theatre string (the file stem, e.g. ``Syria``).
        airbases: The ``{id, name, lat, lon, coalition}`` records.
        out_dir: Directory to write into (created if missing).

    Returns:
        The path of the written ``.json``.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{theatre}.json"
    doc = {"theatre": theatre, "airbases": airbases}
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return out
