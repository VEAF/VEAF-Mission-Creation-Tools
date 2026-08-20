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
