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
        groups: Group or static name prefixes; the units whose name starts with one are the target.
        heading: Engagement heading, degrees on the mission's grid — the direction the camera looks.
        pitch: Degrees below the horizon.
        slant: Camera-to-target distance, metres.
        mark: ``groups`` for one ring per group, ``units`` for one per vehicle.
        labels: Label per type name (``units``) or per group prefix (``groups``); otherwise the type.
        zone: The combat zone the shot illustrates, as the briefing's objectives name it; by default the
            zone the first prefix belongs to.
    """

    name: str
    title: str
    groups: list[str]
    heading: float = 0.0
    pitch: float = 30.0
    slant: float = 1000.0
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
        ValueError: The file lacks ``shots``, a shot lacks ``name`` or ``groups``, a ``mark`` is not
            ``groups`` or ``units``, or the coalition is unknown.
    """
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    coalition = str(data.get("coalition", "red")).lower()
    if coalition not in COALITIONS:
        raise ValueError(f"coalition must be red or blue, not {coalition!r}")
    shots: list[Shot] = []
    for entry in data.get("shots") or []:
        if not entry.get("name") or not entry.get("groups"):
            raise ValueError(f"a shot needs a name and groups: {entry!r}")
        mark = entry.get("mark", "groups")
        if mark not in ("groups", "units"):
            raise ValueError(f"{entry['name']}: mark must be groups or units, not {mark!r}")
        shots.append(
            Shot(
                name=str(entry["name"]),
                title=str(entry.get("title") or entry["name"]),
                groups=[str(g) for g in entry["groups"]],
                heading=float(entry.get("heading", 0.0)),
                pitch=float(entry.get("pitch", 30.0)),
                slant=float(entry.get("slant", 1000.0)),
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


def plan_from_units(units: list[LiveUnit], side: int, operation: str) -> dict[str, Any]:
    """Write a starter shots plan: one shot per zone of *side*, to be edited before shooting.

    The engagement heading cannot be guessed — it is the mission's plan of attack — so every shot
    starts at heading 0 and the file says to set it. The slant range grows with the zone's spread, so
    a battery and a brigade both fill the frame.

    Args:
        units: Every live unit.
        side: Coalition photographed.
        operation: The operation's name, for the banner.

    Returns:
        The plan as a mapping ready to dump to YAML.
    """
    zones: dict[str, list[LiveUnit]] = {}
    for unit in units:
        if unit.side == side:
            zones.setdefault(zone_of(unit.group), []).append(unit)
    shots: list[dict[str, Any]] = []
    for index, (zone, members) in enumerate(sorted(zones.items()), start=1):
        cx, cz, _ = target_of(members)
        spread = max(math.hypot(u.x - cx, u.z - cz) for u in members)
        shots.append(
            {
                "name": f"{index:02d}-{_slug(zone)}",
                "title": zone,
                "groups": [zone],
                "heading": 0,
                "pitch": 30,
                "slant": int(max(600.0, round(spread * 3 / 50) * 50)),
            }
        )
    return {"operation": operation, "coalition": {v: k for k, v in COALITIONS.items()}[side], "shots": shots}


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

#: Prepended to ``veaf-config.lua``: a spawned group keeps its zone and element in its name, so a
#: shot's ``groups`` prefixes can find it. Before anything spawns, hence at the top.
_SHOW_NAMES_LUA = "-- recon-prepare: spawned groups keep their zone's name, for the shots\nveaf.HideNamesFromSpawnedGroups = false\n\n"

#: Appended to ``veaf-config.lua``, after the zones are initialised: every combat zone up. An operation
#: is left alone — activating one activates its zones anyway, and it would start its watchdog.
#:
#: Five seconds later, once per name, and only a zone not already active. Measured on "Marteau du
#: Golan" (2026-10-28) with an immediate loop: every zone on the map two or three times over.
#: ``ActivateZone`` marks a zone active only when its scheduled activation runs a second later, so the
#: zones started by ``active_at_start`` and by the operation still read inactive; and, in a mission
#: built with scripts older than 6.34.0, a zone an operation lists is in ``zonesList`` twice.
_ACTIVATE_ALL_LUA = """
-- recon-prepare: every combat zone active at start, for the reconnaissance photos
if veafCombatZone then
    timer.scheduleFunction(function()
        local done = {}
        for _, zone in ipairs(veafCombatZone.zonesList) do
            local name = zone:getMissionEditorZoneName()
            if not zone.taskingOrderDict and not done[name] and not zone:isActive() then
                done[name] = true
                veafCombatZone.ActivateZone(name, true)
            end
        end
    end, nil, timer.getTime() + 5)
end
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
        ValueError: *start_time* is malformed, *out* is *miz*, or the mission has no VEAF config.
    """
    from mission_tools.miz_tools import list_members, read_member, read_miz, write_miz  # noqa: PLC0415

    from veaf_libs.dcs_bridge_capture import inject_bridge_in_memory  # noqa: PLC0415

    seconds = seconds_of_day(start_time)
    if out.resolve() == miz.resolve():
        raise ValueError("the shooting mission must not overwrite the mission it is made from")
    if VEAF_CONFIG_MEMBER not in list_members(miz):
        raise ValueError(f"{miz.name} has no {VEAF_CONFIG_MEMBER}: is it a mission built by veaf-tools?")
    config = read_member(miz, VEAF_CONFIG_MEMBER).decode("utf-8")

    shutil.copyfile(miz, out)
    mission = read_miz(out)
    content = mission.mission_content or {}
    content["weather"] = clear_sky(content.get("weather") or {})
    content["start_time"] = seconds
    patched = _SHOW_NAMES_LUA + config.rstrip("\n") + "\n" + _ACTIVATE_ALL_LUA
    files = inject_bridge_in_memory(mission, bridge_lua)
    files[VEAF_CONFIG_MEMBER] = patched.encode("utf-8")
    write_miz(mission, out, additional_files=files)
    return [
        t("recon.prepare.weather"),
        t("recon.prepare.time", time=start_time),
        t("recon.prepare.zones"),
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
) -> list[dict[str, Any]]:
    """Take every shot of *plan* and write ``<name>.png`` and ``<name>.json`` under *out_dir*.

    Args:
        plan: The shots.
        out_dir: Where the raw shots go.
        run_server: Runs a chunk in the mission scripting state, returns its reply.
        run_export: Runs a chunk in the ``export`` state.
        grab: Grabs the DCS window; takes the function that puts the camera back before a retry, and
            returns the image (cropped to the client area) and the client area's size.
        latlon_of: ``(theatre, x, z)`` to latitude and longitude, or ``None`` for an unknown theatre.
        sleep: Waits, seconds.
        progress: Told one line per shot.
        only: Shot names to take; all of them when ``None``.

    Returns:
        The metadata written, one per shot taken. A shot whose groups match nothing is skipped and
        said so — the zone may simply not be active.
    """
    side = COALITIONS[plan.coalition]
    units = parse_units(run_server(UNITS_LUA))
    info = parse_info(run_server(INFO_LUA))
    out_dir.mkdir(parents=True, exist_ok=True)
    taken: list[dict[str, Any]] = []
    for shot in plan.shots:
        if only and shot.name not in only:
            continue
        selected = select_units(units, side, shot.groups)
        if not selected:
            progress(t("recon.shoot.skipped", name=shot.name, groups=shot.groups))
            continue
        target = target_of(selected)
        camera = camera_for(target[0], target[1], target[2], shot.heading, shot.pitch, shot.slant)
        order = camera_lua(camera)

        def place(order: str = order) -> None:
            run_export(order)

        place()
        sleep(SCENERY_PAUSE)
        place()
        sleep(SETTLE_PAUSE)
        image, window = grab(place)
        image = image.crop((0, 0, image.width, image.height - INFO_BAR_PX))
        image.save(out_dir / f"{shot.name}.png")
        meta = shot_metadata(
            shot, camera, selected, target, info, window, latlon_of(info.theatre, target[0], target[1])
        )
        (out_dir / f"{shot.name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        progress(t("recon.shoot.taken", name=shot.name, count=len(selected), width=image.width, height=image.height))
        taken.append(meta)
    return taken
