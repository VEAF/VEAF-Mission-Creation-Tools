"""What `campaign validate` and `campaign next` warn about, learnt on a server (FEAT-DYNAMIC-CAMPAIGN ticket 20).

The persistent campaign's first server evening (Syria, 2026-11-16) flew with no AWACS nor tanker, the Caucasus
airfields on its radios, and two zones laid next to their airfield rather than on it — one of which DCS gave to blue
on its own while the zone stayed neutral. None of it was an error the tools could refuse, and none was said. These
checks say it, as warnings: a campaign may have reasons, but nobody should find out in flight.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from veaf_libs.dcs_airdromes import airfields_for_theatre
from veaf_libs.i18n import t
from veaf_libs.magnetic import ground_distance_m
from veaf_libs.mission_validator import WARNING, ValidationIssue

from campaign_manager.models import CampaignDefinition

#: The tankers that refuel with a boom (the F-16, the F-15, the A-10) and with a basket, a hose and drogue (the
#: F/A-18, the AV-8B, the F-14, the Rafale); the KC-10 does both. DCS types.
BOOM_TANKERS = frozenset({"KC-135", "KC-10A"})
BASKET_TANKERS = frozenset({"KC135MPRS", "KC130", "KC130J", "S-3B Tanker", "IL-78M", "KC-10A"})

#: A zone at coordinates this close to an airfield is taken for that airfield's zone set beside it, in metres.
NEAR_AIRFIELD_METRES = 4000


def _warning(key: str, **kwargs: Any) -> ValidationIssue:
    return ValidationIssue(WARNING, t(f"campaign.issue.{key}", **kwargs))


def zones_beside_airfields(campaign: CampaignDefinition) -> list[ValidationIssue]:
    """Warn about a zone at coordinates, of no kind, within `NEAR_AIRFIELD_METRES` of an airfield of the theatre.

    Taftanaz and Menagh were laid 2.3 km from their airfields: two capture rules on two neighbouring objects, and DCS
    handed Minakh's airfield to blue while the zone of Menagh stayed neutral. `at: { airfield: … }` makes them one.

    Args:
        campaign: The validated campaign.

    Returns:
        One warning per zone concerned.
    """
    from presets_injector.airfield_channels_manager import load_reference

    # the airfields DCS gives an ATC frequency: a road strip or a helipad (Syria's "HS09" by Al-Safira) is no base
    known = {str(entry["name"]) for entry in load_reference(campaign.theatre).values()}
    airfields = [airfield for airfield in airfields_for_theatre(campaign.theatre) if airfield["name"] in known]
    issues = []
    for zone in campaign.zones:
        lat, lon = zone.location.lat, zone.location.lon
        if zone.location.airfield or zone.kind or lat is None or lon is None:
            continue  # a depot or a factory beside an airfield is an installation of its own
        for airfield in airfields:
            distance = ground_distance_m(lat, lon, float(airfield["lat"]), float(airfield["lon"]))
            if distance <= NEAR_AIRFIELD_METRES:
                issues.append(
                    _warning("zone_beside_airfield", zone=zone.name, airfield=airfield["name"], m=round(distance))
                )
                break
    return issues


def _group_types(template: Path) -> dict[str, str] | None:
    """The template mission's air groups, name -> aircraft type, or None when it cannot be read."""
    try:
        from mission_tools.miz_tools import read_mission_folder

        mission = read_mission_folder(template)
    except Exception:  # noqa: BLE001 — any reason the template cannot be read only skips the check
        return None
    return {str(group.name): str(group.unit_type or "") for group in mission.iter_groups() if group.name}


def persistent_support(campaign: CampaignDefinition, campaign_folder: Path) -> list[ValidationIssue]:
    """Warn about a persistent campaign with no AWACS or tanker held, no `economy.tanker`, or assets its template lacks.

    Args:
        campaign: The validated campaign.
        campaign_folder: The campaign folder, for its template mission.

    Returns:
        The warnings; none for a multi-mission campaign.
    """
    if campaign.mode != "persistent":
        return []
    dynamic = campaign.dynamic or {}
    assets = [str(name) for name in ((dynamic.get("support") or {}).get("assets") or [])]
    tankers = campaign.shop_tankers()
    issues = []
    if not assets:
        issues.append(_warning("no_support_assets"))
    if not tankers:
        issues.append(_warning("no_shop_tanker"))
    template = campaign_folder / campaign.mission_template
    types = _group_types(template) if (template / "src" / "mission").exists() else None
    if types is not None:
        missing = sorted(name for name in {*assets, *tankers} if name not in types)
        for name in missing:
            issues.append(_warning("support_asset_missing", name=name, template=campaign.mission_template))
        # David, 2026-11-17: a boom and a basket, each held out of reach like the AWACS; said once the assets
        # named are all there, which a missing one already says otherwise
        held = {types[name] for name in assets if name in types}
        if missing or not assets:
            return issues
        if not held & BOOM_TANKERS:
            issues.append(_warning("no_boom_tanker"))
        if not held & BASKET_TANKERS:
            issues.append(_warning("no_basket_tanker"))
    return issues


def template_presets(campaign: CampaignDefinition, campaign_folder: Path) -> list[ValidationIssue]:
    """Warn about the template's radio plan naming airfields of another theatre.

    Args:
        campaign: The validated campaign.
        campaign_folder: The campaign folder.

    Returns:
        One warning per channel concerned.
    """
    import yaml
    from presets_injector.airfield_channels_manager import foreign_airfield_aliases

    path = campaign_folder / campaign.mission_template / "src" / "presets.yaml"
    if not path.is_file():
        return []
    try:
        presets = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return []
    return [
        _warning("foreign_airfield_preset", channel=alias, other=other, theatre=campaign.theatre)
        for alias, other in foreign_airfield_aliases(presets, campaign.theatre)
    ]


def campaign_warnings(campaign: CampaignDefinition, campaign_folder: Path) -> list[ValidationIssue]:
    """Every warning of this module.

    Args:
        campaign: The validated campaign.
        campaign_folder: The campaign folder.

    Returns:
        The warnings, zones first.
    """
    return [
        *zones_beside_airfields(campaign),
        *persistent_support(campaign, campaign_folder),
        *template_presets(campaign, campaign_folder),
    ]
