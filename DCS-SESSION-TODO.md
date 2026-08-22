# What to do next time DCS is running

Everything the backlog is waiting on that **needs DCS started** — nothing here can be done from a
keyboard on a workstation without the game. Each item says what to run, what to look at, and what it
unblocks, so a session can be worked through without re-reading the whole backlog.

**Tick a line off by deleting it**, and update the ticket it names. `.backlog/README.md` stays the
source of truth for scope and status; this file is only the running order for a session in front of
the game.

Written 2026-08-12, reordered 2026-08-14 when items 0 and 0b arrived — they gate a release, so they
come first.

---

## ⚠️ READ FIRST — SAMs do not fire in DCS 2.9.28 (2026-08-20)

**Ground SAMs do not engage at all in the current DCS build.** Not a VEAF defect, not a Skynet defect:
Sharko reproduced it on a bare map with **three SAMs and no scripts whatsoever** — *"j'ai reproduit le
bug sans script aucun, juste 3 sams sur une carte"* — and reports the same on the BFR server, where
nothing fires any more. It appeared with the latest DCS update. Measured build here: **2.9.28.26385**.

Tripack's report of silent SAMs in combat zones is the same thing seen from inside a mission. His
discriminator — works outside a zone, fails inside — looked meaningful and was a coincidence.

**What this blocks, and it is the point of this warning:**

| Item | Why it cannot conclude right now |
|---|---|
| **11** — Skynet checks 6 and 7 | both read whether a SAM joins a network *and behaves*; a SAM that never fires cannot show it |
| **16** — the combat zone alarm state | its whole point is "the battery must light its radars and engage" |

Do **not** read a silent SAM as a regression of ours while this lasts. The convoy half of item 16 is
still measurable — a convoy either drives or it does not — so that one can be checked and the battery
half deferred.

**Before trusting either item again:** put three SAMs on an empty map with no scripts and fly at them.
If they fire, DCS is fixed and the items are measurable. If they do not, nothing on this page about SAMs
means anything.

---

## A mission is ready for items 0 and 0b

`D:\dev\_VEAF\tmp\dcs-session-2026-08-14\TestMenuFR.miz` — Caucasus, `language: fr`, with the modules
that build menus (RADIO, SPAWN, COMBATZONE, ASSETS, WEATHER, NAMEDPOINTS, MOVE, TRANSPORTMISSION,
CASMISSION, SHORTCUTS, SECURITY) and security **left on**.

**It embeds the repository's scripts, not the published ones**, and that matters: release 6.13.0 has
none of these fixes, so a mission built the ordinary way would show the old behaviour and read as
"the fix does not work". Verified before shipping it here — the embedded bundle contains
`ZONES DE COMBAT`, `APPARITION`, `Activer la mission` and `menu.combatzone.root`, and its
`veaf-config.lua` declares `veaf.config.language = "fr"`.

**Utiliser `TestMenuFR-fixed.miz`**, à côté, et non `TestMenuFR.miz` : la première corrige les trois
défauts mesurés le 2026-08-15 sur la seconde — l'A-10 marqué `dynSpawnTemplate`, sa radio coupée, et un
démarrage à 03:48 ([ticket 04](.backlog/archive/FIX-SCRATCH-MISSION-PLAYABLE.md)). Tout
le reste est identique, octet pour octet.

Rebuild it, if needed, with:

```bash
veaf-build build --version 6.13.100 --skip-python
```

then from the mission folder:

```bash
veaf-tools mission build TestMenuFR . --dev-mode --scripts-path D:/dev/_VEAF/VEAF-Mission-Creation-Tools
```

## ✅ 0. The F10 menu reads French — verified in game 2026-08-14

David, in front of the game: the labels are correct. The 90 localised labels of
[`FIX-RADIO-MENU-I18N`](.backlog/archive/FIX-RADIO-MENU-I18N.md) are confirmed, and the release is no
longer gated on this. Kept as a line rather than deleted because it is the release's evidence.

## ✅ Le slot A-10 du 2026-08-14 : `dynSpawnTemplate`

David, en jeu : *"je le prends, et je reste spectateur"*. Le différentiel contre l'A-10 qu'il a ajouté
lui-même dans l'éditeur (mission `-david`) donne :

| | mon script (ko) | éditeur (ok) |
|---|---|---|
| `dynSpawnTemplate` | **`true`** | **`false`** |
| `communication` / `frequency` | `false` / 121.5 | `true` / 251 |
| `skill` | `Client` | `Player` |
| ids | 9001 | 9003 |
| parking | `43` / `16`, `airdromeId` 24 | `6` / `01`, `airdromeId` 22 |

`dynSpawnTemplate = true` ne décrit pas un slot : il désigne le groupe comme **modèle de spawn
dynamique**, ce qui suppose une base aérienne configurée pour ça — cette mission n'en a aucune. J'avais
copié le groupe depuis la démo avec son drapeau. David l'avait dit dès le premier jour : *"il n'y a que
des templates de groupe, et pas de base aérienne configurée pour les slots dyn"*.

**`skill` est innocenté** : David, 2026-08-15 — *"c'est pas le slot Client ; ça fonctionne dans une
mission DCS"*. Les ids forcés aussi (l'éditeur écrit 900x lui-même), et la paire parking, complète des
deux côtés. Consigné dans
[`FIX-SCRATCH-MISSION-PLAYABLE` 03](.backlog/archive/FIX-SCRATCH-MISSION-PLAYABLE.md).

**`TestMenuFR-fixed.miz`** corrige les trois défauts (drapeau, radio, midi), et **le slot a été pris en
jeu le 2026-08-15** — *"le A-10 fonctionne"*. Le correctif est donc mesuré, pas supposé, et cette
mission est celle à utiliser pour la suite de la session.

### Reste de la session

- **0b** — l'avertissement de dépréciation dans `dcs.log`, qui doit être **absent**.
- **1** — la capture parking, 5 min par carte. Débloque le ticket 09 *et* la moitié au sol du slot
  joueur.
- Les items 2 à 8 inchangés ci-dessous.

---

## ✅ 0b. Les deux correctifs de sécurité — vérifiés en jeu 2026-08-15

Tous deux issus de [`FIX-DOCAUDIT-CODE`](.backlog/archive/FIX-DOCAUDIT-CODE.md) (PR #730). Gardés comme
preuve de release plutôt que supprimés.

- **Les noms de paliers passent.** `dcs.log` ne contient **aucun** avertissement de dépréciation — la
  migration des 24 déclarations vers `ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT` est donc complète. Le
  message qu'on cherchait est celui de [`veafSecurity.lua:112`](src/scripts/veaf/veafSecurity.lua:112),
  émis une seule fois par ancien nom rencontré.
- **`_transport` et le pilote listé.** Éprouvé le 2026-08-14 : la commande refuse bien, et l'essai a
  fait tomber un **second** défaut — le message affiché trois fois — corrigé depuis par la PR #735.

⚠️ **#735 n'est pas dans `TestMenuFR-fixed.miz`** : cette mission embarque les scripts du dépôt tels
qu'ils étaient le 2026-08-14, donc avant ce correctif. Pour vérifier que le message ne s'affiche plus
qu'une fois, reconstruire la mission d'abord.

## ✅ 1. La capture parking — faite le 2026-08-15

Caucasus, Syria et PersianGulf : **276 aérodromes, 6521 places**, dans
`veaf_build/dcs_data/airbase_dumps/parking/`. Le ticket
[08](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md) est clos.

Ce que la donnée a **révélé, et qui bloque le 09** : `Term_Index_0` vaut `-1` sur les 6521 places,
donc `parking_id` **ne vient pas** de cette capture — voir l'item 9 ci-dessous. Au passage, `Term_Type`
change de jeu de valeurs d'une carte à l'autre (PersianGulf n'a aucun `68`, Syria est seule à avoir
`100`). D'autres cartes peuvent être capturées à l'identique : `tmp\bridge-maps\collect\` contient
aussi des missions pour GermanyCW, MarianaIslands, Normandy et SinaiMap.

## 🔎 9. D'où vient `parking_id` ? — débloque le ticket 09

[`FEAT-MCP-MUTATION-ACTIONS` 09](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md)
(*"un deux-ship de F-16 sur la ramp à Incirlik"*) a besoin de `parking` **et** `parking_id` pour un
départ au parking. La capture donne `parking` (= `Term_Index`) et la **position exacte** du stand, mais
**pas** `parking_id` (`Term_Index_0` = -1 partout, et les paires parking/parking_id des vraies missions
n'ont aucune fonction dérivable). David, 2026-08-15 : investiguer d'abord, ne rien deviner.

Deux mesures à faire, dans cet ordre :

1. **D'où sort `parking_id`.** Dans l'éditeur, poser 3-4 avions sur des stands **connus** d'un même
   aérodrome (p. ex. Kobuleti), sauver, et me donner pour chacun `(parking, parking_id)` + le stand
   visé. Je corrèle à `Term_Index` et à la position de la capture : soit `parking_id` correspond à
   quelque chose de capturable (alors on étend la capture du ticket 08 pour le sortir), soit il est
   interne à l'éditeur et il faut l'obtenir autrement.
2. **Est-il indispensable si la position est exacte ?** Je te prépare une mission bâtie via
   `add_player_slot` avec la position + `parking` capturés et `parking_id` = `parking` ; tu la charges
   et tu regardes si l'avion se pose sur le bon stand. Si DCS se cale sur la position quoi qu'il
   arrive, un départ ramp n'a pas besoin du vrai `parking_id` et le 09 est débloqué tel quel ; s'il
   déplace l'avion ou refuse, le 09 attend le vrai `parking_id` de l'étape 1.

Rien à lancer côté outils pour l'étape 1 (c'est de l'éditeur) ; pour l'étape 2 je fabrique la mission
quand tu me diras que tu es en jeu.

## ✅ 2 et 2b — faits le 2026-08-15

Les deux aller-retours dans l'éditeur ont eu lieu. Résultats consignés dans
[`FIX-MCP-EDITOR-ROUNDTRIP`](.backlog/archive/FIX-MCP-EDITOR-ROUNDTRIP.md) (4 tickets) et dans le
[ticket 07](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md), qui donne naissance au
[ticket 10](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md).

Ce que l'éditeur a **gardé** : le groupe déplacé de 6 km avec sa route, le renommage, l'emport, la
ligne et l'étiquette sur la couche Blue, le waypoint retiré avec son reverrouillage d'heure — et la
**zone à 6 sommets**, ce qui tranche une question ouverte : `edit_zone` ne doit pas se mettre à
refuser au-delà de 4.

Ce qu'il a **jeté** : la tâche `Bombing`, écrite avec 6 paramètres là où une vraie en porte 11.

Ce qu'il a **recalculé** : le cap d'un avion en vol, remplacé par l'`atan2` du premier segment de sa
route, à la septième décimale. DCS recalcule, il ne casse rien.

Les cinq formes de dessin sont mesurées (`bridge-Syria-editeur.miz`) — et il y en avait cinq, pas six.

Ce qui reste de l'item 2, non fait : **voler** la route avec sa tâche d'attaque (l'éditeur l'ayant
supprimée, ça attend le correctif du ticket 01), et le rebuild qui confirme qu'un dessin survit à une
reconstruction depuis le dossier.

<details>
<summary>Consigne d'origine de l'item 2, conservée pour le prochain aller-retour</summary>

## 2. Open a mutated mission in the Mission Editor

The acceptance criterion of
[`FEAT-MCP-MUTATION-ACTIONS` 02 and 03](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md), and the only half
no test can cover — `FIX-MAPRESOURCE-KEY` is what a plausible-looking write the editor rejects costs.

Take any built `.miz`, then through the MCP (or a Python call):

- `set_unit_properties` — change a loadout and a heading on one aircraft.
- `set_group_properties` — move a group **that has a route** a few km, and rename another.

Then open it in the ME and **save it**. What to watch for: no complaint on load, the moved group's
route still attached to its units, the loadout as asked, and — the one that would be silent — the
group still where you put it after the save.

Four more edits ship in the same lot and want the same pass, each with one thing that could be
silently wrong:

- `edit_route` — add a waypoint with an **attack task**, then *fly it*. The editor accepting a task
  table is not proof DCS runs it, and a flight that quietly does nothing is this ticket's worst case.
  Also remove the route's only ETA-locked waypoint and check the mission still **saves** (the action
  re-locks the first, which is what `FIX-WAYPOINTS-ETA-LOCKED` says DCS itself does).
- `edit_zone` — reshape a combat zone into a polygon with **more than four vertices**, save, reopen.
  The VEAF runtime handles any polygon through mist, but the ME has **no UI** for a non-quad zone, so
  whether it preserves or flattens the shape is unknown. If it flattens it, the action should refuse
  above four rather than warn.
- `add_map_drawing` — place a line and a textbox on the **Blue** layer, and check red cannot see them.
- The **rebuild**: build the mission from its folder again and confirm the drawing is still there. That
  is the entire reason drawings are not left to the editor.

## 2b. Measure the five drawing shapes that no mission here contains

`FEAT-MCP-MUTATION-ACTIONS` ticket 07 ships three shapes — line, rect, textbox — because those are the
only field layouts present in any `.miz` in this repository. `circle`, `oval`, a free-form `Polygon`,
`arrow` and `icon` are **refused by name** rather than guessed, since inventing a layout is
what `FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` both cost.

**It was six until 2026-08-15**, when David opened the editor and found no `chevron` tool. That name
came from a table of proposed verbs, never from a measurement — so the list that exists to stop
invented shapes was carrying one of its own. Removed from the code, the test and the ticket.

Five minutes in the editor closes it: draw **one of each** on any layer, save, and send the `.miz` (or
just its `mission` file). Each shape is then a table entry, not an investigation.

</details>

## 11. Re-run checks 6 and 7 of `verify-mission-c` — the Skynet IADS fixes

[`FIX-SKYNET-DYNAMICSPAWN-SCOPE`](.backlog/FIX-SKYNET-DYNAMICSPAWN-SCOPE/PRD.md) shipped in 6.15.8:
written, 48 new unit tests, three guards mutation-checked. What no unit test can see is Skynet's own
behaviour inside a running DCS, so the two checks that measured the defects are what confirm the fixes.
The instrumentation is **already in the mission's `mission-script.lua`** — the `group added /
delayedActivate / reactivation` counters that produced the original measurements.

The mission needs `dynamic_spawn: true` under `modules.SKYNET` — that field is new, and it replaces the
`module_settings: { veafSkynet.DynamicSpawn: true }` hatch the verification mission used. Rebuild it
before the session or the run measures 6.15.7.

- **Check 6 (#151)** — activate a combat zone holding a standard DCS SAM group, read the Skynet monitor.
  Expected: the SAM joins the red network, as it already did. This one is a **regression check**: the
  path worked, and the lot must not have broken it while making the flag reachable.
- **Check 7 (#261)** — deactivate the red network, then `-samlr, country russia` by map marker nearby.
  - **Before**: `group added → delayedActivate called → RED IADS REACTIVATED`.
  - **Expected now**: `group added`, and **no** `delayedActivate`, **no** reactivation. The SAM is
    attached; the network stays down. Then `veafSkynet.activateNetworkOfCoalition(coalition.side.RED)`
    brings it up **with** that SAM in it.
- **Worth adding while there, since it is the fourth defect and has never been in game**: with
  `dynamic_spawn` on, drop a `-hv_convoy_red`. Its Tor and Tunguska are in Skynet's database, and the
  shortcut passes `skynet false`. Expected: the convoy does **not** appear in the network's element
  list. Before the fix it did.
- ⚠️ **Do not read an element's `isActive()`** to decide whether a network is up — it reports whether
  that radar is emitting, a Skynet SAM stays dark by design until it has a contact, and
  `SkynetIADS:deactivate()` never touches that state. That cost two rounds during the original session.

## 12. Check 8 of `verify-mission-c` — a delayed `#command` dies with its zone

[`FIX-COMBATZONE-DELAYED-COMMAND`](.backlog/FIX-COMBATZONE-DELAYED-COMMAND/PRD.md) shipped in 6.15.9.
The zone `DelayZone` of that mission already carries **one fake unit per delay mechanism**, side by
side, which is what makes the difference observable rather than argued.

Activate the zone, wait past the delay so both SAMs are up, then **deactivate it**.

- **Before**: the `#command="-samsr!30"` SAM stayed alive after deactivation; the `#spawndelay` one died.
- **Expected now**: both die.

Two more, worth a minute each since they are the paths #66 never mentioned and no pilot has ever
exercised:

- a `#command="-spawn group, name sa6, delay 30"` — same expectation, different deferring path.
- a `#command` with a repeat (`repeat 3, delay 10`): **every** spawned group must die with the zone, not
  just the first. That one was lost before and nobody had noticed.
- and the race: activate, then deactivate **during** the delay. The group that appears afterwards must
  be destroyed on sight rather than left running — look for `spawned […] after its zone was deactivated`
  in `dcs.log`.

## 13. Check 12 of `verify-mission-c` — the carrier menu, from the red side

[`FIX-CARRIER-MENU-COALITION`](.backlog/FIX-CARRIER-MENU-COALITION/PRD.md) shipped in 6.15.10. Take the
**red A-10 at Palmyra** — the slot the defect was measured from on 2026-08-18 — and open the F10 menu.

- **Before**: *CARRIER OPS* held both **CARRIER OPS - BLUE** and **CARRIER OPS - RED**, and the red pilot
  could start and stop the blue carrier's recovery window.
- **Expected now**: only **CARRIER OPS - RED**. The shared *CARRIER OPS* root is still there (it carries
  the help entry), and so is its help command.

Then take a blue slot and confirm the mirror image: **CARRIER OPS - BLUE** only.

Worth one extra look while there, because it is what the fix leans on: open the red menu down to a
carrier's own submenu and its commands. Those are children of the scoped menu and inherit the scope
rather than declaring it, so a leak would show up there rather than at the top.

## 14. The FARP escort, on the mission that reproduced it

[`FIX-FARP-ESCORT-PLACEMENT`](.backlog/FIX-FARP-ESCORT-PLACEMENT/PRD.md) shipped in 6.15.11. Use
`test/veaf-tools/verify-mission-a`, the mission the defect was reproduced on 2026-08-17 (screenshot on
[#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232)).

- **The case that failed**: drop a `-farp` marker ~150 m from the static FARP, as before.
  - **Before**: the escort came down on the static FARP's pads, the lead `M 818` close enough to a
    helipad to meet a landing helicopter.
  - **Expected now**: the escort is on clear ground, still close to the FARP. `dcs.log` shows
    `findClearBearing: moved from … to …`.
- **The regression that matters more than the fix**: drop a `-farp` in **open ground**, far from
  anything. It must look exactly as it always did — 150 m out on the FARP's heading, no message in the
  log. The original bearing is tried first precisely so that working missions do not move.
- **Worth a look while there, never seen in game**: a `FARP_T` unit. Its props used to be laid out at the
  non-FARP distances (escort 75 m, tent 100 m, windsock 50 m/45°); it should now measure like any other
  FARP (150 / 200 / 120 m). This is the second defect of the lot and no pilot has ever exercised it.
- If a mission logs `unknown FARP-like type [...]`, that is the new warning doing its job — send me the
  type name, it belongs in `veafGrass.FARP_PLATFORM_TYPES`.

## 16. The combat zone alarm state — both natures, before publishing

[`FIX-COMBATZONE-ALARM-BY-NATURE`](.backlog/FIX-COMBATZONE-ALARM-BY-NATURE/PRD.md), 6.15.13. This one
gates the release: #290 was measured in game, and this changes what that measurement produced.

In a combat zone holding **both** a SAM battery and a convoy, activate the zone:

- **The convoy must still drive its route.** That is #290, fixed in 6.15.5, and the regression to watch —
  it matters more than the new half.
- **The battery must light its radars and engage.** On 6.15.5 through 6.15.12 it stayed silent, which is
  the defect being fixed here.
- Then `#alarm=0` on the battery: it should go quiet again, since an explicit tag still wins.

Worth knowing while looking: this is **not** Tripack's report. He saw silent zone SAMs on 6.15.2, which
predates the AUTO default entirely, so his case is still unexplained and this check does not close it.

## 17. A tag on one unit of a group — `verify-mission-a`, and it is cheap

[`FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`](.backlog/FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY/PRD.md), 6.15.14.
Same mission as item 14, so it costs nothing extra once that one is loaded. **Not blocked by the SAM
problem** — nothing here needs anything to fire.

`SmokeZone-SmokeArmor` is two M-1 Abrams with a two-point route, and only the **second** unit carries
`#alarm=2`:

```
SmokeZone-SmokeArmor Unit #001
SmokeZone-SmokeArmor Unit #002 #alarm=2
```

Activate `SmokeZone` from the F10 menu and watch those two tanks for 60 seconds:

- **they stay put** → the tag on unit #002 reached the group. Fix confirmed.
- **they drive off** towards `(-30220, 407386)` → the tag was ignored and the group fell back to AUTO.

Why the route was added on 2026-08-21, since it changes what the mission holds: with a single waypoint
the group counts as static, so `FIX-COMBATZONE-ALARM-BY-NATURE` already gives it RED and `#alarm=2` was
indistinguishable from no tag. Both Abrams were tagged before, too, which dodged the very defect the
check was supposed to expose. Now the default is AUTO and RED can only come from the tag.

While there, `SmokeZone-ConvoyBlue` (3 M 818) still has no tag and must still drive — that is item 2 of
the mission's own README and the regression to watch.

## 18. The dispersion nothing has had since 2023 — same mission again

[`FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT`](.backlog/FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT/PRD.md),
6.15.15. Third check on `verify-mission-a`, after items 14 and 17, so it costs nothing extra. **Not
blocked by the SAM problem.**

`DefaultSpawnRadiusForUnits = 50` was dead from 2023-03-04 to 2026-08-21, so every group of every combat
zone appeared exactly on its recorded position. It applies again, and the one thing a unit test cannot
answer is whether 50 m of dispersion drops a unit somewhere impossible.

Activate `SmokeZone` and look at where the groups come up:

- **`SmokeZone-ConvoyBlue` and `SmokeZone-SmokeArmor` are scattered**, not lined up on their editor
  positions → the default applies.
- **Nothing is inside scenery** — no truck in a building, no tank on a slope it cannot leave. The
  anchor `(-32220, 405386)` is documented empty desert, so a failure here would be a surprise worth
  reporting.
- Deactivate and reactivate: the groups should come up in *different* spots. That is the point of
  dispersion, and it is the only way to see it is really random rather than a fixed offset.

If a placement needs to be exact, `#spawnradius=0` on the group is the escape hatch — worth trying once
on `SmokeZone-SmokeArmor` to confirm it still pins the group.

**Second thing to look at, now that it is fixed rather than expected.**
[`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](.backlog/FIX-COMBATZONE-SPAWN-ROUTE-OFFSET/PRD.md) shipped in
6.15.20: waypoint 1 now follows the group, so `SmokeZone-ConvoyBlue` should **set off along its route
from wherever it came up**, with no detour back to its editor position first. That detour is what the
defect looked like, and seeing it would mean the fix did not take.

The rest of the track is deliberately **not** moved, so check the convoy still joins the drawn route
rather than driving a track shifted sideways.

**Third thing, and it needs no extra setup.** Does the group come up on its drawn position give or take
the dispersion, or noticeably further? A displacement well beyond 50 m was
[`FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`](.backlog/FIX-COMBATZONE-SPAWN-REFERENCE-UNIT/PRD.md), fixed in
6.15.21: a zone anchored a group on the first unit it could *see*, so a group with its unit 1 outside
the trigger zone came up offset by its own intra-group spacing. Both fixes are unit-tested; what no test
can say is whether a group now lands somewhere impossible.

If `verify-mission-a` has no group straddling a zone edge, that case is untested in game — dragging one
truck of `SmokeZone-ConvoyBlue` just outside the zone before the run would cover it, and the group
should still come up on its drawn position rather than a truck-length away.

## 19. A convoy walking an itinerary — new in 6.15.22, and cheap to check

[`FEAT-CONVOY-WAYPOINTS`](.backlog/FEAT-CONVOY-WAYPOINTS/PRD.md). Both things its PRD wanted measured in
game turned out to be dependencies the lot could simply not have (see the PRD), so what is left is the
ordinary check: does a real convoy on real terrain actually get where it is going?

Place two markers and drop this on the first:

```
_spawn convoy, dest <second marker>, dest <a third point>, speed 40
```

- The convoy **sets off again by itself** on reaching the first point. The watch runs every 30 s and the
  arrival radius is 150 m, so allow up to half a minute after it stops before concluding anything.
- **"Hold at next point"** must let it finish the leg it is on and park *there* — not brake on the spot.
  **"Halt where it stands"** must stop it immediately, mid-road. Those two are the point of the feature;
  if they feel the same in play, the wording needs work, not the code.
- On the last leg, "Hold at next point" should tell you there is no next point.

Worth noting how the 150 m radius feels on a long column: if a convoy visibly parks well short of its
point and still counts as arrived, that number wants revisiting.

## 20. Run the two CSAR-over-water checks — no aircraft needed

[`FEAT-SMOKE-CSAR-WATER`](.backlog/FEAT-SMOKE-CSAR-WATER/PRD.md), 6.15.26. **Not a flying item**: it is
the smoke harness, so it needs DCS running with a mission loaded and nothing else. It is on this page
only because launching a run in your DCS is yours to do.

```bash
poetry run veaf-tools dcs smoke-test
```

The two new checks are `csar-avoids-water-open-sea` and `csar-avoids-water-coast`. They anchor on the
first airbase, sweep outwards for water, spawn a CSAR pilot there, read back what is under him, and
destroy the group.

**The prediction has flipped, and that is the point of running it now.** When these checks were written,
reading `csar.spawnGroup` said both would fail: a fixed `+50/+50` offset with no surface test. The fix
shipped in 6.15.28 — [`FIX-CSAR-SPAWNS-ON-WATER`](.backlog/FIX-CSAR-SPAWNS-ON-WATER/PRD.md), on your
arbitration of 500 m or dead — so **both should now pass**.

A failure here means the replacement of `csar.addCsar` is not taking effect in a real mission, which unit
tests cannot tell you: they prove the decision, not that DCS loads the wrapper.

One thing to watch on the open-sea check: with nothing dry within 500 m the pilot is now **lost**, so
there is no group to inspect. The check reports `no-group` in that case, which is a *pass* for the
arbitration and a *failure* for the assertion as written — if you see it, tell me and I will teach the
check the difference rather than have you interpret it.

## 10. Watch a respawned escort for longer than ten minutes

[`FIX-ESCORT-RESPAWN-TASK`](.backlog/FIX-ESCORT-RESPAWN-TASK/PRD.md) is written and unit-tested, but
the defect is a DCS behaviour the mocks do not model: an `Escort` task whose `groupId` no longer
resolves. Only the game can say whether the repair takes.

Rerun **check 9 of `verify-mission-c`**: F10 → Assets → Respawn Arco, then watch its escort.

- **Before the fix**: the escort holds for a while, then leaves to land after ~10 minutes.
- **Expected now**: it stays with the tanker. David watched the teleport path hold for 30 minutes on
  2026-08-18, so that is the bar.

⚠️ **Watch past the ten-minute mark.** The failure is a *delayed* RTB — a short look would have called
the old behaviour fixed. That is the whole reason this cannot be a five-minute check.

Also worth a glance in `dcs.log`: `Re-establishing the escort task of <group> onto group id <n>`. If
that line is absent, the escort group is not named `<asset> escort` and the convention is what to
check first (it is now documented on the ASSETS page).

## 3. Confirm a rebuilt checklist picture is not served stale

[`FEAT-ASSIST-FOLLOWUP` 01](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) shipped the fix: a checklist image's
file name now carries 8 hex of its own content hash, so DCS cannot serve a cached bitmap under a name
it already knows. **No unit test can see DCS's resource cache**, hence this flight.

Edit a checklist step's text, rebuild, and fly it **without restarting DCS**. The old bug read as
*"the text is wrong, but only on the first image"*.

## 4. Confirm the staggered script loading

[`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`](.backlog/archive/FEAT-CUSTOM-SCRIPT-LOAD-DELAY.md) is ✅ and verified
against the real Foothold Caucasus 4.4.1 `.miz`, but never watched in game.

Build an adopted Foothold and check `dcs.log`: 6 scripts at start, 5 around +3 s, AIEN at +12 s. The
thing that matters is AIEN seeing a **populated** world — Foothold creates part of its groups from
t+2 s onwards, and loading AIEN at t=0 shows it an empty one **with no log error**.

## 5. Fly the F-14B(U) startup checklist

[`FEAT-ASSIST-AUTHORING` 06](.backlog/FEAT-ASSIST-AUTHORING/tickets/06-f14b-manual.md) — written,
resolved, and its four automatic steps already verified in game on 2026-08-03. All that is left is
your verdict on whether the procedure matches what you actually do.

## ✅ 6. The smoke harness's remaining slice — closed 2026-08-15

[`FEAT-DCS-SMOKE-HARNESS`](.backlog/archive/FEAT-DCS-SMOKE-HARNESS.md) — locate, launch, load, quit.
The runner shipped; the unattended single-player load was **dropped rather than built** — DCS does
not document it, David's call. Nothing left here.

This is the lever that pays: run once on 2026-08-06 it closed `FEAT-COMBATZONE-MENU-COALITION` (open
since July) and turned `Disposition` from assumed into existing.

## ✅ 7. Test a token on the fiddle-server port — validated in game 2026-08-15

[`FIX-SECREV2-EXPIRED-DEFERRALS` 02](.backlog/archive/FIX-SECREV2-EXPIRED-DEFERRALS.md) — **VMR-013**, and
it is a live security hole rather than a nicety: the port executes arbitrary Lua from unauthenticated
HTTP, and with `cors='*'` plus a GET channel, any web page visited while the hook is installed gets
code execution.

It was deferred for want of a DCS to test a token on, over the transport the smoke harness speaks
through — and the harness has since run in game, so the dependency is live.

## 8. Two lower-priority pilot items

- [`FEAT-ASSIST-FOLLOWUP` 02](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — whether an
  `a_cockpit_highlight` leaks into another cockpit. Needs **a second pilot**; the per-session id
  exists for it and has never been exercised.
- [`FEAT-ASSIST-FOLLOWUP` 03](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — an F-16C pilot's review of the
  six shipped steps. The engine was flown and works; the *procedure* was never checked by a pilot.
