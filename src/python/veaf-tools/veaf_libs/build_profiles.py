"""
Build-profile resolution for mission.yaml.

Usage::

    from veaf_libs.build_profiles import resolve_profile

    effective_yaml = resolve_profile(raw_yaml, profile_name)
"""

from __future__ import annotations

from veaf_libs.i18n import t
from veaf_libs.logger import logger


def _deep_merge(base: dict, override: dict) -> dict:
    """Deep-merge *override* onto *base*.  Lists are replaced, not concatenated."""
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def _find_profile_key(profiles: dict, profile_name: str) -> str | None:
    """Return the actual ``profiles`` key matching *profile_name*, case-insensitively.

    An exact match wins; otherwise a single case-insensitive match is used (so
    ``--profile test`` resolves the ``TEST`` profile). When several keys differ
    only by case (e.g. ``TEST`` and ``test``) and none matches exactly, the lookup
    is ambiguous: a warning is emitted and ``None`` is returned.

    Args:
        profiles: The ``profiles:`` mapping.
        profile_name: The requested profile name (any case).

    Returns:
        The canonical key, or ``None`` when there is no (unambiguous) match.
    """
    if profile_name in profiles:
        return profile_name
    matches = [k for k in profiles if k.lower() == profile_name.lower()]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        logger.warning(t("profiles.ambiguous_profile", name=profile_name, matches=", ".join(matches)))
    return None


def canonical_profile_name(yaml_data: dict, profile_name: str | None) -> str | None:
    """Return the canonical (declared-case) profile key for *profile_name*, or ``None``.

    Used to label outputs/logs (and the multi-variant ``.miz`` suffix) with the
    profile's real name rather than whatever case the caller typed.

    Args:
        yaml_data: The parsed ``mission.yaml`` mapping.
        profile_name: The requested profile name, or ``None``.

    Returns:
        The canonical key, or ``None`` when *profile_name* is ``None`` or unmatched.
    """
    if profile_name is None:
        return None
    profiles = yaml_data.get("profiles")
    if not isinstance(profiles, dict):
        return None
    return _find_profile_key(profiles, profile_name)


def _step_not_disabled(step_cfg: object) -> bool:
    """Return True when a pipeline step config is not explicitly disabled.

    Mirrors the build's skip rule: a step is disabled only when it is ``False`` or
    ``{enabled: false}``. Absent (``None``) counts as enabled (the default).
    """
    return not (step_cfg is False or (isinstance(step_cfg, dict) and step_cfg.get("enabled") is False))


def pipeline_step_subflag(pipeline_cfg: dict, step: str, subkey: str, default: bool = True) -> bool:
    """Return a boolean sub-flag of a pipeline step's mapping form, else *default*.

    The scalar form (``step: true|false``) carries no sub-flags, so *default* is
    returned; only the mapping form (``step: {..., <subkey>: ...}``) can override it.
    Used for ``pipeline.presets.kneeboards`` (FEAT-PRESETS-KNEEBOARD-TOGGLE).

    Args:
        pipeline_cfg: The ``pipeline:`` mapping from mission.yaml.
        step: The pipeline step key (e.g. ``"presets"``).
        subkey: The sub-flag name (e.g. ``"kneeboards"``).
        default: Value returned when the sub-flag is absent.

    Returns:
        The sub-flag as a bool, or *default* when it is not set.
    """
    step_cfg = pipeline_cfg.get(step)
    if isinstance(step_cfg, dict) and subkey in step_cfg:
        return bool(step_cfg[subkey])
    return default


def pipeline_step_enabled_anywhere(yaml_data: dict, step: str) -> bool:
    """Return True when *step* is enabled in at least one build context.

    A pipeline file is only orphaned when **no** build path uses it — i.e. the
    step is disabled in the base config *and* in every profile. As soon as the
    base or any profile enables it, the file is legitimate (it serves that build),
    so the orphan warning must stay silent (FIX-BUILD-PROFILES). A profile's
    effective value is its own ``pipeline.<step>`` when set, else the base value.

    Args:
        yaml_data: The raw ``mission.yaml`` mapping (before profile resolution).
        step: The pipeline step key (e.g. ``"weather"``).

    Returns:
        True if the base or any profile leaves the step enabled.
    """
    base_pipeline = yaml_data.get("pipeline") or {}
    # The base/no-profile build enables the step unless it explicitly disables it
    # (an absent step is enabled by default).
    if step not in base_pipeline or _step_not_disabled(base_pipeline.get(step)):
        return True
    profiles = yaml_data.get("profiles") or {}
    if isinstance(profiles, dict):
        for prof in profiles.values():
            if not isinstance(prof, dict):
                continue
            prof_pipeline = prof.get("pipeline") or {}
            if step in prof_pipeline and _step_not_disabled(prof_pipeline.get(step)):
                return True
    return False


def resolve_profile(yaml_data: dict, profile_name: str | None) -> dict:
    """Return the effective YAML config for *profile_name*.

    The ``profiles:`` key is stripped from the returned dict so downstream
    workers never see it.  If *profile_name* is ``None`` the base config is
    returned as-is (minus ``profiles:``).  The profile name is matched
    case-insensitively; if it is not found a warning is emitted and the base
    config is returned.
    """
    profiles_raw = yaml_data.get("profiles") or {}
    if not isinstance(profiles_raw, dict):
        logger.warning(t("profiles.invalid_profiles_section"))
        profiles: dict = {}
    else:
        profiles = profiles_raw
    base: dict = {k: v for k, v in yaml_data.items() if k != "profiles"}

    if profile_name is None:
        return base

    key = _find_profile_key(profiles, profile_name)
    if key is None:
        logger.warning(t("profiles.profile_not_found", name=profile_name))
        return base

    logger.info(t("profiles.building_with_profile", name=key))
    return _deep_merge(base, profiles[key])
