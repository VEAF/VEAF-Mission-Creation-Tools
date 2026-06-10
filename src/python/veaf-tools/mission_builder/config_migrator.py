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

from veaf_libs.i18n import t
from veaf_libs.lua_config_generator import yaml_module_entry
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

    # ── YAML-009: identity / security / global_log_level ──────────────────────
    mission_name: str | None = None
    mission_era: str | None = None
    mission_export_path: str | None = None
    security_disabled: bool | None = None
    global_log_level_extracted: str | None = None
    skynet_config: dict | None = None

    # ── CONVERT-FIDELITY-003: silence ATC on all airbases ─────────────────────
    silence_atc: bool = False

    # ── MODULES-UNIFY-004: CTLD / CSAR settings (ctld.xxx / csar.xxx) ──────────
    ctld_config: dict = field(default_factory=dict)
    csar_config: dict = field(default_factory=dict)

    # ── YAML-010: Assets table ─────────────────────────────────────────────────
    assets_extracted: list[dict] | None = None

    # ── YAML-011: QRA chains ───────────────────────────────────────────────────
    qra_silence_all: bool | None = None
    qra_definitions: list[dict] = field(default_factory=list)

    # ── YAML-012: CAP / combat missions ───────────────────────────────────────
    cap_missions_extracted: list[dict] = field(default_factory=list)
    combat_missions_extracted: list[dict] = field(default_factory=list)

    # ── YAML-013: Shortcuts (VeafAlias) ───────────────────────────────────────
    shortcuts_extracted: list[dict] = field(default_factory=list)

    # ── YAML-014: Sanctuary zones ──────────────────────────────────────────────
    sanctuary_zones_extracted: list[dict] = field(default_factory=list)

    # ── YAML-015: CombatZone settings + zone definitions ──────────────────────
    combat_zone_settings_extracted: dict | None = None
    combat_zones_extracted: list[dict] = field(default_factory=list)

    # ── YAML-016: AirWaves zone definitions ───────────────────────────────────
    airwave_zones_extracted: list[dict] = field(default_factory=list)

    # ── YAML-017: Security MM password hashes ─────────────────────────────────
    password_mm_hashes: list[str] = field(default_factory=list)

    # ── Callback hints (cannot be expressed in YAML) ───────────────────────────
    callback_hints: list[str] = field(default_factory=list)
    """Lua snippets for callbacks that must be set manually in mission-script.lua."""


# ---------------------------------------------------------------------------
# Lua string helpers
# ---------------------------------------------------------------------------

#: Matches one double-quoted Lua string fragment (with escaped chars).
_LUA_QUOTED_STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"', re.DOTALL)

#: Lua escape sequences to decode in string values.
_LUA_ESCAPES: list[tuple[str, str]] = [
    ("\\n", "\n"),
    ("\\t", "\t"),
    ('\\"', '"'),
    ("\\\\", "\\"),
]


def _find_matching_paren(text: str, start: int) -> int:
    """Return the index of the ``')'`` that closes the ``'('`` just before *start*.

    Skips quoted string content so parentheses inside strings are not counted.
    *start* is the index immediately after the opening ``'('``.
    Returns ``len(text)`` when no matching ``')'`` is found.

    Args:
        text: Source text to scan.
        start: Index of the first character inside the open parenthesis.

    Returns:
        Index of the matching closing parenthesis, or ``len(text)`` if not found.
    """
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        c = text[i]
        if c in ('"', "'"):
            quote = c
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    break
                i += 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(text)


def _lua_extract_string(text: str, call_name: str) -> str | None:
    """Extract and decode a Lua method argument that may be a ``[[...]]`` long string or ``"..."``-concat.

    Handles Lua ``..`` string concatenation — e.g.:
    ``:setBriefing("line1\\n" .. "line2\\n")`` → ``"line1\\nline2\\n"`` with ``\\n`` → real newlines.

    Only the argument of the matched call is inspected; chained setters after the closing
    ``')'`` are not included.

    Args:
        text: The source text containing the method call.
        call_name: The method name to search for, e.g. ``"setBriefing"``.

    Returns:
        The decoded string value, or ``None`` if the call is not found.
    """
    m = re.search(rf":{re.escape(call_name)}\s*\(", text)
    if not m:
        return None
    arg_start = m.end()
    arg_end = _find_matching_paren(text, arg_start)
    arg_text = text[arg_start:arg_end]
    # Long string [[...]] — no escape decoding needed
    ls = re.match(r"\s*\[\[(.*?)\]\]", arg_text, re.DOTALL)
    if ls:
        return ls.group(1).strip()
    # Collect all "..." fragments within the argument (handles .. concatenation)
    fragments = _LUA_QUOTED_STR_RE.findall(arg_text)
    if not fragments:
        return None
    joined = "".join(fragments)
    for esc, char in _LUA_ESCAPES:
        joined = joined.replace(esc, char)
    return joined


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
        # Use var_name (e.g. "veafQraManager") when available; fall back to the
        # filename stem (e.g. "veafQraCore") for old bundled JSON without var_name.
        self._var_to_id: dict[str, str] = {}
        for mod in get_modules():
            var = mod.get("var_name") or mod["filename"].removesuffix(".lua")  # type: ignore[call-overload]
            self._var_to_id[var] = mod["id"]

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
        # elseif contains 'if' but \bif\b already doesn't match inside it due to
        # word boundaries.  Subtract any elseif matches that slipped through, but
        # never go below zero (a lone elseif line has no net depth change).
        opens = max(0, opens - len(ConfigMigrator._ELSEIF_RE.findall(no_comment)))
        closes = len(ConfigMigrator._CLOSE_KW_RE.findall(no_comment))
        return opens - closes

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def migrate(self, content: str) -> MigrationResult:
        """Transform *content* and return a :class:`MigrationResult`."""
        # Phase 0 — Pre-extract YAML-transferable data (YAML-009 – YAML-012)
        # Creates a partial result to collect extracted fields, then run the
        # existing line-by-line pass on the pre-processed content.
        partial = MigrationResult(new_content="")
        content = self.pre_extract(content, partial)

        lines = content.splitlines()

        output: list[str] = []
        enabled_modules: list[str] = []
        removed_dofiles: list[str] = []
        wrapped_calls: list[str] = []
        warnings: list[str] = []

        depth = 0  # overall Lua nesting depth (0 = file top-level)
        block_comment_depth = 0  # depth of ``--[[ … ]]`` nesting
        current_guard_var: str | None = None  # variable of the active if-guard block

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

            # ── Detect ``if veafXxx then`` → record module ─────────────────
            # Note: depth == 0 is intentionally NOT checked here because
            # _net_depth() may drift when Lua keywords appear inside string
            # literals (e.g. "failed if any..."). Top-level guards are always
            # unindented, so _IF_VEAF_RE.match (anchored at ^) is sufficient.
            if_guard_m = self._IF_VEAF_RE.match(raw_line)
            if if_guard_m:
                mod_var = if_guard_m.group(1)
                mod_id = self._var_to_id.get(mod_var, mod_var)
                if mod_id not in enabled_modules:
                    enabled_modules.append(mod_id)
                # Track guard start (only at top level, depth==0)
                if depth == 0:
                    current_guard_var = mod_var

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

            # ── Inside a guard: comment out initialize() to avoid double-init ──
            elif current_guard_var is not None:
                init_in_guard_m = self._BARE_INIT_RE.match(raw_line)
                if init_in_guard_m:
                    output.append(
                        f"-- [v6 migration] {raw_line.rstrip()}"
                        "  -- removed: veaf.initialize() in veaf-config.lua calls all module init functions"
                    )
                    warnings.append(t("convert_v5.warning.init_commented", line=lineno, var=init_in_guard_m.group(2)))
                    depth += self._net_depth(raw_line)
                    continue

            # ── Default: keep the line unchanged ───────────────────────────
            output.append(raw_line)
            depth += self._net_depth(raw_line)

            # Clear guard tracking when we exit back to top level
            if current_guard_var is not None and depth == 0:
                current_guard_var = None

        # ── Build YAML snippet ──────────────────────────────────────────────
        yaml_snippet = self._build_yaml_snippet(enabled_modules)

        return MigrationResult(
            new_content="\n".join(output),
            enabled_modules=enabled_modules,
            removed_dofiles=removed_dofiles,
            wrapped_calls=wrapped_calls,
            yaml_snippet=yaml_snippet,
            warnings=warnings,
            # Pre-extracted fields (YAML-009 – YAML-017)
            mission_name=partial.mission_name,
            mission_era=partial.mission_era,
            mission_export_path=partial.mission_export_path,
            security_disabled=partial.security_disabled,
            global_log_level_extracted=partial.global_log_level_extracted,
            skynet_config=partial.skynet_config,
            silence_atc=partial.silence_atc,
            ctld_config=partial.ctld_config,
            csar_config=partial.csar_config,
            assets_extracted=partial.assets_extracted,
            qra_silence_all=partial.qra_silence_all,
            qra_definitions=partial.qra_definitions,
            cap_missions_extracted=partial.cap_missions_extracted,
            combat_missions_extracted=partial.combat_missions_extracted,
            shortcuts_extracted=partial.shortcuts_extracted,
            sanctuary_zones_extracted=partial.sanctuary_zones_extracted,
            combat_zone_settings_extracted=partial.combat_zone_settings_extracted,
            combat_zones_extracted=partial.combat_zones_extracted,
            airwave_zones_extracted=partial.airwave_zones_extracted,
            password_mm_hashes=partial.password_mm_hashes,
            callback_hints=partial.callback_hints,
        )

    def _build_yaml_snippet(self, enabled_modules: list[str]) -> str:
        """Generate a ``modules:`` YAML block for ``mission.yaml``."""
        lines: list[str] = ["modules:"]
        enabled_set = set(enabled_modules)

        for mod in get_modules():
            mid = mod["id"]
            # Quote the key if it contains non-identifier characters (spaces, dashes, …).
            yaml_key = f'"{mid}"' if not re.match(r"^[A-Za-z_]\w*$", mid) else mid
            if mid in enabled_set:
                lines.extend(yaml_module_entry(yaml_key, mid))
            else:
                lines.append(f"  # {yaml_key}:")
                lines.append("  #   enabled: false  # not found in missionConfig.lua")

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Pre-extraction helpers (YAML-009 – YAML-012)
    # ------------------------------------------------------------------

    def _comment_out_span(self, content: str, start: int, end: int, label: str) -> str:
        """Replace content[start:end] with commented-out lines tagged with *label*."""
        chunk = content[start:end]
        commented = "\n".join(
            f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
        ) + ("\n" if chunk.endswith("\n") else "")
        return content[:start] + commented + content[end:]

    def _extract_inline_value(self, pattern: re.Pattern[str], content: str) -> tuple[str, str | None]:
        """Find the first match of *pattern*, comment out that line, return (new_content, captured_group_1)."""
        m = pattern.search(content)
        if not m:
            return content, None
        value = m.group(1)
        line_start = content.rfind("\n", 0, m.start()) + 1
        line_end = content.find("\n", m.end())
        line_end = len(content) if line_end == -1 else line_end
        original_line = content[line_start:line_end]
        commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
        return content[:line_start] + commented + content[line_end:], value

    def _find_matching_close(self, content: str, open_pos: int, open_ch: str, close_ch: str) -> int:
        """Return the position immediately after the closing char that matches *open_pos*."""
        depth = 1
        i = open_pos + 1
        while i < len(content) and depth > 0:
            if content[i] == open_ch:
                depth += 1
            elif content[i] == close_ch:
                depth -= 1
            i += 1
        return i  # i points one past the closing character

    def pre_extract(self, content: str, result: MigrationResult) -> str:
        """Modify *content* in-place to extract YAML-transferable data.

        Patterns found are commented out (tagged ``-- [v6 extracted to mission.yaml]``)
        and the extracted data is stored on *result*.

        Returns the modified content ready for the line-by-line migration pass.
        """
        content = self._extract_identity_and_security(content, result)
        content = self._extract_skynet(content, result)
        content = self._extract_ctld_csar(content, result)
        content = self._extract_assets(content, result)
        content = self._extract_qra_chains(content, result)
        content = self._extract_cap_missions(content, result)
        content = self._extract_combat_missions(content, result)
        content = self._extract_shortcuts(content, result)
        content = self._extract_named_points(content, result)
        content = self._extract_sanctuary_zones(content, result)
        content = self._extract_combat_zone_settings(content, result)
        content = self._extract_combat_zones(content, result)
        content = self._extract_airwaves_zones(content, result)
        content = self._extract_security_mm(content, result)
        return content

    # ── identity / security / global_log_level ──────────────────────────────

    _MISSION_NAME_RE = re.compile(r'veaf\.config\.MISSION_NAME\s*=\s*"([^"]+)"')
    _ERA_RE = re.compile(r"veaf\.config\.era\s*=\s*veaf\.ERA\.(\w+)")
    _EXPORT_PATH_RE = re.compile(r'veaf\.config\.MISSION_EXPORT_PATH\s*=\s*(?:"([^"]*)"|(nil))')
    _SECURITY_RE = re.compile(r"(?:veaf|veafSecurity)\.SecurityDisabled\s*=\s*(true|false)")
    _FORCED_LOG_RE = re.compile(r'veaf\.ForcedLogLevel\s*=\s*"([^"]+)"')
    _SILENCE_ATC_RE = re.compile(r"^[ \t]*veaf\.silenceAtcOnAllAirbases\s*\(\s*\)", re.MULTILINE)

    def _extract_identity_and_security(self, content: str, result: MigrationResult) -> str:
        content, result.mission_name = self._extract_inline_value(self._MISSION_NAME_RE, content)
        content, result.mission_era = self._extract_inline_value(self._ERA_RE, content)

        m_ep = self._EXPORT_PATH_RE.search(content)
        if m_ep:
            result.mission_export_path = m_ep.group(1) if m_ep.group(1) is not None else None  # nil → None
            line_start = content.rfind("\n", 0, m_ep.start()) + 1
            line_end = content.find("\n", m_ep.end())
            line_end = len(content) if line_end == -1 else line_end
            original_line = content[line_start:line_end]
            commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
            content = content[:line_start] + commented + content[line_end:]

        content, sec = self._extract_inline_value(self._SECURITY_RE, content)
        if sec is not None:
            result.security_disabled = sec == "true"

        content, ll = self._extract_inline_value(self._FORCED_LOG_RE, content)
        if ll is not None:
            result.global_log_level_extracted = ll

        # CONVERT-FIDELITY-003: an active (non-commented) silenceAtcOnAllAirbases()
        # call → mission.silence_atc_on_all_airbases: true.
        m_atc = self._SILENCE_ATC_RE.search(content)
        if m_atc:
            result.silence_atc = True
            line_start = content.rfind("\n", 0, m_atc.start()) + 1
            line_end = content.find("\n", m_atc.end())
            line_end = len(content) if line_end == -1 else line_end
            commented = f"-- [v6 extracted to mission.yaml] {content[line_start:line_end].strip()}"
            content = content[:line_start] + commented + content[line_end:]

        return content

    # ── Skynet ──────────────────────────────────────────────────────────────

    _SKYNET_INIT_RE = re.compile(
        r"veafSkynet\.initialize\s*\(\s*(true|false)\s*,\s*(true|false)\s*,\s*(true|false)\s*,\s*(true|false)\s*\)"
    )

    def _extract_skynet(self, content: str, result: MigrationResult) -> str:
        m = self._SKYNET_INIT_RE.search(content)
        if not m:
            return content
        result.skynet_config = {
            "enabled": True,
            "include_red_in_radio": m.group(1) == "true",
            "debug_red": m.group(2) == "true",
            "include_blue_in_radio": m.group(3) == "true",
            "debug_blue": m.group(4) == "true",
        }
        line_start = content.rfind("\n", 0, m.start()) + 1
        line_end = content.find("\n", m.end())
        line_end = len(content) if line_end == -1 else line_end
        original_line = content[line_start:line_end]
        commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
        return content[:line_start] + commented + content[line_end:]

    # ── CTLD / CSAR settings (MODULES-UNIFY-004) ──────────────────────────────

    _CTLD_CSAR_ASSIGN_RE = re.compile(
        r"^(\s*)(ctld|csar)\.(\w+)\s*=\s*"
        r"(\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'|-?[\d.]+|true|false)\s*(?:--.*)?$"
    )

    @staticmethod
    def _coerce_lua_scalar(raw: str) -> bool | int | float | str:
        """Coerce a Lua scalar literal to its Python value.

        Args:
            raw: The literal text (``true``/``false``, a number, or a quoted string).

        Returns:
            The corresponding ``bool`` / ``int`` / ``float`` / ``str`` value.
        """
        raw = raw.strip()
        if raw == "true":
            return True
        if raw == "false":
            return False
        if len(raw) >= 2 and raw[0] in "\"'" and raw[-1] == raw[0]:
            return raw[1:-1]
        try:
            return float(raw) if "." in raw else int(raw)
        except ValueError:
            return raw

    def _extract_ctld_csar(self, content: str, result: MigrationResult) -> str:
        """Extract ``ctld.xxx`` / ``csar.xxx`` setting assignments.

        Each scalar assignment is recorded in ``result.ctld_config`` /
        ``result.csar_config`` (for emission under ``modules.CTLD`` /
        ``modules.CSAR``) and commented out in place so it is not applied twice.
        ``initialize()`` and function/table assignments are left untouched.

        Args:
            content: The missionConfig.lua content.
            result: The migration result to populate.

        Returns:
            The content with extracted assignment lines commented out.
        """
        out_lines: list[str] = []
        for line in content.splitlines(keepends=True):
            stripped_nl = line.rstrip("\r\n")
            newline = line[len(stripped_nl) :]
            match = self._CTLD_CSAR_ASSIGN_RE.match(stripped_nl)
            if match:
                indent, table, key, raw = match.group(1), match.group(2), match.group(3), match.group(4)
                target = result.ctld_config if table == "ctld" else result.csar_config
                target[key] = self._coerce_lua_scalar(raw)
                out_lines.append(f"{indent}-- [v6 extracted to mission.yaml] {stripped_nl.strip()}{newline}")
            else:
                out_lines.append(line)
        return "".join(out_lines)

    # ── Assets table ────────────────────────────────────────────────────────

    _ASSETS_TABLE_START_RE = re.compile(r"veafAssets\.Assets\s*=\s*\{")
    _ASSET_ROW_KV_RE = re.compile(r'(\w+)\s*=\s*(?:"([^"]*)"|([\d.]+)|(true|false))')

    def _parse_asset_row(self, row_text: str) -> dict:
        """Parse one ``{key=value, ...}`` asset row into a dict."""
        asset: dict = {}
        for m in self._ASSET_ROW_KV_RE.finditer(row_text):
            key = m.group(1)
            if m.group(2) is not None:
                asset[key] = m.group(2)
            elif m.group(3) is not None:
                v = m.group(3)
                asset[key] = int(v) if "." not in v else float(v)
            elif m.group(4) is not None:
                asset[key] = m.group(4) == "true"
        return asset

    def _extract_assets(self, content: str, result: MigrationResult) -> str:
        m = self._ASSETS_TABLE_START_RE.search(content)
        if not m:
            return content
        # Find the opening brace (last char of the match)
        open_pos = m.end() - 1
        close_pos = self._find_matching_close(content, open_pos, "{", "}")
        table_text = content[open_pos + 1 : close_pos - 1]  # between outer braces

        # Parse each inner row
        assets: list[dict] = []
        # Find all {…} rows inside the table
        i = 0
        while i < len(table_text):
            row_start = table_text.find("{", i)
            if row_start == -1:
                break
            row_end = self._find_matching_close(table_text, row_start, "{", "}")
            row_text = table_text[row_start + 1 : row_end - 1]
            asset = self._parse_asset_row(row_text)
            if asset:
                assets.append(asset)
            i = row_end

        if assets:
            result.assets_extracted = assets
            span_start = m.start()
            content = self._comment_out_span(content, span_start, close_pos, "veafAssets.Assets")

        return content

    # ── QRA chains ──────────────────────────────────────────────────────────

    _QRA_START_RE = re.compile(r"(?:local\s+)?(\w+)\s*=\s*VeafQRA:new\(\)")
    _QRA_SILENCE_ALL_RE = re.compile(r"VeafQRA\.ToggleAllSilence\((true|false)\)")

    def _extract_qra_chains(self, content: str, result: MigrationResult) -> str:
        # Extract ToggleAllSilence
        m_silence = self._QRA_SILENCE_ALL_RE.search(content)
        if m_silence:
            result.qra_silence_all = m_silence.group(1) == "true"
            line_start = content.rfind("\n", 0, m_silence.start()) + 1
            line_end = content.find("\n", m_silence.end())
            line_end = len(content) if line_end == -1 else line_end
            original_line = content[line_start:line_end]
            commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
            content = content[:line_start] + commented + content[line_end:]

        # Find all QRA chains: from `xxx = VeafQRA:new()` to `:start()`
        _START_RE = re.compile(r"(?:local\s+)?(\w+)\s*=\s*VeafQRA:new\(\)")
        replacements: list[tuple[int, int, dict]] = []

        for m in list(_START_RE.finditer(content)):
            chain_start = m.start()
            # Find the next :start() after this point — also match commented-out --:start()
            start_end_m = re.search(r"(--\s*)?:start\s*\(\s*\)", content[m.end() :])
            if not start_end_m:
                continue
            abs_start_end = m.end() + start_end_m.end()
            # Find end of that line
            line_end = content.find("\n", abs_start_end)
            chain_end = line_end + 1 if line_end != -1 else len(content)
            chain_text = content[chain_start:chain_end]

            qra_def = self._parse_qra_chain(chain_text, m.group(1))
            if qra_def:
                # Record whether :start() was active or commented out
                qra_def["start"] = start_end_m.group(1) is None  # True if not commented
                replacements.append((chain_start, chain_end, qra_def))

        # Apply replacements in reverse order to preserve positions
        for start, end, qra_def in reversed(replacements):
            result.qra_definitions.insert(0, qra_def)
            chunk = content[start:end]
            commented = "\n".join(
                f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
            ) + ("\n" if chunk.endswith("\n") else "")
            content = content[:start] + commented + content[end:]

        return content

    def _parse_qra_chain(self, chain_text: str, default_var: str) -> dict | None:
        """Parse a VeafQRA builder chain text into a dict."""
        qra: dict = {}

        # Name
        m = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        qra["name"] = m.group(1) if m else default_var

        # Coalition
        m = re.search(r":setCoalition\s*\(\s*coalition\.side\.(\w+)\s*\)", chain_text)
        if m:
            qra["coalition"] = m.group(1)

        # Enemy coalitions
        enemies = re.findall(r":addEnnemyCoalition\s*\(\s*coalition\.side\.(\w+)\s*\)", chain_text)
        if enemies:
            qra["enemy_coalitions"] = enemies

        # Trigger zone
        m = re.search(r':setTriggerZone\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            qra["trigger_zone"] = m.group(1)

        # Zone radius
        m = re.search(r":setZoneRadius\s*\(\s*(\d+)", chain_text)
        if m:
            qra["zone_radius"] = int(m.group(1))

        # Simple groups
        simple_groups = re.findall(r':addGroup\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if simple_groups:
            qra["simple_groups"] = simple_groups

        # Groups by enemy count
        gbc_list = []
        for gbc_m in re.finditer(
            r":setRandomGroupsToDeployByEnemyQuantity\s*\(\s*(\d+)\s*,\s*\{([^}]+)\}\s*,\s*(\d+)\s*\)", chain_text
        ):
            count = int(gbc_m.group(1))
            groups_str = gbc_m.group(2)
            pick = int(gbc_m.group(3))
            groups = re.findall(r'"([^"]+)"', groups_str)
            gbc_list.append({"enemy_count": count, "groups": groups, "random_pick": pick})
        if gbc_list:
            qra["groups_by_enemy_count"] = gbc_list

        # Delays
        m = re.search(r":setDelayBeforeRearming\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            qra["delay_before_rearming"] = int(m.group(1))

        m = re.search(r":setDelayBeforeActivating\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            qra["delay_before_activating"] = int(m.group(1))

        if re.search(r":setReactOnHelicopters\s*\(\s*\)", chain_text):
            qra["react_on_helicopters"] = True

        m = re.search(r':setAirportLink\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            qra["airport_link"] = m.group(1)

        return qra if len(qra) > 1 else None

    # ── CAP missions ────────────────────────────────────────────────────────

    _CAP_MISSION_RE = re.compile(
        r'veafCombatMission\.addCapMission\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*(true|false)\s*,\s*(true|false)\s*\)'
    )

    def _extract_cap_missions(self, content: str, result: MigrationResult) -> str:
        replacements: list[tuple[int, int, dict]] = []
        for m in list(self._CAP_MISSION_RE.finditer(content)):
            cap = {
                "group_name": m.group(1),
                "menu_name": m.group(2),
                "briefing": m.group(3),
                "default": m.group(4) == "true",
                "activated": m.group(5) == "true",
            }
            line_start = content.rfind("\n", 0, m.start()) + 1
            line_end = content.find("\n", m.end())
            line_end = len(content) if line_end == -1 else line_end
            replacements.append((line_start, line_end, cap))

        for start, end, cap in reversed(replacements):
            result.cap_missions_extracted.insert(0, cap)
            original_line = content[start:end]
            commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
            content = content[:start] + commented + content[end:]

        return content

    # ── Combat missions ─────────────────────────────────────────────────────

    _ADD_MISSIONS_RE = re.compile(r"veafCombatMission\.AddMissionsWithSkillAndScale\s*\(")

    def _extract_combat_missions(self, content: str, result: MigrationResult) -> str:
        replacements: list[tuple[int, int, dict]] = []

        for m in list(self._ADD_MISSIONS_RE.finditer(content)):
            call_start = m.start()
            open_pos = m.end() - 1  # position of `(`
            close_pos = self._find_matching_close(content, open_pos, "(", ")")
            call_text = content[call_start:close_pos]
            cm = self._parse_combat_mission(call_text)
            if cm:
                replacements.append((call_start, close_pos, cm))

        for start, end, cm in reversed(replacements):
            result.combat_missions_extracted.insert(0, cm)
            chunk = content[start:end]
            commented = "\n".join(
                f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
            ) + ("\n" if chunk.endswith("\n") else "")
            content = content[:start] + commented + content[end:]

        return content

    def _parse_combat_mission(self, text: str) -> dict | None:
        """Parse a VeafCombatMission builder chain into a dict."""
        cm: dict = {}

        m = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', text)
        if m:
            cm["name"] = m.group(1)

        m = re.search(r':setFriendlyName\s*\(\s*"([^"]+)"\s*\)', text)
        if m:
            cm["friendly_name"] = m.group(1)

        m = re.search(r":setSecured\s*\(\s*(true|false)\s*\)", text)
        if m:
            cm["secured"] = m.group(1) == "true"

        m = re.search(r":setRadioMenuEnabled\s*\(\s*(true|false)\s*\)", text)
        if m:
            cm["radio_menu_enabled"] = m.group(1) == "true"

        # Briefing: handles [[...]], "..." and "..." .. "..." concatenation
        briefing = _lua_extract_string(text, "setBriefing")
        if briefing is not None:
            cm["briefing"] = briefing.strip()

        # Elements
        elements = []
        for elem_m in re.finditer(r"VeafCombatMissionElement:new\(\)", text):
            elem_start = elem_m.start()
            # Find the close paren of addElement() that contains this element
            add_elem_re = re.compile(r":addElement\s*\(")
            ae_m = add_elem_re.search(text, max(0, elem_start - 100))
            if ae_m:
                ae_open = ae_m.end() - 1
                ae_close = self._find_matching_close(text, ae_open, "(", ")")
                elem_text = text[ae_m.start() : ae_close]
            else:
                elem_text = text[elem_start : elem_start + 500]

            elem: dict = {}
            mn = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', elem_text)
            if mn:
                elem["name"] = mn.group(1)
            groups_m = re.search(r":setGroups\s*\(\s*\{([^}]*)\}", elem_text)
            groups = re.findall(r'"([^"]+)"', groups_m.group(0) if groups_m else "")
            if groups:
                elem["groups"] = groups
            ms = re.search(r":setScalable\s*\(\s*(true|false)\s*\)", elem_text)
            if ms:
                elem["scalable"] = ms.group(1) == "true"
            if elem:
                elements.append(elem)

        if elements:
            cm["elements"] = elements

        return cm if "name" in cm or "elements" in cm else None

    # ── Shortcuts (VeafAlias) ────────────────────────────────────────────────

    _ALIAS_START_RE = re.compile(r"VeafAlias:new\(\)")

    def _extract_shortcuts(self, content: str, result: MigrationResult) -> str:
        """Extract VeafAlias builder chains from the if veafShortcuts block."""
        replacements: list[tuple[int, int, dict]] = []

        for m in list(self._ALIAS_START_RE.finditer(content)):
            chain_start = m.start()
            # Find veafShortcuts.AddAlias( that wraps this
            # The alias chain ends at the last ')' of AddAlias(...)
            # We need to find the enclosing AddAlias(  ...  )
            add_alias_re = re.compile(r"veafShortcuts\.AddAlias\s*\(")
            # Search backwards for the AddAlias call
            preceding = content[max(0, chain_start - 200) : chain_start]
            add_m = None
            for am in add_alias_re.finditer(preceding):
                add_m = am
            if add_m is None:
                continue
            abs_add_start = max(0, chain_start - 200) + add_m.start()
            open_pos = max(0, chain_start - 200) + add_m.end() - 1
            close_pos = self._find_matching_close(content, open_pos, "(", ")")

            chain_text = content[chain_start:close_pos]
            alias = self._parse_alias_chain(chain_text)
            if alias:
                # Find line start of AddAlias
                line_start = content.rfind("\n", 0, abs_add_start) + 1
                line_end = content.find("\n", close_pos)
                line_end = len(content) if line_end == -1 else line_end + 1
                replacements.append((line_start, line_end, alias))

        # Apply in reverse order
        for start, end, alias in reversed(replacements):
            result.shortcuts_extracted.insert(0, alias)
            chunk = content[start:end]
            commented = "\n".join(
                f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
            ) + ("\n" if chunk.endswith("\n") else "")
            content = content[:start] + commented + content[end:]

        return content

    def _parse_alias_chain(self, chain_text: str) -> dict | None:
        """Parse a VeafAlias builder chain into a dict."""
        alias: dict = {}

        m = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            alias["name"] = m.group(1)

        m = re.search(r':setDescription\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            alias["description"] = m.group(1)

        m = re.search(r':setVeafCommand\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            alias["command"] = m.group(1)

        m = re.search(r":setBypassSecurity\s*\(\s*(true|false)\s*\)", chain_text)
        if m:
            alias["bypass_security"] = m.group(1) == "true"

        return alias if "name" in alias else None

    # ── NamedPoints (obsolete v5 block) ─────────────────────────────────────

    _NAMEDPOINTS_BLOCK_RE = re.compile(r"^\s*if\s+veafNamedPoints\s+then\b", re.MULTILINE)

    def _extract_named_points(self, content: str, result: MigrationResult) -> str:
        """Comment out the entire if veafNamedPoints then block (v5 API is obsolete in v6)."""
        m = self._NAMEDPOINTS_BLOCK_RE.search(content)
        if not m:
            return content

        block_start = content.rfind("\n", 0, m.start()) + 1
        # Find the matching end
        depth = 0
        i = m.start()
        while i < len(content):
            # Scan for open/close keywords
            line_end = content.find("\n", i)
            line_end = len(content) if line_end == -1 else line_end
            line = content[i:line_end]
            depth += self._net_depth(line)
            i = line_end + 1
            if depth == 0:
                block_end = i
                break
        else:
            block_end = len(content)

        chunk = content[block_start:block_end]
        migration_note = "-- [v6 migration] veafNamedPoints block commented out: the v5 API (veafNamedPoints.Points = {...}) is obsolete in v6.\n-- In v6, named points are loaded automatically from built-in theatre tables. Add custom points to mission.yaml under NAMEDPOINTS: custom_points:\n"
        commented = (
            migration_note
            + "\n".join(f"-- [v6 migration] {line}" if line.strip() else line for line in chunk.splitlines())
            + ("\n" if chunk.endswith("\n") else "")
        )
        result.warnings.append(t("convert_v5.warn.named_points_commented"))

        return content[:block_start] + commented + content[block_end:]

    # ── Sanctuary zones ──────────────────────────────────────────────────────

    _SANCTUARY_ZONE_START_RE = re.compile(r"VeafSanctuaryZone:new\(\)")

    def _extract_sanctuary_zones(self, content: str, result: MigrationResult) -> str:
        """Extract VeafSanctuaryZone builder chains."""
        replacements: list[tuple[int, int, dict]] = []

        for m in list(self._SANCTUARY_ZONE_START_RE.finditer(content)):
            # Find veafSanctuary.addZone( that wraps this
            add_zone_re = re.compile(r"veafSanctuary\.addZone\s*\(")
            preceding = content[max(0, m.start() - 200) : m.start()]
            add_m = None
            for am in add_zone_re.finditer(preceding):
                add_m = am
            if add_m is None:
                continue
            abs_add_start = max(0, m.start() - 200) + add_m.start()
            open_pos = max(0, m.start() - 200) + add_m.end() - 1
            # The addZone( call may close before chaining: addZone(Zone:new():...))
            # followed by :setCoalition()... on the return value.
            # We find the matching ')' of addZone(
            close_of_addzone = self._find_matching_close(content, open_pos, "(", ")")
            # Then scan for further chained calls on the same logical line(s)
            # until we hit a non-chain line (no leading ':')
            chain_end = close_of_addzone
            # Look ahead for chained method calls (lines starting with ':')
            rest = content[close_of_addzone:]
            for chain_m in re.finditer(r"^[ \t]*:(set\w+|get\w+)\s*\([^)]*\)", rest, re.MULTILINE):
                if chain_m.start() == 0 or rest[: chain_m.start()].strip() == "":
                    chain_end = close_of_addzone + chain_m.end()
                else:
                    break

            # Find end of last line
            line_end = content.find("\n", chain_end)
            chain_end = line_end + 1 if line_end != -1 else len(content)

            chain_text = content[abs_add_start:chain_end]
            zone = self._parse_sanctuary_zone(chain_text)
            if zone:
                line_start = content.rfind("\n", 0, abs_add_start) + 1
                replacements.append((line_start, chain_end, zone))

        for start, end, zone in reversed(replacements):
            result.sanctuary_zones_extracted.insert(0, zone)
            chunk = content[start:end]
            commented = "\n".join(
                f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
            ) + ("\n" if chunk.endswith("\n") else "")
            content = content[:start] + commented + content[end:]

        return content

    def _parse_sanctuary_zone(self, chain_text: str) -> dict | None:
        """Parse a VeafSanctuaryZone builder chain into a dict."""
        zone: dict = {}

        m = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["name"] = m.group(1)

        # setPolygonFromUnits({...})
        m = re.search(r":setPolygonFromUnits\s*\(\s*\{([^}]+)\}", chain_text)
        if m:
            units = re.findall(r'"([^"]+)"', m.group(1))
            if units:
                zone["polygon_units"] = units

        m = re.search(r":setCoalition\s*\(\s*coalition\.side\.(\w+)\s*\)", chain_text)
        if m:
            zone["coalition"] = m.group(1)

        m = re.search(r":setDelayWarning\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["delay_warning"] = int(m.group(1))

        m = re.search(r":setDelaySpawn\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["delay_spawn"] = int(m.group(1))

        m = re.search(r":setDelayInstant\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["delay_instant"] = int(m.group(1))

        m = re.search(r":setProtectFromMissiles\s*\(\s*(true|false)\s*\)", chain_text)
        if m:
            zone["protect_from_missiles"] = m.group(1) == "true"

        return zone if "name" in zone else None

    # ── CombatZone settings ──────────────────────────────────────────────────

    _CZ_BLOCK_RE = re.compile(r"^\s*if\s+veafCombatZone\s+then\b", re.MULTILINE)
    _CZ_EVENT_MSG_RE = re.compile(r"veafCombatZone\.EventMessages\.(\w+)\s*=\s*(?:nil|\"([^\"]*)\"|'([^']*)')")
    _CZ_SCALAR_RE = re.compile(r"veafCombatZone\.(\w+)\s*=\s*(?:(\d+(?:\.\d+)?)|\"([^\"]*)\"|'([^']*)')")

    def _extract_combat_zone_settings(self, content: str, result: MigrationResult) -> str:
        """Extract global veafCombatZone.Xxx = ... assignments."""
        settings: dict = {}
        replacements: list[tuple[int, int]] = []

        for m in list(self._CZ_EVENT_MSG_RE.finditer(content)):
            key = m.group(1)
            value = m.group(2) or m.group(3)  # None if nil
            settings[f"event_message_{key.lower()}"] = value
            line_start = content.rfind("\n", 0, m.start()) + 1
            line_end = content.find("\n", m.end())
            line_end = len(content) if line_end == -1 else line_end
            replacements.append((line_start, line_end))

        # Known scalar settings
        _CZ_KNOWN_SCALARS = {
            "SecondsBetweenWatchdogChecks": "watchdog_check_interval",
            "RadioMenuName": "radio_menu_name",
            "CombatZoneRadioMenuName": "combat_zone_menu_name",
            "OperationRadioMenuName": "operation_menu_name",
        }
        for m in list(self._CZ_SCALAR_RE.finditer(content)):
            attr = m.group(1)
            if attr not in _CZ_KNOWN_SCALARS:
                continue
            yaml_key = _CZ_KNOWN_SCALARS[attr]
            if m.group(2) is not None:
                v = m.group(2)
                settings[yaml_key] = int(v) if "." not in v else float(v)
            else:
                settings[yaml_key] = m.group(3) or m.group(4)
            line_start = content.rfind("\n", 0, m.start()) + 1
            line_end = content.find("\n", m.end())
            line_end = len(content) if line_end == -1 else line_end
            replacements.append((line_start, line_end))

        if settings:
            result.combat_zone_settings_extracted = settings
            for start, end in sorted(set(replacements), reverse=True):
                original_line = content[start:end]
                commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
                content = content[:start] + commented + content[end:]

        return content

    # ── CombatZone zone/operation definitions ────────────────────────────────

    _CZ_ZONE_START_RE = re.compile(r"(?:local\s+(\w+)\s*=\s*)?veafCombatZone\.AddZone\s*\(\s*VeafCombatZone:new\(\)")
    _CZ_OP_START_RE = re.compile(r"veafCombatZone\.AddZone\s*\(\s*VeafCombatOperation:new\(\)")

    def _extract_combat_zones(self, content: str, result: MigrationResult) -> str:
        """Extract VeafCombatZone and VeafCombatOperation definitions."""
        replacements: list[tuple[int, int, dict]] = []

        # Extract VeafCombatZone definitions
        for m in list(self._CZ_ZONE_START_RE.finditer(content)):
            call_start = m.start()
            # Find the opening paren of AddZone(
            open_idx = content.index("(", m.start())
            close_pos = self._find_matching_close(content, open_idx, "(", ")")
            # AddZone returns the zone; there may be chained calls on the return value
            # Find end of line after close_pos
            line_end = content.find("\n", close_pos)
            chain_end = line_end + 1 if line_end != -1 else len(content)

            chain_text = content[call_start:chain_end]
            zone_def = self._parse_combat_zone(chain_text)
            if zone_def:
                line_start = content.rfind("\n", 0, call_start) + 1
                replacements.append((line_start, chain_end, zone_def))

        # Extract VeafCombatOperation definitions
        for m in list(self._CZ_OP_START_RE.finditer(content)):
            call_start = m.start()
            open_idx = content.index("(", m.start())
            close_pos = self._find_matching_close(content, open_idx, "(", ")")
            line_end = content.find("\n", close_pos)
            chain_end = line_end + 1 if line_end != -1 else len(content)

            chain_text = content[call_start:chain_end]
            op_def = self._parse_combat_operation(chain_text)
            if op_def:
                line_start = content.rfind("\n", 0, call_start) + 1
                replacements.append((line_start, chain_end, op_def))

        for start, end, zone_def in reversed(replacements):
            result.combat_zones_extracted.insert(0, zone_def)
            chunk = content[start:end]
            has_callback = bool(re.search(r":setOnCompletedHook\s*\(", chunk))
            if has_callback:
                callback_name_m = re.search(r":setOnCompletedHook\s*\((\w+)\)", chunk)
                zone_name = zone_def.get("zone_name", "?")
                cb_name = callback_name_m.group(1) if callback_name_m else "callbackFn"
                result.callback_hints.append(f'veafCombatZone.GetZone("{zone_name}"):setOnCompletedHook({cb_name})')
                commented = "\n".join(
                    f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
                )
                commented += (
                    f"\n-- [v6 migration] callback not migrated: call manually after init:\n"
                    f'-- veafCombatZone.GetZone("{zone_name}"):setOnCompletedHook({cb_name})'
                )
            else:
                commented = "\n".join(
                    f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
                )
            content = content[:start] + commented + ("\n" if not commented.endswith("\n") else "") + content[end:]

        return content

    def _parse_combat_zone(self, chain_text: str) -> dict | None:
        """Parse a VeafCombatZone builder chain into a dict."""
        zone: dict = {"type": "zone"}

        m = re.search(r':setMissionEditorZoneName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["zone_name"] = m.group(1)

        m = re.search(r':setFriendlyName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["friendly_name"] = m.group(1)

        # Briefing: handles [[...]], "..." and "..." .. "..." concatenation
        briefing = _lua_extract_string(chain_text, "setBriefing")
        if briefing is not None:
            zone["briefing"] = briefing.strip()

        if re.search(r":disableUserActivation\s*\(\s*\)", chain_text):
            zone["user_activation_disabled"] = True

        if re.search(r":setTraining\s*\(\s*(true|false)\s*\)", chain_text):
            m2 = re.search(r":setTraining\s*\(\s*(true|false)\s*\)", chain_text)
            if m2:
                zone["training"] = m2.group(1) == "true"

        chained = re.findall(r':addChainedCombatZone\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if chained:
            zone["chained_zones"] = chained

        m = re.search(r":setChainedCombatZonesDelay\s*\(([^)]+)\)", chain_text)
        if m:
            zone["chained_delay"] = m.group(1).strip()

        # setOnCompletedHook → mark it
        m = re.search(r":setOnCompletedHook\s*\((\w+)\)", chain_text)
        if m:
            zone["on_completed_hook_hint"] = m.group(1)

        return zone if "zone_name" in zone else None

    def _parse_combat_operation(self, chain_text: str) -> dict | None:
        """Parse a VeafCombatOperation builder chain into a dict."""
        op: dict = {"type": "operation"}

        m = re.search(r':setMissionEditorZoneName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            op["zone_name"] = m.group(1)

        m = re.search(r':setFriendlyName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            op["friendly_name"] = m.group(1)

        # Briefing: handles [[...]], "..." and "..." .. "..." concatenation
        briefing = _lua_extract_string(chain_text, "setBriefing")
        if briefing is not None:
            op["briefing"] = briefing.strip()

        # addTaskingOrder(zoneVar, {deps}) — local var refs → extract as string names
        tasking_orders = []
        for to_m in re.finditer(r":addTaskingOrder\s*\(\s*(\w+)(?:\s*,\s*\{([^}]*)\})?\s*\)", chain_text):
            zone_var = to_m.group(1)
            deps_text = to_m.group(2)
            order: dict = {"zone_var": zone_var}
            if deps_text:
                deps = re.findall(r'"([^"]+)"', deps_text)
                # Also handle getMissionEditorZoneName() pattern
                deps_vars = re.findall(r"(\w+):getMissionEditorZoneName\(\)", deps_text)
                if deps:
                    order["dependencies"] = deps
                elif deps_vars:
                    order["dependencies_vars"] = deps_vars
            tasking_orders.append(order)
        if tasking_orders:
            op["tasking_orders"] = tasking_orders

        return op if "zone_name" in op else None

    # ── AirWaves zones ───────────────────────────────────────────────────────

    _AIRWAVE_START_RE = re.compile(r"AirWaveZone:new\(\)")

    def _extract_airwaves_zones(self, content: str, result: MigrationResult) -> str:
        """Extract AirWaveZone builder chains."""
        replacements: list[tuple[int, int, dict, list[str]]] = []

        for m in list(self._AIRWAVE_START_RE.finditer(content)):
            chain_start = m.start()
            # Find end: :start() or end of chain (next non-chained line)
            # The chain can span many lines; look for :start() or a line not starting with ':'
            start_m = re.search(r":start\s*\(\s*\)", content[chain_start:])
            if start_m:
                abs_end = chain_start + start_m.end()
                started = True
            else:
                # No :start() — find last chained method
                abs_end = chain_start + len(m.group(0))
                started = False
                # Scan forward for chained lines
                rest = content[chain_start + 1 :]
                last_chain = chain_start
                for cm in re.finditer(r":(set\w+|add\w+|get\w+|start)\s*\(", rest):
                    last_chain = chain_start + 1 + cm.end()
                # Find end of that line
                le = content.find("\n", last_chain)
                abs_end = le + 1 if le != -1 else len(content)

            line_end = content.find("\n", abs_end)
            abs_end = line_end + 1 if line_end != -1 else len(content)
            line_start = content.rfind("\n", 0, chain_start) + 1

            chain_text = content[chain_start:abs_end]
            zone_dict, callbacks = self._parse_airwave_zone(chain_text, started)
            if zone_dict:
                replacements.append((line_start, abs_end, zone_dict, callbacks))

        for start, end, zone_dict, callbacks in reversed(replacements):
            result.airwave_zones_extracted.insert(0, zone_dict)
            chunk = content[start:end]
            commented = "\n".join(
                f"-- [v6 extracted to mission.yaml] {line}" if line.strip() else line for line in chunk.splitlines()
            )
            zone_name = zone_dict.get("name", "?")
            if callbacks:
                commented += "\n-- [v6 migration] callbacks not migrated. Set them manually after init:"
                for cb in callbacks:
                    hint = f'veafAirWaves.get("{zone_name}"){cb}'
                    result.callback_hints.append(hint)
                    commented += f"\n-- {hint}"
            content = content[:start] + commented + ("\n" if not commented.endswith("\n") else "") + content[end:]

        return content

    def _parse_airwave_zone(self, chain_text: str, started: bool) -> tuple[dict, list[str]]:
        """Parse an AirWaveZone builder chain. Returns (zone_dict, [callback_hints])."""
        zone: dict = {}
        callbacks: list[str] = []

        m = re.search(r':setName\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["name"] = m.group(1)

        m = re.search(r':setDescription\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["description"] = m.group(1)

        # Player coalitions
        coalitions = re.findall(r":addPlayerCoalition\s*\(\s*coalition\.side\.(\w+)\s*\)", chain_text)
        if coalitions:
            zone["player_coalitions"] = coalitions

        # Zone center / trigger zone
        m = re.search(r':setZoneCenterFromCoordinates\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["zone_center_coordinates"] = m.group(1)

        m = re.search(r':setTriggerZone\s*\(\s*"([^"]+)"\s*\)', chain_text)
        if m:
            zone["trigger_zone_name"] = m.group(1)

        m = re.search(r":setZoneRadius\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["zone_radius"] = int(m.group(1))

        m = re.search(r":setDrawZone\s*\(\s*(true|false)\s*\)", chain_text)
        if m:
            zone["draw_zone"] = m.group(1) == "true"

        # Respawn
        m = re.search(r":setRespawnDefaultOffset\s*\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", chain_text)
        if m:
            zone["respawn_default_offset"] = [int(m.group(1)), int(m.group(2))]

        m = re.search(r":setRespawnRadius\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["respawn_radius"] = int(m.group(1))

        # Delays
        m = re.search(r":setDelayBeforeActivation\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["delay_before_activation"] = int(m.group(1))

        m = re.search(r":setDelayBetweenWaves\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["delay_between_waves"] = int(m.group(1))

        m = re.search(r":setMinimumSecondsBetweenWaves\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["min_seconds_between_waves"] = int(m.group(1))

        m = re.search(r":setMaximumSecondsBetweenWaves\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["max_seconds_between_waves"] = int(m.group(1))

        # Altitudes
        m = re.search(r":setMaximumAltitudeInFeet\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["max_altitude_ft"] = int(m.group(1))

        m = re.search(r":setMinimumAltitudeInFeet\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["min_altitude_ft"] = int(m.group(1))

        m = re.search(r":setMaxSecondsOutsideOfZoneIA\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["max_seconds_outside_ia"] = int(m.group(1))

        # Messages
        for msg_method in [
            "setMessageStart",
            "setMessageWaitForHumans",
            "setMessageWaveDeployed",
            "setMessageEndZone",
            "setMessageEndAll",
        ]:
            yaml_key = re.sub(r"([A-Z])", r"_\1", msg_method.replace("set", "")).lower().lstrip("_")
            m = re.search(rf':{msg_method}\s*\(\s*"([^"]+)"\s*\)', chain_text)
            if not m:
                m = re.search(rf":{msg_method}\s*\(\s*\[\[([^\]]*(?:\][^\]])*)\]\]\s*\)", chain_text)
            if m:
                zone[yaml_key] = m.group(1)

        # Waves
        waves = []
        for wave_m in re.finditer(r":addWave\s*\(([^)]+)\)", chain_text):
            wave_text = wave_m.group(1).strip()
            wave: dict = {}
            # Try to parse table { groups = "...", delay = N, number = "...", bias = N }
            gm = re.search(r'groups\s*=\s*"([^"]+)"', wave_text)
            if gm:
                wave["groups"] = gm.group(1)
            dm = re.search(r"delay\s*=\s*(-?\d+)", wave_text)
            if dm:
                wave["delay"] = int(dm.group(1))
            nm = re.search(r'number\s*=\s*"([^"]+)"', wave_text)
            if nm:
                wave["number"] = nm.group(1)
            bm = re.search(r"bias\s*=\s*(\d+)", wave_text)
            if bm:
                wave["bias"] = int(bm.group(1))
            if not wave:
                # Simple string form
                sm = re.search(r'"([^"]+)"', wave_text)
                if sm:
                    wave["groups"] = sm.group(1)
            if wave:
                waves.append(wave)
        if waves:
            zone["waves"] = waves

        # Scalar params
        m = re.search(r":setMinimumLifeForAiInPercent\s*\(\s*(\d+)\s*\)", chain_text)
        if m:
            zone["minimum_life_percent"] = int(m.group(1))

        m = re.search(r":setResetWhenDying\s*\(\s*(true|false)\s*\)", chain_text)
        if m:
            zone["reset_when_dying"] = m.group(1) == "true"

        zone["start"] = started

        # Detect callbacks (not extractable)
        for cb_method in [
            ":setOnDeploy",
            ":setHandleCrippledEnemyUnitCallback",
            ":setIsEnemyGroupDeadCallback",
            ":setOnWaveDeployed",
            ":setOnZoneEnd",
        ]:
            if cb_method in chain_text:
                # Extract the callback fragment for the hint
                cb_m = re.search(re.escape(cb_method) + r"\s*\(([^)]*)\)", chain_text)
                if cb_m:
                    callbacks.append(f"{cb_method}({cb_m.group(1)})")

        return (zone if "name" in zone else {}, callbacks)

    # ── Security MM password hashes ──────────────────────────────────────────

    _PASSWORD_MM_RE = re.compile(r'veafSecurity\.password_MM\s*\[\s*"([^"]+)"\s*\]\s*=\s*true')

    def _extract_security_mm(self, content: str, result: MigrationResult) -> str:
        """Extract veafSecurity.password_MM hash entries."""
        replacements: list[tuple[int, int, str]] = []

        for m in list(self._PASSWORD_MM_RE.finditer(content)):
            hash_val = m.group(1)
            line_start = content.rfind("\n", 0, m.start()) + 1
            line_end = content.find("\n", m.end())
            line_end = len(content) if line_end == -1 else line_end
            replacements.append((line_start, line_end, hash_val))

        for start, end, hash_val in reversed(replacements):
            result.password_mm_hashes.insert(0, hash_val)
            original_line = content[start:end]
            commented = f"-- [v6 extracted to mission.yaml] {original_line.strip()}"
            content = content[:start] + commented + content[end:]

        return content
