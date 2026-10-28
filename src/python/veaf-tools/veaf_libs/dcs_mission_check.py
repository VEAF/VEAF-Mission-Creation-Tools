"""Check a VEAF mission in a running DCS: its F10 menus, its combat zones and missions, its columns.

What the "Marteau du Golan" session (2026-10-28) did by hand before the mission was flown, and what
found three defects there: a menu entry with an empty label, a combat mission that answered to a
name it was not registered under (a CAP registers as ``<name>/<skill>/<scale>`` variants), and a
column that never moved — its route was "On Road" with no road to follow.

The checks run where the VEAF modules live: the fiddle server the hook starts **inside the mission
scripting environment**, port 12080 (:data:`MISSION_FIDDLE_URL`). Measured 2026-10-28 on "Marteau du
Golan": ``net.dostring_in("server", …)`` through port 12081 sees ``coalition`` and ``env`` but
``veafCombatZone`` and ``veafRadio`` are ``nil`` there, while port 12080 answers ``table`` for both. That
server runs on the mission's own timer, so it does not answer while DCS is paused. The checks run
against the test build the user launched. They change the mission while they run — each zone and each combat
mission is switched on and off — and put every one back as it was found. An *operation* is reported
and not toggled: switching one cascades to its zones and starts a watchdog that would move the
mission on.

Every chunk returns text (``net.dostring_in`` only carries strings), parsed here; all of it is
unit-tested without DCS. :func:`run_checks` orchestrates through injected callables.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass, field

from rich.markup import escape

from veaf_libs.i18n import t
from veaf_libs.lua_literals import lua_quoted_string

#: The fiddle server inside the mission scripting environment, where ``veaf*`` live (``env=default``).
MISSION_FIDDLE_URL = "http://127.0.0.1:12080"
#: The environment to ask of it: its own.
MISSION_ENV = "default"

#: How long a routed group has to start moving.
MOVE_TIMEOUT = 60.0
#: Seconds between two speed readings.
MOVE_POLL = 5.0
#: Seconds a zone or a mission gets to spawn after it is switched on (VEAF schedules it 1 s later).
SPAWN_WAIT = 8.0
#: Seconds for a deactivation to take its units off the map.
DESPAWN_WAIT = 3.0
#: Metres per second above which a group is moving.
MOVING_SPEED = 0.5


# --------------------------------------------------------------------------------------------------
# a. The F10 menu tree
# --------------------------------------------------------------------------------------------------

#: The tree VEAF built, depth first: ``kind<TAB>depth<TAB>title`` per node, where the title is
#: ``=text`` for a string and ``!type`` for anything else (a ``nil`` title is the defect looked for).
MENU_LUA = r"""
if not veafRadio or not veafRadio.radioMenu then return "absent" end
local out = {}
local function title(v)
  if type(v) == "string" then return "=" .. v:gsub("[\t\n]", " ") end
  return "!" .. type(v)
end
local function walk(menu, depth)
  if depth > 15 then return end
  for _, sub in ipairs(menu.subMenus or {}) do
    out[#out + 1] = "menu\t" .. depth .. "\t" .. title(sub.title)
    walk(sub, depth + 1)
  end
  for _, cmd in ipairs(menu.commands or {}) do
    out[#out + 1] = "command\t" .. depth .. "\t" .. title(cmd.title)
  end
end
out[#out + 1] = "menu\t0\t" .. title(veafRadio.radioMenu.title)
walk(veafRadio.radioMenu, 1)
return table.concat(out, "\n")
"""


@dataclass(frozen=True)
class MenuNode:
    """One entry of the F10 tree.

    Args:
        kind: ``menu`` or ``command``.
        path: The titles from the root down to this entry, this one last.
        title: The title, or ``None`` when it is not a string.
    """

    kind: str
    path: tuple[str, ...]
    title: str | None


def parse_menu(text: str) -> list[MenuNode]:
    """Read what :data:`MENU_LUA` returned.

    Args:
        text: The chunk's reply.

    Returns:
        The nodes, depth first; empty when VEAF has no radio menu.

    Raises:
        ValueError: A line is not ``kind<TAB>depth<TAB>title``.
    """
    if not text or text == "absent":
        return []
    nodes: list[MenuNode] = []
    stack: list[str] = []
    for line in text.splitlines():
        fields = line.split("\t", 2)
        if len(fields) != 3 or fields[0] not in ("menu", "command") or not fields[1].isdigit():
            raise ValueError(f"unexpected menu line from DCS: {line!r}")
        kind, depth, raw = fields[0], int(fields[1]), fields[2]
        title = raw[1:] if raw.startswith("=") else None
        shown = title if title and title.strip() else "∅"
        del stack[depth:]
        path = (*stack, shown)
        nodes.append(MenuNode(kind, path, title))
        if kind == "menu":
            stack.append(shown)
    return nodes


def empty_labels(nodes: list[MenuNode]) -> list[MenuNode]:
    """Return the entries a player would see without a label.

    Args:
        nodes: The tree.

    Returns:
        The entries whose title is missing or blank.
    """
    return [node for node in nodes if node.title is None or not node.title.strip()]


# --------------------------------------------------------------------------------------------------
# b. Combat zones and combat missions
# --------------------------------------------------------------------------------------------------

#: Lua helpers shared by the zone and mission chunks: live units of a list of group names / objects.
_COUNT_LUA = r"""
local function aliveInGroup(g)
  local n = 0
  if g and g:isExist() then
    for _, u in ipairs(g:getUnits() or {}) do
      if u:isExist() and u:isActive() and u:getLife() > 0 then n = n + 1 end
    end
  end
  return n
end
local function zoneUnits(zone)
  local n = 0
  for _, name in ipairs(zone:getSpawnedGroups() or {}) do
    local g = Group.getByName(name)
    if g then
      n = n + aliveInGroup(g)
    else
      local s = StaticObject.getByName(name)
      if s and s:isExist() then n = n + 1 end
    end
  end
  return n
end
local function missionUnits(mission)
  local n = 0
  for _, g in pairs(mission:getSpawnedGroups() or {}) do n = n + aliveInGroup(g) end
  return n
end
"""

#: Every combat zone then every combat mission: ``zone|mission<TAB>name<TAB>friendly<TAB>active<TAB>
#: operation<TAB>units``.
INVENTORY_LUA = (
    _COUNT_LUA
    + r"""
local out = {}
local function clean(s) return (tostring(s or ""):gsub("[\t\n]", " ")) end
if veafCombatZone then
  for _, zone in ipairs(veafCombatZone.zonesList or {}) do
    local operation = zone.taskingOrderDict ~= nil
    out[#out + 1] = string.format("zone\t%s\t%s\t%d\t%d\t%d", clean(zone:getMissionEditorZoneName()),
      clean(zone:getFriendlyName()), zone:isActive() and 1 or 0, operation and 1 or 0, operation and 0 or zoneUnits(zone))
  end
end
if veafCombatMission then
  for _, mission in ipairs(veafCombatMission.missionsList or {}) do
    out[#out + 1] = string.format("mission\t%s\t%s\t%d\t0\t%d", clean(mission:getName()), clean(mission:getFriendlyName()),
      mission:isActive() and 1 or 0, missionUnits(mission))
  end
end
return table.concat(out, "\n")
"""
)


@dataclass
class Entity:
    """A combat zone or a combat mission, as the inventory found it.

    Args:
        kind: ``zone`` or ``mission``.
        name: The name VEAF knows it under (a CAP variant reads ``<name>/<skill>/<scale>``).
        friendly: The name players see.
        active: Whether it was active when the check started.
        operation: Whether it is an operation (never toggled).
        units: Live units at inventory time.
    """

    kind: str
    name: str
    friendly: str
    active: bool
    operation: bool
    units: int


def parse_inventory(text: str) -> list[Entity]:
    """Read what :data:`INVENTORY_LUA` returned.

    Args:
        text: The chunk's reply.

    Returns:
        The zones then the missions.

    Raises:
        ValueError: A line does not have the six fields the chunk writes.
    """
    entities: list[Entity] = []
    for line in (text or "").splitlines():
        fields = line.split("\t")
        if len(fields) != 6 or fields[0] not in ("zone", "mission"):
            raise ValueError(f"unexpected inventory line from DCS: {line!r}")
        kind, name, friendly, active, operation, units = fields
        entities.append(Entity(kind, name, friendly, active == "1", operation == "1", int(units)))
    return entities


def switch_lua(entity: Entity, on: bool) -> str:
    """Return the chunk that switches *entity* on or off, silently, as its F10 command would.

    Switching a zone on also wraps that zone's ``spawnElement`` for the time of the check, so each
    group it spawns is recorded in ``veafMissionCheck.mobile`` with whether its element has a route
    (``VeafCombatZoneElement:isMobile``). The wrapper sits on the zone **instance**, is removed once
    the spawned groups are listed (:func:`zone_routed_lua`) or the zone is switched off, and only records — a check that needs a rebuilt mission to know which
    groups should drive would not run on the build the user already has.

    Args:
        entity: The zone or mission.
        on: True to activate, False to deactivate.

    Returns:
        Lua returning ``ok`` or ``unknown``.
    """
    if entity.kind == "mission":
        template = _MISSION_ON_LUA if on else _MISSION_OFF_LUA
    else:
        template = _ZONE_ON_LUA if on else _ZONE_OFF_LUA
    return _named(template, entity.name)


def _named(template: str, name: str) -> str:
    """Put a Lua string literal of *name* where *template* says ``__NAME__``."""
    return template.replace("__NAME__", lua_quoted_string(name))


_MISSION_ON_LUA = """
if not veafCombatMission.missionsDict[(__NAME__):lower()] then return 'unknown' end
veafCombatMission.ActivateMission(__NAME__, true)
return 'ok'
"""

_MISSION_OFF_LUA = """
if not veafCombatMission.missionsDict[(__NAME__):lower()] then return 'unknown' end
veafCombatMission.DesactivateMission(__NAME__, true)
return 'ok'
"""

_ZONE_OFF_LUA = """
local zone = veafCombatZone.GetZone(__NAME__)
if not zone then return 'unknown' end
veafCombatZone.DesactivateZone(__NAME__, true)
zone.spawnElement = nil
return 'ok'
"""

_ZONE_ON_LUA = """
local zone = veafCombatZone.GetZone(__NAME__)
if not zone then return 'unknown' end
veafMissionCheck = veafMissionCheck or { mobile = {} }
zone.spawnElement = function(self, element, now)
  local before = #(self.spawnedGroups or {})
  local result = VeafCombatZone.spawnElement(self, element, now)
  local after = self.spawnedGroups or {}
  for i = before + 1, #after do
    local ok, mobile = pcall(element.isMobile, element)
    veafMissionCheck.mobile[after[i]] = ok and mobile or false
  end
  return result
end
veafCombatZone.ActivateZone(__NAME__, true)
return 'ok'
"""


def count_lua(entity: Entity) -> str:
    """Return the chunk counting *entity*'s live units.

    Args:
        entity: The zone or mission.

    Returns:
        Lua returning the count as text, or ``unknown``.
    """
    template = _MISSION_COUNT_LUA if entity.kind == "mission" else _ZONE_COUNT_LUA
    return _COUNT_LUA + _named(template, entity.name)


_MISSION_COUNT_LUA = """
local m = veafCombatMission.missionsDict[(__NAME__):lower()]
if not m then return 'unknown' end
return tostring(missionUnits(m))
"""

_ZONE_COUNT_LUA = """
local z = veafCombatZone.GetZone(__NAME__)
if not z then return 'unknown' end
return tostring(zoneUnits(z))
"""


# --------------------------------------------------------------------------------------------------
# c. Routed groups
# --------------------------------------------------------------------------------------------------

#: Ground groups the mission file gives a route of more than one waypoint, that are on the map now.
MISSION_ROUTED_LUA = r"""
local out = {}
for _, coa in pairs(env.mission.coalition or {}) do
  for _, country in ipairs(coa.country or {}) do
    for _, group in ipairs((country.vehicle or {}).group or {}) do
      local points = group.route and group.route.points or {}
      if #points > 1 and not group.lateActivation then
        local g = Group.getByName(group.name)
        if g and g:isExist() then out[#out + 1] = group.name end
      end
    end
  end
end
return table.concat(out, "\n")
"""


def zone_routed_lua(entity: Entity) -> str:
    """Return the chunk listing the groups *entity* spawned whose element has a route.

    Also takes the recording wrapper off the zone: what it spawned is on the map by now.

    Args:
        entity: A zone switched on by :func:`switch_lua`.

    Returns:
        Lua returning one group name per line.
    """
    return _named(_ZONE_ROUTED_LUA, entity.name)


_ZONE_ROUTED_LUA = r"""
local zone = veafCombatZone.GetZone(__NAME__)
if not zone or not veafMissionCheck then return '' end
zone.spawnElement = nil
local out = {}
for _, groupName in ipairs(zone:getSpawnedGroups() or {}) do
  local g = Group.getByName(groupName)
  if veafMissionCheck.mobile[groupName] and g and g:isExist() and g:getCategory() == Group.Category.GROUND then
    out[#out + 1] = groupName
  end
end
return table.concat(out, '\n')
"""


def speeds_lua(groups: list[str]) -> str:
    """Return the chunk reading each group's fastest unit, ``name<TAB>m/s`` per line.

    Args:
        groups: Group names.

    Returns:
        Lua source; a group no longer on the map reads ``-1``.
    """
    return _SPEEDS_LUA.replace("__NAMES__", ", ".join(lua_quoted_string(g) for g in groups))


_SPEEDS_LUA = r"""
local out = {}
for _, name in ipairs({__NAMES__}) do
  local g = Group.getByName(name)
  local best = -1
  if g and g:isExist() then
    best = 0
    for _, u in ipairs(g:getUnits() or {}) do
      local v = u:getVelocity()
      local s = math.sqrt(v.x * v.x + v.z * v.z)
      if s > best then best = s end
    end
  end
  out[#out + 1] = string.format('%s\t%.2f', (name:gsub('[\t\n]', ' ')), best)
end
return table.concat(out, '\n')
"""


def parse_speeds(text: str) -> dict[str, float]:
    """Read what :func:`speeds_lua` returned.

    Args:
        text: The chunk's reply.

    Returns:
        Group name to speed in m/s, ``-1`` when the group is gone.
    """
    speeds: dict[str, float] = {}
    for line in (text or "").splitlines():
        name, _, value = line.rpartition("\t")
        if name:
            speeds[name] = float(value)
    return speeds


def parse_names(text: str) -> list[str]:
    """Split a one-name-per-line reply, dropping blank lines."""
    return [line for line in (text or "").splitlines() if line.strip()]


# --------------------------------------------------------------------------------------------------
# d. The report
# --------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Line:
    """One verified fact.

    Args:
        ok: Whether it passed; ``None`` for a line that informs without judging.
        check: Which check: ``menu``, ``zone``, ``mission``, ``route``.
        text: What was measured.
    """

    ok: bool | None
    check: str
    text: str


@dataclass
class Report:
    """Every line, in the order the checks ran."""

    lines: list[Line] = field(default_factory=list)

    def add(self, ok: bool | None, check: str, text: str) -> Line:
        """Record a line and return it."""
        line = Line(ok, check, text)
        self.lines.append(line)
        return line

    @property
    def failures(self) -> list[Line]:
        """The lines that failed."""
        return [line for line in self.lines if line.ok is False]

    @property
    def passed(self) -> bool:
        """Whether nothing failed."""
        return not self.failures


def format_line(line: Line) -> str:
    """Write one line as the console shows it: a mark, the check, the fact.

    The fact is escaped: a spawned group is named ``<zone> [b] <base>#<id>``, and Rich reads ``[b]`` as
    "bold" and swallows it.
    """
    mark = {True: "[green]✓[/]", False: "[red]✗[/]", None: "[dim]·[/]"}[line.ok]
    return f"  {mark} {line.check:<8} {escape(line.text)}"


def verdict(report: Report) -> str:
    """Write the final verdict line."""
    checked = sum(1 for line in report.lines if line.ok is not None)
    if report.passed:
        return t("mission_check.verdict.pass", count=checked)
    return t("mission_check.verdict.fail", failed=len(report.failures), count=checked)


# --------------------------------------------------------------------------------------------------
# Orchestration
# --------------------------------------------------------------------------------------------------


def check_menu(run: Callable[[str], str], report: Report, say: Callable[[Line], None]) -> None:
    """Check a: every F10 entry VEAF built has a label."""
    nodes = parse_menu(run(MENU_LUA))
    if not nodes:
        say(report.add(False, "menu", t("mission_check.line.no_menu")))
        return
    blanks = empty_labels(nodes)
    for node in blanks:
        say(report.add(False, "menu", t("mission_check.line.empty_label", path=" > ".join(node.path))))
    if not blanks:
        say(report.add(True, "menu", t("mission_check.line.menu_ok", count=len(nodes))))


def watch_moving(
    run: Callable[[str], str],
    groups: list[str],
    sleep: Callable[[float], None],
    timeout: float = MOVE_TIMEOUT,
    poll: float = MOVE_POLL,
) -> dict[str, float]:
    """Read the groups' speeds until each has moved or *timeout* has passed.

    Args:
        run: Runs a chunk in the scripting state.
        groups: Group names.
        sleep: Waits, seconds.
        timeout: Seconds to wait at most.
        poll: Seconds between readings.

    Returns:
        Each group's highest speed seen, m/s; ``-1`` when it was never on the map.
    """
    best = dict.fromkeys(groups, -1.0)
    waited = 0.0
    while True:
        for name, speed in parse_speeds(run(speeds_lua(groups))).items():
            best[name] = max(best.get(name, -1.0), speed)
        if all(speed > MOVING_SPEED for speed in best.values()) or waited >= timeout:
            return best
        sleep(poll)
        waited += poll


def _judge_moving(report: Report, say: Callable[[Line], None], owner: str, speeds: dict[str, float]) -> None:
    """Add one route line per group."""
    for name, speed in speeds.items():
        if speed < 0:
            say(report.add(False, "route", t("mission_check.line.left_map", owner=owner, group=name)))
        elif speed > MOVING_SPEED:
            say(report.add(True, "route", t("mission_check.line.moves", owner=owner, group=name, speed=f"{speed:.1f}")))
        else:
            text = t("mission_check.line.frozen", owner=owner, group=name, seconds=f"{MOVE_TIMEOUT:.0f}")
            say(report.add(False, "route", text))


def check_entity(
    run: Callable[[str], str],
    entity: Entity,
    sleep: Callable[[float], None],
    report: Report,
    say: Callable[[Line], None],
) -> None:
    """Check b (and c for a zone): switch the entity on and off, count, watch its columns, restore.

    The order follows the entity's state: an active one is switched off first, then back on — so it
    ends active, as found; an inactive one on first, then off.
    """
    label = f"{entity.name} ({entity.friendly})" if entity.friendly and entity.friendly != entity.name else entity.name
    if entity.operation:
        say(report.add(None, entity.kind, t("mission_check.line.operation", label=label)))
        return

    def switch(on: bool) -> int | None:
        if run(switch_lua(entity, on)) != "ok":
            return None
        sleep(SPAWN_WAIT if on else DESPAWN_WAIT)
        value = run(count_lua(entity))
        return int(value) if value.isdigit() else None

    order = (False, True) if entity.active else (True, False)
    counts: dict[bool, int | None] = {}
    for on in order:
        counts[on] = switch(on)
        if on and counts[on] is not None and entity.kind == "zone":
            routed = parse_names(run(zone_routed_lua(entity)))
            if routed:
                _judge_moving(report, say, entity.name, watch_moving(run, routed, sleep))
    on_count, off_count = counts[True], counts[False]
    if on_count is None or off_count is None:
        say(report.add(False, entity.kind, t("mission_check.line.unknown", label=label)))
    elif on_count == 0:
        say(report.add(False, entity.kind, t("mission_check.line.nothing", label=label, seconds=f"{SPAWN_WAIT:.0f}")))
    elif off_count:
        say(report.add(False, entity.kind, t("mission_check.line.leftovers", label=label, on=on_count, off=off_count)))
    else:
        key = "mission_check.line.ok_left_on" if entity.active else "mission_check.line.ok_left_off"
        say(report.add(True, entity.kind, t(key, label=label, on=on_count)))


def run_checks(
    run: Callable[[str], str],
    sleep: Callable[[float], None],
    say: Callable[[Line], None],
    only: list[str] | None = None,
) -> Report:
    """Run the menu, zone, mission and route checks.

    Args:
        run: Runs a chunk in the mission scripting state and returns its text.
        sleep: Waits, seconds.
        say: Told each line as soon as it is known — the run takes minutes.
        only: Zone or mission names to check; every one when ``None``. The menu and the mission's own
            routed groups are checked either way.

    Returns:
        The report.
    """
    report = Report()
    check_menu(run, report, say)

    routed = parse_names(run(MISSION_ROUTED_LUA))
    if routed:
        _judge_moving(report, say, "mission", watch_moving(run, routed, sleep))

    # Before 6.34.0 a zone an operation lists was registered twice — `addTaskingOrder` called `AddZone`
    # on a zone already added (measured 2026-10-28 on "Marteau du Golan": four zones listed twice) —
    # and a mission built with older scripts still is, so each name is checked once.
    seen: set[tuple[str, str]] = set()
    for entity in parse_inventory(run(INVENTORY_LUA)):
        if (only and entity.name not in only) or (entity.kind, entity.name) in seen:
            continue
        seen.add((entity.kind, entity.name))
        check_entity(run, entity, sleep, report, say)
    return report


def expected_duration(entities: int) -> int:
    """A rough upper bound of the run, minutes, to tell the user before it starts."""
    return math.ceil((entities * (SPAWN_WAIT + DESPAWN_WAIT + 10) + MOVE_TIMEOUT) / 60)
