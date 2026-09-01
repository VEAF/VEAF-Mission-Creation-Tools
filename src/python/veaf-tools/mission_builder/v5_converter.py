"""Convert a v5-style VEAF mission folder to v6 format.

Orchestrates all migration steps in one pass:

1. **Scan** the mission folder: detect ``missionConfig.lua``, existing
   ``mission.yaml``, and pipeline config files (presets, waypoints, …).
2. **Migrate** ``missionConfig.lua`` (delegates to :class:`ConfigMigrator`):
   comment out ``doFile(...)`` calls, wrap bare ``initialize()`` calls in
   guards, and collect the list of enabled modules.
3. **Generate** ``mission.yaml``: full file with ``lua_modules:`` section
   (from step 2) and ``pipeline:`` section (from step 1).
4. **Report**: detailed :class:`ConversionReport` describing every action
   taken, every warning, and every leftover that needs manual attention.

DCS trigger conversion (v5 → v6) is handled automatically by
``veaf-tools build`` (``migrate_from_v5=True`` by default) — no action here.
"""

from __future__ import annotations

import difflib
import re
import shutil
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from fnmatch import fnmatch, fnmatchcase
from pathlib import Path
from typing import Any

import yaml  # type: ignore[import-untyped]
from mission_tools.mission_constants import (
    get_community_script_files,
    get_optin_community_script_ids,
    mission_scripts_referencing_mist,
)
from veaf_libs.i18n import current_language, t, tn
from veaf_libs.lua_config_generator import (
    MANDATORY_MODULES,
    MODULE_CATEGORIES,
    resolve_module_dependencies,
    yaml_module_entry,
    yaml_syntax_header,
)
from veaf_libs.lua_module_scanner import get_modules

from mission_builder.config_migrator import ConfigMigrator, MigrationResult
from mission_builder.presets_schema_migrator import is_v5_schema as _presets_is_v5_schema
from mission_builder.presets_schema_migrator import migrate as migrate_presets_schema
from mission_builder.v5_pipeline_converters import convert_pipeline_file


def _holds_v5_schema(step: str, path: Path) -> bool:
    """Whether a file sitting at its v6 path actually holds the v5 schema.

    Args:
        step: Pipeline step key, e.g. ``"presets"``.
        path: The file at the v6 path.

    Returns:
        ``True`` when the file must be rewritten in place. Unreadable files answer ``False`` — the
        loader reports them far better than a scan can, and guessing here would turn a parse error
        into a migration attempt.
    """
    if step != "presets":
        return False
    try:
        return _presets_is_v5_schema(yaml.safe_load(path.read_text(encoding="utf-8")))
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: Default location of missionConfig.lua relative to the mission folder (v5 name — still searched for detection).
MISSIONCONFIG_DEFAULT = Path("src") / "scripts" / "missionConfig.lua"

#: Candidate paths searched in order (relative to mission folder).
#: Only v5 source names are searched — mission-script.lua is the OUTPUT, never the input.
MISSIONCONFIG_CANDIDATES: list[Path] = [
    MISSIONCONFIG_DEFAULT,
    Path("src") / "missionConfig.lua",
    Path("missionConfig.lua"),
]

#: v6 pipeline file paths (what the v6 injectors expect to find).
V6_PIPELINE_CANDIDATES: dict[str, list[str]] = {
    "presets": ["src/presets.yaml"],
    "waypoints": ["src/waypoints.yaml"],
    # convert_aircraft_groups writes BOTH families from one v5 settings.lua; the
    # primary target (v6_candidates[0]) is spawnables.yaml and the sibling
    # dynamic-slot-templates.yaml is written alongside it.
    "aircraft_groups": ["src/spawnables.yaml", "src/dynamic-slot-templates.yaml"],
    "weather": ["src/versions.yaml"],
}

#: v5 source file paths (what a v5 mission folder typically contains).
#: These files need manual conversion to v6 format — the v6 injectors cannot read them directly.
V5_PIPELINE_CANDIDATES: dict[str, list[str]] = {
    "presets": ["src/radio/radioSettings.lua", "src/radioSettings.lua"],
    "waypoints": ["src/waypoints/waypointsSettings.lua", "src/waypointsSettings.lua"],
    "aircraft_groups": ["src/spawnableAircrafts/settings.lua"],
    "weather": ["src/weatherAndTime/versions.json", "src/weatherAndTime/versions.lua"],
}

#: Per-step guidance on how to convert a v5 file to v6 format.
#: Backward-compatible alias — exported public symbol.
PIPELINE_CANDIDATES = V6_PIPELINE_CANDIDATES

# ── Legacy v5 file cleanup (CONVERT-V5-CLEANUP-FILES) ───────────────────────────
#: v5 tooling files at the mission root made obsolete by the v6 toolchain. Moved to
#: backup_v5/ (reversible), like the converted pipeline configs.
_LEGACY_V5_TOOLING_GLOBS: tuple[str, ...] = ("*.cmd", "*.cmd.sample", "*.ps1")
_LEGACY_V5_TOOLING_NAMES: frozenset[str] = frozenset(
    {"package.json", "package-lock.json", "yarn.lock", "configuration.json", "7za.exe"}
)
#: Regenerable v5 build artifacts (npm/build/cache, all gitignored) — deleted outright,
#: never copied into backup_v5/ (pointless to archive 20 MB of node_modules).
_LEGACY_V5_REGENERABLE_DIRS: frozenset[str] = frozenset({"node_modules", "build", "cache"})
#: Tooling files known to carry secrets — flagged so a leaked key can be rotated/removed.
_LEGACY_V5_SECRET_NAMES: frozenset[str] = frozenset({"configuration.json"})
#: Root entries the cleanup scan never touches nor reports (VCS, its own backup, v6 artifacts).
_CLEANUP_ROOT_KNOWN: frozenset[str] = frozenset({".git", "backup_v5", "mission.yaml", "src", "published", "missions"})
#: The v6 toolchain binaries the mission-maker runs from the folder — never list these as
#: "unrecognized": suggesting to delete your own tools is absurd (CONVERT-V5-CLEANUP-FILES).
_CLEANUP_TOOLCHAIN_GLOBS: tuple[str, ...] = ("veaf-tools*.exe",)
#: src/ entries that belong to a v6 mission — excluded from the "unrecognized" listing.
_CLEANUP_SRC_KNOWN: frozenset[str] = frozenset(
    {
        "presets.yaml",
        "presets.v5.yaml",
        "waypoints.yaml",
        "spawnables.yaml",
        "dynamic-slot-templates.yaml",
        "warehouses.yaml",
        "versions.yaml",
        "spawn-groups.yaml",
        "scripts",
        "mission",
        "options",
    }
)

DOC_BASE = "https://veaf.github.io/documentation/dev"
DOC_LINKS: dict[str, str] = {
    "Mission Maker Guide": f"{DOC_BASE}/mission-maker/GUIDE/",
    "Migration Guide": f"{DOC_BASE}/mission-maker/MIGRATION_GUIDE/",
    "Tools Reference": f"{DOC_BASE}/",
}


def _doc_lang_segment(lang: str) -> str:
    """Return the documentation-site path segment for *lang* (``"en/"`` or ``""``).

    The site serves the default language (FR) at the root and English under ``/en/``;
    centralised here so a new locale only touches this mapping.
    """
    return "en/" if lang == "en" else ""


#: YAML special characters that require quoting a string value.
_YAML_NEEDS_QUOTE_RE = re.compile(r'[:#{}[\]\\"]')
#: YAML scalar keywords that must be quoted to stay as plain strings.
_YAML_KEYWORDS: frozenset[str] = frozenset({"true", "false", "null", "yes", "no", "on", "off", "~"})
#: Characters that, when at position 0, force quoting.
_YAML_SPECIAL_START = frozenset("-?|>&!%@`'*,")


def _yaml_str(value: str) -> str:
    """Return *value* as a YAML scalar, quoted only when necessary.

    Args:
        value: The string to serialize.

    Returns:
        Plain string or ``"quoted"`` string per YAML quoting rules.
    """
    if not value:
        return '""'
    if value.lower() in _YAML_KEYWORDS:
        return f'"{value}"'
    if value[0].isdigit() or value[0] in _YAML_SPECIAL_START:
        return f'"{value}"'
    if _YAML_NEEDS_QUOTE_RE.search(value):
        return f'"{value}"'
    if "\n" in value:
        # Double-quoted scalar with escaped newlines — safe for inline use.
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    return value


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class PipelineFile:
    """A pipeline config file detected in the mission folder."""

    step: str
    """Step key, e.g. ``"presets"``."""

    path: Path
    """Absolute path to the file."""

    relative: str
    """Path relative to the mission folder (for display)."""

    needs_conversion: bool = False
    """``True`` when the file is in v5 format and must be converted before use."""

    v6_target: str = ""
    """Expected v6 output path (only set when ``needs_conversion`` is ``True``)."""

    converted: bool = False
    """``True`` when the v5 file was successfully converted to v6 format."""

    v5_source: str = ""
    """Original v5 relative path, saved before ``relative`` is updated post-conversion."""

    needs_schema_migration: bool = False
    """``True`` when the file already sits at its v6 **path** but holds the v5 **schema**.

    Distinct from ``needs_conversion``, which means "a v5 source file has to be turned into a v6
    one". Here the file is the right file in the right place and the right format; only its inner
    layout is v5, so it is rewritten where it is (FIX-CONVERT-V5-PRESETS-SCHEMA ticket 02). This
    used to go unnoticed: the path existed, so the step was reported as already converted.
    """


@dataclass
class ConversionReport:
    """Complete record of what :class:`V5Converter` did (and didn't do)."""

    # ── Input ──────────────────────────────────────────────────────────────
    mission_folder: Path
    timestamp: str = field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M"))
    version: str = "unknown"

    # ── Scan ───────────────────────────────────────────────────────────────
    missionconfig_path: Path | None = None
    """Absolute path to the missionConfig.lua that was found (or ``None``)."""
    mission_yaml_existed: bool = False
    """``True`` if ``mission.yaml`` already existed before conversion."""
    pipeline_files: list[PipelineFile] = field(default_factory=list)
    """Pipeline config files detected under ``src/``."""
    detected_community_script_ids: set[str] = field(default_factory=set)
    #: Mission scripts found calling MiST, so the conversion can keep it enabled for them.
    mist_callers: list[str] = field(default_factory=list)
    """IDs of community scripts found in ``published/src/scripts/community/``."""

    # ── missionConfig.lua migration ────────────────────────────────────────
    migration_result: MigrationResult | None = None
    missionconfig_output: Path | None = None
    """Path to the written (migrated) missionConfig.lua."""
    missionconfig_backup: Path | None = None
    """Path to the ``.bak`` backup created before overwriting, if any."""

    # ── mission.yaml ───────────────────────────────────────────────────────
    mission_yaml_generated: bool = False
    mission_yaml_path: Path | None = None
    mission_yaml_skipped_reason: str = ""
    auto_resolved_deps: list[str] = field(default_factory=list)
    """Module IDs auto-enabled to satisfy dependencies (e.g. CASMISSION → GROUNDAI)."""

    # ── src/mission promotion to v6 (FEAT-MIGRATE-MISSION-V6) ───────────────
    promotion_attempted: bool = False
    """True when the v6 promotion was run (i.e. ``--no-promote`` was not passed)."""
    promotion_done: bool = False
    """True when ``src/mission/`` was successfully promoted to v6 on disk."""
    promotion_backup: str = ""
    """Relative path of the ``src/mission/`` backup under ``backup_v5/``."""
    promotion_reason: str = ""
    """Skip/failure reason when the promotion did not complete."""

    # ── Summary lists ──────────────────────────────────────────────────────
    actions: list[str] = field(default_factory=list)
    """High-level descriptions of actions taken (shown in the summary)."""
    warnings: list[str] = field(default_factory=list)
    """Non-fatal issues that deserve attention."""
    manual_review: list[str] = field(default_factory=list)
    """Items the user must review / clean up manually after testing."""
    backup_v5_sources: list[str] = field(default_factory=list)
    """Relative paths of v5 files/folders backed up under ``backup_v5/``."""
    legacy_tooling_backed_up: list[str] = field(default_factory=list)
    """Relative paths of obsolete v5 tooling files moved to ``backup_v5/`` (build*.cmd, package.json, …)."""
    regenerable_deleted: list[str] = field(default_factory=list)
    """Relative paths of regenerable v5 artifacts deleted outright (``node_modules/``, ``build/``, ``cache/``)."""
    secret_tooling_files: list[str] = field(default_factory=list)
    """Backed-up tooling files that may carry a secret (e.g. ``configuration.json``'s API key)."""
    unrecognized_files: list[str] = field(default_factory=list)
    """Relative paths of files the converter does not manage — listed for the maker to review/delete."""
    missionconfig_source: str = ""
    """Original (pre-migration) missionConfig.lua content — used to recover commented-out v5 elements."""

    # -----------------------------------------------------------------------
    # Report rendering
    # -----------------------------------------------------------------------

    def _summary_lines(self) -> list[str]:
        """Build the at-a-glance numeric summary header (CONVERT-FIDELITY-004).

        Reports how many modules were migrated and how many items still need
        manual action (with the source line numbers mentioned, when present), so
        the mission-maker sees whether work remains without reading the whole
        annotated config.

        Returns:
            Markdown lines for the summary section (ending with a divider).
        """
        n_modules = len(self.migration_result.enabled_modules) if self.migration_result else 0
        manual_items = list(self.manual_review) + list(self.warnings)
        line_nums = sorted(
            {int(num) for item in manual_items for num in re.findall(r"(?:line|ligne)\s+(\d+)", item, re.IGNORECASE)}
        )

        lines = [
            f"## {t('report.section.summary')}",
            "",
            f"- {tn('report.summary.modules', n_modules)}",
        ]
        if manual_items:
            entry = tn("report.summary.manual", len(manual_items))
            if line_nums:
                entry += t("report.summary.manual_lines", lines=", ".join(str(num) for num in line_nums))
            lines.append(f"- {entry}")
        else:
            lines.append(f"- {t('report.summary.no_manual')}")
        lines += ["", "---", ""]
        return lines

    def to_markdown(self) -> str:
        """Return the full conversion report as a Markdown string."""
        lines: list[str] = []

        lines += [
            f"# {t('report.title')}",
            "",
            f"*{t('report.generated_by', timestamp=self.timestamp, version=self.version)}*",
            "",
            "---",
            "",
        ]

        # ── At-a-glance numeric summary (CONVERT-FIDELITY-004) ────────────────
        lines += self._summary_lines()

        lines += [
            f"## {t('report.section.folder')}",
            "",
            f"`{self.mission_folder}`",
            "",
            "---",
            "",
        ]

        # ── Scan results ──────────────────────────────────────────────────
        lines += [
            f"## {t('report.section.scan')}",
            "",
            f"| {t('report.scan.col.item')} | {t('report.scan.col.status')} |",
            "|------|--------|",
        ]
        if self.missionconfig_path:
            rel = self.missionconfig_path.relative_to(self.mission_folder)
            lines.append(f"| `{rel}` | {t('report.scan.missionconfig.found')} |")
        else:
            lines.append(f"| `src/scripts/missionConfig.lua` | {t('report.scan.missionconfig.not_found')} |")

        if self.mission_yaml_existed:
            lines.append(f"| `mission.yaml` | {t('report.scan.mission_yaml.existed')} |")
        elif self.mission_yaml_generated:
            lines.append(f"| `mission.yaml` | {t('report.scan.mission_yaml.generated')} |")
        else:
            lines.append(f"| `mission.yaml` | {t('report.scan.mission_yaml.not_generated')} |")

        detected_steps = {pf.step for pf in self.pipeline_files}
        for step, candidates in PIPELINE_CANDIDATES.items():
            if step in detected_steps:
                pf = next(pf for pf in self.pipeline_files if pf.step == step)
                if pf.converted:
                    lines.append(f"| `{pf.v5_source}` → `{pf.relative}` | {t('report.scan.pipeline.converted')} |")
                else:
                    lines.append(f"| `{pf.relative}` | {t('report.scan.pipeline.found')} |")
            else:
                lines.append(f"| `{candidates[0]}` | {t('report.scan.pipeline.not_found', step=step)} |")

        # src/mission promotion to v6 (FEAT-MIGRATE-MISSION-V6)
        if not self.promotion_attempted:
            promo_scan = t("report.scan.promotion.skipped")
        elif self.promotion_done:
            promo_scan = t("report.scan.promotion.done")
        else:
            promo_scan = t("report.scan.promotion.failed")
        lines.append(f"| `src/mission/` | {promo_scan} |")
        lines += ["", "---", ""]

        # ── Actions taken ─────────────────────────────────────────────────
        lines += [f"## {t('report.section.actions')}", ""]

        # missionConfig.lua
        if self.migration_result is not None:
            mr = self.migration_result
            if self.missionconfig_backup:
                rel_bak = self.missionconfig_backup.relative_to(self.mission_folder)
                lines.append(f"### 1. {t('report.missionconfig.migrated', bak=rel_bak)}")
            else:
                lines.append(f"### 1. {t('report.missionconfig.migrated_no_bak')}")
            lines.append("")

            # The doFile / bare-initialize() edits describe the migrated buffer that
            # convert-v5 never writes (the original missionConfig.lua is deleted and
            # replaced by the generated mission-script.lua), so they are not reported
            # here. Only the genuinely useful outcome — the detected modules, which
            # drive mission.yaml — is kept (CONVERT-V5-INIT-COMMENTED-NOISE).
            if mr.enabled_modules:
                lines += [
                    f"#### {t('report.missionconfig.modules_counted', n=len(mr.enabled_modules))}",
                    "",
                    ", ".join(f"`{m}`" for m in mr.enabled_modules),
                    "",
                ]
        else:
            lines += [
                f"### 1. {t('report.missionconfig.skipped')}",
                "",
                f"*{t('report.missionconfig.not_found')}*",
                "",
            ]

        # mission.yaml
        if self.mission_yaml_generated and self.mission_yaml_path:
            rel_yaml = self.mission_yaml_path.relative_to(self.mission_folder)
            enabled_count = len(self.migration_result.enabled_modules) if self.migration_result else 0
            all_count = len(get_modules())
            disabled_count = all_count - enabled_count
            lines += [
                f"### 2. `mission.yaml` \u2014 {t('report.mission_yaml.generated')}",
                "",
                f"**File**: `{rel_yaml}`",
                "",
                t("report.mission_yaml.created_with"),
                f"- `global_log_level: debug` \u2014 {t('report.mission_yaml.log_level_warn')}",
                f"- `lua_modules:` \u2014 {t('report.mission_yaml.modules_count', enabled=tn('report.mission_yaml.enabled_frag', enabled_count), disabled=tn('report.mission_yaml.disabled_frag', disabled_count))}",
            ]
            if self.auto_resolved_deps:
                lines.append(f"- {t('report.mission_yaml.deps_resolved', list=', '.join(self.auto_resolved_deps))}")
            if self.pipeline_files:
                ready = [pf for pf in self.pipeline_files if not pf.needs_conversion]
                needs_conv = [pf for pf in self.pipeline_files if pf.needs_conversion]
                if ready:
                    pipeline_summary = ", ".join(f"`{pf.step}: true` ({pf.relative})" for pf in ready)
                    lines.append(f"- `pipeline:` — {pipeline_summary}")
                else:
                    lines.append(f"- `pipeline:` — {t('report.mission_yaml.pipeline_none')}")
                if needs_conv:
                    conv_summary = ", ".join(f"`{pf.step}` ({pf.relative} → `{pf.v6_target}`)" for pf in needs_conv)
                    lines.append(f"- ⚠️ {t('report.mission_yaml.pipeline_v5_warn', steps=conv_summary)}")
            else:
                lines.append(f"- `pipeline:` — {t('report.mission_yaml.pipeline_none')}")
            lines.append("")
        elif self.mission_yaml_existed:
            lines += [
                f"### 2. `mission.yaml` \u2014 {t('report.mission_yaml.skipped')}",
                "",
                f"*{self.mission_yaml_skipped_reason}*",
                "",
            ]
        else:
            lines += [
                f"### 2. `mission.yaml` \u2014 {t('report.mission_yaml.not_generated')}",
                "",
                f"*{self.mission_yaml_skipped_reason or t('convert_v5.report.unknown_reason')}*",
                "",
            ]

        # src/mission promotion to v6 (FEAT-MIGRATE-MISSION-V6)
        if self.promotion_done:
            promo_body = t("report.promotion.done", backup=self.promotion_backup or "backup_v5/src/mission")
        elif not self.promotion_attempted:
            promo_body = t("report.promotion.skipped")
        else:
            promo_body = t("report.promotion.failed", reason=self.promotion_reason or "?")
        lines += [
            f"### 3. {t('report.section.promotion')}",
            "",
            promo_body,
            "",
        ]

        # Everything the run recorded as it went, verbatim and last. The numbered steps above
        # describe convert-v5's own stages, so a `convert-other` run — which shares this report
        # class — had *nothing* to show for itself: its whole account of the refresh went into
        # this list, which nothing printed (FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS ticket 02).
        if self.actions:
            lines += [f"### 4. {t('report.actions.recorded')}", ""]
            lines += [f"- {action}" for action in self.actions]
            lines.append("")

        lines += ["---", ""]

        # The missionConfig.lua migration is reported as the line→effect tables above
        # (commented doFiles, wrapped/extracted init calls, enabled modules); the
        # original file is preserved untouched under backup_v5/. We deliberately do not
        # embed a pseudo "annotated missionConfig.lua" here — it was never an executed
        # artifact and only obscured the actual outcome (CONVERT-V5-REPORT-ANNOTATION).

        # ── Manual review ─────────────────────────────────────────────────
        lines += [f"## {t('report.section.review')}", ""]

        # The items the section is named after. They were collected and counted — the summary
        # line at the top of the report counts exactly these plus the warnings — and then never
        # listed, so the count pointed at nothing a reader could act on.
        if self.manual_review:
            lines += [f"### 📝 {t('report.review.items_title')} ({len(self.manual_review)})", ""]
            lines += [f"- {item}" for item in self.manual_review]
            lines.append("")

        if self.warnings:
            lines += [f"### ⚠️ {t('report.warnings.title')} ({len(self.warnings)})", ""]
            for w in self.warnings:
                lines.append(f"- {w}")
            lines.append("")
        else:
            lines += [
                f"### ⚠️ {t('report.warnings.title')}",
                "",
                f"*{t('report.warnings.none')}*",
                "",
            ]

        # ── Legacy v5 files triaged (CONVERT-V5-CLEANUP-FILES) ────────────────
        if self.legacy_tooling_backed_up or self.regenerable_deleted or self.unrecognized_files:
            lines += [f"### 🧹 {t('report.legacy_files.title')}", ""]
            if self.legacy_tooling_backed_up:
                lines.append(t("report.legacy_files.tooling", n=len(self.legacy_tooling_backed_up)))
                lines += [f"- `{f}` → `backup_v5/{f}`" for f in self.legacy_tooling_backed_up]
                lines.append("")
            if self.secret_tooling_files:
                secret = ", ".join(f"`{f}`" for f in self.secret_tooling_files)
                lines += [f"> ⚠️ {t('report.legacy_files.secret', files=secret)}", ""]
            if self.regenerable_deleted:
                lines.append(t("report.legacy_files.deleted", n=len(self.regenerable_deleted)))
                lines += [f"- `{f}`" for f in self.regenerable_deleted]
                lines.append("")
            if self.unrecognized_files:
                lines.append(t("report.legacy_files.unrecognized", n=len(self.unrecognized_files)))
                lines += [f"- `{f}`" for f in self.unrecognized_files]
                lines.append("")
            lines += ["---", ""]

        # Always include cleanup advice
        lines += [
            f"### 🗑️ {t('report.cleanup.title')}",
            "",
            t("report.cleanup.intro"),
            "",
        ]
        cleanup_items: list[str] = []
        if self.missionconfig_backup:
            rel_bak = self.missionconfig_backup.relative_to(self.mission_folder)
            cleanup_items.append(t("report.cleanup.delete_bak", path=rel_bak))
        # No "remove the commented doFile() lines" item: those lines exist only in the
        # migrated buffer convert-v5 discards (the original missionConfig.lua is deleted),
        # so there is nothing on disk to clean up (CONVERT-V5-INIT-COMMENTED-NOISE).
        if self.backup_v5_sources:
            backed = ", ".join(f"`backup_v5/{s}`" for s in self.backup_v5_sources)
            cleanup_items.append(t("report.cleanup.delete_backup_v5", files=backed))
        if not cleanup_items:
            lines.append(f"*{t('report.cleanup.none')}*")
        else:
            for i, item in enumerate(cleanup_items, 1):
                lines.append(f"{i}. {item}")
        lines += ["", "---", ""]

        # ── Next steps ────────────────────────────────────────────────────
        lines += [
            f"## {t('report.section.next_steps')}",
            "",
            f"1. {t('report.next_steps.review_yaml')}",
            f"2. {t('report.next_steps.build')}",
            f"3. {t('report.next_steps.test')}",
            f"4. {t('report.next_steps.cleanup')}",
            "",
            "---",
            "",
        ]

        # ── Documentation ─────────────────────────────────────────────────
        lines += [f"## {t('report.section.docs')}", ""]
        for title, url in DOC_LINKS.items():
            lines.append(f"- [{title}]({url})")
        lines.append("")

        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------


class _LiteralDumper(yaml.Dumper):
    """YAML Dumper that uses literal block style (``|``) for multiline strings."""


def _literal_str(dumper: yaml.Dumper, data: str) -> yaml.ScalarNode:
    style = "|" if "\n" in data else None
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style=style)


_LiteralDumper.add_representer(str, _literal_str)


def _yaml_list_block(items: list[Any], indent: int = 4) -> list[str]:
    """Serialize a list of dicts to YAML lines at the given indent level."""
    raw = yaml.dump(
        items, Dumper=_LiteralDumper, default_flow_style=False, allow_unicode=True, sort_keys=False, indent=2
    ).rstrip("\n")
    prefix = " " * indent
    return [f"{prefix}{line}" for line in raw.splitlines()]


def _yaml_dict_block(data: dict, indent: int = 6) -> list[str]:
    """Serialize a flat dict to YAML key: value lines at the given indent level."""
    raw = yaml.dump(
        data, Dumper=_LiteralDumper, default_flow_style=False, allow_unicode=True, sort_keys=False, indent=2
    ).rstrip("\n")
    prefix = " " * indent
    return [f"{prefix}{line}" for line in raw.splitlines()]


def _yaml_scalar(value: object) -> str:
    """Render a scalar as a YAML value (bool/str/number)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return _yaml_str(value)
    return str(value)


def _ctld_csar_settings(mr: object, upper: str) -> dict:
    """Return the extracted CTLD/CSAR ``ctld.xxx`` / ``csar.xxx`` settings dict.

    Args:
        mr: The mission conversion result.
        upper: ``"CTLD"`` or ``"CSAR"``.

    Returns:
        The settings dict (empty when nothing was extracted).
    """
    attr = "ctld_config" if upper == "CTLD" else "csar_config"
    return getattr(mr, attr, None) or {}


_DECOMMENT_RE = re.compile(r"^(\s*)--+ ?(.*)$")


def _decomment_lua(content: str) -> str:
    """Strip the leading ``--`` from single-line comments to reveal v5 code.

    Used to recover *commented-out* v5 elements (CONVERT-FIDELITY-001): a
    re-extraction of the de-commented text surfaces any builder chains / tables
    the mission-maker had disabled. ``-- [v6 …]`` migration markers are left
    untouched (they are not original v5 elements). Prose comments are harmless —
    the extraction is pattern-based, so non-code lines simply do not match.

    Args:
        content: The original missionConfig.lua content.

    Returns:
        The content with single-line comments un-commented.
    """
    out: list[str] = []
    for line in content.splitlines():
        if line.lstrip().startswith("-- [v6"):
            out.append(line)
            continue
        match = _DECOMMENT_RE.match(line)
        out.append(f"{match.group(1)}{match.group(2)}" if match else line)
    return "\n".join(out)


def _emit_qra_definitions(silence_all: bool | None, definitions: list[dict], indent: int) -> list[str]:
    """Emit the QRA ``silence_all`` + ``definitions`` block at the given indent.

    Used to nest QRA config under ``modules.QRA`` (MODULES-UNIFY); the indent is
    the column of the ``silence_all:`` / ``definitions:`` keys.

    Args:
        silence_all: The ``ToggleAllSilence`` value, or ``None`` (defaults False).
        definitions: The extracted QRA builder-chain definitions.
        indent: Number of leading spaces for the top-level QRA keys.

    Returns:
        The YAML comment/value lines.
    """
    base = " " * indent
    item = " " * (indent + 2)
    field = " " * (indent + 4)
    sub = " " * (indent + 6)
    lines = [f"{base}silence_all: {'true' if silence_all else 'false'}", f"{base}definitions:"]
    for qra in definitions:
        lines.append(f"{item}- name: {_yaml_str(qra.get('name', 'QRA'))}")
        if coalition := qra.get("coalition"):
            lines.append(f"{field}coalition: {coalition}")
        if enemies := qra.get("enemy_coalitions"):
            lines.append(f"{field}enemy_coalitions:")
            lines.extend(f"{sub}- {e}" for e in enemies)
        if tz := qra.get("trigger_zone"):
            lines.append(f"{field}trigger_zone: {tz}")
        if zr := qra.get("zone_radius"):
            lines.append(f"{field}zone_radius: {zr}")
        if sg := qra.get("simple_groups"):
            lines.append(f"{field}simple_groups:")
            lines.extend(f"{sub}- {g}" for g in sg)
        if gbc := qra.get("groups_by_enemy_count"):
            lines.append(f"{field}groups_by_enemy_count:")
            for entry in gbc:
                lines.append(f"{sub}- enemy_count: {entry['enemy_count']}")
                groups = entry.get("groups", [])
                if groups:
                    lines.append(f"{sub}  groups:")
                    lines.extend(f"{sub}    - {g}" for g in groups)
                lines.append(f"{sub}  random_pick: {entry.get('random_pick', 1)}")
        if dbr := qra.get("delay_before_rearming"):
            lines.append(f"{field}delay_before_rearming: {dbr}")
        if dba := qra.get("delay_before_activating"):
            lines.append(f"{field}delay_before_activating: {dba}")
        if qra.get("react_on_helicopters"):
            lines.append(f"{field}react_on_helicopters: true")
        if al := qra.get("airport_link"):
            lines.append(f"{field}airport_link: {_yaml_str(al)}")
        if not qra.get("start", True):
            lines.append(f"{field}start: false  {t('converter.yaml.qra.start_comment')}")
    return lines


def _is_v6_migration_comment(line: str) -> bool:
    """Return True for lines that are pure v6 migration annotations (not code)."""
    stripped = line.lstrip()
    return stripped.startswith("-- [v6 extracted to mission.yaml]") or stripped.startswith("-- [v6 migration]")


def _generate_mission_script(result: MigrationResult, version: str = "unknown") -> str:
    """Generate a clean mission-script.lua from scratch.

    Contains only a header comment and optional callback stubs for any callbacks
    that were detected during migration but cannot be expressed in mission.yaml.
    Everything else (module init, configuration) is handled by veaf-config.lua.
    """
    lines = [
        "-- mission-script.lua",
        f"-- Generated by veaf-tools convert-v5 (v{version})",
        "--",
        "-- This file should contain ONLY code that cannot be expressed in mission.yaml,",
        "-- such as callback functions for CombatZone, AirWaves, QRA, etc.",
        "-- Module initialization is handled automatically by veaf-config.lua (generated at build time).",
        "--",
        "-- Add your custom code below.",
        "",
    ]

    if result.callback_hints:
        lines += [
            "-- ── Callbacks detected during conversion ─────────────────────────────────────",
            "-- The following callbacks were found in missionConfig.lua but cannot be",
            "-- expressed in mission.yaml. Uncomment and implement them here.",
            "",
        ]
        for hint in result.callback_hints:
            lines += [
                "-- local function myCallback(arg)",
                "--   -- TODO: implement",
                "-- end",
                f"-- {hint}",
                "",
            ]

    if result.not_migrated:
        # A declared loss, in the sense callback_hints established. The original lines are kept
        # verbatim so the author can uncomment what still matters: convert-v5 deletes
        # missionConfig.lua, and a mission that behaves differently with nothing naming the
        # settings that stopped applying is the defect this block exists to prevent (#725).
        lines += [
            "-- ── Settings NOT migrated ────────────────────────────────────────────────────",
            "-- These were set in missionConfig.lua and are expressed by neither mission.yaml nor",
            "-- the generated veaf-config.lua, so they no longer apply. The original lines are kept",
            "-- verbatim below: uncomment the ones your mission needs.",
            "--",
            "-- A setting listed here is not necessarily a bug in your mission — it may simply be a",
            "-- v5 setting v6 has no key for yet. Please report it so it can be carried properly.",
            "",
        ]
        lines += [f"-- {line}" for line in result.not_migrated]
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Converter
# ---------------------------------------------------------------------------


class V5Converter:
    """Orchestrates the full v5 → v6 conversion of a VEAF mission folder."""

    def __init__(self, version: str = "unknown") -> None:
        self._version = version
        self._migrator = ConfigMigrator()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def convert(
        self,
        mission_folder: Path,
        overwrite_mission_yaml: bool = False,
        backup: bool = True,
        convert_pipeline: bool = True,
        icao_callback: Callable[[str], str] | None = None,
    ) -> ConversionReport:
        """Run all migration steps and return a :class:`ConversionReport`.

        Parameters
        ----------
        mission_folder:
            Root of the VEAF mission folder (where ``mission.yaml`` should live).
        overwrite_mission_yaml:
            When ``True``, overwrite an existing ``mission.yaml``.
        backup:
            When ``True`` (default), create a ``.bak`` copy of
            ``missionConfig.lua`` before overwriting it.
        convert_pipeline:
            When ``True`` (default), automatically convert detected v5 pipeline
            files (presets, waypoints, weather, aircraft groups) to v6 YAML.
        icao_callback:
            Optional callable ``(version_name) -> icao_code`` invoked for each
            weather version that uses ``realweather: true``.  When ``None``,
            a ``TODO`` placeholder is inserted.
        """
        report = ConversionReport(mission_folder=mission_folder, version=self._version)

        # Step 1 — Scan
        self._scan(report)

        # Step 1.5 — Convert v5 pipeline files (before mission.yaml generation)
        if convert_pipeline:
            self._convert_pipeline_files(report, icao_callback=icao_callback)
            # …and upgrade the ones already at their v6 path but still holding the v5 schema.
            self._migrate_pipeline_schemas(report, backup=backup)

        # Step 2 — Migrate missionConfig.lua
        if report.missionconfig_path:
            self._migrate_config(report, backup=backup)
        else:
            report.warnings.append(
                "missionConfig.lua not found — Lua config migration was skipped. "
                "Searched: " + ", ".join(str(mission_folder / c) for c in MISSIONCONFIG_CANDIDATES)
            )

        # Step 3 — Generate mission.yaml
        self._generate_mission_yaml(report, overwrite=overwrite_mission_yaml)

        # Step 4 — Build manual-review list
        self._build_manual_review(report)

        # Step 5 — Triage leftover v5 files (tooling → backup_v5/, regenerable → deleted,
        # unrecognized → listed). Runs last, after the handled files have been moved out.
        self._cleanup_legacy_v5_files(report)

        return report

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _backup_and_delete_v5(
        self,
        step: str,
        v5_path: Path,
        report: ConversionReport,
    ) -> None:
        """Copy the v5 source to ``backup_v5/``, delete it, and prune empty dirs."""
        mission_folder = report.mission_folder
        backup_root = mission_folder / "backup_v5"
        # For weather the whole weatherAndTime/ folder is obsolete
        # (includes the per-version .lua files).  For all other steps
        # only the specific detected file needs to be archived.
        source = v5_path.parent if step == "weather" else v5_path
        is_dir = source.is_dir()
        try:
            rel = source.relative_to(mission_folder)
        except ValueError:
            report.warnings.append(t("convert_v5.action.backup_path_error", source=source))
            return
        backup_dest = backup_root / rel
        try:
            if is_dir:
                if backup_dest.exists():
                    shutil.rmtree(backup_dest)
                shutil.copytree(source, backup_dest)
                shutil.rmtree(source)
            else:
                backup_dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, backup_dest)
                source.unlink()
            # Prune empty parent directories up to mission_folder
            prune = source.parent
            while prune != mission_folder and prune.exists() and not any(prune.iterdir()):
                prune.rmdir()
                prune = prune.parent
            rel_str = str(rel).replace("\\", "/")
            report.backup_v5_sources.append(rel_str)
            report.actions.append(t("convert_v5.action.v5_backed_up", path=rel_str))
        except Exception as exc:
            report.warnings.append(t("convert_v5.action.backup_error", rel=rel, exc=exc))

    def _archive_file_to_backup_v5(self, path: Path, report: ConversionReport) -> bool:
        """Copy *path* under ``backup_v5/`` (mirroring its relative path) and delete it.

        Returns ``True`` on success; on failure the file is left in place and a warning
        is recorded.
        """
        mission_folder = report.mission_folder
        try:
            rel = path.relative_to(mission_folder)
        except ValueError:
            report.warnings.append(t("convert_v5.action.backup_path_error", source=path))
            return False
        dest = mission_folder / "backup_v5" / rel
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
            path.unlink()
            return True
        except Exception as exc:
            report.warnings.append(t("convert_v5.action.backup_error", rel=rel, exc=exc))
            return False

    def _cleanup_legacy_v5_files(self, report: ConversionReport) -> None:
        """Triage v5 files made obsolete by the v6 toolchain (CONVERT-V5-CLEANUP-FILES).

        Three outcomes:
        - **Tooling files** at the root (``build*.cmd``, ``*.ps1``, ``package.json``,
          ``yarn.lock``, ``configuration.json``, …) → moved to ``backup_v5/`` (reversible).
        - **Regenerable artifacts** at the root (``node_modules/``, ``build/``, ``cache/``)
          → deleted outright (gitignored, rebuilt on demand — not worth archiving).
        - **Unrecognized files** (root + ``src/`` top level) → only listed in the report
          for the maker to review; never touched.

        Never touches ``.git/``, ``backup_v5/``, ``src/mission/``, generated v6 files, or
        dotfiles. Safe to re-run: a second pass finds nothing left to clean.
        """
        folder = report.mission_folder

        def _is_tooling(name: str) -> bool:
            return name in _LEGACY_V5_TOOLING_NAMES or any(fnmatch(name, g) for g in _LEGACY_V5_TOOLING_GLOBS)

        for entry in sorted(folder.iterdir(), key=lambda p: p.name):
            name = entry.name
            if (
                name.startswith(".")
                or name in _CLEANUP_ROOT_KNOWN
                # Case-insensitive on every OS (fnmatchcase on the lowered name): the
                # toolchain must be skipped whatever the casing, and matching must not
                # depend on the platform (plain fnmatch differs Windows vs POSIX).
                or any(fnmatchcase(name.lower(), g) for g in _CLEANUP_TOOLCHAIN_GLOBS)
            ):
                continue
            if entry.is_dir() and name in _LEGACY_V5_REGENERABLE_DIRS:
                try:
                    shutil.rmtree(entry)
                    report.regenerable_deleted.append(f"{name}/")
                    report.actions.append(t("convert_v5.cleanup.deleted", path=f"{name}/"))
                except Exception as exc:
                    report.warnings.append(t("convert_v5.cleanup.delete_failed", path=name, exc=exc))
            elif entry.is_file() and _is_tooling(name):
                if self._archive_file_to_backup_v5(entry, report):
                    report.legacy_tooling_backed_up.append(name)
                    report.actions.append(t("convert_v5.cleanup.backed_up", path=name))
                    if name in _LEGACY_V5_SECRET_NAMES:
                        report.secret_tooling_files.append(name)
            else:
                report.unrecognized_files.append(f"{name}/" if entry.is_dir() else name)

        src = folder / "src"
        if src.is_dir():
            for entry in sorted(src.iterdir(), key=lambda p: p.name):
                name = entry.name
                if name.startswith(".") or name in _CLEANUP_SRC_KNOWN:
                    continue
                report.unrecognized_files.append(f"src/{name}/" if entry.is_dir() else f"src/{name}")

        # Defensive: keep each reported path unique (order-preserving), so an accidental
        # double call never repeats an entry in the report/console.
        report.unrecognized_files = list(dict.fromkeys(report.unrecognized_files))

    def _migrate_pipeline_schemas(self, report: ConversionReport, backup: bool) -> None:
        """Rewrite pipeline files that sit at their v6 path but hold the v5 schema.

        Only ``presets`` has such a case today. The original is kept beside the mission as
        ``backup_v5/src/presets.yaml`` when *backup* is on, so a maker can compare.

        Args:
            report: The conversion report, updated in place with actions and warnings.
            backup: Whether to keep the pre-migration copy under ``backup_v5/``.
        """
        for pf in report.pipeline_files:
            if not pf.needs_schema_migration:
                continue
            label = t(f"pipeline.label.{pf.step}")
            try:
                data = yaml.safe_load(pf.path.read_text(encoding="utf-8"))
                migrated, warnings = migrate_presets_schema(data)
                if backup:
                    backup_path = report.mission_folder / "backup_v5" / pf.relative
                    backup_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(pf.path, backup_path)
                pf.path.write_text(
                    yaml.safe_dump(migrated, allow_unicode=True, sort_keys=False, default_flow_style=False),
                    encoding="utf-8",
                )
                pf.needs_schema_migration = False
                pf.converted = True
                report.actions.append(t("convert_v5.action.pipeline_schema_migrated", label=label, target=pf.relative))
                for w in warnings:
                    report.warnings.append(f"{label}: {w}")
            except Exception as exc:
                report.warnings.append(t("convert_v5.action.pipeline_convert_failed", label=label, exc=exc))

    def _convert_pipeline_files(
        self,
        report: ConversionReport,
        icao_callback: Callable[[str], str] | None = None,
    ) -> None:
        """Convert detected v5 pipeline files to v6 YAML format in-place."""
        for pf in report.pipeline_files:
            if not pf.needs_conversion:
                continue
            v5_abs_path = pf.path  # save before we overwrite pf.path below
            v6_path = report.mission_folder / pf.v6_target
            _lk = f"pipeline.label.{pf.step}"
            _lk_val = t(_lk)
            label = _lk_val if _lk_val != _lk else pf.step
            try:
                warnings = convert_pipeline_file(
                    pf.step,
                    pf.path,
                    v6_path,
                    icao_callback=icao_callback,
                )
                pf.needs_conversion = False
                pf.converted = True
                pf.v5_source = pf.relative
                pf.path = v6_path
                pf.relative = pf.v6_target
                for w in warnings:
                    report.warnings.append(f"{label}: {w}")
                report.actions.append(t("convert_v5.action.pipeline_converted", label=label, target=pf.v6_target))
                self._backup_and_delete_v5(pf.step, v5_abs_path, report)
            except Exception as exc:
                report.warnings.append(t("convert_v5.action.pipeline_convert_failed", label=label, exc=exc))

    def _scan(self, report: ConversionReport) -> None:
        """Detect missionConfig.lua, existing mission.yaml, and pipeline files."""
        folder = report.mission_folder

        for candidate in MISSIONCONFIG_CANDIDATES:
            p = folder / candidate
            if p.exists():
                report.missionconfig_path = p
                break

        report.mission_yaml_existed = (folder / "mission.yaml").exists()

        # Detect which community scripts are present in published/src/scripts/community/
        community_folder = folder / "published" / "src" / "scripts" / "community"
        if community_folder.is_dir():
            present_filenames = {p.name for p in community_folder.iterdir() if p.is_file()}
            for script in get_community_script_files():
                if Path(script["path"]).name in present_filenames:
                    report.detected_community_script_ids.add(script["id"])

        # MiST is the one script whose presence proves nothing (DROP-MIST ticket 08): v5 injected it
        # into every mission, used or not, so every folder being converted has it. Detecting it by
        # file name would emit `MIST: true` for all of them and carry 336 KB forward for nobody.
        # Ask the same question the builder asks instead — does one of this mission's own scripts
        # call it? — which is what keeps a mission like an Open Training one, whose HoundElint calls
        # `mist.DBs.humansByName`, working across the conversion.
        if "mist" in report.detected_community_script_ids:
            report.mist_callers = mission_scripts_referencing_mist(folder / "src" / "scripts")
            if not report.mist_callers:
                report.detected_community_script_ids.discard("mist")

        for step, v6_candidates in V6_PIPELINE_CANDIDATES.items():
            # Check v6-format files first (already converted or freshly created)
            for rel in v6_candidates:
                p = folder / rel
                if p.exists():
                    # Being at the v6 path is not the same as being at the v6 schema. Detected by
                    # **structure**, never by file name: a name says nothing about content, which is
                    # exactly how a v5 presets.yaml used to pass for converted.
                    report.pipeline_files.append(
                        PipelineFile(
                            step=step,
                            path=p,
                            relative=rel,
                            needs_schema_migration=_holds_v5_schema(step, p),
                        )
                    )
                    break
            else:
                # Not found as v6 — check v5 source paths
                for rel in V5_PIPELINE_CANDIDATES.get(step, []):
                    p = folder / rel
                    if p.exists():
                        report.pipeline_files.append(
                            PipelineFile(
                                step=step,
                                path=p,
                                relative=rel,
                                needs_conversion=True,
                                v6_target=v6_candidates[0],
                            )
                        )
                        break

    def _migrate_config(self, report: ConversionReport, backup: bool) -> None:
        """Run ConfigMigrator on missionConfig.lua and write the result.

        File layout after migration:
        - ``backup_v5/src/scripts/missionConfig.lua``  — original unmodified copy (for rollback)
        - ``src/scripts/mission-script.lua``            — clean v6 file (callback stubs only)

        The annotated version (with ``-- [v6 ...]`` comments) is embedded in
        ``convert-v5-report.md``, not written as a separate file in ``backup_v5/``.
        """
        src = report.missionconfig_path
        assert src is not None

        original_content = src.read_text(encoding="utf-8")
        result = self._migrator.migrate(original_content)
        report.migration_result = result
        report.missionconfig_source = original_content

        mission_folder = report.mission_folder

        # Place the original .bak under backup_v5/ (the authoritative rollback reference).
        if backup:
            try:
                rel = src.relative_to(mission_folder)
            except ValueError:
                rel = Path(src.name)
            backup_dir = mission_folder / "backup_v5" / rel.parent
            backup_dir.mkdir(parents=True, exist_ok=True)

            bak_path = backup_dir / src.name
            if not bak_path.exists():
                shutil.copy2(src, bak_path)
                report.missionconfig_backup = bak_path
                report.actions.append(t("convert_v5.action.missionconfig_bak", path=f"{rel.parent}/{src.name}"))

            # Write a README.txt in backup_v5/ explaining its purpose
            readme_path = mission_folder / "backup_v5" / "README.txt"
            if not readme_path.exists():
                readme_path.write_text(
                    "backup_v5/ — v5 migration backup\n"
                    "================================\n"
                    "\n"
                    "This folder contains a backup of your original v5 missionConfig.lua.\n"
                    "It was created automatically by 'veaf-tools convert-v5'.\n"
                    "\n"
                    "Contents:\n"
                    "  src/scripts/missionConfig.lua  — original unmodified file (for rollback)\n"
                    "\n"
                    "What each line of the original was migrated into is summarised in the\n"
                    "conversion report (commented doFiles, init calls, enabled modules):\n"
                    "  convert-v5-report.md\n"
                    "\n"
                    "Once you have verified that the mission builds and runs correctly:\n"
                    "  1. Delete this entire backup_v5/ folder.\n"
                    "  2. Remove any old 'do file(...)' calls from your triggers (already commented out).\n"
                    "\n"
                    "Do NOT edit the .bak file — it is an exact copy of your original missionConfig.lua.\n",
                    encoding="utf-8",
                )

        # Generate clean mission-script.lua from scratch (only callback stubs — no old code)
        clean_content = _generate_mission_script(result, self._version)

        dest = src.parent / "mission-script.lua"
        dest.write_text(clean_content, encoding="utf-8")
        report.missionconfig_output = dest

        # Remove the original missionConfig.lua (replaced by mission-script.lua)
        src.unlink()

        # Only mention mission-script.lua when it actually carries callbacks to
        # implement; an empty skeleton (header only) needs no mention. The doFile /
        # bare-initialize() edits describe the migrated buffer that convert-v5 never
        # writes to disk (the original is deleted), so they are no longer reported
        # here — only the standalone `migrate-config` command, which DOES write that
        # buffer, still reports them (CONVERT-V5-INIT-COMMENTED-NOISE).
        if result.callback_hints:
            report.actions.append(t("convert_v5.action.mission_script_generated"))

        if not result.removed_dofiles and not result.wrapped_calls:
            report.actions.append(t("convert_v5.action.already_v6"))
        if result.enabled_modules:
            report.actions.append(
                tn(
                    "convert_v5.action.modules_detected",
                    len(result.enabled_modules),
                    list=", ".join(result.enabled_modules),
                )
            )
        for w in result.warnings:
            report.warnings.append(f"missionConfig.lua: {w}")

        # Settings no extractor recognised: named in the report as well as in the generated Lua,
        # since the report is what a mission maker reads after a conversion (#725).
        if result.not_migrated:
            report.warnings.append(
                t(
                    "convert_v5.warning.settings_not_migrated",
                    count=len(result.not_migrated),
                    settings=", ".join(result.not_migrated),
                )
            )

        # Report extracted YAML data
        mr = result
        if mr.mission_name or mr.mission_era or mr.mission_export_path is not None:
            report.actions.append(t("convert_v5.action.identity_extracted"))
        if mr.assets_extracted:
            report.actions.append(tn("convert_v5.action.assets_extracted", len(mr.assets_extracted)))
        if mr.qra_definitions:
            report.actions.append(tn("convert_v5.action.qra_extracted", len(mr.qra_definitions)))
        if mr.cap_missions_extracted:
            report.actions.append(tn("convert_v5.action.cap_extracted", len(mr.cap_missions_extracted)))
        if mr.combat_missions_extracted:
            report.actions.append(tn("convert_v5.action.combat_extracted", len(mr.combat_missions_extracted)))

    def _generate_mission_yaml(self, report: ConversionReport, overwrite: bool) -> None:
        """Build and write mission.yaml."""
        dest = report.mission_folder / "mission.yaml"

        if dest.exists() and not overwrite:
            report.mission_yaml_skipped_reason = t("convert_v5.action.yaml_skip_reason")
            report.actions.append(t("convert_v5.action.yaml_exists"))
            return

        content = self._build_mission_yaml(report)
        content = self._append_commented_v5_elements(report, content)
        dest.write_text(content, encoding="utf-8")
        report.mission_yaml_generated = True
        report.mission_yaml_path = dest

        enabled_count = len(report.migration_result.enabled_modules) if report.migration_result else 0
        all_count = len(get_modules())
        v6_ready = sum(1 for pf in report.pipeline_files if not pf.needs_conversion)
        v5_detected = sum(1 for pf in report.pipeline_files if pf.needs_conversion)
        pipeline_note = tn("convert_v5.action.pipeline_steps_ready", v6_ready)
        if v5_detected:
            pipeline_note += f", {tn('convert_v5.action.pipeline_steps_v5', v5_detected)}"
        report.actions.append(
            t("convert_v5.action.yaml_generated", enabled=enabled_count, total=all_count, pipeline=pipeline_note)
        )

    def _append_commented_v5_elements(self, report: ConversionReport, active_yaml: str) -> str:
        """Recover commented-out v5 elements and append them as commented YAML.

        Re-extracts the de-commented ``missionConfig.lua`` and diffs the
        resulting ``mission.yaml`` against the active one; any lines that exist
        only because of previously-commented elements are appended under a
        clearly-marked, fully-commented block so the mission-maker can re-enable
        them by uncommenting (CONVERT-FIDELITY-001). Returns ``active_yaml``
        unchanged when there is nothing to recover.

        Args:
            report: The conversion report (source + active migration result).
            active_yaml: The mission.yaml built from the active configuration.

        Returns:
            ``active_yaml``, optionally followed by the commented-elements block.
        """
        source = report.missionconfig_source
        active_mr = report.migration_result
        if not source or active_mr is None:
            return active_yaml

        decommented = _decomment_lua(source)
        if decommented == source:
            return active_yaml

        # Build the de-commented mission.yaml with the same report context.
        saved_deps = list(report.auto_resolved_deps)
        report.migration_result = self._migrator.migrate(decommented)
        decommented_yaml = self._build_mission_yaml(report)
        report.migration_result = active_mr
        report.auto_resolved_deps = saved_deps

        # Lines present only in the de-commented YAML are the recovered elements.
        # Only ``insert`` opcodes are taken: a ``replace`` could carry lines that
        # are modifications of *active* config rather than purely recovered
        # elements, which we must not mislabel as "commented-out".
        active_lines = active_yaml.splitlines()
        decommented_lines = decommented_yaml.splitlines()
        matcher = difflib.SequenceMatcher(a=active_lines, b=decommented_lines)
        recovered: list[str] = []
        for tag, _i1, _i2, j1, j2 in matcher.get_opcodes():
            if tag == "insert":
                recovered.extend(line for line in decommented_lines[j1:j2] if line.strip())
        if not recovered:
            return active_yaml

        block = ["", t("converter.yaml.header.commented_elements")]
        block += [f"# {line}" for line in recovered]
        return active_yaml + "\n" + "\n".join(block) + "\n"

    def _build_mission_yaml(self, report: ConversionReport) -> str:
        """Produce the full mission.yaml content (with explanatory comments)."""
        import re as _re  # noqa: PLC0415 (avoid shadowing outer re)

        folder_name = report.mission_folder.name
        now = report.timestamp
        mr: MigrationResult | None = report.migration_result

        # Language-aware GUIDE base, with the trailing slash the site needs before a
        # `#fragment` (otherwise `GUIDE` redirects to `GUIDE/` and drops the anchor). The
        # anchors below are stable explicit ids declared identically on the FR and EN
        # headings via attr_list (DOC-GUIDE-ANCHORS).
        _DOC_BASE = (
            f"https://veaf.github.io/documentation/dev/{_doc_lang_segment(current_language())}mission-maker/GUIDE/"
        )

        lines: list[str] = [
            f"# mission.yaml — generated by veaf-tools convert-v5 on {now}",
            f"# Source mission folder: {folder_name}",
            "#",
            t("converter.yaml.file_place"),
            t("converter.yaml.file_optional"),
            "#",
            f"# Doc: {_DOC_BASE}",
            "",
        ]
        lines.extend(yaml_syntax_header())
        lines.append("")

        # ── Global log level ──────────────────────────────────────────────
        extracted_ll = mr.global_log_level_extracted if mr else None
        lines += [
            t("converter.yaml.header.loglevel"),
            t("converter.yaml.loglevel.desc1"),
            t("converter.yaml.loglevel.desc2"),
            t("converter.yaml.loglevel.desc3"),
            f"# Doc: {_DOC_BASE}#debug-logging",
            "#",
            f"global_log_level: {extracted_ll or 'info'}",
            "",
        ]

        # ── Mission identity ───────────────────────────────────────────────
        if mr and (mr.mission_name or mr.mission_era or mr.mission_export_path is not None or mr.silence_atc):
            lines.append(t("converter.yaml.header.identity"))
            lines.append("mission:")
            if mr.mission_name:
                lines.append(f"  name: {_yaml_str(mr.mission_name)}")
            if mr.mission_era:
                lines.append(f"  era: {mr.mission_era}")
            if mr.mission_export_path is not None:
                ep_yaml = _yaml_str(str(mr.mission_export_path))
                lines.append(f"  export_path: {ep_yaml}")
            # CONVERT-FIDELITY-003: only emit when active (absent ≡ not silenced).
            # FIX-MISSIONYAML-MISSION-SECTION: annotate provenance so the maker
            # understands "how it got here" (a mission-wide option, not identity).
            if mr.silence_atc:
                lines.append("  silence_atc_on_all_airbases: true  # migrated from veaf.silenceAtcOnAllAirbases()")
            lines.append("")

        # ── Security ──────────────────────────────────────────────────────
        if mr and (mr.security_disabled is not None or mr.password_mm_hashes or mr.password_hashes):
            lines.append(t("converter.yaml.header.security"))
            lines.append("security:")
            if mr.security_disabled is not None:
                lines.append(f"  disabled: {'true' if mr.security_disabled else 'false'}")
            # The mission's own level-1 hashes. Never the two `veafSecurity.lua` ships to every
            # mission: they are public, and carrying one here would re-open the hole VMR-040 closed
            # (FIX-CONVERT-V5-SILENT-LOSSES ticket 04).
            if mr.password_hashes:
                lines.append("  password_hashes:")
                for h in mr.password_hashes:
                    lines.append(f"    - {_yaml_str(h)}")
            if mr.password_mm_hashes:
                lines.append("  password_mm_hashes:")
                for h in mr.password_mm_hashes:
                    lines.append(f"    - {_yaml_str(h)}")
            lines.append("")

        # ── Module settings (FIX-CONVERT-V5-SILENT-LOSSES ticket 04) ───────
        if mr and mr.module_settings:
            lines.append("# Scalar settings read straight off a VEAF module table in missionConfig.lua.")
            lines.append("# Half of these used to reach neither this file nor the generated Lua (#725).")
            lines.append("module_settings:")
            for key, value in mr.module_settings.items():
                rendered = (
                    _yaml_str(value)
                    if isinstance(value, str)
                    else str(value).lower()
                    if isinstance(value, bool)
                    else value
                )
                lines.append(f"  {key}: {rendered}")
            lines.append("")

        # ── Module configuration ───────────────────────────────────────────
        # Base infrastructure modules that must always be explicitly enabled.
        # Without them in lua_modules, their initialize() would not be called.
        _BASE_ALWAYS_ON: frozenset[str] = MANDATORY_MODULES | frozenset({"AIRBASES"})

        lines += [
            t("converter.yaml.header.modules"),
            t("converter.yaml.modules.desc1"),
            t("converter.yaml.modules.desc2"),
            t("converter.yaml.modules.desc3"),
            t("converter.yaml.modules.desc4"),
            "#   enabled: true",
            "#   ...",
            f"# Doc: {_DOC_BASE}#configuring-modules",
            "#",
            "modules:",
        ]

        enabled_modules = mr.enabled_modules if mr else []
        enabled_set = set(enabled_modules) | _BASE_ALWAYS_ON
        # QRA config now lives under modules.QRA, so the module must be enabled
        # whenever QRA definitions were extracted (MODULES-UNIFY).
        if mr and mr.qra_definitions:
            enabled_set.add("QRA")
        # Pre-resolve module dependencies (e.g. CASMISSION → GROUNDAI, SPAWN) so
        # the generated mission.yaml is self-consistent and the build no longer
        # needs to auto-enable them at config-generation time with a warning.
        auto_deps = resolve_module_dependencies(enabled_set)
        # Always assign (even when empty) so a report reused across calls never
        # keeps stale auto-resolved dependencies.
        report.auto_resolved_deps = auto_deps
        if auto_deps:
            enabled_set.update(auto_deps)
        all_mods = get_modules()

        # Modules explicitly enabled (from missionConfig.lua or always-on base set)
        enabled_by_id = {m["id"] for m in all_mods if m["id"] in enabled_set}

        # A few modules (SKYNET) are ALSO community scripts and own a richer, config-carrying
        # entry in the dedicated community section below. Emitting them here too would write the
        # same YAML key twice. The community section is authoritative, so skip them here.
        community_ids_upper = {s["id"].upper() for s in get_community_script_files()}

        # Emit modules grouped by category in declaration order
        for category, cat_mods in MODULE_CATEGORIES.items():
            cat_enabled = [mid for mid in cat_mods if mid in enabled_by_id and mid not in community_ids_upper]
            if not cat_enabled:
                continue
            lines.append(f"  # {category}")
            for mid in cat_enabled:
                yaml_key = f'"{mid}"' if not _re.match(r"^[A-Za-z_]\w*$", mid) else mid
                # Detect whether extra config will follow (block style needed)
                has_config = bool(
                    (mid == "ASSETS" and mr and mr.assets_extracted)
                    or (mid == "SHORTCUTS" and mr and mr.shortcuts_extracted)
                    or (mid == "SANCTUARY" and mr and mr.sanctuary_zones_extracted)
                    or (mid == "COMBATZONE" and mr and (mr.combat_zone_settings_extracted or mr.combat_zones_extracted))
                    or (mid == "AIRWAVES" and mr and mr.airwave_zones_extracted)
                    or (mid == "QRA" and mr and mr.qra_definitions)
                )
                lines.extend(yaml_module_entry(yaml_key, mid, has_config=has_config))
                # Inject extracted config under the module entry
                if mid == "ASSETS" and mr and mr.assets_extracted:
                    lines.append("    assets:")
                    for asset in mr.assets_extracted:
                        first = True
                        for k, v in asset.items():
                            prefix = "    - " if first else "      "
                            first = False
                            if isinstance(v, bool):
                                lines.append(f"{prefix}{k}: {'true' if v else 'false'}")
                            elif isinstance(v, str):
                                lines.append(f"{prefix}{k}: {_yaml_str(v)}")
                            else:
                                lines.append(f"{prefix}{k}: {v}")

                elif mid == "SHORTCUTS" and mr and mr.shortcuts_extracted:
                    lines.append("    shortcuts:")
                    lines.extend(_yaml_list_block(mr.shortcuts_extracted, indent=4))

                elif mid == "SANCTUARY" and mr and mr.sanctuary_zones_extracted:
                    lines.append("    sanctuary_zones:")
                    lines.extend(_yaml_list_block(mr.sanctuary_zones_extracted, indent=4))

                elif mid == "COMBATZONE" and mr:
                    if mr.combat_zone_settings_extracted:
                        lines.append("    combat_zone_settings:")
                        lines.extend(_yaml_dict_block(mr.combat_zone_settings_extracted, indent=6))
                    if mr.combat_zones_extracted:
                        lines.append("    combat_zones:")
                        lines.extend(_yaml_list_block(mr.combat_zones_extracted, indent=4))

                elif mid == "AIRWAVES" and mr and mr.airwave_zones_extracted:
                    lines.append("    airwave_zones:")
                    lines.extend(_yaml_list_block(mr.airwave_zones_extracted, indent=4))

                elif mid == "QRA" and mr and mr.qra_definitions:
                    lines.extend(_emit_qra_definitions(mr.qra_silence_all, mr.qra_definitions, indent=4))

        # Emit any enabled module not in any known category (safety net)
        categorized = {mid for mods in MODULE_CATEGORIES.values() for mid in mods}
        uncategorized = [mid for mid in enabled_by_id if mid not in categorized]
        if uncategorized:
            for mid in sorted(uncategorized):
                yaml_key = f'"{mid}"' if not _re.match(r"^[A-Za-z_]\w*$", mid) else mid
                lines.extend(yaml_module_entry(yaml_key, mid))

        # Community scripts appended at end of modules: block (IDs in uppercase)
        all_community = get_community_script_files()
        detected_comm = report.detected_community_script_ids
        # Opt-in scripts (e.g. TUM) must never be enabled automatically — they need a
        # specific mission-design setup — even when their .lua is present in the bundle.
        optin_comm = get_optin_community_script_ids()
        if all_community:
            lines.append(t("converter.yaml.community.header"))
            lines.append(t("converter.yaml.community.desc"))
            lines.append(f"# Doc: {_DOC_BASE}#ctld-and-csar-integration")
            for script in all_community:
                sid = script["id"]
                upper = sid.upper()
                detected = sid in detected_comm
                if upper == "SKYNET" and mr and mr.skynet_config:
                    sc = mr.skynet_config
                    lines.append("  SKYNET:")
                    lines.append("    enabled: true")
                    lines.append(f"    include_red_in_radio: {'true' if sc.get('include_red_in_radio') else 'false'}")
                    lines.append(f"    debug_red: {'true' if sc.get('debug_red') else 'false'}")
                    lines.append(f"    include_blue_in_radio: {'true' if sc.get('include_blue_in_radio') else 'false'}")
                    lines.append(f"    debug_blue: {'true' if sc.get('debug_blue') else 'false'}")
                elif upper in ("CTLD", "CSAR") and detected and mr and _ctld_csar_settings(mr, upper):
                    lines.append(f"  {upper}:")
                    lines.append("    enabled: true")
                    lines.append("    settings:")
                    for key, value in _ctld_csar_settings(mr, upper).items():
                        lines.append(f"      {key}: {_yaml_scalar(value)}")
                elif sid == "mist":
                    # MiST is opt-in like TUM, but for the opposite reason: TUM must not start on
                    # its own because it imposes a mission-design contract, whereas MiST is simply
                    # dead weight for a mission that does not call it. So unlike TUM it *is*
                    # enabled when detected — and `detected` here already means "one of this
                    # mission's scripts calls it", not "the file was in the v5 bundle".
                    lines.append(f"  {upper}: {'true' if detected else 'false'}")
                elif sid in optin_comm:
                    # Opt-in: keep disabled by default; the maker enables it explicitly.
                    lines.append(f"  {upper}: false")
                else:
                    # A community script that is also an enabled module (SKYNET) counts as
                    # enabled even when its .lua is not bundled, so its single entry here still
                    # reflects the mission's intent.
                    enabled = detected or upper in enabled_by_id
                    lines.append(f"  {upper}: {'true' if enabled else 'false'}")
        lines.append("")

        # ── CAP missions ──────────────────────────────────────────────────
        if mr and mr.cap_missions_extracted:
            lines.append(t("converter.yaml.header.cap"))
            lines.append(f"# Doc: {_DOC_BASE}#configuration-examples")
            lines.append("cap_missions:")
            for cap in mr.cap_missions_extracted:
                lines.append(f"  - group_name: {_yaml_str(cap.get('group_name', ''))}")
                lines.append(f"    menu_name: {_yaml_str(cap.get('menu_name', ''))}")
                b = cap.get("briefing", "")
                if b and "\n" in b:
                    lines.append("    briefing: |")
                    for bl in b.strip().splitlines():
                        lines.append(f"      {bl}")
                else:
                    lines.append(f"    briefing: {_yaml_str(b)}")
                lines.append(f"    default: {'true' if cap.get('default') else 'false'}")
                lines.append(f"    activated: {'true' if cap.get('activated', True) else 'false'}")
            lines.append("")

        # ── Combat missions ───────────────────────────────────────────────
        if mr and mr.combat_missions_extracted:
            lines.append(t("converter.yaml.header.combat"))
            lines.append(f"# Doc: {_DOC_BASE}#configuration-examples")
            lines.append("combat_missions:")
            for cm in mr.combat_missions_extracted:
                lines.append(f"  - name: {_yaml_str(cm.get('name', ''))}")
                if fn := cm.get("friendly_name"):
                    lines.append(f"    friendly_name: {_yaml_str(fn)}")
                lines.append(f"    secured: {'true' if cm.get('secured') else 'false'}")
                lines.append(f"    radio_menu_enabled: {'true' if cm.get('radio_menu_enabled', True) else 'false'}")
                if b := cm.get("briefing"):
                    # Indent multiline briefing as YAML literal block
                    b_lines = b.strip().splitlines()
                    lines.append("    briefing: |")
                    for bl in b_lines:
                        lines.append(f"      {bl}")
                if elems := cm.get("elements"):
                    lines.append("    elements:")
                    for elem in elems:
                        lines.append(f"      - name: {_yaml_str(elem.get('name', ''))}")
                        if gs := elem.get("groups"):
                            lines.append("        groups:")
                            for g in gs:
                                lines.append(f"          - {g}")
                        lines.append(f"        scalable: {'true' if elem.get('scalable', True) else 'false'}")
            lines.append("")

        # Pipeline section
        lines += [
            t("converter.yaml.header.pipeline"),
            t("converter.yaml.pipeline.desc1"),
            t("converter.yaml.pipeline.desc2"),
            f"# Doc: {_DOC_BASE}#build-profiles",
            "#",
        ]

        detected_steps = {pf.step: pf for pf in report.pipeline_files}
        pipeline_lines: list[str] = []
        for step, v6_candidates in V6_PIPELINE_CANDIDATES.items():
            if step in detected_steps:
                pf = detected_steps[step]
                if pf.needs_conversion:
                    pipeline_lines.append(
                        t(
                            "converter.yaml.pipeline.step_needs_conversion",
                            step=step,
                            file=str(pf.relative),
                            v6_target=pf.v6_target or "",
                        )
                    )
                else:
                    pipeline_lines.append(t("converter.yaml.pipeline.step_found", step=step, file=str(pf.relative)))
            else:
                pipeline_lines.append(t("converter.yaml.pipeline.step_missing", step=step, file=v6_candidates[0]))

        if pipeline_lines:
            lines.append("pipeline:")
            lines.extend(pipeline_lines)
        else:
            lines.append(t("converter.yaml.pipeline.empty"))

        # ── Build configuration ────────────────────────────────────────────
        lines += [
            "",
            t("converter.yaml.header.build"),
            t("converter.yaml.build.desc1"),
            t("converter.yaml.build.desc2"),
            "#",
            "# build:",
            "#   dev_mode: false         # true = resolve scripts from a local dev repo",
            "#   # scripts_path: null   # path to VEAF-Mission-Creation-Tools repo root (dev mode)",
            "#   dynamic_loading: false  # true = load scripts from disk at runtime (dev/test); profile-overridable",
        ]

        return "\n".join(lines) + "\n"

    def _build_manual_review(self, report: ConversionReport) -> None:
        """Populate ``report.manual_review`` with actionable items."""
        if report.missionconfig_backup:
            rel = report.missionconfig_backup.relative_to(report.mission_folder)
            report.manual_review.append(t("convert_v5.review.delete_backup", path=rel))
        # No "remove the commented doFile() lines" item: those lines live only in the
        # migrated buffer convert-v5 discards (the original missionConfig.lua is
        # deleted), so there is nothing on disk to edit (CONVERT-V5-INIT-COMMENTED-NOISE).
        if report.migration_result and report.migration_result.warnings:
            for w in report.migration_result.warnings:
                report.manual_review.append(f"missionConfig.lua — {w}")
        if report.mission_yaml_existed and not report.mission_yaml_generated:
            report.manual_review.append(t("convert_v5.review.yaml_not_overwritten"))
        for pf in report.pipeline_files:
            if pf.needs_conversion:
                _note_key = f"convert_v5.migration_note.{pf.step}"
                _note_raw = t(_note_key)
                if _note_raw == _note_key:
                    _note_raw = t("convert_v5.review.convert_pipeline_default")
                note = _note_raw.format(v5=pf.relative)
                _lk = f"pipeline.label.{pf.step}"
                label = t(_lk) if t(_lk) != _lk else pf.step
                report.manual_review.append(f"**{label}**: {note}")
