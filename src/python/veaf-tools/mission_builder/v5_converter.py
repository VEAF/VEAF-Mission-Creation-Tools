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

import re
import shutil
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml  # type: ignore[import-untyped]
from mission_tools.mission_constants import get_community_script_files
from veaf_libs.i18n import t
from veaf_libs.lua_config_generator import MANDATORY_MODULES, MODULE_CATEGORIES, yaml_module_entry, yaml_syntax_header
from veaf_libs.lua_module_scanner import get_modules

from mission_builder.config_migrator import ConfigMigrator, MigrationResult
from mission_builder.v5_pipeline_converters import convert_pipeline_file

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
    "aircraft_groups": ["src/aircraft-templates.yaml", "src/templates.yaml"],
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

DOC_BASE = "https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/doc"
DOC_LINKS: dict[str, str] = {
    "Mission Maker Guide": f"{DOC_BASE}/MISSION_MAKER_GUIDE.md",
    "Migration Guide": f"{DOC_BASE}/mission-maker/MIGRATION_GUIDE.md",
    "Tools Reference": f"{DOC_BASE}/TOOLS_REFERENCE.md",
}

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

    # ── Summary lists ──────────────────────────────────────────────────────
    actions: list[str] = field(default_factory=list)
    """High-level descriptions of actions taken (shown in the summary)."""
    warnings: list[str] = field(default_factory=list)
    """Non-fatal issues that deserve attention."""
    manual_review: list[str] = field(default_factory=list)
    """Items the user must review / clean up manually after testing."""
    backup_v5_sources: list[str] = field(default_factory=list)
    """Relative paths of v5 files/folders backed up under ``backup_v5/``."""
    missionconfig_annotated_content: str = ""
    """Annotated missionConfig.lua content (with [v6 ...] comments) — embedded in report."""

    # -----------------------------------------------------------------------
    # Report rendering
    # -----------------------------------------------------------------------

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

            if mr.removed_dofiles:
                lines += [
                    f"#### {t('report.missionconfig.dofiles_counted', n=len(mr.removed_dofiles))}",
                    "",
                    t("report.missionconfig.dofiles_intro"),
                    "",
                    f"| {t('report.missionconfig.dofiles_col.location')} | {t('report.missionconfig.dofiles_col.expression')} |",
                    "|----------|-----------|",
                ]
                for item in mr.removed_dofiles:
                    lines.append(f"| {item.split(':', 1)[0]} | `{item.split(':', 1)[1].strip()}` |")
                lines.append("")
            else:
                lines += [
                    f"#### {t('report.missionconfig.dofiles_none_title')}",
                    "",
                    f"*{t('report.missionconfig.dofiles_none_msg')}*",
                    "",
                ]

            if mr.wrapped_calls:
                lines += [
                    f"#### {t('report.missionconfig.wrapped_counted', n=len(mr.wrapped_calls))}",
                    "",
                    t("report.missionconfig.wrapped_intro"),
                    "",
                    f"| {t('report.missionconfig.dofiles_col.location')} | {t('report.missionconfig.dofiles_col.expression')} |",
                    "|----------|-----------|",
                ]
                for item in mr.wrapped_calls:
                    lines.append(f"| {item.split(':', 1)[0]} | `{item.split(':', 1)[1].strip()}` |")
                lines.append("")
            else:
                lines += [
                    f"#### {t('report.missionconfig.init_title')}",
                    "",
                    f"*{t('report.missionconfig.init_none')}*",
                    "",
                ]

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
                f"- `lua_modules:` \u2014 {t('report.mission_yaml.modules_count', enabled=enabled_count, disabled=disabled_count)}",
            ]
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

        # DCS triggers
        lines += [
            f"### 3. {t('report.section.triggers')}",
            "",
            t("report.triggers.auto"),
            "",
            "---",
            "",
        ]

        # ── Annotated missionConfig.lua ───────────────────────────────────────
        if self.missionconfig_annotated_content:
            lines += [
                f"## {t('report.section.annotated_config')}",
                "",
                t("report.annotated_config.intro"),
                "",
                "~~~~lua",
                self.missionconfig_annotated_content,
                "~~~~",
                "",
                "---",
                "",
            ]

        # ── Manual review ─────────────────────────────────────────────────
        lines += [f"## {t('report.section.review')}", ""]

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
        if self.migration_result and self.migration_result.removed_dofiles:
            cleanup_items.append(t("report.cleanup.remove_dofiles"))
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


def _yaml_list_block(items: list[Any], indent: int = 4) -> list[str]:
    """Serialize a list of dicts to YAML lines at the given indent level."""
    raw = yaml.dump(items, default_flow_style=False, allow_unicode=True, sort_keys=False, indent=2).rstrip("\n")
    prefix = " " * indent
    return [f"{prefix}{line}" for line in raw.splitlines()]


def _yaml_dict_block(data: dict, indent: int = 6) -> list[str]:
    """Serialize a flat dict to YAML key: value lines at the given indent level."""
    raw = yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False, indent=2).rstrip("\n")
    prefix = " " * indent
    return [f"{prefix}{line}" for line in raw.splitlines()]


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

        for step, v6_candidates in V6_PIPELINE_CANDIDATES.items():
            # Check v6-format files first (already converted or freshly created)
            for rel in v6_candidates:
                p = folder / rel
                if p.exists():
                    report.pipeline_files.append(PipelineFile(step=step, path=p, relative=rel))
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
        annotated_content = result.new_content

        mission_folder = report.mission_folder

        # Place original .bak and annotated version under backup_v5/
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

            # Store the annotated content in the report (embedded in the Markdown).
            # We do NOT write it as a separate file in backup_v5/ to avoid confusion
            # with the .bak file that is the authoritative rollback reference.
            report.missionconfig_annotated_content = annotated_content
            report.actions.append(t("convert_v5.action.missionconfig_annotated"))

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
                    "The annotated version of missionConfig.lua (with [v6 ...] comments showing\n"
                    "what each line was migrated into) is embedded in the conversion report:\n"
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
        report.actions.append(t("convert_v5.action.mission_script_generated"))

        if not result.removed_dofiles and not result.wrapped_calls:
            report.actions.append(t("convert_v5.action.already_v6"))
        if result.removed_dofiles:
            report.actions.append(t("convert_v5.action.dofiles_commented", n=len(result.removed_dofiles)))
        if result.wrapped_calls:
            report.actions.append(t("convert_v5.action.init_wrapped", n=len(result.wrapped_calls)))
        if result.enabled_modules:
            report.actions.append(
                t(
                    "convert_v5.action.modules_detected",
                    n=len(result.enabled_modules),
                    list=", ".join(result.enabled_modules),
                )
            )
        for w in result.warnings:
            report.warnings.append(f"missionConfig.lua: {w}")

        # Report extracted YAML data
        mr = result
        if mr.mission_name or mr.mission_era or mr.mission_export_path is not None:
            report.actions.append(t("convert_v5.action.identity_extracted"))
        if mr.assets_extracted:
            report.actions.append(t("convert_v5.action.assets_extracted", n=len(mr.assets_extracted)))
        if mr.qra_definitions:
            report.actions.append(t("convert_v5.action.qra_extracted", n=len(mr.qra_definitions)))
        if mr.cap_missions_extracted:
            report.actions.append(t("convert_v5.action.cap_extracted", n=len(mr.cap_missions_extracted)))
        if mr.combat_missions_extracted:
            report.actions.append(t("convert_v5.action.combat_extracted", n=len(mr.combat_missions_extracted)))

    def _generate_mission_yaml(self, report: ConversionReport, overwrite: bool) -> None:
        """Build and write mission.yaml."""
        dest = report.mission_folder / "mission.yaml"

        if dest.exists() and not overwrite:
            report.mission_yaml_skipped_reason = t("convert_v5.action.yaml_skip_reason")
            report.actions.append(t("convert_v5.action.yaml_exists"))
            return

        content = self._build_mission_yaml(report)
        dest.write_text(content, encoding="utf-8")
        report.mission_yaml_generated = True
        report.mission_yaml_path = dest

        enabled_count = len(report.migration_result.enabled_modules) if report.migration_result else 0
        all_count = len(get_modules())
        v6_ready = sum(1 for pf in report.pipeline_files if not pf.needs_conversion)
        v5_detected = sum(1 for pf in report.pipeline_files if pf.needs_conversion)
        pipeline_note = t("convert_v5.action.pipeline_steps_ready", n=v6_ready)
        if v5_detected:
            pipeline_note += f", {t('convert_v5.action.pipeline_steps_v5', n=v5_detected)}"
        report.actions.append(
            t("convert_v5.action.yaml_generated", enabled=enabled_count, total=all_count, pipeline=pipeline_note)
        )

    def _build_mission_yaml(self, report: ConversionReport) -> str:
        """Produce the full mission.yaml content (with explanatory comments)."""
        import re as _re  # noqa: PLC0415 (avoid shadowing outer re)

        folder_name = report.mission_folder.name
        now = report.timestamp
        mr: MigrationResult | None = report.migration_result

        _DOC_BASE = "https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/doc/mission-maker/GUIDE.en.md"

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
        if mr and (mr.mission_name or mr.mission_era or mr.mission_export_path is not None):
            lines.append(t("converter.yaml.header.identity"))
            lines.append("mission:")
            if mr.mission_name:
                lines.append(f"  name: {_yaml_str(mr.mission_name)}")
            if mr.mission_era:
                lines.append(f"  era: {mr.mission_era}")
            if mr.mission_export_path is not None:
                ep_yaml = "null" if mr.mission_export_path is None else _yaml_str(str(mr.mission_export_path))
                lines.append(f"  export_path: {ep_yaml}")
            lines.append("")

        # ── Security ──────────────────────────────────────────────────────
        if mr and (mr.security_disabled is not None or mr.password_mm_hashes):
            lines.append(t("converter.yaml.header.security"))
            lines.append("security:")
            if mr.security_disabled is not None:
                lines.append(f"  disabled: {'true' if mr.security_disabled else 'false'}")
            if mr.password_mm_hashes:
                lines.append("  password_mm_hashes:")
                for h in mr.password_mm_hashes:
                    lines.append(f"    - {_yaml_str(h)}")
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
        all_mods = get_modules()

        # Modules explicitly enabled (from missionConfig.lua or always-on base set)
        enabled_by_id = {m["id"] for m in all_mods if m["id"] in enabled_set}

        # Emit modules grouped by category in declaration order
        for category, cat_mods in MODULE_CATEGORIES.items():
            cat_enabled = [mid for mid in cat_mods if mid in enabled_by_id]
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
        if all_community:
            lines.append(t("converter.yaml.community.header"))
            lines.append(t("converter.yaml.community.desc"))
            for script in all_community:
                sid = script["id"]
                val = "true" if sid in detected_comm else "false"
                lines.append(f"  {sid.upper()}: {val}")
        lines.append("")

        # ── External modules (Skynet) ──────────────────────────────────────
        if mr and mr.skynet_config:
            sc = mr.skynet_config
            lines.append(t("converter.yaml.header.external"))
            lines.append(t("converter.yaml.external.desc"))
            lines.append(f"# Doc: {_DOC_BASE}#ctld-and-csar-integration")
            lines.append("external_modules:")
            lines.append("  skynet:")
            lines.append("    enabled: true")
            lines.append(f"    include_red_in_radio: {'true' if sc.get('include_red_in_radio') else 'false'}")
            lines.append(f"    debug_red: {'true' if sc.get('debug_red') else 'false'}")
            lines.append(f"    include_blue_in_radio: {'true' if sc.get('include_blue_in_radio') else 'false'}")
            lines.append(f"    debug_blue: {'true' if sc.get('debug_blue') else 'false'}")
            lines.append("")

        # ── QRA ───────────────────────────────────────────────────────────
        if mr and mr.qra_definitions:
            lines.append(t("converter.yaml.header.qra"))
            lines.append(f"# Doc: {_DOC_BASE}#configuration-examples")
            lines.append("qra:")
            if mr.qra_silence_all is not None:
                lines.append(f"  silence_all: {'true' if mr.qra_silence_all else 'false'}")
            else:
                lines.append("  silence_all: false")
            lines.append("  definitions:")
            for qra in mr.qra_definitions:
                name = qra.get("name", "QRA")
                lines.append(f"    - name: {_yaml_str(name)}")
                if coalition := qra.get("coalition"):
                    lines.append(f"      coalition: {coalition}")
                if enemies := qra.get("enemy_coalitions"):
                    lines.append("      enemy_coalitions:")
                    for e in enemies:
                        lines.append(f"        - {e}")
                if tz := qra.get("trigger_zone"):
                    lines.append(f"      trigger_zone: {tz}")
                if zr := qra.get("zone_radius"):
                    lines.append(f"      zone_radius: {zr}")
                if sg := qra.get("simple_groups"):
                    lines.append("      simple_groups:")
                    for g in sg:
                        lines.append(f"        - {g}")
                if gbc := qra.get("groups_by_enemy_count"):
                    lines.append("      groups_by_enemy_count:")
                    for entry in gbc:
                        lines.append(f"        - enemy_count: {entry['enemy_count']}")
                        groups = entry.get("groups", [])
                        if groups:
                            lines.append("          groups:")
                            for g in groups:
                                lines.append(f"            - {g}")
                        lines.append(f"          random_pick: {entry.get('random_pick', 1)}")
                if dbr := qra.get("delay_before_rearming"):
                    lines.append(f"      delay_before_rearming: {dbr}")
                if dba := qra.get("delay_before_activating"):
                    lines.append(f"      delay_before_activating: {dba}")
                if qra.get("react_on_helicopters"):
                    lines.append("      react_on_helicopters: true")
                if al := qra.get("airport_link"):
                    lines.append(f"      airport_link: {_yaml_str(al)}")
                if not qra.get("start", True):
                    lines.append(t("converter.yaml.qra.start_comment"))
            lines.append("")

        # ── CAP missions ──────────────────────────────────────────────────
        if mr and mr.cap_missions_extracted:
            lines.append(t("converter.yaml.header.cap"))
            lines.append(f"# Doc: {_DOC_BASE}#configuration-examples")
            lines.append("cap_missions:")
            for cap in mr.cap_missions_extracted:
                lines.append(f"  - group_name: {_yaml_str(cap.get('group_name', ''))}")
                lines.append(f"    menu_name: {_yaml_str(cap.get('menu_name', ''))}")
                lines.append(f"    briefing: {_yaml_str(cap.get('briefing', ''))}")
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
        ]

        return "\n".join(lines) + "\n"

    def _build_manual_review(self, report: ConversionReport) -> None:
        """Populate ``report.manual_review`` with actionable items."""
        if report.missionconfig_backup:
            rel = report.missionconfig_backup.relative_to(report.mission_folder)
            report.manual_review.append(t("convert_v5.review.delete_backup", path=rel))
        if report.migration_result and report.migration_result.removed_dofiles:
            report.manual_review.append(t("convert_v5.review.remove_dofiles"))
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
