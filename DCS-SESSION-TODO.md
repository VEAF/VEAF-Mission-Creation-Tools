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

## ⏱ RELEASE GATE — fixes that are shipped and nobody has ever seen work

Added 2026-09-01, taking the inventory of open lots. Three lots (R1–R3) sit at `🧑 waiting-human` with
their **code already merged**: it will go out with the next release whether or not anyone looks at it.
Two of them had no entry in this file at all, so the wait had nowhere to end. Items are appended here
as later lots land in the same state, so read the list rather than a count.

Each item below states what to run, what to look at, and **what each of the two outcomes means** — a
check that cannot come out negative proves nothing.

### R1. A SAM that has locked you must keep its radar long enough to fire

Unblocks [`FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING`](.backlog/FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md),
whose last two boxes are exactly this. The repair is in the artefact VEAF embeds (`VEAF/Skynet-IADS`
commit `3a94937`, carried in by #846): the faulty `isActive() == false` filter is gone from
`src/scripts/community/skynet-iads-compiled.lua`.

**Run**: `verify-mission-c`, the SA-6 site (`Kub 1S91 str` ×1 + `Kub 2P25 ln` ×2) — the same site as
the 2026-08-22 observation. Get locked and stay in the engagement envelope.

- **Fixed**: the launchers rise, stay up, and the site shoots.
- **Not fixed**: they still alternate raise/retract without firing. On 2026-08-22 the period was
  *"toutes les 10 secondes"*; if that cycling is back, note whether the 10 s runs **raise → raise** or
  **raise → retraction**, because the PRD's mechanism predicts 5 s for the second one and the
  difference tells us which constant is wrong.

### R2. One airfield assigned must not disable the other 224

Unblocks [`FIX-WAREHOUSES-INCREMENTAL`](.backlog/FIX-WAREHOUSES-INCREMENTAL/PRD.md) — implemented
2026-08-16, never seen in game. Before the fix, `ensure_airports_populated` filled the airfield table
only when it was **empty**, so the documented MCP workflow (assign one airfield, then build) shipped a
mission with **1 airfield out of 225** usable.

**Run**: a Syria mission, one airfield set blue and one red through the MCP, then
`.\veaf-tools.exe mission build`. In game, try to spawn at a **third**, untouched airfield.

- **Fixed**: the two named airfields carry their coalition and dynamic slots, *and* the untouched ones
  are still usable — that second half is the whole point.
- **Not fixed**: only the airfields you named have slots.

The measured reference from the lot, for comparison: Deir ez-Zor BLUE / Palmyra RED both
`dynamicSpawn = true` with 52 aircraft types, Nicosia untouched NEUTRAL with none.

### R3. The airfields come back on a mission rebuilt from a current version

Unblocks [`FIX-WAREHOUSES-LIST-FORM`](.backlog/FIX-WAREHOUSES-LIST-FORM/PRD.md) — every base turned
neutral in a 6.14.2 build. Shipped in **6.15.0** (#756, published 2026-08-18); the lot has been waiting
on Tripack rebuilding his mission ever since.

Tripack is the reference case and that is his to run, but it does not have to wait for him: rebuilding
any mission that has airfield ownership answers the same question.

- **Fixed**: the airfields hold the coalition the mission declares.
- **Not fixed**: they come out neutral, and 6.15.0 did not carry what we think it carried.

### R4. The `100` (`SmallSizeFighter`) parking type

Already written up at the end of this file — left there, it is a measurement rather than a gate.

### R5. A respawned tanker's escort must be *with* it, not 80 km away

Unblocks [`FIX-ESCORT-RESPAWN-DISTANCE`](.backlog/FIX-ESCORT-RESPAWN-DISTANCE/PRD.md), whose only
remaining box is this one. Repairing the Escort task was already shipped and already proven to run;
what it could not fix is the distance. Measured on 2026-08-28, minutes after a respawn: **78 km and
82 km** between the demo mission's tanker and its escorts, one of them already landed at 14 m —
against the Escort task's own `engagementDistMax` of **60 km**. The escort is now respawned with its
charge, and only then is the task repaired.

**Run**: the session mission, **F10 → ASSETS → Respawn Arco**. Read the escorts' distance to Arco
straight away — the same reading that produced the 78/82 km above.

- **Fixed**: a few hundred metres, in formation. The escort was put back with its charge.
- **Not fixed**: tens of kilometres, or an escort still sitting on a runway. That means the escort was
  not respawned at all, which is a different defect from the one this lot closed.

Then the second half, which is easy to skip and is where the risk actually is: **shoot one escort
down**, then respawn its asset. It should come back *and* escort. This is the only path no unit test
can cover — the mocked `coalition.addGroup` does not register the group it is handed, so nothing off
DCS can show whether the freshly created escort is already findable by the repair that runs a few
instructions later.

Worth expecting, so it is not read as a regression: the escort that comes back is a **fresh** one, so
one that was engaged or damaged is replaced. That is the accepted cost of the design call made on
2026-08-28, not a bug.

**Reminders for whatever mission you build for these**: `security.disabled: true` goes at the **root**
of `mission.yaml`, not under `modules:` (a check that asks for a password cannot be run), and playable
slots are `parking-cold` — never an air start.

---

## ✅ SETTLED — there was no DCS SAM bug (2026-08-22)

**Ground SAMs fire in 2.9.28.26385.** Measured twice on a bare map with no scripts whatsoever:

| Control test | Result |
|---|---|
| Three **SA-15 (Tor 9A331)**, red, alarm red, ROE fire-at-will | locked and fired |
| A complete **SA-6** — 2 × `Kub 1S91 str` + 4 × `Kub 2P25 ln` **in one group** — alarm red, ROE fire-at-will | **fired** |

So the theory this page carried for two days — *"ground SAMs do not engage at all in the current DCS
build"* — was wrong, and the second test is what closes it: the SA-6 is the multi-unit family, the one
whose launchers depend on a separate tracking radar, and it engages normally.

### What the first attempt at that test taught, which is the transferable part

The SA-6 control test **failed on its first run**: locked, launchers inert. The mission had the six
vehicles in **six separate groups**, one unit each. In DCS a SAM site *is* a group — the group's
controller is what hands a target from the radar to a launcher. Four launchers alone have no radar and
never fire; a lone `1S91` has its own radar and locks perfectly with nothing to command. That is
precisely what was seen, and it is indistinguishable from "DCS is broken" unless you look at the group
structure.

Which raises a question worth putting to Sharko rather than assuming: his report was *"j'ai reproduit le
bug sans script aucun, juste 3 sams sur une carte"*, with no mention of how they were placed. If they
were dropped as individual units — the natural thing to do when throwing a quick test together — his
mission had no SAM sites in it at all. **Unverified**, and his to answer.

### What this moves onto us

The cycling seen inside `verify-mission-c` — the SA-6 locks, slews, elevates, then returns to travel
state, five times, without firing — is therefore **ours**. A site that behaves correctly with no scripts
and stands down mid-engagement with Skynet running is being switched off by Skynet. See
[`FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING`](.backlog/FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md).

It also reopens **Tripack's** report of silent zone SAMs on 6.15.2, which had been filed under "DCS is
broken for everyone". It never was.

Items **11** and **16** are fully measurable, with no double reading and no caveat.

## The session mission — built 2026-08-27, twice corrected 2026-08-28

`D:\dev\_VEAF\tmp\dcs-session-2026-08-27\` — **load
`missions\VEAF-session-2026-08-27-escortfix_noon.miz`**, the newest of the three. Caucasus, noon,
`language: fr`, security off, built with `--dev-mode` against the repository so it carries fixes no
release has yet.

Items 21, 22 and 10 were all run on it on 2026-08-28 and are closed — item 21's counts are recorded in
[`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04](.backlog/FIX-PLACEMENT-IGNORES-SCENERY/tickets/04-refuse-the-farp-when-the-escort-cannot-be-placed.md),
item 22's answer in the `scenery-death-events-in-dcs` note and in `DROP-MIST` ticket 09. What remains
here is the mission itself, still the right one to load for anything needing a live VEAF mission on
Caucasus.

⚠️ **Two defects of the 27th's build, both fixed on the 28th — do not reintroduce them.**

1. **It carried two VEAF configurations.** `src/scripts/` held the demo mission's v5 `missionConfig.lua`
   (59 KB, `MISSION_NAME = "VEAF-Demo-Mission"`) *next to* the generated `veaf-config.lua`. Both ran, so
   every module initialised twice and **every radio submenu appeared twice**, the second one inert —
   19 submenus under the VEAF root where there should be 9. Deleting `missionConfig.lua` and rebuilding
   fixed it, confirmed by probing the live menu tree. The repository's own demo mission
   (`test/veaf-tools/demo-mission/src/scripts/`) is clean; the stale file came from extracting a v5
   `.miz`. **Anyone converting a v5 mission will hit this** — worth a guard of its own.
2. It was built before the `findEscortTask` fix, so item 10 could not pass on it.

**The item 10 control is built in and worth keeping**: one escort is named `Arco escort` (matching the
`<asset name> .. " escort"` convention, [`veafMove.lua:37`](src/scripts/veaf/veafMove.lua)) and the other
deliberately left as `Arco-escort1`, so a run can tell a working repair from a silent no-op.

⚠️ **The folders for items 3 and 4 are gone.** `dcs-session-2026-08-14` and `dcs-session-2026-08-24` no
longer exist; `tmp/` holds only the Foothold archives, now **4.7.0** where item 4's text targets 4.4.1.
Those two need rebuilding before they can be run — see `LIRE-MOI.md`.

⚠️ **`mission extract` → `mission build` does not round-trip.** The demo `.miz` stores its members under
lowercase `l10n/default/`, the extractor reproduces that faithfully, and the builder demands
`l10n/DEFAULT/` — it aborts with *"These components are missing … they are mandatory in a DCS
mission!"*. Renamed by hand for this session; worth a lot of its own, since a repository test mission
triggers it.

## An older mission, for items 0 and 0b — both since closed

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

## ✅ 11. Checks 6 and 7 of `verify-mission-c` — verified in game 2026-08-22

`FIX-SKYNET-DYNAMICSPAWN-SCOPE` confirmed: `group added to RED IADS`, and `0 actual reactivations`
on a spawn into a dark network. The cycling seen alongside it is a **different** defect and now has
its own lot, [`FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING`](.backlog/FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md).

---

## ✅ 12. Check 8 of `verify-mission-c` — verified in game 2026-08-22

`FIX-COMBATZONE-DELAYED-COMMAND`: a delayed `#command` dies with its zone.

---

## ✅ 13. Check 12 of `verify-mission-c` — verified in game 2026-08-22

`FIX-CARRIER-MENU-COALITION`: the carrier menu is there from the red side.

---

## ✅ 14. The FARP escort — verified in game 2026-08-24, after five rounds

[#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232), open since 2023 and "fixed" in
6.15.11 by a change that could not work. Confirmed still broken on 2026-08-22, then fixed for real
in #792 — **five** distinct defects, three of them sizing guesses of mine that a measurement would
have killed sooner. David's verdict: *« c'est bon, tout est en dehors du farp statique »*.

The transferable lesson, and the reason this took five in-game rounds instead of one: the placement
logged nothing about **why** it refused a spot, so each hypothesis cost a full DCS reload. It logs
at info now.

---

## ✅ 16. The combat zone alarm state — verified in game 2026-08-22

`FIX-COMBATZONE-ALARM-BY-NATURE`, as far as it was testable: the convoy drives. The armour half
was **not** a valid check — see the withdrawal of item 17 below, which is the same mistake.

---

## 17. ~~A tag on one unit of a group~~ — withdrawn 2026-08-22, the criterion was wrong

[`FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`](.backlog/FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY/PRD.md), 6.15.14.
Closed on unit coverage instead. **Nothing to do in game.**

This check told the tester to activate the zone and watch two M-1 Abrams: *"they stay put"* meant the tag
had been read, *"they drive off"* meant it had not. David ran it and reported the tanks moving — which
turns out to be what happens either way.

`#alarm=2` reduces to `setOption(AI.Option.Ground.id.ALARM_STATE, 2)` in `veaf.readyForCombat`
(`veaf.lua:2117`), reached from `veafCombatZone.lua:1505`. Nothing on that path immobilises a group. A
mobile group with a route drives it under RED exactly as under AUTO, so the two states this check meant to
tell apart are **visually identical for this group**. The observation could not have failed, and could not
have succeeded either.

What the game would have added is only "DCS honours the option", which is not our code. The part that *is*
ours — reading a tag off any unit of the group rather than the first one met — is covered by enumerated
tests over the whole tag family with the tag on the **second** unit
(`test/lua/test_veafCombatZone.lua:1674`, `:1872`).

Also recorded because it cost real time: the zone shows as **"Convoy Test Zone"** in the radio menu, its
`friendly_name`. `SmokeZone` is the trigger-zone name and appears nowhere a player looks.

The lesson worth keeping is not about alarm states. An in-game check is only worth a session if it can
**come out both ways**; this one was written from an assumption about DCS behaviour that was never tested,
and the assumption was wrong. Two waypoints were even added to the group on 2026-08-21 to make the check
possible — and that hand-copied waypoint is what later broke the mission for the DCS editor
([`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`](.backlog/FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS/PRD.md)).
The whole cost came from a check that could never conclude.

## ✅ 18. The dispersion — verified in game 2026-08-22

`FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT`: *« tout est comme prévu »*.

---

## ✅ 19. A convoy walking an itinerary — verified in game 2026-08-22

`FEAT-CONVOY-WAYPOINTS`: the commands work. The ergonomic reservation David raised at the same
time — one command per submenu — was fixed separately in #791.

---

## ✅ 20. The two CSAR-over-water checks — run 2026-08-23

`FEAT-SMOKE-CSAR-WATER`. Worth recording what it actually cost: **five successive defects in the
harness**, each of which read as a product regression and none of which was one — no bridge
injected, bridge and CSAR on different branches, `CSAR: false`, the check calling a function the
replacement had superseded, and an "open sea" defined at 150 m against a 500 m search radius. The
checks pass, and #790 is what made them able to fail.

---

## 3. Confirm a rebuilt checklist picture is not served stale — **prepared 2026-08-24**

[`FEAT-ASSIST-FOLLOWUP` 01](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) shipped the fix: a checklist image's
file name now carries 8 hex of its own content hash, so DCS cannot serve a cached bitmap under a name
it already knows. **No unit test can see DCS's resource cache**, hence this flight.

Four missions are built and waiting, with the full procedure, in
`D:\dev\_VEAF\tmp\dcs-session-2026-08-24\` (`LIRE-MOI.md` + `missions-a-charger\`). F-16C at
Kobuleti parking, cold; **F10 → Assistance → Démarrage à froid** (the missions build `language: fr`),
and the picture appears at state 0 on its own. The marker sits on the highlighted first line:
`AVANT -- cache probe build A` / `APRES -- cache probe build B`.

**Three loads, no DCS restart between them** — a restart clears the very cache under test:

| # | Mission | Must read | What it says |
|---|---|---|---|
| 1 | `2-item3-controle-A-AVANT` | AVANT | the picture enters DCS's cache |
| 2 | `3-item3-controle-B-APRES` | **AVANT** (stale) | DCS still caches by file name → the check means something |
| 3 | `4-item3-corrige-B-APRES` | APRES | the fix works |

**Why a control pair at all**, and the reason this is three loads rather than one: missions 1 and 2 are
built normally and then rewritten back to the **pre-fix** naming (`assist-f16c-cold-start-0.png`, no
digest) in both the archive and `mapResource` — two different pictures under one name, the artefact the
bug was made of. Without them, mission 3 showing the right text would be equally consistent with "the
fix works" and with "DCS stopped caching between 2.9 builds", and we would not know which. If step 2
reads APRES, the check is void and step 3 proves nothing.

Measured on the built files: the fixed pair changes **7 file names out of 7** with the label while
keeping identical resource keys (so a label edit does not move the mission's Lua, which was the design
constraint); the control pair shares **7 out of 7**.

## 4. Confirm the staggered script loading — **prepared 2026-08-24, and half of it is already answered**

[`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`](.backlog/archive/FEAT-CUSTOM-SCRIPT-LOAD-DELAY.md) is ✅ and verified
against the real Foothold Caucasus 4.4.1 `.miz`, but never watched in game.

**The staging itself no longer needs DCS.** Foothold Caucasus 4.4.1 was adopted fresh today and the
built `.miz` was read back: `Mission scripts loading - static` carries 8 files at t=0,
`- delayed 3s` carries 5, `- delayed 12s` carries AIEN alone — exactly the upstream table. The mission
runs in **static** mode (both selector triggers `return false`), so those are the triggers that execute,
and the generated `veafDynamicConfig.lua` schedules the same delays, so the documented claim that both
modes stage alike holds. Nothing left to look at there.

**What the game still has to say is the PRD's own open question:** does the delay change anything? The
lot settled it by reading code — AIEN inventories ground groups once, at load, and Foothold creates part
of its groups from t+2 s — but never measured it.

AIEN's log cannot answer: its line that would count each inventoried group is **commented out** upstream
(only MLRS-with-guidance and unidentified-class groups log), and it writes no total. So
`1-item4-foothold-echelonnement.miz` (same folder as item 3) carries an instrument in
`mission-script.lua` that counts ground groups at t=0, +3 s, +12 s and +30 s.

Load it, take any slot, let it run 40 s, quit, and grep `dcs.log` for `VEAF-PROBE` (five lines) and
`STATIC Mission scripts loading` (three, for their timestamps).

- count at +12 s **equal** to t=0 → the upstream staging is caution, and the lot is a fidelity nicety;
- count at +12 s **higher** → AIEN at t=0 was demonstrably shown fewer groups, and the lot delivered a
  correctness fix as it claimed.

Either way it is a result, which is why it is worth the load.

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

---

## ✅ 23. CSAR sans MiST — vérifié en jeu le 2026-08-31, et il a trouvé deux défauts

Les quatre étapes passées : pilote abattu créé (`Wounded Pilot #200084`, identifiant de
l'allocateur VEAF), message radio `requests SAR at bullseye 333 for 62, beacon at 300.00 KHz`,
direction « 2 heures » recoupée par un calcul indépendant, et ramassage effectif. `mist` était
`nil` du début à la fin.

Deux défauts trouvés au passage, qu'aucun des 3950 tests ne voyait : l'assertion de dépendance
s'exécutait au chargement, là où `veaf` ne peut pas encore exister ; et un groupe créé en vol
n'avait pas de pays, ce qui cassait **tout** téléport de groupe dynamique. Détail complet dans
`.backlog/REFACTOR-CSAR-WITHOUT-MIST/PRD.md`.

## ✅ 24. Skynet sans MiST — vérifié en jeu le 2026-08-31, sans un seul décollage

Piloté par le hook fiddle plutôt que volé, David n'ayant pas de matériel sous la main — et c'est
mieux tombé ainsi : les deux morceaux risqués sont du comportement dans le temps, qui se mesure
mieux qu'il ne se regarde.

Ordonnanceur exact (13 exécutions en 26 s à 2 s d'intervalle), annulation propre, défense HARM qui
éteint **et rallume** à l'échéance, 13 sites SAM et 8 radars EW recensés par préfixe, site créé en
vol vu immédiatement. Le piège MiST a mordu 31 fois, **31 fois depuis `dcs-bridge.lua`** (l'outil
d'observation lui-même) et **zéro depuis Skynet**.

Détail complet, y compris mes deux fausses alertes de méthode, dans
`.backlog/REFACTOR-SKYNET-WITHOUT-MIST/PRD.md`.


---

## Le type d'emplacement `100` (`SmallSizeFighter`) — à regarder en jeu

Ouvert par `CHORE-AIRCRAFT-STAND-TYPES` (PR #865), qui a élargi `AIRCRAFT_STAND_TYPES` à
`{68, 72, 104}` sur des mesures et a **laissé `100` dehors**, faute de pouvoir trancher sans DCS.

Ce qui est établi, et qui n'appelle pas de vérification :

- `100` n'existe que sur **11 aérodromes syriens**, qui ont **tous** déjà du `68`/`104` — l'inclure
  ne débloquerait donc **aucun** aérodrome ;
- **aucune** des missions mesurées (Foothold ×3 théâtres, Open Training Syria) n'y gare quoi que ce
  soit — 105 avions garés, aucun sur du `100` ;
- DCS le documente comme une place étroite pour petit appareil, et le masque officiel
  `FighterAircraftSmall` le contient bien.

**La seule question ouverte est physique** : un appareil lourd tient-il sur un `100` ? Un C-130 ou
un B-52 posé là passe-t-il, ou clippe-t-il dans le décor ?

Comment vérifier, si l'occasion se présente : sur un des 11 aérodromes syriens concernés, poser
dans l'éditeur un gros porteur sur un stand de type `100` et charger la mission. S'il apparaît
proprement, `100` peut rejoindre l'ensemble ; s'il clippe ou refuse, la constante reste comme elle
est et **la raison est enfin sourcée** plutôt que déduite de l'absence de contre-exemple.

Sans enjeu : personne n'attend ce changement, il n'ouvrirait aucun terrain. C'est une vérification
de confort, à faire si une session DCS a du temps de reste.

---

## 25. The FARP escort on clear ground must not move — unblocks `FIX-PLACEMENT-IGNORES-SCENERY` 04

Opened by [`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](.backlog/FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md),
whose code fix and tests landed 2026-09-01. Item 21's own non-regression case failed on 2026-08-28: a
`-farp` on open ground, nothing within a kilometre, logged `FARP escort: bearing 0 requested, 25 used at
1.054x distance`. Tier 1 of `findClearBearing` selected out of `Disposition`'s cloud before testing the
requested bearing, and the wanted spot is never one of the cloud's candidates.

Three markers, on the session mission rebuilt with `--dev-mode` against the fix. Grep `dcs.log` for
`FARP escort:` and `findClearBearing:`.

| Marker | Case | Expected |
|---|---|---|
| open ground, nothing within a kilometre | the non-regression | bearings **equal**, `1x`, plus `bearing N is inside a scenery-clear area, keeping it` |
| in or beside a wood | the reason tier 1 exists | bearings **differ**, escort visibly out of the trees |
| beside a static FARP | the reason the occupancy probe still decides | bearings differ or scale above 1, escort off the apron |

**A run where nothing moves in any of the three is a failure, not a pass** — it would mean the fix
turned tier 1 off. The last two rows are the half that makes this a real check.

`no usable point in Disposition's cloud, walking the bearings instead` now logs at **info**, so the
old instruction to set `veafGrass.LogLevel = "debug"` for this no longer applies.

Full protocol: [ticket 02](.backlog/FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/tickets/02-verify-in-game-that-nothing-moves.md).
