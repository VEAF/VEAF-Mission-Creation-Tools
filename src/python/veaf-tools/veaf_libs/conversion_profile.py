"""Conversion profiles — declarative data for adopting a third-party mission.

A *conversion profile* carries the author-specific knowledge that `convert-other`
needs for a given third-party mission family (e.g. Foothold): which VEAF modules
to enable, which are incompatible, which VEAF community scripts to disable (the
mission ships its own), how to normalise versioned script names, and a
``config_override`` scaffold. The profile is data; the code reading it is generic.
See ADR 0007.

Profiles ship as bundled defaults under ``veaf_libs/data/convert-profiles/`` and
can be overridden by passing a filesystem path instead of a name.
"""

from __future__ import annotations

import fnmatch
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from veaf_libs.bundled_data import read_bundled_text

_PROFILE_DATA_PARTS = ("data", "convert-profiles")


@dataclass(frozen=True)
class NameRule:
    """A versioned-name normalisation rule: glob *pattern* → fixed *replacement*."""

    pattern: str
    replacement: str


@dataclass(frozen=True)
class ConfigOverrideSpec:
    """The ``config_override`` scaffold: which upstream file, which default settings."""

    target: str
    defaults: dict[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class ConversionProfile:
    """Parsed conversion profile (see module docstring)."""

    name: str
    description: str = ""
    modules: tuple[str, ...] = ()
    incompatible_modules: tuple[str, ...] = ()
    disabled_community_scripts: tuple[str, ...] = ()
    name_rules: tuple[NameRule, ...] = ()
    config_override: ConfigOverrideSpec | None = None

    def normalize_script_name(self, filename: str) -> str:
        """Return *filename* normalised by the first matching name rule, else unchanged.

        Args:
            filename: A script filename (e.g. ``"Moose_2026-04-28.lua"``).

        Returns:
            The normalised name (e.g. ``"Moose.lua"``), or *filename* if no rule matches.
        """
        for rule in self.name_rules:
            if fnmatch.fnmatch(filename, rule.pattern):
                return rule.replacement
        return filename


def _parse_profile(raw: dict, name_hint: str) -> ConversionProfile:
    """Build a :class:`ConversionProfile` from a parsed YAML mapping."""
    co_raw = raw.get("config_override")
    config_override = (
        ConfigOverrideSpec(target=str(co_raw["target"]), defaults=dict(co_raw.get("defaults") or {}))
        if isinstance(co_raw, dict) and co_raw.get("target")
        else None
    )
    return ConversionProfile(
        name=str(raw.get("name", name_hint)),
        description=str(raw.get("description", "")),
        modules=tuple(raw.get("modules") or ()),
        incompatible_modules=tuple(raw.get("incompatible_modules") or ()),
        disabled_community_scripts=tuple(raw.get("disabled_community_scripts") or ()),
        name_rules=tuple(
            NameRule(pattern=str(r["pattern"]), replacement=str(r["replacement"]))
            for r in (raw.get("name_normalization") or [])
        ),
        config_override=config_override,
    )


def load_profile(name_or_path: str) -> ConversionProfile:
    """Load a conversion profile by bundled name or by filesystem path.

    Args:
        name_or_path: A bundled profile name (e.g. ``"foothold"``) or a path to a
            ``.yaml`` profile file (overrides the bundled defaults).

    Returns:
        The parsed profile.

    Raises:
        FileNotFoundError: if neither a bundled profile of that name nor the given
            path exists.
    """
    candidate = Path(name_or_path)
    if candidate.suffix.lower() in (".yaml", ".yml") or candidate.exists():
        if not candidate.is_file():
            raise FileNotFoundError(f"conversion profile not found: {candidate}")
        raw = yaml.safe_load(candidate.read_text(encoding="utf-8")) or {}
        return _parse_profile(raw, candidate.stem)

    try:
        text = read_bundled_text("veaf_libs", *_PROFILE_DATA_PARTS, f"{name_or_path}.yaml")
    except (FileNotFoundError, ModuleNotFoundError) as exc:
        raise FileNotFoundError(f"unknown conversion profile: {name_or_path}") from exc
    return _parse_profile(yaml.safe_load(text) or {}, name_or_path)


def _module_enabled(modules_block: dict, module_id: str) -> bool:
    """Whether *module_id* is enabled in a ``modules:`` mapping.

    A module is enabled when its value is ``True`` or a mapping that is not
    explicitly ``enabled: false`` (the unified community-script config form).
    """
    value = modules_block.get(module_id)
    if value is True:
        return True
    if isinstance(value, dict):
        return value.get("enabled", True) is not False
    return False


def incompatible_modules_enabled(yaml_data: dict) -> list[str]:
    """Return the profile-incompatible modules currently enabled in *yaml_data*.

    Reads the ``conversion_profile`` marker; if present and resolvable, returns the
    ids from the profile's ``incompatible_modules`` that are enabled in the
    ``modules:`` block. Empty when there is no profile, it is unknown, or none of
    its incompatibilities are enabled.

    Args:
        yaml_data: The parsed ``mission.yaml`` mapping.

    Returns:
        The enabled-yet-incompatible module ids (empty if none/unknown).
    """
    profile_name = yaml_data.get("conversion_profile")
    if not profile_name:
        return []
    try:
        profile = load_profile(str(profile_name))
    except FileNotFoundError:
        return []
    modules_block = yaml_data.get("modules") or {}
    if not isinstance(modules_block, dict):
        return []
    return [m for m in profile.incompatible_modules if _module_enabled(modules_block, m)]
