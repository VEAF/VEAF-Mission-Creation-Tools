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

    # ── YAML-009: identity / security / global_log_level ──────────────────────
    mission_name: str | None = None
    mission_era: str | None = None
    mission_export_path: str | None = None
    security_disabled: bool | None = None
    global_log_level_extracted: str | None = None
    skynet_config: dict | None = None

    # ── YAML-010: Assets table ─────────────────────────────────────────────────
    assets_extracted: list[dict] | None = None

    # ── YAML-011: QRA chains ───────────────────────────────────────────────────
    qra_silence_all: bool | None = None
    qra_definitions: list[dict] = field(default_factory=list)

    # ── YAML-012: CAP / combat missions ───────────────────────────────────────
    cap_missions_extracted: list[dict] = field(default_factory=list)
    combat_missions_extracted: list[dict] = field(default_factory=list)


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
            # Pre-extracted fields (YAML-009 – YAML-012)
            mission_name=partial.mission_name,
            mission_era=partial.mission_era,
            mission_export_path=partial.mission_export_path,
            security_disabled=partial.security_disabled,
            global_log_level_extracted=partial.global_log_level_extracted,
            skynet_config=partial.skynet_config,
            assets_extracted=partial.assets_extracted,
            qra_silence_all=partial.qra_silence_all,
            qra_definitions=partial.qra_definitions,
            cap_missions_extracted=partial.cap_missions_extracted,
            combat_missions_extracted=partial.combat_missions_extracted,
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
        content = self._extract_assets(content, result)
        content = self._extract_qra_chains(content, result)
        content = self._extract_cap_missions(content, result)
        content = self._extract_combat_missions(content, result)
        return content

    # ── identity / security / global_log_level ──────────────────────────────

    _MISSION_NAME_RE = re.compile(r'veaf\.config\.MISSION_NAME\s*=\s*"([^"]+)"')
    _ERA_RE = re.compile(r"veaf\.config\.era\s*=\s*veaf\.ERA\.(\w+)")
    _EXPORT_PATH_RE = re.compile(r'veaf\.config\.MISSION_EXPORT_PATH\s*=\s*(?:"([^"]*)"|(nil))')
    _SECURITY_RE = re.compile(r"veaf\.SecurityDisabled\s*=\s*(true|false)")
    _FORCED_LOG_RE = re.compile(r'veaf\.ForcedLogLevel\s*=\s*"([^"]+)"')

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
            # Find the next :start() after this point
            start_end_m = re.search(r":start\s*\(\s*\)", content[m.end() :])
            if not start_end_m:
                continue
            abs_start_end = m.end() + start_end_m.end()
            # Find end of that line
            line_end = content.find("\n", abs_start_end)
            chain_end = line_end + 1 if line_end != -1 else len(content)
            chain_text = content[chain_start:chain_end]

            qra_def = self._parse_qra_chain(chain_text, m.group(1))
            if qra_def:
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

        # Briefing: [[...]] or [==[...]==] or "..."
        m = re.search(r":setBriefing\s*\(\s*(?:\[\[([^\]]*(?:\][^\]])*)\]\]|\[=\[([^=]*)\]=\]|\"([^\"]*)\")", text)
        if m:
            briefing = m.group(1) or m.group(2) or m.group(3) or ""
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
