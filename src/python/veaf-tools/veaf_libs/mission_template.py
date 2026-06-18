"""Data-driven generation of a scaffolded ``mission.yaml`` from a chosen module set.

Single source of truth for the ``prepare`` command's templates. A :class:`Module`
catalog (ordered, with category) plus the named tiers (``minimal`` / ``standard`` /
``full``) feed one generator, :func:`generate_mission_yaml`. The ``custom`` template is
just an arbitrary module set fed to the same generator.

Rendering per module, for a given enabled set:
  - infrastructure modules are always emitted (bare ``ID:``);
  - a feature toggle in the set is emitted as ``ID: true``;
  - a config-required module in the set is emitted as a **commented** example block
    (ready to uncomment — a fresh mission stays valid and ``validate`` does not flag
    placeholder groups/zones);
  - ``SECURITY`` is always emitted commented (off by default — uncomment to require a
    password); ``TUM`` is emitted commented with a warning (it aborts at start-up
    without BLUFOR/REDFOR territory zones);
  - modules outside the set are omitted, so each tier's file stays focused.
"""

from __future__ import annotations

from dataclasses import dataclass, field

INFRA = "infra"
FEATURE = "feature"
CONFIG = "config"
SECURITY = "security"
TUM = "tum"


@dataclass(frozen=True)
class Module:
    """A module catalog entry: how to render it and which category it sits under."""

    id: str
    kind: str
    category: str
    comment: str = ""
    config_block: str = ""  # commented body for CONFIG/TUM modules (already `#`-prefixed)
    tiers: frozenset[str] = field(default_factory=frozenset)


# Commented example blocks (lifted from the shipped default mission.yaml) — emitted
# under the module when a config-required module belongs to the selected set.
_ASSETS_BLOCK = """\
  #   ASSETS:
  #     enabled: true
  #     assets:
  #       - sort: 1
  #         name: T1-Arco-1
  #         description: Arco-1 (KC-135)
  #         information: "Tacan 64Y\\nU290.50 (20)\""""

_SANCTUARY_BLOCK = """\
  #   SANCTUARY:
  #     enabled: true
  #     sanctuary_zones:
  #       - name: Base Alpha
  #         polygon_units:
  #           - Sanctuary-Unit-1
  #         coalition: BLUE
  #         delay_warning: 30
  #         delay_spawn: 60"""

_COMBATZONE_BLOCK = """\
  #   COMBATZONE:
  #     enabled: true
  #     combat_zones:
  #       - type: zone
  #         zone_name: CZ-Alpha
  #         friendly_name: Alpha Zone
  #         training: false"""

_QRA_BLOCK = """\
  #   QRA:
  #     enabled: true
  #     definitions:
  #       - name: Base QRA
  #         coalition: RED
  #         enemy_coalitions: [BLUE]
  #         trigger_zone: QRA zone
  #         zone_radius: 30000
  #         groups_by_enemy_count:
  #           - enemy_count: 1
  #             groups: [Group1, Group2]
  #             random_pick: 1"""

_AIRWAVES_BLOCK = """\
  #   AIRWAVES:
  #     enabled: true
  #     airwave_zones:
  #       - name: BVR Zone
  #         start: true
  #         player_coalitions: [BLUE]
  #         zone_center_coordinates: "N41°00'00\\" E044°00'00\\""
  #         zone_radius: 50000
  #         waves:
  #           - groups: su27-2ship
  #             delay: 0"""

_SKYNET_BLOCK = """\
  #   SKYNET:
  #     enabled: true
  #     include_red_in_radio: false"""

_TUM_BLOCK = """\
  # TUM requires BLUFOR/REDFOR territory trigger zones (each owning an airbase) placed
  # in the Mission Editor, or it aborts at start-up. Uncomment once the zones exist:
  #   TUM: true"""

#: The module catalog, in emission order.
_CATALOG: tuple[Module, ...] = (
    # ── Infrastructure (always active) ──
    Module("UNITS", INFRA, "Infrastructure"),
    Module("TIME", INFRA, "Infrastructure"),
    Module("CACHE", INFRA, "Infrastructure"),
    Module("EVENTS", INFRA, "Infrastructure"),
    Module("MARKERS", INFRA, "Infrastructure"),
    Module("COMMANDS", INFRA, "Infrastructure"),
    Module("MIST", INFRA, "Infrastructure", comment="MiST community lib — mandatory (VEAF dependency)"),
    # ── Core ──
    Module(
        "RADIO", FEATURE, "Core", comment="the VEAF F10 radio menu", tiers=frozenset({"minimal", "standard", "full"})
    ),
    Module("SPAWN", FEATURE, "Core", tiers=frozenset({"minimal", "standard", "full"})),
    Module(
        "SHORTCUTS",
        FEATURE,
        "Core",
        comment="built-in aliases (-shilka, -sa2, …)",
        tiers=frozenset({"minimal", "standard", "full"}),
    ),
    Module("INTERPRETER", FEATURE, "Core", tiers=frozenset({"minimal", "standard", "full"})),
    Module(
        "SECURITY",
        SECURITY,
        "Core",
        config_block="  # SECURITY: true   # uncomment + add password_hashes in a `security:` section to require a password",
        tiers=frozenset({"minimal", "standard", "full"}),
    ),
    # ── Features ──
    Module("NAMEDPOINTS", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("MOVE", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("GRASS", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("WEATHER", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("REMOTE", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("AIRBASES", FEATURE, "Features", tiers=frozenset({"standard", "full"})),
    Module("MISSILEGUARDIAN", FEATURE, "Features", tiers=frozenset({"full"})),
    # ── Combat ──
    # GROUNDAI sits in exactly CASMISSION's tiers: CASMISSION depends on it, so the build
    # would silently auto-enable it otherwise — keep the dependency declared, not implicit.
    Module(
        "GROUNDAI",
        FEATURE,
        "Combat",
        comment="ground units AI behaviour (required by CASMISSION)",
        tiers=frozenset({"standard", "full"}),
    ),
    Module("CASMISSION", FEATURE, "Combat", comment="`_cas` marker (no config)", tiers=frozenset({"standard", "full"})),
    Module(
        "TRANSPORTMISSION",
        FEATURE,
        "Combat",
        comment="`_transport` marker (no config)",
        tiers=frozenset({"standard", "full"}),
    ),
    Module("COMBATMISSION", FEATURE, "Combat", tiers=frozenset({"full"})),
    Module(
        "CARRIER", FEATURE, "Combat", comment="carrier-operations radio menus", tiers=frozenset({"standard", "full"})
    ),
    Module("COMBATZONE", CONFIG, "Combat", config_block=_COMBATZONE_BLOCK, tiers=frozenset({"standard", "full"})),
    Module("QRA", CONFIG, "Combat", config_block=_QRA_BLOCK, tiers=frozenset({"standard", "full"})),
    Module("AIRWAVES", CONFIG, "Combat", config_block=_AIRWAVES_BLOCK, tiers=frozenset({"full"})),
    Module("ASSETS", CONFIG, "Combat", config_block=_ASSETS_BLOCK, tiers=frozenset({"full"})),
    Module("SANCTUARY", CONFIG, "Combat", config_block=_SANCTUARY_BLOCK, tiers=frozenset({"full"})),
    # ── Community scripts ──
    Module("STTS", FEATURE, "Community", tiers=frozenset({"standard", "full"})),
    Module("CTLD", FEATURE, "Community", tiers=frozenset({"standard", "full"})),
    Module("CSAR", FEATURE, "Community", tiers=frozenset({"standard", "full"})),
    Module("AIEN", FEATURE, "Community", tiers=frozenset({"full"})),
    Module("HERCULES", FEATURE, "Community", tiers=frozenset({"full"})),
    Module("SKYNET", CONFIG, "Community", config_block=_SKYNET_BLOCK, tiers=frozenset({"full"})),
    Module("TUM", TUM, "Community", config_block=_TUM_BLOCK, tiers=frozenset({"full"})),
)

#: Catalog indexed by id.
CATALOG: dict[str, Module] = {m.id: m for m in _CATALOG}

#: The named tiers, as the set of module ids each enables (infra is implicit/always).
TIER_NAMES: tuple[str, ...] = ("minimal", "standard", "full")


def tier_modules(tier: str) -> set[str]:
    """Return the module ids enabled by a named tier (excluding always-on infrastructure).

    Raises:
        ValueError: if *tier* is not one of :data:`TIER_NAMES`.
    """
    if tier not in TIER_NAMES:
        raise ValueError(f"unknown tier '{tier}' (valid: {', '.join(TIER_NAMES)})")
    return {m.id for m in _CATALOG if tier in m.tiers}


#: Modules a user may pick in the ``custom`` template — everything except the
#: always-emitted ones (infrastructure and the SECURITY how-to block).
SELECTABLE_MODULES: tuple[str, ...] = tuple(m.id for m in _CATALOG if m.kind not in (INFRA, SECURITY))


def module_lowest_tier(module_id: str) -> str | None:
    """Return the lowest named tier a module belongs to (tiers are cumulative), or ``None``.

    e.g. ``RADIO`` → ``"minimal"`` (also in standard/full), ``WEATHER`` → ``"standard"``,
    ``MISSILEGUARDIAN`` → ``"full"``. Used to tag modules in the ``custom`` picker.
    """
    tiers = CATALOG[module_id].tiers
    return next((name for name in TIER_NAMES if name in tiers), None)


def module_category(module_id: str) -> str:
    """Return a module's catalog category (for grouping in the picker)."""
    return CATALOG[module_id].category


def render_modules_block(enabled: set[str]) -> list[str]:
    """Render the body of a ``modules:`` block (category-grouped) for *enabled*.

    Infrastructure modules and the SECURITY how-to block are always emitted;
    every other module only when its id is in *enabled*. Returns the indented
    lines that go **under** a ``modules:`` key (not the key itself).

    Args:
        enabled: Module ids to enable (infrastructure is always included).

    Returns:
        The ``modules:`` body lines.
    """
    lines: list[str] = []
    current_category = ""
    for module in _CATALOG:
        include = module.kind in (INFRA, SECURITY) or module.id in enabled
        if not include:
            continue
        if module.category != current_category:
            lines.append(f"  # ── {module.category} ──")
            current_category = module.category
        suffix = f"  # {module.comment}" if module.comment else ""
        if module.kind == INFRA:
            lines.append(f"  {module.id}:{suffix}")
        elif module.kind == FEATURE:
            lines.append(f"  {module.id}: true{suffix}")
        else:  # CONFIG / SECURITY / TUM → commented block
            lines.append(module.config_block)
    return lines


def generate_mission_yaml(enabled: set[str]) -> str:
    """Generate a ``mission.yaml`` text whose ``modules:`` block reflects *enabled*.

    Args:
        enabled: Module ids to include (infrastructure is always included regardless).

    Returns:
        The full ``mission.yaml`` content (header + ``mission:`` + ``modules:``).
    """
    lines: list[str] = [
        "# mission.yaml — generated by `veaf-tools prepare`. Edit freely.",
        "# Run `veaf-tools validate` to check it, then `veaf-tools build`.",
        "",
        "mission:",
        '  name: "My-Mission"',
        "",
        "modules:",
    ]
    lines.extend(render_modules_block(enabled))
    return "\n".join(lines) + "\n"
