"""Migrate a v5-style missionConfig.lua to the v6 format.

Transformations applied:
- ``doFile(...)`` calls loading VEAF ``.lua`` scripts are commented out; the
  v6 builder injects them automatically via ``veaf-scripts.lua``.
- Bare ``veafXxx.initialize(...)`` calls that sit at the top-level scope
  (outside an ``if veafXxx then … end`` guard) are wrapped in the guard.
- All ``if veafXxx then … end`` blocks are scanned to collect the list of
  modules that are initialised, which is used to generate the ``lua_modules``
  YAML snippet.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from veaf_libs.lua_module_scanner import get_modules

# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class MigrationResult:
    """Holds the output of a migration run."""

    new_content: str
    """The transformed missionConfig.lua content."""

    enabled_modules: list[str] = field(default_factory=list)
    """Module IDs whose ``initialize()`` call was found (in a guard or bare)."""

    removed_dofiles: list[str] = field(default_factory=list)
    """Human-readable descriptions of each ``doFile`` call that was commented out."""

    wrapped_calls: list[str] = field(default_factory=list)
    """Human-readable descriptions of each bare ``initialize()`` call that was wrapped."""

    yaml_snippet: str = ""
    """``lua_modules:`` YAML block suitable for pasting into ``mission.yaml``."""

    warnings: list[str] = field(default_factory=list)
    """Items that could not be migrated automatically and need manual review."""


# ---------------------------------------------------------------------------
# Migrator
# ---------------------------------------------------------------------------


class ConfigMigrator:
    """Stateless migrator — call :meth:`migrate` with the file content."""

    # ``doFile(...)`` referencing any ``.lua`` file with ``veaf`` in its path/name.
    _DOFILE_RE = re.compile(r"doFile\s*\([^)]*veaf[^)]*\.lua[^)]*\)", re.IGNORECASE)

    # Bare ``veafXxx.initialize(...)`` — module variable followed by ``.initialize(``.
    _BARE_INIT_RE = re.compile(r"^(\s*)(veaf\w+)\.initialize\s*\(")

    # ``if veafXxx then`` guard opening.
    _IF_VEAF_RE = re.compile(r"^\s*if\s+(veaf\w+)\s+then\b")

    # Opening keywords that increase nesting depth in Lua.
    _OPEN_KW_RE = re.compile(r"\b(if|for|while|repeat|function|do)\b")
    # ``elseif`` contains "if" but does NOT increase depth.
    _ELSEIF_RE = re.compile(r"\belseif\b")
    # Closing keywords.
    _CLOSE_KW_RE = re.compile(r"\b(end|until)\b")

    def __init__(self) -> None:
        # Build {variable_name: module_id} from the module list.
        # e.g. "veafSpawn" → "SPAWN"
        self._var_to_id: dict[str, str] = {}
        for mod in get_modules():
            var_name = mod["filename"].removesuffix(".lua")
            self._var_to_id[var_name] = mod["id"]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _net_depth(line: str) -> int:
        """Return the net Lua nesting-depth change produced by *line*.

        Strips inline comments before counting so keywords inside ``-- …``
        comments are not counted.  The heuristic is intentionally simple and
        good enough for typical well-formatted ``missionConfig.lua`` files.
        """
        # Remove inline comments.
        no_comment = re.sub(r"--(?!\[).*$", "", line)
        opens = len(ConfigMigrator._OPEN_KW_RE.findall(no_comment))
        # elseif contains 'if' → subtract those; they don't open a new block.
        opens -= len(ConfigMigrator._ELSEIF_RE.findall(no_comment))
        closes = len(ConfigMigrator._CLOSE_KW_RE.findall(no_comment))
        return opens - closes

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def migrate(self, content: str) -> MigrationResult:
        """Transform *content* and return a :class:`MigrationResult`."""
        lines = content.splitlines()

        output: list[str] = []
        enabled_modules: list[str] = []
        removed_dofiles: list[str] = []
        wrapped_calls: list[str] = []
        warnings: list[str] = []

        depth = 0  # overall Lua nesting depth (0 = file top-level)
        block_comment_depth = 0  # depth of ``--[[ … ]]`` nesting

        for lineno, raw_line in enumerate(lines, 1):
            stripped = raw_line.strip()

            # ── Block-comment tracking ──────────────────────────────────────
            opens_bc = stripped.count("--[[")
            if block_comment_depth > 0:
                closes_bc = stripped.count("]]")
                block_comment_depth = max(0, block_comment_depth - closes_bc + opens_bc)
                output.append(raw_line)
                continue
            if opens_bc > 0:
                closes_bc = stripped.count("]]")
                net = opens_bc - closes_bc
                if net > 0:
                    block_comment_depth = net
                # Line that opens and immediately closes (or is entirely in one
                # line) falls through to normal processing below.
                output.append(raw_line)
                continue

            # ── Single-line comment → pass through ─────────────────────────
            if stripped.startswith("--"):
                output.append(raw_line)
                continue

            # ── doFile loading a VEAF script → comment out ─────────────────
            if self._DOFILE_RE.search(raw_line):
                output.append(
                    f"-- [v6 migration] {raw_line.rstrip()}"
                    "  -- removed: the builder injects veaf-scripts.lua automatically"
                )
                removed_dofiles.append(f"line {lineno}: {stripped}")
                depth += self._net_depth(raw_line)
                continue

            # ── Detect ``if veafXxx then`` at top level → record module ────
            if_guard_m = self._IF_VEAF_RE.match(raw_line)
            if if_guard_m and depth == 0:
                mod_var = if_guard_m.group(1)
                mod_id = self._var_to_id.get(mod_var, mod_var)
                if mod_id not in enabled_modules:
                    enabled_modules.append(mod_id)

            # ── Bare initialize() at top level → wrap in guard ─────────────
            bare_init_m = self._BARE_INIT_RE.match(raw_line)
            if bare_init_m and depth == 0:
                indent = bare_init_m.group(1)
                mod_var = bare_init_m.group(2)
                mod_id = self._var_to_id.get(mod_var, mod_var)
                output.append(f"{indent}if {mod_var} then")
                output.append(raw_line)
                output.append(f"{indent}end")
                wrapped_calls.append(f"line {lineno}: {stripped}")
                if mod_id not in enabled_modules:
                    enabled_modules.append(mod_id)
                # The bare call doesn't change depth by itself.
                depth += self._net_depth(raw_line)
                continue

            # ── Default: keep the line unchanged ───────────────────────────
            output.append(raw_line)
            depth += self._net_depth(raw_line)

        # ── Build YAML snippet ──────────────────────────────────────────────
        yaml_snippet = self._build_yaml_snippet(enabled_modules)

        return MigrationResult(
            new_content="\n".join(output),
            enabled_modules=enabled_modules,
            removed_dofiles=removed_dofiles,
            wrapped_calls=wrapped_calls,
            yaml_snippet=yaml_snippet,
            warnings=warnings,
        )

    def _build_yaml_snippet(self, enabled_modules: list[str]) -> str:
        """Generate a ``lua_modules:`` YAML block for ``mission.yaml``."""
        lines: list[str] = ["lua_modules:"]
        enabled_set = set(enabled_modules)

        for mod in get_modules():
            mid = mod["id"]
            # Quote the key if it contains non-identifier characters (spaces, dashes, …).
            yaml_key = f'"{mid}"' if not re.match(r"^[A-Za-z_]\w*$", mid) else mid
            if mid in enabled_set:
                lines.append(f"  {yaml_key}:")
                lines.append("    enable: true")
            else:
                lines.append(f"  # {yaml_key}:")
                lines.append("  #   enable: false  # not found in missionConfig.lua")

        return "\n".join(lines)
