"""
Build-profile resolution for mission.yaml.

Usage::

    from veaf_libs.build_profiles import resolve_profile

    effective_yaml = resolve_profile(raw_yaml, profile_name)
"""

from __future__ import annotations

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


def resolve_profile(yaml_data: dict, profile_name: str | None) -> dict:
    """Return the effective YAML config for *profile_name*.

    The ``profiles:`` key is stripped from the returned dict so downstream
    workers never see it.  If *profile_name* is ``None`` the base config is
    returned as-is (minus ``profiles:``).  If the named profile is not found a
    warning is emitted and the base config is returned.
    """
    profiles_raw = yaml_data.get("profiles") or {}
    if not isinstance(profiles_raw, dict):
        logger.warning("Ignoring invalid 'profiles' section in mission.yaml (expected mapping)")
        profiles: dict = {}
    else:
        profiles = profiles_raw
    base: dict = {k: v for k, v in yaml_data.items() if k != "profiles"}

    if profile_name is None:
        return base

    if profile_name not in profiles:
        logger.warning(f"Profile '{profile_name}' not found in mission.yaml — using base config")
        return base

    logger.info(f"Building with profile: {profile_name}")
    return _deep_merge(base, profiles[profile_name])
