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

import shutil
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from veaf_libs.i18n import t
from veaf_libs.lua_module_scanner import get_modules

from mission_builder.config_migrator import ConfigMigrator, MigrationResult
from mission_builder.v5_pipeline_converters import convert_pipeline_file

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: Default location of missionConfig.lua relative to the mission folder (v5 name — still searched for detection).
MISSIONCONFIG_DEFAULT = Path("src") / "scripts" / "missionConfig.lua"

#: Candidate paths searched in order (relative to mission folder).
#: mission-script.lua first (already-migrated missions), then v5 names.
MISSIONCONFIG_CANDIDATES: list[Path] = [
    Path("src") / "scripts" / "mission-script.lua",
    MISSIONCONFIG_DEFAULT,
    Path("src") / "missionConfig.lua",
    Path("missionConfig.lua"),
]

#: v6 pipeline file paths (what the v6 injectors expect to find).
V6_PIPELINE_CANDIDATES: dict[str, list[str]] = {
    "presets": ["src/presets.yaml"],
    "waypoints": ["src/waypoints.yaml"],
    "aircraft_groups": ["src/aircraft-templates.yaml", "src/templates.yaml"],
    "weather": ["src/missions.yaml", "src/versions.yaml"],
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
V5_MIGRATION_NOTES: dict[str, str] = {
    "presets": (
        "Convert `{v5}` to v6 YAML (`src/presets.yaml`). "
        "The v6 schema uses `radios_collection:` / `presets_collection:` / `presets_assignments:` "
        "instead of the flat v5 `presets_definition:` / `coalitions:` structure."
    ),
    "waypoints": (
        "Convert `{v5}` to v6 YAML (`src/waypoints.yaml`). "
        "The overall structure (`waypoints:` + `settings:`) is similar but some field names changed."
    ),
    "aircraft_groups": (
        "Convert `{v5}` to v6 YAML (`src/templates.yaml`). "
        "The v6 schema uses `airplanes:` / `helicopters:` top-level keys with a flattened "
        "`coalitions > country > group` structure instead of "
        "`settings.categories.plane.coalitions.countries.groups`."
    ),
    "weather": (
        "Convert `{v5}` to v6 YAML (`src/versions.yaml`). Key renames: "
        "`lat/lon/tz` → `latitude/longitude/timezone`, "
        "`targets` → `versions`, `version` → `name`, "
        "`realweather: true` → `airport_icao: <ICAO>`, "
        "`weatherfile: x.lua` → inline `weather:` block."
    ),
}

#: Backward-compatible alias — exported public symbol.
PIPELINE_CANDIDATES = V6_PIPELINE_CANDIDATES

#: Human-readable labels for each pipeline step.
PIPELINE_LABELS: dict[str, str] = {
    "presets": "Radio presets",
    "waypoints": "Waypoints",
    "aircraft_groups": "Aircraft groups",
    "weather": "Weather variants",
}

DOC_BASE = "https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/doc"
DOC_LINKS: dict[str, str] = {
    "Mission Maker Guide": f"{DOC_BASE}/MISSION_MAKER_GUIDE.md",
    "Migration Guide": f"{DOC_BASE}/mission-maker/MIGRATION_GUIDE.md",
    "Tools Reference": f"{DOC_BASE}/TOOLS_REFERENCE.md",
}

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
            "## Scan Results",
            "",
            "| Item | Status |",
            "|------|--------|",
        ]
        if self.missionconfig_path:
            rel = self.missionconfig_path.relative_to(self.mission_folder)
            lines.append(f"| `{rel}` | ✅ Found — migrated |")
        else:
            lines.append("| `src/scripts/missionConfig.lua` | ❌ Not found — skipped |")

        if self.mission_yaml_existed:
            lines.append("| `mission.yaml` | ⚠️ Already existed — not overwritten |")
        elif self.mission_yaml_generated:
            lines.append("| `mission.yaml` | ✅ Generated |")
        else:
            lines.append("| `mission.yaml` | ❌ Not generated |")

        detected_steps = {pf.step for pf in self.pipeline_files}
        for step, candidates in PIPELINE_CANDIDATES.items():
            if step in detected_steps:
                pf = next(pf for pf in self.pipeline_files if pf.step == step)
                if pf.converted:
                    lines.append(f"| `{pf.v5_source}` \u2192 `{pf.relative}` | \u2705 Converted from v5 (backed up) |")
                else:
                    lines.append(f"| `{pf.relative}` | \u2705 Found \u2014 added to `pipeline:` |")
            else:
                lines.append(f"| `{candidates[0]}` | ❌ Not found — `{step}` step will be skipped |")
        lines += ["", "---", ""]

        # ── Actions taken ─────────────────────────────────────────────────
        lines += [f"## {t('report.section.actions')}", ""]

        # missionConfig.lua
        if self.migration_result is not None:
            mr = self.migration_result
            if self.missionconfig_backup:
                rel_bak = self.missionconfig_backup.relative_to(self.mission_folder)
                lines.append(f"### 1. missionConfig.lua — Migrated (backup: `{rel_bak}`)")
            else:
                lines.append("### 1. missionConfig.lua — Migrated")
            lines.append("")

            if mr.removed_dofiles:
                lines += [
                    f"#### `doFile()` calls commented out ({len(mr.removed_dofiles)})",
                    "",
                    "In v6 the builder injects all VEAF scripts automatically via `veaf-scripts.lua`.",
                    "Explicit `doFile(...)` calls are no longer needed. They have been commented out",
                    "with a `-- [v6 migration]` prefix — verify them before deleting permanently.",
                    "",
                    "| Location | Expression |",
                    "|----------|-----------|",
                ]
                for item in mr.removed_dofiles:
                    lines.append(f"| {item.split(':', 1)[0]} | `{item.split(':', 1)[1].strip()}` |")
                lines.append("")
            else:
                lines += [
                    "#### `doFile()` calls",
                    "",
                    "*None found — file may already be v6-compatible in this regard.*",
                    "",
                ]

            if mr.wrapped_calls:
                lines += [
                    f"#### Bare `initialize()` calls wrapped ({len(mr.wrapped_calls)})",
                    "",
                    "In v6 all module calls must be wrapped in `if veafXxx then … end` guards.",
                    "The following bare calls were wrapped automatically:",
                    "",
                    "| Location | Expression |",
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
                    f"#### Enabled modules detected ({len(mr.enabled_modules)})",
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
                f"*{self.mission_yaml_skipped_reason or 'Unknown reason.'}*",
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
            report.warnings.append(f"Could not resolve backup path for {source} — v5 source not cleaned up")
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
            report.actions.append(f"v5 source backed up to backup_v5/{rel_str} and deleted")
        except Exception as exc:
            report.warnings.append(f"Could not back up/delete {rel}: {exc}")

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
                    report.warnings.append(f"{PIPELINE_LABELS.get(pf.step, pf.step)}: {w}")
                report.actions.append(f"{PIPELINE_LABELS.get(pf.step, pf.step)}: converted to {pf.v6_target}")
                self._backup_and_delete_v5(pf.step, v5_abs_path, report)
            except Exception as exc:
                report.warnings.append(
                    f"{PIPELINE_LABELS.get(pf.step, pf.step)}: conversion failed — {exc}. "
                    "Convert manually (see migration guide)."
                )

    def _scan(self, report: ConversionReport) -> None:
        """Detect missionConfig.lua, existing mission.yaml, and pipeline files."""
        folder = report.mission_folder

        for candidate in MISSIONCONFIG_CANDIDATES:
            p = folder / candidate
            if p.exists():
                report.missionconfig_path = p
                break

        report.mission_yaml_existed = (folder / "mission.yaml").exists()

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

        If the source file is named ``missionConfig.lua``, the migrated content
        is written to ``mission-script.lua`` (the v6 name) and the original is
        backed up / removed.
        """
        src = report.missionconfig_path
        assert src is not None

        content = src.read_text(encoding="utf-8")
        result = self._migrator.migrate(content)
        report.migration_result = result

        # Determine output path: rename missionConfig.lua → mission-script.lua
        if src.name == "missionConfig.lua":
            dest = src.parent / "mission-script.lua"
        else:
            dest = src

        # Backup before overwriting
        if backup:
            bak = src.with_suffix(".lua.bak")
            if not bak.exists():
                shutil.copy2(src, bak)
                report.missionconfig_backup = bak
                report.actions.append(f"missionConfig.lua: backup created → {bak.name}")

        # Write migrated content to destination
        dest.write_text(result.new_content, encoding="utf-8")
        report.missionconfig_output = dest

        # Remove original if renamed
        if dest != src:
            src.unlink()
            report.actions.append(f"missionConfig.lua → renamed to {dest.name}")

        if not result.removed_dofiles and not result.wrapped_calls:
            report.actions.append(
                "missionConfig.lua: no v5 patterns found (no doFile calls, no bare initialize calls)"
                " — file appears already v6-compatible"
            )
        if result.removed_dofiles:
            report.actions.append(f"missionConfig.lua: {len(result.removed_dofiles)} doFile() call(s) commented out")
        if result.wrapped_calls:
            report.actions.append(
                f"missionConfig.lua: {len(result.wrapped_calls)} bare initialize() call(s) wrapped in guards"
            )
        if result.enabled_modules:
            report.actions.append(
                f"missionConfig.lua: {len(result.enabled_modules)} enabled module(s) detected: "
                + ", ".join(result.enabled_modules)
            )
        for w in result.warnings:
            report.warnings.append(f"missionConfig.lua: {w}")

        # Report extracted YAML data
        mr = result
        if mr.mission_name or mr.mission_era or mr.mission_export_path is not None:
            report.actions.append("mission.yaml: mission identity extracted from missionConfig.lua")
        if mr.assets_extracted:
            report.actions.append(f"mission.yaml: {len(mr.assets_extracted)} asset(s) extracted")
        if mr.qra_definitions:
            report.actions.append(f"mission.yaml: {len(mr.qra_definitions)} QRA definition(s) extracted")
        if mr.cap_missions_extracted:
            report.actions.append(f"mission.yaml: {len(mr.cap_missions_extracted)} CAP mission(s) extracted")
        if mr.combat_missions_extracted:
            report.actions.append(f"mission.yaml: {len(mr.combat_missions_extracted)} combat mission(s) extracted")

    def _generate_mission_yaml(self, report: ConversionReport, overwrite: bool) -> None:
        """Build and write mission.yaml."""
        dest = report.mission_folder / "mission.yaml"

        if dest.exists() and not overwrite:
            report.mission_yaml_skipped_reason = "mission.yaml already exists — use --force to overwrite"
            report.actions.append("mission.yaml: already exists — skipped (pass --force to overwrite)")
            return

        content = self._build_mission_yaml(report)
        dest.write_text(content, encoding="utf-8")
        report.mission_yaml_generated = True
        report.mission_yaml_path = dest

        enabled_count = len(report.migration_result.enabled_modules) if report.migration_result else 0
        all_count = len(get_modules())
        v6_ready = sum(1 for pf in report.pipeline_files if not pf.needs_conversion)
        v5_detected = sum(1 for pf in report.pipeline_files if pf.needs_conversion)
        pipeline_note = f"{v6_ready} pipeline step(s) ready"
        if v5_detected:
            pipeline_note += f", {v5_detected} step(s) detected in v5 format (need conversion)"
        report.actions.append(f"mission.yaml: generated — {enabled_count}/{all_count} modules enabled, {pipeline_note}")

    def _build_mission_yaml(self, report: ConversionReport) -> str:
        """Produce the full mission.yaml content (with explanatory comments)."""
        import re as _re  # noqa: PLC0415 (avoid shadowing outer re)

        folder_name = report.mission_folder.name
        now = report.timestamp
        mr: MigrationResult | None = report.migration_result

        lines: list[str] = [
            f"# mission.yaml — generated by veaf-tools convert-v5 on {now}",
            f"# Source mission folder: {folder_name}",
            "#",
            "# Place this file at the root of your mission folder (next to veaf-tools-updater.exe).",
            "# If absent, veaf-tools build works with default settings.",
            "#",
            "# See: https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/doc/MISSION_MAKER_GUIDE.md",
            "",
        ]

        # ── Global log level ──────────────────────────────────────────────
        extracted_ll = mr.global_log_level_extracted if mr else None
        lines += [
            "# ── Global log level ─────────────────────────────────────────────────────────",
            "# Forces veaf.ForcedLogLevel in the built mission. Applies to every module.",
            "# Values: error | warning | info | debug | trace",
            "# Remove or set to 'info' before deploying to players.",
            "#",
            f"global_log_level: {extracted_ll or 'debug'}",
            "",
        ]

        # ── Mission identity ───────────────────────────────────────────────
        if mr and (mr.mission_name or mr.mission_era or mr.mission_export_path is not None):
            lines.append("# ── Mission identity ──────────────────────────────────────────────────────────")
            lines.append("mission:")
            if mr.mission_name:
                lines.append(f'  name: "{mr.mission_name}"')
            if mr.mission_era:
                lines.append(f"  era: {mr.mission_era}")
            if mr.mission_export_path is not None:
                ep_yaml = "null" if mr.mission_export_path is None else f'"{mr.mission_export_path}"'
                lines.append(f"  export_path: {ep_yaml}")
            lines.append("")

        # ── Security ──────────────────────────────────────────────────────
        if mr and mr.security_disabled is not None:
            lines.append("# ── Security ──────────────────────────────────────────────────────────────────")
            lines.append("security:")
            lines.append(f"  disabled: {'true' if mr.security_disabled else 'false'}")
            lines.append("")

        # ── Module configuration ───────────────────────────────────────────
        # Base infrastructure modules that must always be explicitly enabled.
        # Without them in lua_modules, their initialize() would not be called.
        _BASE_ALWAYS_ON: frozenset[str] = frozenset({"AIRBASES", "MARKERS", "TIME", "UNITS", "EVENTS - ", "CACHE - "})

        lines += [
            "# ── Module configuration ─────────────────────────────────────────────────────",
            "# Enable or disable individual VEAF Lua modules.",
            "# Only modules listed here will have their initialize() called by the builder.",
            "# To disable a module, set enable: false instead of removing it.",
            "#",
            "lua_modules:",
        ]

        enabled_modules = mr.enabled_modules if mr else []
        enabled_set = set(enabled_modules) | _BASE_ALWAYS_ON
        all_mods = get_modules()

        # Modules explicitly enabled (from missionConfig.lua or always-on base set)
        enabled_found = [m["id"] for m in all_mods if m["id"] in enabled_set]

        if enabled_found:
            lines.append("  # ── Active modules ──────────────────────────────────────────────────────────")
            for mid in enabled_found:
                yaml_key = f'"{mid}"' if not _re.match(r"^[A-Za-z_]\w*$", mid) else mid
                lines.append(f"  {yaml_key}:")
                lines.append("    enable: true")
                # For ASSETS, inject the extracted asset list directly under the module entry
                if mid == "ASSETS" and mr and mr.assets_extracted:
                    lines.append("    assets:")
                    _ASSET_STR_KEYS = (
                        "name",
                        "description",
                        "information",
                        "jtac",
                        "freq",
                        "linked",
                        "mod",
                    )
                    for asset in mr.assets_extracted:
                        first = True
                        for k, v in asset.items():
                            prefix = "    - " if first else "      "
                            first = False
                            if isinstance(v, bool):
                                lines.append(f"{prefix}{k}: {'true' if v else 'false'}")
                            elif isinstance(v, str):
                                lines.append(f'{prefix}{k}: "{v}"')
                            else:
                                lines.append(f"{prefix}{k}: {v}")

        lines.append("")

        # ── External modules (Skynet) ──────────────────────────────────────
        if mr and mr.skynet_config:
            sc = mr.skynet_config
            lines.append("# ── External modules ─────────────────────────────────────────────────────────")
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
            lines.append("# ── QRA definitions (extracted from missionConfig.lua) ───────────────────────")
            lines.append("qra:")
            if mr.qra_silence_all is not None:
                lines.append(f"  silence_all: {'true' if mr.qra_silence_all else 'false'}")
            else:
                lines.append("  silence_all: false")
            lines.append("  definitions:")
            for qra in mr.qra_definitions:
                name = qra.get("name", "QRA")
                lines.append(f'    - name: "{name}"')
                if coalition := qra.get("coalition"):
                    lines.append(f"      coalition: {coalition}")
                if enemies := qra.get("enemy_coalitions"):
                    lines.append(f"      enemy_coalitions: [{', '.join(enemies)}]")
                if tz := qra.get("trigger_zone"):
                    lines.append(f'      trigger_zone: "{tz}"')
                if zr := qra.get("zone_radius"):
                    lines.append(f"      zone_radius: {zr}")
                if sg := qra.get("simple_groups"):
                    lines.append(f"      simple_groups: [{', '.join(repr(g) for g in sg)}]")
                if gbc := qra.get("groups_by_enemy_count"):
                    lines.append("      groups_by_enemy_count:")
                    for entry in gbc:
                        lines.append(f"        - enemy_count: {entry['enemy_count']}")
                        gs = ", ".join(f'"{g}"' for g in entry.get("groups", []))
                        lines.append(f"          groups: [{gs}]")
                        lines.append(f"          random_pick: {entry.get('random_pick', 1)}")
                if dbr := qra.get("delay_before_rearming"):
                    lines.append(f"      delay_before_rearming: {dbr}")
                if dba := qra.get("delay_before_activating"):
                    lines.append(f"      delay_before_activating: {dba}")
                if qra.get("react_on_helicopters"):
                    lines.append("      react_on_helicopters: true")
                if al := qra.get("airport_link"):
                    lines.append(f'      airport_link: "{al}"')
            lines.append("")

        # ── CAP missions ──────────────────────────────────────────────────
        if mr and mr.cap_missions_extracted:
            lines.append("# ── CAP missions (extracted from missionConfig.lua) ──────────────────────────")
            lines.append("cap_missions:")
            for cap in mr.cap_missions_extracted:
                lines.append(f'  - group_name: "{cap.get("group_name", "")}"')
                lines.append(f'    menu_name: "{cap.get("menu_name", "")}"')
                lines.append(f'    briefing: "{cap.get("briefing", "")}"')
                lines.append(f"    default: {'true' if cap.get('default') else 'false'}")
                lines.append(f"    activated: {'true' if cap.get('activated', True) else 'false'}")
            lines.append("")

        # ── Combat missions ───────────────────────────────────────────────
        if mr and mr.combat_missions_extracted:
            lines.append("# ── Combat missions (extracted from missionConfig.lua) ───────────────────────")
            lines.append("combat_missions:")
            for cm in mr.combat_missions_extracted:
                lines.append(f'  - name: "{cm.get("name", "")}"')
                if fn := cm.get("friendly_name"):
                    lines.append(f'    friendly_name: "{fn}"')
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
                        lines.append(f'      - name: "{elem.get("name", "")}"')
                        if gs := elem.get("groups"):
                            gs_yaml = ", ".join(f'"{g}"' for g in gs)
                            lines.append(f"        groups: [{gs_yaml}]")
                        lines.append(f"        scalable: {'true' if elem.get('scalable', True) else 'false'}")
            lines.append("")

        # Pipeline section
        lines += [
            "# ── Build pipeline ────────────────────────────────────────────────────────────",
            "# Controls which optional injection steps run after the base build.",
            "# Auto-detected from src/ — set a step to false to disable it even if its file exists.",
            "#",
        ]

        detected_steps = {pf.step: pf for pf in report.pipeline_files}
        pipeline_lines: list[str] = []
        for step, v6_candidates in V6_PIPELINE_CANDIDATES.items():
            if step in detected_steps:
                pf = detected_steps[step]
                if pf.needs_conversion:
                    pipeline_lines.append(
                        f"  # {step}: false"
                        f"  # {pf.relative} is v5 format — convert to {pf.v6_target} first (see migration guide)"
                    )
                else:
                    pipeline_lines.append(f"  {step}: true  # {pf.relative} detected")
            else:
                pipeline_lines.append(f"  # {step}: false  # {v6_candidates[0]} not found")

        if pipeline_lines:
            lines.append("pipeline:")
            lines.extend(pipeline_lines)
        else:
            lines.append("# pipeline: {}  # no pipeline config files detected in src/")

        # ── Build configuration ────────────────────────────────────────────
        lines += [
            "",
            "# ── Build configuration ─────────────────────────────────────────────────────",
            "# Persisted build settings — set via --dev-mode / --scripts-path CLI flags.",
            "# Note: scripts_path is usually machine-specific.",
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
            report.manual_review.append(f"Delete `{rel}` once you have verified the migrated missionConfig.lua.")
        if report.migration_result and report.migration_result.removed_dofiles:
            report.manual_review.append(
                "Remove the commented-out `doFile()` lines from `missionConfig.lua` "
                "(search for `-- [v6 migration]` and delete those lines once verified)."
            )
        if report.migration_result and report.migration_result.warnings:
            for w in report.migration_result.warnings:
                report.manual_review.append(f"missionConfig.lua — {w}")
        if report.mission_yaml_existed and not report.mission_yaml_generated:
            report.manual_review.append(
                "Your existing `mission.yaml` was NOT overwritten. "
                "Manually add/merge the `lua_modules:` and `pipeline:` sections shown in the report."
            )
        for pf in report.pipeline_files:
            if pf.needs_conversion:
                note_template = V5_MIGRATION_NOTES.get(pf.step, "Convert `{v5}` to v6 format (see migration guide).")
                note = note_template.format(v5=pf.relative)
                label = PIPELINE_LABELS.get(pf.step, pf.step)
                report.manual_review.append(f"**{label}**: {note}")
