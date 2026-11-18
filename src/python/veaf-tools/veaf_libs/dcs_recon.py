"""Reconnaissance photos taken in a running DCS: the geometry, the requests and the shooting mission.

Taken over from the prototype written for "Marteau du Golan" (Syria, 2026-10-28), where twelve shots
were taken by hand through the ``dcs-fiddle`` hook; the commands now go through the VEAF bridge
(REFACTOR-BRIDGE-ONLY). What the prototype measured, and what this module keeps:

- **Positions come from the running mission.** The groups a combat zone draws at random only exist
  in game, so the mission file cannot say where they stand; ``coalition.getGroups`` can. The bridge
  asks in the mission scripting state it runs in.
- **The camera moves only from the ``export`` state.** ``LoSetCameraPosition`` sent from the GUI
  state leaves the camera where it is, and in the F10 view it pans the map instead. In F11 free
  camera, sent through ``export``, it places the camera exactly.
- **The camera basis is x forward, y up, z right, p position**, in DCS world axes: x north,
  y altitude, z east (see ``docs/agents/dcs-coordinates.md`` — the runtime's own meaning of ``y``).
- **The horizontal field of view is 80°.** Calibrated on the SA-11 shot: with it, the six vehicles of
  the battery fall within a few pixels of their projection.

Everything here is pure computation or Lua text, so it is unit-tested without DCS; the window grab
lives in :mod:`veaf_libs.dcs_window_capture` and the rendering in :mod:`veaf_libs.recon_render`.
"""

from __future__ import annotations

import json
import math
import re
import shutil
import unicodedata
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from veaf_libs.i18n import t
from veaf_libs.lua_literals import lua_quoted_string

#: The export state, the only one from which ``LoSetCameraPosition`` moves the F11 camera. The bridge
#: runs in the mission scripting state and reaches it through ``net.dostring_in`` (measured 2026-10-28:
#: the camera moved, 145 → 445 m).
ENV_EXPORT = "export"

#: Horizontal field of view of the DCS window, degrees. Measured, see the module docstring.
HFOV_DEGREES = 80.0

#: Height of the F11 information bar at the bottom of the window, cut off every shot. Measured on a
#: 2650 x 1634 client area (2026-10-28): the bar starts 36 px above the bottom.
INFO_BAR_PX = 40

#: Coalition ids as ``coalition.getGroups`` takes them.
COALITIONS = {"red": 1, "blue": 2}

Vec3 = tuple[float, float, float]


@dataclass(frozen=True)
class Camera:
    """A camera pose in DCS world axes (x north, y altitude, z east).

    Args:
        position: Where the camera stands.
        forward: Unit vector the camera looks along.
        up: Unit vector of the image's up direction.
        right: Unit vector of the image's right direction.
    """

    position: Vec3
    forward: Vec3
    up: Vec3
    right: Vec3


def camera_for(x: float, z: float, ground: float, heading: float, pitch: float, slant: float) -> Camera:
    """Place a camera looking at a ground point along an engagement axis.

    Args:
        x: Target northing, DCS metres.
        z: Target easting, DCS metres.
        ground: Target altitude, metres.
        heading: Direction the camera looks, degrees on the mission's grid, as the camera's axes are the world's (the attack heading).
        pitch: How far below the horizon it looks, degrees.
        slant: Distance from the camera to the target, metres.

    Returns:
        The camera pose, ``slant`` metres back up the line of sight from the target.
    """
    p, h = math.radians(pitch), math.radians(heading)
    forward = (math.cos(p) * math.cos(h), -math.sin(p), math.cos(p) * math.sin(h))
    up = (math.sin(p) * math.cos(h), math.cos(p), math.sin(p) * math.sin(h))
    right = (-math.sin(h), 0.0, math.cos(h))
    position = (x - forward[0] * slant, ground - forward[1] * slant, z - forward[2] * slant)
    return Camera(position=position, forward=forward, up=up, right=right)


def camera_lua(camera: Camera) -> str:
    """Return the ``export``-state chunk that puts the F11 camera on *camera*.

    Args:
        camera: The pose to apply.

    Returns:
        Lua source returning ``"ok"``.
    """

    def vec(v: Vec3) -> str:
        return f"{{x={v[0]:.6f},y={v[1]:.6f},z={v[2]:.6f}}}"

    order = "LoSetCameraPosition({x=%s,y=%s,z=%s,p=%s}) return 'ok'"
    return order % (vec(camera.forward), vec(camera.up), vec(camera.right), vec(camera.position))


def project(
    camera: Camera, x: float, z: float, alt: float, width: int, height: int, hfov: float = HFOV_DEGREES
) -> tuple[float, float] | None:
    """Project a world point into a shot.

    Args:
        camera: The pose the shot was taken from.
        x: Point northing, DCS metres.
        z: Point easting, DCS metres.
        alt: Point altitude, metres.
        width: Width of the whole window client area, pixels.
        height: Height of the whole window client area, pixels — **before** the info bar is cut, since
            the optical centre is the window's.
        hfov: Horizontal field of view, degrees.

    Returns:
        ``(px, py)`` from the top-left corner, or ``None`` when the point is behind the camera.
    """
    d = (x - camera.position[0], alt - camera.position[1], z - camera.position[2])

    def dot(a: Vec3, b: Vec3) -> float:
        return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

    depth = dot(d, camera.forward)
    if depth <= 0:
        return None
    focal = (width / 2) / math.tan(math.radians(hfov) / 2)
    return width / 2 + focal * dot(d, camera.right) / depth, height / 2 - focal * dot(d, camera.up) / depth


# --------------------------------------------------------------------------------------------------
# Live units
# --------------------------------------------------------------------------------------------------

#: Every active unit and every static of both coalitions, one tab-separated line each:
#: ``kind side name type x z alt`` where ``name`` is the group's for a unit, the object's for a static.
#: ``isActive`` because a late-activated group is listed by ``coalition.getGroups`` while not on the map.
UNITS_LUA = r"""
local out = {}
local function clean(s) return (tostring(s):gsub("[\t\n]", " ")) end
for _, side in ipairs({1, 2}) do
  for _, g in ipairs(coalition.getGroups(side) or {}) do
    for _, u in ipairs(g:getUnits() or {}) do
      if u:isActive() then
        local p = u:getPoint()
        out[#out + 1] = string.format("unit\t%d\t%s\t%s\t%.1f\t%.1f\t%.1f", side, clean(g:getName()), clean(u:getTypeName()), p.x, p.z, p.y)
      end
    end
  end
  for _, s in ipairs(coalition.getStaticObjects(side) or {}) do
    local p = s:getPoint()
    out[#out + 1] = string.format("static\t%d\t%s\t%s\t%.1f\t%.1f\t%.1f", side, clean(s:getName()), clean(s:getTypeName()), p.x, p.z, p.y)
  end
end
return table.concat(out, "\n")
"""

#: The theatre, the mission date and the current mission time in seconds since midnight of day one.
INFO_LUA = r"""
local d = env.mission.date or {}
return string.format("%s\t%04d-%02d-%02d\t%d", env.mission.theatre or "", d.Year or 0, d.Month or 0, d.Day or 0, timer.getAbsTime())
"""


@dataclass(frozen=True)
class LiveUnit:
    """One unit or static, where DCS says it is now.

    Args:
        kind: ``unit`` or ``static``.
        side: Coalition id, 1 red, 2 blue.
        group: The group's name for a unit, the object's own name for a static.
        type: DCS type name.
        x: Northing, metres.
        z: Easting, metres.
        alt: Altitude, metres.
    """

    kind: str
    side: int
    group: str
    type: str
    x: float
    z: float
    alt: float


def parse_units(text: str) -> list[LiveUnit]:
    """Read what :data:`UNITS_LUA` returned.

    Args:
        text: The chunk's reply.

    Returns:
        The units, in DCS's order.

    Raises:
        ValueError: A line does not have the seven fields the chunk writes.
    """
    units: list[LiveUnit] = []
    for line in (text or "").splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != 7:
            raise ValueError(f"unexpected unit line from DCS: {line!r}")
        kind, side, group, type_, x, z, alt = fields
        units.append(LiveUnit(kind, int(side), group, type_, float(x), float(z), float(alt)))
    return units


@dataclass(frozen=True)
class MissionInfo:
    """What the running mission says about where and when it is.

    Args:
        theatre: DCS theatre name.
        date: ``YYYY-MM-DD``.
        seconds: Mission time, seconds since midnight of the first day.
    """

    theatre: str
    date: str
    seconds: int

    @property
    def clock(self) -> str:
        """The time of day, ``HH:MM``."""
        of_day = self.seconds % 86400
        return f"{of_day // 3600:02d}:{of_day % 3600 // 60:02d}"


#: Every combat zone of the running mission, once each, operations left out: ``name x z radius`` per line.
#: Once per name: in a mission built with scripts older than 6.34.0, a zone an operation lists is in
#: ``zonesList`` twice (measured on "Marteau du Golan", 2026-10-28).
ZONES_LUA = r"""
local out, done = {}, {}
if not veafCombatZone then return "" end
for _, zone in ipairs(veafCombatZone.zonesList) do
  local name = zone:getMissionEditorZoneName()
  local trig = trigger.misc.getZone(name)
  if not zone.taskingOrderDict and not done[name] and trig then
    done[name] = true
    out[#out + 1] = string.format("%s\t%.1f\t%.1f\t%.1f", (tostring(name):gsub("[\t\n]", " ")), trig.point.x, trig.point.z, trig.radius or 0)
  end
end
return table.concat(out, "\n")
"""


@dataclass(frozen=True)
class CombatZone:
    """A combat zone of the running mission.

    Args:
        name: Its mission-editor trigger zone name.
        x: Centre northing, metres.
        z: Centre easting, metres.
        radius: Trigger zone radius, metres.
    """

    name: str
    x: float
    z: float
    radius: float


def parse_zones(text: str) -> list[CombatZone]:
    """Read what :data:`ZONES_LUA` returned.

    Args:
        text: The chunk's reply.

    Returns:
        The combat zones, in the mission's order.

    Raises:
        ValueError: A line does not have the four fields the chunk writes.
    """
    zones: list[CombatZone] = []
    for line in (text or "").splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != 4:
            raise ValueError(f"unexpected zone line from DCS: {line!r}")
        zones.append(CombatZone(fields[0], float(fields[1]), float(fields[2]), float(fields[3])))
    return zones


def zone_units_lua(zone: str) -> str:
    """Return the chunk listing the units and statics a combat zone spawned, as :data:`UNITS_LUA` does.

    The zone says which groups are its own (``getSpawnedGroups``): no name prefix to match, so a shot
    finds them whether their names are hidden or not, and ``combatZone_X`` never takes ``combatZone_X2``'s.

    Args:
        zone: The zone's mission-editor name.

    Returns:
        Lua source returning ``kind side name type x z alt`` lines.
    """
    return f"""
local out = {{}}
local function clean(s) return (tostring(s):gsub("[\\t\\n]", " ")) end
local zone = veafCombatZone and veafCombatZone.GetZone({lua_quoted_string(zone)})
if not zone then return "" end
for _, name in ipairs(zone:getSpawnedGroups() or {{}}) do
  local g = Group.getByName(name)
  if g and g:isExist() then
    for _, u in ipairs(g:getUnits() or {{}}) do
      local p = u:getPoint()
      out[#out + 1] = string.format("unit\\t%d\\t%s\\t%s\\t%.1f\\t%.1f\\t%.1f", u:getCoalition(), clean(name), clean(u:getTypeName()), p.x, p.z, p.y)
    end
  else
    local s = StaticObject.getByName(name)
    if s and s:isExist() then
      local p = s:getPoint()
      out[#out + 1] = string.format("static\\t%d\\t%s\\t%s\\t%.1f\\t%.1f\\t%.1f", s:getCoalition(), clean(name), clean(s:getTypeName()), p.x, p.z, p.y)
    end
  end
end
return table.concat(out, "\\n")
"""


def activate_alone_lua(zone: str) -> str:
    """Return the chunk that deactivates every active combat zone, then activates *zone* alone.

    The easy, medium and hard variants of an Open Training site share one trigger zone: all active at
    once, a photo shows the three superimposed (2026-11-17). Operations are left alone. ``ActivateZone``
    spawns a second later.

    Args:
        zone: The zone's mission-editor name.

    Returns:
        Lua source returning ``ok``, or ``unknown`` when the mission has no such combat zone.
    """
    return f"""
local wanted = {lua_quoted_string(zone)}
if not veafCombatZone or not veafCombatZone.GetZone(wanted) then return "unknown" end
for _, zone in ipairs(veafCombatZone.zonesList) do
  if not zone.taskingOrderDict and zone:isActive() then
    veafCombatZone.DesactivateZone(zone:getMissionEditorZoneName(), true)
  end
end
veafCombatZone.ActivateZone(wanted, true)
return "ok"
"""


def deactivate_lua(zone: str) -> str:
    """Return the chunk that deactivates *zone*, silently."""
    return f"veafCombatZone.DesactivateZone({lua_quoted_string(zone)}, true) return 'ok'"


def airbase_lua(name: str) -> str:
    """Return the chunk giving an airbase's position as ``x z``, or an empty string when there is none."""
    return (
        f"local a = Airbase.getByName({lua_quoted_string(name)}) if not a then return '' end "
        "local p = a:getPoint() return string.format('%.1f\\t%.1f', p.x, p.z)"
    )


def parse_point(text: str) -> tuple[float, float] | None:
    """Read what :func:`airbase_lua` returned: ``(x, z)``, or ``None`` for an unknown airbase."""
    fields = (text or "").split("\t")
    return (float(fields[0]), float(fields[1])) if len(fields) == 2 else None


def parse_info(text: str) -> MissionInfo:
    """Read what :data:`INFO_LUA` returned.

    Args:
        text: The chunk's reply.

    Returns:
        The mission's theatre, date and time.

    Raises:
        ValueError: The reply is not the three fields the chunk writes.
    """
    fields = (text or "").split("\t")
    if len(fields) != 3:
        raise ValueError(f"unexpected mission info from DCS: {text!r}")
    return MissionInfo(fields[0], fields[1], int(fields[2]))


# --------------------------------------------------------------------------------------------------
# Shots
# --------------------------------------------------------------------------------------------------


@dataclass
class Shot:
    """One photo to take: what it aims at and from where.

    Args:
        name: File stem, e.g. ``01-tellhara``; also the order shots are rendered in.
        title: What the banner says the target is.
        groups: Group or static name prefixes; the units whose name starts with one are the target. On a
            combat zone's shot, they narrow the zone's own units; empty, the zone's units are the target.
        heading: Engagement heading, degrees on the mission's grid — the direction the camera looks.
        pitch: Degrees below the horizon.
        slant: Camera-to-target distance, metres; ``None`` to work it out from the target's spread when
            the shot is taken (:func:`auto_slant`).
        mark: ``groups`` for one ring per group, ``units`` for one per vehicle.
        labels: Label per type name (``units``) or per group prefix (``groups``); otherwise the category.
        zone: The combat zone the shot illustrates, as the briefing's objectives name it; by default the
            zone the first prefix belongs to. A combat zone of the mission is activated alone for its shot.
    """

    name: str
    title: str
    groups: list[str]
    heading: float = 0.0
    pitch: float = 30.0
    slant: float | None = None
    mark: str = "groups"
    labels: dict[str, str] = field(default_factory=dict)
    zone: str = ""

    def __post_init__(self) -> None:
        """Default the zone to the one the first group prefix belongs to."""
        if not self.zone and self.groups:
            self.zone = zone_of(self.groups[0])


@dataclass
class ShotPlan:
    """A shots file: the operation's name, the side photographed, the shots in order.

    Args:
        operation: Shown in every banner.
        coalition: ``red`` or ``blue``, the side whose units are photographed.
        shots: The shots.
    """

    operation: str
    coalition: str
    shots: list[Shot]


def load_plan(path: Path) -> ShotPlan:
    """Read a shots file.

    Args:
        path: The YAML file.

    Returns:
        The plan.

    Raises:
        ValueError: The file lacks ``shots``, a shot lacks ``name`` or both ``groups`` and ``zone``, a
            ``mark`` is not ``groups`` or ``units``, a ``slant`` is neither a distance nor ``auto``, or
            the coalition is unknown.
    """
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    coalition = str(data.get("coalition", "red")).lower()
    if coalition not in COALITIONS:
        raise ValueError(f"coalition must be red or blue, not {coalition!r}")
    shots: list[Shot] = []
    for entry in data.get("shots") or []:
        if not entry.get("name") or not (entry.get("groups") or entry.get("zone")):
            raise ValueError(f"a shot needs a name, and groups or a zone: {entry!r}")
        mark = entry.get("mark", "groups")
        if mark not in ("groups", "units"):
            raise ValueError(f"{entry['name']}: mark must be groups or units, not {mark!r}")
        slant = entry.get("slant", "auto")
        if slant != "auto" and not isinstance(slant, int | float):
            raise ValueError(f"{entry['name']}: slant must be a distance in metres or auto, not {slant!r}")
        shots.append(
            Shot(
                name=str(entry["name"]),
                title=str(entry.get("title") or entry["name"]),
                groups=[str(g) for g in entry.get("groups") or []],
                heading=float(entry.get("heading", 0.0)),
                pitch=float(entry.get("pitch", 30.0)),
                slant=None if slant == "auto" else float(slant),
                mark=mark,
                labels={str(k): str(v) for k, v in (entry.get("labels") or {}).items()},
                zone=str(entry.get("zone") or ""),
            )
        )
    if not shots:
        raise ValueError(f"{path}: no shots")
    return ShotPlan(operation=str(data.get("operation") or ""), coalition=coalition, shots=shots)


def select_units(units: list[LiveUnit], side: int, prefixes: list[str]) -> list[LiveUnit]:
    """Keep the units of *side* whose group (or static) name starts with one of *prefixes*.

    Args:
        units: Every live unit.
        side: Coalition id.
        prefixes: Name prefixes.

    Returns:
        The matching units.
    """
    return [u for u in units if u.side == side and any(u.group.startswith(p) for p in prefixes)]


def target_of(units: list[LiveUnit]) -> tuple[float, float, float]:
    """Return the point a shot aims at: the units' centroid, at their mean altitude.

    Args:
        units: The shot's units, at least one.

    Returns:
        ``(x, z, ground)``.

    Raises:
        ValueError: *units* is empty.
    """
    if not units:
        raise ValueError("no unit to aim at")
    n = len(units)
    return sum(u.x for u in units) / n, sum(u.z for u in units) / n, sum(u.alt for u in units) / n


#: A spawned group's name: its zone, then its side's marker, then a name or an id or nothing (``Sasa [r]``).
_SPAWNED = re.compile(r"(.+?) \[[rbn]\](?=[ #]|$)")


def zone_of(group: str) -> str:
    """Return the combat zone a spawned group belongs to, from its name.

    A group a zone spawns is named ``<zone> [r] <base>#<id>`` when names are not hidden (the shooting
    mission makes sure they are not), or ``<zone> [r]`` with nothing after the marker; any other group is
    its own "zone".

    Args:
        group: Group name.

    Returns:
        The zone name, or the group name.
    """
    found = _SPAWNED.match(group)
    return found.group(1) if found else group


#: The closest and the farthest an automatic slant puts the camera, metres. Beyond 6 km nothing a
#: zone holds can be seen: ``recon-plan`` proposed 18.3 km for Beslan (2026-11-17).
MIN_SLANT = 600.0
MAX_SLANT = 6000.0


def auto_slant(units: list[LiveUnit]) -> float:
    """Return a slant range that fits the units in the frame: three times their spread, within bounds.

    Args:
        units: The shot's units, at least one.

    Returns:
        Metres, a multiple of 50 between :data:`MIN_SLANT` and :data:`MAX_SLANT`.
    """
    cx, cz, _ = target_of(units)
    spread = max(math.hypot(u.x - cx, u.z - cz) for u in units)
    return min(MAX_SLANT, max(MIN_SLANT, round(spread * 3 / 50) * 50))


def heading_from(origin: tuple[float, float], x: float, z: float) -> int:
    """Return the grid heading from *origin* ``(x, z)`` to the point ``(x, z)``, whole degrees.

    The Open Training photos looked from the main blue airbase towards each zone: the axis a player
    flies in on.
    """
    return round(math.degrees(math.atan2(z - origin[1], x - origin[0]))) % 360


def load_objectives(path: Path) -> list[tuple[str, str]]:
    """Read the objectives of a briefing's words file: ``(zone, title)`` in their order.

    The file is the one ``build_mission_briefing`` takes (an Open Training's ``docs/kneeboard.json``):
    an ``objectives`` list of ``{zone, title}``.

    Args:
        path: The JSON file.

    Returns:
        The objectives; those without a zone are left out.

    Raises:
        ValueError: The file has no ``objectives`` list.
    """
    data = json.loads(path.read_text(encoding="utf-8"))
    objectives = data.get("objectives") if isinstance(data, dict) else None
    if not isinstance(objectives, list):
        raise ValueError(f"{path}: no objectives list")
    return [(str(o["zone"]), str(o.get("title") or o["zone"])) for o in objectives if o.get("zone")]


def plan_from_zones(
    zones: list[CombatZone],
    coalition: str,
    operation: str,
    objectives: list[tuple[str, str]] | None = None,
    origin: tuple[float, float] | None = None,
) -> tuple[dict[str, Any], list[str]]:
    """Write a starter shots plan: one shot per combat zone, to be checked before shooting.

    Only combat zones: an AWACS, a tanker or a lone radar is no objective (the Open Training plans
    listed 236 shots for 26 zones). With *objectives*, the shots follow them, in their order and with
    their titles. The heading points from *origin* to the zone; without one it is 0, for the mission
    maker to set. The slant is ``auto``, worked out when the shot is taken.

    Args:
        zones: The mission's combat zones.
        coalition: ``red`` or ``blue``, the side photographed.
        operation: The operation's name, for the banner.
        objectives: ``(zone, title)`` to follow, or ``None`` for every zone in the mission's order.
        origin: ``(x, z)`` the shots look from, or ``None``.

    Returns:
        The plan as a mapping ready to dump to YAML, and the objectives' zones the mission does not have.
    """
    by_name = {zone.name: zone for zone in zones}
    wanted = objectives if objectives is not None else [(zone.name, zone.name) for zone in zones]
    missing = [name for name, _ in wanted if name not in by_name]
    shots: list[dict[str, Any]] = []
    for index, (name, title) in enumerate([w for w in wanted if w[0] in by_name], start=1):
        zone = by_name[name]
        shots.append(
            {
                "name": f"{index:02d}-{_slug(re.sub(r'^combatZone_', '', name, flags=re.IGNORECASE))}",
                "title": title,
                "zone": name,
                "heading": heading_from(origin, zone.x, zone.z) if origin else 0,
                "pitch": 30,
                "slant": "auto",
            }
        )
    return {"operation": operation, "coalition": coalition, "shots": shots}, missing


def _slug(text: str) -> str:
    """Lower-case ASCII letters and digits joined by dashes, for a file name."""
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii").lower()
    words = "".join(c if c.isalnum() else " " for c in ascii_text).split()
    return "-".join(words) or "shot"


def dominant_type(units: list[LiveUnit]) -> str:
    """Return the most common type name among *units* (the first met on a tie)."""
    return Counter(u.type for u in units).most_common(1)[0][0]


def shot_metadata(
    shot: Shot,
    camera: Camera,
    units: list[LiveUnit],
    target: tuple[float, float, float],
    info: MissionInfo,
    window: tuple[int, int],
    latlon: tuple[float, float] | None,
) -> dict[str, Any]:
    """Assemble everything the renderer and the briefing need to know about one shot.

    Args:
        shot: The shot as planned.
        camera: The pose it was taken from.
        units: The units aimed at.
        target: ``(x, z, ground)``.
        info: The mission's theatre and time.
        window: ``(width, height)`` of the whole client area the shot was grabbed from.
        latlon: The target's latitude and longitude, or ``None`` when the theatre has no conversion.

    Returns:
        A JSON-ready mapping.
    """
    return {
        "name": shot.name,
        "title": shot.title,
        "heading_deg": shot.heading,
        "pitch_deg": shot.pitch,
        "slant_m": shot.slant,
        "mark": shot.mark,
        "labels": shot.labels,
        "zone": shot.zone,
        "camera": {
            "position": list(camera.position),
            "forward": list(camera.forward),
            "up": list(camera.up),
            "right": list(camera.right),
            "hfov_deg": HFOV_DEGREES,
        },
        "window": {"width": window[0], "height": window[1], "cropped_bottom": INFO_BAR_PX},
        "target": {
            "x": target[0],
            "z": target[1],
            "alt_m": target[2],
            "lat": latlon[0] if latlon else None,
            "lon": latlon[1] if latlon else None,
        },
        "theatre": info.theatre,
        "date": info.date,
        "time": info.clock,
        "units": [{"kind": u.kind, "group": u.group, "type": u.type, "x": u.x, "z": u.z, "alt": u.alt} for u in units],
    }


def briefing_sidecar(meta: dict[str, Any], order: int) -> dict[str, Any]:
    """Return the keys ``build_mission_briefing`` reads beside a photo.

    The interface is the briefing's (lot FEAT-OBJECTIVE-MISSION-V2): ``zone`` and ``title`` required,
    then the camera's heading, its pitch **negative looking down**, its position in mission
    coordinates (``x`` north, ``y`` east — the mission file's ``y``, the runtime's ``z``), its altitude
    and the order among the shots. Unknown keys are ignored there, so the shot's own metadata stays in
    the same file.

    Args:
        meta: The shot's metadata.
        order: Its rank among the shots.

    Returns:
        The sidecar keys.
    """
    position = meta["camera"]["position"]
    return {
        # a shot taken before FIX-BRIEFING-PARITY-MARTEAU 01 carries "Sasa [r]": read again, it is "Sasa"
        "zone": zone_of(meta.get("zone") or meta["name"]),
        "title": meta["title"],
        "heading": round(meta["heading_deg"]) % 360,
        "pitch": -meta["pitch_deg"],
        "x": position[0],
        "y": position[2],
        "altitude_m": round(position[1]),
        "order": order,
    }


def camera_of(meta: dict[str, Any]) -> Camera:
    """Rebuild the camera from a shot's metadata.

    Args:
        meta: What :func:`shot_metadata` wrote.

    Returns:
        The camera pose.
    """
    cam = meta["camera"]
    return Camera(
        position=tuple(cam["position"]),  # type: ignore[arg-type]
        forward=tuple(cam["forward"]),  # type: ignore[arg-type]
        up=tuple(cam["up"]),  # type: ignore[arg-type]
        right=tuple(cam["right"]),  # type: ignore[arg-type]
    )


# --------------------------------------------------------------------------------------------------
# The shooting mission
# --------------------------------------------------------------------------------------------------

VEAF_CONFIG_MEMBER = "l10n/DEFAULT/veaf-config.lua"

#: Appended to ``veaf-config.lua``: a spawned group keeps its zone and element in its name. At the end,
#: after the mission's own settings: prepended, it was set back to ``true`` a few lines below by the
#: mission's config, and 227 shots out of 236 of the Open Training missions carried a random name
#: (2026-11-17). Nothing spawns before the config has run, so the end is early enough.
_SHOW_NAMES_LUA = """
-- recon-prepare: spawned groups keep their zone's name, for the shots
veaf.HideNamesFromSpawnedGroups = false
"""


def clear_sky(weather: dict[str, Any]) -> dict[str, Any]:
    """Return *weather* with nothing between the camera and the ground.

    Wind and temperature are kept; clouds, precipitation, fog and dust go, visibility is the maximum.

    Args:
        weather: The mission's ``weather`` table.

    Returns:
        A new table.
    """
    clear = dict(weather)
    clouds = {k: v for k, v in (weather.get("clouds") or {}).items() if k != "preset"}
    clouds.update({"density": 0, "iprecptns": 0, "thickness": 200, "base": clouds.get("base", 3000)})
    clear["clouds"] = clouds
    clear["enable_fog"] = False
    clear["fog"] = {"thickness": 0, "visibility": 0}
    clear["enable_dust"] = False
    clear["dust_density"] = 0
    clear["visibility"] = {"distance": 80000}
    return clear


def seconds_of_day(value: str) -> int:
    """Parse ``HH:MM`` into seconds since midnight.

    Args:
        value: The time of day.

    Returns:
        Seconds.

    Raises:
        ValueError: Not ``HH:MM`` with hours 0-23 and minutes 0-59.
    """
    try:
        hours, minutes = (int(part) for part in value.split(":"))
    except ValueError as exc:
        raise ValueError(f"time must be HH:MM, got {value!r}") from exc
    if not (0 <= hours < 24 and 0 <= minutes < 60):
        raise ValueError(f"time must be HH:MM, got {value!r}")
    return hours * 3600 + minutes * 60


def recon_mission_path(miz: Path) -> Path:
    """Return where the shooting copy of *miz* goes: beside it, ``_RECON`` appended."""
    return miz.with_name(f"{miz.stem}_RECON{miz.suffix}")


def derive_recon_mission(miz: Path, out: Path, start_time: str, bridge_lua: Path) -> list[str]:
    """Write the shooting copy of a built mission.

    Args:
        miz: The built mission; never modified.
        out: Where the copy goes.
        start_time: ``HH:MM``, the time of day the photos are taken at.
        bridge_lua: The ``dcs-bridge.lua`` to embed: ``recon-plan`` and ``recon-shoot`` talk to the
            mission through it.

    Returns:
        What was changed, one line each, for the command to print.

    Raises:
        ValueError: *start_time* is malformed, *out* is *miz*, the mission has no VEAF config, or it
            carries the spawn database without loading it.
    """
    from mission_tools.miz_tools import list_members, read_member, read_miz, write_miz  # noqa: PLC0415

    from veaf_libs.dcs_bridge_capture import check_spawn_data_loaded, inject_bridge_in_memory  # noqa: PLC0415

    seconds = seconds_of_day(start_time)
    if out.resolve() == miz.resolve():
        raise ValueError("the shooting mission must not overwrite the mission it is made from")
    members = list_members(miz)
    if VEAF_CONFIG_MEMBER not in members:
        raise ValueError(f"{miz.name} has no {VEAF_CONFIG_MEMBER}: is it a mission built by veaf-tools?")
    check_spawn_data_loaded(read_miz(miz), members)
    config = read_member(miz, VEAF_CONFIG_MEMBER).decode("utf-8")

    shutil.copyfile(miz, out)
    mission = read_miz(out)
    content = mission.mission_content or {}
    content["weather"] = clear_sky(content.get("weather") or {})
    content["start_time"] = seconds
    patched = config.rstrip("\n") + "\n" + _SHOW_NAMES_LUA
    files = inject_bridge_in_memory(mission, bridge_lua)
    files[VEAF_CONFIG_MEMBER] = patched.encode("utf-8")
    write_miz(mission, out, additional_files=files)
    return [
        t("recon.prepare.weather"),
        t("recon.prepare.time", time=start_time),
        t("recon.prepare.names"),
        t("recon.prepare.bridge"),
    ]


# --------------------------------------------------------------------------------------------------
# Shooting
# --------------------------------------------------------------------------------------------------

#: Seconds DCS gets to load the scenery around a new camera position before the order is repeated.
SCENERY_PAUSE = 2.5
#: Seconds after the repeated order, before the grab.
SETTLE_PAUSE = 1.0
#: Seconds the camera first stays on a shot so that DCS loads the terrain, before the positions are read
#: again and the shot taken. After a long jump 2.5 s left 4 Falklands photos out of 26 blurred; 10 s left
#: none (2026-11-17).
WARMUP_PAUSE = 10.0
#: Seconds a combat zone gets to spawn once activated (VEAF spawns it a second later; zone elements with
#: a short ``#spawndelay`` come after).
SPAWN_WAIT = 10.0
#: Seconds for a deactivation to take a zone's units off the map.
DESPAWN_WAIT = 3.0


def shoot_plan(
    plan: ShotPlan,
    out_dir: Path,
    run_server: Callable[[str], Any],
    run_export: Callable[[str], Any],
    grab: Callable[[Callable[[], None]], tuple[Any, tuple[int, int]]],
    latlon_of: Callable[[str, float, float], tuple[float, float] | None],
    sleep: Callable[[float], None],
    progress: Callable[[str], None],
    only: list[str] | None = None,
    warmup: float = WARMUP_PAUSE,
) -> list[dict[str, Any]]:
    """Take every shot of *plan* and write ``<name>.png`` and ``<name>.json`` under *out_dir*.

    A shot on a combat zone of the mission is taken with that zone active alone: every active zone is
    deactivated, the shot's zone activated, its units are the ones it spawned, and it is deactivated
    after. Any other shot takes the units whose name starts with one of its ``groups``.

    The camera first stays *warmup* seconds on the shot, so that the terrain loads; the positions are
    then read again and the camera placed on them, and they are read once more just before the grab,
    for the rings: a boat runs hundreds of metres while the terrain loads (Open Training, 2026-11-17).

    Args:
        plan: The shots.
        out_dir: Where the raw shots go.
        run_server: Runs a chunk in the mission scripting state, returns its reply.
        run_export: Runs a chunk in the ``export`` state.
        grab: Grabs the picture; takes the function that puts the camera back before a retry, and
            returns the image of the whole client area and that area's size.
        latlon_of: ``(theatre, x, z)`` to latitude and longitude, or ``None`` for an unknown theatre.
        sleep: Waits, seconds.
        progress: Told one line per shot.
        only: Shot names to take; all of them when ``None``.
        warmup: Seconds the camera stays on a shot before it is taken; 0 for none.

    Returns:
        The metadata written, one per shot taken. A shot that finds nothing to aim at is skipped and
        said so.
    """
    side = COALITIONS[plan.coalition]
    combat_zones = {zone.name for zone in parse_zones(run_server(ZONES_LUA))}
    info = parse_info(run_server(INFO_LUA))
    out_dir.mkdir(parents=True, exist_ok=True)
    taken: list[dict[str, Any]] = []
    for shot in plan.shots:
        if only and shot.name not in only:
            continue
        zoned = shot.zone in combat_zones
        if zoned:
            run_server(activate_alone_lua(shot.zone))
            sleep(SPAWN_WAIT)
        try:
            meta = _take(shot, side, zoned, info, out_dir, run_server, run_export, grab, latlon_of, sleep, warmup)
        finally:
            if zoned:
                run_server(deactivate_lua(shot.zone))
                sleep(DESPAWN_WAIT)
        if meta is None:
            progress(t("recon.shoot.skipped", name=shot.name, groups=shot.groups or shot.zone))
            continue
        progress(
            t(
                "recon.shoot.taken",
                name=shot.name,
                count=len(meta["units"]),
                width=meta["window"]["width"],
                height=meta["window"]["height"] - INFO_BAR_PX,
            )
        )
        taken.append(meta)
    return taken


def _take(
    shot: Shot,
    side: int,
    zoned: bool,
    info: MissionInfo,
    out_dir: Path,
    run_server: Callable[[str], Any],
    run_export: Callable[[str], Any],
    grab: Callable[[Callable[[], None]], tuple[Any, tuple[int, int]]],
    latlon_of: Callable[[str, float, float], tuple[float, float] | None],
    sleep: Callable[[float], None],
    warmup: float,
) -> dict[str, Any] | None:
    """Take one shot, the zone already activated when *zoned*; ``None`` when there is nothing to aim at."""

    def read() -> list[LiveUnit]:
        units = parse_units(run_server(zone_units_lua(shot.zone) if zoned else UNITS_LUA))
        if zoned:
            units = [u for u in units if u.side == side]
            return [u for u in units if any(u.group.startswith(p) for p in shot.groups)] if shot.groups else units
        return select_units(units, side, shot.groups)

    selected = read()
    if not selected:
        return None
    slant = shot.slant if shot.slant is not None else auto_slant(selected)

    def aim(units: list[LiveUnit]) -> tuple[tuple[float, float, float], Camera]:
        target = target_of(units)
        return target, camera_for(target[0], target[1], target[2], shot.heading, shot.pitch, slant)

    target, camera = aim(selected)
    if warmup > 0:
        run_export(camera_lua(camera))
        sleep(warmup)
        selected = read() or selected
        target, camera = aim(selected)
    order = camera_lua(camera)

    def place(order: str = order) -> None:
        run_export(order)

    place()
    sleep(SCENERY_PAUSE)
    place()
    sleep(SETTLE_PAUSE)
    selected = read() or selected
    image, window = grab(place)
    image = image.crop((0, 0, image.width, image.height - INFO_BAR_PX))
    image.save(out_dir / f"{shot.name}.png")
    taken_as = Shot(
        shot.name, shot.title, shot.groups, shot.heading, shot.pitch, slant, shot.mark, shot.labels, shot.zone
    )
    meta = shot_metadata(
        taken_as, camera, selected, target, info, window, latlon_of(info.theatre, target[0], target[1])
    )
    (out_dir / f"{shot.name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    return meta
