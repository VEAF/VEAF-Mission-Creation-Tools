# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

> **6.15.34 does not exist.** It was reserved for the entry below while its PR was open, and the CSAR
> fix that merged first took 6.15.35 instead. The number was never released; nothing is missing.
>
> That is the failure mode this section exists to prevent. **A pull request adds its entry under
> `[Unreleased]` and does not touch the version**; the release commit renames the heading and moves
> `pyproject.toml` with both agent manifests. Add new entries at the **end** of the section: two PRs
> appending merge cleanly far more often than two PRs prepending.

## [Unreleased]

### Changed

- **A pull request no longer bumps the version, and writes its changelog entry under
  `[Unreleased]`.** The rule used to require a PATCH bump on every change, so any two concurrent PRs
  conflicted by construction — on `pyproject.toml`, both agent manifests and the `CHANGELOG.md`
  heading, none of which carries engineering content. Of the 10 merges following 6.16.0, 9 touched
  the changelog and 8 touched the version files; one documentation-only PR needed three rebases in
  one hour, renumbering 6.16.5 → .8 as `develop` took each number first.

  The numbers bought little: 6.16.0 consolidated **47 patch versions, none of which was ever
  published** — nobody could install 6.15.34. The version now moves only in the release commit,
  with both manifests, which is what `.claude/commands/release.md` always described: its step 1 read
  an `[Unreleased]` section that had not existed since the 6.15.0 release, and its step 4 renamed a
  heading that was not there. Three documents described three different processes; they now describe
  one, and a test fails if a release forgets to re-open the section.

- **Every DCS event was delivered to VEAF twice.** `veafEventHandler.initialize()` registers the
  handler with DCS, and it runs twice on every mission: the script initialises itself on load, so a
  mission generating no `veaf-config.lua` still handles events, and the generated `veaf-config.lua`
  initialises it again with the other modules. Both calls are deliberate; registering the handler
  twice was not — so every callback behind it ran twice: two radio menu rebuilds on a birth, two QRA
  evaluations, two FARP warehouse refills.

  It stayed invisible because the consumers that would show it carry idempotence guards of their own,
  which is how this kind of defect ends up blamed on DCS. Found while diagnosing an unrelated report,
  and measured rather than inferred: a test counting the registrations reports 1 where the old code
  reported 2. Guarded inside `initialize()` rather than by deleting one of the two calls — each
  covers a case the other does not, and a third caller would bring the defect back.

## [6.16.10] — 2026-08-26

### Fixed

- **A mission could lose every FARP and carrier as a CTLD loading point, silently.** CTLD 2 knows
  which units are loading points from `logisticUnitTypes` / `troopZoneShipTypes`, and it ships them
  **empty** — the right default for the wider world, the wrong one for a VEAF mission, which
  registered carriers and FARP ammo dumps automatically for years. `mission prepare` filled those
  lists at scaffold time and never again, so any other route to a `ctld-config.yaml` — written by
  hand, copied from another mission, regenerated from the CTLD defaults in ctld-tools — arrived with
  both empty and nothing said so. Observed on a real mission: `CTLDZoneManager ready — troop:0
  logistic:0`.

  The symptom is confusing because it is partial: FOBs spawned in flight keep working, they go
  through `registerFOBAsLogistic`; the FARPs placed in the editor do not.

  New `modules.CTLD.manage_logistics` (default **true**): at build time the VEAF types are **merged
  into** whatever the mission declares, on the way into the `.miz`. Union, never overwrite —
  replacing the lists would rebuild the silent-discard defect ADR 0016 removed, on anyone who added
  a modded carrier of their own. The mission maker's file is never rewritten, and the generated
  `CTLD_userConfig.lua` records what was added. Set the flag to `false` to own those two lists
  entirely; if that leaves both empty, the build says so loudly rather than starting a mission with
  no loading point at all. ADR 0016 is amended: two of its statements stop being true.

---

## [6.16.9] — 2026-08-26

### Fixed

- **The welcome brief never fired on a server: the handler read the wrong shape of `initiator`.**
  Reported on a mission built with 6.16.0, the release that introduced the feature.
  `veafEventHandler` hands callbacks the **data table** `completeUnitFromName` returns — `unitName`,
  `unitType`, … and no methods — but `veafWeather.onPlayerEnterUnit` tested `initiator.getName`, so
  it returned on every event it received, before its own log line. Hence total silence rather than an
  error, and hence a feature that only a dynamic-slot unit (a raw DCS object, no mist table entry)
  could ever have triggered.

  Diagnosed statically: the bundled scripts carried the whole feature, the module was enabled, every
  module initialised after it logged, the pilot had flown — and three server sessions carried not one
  `welcome brief` line, though that line is `INFO` for exactly this question.

  `veafQraCore` and `veafGrass` already read `unitName` first with `:getName()` as the dynamic-slot
  fallback, inline, in both. That logic is now `veafEventHandler.unitNameFromEvent()` and the three
  callers share it. The tests missed the defect because they handed the handler a DCS object mock, a
  shape the event handler never produces; the runtime shape is now covered, and the object mock kept
  for the dynamic-slot path.

---

## [6.16.8] — 2026-08-25

### Documentation

- **The CTLD documentation never said where to get `ctld-tools`.** Every other part of the procedure
  was covered in both languages — the sidecar file, the two traps, the rejected `settings:` block —
  but not the first step: obtaining the editor. The guide said "shipped with CTLD" and linked the
  repository, while the executable is a *release asset*, and every CTLD 2 release is published as a
  **pre-release** — so none appears as "Latest release" and following that link does not lead to the
  file. The guide now has a "where to get `ctld-tools`" section with the releases page, the asset
  name, that pre-release trap, and how to read the CTLD version your install ships (the header of
  `published/src/scripts/community/CTLD.lua`) so the tool matches the engine. Added to the
  prerequisites table, linked from the YAML reference and the migration guide, and the builder's
  "no `ctld-config.yaml` found" message now carries the download URL instead of naming a tool the
  reader cannot locate.

---

## [6.16.7] — 2026-08-25

### Fixed

- **The one message that teaches a command taught the wrong one.** When an order is addressed to an
  autopilot that does not exist, the module answers by saying how to create one — the fix that replaced
  eight silences with useful answers. But the command it gave was `_ground set, name arty-1`, and `_ground`
  was dropped from the documentation the same day `_gc` shipped. The form is still accepted so no existing
  mission breaks, but nothing documents it any more. That made this the worst possible place for a stale
  syntax: a pilot reads this message precisely because he does not know what to type. It now says
  `_gc arty-1, set`.

  Swept rather than searched: the family is "a message that teaches a command", not "a message mentioning
  `_ground`". All fourteen registered marker keyphrases were read out of the modules and crossed with every
  value in the catalogue — three messages teach a command (`_cas`, `_move`, and this one), and only this one
  was stale. The sweep ships as a test, so a message teaching an unregistered keyphrase now fails the suite,
  and the two tests that asserted the literal string `_ground set` read the module's own constants instead.

---


## [6.16.6] — 2026-08-25

### Fixed

- **`groupname` never found a group a VEAF command had spawned, and silently replaced it with whatever
  stood nearest.** The `_gc` marker's parameter looked the name up **exactly**, but
  `veaf.getNameForSpawnedGroup` decorates the name of anything a command creates: `-arty, unitname arty-1`
  produces a group DCS calls `[b]-arty-1#7`. So `groupname arty-1` always missed, and the parameter only
  ever worked on groups placed in the mission editor — not on the ones a pilot has just spawned, which is
  the artillery case.

  The miss was worse than a miss: an unfound name fell back on the nearest-allied-group search and attached
  the autopilot to whatever stood within 250 m of the marker, with no message either way. A fragment of the
  name is now enough; if several groups match, the command is refused and the names found are said, rather
  than one being picked at random; and a name that designates nothing stops the command instead of
  designating something else. Only `set` and `unset` are concerned — `status` with a mistyped `groupname` is
  still answered.

  Also fixed, and the reason no test could see any of this: `coalition.getGroups` returned `{}` in the test
  mocks while `Group.getByName` found registered groups, so nothing could exercise code that enumerates
  groups.

---


## [6.16.5] — 2026-08-25

### Fixed

- **A sanctuary zone posted its two land SAM sites at the same spot, with the same radius.** Only the
  heading differed. Its three neighbouring blocks in the same function all spread their second piece —
  2000 then 3000 metres on water, 3000 then 4000 in both hardened waves, and always moving to the later
  position — so the intended values were legible from them. Recorded as a *question* when it was spotted,
  because two sites at one point with different headings is a defensible layout; confirmed unintended and
  fixed.

  The tests assert the **property** rather than the numbers — the two pieces of a wave differ, and the
  second spreads wider — across all four blocks, including the ones that were already right. That is what
  makes the symmetrical mistake fail too: aligning the water block on the wrong one of the two.

---

## [6.16.4] — 2026-08-25

### Fixed

- **An artillery battery left its position after every fire mission, so the next order found it driving.**
  The fire task hard-coded `counterbattaryRadius = 500`, which the DCS API describes as the radius the
  group *"will move in random directions after completing the fireAtPoint task"* — counter-battery
  evasion. Realistic for a single mission, ruinous for an adjustment loop: the ranging shot goes out, the
  guns scatter, and the order for effect arrives on a group in motion. **A gun does not fire while it is
  driving.** It is now zero, behind a named constant that carries the reason so nobody puts 500 back
  meaning well.

  The correction arithmetic was never wrong — it works on the *target*, not on where the guns stand. Only
  the firing was prevented.

  Nothing had ever asserted the task handed to DCS: not the scatter radius, not the two axes, not the
  `expendQtyEnabled` flag without which DCS ignores the round count. Six tests now read that exact table.
  (found in game)

- `coord.LLtoMGRS` in the shared test doubles returned a table **without `UTMZone`**, which real DCS
  always provides. Any code building a readable grid reference concatenates it and died on a nil as soon as
  a test reached that path — an incomplete double does not fail the code that reads it, it crashes
  somewhere else.

---

## [6.16.3] — 2026-08-25

### Fixed

- **`-arty1` and its siblings could not command the battery they had just spawned.** The alias answered
  "no allied group within 250 m of the marker" while the battery stood right under it. The alias entry
  point computes the **opposing** coalition — an alias usually expands to a spawn, and a marker spawns
  against you — and handed that single value to every module in the chain, including the ground-AI module,
  which uses it as the side of the **allied** group to look for. A blue pilot spawned a blue battery and
  then searched for a red one. The same order typed by hand worked, because that route derives the
  coalition from the player.

  Two coalitions now travel the chain: the spawn side for what gets created, the requester side for
  modules that look for the pilot's own groups. Callers that pass no requester — the mission-start batch,
  the remote path — fall back to the previous value, so nothing else changes behaviour.

  Three of the five mutations killed nothing at first, and all three were wiring: the entry point that
  computes the value, the batch loop that forwards it, and the delayed path that stores it in its argument
  table. The batch one mattered doubly — **`-arty1` is a batch**, so that was the exact path of the
  reported defect. (found in game)

---

## [6.16.2] — 2026-08-25

### Fixed

- **The new `_gc` marker did nothing at all: it never reached the module.** A marker command handler
  registers with a **keyphrase filter**, and the dispatcher only calls it for texts containing that word.
  The filter takes a single string, so `_gc …` was never handed to the ground-AI module — the marker just
  stayed on the map, silent. The module now registers once per keyphrase.

  It shipped that way with 163 green tests, and none of them could see it: every one called
  `executeCommand` or the parser **directly**, so nothing covered whether anything calls *them*. Five
  tests now inspect the declared filters instead of the handler, and removing the second registration
  fails three of them. (found in game)

---

## [6.16.1] — 2026-08-25

### Added

- **A shorter, flatter way to command a ground unit: `_gc`.** The addressee comes first, the way you
  would say it on the radio, and there is one separator instead of two:

  ```
  _gc arty-1, aim 37T GG 12345 12345
  _gc arty-1, correction 09050
  _gc arty-1, fire, shells 40-80, radius 50-150
  ```

  No more `name`, no more `order`, no more `target`, and **no more semicolon**. That semicolon was not a
  style choice: the marker text is cut at every comma, so the value of `order` ended at the next comma and
  the order own parameters had to use something else. Teaching the marker the order own words — `aim`,
  `fire`, `correct`, `target`, `shells`, `radius`, `correction` — is what makes one separator enough.
  `_gc` stands for *ground commander*.

  `_gc arty-1` on its own creates the autopilot from the nearest allied group, as `_ground set` did — and
  unlike `_ground`, the short form genuinely works: the page claimed bare `_ground` was the same as
  `_ground set`, and it was not. Measured, `_ground, name arty-1` was refused.

  The fifteen shipped `-arty*` and `-ai_set` alias definitions now write the new form. `_ground` and its
  nested syntax still work, undocumented, so no existing mission breaks.

### Fixed

- **A completed operation's briefing printed its own translation key.** Opening the briefing of a finished
  combat operation showed the literal text `combatzone.operation_complete` where the congratulations
  should have been — and the operation's name was dropped with it, because the code called
  `string.format` on the key instead of `veaf.t`, and a key contains no `%s` to put the name in. The same
  constant was already used correctly in the event message forty lines below, which is why only the
  briefing was affected and nobody had noticed. (found in game)

---

## [6.16.0] — 2026-08-24

**Released.** This version consolidates the forty-seven patch versions from **6.15.5 to 6.15.52**, whose
detailed entries follow below and are left untouched. Nothing new is recorded here — this heading exists
so the changelog says which version shipped, and what it contained.

Four changes can alter the behaviour of missions that already worked; they are set out in
`RELEASE_NOTES.md` before anything else. In short: every latitude/longitude written in degrees, minutes
and seconds moves by about 31 metres (it was wrong before), a misspelt marker option is now refused in
every command rather than only in `_spawn`, the mission validator refuses more missions, and waypoint
injection now reaches every human slot instead of one in 105.

---

## [6.15.52] — 2026-08-24

### Fixed

- **Eight `_ground` commands did nothing and said nothing.** Six verbs — `unset`, `start`, `stop`, `clear`,
  `status` and `order` — looked up a named autopilot with no `else` branch, so a name nobody had registered
  produced no action and no message, its only trace a `trace`-level log line invisible at the default
  level. Two more silences sat around them: `set`/`unset` finding no allied group within 250 m of the
  marker aborted without a word, and an order text that could not be parsed at all was dropped in silence.
  Each of the eight now answers, and the answer says what to do — the autopilot message names the
  `_ground set` that would create one, the range message offers `groupname`, and the order message lists
  the valid orders.

  Found in game: an order to `arty-1` after a mission reload — which discards the autopilots — vanished
  with no way to tell "the autopilot is gone" from "my coordinates are wrong" from "the module is broken".

---

## [6.15.51] — 2026-08-24

### Fixed

- **Every latitude/longitude written in degrees, minutes and seconds was about 31 metres off.** The reader
  accumulated arc-seconds from `-1` instead of `0`, so each DMS coordinate came out exactly one arc-second
  short — since 2021, in every mission, and not only for artillery: this is the single coordinate reader
  for AirWaves zones, ground-AI targets, named points, QRAs and the shortcut aliases. A test had even
  recorded the offset as "by design" and widened its tolerance to accept it.

### Added

- **Coordinates can now be written the way DCS shows them.** `37T GG 12345 12345`, copied off the F10 map
  with its spaces, is accepted as it stands — no `u` prefix, no retyping. Retranscribing a grid reference
  is exactly how shells end up in the wrong village. The MGRS digit count is the precision, from 10 km at
  two digits a side down to one metre at five, and an **odd** digit count is now refused rather than
  silently halved into a position nobody asked for.
- **Degrees, minutes and seconds can be separated however a pilot writes them** — spaces, or the `°`, `'`
  and `"` symbols, alongside the `:` and `-` that already worked. Degrees with decimal minutes
  (`N42:30.5E041:45.5`), the form charts and kneeboards use, is read correctly too.
- The accepted formats are now documented, with their precision, on the veafGroundAI page in both
  languages.
- **A coordinate written longitude-first is now refused instead of silently transposed.** `E041N42` used
  to be accepted and come back as latitude 41, longitude 42 — the two values the wrong way round, with no
  warning. Refusing is the whole argument of this change: a coordinate nobody can read is a message on
  screen, a coordinate quietly transposed is a shell in the wrong village.

---

## [6.15.50] — 2026-08-24

### Fixed

- **The welcome brief still said nothing, and adding the birth event had not been enough.** In single
  player the pilot occupies his slot **before** the mission's scripts load, so his birth event fires
  before this module (load order 210) can subscribe to anything — the timing was the problem, not the
  event name, and changing slot restarts the mission in single player so the second attempt lost the same
  race. The brief now **looks at who is already flying** shortly after it initializes, instead of only
  waiting to be told. The subscription stays for pilots joining a running server later; both paths share
  a once-per-slot rule so nobody hears the runway twice. (found in game, 2026-08-24)

---

## [6.15.49] — 2026-08-24

### Fixed

- **The welcome brief said nothing at all**, on an airfield and on a carrier alike. It listened only for
  `S_EVENT_PLAYER_ENTER_UNIT`, and DCS does **not** raise that event when a single-player pilot occupies
  his starting slot — it raises a birth event for him. So the feature shipped dead. It now listens for
  both, with the human test that keeps a birth event from briefing every AI aircraft that spawns, and a
  once-per-slot rule so a pilot is not told the runway twice when both events name him. `veafGrass` and
  `veafQraCore` have both taken both events for exactly this reason for years; this now follows them
  instead of inventing a third answer. (found in game, 2026-08-24)

---

## [6.15.48] — 2026-08-24

### Fixed

- **A sanctuary zone's defences never deployed — they raised an error instead.** Set `delay_spawn` on a
  sanctuary zone, let a player linger past it, and the ships or SAM sites that should punish him simply
  never appeared. The eight calls that spawn them passed their arguments **one position off**: they were
  written against a signature that gained a `delay` parameter in second place on **2021-04-13** and were
  never updated, so a command string landed on `delay` and the scheduler tried to add it to a timestamp.
  Five years old, and invisible because `delay_spawn` defaults to `-1`, which disables the whole branch.
- **A delay that is not a number is now refused loudly** instead of raising deep inside the scheduler.
  A legitimate one is always digits — the marker syntax is `-alias!30` — so anything else means a caller
  passed its arguments in the wrong order. The alias now runs **immediately** and the log names the bad
  value: losing the delay is a smaller loss than losing the spawn, and the next misaligned call will be
  found by reading a log rather than by a player noticing that nothing happened.

---

## [6.15.47] — 2026-08-24

### Fixed

- **A `-tacan` marker spawned a beacon and told nobody.** Dropping it produced no confirmation at all —
  no channel, no band, nothing. The cause was two unrelated ideas sharing one setting: **fourteen** spawn
  handlers forwarded "this command ran without a password" into a parameter meaning "the player does not
  want to be told". An alias like `-tacan` is deliberately usable without a password, and inherited a
  silence meant for mission scripts. Silence now follows **who asked**: a pilot who drops a marker always
  gets an answer, a script never spams one. ([#198 sibling finding](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/198))
- **A spawn asked for by a combat zone or an AirWaves wave still says nothing**, which is the behaviour
  that made the conflation survive for years and is preserved on purpose — a zone spawning thirty groups
  must not print thirty messages.

### Added

- **A TACAN now reports its channel, band and ident** when a pilot places it, the way a JTAC has always
  reported its laser code and frequency. A beacon whose channel is never told to anybody cannot be tuned.

### Changed

- **A JTAC keeps announcing itself even when a mission script places it.** That exemption used to be a
  patch working around the conflation above; it is now a recorded decision, because its message carries
  the code and frequency a pilot needs to *use* the JTAC rather than a notification he can afford to miss.
- The `veafShortcuts` documentation listed **eight** aliases that bypass security. There are nine.
- **A radio beacon placed by a mission script is now quiet**, where it used to announce itself. The `beacon` handler was already asking the right question — "does the caller want silence?" — but nothing had ever answered it, so it always spoke. It now follows the same rule as everything else.

---

## [6.15.46] — 2026-08-24

### Added

- **veafGroundAI — the fire-adjustment loop.** A battery can now be corrected: `_ground order, name
  arty-1, order correct; correction 09050` shifts the last point it aimed at by 50 m east and fires
  again. The correction is written as artillery writes it — three digits of true bearing, then the
  distance in metres — and corrections compound, so two of them move the aim point twice. An unreadable
  correction, or one given to a battery with no fire mission in progress, is **refused and announced to
  the pilot** rather than guessed at. ([#198](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/198),
  [#57](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/57))

### Fixed

- **veafGroundAI kept two different ideas of "the last target".** One was set when an order was queued,
  the other once the rounds actually went out, and only the second was used by `fire` with no target.
  They are now a single remembered aim point, shared by a correction and by a bare `fire` — so an effect
  mission lands where the correction put the aim, not at the point before it.
- **`fire` with no target had never been tested with an actual previous target** — only the empty case
  was. The documented behaviour is now covered.

---

## [6.15.45] — 2026-08-24

### Added

- **A pilot taking a slot is greeted with the weather and the runway in service** —
  [#301](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/301), Tripack. Five seconds after
  entering the unit, so he has finished loading his cockpit, and to **his group only**: it is about his
  airfield, and broadcast to a coalition it becomes noise the moment two pilots take slots at different
  bases.

  Deliberately shorter than the ATIS, which stays a radio command away — a greeting that fills the screen
  at every slot change stops being read. It repeats on **every** slot entry rather than once per session,
  because a pilot who changes airfield wants the new airfield's runway.

  **A carrier announces its current heading instead of a runway**, because it turns into the wind and the
  runway is therefore mobile. In the carrier group's own words — `carrier.atc_navigation`'s *"current
  heading (true)"* — rather than a second vocabulary for the same number, and from the same
  `mist.getHeading(unit, true)` call carrier operations already make. A helipad has neither, so it gets
  the weather alone; a heading that cannot be read falls back to the weather rather than inventing one,
  since a course a pilot cannot trust is worse than none.

  Off with `modules.WEATHER.welcomeBrief: false`, for a mission running its own briefing.

  Worth noting for anyone reading the lot: its PRD called the runway-from-wind *"the only real computation
  here"* and said nothing decided it. That was the one part already shipped —
  `veafAirbase:getRunwayInService` picks the best-headwind runway end and the ATIS has been using it — so
  what this adds is the trigger, the airbase, the message and the switch.

---

## [6.15.44] — 2026-08-24

### Added

- **The mission's own bullseye is injected as a waypoint, per coalition** —
  [#175](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/175), asked for in 2023. Every flight
  plan gains a `BULLSEYE` waypoint at the coordinates the mission itself carries, appended so existing
  point numbers do not move.

  **RED gets the red bullseye, everything else gets blue** — the rule
  [#304](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/304) established for the runtime,
  reused rather than reinvented. Two-way for a concrete reason: the real `neutrals` bullseye is `{0, 0}`
  in the Syria smoke-test mission and `{100, 100}` in the demo mission, so a three-way branch would send
  a neutral flight to the map origin.

  **A flight plan that already declares `BULLSEYE` keeps its own.** Not merely un-duplicated —
  *un-overwritten*: the injector replaces a same-named waypoint in place, so adding ours unconditionally
  would have silently replaced the mission maker's coordinates with the mission's.

  On by default through `pipeline.waypoints.bullseye`, the same shape as `pipeline.presets.kneeboards`:
  a behaviour sub-flag defaults on while the step stays opt-in by the existence of `waypoints.yaml`. A
  mission without one is untouched, and a group no flight plan matches receives nothing — the bullseye
  rides along with a plan rather than creating one. The build reports how many it added.

  Measured on the built smoke-test mission rather than asserted: 105 human slots, 53 with the correct
  blue bullseye, 52 with the correct red one, **0 wrong and 0 missing**. That check is the one that
  matters, because the failure mode here is using the wrong side's bullseye and a unit test with invented
  coordinates would not notice.

  This only works because the previous release moved the waypoints step: before it, the same feature
  would have reached one slot in 105 while satisfying its own acceptance criteria.

---

## [6.15.43] — 2026-08-24

### Fixed

- **Waypoint injection reached one human slot in 105.** The `waypoints` pipeline step ran **before**
  `spawnable_aircrafts` and `dynamic_slot_templates` — the two steps that create the human-piloted slots
  a flight plan exists for. So when the waypoints were injected, those slots did not exist.

  Measured in the built `SmokeTest_noon.miz`: **105** human-piloted groups, exactly **1** carrying a
  waypoint from the flight plan — the one already present in the source `.miz`. With the step at its
  corrected position: **105 of 105**.

  This was never only about an automatic bullseye. It hit **declared** waypoints: a mission maker writing
  a flight plan for a mission with dynamic slots or spawnable aircraft had it applied to a handful of
  slots and nothing else.

  **And it was silent for a reason worth recording.** The step already reported what it did — "N
  injected", "M human groups without a flight plan". At the old position it saw one group and reported
  *1 injected, 0 without a plan*: accurate, and perfectly healthy to read. Nothing lied. The count was
  taken before the world was finished, so moving the step restores the denominator as much as the
  behaviour, and no new reporting was needed.

  The move was made on measurement, not preference: none of the 105 slots has an empty route, so appending
  cannot leave one starting in mid-air, and all 105 already carry a locked ETA, so the injector's "lock
  point 1" fallback — the behaviour its own comment says exists to avoid an untakeable slot — never fires
  on them.

  Guarded by a source-order test bounded on both sides: waypoints must run after the aircraft steps and
  still before the weather step, which writes the variant files.

---

## [6.15.42] — 2026-08-24

### Changed

- **The most specific flight plan now wins, instead of the first one declared.** `src/waypoints.yaml`
  declares plans with criteria — coalition, category, aircraft type, country — and the ones a plan omits
  are wildcards. Until now the **first** compatible plan was used, so declaration order decided and a
  specific plan written after a broad one was unreachable.

  Both the code's docstring and the shipped template promised the priority for years without it being
  implemented, and the template shipped the consequence as its own illustration: `all_blue_planes` is
  declared before `f16_flight_plan`, so a blue F-16C matched the first and the F-16 plan was
  configuration **no aircraft could reach**.

  Measured on the real template, before and after: exactly one case changes, and it is the broken one —
  a blue F-16C now gets `f16_flight_plan`, while every other aircraft gets what it got before.

  **This is a behaviour change for missions whose plans overlap**, and mission folders live outside this
  repository, so the reach is not measurable from here. A mission maker who had ordered plans
  narrow-first to work around the old behaviour sees nothing change — narrow-first is what specificity
  produces. One who relied on order so that a broad plan masked a specific one will now get the specific
  one.

  Declaration order still breaks a tie between plans of equal specificity, deliberately: the alternative
  depends on dictionary iteration and would make the same file build differently for no visible reason.

  Documented for mission makers under `{#flight-plan-matching}` in both languages, with the worked
  example and an explicit note on who is affected.

---

## [6.15.41] — 2026-08-24

### Fixed

- **Every mission built from the template shipped a waypoint labelled BULLSEYE, 483 km from the real
  one.** `src/defaults/mission-folder/src/waypoints.yaml` declared an example waypoint named `BULLSEYE`
  at fixed coordinates; that file is copied into every folder `veaf-tools mission prepare` creates, and
  the waypoints injector runs as an ordinary build step whenever it is present. So the example was not
  dormant — it was injected.

  Measured in the built Syria smoke-test mission rather than reasoned about: one waypoint named
  `BULLSEYE`, at the template's coordinates, **483 km** from that mission's own blue bullseye and 216 km
  from its red one. All four mission folders in this repository carried it.

  The failure is silent by construction, which is why it survived: a pilot has no reason to distrust a
  steerpoint labelled BULLSEYE, and a mission maker reads it as something he put there himself.

  Renamed to `HOLDING_POINT` rather than commented out. The example teaches the file's shape and is worth
  keeping; what had to go was the **claim**. `INITIAL_POINT` and `TARGET` beside it are per-mission
  choices and no value for them is wrong — a bullseye is a property the mission already carries, with one
  correct value, so naming an example after it asserts something a template cannot know.

  Guarded by four checks (`test_default_waypoints_template.py`), one of which covers the rename's own
  silent failure mode: a flight plan pointing at a waypoint that no longer exists injects nothing and
  reports nothing.

- **The plan-matching priority described in two places does not exist.** The template's usage notes and
  `get_flight_plan_for`'s docstring both promised *aircraft type first, then category, then coalition*.
  The code returns the **first** plan whose stated criteria match, so declaration order decides.

  The consequence was shipped as an illustration and nobody noticed: `all_blue_planes` is declared before
  `f16_flight_plan`, a blue F-16C matches both, so the F-16 plan is dead configuration in the default
  template. Both descriptions now say what the code does, with that example spelled out as the warning.
  Whether the priority should be built is a behaviour question, filed as `FIX-WAYPOINTS-PLAN-PRIORITY`.

---

---

## [6.15.40] — 2026-08-24

### Added

- **`_spawn beacon` / `-beacon`: a radio beacon from a marker**, which
  [#38](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/38) (FM beacons) and
  [#192](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/192) asked for. One command places
  three beacons at the marker — ADF (VHF), UHF and **FM** — because CTLD lights all three whether you
  ask or not, so the FM request is answered without an option for it.

  Placed **exactly where the marker was dropped**: `radius` defaults to 0, unlike every command that
  spawns a group, because a beacon's position is the reason for dropping it there.

  **The message is the feature.** CTLD draws each frequency from an internal pool and exposes no way to
  request one, so the command's job is to report what it got:

  ```
  Radio beacon up — ADF 245.00 kHz · UHF 251.00 MHz · FM 40.50 MHz
  ```

  `-tacan` was the model for the plumbing and deliberately not for this: it emits no message at all, and
  none of its keys carry a frequency, so copying it would have shipped a command that works and cannot
  be used. A `freq` option is proposed upstream ([VEAF/CTLD#128](https://github.com/VEAF/CTLD/pull/128))
  rather than faked here — a beacon reporting a frequency VEAF cannot choose would be a command that
  lies.

  Two refusals rather than silence: no CTLD started, and a spawn CTLD declines. The pilot dropped a
  marker and is waiting for something, and reporting success on a failed spawn would leave him tuning a
  frequency nothing transmits on.

  Documented on the spawn page in both languages — `_spawn tacan` was documented nowhere, so there was
  no neighbouring section to mirror — and listed in both alias tables.

---

---

## [6.15.39] — 2026-08-24

### Added

- **A game master can switch CTLD sling loading on and off from the radio menu** (`F10 → CTLD`), which
  [#60](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/60) asked for in 2021. Secured, and
  global: it changes how every helicopter crew in the mission plays, not only whoever pressed it. Only
  the command that changes something is ever shown.

  Effective immediately in both directions, and that is not an accident of the implementation: CTLD's
  hover loop reschedules itself **before** it tests the setting, so switching off stops pickups at the
  next tick and switching back on resumes them. Which is what makes a toggle honest here rather than a
  build-time option pretending to be one.

  **The obvious flag was the wrong one.** `slingLoad` kept its CTLD 1 name through the CTLD 2 migration
  and lost its meaning: it now only decides which model a crate spawns with, and all three of those
  models are `canCargo: true`. A toggle wired to it would have passed any review and reskinned crates.
  The one that governs sling loading is `enableHoverSlingload`.

  **The message names what does not change.** CTLD checks native DCS cargo before it looks at this
  setting, so DCS's own winch keeps working whatever the toggle says — a CTLD crate stays hookable.
  Unsaid, the first crew to hook a crate after a switch-off reports the command as broken.

  It lives in `veaf.lua` beside the CTLD integration rather than in a module of its own. A `veafCtld`
  module would have cost four plumbing points and, worse, a new module key a mission maker has to
  discover — leaving the feature off and invisible by default.

### Fixed

- **The CTLD test double claimed to be a ready engine while missing part of one.** `dcs_mocks` satisfied
  `veaf.isCtldReady()` but offered neither `ctld.gs` nor `setSetting`, which a real CTLD defines
  unconditionally, so the first VEAF code to read a CTLD setting fell over on it. The mock now provides
  the settings surface and `reset()` restores it. Hardening the production code against a missing `gs`
  was the alternative and would have been wrong: it cannot happen in DCS, and it would hide a genuinely
  broken CTLD behind a silent default.

---

## [6.15.38] — 2026-08-24

### Fixed

- **`vendored.yaml` pinned CTLD four release candidates behind the file it describes.** PR #746
  (2026-08-15) updated the vendored `CTLD.lua` from `2.0.0-rc3` to `2.0.0-rc7` and did not touch the
  manifest. The pin stayed at rc3 for nine days.

  The cost is not the wrong number, it is what the wrong number did to the drift watcher. The watcher
  compares upstream releases against the pin, so it spent those nine days reporting rc4, rc5, rc6 and rc7
  as *available updates* — all four already applied. A watcher whose alarms are known to be wrong is a
  watcher nobody reads, and the next alarm is the one that matters. The same failure as the datamine
  robot silenced by a surviving branch, from the other direction.

  Both the pin and the release watch tag are corrected; fixing only the first would have left the watcher
  wrong while making the manifest look right.

### Added

- **A test that a vendored file and its pin describe the same version** (`test_vendored_pins_match_the_files.py`).
  Offline, so it gates every run rather than waiting for the weekly drift check.

  Deliberately a table of named artefacts rather than a sweep: only a few of the eleven declare a version
  a machine can read — two are directories. A heuristic was written first and thrown away, because it
  reported AIEN as consistent for the wrong reason: the digit `1` of its `1.0 build 0154` occurs in its
  pin. A green light earned by accident is the failure this test exists to prevent, one level up.

  The release-tag check is scoped to artefacts whose tag and pin share a numbering scheme. The first
  version required every tag to contain its pin and failed on CSAR, which pins the date-version of the
  adapted file while watching ciribob's separate `1.9.x` releases — a correct manifest reported as drift.
  Tightening the scope was the fix; loosening the comparison would have made the check unable to fail.

---

## [6.15.37] — 2026-08-24

### Fixed

- **Three defects in the missile-guardian module, one of them on the path its own documentation
  teaches.** The module has been a declared skeleton since 2021 — its page says so, version `0.0.2`,
  exploratory use only — but a skeleton that raises is indistinguishable from a broken feature when it
  turns up in a DCS log.

  1. `ActivateGuardian` and `DesactivateGuardian` opened on `veafMissileGuardian.GetGuardian`, a function
     that was never written. Found by the call sweep shipped in 6.15.31.
  2. The weapon path ended on `getLargeScaleProtector():setWeapon(...)`, and `getLargeScaleProtector` is
     a stub returning nil. **This one was reachable**: the documentation tells a mission maker to build a
     guardian by hand in `mission-script.lua` and call `start()`, so following the page gave a warning to
     the targeted pilot followed by a Lua error — on every shot.
  3. Found by a test written for the second: `VeafMG_Weapon:setDcsWeapon` passed `getLauncher()` straight
     to `getUnitName`, which indexed it. `getLauncher()` legitimately answers nil once the shooter is
     gone, which for a shot event processed a moment later is ordinary. The existing `setDcsWeapon` test
     never saw it because its mock always supplied a launcher.

  So the one behaviour the page promises — warn the target — now completes instead of raising.

### Changed

- **The missile-guardian skeleton refuses instead of pretending.** `AddGuardian`, `ActivateGuardian`,
  `DesactivateGuardian` and `listGuardians` log a warning and return `false`. A warning rather than a
  silent return, because a mission calling one of them asked for protection it is not getting; kept
  rather than deleted, because removing them would turn a warning into a nil-call crash at the caller.

  `listActiveMissions` **is** removed: it iterated `veafMissileGuardian.missionsDict`, a table this
  module never had — copied from `veafCombatMission`, where "missions" is a real concept — so its only
  possible outcome was an error.

  Neither repaired nor removed, and both were considered. Giving it storage was one hole out of five: the
  class has no `activate`, `desactivate` or `isSilent`, and `VeafMG_Protector:start()` has an empty body,
  so **no watchdog anywhere ever destroys a weapon in flight**, which is the feature's entire point.
  Removing it would have deleted a module that is shipped in the bundle, offered as `MISSILEGUARDIAN` in
  the catalogue and the template picker, and documented in both languages. Finishing it is a feature
  project, not a fix.

  The module now carries a header stating everything above, and its documentation page a `{#state}` table
  in both languages: what works, what refuses, what is not implemented.

- **`KNOWN_MISSING` in `test_lua_module_calls_resolve.py` is empty.** It held one name; the ratchet only
  ever shrinks, and adding to it is now explicitly a decision to ship a call that raises.

---

## [6.15.36] — 2026-08-24

### Fixed

- **The API reference documented the opposite of the real default.** Both `doc/LUA_API_REFERENCE.md` and
  its English twin listed `veaf.HideNamesFromSpawnedGroups = false`, while `veaf.lua` sets it to **true**.

  That flag replaces a spawned group's zone and unit type with an invented name, so a group comes out as
  `[r]-Hydra Unit#10230`. The documentation therefore told a mission maker the opposite of what his
  missions were doing, and it went unnoticed until someone asked why his groups were being renamed.

### Added

- **`mission.hide_names_from_spawned_groups` in `mission.yaml`.** The flag existed but was reachable only
  through the `module_settings:` migration hatch and documented only in the API reference — which is not
  where a mission maker looks when he wants to know why his groups are renamed.

  Emitted only when the field is actually given, the way `SecurityDisabled` and `DynamicSpawn` are:
  silence leaves `veaf.lua`'s own default and lets a `module_settings:` line survive. Documented on the
  combat-zone page in both languages, where the question is asked, with what is and is not configurable —
  the coalition tag and the `#<id>` stay either way, since DCS requires unique group names.

- **A test comparing documented Lua defaults against the code** (`test_documented_lua_defaults.py`).
  The reference pages list module constants as literal assignments, so a reader takes them for the real
  defaults. Nothing compared the two, and nothing could have: each value was right in its own file.

  Scoped to stay trustworthy rather than noisy — booleans and numbers only inside fenced Lua blocks, and
  a constant the scripts do not assign at top level is skipped rather than failed, since documentation
  legitimately describes fields set at runtime. It also checks the two languages document the same values,
  because a value corrected in one and not the other is the next version of this bug. Verified by
  re-introducing the wrong default and watching the test name it with both values.

---

### Changed

- **A documented `mission:` field now beats a `module_settings:` leftover for the same Lua target.**
  Raised in review on the PR above, and measured before being believed: the `mission:` block is emitted
  first and `module_settings:` after, so Lua took the hatch's value and
  `mission.hide_names_from_spawned_groups` had no effect whenever both forms were present. The commit
  that added the field even carried a test whose docstring claimed it *"must beat a `module_settings:`
  line"* — with no `module_settings:` line anywhere in the case. Asserting the emitted constant while
  the docstring described the applied behaviour is the same trap `test_defaultSpawnRadii` sat in for
  three years.

  Which form *should* win is settled by the reference itself, where `module_settings:` is described as a
  migration path rather than a permanent override: the documented field wins, the superseded hatch entry
  is dropped, and the build warns naming both. Silently ignoring a line somebody wrote would be
  `FIX-MODULE-SETTINGS-OVERWRITTEN` from the other side, which is why it is said out loud. Only the
  superseded key yields — the hatch stays generic, and a mission that has not adopted the new field is
  unaffected. Documented in `MISSION_YAML_REFERENCE` in both languages.

- **The two-language comparison in `test_documented_lua_defaults.py` compared only shared keys.** Also
  from review. Deleting a documented default from one page dropped it out of the comparison entirely, so
  the test passed while the two references no longer documented the same thing — the exact divergence it
  exists to catch. It now compares the union of both key sets and names the page a default is missing
  from. Verified by removing one line from the English page: the old form passed, the new one fails and
  says which file.

---

## [6.15.35] — 2026-08-24

### Fixed

- **A mission that set `csar.csarMode` got a Lua error instead of the sanction it configured.**
  `csar.addCsar` calls `csar.handleEjectOrCrash(_playerName, false)`, and that function immediately does
  `_unit:getName()` — so a player name raised *"attempt to index a string value"*. Every other caller
  passes a unit, which is why the defect sat in the one path the setting exists for. Invisible at the
  default mode of 0, where nothing happens at all.

  Fixed by replacing `csar.handleEjectOrCrash` from `veaf.csar_initialize_replacement`, next to the
  existing `addCsar` replacement, rather than editing the vendored `CSAR.lua` (an edit there is erased by
  the next update) or sending it upstream (`VEAF/DCS-CSAR` is `ahead=0` on `ciribob/DCS-CSAR` and both
  have been untouched since August 2023).

  Reading the vendored function through showed **three** modes rather than the two first assumed, and
  they do not need the same information — which is what made the fix decidable:

  | `csarMode` | Sanction | Needs |
  |---|---|---|
  | 1 | disables the aircraft for everyone | the aircraft's `getID()` |
  | 2 | disables that aircraft for that pilot | the aircraft's `getID()` |
  | 3 | reduces the pilot's lives | only `getPlayerName()` |

  So the replacement passes a unit through untouched, resolves a player name to his unit through
  `coalition.getPlayers` when he is still flying, and when it cannot resolve one — he has just ejected,
  his aircraft may already be gone — still serves mode 3 from the name alone while refusing modes 1 and
  2 **with a warning**. Those key on an aircraft id; inventing one would ground an aircraft nobody chose.
  A skipped sanction is recoverable, a misapplied one is not.

  `coalition.getPlayers` was missing from the DCS mocks, which is why no test could exercise a
  player-name lookup; it is now mocked. Sixteen Lua tests cover it, and three mutations were run against
  them to prove they can fail.

### Changed

- **The `pcall` around that call, added in 6.15.33, stays — with an honest comment.** It was introduced
  to keep the over-water path from dying of this defect, and its comment said the call *does* raise,
  which is no longer true. It now guards the next defect in a vendored function rather than a known one,
  on the path that runs while a pilot is drowning. A test asserts the lost-at-sea path applies the mode-3
  sanction for real and that the guard reports nothing.

- **The smoke checks' Lua parse test now version-checks its interpreter.** It resolved one with
  `shutil.which("lua")`; this machine has two — a scoop 5.5.0 shim and the 5.1.5 in Program Files — and
  which one answers depends on the PATH of the shell that launched pytest. It answered 5.1.5, so the
  check was right by accident. It now goes through `veaf_build.lua_tests._find_lua`, which rejects
  anything but 5.1: a 5.5 refuses valid 5.1 (it reads a `for` variable as const) and accepts syntax DCS
  would not, so the same test could have reported failures that are not defects.

---

## [6.15.33] — 2026-08-24

### Fixed

- **A `-farp` dropped near an existing FARP put its escort and props on that platform.** [#232], open
  since 2023, "fixed" in 6.15.11 by a change that could not work, and confirmed still broken in game on
  2026-08-22. Verified fixed in game on 2026-08-24.

  Five distinct defects were in the way, and only the first was the one originally suspected. Each was
  found by measuring rather than reasoning, and four of them only became visible once the placement
  logged what it was doing:

  1. **A FARP is not a static.** `isSpotOccupied` probed `world.searchObjects` over units and statics,
     but a FARP placed in the editor is an **airbase** — `Airbase.Category.HELIPAD`, through
     `world.getAirbases()`, which is how `veafAirbases.lua` has always treated it. The probe could never
     see the one object the issue is about. FARPs that DCS miscategorises as `SHIP` are included, the
     same remediation `veafAirbases` applies; an airdrome deliberately is not, or a runway-sized radius
     would move FARPs that were placed perfectly well.
  2. **A sphere probe cannot answer this.** `searchObjects` matches an object's *position*, so with a
     12 m clearance and a platform tens of metres across, an escort on its **edge** — the actual
     complaint — leaves the platform's centre outside the sphere.
  3. **The size was guessed twice before being measured.** 80 m first, which is *below* the 84 m where
     that FARP's outermost pad sits, so an object at 81 m was on a pad and passed. Then 84 m from
     `getParking()`, which bounds the pads and not the apron, leaving the escort on it at ~120 m. DCS
     does report the real extent: `getDesc().box` gives ±129.5 m, a 259 m square. The test is now a
     **box**, since a circle through the corners would refuse ground that is plainly free.
  4. **The fallback placed groups at the worst spot available.** With the exclusion finally apron-sized,
     one group had no clear bearing at its distance — and the search kept the *original* angle, which
     pointed at a pad. #232's arbitration (keep the distance, move the bearing) was revised on that
     evidence: the search now walks out to 1.5× then 2×, always trying the requested bearing first at
     each distance, so a nearer bearing wins over a further one and a group with clear ground does not
     move at all.
  5. **The FARP was avoiding itself.** The FARP a marker creates is an airbase too, and it exists by the
     time its props are placed — so every prop inside its own 139 m apron, which is where they belong,
     was refused at every bearing and every distance. The fix aimed at a *neighbouring* platform was
     placing things worse than before it existed.

  The windsock also went through no clear-ground search at all, and on a FARP it sits 120 m out. Its
  bearing is free by David's call, so it now searches like everything else; both windsocks are placed
  from the same bearing, since the second is offset 90° from the first by design.

  Recorded in the code because it cost an afternoon: `land.getSurfaceType` returns `LAND` everywhere out
  to 260 m around a FARP. The apron is **not** in the terrain data and cannot be found by probing ground.

### Added

- **The FARP placement says what it decided, at info.** How many platforms it is avoiding and which one
  is the FARP being built, each refusal with its distance and the platform's extents, and the bearing and
  distance each group ended up with.

  Not scaffolding. Four of the five defects above are indistinguishable from the outside — "still on the
  FARP" looks identical whether the probe saw nothing, saw it and was calibrated too tight, or worked
  perfectly and fell back to the original angle. The first three rounds of this fix were spent adding
  size to a problem that was structural, because nothing said which. A mission maker whose escort quietly
  moved has the same question.

---

## [6.15.32] — 2026-08-23

### Fixed

- **A `module_settings:` value was silently overwritten by the module block below it.** The generator
  wrote `veafSkynet.DynamicSpawn = <bool>` on every build, from a `False` default, immediately before
  `initialize()`. A mission setting the same variable through the migration hatch got it written ~145
  lines earlier and undone without a word — the setting was visibly present in the generated Lua, and
  inert.

  It broke `verify-mission-c`, the mission whose job is to verify that very feature, from 2026-08-20
  until it was found on 2026-08-22: its Skynet checks ran with dynamic spawn off and would have reported
  the documented default as a measurement.

  The line is now emitted only when `dynamic_spawn` is actually given, the way `veaf.SecurityDisabled`
  already was. Not emitting it is safe rather than a behaviour change: `veafSkynet.lua` declares the
  same `false` default. An explicit `dynamic_spawn: false` is a statement and still wins.

  A `module_settings:` key a module block assigns again is now **reported** at build time. That silence
  cost more than the wrong value did.

- **The validator passed missions the DCS Mission Editor refuses to open.** `ETA_locked` and
  `speed_locked` appeared nowhere in it, so `mission validate` reported "no defect" on `verify-mission-a`
  seconds before the editor rejected it with *"All waypoints (2-2) have locked speed and surrounded by
  waypoints 1 and 2 with locked time!"*.

  Both shapes are now reported, naming the group and the waypoint and saying which flag to clear: a
  locked speed between locked times, and its symmetric twin — a route with no locked time at all, which
  `FIX-WAYPOINTS-ETA-LOCKED` taught the MCP to repair on its own edits while leaving the validator blind
  to it in data it did not write. Verified end to end by re-introducing the real defect into
  `verify-mission-a` and watching `validate` name it.

- **Six convoy radio commands, each alone inside its own submenu.** Two keystrokes for one item, with the
  second menu repeating the label of the first — *"F4 - Arrêter le convoi le plus proche sur place"* then
  *"F1 - Arrêter le convoi le plus proche sur place"*. Reported in game.

  Nothing required the nesting: `veafCarrierOperations` puts several group-scoped commands in one shared
  submenu, and `convoy_cleanup` in the same block always went straight to the root. The pattern predated
  `FEAT-CONVOY-WAYPOINTS` — the two mark commands were already written this way and the four itinerary
  commands copied their neighbour — so all six moved together rather than leaving the menu half-flat.

  A test captures what `buildRadioMenu()` asks the radio for, rather than grepping the source, and pins
  that the commands stay group-scoped and that `hold` and `stop` stay adjacent — their labels have to be
  readable against one another.

---

## [6.15.31] — 2026-08-22

### Fixed

- **The two CSAR-over-water checks were measuring the wrong function.** They called
  `csar.spawnGroup` — the raw placement *underneath* `csar.addCsar`, which is what
  `FIX-CSAR-SPAWNS-ON-WATER` replaces. So they bypassed the fix entirely and reported
  `surface:3 dry:0`, a wet pilot, against a working product. Measured in game 2026-08-22, and worse
  than no verdict, because it reads as a regression.

  They now go through `addCsar`, the entry point CSAR itself uses on an ejection. Since `addCsar`
  returns nothing, the survivor is found through the new key in `csar.woundedGroups`, and its
  **absence** is what open sea is supposed to produce.

  The verdict is split accordingly, because the two modes expect **opposite** results — which is
  David's arbitration on #245: within 500 m of dry ground the survivor is moved there, otherwise he
  counts as dead. Open sea passes on `lost:1` and fails on any placement; a coast passes only on a
  survivor standing on dry ground, and a `lost:1` there means a rescuable pilot was written off — the
  failure the open-sea check structurally cannot see. One expectation for both would have had to accept
  one of the two failures.

  Cleanup now removes both halves: the DCS group *and* CSAR's `woundedGroups` entry, which would
  otherwise leave the mission announcing a survivor that no longer exists.

- **"Open sea" was defined too weakly to test the rule it was checking.** The check called a spot open
  sea when its eight neighbours **at 150 m** were all water, while the fix searches for dry ground out
  to **500 m**. A spot 300 m off a coast satisfied both: the survivor was correctly carried ashore, and
  the check reported `surface:1 dry:1` as a failure. Measured in game — a correct product called broken,
  twice in a row, for two different reasons.

  The radius is now **read from the product** (`veaf.CSAR_SURVIVOR_SEARCH_RADIUS_METRES`) instead of
  duplicated, and open sea is asserted by sampling rings out to 1.2× it rather than one ring of eight
  points. A test that copies a distance the product owns drifts from it the moment the product changes.

- **The smoke harness's `veaf-loaded` check could not pass.** It read `veaf.MAIN_VERSION`, a field that
  has never existed — the real one is `veaf.BuildVersion`. Lua's `a and b or c` falls through to `c`
  whenever `b` is nil, so the chunk returned its "VEAF is absent" sentinel unconditionally, from
  2026-08-05 until now, reporting that VEAF was not loaded against missions where it plainly was.

  It surfaced only because `findspawnpoint-exists` answered `function` on the same run: two results side
  by side, flatly contradictory, and one of them had to be wrong. A check that cannot pass is the same
  defect class as a check that cannot fail — both return a confident verdict about something they never
  measured.

  The three outcomes are now distinct instead of collapsed into one word: `veaf-absent` (no table),
  `veaf-no-version` (table, no build version), or the version itself. Answering "absent" for "present
  but this one field is missing" is what kept it invisible: it named a cause that was not the cause.
  Returning the version also makes a mission built from a stale bundle visible in the answer.

- **`verify-mission-c` had CSAR switched off, so the two `csar-avoids-water-*` checks measured nothing.**
  The note explaining why reasoned backwards: #245 did move that verification off a flying session, but
  "no pilot needed" is not "no module needed" — both checks call `csar.spawnGroup` in the mission's Lua
  state and returned `csar-absent`. Enabled, with the reasoning recorded so it does not get switched back.

### Added

- **The CSAR reply now carries its geometry, not just its verdict.** `moved`, `radius`, `asked` and
  `wrapped` — how far the survivor travelled, the bound it was measured against, the surface under the
  ejection point, and whether the replacement was installed. Two runs had been spent on a single
  ambiguous answer, each hypothesis costing a person a DCS reload; these fields settle it in one. A
  `moved` beyond `radius` is now a failure in its own right, in either mode: the radius *is* the rule.

  The open-sea sweep also widened to **2×** the rescue radius, because the thing under test is not
  deterministic — `veaf.findSpawnPoint` draws from `Disposition.getSimpleZones` and
  `mist.getRandPointInCircle`, both random, so near a marginal spot the identical harness answered
  `lost:0` then `lost:1` with no code change in between. A check that flickers gets ignored.

  Measured **9/9** on 2026-08-22: `mode:open lost:1`, and
  `mode:coast lost:0 surface:1 dry:1 moved:259 radius:500 asked:3 wrapped:1`. Both
  `FEAT-SMOKE-CSAR-WATER` and `FIX-CSAR-SPAWNS-ON-WATER` close on it.

- **Every harness chunk is parsed by real Lua 5.1 in the test suite.** The chunks are built by string
  concatenation, so a missing space between fragments or an unbalanced `end` was a syntax error that
  surfaced only as a failed check in a live session — one round-trip through someone's DCS to learn what
  `loadfile` answers instantly. Verified by injecting a stray `end` and watching the test name the check.

- **A sweep refusing any harness check that reads a field the scripts never define**
  (`test_dcs_smoke.py`). Verified against the real defect: with `MAIN_VERSION` restored, the sweep names
  it.

  Its own first version was broken in the same spirit and is worth recording. Written through a shell
  heredoc, its `` became a literal backspace (0x08), so the regex looked for a control character,
  matched nothing, and the test passed on the very defect it existed for — and a `grep` looked correct,
  because a terminal renders 0x08 by eating the character before it. The pattern is now asserted
  explicitly.

---

## [6.15.30] — 2026-08-22

### Fixed

- **Any map marker carrying text answered "your marker command failed".** Dropping a plain annotation
  — a name, an arrow, a note to a wingman — reported a VEAF error to the pilot who placed it.

  `veafRemote.initialize()` registered a marker command handler calling `veafRemote.executeCommand`,
  and that function was deleted on 2026-08-11 with the shared-password marker mechanism it belonged to
  (replaced by `registerRemoteModule` / `executeCommandFromRemote`, which authenticates a named user
  instead of trusting a string typed on the map). The registration outlived it. Since
  `veafMarkers.onEvent` calls every registered handler under `pcall` and surfaces any failure to the
  pilot, every marker with text hit it — for eleven days, until a pilot said so.

  The pilot-facing message was not the cause. It is what made a silent breakage visible, which is what
  it was added for.

  `veafRemote.addNiodCommand` went with it: it called the same deleted function and had no caller
  anywhere, so it never raised — the other half of a removal left unfinished.

### Added

- **A repo-wide sweep for calls that reach nothing** (`test/python/test_lua_module_calls_resolve.py`).
  Every `veafX.y(...)` in the scripts must resolve to a function something defines. Lua cannot catch
  this class on its own: a missing table field is `nil` until called, and that call dies inside a
  `pcall` nobody reads.

  Proven against the real defect rather than assumed — re-introducing the dead call makes the sweep
  name it. Strings and comments are stripped first, because three of the first five candidates were log
  labels and code inside a `[[ ]]` block. Across 1166 defined symbols it leaves exactly one known
  offender, `veafMissileGuardian.GetGuardian`, listed in a shrink-only ratchet and filed as its own lot
  rather than skipped.

---

## [6.15.29] — 2026-08-22

### Changed

- **A point defence no longer guards a site that can no longer fight.** When Skynet picks which site a
  point-defence group protects, it now passes over groups `veaf.isGroupCombatEffective` reports as
  finished — so a Tor does not spend a mission covering a decapitated S-300 while a live site next door
  goes undefended.

  Invisible to a player until it matters, and it cannot end a mission early. That last point is why this
  half shipped and the other did not: adopting the same predicate in `completionCheck` would have let a
  zone announce itself complete with intact launchers still standing, and **David refused it** — a zone
  completes only when everything is destroyed.

  **Early-warning radars are exempt**, and not out of caution: an EWR is defended because it *sees*, not
  because it shoots, so asking whether one can still fight is a category error. Judging them would also
  have let a **mixed group** — a 55G6 and a launcher together — lose its defence silently, since such a
  group carries `SAM LL` with no tracking radar.

---

## [6.15.28] — 2026-08-22

### Fixed

- **A downed pilot no longer appears in the water**, closing
  [#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245). CSAR placed the survivor at a
  fixed 50 m offset from the aircraft that went down, with no surface test at all — so ejecting near a
  shoreline put him in the sea, unreachable.

  David's arbitration: **within 500 m of dry ground, put him there; otherwise he counts as dead.** Two
  outcomes and nothing in between, and the second is the absence of a CSAR rather than an unreachable
  one — no MAYDAY, no ADF beacon, no wounded group sitting on the seabed for the rest of the mission. His
  coalition is told he is lost, unless the caller asked for silence.

  Shallow water is not open sea: a survivor wading a few metres off a beach stays rescuable where he is.

  **Not a line of `CSAR.lua` changed.** It is a vendored third-party script whose update procedure
  re-applies VEAF adaptations onto a fresh upstream copy, so an edit there would be erased silently.
  `veaf.csar_initialize_replacement` already replaces seven things in the `csar` table — its loggers, its
  id — and now replaces `csar.addCsar` as well. It has to be `addCsar` and not `spawnGroup`, where the
  placement happens: `addCsar` dereferences the spawned group immediately, so refusing to spawn from
  there raises.

---

## [6.15.27] — 2026-08-22

### Added

- **A briefing can show the weather the mission was built with.**
  [#40](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/40), open since 2021. Write
  `${METAR}` in the briefing and the build replaces it with **that variant's** weather, so seven weather
  variants give seven different briefings with nothing retyped:

  ```
  Weather at departure: ${METAR}
  ```

  The issue explained why hand-typing it never worked: a mission is rebuilt from its sources on every
  build, so the text is overwritten next time. The weather was known at build time and simply never
  reached the text a pilot reads.

  Both things the backlog said to check first turned out to matter. **The prose lives in the l10n
  dictionary**, with `mission` holding only a key — a substitution pass over `mission` alone would have
  found that key and replaced nothing at all, on every mission ever saved by the DCS editor. And the
  substitution runs **per variant**, inside the loop the weather injector already had.

  All four description fields are covered — the situation plus the three per-coalition tasks — because
  `${METAR}` in the blue task has no reason to behave differently.

  **An unsupplied token is left exactly as written**, never blanked. A variant built from individual
  `weather:` parameters has no METAR string in existence, so `${METAR}` survives and a warning names it:
  a hole in player-facing text reads as the build having eaten the prose, while a visible token says what
  to fix. Same for a misspelt `${METRA}`.

  The ICAO fetch is only made when the briefing actually asks for `${METAR}`, so an unused variable costs
  no network call.

### Fixed

- **A weather variant declaring only `airport_icao` never had its weather injected.** From the weather
  feature's first commit (2025-11-25) until now, the gate read `version.weather or version.metar`, so a
  variant asking for live weather silently kept the base mission's — nine months, with
  `_inject_weather` perfectly able to fetch it and simply never called. Found while reviewing the
  briefing feature above: a briefing claiming the live weather is what made the inconsistency visible.

- **The live METAR is fetched once, not twice.** The weather table and the briefing's `${METAR}` are two
  consumers of the same report, and two independent requests meant a station publishing between them
  would put a METAR in the briefing contradicting the weather actually injected — besides being a second
  chance to be rate-limited. The fetch is memoised per ICAO, so seven variants sharing a station make one
  request.

- **The `versions[]` reference was missing its `airport_icao` row.** The field is read by the build and
  documented nowhere, which mattered here because `${METAR}` resolves through it.

---

## [6.15.26] — 2026-08-22

### Added

- **Two smoke-harness checks answer "does the CSAR pilot spawn in the water?" with a script rather than
  a pilot.** [#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245) had been sitting in a
  flying session out of habit; deciding it needs three scripting calls and no aircraft — trigger the
  spawn, read the position back, ask what is underneath.

  `csar-avoids-water-open-sea` and `csar-avoids-water-coast` ask deliberately different questions: the
  first is the reported case, the second is whether CSAR consults the land-aware `veaf.findSpawnPoint` at
  all. Neither hard-codes a coordinate — they anchor on the first airbase, sweep outwards for water and
  classify the spot by what surrounds it at 150 m — so they travel between theatres.

  **Reading the code already answered the lot's central question, before any run.** `csar.spawnGroup`
  places the pilot at a fixed `+50/+50` offset with **no surface test of any kind**; it does not consult
  `findSpawnPoint`, it never asks. So the prediction is on record: *both* checks should fail. If the coast
  one passes while the sea one fails, that reading is wrong — which would be the more interesting result.

  The fix is deliberately **not** in this release. `CSAR.lua` is vendored `adapted`, and its documented
  update procedure re-applies VEAF adaptations onto a fresh upstream copy — so an edit made here would be
  erased by the next update. `veaf.csar_initialize_replacement` already replaces `csar` functions from
  VEAF code and is the seam that survives; the work is filed as `FIX-CSAR-SPAWNS-ON-WATER`, with one
  question to settle first: what a pilot ditching over open ocean should do, since moving him to the
  nearest land can be kilometres away and stops being a rescue.

  Every "could not ask" answer — `csar-absent`, `no-water-found`, `no-group` — **fails** rather than
  passing vacuously. A check that goes green while having asked nothing would close #245 on nothing at
  all.

---

## [6.15.25] — 2026-08-21

### Fixed

- **A blue cold-war platoon has been drawing from a list where one entry in three spawned nothing.**
  `"APC TPz Fuchs"` appeared in six places across the platoon composition tables and resolved to
  **nothing** — silently, the only trace being a log line. The name DCS ships is `'APC TPz Fuchs '`, with
  a **trailing space**, and the unit lookup compared it untrimmed. Two of the 873 units in the generated
  database have one; no type id does.

  `veafUnits.findDcsUnit` now compares trimmed values, which also rescues a mission maker who reads a
  name off the mission editor and types it — the space being invisible there too.

  Found by the enumerated sweep added for #296 below, on its first run, before a single unit was added.

### Added

- **The Currenthill armour units can appear in a spawned platoon**, closing
  [#296](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/296). All nine of them, placed by
  role and period: `CHAP_T84OplotM` (Oplot-M) at the top of blue modern, `CHAP_T90M` and `CHAP_BMPT`
  (T-90M, Terminator) at the top of red modern, `CHAP_M1130` and `CHAP_MATV` filling out blue modern, and
  the two CVR(T)s in blue cold war.

  **The tiers stay hand-written, and the data decided that** rather than a preference: a generated record
  carries `type`, `name`, `kind`, `category` and DCS attributes, and **neither an era nor a tier**. A tier
  is an editorial judgement of relative power, an era a judgement of period; deriving them would mean
  inventing the data first.

  So what stops this recurring is not derivation but a **test that enumerates every entry of all four
  type tables** and checks each against the database. A type DCS renames or drops now fails the build
  instead of quietly spawning nothing — which is exactly how the Fuchs above survived. Entries now use
  the DCS type id where it differs from the display name, a type id being stable and a display name being
  what carried the space.

---

## [6.15.24] — 2026-08-21

### Added

- **A combat zone now reports the groups that can no longer fight**, closing
  [#177](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/177) from 2023. A group is not only
  alive or dead: an S-300 whose tracking radar is destroyed keeps its launchers, trucks and crew, counts
  as alive everywhere in the code, and in play is finished.

  ```
  OUT OF ACTION (can no longer fight): ALPHA-SA10
  ```

  The judgement lives in a new `veaf.isGroupCombatEffective`, and it works two ways. A **pattern table**
  (`veaf.ImportantUnitsByGroupPattern`) declares the sets of units a kind of site cannot do without —
  the S-300 entry from the issue body ships as the first one — with a `minimumLife` expressed as a
  **percentage** rather than hit points, because absolute points mean a different threshold per unit
  type. With no pattern, the **DCS attributes** decide: a group with a living search radar or launcher
  *is* a SAM site, and is finished once nothing living carries a tracking radar. A Tunguska, which is its
  own radar and launcher, stays operational alone; a convoy has no radar and remains a threat while it
  rolls.

  Attributes are read from the repository's own generated `dcsUnits` database rather than through
  `Unit.getDesc()` — the same data, no DCS call, and a unit type can be asked about without a living unit
  to ask through, which is what makes it testable. A test checks the real database still carries the
  attributes the rule reads, because a regeneration that dropped them would quietly declare every SAM
  site finished.

  **Adopted in exactly one place, on purpose.** The report *adds* information and removes none, so no
  mission behaviour changes: a zone still completes only when every enemy unit is destroyed, useless
  launchers included. Adopting the predicate where zones complete would change every existing mission
  and is a design question rather than a technical one — it is analysed in the lot's PRD and filed as a
  follow-up.

  **The limit is documented rather than hidden**: destroyed units vanish from `Group:getUnits()`, so the
  default cannot know a group *had* a radar it has since lost. The pattern table is what carries that
  knowledge.

### Fixed

- **`dcsUnits` no longer counts toward Lua coverage.** It is a generated data table — 13 600 lines of
  literals with no logic — and a test that merely loads it counted every line as covered, inflating the
  total by about 8 points. Left alone, that inflation would have been baked into the ratchet floor and
  collapsed the moment the load went away.

---

## [6.15.23] — 2026-08-21

### Added

- **A combat-zone numeric tag accepts a range**, closing the half of
  [#25](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/25) that was still open:

  ```
  ALPHA-CONVOY #spawnradius=100-300 #spawndelay=30-90
  ```

  `#spawnradius`, `#spawnchance`, `#spawncount` and `#spawndelay` draw a value through the same
  `veaf.getRandomizableNumeric` marker commands use, so a range means the same thing in both places. The
  draw happens once per mission, when names are read: placement varies from one game to the next, not
  from one activation to the next.

  **This was silently truncated before, not unsupported.** The patterns captured `(%d+)`, so
  `#spawnradius=100-300` matched `100` and the `-300` was never seen — a mission maker who wrote a range
  got its lower bound and no message. Existing missions carrying one will see it take effect.

  `#alarm` deliberately takes no range: an alarm state is an enumeration, so `#alarm=0-2` is a typo
  rather than a random state.

### Fixed

- **An interpreter trigger the world does not hand back now still fires**, closing
  [#123](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/123). A unit carrying
  `#veafInterpreter["…"]` is only there to mark a spot, so a mission maker wants it out of the way —
  late-activated, never existing in the world. `executeCommandOnUnit` read the position from the running
  world only, so such a unit reached neither of its branches and its command was **dropped in silence**.

  `_initialize` already holds every unit's mission record, so it is passed down as a fallback: the
  trigger fires whether or not DCS resolves a late-activated unit by name — a question that cannot be
  settled from a workstation, and now does not need to be. Nothing is destroyed on that path, there
  being no world object to destroy.

  Ticking "hidden on MFD" always worked and now says so in the documentation: the interpreter neither
  reads nor writes that flag.

- **An open-ended or reversed numeric range no longer raises.** With no upper bound the fallback is 99,
  so `size 100-` reached `math.random(100, 99)` — *"interval is empty"*, a Lua error rather than a wrong
  number — and so did any reversed range like `5-2`. Reachable from **every** marker command taking a
  number, and found while widening the combat-zone tag patterns onto the same converter. An upper bound
  below the lower one now means the lower one, with a warning.

---

## [6.15.22] — 2026-08-21

### Added

- **A convoy can be given an itinerary, walks it unaided, and takes orders on the way.**
  [#153](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/153), open since 2022. `dest` may
  now be written several times, and the convoy visits the points in the order written:

  ```
  _spawn convoy, dest KOBULETI, dest BATUMI, dest POTI, speed 40
  ```

  A single `dest` is a one-point itinerary and behaves exactly as before — no existing marker changes
  meaning, and no watchdog is started for it.

  Reaching a point starts the next leg on its own, and the leg is generated from **where the convoy is**
  rather than where it spawned: it has been driving since, and re-using the old origin would send it back
  to the start first — the same defect `FIX-COMBATZONE-SPAWN-ROUTE-OFFSET` fixed for combat zones.

  Four F10 commands, and the two brakes are deliberately not interchangeable:

  | Command | Effect |
  |---|---|
  | Send to next point | starts the next leg at once |
  | **Hold at next point** | lets the leg finish, then parks there and waits |
  | **Halt where it stands** | stops on the spot, mid-road if need be |
  | Resume after a halt | picks the current leg back up |

  `hold` chooses **where** a convoy stops, `stop` chooses **when** — one paces a mission, the other
  rescues one going wrong. They carry different labels and different messages, and a test fails if the
  two ever report the same thing. `hold` on the last leg says there is no next point rather than
  silently doing nothing.

  `patrol` now applies to the **last** leg only: patrolling between two points of an itinerary would
  contradict the itinerary.

  **Both things the backlog said to measure were removed rather than assumed.** Whether a stopped group
  resumes its route: the question does not arise, since every resume and every leg re-issues the route,
  and #290 — suspected of being the same root cause — was diagnosed as the alarm state, not a lost
  route. What "arrival" means when the lead vehicle dies: the watch reads the convoy's **average**
  position, which has no lead to lose and returns nothing exactly when nothing is left alive.

---

## [6.15.21] — 2026-08-21

### Fixed

- **A combat zone anchored a group on the first unit it could see, so a group straddling the zone's
  edge appeared offset from where it was drawn.** A zone adopts a group as soon as one of its units
  stands inside the circle, then destroys and recreates the whole group — but it took the group's
  position from the first unit `mist.getUnitsInZones` returned, and that call returns **only the units
  inside the zone**. With unit 1 outside, unit 2 became the anchor.

  That matters because `mist.teleportToPoint` computes the displacement as
  `newCoord - newGroupData.units[1]` (`mist.lua:4470`) — the mission table's unit 1 — and applies it to
  every unit. Anchoring on any other unit therefore fed the displacement the **spacing between the two
  units**, translating the entire group by it: a truck-length for a convoy, with no dispersion asked for
  and even with `#spawnradius=0` written.

  The anchor is now the group's first unit, inside the circle or not, through a named
  `veafCombatZone.referencePositionOf`. A static is skipped — it is its own group of one — and a group
  DCS cannot produce a unit 1 for falls back on the unit at hand, saying so in the log, since an
  element with no position spawns nothing at all.

  **The backlog's diagnosis was wrong and the measurement corrected it.** It recorded the encounter
  order as a `pairs()` lottery; read end to end, every step preserves editor order, and the trigger is
  the zone's own filtering. A test written before the fix pinned it: a convoy spaced 30 m apart,
  anchored on unit 2, produced an element 30 m from unit 1.

---

## [6.15.20] — 2026-08-21

### Fixed

- **A combat zone's group now sets off along its route from where it appeared, instead of driving back
  to its editor position first.** MiST translates a respawned group's route by the teleport delta only
  when asked to (`mist.lua:4561`), and `spawnElement` never asked — so a group that came up displaced
  kept a waypoint 1 at its recorded position and walked a leg nobody had drawn.

  The fix asks for **`offsetWP1`, not `offsetRoute`**, against what the backlog had assumed. The delta
  is a *local, random* displacement around the drawn position, not a relocation: translating the whole
  route by it would move waypoints a mission maker placed on roads, bridges and passes, and would draw
  a different track on every activation. Waypoint 1 is not a design choice — it is where the group
  starts — so it is the one that follows the group, and the rest of the track stays where it was drawn.

  **The offset is unconditional, including with no dispersion at all**, and that is the finding rather
  than a detail: the delta is not only the dispersion. MiST measures it against the mission table's
  **unit 1**, while a zone's element takes its position from the first unit the zone happened to
  **meet**. When those differ, the delta carries the group's own intra-group spacing — tens of metres
  for a convoy, with `#spawnradius=0` written. Gating the offset on `spawnRadius > 0` would have been
  exactly wrong. The reference-unit mismatch is filed separately as
  `FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`; it moves where groups appear, which this fix does not.

---

## [6.15.19] — 2026-08-21

### Changed

- **The testing page no longer counts the tests, and can no longer be wrong about them.**
  `doc/TESTING.md` and its English twin carried a hand-typed "how many tests each Lua suite has"
  column. Measured against `test-lua` on the day it was dropped: **12 of 36 rows wrong** —
  `test_veafCombatZone.lua` documented at 138 for 214 actual, `test_veafGrass.lua` at 16 for 36 — and
  `test_veafMove_escort.lua` missing from the table entirely, silently, since the suite shipped.

  The backlog had measured **16** wrong four days earlier. Four rows were repaired by hand in the
  meantime, by the two lots that happened to touch them — which is the argument for this change rather
  than against it: correcting the column fixes the day it is done and nothing after it.

  The column is gone rather than corrected. Nothing decides anything on those numbers; what the table
  is for is "which suite covers what", and the real coverage figure is measured by luacov behind its
  own ratchet gate. The two other hand-written counts on the page — "36 Lua test suites" in the
  overview and "(36 files)" in the file layout, both also wrong — went with it.

  What replaced them is a check rather than a number: `docs-check` now reports a Lua suite absent from
  either testing page, using the `CoverageRule` mechanism the repository already had for MCP actions,
  marker aliases and CLI commands. A suite nobody documented is coverage nobody knows exists, which is
  worth a gate; an arithmetic total is not.

---

## [6.15.18] — 2026-08-21

### Added

- **A misspelt marker option is now refused and named, in every command rather than only `_spawn`.**
  [#33](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/33), open since 2021: an option no
  rule recognises does nothing, so the command spawned or moved something other than what was asked and
  nothing said so — a pilot could not tell his own typo from a feature that does not exist.

  The collector already existed (UXPILOT-003), complete with a nearest-match suggestion. What was missing
  is that **one** spec out of eight switched it on. Six do now — `SPAWN`, `CAS`, `MOVE`, `RADIO`,
  `TRANSPORT`, `GROUNDAI` and artillery orders — each reporting through one shared message that names the
  module and aggregates every bad key into a single line:

  ```
  VEAF SPAWN: unknown parameter(s), command aborted: 'headng' (did you mean 'heading'?)
  ```

  The name in the message is the module's own `Id` — the string it already prefixes its DCS log lines
  with — so a pilot's message and the log line up, and no invented label can drift away from the module
  it names.

  The command **aborts**. An unknown option would otherwise run a half-understood command, which is what
  `_spawn` has refused to do since UXPILOT-003; the marker is left in place so the typo can be fixed.

  `veafShortcuts`' alias spec is deliberately left out. Measured over 228 valid marker texts it flags
  **52** keys where the six switched-on specs flag none — an alias carries the parameters of the command
  it expands into and declares only its own three. A typo inside an alias is caught by the final command.

### Fixed

- **A command verb no longer reads as a mistyped option.** Keyphrase commands (`_spawn`, `_move`) were
  skipped by the collector because they start with `_`; the artillery verbs `aim` and `fire` are bare
  words and were not, so all nine valid orders measured were flagged. `veaf.prepareMarkerSpec` adds every
  command verb to the known-key set.

  A side effect worth having: an artillery order written with a **comma** instead of the semicolon it
  requires now reports `'aim,'` and suggests `aim`. It used to drop the rest of the order in silence.

---

## [6.15.17] — 2026-08-21

### Fixed

- **A player who leaves his slot is no longer registered in a unit called `nil`.** Two halves, each
  written for the right case and neither doing it. The server hook formatted the absent unit as
  `tostring(unitName or "nil")` — the four-character **string** — and the mission guarded with
  `if not unitName`, which never fires for a truthy string. So a spectator or a game master ended up as
  `veafRemote.remoteUnitsPilots["nil"]`, and both sides' comments described behaviour that never happened.

  What it cost: `veafSecurity.getUnitNameForPlayer` returned the string `"nil"` for such a player, the
  elevation refusal then logged *"cannot resolve a group for unit [nil]"* — a correct refusal with a
  fictional reason, the kind of message that costs someone an evening — and **two players in the same
  state disagreed**, since one table entry held whichever of them moved last, making the other
  unfindable.

  Both sides ship, deliberately. The hook now sends an empty string; the mission reads `nil`, `""`, blank
  and the literal `"nil"` alike as "no unit" and represents that state by **absence**, which is what the
  code already claimed to do. Fixing only the hook would have been tempting and wrong: the hook is
  deployed **by hand**, server by server, with no pipeline, so a mission built from a newer framework
  meets an older hook for as long as it takes someone to copy a file.

  The trade is stated rather than hidden: a unit genuinely named `nil` is indistinguishable from absence.
  That is the price of accepting the old payload, and there is a test pinning it so the next reader finds
  it on purpose.

  Server owners: copying the new hook is worth doing but is **not** required for the fix — the mission
  side handles the old payload.

---

## [6.15.16] — 2026-08-21

### Added

- **A combat zone can keep its units' original names.** Sharko's
  [#289](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/289), open since February 2025:
  renaming a zone's units sequentially is useful once a map is finished and gets in the way while
  debugging a `.miz`, because the name typed in the Mission Editor is gone and the unit can no longer be
  found in the logs. `renameUnitsSequentially = true` was hard-coded in the `mist.teleportToPoint` call —
  the single occurrence of that field in the whole runtime — so there was nothing to set and the answer
  was no.

  `rename_units_sequentially: false` on a combat zone in `mission.yaml` now keeps the original names. It
  is a **per-zone** setting rather than a global debug switch, which is what the request asked for and
  one less thing to remember to put back before shipping. The default stays `true`, so no existing
  mission changes and generated Lua stays byte-identical.

  A v5 mission that turned renaming off converts: the migrator reads the setter like the other six of its
  family. Documented in both languages — **along with the four keys of that family that had never been
  documented at all** (`show_units_list`, `show_zone_position_info`, `smoke_and_flare`,
  `radio_menu_disabled`): the generator accepted them and the reference table did not list them.

### Fixed

- **A trigger zone of an unexpected type no longer fails in silence, in any of the three modules that
  read one.** `if type == 0 … elseif type == 2 … end` with no `else` left the unit list untouched for any
  other value, **`nil` included** — a hand-edited mission, a zone written by a tool, a renamed DCS field.
  Each module then failed quietly in its own way:

  | Module | What it looked like |
  |---|---|
  | `veafCombatZone` | the zone activates, has nothing to kill, and the first watchdog tick announces it won |
  | `veafAirWaves` | no player is ever detected, so the wave never triggers |
  | `veafQraCore` | zero units in the zone, so the QRA never scrambles |

  The branch now lives in one place, `veaf.getUnitsInTriggerZone`, which logs an error naming the zone
  and the value into the log of whoever asked. It returns **nil** rather than an empty table for a zone
  it cannot read: "unusable" and "legitimately empty" are different answers, and a caller unable to tell
  them apart is how this defect started. No fallback shape is guessed — assuming circular for an unknown
  type would put the silent wrong answer back one level down.

  **And the difference is not cosmetic.** A combat zone whose shape could not be read is marked unusable,
  so it never completes: a zone that cannot say what it holds must not announce that everything in it is
  dead, which was the worst of the three symptoms. For a QRA and an air wave, "unusable" and "empty" lead
  to the same safe conduct — no scramble, no wave — and the code now says so where it relies on it.

  The lot was written for `veafCombatZone` alone; the sweep its own definition of done demanded turned up
  the other two. Neither of the two files the PRD had guessed at (`veafSanctuary`, the MCP's `edit_zone`)
  reads a zone's type at all.

---

## [6.15.15] — 2026-08-21

### Fixed

- **A combat zone disperses its groups again.** `veafCombatZone.DefaultSpawnRadiusForUnits = 50` has
  existed since 2020 and has been **unreachable since 2023-03-04**: an element is created with
  `spawnRadius = 0`, and the code applying the per-category default asked
  `if not element:getSpawnRadius()` — false for 0 in Lua. So the branch never ran and every group a
  combat zone spawned appeared exactly on its recorded position, with no dispersion at all. `#spawnradius=`
  worked and was the only thing that did.

  The default is now decided from whether the **tag was written**, which the builder knows exactly,
  rather than from the value the element happens to hold. That keeps `#spawnradius=0` meaning "no
  dispersion" — any scheme reading 0 as "unstated" would have taken that away from the mission maker —
  and it leaves the constructor at 0, so nothing can reach `spawnElement`'s `getSpawnRadius() > 0` with
  a nil.

  A `#command` object is still never scattered, and that is deliberate: the command runs *at its
  position*, so dispersing it would move whatever it spawns. An explicit `#spawnradius=` still applies.

  **This changes where existing missions' zone groups appear.** Three years of missions were built and
  flown against no dispersion, so a group may now come up some fifty metres from where it used to. A
  placement that was precise on purpose wants `#spawnradius=0`.

  Nothing caught this for three years because `test_defaultSpawnRadii` asserts the **constant** and never
  its application — the test and the defect coexisted happily. The new tests assert the applied radius.

---

## [6.15.14] — 2026-08-21

### Fixed

- **A combat-zone tag now counts wherever it is written.** `#alarm=`, `#spawnradius=`, `#spawnchance=`,
  `#spawncount=`, `#spawngroup=` and `#spawndelay=` were read off every unit of a group, applied to a
  zone element, and then thrown away for every unit but the one the engine happened to meet first. That
  order comes from `mist.getUnitsInZones` followed by `pairs()`, so it is not the mission editor's order
  and is not promised at all: tagging one truck of a convoy worked or did not work for no visible
  reason. A tag written on a **group** name — which the documentation has always offered — was never
  read.

  A group's tags are now collected from **its own name and from the names of all its units**. Sources
  are read group name first, then unit names in alphabetical order, and the first value found for a tag
  wins. A later source stating a *different* value is ignored with a warning in the log, so two trucks
  disagreeing no longer toss a coin; repeating the same value on several units stays silent, since that
  is the ordinary way of tagging a convoy.

  Alphabetical rather than the order the units were met in, deliberately: that order *is* `pairs()`, so
  tie-breaking on it would have reinstated the very lottery this removes, and it is not something a
  mission maker can see in the editor.

  `#command` is left out of the merge and keeps its rule: it turns one object into a one-shot trigger,
  not a setting of the group, so each unit carrying one is still its own trigger and a group can still
  carry several commands. Written on a **group** name it now makes that group one single trigger, which
  is what the documentation promised. The six settings tags do reach a `#command` element, so a
  `#spawndelay=` on the group name now applies to a command unit that carries none.

  The verification mission `verify-mission-a` was set up by tagging **both** M-1 Abrams to dodge this
  defect, so its in-game pass proved nothing about the single-unit case. It now carries the tag on one
  Abrams only, and the group was given a second waypoint so that `#alarm=2` is actually observable —
  with a single waypoint the nature-based default was already RED and nothing turned on the tag.

### Changed

- The Lua coverage floor moves from **73% to 74%**, the CI having measured 74.68% with this lot's tests
  in. The ratchet only ever goes up.

---

## [6.15.13] — 2026-08-20

### Fixed

- **A combat zone's air defences are no longer silent.** 6.15.5 gave every group that a zone spawns the AUTO
  alarm state so that convoys would finally drive their route
  ([#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290)) — but a SAM battery on AUTO
  keeps its radars down, so the same change made every air defence inside a combat zone go quiet. One
  defect traded for another, on a version that was **never published**, which is the only reason nobody
  outside the repository saw it.

  The zone now picks the state from the **nature of the group** instead of applying one default to all:
  a group with a route to drive gets AUTO, so it leaves; a group that stays put gets RED, so it fights.
  `#alarm=N` still overrides both, in either direction.

  The trade was named in the previous fix's own PRD — *"right for a SAM battery, wrong for a convoy"* —
  and answered with a single default plus `#alarm=N` as the escape hatch. An escape hatch that every
  mission maker has to apply to every existing battery is a regression, not an option; hence choosing per
  group. A `#alarm=2` added on a battery in the meantime still works and is now redundant.

  Criterion and its alternative, recorded because it is a judgement call: **more than one waypoint means
  the group is meant to move**, which is the reason AUTO exists here at all. Asking instead whether the
  group *contains* a SAM launcher would be more precise about air defence but answers the wrong question
  — a supply convoy with an escort SAM would come out "air defence" and stop moving, which is the very
  bug #290 was about.

---

## [6.15.12] — 2026-08-20

### Fixed

- **A tanker's orbit is found wherever it is in the route.** `veafMove` looked for it on the
  second-to-last waypoint, which is true of VEAF's own templates — whose route is [approach, orbit, leg
  end] — and false of a DCS-Liberation tanker, whose longer route ends with a landing point. Both tanker
  commands then refused with *"has no ORBIT task defined"*
  ([#248](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/248), reported by Maveric). The
  orbit is now searched for by its task rather than counted backwards from the end.

  Maveric's postscript — *"potentiellement le faire pour les autres manipulations de tanker"* — is
  covered: there are two, `_move tanker` and `_move tankermission`, and they already shared the helper,
  so both are fixed at one point.

  Decisions recorded, since the issue left them open: **the first orbit wins** when a route carries
  several (it is the one the tanker reaches first, so the one active or imminent); a route with **no**
  orbit is refused with a message rather than adjusted on a guess; and the waypoints before and after
  the orbit became **optional**, so an orbit on the first or last waypoint of a route is no longer
  refused for being in the wrong place.

  One trap avoided rather than fixed: `_move tanker` **overwrites** the waypoint after the orbit, using
  it as the far end of the refuelling leg. That is right by DCS's own semantics for a `Race-Track` orbit,
  which flies between the task's waypoint and the next one — but a `Circle` orbit turns around a single
  point and gives that waypoint no role, so overwriting it would silently redraw the route, and on a
  Liberation tanker it could be the landing point. `Circle` orbits now leave it alone, and `_move tanker`
  asks for `distance` and `hdg` when it cannot work the leg out.

---

## [6.15.11] — 2026-08-20

### Fixed

- **A FARP's escort no longer lands on whatever is already there.** `-farp` placed its escort, tents and
  props at a fixed distance on a fixed bearing, with **no test of whether that spot was free**
  ([#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232), Sharko 2023, reproduced in
  game 2026-08-17). Beside a static FARP the trucks came down on its pads, the lead `M 818` close enough
  to a helipad that a helicopter landing there met it. And that is the **nominal** use, not an edge case:
  the static FARP is what unlocks spawning on it once the zone is captured, so `-farp` is run on top of
  one on purpose.

  The module now walks around the FARP until the ground is clear — **keeping the distance and changing
  the bearing**, since growing the radius would push the escort away from the FARP it serves. The whole
  group is tested rather than its origin, because the escort sits on a ~30 m line and a clear origin with
  an overhanging tail still blocks a pad. **A FARP with clear ground around it does not move at all**:
  the original bearing is tried first, so no working mission changes. If nothing is clear the FARP is
  still built, at its original position.

- **A `FARP_T` is laid out as the FARP it is.** The list of FARP platform types existed **four times** in
  `veafGrass.lua`, and commit `a454c577` (2025-08-08) added `FARP_T` to exactly one of them — the one
  that *recognises* FARP units. So a `FARP_T` was processed as a FARP and then measured as if it were
  not: escort at 75 m instead of 150, tent at 100 instead of 200, windsock at 50 m/45° instead of
  120 m/0° — which put its escort straight onto the pads by a second route. The four copies are now one
  predicate, and a FARP-looking type that is **not** in it says so in the log instead of silently taking
  the default distances.

  Visible consequence: a `FARP_T` in an existing mission has its props move outwards to the FARP
  distances. That is the fix, not a side effect.

---

## [6.15.10] — 2026-08-20

### Fixed

- **A red pilot no longer runs blue's carrier operations.** Opening *Carrier operations* showed both
  sides' submenus to everyone, so a red player could start and stop the blue carrier's recovery window
  ([#87](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/87), measured in game on 2026-08-18
  from a red A-10 at Palmyra). The per-side menus already existed and the renderer already filters on a
  coalition — the two menus were simply created without stating theirs. The other half of #87, *"red
  cannot run its own"*, was **already fixed** and is closed as such. Each carrier's own submenu sits
  under its side's menu and inherits the scope, so the shared **CARRIER OPS** root stays common: it
  carries the help entry.

  The sweep this came with is worth recording, since a menu built per side and rendered to everyone is a
  defect *shape*: all **43** `addSubMenu` call sites were enumerated rather than hand-picked, of which 40
  are callers and exactly one was already scoped. No other module builds a menu per side, so this defect
  had two sites and no siblings. Two suspicions the enumeration raised were checked and turned out fine —
  scope inheritance is transitive across generations (now pinned by a test, since this fix depends on it)
  and pagination already scopes its overflow pages.

---

## [6.15.9] — 2026-08-20

### Fixed

- **A combat zone's delayed command no longer leaves a group behind.** A zone can carry a VEAF command
  on a fake unit, and that command can be delayed — `-samsr!30`. The zone passed a collection table
  down and read it on the very next line, but a delayed command hands its work to a scheduler and
  returns immediately: the table was empty, the group was registered nowhere, and deactivating the zone
  could not destroy it. The SAM outlived the zone that spawned it
  ([#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66), open since the v5 era,
  confirmed in game on 2026-08-18).

  **Two things widened this beyond the report.** The table was never lost — it is passed by reference
  into the deferred call and *is* filled later; nobody read it again. And there are **three** deferring
  paths, not one: an alias delay, a spawn's `delay` option, and a spawn's repeats. A zone therefore also
  lost the groups of every repeat past the first. A caller can now ask to be told about each group as it
  appears, so all three are fixed at once. `#spawndelay` never had the problem and is untouched.

  A group that appears *after* its zone was deactivated is now destroyed rather than registered:
  nothing can cancel an already scheduled spawn, so that is the outcome the deactivation would have
  produced.

---

## [6.15.8] — 2026-08-20

### Added

- **`dynamic_spawn` is now a `mission.yaml` field** under `modules.SKYNET`, so a mission can ask the
  IADS to take in the SAMs that appear while it runs. That was the whole of
  [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) (*"combat-zone SAMs are not in
  the IADS"*): measured in game on 2026-08-18, the path **works** — a combat zone's SA-6 does join the
  red network. The flag that enables it was simply off, and reachable only through the
  `module_settings:` migration hatch, which is a compatibility path and not an interface. Documented
  in both languages with what it costs: a birth-event handler on every spawn of the mission, which is
  why it stays off by default.
- **`veafSkynet.activateNetworkOfCoalition`** — the half of the API that was missing. Since a
  deactivated network now stays deactivated (below), there had to be a way back that is not a full
  reinitialisation. Everything attached while the network was down comes up with it.

### Fixed

- **A network switched off on purpose stays off.** Spawning a single SAM into a deactivated IADS
  brought the whole network back up ([#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261),
  confirmed in game 2026-08-18 with the chain measured end to end). `addGroupToNetwork` finished with
  an unconditional `delayedActivate`, and nothing anywhere recorded that the network had been switched
  off deliberately. The group is still attached — that is what `skynet true` asks for — it just no
  longer wakes the network up.
- **Deactivating one coalition's network no longer disarms the other's.** `deactivateNetwork` removed
  the birth-event handler *shared by every network*, and nothing ever re-armed it: switching off red
  silently stopped blue from integrating anything it spawned for the rest of the mission. The setting
  is now per network, and the shared handler stays armed as long as some network wants it.
- **A spawn's `skynet` option is honoured on the dynamic path.** `skynet true|false|<network>` has
  always been a per-spawn option, and the birth-event handler never looked at it: it integrated every
  eligible group it saw. So with dynamic integration on, `-hv_convoy_red` — which passes `skynet false`
  precisely to stay out — joined the IADS anyway, its Tor and Tunguska being enough to qualify. A
  network name now also wins over the coalition default, which that path used to ignore. A group no
  VEAF command declared, placed in the Mission Editor or created by a third-party script, still joins
  its coalition's network: that is what the feature is for.

---

## [6.15.7] — 2026-08-20

### Fixed

- **A respawned tanker keeps its escort.** Respawning an asset from the F10 menu gave it a new DCS
  group id, which silently invalidated the `Escort` task of its escort: the escort held for a while,
  then flew out its route and landed after about ten minutes
  ([#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107)). The teleport path
  (`_move tanker … teleport`) had always repaired this, which is why the same escort stayed put for
  thirty minutes when teleported and gave up when respawned — measured in game on 2026-08-18. The
  repair is now **one shared implementation** used by both paths, so the next DCS quirk of this kind
  has one place to be fixed rather than two to diverge.
  [#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) is closed with it, as not
  reproducible: the teleport it reported as broken works, and is what this fix is ported from.

### Documentation

- **An asset's escort is the group named `<asset> escort`** — a convention the framework has always
  relied on and that nothing told a mission maker about. Now on the ASSETS page in both languages,
  including what it is *not*: `linked` lists groups to respawn alongside an asset and has nothing to
  do with declaring an escort. The page also names the symptom, since that is how a mission maker
  arrives on it — an escort that goes home after ten minutes.

---

## [6.15.6] — 2026-08-20

### Fixed

- **A save no longer fails because a virus scanner was reading the file.** Every atomic write ends by
  renaming a temp file onto its target, and on Windows that rename fails intermittently with
  `PermissionError: [WinError 5]` while something outside the process still holds the file just
  written. Measured with a probe involving no VEAF code at all: **8 failures in 300 writes**, the
  target never read-only, and **a single retry 50 ms later cleared every one of them**. The three
  atomic writes now retry instead of giving up — writing a `.miz` (`write_miz`), rewriting one of its
  members (`rewrite_miz_members`), and installing a downloaded executable in the updater, which is the
  most exposed of the three since a fresh `.exe` is what a scanner is most certain to open. A genuine
  permission problem still fails, with its own message, and a failed write still leaves no temp file
  behind.

---

## [6.15.5] — 2026-08-20

### Fixed

- **A convoy placed in a combat zone finally drives its route.** Activating a zone put every group it
  spawned on **RED** alert, and a DCS ground group on red alert holds position and deploys — right for
  a SAM battery, wrong for a convoy, which never left its start point
  ([#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290), open since April 2025).
  Zones now spawn groups on **AUTO**, where DCS raises the group's own alert level on contact: the
  convoy moves and a defence still fires once it detects a target.

### Added

- **`#alarm=N` unit-name tag for combat zones.** Sets a single group's alarm state (`0` AUTO, `1`
  GREEN, `2` RED) instead of inheriting the zone's default, so air defence that must be hot from the
  first second can be marked `#alarm=2`. An unreadable or out-of-range value falls back to AUTO rather
  than failing the zone — and **says so in the log**, since a silent fallback makes a typo
  indistinguishable from a deliberate AUTO. Documented in both languages, and added to the
  reserved-marker set the MCP server warns about.

---

## [6.15.4] — 2026-08-19

### Fixed

- **`veaf-tools.exe` starts again.** Every 6.15.x executable died on any command — including
  `--help` — with `ModuleNotFoundError: No module named 'mission_builder.mission_builder_README'`,
  reported by Tripack. The `mission_builder` package started resolving its exports lazily in 6.15.0,
  and PyInstaller decides what to bundle by reading `import` statements: with the submodules named
  only in a table read at runtime, none of the eleven modules behind it shipped. The build now
  collects the package wholesale, so an export added later needs no build change.
- **A packaged-only failure can no longer ship unnoticed.** The CI builds the executable and runs it
  on every Python change; until now every test ran from a checkout, where the missing imports resolve
  perfectly — which is why this shipped, and the two bundled-data defects before it.

---

## [6.15.3] — 2026-08-19

### Fixed

- **A mission whose tables are numbered `1,3,4` no longer kills the build with an unrelated
  traceback.** A Lua table reaches Python as a list when its keys are contiguous and as a dict
  otherwise, and eight readers assumed the list — so a hand edit, a third-party tool or a deletion
  made the build die on `AttributeError: 'int' object has no attribute 'get'` at whichever subsystem
  read the table first. Group containers, units, route points, trigger zones, zone vertices, map
  drawings and nested tasks are now normalised **once, on the read path**. Measured: the
  normalisation changes zero bytes on every mission in the repository, and `payload.pylons` is
  deliberately left alone — it is keyed by station number, and renumbering it would move every weapon.
- **A closed-up hole is named.** `validate` warns with the offending table's full path
  (`coalition.blue.country[1].plane.group: keys 1, 3 -> 1..2`) and the build logs the same, instead of
  repairing it in silence.
- **`add_group` writes a patrol task DCS can see.** Its task table used the string key `"1"`, which
  `luadata` renders as `["1"]` — a different Lua entry from `[1]`, leaving `#tasks` at zero, so the
  loop never applied. Every real mission writes `[1]`.

---

## [6.15.2] — 2026-08-19

### Fixed

- **`build --dev-mode` no longer deletes whatever sits after the build marker in `mission.yaml`.** The
  `build:` section was persisted by truncating the file at its marker and rewriting the tail, so
  anything a mission maker wrote after it was eaten by the next build — silently. Measured: a
  `security:` block with its password hashes and the file's trailing comment, all gone in one call.
  The replacement is now bounded at the end of the `build:` block.
- **`mission.yaml` keeps its LF line endings.** Both writers (`_update_build_config_in_yaml` and
  `mission_yaml_editor.save_yaml`, the one the MCP composites use) let Python translate newlines, so on
  Windows a call meant to touch one section rewrote **every line of the file**. Found by the new
  round-trip test helper on its first use.

---

## [6.15.1] — 2026-08-19

### Added

- **MCP: `remove_group`** removes a group and **renumbers** the container it leaves behind, so a
  removal can no longer leave the `1,3,4` hole that made three builds die on a traceback pointing
  nowhere near the edit. It names the references that would otherwise break in silence: a combat zone
  capturing the group by name prefix, an `Escort` task pointing at its group id, and a
  `modules.ASSETS` entry in `mission.yaml`.
- **MCP: the editing actions accept a mission folder**, not only a `.miz` — `edit_route`,
  `set_group_properties`, `set_unit_properties`, `edit_zone`, `add_trigger_zone`, `add_map_drawing`
  and `edit_map_drawing`. A folder edit is durable (it survives the next build) and each action now
  reports `durable`. A directory that is not a mission folder is refused with a message saying so,
  instead of an `[Errno 13] Permission denied`.
- `dcsUnits.yaml` carries each air type's internal fuel capacity (`fuel_capacity`, from the
  datamine's `M_fuel_max`). `dcsUnits.lua` is unchanged.

### Fixed

- **MCP: an aircraft created by `add_air_group` or `add_player_slot` has fuel.** Both wrote
  `payload.fuel = 0` — no fuel at all — so a flight created in the air fell out of the sky the instant
  it appeared; a parking start hid it, DCS fuelling a parked aircraft from the airfield's stock. The
  default is now the type's full internal fuel, with optional `fuel` (kg) and `fuel_fraction`
  parameters. An aircraft type the units database does not know is created without a fuel key and the
  caller is warned.
- **MCP: `create_combat_zone` writes its zone inside the list**, not below the commented-out block
  trailing it — where it read as if it belonged to whatever section that comment introduces. The same
  fix covers `create_qra` and `create_cap_mission`, which appended to `mission.yaml` lists the same
  way.
- The backlog index's status cells carry the icon alone again, so the consistency check reads them
  instead of skipping the row.

---

## [6.15.0] — 2026-08-17

### Fixed

- **Every airfield turned neutral in a mission built with 6.14.2** (FIX-WAREHOUSES-LIST-FORM).
  Reported by Tripack with two builds of the same mission: its `warehouses` member fell from 261 KB
  to 141.7 KB, and 29 airfields carrying 26 RED, 1 BLUE and three aircraft stocks came out as 30
  NEUTRAL entries with no stock, no `allowHotStart` and no `dynamicSpawn`. DCS keys the airfield
  table by airdrome id, so a mission declaring every airfield of its theatre has the ids `1..N` —
  and the Lua parser renders a contiguous integer-keyed table as a **list**. The build's guard read
  that as "absent or malformed" and replaced the mission's own airfields with an empty table before
  filling it with neutral defaults; it caught the nominal case rather than the broken one. The table
  is now normalised at load, keyed from 1, and a mission nobody touched is written back
  byte-identical. `set_airbase_coalition` and the warehouses injector were raising on the same
  shape and are fixed with it.

  **If you built a mission with 6.14.2, rebuild it with this version** — its bases are neutral. Your
  mission *sources* are untouched: the build never rewrites them, so a rebuild is all it takes.

- **A multi-line briefing truncated the conversion of a combat zone** (FIX-CONVERT-V5-SILENT-LOSSES,
  [#722](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/722)). The builder-chain walker
  accepted only lines starting with `:`, and a Lua string concatenation continues with a quote — so
  a multi-line `setBriefing` ended the chain and **every setter written after it was dropped**. The
  loss was positional, not setter-specific, so nothing about the missing setting pointed at the
  cause. Measured by Sharko on his campaign corpus: **302 truncated briefings out of 1864 zones**,
  worst case a 137-character briefing migrated as 6.

### Added

- **`convert-v5` now says what it cannot carry** ([#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725)).
  It generates `mission-script.lua` from scratch and deletes `missionConfig.lua`, and half the
  scalar settings reached neither `mission.yaml` nor the generated Lua — with no warning, because
  nothing looked. Settings that still cannot be expressed (a table, a function) are now listed
  verbatim under a **"Settings NOT migrated"** block in the generated file *and* named in the
  conversion report, the way callback hints already were.
- **`module_settings:`**, a new `mission.yaml` section carrying scalar settings written straight
  onto a VEAF module table (`veafSkynet.DelayForStartup`, `veafRadio.RadioMenuName`…). Generic
  rather than a key per module: the fourteen dropped settings were measured on one mission maker's
  corpus, so named keys would have covered those and left the next fourteen to be found the same
  way. A key outside the `veaf` namespace is refused at generation time.
- **Six `combat_zones:` settings that the schema could not express**
  ([#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723)): `completable`,
  `show_units_list`, `show_zone_position_info`, `smoke_and_flare` and `radio_menu_disabled`, plus
  `setEnableUserActivation(false)` mapped onto the existing `user_activation_disabled`. Every
  framework default is `true` and these are used to turn a feature **off**, so losing one inverted
  the behaviour rather than neutralising it — `completable` most of all: without it, a zone holding
  no RED unit self-completes ~60 s after activation and chains onward. Counts on the reporting
  corpus: 1135 zones each for the first four, 171 for `disableRadioMenu`, 82 for `setCompletable`.
- **A mission's own level-1 password hashes** now survive the conversion into
  `security.password_hashes`. The two hashes `veafSecurity.lua` ships to **every** mission are
  deliberately skipped: they live in a public repository, and carrying one into a mission's own
  list would re-open the hole `SECREV-2 / VMR-040` closed.

### Changed
- **Importing `mission_builder` no longer loads the whole package** (and, through it, pydantic).
  Symbols resolve lazily (PEP 562), so `from mission_builder import X` imports what X needs and
  nothing else — reported by Sharko, whose measurement harnesses use `ConfigMigrator` as a library.
- **The role of GitHub Issues is now written down** (CHORE-GITHUB-ISSUE-TRIAGE): they are the
  intake desk, `.backlog/` is the tracker, and a lot is never mirrored as an issue. The 63 open
  issues were re-read against the v6 code and labelled `v5-era`, `probably-done`, `still-valid` or
  `verify` — 49 of them date from 2020-2023, and several were fixed years ago without anyone
  closing them. Nothing was closed: the evidence behind each verdict lives in the lot's PRD so a
  human confirms before an old report from a contributor disappears.

---

## [6.14.2] — 2026-08-16

### Fixed

- **Assigning one airfield to a coalition disabled all the others** (FIX-WAREHOUSES-INCREMENTAL).
  The build filled the airfield table only when it was **empty**, which the documented workflow
  breaks immediately: one `set_airbase_coalition` call leaves a table with a single entry, the build
  then adds nothing, and the mission ships with 1 airfield out of 225 — the defect
  FIX-EMPTY-WAREHOUSES fixes, reintroduced by using the MCP as intended. The table is now
  **completed**: missing airfields are added, an existing entry is never touched (it carries the
  mission's own ownership and stock). With that, dynamic slots work by default on every airfield of
  a coalition, which needs no new code — the existing `warehouses.yaml` step already reads "no
  airfield list" as "every airfield of that coalition", sets `dynamicSpawn` and stocks the
  templates. It only ever needed airfields that *have* a coalition.
- **An airfield entry could exist and still be unusable.** `set_airbase_coalition` wrote **5 keys**
  where DCS expects **20** — no `unlimitedAircrafts`, no fuels, no operating levels — and the
  build's completion pass skipped it because it existed. In game that reads as parked slots that
  cannot be taken and a dynamic-slot catalogue showing zero aircraft in every type. Fixed at both
  ends: the MCP writes a full entry, and the build completes a partial one key by key without ever
  overwriting what the mission already set.
- **A dynamic slot could only be taken cold.** `allowHotStart` — the field behind the "spawn hot"
  option — is written `false` by the DCS Mission Editor, and nothing turned it back on. An airfield
  the mission opens to dynamic slots now offers a hot start; `hot_start: false` under a coalition's
  `defaults:` in `warehouses.yaml` returns to cold starts only.

### Documentation

- **The shipped dynamic-slot templates are a starting point, and the guides now say so.** A pilot
  taking a dynamic slot gets the aircraft as its template describes it, and only **9 of the 52**
  templates shipped by default carry a loadout — an A-10C II comes out armed and painted, a UH-1H
  or an F/A-18C comes out bare. The link works (measured in game); the template is empty. Both
  guides name the two families and give the `content extract-aircraft-groups … --kind
  dynamic-template` command that replaces them with the mission maker's own.

- **CTLD never started in a built mission** (FIX-CTLD-NEVER-INITIALIZED). Reported by Tripack on a
  6.14.0 mission: *no CTLD entry in the radio menu*, and the mission's first `-fob` raising
  `CTLD.lua:9109: attempt to perform arithmetic on local 'interval'`. Both come from the same
  missing line. Since FEAT-CTLD2-INTEGRATION, `veaf.lua` **registers** CTLD as a VEAF module
  (`veaf.registerModule`, order 50) rather than starting it — and a registration is consumed by
  `veaf.initialize()` alone, which the generated `veaf-config.lua` never calls, initializing each
  module one by one instead. So `ctld.initialize()` never ran, CTLD's configuration was never
  loaded, and `ctld.gs("smokeRefreshInterval")` returned nil the moment `spawnFob` reached a CTLD
  manager. The generator now emits the start-up call, **before** the module block so CTLD is up
  ahead of `veafGrass` and `veafAssets`, the two modules that call into it. Nothing in the test
  suite could see the gap: `veaf.ctld_initialize` existed in three places — its definition, the
  registration, and a Lua test calling it **directly** — and the string `veaf.initialize` appeared
  nowhere in the generator. **A mission built with 6.14.0 or earlier must be rebuilt**, or carry
  `if ctld then veaf.ctld_initialize() end` in its `mission-script.lua`. Confirmed in game.
- **A CTLD that was loaded but never started now refuses instead of crashing.** The nine VEAF call
  sites guarded by `ctld and veaf.isEnabled("ctld")` — across `veafAssets`, `veafGrass`,
  `veafSpawnAircraft`, `veafSpawnEffects` and `veafSpawnGround` — go through `veaf.isCtldReady()`,
  which also checks `CTLDConfig.get().isLoaded`, the flag `ctld.initialize()` raises once it has
  parsed the configuration. That third state used to reach the vendored engine and die on a nil
  setting, in a stack trace naming neither CTLD nor the missing call; it now logs what to do about
  it. Two comments asserting the opposite of the truth (`lua_config_generator`'s *"started by
  veaf.lua"*, `config_migrator`'s *"veaf.initialize() in veaf-config.lua calls all module init
  functions"*) are corrected, and ADR 0016 describes the whole chain rather than half of it. The
  crash inside the vendored engine is reported upstream as
  [VEAF/CTLD#125](https://github.com/VEAF/CTLD/issues/125).

- **A built mission had no usable airfield, so no parked slot could be taken** (FIX-EMPTY-WAREHOUSES).
  A `.miz` keeps each airfield's coalition and stock in its `warehouses` table, one entry per
  airfield of the theatre. A mission built from a blank or scratch-made source had `airports = {}`,
  and DCS then refuses to seat a pilot on a ramp: the slot appears in the list, can be selected, and
  never takes. An air start does not go through that table, which is why this survived until someone
  parked a helicopter. Nothing reported it — `validate` was clean, the build said nothing, and the
  warehouses injector logged "0 airports configured", which reads like a mission that declared none.
  Opening the mission in the DCS Mission Editor and saving it repairs the file, which is exactly why
  such a mission "works when launched from the editor". The build now writes those entries itself,
  from the runtime-sourced `airdromes.yaml`, in the shape the editor writes them (`NEUTRAL`,
  ownership being resolved at runtime). A mission that already declares airfields is left untouched.
  Measured on the smoke-test mission: `warehouses` 69 bytes → 150 040, 225 airfields.
- **`set_airbase_coalition` reported success without writing anything.** It mutated the warehouses
  table and returned `durable: true`, but `write_mission_folder` only ever wrote the `mission` file
  — so an airfield's coalition, which lives in `warehouses`, never reached the disk. The folder
  writer now persists that table too, when the folder has one.

- **Every helicopter slot the MCP created was unflyable** (FIX-MCP-AIRCRAFT-CATEGORY). `add_air_group`
  and `add_player_slot` both hard-coded `category="plane"`, and a DCS mission files aircraft under
  `plane` or `helicopter` as two non-interchangeable keys — a helicopter under `plane` opens in the
  Mission Editor as an AIRPLANE GROUP with its type in red and cannot be flown. Nothing in the
  mission file marks the error, and the suite stayed green because no assertion looked at the
  category. The category is now resolved from the aircraft type against the generated
  `dcsUnits.yaml` (the database `list_unit_types` already serves). A type absent from it — a
  third-party mod — still lands under `plane`, but the action returns a warning naming it rather
  than guessing in silence, and both actions now report the `category` they chose.

- **CTLD spoke English on a French mission** (FIX-CTLD-LANGUAGE). CTLD 2 hard-codes
  `ctld.i18n_lang = "en"`, the key is not even in the engine's default catalogue, and nothing on the
  VEAF side ever aligned it — so its radio menu ignored `mission.language` entirely. Reported in
  game the day the CTLD menu first appeared. `veaf.ctld_initialize()` now sets CTLD's language from
  `veaf.config.language`, **before** `ctld.initialize()` so the startup report is translated too. It
  writes the module **global**, which CTLD's own `_activeLang()` reads *after* its config setting:
  an explicit `i18n_lang:` in a mission's `ctld-config.yaml` still wins, as ADR 0016 intends. A
  language CTLD has no dictionary for (it ships `en`, `fr`, `es`, `ko`) is left alone and logged
  once, since `ctld.tr()` warns for every string it cannot resolve.

- **The `dcs-fiddle-server.lua` debug hook wiped out the VEAF framework mid-mission**
  (FIX-FIDDLE-HOOK-CLOBBERS-VEAF). The hook opened with `veaf = {}` — a line this repo added the day
  before — and it is injected into the **mission scripting environment**, the same Lua state the
  framework lives in, *after* the mission scripts have loaded. Measured in the DCS log: 33 ms
  between the hook starting and `veaf.loggers` being nil. Every VEAF event handler then raised on
  every DCS event, and `veaf.ctldLogLevels` being nil made the `ctld.utils.log` override raise
  inside CTLD's own `onEvent` — the handler that builds a player's CTLD radio menu, so the menu
  never appeared. The hook's table is now `veafFiddle` (nothing outside the hook referenced it), and
  a guard fails the build on a global `veaf` assignment in that file. **The hook is hand-deployed**:
  copy `src/scripts/other/dcs-fiddle-server.lua` over `%USERPROFILE%\Saved Games\DCS\Scripts\Hooks\`
  to pick the fix up. Only affects a workstation with the hook installed. Confirmed in game.

## [6.14.0] — 2026-08-15

### ⚠️ Behaviour change — tell your pilots before you ship this

**`/login` and `_auth` no longer unlock the mission for everybody.**

Until now, one successful authentication opened every secured command to **every player on the
server** for `authDuration` minutes. That was the whole point of the password, and it is now gone:
each secured command checks who is asking.

What your pilots will notice:

| | |
|---|---|
| **A pilot listed in `veaf-pilots.txt`** | nothing changes — their own level already granted them their commands, and they never needed the password |
| **A pilot who is not listed** | must give the password **on every command**. There is no ten-minute session any more |
| **The F10 radio menu** | DCS cannot tell *which* occupant of a group clicked, so a group acts at the level of its **lowest-graded** occupant. `_auth` or `/login` from a marker or the chat raises that group to the **requester's** level for 2 minutes |

That last line is what solves flying with someone less privileged — an instructor with a student
keeps their own commands by authenticating, without lending the student anything.

Alias passwords follow the same principle: being listed in `veaf-pilots.txt` at all excuses them,
whatever your level. An unknown author still has to type the password.

`veaf.SecurityDisabled = true` still turns the whole layer off for a solo or test mission.

See [`doc/mission-maker/scripts/veafSecurity.md`](doc/mission-maker/scripts/veafSecurity.md).

### Added
- **Le harnais de fumée DCS est complet : mission de test committée, évitement `Disposition` mesuré, deux limites actées** (`FEAT-DCS-SMOKE-HARNESS` tickets 01 & 03, en jeu le 2026-08-15). **Ticket 01** : `test/veaf-tools/smoke-test-mission/` est la mission de test committée (source ; le `.miz` est un artefact reproductible, gitignoré) — théâtre Syria à l'ancre `(-32220, 405386)`, slot joueur A-10C + groupe sol + zone de combat, valide et bâtit proprement. L'ancre a été **vérifiée en jeu** (pas crue) : une unité spawnée là puis détruite produit un événement de mort que le harnais capte ; le contre-exemple « au-dessus de l'eau les morts sont perdues » reste crédité à dcs-sms dans la doc. **Ticket 03** : `Disposition.getSimpleZones(centre, rayon, arg3, count)` renvoie des points `{x, y, course}` ; son **évitement est mesuré** — centré sur un aérodrome portant 369 objets scenery dans 2 km, les 30 points rendus sont à 0 sur du scenery (≤10 m) et tous sur du sol ; il **rend moins que demandé quand l'espace dégagé manque** (150 m → 2, 500 m → 10, désert → 30), ce qui rend nécessaire le repli de `veaf.findSpawnPoint` ; ~43 ms/appel. Un **check de non-régression `disposition-avoids-scenery`** encode cette mesure et **passe en direct**. L'ADR 0018 et TUM-EXPLOIT.md, restés à « asserted, not measured » alors que `FEAT-SCENERY-AWARE-SPAWN` avait sondé le 2026-08-06, sont réconciliés. Deux limites actées plutôt que masquées : le **chargement de mission sans surveillance en solo est abandonné** (`net.load_mission` est SERVER ONLY, no-op depuis le menu ; aucune API SP documentée), et les questions Foothold (`dcs.log`) et checklists restent des questions ouvertes pour une session dédiée.
- **Le harnais de fumée DCS gagne le cycle launch → load → assert → quit** (`FEAT-DCS-SMOKE-HARNESS` ticket 02). La première tranche s'arrêtait à « DCS doit déjà tourner » ; `veaf-tools dcs smoke-test --full --mission <chemin.miz>` localise `DCS.exe` (via le dossier d'installation que la sonde rapporte, ou `--dcs-exe`), lance DCS, attend que le hook réponde, appelle `net.load_mission`, attend que la mission soit active, exécute les vérifications, puis **quitte DCS — toujours, même en cas d'échec**, sinon le run suivant hérite d'une instance restée ouverte. Chaque attente est bornée et nomme l'étape qui expire ; la mesure du gel du compteur d'images pendant le chargement (~24 s) fait surveiller le **nom** de la mission plutôt qu'un compteur qui gèlerait un watchdog naïf. Un DCS déjà lancé est **refusé** par sécurité (charger une mission écraserait la session) ; `--allow-running` lève ce garde-fou et ne quitte alors pas une instance qu'il n'a pas démarrée. L'orchestration est couverte par des tests à doublures injectées. **Limite mesurée en jeu le 2026-08-15** : `net.load_mission` est présent et `isServer()` vrai en solo, mais l'appeler depuis le menu **renvoie nil et ne charge aucune mission** (ED le documente SERVER ONLY ; il faut un serveur en cours). Donc `--full` **ne peut pas charger en solo** : il échoue proprement au délai en le disant, plutôt que de mentir ; pour vérifier en solo, charger la mission à la main et lancer `smoke-test` sans `--full`. Le chargement sans surveillance en solo reste non résolu (piste : mission en ligne de commande). Corrigé au passage, trouvé par ce run : le fork du hook sérialise un retour **nil** en `[]`, que le client rejetait — un appel qui ne renvoie rien (`net.load_mission`, `exitProcess`) est désormais lu comme un nil, pas une erreur.
- **La mission de démonstration est passée en v6** (`MIGRATE-DEMO-MISSION-V6`). `test/veaf-tools/demo-mission/` était encore **v5 dans sa structure** (pas de `mission.yaml`, un `missionConfig.lua`, les dossiers frères v5) — la première chose qu'ouvre un nouveau mission-maker, incohérente à côté d'un outillage v6. Le blocage était que deux tests de migration lisaient la démo **comme un artefact v5** : ils ont désormais leur propre fixture v5 gelée (`test/veaf-tools/migration-v5-fixture/`, une copie du config et des presets d'origine), donc les six renommages de presets et la migration de config restent couverts, depuis une fixture que les tests possèdent. La démo est ensuite convertie par `convert-v5` (mission.yaml + src/ v6), et **démontre du v6** : zones de combat et une opération complète (`goriOperation` avec ses `tasking_orders` et leurs `dependencies`) déclarées en YAML, config déclarative des modules (ASSETS, SHORTCUTS, SANCTUARY, AIRWAVES), et surtout un `custom_scripts` avec `delay_seconds` — la feature `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` invisible dans tous les autres exemples. Le README du dossier nomme ce qu'elle montre. **Un défaut du validateur révélé au passage, corrigé** : `SANCTUARY.polygon_units` n'était vérifié que contre les noms d'**unité**, alors que le runtime résout `Unit.getByName` puis `Group.getByName(...):getUnit(1)` — les 16 groupes-polygones de la démo (nommés `Sanctuary_Kutaisi_Polygon #NNN`, unité `Ground-1-1` dedans) étaient donc signalés en erreur à tort ; le validateur accepte maintenant un nom d'unité **ou** de groupe, comme le runtime. La démo valide sans erreur et construit. Le `veaf-config.lua` (généré au build) que la conversion déposait à tort en source est retiré, et un `.gitignore` (repris du modèle) évite de committer les artefacts de build.
- **Trois formes de dessin de plus sur la carte F10** (`FEAT-MCP-MUTATION-ACTIONS` ticket 10). `add_map_drawing` livrait ligne, rectangle et étiquette ; il ajoute maintenant le **cercle** (`radius`), l'**ovale** (`r1`/`r2`/`angle`) et le **polygone libre** rempli (`points`, trois ou plus, relatifs à l'ancre comme une ligne) — structures **mesurées** sur `bridge-Syria-editeur.miz`, où David a dessiné une de chaque le 2026-08-15, pas devinées. **`arrow` et `icon` restent refusés, mais avec une raison** au lieu d'un « non mesuré » générique : une flèche stocke un contour calculé de 8 points en plus de ses `length`/`angle`, donc l'écrire demande un aller-retour en jeu pour savoir si DCS recalcule le contour ; une icône réclame un `file` du jeu d'icônes de l'éditeur qu'aucune donnée du dépôt n'énumère. Un test garantit qu'une forme est soit livrée soit refusée, jamais les deux, et que `chevron` — retiré car inexistant dans l'éditeur — n'y revient pas. Documenté dans le catalogue mission-maker et la référence développeur, deux langues.
- **L'assistant peut poser un vol au parking, places résolues toutes seules** (`FEAT-MCP-MUTATION-ACTIONS` ticket 09, `add_air_group`). *« Un deux-ship de F-16 au parking de Kobuleti »* : on donne un **nom** d'aérodrome et un nombre, l'action choisit ce nombre de places libres — les plus proches de la piste d'abord — que la mission n'occupe pas déjà, et pose chaque appareil à la **position exacte** du stand. Départ moteurs coupés/chauds au parking, sur la piste, ou en vol ; appareils en IA par défaut (ou slots joueur sur demande). **Le blocage a été levé en jeu** : `parking_id` est absent de la capture (`Term_Index_0` = -1 partout) et n'a aucune règle dérivable, mais David a chargé une mission témoin où trois A-10 posés à la position exacte avec `parking` = `Term_Index` et `parking_id` = `parking` se garaient et se pilotaient correctement — donc `parking_id` n'est **pas porteur** quand la position et `parking` sont exacts, et la capture suffit. **Seuls les types de terminal 104 et 68** sont proposés comme parking (mesuré : les avions parkés des vraies missions Caucasus n'occupent qu'eux), un aérodrome sans place de ce type est refusé plutôt que de poser un appareil sur un seuil de piste. Une place déjà occupée est refusée **en nommant** le groupe qui la tient, et la sélection automatique saute les places prises. La donnée de parking capturée (1,9 Mo) est **allégée puis bundlée** (616 Ko, `veaf-build update-dcs-data --parking` → `veaf_libs/data/parking/<théâtre>.json`) pour être lisible par le MCP installé. Un théâtre non capturé, un aérodrome inconnu ou trop peu de places libres sont refusés en nommant la cause. Documenté dans le catalogue mission-maker et la référence développeur, deux langues.
- **L'assistant peut enfin créer une place joueur, et une mission bâtie de zéro est jouable de bout en bout** (`FIX-SCRATCH-MISSION-PLAYABLE`). Trois défauts d'une même mission, trouvés trente secondes après que David l'a chargée : aucune coalition (DCS ouvrait CHANGING COALITIONS, tous les pays non assignés), aucun slot jouable, et un démarrage de nuit. **`coalitions` n'était peuplée par personne.** Une mission décrit le même fait dans deux tables — `coalition.<camp>.country` porte les unités, `coalitions.<camp>` la **liste des id de pays** — et DCS exige les deux ; remplir la première sans la seconde donne des unités dans un camp qui n'existe pas. `blank_mission` livrait `coalitions` vide en affirmant en commentaire que `add_group` la remplissait ; **aucune ligne ne le faisait**. Désormais le writer partagé par `add_group` et les composites (`create_combat_zone`, `create_qra`, `create_cap_mission`) inscrit le pays dans `coalitions.<camp>` — idempotent, gérant la forme dict-vide et la forme liste. **La nouvelle action `add_player_slot`** crée la place manquante : un groupe avion en `skill: Client` (jouable aussi en solo), avec une fréquence de groupe, et surtout `dynSpawnTemplate` **désactivé** — c'est ce drapeau, laissé actif, qui faisait qu'un slot posé à la main existait dans le fichier mais **n'apparaissait pas** dans la liste des places (il marque un template de spawn dynamique, qui suppose une base configurée pour ça). Départ **en vol** (position, altitude, vitesse, cap — aucune donnée runtime requise) ou **au sol** froid/chaud, où la place de parking est **exigée et refusée si absente** plutôt que devinée : les emplacements sont la donnée capturée par `FEAT-MCP-MUTATION-ACTIONS` ticket 09. La paire `type`/`action` du premier waypoint est écrite pour l'appelant. **Cause du démarrage de nuit trouvée par la mesure** : le pipeline météo ne tourne que si `src/versions.yaml` existe, mais ce fichier est **livré par défaut** sous la forme d'un tutoriel à sept variantes dont `dawn-auto` (lever de soleil ≈ 03 h 48) était la première produite. Le défaut n'était ni dans le moteur météo ni dans la mission vierge (qui démarre à midi), mais dans le fait que le défaut actif d'une mission neuve était un tutoriel. Réduit — sur choix de David — à **une seule variante midi/ciel clair**, le tutoriel conservé en commentaire dessous. Documenté dans le catalogue mission-maker (deux langues).
- **Les cinq modules qui n'avaient aucune page en ont une** (`DOC-MODULE-PAGES`). Ils étaient enregistrés, chargés et actifs, et absents de la documentation comme du sommaire — deux avec des surfaces que les joueurs utilisent. **`veafGroundAI`** pilote une batterie d'artillerie depuis un marqueur F10, avec sept verbes, et son alias `-ai_set` était **déjà documenté** dans `veafShortcuts` : il pointait vers un module sans page. Sa page dit ce que le code fait, y compris les deux pièges que seule une lecture du code révèle — le texte d'un ordre se sépare par des **points-virgules** et non des virgules, et un `set` sans `groupname` cherche le groupe allié le plus proche **dans 250 mètres seulement**, sinon ne fait rien. **`veafCombatMission`** possède le menu F10 `MISSIONS`, les alias `-airstart`/`-airstop` et le module distant `/air` — et ses sections YAML `cap_missions:` / `combat_missions:` étaient documentées **dans la page d'un autre module**, `veafCasMission` ; elles sont déplacées chez leur propriétaire, avec un renvoi là où elles étaient. Le trio d'infrastructure suit, côté développeur : **`veafCommands`** (le répartiteur, ses neuf priorités et le fait qu'un module qui oublie de déclarer son palier de sécurité ne s'enregistre pas), **`veafI18n`** (263 clés, deux langues obligatoires, et pourquoi une clé brute s'affiche en jeu quand l'entrée manque) et **`veafUnits`** (la base des groupes, et le placement en grille dont le côté vaut `ceil(sqrt(n))`). Dix pages, dans les deux langues, dans le sommaire, avec leurs lignes de README.
- **A real CLI reference, and it cannot go stale quietly** (`DOC-AUDIT-FIXES` ticket 04). `TOOLS_REFERENCE` documented **3 commands of 25** while several pages linked to it as the complete CLI reference; the only honest inventory anywhere was the mission-maker guide's one-line-per-command table. `doc/CLI_REFERENCE.md` (+ `.en.md`) now carries all 25 commands grouped the way `veaf-tools --help` groups them, each with its arguments, **every** option — 120 entries per language — a realistic example, its flat alias (`veaf-tools convert v5` is also `veaf-tools convert-v5`, and your existing scripts keep working), and a link to the page that explains the why. The tables are **introspected from the real typer app**, not typed out: the option rule `FIX-DOCAUDIT-CODE` shipped now points at this page, so an option added without documentation fails CI — which is exactly what `capture-map --parking` slipped through. Two things measurement decided: the flat alias of `convert other` is `convert-other` and not `other`, so it comes from the command tree rather than from splitting a name; and every help string is already localised, so each page says what `--help` says in its own language instead of a translation invented here. Pointing the rule at the new page immediately exposed a bug in the rule itself — `typer.Option(None, "--dev-mode/--no-dev-mode")` is **one** literal declaring both forms, and the check was demanding a string no reference writes.
- **The assistant can now edit a route, reshape a zone and draw on the F10 map** (`FEAT-MCP-MUTATION-ACTIONS` tickets 04, 06 and 07, closing every ticket of the lot an agent can finish alone). **`edit_route`** adds, inserts, removes and reorders waypoints, sets their altitude, speed, name and type, and gives them a **task**. **`edit_zone`** finally makes a VEAF combat zone adjustable — it *is* a trigger zone, and until now adjusting one meant deleting it and building it again — moving, resizing, renaming, reshaping into a polygon, linking to a carrier, or removing it. **`add_map_drawing`** and **`edit_map_drawing`** place a coordination line, an ingress corridor, a no-fly box or a label on the F10 map, which matters because **a drawing made by hand in the editor is lost the moment the mission is rebuilt from its folder** while one an agent places is part of the recipe. **Three measurements decided their shape, and each is a silent failure avoided.** First, DCS **refuses to save a mission whose route has no waypoint with a locked time** — `FIX-WAYPOINTS-ETA-LOCKED` established both the error and the repair — so removing or reordering can produce a mission the editor rejects on a different day, naming the route rather than the edit; every operation restores the invariant and says when it had to, and the lock is *at least one* rather than *the first*, so an authored lock further down survives. Second, `veafCombatZone.lua` **does** handle a polygon (`mist.getUnitsInPolygon`) but only for zone type 2, and its `if/elseif` has **no `else`** — so a zone of any other type would find no units at all, in silence, which is worse than not offering the shape; the action writes only types 0 and 2. Third, a drawing's `points` are **relative to its `mapX`/`mapY` anchor**, the first being `{0, 0}`, so a drawing written in absolute coordinates lands hundreds of kilometres away with no error — the actions take the absolute coordinates a caller has and anchor them, which also makes moving a drawing a matter of moving its anchor while the shape follows. **The waypoint task set is closed on purpose**, seven tasks chosen from what real missions carry (counted across the fixtures: `Land` 184, `Orbit` 169, `EngageTargets` 152, `EngageTargetsInZone` 109, `Bombing` 13): a generic "write this task table" action lets an agent produce a plausible table DCS ignores, and the mission maker discovers it an hour into testing when the flight does nothing. Three of those signatures are traps a generic writer walks into: **`SetFrequency` takes hertz** (`31000000` for 31 MHz) while a *group's* frequency is in MHz — two units for the same notion in one file — **`EngageTargetsInZone` stores its target list twice**, as a `targetTypes` array *and* a serialised `value` string, so writing one alone leaves the mission carrying two versions of the same decision, and **`SetFrequency`/`SwitchWaypoint` are not tasks but *actions*** carried inside a `WrappedAction` envelope, which DCS ignores if written bare. Two more measured details the tickets did not foresee: a waypoint's `type` and `action` are a **pair** (`Land` goes with `Landing`), and an added waypoint **inherits** its neighbour's altitude and speed, or it is written at altitude 0 and the flight dives to reach it. Altitudes and speeds are taken in **feet and knots** and reported in both systems, following `heading_deg`'s precedent. **Ticket 07 reduced its own scope, stated rather than slipped in**: it lists nine drawing shapes, and only **three** field layouts exist anywhere in this repository, so `circle`, `oval`, free-form `Polygon`, `arrow`, `chevron` and `icon` are **refused by name** pointing at what does work — inventing a layout is exactly what that ticket's own "read a real `.miz` first" rule forbids, and what `FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` already cost. The functional need still lands: a closed line outlines a free-form area and a rect is the no-fly box, and measuring the other six is one editor session, recorded in `DCS-SESSION-TODO.md`. Refusals worth knowing: a zone rename is refused on a collision and **warns that references do not follow** (a combat zone is wired by zone name in `mission.yaml` and by its groups' name prefix, neither visible from here); a zone linked to a unit that does not exist is **refused** rather than warned, since a zone linked to nothing simply never follows anything; removing a route's **last** waypoint is refused, a route with none not being a route; and a drawing name already used on its layer is refused, since edit and remove address a drawing by name. 114 tests.
- **One shared reader for the mission table's quirks**, on the lesson `REFACTOR-MARKER-PARSER` paid for — copied code receives half the fixes. Three actions had each re-implemented the same three traps: a 1-based Lua table arrives as a **dict or a list** depending on whether its keys happened to be contiguous (the parser flattens the contiguous case, which is why `describe_units` documents its pylon numbering so loudly), numeric keys must sort **as numbers** or waypoint 10 lands between 1 and 2, and finding a group must **name what exists** when it misses so a calling agent can retry without re-reading the mission. They now live once in `veaf_mission_mcp/mission_table.py`.
- **The assistant can now change a unit and move a group** (`FEAT-MCP-MUTATION-ACTIONS` tickets 02 and 03). Every `set_*` action shipped before these operated on mission *configuration* — modules, security, logging, an airbase's coalition — and **not one mutated an object the mission already contained**, so *“give Colt flight an air-to-ground loadout”* and *“move that SAM battery 5 km east”* were impossible while every other link in the chain existed. Two actions close that. **`set_unit_properties`** changes a unit's loadout, skill, livery, heading, callsign or side number, addressing it by **exact** group and unit name — a fragment is refused, because `describe_units` may filter on one but an edit landing on whichever group matched first is not recoverable — and a miss names what it searched and lists what exists, so an agent can retry without re-reading the mission. **`set_group_properties`** moves, renames and reconfigures a whole group: frequency, modulation, late activation, hidden, uncontrolled. Only the fields passed change, and the result reports each **previous** value, because an assistant that cannot say what it replaced cannot let a mission maker undo it. **Four shapes the tickets described were wrong, and reading real missions is what caught them.** `skill` has **seven** values, not four: `Average`/`Good`/`High`/`Excellent`/`Random` are AI levels, while `Client` and `Player` are *human slots* — writing an AI level over a `Client` deletes a multiplayer slot and writing `Client` over an AI unit creates one, which is the bug `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for, so both directions are refused naming the reason. An aircraft's `callsign` is **not a plain field** but a table `{1: family, 2: flight, 3: number, name: "Colt11"}` whose `name` is the family's word followed by the two indices (`{1:1, 2:1, 3:2}` reads `Enfield12`); writing `name` alone desynchronises what DCS says on the radio from what the editor shows, so the indices are edited and the name **rebuilt** from the word already there — and changing the *family* is refused unless the caller supplies the resulting name, since DCS's family→word table does not ship here. A move must translate the group's **own `x`/`y` anchor** along with every unit and every waypoint, which ticket 03 did not mention and the editor draws the group from; the shear case (units move, waypoints stay) has its own test, **proven discriminating by deliberately breaking the translation** and watching exactly those two tests fail. And the delta comes from the **geodesic** offset `FEAT-GEO-PLACEMENT` already ships, pinned against `veaf_libs.coordinates` itself so the projection cannot be quietly bypassed later. **Two limits are stated rather than faked.** A weapon's CLSID cannot be checked against the airframe carrying it and a livery cannot be checked against the skins installed — no such table ships with veaf-tools, and DCS drops an impossible weapon and shows a default skin **without any error** — so both come back as warnings instead of being implied by silence. More consequentially, **the destination's surface cannot be checked at design time at all**: `land.getSurfaceType` is a runtime API and no terrain data exists on the Python side, which is exactly why `FEAT-SCENERY-AWARE-SPAWN` solved that problem at runtime, so a move *says* it could not look rather than validating and lying. Frequency is the opposite case, checked hard: it is gated on the airframe's own `HumanRadio` range from `dcs-radio-specs.yaml` — reusing the presets injector's validator rather than re-deriving it, and checking **every** unit type in the group rather than the first, since a mixed group would otherwise pass here and be refused by the editor because of another member — because `FIX-PRIMARY-FREQ-HUMANRADIO` established that the Mission Editor *refuses to save* a mission that breaks it. A rename refuses a **collision** (two groups sharing a name makes every later edit ambiguous, including the undo) and, by default, a name triggering a reserved VEAF convention, since a group named after a combat zone's trigger zone is despawned at mission start in silence; `acknowledge_conventions` allows the legitimate case of renaming *into* a convention. Unit names never cascade from a group rename — they carry their own `#command=` and `#veafInterpreter[...]` markers, which a cascade would rewrite blind. 86 tests; documented in the mission-maker catalogue and the developer reference, both languages.
- **`capture-map --parking` collects the parking slots an aircraft needs to stand on a ramp** (`FEAT-MCP-MUTATION-ACTIONS` ticket 08). Placing a flight "on the ramp at Incirlik" turned out to need data nobody had: a parked unit carries **two distinct numbers**, `parking` **and** `parking_id` — 28 and 24 on the same F-14A in this repository's own fixtures, the runtime's `Term_Index` and `Term_Index_0` — and the 15 committed airbase dumps carry `{id, name, lat, lon, coalition}` and nothing more. So `add_air_group` left ticket 03 to become a data capture (08) and a write (09). The capture runs `Airbase:getParking(false)` over the existing dcs-bridge and dumps **every key each slot carries**, flattening a nested table one level and keeping values as strings: the API schema shipped here declares four fields where a mission file already proves there are more, so the shape comes from the runtime rather than from the schema — and a test pins that an unknown future field survives. Written to `parking/<theatre>.json`, separate from the airbase dumps that 15 theatres already use, airbases captured **first** so a maker who loses the slower second call still has the useful half. A theatre reporting no slots is data, not a failure. Running it needs a DCS session, which is the same five-minute-per-map job `FEAT-AIRDROMES-RUNTIME-SOURCE` established.
- **The assistant can finally see a unit** (`FEAT-MCP-MUTATION-ACTIONS` ticket 05). `describe_mission` reported groups and zones and nothing else — no units, no loadout, no skill, no livery, no route, no waypoint, no task — so *“give Colt flight an air-to-ground loadout”* or *“add a waypoint after the third”* could only be attempted on a guess, and a mission mutated on a guess opens in the Mission Editor and flies wrong, which nothing here catches. The new **`describe_units`** action reads each group down to its units (type, skill, livery, callsign, side number, position, heading, altitude, fuel, counters, gun), their loadout, and the group's route with the tasks at each waypoint — plus the group properties the setters will change: task, frequency, hidden flags, uncontrolled and late activation. A separate action rather than a fatter `describe_mission`, which is documented as a light look before a write. **Three shape decisions, each measured on a real mission** (Foothold Caucasus 4.4.1, 357 armed units) rather than assumed. First, **`pylons` is keyed by pylon number, never positional**: DCS numbers stations and they are *not contiguous* — a real FA-18C carries 1, 4, 5, 6 and 9 — and 170 of those 357 units have a gapped layout while the Lua parser flattens the contiguous ones into a list, so a reader treating pylons as an ordered list is right about half the time and silently wrong the rest, which is exactly how a setter would hang a weapon on the wrong station. Second, **the editor's own auto options are flagged and stripped**: a waypoint task is a `ComboTask` mixing the authored task with the options the editor writes itself, 1093 automatic entries against 189 authored in that mission — both are reported, since hiding them would misrepresent the mission, but only authored tasks carry their `params`. Third, **a cap the caller is told about**: the whole mission is 1.9 MB of JSON and one 62-waypoint group is 18 KB, hence filters (`group_name` matches a fragment, `coalition`, `category`), a 50-group default with `matched`/`truncated` in the answer, and `include_route: false` which *omits the key* rather than returning an empty list — “not asked for” is not “this group has no route”. Booleans come back as booleans because DCS omits a false key, and a caller reading `null` cannot tell “off” from “the reader did not look”. 32 tests; documented in the mission-maker catalogue and the developer reference, both languages.
- **A custom script can now be loaded after a delay, and an adopted mission reproduces the staging it came with** (`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`). A third-party mission may stage its script loading — Foothold uses `triggerStart`, then `triggerOnce` + `c_time_after 3`, then `+12` — and adopting it collapsed all fourteen scripts into one `triggerStart`. The order held; only the wall-clock delay was lost, silently. **The ticket asked whether that actually breaks anything, and it does**: AIEN's `populate_Db()` is, in its own words, "launched once at mission start and collect everything relevant that is already there" — a single inventory of ground groups — while Foothold creates part of its own groups from `SCHEDULER:New(…, o:update(), …, 2, …)` and deferred save restores, i.e. from t+2 s onwards. Loading AIEN at t=0 hands it a world those schedulers have not populated, and the symptom is silent: no log error, just ground AI that never manages the groups Foothold created. So this is a correctness fix wearing a fidelity hat. `custom_scripts.scripts[].delay_seconds` moves a script out of the shared trigger into a `triggerOnce` of its own, **one trigger per distinct delay** with declaration order kept inside it. The three structural facts were **read out of an upstream `.miz`** rather than assumed: a deferred trigger is dispatched from `trig.func` and not `trig.funcStartup`, its condition ANDs `c_time_after` onto the existing `c_predicate` (which is what keeps a *static* trigger inert in a *dynamic* build — dropping it would load the script twice), and its action string ends by clearing its own `func` entry, which is what makes the "Once". **Dynamic builds stage identically** — `veafDynamicConfig.lua` schedules the load — because `generate_load_trigger` governs both modes and a delay that existed in only one would be a trap. **The ordering rule is documented rather than enforced**: the delay decides, not the position in the list, and a delayed script declared before an undelayed one earns a build warning naming the pair, since that is the only case where reading the list top to bottom disagrees with what runs. A zero, negative or non-numeric delay is refused with a warning and the script still loads in the shared trigger — never dropped. **`convert-other` closes the loop**: it detects each loader trigger's `c_time_after` and writes `delay_seconds:` into the scaffold, verified end to end against the real Foothold Caucasus 4.4.1 `.miz` (6 scripts with no delay, 5 at +3 s, AIEN at +12 s), and `--update` now reports a delay that moved upstream — the one change nothing else would reveal, since `--update` deliberately preserves the tuned `mission.yaml`. 43 tests. Two pre-existing test defects surfaced on the way and are fixed: three assertions pinned the *syntax* of the generated dynamic list rather than its contents, and the factory-contract gate could not see attributes assigned by tuple unpacking — a blind spot that would have let a future field escape the contract it exists to enforce.
- **A checklist step can now be tested without staging the whole cockpit** (`CHORE-SMS-QUICK-WINS` ticket 03). Verifying step 30 of an engine start meant performing the 29 before it, in a cockpit — which is why the first checklists were signed off by hand, in flight, and why fixing a small thing was discouraging enough not to bother. `dev_condition: true` on a step makes it pass without the cockpit ever being in the required state; hatch steps 1 to 29 and the session opens **on step 30**, which falls out of the existing mechanics because a session already ticks everything satisfied when it opens. It is **not a third validation mode**: the step keeps its `argument`/`param`/`confirm` and the hatch short-circuits the evaluation, so removing the key restores the real gate with nothing to rewrite. Three guards, because a hatched checklist reaching production would tell a pilot they did something they did not: absent means today's behaviour exactly and `dev_condition: yes`/`1` are **refused** (`StrictBool`, so a typo cannot open it); the **build warns**, naming the checklist and every step number; and the engine **tells the pilot on screen** at session start. The decision the ticket left open is taken and recorded in the code: **warn, never refuse, and no strict flag** — refusing would make the feature unusable since you could never build the mission you wanted to test, and a flag has to be remembered by the same person who forgot to remove the key, while the on-screen notice reaches the one person who would otherwise be misled. In Lua the test is `step.devCondition == true` and not a truth test, because every non-nil value is truthy there — the string `"false"` included, and a hand-edited generated file is exactly where that comes from; a test pins it. 7 Lua tests, 9 Python, documented in both languages.
- **The DCS coordinate convention is written down** (`CHORE-SMS-QUICK-WINS` ticket 01). `x`/`y`/`z` mean different things in a mission table (`{x = north, y = east}`) and in a runtime vec3 (`{x = north, y = altitude, z = east}`), and confusing them raises **no error** — a group lands a hundred kilometres away, or at four hundred thousand metres, and the mission opens in the editor perfectly happily. `resolve_coordinates` hides it on the MCP path, which is why it has not bitten recently; an agent writing Lua by hand walks straight into it. Now in `docs/agents/dcs-coordinates.md`, pointed at from `CLAUDE.md`. **Verifying it rather than restating it found something the ticket did not know**: the runtime is not internally consistent either — `land.getHeight` takes a **vec2** whose `y` is the easting, the mission-table meaning, three lines from the vec3 whose `y` is altitude in `veaf.getLandHeight`. So the page says to reason from the called function's signature, not from which side of the fence you are on, and it names what already handles the conversion instead of restating the rule abstractly.
- **The authoring skill now works from Gemini CLI as well as Claude Code, and there is still only one copy of it** (`CHORE-SMS-QUICK-WINS` ticket 02). `plugin/` gained a `gemini-extension.json` next to its `.claude-plugin/plugin.json`, because the two agents happen to look for skills in the **same place**: `<root>/skills/<name>/SKILL.md`, same `SKILL.md` format with `name`/`description` frontmatter. So one directory serves both and the guidance is not duplicated — which matters more than it sounds, since two copies of authoring guidance drift and the drift is silent because nobody reads both. Established from the Gemini extension reference rather than assumed. **One compromise, stated rather than hidden**: `gemini extensions install` wants its manifest at the root of what it is given and has no field to redirect the `skills/` scan, so installing from the GitHub URL in one line is not possible — it is `git clone` then `gemini extensions install <clone>/plugin`. Putting the manifest at the repository root would need `skills/` there too: either a second copy of the skill or moving the folder out from under the Claude plugin, both of which cost more than one clone. Also: **Gemini does not install the `veaf-tools` binary for you** — the automatic download is a Claude Code `SessionStart` hook, whose format Gemini does not share, and porting it blind against hooks nobody here has exercised is how the smoke-harness lot earned three defects. The Gemini manifest calls plain `veaf-tools`, so the binary must be on `PATH`; the install page says so in both languages. `test_plugin_version.py` now covers both manifests, asserts they declare the **same MCP server name** (the shared skill names it, so a mismatch would make the same text wrong on one side), and pins that the skill sits where both agents look.
- **The marker-text loop that was copied across the codebase now exists once** (`REFACTOR-MARKER-PARSER`, tickets 02-03 complete). Six modules and four further inline loops declare their parameters to `veaf.parseMarkerText`; **547 lines deleted against 497 added** under `src/scripts/veaf/`. The win is not bulk and pretending otherwise would be dressing it up — most added lines are declarations plus comments recording why a quirk survives — it is that a fix now reaches every caller instead of the copy it was written against. Nine always-true `if switch.casmission and …` / `if switch.transportmission and …` conditions went with it, and the three `veafShortcuts` loops (two of them identical but for one local's name) became one specification. **The six recorded defects are fixed, each in its own named commit**: `disperse` never reached the 15-second default its `else` branch promised, because a valueless keyword arrives as nil and never `""`; `veafRadio`'s duplicate `path` rule was unreachable; a *recognised* radio keyword with no value destroyed its default so `_radio transmit, freq` did nothing at all without telling the pilot, where an *unknown* keyword was harmless; `veafGroundAI` accepted a nameless handler because `if not options.name` cannot catch `""`, the same bug `SECREV-010` fixed in `veafMove`; and it no longer asks DCS for `Group.getByName("")`. **The lot's premise was demonstrated four times while doing the work**, three of them in code already believed fixed — including `veaf.getRandomizableNumeric`, where `VMR-025` described the crash in a comment and then guarded its *caller*, which is exactly why its sibling walked into it. The most useful finding came last: `veafMove`'s defect was recorded as "a nil travels downstream instead of the sentinel", which reads as harmless. Two pre-existing `VMR-092` tests asserted that outcome, and measuring rather than editing them showed `moveGroup` concatenates its speed into a log line, so a nil raised one call after a clean parse — "unset, not crash" had only moved the crash. That was a twelfth crash in the family and it exposed a real gap: all 485 sweep cases probed **parsers**, never the whole command path. An `executeCommand`-level assertion now covers it. `veafSecurity`, `veafNamedPoints` and `veafShortcuts.markTextAnalysis` stay deliberately untouched.
- **One shared marker-text parser, and the module declares its parameters instead of writing the loop** (`REFACTOR-MARKER-PARSER` ticket 02). `veaf.parseMarkerText(text, spec)` in `veaf.lua`, with the four `apply` kinds as `veaf.markerRules.{number, nonNegativeNumber, text, flag}`. The machine was **moved, not invented**: `veafSpawnParser` had already been rewritten into this shape, so the ticket lifts it rather than reimplementing a generic loop and meeting the hardest case last. That module now declares `veafSpawn.MarkerSpec` and its `markTextAnalysis` is two lines — **its 71 tests pass with the file unedited**, which is what makes the move reviewable. The specification expresses every load-bearing quirk ticket 01 measured: a valueless keyword being nil in some modules and `""` in others, `,` versus `;` separators, first-match-wins command descriptors seeding per-sub-verb defaults, all-matching-rules-run with `when` gating, values kept untrimmed (so `side  BLUE` with two spaces still resolves to RED, as it does today), opt-in unknown-key reporting with a "did you mean" suggestion, and a post-loop `validate` for mandatory parameters. **A root cause fixed rather than worked around a fourth time**: sharing `nonNegativeNumber` made an old hole reachable again — inside `veafSpawnParser`, `valueWhenAbsent = ""` had guaranteed a string — and a new test caught it before the merge. The guard is back in the helper, but the real defect was a level down, in `veaf.getRandomizableNumeric_random(nil)` raising on `string.find(nil, "%-")`. `VMR-025` described that crash in a comment and then guarded against it **in its caller**, which is exactly why `_numNonNegative` one function below walked into it and why `FIX-MARKER-PARAM-CRASHES-2` was needed; it returns nil at the source now. Ticket 02's second criterion — that the spec express a module other than `veafSpawnParser` — is met by a **differential test** rather than an argument: the live `veafRadio` parser and the shared parser run the same 37-input corpus and are compared field by field, with one guard asserting the corpus is non-empty and another proving a deliberately wrong spec is caught. Ticket 03 reuses that harness per module.
- **Every marker text parser now has a suite pinning what it does today** (`REFACTOR-MARKER-PARSER` ticket 01). Characterisation before extraction, so the refactor's diff can be read as "a parser was replaced" rather than "a parser was replaced and something changed, good luck". 436 lines of tests across the six group-A parsers and the four group-B loops the first inventory missed; group C is deliberately untouched. The quirk inventory went from **10 items read out of the code to 19 measured** — nine were invisible from reading, including that a value keeps everything after the *first* space (so `side  BLUE` with two spaces silently resolves to RED), that flags discard any value handed to them (`teleport false` teleports), that sub-verb chains are decided by the chain's order and not the text's (`_move group tanker` is a group move), and that `ArtilleryUnitHandler`'s `target` is the codebase's only parameter rule that validates its own input. **Two findings changed the plan**: `veafRadio`'s `elseif` chain, billed as the one structural difference and scheduled first to prove the spec could express it, turns out **not to be observable** — no key is claimed by two live branches — so the permissive form is behaviour-preserving there, and that is now pinned by a test rather than argued in a document; and the three `veafShortcuts` group-B loops are **not standalone functions** but steps inside `execute`, so they are characterised through spies on what the parsing hands downstream, and the migration has to extract before it can replace. **Two new defects recorded and deliberately not fixed**, both wrong-input-accepted rather than crashes: `veafGroundAI` accepts an empty handler name, which is the same `""`-is-truthy guard bug `SECREV-010` fixed in `veafMove` and which the `veafShortcuts` loops get right; and `_radio transmit, freq` sets `frequencies` to nil, destroying the default that `executeCommand` requires — so that command does nothing at all, with no message to the pilot, where an *unknown* keyword would have been harmless.

### Changed
- **CTLD embarqué mis à jour en 2.0.0-rc7** (depuis rc3, release VEAF/CTLD `published-v2.0.0-rc7`). `src/scripts/community/CTLD.lua` remplacé par la version rc7 (normalisée en LF). rc7 apporte des changements de config notables, mais notre génération s'y adapte **sans modification** : le build **extrait le YAML `ctld.configDefault` du CTLD.lua embarqué lui-même** puis applique les overrides VEAF par-dessus (une clé absente est ignorée, jamais inventée) et écrit `CTLD_userConfig.lua` chargé **avant** `CTLD.lua`, exactement ce que rc7 attend. Vérifié : les deux clés que VEAF override (`logisticUnitTypes`, `troopZoneShipTypes`) existent toujours dans le `configDefault` rc7 (section `mm_facing`), les sons `beacon*.ogg` sont identiques (pas de mise à jour), aucun pin de version ailleurs, et la suite community/CTLD passe. Le fichier n'a aucun patch VEAF local (le dépôt VEAF/CTLD est déjà la version VEAF), donc remplacement direct.
- **Le harnais de fumée route les assertions VEAF par le pont de mission, pas par le hook** (`FEAT-DCS-SMOKE-HARNESS` ticket 04). Deux fois, lancé contre un DCS avec une mission VEAF en vol, le harnais rapportait `veaf-absent` pour `veaf-loaded` et `findspawnpoint-exists` alors que `dcs.log` montrait les scripts VEAF chargés normalement — parce que le hook `dcs-fiddle` atteint un état de script **nu** : les globals de DCS (`Disposition`, `missionCommands`, `coalition`) y sont, mais pas ceux des scripts de la mission (`veaf`, `mist`). Désormais chaque vérification déclare son transport : les vérifications DCS natives passent par le hook, les assertions **VEAF** par le **pont** (`dcs-serve` → `dcs-bridge.lua`, injecté *dans* la mission, là où `veaf` vit). Le sentinel qui masquait le problème est corrigé : la sonde testait `type(env)` — or `env` est une table dans *tout* état de script, chargé ou nu, donc « env est une table » ne prouvait pas que les scripts de la mission avaient tourné ; elle mesure maintenant explicitement `type(veaf)` sur la route du hook et le dit. Et le pont est un **prérequis énoncé** : une assertion VEAF dont le pont est absent **échoue en nommant `dcs-serve`** au lieu de rapporter `veaf-absent` et d'envoyer déboguer la mission. `smoke-test` gagne `--serve-url`, `--api-key` et `--config` pour le pont. Établi par mesure, pas par argument : une mission bâtie des sources courantes et pilotée entièrement par ce pont a répondu tout ce que ce lot veut vérifier (paliers de sécurité par occupant, `findSpawnPoint` au-dessus de l'eau, dégradation par tier en gardant le rayon).
- **The backlog status gate no longer lets anything opt out in silence** (follow-up to the check added in #692, on Sourcery's two remarks). It had the very defect it was built to remove: a `Status:` line below the 15-line window it scanned read as *absent*, and an unrecognised icon in a scope-table cell made the row **invisible** — both skipped the comparison instead of failing it. The window is gone, a missing or unreadable status is now reported, and each of the three holes was verified by reopening it and watching the gate refuse. The reliable fix turned out to be neither mine nor the one suggested: reading **the column the table names `Status`** rather than "the last cell". Measured first — a positional rule produced **17 false positives**, because two lots end their table with a *depends on* column holding values like `01, 02` or `—`.

### Changed
- **The MCP server follows `mcp` 2.0, where `FastMCP` became `MCPServer`.** The 2.0 release removes the `mcp.server.fastmcp` module outright, so Dependabot's #689 failed at import and took both MCP test modules down during collection. The migration is two lines: `from mcp.server import MCPServer` and `MCPServer(SERVER_NAME)`. Checked against the installed package rather than assumed — the docs give two candidate paths (`mcp.server` and `mcp.server.mcpserver`, both work), the `tool` decorator still accepts a synchronous function, and `run()` still defaults to `transport="stdio"`, so the existing call stays correct. Nothing else in the repo referenced `FastMCP`, and we use neither `Context` nor `ctx.fastmcp`, the other two renames. One behaviour change worth knowing: 2.0 runs **synchronous** handlers on worker threads, and all four of our tools are synchronous — they share the module-level `CATALOG`, so a future action holding state across calls would need to account for that.

### Fixed
- **Le hook `dcs-fiddle-server.lua` exige enfin une authentification, et le dépôt vendredise le bon fork** (`FIX-SECREV2-EXPIRED-DEFERRALS` ticket 02, finding VMR-013). Le finding visait le `dcs-fiddle-server.lua` du dépôt (RCE sur HTTP non authentifié). En allant l'implémenter, découverte décisive : ce fichier était une **copie obsolète** (base JonathanTurnock) que personne n'installe — le hook réellement utilisé, contre lequel le harnais est validé, est le fork **omltcat/dcs-lua-runner**, qui a **déjà** une auth Basic mais avec `BYPASS_LOCAL = true` : les requêtes loopback sautent l'auth via le Host header (falsifiable), donc une page web visitée pendant que le hook tourne exécute du Lua dans DCS. **C'était ça, le vrai VMR-013.** Le dépôt **adopte** donc ce fork comme fichier vendredisé, ré-applique le patch VEAF `sanitizedModule`, et le configure sûr : `AUTH = true`, `BYPASS_LOCAL = false`, et un **mot de passe par session** généré au démarrage, écrit dans `%USERPROFILE%\dcs-fiddle-token.txt` (chemin fixe, pour ne pas dépendre du bon `writedir` parmi plusieurs profils), que le client du harnais lit et envoie en auth Basic (username `veaf`). Une page web ne pouvant pas lire un fichier local, le vecteur navigateur est fermé ; reste vrai qu'un processus local capable de lire le fichier peut exécuter du Lua, d'où l'avertissement conservé « retirer le hook après usage, jamais sur un serveur ». **Effet de bord assumé** : l'interface web amont de DCS Fiddle, qui dépendait du contournement local, n'est plus supportée. La moitié Lua se valide par un run en jeu (une auth qui casserait silencieusement le transport est le piège que l'ADR 0019 refusait de livrer à l'aveugle) ; le côté client est couvert par des tests.
- **`convert-v5` écrivait SKYNET deux fois dans le bloc `modules:`** (`FIX-CONVERT-V5-DUPLICATE-SKYNET`). SKYNET est à la fois un module (catégorie « External » de `MODULE_CATEGORIES`) **et** un script communautaire, et chacun a son émission : la boucle par catégories posait un `SKYNET: true` nu sous « External », la section communautaire posait un `SKYNET:` en bloc avec sa config (`include_red_in_radio`, `debug_red`…). Une mission activant SKYNET recevait donc **deux clés `SKYNET:`** — un doublon de clé YAML, où le lecteur garde la dernière et jette silencieusement la première. Corrigé à la cause : la section communautaire, plus riche, est autoritaire, donc l'émission « External » exclut désormais tout module qui est aussi un script communautaire ; et l'entrée communautaire honore l'état « module activé » même sans config ni `.lua` détecté, pour que son unique entrée reflète toujours l'intention de la mission. Un test génère la `mission.yaml` avec SKYNET activé et vérifie qu'il n'apparaît qu'une fois, et que c'est le bloc de config qui survit. Trouvé sur la mission de démonstration migrée en v6.
- **Ce que l'éditeur DCS fait subir à ce que le MCP écrit** (`FIX-MCP-EDITOR-ROUNDTRIP`). Mesuré le 2026-08-15 : six mutations écrites dans une mission via le MCP, David l'ouvre et la sauve dans l'éditeur, comparaison champ par champ. Chaque action était couverte par des tests — qui vérifient ce qui est *écrit*, jamais ce que DCS *garde*. Trois défauts en sont sortis. **Une tâche `Bombing` était jetée en silence** : écrite avec 6 paramètres là où une vraie en porte 11, sans `weaponType`, l'éditeur la supprimait à la sauvegarde — un dispositif d'attaque qui ne largue rien. `Bombing` et `AttackGroup` portent désormais le jeu complet mesuré sur de vraies missions : `weaponType` (défaut « Auto » sourcé — 2032 pour Bombing sur 128 occurrences, 9659482112 pour AttackGroup, surchargeable), les paires `altitude`/`altitudeEnabled` et `direction`/`directionEnabled` présentes mais désactivées par défaut, et `expend`/`attackQty`/`groupAttack` ; `EngageTargetsInZone` gagne `noTargetTypes`. Les sept tâches ont été comparées à un exemple réel, pas échantillonnées. **`edit_route add`/`insert` ignorait l'altitude et la vitesse qu'on lui passait** : acceptées, documentées, et silencieusement écrasées par l'héritage du voisin — faux d'une manière *plausible*, la pire à repérer en revue ; elles sont maintenant écrites quand elles sont fournies, l'héritage restant le défaut quand elles sont omises. **Le cap posé sur un avion en vol ne survit pas** : DCS le recalcule depuis le premier segment de la route à la sauvegarde (revenu exactement à l'`atan2` du segment, à la septième décimale). Ce n'est pas un bug — le cap reste pertinent au sol, sur un navire — donc l'action **avertit** au lieu de refuser, en nommant la cause (régler la route, pas le cap), pour un avion en vol dont la route a 2+ points ; un appareil parké ou une unité au sol ne déclenchent rien. **Et une question ouverte tranchée en notre faveur** : la zone à 6 sommets **survit** intacte à une sauvegarde, donc `edit_zone` ne se met pas à refuser au-delà de quatre — l'avertissement énonce une limite connue (l'éditeur ne sait pas éditer la forme à la main) au lieu d'un risque inconnu. Trois défauts que seul un aller-retour en jeu pouvait révéler, chacun reproduit par un test avant correction.
- **Le MCP refusait une forme de dessin qui n'existe pas** (`FEAT-MCP-MUTATION-ACTIONS` ticket 07). `add_map_drawing` ne crée que les trois formes dont la structure a été lue dans un vrai `.miz` — ligne, rectangle, étiquette — et refuse les autres par leur nom plutôt que d'inventer une disposition de champs que l'éditeur jetterait en silence. Cette liste de refus contenait `chevron`, **un outil que l'éditeur DCS ne propose pas** : le nom venait d'un tableau de verbes envisagés à la conception, jamais confronté au jeu. Autrement dit, la liste chargée d'empêcher les formes inventées en transportait une. Trouvé par David, l'éditeur ouvert, pendant la session du 15/08. Retiré du code, du test et du ticket, avec une assertion qui interdit son retour et vérifie qu'aucune forme n'est à la fois livrée et refusée. Rien ne change pour un appelant : `chevron` était refusé avant, il l'est toujours — avec un message qui ne prétend plus qu'il s'agit d'une forme DCS.
- **Annoter la carte ne demande plus de mot de passe** (`FIX-SECURITY-BEFORE-RECOGNITION`). Un pilote qui écrivait simplement « RDV ici » sur un marqueur recevait **deux** messages *« Veuillez utiliser l'option password L1 »*, et un `_transport` refusé en affichait **trois**. La cause n'était pas le message mais l'ordre : le répartiteur vérifiait la sécurité **avant** que le module dise s'il reconnaissait la commande, donc chaque module dont le pilote n'avait pas le palier refusait une commande qu'il n'aurait de toute façon jamais traitée. Le cas courant était le pire : `veafMarkers` transmet **tout marqueur portant du texte**, et la boucle ne s'arrête qu'au premier module qui *consomme* l'événement — donc n'importe quelle annotation de carte traversait tous les paliers. Corrigé à la cause plutôt qu'en dédoublonnant les messages, ce qui aurait laissé le log rempli d'échecs de sécurité pour des commandes que personne n'a tapées : les modules déclarent désormais leur mot-clé à l'enregistrement (`_move`, `_radio`, `_ground`, `_auth`, `_name point`) et le répartiteur écarte un module avant de tester quoi que ce soit. Un module qui n'en déclare pas garde le comportement actuel, ce qui rend le changement purement additif. Trouvé en jeu par David, et le défaut précédait le travail du 13/08 — le répartiteur vient de `SECREV-2`.
- **`validate` refuse enfin une mission que personne ne peut charger** (`FIX-SCRATCH-MISSION-PLAYABLE` ticket 02). Une mission bâtie de zéro passait la validation et le build, puis DCS ouvrait l'écran d'affectation des coalitions avec les 200 pays non assignés : la table `coalitions` (quels pays appartiennent à quel camp) était vide alors que `coalition` (les unités) était peuplée. Deux tables décrivent le même fait, et remplir la seconde sans la première donne des unités dans un camp qui n'existe pas. Le validateur signale désormais **en erreur** un camp qui contient des unités sans aucun pays affecté, en nommant le camp et en disant quoi corriger, et **en avertissement** une mission sans aucune place joueur — légitime pour un scénario côté serveur ou une bibliothèque de modèles, donc jamais bloquant. Le garde-fou a été écrit **avant** les correctifs et échouait sur la mission fautive, ce qui est ce qui prouve qu'il mesure quelque chose ; il ne signale rien sur les cinq missions réelles du dépôt.
- **`update-dcs-data --radio` peut enfin être lancée** (`FIX-RADIO-SPECS-GENERATOR-LOCALE`). Le générateur des spécifications radio ne nommait qu'une seule sortie Markdown — `dcs-radio-specs.md`, la page **française**, la locale par défaut du site — et y écrivait une page entière **en anglais**, sans jamais ouvrir la page anglaise. La lancer remplaçait une centaine de lignes de prose française rédigée à la main par 84 lignes d'anglais généré, et le contrôle documentaire restait **vert** du début à la fin, parce qu'une page française remplie de texte anglais n'est pas un défaut qu'il sait exprimer. Le robot de veille disait à qui lançait la commande de restaurer la prose à la main sur les deux pages ; ce qui manquait, c'était de quoi rattraper l'oubli. Le générateur réécrit désormais **trois blocs délimités par page** — la note de provenance, le tableau des fréquences principales bridées, les tableaux d'appareils — dans la langue de chaque page, et **refuse bruyamment** si un marqueur manque : un générateur qui ne fait rien en silence est la façon dont un tableau périmé part en release. Vérifié en lançant réellement la commande : 73 insertions et 2 suppressions, ces dernières étant l'ancienne note de provenance écrite à la main, qui citait au passage une commande n'existant plus. **Un manque de documentation comblé au passage** : le tableau des 27 appareils dont la fréquence principale est plus étroite que leurs canaux préréglés n'était dans **aucune** des deux pages — il avait été perdu quand la prose a été écrite à la main. La prose explique le mécanisme, le tableau généré donne la liste exhaustive, que personne ne peut écrire de mémoire.
- **Le menu radio F10 parle enfin la langue de la mission** (`FIX-RADIO-MENU-I18N`). Un serveur configuré en français affichait `Activate mission`, `Get info`, `Combat Zones` : **90 libellés répartis sur 12 modules** étaient des chaînes anglaises écrites en dur, alors que tous les *messages* adressés au joueur passaient déjà par le catalogue de traductions. Un pilote francophone cherchait « Activer » dans un menu qui ne l'a jamais contenu — c'est `DOC-MODULE-PAGES` qui l'a découvert, en citant les libellés depuis le code au lieu de faire confiance à la doc. Tout est traduit, **noms de rubriques compris** : `SPAWN` devient `APPARITION`, `COMBAT ZONES` devient `ZONES DE COMBAT`, `ASSETS` devient `MOYENS`, en majuscules pour garder le repère visuel. `MISSIONS`, `VEAF` et `GUARDIAN` sont identiques dans les deux langues. **Le piège que ce correctif devait éviter mérite d'être connu de quiconque touchera à ces modules** : `veaf.config.language` est affecté *après* le chargement des fichiers et *avant* les `initialize()`, donc un libellé résolu sur sa ligne de déclaration figerait chaque serveur en français **sans la moindre erreur** — `veafRadio` faisait exactement cela, et un test l'interdit désormais. Le garde-fou qui refuse le prochain littéral a lui-même eu besoin d'un garde-fou : écrit ligne par ligne, il voyait **46 des 77** libellés, parce que le formateur répartit la plupart des appels sur plusieurs lignes ; il aurait annoncé un balayage propre avec 31 libellés anglais toujours en place. **Un mot d'anglais change pour les anglophones** : `Desactivate zone` et `Desactivate mission` deviennent `Deactivate …`, la faute étant dans le jeu depuis l'origine et la chaîne bougeant de toute façon. Le nom de fonction Lua `DesactivateMission` garde son orthographe : corriger ce qu'un pilote lit est le but, casser les scripts tiers ne l'est pas. Au passage, `veafShortcuts.RadioMenuName` est supprimé — ce module ne construit aucun menu radio et personne ne lisait ce champ.
- **Le guide pilote annonçait des entrées de menu qui n'existent pas** (trouvé en écrivant `DOC-MODULE-PAGES`). Il promettait « Zones de combat → [Zone] → Activer » et « Missions → [Mission] → Infos » quand le jeu affiche `Combat Zones` → `Activate zone` et `MISSIONS` → `Get info` : les libellés du menu F10 sont des chaînes **écrites en dur en anglais** dans `veafCombatMission.lua` et `veafCombatZone.lua`, pas des textes traduits. Un pilote francophone cherchait donc « Activer » sans le trouver. Les neuf chemins de menu du guide français portent maintenant le libellé réel, et la page dit pourquoi il est en anglais. **La page anglaise était fausse aussi**, de façon moins visible : elle abrégeait les libellés (`Info` pour `Get info`, `Deactivate` pour `Desactivate zone` — dont la faute d'orthographe est dans le jeu). Les libellés eux-mêmes ne sont pas corrigés ici : les localiser est un changement de code, pas de documentation.
- **Four behaviours a pilot meets in game had no page, or the old model's page** (`DOC-AUDIT-FIXES` ticket 03). **Guided checklists were invisible**: neither the F10 menu tree nor the feature table mentioned the `Assistance` submenu, so a pilot who used it in game had no path from the documentation to it. **Coalition-scoped combat-zone menus** change what a pilot sees and said so nowhere — you only see your own side's zones, two pilots on opposing sides see different lists, and a zone missing from yours is not a missing zone (`radio_menu_coalition: ALL` restores the old behaviour). **The security section gained the case that actually trips people up**, worked through end to end: an instructor and a student in the same aircraft, where marker commands keep working because a marker carries its author's name, F10 entries stop responding because the group acts at its lowest-graded occupant's level, and `_auth elevate` raises the group to the instructor's own level for two minutes. And **ten Flaming Cliffs types answer *“why are my presets empty?”*** for the first time: they have no settable radio at all, so the build renders the kneeboard and writes nothing into the mission — with the measurement that settled it (110 FC3 player slots carry no `Radio` table against 2105 non-FC3 slots that do) and the ten types listed by DCS id.
- **Six reference gaps closed, and two of the audit's own claims corrected by reading the code** (`DOC-AUDIT-FIXES` ticket 03). `era` was documented as defaulting to `MODERN`; it is **inferred** from the base mission — a WW2 unit type or a year ≤ 1945 gives `WW2`, ≤ 1991 `COLD_WAR`, otherwise `MODERN` — and, contrary to the ticket, the inferred value is **not** written back into `mission.yaml`: it is recomputed at every build, so setting the key is how you pin it. `warehouses.yaml` was already in the pipeline-files table, contrary to the ticket too; what was missing there is `spawn-groups.yaml`, and both were absent from the folder tree. Four top-level keys the build reads and no reference mentioned (`conversion_profile`, `config_override`, `strip_native_triggers`, `dcs_bridge`) get a table pointing at the page that owns each. `pipeline:`'s field table was missing `warehouses` outright and its sub-field table both `enabled` and the `presets`-only `kneeboards`. `TOOLS_REFERENCE` listed 6 of `update-dcs-data`'s 14 options and neither `build-standalone` nor `build-kit`. And the shipped default `mission.yaml` gains a commented `delay_seconds:` example, because a feature invisible in the one file a mission maker copies from is a feature nobody finds.
- **The documentation roadmap claimed `master` still carried v5, four weeks after it moved to v6** (`DOC-AUDIT-FIXES` ticket 03, David's arbitration b). It also listed `veaf-tools mission validate` as an idea with no ticket, a command that ships. Rather than correct a page that had drifted for a year, it becomes what it should have been: a pointer to the repository's own `ROADMAP.md` and `.backlog/`, plus the three long-term axes in plain prose. **`AI_ASSISTANT_CATALOG`'s 32 French anchors were rewritten to the English slugs** (65 occurrences, headings and their table-of-contents links), so both languages expose one identical anchor set — the repo convention, and what lets a cross-page link work from either language. **The two `MISSION_YAML_REFERENCE` indexes were two different documents**: a French 3-tier taxonomy against an English 6-domain one, with `modules.QRA` listed twice on the English side and five entries missing on the French. Both are now the six domains, and a sweep over the page's own sections proves each appears exactly once — including the three that were in neither (`modules:`, `community_scripts:`, `build_variants:`). Those three gained explicit anchors so the index does not rest on a derived slug, and the four inbound links that broke as a result were caught by the gate rule this same release added.
- **The security dispatchers refused the tier names David decided on** (`FIX-DOCAUDIT-CODE` ticket 01). `REVIEW-SECURITY-LAYER` renamed the tiers to `ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT` with the values unchanged, the documentation described exactly that, and **both dispatchers accepted only the 2021 spellings**: registering a command handler with `security = "ADMIN"` failed the assert, so the decided vocabulary existed in the pages and in one function nothing called (`veafSecurity.levelForName`, which now has its production caller). Both vocabularies work; the old `L0`/`L1`/`L9` stay for one release and warn **once per name**, and each is bound to the *same* function as its replacement rather than a copy of it, since two copies is how one of two paths receives tomorrow's fix. `veafSpawn` gained the `ADMIN` tier it never had, so the two dispatchers now offer the same set. **One decision beyond the ticket**: the 24 handler declarations across VEAF's own modules are migrated to the new names, because leaving them would make *our* code raise the deprecation notice that exists to warn a mission maker — a signal nobody could then act on. `veafSecurity`'s player-facing "give the L1 password" messages are untouched: those name the configured password, not the tier.
- **`_transport` demanded the password from every pilot, listed or not** (`FIX-DOCAUDIT-CODE` ticket 02). It called `checkSecurity_L1(options.password)` **without the marker id**, and `getMarkerSecurityLevel(nil)` returns `-1`, so the identity path could never grant anything: a pilot listed as `SENIOR_PILOT` in `veaf-pilots.txt` — whose level is the entire point of the listing — still typed the password on every `_transport`. Every other marker command passes its marker id; this one predates the per-player model and was never rewired. It is the single place where `veafSecurity.md`'s *"rien ne change pour un pilote listé"* was false, and the caveat the documentation lot had to add is removed with it, in both languages.
- **Seven "animated NO fog" radio entries handed `nil` to their handler** (`FIX-DOCAUDIT-CODE` ticket 03). The menu passed `veafWeather.FOG_ANIMATED_5_NO`, a constant that does not exist — the generated names carry the `M` (`FOG_ANIMATED_5M_NO`) — so clicking any of the seven durations did nothing; and had the name been right, all seven would still have applied the **5-minute** preset, the duration being frozen by a copy-paste. The new test builds the real menu against a recording stub and checks, for **every** fog entry the menu wires, that the preset it passes is the preset its own label advertises — enumerated from the menu-building code rather than sampled, so a mistyped constant fails by name. Also: two `veaf-build` help strings told a release manager to run `veaf-tools-updater update --tag …`, and the updater has **no subcommands** at all (it is a bare `typer.run(main)`); a test now refuses any help string that puts a bare word between the binary and its first option.
- **Every scaffolded `mission.yaml` claimed security was off by default** (`FIX-DOCAUDIT-CODE` ticket 05). The generator emitted `disabled: true  # true = no password required (default)` next to a runtime whose default is `veaf.SecurityDisabled = false` — security **on**. The shipped default `mission.yaml` was corrected with the documentation, which left the generator as the surviving source of the same claim, minting it into every new mission. A lockstep test now compares the two, so correcting one and forgetting the other fails rather than ships.
- **The radio-specs reference listed engine types under "Aircraft", on 72 of its 88 rows** (`FIX-DOCAUDIT-CODE` ticket 06). `parse_display_name` searched for `type = "…"` under a comment claiming that field held the aircraft's display name at the top level of the datamine dump. Measured against **all 170** unit files at the pinned ref, that comment was wrong twice over: the top-level `type` is the **DCS id** (identical to the file name in 168 of the 170), and the `^\s*` pattern matched the **engine block's** own `type` — which sits some 600 lines earlier. Hence `TurboFan` for the A-10C and F-16C, `TurboJet` for thirty Mirage F1 variants, `Piston` for the FW-190D9. The field that works is `DisplayName`, present in all 170 at the outermost indentation, taken by shallowest occurrence so a pylon's own `DisplayName` cannot win. The defect was **not confined to the page**: `dcs-radio-specs.yaml`, the file the presets injector loads, carried the same 48 wrong names. Both are corrected, and by **merge rather than regeneration** — the YAML diff is 146 lines of which every one is a `name:`, no override lost; the Markdown could not be regenerated at all, since the generator writes its output over the **French** page and would have replaced hand-written French prose with generated English.
- **Four blind spots in the `docs-check` gate itself, each proven by a defect that survived it** (`FIX-DOCAUDIT-CODE` ticket 04). An **explicit `{#anchor}` now retires the heading-derived slug**: mkdocs' `attr_list` *replaces* the generated id rather than adding to it, so the gate was validating links that 404 on the published site — five dead anchors got through exactly that way. **Same-page anchors are checked at all**, which they were not: a table-of-contents entry pointing at a heading whose explicit anchor made the derived slug unreachable passed CI untouched, and seven such links had to be found by hand. **`slugify` stops stripping underscores** — `_` is a word character for pymdownx, so a `build_variants:` heading really is served as `build_variants`, and registering it as `buildvariants` made a dozen *correct* links in `MISSION_YAML_REFERENCE` invisible to the gate; this one had to land first, or the same-page check would have buried its real findings under false positives. And **CLI coverage keys on options, not just command names**, which is how `capture-map --parking` shipped with zero documentation through a green gate: options are read from the typer signatures by **AST**, because typer derives `--no-backup` from a parameter named `no_backup` with no literal anywhere in the file. The hardened gate immediately found two genuinely dead links the old one could not see (`#custom_scripts` against an anchor that is `custom-scripts`), and each of the four rules was verified by injecting its defect into a real page and watching the gate name it. The option rule is enabled for the **updater** only, and that is a measurement rather than a preference: the mission-maker guide names 4 of the main CLI's 59 long options because it is a guide, not a reference, and pointing the rule at it would report 110 defects on the wrong page — the full CLI reference is `DOC-AUDIT-FIXES` ticket 04, and adding its rule there is one tuple entry.
- **The documentation's broken *form*: a rendering defect repeated 58 times, seven dead anchors and six links that 404 on the published site** (`DOC-AUDIT-FIXES` ticket 02). `LUA_API_REFERENCE`'s metadata blocks — `**Version :**`, `**Dernière mise à jour :**`, `**Module ID :**`, `**Objectif :**` — were consecutive lines with no blank line between them, which Markdown collapses into a single paragraph: the browser showed each block as one run-on line, in 21 places per language. The fix had to keep every one of those lines anchored at column 0, because `docs_version_stamp.py` rewrites three of them with `^`-anchored regexes at deploy — turning the blocks into bullet lists would have silently broken the version stamper, so blank-line separation it is, verified by re-running the stamper's own patterns against the result. The same pass dropped **24 retired per-module version lines** from that page: `FEAT-LUA-BUILD-STAMP` replaced per-module versions with the single `veaf.BuildVersion` stamp, and `veafSpawn.Version` / `veafCombatZone.Version` no longer exist in the code at all. **Seven dead same-page anchors** were fixed — `developer/GUIDE.md` had four in its own table of contents, each pointing at a heading-derived slug whose heading carries an explicit English anchor, which mkdocs' `attr_list` makes the *only* id. **Six links escaped `docs_dir`** and therefore 404 on the site (`../../docs/adr/…` from a page two levels deep); they now use the absolute GitHub URL the rest of the pages already use. `PIPELINE_REFERENCE` listed its steps 1, 2, 3, **6**, 4, 5 against its own promise of *“dans cet ordre”*: the numbering was right — it matches the execution order in `build.py` — so the step-6 block was **moved** rather than renumbered, and steps 4 and 5 gained the explicit anchors their siblings had, so every step can be deep-linked. `TOOLS_REFERENCE` said goodbye (*“Bonnes publications ! 🚀”*) and then carried on with a whole further section which **repeated an earlier one verbatim**, the same five-step language-resolution list twice on one page; the duplicate is gone, its one unique sentence folded into the survivor, and the hand-written table of contents — 4 entries of some 20, in the wrong order — was deleted rather than completed, since mkdocs renders one from the headings and a hand-maintained one drifts by construction. A **corrupted path** a reader would have copied was repaired in both languages: `%USERPROFILE%\.gemini\extensions` was followed by a literal **vertical-tab byte** where `\veaf-mission-editor` belonged — a Windows path's `\v` interpreted as an escape when the line was written. Plus about sixty prose corrections: French grammar and agreement, franglais retired (*stabilotées*, *droppant*, *misroutait*, *committée*, *plancher de cliquet*), one page's stray *tu* among its *vous*, English guillemets and ASCII hyphens standing in for em dashes on the English pages, duplicate section anchors, and a `veafCombatZone` section that sat in a different position in each language. Two claims corrected on the way: `mission-maker/GUIDE`'s advice to edit the generated `veaf-config.lua` destroyed itself in its own sentence (*“éditez-le — c'est généré, **donc** vos modifications seront écrasées”*), and `MIGRATION_GUIDE` told makers to rename `veaf.SecurityDisabled` when the runtime honours **both** spellings deliberately — its own docstring records that treating “nothing in this repository assigns it” as evidence, for a *config* field, is how three years of fail-safe breakage went unnoticed.
- **Three of the audit's own counts were wrong, in both directions, and the sweeps that corrected them are worth keeping** (`DOC-AUDIT-FIXES` ticket 02). Dead anchors were seven rather than five and escaping links six rather than four, because the audit had sampled; both were re-derived by enumerating the whole tree. In the other direction, two sweeps nearly *introduced* breakage. A hand-rolled slugifier that collapsed whitespace runs reported **13 phantom dead anchors** — the repo's, and pymdownx's, is a plain `.replace(\" \", \"-\")`, so `Unit & Group Management` really is `unit--group-management`, two dashes and all; the rule is to import `docs_check.slugify` and never reimplement it. And a blanket `../../` → GitHub-URL conversion **broke 55 valid links** before being reverted: from `doc/mission-maker/scripts/`, `../../` lands in `doc/`, which is *inside* `docs_dir`, so only pages two levels deep escape. `docs-check` was green before and after that breakage, since it does not verify external URLs — which is one more reason the gate hardening is tracked as its own lot.
- **The documentation said the opposite of the code in about forty places, and a five-pass audit found them** (`DOC-AUDIT-FIXES` ticket 01). The `docs-check` gate was green throughout and stayed green: everything it guards — links, anchors, translation existence, nav — was healthy, and what had rotted is the one thing it cannot see, **content**. The largest cluster is security, where `REVIEW-SECURITY-LAYER` changed the model and only its own page followed, half-way: the pilot guide still promised *“l'authentification reste valide pendant 10 minutes”* — the exact sentence the change deleted — while `veafSecurity.md` carried *“access is granted for `authDuration` minutes”* three lines above the danger box saying the opposite. Both are gone; the pilot guide now describes the real model in pilot vocabulary (password checked per command for an unlisted pilot, a listed pilot's own tier applying by itself, the `OPEN` and `MM` tiers the table lacked) and, for the first time, **the rule a pilot actually trips over**: DCS cannot tell which occupant of a group clicked an F10 entry, so a protected menu command works at the level of the group's **lowest-graded occupant** — with `_auth elevate` raising the group to the requester's own level for two minutes, verified as a real marker verb rather than assumed. Eleven surviving `/secu login` references across the script pages went with it, plus a documented `veafSpawn.defaultSecurity` field that **exists nowhere in the code**. Beyond security, pages that inverted their own subject: `veafSanctuary` described `coalition` as the side **destroyed** when it is the side **protected**, and gave `0` for two defaults that are `-1 = disabled` (its own builder table contradicted its prose in both cases); `veafAirWaves` presented its altitude bounds as AI cleanup when they gate **player detection**; `veafAssets` documented `jtac` as a boolean when the value is the **laser code**, and claimed a carrier integration its module does not reference; `veafWeather` documented `_weather` marker commands that are **not registered** (they are remote `/weather`, `/atc`, `/atis`); `veafGrass` tested the wrong name (unit, not group); `veafTransportMission` presented `blocade` as a feature where the code is an empty `-- TODO`. **Every command example on `veafInterpreter.md` was invalid**, which stopped being cosmetic when the marker parsers were unified: an unknown key now **aborts** the command, so each documented tag did nothing at mission start. There is no `-spawn` alias (the SAM aliases are `-sa11`/`-sa10`/`-sa6`), `laserCode` is `laser`, a convoy's destination is `dest` and is **mandatory**, and `rounds` does not exist — nor does an equivalent, since `shells` drives bombs and smoke while `-arty` expands to a plain gun-battery group. Rewriting them turned up a defect the audit had missed: `smoke` is **conditional on cargo and is a flag, not a colour**, so the documented `-jtac, laserCode 1688, smoke red` was wrong twice over. On the reference pages: `MISSION_YAML_REFERENCE` claimed security is **off** by default when the runtime default is on (`veaf.SecurityDisabled = false`) — the same wrong comment was corrected in the shipped default `mission.yaml` — claimed `MIST` can be disabled when it is mandatory and re-injected with a warning, listed 25 of the 32 module IDs (four of the six missing ones are switched **on** by that very default), and was wrong about community-script IDs in **both** directions: the case is irrelevant, and an unknown id is not “a warning, ignored” but an **aborting error**. `TOOLS_REFERENCE` documented a `--prerelease` invocation the code **rejects** (a semver pre-release suffix is required) and build scripts the updater does not ship. The developer pages had drifted from their own CI: stylua at the wrong major version and the wrong scope, a Lua coverage ratchet three points stale, a job table missing a blocking gate, `openspec/` in a repository tree that has `.backlog/`, and a “modules not covered” table naming **seven Lua files that no longer exist**. Also, per David's call, reference pages stopped narrating their own history (*“cette page affirmait l'inverse jusqu'au …”* with internal ticket ids): provenance belongs in git and here, not in a page a third party reads. Every fix landed in **both languages in the same commit** — three defects found during the audit were fixes that had only ever been applied to one language. Two of the audit's own findings were **disproved while being applied** and are recorded as such in the ticket, because an audit finding is a hypothesis until the cited line is re-read: the claim that lowercase community ids are silently ignored (they are not; matching is case-insensitive) and the claim that `elevate` is gated at level 10 (it is capped at the requester's own level instead).
- **A `convert-other` test failed on any machine whose `TEMP` is an 8.3 short path**, and the command was never at fault. `test_plain_miz_is_passed_straight_through` built its expected path from `TemporaryDirectory()` and compared it to what the command received — but `convert-other` puts its input through `resolve_path`, which returns an **absolute, resolved** path, so on a workstation where `tempfile.gettempdir()` is `C:\Users\DPIERR~1\AppData\Local\Temp` the resolution expanded the short name and the two `WindowsPath` values differed **by form alone**. CI never saw it, its temp directory already being a long path, so the suite was green there while failing locally on every single run — the kind of failure that teaches a developer to ignore a red test. The assertion now compares resolved paths. The **family was enumerated rather than sampled**: all seven places in the suite that compare a path built from `tmp_path`/`TemporaryDirectory` against a received value were listed, and the empirical proof that only this one traverses a resolution is that the full suite runs on a machine with an 8.3 `TEMP` and this was its only failure. 3385 tests now pass locally with none failing.
- **A rebuilt checklist picture no longer arrives under a name DCS has already cached** (`FEAT-ASSIST-FOLLOWUP` ticket 01). DCS caches embedded resources **by name**, and during the first checklist flight the image for state 0 showed raw i18n keys while every later state was translated — the `.miz` was innocent, all seven PNGs matched a fresh render byte for byte, but state 0 was the only one already *displayed* under an earlier build, so DCS served its cached bitmap and only a full restart cleared it. The symptom, *"the text is wrong but only on the first image"*, points nowhere near the cause, and it hits any mission maker iterating on a checklist. The embedded file name now ends in **8 hex characters of a SHA-256 of its own bytes**; identical content keeps an identical name, so there is no churn in the archive. **The resource key deliberately carries no digest** — it is the stable handle the emitted Lua asks `a_out_picture` for, so editing a label must not change a mission's scripts, and a test pins that. **The orphan question was read rather than assumed**: `write_miz` does copy any source-archive file absent from `additional_files`, so a per-build name *would* leave the old picture behind — except `create_miz` rebuilds the `.miz` from `src/` on every build and the images only enter afterwards, so nothing from a previous build is in the archive being copied. Had the build written on top of its own output, this change would have earned back exactly the bug `FIX-COMMUNITY-SOUNDS-PRUNED` repaired. One consequence fixed alongside: `resources()` **rebuilt** each name from the id and the state, which a digest makes impossible — leaving it would have made `mapResource` name files the archive does not contain, which is that same editor-pruning bug from the other end. 7 tests, plus 4 existing ones rerouted through the new `file_names` so they pin the text or the pairing rather than the naming scheme. **Still needs one flight to confirm**: no unit test can see DCS's cache — change a label, rebuild, and fly without restarting DCS.
- **A combat mission's remaining-enemies count could disagree with itself** (`FIX-SECREV2-EXPIRED-DEFERRALS` ticket 01, `SECREV-2` / VMR-088). `getRemainingEnemies` asked DCS for the same unit's life on every test: once for a trace, once for `== 1.0`, once for the kill threshold, and once more inside the "damaged" trace. A unit under fire changes between reads, so it could fail `== 1.0`, read back at full health on the next line, or drop past the threshold and land in the `else` branch whose own comment claimed it could never be reached — and these counts feed the message a player has no way to check. One read into a local decides now. **Measured before and after, because neither the review nor I had the number right**: it was **2 calls on the alive path and 4 on the damaged one** (the review said three), and it is 1 either way now. The `else` branch is genuinely reachable once a single read decides, and correctly counts nothing — the group's spawned count turns that unit into a dead one — so its comment now says that instead of denying the branch exists. 10 tests. Explicitly **not** the 794 pre-formatted trace calls the same finding measured across `src/scripts/veaf/`: David's verdict there, *"that is a lot, not a finding"*, stands.
- **An alias password is no longer excused by somebody else's login** (`REVIEW-SECURITY-LAYER` ticket 01, completing the lot). The three `veafShortcuts` gates were the global boolean's last readers, and they are a different question from the tiers: an alias password is a **per-alias secret with no tier attached**, so "which level excuses it?" had no answer in the tier model. David chose option 1 — being in `veaf-pilots.txt` at all excuses it, whatever the level — implemented as `veafSecurity.isKnownPilot(markId)`. An author the server cannot resolve still has to give the password, and `SecurityDisabled` (either spelling) still excuses everything, since a solo mission that turned the layer off must not keep demanding alias passwords. **The global boolean now has no readers at all.** Wiring this widened `getMarkerSecurityLevel`'s callers and exposed a defect worth more than the change: it indexed `veafRemote` **unguarded**, unlike `getPilotLevelForUnit` three functions below — harmless while every caller happened to load that module, and a *raise inside a security check* as soon as one did not. It returns -1 (unknown author) now, so the failure mode is a refusal rather than a crashed handler. Found by the `veafShortcuts` characterisation suite, which has nothing to do with security and simply does not load `veafRemote`. 7 further tests.
- **One `/login` no longer unlocks every secured command for every player on the server** (`REVIEW-SECURITY-LAYER` ticket 01). `checkSecurity_L0/L1/L9` each opened with `if veafSecurity.isAuthenticated() then return true end` — a module-level boolean — so a single authentication granted every secured marker command to everyone for `authDuration`, and while anyone was logged in **the per-pilot path was never reached at all**: the blunt mechanism disabled the precise one it was supposed to complement. The per-group machinery this lot built (a group acts at its **lowest**-graded occupant's level, raised to the requester's own level for two minutes by `_auth` from an identified channel) was complete, tested, and short-circuited. **What this changes, measured**: a pilot listed in `veaf-pilots.txt` notices nothing — their level already satisfied the check and they never needed a password; a pilot who is *not* listed must now supply the password on every command, since there is no ten-minute session any more. `veaf.SecurityDisabled` still bypasses everything, because it is a mission-wide switch rather than an authentication path, and a test pins that it survived. `checkSecurity_MM` never had the short-circuit and now has tests pinning that it refuses without a password and is unaffected by anyone's login, since it takes no actor at all. Documented in both languages as a **behaviour change server admins must announce** — including the case the elevation exists for, an instructor sharing a group with a student, where DCS cannot tell which occupant clicked. 7 tests.
- **A v5-era mission asking for security *off* was getting it *on*, for three years** (`REVIEW-SECURITY-LAYER` ticket 03). `SECREV-009` moved `isAuthenticated`'s fallback from `veafSecurity.SecurityDisabled` to `veaf.SecurityDisabled` on the grounds that the old name was "never assigned" — true inside this repository and **false outside it**, because it is a *mission-facing config knob*: the only places that assign it are mission configs, including our own demo mission. One line changed, no alias, no warning. The direction is fail-safe, which is why it went unnoticed — nobody was over-privileged — but every secured command then refused for **everyone** on a mission whose author had deliberately opened them, and a permission denial reads as "the security layer is broken", not "your config field was retired". `veafSecurity.isSecurityDisabled()` now honours both spellings and warns **once** per mission for the old one, since the flag is consulted by every secured gate and warning per read would bury the log it exists to inform. Documented in both languages as deprecated-but-honoured, naming **v7** as the release that retires it. `convert-v5` was never at fault and needs no change — its regex accepts both spellings. **The lesson is the durable part**: for a config field, "nothing in the repository assigns it" is evidence of nothing. **Also finished: ticket 02's deprecation warning, which had never been wired up.** Looking for the precedent ticket 03 was told to copy found there was none — `LEVELS_BY_NAME` and `DEPRECATED_LEVEL_NAMES` had **no reader anywhere in the tree**, and the comment above the tier aliases claimed `veafSecurity.registerCommandHandler` emits the warning when **no such function exists** (`registerCommandHandler` lives in `veafCommands`). The rename itself worked, because callers use the constants directly; it is the by-name path — what a config string would use — that was declared and left unwired. `veafSecurity.levelForName()` is that wiring, case-insensitive, nil for `OPEN` (no check rather than a level) and nil rather than a default for an unknown name. 21 tests across the two.
- **The last of the 2026-07-01 security review's cosmetic findings, and `SECREV-2` closes with all 140 decided** (ticket 07, fourteenth and final pass). The 18 that were left had been reserved *in writing* for `REFACTOR-MARKER-PARSER` — "which rewrites exactly those files" — so shipping that lot made the reservation come due. Crossed against the files it actually rewrote: **3 hit, 15 did not**, and that is the whole of the pass, because the policy that produced these 18 is the same one that says not to touch the other 15. Of the three, two were **already gone**: `path` was handled twice in `veafRadio`'s `elseif` chain and the second branch was unreachable, deleted rather than translated by the migration and now pinned by a test; and `string.format("Keyword password", val)` disappeared with the hand-rolled branch it lived in. The third, `local spawnCapFunction = function() end`, was confirmed dead and removed. **One finding inverted its own severity**: VMR-136 is classed *Readability*, but a **working** `%s` there would have written a marker password into the log — the broken format string was what prevented it, so fixing it as reported would have turned a cosmetic finding into a security one. Deleting the call was right for a reason the finding does not contain. Two further corrections to it: it names `veafCombatMission` while its path is `veafCasMission.lua`, and the same line existed a second time in `veafTransportMission` which the review never reported. The 15 unreached findings are `decided-deferred` — **a decision, not a completion** — each listed by file in the ticket so it resurfaces the next time a lot edits one; two share `veaf_build/worker.py`, so touching it retires both.
- **Three more marker parameters took the command down, and the previous lot's "family closed" claim was wrong** (`FIX-MARKER-PARAM-CRASHES-2`). That claim rested on a probe of **thirteen hand-picked cases** — numeric keywords plus `side`/`name`. Re-run as an actual sweep, with every keyword **enumerated from the source** (`veafSpawn`'s 53 from `ParameterRules`), each tried bare, with `banana`, with `-1` and with `999999`, plus degenerate inputs, the coverage is **485 cases** and three sites still raised: `_transport, from` (`string.format("%s", nil)` — the first lot fixed that module's three numeric keywords and never probed its string one), and `_spawn` on `defense`/`armor`/`disperse`/`delayed`, where `getRandomizableNumeric` returns nil and `nil >= 0` raises. Groups B and C are clean across 75 further cases. **The finding that outlives the fix**: four of the nine are in `veafSpawnParser`, the module `REFACTOR-MARKER-PARSER` designates as the *source* of the shared parser for being already declarative and proven in production — `VMR-025` fixed `_num` and left its sibling `_numNonNegative` immediately below it, plus the inline `delayed`. `VMR-019`'s pattern for the third time, inside the module held up as the healthy one; "proven in production" was an assumption, and the PRD now says so on measured grounds. The sweep ships as a **test that reads `ParameterRules`** rather than a list of keys, so a parameter added tomorrow with an unguarded conversion fails in CI — verified by injecting one and watching it fail by name.
- **Six marker parameters still took the whole command down when the pilot omitted or mistyped their value** (`FIX-MARKER-PARAM-CRASHES`). Proven before being fixed, by a `pcall` probe over the real parsers under Lua 5.1: `_cas, side`, `_move group, name`, and `_transport` on each of `size`, `defense` and `blocade` — the last three raising both on a missing value and on a non-numeric one. `VMR-019` fixed exactly this crash shape and introduced `veaf.safeNumber` for it, and reached four sites in `veafCasMission`. It left that module's `%s`-on-nil log line for `side` (with `val:upper()` waiting one line behind it), never scoped `veafMove`'s identical `%s` on `name`, and **never touched `veafTransportMission` at all** — whose `size` is the same parameter with the same 1..5 bounds and still carried the original `tonumber(val) <= 5`. A bad parameter now costs the pilot that parameter and nothing else: numeric keywords keep their default, and a valueless `side` leaves the side *unset* rather than falling through to RED, so `executeCommand` derives it from the marker's own coalition. Out-of-range values stay ignored rather than clamped, as `VMR-019` decided for the twin sites. 12 tests, and the fix is deliberately not the refactor: `REFACTOR-MARKER-PARSER` addresses why one fix reached one copy of six. On Sourcery's review, the `safeNumber`-plus-bounds pattern the seven numeric keywords had written out inline became **`veaf.safeNumberInRange(value, min, max)`** — the rejecting twin of `veaf.safeNumber`, which clamps: a marker keyword wants `size 42` to keep the command's default, not to silently become 5. Naming the rule also removed the need for the long comments repeating it at each site.
- **A release could be published as tags with no release behind them** (`SECREV-2` ticket 07 / VMR-104, VMR-105 — and with it **ticket 04 closes**). `publish` pushed the git tags first and created the GitHub release second, so an absent `gh` CLI left `published-v<x>` on the remote pointing at a commit with no release — and for a full release the floating `published-latest` had already been force-moved onto that same commit, which is the tag the updater and every "latest" link resolve. `gh` is now checked **before** anything reaches the remote, and the floating tag moves only once the release exists. The finding's other half does not reproduce: `logger.error` raises `typer.Abort`, so a failed push or release creation already aborted the publish — which is precisely what keeps the floating tag where it was (VMR-105); the `git tag -d` that runs unchecked is deliberate, it is how re-publishing a version is allowed, and it now lives in one place instead of four. **Also fixed: the updater's download is capped.** It read `response.content` whole, so a reply with no `Content-Length` that never ends had no bound at all — on a tool that installs and then *runs* what it downloads. Now read in 64 KiB chunks against 256 MiB, a bound taken from measurement (largest real asset: `published.zip` at 61 MiB) and matching `safe_zip.MAX_MEMBER_UNCOMPRESSED_BYTES`. That was ticket 04's last open item, so its three shapes now all refuse. 18 tests.
- **The remains of the SLMOD bridge are gone, four years after the bridge** (`SECREV-2` / VMR-130, David's call). `veafRemote.monitoredCommands` was filled by `veafRemote.monitorWithSlMod(command, script, …)`, the mission-facing half of the SLMOD integration. That registration API was deleted on **2021-08-24** (*"removed slmod monitoring altogether"*), leaving a table nothing could fill, a consumer that could only ever warn — and behind it a `mist.utils.dostring` of arbitrary Lua gated by a password that ships in a public repository. Removed: `executeRemoteCommand`, `markTextAnalysis`, the `_remote` marker command, `monitoredCommands`, `CommandStarter`, the two orphaned `USE_SLMOD*` flags, and the `veafShortcuts` branch that routed markers there. Remote execution keeps its supported route, `registerRemoteModule` / `executeCommandFromRemote`, which is the only one the server hook uses; `_remote` was documented nowhere. **Also fixed: the smoke-harness server errored on every request** — `handle_client_connection` returns nothing, so the failure branch concatenated a nil and raised each time, while the branch the finding actually names (`clients[id]`, with `id` undefined) could never run; the response had already been sent, which is why this stayed invisible (VMR-073). **And `dictionaryNormalizer.lua` is deleted** — a 2021 one-shot CLI tool nothing referenced, whose job the v6 Python pipeline does (VMR-129). **122 of 140 findings decided: every Critical, High, Medium, Security-flaw, Documentation and Error/bug tier is now closed**, leaving 18 readability / optimization findings that ticket 07 reserves for files being changed anyway.
- **Every failed mission build left a temp file behind, and the reason was a handle nobody had closed** (`SECREV-2` ticket 07 / VMR-053). `write_miz` held its `NamedTemporaryFile` open while `zipfile.ZipFile` wrote to that same path, so on Windows `os.unlink` failed with a sharing violation — and the surrounding `contextlib.suppress(OSError)` swallowed exactly that, leaving a `veaf_mission_*.miz` beside the mission after every failure. Now `mkstemp` plus an immediate close, with the cleanup in a `finally` so it also covers a failing `os.replace`, which the old code did not. **The headline half of the finding does not reproduce**: it claims a partial failure returns success with the original untouched, but `logger.exception` is `error(..., exception_type=type(e))` and `veaf_libs.logger.error` *raises* — the failure has always reached the caller, which is also what made the `temp_zip_path = None` line below it unreachable code. Proved by putting the open handle back and watching 6 of the 9 new tests fail, one of them a control, because `os.replace` cannot rename an open file either. **Also fixed: the bundled Lua module list is validated before it reaches Lua emission** — and the real defect there was that the two consumers disagreed, `lua_config_generator` reading `mod["var_name"]` directly where `config_migrator` treats it as optional, so a JSON one accepts the other raises on. `get_modules()` now refuses a payload that is not a list of entries carrying an `id` and a `filename`, naming the file, and normalises the optional fields so both consumers see one shape (VMR-061). 18 tests. **114 of 140 findings decided; the 26 left are all decision-gated.**
- **The security page told mission makers that `L0` was the public tier; in the code it is ADMIN** (`SECREV-2` ticket 07 — the Documentation tier, now closed). `veafSecurity.lua` records the incident in a comment: someone read "L0 — all players" off the documentation and would have locked a deliberately public command to administrators. That was corrected in the mission-maker GUIDE on 2026-08-06 and **left standing on the module page**, which is what a half-finished correction looks like. Both language versions now carry the same tier table (`ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT` / `MM` / `OPEN`), the deprecated-alias warning, and the password hierarchy — the finding only asked for the missing Mission-Master tier (VMR-124). Two further traps on that page, neither reported: the key-constants table repeated the inverted meaning, and the password example wrote `myAdminPassword` into `password_L9`, the **loosest** tier — a mission maker following it put the admin password on the tier every listed pilot already passes. The pilot guide's permission table had the same problem in plainer words ("Pilots = non-spectator players", which matches nothing in the code) and is rewritten for a pilot audience: two ways in, which commands are open to everyone, and that the administrator password also opens everything below it (VMR-127). Also fixed: the pilot guide documented an **ASSETS menu hierarchy that does not exist** — the menu is flat, one submenu per asset, so the *Tankers* / *AWACS* steps were invented, the labels were wrong (`Get info on X`, not *Info*), and the F10 tree diagram additionally put carriers under ASSETS when `CARRIER OPS - BLUE/RED` is its own menu (VMR-126); the shortcuts pages listed 6 aliases that bypass security where **8** do, `-point` and `-longsmoke` included (VMR-140); the English `veafCombatZone` page had its See Also links with no heading (VMR-123); and the two disagreeing test counters — `TESTING` said 34 suites / ~1000 tests, `ROADMAP` said 31 / ~915, the tree holds 36 — are **deleted** rather than refreshed, the way ticket 06 dealt with this same drifting-counter family (VMR-139). Three findings needed nothing: VMR-120 was closed by the VMR-008 sweep and is now enforced by `docs_check`, VMR-121 and VMR-122 were already done. **112 of 140 findings decided; every one left awaits a decision rather than a fix.**
- **A Windows path in a v5 weather config converted to nothing at all, and four more confirmed bugs** (`SECREV-2` ticket 07, third Python batch — the conversion and validation chain). `_extract_list` treated any backslash as an escape regardless of string state, where `_extract_table` ten lines above honours one only *inside* a string: a path like `"C:\\missions\\"` leaves the closing quote preceded by a backslash, so the string never closed and every later brace went uncounted. Measured: **zero** tables returned instead of two, so the whole list silently vanished rather than being shortened (VMR-068). Also fixed: extracting a v5 block to `mission.yaml` no longer turns a statement that shares the closing brace's line into a comment — `} local keep = 1` became `-- [v6 extracted…] } local keep = 1`, so live code was lost; the span is now isolated onto its own lines, as the sibling `_extract_inline_value` already did (VMR-048). A v5 position carrying an explicit `"lat": null` beside a real `latitude` no longer loses the coordinate: `dict.get` only reaches its default when the key is *absent*, so the mission ended up positioned nowhere without a warning (VMR-051). A source mission table that exists but will not parse is now reported as **unreadable, with the parse error**, instead of as *not found* — the one message guaranteed to send the mission maker looking in the wrong place while the group / preset / waypoint / TUM checks quietly did not run (VMR-062). And `clear_veaf_triggers` no longer half-handles a list-shaped trigger category: the collection loop accepted one, the removal loop right below would have raised on `list.get`, and it could not have been right in any case — a trigger index is shared across categories, so mixing 0-based positions with Lua's 1-based keys would delete *other* triggers. Since every read of `mission_content` passes `keep_as_dict=["trig", "trigrules"]`, the shape cannot occur; that invariant is now pinned by a test against a real `.miz`, with the branch replaced by an explicit fail-closed refusal (VMR-050). 26 tests. **103 of 140 findings decided.**
- **A mistyped trigger-zone name crashed every air wave, and five more one-per-module defects** (`SECREV-2` ticket 07, fourth Lua batch). `AirWaveZone:setTriggerZone` is deliberately lenient — it stores the name, and when a centre is already configured it warns instead of failing — but `deployWaves` then tested the *name* rather than the zone, so `veaf.getTriggerZone` returned nil and got indexed: a warning at configuration time, a raise at the first wave. It now asks for the zone and then decides, which is the shape `AirWaveZone:check()` already had (VMR-085). Also fixed: `-auth login abc5` **raised** rather than being refused, because the guard `not actualMinutes:match("%d+")` is unanchored and `"abc5" * 60` is an arithmetic error — measured in Lua 5.1 — while `-auth login -5` scheduled the logout in the past, unlocking the mission and relocking it without a word; both now go through `tonumber` with a floor (VMR-095). The SRS positional broadcast no longer truncates latitude and longitude to whole degrees, which put a transmission up to ~111 km from the marker it was handed, and in the other direction west of Greenwich, since Lua 5.1's `%d` truncates toward zero instead of complaining (VMR-093). The remote carrier `start` command now honours the duration it is given: `_parameters` comes out of a string match, so the `type(_parameters) == "number"` guard was never true and every remote start ran for the 45-minute default — and the unreachable branch inside it read a global `parameters` that does not exist (VMR-086). And removing a Skynet element whose DCS group is already gone no longer raises on a nil dereference that a `---@diagnostic disable-next-line: need-check-nil` had recorded rather than fixed; the network also stopped listing groups that no longer exist (VMR-096). 31 tests. **98 of 140 findings decided.**
- **Sanctuary followed the wrong players, and the review's own remedy would have made it worse** (`SECREV-2` / VMR-094). `A or B and C and D` parses as `A or (B and C and D)`, so `PLAYER_ENTER_UNIT` skipped the unit-name check and registered a follow entry under the key `""`. The finding proposes parenthesising the two event ids together — which would require the `humanUnits` lookup on `PLAYER_ENTER_UNIT`, and that table is filled **once** at `initialize()` from `mist.DBs.humansByName`: a player in a **dynamic slot** is not in it, so Sanctuary would have stopped following them entirely, and a sanctuary violation from a dynamic slot would have carried no consequence. Rather than argue the point, the proposed remedy was applied and the dynamic-slot test watched to fail. The two branches genuinely differ and now say so: entering or leaving a unit is a human by definition and needs only a name, while BIRTH/DEAD fires for AI as well and does need the lookup. **VMR-087 is disproved in the same batch**: its "unreachable branch after clamp" is reachable, because the line above is not a clamp — `if _actualDefense > 5 then _actualDefense = 6 end` *promotes* to 6, which is precisely what fires the branch, and the two tiers spawn different units. What is left of it is that two functions disagree on the ceiling, and removing a difficulty tier is a balance decision rather than a sweep's call.
- **`-showmfd` did the opposite of what it says on AFACs and CAPs** (`SECREV-2` ticket 07, third Lua batch). Every spawn handler passes `not options.showMFD` for the `hiddenOnMFD` parameter; these two passed the flag through unchanged, so the default left the aircraft **visible** on every MFD and asking for `-showmfd` hid it. The finding named the `afac` handler only — `cap` has it too (VMR-099). Also fixed: with all eight AFAC callsigns taken, the callsign loop fell back to `callsigns[coalition][numberSpawned]` and handed out the callsign of an AFAC that is still flying — two aircraft on one name, and the first watchdog to fire releases a slot the other one still uses; the spawn is now refused. **The finding's other half was a regression waiting to happen**: it asked for `>` → `>=` on the limit check, but `numberSpawned` is pre-incremented, so `>` already refuses the ninth AFAC and `>=` would have capped missions at seven — both bounds are now pinned by tests (VMR-098). And: the cargo weight computation no longer swaps `minMass`/`maxMass` **inside the shared units database**, which `findDcsUnit` hands back by reference, so a single cargo spawn edited the descriptor every later reader sees (VMR-100); one convoy with no average position no longer hides every live one from *mark/stop/move closest convoy* — the error it logged also named the **player** rather than the convoy (VMR-101); and an undialable laser code is refused instead of producing a plausible frequency, since DCS codes are octal-like and the 1111..1688 range check accepted 1201, 1210 or 1119, leaving a JTAC lasing on a code no aircraft can enter (VMR-102). 16 tests. **91 of 140 findings decided.**
- **VMR-103 is disproved rather than fixed, and by measurement.** The ATIS new-block check was reported as triggering "on any lower date component, not strict chronology". Enumerated instead of argued: 26 304 hour blocks over three years, 345 963 360 ordered pairs, **zero divergence** from a lexicographic comparison — and the control, the same test with the clock allowed to run backwards, does diverge, so the probe is not hollow. `timer.getAbsTime()` never runs backwards. Two things did come out of the surrounding work: writing the convoy fix I reached for `logger:warning`, which **does not exist** on the VEAF logger (it is `warn`) — the error path being the error, the exact defect this ticket has now corrected four times, caught this once by a test rather than by a pilot; and an existing test asserted that laser code `1500` produces a frequency, pinning behaviour that was wrong (`1500` contains two `0` digits and is not dialable). Documentation corrected in both languages while there: the AFAC example read `code 1688`, but `code` is the **TACAN** channel — the laser keyword is `laser`, and its digit rule was written down nowhere.
- **Every CAP flew its whole route at Mach 0.3** (`SECREV-2` ticket 07, second Lua batch). `convertSpeeds(speed, mach, altitude)` took its `mach` argument and ignored it, using a hard-coded `0.3`; the four legs are called with 0.3, 0.5, 0.63 and 0.63, so any CAP spawned without an explicit speed flew the lot at Mach 0.3 — sluggish patrols in game (VMR-097). Also fixed: the server hook read every player's statistics with the **Lua list index** (1..8) where `net.get_stat` expects one of the `net.PS_*` constants, so the numbers came from whatever ids 1..8 happen to be and were filed under the wrong names — the finding's own remedy, passing the name as a string, would not have worked either, and the repo's datamined API schema is what settled it (VMR-071); and `trainingSpawnZone.lua` called `veafServerHook.logError` although `veafServerHook` appears exactly once in that file — the call itself, copied from the server hook — so hitting the depth limit raised instead of reporting, the same shape as VMR-077 and VMR-078 (VMR-075). **85 of 140 findings decided.**
- **Declaring your own mission passwords now turns the shipped ones off, instead of adding to them** (`SECREV-2` ticket 07 / VMR-040, VMR-033, VMR-039 — the Security-flaw tier is now fully closed). `veafSecurity.lua` ships two password hashes common to every mission, in a public repository. The generator added a mission's own `password_hashes` to the table **without clearing it**, so the well-known password kept opening a mission that had carefully configured its own — while `password_mm_hashes`, three lines away in the same function, has always *replaced* its table. That asymmetry was the whole defect: the fix is neither destructive nor cosmetic. `L0` is cleared alongside `L1`, deliberately, because `checkPassword_L1` accepts L1 **or** L0 and leaving the shipped L0 hash would have made the change decorative — so on a mission that declares its own hashes, nothing grants the ADMIN tier by password any more (ADMIN comes from the pilot's level in `veaf-pilots.txt`). Missions that declare nothing keep the shipped defaults, so nothing changes under anyone's feet. The unsalted SHA-1 is untouched on purpose: a known password is known whatever the digest. **Also corrected: the documentation said SHA-256 while the code hashes SHA-1** — `mission.yaml`, the generator's template, the MCP action's docstring and both GUIDE pages, so a mission maker following the docs produced a hash that could never match and believed access was restricted while only the public default worked (`MISSION_YAML_REFERENCE` already warned about this, which made it a half-finished correction rather than a discovery). 4 tests. **82 of 140 findings decided.**
- **Every formatted log call in `dcsDataExport.lua` was broken, and not for the reason reported** (`SECREV-2` ticket 07, first Lua batch). The finding calls reliance on Lua 5.1's implicit `arg` table a portability risk for 5.2+; measured on 5.1 itself, `arg` is **nil inside a vararg function** — the global `arg` holds the script's command-line arguments, which is why it looks defined. So `formatText`'s format branch never ran, and the five logger methods called `unpack(arg)` on nil, which raises outright unless the interpreter was built with `LUA_COMPAT_VARARG` — a compile-time option of whichever Lua DCS ships. All six occurrences now use `{...}` (VMR-079); `mist.lua` has the same pattern six more times and was left alone as third-party code. Also fixed: all **three** branches of `veafMissileGuardian`'s remote handler called functions that do not exist — the module was renamed *mission* → *guardian* and the handler never followed, so every remote command raised (VMR-090); the pretty-printer's `skip` list was written into the caller's own table, turning `{"units"}` into `{"units", units = true}` for whoever passed it (VMR-080); and an unserializable value was reported through an undefined `log`, so the error path was itself the error (VMR-078, the same defect as VMR-077). **79 of 140 findings decided.**
- **An unreadable installed version made the updater claim a new release on every run** (`SECREV-2` ticket 07, second Python batch). `_version_tuple` falls back to `(0,)`, which sorts below every real release, so a version string it could not parse was treated as *very old* rather than as unknown (VMR-063). The fallback is now a named sentinel the caller recognises, and the check stays quiet when it cannot tell what is installed. **Writing the tests mattered more than the fix here**: the first three passed for the wrong reason — a cache mock keyed on `checked_at` where the code reads `last_check`, so the code went to the network and the exception was swallowed — and only the control test, that a readable *older* version still prompts, exposed three green tests exercising nothing. Also fixed: counting a coalition's units no longer crashes when DCS returns an indexed table instead of a list, which is what the Mission Editor produces after a country or group is deleted (VMR-047 — half of that finding is obsolete, `_max_ids` no longer exists); and the `ask` REPL survives any error rather than only `RuntimeError`, so one bad question no longer ends the session (VMR-064). **75 of 140 findings decided.**
- **A METAR's forecast could overwrite the weather actually observed, and six more confirmed bugs** (`SECREV-2` ticket 07, first Python batch of the Error/bug tier). The visibility branch had no `break`, so the **last** four-digit group in the report won — and everything from `TEMPO`, `BECMG`, `PROB` or `RMK` onwards is a forecast or free text, not the observation. A report observed at 9999 and ending in `TEMPO 3000` was flown at 3000 m; the parser now stops at those words and keeps the first prevailing visibility (VMR-070). Also fixed: `exit()` replaced by `raise typer.Exit()` in the CLI commands — it is installed by the `site` module, so it is absent under `python -S` and not guaranteed in the PyInstaller exe we ship, and `typer.Exit` was already the idiom in the same directory (VMR-065, **10** occurrences against the one reported, plus one unreachable line found on the way: `prepare.py` called `exit(1)` after a `logger.error` that already raises); named-point coordinates are emitted as numbers instead of quoted strings that only worked through Lua's coercion, and the point's **name** — which the finding does not mention — is now escaped, so a quote in it no longer produces Lua that fails to parse (VMR-060); a group with no name is skipped instead of crashing the whole waypoint extraction on `pattern.match(None)` (VMR-067); a non-numeric trigger key no longer crashes the search for the next free index (VMR-056); a QRA guard whose `False` default made it always true no longer emits `ToggleAllSilence(false)` into every mission that never asked for silence (VMR-059); and a failed live-METAR fetch now names the exception type and keeps its traceback, so an avwx API change is tellable from a service outage (VMR-069). 25 tests. **71 of 140 findings decided.**
- **A marker typo took the whole `_move` parser down, and nine more confirmed bugs** (`SECREV-2` ticket 07 — every finding the review's own verifier had marked CONFIRMED is now decided, none is left). `veafMove` logged the value with `string.format("%d", val)` on the **raw** marker text before `tonumber()`, and the format call runs before the logger sees it, so the log level made no difference: `_move speed abc` raised. Measuring Lua 5.1 changed the fix — `string.format("%s", nil)` **also** raises, and nil is exactly what `_move speed` with no value produces, so `%s` alone would have shipped a fix that still crashed on the simpler typo. Seven occurrences across `veafMove` **and** `veafTransportMission`, against the one line reported; three lookalikes in `veafShortcuts` are safe (`math.random`) and were left alone. Also fixed: `veaf.exportAsJson` wrote to a file handle before checking `io.open` succeeded, which raised **inside DCS** when the export directory was unwritable (VMR-081), and the same shape twice in `dcsDataExport.lua` (VMR-076) where the error path itself called an undefined `logError` (VMR-077); hand-written spawn YAML now names the entry and the missing key instead of surfacing a bare `KeyError` (VMR-055); `respawn_default_offset` is validated, where a *string* used to emit silently wrong Lua because `"12"[0]` is `"1"` (VMR-058); and the pilot documentation no longer advertises a `group N` spawn option that does not exist or a CAS menu item that was never there — both in French and English, though the findings named only one page each (VMR-043/045/046). **Four of the ten under-reported their own scope**, the same pattern as VMR-008 this morning. 25 tests.
- **A conversion profile could rename a script out of the mission folder** (`SECREV-2` ticket 07 / VMR-035, the Security-flaw tier of the LOW sweep). `_normalize_script_names` joined the profile's replacement string straight onto `scripts_dir`, and `load_profile` accepts a **filesystem path** as well as a bundled name — so the replacement is not necessarily one we ship, and profiles are exactly the kind of file that gets passed around between mission makers. Rather than assert the risk, the new guard was disabled and the run measured: `escaped.lua` appeared in the parent folder and the original was gone. A replacement that is not a plain filename is now refused with a localized warning, keeping the original name. Three more findings in the same tier were hardened: the auto-downloaded `dcs-bridge.lua` is capped at 2 MiB (measured against its actual 13 237 bytes) since its content is Lua that DCS executes (VMR-034); the updater now requires **every hop** of a release asset download to be https on a GitHub host, because it installs and then *runs* what it downloads (VMR-037) — the first version of that fix had the very hole it was closing, since `requests` follows redirects anywhere by default, and chasing it turned up a second issue nobody reported: walking the chain by hand means the user's GitHub token would have followed the redirect off GitHub, which `requests` strips on its own; and the deferred update script aborts when its `cd` fails instead of running every relative `ren`/`del` against whatever directory it started in (VMR-036). **Three of the ten findings were overstated, and saying so is part of the work**: VMR-038's "untrusted execution" runs under `setfenv(file, {})` — an empty environment reaching no global at all; VMR-042's "missing whitelist" is already narrowed by `:upper()` to keys that are, measured across the file, all fog presets; and VMR-036's "batch injection" is unreachable because Windows forbids `"` in a path. 19 tests. **54 of 140 findings decided**, and the shared-password family (VMR-039/040/033) is left open on purpose: it is a trade-off between breaking every existing server and telling attackers where to look, which is not a sweep's call to make.
- **A dependency bump could reach `develop` without running a single Python test.** `python-quality` watched `src/python/**`, `test/python/**`, `veaf_build/**` and `pyproject.toml` — but not `poetry.lock`. A minor or patch bump that fits the existing constraint changes **only** the lock file, so the whole suite, ruff and mypy were skipped, and the PR was reported green on the strength of the checks that had run: Lua, docs, gitleaks — none of which can notice a broken Python dependency. Dependabot's #687 and #688 sit in exactly that state, seven packages between them and no Python test executed; #687 raises **typer 0.25.1 → 0.27.1**, the framework `build_cli_tree` drives through its internals. #689 caught the `mcp` 2.0 breakage only because a *major* forced the constraint in `pyproject.toml` to move as well. Both triggers now watch the lock.

### Added
- **A gate for the `print()` rule CLAUDE.md has always had and nothing enforced.** `veaf_libs.logger` exists so output can be muted — the MCP server silences the console because stdout carries its JSON-RPC stream — and routed to the log file; a bare `print()` bypasses both. The rule was written down, never checked, and drifted (`SECREV-2` / VMR-052 found one, and looking properly found a second). `test/python/test_no_bare_print.py` parses the whole shipped package with `ast` rather than grepping, because a regex counts `print(` inside comments, docstrings and `pprint(`. That choice paid immediately: my own `grep -r "^\s*print("` reported **zero** — `\s` is not BRE without `-E` — while the AST pass found eleven more in a migration script. A broken measurement reads exactly like a clean result. One exemption, named rather than pattern-matched: `migrate_lazy_log.py`, run by hand and whose console output *is* its deliverable.
- **A test that the three places a lot's status is written agree.** `.backlog/README.md` carries a row per lot, `<LOT>/PRD.md` a `Status:` header and usually a scope table, and each ticket its own header — and nothing checked they told the same story. That cost **four separate corrections in one day**, the last of them inside the very commit that called the pattern out and still left the index row on ⬜. Naming a pattern is not removing it. The rule is **agreement, not conformity**: several PRDs deliberately carry no scope table, so the test compares the sources that exist rather than imposing one shape. It found **14 drifts** on landing — `TOOLING-REPO-LINK-GATE` had all five tickets done and none of them ticked, `SECREV-2` four, and `REVIEW-SECURITY-LAYER`'s PRD still read `ready` while its index row said in-progress. All aligned, taking the **ticket file** as truth: it is the one edited on finishing the work, so it is the source that drifts last.

### Fixed
- **A radio-compass no longer advertises itself as an FM radio** (`FIX-RADIO-LAYOUT-GAPS` ticket 01, closing the lot). Verified end to end at last, and it did not need the Foothold folder the ticket was waiting on — the local missions carry player slots for all four affected types, so looking for the *aircraft* instead of the *mission* unblocked it. On `Operation-Bluestorm-V2_Part_1` (302 aircraft groups) none of `Ka-50`, `Ka-50_3`, `MiG-29 Fulcrum` or `Yak-52` appears in the out-of-range report any more, and the Fulcrum's preset ends up with **one** radio — its R-862 V/UHF — where the ARK-19 used to attract a 30-channel list it could never tune.
- **A docstring the same fix had quietly falsified.** `pack_preset_for_type` still said single-radio "HF/ADF" sets, *"e.g. the MiG-15bis or Yak-52"*, get an `fm_substitute` guess. Measured per radio: the MiG-15bis RSI-6K at 3.75–5.0 MHz sits above the comm floor and still does; the Yak-52's ARK-15M at 0.1–1.795 classifies as `non_comm` and gets no role at all. The HF half stayed true, which is precisely why the sentence survived the change unnoticed.

### Added
- **Flaming Cliffs aircraft get a radio kneeboard again** (`FIX-RADIO-LAYOUT-GAPS` ticket 03, David's decision of 2026-08-10). The ticket's plan was to hand-write radio specs for the ten FC3 types "sourced from the aircraft manuals". Measuring killed that premise: across **40 real VEAF missions, 110 FC3 player slots carry no `Radio` table at all, against 2105 non-FC3 slots that do**. DCS exposes no settable radio on those airframes — their pilots dial frequencies into SRS by hand — so writing specs would have been inventing hardware. What the Foothold workaround actually bought, and what converting to the plan model had cost, was the **kneeboard plate**: the only thing that has ever reached an FC3 pilot. The ten types now declare all three bands (UHF, VHF, FM) in the shipped overlay, flagged **`kneeboard_only`**: the packer builds them a plate, and the build writes **nothing** into their units. Band bounds are the conventional DCS edges chosen to strictly contain what the shipped plan actually puts on each band (measured: fm 30–59, vhf 118–141, uhf 225–391.7) — they bound the plan's bands, not any radio set.
- **`tools/foothold/presets.yaml` loses its legacy override layer**, eleven aircraft entries and the collections behind them. Its own comment had told the reader to delete each type "as soon as it appears in `dcs-radio-specs.yaml`" — an instruction describing a future that could not arrive. `F-14BU` came off too: it has real radios since the datamine pin bump of 2026-08-08. Verified on a real mission rather than in a unit test: the FC3 types still get their plate, and no FC3 slot carries a `Radio` table.

### Changed
- **Inside a group, a command drops the group's own word**: `veaf-tools convert v5` and `veaf-tools convert other`, not `convert convert-v5` (`REFACTOR-CLI-COMMAND-TREE`, follow-up). Only those two stutter in the whole tree. **Free of charge**, and that is why it is done now rather than filed: the published version is 6.13.0, the tree has never shipped, so nobody has ever been able to type the stuttering form — while the flat `convert-v5` stays registered at the root as a hidden alias and keeps working. After a release this would have been a breaking rename. Not the one-line change it looked like: the wizard looks commands up by their canonical name, so the CLI↔TUI bridge maps the short token back — and `convert other` has **two required arguments**, which is exactly when a user needs that bridge rather than Typer's help screen. 22 documentation occurrences shortened in both languages.
- **Adding a field to `MissionBuilderWorker` no longer breaks fifteen test files** (`REFACTOR-WORKER-TEST-FACTORY`). Its `__init__` reads `mission.yaml`, resolves the scripts path and checks the loader exists on disk, so 14 test files skipped it with `object.__new__` — 20 sites — and each set a *different subset* of the 28 fields by hand. Every one of those shells is a partial copy of the field list, so a new field broke an unpredictable set of them with an `AttributeError` naming a field the failing test had never heard of. It happened twice on 2026-08-10 (`collected_community_sound_files`, then `_dcs_bridge_temp_file` — 15 files, two of them fixtures *inside* test classes that a grep over module-level helpers missed). One `make_worker(**overrides)` in `test/python/testlib/` now defaults every field, and a contract test reads the `self.<field>` assignments out of `__init__` with `ast` and **fails naming the field and the file to fix** — verified by injecting a field and watching it fail, so the next one costs one edit instead of fifteen. Test-side only: no production code was touched.

### Fixed
- **239 links sent English readers to French pages** (`SECREV-2` ticket 07, finding VMR-008). The review reported one page; measuring the tree found **239 links across 38 `.en.md` pages** pointing at the French version of a page that has an English one. All rewritten. The reason so many piled up is worth more than the fix: `docs-check` already knew about the case — it *followed the twin* to check anchors on the page the reader would land on — and so compensated for the mistake in silence instead of reporting it. It now reports it, verified by reintroducing a bad link and watching the gate fail. A checker that quietly works around a defect is worse than one that ignores it.
- **The auto-downloaded `dcs-bridge.lua` left a temp file behind on every build** (`SECREV-2` ticket 07, finding VMR-049). `NamedTemporaryFile(delete=False)` with nothing to remove it. The trap is that the caller cannot delete whatever it is handed: the same argument also carries a `lua_path` the mission maker supplied, and deleting that would be data loss. The worker now remembers which file **it** created.
- **`convert-other` still advertised conversion profiles as "coming next"** (`SECREV-2` ticket 07, finding VMR-007) while `foothold` and `foothold-ww2` have shipped for months — in both languages. Nearly missed because `grep "coming next"` found nothing on the English page: the phrase is split across two lines.

### Changed
- **The 25 CLI commands are filed by theme** (`REFACTOR-CLI-COMMAND-TREE`). `veaf-tools --help` listed 25 flat entries and the wizard grouped them four ways — a grouping that did not survive measurement: `config` held **10 of 21** and mixed starting a mission, converting one, configuring it, and `about`/`ask`, while the split was by *verb*, so `inject-waypoints` and `extract-waypoints` — the two halves of one job — sat in different menus. Both interfaces now read one tree: `mission` / `convert` / `content` / `cockpit` / `dcs`, plus four commands about the tool itself at the root. `dcs` earns its own group because *needs DCS running* is a constraint you must know **before** choosing, not a theme. **Nothing breaks**: every flat name stays registered as a hidden alias, so `veaf-tools build` does exactly what `veaf-tools mission build` does and every existing script, forum post and doc page keeps working — deprecated, droppable at a v7. The wizard shows five headings instead of four, its largest holds 6 of 21 instead of 10, and the `extract`/`inject` pairs are adjacent; asserted by tests rather than eyeballed, since the reduction *is* the deliverable. 193 invocations across 44 documentation pages were rewritten to the grouped form in both languages.
- **A command can no longer ship unplaced or undocumented.** One test fails when a registered command is absent from the tree (it would vanish from `--help`) or when the tree names one that no longer exists; a new `docs-check` coverage rule requires every command **and group name** to be mentioned by the CLI reference. That rule immediately found **16 of 30** missing from the guide's command table — `resolve-checklist`, `verify-checklist`, `smoke-test`, `capture-map`, `inject-bridge`, `mcp`, `ask`, `about` and more — now filled in from each command's own help text, in both languages.

### Fixed
- **A v5 `presets.yaml` survived `convert-v5` untouched, then killed the build** (`FIX-CONVERT-V5-PRESETS-SCHEMA` ticket 02). `convert-v5` declares `src/presets.yaml` as the file it *writes*, so one already sitting there was left alone — right for a v6 file, wrong for a v5 one that shares the name and the file format while its **schema** is the one thing that changed. Detection is now by **structure**, never by file name: a name says nothing about content, which is exactly how this passed for converted. The file is rewritten in place, the original kept in `backup_v5/`, and the conversion report says so. Six differences were mapped by walking a real v5 file against the shipped v6 default rather than from memory: the section rename, the collection level v5 did not have, radios lifted out into `radios_collection` and referenced by name, `channel_01` → `1`, a channel's `name` → `title`, and the extra `coalitions:` level. Nothing is invented — v6 accepts `{freq, title, mod}`, so the frequencies carry over verbatim. The one exception is a radio's `type:`, which v6 makes mandatory and v5 never wrote: it is inferred from the frequencies, and a radio straddling two bands **says so** instead of choosing in silence. Reading the code had suggested `type` was unnecessary; the acceptance test — the repository's own demo mission migrated and then read by the real `PresetsManager` — refused that immediately.

### Fixed
- **Saving a mission in the DCS editor deleted its CTLD and CSAR sounds** (`FIX-COMMUNITY-SOUNDS-PRUNED` ticket 01). Measured by diffing the archives before and after an editor save: `CSAR.ogg`, `beacon.ogg`, `beaconsilent.ogg` and `csar-beacon.ogg` gone. None of them was in `mapResource`, so the editor pruned them as orphans — reasonable on its part, since CTLD and CSAR ask for them **by filename at runtime** from a script it never reads. A mission maker who opened their mission to nudge one group lost the audio, with nothing said on either side. The build now emits a *Declare mission sounds* trigger playing each sound to a country **no coalition uses** — the trick the v5 missions already carried — so the files become resources the editor keeps. The country is picked from the **top** of the DCS table (92 New Zealand and down) rather than the bottom, because the low ids are the countries missions actually use: handing out `3` would be handing out **Turkey** on a Syria map. The gap was deliberate — `BUILD-COMMUNITY-SOUNDS-001` scoped itself *"files-only — no mapResource entry, no out_sound trigger"* and the sequel lived only in a code comment; the build had learned to **remove** the legacy trigger and never to create it.
- **The rule is about orphans, not about CTLD.** The first implementation keyed on the tool-injected sound set and still left the reported bug in place: the sounds that were measured came from the mission's **own** `src/mission/l10n/DEFAULT/` with both modules *disabled*. Every `.ogg` the mission carries and nothing else declares is now declared, whatever put it there; one already referenced by its own trigger (a briefing clip) is left alone. `veafDynamicConfig.lua` is deliberately **not** declared (ticket 02): dynamic mode reads it off disk and static mode does not load it at all, so the editor pruning that copy costs nothing and declaring it would assert a dependency that does not exist.

### Changed
- **One `/login` no longer unlocks every secured command for everybody** (`REVIEW-SECURITY-LAYER` ticket 01). `veafSecurity.authenticated` was a single boolean tested first in every check, so one pilot authenticating opened the whole mission to the whole server — and, because that test came first, it *disabled* the per-pilot mechanism (`veaf-pilots.txt`) exactly while someone was logged in: the blunt instrument switched off the precise one. **Changes existing missions**, and the shape of the change is dictated by DCS: `missionCommands` posts to all, to a coalition or to a **group**, and hands the callback only the argument fixed at registration — so an F10 menu can never know *which* occupant clicked. The group is therefore the finest identity available on that channel, and a group acts at the **lowest** level among its occupants. Taking the highest would have rebuilt the very defect being removed, one player acting with another's rights, merely at group scale. A secured command may consequently no longer be posted for a coalition, and one posted without a group is refused rather than waved through. The marker channel keeps a finer grain, since it carries an author.
- **The security tiers are renamed to say what they mean**: `OPEN` / `KNOWN_PILOT` / `SENIOR_PILOT` / `ADMIN` (`REVIEW-SECURITY-LAYER` ticket 02). The old `L9`/`L1`/`L0` read backwards — `L0` was the *tightest* — and the guide claimed the opposite until 2026-08-06, which is how a change came within one line of locking a deliberately public command to administrators. **The values are unchanged** (1, 10, 90), so no mission changes behaviour; `L0`/`L1`/`L9` remain as deprecated aliases for one release. Both guide pages are rewritten, and the warning admonition they carried is gone because the trap it described is.
- **A pilot can hand their own level to their group for two minutes** (`REVIEW-SECURITY-LAYER` ticket 01, David's design). The minimum-of-the-group rule has a cost: an admin sharing a four-slot group loses their admin commands in the menu. The hatch is `_auth elevate` on a marker, or `elevate` over chat — **both channels carry an author, the F10 menu does not, which is exactly why it is not offered there**. The elevation is capped at the requester's *own* level, so nobody can borrow a rank they do not hold, and it expires after 120 seconds. The residual effect is deliberate and worth stating: during those two minutes the group's other occupants act at that level too — the old global `/login`, reduced to one group, time-boxed, and attributable to a named pilot.

### Changed
- **`test/lua/` is under the StyLua gate**, the pendant of what `CHORE-TOOLING-GATES` ticket 03 did for ruff on `test/python/`. Its 36 files had been formatted by nothing. Honest about how it came about: they were reformatted **by accident** in #678, by a whole-tree `stylua` run meant for the two files being changed — 77 000 lines of diff around two real fixes, and exactly the trap this repository already documents. The repair is the gate rather than a revert: reverting means a second massive commit for nothing, and restores files to a state nothing maintains. The formatting was wanted; the timing was wrong. `src/scripts/other/` stays out on purpose — those files come from elsewhere and reformatting them would fight their upstream.

### Fixed
- **The AJS-37's E and F preset channels never reached a mission** (`FIX-RADIO-LAYOUT-GAPS` ticket 02). ADR 0012 gives the Viggen seven specials at slots 41–47; two of them, FR24 **E (33 MHz)** and **F (34 MHz)**, were stripped from every build since July by `_drop_out_of_range_channels`, because `dcs-radio-specs.yaml` describes the airframe as a single 103–400 MHz set. **Measured in DCS rather than argued**: a mission carrying 30/31/32/33/34 MHz on an AJS-37 loads in the Mission Editor, saves, and comes back with every value unchanged — so the datamine simply does not model the FM band, and the guard has been deleting legal channels. The band is now declared as a second *range on the same radio*, not as a second radio: DCS keeps the whole Viggen fit in **one** 47-slot table, and modelling it as a radio made the build warn on every run that the layout and the specs disagreed. Bounds are what was measured (30–34 MHz, the values a real Viggen mission uses); the set's true ceiling was not probed, so widen it against evidence only.
- **Hand-written radio-spec corrections no longer die at the next regeneration.** They move to `dcs-radio-specs-overrides.yaml`, which the generator merges in — replacing a manual checklist step nobody was going to remember. The first run of the strict merge caught what that step had already lost: the `MiG-15bis` and `MiG-15bis_FC` entries are **ours end to end** (the datamine models no radio for them) and the drift workflow only ever said to re-apply the `dcs_rejects_on_load` flags, so a regeneration would have deleted both airframes in silence. An override naming an aircraft or a radio that does not exist is now an error rather than a no-op, because an overlay that quietly stops applying is worse than none. The **doc page stays hybrid** — the generator writes the French page in English — and the drift workflow now says so plainly instead of implying the whole artifact is automatic.
- **`veaf.split` raised on a percent-sign separator, and coordinates never pretty-printed** (`SECREV-2` ticket 07, findings VMR-082 and VMR-084, both in `veaf.lua`). `split` and `breakString` interpolated the separator straight into a character class, so a Lua-magic separator changed what the class meant. Measured rather than assumed: `-` and `]` happen to survive, `%` raises *malformed pattern* outright — and every separator used inside this repository is a comma, a space or a semicolon, so nothing was broken today. Fixed anyway, because both are public API a mission can call with anything. Separately, `veaf.p`'s vec3 and vec2 branches tested `#o == 3` and `#o == 2`; `#` measures a table's **sequence** part, and a coordinate holds only the named keys `x`/`y`/`z`, so `#o` is 0. Both branches were dead, and every coordinate had been falling through to the multi-line generic dump instead of reading as `{x=…, z=…, y=…}` on one line.
- **Every copy of a missile-guardian silently lost its protected units** (`SECREV-2` ticket 07, finding VMR-091). `VeafMG_Guardian:copy` iterated `self.protectedUnits` and wrote each entry into `copy.protectedZone` — and the block immediately below then reassigned `copy.protectedZone = {}`, wiping the misplaced entries. So `protectedZone` ended up looking perfectly correct while `protectedUnits` came back **empty**, which is exactly why nobody noticed: the visible half was right. Classed *low* by the review; it drops data on every copy.
- **A mistyped zone name crashed the training-zone command** (`SECREV-2` ticket 07, finding VMR-074). `activateZone` and `deactivateZone` both looked up `zones[zoneName:lower()]` and indexed the result on the very next line, so an unknown zone — or the right zone in a case the table does not hold, which is why the lookup lowercases in the first place — raised instead of being refused. Both are guarded now, with an error naming the zone.
- **A build-time weather variant crashed the time parser** (`SECREV-2` ticket 06, finding VMR-015 🟡). The Lua-to-YAML converter emitted `versions[].time` as a **number**, and its consumer `TimeExpressionParser.parse` begins with `expression.strip()` — so a converted mission raised `AttributeError` instead of setting a time. The shipped `versions.yaml` confirms the intended shape is a string (`"sunrise"`, `"08:30"`), so seconds since midnight become `HH:MM`. Guarded with `is not None` rather than truthiness, because **midnight is 0** and a plain `if time:` would drop it in silence — the same class of defect one line further on. One of the five tests feeds the emitted value straight back into the consumer, which is the assertion that actually matters.
- **Carrier tanker setup dereferenced data it knew could be absent** (`SECREV-2` ticket 06, finding VMR-018 🟡). `carrier.tankerData` is read twice inside the tanker block — for the TACAN task and the radio frequency — while a guard a hundred lines below (`if carrier.tankerData then`) proves the code already knows it can be missing. Added to the block's entry condition rather than as two inner guards: with no tanker data there is nothing that block can usefully set up.
- **A dynamic slot with no resolvable group crashed the birth handler** (`SECREV-2` ticket 06, finding VMR-023 🟡). Both `groupId` resolution paths can come back empty, and the value then reached `veafRadio.humanGroups[groupId] = {}` — assigning at a nil index raises *table index is nil* in Lua. The unit is now skipped with a warning, since without a group there is no per-group radio menu to build for it.
- **Documentation that was wrong rather than merely stale** (`SECREV-2` ticket 06, group C). The developer guide's counters are **removed rather than corrected**: it claimed 31 test suites and 34 files, the review said 34 and 41, and today it is 36 and 42 — a number wrong three times will be wrong again, and a directory tree does not need to count itself. Five French table-of-contents links pointed at slugs derived from French headings while those headings carry explicit English anchors, so an explicit anchor won and all five were dead. The migration guide promised a Klogg profile as "planned" when `tools/klogg/veaf.conf` has been shipping. The shortcuts page named the config field `enable` while its own two examples — and the shipped `mission.yaml` — say `enabled`. And the weather page was poorer in French than in English, the project's *default* language: a flat paragraph where English split two roles, and a bullet list where English had a table carrying an "available to" column French readers never got.
- **One match manager of the wrong coalition hid a joining player from all the others** (`SECREV-2` ticket 06, finding VMR-017 🟡). `DcssbMatchManager.onEvent` looped over every known match manager and used `return` on a coalition mismatch — which leaves the **whole function**, not the iteration. So the first manager belonging to the other side ended the loop, and every manager after it never saw the player at all. Lua 5.1 has no `continue`, so the test became a flag guarding the body. Noted rather than silently changed: the trigger-zone branch a few lines below has the same `return` with the same reach, but VMR-017 reports the coalition test only and "a player joins one match at a time" may well be intended there — it now carries a comment asking for a decision instead of a quiet edit.
- **The point-defence lookup could never fail, so it never found the right radar** (`SECREV-2` ticket 06, finding VMR-024 🟡). `iads:getEarlyWarningRadars(defended_name)` looks like a lookup by name and is not: checked against Skynet's own source, `getEarlyWarningRadars()` takes **no argument** and returns *every* EWR as a table delegator. The name was therefore ignored, the result was always truthy, and `defended_site` became the whole collection rather than the radar asked for. Switched to `getEarlyWarningRadarByUnitName`, which matches on `getDCSName()` exactly as `getSAMSiteByGroupName` does for SAM sites. Skynet's naming asymmetry is genuine — a SAM site's DCS name is its *group*, an EWR's is its *unit* — so a lookup naming a group whose radar unit differs will now correctly find nothing instead of incorrectly finding everything.
- **A FARP declared red in text was built blue** (`SECREV-2` ticket 06, finding VMR-022 🟡). The coalition normalisation read `if type(farpCoalition == "number") then` — the closing parenthesis one place too early, so it evaluated `type(boolean)`, which is the string `"boolean"` and always truthy. Both guards therefore always ran, and that is not merely dead code: with both executing in order, a coalition arriving as the **string** `"red"` failed the `== 1` test in the first block, fell into its `else`, and came out **blue**. The FARP was built for the wrong side. Extracted into `veafGrass._normalizeFarpCoalition` so the behaviour is testable rather than buried in a 200-line builder, with the name and the number now guaranteed to agree — returning an unrecognised name beside the blue number would hand DCS a coalition it does not know, a worse failure than the one being fixed.
- **`setAllElementsSkill` crashed on its first call** (`SECREV-2` ticket 06, finding VMR-020 🟡). `for _, element in self.elements do` asks Lua to call the table as an iterator. The two sibling loops in the same file both write `pairs(self.elements)`, so this was a slip rather than a convention — and nothing in the repository calls the method, which is exactly why it survived long enough to be found by a review instead of by a mission.
- **Activating a combat mission crashed when a teleport returned nothing** (`SECREV-2` ticket 06, finding VMR-021 🟡). `_group.groupName = spawnedGroupName` sat **between two `if _group then` guards** while being unguarded itself, so a nil return from `mist.teleportToPoint` took the activation down immediately after the code had finished checking for precisely that. The guards are merged rather than a third one added: the assignment belongs with the work it labels.
- **A non-numeric spawn parameter aborted the spawn with a runtime error** (`SECREV-2` ticket 06, finding VMR-025 🟡). `multiplier banana` set `options.multiplier = nil`, and the spawn then died downstream on `for i = 1, options.multiplier do`. A *valueless* `multiplier` was worse still: the conversion itself raised, reaching `string.find(nil, "%-")` after `tonumber` returned nil — so the error came from inside the number parser rather than from the spawn. Fixed in the parser's shared `_num` applier rather than on `multiplier`, because **every** numeric spawn keyword goes through it: an unusable value now leaves the existing default in place instead of erasing it.
- **A mistyped marker parameter killed the whole command instead of being ignored** (`SECREV-2` ticket 06, finding VMR-019 🟡). `_cas, size` with no value reached `string.format("Keyword size = %d", nil)` and then `tonumber(nil) <= 5` — either one raises, and the marker handler dies with it, so one typo lost the entire command rather than one parameter. The same two crash sites existed four times over, for `size`, `defense`, `armor` and `spacing`. The review recommended fixing this "in the shared marker parser", and **there is no such thing**: ten modules carry their own `markTextAnalysis`, and unifying them is a different lot entirely. What *can* be shared is the conversion — the part that was being written wrong each time — so `veaf.safeNumber` joins the existing `veaf.safe*` family, with 13 tests of its own. Out-of-range values remain **ignored rather than clamped**: that is the current behaviour, and changing it is not this fix's business.
- **The documented DCS coalition IDs were inverted, in both languages** (`SECREV-2` ticket 06, finding VMR-014 🟡). `LUA_API_REFERENCE` said `1=blue, 2=red`; DCS defines `coalition.side = { NEUTRAL = 0, RED = 1, BLUE = 2 }`. This is a correctness defect wearing documentation's clothes: nothing catches it, because code written from the wrong mapping compiles, runs, and quietly targets **the other side**. Verified against the mocks and `veaf.lua` rather than taken on trust — the repository's own Lua never used the wrong values, so the blast radius was those two pages and nothing else. Both now carry a danger admonition with the real table, so the next reader is warned rather than merely corrected.
- **Every sub-zero temperature in a METAR was silently discarded** (`SECREV-2` ticket 06, finding VMR-016 🟡). A METAR spells a negative temperature with an `M` prefix — `M05/M10` is -5 °C — and the fallback parser tested `part.lstrip("-").isdigit()`, so `M05` failed the test and the **configured default survived in its place**. Winter and high-altitude missions are precisely where this matters, and precisely where nobody would think to check that the temperature they set had survived. The telling part: an existing test, `test_temperature_negative_M_prefix_not_parsed`, was **pinning the defect as intended behaviour** — its own comment spelled out the mechanism (`"M05".lstrip("-")` is not a digit string) as though that were the design. It asserts -5.0 now. 9 new tests, half of them guarding that positive temperatures still parse.
- **A radio-compass was being handed a 30-channel radio list** (`FIX-RADIO-LAYOUT-GAPS` ticket 01). The default role classification called anything that never reaches above the FM ceiling an FM radio — right for an FM set, wrong for an ADF. The Ka-50's `ARK-22`, the MiG-29's `ARK-19` and the Yak-52's `ARK-15M` sit entirely below 2 MHz, so a full channel list was projected onto a radio-compass: every channel then reported out of range and dropped, while the kneeboard advertised a radio the aircraft does not have. A radio whose every range falls below a new 2 MHz comm floor is now classified `non_comm` and gets **no role at all**. The change is one branch, because the role groups filter on `band is None` and `"non_comm"` is not `None` — these radios fall out of every group by construction rather than through a second exclusion rule. Fixed in the classification rather than with four per-type layout entries on purpose: an airframe added by a future DCS patch with an ADF would hit it again. 9 tests, two of which exist to bound the blast radius — a genuine FM supplement must keep its role, and a V/UHF radio must be untouched.
- **Enabling the DCS bridge silently broke every trigger the mission already had** (`SECREV-2` ticket 05, finding VMR-005 🟠). `inject_dcs_bridge_trigger` made room at index 1 by shifting each `trig` category up, but did not rewrite the **Lua text** of what it shifted — and those strings carry their own indices: `if mission.trig.conditions[1]() then mission.trig.actions[1]() end`. A trigger moved from key 1 to key 2 therefore kept calling `conditions[1]`, which by then was the bridge's, so every previously inserted trigger fired the wrong pair. `insert_veaf_triggers` already did this correctly, so the fix is the substitution that existed rather than new logic, applied **per entry with that entry's own key** — a blanket pass over the category would corrupt its neighbour. Why it survived: a mission with **no** prior trigger is unaffected, and the shipped default has none, so the common path never showed it. The test was written first and confirmed failing on the real defect, including a three-trigger case, which is where a colliding rewrite would surface.
- **A mission asking for live weather got invented weather, and nothing said so** (`SECREV-2` ticket 05, finding VMR-006 🟠). `_fetch_live_metar` did `Metar(airport_icao)` and read `.temperature`, `.wind_speed` and the rest straight off it. In avwx the constructor does not fetch — `.update()` does — so every attribute was `None`, the function returned its canned defaults, and the log said *"Successfully fetched METAR"*. Checking `update()`'s **return value** matters as much as calling it: avwx reports a failed fetch by returning `False` rather than raising, so calling it and ignoring the result would have reinstated the identical silence. Both failure paths now announce themselves at warning level, naming the ICAO — falling back quietly is what hid this for a month. 7 tests against a faked avwx that, like the real one, only populates its attributes inside `update()`, so they fail structurally without the fix rather than by coincidence.

### Security
- **The updater verified nothing whenever its metadata was absent, and said it was verifying** (`SECREV-2` ticket 04, finding VMR-011 🟡). An attacker able to influence release metadata never had to defeat the checksum — **removing** it was enough. The finding described two fall-through paths; there were **four**: no metadata asset, an undownloadable one, unparseable JSON, and a present-but-checksum-less JSON. Each logged a warning and installed anyway. All four refuse now. The mechanism behind the bug is worth recording because it will recur: in this codebase `logger.error` **raises `typer.Abort`** rather than logging a line, so the original author reached for `logger.warning` to avoid stopping the run — and got fail-open as the side effect. The verification is extracted into `_checksum_verified` so each path is unit-testable without driving the whole download flow, and every refusal names the escape hatch (`--no-verify-checksum`), which already existed: this code updates a mission maker's tooling, so a refusal that strands them with no way forward would be its own defect. 12 tests, including that a *good* release still installs.
- **The publish side had to be hardened in the same breath, and that is the part that nearly got missed.** A fail-closed updater turns any silent gap in release publishing into a release nobody can install — discovered by a user, not by us. `veaf-build` does produce `published-metadata.json` carrying `published_zip_sha256`, the exact asset name and key the updater looks for (verified rather than assumed), but it had **two silent failure paths**: `worker.py` warned and carried on when the file could not be written, and `github.py` skipped the upload entirely if the file was absent *and* ignored the upload command's return code, unlike the main asset upload right above it. Both are errors now.
- **A `.miz` could exhaust memory before touching the disk** (`SECREV-2` ticket 04, finding VMR-009 🟡). `read_miz` pulls `mission`, `options`, `warehouses`, `theatre` and the l10n files straight into memory with a bare `.read()`, with no cap at all — a small archive declaring a huge member is a zip bomb that never reaches the file system. The ticket asked whether this was new code or a matter of routing through the existing `safe_zip.py`; the answer, recorded because the question was fair, is **new code**: `miz_tools` already imports `safe_extract_all`, but that guards *extraction to disk* and this path deliberately never writes a file, so no on-disk cap can bound it. `safe_read_member` checks the declared size first (cheap, refuses before allocating) and counts the real stream while reading (what actually holds, since the declared size comes from the archive). Understating the size to slip past the first check does not help: `zipfile` itself then rejects the CRC, so the test asserts *that the read is refused* rather than which layer refuses it — pinning `ValueError` there would pin an implementation detail of CPython.
- **All 14 open Dependabot alerts closed, and 11 of them were never a production risk** — worth recording, because the severity badge said otherwise. Three are real and fixed by a lock bump: `pymdown-extensions` 10.21.3 → **11.0.1** (one high, one medium) and `setuptools` 82.0.1 → **83.0.0** (medium). Both are transitive — `pymdown-extensions` comes from `mkdocs-material`, whose `>=9.5,<10` constraint turned out to accept the 11.x major, so nothing had to be relaxed. The major bump was checked rather than assumed: `mkdocs build --strict` aborts on 4 warnings, and **the same 4 warnings still trigger an abort without the bump** (links from `doc/` pages out to `docs/exploration/`, `.backlog/` and `tools/`), so they are pre-existing and unrelated; the docs workflow does not use `--strict` in any case. Diagnosing that needed a detour — the local `mkdocs-material` install was amputated, `material/plugins` enumerated as **empty**, which produced a `ModuleNotFoundError` that looked exactly like breakage from the bump and was an install artifact.
- The other **11** (`sharp` and `ws` at *high*, `undici` ×8, `esbuild`) are all in `poc/doc-chatbot/worker`, and every one of them is `dev: true` in the lock file, pulled by **`wrangler`** — the worker's *only* dependency, and a development one. Cloudflare runs the bundle, not `node_modules`, so none of that code has ever been deployed. Fixed anyway by taking `wrangler` from `^3.90.0` to `^4.120.0`, after which `npm audit` reports **0 vulnerabilities**. A major bump of the deploy tool is exactly where a chatbot outage would come from, so it was verified: the 11 worker tests pass, `wrangler deploy --dry-run` accepts the existing `wrangler.toml` and resolves the `CHAT_KV` binding, and `wrangler kv key put` — the form the `docs-chatbot-index` workflow calls — still exists in v4.

### Changed
- **The ruff gate now covers the whole Python tree, and the trigger paths with it** (`CHORE-TOOLING-GATES` ticket 03). `test/python/` — 180 files — was linted by **nothing**: the CI ran `ruff check src/python/veaf-tools` and `CLAUDE.md` documented the same narrower scope, so the omission was consistent and therefore invisible. It had already cost two clean-ups, where a `ruff --fix` run in passing silently rewrote test files unrelated to the work in hand. The drift measured today was **12 findings**, not the 9 recorded when the ticket was written — the ticket's own argument, that this only gets more expensive, demonstrated on itself. All `I001`, all auto-fixed, plus 2 formatting diffs. `veaf_build/` is included too and it was free: its 20 files already passed both checks. **The part that mattered most is the least visible**: `python-quality.yml` only triggered on `src/python/**` and `pyproject.toml`, so widening the gate alone would have been a no-op — a change confined to `test/python/` would never have run the job that now lints it. `CLAUDE.md` is updated in both places, and spells out that ruff covers the whole tree while mypy stays on the shipped package, since tests use loose typing deliberately.
- **Both PyInstaller `.spec` files deleted — they had become misinformation** (`CHORE-TOOLING-GATES` ticket 02). `veaf-tools.spec` declared four bundled-data entries including the conversion profiles; the build never read it, passing its own `--add-data` list from `_veaf_tools_extra_data` instead, which assembles a dozen. So the two had **silently diverged in both directions**, and that is what made a real bug hard to find: the profiles were missing from the shipped executable (`unknown conversion profile: foothold`) and the obvious place to check said they were bundled. Deletion was chosen over generating or building from the spec because the data list is *computed* — paths conditional on `exists()`, two of them generated JSON files passed in as arguments — which a static spec cannot express, and that is why the code path won originally. Verified nothing invoked them first: no workflow, no live documentation, no release skill, the only surviving mentions being in a dated historical plan. `_veaf_tools_extra_data`'s docstring now says in its first line that it is the single source of truth, so a developer asking "what data ships in the exe?" finds exactly one answer instead of two with the wrong one more prominent.
- **`.claude/memory/` is now git-ignored.** It is a junction into a personal central configuration repository, not project content, and it was untracked but *not* ignored — so a `git add -A` in any future session would have published personal notes into a public repository.
- **Two decisions closed, and one of them corrected the ticket that asked it** (`TOOLING-REPO-LINK-GATE` ticket 04, `FIX-ATIS-NIL-MESSAGE`). The eleven broken links in dated documents are **exempt, not repaired**: repairing the links of a document that records a past state would rewrite it into a state that never existed, which is worse than a link that does not resolve. The exemption set was already in place as a placeholder; it is now a recorded decision, and each entry keeps its own reason so a later reader can tell a deliberate exemption from neglect. The ticket also proposed deleting `CODE_DOC_REVIEW_2026-07-01.md` on the grounds that "its findings were all actioned" — **that was wrong**, and checking rather than trusting it is what caught it: `SECREV-2`'s PRD sources its tickets from that file and tickets 04 to 07 are still open. It is live work, so the delete-or-archive question reopens when `SECREV-2` closes and not before. `FIX-ATIS-NIL-MESSAGE` is promoted to ✅, having shipped in #667 and sat at 🔄 since; `TOOLING-REPO-LINK-GATE` closes with all five tickets done.

### Added
- **Three aircraft the DCS data had been missing for three weeks — F-100D, F-14A-95-GR and F-14BU** (datamine pin `dc7d15e8` → `d75d7ac5`). The units database, the Lua unit table and the radio specs all gained them; nothing else in the data changed. The interesting part is **why the gap lasted**: the weekly `DCS Data Drift Watcher` had already caught the drift and opened PR #617 on 2026-07-20, but that PR targeted `master` — the repository's default branch at the time — where it was unmergeable, exactly like Dependabot's sixteen. It was closed on the assumption the robot would reopen one against `develop` at its next run. It never did, and the cause was the branch it had left behind: the workflow always pushes to the fixed branch name `chore/datamine-pin-bump`, so the following Monday it found that branch already holding precisely the commit it wanted to make, had nothing to push, and therefore opened no pull request. **A robot with nothing to say is indistinguishable from a robot that has been silenced**, which is why three weeks passed without anyone noticing. Deleting the stale branch and dispatching the workflow by hand reopened it immediately, against `develop` this time.
- The radio specs were **merged rather than regenerated**, deliberately. `update-dcs-data --radio` overwrites a hybrid artifact: it drops the entries the datamine does not carry (`MiG-15bis`, `MiG-15bis_FC`), discards the `dcs_rejects_on_load` overlays, and replaces the hand-written French page with the generated English one. To separate the bump's real effect from that collateral, the specs were generated **at both pins into temporary directories, writing nothing to the repository**, and compared: 85 → 88 entries, three added, **none removed and none modified**. Only those three keys were then merged into the shipped YAML and into both documentation pages, so the whole change is insertions — 64 lines of data, 9 lines per page, zero deletions. None of the three restricts its primary frequency (each `human_radio` spans exactly its preset ranges), so the primary-frequency table is untouched.

### Fixed
- **A pilot asking for ATIS at a vanished airbase crashed the display instead of being told anything** (FIX-ATIS-NIL-MESSAGE, **credit MacFlorent**, PR #303). Issue #302 reported `getNearestAirbaseList` raising *Object doesn't exist* on a stale airbase — a sunk carrier, a despawned base, a persistence reload — and that was fixed in `19cec379`. But the guard went where the value is *computed*, so `veafWeatherAtis.getAtisString` now correctly returns `nil` and `veafWeather.messageAtcClosestAirbase` handed that `nil` straight to `veaf.outTextForUnit`, which forwarded it to `trigger.action.outTextForUnit` unchecked. **The same crash, one level later** — and it reads in `dcs.log` as a weather bug rather than as "somebody passed nothing". MacFlorent's PR had proposed exactly this fix six months earlier and was never reviewed; it is closed as superseded, and this is the half of it nobody picked up. His version hardcoded the English sentence, so the message goes through `veaf.t` here (`weather.atis_unavailable`, both languages). Fixed at **two** levels deliberately: the ATIS path now says "no ATIS available for *<airbase>*", and `veaf.outTextForUnit` **refuses a nil or blank message** rather than forwarding it — a floor under dozens of callers, because guarding them one at a time leaves the trap armed everywhere else. It logs rather than swallowing: a caller with nothing to say has a defect, and silence is worse than a crash for whoever has to diagnose it. This path had **no test coverage at all**, which is how the gap survived a guard being added right next to it; it now has nine tests, including that a message of `"0"` still counts as something to say.

### Security
- **Pillow to 12.3.0 and cryptography to 50.0.0, closing ~20 open advisories** — done by hand on `develop` rather than by merging Dependabot's pull requests, because those cannot land. **Every one of Dependabot's 16 open PRs targets `master`**: it opens them against the repository's *default* branch, and this repo's default is the release branch. They are all `BLOCKED` (`master` requires a review) and none has reached `develop` since 2026-07-18. Merging them there would have been wrong even if possible — the gitflow routes everything through `develop`, and a lock file bumped on `master` alone leaves `develop` older, so the next release merge either conflicts or **silently reverts the fix**, closing the alert on GitHub while the vulnerability returns to the product. What actually blocked the Pillow fix was our own constraint, `Pillow = ">=10.0,<12"`, added by a general cleanup commit in May with no recorded incompatibility: 14 advisories name **12.3.0** as the patched version, and 7 of them cite `pyproject.toml` rather than the lock, so the floor had to move too — hence `>=12.3,<13`. `cryptography` is transitive (`mcp` → `pyjwt[crypto]` → `cryptography`) and `pyjwt` asks for `>=3.4.0` with no upper bound, so 50.0.0 needed nothing but an explicit `poetry update`. The image code is genuinely exercised by the checklist and kneeboard tests, which render real images and read their pixels, so the bump is verified rather than assumed — and it surfaced a deprecation those tests were relying on: `Image.getdata()`, removed in Pillow 14, now `get_flattened_data()` at its three call sites.

  Deliberately **not** done: adding `target-branch: develop` to `.github/dependabot.yml`, which looks like the obvious root-cause fix and is a trap — per GitHub's documentation, pointing an ecosystem at a non-default branch **disables Dependabot security updates for it**, so it would have removed exactly the alerting that surfaced this. The real root cause is that the default branch is `master` while development happens on `develop`; that is a repository setting and a decision, not a config tweak.
- **Three marker commands ran for anyone, and only one of them was reported** (SECREV-2 ticket 03, finding VMR-003 🟠). The dispatcher delegated the security decision to each handler, so a handler that simply did not check was wide open and nothing noticed — forgetting failed open. The inventory the ticket demanded found **four** such handlers, not one: `veafGroundAI` (the reported finding), plus `veafMove`, `veafNamedPoints` and the `veafRadio` marker path. `veafRadio` is the instructive one: it *does* contain two `isAuthenticated` calls, so counting references answers "yes, it checks" — both guard the **F10 menu**, and the marker path had nothing. The fix is structural rather than four patches: `veafCommands.registerCommandHandler` now takes a **required** security argument and refuses a missing or unknown one at load time, and the dispatcher enforces it centrally. `veafSpawn.registerCommandHandler` already took a level but documented a *"legacy 2-arg form (key, fn), no security check"* — the escape hatch is gone, and the three commands using it (`smoke`, `flare`, `signal`) now declare `OPEN`, so "deliberately public" is something a command says rather than something it achieves by staying silent. The four newly-gated handlers parse no password, so the check is on **identity** alone — the pilot level the server hook publishes from `veaf-pilots.txt`, which is the mechanism that already existed and that nothing on these paths was calling. **Changes existing missions**: ground AI, move and SRS transmit now need a pilot level or a `/login`. Levels chosen by David — `veafGroundAI` L9, `veafMove` L1, `veafRadio` L1, `veafNamedPoints` OPEN.

- **A player name could execute code on the server, before authentication** (SECREV-2 ticket 02, findings VMR-001 and VMR-002 🔴). The server hook built its injected Lua with `registerUser("%s", …)` and handed it to `a_do_script`, so a name carrying a quote stopped being data: `") PWNED = true; veafRemote.registerUser("` closes the argument, runs a statement and reopens the call, leaving a chunk that compiles. It ran on the **connect** path, which is why no login was needed. Every template now interpolates with **`%q`** — Lua's own quoting — and every call site passes `tostring(value)`, so a number cannot arrive unquoted and a nil cannot crash the hook. That alone was **not enough**, and the measurement is the interesting part: `%q` escapes quotes and backslashes but not `]`, so a name containing `]===]` still closed the long bracket `injectCode` wrapped the payload in, and reached execution through an *expression* rather than a statement (a statement after the chunk's `return` does not compile, which is what made the first attempt look like a harmless syntax error). `injectCode` now quotes the whole payload with `%q` too, removing the bracket problem instead of computing a safe bracket level around it. The hook had **never had a test**; it does now — `test/lua/test_veafServerHook.lua` loads the real file and drives the real DCS callbacks, and 7 of its 9 tests fail without the fix. The deliberate `/code` admin path still executes arbitrary Lua, with a test pinning both that it works at level 90 and that it is refused at 89. **Not yet deployed**: `REFACTOR-SERVER-HOOK-CANONICAL` made the repository copy the deployable source, so this is fixed here and fixed on the VEAF servers only once it is copied there.
- **An F10 map marker could run commands on the server's host machine** (SECREV-2 ticket 02, finding VMR-004 🟠). `veafRadio._transmitViaSRS` formats `start /min "…" -t "%s" … -n "%s"` and passes it to `os.execute`; the message, the station name and the MP3 path come from `markTextAnalysis`, which reads the marker text, and **nothing on that path authenticates**. A double quote ends the argument it sits in and `&` starts a new command. Free-text values are now stripped of the characters that break out — the quote, cmd's separators, redirections, escape character and variable marker, and control characters — while the values with a small legal shape (frequencies, modulations, coalition) are **validated** against an anchored pattern and fall back with a warning, following the review's own advice to validate rather than escape where the shape is known. Escaping was rejected on purpose: cmd's quoting rules do not compose, so a scheme correct at one nesting depth is wrong at the next. The cost is a literal `&` in a spoken message becoming a space. Six new tests, five of which fail without the fix.

### Changed
- **A combat zone's coalition-scoped F10 menu is confirmed working in DCS, and the lot is closed** (FEAT-COMBATZONE-MENU-COALITION). It had been 🧑 waiting-human since July on one question no unit test could answer — the mocks pin *which* API is called, not DCS's reaction: does DCS accept an `addSubMenuForCoalition` **under a global parent**? `veafRadio` inherits the side down a subtree, so a refusal would have meant the feature was built on sand. Answered by the smoke harness inside a running mission: **`created`**. The nesting is legal, and the prepared fallback — scoping the `COMBAT ZONES` parent per coalition too — is not needed and stays on the shelf. Scope of that answer, stated because it is narrower than the headline: it establishes that DCS *accepts* the nesting, not that the menu is *displayed* to blue alone, which is `veafRadio`'s own logic and is what the unit tests already cover.

### Fixed
- **A ground spawn could be placed kilometres from where it was asked for** (FEAT-SCENERY-AWARE-SPAWN, found and fixed the day after it shipped). `Disposition.getSimpleZones` — the undocumented singleton tier 1 of `veaf.findSpawnPoint` calls — **does not bound its answers by the radius it is given**. Measured in a live DCS around one centre in wooded terrain: asked for 800 m it returned points 2035-2258 m out, and asked for 1600 m with a count of **one** it still returned a point 2628 m out, so the overshoot is not the requested count forcing a wider search. Tier 1 took the first candidate that was merely on land, with no distance test at all, and passed `math.max(1852, safeRadius * 5)` as the radius while ignoring the caller's own — tier 2 honoured it, tier 1 did not. So `_spawn group, radius 50` in a forest could move the whole group kilometres away, silently, which is the correctness regression [ADR 0018](docs/adr/0018-undocumented-dcs-api-dependency.md) exists to forbid: this dependency may improve quality and must never change correctness. Now the candidate must be within the caller's `radius` or tier 2 takes over, the singleton is asked for that radius rather than an invented one, and a `radius` of **0** — what `veafSpawn` passes for farp, cargo, teleport, bomb, smoke and friends — skips tier 1 entirely, since "exactly here, the mission maker means it" is not a point to move. Distance is measured **horizontally** on purpose: `placePointOnLand` writes the terrain height into `y`, so measuring in three dimensions would let a hill push a perfectly good candidate out of range. 10 new Lua tests. One **existing** test had to change, and it is the whole story in one line: `test_scenery_aware_point_becomes_the_group_centre` asserted that a candidate 4200 m away became the centre of a group requested within 1000 m — the suite had been pinning the bug.
- **The smoke harness read a crash in the mission environment as a successful answer** (FEAT-DCS-SMOKE-HARNESS ticket 02). Found by running the enriched probe against a live DCS rather than by reading: at the main menu, asking for `env.mission.theatre` came back as the string `:1: attempt to index global 'env' (a nil value)` — HTTP 200, `{result=…}` body — and the probe reported *"mission environment answered"*. ED documents `net.dostring_in(state, string) -> string`, and the hook returns that string verbatim, so **a Lua failure has exactly the shape of a string result** and only its shape can tell them apart. Two consequences, both fixed: the transport now raises on a returned Lua error for any non-hook environment, and `_is_truthy` rejects one — which matters because the `veaf-loaded` check exists to notice an empty environment and would have gone **green on the very reply proving nothing ran**. That is the third truthy-failure in this lot after the sentinel strings and the submenu check returning a constant; the sweep test now covers Lua error text alongside every sentinel. The probe additionally **measures what each Lua type becomes after crossing the transport**, because if the stringification is literal then two of the six shipped checks — one expecting a number, one expecting `True` — can never pass however correct their Lua is. Measured rather than assumed, and pending a run with a mission loaded.
- **The smoke transport destroys booleans and tables, which left the harness's two most important checks unable to answer** (FEAT-DCS-SMOKE-HARNESS ticket 02). Measured across the working route: a Lua string arrives intact, a number arrives **as a string** (`3` → `'3'`), and a boolean or a table arrives as `''` — indistinguishable from each other and from a chunk that returned nothing. So **a check's Lua must return a string, always**, now enforced by a `TRANSPORT_LOSS` sweep over every expectation. Two checks were condemned by it: `disposition-returns-points` expected a number, got `'10'`, and was reported FAIL when its Lua had actually **succeeded** — the expectation was the defect, and it now returns a tagged `count:N` so that `count:0` ("asked, got nothing") stays distinct from `''` ("the answer was destroyed"). Worse, `coalition-scoped-submenu-accepted` returned `''` and so could not tell "DCS refused" from "the reply was lost" — leaving it **inconclusive on the exact question FEAT-COMBATZONE-MENU-COALITION has been waiting on since July**, which is not an improvement on the earlier false pass, only a quieter failure. Its verdict is a word now (`created` / `refused-nil`).
- **`Disposition` exists, and the harness is what proved it** (FEAT-SCENERY-AWARE-SPAWN ticket 01, partly answered). The undocumented DCS singleton that tier 1 of `veaf.findSpawnPoint` depends on — never called by this repository, absent from `dcs-world-schema`, its whole evidence base one unguarded call site in TUM and a Reddit claim — is a real `table`, `getSimpleZones` is a real `function`, and `getSimpleZones({x=0,y=0,z=0}, 1852, 100, 10)` returns a table of **10** entries without raising, matching the `10` passed fourth so the assumed signature holds. Measured by a machine in a live mission, which is what this lot exists for. **It does not establish the claim ADR 0018 rests on**: that the points avoid buildings and forests. Returning 10 points is also what a naive random generator would do, so ADR 0018 keeps saying *asserted, not measured* until the avoidance is observed against a village — recorded in the ticket so nobody reads one as the other. Per-call cost, cross-theatre presence and the empty case also stay open.
- **Also refuted by measurement: `a_do_script` does not return values on this build.** ED's documentation states "there is no need for `net.dostring_in` anymore — you can return values from `a_do_script()` directly"; the call runs and returns nothing, so the obsolete API is the only one that reaches the scripting state. That is the third statement in ED's own shipped documentation corrected by measurement this session, after the `Sim`/`DCS` rename being an alias rather than a migration and the `autoexec.cfg` gate. `SCRIPTING_ROUTES` keeps both routes, ordered by evidence rather than by the documentation's preference.
- **Every smoke check was aimed at the wrong Lua state, and none of them could ever have passed** (FEAT-DCS-SMOKE-HARNESS ticket 02). Found by running the harness in a live mission — `Smerch Hunt II`, pilot in the cockpit — where the mission environment still answered `:1: attempt to index global 'env' (a nil value)`. The intermediate hypothesis was a missing `autoexec.cfg` permission, and the error text refutes it: `attempt to index global 'env'` is a Lua **runtime** error raised *inside* the target state, so the chunk ran. A refusal does not execute your code and then complain about a nil global. The state is reachable and simply has no `env`, because **`env=mission` is the *trigger* state** — where `a_do_script` and the `a_*` actions live — not the scripting state holding `env`, `timer` and the VEAF scripts. Two things in this repository already said so: `FEAT-ASSIST-CHECKLISTS` ticket 01 placed `a_cockpit_highlight` "one `net.dostring_in` away", and the hook's own bootstrap is `net.dostring_in("mission", 'a_do_script("dofile(…)")')` — one line, read while writing the transport, whose meaning was missed. Fixed by measurement rather than assumption: `SCRIPTING_ROUTES` holds the candidate ways in, the probe tries each with `return type(env)` and requires the answer to **be** `table` (a wrong state returns a Lua error, which this transport hands back as an ordinary string, so "something came back" proves nothing), and the runner sends every check through whichever route worked. `a_do_script` is tried first: it is the path ED documents as current — the same paragraph marking `net.dostring_in` obsolete shows `local a, b, c = a_do_script("return 1,2,3")` — and the hook already proves it reaches. Its chunk is quoted with `lua_quoted_string` from `veaf_libs/lua_literals.py`, the helper SECREV-2 built for exactly this.
- **`net.dostring_in` needs no `autoexec.cfg` unlock, contrary to ED's own documentation.** The doc states it is allowed only for the states listed in `net.allow_unsafe_api` / `net.allow_dostring_in`; measured on an install listing neither, it is present and callable from the hook environment. The harness therefore checks for the **function** rather than for the config, and the prerequisite was removed from both language versions of the page — where it had been written on the strength of the documentation alone. Also measured in the same run: `Sim` and `DCS` are literally the **same table**, and `isServer()` is true in single-player, which makes the SERVER-ONLY `net.load_mission` legitimate on a local instance and settles the design question ticket 02 raised.
- **The smoke harness would have blamed a missing mission for a missing permission** (FEAT-DCS-SMOKE-HARNESS ticket 02). Before writing the launch/load/quit slice, ED's own API documentation was read — `<DCS install>/API/Sim_ControlAPI.md`, which **ships with every DCS** and had never been opened here. Three of its statements contradict what the first slice assumed. The control table is documented as **`Sim.*`**, not `DCS.*`: `DCS` still answers, so nothing was broken, but the probe tested `DCS.exitProcess` alone and would have reported a renamed table as *unable to quit*. `net.load_mission` is **SERVER ONLY**, which turns "load the test mission" from an implementation detail into a design decision (single local instance, dedicated server, or command line — filed in the ticket with a recommendation, since a dedicated server has no client slot and could never run the cockpit-side checks). And `net.dostring_in` — **the only transport every assertion uses** — is marked obsolete and permitted only for the states listed in `Config/autoexec.cfg`, which this workstation does not enable: so the six checks may have had no transport at all, and the old probe reported that as `no mission loaded?`, sending the reader to load a mission where loading one cannot help. The diagnosis now orders **root cause before symptom** — no hook, then no permission, then no mission — and `blocking_reason()` names the single thing to fix first. The probe gathers every fact in **one round trip** instead of four half-answers, adding `stopMission`, `setUserCallbacks`, `isServer()` alongside `load_mission` (its presence being necessary and not sufficient), and — asked rather than guessed, because a workstation can carry six `Saved Games` folders — `lfs.writedir()` and `lfs.currentdir()`, so the harness knows which install and which write directory the live instance actually uses. A "could not ask" answer is now `None` rather than `False`: reading a failed `isServer()` call as "not a server" would have retired the local option on no evidence. Documented in both languages, including the `autoexec.cfg` prerequisite — the same unlock refused for distributed missions in `FEAT-SCENERY-AWARE-SPAWN`, acceptable here only because this is a local development tool.
- **`docs-check` reported 392 defects locally and 0 in CI, because it validated files git does not track.** The repo-wide link pass walked `*.md` from the repository root, so it read whatever happened to sit on the workstation: 367 defects from `.claude/worktrees/`, where each agent worktree is a **full checkout of this repository** re-read at a different depth so none of its relative links resolve, and 25 from `test/veaf-tools-updater/`, the updater tests' scratch directory — **ignored at `.gitignore:63`**, which is why a fresh clone has neither and CI stayed green. The first fix named those two paths in a skip list and was too narrow: the next local artefact would have needed a third entry and the list would drift out of step with `.gitignore`. The pass now takes its file list from **`git ls-files`**, falling back to walking the tree when git cannot answer (a release tarball, a vendored copy). That is the right authority as well as the general fix — a link is only broken *for other people* if both ends are committed. It mattered beyond convenience: a gate that only passes on a clean CI checkout cannot be run before pushing, which is exactly the hole #655 shipped its 68 broken links through.
- **Four smoke-harness tests were failing on the workstation that has DCS, and green in CI.** They compare report text literally while `t()` resolves the language from the ambient environment — `VEAF_LANG`, then `~/veafmct.yaml`, then the OS locale — so they asserted English prose and got French. Green where nobody looks, red where the only person who can finish this suite works. The locale is now pinned for that file; asserting on translated prose without saying which translation was the bug.
- **The security-level table in the mission-maker guide said the opposite of what the code does** (SECREV-2 ticket 03). It listed "0 (public) — all players" and "9 (admin) — authenticated admins". The code has `LEVEL_L0 = 90`, `LEVEL_L1 = 10`, `LEVEL_L9 = 1`, and a check passes when the pilot's level is *at least* the constant — so **`L9` is the loosest tier and `L0` the tightest**. Self-consistent if the names are read as password tiers with `L0` the most secret, and the exact reverse of what the page taught. Not theoretical: the levels for ticket 03 were put to David using the page's labels, he picked "L0 — all players" for named points, and writing that literally would have locked a deliberately public command to administrators. Both language versions now describe the real behaviour, with a warning admonition and an explanation of the two ways a check passes (pilot identity from the hook, or the tier's password). Whether the *names* should change is a breaking decision, filed as `REVIEW-SECURITY-LAYER` ticket 02.
- **Generated Lua now comes from one place instead of three disagreeing ones** (SECREV-2 ticket 02, findings VMR-010 and VMR-012 🟡). Three emitters had three ideas about quoting a string: `lua_config_generator._emit_lua_string` was correct, `spawn_data_emitter._lua_string` escaped a backslash and a double quote and stopped — leaving a newline, legal in a YAML unit name and a syntax error inside a Lua `"…"`, to break the generated file — and `_to_lua_scalar`, twenty lines from the correct one in the *same module*, interpolated into `f'"{value}"'` with **no escaping at all**, feeding sixteen call sites that render `mission.yaml` values. New `veaf_libs/lua_literals.py` is the single helper the review asked for. It deliberately keeps **two** forms rather than forcing one: the config generator keeps long strings, because its output is briefings a person reads; the spawn emitter gets an escaped short string, because its output is read back by the bundled `luadata` parser, which was measured and **implements no long-string syntax at all** — the first attempt at one-size-fits-all broke two tests and that is how the difference was found. A leading newline now survives the round trip (Lua eats the one after an opening bracket).
- **The references are now checked against the code, not just for broken links** (TOOLING-DOC-AUTOGEN). `docs-check` could tell that a link resolved but not that a reference still *described* the code — which is how DOC-AUDIT-PASS found a stale `addSubMenu` signature. The lot was scoped as **generate two references** and shipped as a **drift check**, because checking the premise first showed both were wrong: `ALIASES.md` is not a rendering of `veaf-units.yaml` (that file holds *spawn* units; the marker aliases are registered at runtime in `veafShortcuts.lua`) and it carries thematic sections and a hand-written description per alias; the MCP page the ticket named is written for mission makers in natural language and says outright you need not know the technical names, so 3 of 29 appear in it. Generating either would have replaced a document people read with a table nobody needs. The check instead asserts that **every name the code defines is mentioned by the page documenting it** — proven immediately by two live gaps: **`set_airbase_coalition`**, shipped by FEAT-MCP-AIRBASES-WAREHOUSES and never written up in either language, and **5 marker aliases** absent from `ALIASES`. All six now documented, including the airfield-coalition trap (it lives in `warehouses.airports[<id>].coalition`, not `mission.coalition`, so placing a unit near a base never turns the base). Names are read by regex rather than imported, keeping the CI job stdlib-only and seconds long, with a test asserting the regex and the real `list_catalog()` agree. The CI trigger gained the **source** paths: adding an action touches none of the old ones, so the gate would have been blind to the exact commit it exists for.
- **`list_shortcuts` was offering `-login` and `-logout` to AI assistants** (TOOLING-DOC-AUTOGEN). The `:setHidden(true)` flag on internal aliases is read by `veaf_shortcuts_scanner.py`, which builds the list that MCP action serves — but `get_shortcuts()` prefers a **pre-generated JSON**, and the local copy on this workstation had drifted to 128 entries while the parser produced 123. A stale generated artefact was therefore silently overriding its own generator, exclusion included, and the test asserting otherwise had been **red on this workstation while CI stayed green**. JSON regenerated, test green, and a new test now compares the artefact against a fresh scan when present so it cannot rot again. The flag's Lua comment still named its *original* consumer — the veafShortcuts F10 radio menu, deleted in `ca962e4b` in June 2021 — and now names the real one. The five internal aliases are additionally **documented for humans** in `ALIASES.{md,en.md}`: keeping an auth command out of a public reference while its code is public protected nothing and denied the legitimate mission maker the information; not offering it to an AI building a mission is a separate, sound decision, and that is what the flag now does.
- **`docs-check` stopped at `doc/`, and 92 links had rotted behind it** (TOOLING-REPO-LINK-GATE). The gate guarded the published documentation and nothing else, so `.backlog/`, `docs/adr/`, `docs/exploration/` and the root pages — 340 files, 555 relative links — were unchecked. **68 of the 92 were a regression from the archive sweep (#655)**: folding a lot's tickets into one file moved their content from three levels below the repo root to two, so every `../` chain climbs one level too far, while `../PRD.md` and `tickets/NN-x.md` came to point at sections of the very file doing the pointing. That sweep's verification was line-level and reported 0 losses, which was true and insufficient — **line fidelity is not link validity**, a relative path being a fact about where a file sits rather than about its content. Repaired candidate-first rather than by rule, since the breakage had several causes at once including links already wrong beforehand: try the plausible rewrites, keep the one that resolves, refuse anything ambiguous — 0 ambiguous cases, so nothing was guessed. Intra-document references are **de-linked to plain text** rather than turned into anchors, because GitHub's slugifier is not the `pymdownx` one the gate mirrors and the new pass deliberately does not validate anchors outside `doc/`; generating them would have produced links nothing here can verify, which is how this happened in the first place. Also fixed 11 links to `doc/*.fr.md` on `README.md` and `CONTRIBUTING.md` — that suffix has never existed here (the convention is `X.md` + `X.en.md`), so the two most-read pages in the repo had been broken since they were written. `docs/superpowers/` and `CODE_DOC_REVIEW_2026-07-01.md` are **exempted with their reasons in code** rather than silently skipped: their links described a real past state and rewriting them would invent one that never existed, so the keep/fix/delete call is filed as ticket 04 instead of guessed.
- **The docs CI job did not trigger on the paths it now checks.** `pull_request` was scoped to `doc/**` and four files, so a PR breaking a backlog link never ran the gate — precisely how #655 shipped 68 dangling links. `.backlog/**`, `docs/**` and root `*.md` added to the trigger.
- **`poetry run test-lua` no longer runs the suite on the wrong Lua** (FIX-LUA-RUNNER-VERSION-CHECK). It took the first `lua` on PATH without asking what version it was, so on a workstation where that is scoop's 5.4 the whole suite ran on an interpreter the VEAF scripts do not target — `unpack` removed in 5.2 breaks `veaf.safeCall`, `string.format('%d', …)` refusing a fractional number since 5.3 breaks `veafUnits`, `veafSpawnEffects` and `veafSpawnAircraft` — **34 failures across 6 suites on a clean checkout**, reported as if the code were broken. CI installs `lua5.1`, so it was green there and nobody saw it. It was also intermittent: `veaf.lua` seeds `math.random` from `os.time()`, so the heading reaching a `%03d` is fractional on roughly 40 % of runs, which made `test_veafUnits.lua` look flaky (5 green / 3 red over 8 runs at constant code). Every candidate is now **version-checked with `lua -v`** and anything that is not 5.1 is refused, with what was found and how to install the right one, rather than used. `lua51` joins the candidate list — the shim `scoop install lua51` leaves pointing at 5.1 when another Lua is also installed — and the documentation carries the trade-off, that package's `lua` shim replacing the other one's. **The Lua sources are deliberately untouched:** DCS runs 5.1 and that is the only target; the defect was the runner's silent fallback. Found while delivering FEAT-SCENERY-AWARE-SPAWN (PR #653), where it cost real time to prove a red suite was not a regression.

### Added
- **[ADR 0019](docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) — DCS Fiddle keeps its open port for now, and the harness docs finally say so** (SECREV-2 ticket 02, finding VMR-013 🟡). The hook the smoke harness speaks through runs any Lua it is sent with no token and no origin check. Hardening it and keeping the harness alive is **one decision**, so it is written down rather than done quietly: the port stays open because no DCS is available here to test a change to the harness's only transport, and untested authentication there fails invisibly until someone with a DCS blames their own setup. What ships instead is the half that can be verified by reading — a danger warning in the page that tells you to install the hook, in both languages — plus the token design, to be implemented with the harness's remaining slice where it can be tested. The review's MEDIUM rating **understates it**: `server_config = { cors = "*" }` with a `GET` command channel means any web page visited while the hook is installed executes Lua in DCS and reads the result, since a browser sends a cross-origin `GET` without asking. "It only binds to loopback" is no protection when the browser is on loopback too.
- **`veaf-tools smoke-test` — assert VEAF behaviour inside a running DCS** (FEAT-DCS-SMOKE-HARNESS, first slice). `test-lua` runs against `dcs_mocks.lua`, a DCS we wrote ourselves, so it can only confirm what we already believed — and everything beyond it had been queuing up for a human to fly: the `Disposition` probe, the coalition-scoped submenu question, Foothold's staggered loading, and the guided checklists, which were signed off by someone sitting in a cockpit. The harness talks to the `dcs-fiddle-server.lua` hook, whose contract was **read out of the script rather than assumed**: Lua base64 in the URL path, target environment in `?env=`, JSON `{result}`/`{error}` back. `env=default` reaches the hook's own environment, the only one holding `net.*`; `env=mission` reaches where the VEAF scripts live. Not the `dcs-serve` bridge `capture-map` uses — that one lives *inside* the mission, so it cannot answer before the mission exists. What makes any of it possible is already measured: `onSimulationFrame` fires at ~28 Hz **with no mission loaded**. Assertions are **data** — six checks so far, each recording *why* we want the answer and which lot it unblocks. `--probe-only` reports what a running DCS actually allows, including whether `net.load_mission` and `DCS.exitProcess` exist, two calls this repository has never made. It **skips with an explanation** and exit 0 when there is no hook or no mission, because that is the normal state of most machines and a tool that goes red there stops being run; it will never be a CI gate, since runners have no DCS, licence or GPU. **Not one check has actually run**: no DCS was available, so this is the framework and none of the evidence — by the lot's own Definition of Done it is unfinished, and it stays 🔄. Launching and quitting DCS were deliberately cut rather than written blind against calls nobody here has made. Writing the checks surfaced a bug worth recording: the Lua snippets return truthy **sentinel strings** (`veaf-absent`, `no-singleton`) instead of raising, so an expectation written as a plain truthiness test passed in exactly the case it existed to catch — a test now sweeps every check against every sentinel.
- **Ground units stop spawning inside villages and forests** (FEAT-SCENERY-AWARE-SPAWN). Placement knew only water from land — `land.getSurfaceType` is the only scenery signal the documented DCS API offers — so a marker dropped over a hamlet put a platoon in the houses. New `veaf.findSpawnPoint` searches in three bounded tiers: **all criteria including clearance from buildings and forests** via `Disposition`, a native but *undocumented* DCS singleton found in TUM; failing that **every criterion except that clearance**; failing that an explicit **failure with one message**. Wired into the four dynamic ground spawners and the generic `doSpawnGroup`; the convoy spawner is deliberately excluded, its departure point being also its route origin. Two things this fixed that were not the original target: the five affected callers used to jitter **once** and use the point unvalidated, so a centre could land in the sea and the units were then dropped one at a time downstream — that spawn now works, and a genuinely impossible spawn aborts once instead of emitting one message per unit. `Disposition` is guarded and `pcall`-wrapped and is deliberately **absent from the DCS mocks**, so all 35 Lua suites exercise the path that does not need it ([ADR 0018](docs/adr/0018-undocumented-dcs-api-dependency.md)). **The in-game probe is deferred**, so the avoidance itself is asserted rather than measured; if it disproves, tier 1 is a deletion and tier 2 stands on its own. Opt out with `veaf.doNotAvoidScenery`.
- **Trigger-zone properties are readable** (FEAT-SCENERY-AWARE-SPAWN). `veaf._discoverTriggerZones` has always copied each zone's `properties` into its cache and nothing ever read them, so a mission maker could type properties in the editor and no VEAF module could consult them. DCS hands them over as an array of string pairs, never a map, so `veaf.getZoneProperty` / `getZonePropertyBoolean` / `getZonePropertyNumber` replace the linear scan and the `tonumber` every caller would otherwise write. Booleans accept any case and treat junk as a miss rather than as `false`; numbers **clamp** into an optional range instead of rejecting, so an absurd value yields the bound and not a dead module.
- **Fixed: 219 F-14 cockpit controls were missing from its index** (FEAT-ASSIST-AUTHORING). The element pattern was anchored at column zero, and Heatblur declares whole panels inside `if` blocks — so every indented element was silently dropped, including the DFCS stability augmentation switches. Found by using `explore-cockpit` in a live cockpit: a switch was thrown, nothing was reported, and the control turned out not to be in the index at all. The F-14B and F-14B(U) go from 360 controls to 579, and the F-16C gains one. `explore-cockpit` also announces each control it identifies **in game**, like the verifier does — the console is invisible from a cockpit.
- **The checklist verifier talks to the pilot in game** (FEAT-ASSIST-AUTHORING). Instructions and outcomes now appear in DCS rather than in a terminal the pilot cannot see from a full-screen cockpit — which is what the first live run of `verify-checklist` made obvious, confirming 1 step of 4. Two more defects came out of the same run: the prompt showed the step's flight label (“Lancer le moteur droit”), naming neither the control nor the position, and now shows the instructor's own `control` text; and the wait ended on the first movement, so a switch moved back and forth reported “the checklist has the wrong value” when it did not. It now waits for the **wanted** value and confirms a control already in position rather than waiting for a move that will never come. Second run: **4 of 4 confirmed** on the F-14B(U), and the checklist is marked `verified`.
- **`veaf-tools explore-cockpit` names a control by having you move it** (FEAT-ASSIST-AUTHORING). Run it, throw a switch, and the tool tells you which control that was — element, animation argument, and the value of the position it just reached — printed as a checklist step ready to paste. The value is **measured**, not inferred, which is what unblocks the aircraft the resolver cannot help with: only 7 of the AH-64D's 478 controls have a position value written down anywhere, and handling them yields all the others. `--control "transfer pump"` works the other way, boxing a named control before the loop starts — the thing that turned out to be useful first, when a pilot could not find the hydraulic transfer pump. It loops until Ctrl-C, reads the whole cockpit in one round trip rather than one per control, and never moves anything itself.
- **The wizard groups its commands under four headings** (FEAT-ASSIST-AUTHORING): build a mission, extract from a mission, set up and check, guided checklists. Twenty commands in a flat list was a wall of text, and the checklist commands are one workflow that had ended up scattered through it. A `CommandSpec` now carries its group, every command is assigned to one, and tests guard both facts — an unassigned command would silently vanish from the menu, since the selector now iterates groups rather than commands.
- **`veaf-tools verify-checklist` checks a checklist against a real cockpit** (FEAT-ASSIST-AUTHORING). For each measurable step it boxes the control in the pilot's aircraft, waits for them to move it, reads the animation argument and compares it with what the checklist claims; `--write` marks the confirmed steps `verified: true`. It waits for the value to **change and settle** rather than for a keypress — nobody is holding a keyboard inside a cockpit — and it never throws a switch itself: boxing the control is all it does to the aircraft, which doubles as the answer when you cannot find the control. A reading that disagrees with the checklist is reported loudly and fails the command, because that is the case worth knowing about. The automatic mode originally planned alongside it is **dropped with a reason**: `a_cockpit_perform_clickable_action` needs numeric device and command ids, and those are not in a module's readable files — searching the A-10C's whole `Cockpit/Scripts` tree for the ids its own autostart uses returns the autostart and nothing else.
- **The F/A-18C cockpit is indexed** (FEAT-ASSIST-AUTHORING): 280 controls, 77 with position values. Its autostart resolves 39 of its 138 steps outright — between the F-16C's 60 of 115 and the AH-64D's 2 of 86.
- **The binding-derived values are confirmed in a live cockpit** (FEAT-ASSIST-AUTHORING). Read on 2026-08-03 in a F-14B(U) through the export environment, with each control physically in the position under test: argument 629 gives 0 at NORMAL and 1 at SHUTOFF, argument 2102 gives −1 at Engine Crank Right and +1 at Left. Four for four against what the resolver had written. It matters because this is a **third-party** aircraft whose hints name no positions at all — the input bindings were the only possible source for those values, so until now there was nothing to check them against. `a_cockpit_highlight` also boxed a control in the live cockpit on request, which is the assisted-verification mode minus its loop.
- **The guided-checklist page now leads with the instructor, not the format** (FEAT-ASSIST-AUTHORING). Writing a checklist is one section — a label, a `control` in plain words, one command — and the technical fields moved into a *Format reference* introduced as something you do not need in order to write one. New section on choosing the validation mode, leading with the multiplayer rule: `argument` for solo and local training, `param` and `confirm` for a mission meant for the server; the caveat used to be repeated in two places and now lives in one. *Finding the element to box* leads with the resolver and keeps the manual route for an unindexed aircraft, plus the command to index it. **A correction while restructuring:** the page said a position's value is read from `clickable_defs.lua`'s `arg_lim`. That gives the window, not which position is which value — the aircraft's input bindings give that, and the page now says so. The exploration note gains three sections: the bindings as the real source of a position's value, the four `clickabledata.lua` dialects with what each costs if unhandled, and the unit catalogue lagging behind the store.
- **A guided checklist for the F-14B(U), from Heatblur's own manual** (FEAT-ASSIST-AUTHORING). The pilot's engine-start procedure, written the instructor way and resolved from the cockpit index: the two hydraulic-transfer-pump steps and the two engine-crank steps validate themselves (`Engine Crank` runs Right −1 / Left +1), while the throttles — axes — and the air-source selector — five separate buttons — are pilot-confirmed. Sourced from <https://f14.manuals.heatblur.se/f14bu/procedures/checklists/startup.html>, read 2026-08-03: the sequence and positions are facts about the aircraft, the labels are written in our own words. Getting there needed two fixes worth knowing about. The F-14B(U) has no cockpit of its own but **does** ship its own bindings, and its Input folders are stubs pulling the F-14B's in — 4 valued positions read alone against 87 read as a pair — so the generator now separates whose cockpit from whose bindings and reads both. And the shipped unit catalogue, generated from a datamine at a pinned revision, simply does not know this aircraft: a checklist naming `F-14BU` was rejected outright, which is the wrong answer for the aircraft somebody just bought. A committed cockpit-control index now counts as proof an aircraft exists, alongside the catalogue.
- **An instructor writes a checklist in their own words** (FEAT-ASSIST-AUTHORING). `control: MAIN PWR sur BATT` beside the label, then `veaf-tools resolve-checklist checklists/my-checklist.yaml`, and the technical fields appear underneath — element, animation argument, and the value that means “in position” — with a `resolved_from` recording the text they came from. Edit the text, run it again: only the steps that changed are touched. One file, the instructor's own, keeping its comments, its indentation and its blank lines; a run that reindented it would turn a two-field edit into a diff nobody can read. Run against the six steps of the shipped F-16C checklist, the resolver reproduces **exactly** what a developer had written by hand after reading `clickabledata.lua` inside a DCS install: `equals: 0.0` and `equals: 1.0` on the two MAIN PWR steps, matching the in-game measurement, and pilot-confirmed on the JFS and the throttle, neither of which holds a position anything can read. **It refuses rather than guesses** — no match, two matches equally good, a position the control does not have, or a control whose position values are unknown — because a wrong resolution produces a checklist that looks finished and never validates, and you find out sitting in a cockpit. One refused step leaves the whole file untouched, and a step whose `control` no longer matches its `resolved_from` fails the mission build rather than shipping a check on the previous control. Refusals and notes are translated; French and English filler words are ignored on both sides.
- **Every clickable control of a cockpit, indexed at build time** (FEAT-ASSIST-AUTHORING). `veaf-build update-dcs-data --cockpit-controls --dcs-path <DCS>` reads a module's `clickabledata.lua` and writes one committed YAML per aircraft: the animation argument, the hint DCS shows on mouse-over, the named positions, the value window, and whether the control has a position worth polling. This is what lets the next step of the lot turn an instructor's `throttle sur idle` into `element`/`argument`/`equals` without anyone opening a DCS install. Six aircraft are known to the generator; four are installed here and shipped: F-16C (284 controls), A-10C II (470), AH-64D (478) and the F-14B — whose index the F-14B(U) shares, since Heatblur's newer jet has no cockpit of its own but two lines of `dofile` pointing at the older one's. Each module turned out to speak its own dialect, every one of them found by indexing a real cockpit rather than assumed: the AH-64D names the crew station before the hint and quotes it with apostrophes, the A-10C's UFC keypad passes an empty hint, and Heatblur names its arguments instead of writing them out — that last one alone was the difference between 114 F-14 controls and 360. **The trap the index is built to prevent:** a hint's positions are in hint order, not value order (`MAIN PWR/BATT/OFF` runs +1/0/−1 while `OFF/BACKUP` runs 0/1), so reading a value off a rank is wrong half the time and silently. And naming positions at all is a recent ED habit, not a rule — 127 of the F-16C's 284 controls do it, and none of the F-14's 360. Whatever the parser cannot read is counted and printed, never dropped quietly.
- **Guided checklists: the mission walks a pilot through a procedure** (FEAT-ASSIST-CHECKLISTS). A new `ASSIST` module boxes the cockpit control the current step needs, ticks the line as soon as that control reaches the right position — or as soon as the pilot confirms it — and moves on, with the whole checklist shown on screen as a picture. Reached from the F10 menu under `Assistance`. It is built on a discovery worth recording: the cockpit-highlight machinery ED uses for its own training missions is **not** restricted to trigger actions, it is reachable as a plain function from the mission scripting environment — so the whole thing is a runtime module driven by data and emits **zero trigger rules**, instead of the two-rules-per-step design that would have buried a mission maker's own triggers under hundreds of ours. Checklists are authored as YAML sidecar files, in a shipped catalogue and in the mission's own `checklists/` folder, the same profile as `ctld-config.yaml` ([ADR 0016](docs/adr/0016-ctld2-sidecar-configuration.md)). The first one ships: an F-16C engine start, taken from ED's own autostart sequence rather than written from the switch labels, every step pilot-confirmed for the reason given in the entry above. A mission activates checklists with `modules: ASSIST: {enabled: true, checklists: [...]}`; with no list, the checklists the mission maker dropped in its own folder are activated, **never** the whole catalogue — every activated checklist bakes one picture per step into the `.miz`. Turning the module off costs nothing at build and nothing in game.
- **A checklist step can be validated on a cockpit switch's position after all** (FEAT-ASSIST-CHECKLISTS). `argument: 510` with a window, read through `GetDevice(0):get_argument_value()` in **Export.lua's** Lua environment — a third namespace, reached by the same `net.dostring_in` bridge the module already uses. This reverses the finding recorded a day earlier: three mechanisms reachable from the *mission* environment are all blind to the cockpit, but `export` is not, and MAIN PWR reports −1 / 0 / +1 across its three positions, matching the `arg_lim` of its prototype exactly. The shipped F-16C checklist gets its two MAIN PWR steps back as automatic ones. **Caveat, stated in the documentation:** `Export.lua` runs on the pilot's machine, so this may not reach a dedicated server — untested; a step that cannot be read simply never self-validates and the pilot still has "skip". A spring-loaded switch (the F-16C's JFS) and a button (argument 757 is the throttle's cut-off, not its position) remain unreadable in any environment.
- **A mission maker can write their checklist's translations in place** (FEAT-ASSIST-CHECKLISTS). `label: {fr: …, en: …}` on a step, or on a checklist's `title`, resolved at build time in the mission's language. Until now a checklist written for a mission could only be one language: labels are catalog keys, the catalog is `veafI18n.lua`, and that file belongs to the framework — adding entries meant forking the VEAF scripts. Plain text worked and still does, but only in one language, and a `custom_scripts` extending `veaf.i18nCatalog` would have fixed the messages while leaving the *picture* showing raw keys, since it is rendered at build time from `published/`. A string is still emitted untouched, so a catalog key remains a key resolved in game.
- **A mission chooses between a pretty checklist and a cheap one, at build time** (FEAT-ASSIST-CHECKLISTS). `modules: ASSIST: {display: text}` renders **no image at all** — nothing generated, nothing embedded, nothing in `mapResource` — and the engine sends the current instruction as a message instead (`Étape 3/6 : …`). The cockpit control is still boxed: text mode drops the picture, not the assistance. `picture` remains the default, so nothing changes for a mission that says nothing. The shipped six-step F-16C checklist weighs 68 KB as pictures and zero as text, and the gap passes half a megabyte at forty steps. An unrecognised value fails the build rather than quietly falling back to the expensive mode.
- **A checklist step can be validated on what the aircraft *is*, not on where its switches are** (FEAT-ASSIST-CHECKLISTS). A step's `param:` reads a live cockpit parameter — `BASE_SENSOR_NOSE_GEAR_DOWN`, `BASE_SENSOR_IAS`, `BASE_SENSOR_BAROALT`, 78 of them published on an F-16C — and ticks when it enters the step's window. This replaces the animation-argument check the design was built around, which was **measured in game and does not work**: a cockpit control's position cannot be read from the mission environment at all. MAIN PWR was moved through its three positions while `getDrawArgumentValue`, `c_player_unit_argument_in_range` and `list_cockpit_params` all stayed blind — the cockpit is a separate model, which is also why ED's own training checklists manage it (their code runs *inside* the module's cockpit) and we cannot. The `argument:` field is now rejected with an error explaining the alternative, rather than silently never firing, and the shipped F-16C checklist is pilot-confirmed throughout. Full measurements in [DCS cockpit + picture API](docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md). The upshot: an engine-start checklist is a guided-and-confirmed one, while a bomb run — altitude, speed, heading — is fully automatic.
- **A radio command can be given an explicit position in its menu** (FEAT-ASSIST-CHECKLISTS). `veafRadio` sorts a menu's entries alphabetically, which is right for a list to browse and wrong for a pair with an intended sequence: in French *"passer l'étape"* sorts before *"valider l'étape"*, putting "skip" above "confirm" for the two entries a pilot presses on every step. A command may now carry a `sortKey` the sort prefers, so the order holds whatever the labels become in translation.
- **A radio command can be offered only to the pilots it applies to** (FEAT-ASSIST-CHECKLISTS). `veafRadio` per-group and per-unit commands accept an optional `groupFilter(unitName, groupId)`, consulted once per candidate unit; false leaves the entry out for that group. It is what lets the assistance offer "Cold start" only to pilots flying an aircraft that has one, and swap it for the in-session entries once a checklist is running — instead of showing everyone an item that answers "nothing for you". A filter that throws is logged and treated as false, so it cannot take a menu rebuild down with it.

### Fixed
- **Checklist pictures showed raw i18n keys when built from a release** (FEAT-ASSIST-CHECKLISTS). The text baked into a picture is resolved through the **runtime** catalogue so it matches the pilot's messages — but the reader looked for `veafI18n.lua`, and a distribution's `published/` ships only the concatenated `veaf-scripts.lua`. Every checklist built from a release would have read `assist.f16c.main_pwr_batt` instead of *"MAIN PWR sur BATT"*; only a source checkout worked. The reader now accepts the bundle, narrowing to the `veaf.i18nCatalog` table — without that it scraped 5245 entries out of every other module's tables, and the catalogue's name appears in `veaf.lua`'s comments 2300 lines before the table itself.
- **Two documentation deployments can no longer knock each other out** (FIX-DOCS-DEPLOY-CONCURRENCY). Every `Deploy Docs` run fetches `gh-pages` from the external documentation repository, builds and pushes it back, so two at once meant the second fetched before the first landed and was rejected — `! [rejected] gh-pages -> gh-pages (fetch first)`. The window is built into the release procedure, which pushes the `v*` tag and back-merges to `develop` minutes later: it cost the 6.13.0 release a red run, and it is why the 6.11.0 documentation was never published at all. A `concurrency` group makes deployments queue; `cancel-in-progress: false`, because cancelling would drop a deployment on the floor, which is the outcome to avoid. No retry on the push: `docs.yml` here is the only producer for that repository, verified, so a retry would guard against a writer that does not exist.

## [6.13.0] — 2026-08-01

### Changed
- **The four VEAF modules that talk to CTLD use its v2 API** (FEAT-CTLD2-INTEGRATION). `veafGrass`, `veafSpawnGround`, `veafSpawnEffects` and `veafSpawnAircraft` poked v1 globals — `ctld.logisticUnits`, `ctld.builtFOBS`, `ctld.fobBeacons`, `ctld.beaconCount` — none of which exist in CTLD 2, where a manager owns each. They now call `CTLDZoneManager:registerFOBAsLogistic`, `CTLDBeaconManager:createAtPoint` and `CTLDJTACManager:autoLase` / `stopAutoLase` directly rather than the `legacy_api` wrappers, which log a `DEPRECATED` line on every call. Two consequences worth knowing: a FOB beacon is numbered by CTLD instead of by a second VEAF counter, and the TACAN carrier unit on a FARP is spawned by `veafGrass.spawnTacanCarrierUnit` — it was borrowed from `ctld.spawnRadioBeaconUnit`, but it is a plain DCS group with nothing CTLD about it. The scaffolded `ctld-config.yaml` also carries the VEAF starting values for `logisticUnitTypes` and `troopZoneShipTypes`, which is what preserves the carrier and FARP recognition `autoInitializeAllLogistic` used to provide; `FARP Ammo Storage` is **not** among them — it is the display name of `FARP Ammo Dump Coating`, so the v1 entry never matched anything.
- **CTLD is a VEAF module like any other** (FEAT-CTLD2-INTEGRATION). The 185-line `veaf.ctld_initialize_replacement` wrapper is gone: CTLD 2 registers through `veaf.registerModule`, so the framework gives it its initialisation order, its `enable` flag and its `logLevel` for free. Its verbosity is now `veaf.config.ctld.logLevel` like every other module — CTLD 2 has no log level of its own (`ctld.utils.log` labels the text and sends everything to `env.info`), so VEAF overrides that **one** function where v1 needed seven. `veaf.ctld_initialized`, `veaf.ctld_initialize_replacement` and the `configurationCallback` extension point disappear with it; a mission needing custom settings puts them in its `ctld-config.yaml`. `veafSpawn.spawnFob` now refuses to build for the right reason — the module being disabled is no longer indistinguishable from the script being absent.
- **CTLD is now CTLD 2, and it is configured in its own file** (FEAT-CTLD2-INTEGRATION, [ADR 0016](docs/adr/0016-ctld2-sidecar-configuration.md)). The bundled script becomes [VEAF/CTLD](https://github.com/VEAF/CTLD) 2.0.0-rc3 — the OOP rewrite — vendored verbatim instead of the adapted ciribob v1 concatenation. A mission's CTLD settings move out of `mission.yaml` into a `ctld-config.yaml` beside it, a complete YAML snapshot edited with `ctld-tools.exe` and injected by the build as `CTLD_userConfig.lua`, loaded immediately before `CTLD.lua` in both static and dynamic mode. **`modules.CTLD.settings:` is no longer read and is now a validation error**, because the v1 channel only ever half-worked: the generated `ctld.<key>` lines were silently overwritten by the hardcoded configuration in `veaf.ctld_initialize_replacement`, so a `slingLoad: false` written in a `mission.yaml` never did anything and never said so. The build also defers CTLD's start-up (`ctld.dontInitialize`) so the VEAF framework initialises it after wiring its logger, keeping CTLD's startup report in the VEAF log.

### Documentation
- **The mission maker's guide teaches the CTLD 2 way** (FEAT-CTLD2-INTEGRATION). The CTLD sections of the guide, the `mission.yaml` reference, the migration guide and the AI-assistant catalogue still described `modules.CTLD.settings:` and the `ctld.initialize(configurationCallback)` fallback — both gone. They now cover `ctld-config.yaml` and `ctld-tools`, the warning against that tool's own `.miz` injection on a VEAF mission (the next build overwrites it), the complete-snapshot rule that makes an omitted list a deletion, the real trigger order, and a before/after table for the v1 reserved zone names. FR and EN.

### Added
- **A version's documentation can be republished without moving its tag** (DOC-STAMP-FOOTER). `Deploy Docs` gained a manual trigger taking a `version` (and whether to move `latest`). Re-running the tag build was not an option: it rebuilds from the **tagged commit**, so a fix landed after the tag — such as the footer stamper below — could never reach the published pages. The version entered is also the one stamped into the pages, since republishing 6.12.0 from a 6.12.1 tree would otherwise stamp 6.12.1 onto them. Documented in the developer guide (FR + EN).

### Fixed
- **The docs version stamper also stamps the page footer** (DOC-STAMP-FOOTER). `LUA_API_REFERENCE` carries a version and a date **twice** — header and footer — and the first implementation stamped only the header, using `count=1`. The published 6.12.0 page therefore still advertised *"Généré pour : VEAF Mission Creation Tools v6.5.25"* and *"Juin 2026"* in its footer, which is exactly the stale-header defect the stamper was written to end. Found by reading the published page rather than trusting the local run. The footer pattern is anchored on the ASCII product name instead of the localised label, and both date lines are now stamped. A regression test asserts the pattern contains no control character: the first attempt wrote a literal backspace where a regex `` was intended, producing a pattern that silently matched nothing — invisible in the source and in a `sed` dump.

## [6.12.0] — 2026-07-28

### Added
- **The documentation now has a quality gate** (DOC-QUALITY-GATE). Every other artifact in this repo is gated; `doc/` was not, which is how DOC-AUDIT-PASS came to find eight defects that had accumulated silently. `poetry run docs-check` (CI job `Docs Check`) refuses a broken relative link, a cross-page anchor the target does not expose, a cross-page anchor derived from a heading, a French page with no `.en.md`, a page absent from the `nav`, and a `nav` entry with no file. It is stdlib-only, so the job needs no Poetry install and runs in seconds. Two behaviours are pinned by tests because getting them wrong produced 245 false positives during the audit — relative links are language-agnostic (the i18n plugin rewrites them) and `pymdownx` anchors keep their accents.
- **Cross-page anchors are explicit and English** (DOC-QUALITY-GATE). The 82 links that relied on a heading-derived slug now target explicit anchors, stamped on both language versions of 54 headings. Heading **text** is untouched — French stays French, in the page and in the menu — only the anchor is English and shared, so one link works for readers of either language and survives a reword. Four slugs became short hand-picked names, including one that pinned a tool version (`5-stylua-240-lua-code-quality` → `stylua-setup`).
- **The references' version header is stamped at deploy** (DOC-QUALITY-GATE). `LUA_API_REFERENCE` had advertised "Version 6.5.25 / June 2026" while 6.11.8 shipped: a header nobody remembers to bump is worse than none, because readers trust it. The repository keeps a readable `6.11.x` range and the deploy workflow rewrites it to the shipped version on its throwaway checkout.

### Fixed
- **Documentation audit: the English site no longer serves French, and no link 404s** (DOC-AUDIT-PASS). `mission-maker/dcs-radio-specs` had no English version, so its EN URL returned a French page — made worse by FIX-PRIMARY-FREQ-HUMANRADIO adding a whole section to it; it is now translated (85 aircraft rows on both sides). Six links to `../adr/*.md` returned **404 in production**, because `docs/adr/` is not under `docs_dir: doc/` — they now use the GitHub blob URL like every other ADR reference. Three cross-page anchors were dead: two pointed at pipeline "step 4" for the weather/time step, which renumbering had moved to step 6, and one guessed a French slug for a section that carries the stable anchor `ctld-and-csar-integration`. `LUA_API_REFERENCE` still documented `veafRadio.addSubMenu(title, parentMenu)` without the `coalitionSide` parameter, and pinned "Version 6.5.25 / June 2026" while shipping 6.11.8. The `veafRadio` page gained the coalition-scoped menu section it was missing, `developer/capture-airbases` joined the Developer menu (it was reachable only through one inline link), and the sections added today got explicit English anchors instead of guessed slugs. Verified against the published site, which also cleared two false alarms: the i18n plugin rewrites relative links, and `pymdownx` keeps accents in anchors.

### Changed
- **A combat zone's F10 menu now goes to the side playing it** (FEAT-COMBATZONE-MENU-COALITION). Every zone's submenu was global: both coalitions saw every zone. That menu is not read-only — it is how a zone is **activated**, its smoke popped, its info requested — so with red-side zones now possible, either side could trigger the other's zones. A zone's menu is now shown to the opposite of its `enemy_coalition`, with `radio_menu_coalition: RED | BLUE | ALL` to override (`ALL` restores the global menu, for an umpire in a red slot who must trigger a blue zone). **This changes existing missions**: a zone with no `enemy_coalition` now shows its menu to blue only. A mission whose player slots are all blue sees no difference; one with red slots that must keep access to the blue zones needs `radio_menu_coalition: ALL` on those zones. The parent `COMBAT ZONES` menu deliberately stays global, since a `radio_group_name` submenu may hold zones of both sides.

### Added
- **`veafRadio` supports coalition-scoped menus** (FEAT-COMBATZONE-MENU-COALITION). `veafRadio.addSubMenu(title, parent, coalitionSide)` renders that subtree through DCS's `ForCoalition` menu API, which the builder never used — it only knew the global and per-group variants. The side is inherited by everything below the node: child submenus, commands, and the render-time pagination pages (ADR 0013), since a global child under a coalition-scoped parent has no coherent meaning in DCS. A `USAGE_ForGroup` command inside a scoped subtree is only emitted for human groups of that coalition (groups whose side DCS never reported are left in, as before), which required `veafRadio.humanGroups` to start recording each group's coalition. `rebuild()` now removes scoped nodes explicitly: the global `removeItem` on the root is not guaranteed to reach them, and since the menu is rebuilt on every player join, anything left behind would stack one duplicate menu per join.
- **A combat zone can be played from the red side** (FEAT-COMBATZONE-RED-SIDE). A zone assumed the players were blue and the units to destroy red, in two places: the watchdog completed the zone on the **red count alone**, and the F10 report labelled the blue tally *friends* and the red one *enemies*. So a zone whose enemies are blue could not work — holding no red unit, it saw zero reds on its first check (~1 min) and immediately completed and deactivated. The documented workaround, `completable: false`, did not make the zone red-sided: it just switched auto-completion off, and the report still called the blue enemies "friends". The new `enemy_coalition: RED | BLUE` key on a `combat_zones[]` entry names the hostile side, and both the completion condition and the report labels follow it. `RED` stays the default and is not emitted, so every existing mission behaves exactly as before and generated configs stay byte-identical. Unit counting itself was already per-coalition and correct — only the side the condition looked at was hard-coded. In Lua: `VeafCombatZone:setEnemyCoalition(coalition.side.BLUE)`, which also accepts a `"blue"`/`"red"` string. An unknown value is a build error rather than a silent fallback to red, since that fallback is precisely the bug being fixed.

### Fixed
- **The Mission Editor no longer refuses to save a mission because of an injected primary frequency** (FIX-PRIMARY-FREQ-HUMANRADIO). Reported by Tripack: a built mission carrying FW-190s could not be saved — *"FW-190D9 Template: Fréquence invalide 134 MHz"* — and only the **blue** templates were flagged, the red ones (which match no preset, so the injector leaves them alone) being fine. A DCS aircraft has two distinct frequency constraints and `dcs-radio-specs.yaml` only modelled one: `panelRadio.range`, what the radio set can tune as **preset channels** (FW-190: 38–156 MHz), versus `HumanRadio`, what the editor accepts as the group's **primary frequency** (FW-190: 38.4–42.4 MHz). `inject-presets` promotes channel 1 to the primary so the editor's field matches it, gated only on a blanket 30 MHz floor — so a 134 MHz VHF channel, a perfectly legal FuG 16 preset, became an illegal primary. `HumanRadio` is now extracted per aircraft and the promotion is skipped when channel 1 falls outside it: the group keeps its own valid frequency and the presets are still injected. This bounds **27 of 87** aircraft, and generalises three carve-outs that had been added one bug at a time — the FM-primary Gazelle, the ADF Yak-52, and the Ka-50/Mi-8/Mi-24 family — while surfacing the same latent trap on the Hawk, the M-2000C and the whole P-51/P-47/Mosquito set.
- **A `mission.yaml` password now actually works** (FEAT-FOOTHOLD-V5-PARITY). Two independent defects made `security:` a decoration. First, `password_hashes` was emitted at level **L9 only** — the weakest — while the gates that matter (marker authentication, the sensitive spawns, transport missions) accept **L1 or L0**; a mission configured this way had a password that could not authenticate a marker, whatever it was set to. It is now emitted at L1 **and** L9, which is what the hand-written v5 missions did. Second, the reference page documented **SHA-256** while `veafSecurity._checkPassword` computes `sha1.hex(password)`: every hash produced by following the documentation could never match, so the mission looked protected and was wide open. The page now says SHA-1, with a working example and a warning to re-check existing missions.

### Added
- **The Foothold batch flags a `.miz` whose name no longer matches `mission.yaml`** (FIX-BATCH-MIZ-NAMING-CHECK). The build names its output after `mission.name`, and on the VEAF servers that name is an interface — RealWeather reads `_ICAO_<code>` from it. A `.miz` left from an earlier build under a different name is therefore not clutter but a trap: deploy it and the mission pulls the weather of the wrong airfield, silently. It happened on five missions whose ICAO codes had been corrected after their first build. The batch now compares the files present with the expected name, counts only the matching ones (the count previously included stale files), and names each stale file so it can be removed.
- **The `.miz` file name is documented as an interface** (FEAT-FOOTHOLD-V5-PARITY). The RealWeather extension of DCSServerBot reads `_ICAO_<code>` from the built mission's **file name** and fetches that airfield's live METAR at mission start — a convention that was written down nowhere and was silently lost when a mission was rebuilt under a new name. `MISSION_YAML_REFERENCE` (FR + EN) now explains that `mission.name` becomes the file name, how to keep the marker, how to get a date-less fixed name, and — the part that matters — that a code must be checked for **freshness**, not just existence: a stale station is worse than no real weather, since the mission then advertises a "real" weather several days old. Measured on the Afghanistan theatre, all 29 airfields fail that test — the page presents both defensible answers (omit the marker, or take the least bad knowingly) rather than prescribing one.
- **`modules.RADIO.init.create_menus`** (FEAT-FOOTHOLD-V5-PARITY): `false` suppresses the VEAF F10 menu entirely (`veafRadio.initialize`'s `dontCreateMenus`), which combined with `security:` is how a public mission keeps the VEAF commands reachable only through password-protected map markers — the posture the v5 Foothold used and that v6 could not express. The key is optional: a mission that does not mention it generates exactly what it generated before.
- **The Foothold radio presets move to the preset-plan model** (FEAT-FOOTHOLD-PRESETS-PLAN). The shared `presets.yaml` still worked, but gave **10 aircraft types channels outside their radios' bands** — silently dropped, the AJS-37 losing its whole 30-channel FM list — because one collection was applied to every airframe, and it carried six hand-written collections plus three `empty` types to work around that. Rewritten as three role-based channel lists (`tools/foothold/presets.yaml`) that the build projects onto each type's physical radios: on `Foothold_AF_2.4.1` **10 → 2** out-of-band types and **30 → 32** kneeboard plates, on WWII Normandy **2 → 0**, with no type losing coverage — `Mi-24P` and `Mi-8MT` gaining presets the old file had given up on. A legacy override layer remains for Flaming Cliffs aircraft, absent from `dcs-radio-specs.yaml`, sharing the same channel lists through YAML anchors so no frequency is duplicated.
- **Batch adoption of a whole Foothold release** (CHORE-TOOLING-GATES). Now also validates and **builds** the batch (`-Build`), against one shared scripts bundle (`-SharedPublished`) instead of ~58 MB of `published/` per folder — and strips the machine-specific `build.scripts_path` the build persists, so each `mission.yaml` is left as its author wrote it. Before building it flags what would make the result wrong: a still-commented `config_override`, or a `src/versions.yaml` with the weather step enabled (one `.miz` per declared version). A Lekaa release ships one archive per map, so adopting it meant ten `convert-other` runs with the right profile each time. `tools/Convert-FootholdBatch.ps1` does the batch in one pass, one mission subfolder per archive, choosing the conversion profile **by content** — it opens the `.miz` inside the `.zip` and looks for `Foothold Config WW2.lua`, so a future WWII map named differently still resolves (the archive name is only a fallback). One failure never stops the batch; a summary table closes the run and the exit code reflects it. `-Update` for later releases (refresh scripts, keep every tuned `mission.yaml`), `-Validate` to check the batch. Exercised on the real 4.4.1: 10/10 adopted and validated. Repo-only helper, documented in `FOOTHOLD.md`; `tools/README.md` states what belongs there versus in the shipped product.
- **`convert-other` accepts a release archive** (FEAT-FOOTHOLD-RELEASE-INTAKE). Third-party missions are now distributed as a `.zip` rather than a bare `.miz` — Lekaa's Foothold assets bundle the mission with a config-manager executable, the manual and a shortcut — so every adoption started with a manual unzip. Pass the archive you downloaded and the command adopts the `.miz` inside it, reading **only** that member (the bundled executable is never extracted, and never run). The archive must contain exactly one `.miz`: with none, or with several, the command stops and names what it found instead of guessing which mission you meant. A plain `.miz` keeps working unchanged, and `--update` takes an archive too.
- **`foothold-ww2` conversion profile** for the WWII Normandy Foothold (FEAT-FOOTHOLD-RELEASE-INTAKE). Normandy is a different family: its config file is `Foothold Config WW2.lua`, it has no `Era` global (WWII has no era switch) and no `StartNormal`, and it ships **no Foothold CTLD** — so the VEAF CTLD is not incompatible there (it still stays OFF by default; adopting a mission must not silently add a subsystem). Adopting it with `--profile foothold` used to validate and build cleanly while producing a dud override — see the `config_override.target` fix below.
- **`validate` rejects a `config_override.target` that names no injected script** (FEAT-FOOTHOLD-RELEASE-INTAKE). Only the override's *keys* were validated, never its target, and the build appends the override **last** when the target is absent — after the setup script has read the globals. The result was an override embedded, loaded, and silently without effect; confirmed in a built `.miz` where it landed at resource key 11012 instead of 11005. The message names the consequence and points at the matching conversion profile. Found by adopting WWII Normandy with the modern `foothold` profile.

### Changed
- **The `foothold` profile keeps up with upstream 4.4.1** (FEAT-FOOTHOLD-RELEASE-INTAKE). `Splash_Damage_*.lua` is now normalised to `Splash_Damage.lua` alongside `Moose_*.lua`, so a version bump of either no longer breaks the `custom_scripts:` paths on `convert-other --update`. The commented `config_override` scaffold also offers `FootholdLocale` (config V1.0.9, `FR` among ten locales), the setting that drives Foothold's on-screen language. The per-map setup script (`MA_Setup_CA.lua`, `footholdSyriaSetup.lua`, …) is deliberately **not** normalised: those names vary per map, not per version.
- **Foothold documentation covers the new release channel** (FEAT-FOOTHOLD-RELEASE-INTAKE): where the upstream comes from (GitHub releases), which profile suits which map, the four `Era` values (`Modern`, `Coldwar`, `Gulfwar`, `Vietnam` — the guide only knew the first two), and a warning about the **external config channel** the Foothold Config Manager installs. Since config V1.0.9, `Foothold Config.lua` overlays `<Saved Games>\…\Missions\Saves\Foothold Config.lua` when that file exists: our `config_override` still wins (the generated override is loaded after the config script, verified in a built `.miz`), but such a file on a server silently changes every Foothold mission on that instance — so it must not be installed on a VEAF server.

### Fixed
- **`convert-other --profile` works in the shipped executable** (FEAT-FOOTHOLD-RELEASE-INTAKE). The conversion profiles were never bundled by PyInstaller, so `veaf-tools.exe convert-other … --profile foothold` died with `unknown conversion profile` — meaning the Foothold moulinette documented in `FOOTHOLD.md` was unusable for anyone not running from the sources, which is presumably why it went unnoticed. The stale `veaf-tools.spec` *does* list the profiles, but the build ignores that file and passes its own `--add-data` list, where the directory was missing. The whole directory now ships, so a new profile needs no build change, and a regression guard covers it. Same family as `FIX-VEAF-BUILD-RADIO-LAYOUT-DATA`.
- **Released documentation is published again** (FIX-DOCS-LATEST-ALIAS). The docs site still advertised **6.10.0** as `latest` although 6.11.0 had shipped. Two stacked causes: the release procedure only documented the `published-v*` tag, so the `v*` tag that deploys the versioned documentation was never pushed for 6.11.0 (procedure fixed); and `docs.yml` could not have succeeded anyway — its `master` step ran `mike deploy latest`, creating a **version** literally named `latest` that collided with the `latest` **alias** the tag step needs (`alias 'latest' already specified as a version`). That step only started running after `main`→`master` was corrected, which is why the breakage appeared then. The `master` step is removed (a release's documentation is published by its tag), the parasite version was deleted from the site, and `v6.11.2` redeployed: the picker now shows `6.11.2` as `latest`.

## [6.11.2] — 2026-07-28

### Added
- **All 14 DCS theatres now resolve airfield names** (FEAT-AIRDROMES-RUNTIME-SOURCE). **Reaper** captured the seven maps nobody had covered yet — Nevada, The Channel, South Atlantic (Falklands), Kola, Afghanistan, Iraq and Marianas WWII — using the map-capture kit, so `airdromes.yaml` goes from 7 theatres / 657 airbases to **14 theatres / 810 airbases**. A QRA `airport_link` or a `warehouses.yaml` entry now resolves on every current map. Note: DCS exposes no coordinates for three Afghanistan forward bases (`FOB Thunder`, `FOB Camp Dubs`, `FOB Clark`) — they are kept because their name and id are valid, which is all the name→id table uses.

### Fixed
- **A script embedded by `add_startup_script_trigger` never loaded** (FIX-MAPRESOURCE-KEY). In `file_static` mode the resource key was written into the **`mission`** table, whereas DCS resolves `getValueResourceByKey` against the separate `l10n/DEFAULT/mapResource` archive member. The `.lua` was embedded but unreachable: the editor showed an empty FILE field on the DO SCRIPT FILE action and the script silently never ran. Affects every mission outfitted through that action — including the bridge missions bundled in the map-capture kit, which is how it surfaced. A second, related loss was found while fixing it: a `.miz` carrying **no** `mapResource` member at all (possible for a tool-generated mission) lost the key too, since `write_miz` only rewrites members that already exist — the helper now supplies the file itself. The unit test had locked in the wrong behaviour (asserting the key landed in `mission`), and the end-to-end test only checked that the `.lua` was in the archive, never that its key resolved; both are corrected and two regression tests added. Verified in the DCS editor.

## [6.11.0] — 2026-07-26

### Added
- **A QRA can be declared without being armed** (FEAT-ACTIVATION-CONTROLS). New `active_at_start` key on a `modules.QRA.definitions[]` entry (default `true`, so nothing changes for existing missions). With `false`, the generated builder chain stops before `:start()`: the QRA is still registered under its name, so a `qra.start` radio command — or a script — arms it later. Until then it is inert (its birth-event handler returns early while its enemy-unit cache is unset). Previously every QRA was armed at mission load and `active_at_start` was silently ignored there (it is a *combat-zone* key). Reported by Tripack.
- **A combat zone can be told never to auto-complete** (FEAT-ACTIVATION-CONTROLS). New `completable` key on a `modules.COMBATZONE.combat_zones[]` entry (default `true`), mapping to the runtime's existing `:setCompletable(false)`, which stops the zone from scheduling its completion watchdog. This is what a zone holding **only BLUE units** needs: completion is decided on the *red* unit count alone (`nbUnitsR == 0` — the blue count is computed but never used), so such a zone activated and then deactivated itself on its first check, about a minute later. Reported by Tripack. Making the enemy coalition itself configurable remains open.
- **The map-capture kit is now a release asset** (FEAT-AIRDROMES-RUNTIME-SOURCE). A new `kit` job in the release workflow publishes `veaf-map-capture-kit-<version>.zip` alongside the other assets: `veaf-tools.exe`, `dcs-serve.exe` (pulled from the latest [VEAF-dcs-bridge](https://github.com/VEAF/VEAF-dcs-bridge) release — best-effort, the kit still ships without it), a ready-to-run bridge mission **per supported theatre** (generated without DCS: blank mission + bridge trigger), and the step-by-step procedure. Assembled by `veaf-build build-kit`. No `dcs-serve.yaml` is bundled, so the public artifact carries no secret: `dcs-serve` writes its own key on first launch and `capture-map` now **finds it automatically** (`--api-key` became optional; `--config` points at a specific `dcs-serve.yaml`/`dcs-client.yaml`) — a helper just runs `veaf-tools capture-map --out-dir .`.
- **Delegable map-data capture via the dcs-bridge** (FEAT-AIRDROMES-RUNTIME-SOURCE). Two maker-facing `veaf-tools` commands let anyone collect a theatre's airbases without a source checkout, Python or Poetry — just the shipped executables: `veaf-tools inject-bridge <mission.miz>` embeds `dcs-bridge.lua` + a start trigger into any `.miz` (reusing the MCP editor-parity primitive), and `veaf-tools capture-map` reads `world.getAirbases()` from the running mission over `dcs-serve` (`POST /api/exec`) and writes a rich `<theatre>.json` — `{id, name, lat, lon, coalition}` per airbase (real airfields **and** terrain helipads; lat/lon from `coord.LOtoLL`). On the dev side, `veaf-build update-dcs-data --airdromes` merges the committed JSON dumps (`veaf_build/dcs_data/airbase_dumps/`) into `airdromes.yaml` (name→id projection). See `doc/developer/capture-airbases.md`.

### Changed
- **Secret-scanning CI uses the free gitleaks CLI** (FIX-SECRET-SCANNING-GITLEAKS-CLI). The `Secret Scanning` workflow relied on `gitleaks/gitleaks-action@v3`, whose wrapper requires a **paid licence for GitHub organisations** — without a `GITLEAKS_LICENSE` secret it aborted (`[VEAF] is an organization. License key is required.`), so the job had failed on every run since it was added and secret scanning never actually ran. It now installs the MIT-licensed **gitleaks CLI** (pinned) and runs `gitleaks git` against the existing `.gitleaks.toml` — no licence, organisations included.

### Fixed
- **QRA `airport_link` and warehouse airfield names now use exact DCS names** (FEAT-AIRDROMES-RUNTIME-SOURCE). The `airdromes.yaml` name→id table was generated by scraping terrain `Beacons.lua`, which carries *beacon* display names (e.g. a VOR named `ABYAD` mapped to a nearby airfield's id) rather than real airbase names, and omitted every airfield without a beacon. Validation therefore rejected valid `airport_link` values (Tiyas, Marj Ruhayyil, Al-Dumayr…) as "unknown airfield". The table is now sourced from **runtime dumps** (`world.getAirbases()` via the VEAF dcs-bridge), giving the exact `Airbase:getName()` value — the one `Airbase.getByName`/`airport_link` actually expects — for every airbase including terrain helipads. **Seven theatres regenerated** (Caucasus, GermanyCW, MarianaIslands, Normandy, PersianGulf, SinaiMap, Syria — 657 airbases); un-captured theatres are migrated lot-by-lot. `veaf-build update-dcs-data --airdromes` now reads committed dumps under `veaf_build/dcs_data/airbase_dumps/` and no longer needs `--dcs-path`. Stale folder-named keys from the retired scraper (`Sinai`, `GermanyColdWar` — DCS names the theatres `SinaiMap`/`GermanyCW`) are dropped once their canonical theatre is captured, so no duplicate survives.
- **Server hook: the shared pilots list is loaded again, and load failures no longer crash the hook or deny everyone silently** (FIX-SERVERHOOK-UNKNOWN-PILOT-PARSE). On a production server no pilot was recognized at all (admin included) and any `/command` crashed the hook. Three linked defects:
  - The pilots file is meant to be **shared by all VEAF servers** from the `Saved Games/` root, but `loadPilots` looked for it under the per-server `Scripts/Hooks/` folder (`writedir()\scripts\hooks\`), where it does not exist — so the list was always empty. The default location is now the shared `Saved Games/` root (`writedir()\..\`), one level above the server folder; `pilotsDir` still overrides it for a standalone server.
  - `loadPilots` used `assert(loadfile(filepath))`, which *threw* on a missing file — making the `if not file` error branch right below dead code and leaving the pilots table empty. It now loads defensively: a missing/invalid file logs a clear error (`no pilot will be recognized and every command will be denied`) instead of raising a raw Lua exception.
  - `veafServerHook.parse` logged the "Unknown pilot" warning but kept going and then indexed `pilot.level` on a `nil` pilot, throwing `attempt to index local 'pilot' (a nil value)` (VEAF-Server-hook.lua:413). A pilot absent from the list now gets `level = -1` (no power at all), the same convention `onPlayerConnect` already used, so the command is cleanly denied instead of crashing the hook.
  All three paths only became reachable once #590 revived the dead chat callback (`onChatMessage` → `onPlayerTrySendChat`).
- **CI workflows now trigger on `master`** (FIX-WORKFLOWS-MAIN-TO-MASTER). Every workflow was scoped to a `main` branch that does not exist in this repo (the stable branch is `master`), so no CI ran on a push to `master` — quality checks, SBOM, secret scanning and the `latest` docs deploy were all dead on the branch that receives the release merges. Renamed `main` → `master` across the 7 workflows (`develop` triggers and the `v*` tag doc path untouched).

## [6.10.0] — 2026-07-18

First stable, official v6 release cut to `master` (previously `master` still carried v5).
This tags the accumulated v6 line — declarative `mission.yaml` toolchain, the AI mission
authoring assistant (MCP server + Claude plugin), all-theatre coordinates and geo-placement,
and the cross-platform binaries — as the new `published-latest`.

### Fixed
- **Logger no longer crashes on servers wired to DCSServerBot** (FIX-SERVERHOOK-CHAT-SIM-LOGGER). `veaf.Logger:print` forwarded log lines to the DCSServerBot channel via `Sim.getMissionName()`, but `Sim` is a GameGUI/hook global that does not exist in the mission scripting environment — so every `:error()` raised `attempt to index global 'Sim'`. On such servers this swallowed player-facing messages (e.g. the carrier-ops "radio not authenticated" notice never displayed) and broke unrelated error paths. The mission name now comes from `veaf.config.MISSION_NAME`.
- **Server hook now actually receives chat commands** (FIX-SERVERHOOK-CHAT-SIM-LOGGER). `VEAF-Server-hook.lua` listened on `onChatMessage`, which is not a DCS GameGUI callback, so no server chat command (`/secu login`, `/send`, `/restart`, …) ever ran. It now uses the real `onPlayerTrySendChat(playerID, msg, all)` callback, returning `nil` for normal chat (broadcast) and `""` for a recognised VEAF command (consumed). Redeploy the hook on servers to pick this up.

### Changed
- **Server hook is a single deployable source again** (REFACTOR-SERVER-HOOK-CANONICAL). `VEAF-Server-hook.lua` no longer `require`s the native `BufferingSocket` module at load time (which crashed the hook when the module was absent). Its two production-specific divergences are now OFF-by-default flags a companion `VEAF-specific-server-hook.lua` can enable: `enableBufferingSocket` (telemetry, now loaded defensively via `pcall` and auto-disabled if missing), `enableAutoRestart` (idle-restart watchdog + `restart`/`restartnow`/`halt` commands), plus `pilotsDir` to share one `veaf-pilots.txt` across servers. Repo defaults reproduce the deployed behaviour, so the hook can be deployed by plain copy. Bumped to 2.7.0; new admin doc `doc/mission-maker/scripts/veafServerHook.md`.

## [6.9.2] — 2026-07-15

### Added
- **`add_group` is now folder-aware — durable groups in the recipe** (FEAT-MCP-ADD-GROUP-FOLDER, found testing): `add_group` accepts either a **mission folder** (exploded `src/mission/` — durable, survives a rebuild) or a **`.miz`** (built, transient) as its target. Placing a **permanent** SAM (a `#veafInterpreter["-samLR"]` carrier unit) can now be written **durably** into the recipe instead of only into the built `.miz` — previously `add_group` was `.miz`-only, so the assistant had to fall back to the built world (lost on rebuild). Reuses the group-insertion core already shared with the composite builders; the action's parameter is renamed `miz_path` → `target` and the result gains a `durable` flag. The skill documents targeting the folder for standing content.
- **Combat-zone radio grouping from config** (FEAT-COMBATZONE-RADIO-GROUPS). A combat zone may now carry two optional keys in `mission.yaml`: `radio_group_name` gathers every zone sharing the same value under one intermediate F10 submenu, and `radio_menu_prefix` prepends a prefix to the zone's menu label. Both map 1:1 onto the runtime setters (`setRadioGroupName` / `setRadioMenuPrefix`) and are round-tripped by `convert-v5`, so a v5 mission that grouped or prefixed its zones converts iso-functionally.
- **Automatic radio menu pagination** (FEAT-COMBATZONE-RADIO-GROUPS, [ADR 0013](docs/adr/0013-radio-menu-pagination.md)). Any F10 radio menu that exceeds the DCS 10-item limit is now paginated automatically at render time, spilling the overflow into "Next page" submenus — no per-module code, and no "Next page" when a menu fits. Opt a menu out with `veafRadio.doNotPaginate(menu)`; a menu holding a `USAGE_ForUnit` command opts out automatically (with a warning). The Combat Zone menu (and its radio groups) benefits for free.

### Changed
- **The Claude plugin version now tracks the veaf-tools version** (found testing): the plugin manifest shipped a standalone `0.2.0` while the tools were at `6.9.x`, which was confusing (`claude plugin list` vs `veaf-tools --version`). `plugin/.claude-plugin/plugin.json` is aligned to the tools' version, and a new `test_plugin_version.py` guard fails CI if the two ever drift — so every version bump touches both.
- The opt-in pagination helpers `veafRadio.addPaginatedRadioElements` / `addPaginatedRadioMenu` no longer paginate themselves (they sort and insert their elements); pagination is now done once, at render time, for every menu.

### Added
- **Assign an airfield to a coalition, with automatic Dynamic Slots** (FEAT-MCP-AIRBASES-WAREHOUSES, found testing): new MCP action `set_airbase_coalition` colours a DCS airfield blue/red/neutral in a mission **folder** (durable). An airfield's coalition lives in `warehouses.airports[<id>].coalition`, **not** in `mission.coalition` — so placing a unit near a base never turned the base itself; now it does. Assigning a base also turns on its **Dynamic Spawn** slots, and the build's warehouses injector stocks it with that coalition's dynamic templates — a new auto-fill kicks in when no explicit `aircrafts:` list is given. The shipped default `src/warehouses.yaml` is now **effective** (enables dyn slots + auto-fill on every assigned base) instead of fully commented. Airfield name → id is resolved via the mission's theatre.
- **Alias-first authoring guidance** (FEAT-MCP-AIRBASES-WAREHOUSES, found testing): the `veaf-mission-authoring` skill now states a **general** rule — prefer a VEAF alias (`#command` for zone content, `#veafInterpreter` for a permanent asset) over hand-placed literal units whenever an alias covers the need, not only for combat zones. So a long-range SAM is a `#veafInterpreter["-samLR"]` carrier, not a literal Patriot. The oracle's `list_shortcuts` commands gain a structured `category` (SAM/AAA/infantry/armor/artillery/naval/transport/…) so aliases are discoverable by kind instead of substring-guessing.
- **Mission-editing MCP server skeleton** (`veaf-mission-mcp`, FEAT-MCP-MISSION-EDITOR-001, first phase of NL-MISSION-GEN, [ADR 0014](docs/adr/0014-mission-editor-mcp-editor-parity-layer.md)). New `veaf_mission_mcp` package exposing a `capabilities`/`list_catalog`/`describe_action`/`run_action` MCP surface, empty for now — concrete editor-parity actions (add a group, read the mission state) land in follow-up tickets.
- **Backup-before-write helper** (FEAT-MCP-MISSION-EDITOR-002): `mission_tools.miz_backup.backup_before_write` copies a `.miz` to a timestamped sibling (`mission.miz` → `mission.20260712-143012.miz`) before an editor-parity action overwrites it — pure safety net, git remains the actual undo. A same-second collision is disambiguated with a `-2`, `-3`, ... suffix rather than overwriting a prior backup (an LLM driving several actions in a row can easily land in the same second).
- **`describe_mission` read action** (FEAT-MCP-MISSION-EDITOR-003): the mission-editing MCP now exposes `describe_mission`, listing every group (name, coalition, country, category) and trigger zone (name, position, radius) currently in a mission's `.miz` — reuses the existing pure-Python parser (`read_miz`), no new Lua/JSON parsing. Gives the calling LLM situational awareness before an editor-parity write.
- **`add_group` write action** (FEAT-MCP-MISSION-EDITOR-004): the mission-editing MCP now exposes `add_group`, inserting a ground/vehicle group (units expanded from `{type, count}`, an optional route with patrol looping) into a mission's source `.miz`, in place and backed up first. Fresh `groupId`/`unitId`s never collide, even on a mission with sparse existing ids. Not deduplicated — mirrors adding a group by hand in the DCS Mission Editor. The id/country-lookup bookkeeping is now shared (`mission_tools.group_insertion`), reused by `coalition_placeholder.py`'s existing placeholder injection.
- **`add_trigger_zone` write action** (FEAT-MCP-MISSION-EDITOR-006, wave 2): inserts a named **circular** trigger zone into `mission.triggers.zones` with a fresh `zoneId` — the zone a VEAF combat zone references, so combined with `add_group` an LLM can lay down a full combat zone. Backed up first; not deduplicated.
- **`add_startup_script_trigger` write action** (FEAT-MCP-MISSION-EDITOR-007, wave 2): adds a "mission start" trigger that runs a script — `inline` Lua, a `file_static` `.lua` embedded into the `.miz` (`l10n/DEFAULT` + `mapResource`), or a `file_dynamic` disk-path `loadfile`. For outfitting a **vanilla or CTLD** mission with scripting without the DCS editor. Generalizes `inject_dcs_bridge_trigger`/static-dynamic loading; appends at the next free trigger index (no renumbering). Backed up first; not deduplicated.
- **v1 wrap-up** (FEAT-MCP-MISSION-EDITOR-005): end-to-end test driving `describe_mission` → `add_group` (twice) → `describe_mission` against a real `.miz`, and a new [developer doc page](doc/developer/mission-editing-mcp.md) (FR/EN) covering the v1 action catalog and the editor-parity/VMCT-action split.
- **Embedded-Lua editing — generic** (FEAT-MCP-MISSION-EDITOR-009, wave 3): `replace_in_mission_files` does a text/regex search-replace across a mission's embedded Lua, **restricted to `l10n/DEFAULT/**/*.lua`** (never the raw `mission`/`options` tables or binaries). Backed up first; only the changed members are rewritten verbatim (new `mission_tools.rewrite_miz_members` brick — no Lua-table re-serialization).
- **Embedded-Lua editing — VMCT config** (FEAT-MCP-MISSION-EDITOR-010, wave 3): edit a built mission's `veaf-config.lua` without a rebuild — `set_log_level`, `set_module_enabled`, `set_security_disabled`, `set_veaf_config`. Each replaces the target line if present, else inserts it near the top (before module init). Backed up first. (Security password hashes are not covered yet — only the `SecurityDisabled` flag.)
- **VMCT actions on the source `mission.yaml`** (FEAT-MCP-MISSION-EDITOR-012/013, wave 4): the first genuinely *VMCT* action family — edit the declarative source the build consumes, not a built artifact. `describe_mission_config` lists the `modules:` block and each module's state; `set_mission_module` toggles a module (scalar) or sets its extended config block (e.g. `COMBATZONE`/`CTLD`), inserting the key if absent. Comments, key order and formatting are preserved via a new `ruamel.yaml` round-trip brick (`mission_tools.mission_yaml_editor`); backed up first. Deliberately generic — no per-module schema validator.
- **Mission-maker action catalogue** (FEAT-MCP-MISSION-EDITOR-015): a new user-facing [doc page](doc/mission-maker/AI_ASSISTANT_CATALOG.md) (FR/EN) listing everything a Mission Maker can ask the AI to do through the MCP, in plain language — grouped by theme, ordered by estimated frequency, with a complete index and the recipe-vs-built-mission distinction. A living doc, extended as the MCP grows.
- **Domain-knowledge oracle** (FEAT-MCP-MISSION-EDITOR-016, wave 5): read-only MCP actions giving the LLM the DCS + VEAF knowledge to author correctly — `list_unit_types` (from the generated `dcsUnits.yaml`), `list_shortcuts` (VEAF aliases from `veaf-units.yaml`), `describe_naming_conventions` (the 8 reserved group/unit naming patterns), `describe_module` (locator over the canonical module list → doc page + enabled state). All read from the sources the build already uses, so they cannot drift.
- **Convention-aware `add_group`** (FEAT-MCP-MISSION-EDITOR-019/020, wave 6): the LLM gives intent, `add_group` names the group correctly itself — `for_combat_zone` (zone-name prefix so the zone captures it), `late_activation` (QRA/CAP), `as_spawn_template` (`veafSpawn-`). New `validate_group_name` action flags reserved-convention collisions (and, with a `.miz`, the combat-zone capture trap); `add_group` surfaces those as `warnings` and still writes, for the calling LLM to relay.
- **Composite one-pass builders** (FEAT-MCP-MISSION-EDITOR-024..028, wave 8): the MCP is now **mission-folder-aware** and ships high-level actions that lay down a whole VEAF feature in one call, editing both worlds durably (exploded `src/mission/` + `mission.yaml`, no build) — `create_combat_zone` (zone + zone-prefixed groups inside + `COMBATZONE` block), `create_qra` (zone + Late-Activation interceptors + `QRA` definition referencing them by exact name), `create_cap_mission` (`OnDemand-` template + `cap_missions` entry). Foundation: `mission_folder` + `write_mission_folder` (write-side of `read_mission_folder`, no zip/Lua-exec).
- **Recipe/built config parity** (FEAT-MCP-MISSION-EDITOR-022, wave 7): the source `mission.yaml` now has setters mirroring the built-`veaf-config.lua` actions — `set_mission_log_level` (`global_log_level`), `set_mission_security` (`security:` block, incl. the JTF/Mission-Master password hashes the built-side action doesn't cover), `set_mission_setting` (`settings.<key>` → `veaf.config.<key>`). Every dual-target setting is now reachable on both the durable recipe and the built mission.
- **`scaffold_mission` — bootstrap a fresh mission folder** (FEAT-MCP-MISSION-EDITOR-029, wave 9): the MCP can now create a mission folder from an **empty** folder, driving the real VEAF bootstrap — download the updater from the GitHub release (stable release-download URL, no API rate limit), run it to install the tools and `published/` into the folder, then `veaf-tools prepare --template` to lay down the default scaffold. Step 0 of a from-scratch mission, before the `create_*` composites. Refuses a non-empty folder; accepts `minimal`/`standard`/`full` (the interactive `custom` tier has no TTY under a subprocess). New cross-OS updater-asset resolver (`platform_assets.release_updater_asset_name`, including the fixed-name Windows asset).
- **Synthetic per-theatre blank mission** (FEAT-BLANK-MISSION-THEATRE): `veaf-tools prepare --theatre <name>` now lays down a minimal, loadable blank mission for a DCS map into `src/mission/` — no more hand-making a `.miz` in the DCS Mission Editor to start. Built in Python (`veaf_libs.blank_mission`) from a generic mission skeleton + per-theatre constants (`data/theatre-defaults.yaml`); **Caucasus** seeded and DCS-load-verified. `--list-theatres` lists the supported maps; unknown theatre errors cleanly; an existing `src/mission/` is kept unless `--force`. The MCP `scaffold_mission` action gained a `theatre` parameter that forwards to `prepare --theatre`, so an LLM can bootstrap a ready-to-fill folder in one call.
- **Design-time coordinate conversion + map read** (FEAT-MCP-MISSION-EDITOR wave 10): `veaf_libs.coordinates` converts DCS local `x/y ↔ lat/lon` per theatre — a pure-Python port of `projection.lua` (MIT, `bfr-claude-plugins`, [ADR 0015](docs/adr/0015-coordinate-projection-port.md)), Transverse Mercator WGS84 + per-theatre tables (Caucasus/Syria/PersianGulf/MarianaIslands), verified against the source's reference cases. New read-only MCP actions `describe_map` (theatre, bullseyes, existing zones/groups as reference points — from a `.miz` or a folder) and `resolve_coordinates` (`{x,y} ↔ {lat,lon}` for the mission's theatre). Since DCS theatres are the real world projected, this is the bridge for real-world placement (see the FEAT-GEO-PLACEMENT lot).
- **Place by real-world geography** (FEAT-GEO-PLACEMENT): the MCP `geocode` action resolves a real place name ("Batumi", "Kobuleti airport"), optionally offset by a bearing + distance ("10 km north of X"), to DCS coordinates for the mission's theatre — since DCS maps are the real world projected. Pluggable geocoder: **OpenStreetMap Nominatim** by default (free, no key; © OpenStreetMap attribution), **Google Maps** when `GOOGLE_MAPS_API_KEY` is set. Per-theatre bounding boxes disambiguate results and flag out-of-theatre hits. Results are approximate (confirm visually); named places work, vague terrain does not. Adds `veaf_libs.geocoding`, `coordinates.offset_latlon`, and `data/theatre-bounds.yaml`.
- **Build & validate from the MCP** (FEAT-MCP-MISSION-EDITOR wave 11): two actions close the authoring loop so the server goes from an empty folder to a playable `.miz` without leaving the assistant — `validate_mission` (in-process pre-build lint → `{ok, errors, warnings}`) and `build_mission` (drives `veaf-tools build` in the folder — the binary `scaffold_mission` installed, or `veaf-tools` on PATH — surfacing a build failure). The MCP now spans create → edit → validate → build → play (28 actions).
- **Unit-name markers on placement** (FEAT-MCP-MISSION-EDITOR wave 12): `add_group` (and the composites, via pass-through) now accept an optional `name` per unit, so the combat-zone spawn idiom — a fake-unit group whose unit name carries `#command="-armor ..."` (also `#spawngroup`/`#spawnradius`/`#spawncount`/`#spawnchance`/`#spawndelay`) — is finally buildable through the MCP. The oracle and skill already taught it; now the action can express it.
- **All DCS theatres for coordinate conversion** (FEAT-ALL-THEATRE-COORDS): `veaf_libs.coordinates` (used by `geocode`/`resolve_coordinates`/`describe_map`) is now data-driven from a vendored export of [VEAF/dcs-maps](https://github.com/VEAF/dcs-maps) (`data/dcs-maps.yaml`, MIT) — covering **all DCS theatres** (Caucasus, Syria, PersianGulf, Marianas, Normandy, Nevada, SinaiMap, GermanyCW, Kola, TheChannel, Falklands, Afghanistan, Iraq) with the exact DCS theatre keys, instead of 4 hardcoded ones. Kept our thin pure-Python Transverse Mercator (no `pyproj`); adopting the `dcs-maps-coordinates` package was rejected (native `pyproj`/`mgrs` deps, PyInstaller-hostile) — see ADR 0015. Alias map covers `Sinai`→`SinaiMap` / `GermanyColdWar`→`GermanyCW`.
- **Blank missions for 9 theatres** (FEAT-BLANK-MISSION-THEATRE-005): `theatre-defaults.yaml` (the per-theatre map-centre + bullseye the blank generator uses) is now extracted from the calibration missions in [VEAF/dcs-maps](https://github.com/VEAF/dcs-maps) `data/maps/*.miz` (MIT), parsed with our own `read_miz` — real values, not fabricated. `prepare --theatre` / `scaffold_mission(theatre=)` now cover Caucasus, Afghanistan, GermanyCW, MarianaIslands(+WWII), Normandy, PersianGulf, SinaiMap, Syria (the maps dcs-maps ships); the generator itself is unchanged.
- **`veaf-tools mcp` subcommand** (FEAT-MCP-PLUGIN-001): launches the mission-editing MCP server on stdio from inside the shipped `veaf-tools` binary (no separate binary). First step toward packaging `veaf-mission-mcp` + the `veaf-mission-authoring` skill as a self-hosted Claude plugin.
- **Install guide for the AI mission-editing assistant** (FEAT-MCP-PLUGIN-003): `doc/mission-maker/AI_ASSISTANT_INSTALL.md` (FR + EN) walks a maker through installing the `veaf-mission-editor` plugin (`claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools` + `install veaf-mission-editor@veaf`), the first-launch auto-install, updating, and testing a pre-release via `VEAF_MCP_UPDATER_TAG`. Linked from the mission-maker README; the plugin manifest is bumped to 0.2.0 so an already-installed copy picks up the bootstrap on update.
- **Self-hosted Claude plugin `veaf-mission-editor`** (FEAT-MCP-PLUGIN-002): the MCP server + authoring skill packaged as an installable Claude plugin (`plugin/.claude-plugin/plugin.json`, `.mcp.json`, `.claude-plugin/marketplace.json` — `claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools`). The `veaf-tools` binary the server runs is installed and kept current **automatically** by a `SessionStart` bootstrap hook (`scripts/bootstrap.ps1`, Windows) driving `veaf-tools-updater` — no manual copy: first launch installs it synchronously, later launches refresh it detached (throttled to ≤ once per 4 h; replacement deferred to the next session when the exe is locked). Tracks `published-latest` by default; set `VEAF_MCP_UPDATER_TAG` (e.g. `published-v6.9.21-rc1`) to test a pre-release. Windows-first (a Unix `bootstrap.sh` can follow; the hook no-ops without PowerShell).
- **`list_shortcuts` now exposes the `#command` spawn shortcuts** (FEAT-MCP-ORACLE-COMMANDS): a third `commands` block lists the 128 high-level aliases declared in `veafShortcuts.buildDefaultList()` (`-samLR`, `-samSR`, `-armor`, random convoys, …) — previously invisible to the oracle, which only knew the `veafUnits` aliases from `veaf-units.yaml`. This is the authoritative source for the `-<alias>` a combat-zone fake-unit carries in `#command="..."`; found in real use (the LLM invented a non-existent `-lrsam` instead of the real `-samLR`). A new `veaf_libs.veaf_shortcuts_scanner` parses the aliases from the Lua source, following the `lua_module_scanner` pattern (live scan in dev, a build-time `veaf-shortcuts.json` bundled into the binary). The `veaf-mission-authoring` skill now steers to `list_shortcuts` for these.

### Fixed
- **`build_mission` no longer deadlocks the MCP on a build that reads stdin** (FIX-BUILD-STDIN-DEADLOCK, found testing in a clean Windows VM): `build_mission` ran `veaf-tools build` **inheriting the MCP server's stdin** — the JSON-RPC stdio pipe, which never reaches EOF — so an interactive `input()` reached on a build path blocked **forever** (~0 % CPU, no disk I/O, no network: the exact observed hang), whereas `prepare` in the same scaffold succeeded because `scaffold._run` already closes stdin. The subprocess now closes `stdin` (`DEVNULL` → a read gets EOF at once), bounds the build with a `timeout`, and exports `VEAF_UPDATER_NO_PAUSE`; and the `veaf-tools` exit pause (`veaf-tools.py`, `app.py`) now goes through `should_auto_pause()` so the env var suppresses it everywhere — belt-and-braces so no build path can hang on a keypress no one can press.
- **MCP server no longer corrupts its stdio stream** (FIX-MCP-STDOUT-POLLUTION, found testing in a clean env): the server logged `Starting veaf-mission-mcp …` through the Rich console, which writes to **stdout** — but a stdio MCP server carries JSON-RPC on stdout, so the log line garbled the handshake and the client connected **but saw zero tools** (exactly what happened in Claude Desktop). The server now mutes the Rich console before `mcp.run()` (new `Logger.mute_console()`); all logging stays on the log file / stderr, stdout is JSON-RPC only.
- **Windows: the plugin marketplace clone no longer fails on "Filename too long"** (FIX-LONG-FILENAMES-WINDOWS, found testing the plugin in a clean Windows VM): 42 empty KNEEBOARD placeholder files in the test fixtures had 95-character names (`this folder contains the images (jpg) that will go in the kneeboard of this particular aircraft`) which, cloned under a deep path, exceeded Windows' 260-char `MAX_PATH` and aborted the marketplace checkout — so `claude plugin install` could never find the plugin. Renamed them to `.gitkeep` (keeps the folders, short name); the longest tracked path is now 91 chars. The install guide also notes `git config --global core.longpaths true` as a belt-and-braces.
- **Skill: `#veafInterpreter` documented with an example + distinguished from `#command`** (FIX-MCP-INTERPRETER-DOC, found testing): the `veaf-mission-authoring` skill mentioned `#veafInterpreter["<cmd>"]` in one line with no concrete example, so for a **permanent** SAM the assistant left the MCP to look up the exact format in an external plugin's VMCT knowledge base. The skill now gives a worked example (`#veafInterpreter["-samLR"]` on a blue unit → a permanent blue LR SAM at start) and states the rule: `#veafInterpreter["<alias>"]` = spawned **at start, permanent** (carrier destroyed); `#command="-<alias>"` on a combat-zone fake-unit = spawned **on zone activation** (dynamic). Both use `list_shortcuts` aliases and the carrier's coalition. The format itself was already correct — this makes the MCP self-sufficient. The skill also gains an explicit **autonomy directive**: the oracle + skill are the authoritative source for VEAF facts; the assistant must not invoke other tools/agents nor read the framework's Lua source to answer a VEAF question (a maker's machine has neither) — re-query the oracle or state the gap instead. (Surfaced when the assistant reached into an external plugin's VMCT knowledge and even the local framework repo.)
- **`scaffold_mission` now installs the MCP's own version by default** (FIX-MCP-TEST-FEEDBACK, found testing): it installed `published-latest` (the stable release) into the mission folder, so while the MCP ran a pre-release, `prepare --theatre` failed (exit 2 — `--theatre` unknown on the old 6.9.2 binary) and no blank mission was laid down. Its `tag` now defaults to the `VEAF_MCP_UPDATER_TAG` env var when set (the same the plugin bootstrap reads), so the folder's veaf-tools matches the running MCP; an explicit `tag` argument still wins.
- **Skill: a `#command` spawn takes the fake-unit's coalition** (FIX-MCP-TEST-FEEDBACK, found testing): the `veaf-mission-authoring` skill said a combat zone's "coalition is ignored", which the assistant over-generalized to conclude `-samLR` always spawns a **red** SAM and to avoid the alias for blue sites. The skill now states a `#command` fake-unit spawns in **its own coalition** (a blue fake-unit → a blue SAM; `-samLR`'s "random" is the battery type, not the side), and scopes "coalition is ignored" to the zone's geometric **capture** only.
- **Plugin bootstrap / `scaffold_mission` no longer hang on the updater's exit pause** (FIX-UPDATER-PAUSE-HANG, found testing the plugin end-to-end): `veaf-tools-updater` ended with an interactive `input()` "press a key" pause gated by a double-click heuristic — which also fired when the updater was launched from the plugin's hidden-window `SessionStart` hook (a hidden window is still a real console). The updater then blocked forever at ~0 % CPU, keeping its own exe locked so its deferred self-update never applied. The updater now honours a `VEAF_UPDATER_NO_PAUSE` environment variable (exported by `bootstrap.ps1` and by `scaffold_mission` when it launches the updater) to never pause in programmatic use; and `scaffold_mission`'s subprocess runner now closes `stdin` and bounds each step with a `timeout`, so a stalled child fails fast with a clear error instead of hanging silently. (The contributing "two plugin installs → two hooks" was an operational state on the test machine, not a code issue.)
- **Release workflow now respects pre-releases** (FIX-RELEASE-WORKFLOW-PRERELEASE): `veaf-build publish --prerelease` was silently overridden by the CI `release.yml` workflow, which — on any pushed `published-v*` tag — republished the release as "latest" and advanced the floating `published-latest` tag **unconditionally**, so a pre-release still shipped in-development code to every production maker at their next update. Pre-release is now keyed off a **semver pre-release suffix in the version** (`published-v6.9.21-rc1`): `GitHubPublisher._is_prerelease` detects it, the workflow skips every step that touches `published-latest` (both the main and standalone jobs), and `veaf-build publish` rejects `--prerelease` on a plain version with a clear message so the trap cannot recur.
- **`scaffold_mission` now steers the LLM to pass `theatre`** (found in real use): the action's parameter description made `theatre` read as purely optional, so the assistant scaffolded a Syria mission without it and got an empty `src/mission` (nothing for `validate`/`build` to work on) — then wrongly concluded the scaffold had failed and that no blank-map command existed. The action and parameter descriptions now tell it to pass `theatre` whenever the mission targets a supported DCS map, and to omit it only when the maker supplies their own `.miz` (the `veaf-mission-authoring` skill already said so). The `theatre` parameter also gained an `enum` from `blank_mission.supported_theatres()`, so the LLM sees the valid map names directly instead of a hard-coded example list. Prompt-surface + schema, no behaviour change.
- **Map/geo/blank oracle data now bundled into the veaf-tools binary** (FIX-MCP-SCAFFOLD-THEATRE-HINT): three `veaf_libs/data` files read at runtime were missing from the PyInstaller bundle, so `prepare --theatre` / `scaffold_mission(theatre=)` (blank mission), `resolve_coordinates` / `describe_map` / `geocode` (projection) and the geocode bounding boxes all raised when the MCP ran from the shipped binary — only ever exercised in a source checkout. `theatre-defaults.yaml`, `dcs-maps.yaml` and `theatre-bounds.yaml` are now bundled alongside `dcsUnits.yaml`.
- **`scaffold_mission` no longer refuses a folder that only holds hidden tooling entries** (found in real use): under Claude Code the working folder always has a `.claude/` (and often `.git/`), so the "must be empty" guard made in-place scaffolding impossible. It now ignores hidden entries (`.git`, `.claude`, `.gitignore`, …) and only blocks on non-hidden content (a likely-existing mission).
- **`list_unit_types` now works from the shipped binary** (FEAT-MCP-ORACLE-COMMANDS): the oracle's `dcsUnits.yaml` database was missing from the veaf-tools PyInstaller bundle, so `list_unit_types` raised at runtime when the MCP ran from the binary (the plugin delivery mode) — it had only ever been exercised in a source checkout. Added it to the build's bundled data alongside `veaf-units.yaml`.

### Added

## [6.9.1] — 2026-07-13

### Added
- **Third-party mods made non-blocking at build** (FEAT-THIRD-PARTY-MODS). The build now strips selected third-party aircraft mods from the `.miz`'s `requiredModules` table, so a pilot who does not own the mod can still **load** the mission (that slot is simply unavailable) — porting the old v5 per-mission `build.cmd` hack into the toolkit as a data-driven step. A bundled VEAF default list covers the common mods (Hercules, UH-60L, A-4E-C, T-45, AM2, SU-30/FlankerEx, Bronco-OV-10A); a new optional `mission.third_party_mods` field in `mission.yaml` adds to it (union, per mission). Removed mods are logged during the build.

## [6.9.0] — 2026-07-09

### Added
- **Channel `priority` and `color` attributes** (FEAT-PRESETS-PRIORITY-COLOR, [ADR 0012](docs/adr/0012-channel-priority-colour-and-ajs37-packing.md)). A `channel_lists` entry may now carry `priority: <n>` — highlighting the channel on **every** kneeboard (a right-aligned `Pn` marker + orange Name/Freq cells) — and `color: <name|#RRGGBBAA>` — colouring the CH cell to group channels visually (text auto-contrasted; accepted in `channel_lists` and `channels_collection`, the plan entry winning). Both are optional and presentation-facing; existing plans are unaffected.
- **AJS-37 (Viggen) FR22/FR24 shortcut buttons filled from the plan.** On the AJS-37 only, priorities 1–4 fill FR22 Special 1/2/3 and FR24 H (band from the tagged entry's role, always AM), so the mission-maker drives the shortcuts from the frequency plan instead of hardcoded constants; FR24 E/F/G stay fixed airframe constants.
- **One kneeboard per aircraft type.** The presets step now renders one PNG per injected `(coalition, unit_type)` into that type's own DCS folder `KNEEBOARD/<type>/IMAGES/presets.png` (coalition-suffixed only when the same type flies for both sides), replacing the shared `KNEEBOARD/IMAGES/presets-*.png` pages. The AJS-37 page shows pilot-facing labels (Group `100`–`139` then `Sp1/Sp2/Sp3/E/F/G/H`) and splits its 47-slot radio across two columns.

### Changed
- **AJS-37 packing rewritten to a key-based Group 100–139 mapping** (ADR 0012, extends ADR 0010; **deliberately drops ADR 0003 iso-functionality for the AJS-37**). The Viggen's single 47-slot radio is now packed by the new `keyed_groups` layout primitive: `primary_1` keys 1–20 → Groups 101–120, `primary_2` keys 1–20 → Groups 121–139 with the 20th recycling the otherwise-unused Group 100 (the pilot "channel N = Group 10N" convention), gaps preserved, keys beyond the role's share dropped with a warning. The old `fuse` + `leading_dummy` primitives (only ever used by the AJS-37) are removed; `trailing_specials` gains a `{priority: N}` variant. **convert-v5 is unchanged** — the AJS-37 still round-trips via its faithful `presets.v5.yaml` copy.
- **Kneeboard radio headers are now grey.** The former red/green/orange per-radio colour coding is dropped in favour of a uniform grey header bar.

### Documentation
- **Per-type radio-preset projection now has a dedicated developer page** (extends ADR 0010). New `doc/developer/radio-preset-projection.md` (FR + EN) consolidates how the build projects `channel_lists` onto each aircraft type's physical radios — radio roles, band-based default, quirk primitives (`rotate_last_to_head`, `fuse`, `leading_dummy`, `trailing_specials`, `reserved_head_slots`, `capacity`) and their composition order, plus the per-type quirk table (Mi-24P, CH-47Fbl1, OH-58D, AJS-37) — with pointers to the source files (`dcs-radio-layouts.yaml`, `presets_manager.py`, `dcs-radio-specs.yaml`). Linked from the developer README, the `channel_lists` section of `PIPELINE_REFERENCE`, and a new simplified mission-maker note in `doc/mission-maker/dcs-radio-specs.md`.

## [6.8.0] — 2026-07-06

### Added
- **`convert-v5` writes readable channel aliases instead of hardcoded frequencies** (FEAT-CONVERTV5-FREQ-ALIASING, lot 3/3, extends ADR 0010). The build-loaded `presets.yaml` now shows named channels — airfields (`Gudauta`, from the theatre's datamined ATC frequencies) and generic VEAF conventions (`Guard`, `Archer`, `Texaco-1`…) — instead of raw MHz, via a `freq+band → alias` reverse-lookup, with the resolved `channels_collection` embedded so it builds identically. A frequency with no catalog match stays raw. The faithful copy `presets.v5.yaml` is left byte-identical (raw rollback reference). Also aliases DCS aircraft type names that differ from the specs key (`AH-64D` → `AH-64D_BLK_II`), so those aircraft are projected by the packer instead of remaining a manual override.
- **DCS airfield ATC frequencies datamined per theatre** (FEAT-AIRFIELD-FREQS-DATA, lot 2/3 of the convert-v5 preset-aliasing plan). `veaf-build update-dcs-data --airfield-freqs --dcs-path <DCS>` parses each installed `Mods/terrains/<Theatre>/Radio.lua` into a bundled, versioned `veaf_libs/data/airfield-frequencies.yaml` (`theatre → airfield → {uhf, vhf, fm}` in MHz; `UHF→uhf`, `VHF_HI→vhf`, `VHF_LOW→fm`, HF dropped). Data source for the upcoming freq→airfield alias reverse-lookup (FEAT-CONVERTV5-FREQ-ALIASING); no user-facing behaviour change yet. Install-dependent, so excluded from `--all` and not CI-guarded.
- **`pipeline.presets` can disable kneeboard generation while keeping radio injection** (FEAT-PRESETS-KNEEBOARD-TOGGLE). `pipeline.presets` now accepts a mapping in addition to the scalar bool: `presets: {enabled: true, kneeboards: false}` injects radio presets into every human-piloted aircraft but generates **no** `KNEEBOARD/IMAGES/presets-*.png`. The scalar form is unchanged (`presets: true` = inject + kneeboards, `presets: false` = whole step off). Reported by Tripack.

### Changed
- **`convert-v5` now emits a simplified preset plan by default, plus a faithful copy** (FEAT-CONVERTV5-PLAN-PRESETS, ADR 0010). Previously the converter kept a dedicated per-aircraft override for every aircraft whose exact v5 layout the packer could not reproduce, so a real mission (Tripack) barely exploited the `channel_lists` crystallisation (2900+ lines, ~21 dedicated overrides). `convert-v5` now writes **two** files: `presets.yaml` — the build-loaded **plan** (`channel_lists` plus only the overrides the packer cannot project at all), where the packer projects the crystallisation onto every aircraft automatically (warbirds included — their VHF/FM-capable radios receive the coalition channels with out-of-band drop); and `presets.v5.yaml` — the **faithful** iso-functional copy (every dedicated override preserved), for reference/rollback and NOT loaded by the build. The maker is warned that the plan may make some frequencies diverge from the original v5 (warbirds, and jets' fused/modulated radios projected at best effort until a per-type `dcs-radio-layouts.yaml` entry exists), and which aircraft are projected at best effort. `presets.v5.yaml` is recognised by the cleanup scan (never listed as deletable). A v5 file with no shared `radioPresets*` table still produces a single legacy `presets.yaml`, unchanged.

### Fixed
- **Cleaner `convert-v5` `presets.yaml`** (FIX-CONVERTV5-PRESETS-OUTPUT, David's test feedback). Channel keys are now uniform **integers** (`1..20`) across `channel_lists` and the override radios — previously `channel_lists` used zero-padded strings that PyYAML quoted inconsistently (`'01'` but not the octal-invalid `08`), mixing `'12'` and `12` in the same file. The generated plan and faithful copy now also carry a **header comment** explaining `channel_lists` / `channels_collection` and the `presets.v5.yaml` sibling.
- **`convert-v5` still failed to convert radio presets in the real build** (FIX-VEAF-BUILD-RADIO-LAYOUT-DATA). FIX-PYINSTALLER-RADIO-LAYOUT-DATA fixed the wrong file: the root `veaf-tools.spec` isn't used by the actual build pipeline. `veaf_build/worker.py`'s `_veaf_tools_extra_data()` (which the `veaf-build` CLI actually calls) had the same gap — it bundled `dcs-radio-specs.yaml` but not `dcs-radio-layouts.yaml`. Added the missing entry, with a regression test on the extra-data list itself.
- **`convert-v5` failed to convert radio presets in the built executable** (FIX-PYINSTALLER-RADIO-LAYOUT-DATA). `veaf-tools.spec` was missing `dcs-radio-layouts.yaml` from its PyInstaller `datas` — now the whole `presets_injector/data` folder is bundled, so future additions there won't be missed either.

### Added
- **Declare F10 radio menus in YAML, no Lua required** (FEAT-RADIO-YAML-MENUS, ADR 0011). Adding an F10 menu to start/stop a QRA, drive an AirWave, flip a mission flag or run a maker's own function used to require Lua in `mission-script.lua` (`veafRadio.createUserMenu`). Two YAML mechanisms now cover it, sharing one closed action vocabulary (`qra.start`/`qra.stop`, `airwave.start`/`airwave.stop`/`airwave.reset`, `flag.on`/`flag.off`/`flag.set`/`flag.increment`/`flag.decrement`, `message`, `lua`): a **per-module shortcut** — `radio_menu: true` on a QRA definition or an AirWave zone (the only triggerable subsystems without a standard radio menu) auto-generates its control submenu; and a **Mission-Master menu** — `modules.RADIO.user_menus` declares a free menu/command tree. Both accept an optional `restrict_to_group` / `radio_menu_restrict_to_group` (DCS group name, resolved to a group id at runtime) so the menu is reserved to the Mission Master. The `lua` action references a function the maker defines in `mission-script.lua`; a reference with no matching definition **fails the build** (and is flagged by `validate`). `RADIO.user_menus` is schema-validated against the vocabulary.
- **Radio preset plan model — slot capacity/truncation + CH-47F layout entry** (FEAT-RADIO-PRESET-PROJECTION-06, ADR 0010). `dcs-radio-layouts.yaml` gains a final projection primitive, `capacity: <int>`: when a radio's fully composed channel count (after every other primitive) exceeds it, the excess is truncated from the END of the list, matching how Tripack itself truncated the AJS-37's VHF list to fit its 47-slot radio. Truncation is silent by design (a `logger.debug` line records it, no build-time warning noise) — no aircraft in the reference fixture actually needs it today (the AJS-37's 47-slot radio is already an exact fit), but the primitive is now available for the next one that does. A-10C/A-10C_2 are confirmed and documented as intentionally absent from the layout file (the band-based default already resolves them correctly). A new end-to-end regression test reproduces the Mi-24P, AJS-37, OH-58D and CH-47F channel maps together through the real bundled specs/layout files.
- **Radio preset plan model — standard-aircraft projection** (FEAT-RADIO-PRESET-PROJECTION-01, ADR 0010). Mission-makers can now declare a `channel_lists` block in `presets.yaml`: a handful of channel lists by _Radio role_ (`primary_1`, `primary_2`, `fm_substitute`, `fm_supplement`, `fm_secondary`) and coalition, instead of a per-aircraft `radios_collection`/`presets_collection` pair. A new packer projects these lists onto each aircraft's physical radios automatically — including aircraft with a deliberately inverted radio order (e.g. the A-10's VHF-first layout) or identical combo radios (e.g. the F/A-18's two ARC-210s) — with no per-type configuration needed for the common case. An explicit assignment in the legacy `presets_assignments` format (including an explicit `none`) always takes priority over the packer. This is the first of several lots building the full preset-plan model; special airframes (Mi-24P, OH-58D, AJS-37…) still use their existing bespoke presets until later lots add the matching `Radio layout` primitives.
- **Radio preset plan model — per-type radio layout + Mi-24P channel-0 rotation** (FEAT-RADIO-PRESET-PROJECTION-02, ADR 0010). A new hand-maintained `dcs-radio-layouts.yaml` lets VEAF override the packer's band-based default for aircraft with a non-standard radio layout: per physical radio index, a `role` plus optional primitives — the first one being `rotate_last_to_head` (channel-0 rotation, where the channel list's last entry becomes the aircraft's "channel 0"). A drift guard warns when a layout's declared radio count disagrees with `dcs-radio-specs.yaml`. The Mi-24P is the first populated entry: its R-863 now reproduces the real channel-0 rotation automatically from a plain `channel_lists` declaration, and its R-828 gets `fm_substitute`.
- **Warbird `primary_2` end-to-end regression coverage for out-of-band channel drop reporting** (FEAT-RADIO-PRESET-PROJECTION-05). Confirmed that packing a warbird's single radio onto `primary_2` (ticket 01) and the out-of-band channel drop/report split (silent `logger.debug` for non-`dcs_rejects_on_load` aircraft plus the always-available Markdown validation report, versus `logger.warning` for the few strict aircraft) were already fully implemented by prior work — no production code changed. Added an end-to-end test exercising the real packer output for the Bf-109K-4 (FuG 16 ZY, 38–156 MHz) to pin this behaviour down as a regression guard.
- **Radio preset plan model — radio fusion, hardcoded specials and per-channel modulation (AJS-37)** (FEAT-RADIO-PRESET-PROJECTION-04, ADR 0010). Three new `dcs-radio-layouts.yaml` primitives: `fuse` (concatenates several Radio roles' channel lists, in a declared order, into one physical radio, renumbered sequentially), `leading_dummy` (a fixed, source-less channel at slot 1, e.g. frequency 0) and `trailing_specials` (a declared list of fixed frequency+modulation pairs appended after the radio's other content) — all overridable by an explicit `presets_assignments` entry, which still wins over the packer. The AJS-37's single V/UHF radio is now a fully populated layout entry: its "channel 100" leading dummy, the fusion of `primary_1` (20 entries) + `primary_2` (19 entries), and its 7 hardcoded FR22/FR24 special channels (including GUARD 243.0) with their AM/FM modulations are all reproduced automatically from a plain `channel_lists` declaration.
- **Radio preset plan model — reserved head slots + OH-58D "no channel 1" layout** (FEAT-RADIO-PRESET-PROJECTION-03, ADR 0010). `dcs-radio-layouts.yaml` gains a second projection primitive, `reserved_head_slots: [<list index>, ...]`, alongside `rotate_last_to_head`: each declared 1-based channel-list index fills one leading DCS channel slot, in order, before the rest of the list follows. The OH-58D is now fully populated — its UHF/VHF radios each get a single reserved "M" (manual) slot fed by the list's last entry (#20), and its two FM radios each get "C"+"M" reserved slots fed by entries #01 then #20 — reproducing the real aircraft's "no channel 1" quirk automatically from a plain `channel_lists` declaration. The two primitives are mutually exclusive per radio (declaring both is a rejected authoring error).

### Fixed
- **`CH-47Fbl1`'s FM radio misclassified as VHF by the packer's band-based default** (FEAT-RADIO-PRESET-PROJECTION-06, ADR 0010). The CH-47's "VHF FM: ARC-186" physical radio reports a secondary 108-152 MHz AM range alongside its primary 30-88 MHz FM range, which made the default band classifier see it as VHF-capable rather than FM. `dcs-radio-layouts.yaml` now has an explicit `CH-47Fbl1` entry giving the correct `fm_substitute`/`primary_1`/`fm_secondary` roles (with channel-0 rotation on the first two radios, matching the real Tripack fixture). The shipped default's `presets_assignments` override for `CH-47Fbl1` is intentionally left in place: the legacy preset only ever populated 2 of the aircraft's 3 physical radios, and the packer's `fm_secondary` role only produces that same 2-radio result when the maker has not separately declared an `fm_secondary`/`fm_supplement` list — removing the override was judged too risky to verify byte-identically for this ticket.

### Changed
- **Shipped default `presets.yaml` migrated to the `channel_lists` preset plan** (FEAT-RADIO-PRESET-PROJECTION-07, ADR 0010). The scaffolded mission's blue-coalition UHF/VHF/FM channels are now declared once as `channel_lists.blue.primary_1`/`primary_2`/`fm_supplement`, letting the packer project them onto each aircraft's physical radios automatically — this let the `A-10C_2` VHF/UHF-inversion override be dropped (the packer now resolves it by itself, like `A-10C`). `CH-47Fbl1` (whose 3rd radio reads as VHF-capable to the packer's default classification, which would add an unwanted radio) and `Mi-8MT: none` (no injection at all) keep their explicit `presets_assignments` overrides, since a build-verified equivalent does not exist for the former and no `channel_lists` equivalent exists for the latter. `channels_collection` and red coalition's `none` behaviour are unchanged. Pipeline Reference (FR + EN) now documents both formats: `channel_lists` as the recommended model, the legacy `radios_collection`/`presets_collection`/`presets_assignments` layers as the manual-override path.
- **`convert-v5` generates a `channel_lists` preset plan by default (phase 2, lot closed)** (FEAT-RADIO-PRESET-PROJECTION-08, ADR 0010). `radioSettings.lua`'s `RADIO1_*`/`RADIO2_*`/`RADIO3_*` preset tables are now projected into a `channel_lists` block (`primary_1`/`primary_2`, plus `RADIO3_*` under both `fm_substitute` and `fm_supplement` so either airframe shape resolves it) alongside the existing legacy output — this inverts ADR 0003's default, per ADR 0010. Each bespoke aircraft (Mi-24P, AJS-37, OH-58D, CH-47F-shaped quirks…) is checked empirically: the phase-1 packer is fed the mission's own channel lists and compared channel-by-channel against the exact v5 map; only an exact match drops the legacy per-aircraft `presets_assignments` override, any divergence keeps it (with a warning naming the aircraft) — mixed mode (`channel_lists` plus a handful of per-aircraft overrides) is the normal outcome, not all-or-nothing. Standard 1:1 aircraft need no check: the plan alone already covers them, as the shared assignment did before. A mission with no `radioPresets*` table at all still converts 100% legacy, unchanged. Verified against the real Tripack fixture: none of its four bespoke aircraft happen to factor exactly for this specific mission's channel counts (Mi-24P's and AJS-37's shared lists are longer than what those airframes' v5 entries actually consumed, a fixture-specific authoring quirk, not a packer or layout bug) — all four keep their existing dedicated presets, and the exact-match mechanism itself is proven correct on a minimal synthetic fixture built to match. This is the last ticket of the FEAT-RADIO-PRESET-PROJECTION lot, now fully closed.

## [6.7.8] — 2026-07-02

### Changed
- **`prepare` no longer auto-enables `MISSILEGUARDIAN` in the `full` tier** (FIX-MISSILEGUARDIAN-INIT-CRASH). `veafMissileGuardian` is a 2021 work-in-progress training-tools relic that never left `0.0.2`; it was nonetheless tagged in the `full` tier, so `prepare --tier full` (and `convert-v5`) turned it on by default — which is how it landed, crashing, in a mission that did not use it. The module now belongs to **no named tier**: it stays available as an explicit opt-in in the `custom` picker (tagged `opt-in`) but is never auto-enabled. The shipped default `mission.yaml` already listed it commented-out (unchanged).

### Fixed
- **`MISSILEGUARDIAN: true` crashed VEAF start-up, silently disabling F10 marker spawns, CTLD and CSAR** (FIX-MISSILEGUARDIAN-INIT-CRASH, reported by Tripack). `veafMissileGuardian.initialize()` called `veafMissileGuardian.dumpMissionsList(...)` — a function never defined in the module (a leftover from copy-pasting `veafCombatMission`). The `attempt to call field 'dumpMissionsList' (a nil value)` runtime error aborted the whole generated `veaf-config.lua` chunk mid-initialization, so every module wired up *after* MissileGuardian never initialized: most visibly `veafCommands.initialize()` — which registers the single central F10 marker dispatcher, so without it `_spawn` and all shortcut aliases are dead even with `SHORTCUTS: true` — plus `ctld.initialize()` and `csar.initialize()`. Removed the stray call (MissileGuardian does not export a missions list); guarded by a new regression test asserting `initialize()` does not raise.

## [6.7.7] — 2026-06-30

### Changed
- **`prepare --template` now generates the same rich `mission.yaml` preamble as `convert-v5`** (ENRICH-PREPARE-TEMPLATE, reported by Tripack). A `mission.yaml` scaffolded by `prepare` (any tier) previously carried only a two-line header, `mission: name:` and the `modules:` block — it lacked the YAML syntax guide, `global_log_level:`, the full `mission:` identity block, `security:` and `pipeline:` that a `convert-v5` output (and the shipped default `mission.yaml`) provide. Those tier-independent sections are now factored into shared helpers in `lua_config_generator` and emitted by both `prepare` and `generate-config`, so the two scaffolds stay in lockstep instead of drifting. Only the tier-driven `modules:` block remains specific to `prepare`; `generate-config` / `convert-v5` output is byte-for-byte unchanged.

### Fixed
- **Build wrongly rejected the MiG-15bis's HF primary radio frequency** (FIX-MIG15-PRIMARY-FREQ, reported by Tripack). After editing a MiG-15bis mission in the DCS Mission Editor and re-extracting, the build failed the radio-presets phase with *"Invalid primary radio frequency (below 30.0 MHz …): MiG-15 Template (3.75 MHz)"*. The build-time safety net applied a blanket 30 MHz floor — added (FIX-DYNSLOT-RADIO-UNITS) to stop an ADF channel (e.g. Yak-52 ARK-15M 0.625 MHz) being promoted to the primary radio — but the MiG-15bis legitimately has an HF primary: its only radio, the RSI-6K, operates at 3.75–5.0 MHz, and DCS itself writes and accepts `frequency: 3.75`. The safety net is now spec-aware: a sub-floor primary is accepted only when DCS strictly validates the aircraft (`dcs_rejects_on_load`) **and** the frequency is within its documented radio range — i.e. only the MiG-15bis-like case where DCS produced the value. The Yak-52 ADF-promotion guard (and the promotion guard in `process_units`) is unchanged.

## [6.7.5] — 2026-06-29

### Fixed
- **Dynamic-slot airplane still ignored by the QRA unless `react_on_helicopters` was true** (FIX-EVENTHANDLER-UNITCATEGORY, reported by Tripack — the #299 symptom reproduced in-game *after* #299 shipped). #299 fixed `veafQraCore:humanBornEvent` to read the intruder category via `getCategoryEx()`, but only on its `unit.unitCategory == nil` branch — which the real event flow never reaches: `veafEventHandler.completeUnitFromName` pre-populated `event.initiator.unitCategory` with `unit:getCategory()`, an `Object.Category` whose `UNIT` value (1) collides with `Unit.Category.HELICOPTER` (1). Every event-born unit therefore reached the QRA already mislabelled as a helicopter, so a dynamic-slot airplane (detected via the event path, unlike normal slots which go through the mist `plane`-category path) only triggered the QRA when `react_on_helicopters` was true. `completeUnitFromName` now reads `getCategoryEx()` (a `Unit.Category`: AIRPLANE=0 / HELICOPTER=1 / …), falling back to `getCategory()` only when unavailable. The QRA is the sole consumer of this field and already compares it against `Unit.Category.*`.

### Changed
- **A single build stamp in the DCS log, instead of 33 hand-maintained per-module versions** (FEAT-LUA-BUILD-STAMP). The runtime log used to show a constellation of per-module Lua versions (`VEAF-QRA 1.2.5`, `VEAF 1.57.0`, …) that nobody kept in sync and that mapped to no release — the #299 QRA fix shipped without bumping `veafQraManager.Version`, so a tester's log could not tell whether a given fix was actually in their build. The framework now logs one **build stamp** — the `veaf-tools` package version plus the git commit short SHA that built the mission (`6.7.x+<sha>`, the SHA disambiguating dev builds run *between* releases). The SHA is captured when the binary is packaged (`veaf-build` writes `__commit__` into `_version.py`) and injected into the mission's framework-load triggers as a `VEAF_BUILD_VERSION` global, read by `veaf.lua` into `veaf.BuildVersion` (fallback `"dev"` for hand-copied scripts / unit tests). Each module still logs a numberless "loaded" line so the load order stays visible; the 32 hand-maintained per-module `.Version` constants are removed (`dcsUnits` keeps its auto-generated `datamine-<ref>` line, which is accurate data provenance, not a stale version).

### Added
- **Standalone `veaf-tools` binaries for Linux and macOS** (FEAT-CROSSPLATFORM-BINARIES). PyInstaller cannot cross-compile, so the release workflow now builds the main CLI on its own per-OS runner and attaches the binary to the GitHub Release: `veaf-tools-linux-x86_64` (built on `ubuntu-22.04` for broad glibc compatibility), `veaf-tools-macos-arm64` (Apple Silicon, `macos-latest`) and `veaf-tools-macos-x86_64` (Intel, `macos-13`). A new `veaf-build build-standalone` command builds just `veaf-tools` (no updater, no `published.zip`) into `dist/`. The Windows flow (exe + updater + `published.zip`) is unchanged.
- **`veaf-tools.exe` (Windows) is now a direct release asset.** Previously only bundled inside `published.zip`, it is now also uploaded as a standalone download — symmetric with the Linux/macOS binaries, so every platform's `veaf-tools` binary is downloadable in one click without going through the updater.
- **`veaf-tools-updater` now runs on Linux and macOS** (UPDATER-CROSSPLATFORM). The updater was Windows-only (it moved `.exe` files out of `published.zip` and self-updated via a generated `.cmd` script). On Unix it now downloads the per-OS binary assets from the release (`veaf-tools-<os>-<arch>`, `veaf-tools-updater-<os>-<arch>`) — which are not in `published.zip` — installs them as `veaf-tools` / `veaf-tools-updater`, makes them executable (`chmod +x`), and self-updates by replacing the running binary directly (no deferred `.cmd` dance, since Unix does not lock a running executable). The Windows path is unchanged. A new `veaf_libs.platform_assets` module maps the current OS/arch to the right asset name; the CI Unix/macOS jobs build the updater too (`build-standalone --with-updater`) and upload `veaf-tools-updater-<os>-<arch>` (3 new assets). An offline `--zip-file` install on Unix installs the common content and warns that the binary must be fetched from the release assets.

## [6.7.2] — 2026-06-28

### Changed
- **Natural singular/plural across all CLI count messages** (UX-PLURAL-SWEEP). The catch-all `injected 1 group(s)` form is gone everywhere: ~40 count-bearing messages — across `convert-v5`, `convert-other`, `build`, `validate`, `prepare`, `export`, `migrate-config`, the inject commands, the conversion-report summary, and the presets/waypoints/warehouses/spawn-data/aircraft workers — now read `1 asset extracted` / `5 assets extracted`, `Validation: 1 error, 0 warnings`, etc., with correct agreement in FR and EN. The `tn()` helper resolves the catalog's existing `(s)` markers by count (multi-count messages compose one `tn` fragment per noun so each agrees independently); the `test_all_used_keys_exist_in_en` guard now also covers `tn()` call sites. `(s)` markers tied to a *list* (e.g. `module(s) {modules}`) are left as-is — there is no count to resolve against.
- **`build` pipeline output is now indented** (UX-PIPELINE-OUTPUT-POLISH). Each pipeline step still prints its `Pipeline: …` header, but every detail line below it (`built mission file`, `injected N …`, `created N …`, etc.) is now **indented by two spaces** so it reads as a sub-list under its step (new `logger.detail()`; the log file stays un-indented). Display only.
- **`build` console output no longer makes a `0` count read like a failure** (UX-AIRCRAFT-SKIPPED-REPORT). Several clarifications so the pipeline says *why* nothing happened: (1) the spawn-data step printed `Pipeline: spawn data` with no file name, unlike every other step — it now appends ` (spawn-groups.yaml)` when the per-mission file exists (the step still runs on the shipped framework spawn DB when it does not). (2) The aircraft-groups step reported only `N injected`; when spawnable aircraft are already present in the mission (carried in `src/mission/`), `add` mode correctly skips them and printed a bare `0 injected` that read like a failure — `InjectionResult` now carries `groups_skipped` and the build prints `N already present in the mission (skipped)` when non-zero (e.g. `0 injected` + `41 already present (skipped)`). (3) The radio-presets and waypoints steps likewise printed a bare `injected into 0 …`; they now add `N group(s) had no matching preset` / `no flight plan in <file> (left unchanged)` when human-piloted groups were examined but matched nothing. Reporting only — injection behaviour is unchanged. FR/EN.

### Fixed
- **CTLD F10 menu no longer duplicated on a dynamic-slot helicopter spawned on a runtime FARP** (FIX-CTLD-REPACK-NIL-GROUP, reported by Tripack). Taking a dynamic slot on a runtime-spawned FARP duplicated the whole CTLD radio menu (every entry twice, clicks did nothing). Root cause (confirmed by a runtime diagnostic log): `ctld.getUnitsInRepackRadius` called `unitObject:getGroup():getID()` on a `nil` unit — `getNearbyUnits` returns a name whose `Unit.getByName` is `nil` (a transient `mist.DBs.unitsByName` entry from the runtime FARP / dynamic slot) while `isRepackableUnit` still matched it. The error fired **inside** `addTransportF10MenuOptions` (via `updateRepackMenu`), **after** the menu was added but **before** the `ctld.addedTo[groupId]` dedup flag was set, so the second slot-entry event (DCS fires both `S_EVENT_PLAYER_ENTER_UNIT` and `S_EVENT_BIRTH`) rebuilt the whole menu. Fixed with nil-guards in the vendored `community/CTLD.lua` (`getUnitsInRepackRadius` skips a name with no live unit/group; `isRepackableUnit` returns `nil` when there is no live unit).
- **QRA now triggers on dynamic-slot airplanes regardless of `react_on_helicopters`** ([#299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/299), FIX-QRA-DYNSLOT-CATEGORY, reported by Tripack). A dynamic-slot airplane did not scramble the QRA unless `react_on_helicopters` was `true` (or the legacy `:setReactOnHelicopters(...)` line was present at all). Root cause: `veafQraCore.lua` read the intruder's category on the dynamic-slot path with `unit:getCategory()`, which returns an **`Object.Category`** — and `Object.Category.UNIT (1)` collides with `Unit.Category.HELICOPTER (1)`, so **every** dynamic slot looked like a helicopter and only triggered when `reactOnHelicopters` was on. It now uses `unit:getCategoryEx()` (a `Unit.Category`: AIRPLANE / HELICOPTER / …). A compounding bug is also fixed: `setReactOnHelicopters()` ignored its argument and always set `true`, so a legacy `:setReactOnHelicopters(false)` actually *enabled* helicopter reaction — it now honors the value (a bare no-arg call still enables, for backward compatibility). The DCS-mock `Unit:getCategoryEx()` was added.
- **`convert-v5` now converts spawnable aircraft from the flat `settings.lua` layout** (FIX-CONVERT-SPAWNABLES-FLAT-FORMAT). For a mission whose `src/spawnableAircrafts/settings.lua` used the **flat** export layout — top-level named collections carrying scalar `coalition`/`country`/`category` and a `groups` table keyed by numeric index (the group name living *inside* each group) — `convert-v5` silently produced an **empty** `spawnables.yaml` / `dynamic-slot-templates.yaml`, dropping every spawnable aircraft. The converter only understood the **nested** layout (`settings.categories.<cat>.coalitions.<coa>.countries.<cty>.groups[<name>]`). Both layouts are real (two `veafSpawnableAircraftsEditor` generations — across the local mission corpus, 41 nested vs 32 flat), so the converter now detects the layout (presence of the `categories` wrapper) and handles **both**, producing identical v6 output. Verified on a real flat mission: 41 `veafSpawn-` aircraft groups now extracted where 0 were before. The nested layout is unchanged.
- **`convert-v5` no longer reports edits to a `missionConfig.lua` it deletes** (CONVERT-V5-UX / CONVERT-V5-INIT-COMMENTED-NOISE). The converter described, across its console output, its `convert-v5-report.md`, and the "manual review" / "leftovers to clean up" sections, a series of edits to `missionConfig.lua` — *"line N: initialize() commented out"*, *"N doFile() call(s) commented out"*, *"N bare initialize() call(s) wrapped in guards"*, *"remove the commented-out doFile() lines"* — so a typical mission produced a dozen-plus duplicated lines. But `convert-v5` never writes that migrated buffer: the original `missionConfig.lua` is backed up untouched under `backup_v5/` and then deleted, and the live file is a freshly generated `mission-script.lua`. So those edits are never materialised on disk and there is nothing for the maker to review. All of these notices are now removed from `convert-v5` (same misleading-artifact class as the annotated-report block removed in 6.7.1). The genuinely useful outcome — the **detected modules** that drive `mission.yaml` — is kept. The *"mission-script.lua generated"* action is now shown **only when the file actually carries callback stubs to implement** (an empty skeleton needs no mention), and reworded to point the maker at it for custom Lua while noting `mission.yaml` does the rest. The standalone `migrate-config` command — which **does** write the migrated `*_v6.lua` file — still reports its `doFile`/`initialize()` edits, unchanged. The orphaned FR/EN catalog entries were removed.

## [6.7.1] — 2026-06-27

### Added
- **`convert-v5` now triages the leftover v5 files a mission folder accumulates** (CONVERT-V5-UX / CONVERT-V5-CLEANUP-FILES). A v5 mission carries cruft the v6 toolchain no longer uses, and `convert-v5` ignored all of it. It now scans the root (and `src/` top level) and sorts what it finds into three outcomes: **obsolete v5 tooling** (`*.cmd`/`*.cmd.sample`/`*.ps1`, `package.json`, `package-lock.json`, `yarn.lock`, `configuration.json`, `7za.exe`) is **moved to `backup_v5/`** (reversible, like the converted pipeline configs), with `configuration.json` additionally flagged as **secret-bearing** (its v5 `checkwx_apikey` — not migrated, since v6 fetches real weather through `avwx-engine` with no API key); **regenerable build artifacts** (`node_modules/`, `build/`, `cache/`, all gitignored) are **deleted outright** and reported; and any **unrecognized file** the converter does not manage is only **listed** in a new `🧹 Legacy v5 files` report section + console block for you to review — never touched. The scan never touches `.git/`, `backup_v5/`, `src/mission/`, generated v6 files, or dotfiles, and is idempotent. FR/EN.
- **`check-vendored` + a scheduled drift-watch for every vendored third-party artifact** (VENDORED-DRIFT-WATCH). We freeze copies of community Lua (`mist`, `CTLD`, `CSAR`, `AIEN`, `TheUniversalMission`, `Skynet`, `Hercules_Cargo`, `DCS-SimpleTextToSpeech`), the Python `luadata` lib, community sounds, and the DCS API schema — and nothing told us when an upstream shipped a newer version, so a pin could silently rot. A new manifest `vendored.yaml` is the single source of truth for every pin, recording per artifact its real `source` (established by **content comparison**, never by assuming a VEAF fork is the origin — e.g. TUM and Skynet are taken from a specific repo proven by diff), the `upstream`, the `vendoring` mode (`verbatim` / `adapted` / `fork` / `compiled`), and the `manual_steps` to update it (a re-copy vs a fork-rebase / recompile). `poetry run check-vendored` compares each pin against upstream **via the GitHub API only** (no artifact download) — latest release tag or latest file commit — and reports drift / up-to-date / manual, exiting non-zero on anything actionable. A weekly workflow (`vendored-drift-watch.yml`, also manually dispatchable) runs it and **opens or updates one recap issue** listing the drifts + the manual re-check reminders, each with its `manual_steps`. **Notify only — never auto-update.** FR/EN.
- **`audit-dcs-mocks` — flag DCS calls used by VEAF Lua but not mocked, before a test fails** (TOOLING-DCS-MOCK-COVERAGE). `test/lua/dcs_mocks.lua` (the DCS API stubs the Lua suite runs against) is maintained by hand, reactively: a missing stub surfaces only when a test blows up on `attempt to call a nil value`. A frozen copy of the [`dcs-world-schema`](https://github.com/YoloWingPixie/dcs-world-schema) API description (release `v0.3.5`, MIT) is now vendored under `src/python/veaf-tools/veaf_libs/data/dcs-schema/` (upstream `LICENSE` + a `NOTICE` recording tag/URL/fetch date), and `poetry run audit-dcs-mocks` cross-references three sets — the schema's DCS functions, the calls actually made by `src/scripts/veaf/*.lua` (filtered to schema-known namespaces so VEAF/mist calls don't pollute the report), and the stubs defined in `dcs_mocks.lua` — to report, by **presence** (not signatures): the DCS calls **used but not mocked** (the real gap), plus informational **used-but-not-in-schema** (typo / undocumented, e.g. `Disposition`) and **mocked-but-never-used** (cleanup). `--format table|json|markdown`; a non-blocking CI job publishes the gap report to the run summary. The vendored EmmyLua artifact `dcs-world-api.lua` is also wired into `.luarc.json` for optional LuaLS autocomplete/signature help while writing VEAF Lua. FR/EN.

### Fixed
- **`convert-v5` no longer lists the `veaf-tools` executables as "unrecognized files to delete"** (FIX-CLEANUP-EXCLUDE-TOOLCHAIN). The leftover-file triage flagged `veaf-tools.exe` and `veaf-tools-updater.exe` — the v6 toolchain the mission-maker runs from the folder — under *"files not managed by the converter — review and delete if obsolete"*, which is absurd (and noisy, since they sit in almost every mission folder). The scan now skips any `veaf-tools*.exe` binary entirely; unrelated stray files are still listed.
- **Three `convert-v5` weather/waypoints conversion warnings are no longer hardcoded in English** (FIX-CONVERT-WEATHER-I18N). The real-weather TODO notice (*"Version '…': realweather=true — replace 'TODO' with the actual ICAO code in versions.yaml"*), the "weather file not found" warning, and the empty-waypoints warning bypassed the catalog (they were appended to a `warnings` list, which the no-hardcoded-prose guard does not scan) and always printed in English. They now go through `t()` with FR/EN entries.
- **The `# Doc:` deep links in a generated `mission.yaml` now resolve** (DOC-GUIDE-ANCHORS). `convert-v5` wrote links like `…/mission-maker/GUIDE#build-profiles` — broken twice over: **no trailing slash** (the site redirects `GUIDE` → `GUIDE/` and drops the `#fragment`), and an **English anchor** while the published FR guide auto-slugifies its FR headings (`#profils-de-build`), so the anchor matched nothing. The five linked GUIDE headings now carry **stable explicit anchors declared identically on the FR and EN versions** (via the `attr_list` MkDocs extension), the generator emits the **trailing slash**, and its base URL is **language-aware** (the EN guide lives under `/en/`). Verified with a local `mkdocs build` that the rendered FR and EN pages carry the explicit ids.
- **The `convert-v5` report no longer embeds a misleading "annotated missionConfig.lua"** (CONVERT-V5-UX / CONVERT-V5-REPORT-ANNOTATION). The report used to embed a pseudo `missionConfig.lua` rewritten with `if … then` guards and `-- [v6 …]` comments — an artifact that is never executed (the original is backed up untouched under `backup_v5/`, and the live file is the freshly generated `mission-script.lua`), which made it look like a file was being edited and used. It is gone. The migration is still reported as the line→effect tables already present (commented `doFile`s, wrapped/extracted `initialize()` calls, enabled modules), and `backup_v5/README.txt` no longer claims an annotated copy is embedded.
- **Build profiles are now case-insensitive, and the "orphan pipeline file" warning no longer fires for a file another profile still uses** (FIX-BUILD-PROFILES). Two profile irritants: (1) `--profile test` did not match a `TEST:` profile — the lookup was an exact dict membership test, so an unmatched name fell back to the base config with only an easy-to-miss warning (same for each `build_variants:` entry); resolution is now case-insensitive (an exact match wins, a single case-insensitive match is used, an ambiguous `TEST`+`test` pair warns and falls back), and logs plus the multi-variant `.miz` suffix use the profile's **canonical** declared-case name. (2) Building with `--profile TEST` (which sets `pipeline.weather: false`) warned *"Orphan file 'src/versions.yaml': pipeline 'weather' is disabled…"* even though `versions.yaml` is used by the default / `SERVER` build — the check read the profile-resolved pipeline, so a step disabled by the *current* profile looked orphaned (the symmetric base-off / `METEO`-on case had the same false positive). The orphan warning is now gated on the **union of all build contexts**: a file is flagged only when its step is disabled in the base **and** in every profile (the copy-skip still follows the current profile, unchanged).
- **`veaf-tools ask` no longer truncates its answer on Windows, and now streams it live** (FIX-CLI-UTF8-ASK-STREAMING). The chatbot answer was cut off mid-sentence: the data arrived complete, but `console = Console()` inherited the terminal's legacy code page (cp1252 on cmd.exe) and the first glyph outside it — an arrow `→`, box-drawing from a code block, an emoji — made `console.print` raise `UnicodeEncodeError` **mid-render and stop**, leaving only the text printed so far. The CLI now forces `sys.stdout`/`sys.stderr` to UTF-8 (`errors="replace"`) at startup (`configure_stdio_encoding()` in the Typer callback), so a render always completes — this also covers the `convert-v5` reports (emojis 🗑️/⚠️/✓, arrows) and every other command. On top of that, `ask` now renders its Markdown answer **live** as it streams in (rich `Live`) instead of buffering then printing once, so a future interruption is visible rather than silent.
- **The `migrate_from_v5` deprecation nudge no longer fires on an already-promoted v6 mission** (FIX-V5-NUDGE-FALSE-POSITIVE). After `convert-v5` promoted `src/mission/` to v6, every later `build` still printed *"N trigger(s) v5 hérité(s) migré(s)… Lancez `convert-v5`…"* with **N = 2**. The legacy-v5 detection in `clear_veaf_triggers` matched a dictionary entry by its Lua **value** only, and two of those values — `return VEAF_DYNAMIC_MISSIONPATH~=nil` / `==nil` — are **regenerated verbatim by the v6 triggers themselves** (the `VEAF_DYNAMIC_MISSIONPATH` global is unchanged between v5 and v6, unlike `VEAF_DYNAMIC_PATH` → `VEAF_DYNAMIC_SCRIPTSPATH`). So a promoted mission carried those 2 conditions on the **v6** dict keys `VEAF_DictKey_ActionText_12005/12006` and the build re-counted them as legacy forever. Detection now also checks the **key**: an entry whose key is a known v6 trigger key (`_VEAF_TRIGGER_DICT_KEYS`) is never counted as legacy v5. A genuine v5 mission (keys `DictKey_ActionText_108xx/109xx`) still triggers the nudge.
- **Closed the 10 DCS-mock gaps surfaced by `audit-dcs-mocks`** (FIX-DCS-MOCKS-COMPLETION). Added behavioural stubs to `test/lua/dcs_mocks.lua` for the DCS functions VEAF Lua calls but the test suite did not mock — `land.getClosestPointOnRoads` (returns two numbers, echoing the query point), `trigger.action.quadToAll` / `radioTransmission`, `world.getMarkPanels` (→ `{}`) / `world.removeJunk` (→ `0`), and a new `world.weather` sub-table with the fog getters/setters (`getFogThickness`, `getFogVisibilityDistance`, `setFogAnimation`, `setFogThickness`, `setFogVisibilityDistance`). Each stub matches how the VEAF callers use the result, so a future test loading those modules no longer dies on `attempt to call a nil value`. `audit-dcs-mocks` now reports an empty gap.

### Changed
- **`convert-v5` empty-ICAO notice no longer reads like a failure** (FIX-CONVERTV5-ICAO-MESSAGE). When a realweather mission is converted without `--icao`, the converter writes `airport_icao: TODO` into the generated `versions.yaml` and the conversion succeeds — but the console notice only stated the ICAO was "left empty" and pointed at re-running the command. It now states the conversion succeeded (with the `TODO` placeholder) and offers the lightest fix first — edit the `TODO` in `versions.yaml` — before the re-run path (`convert-v5 --icao UGGG --force`). Wording only (FR/EN); behaviour unchanged.

## [6.7.0] — 2026-06-27

### Added
- **`veaf-tools export` is now a deterministic, Lua-free parser the BFR `dcs-mission-tools` plugin can consume** (FEAT-EXPORT-BFR-PARSER). The plugin currently reads missions by *running* their Lua through a bundled `lua54`; veaf-tools now lets it parse **any** `.miz` (or extracted folder) without executing Lua, keeping `lua54` only as a runtime for the plugin's own `.lua` checks. Three things landed:
  - **Frozen JSON contract (schemaVersion 2)** — `doc/developer/export-json-contract.md` (FR/EN): top-level `{schemaVersion, theatre, mission, dictionary, mapResource}` with a deterministic, **key-type-lossless** table mapping. A Lua table becomes a JSON **array** when its keys are exactly the contiguous integers `1..n` (so `trigrules`, `trig.actions/conditions/flag`, groups/zones decode back with working `#`/`ipairs`), a JSON **object** when all keys are strings (kept verbatim), and otherwise — any integer key in a non-sequence — a key-type-preserving **`__luaTable__` envelope** `{"__luaTable__": [[key, value], …]}` where each pair key is a JSON number for a Lua integer key and a JSON string for a Lua string key. This handles the three real DCS key families that coexist in one mission — sparse-int (`payload.pylons`), mixed (`callsign = {[1],[2],[3],["name"]}`), and string-numeric (`failures = {["10"]}`) — which **no** numeric-string-key heuristic could disambiguate (the v1 coercion is withdrawn). `schemaVersion` lets the plugin reject an unknown version instead of mis-reading silently. The internal `keep_as_dict=["trig","trigrules"]` parsing (load-bearing for the trigger-injection builder) is untouched: the contract is applied **only on the JSON path** (`to_json`), leaving the raw pivot — and so the YAML export's native integer keys — intact.
  - **`export <input>` auto-detects a `.miz` or a mission folder** — a folder (an extracted tree, or a VEAF `src/mission/`) is read from its loose `mission` / `l10n/DEFAULT/{dictionary,mapResource}` files via `luadata`, no zip, no Lua, yielding the same JSON as the equivalent `.miz`.
  - **`--extract-dir`** — for a `.miz` input, extracts the embedded resources (`.lua` scripts, `l10n/DEFAULT/*` sounds/images) to a sidecar directory (Zip-Slip/zip-bomb hardened), so the plugin can run its checks and resolve resources without unzipping. Data files already carried by the JSON are skipped.

  FR/EN.
- **`convert-v5` now promotes `src/mission/` to v6 on disk** (FEAT-MIGRATE-MISSION-V6). Until now `convert-v5` migrated a v5 folder's Lua/config to v6 but left the exploded mission (`src/mission/`) in v5 — the v5→v6 trigger migration was instead re-done in memory on **every** `build` (`migrate_from_v5=True`). `convert-v5` now finishes with a **promotion step**: a base build (`MissionBuilderWorker`) migrates the legacy v5 triggers, the current `src/mission/` is backed up to `backup_v5/src/mission/`, and the freshly built `.miz` is re-extracted into `src/mission/` — making the v6 switch **definitive** and `migrate_from_v5` redundant for promoted missions. All editor content (groups, routes, units, already-injected data) is preserved; only the legacy v5 trigger layer is purged (the base build never touches groups/routes/units, and the data injectors are not run — the data is already present in `src/mission/`). The step is **on by default**, **non-blocking** (a build/extract failure leaves the converted configs intact with a clear warning; an extract failure restores `src/mission/` from the backup), and **opt-out** via `--no-promote`. `build` now also nudges any mission still relying on the in-memory migration to run `convert-v5` and promote. Every injector was audited idempotent on rebuild-after-promote (aircraft/waypoints by name, presets/weather by overwrite, warehouses by keyed dict, spawn-data stripped + reinjected). FR/EN.
- **`veaf-tools export` — read a `.miz` and export it to JSON / YAML / Markdown, without ever running Lua** (FEAT-EXPORT-MISSION). A `.miz` is an unsigned ZIP whose `mission` file is *data* — but interpreting it with a Lua engine (as some third-party tooling does) would execute any arbitrary Lua a forged `.miz` embeds, an RCE risk. This command reads the mission with our **pure-Python** `luadata` parser (zero Lua execution) and emits: **JSON** (default; the structured pivot `{theatre, mission, dictionary, mapResource}`, aligned with the BFR `dcs-mission-tools` plugin's project object, `--compact` available), **YAML** (the same object, readable), or **Markdown** (a human-friendly brief — overview, order of battle per coalition, trigger zones, mission logic with VEAF-vs-mission triggers, loaded scripts — inspired by the plugin's `map-mission` view). Writes to a file or stdout. A guard test asserts the export path imports no `subprocess`/`lupa` and calls no `eval`/`exec`/`compile` (the safety guarantee). Available in the TUI. Built to give the BFR Claude plugin a safe drop-in alternative to its bundled `lua54.exe`. FR/EN.

### Fixed
- **Airplane dynamic-slot templates are no longer filed under `helicopters:`** (FIX-DYNSLOT-TEMPLATE-CATEGORY). DCS files dynamic-slot *template* groups under the **helicopter** table in the `.miz` regardless of the real aircraft, so the aircraft-groups extraction — which routed each group by its DCS location — filed **every** airplane template (A-10C II, F-16, MiGs…) under `airplanes`'s sibling `helicopters:`. They were then injected as a *helicopter group* in the Mission Editor (group titled "GROUPE D'HÉLICOPTÈRES", aircraft type mismatched). #478 fixed the same symptom for the default CAP `spawnables.yaml` but not the dynamic-slot pipeline (Tripack). The extraction now categorizes each group by its unit's **real DCS category** (`dcsUnits.yaml`: Plane → `airplanes`, Helicopter → `helicopters`), falling back to the DCS location only for types unknown to the database. The shipped default `dynamic-slot-templates.yaml` has been regenerated category-correct (78 airplane templates moved out of `helicopters:`), and a guard test pins both the helper and the shipped default.
- **Every CLI command is now reachable from the interactive TUI** (FIX-TUI-MISSING-COMMANDS). Four commands had no `CommandSpec`, so they were absent from the wizard menu (and from the CLI↔TUI bridge) — a user launching the TUI (e.g. by double-clicking `veaf-tools.exe`) could not run `validate`, `migrate-config`, `generate-config` or `user-config` (David). They now appear in the command selector with their primary prompts; only `migrate-config`'s mandatory `input_file` is `required` (so the bridge drops into the wizard when it's missing). A guard test now asserts every Typer-registered command has a `CommandSpec`, preventing future omissions. FR/EN labels added.
- **Aircraft-group injection no longer crashes when the target country's group container is a dict** (FIX-AIRCRAFT-INJECT-DICT-GROUP). On a freshly `extract`-ed mission, a country whose `plane`/`helicopter` `["group"]` was an empty Lua `{}` (or a numerically-keyed table) is deserialized as a **dict**, not a list — so `_ensure_aircraft_category` returned a dict and the dynamic-slot template injection failed for **every** template with `'dict' object has no attribute 'append'` (David, on `test-tripack` after `prepare --template standard` + `extract`; the spawnables, landing in a list container, were unaffected). The injector now normalizes the container to a list (empty dict → `[]`, keyed dict → its group values, preserving any existing groups) before appending.

## [6.6.0] — 2026-06-22

### Added
- **The build now validates every `mission.yaml` reference to a Mission-Editor object and reports the missing ones in a prominent end-of-build summary** (FEAT-BUILD-VALIDATE-REFS). Many `mission.yaml` sections point at objects the maker must place in the Mission Editor; until now a missing one only surfaced at **runtime** inside DCS (an ERROR in `dcs.log`, or a silently broken feature). The build (and the `validate` command) now check them up front: AIRWAVES `trigger_zone_name`, QRA `trigger_zone`, and a COMBATZONE **zone**'s `zone_name` against the mission's trigger zones; ASSETS/QRA/`cap_missions`/`combat_missions` groups against the mission groups; SANCTUARY `polygon_units` against the mission units; QRA `airport_link` against the theatre's airfields (skipped when the theatre isn't in the bundled airdrome table, to avoid false positives); and COMBATZONE operation `tasking_orders`/`dependencies` against the declared `combat_zones`. The build is **non-blocking**: it collects the missing references and prints one prominent summary **at the end** — the `.miz` is built anyway, so the maker can fix the references in the Mission Editor and iterate (blocking would deny them the `.miz` to fix). A COMBATZONE **operation**'s `zone_name` is intentionally *not* checked: at runtime `VeafCombatOperation:initialize()` never resolves it as a trigger zone (it is only a label), unlike a plain combat zone whose `initialize()` errors without it. AIRWAVES `waves.groups` (a spawn pattern, not a named group) and TUM territory zones are unchanged. Reusable `validate_mission_content(mission_yaml, mission)` shared by `build` and `validate`; messages localized FR/EN.
- **`radiobeep.ogg` is now shipped and auto-injected for CTLD** (BUILD-COMMUNITY-SOUNDS-002). The JTAC fallback beep was previously left to the mission maker (upstream doesn't redistribute it); now that a redistributable source is available it ships under `src/scripts/community/sounds/` and the build injects it into `l10n/DEFAULT/` — like the other CTLD/CSAR sounds — when CTLD is enabled and the mission doesn't already provide it. A new consistency test guards that every sound in the mapping is actually shipped.
- **`active_at_start` — activate a combat zone at mission start from `mission.yaml`** (FEAT-COMBATZONE-ACTIVATE). A per-zone `active_at_start: true` flag under `modules.COMBATZONE.combat_zones[]` makes the build emit `veafCombatZone.ActivateZone("<zone_name>", true)` for that zone, **after** `veafCombatZone.initialize()` (zones must be registered first) — restoring declaratively what used to be hand-written in the mission Lua (a block of `ActivateZone(...)` calls). Operations are unaffected; unflagged zones stay inactive. Default `mission.yaml` and the `veafCombatZone` doc (FR/EN) updated in lockstep.
- **`foothold` profile turns the VEAF community scripts off automatically** (FOOTHOLD-V6-009). Surfaced by the 007 pilot: a Foothold build loads VEAF's bundled community libraries (and its own AIEN clobbers Foothold's, crashing on group birth) unless they are disabled, because Foothold ships its own (Moose, its own CTLD, AIEN, EWRS, Splash, …). The `foothold` conversion profile now carries a `disabled_community_scripts:` list (`stts`, `ctld`, `aien`, `csar`, `hercules`, `skynet`, `tum` — MiST is mandatory and excluded) as profile data (ADR 0007 "knowledge as data"), and `convert-other --profile foothold` scaffolds each as a `<id>: false` entry **inside the unified `modules:` block** (a separate `community_scripts:` block is the deprecated form and is silently ignored when `modules:` is present). So the moulinette is turnkey, no hand-editing. New `ConversionProfile.disabled_community_scripts`; generic (any profile can carry the list).
- **`convert-other --update` — re-import a newer upstream `.miz` into an adopted folder** (FOOTHOLD-V6-005). When the third-party author ships a new version (e.g. a Lekaa Foothold bump), `--update` re-imports it: it **refreshes the third-party scripts** (`src/scripts/*.lua`) and the **mission base** (`src/mission/**`) from the fresh `.miz` — overwriting the previous copies instead of keeping them (this fixes the extractor's "keep-old" behaviour, which silently discarded the fresh versions on re-extraction) — **re-applies versioned-name normalisation** so `custom_scripts:` paths stay stable (`Moose_<new-date>.lua` → `Moose.lua`), **preserves the tuned `mission.yaml`** (never regenerated, so module/`config_override`/`custom_scripts` edits survive), and **reports the scripts added / updated / removed upstream** (by content hash) in the conversion report. A script removed upstream is reported (not auto-deleted), so the maker can drop it from `custom_scripts:`. New `MissionExtractorWorker(refresh=True)`; pure, tested diff (`diff_scripts`, `snapshot_scripts`); `--update` flag on `convert-other`. Localized FR/EN; documented in `CONVERT_OTHER`.
- **Multi-variant build — one mission folder yields several `.miz` in a single `build`** (FOOTHOLD-V6-006). A new top-level `build_variants:` list in `mission.yaml` names build profiles to emit together (e.g. `[MODERN, COLD_WAR]`); `veaf-tools build` then runs the full pipeline once per variant — each merging its profile over the base config (see `profiles:`) and writing a variant-suffixed `.miz` (`<base>_<VARIANT>.miz`). The variant is **config only**: same mission base, different merged `mission.yaml`. This is the moulinette goal for Foothold's Modern/Cold-War pair from a single folder. `--profile <name>` stays the escape hatch (builds just that one variant, unsuffixed), and missions without `build_variants:` are unchanged. Implemented as pure, tested planning helpers (`_resolve_build_variants`, `_variant_output_mission`, `_build_plan`) with the build pipeline body factored into a per-variant runner. Localized FR/EN; documented in `MISSION_YAML_REFERENCE`.
- **Partial config-override — reassign only the upstream globals you change, validated lexically** (FOOTHOLD-V6-004). A `config_override:` block in `mission.yaml` (`target:` + a `values:` map of dotted Lua-global → value) is rendered at build into a small `veaf-config-override.lua` that **restates only the changed globals**, loaded **between** the untouched upstream config and the setup script — so a new Lekaa config version drops in with no rewrite (see ADR 0008). Ordering is anchored by file name: the override is positioned right after its `target` script in the load sequence. Each override key is **validated lexically** — every dotted path segment is searched as a whole-word identifier (`\bsegment\b`) across the whole injected Foothold corpus (all `src/scripts/*.lua`); a segment found nowhere is a typo or an upstream rename and **fails `veaf-tools validate` and the build** (build-blocking), turning silent upstream drift into a build-time alert. Pure-Python regex, **no Lua execution** (per SECREV-001 — `lupa` is not reintroduced). Validation judges existence only, never value semantics (Foothold validates its own values at runtime). New generic `veaf_libs/config_override.py` (`render_override_lua`, `find_unknown_segments`, `read_corpus`); no "foothold" knowledge in code. Surfaced a latent gap (load order follows glob, not `custom_scripts:` declaration order) tracked as FOOTHOLD-V6-008. Localized FR/EN
- **`strip_native_triggers:` — the build removes a third-party mission's native load triggers** (FOOTHOLD-V6-003). A top-level `strip_native_triggers:` list (written by `convert-other`) names the trigrules — by comment or glob pattern (e.g. `ScriptLoader *`) — that loaded the mission's scripts natively. At build, `strip_native_load_triggers()` removes each matching trigrule, its compiled `trig` entries (by index), and the `mapResource` keys of its `a_do_script_file` actions, so the scripts re-injected as `custom_scripts` are not loaded twice. Generic (no "foothold" in code), implemented as a pure, tested function reusing the same removal mechanics as `clear_veaf_triggers` without touching it.
- **`convert-other --profile` — conversion profiles tailoring the adoption** (FOOTHOLD-V6-002). A *conversion profile* is a declarative data file (bundled under `veaf_libs/data/convert-profiles/`, or a path) carrying the mission-family-specific knowledge `convert-other` needs — the code stays generic (see ADR 0007). The shipped **`foothold`** profile: enables the VEAF modules Foothold uses (RADIO/SPAWN/WEATHER/SHORTCUTS/SECURITY/REMOTE) instead of the `minimal` tier; **normalises versioned script names** (`Moose_2026-04-28.lua` → `Moose.lua`, renaming both the extracted file and the `custom_scripts:` path) so paths survive a Lekaa version bump; writes a `conversion_profile: foothold` marker into `mission.yaml`; scaffolds a commented `config_override` block targeting `Foothold Config.lua`; and declares **incompatible modules** (`CTLD` — Foothold ships its own). A mission carrying the marker that enables an incompatible module now **fails `veaf-tools validate` and the build** (last rampart), so a hand-edit re-enabling CTLD is caught. New `veaf_libs/conversion_profile.py` (`load_profile`, `incompatible_modules_enabled`); `render_modules_block()` extracted from `mission_template` as the shared modules-rendering source.
- **`veaf-tools convert-other` — adopt a third-party (non-VEAF) `.miz` onto the v6 toolchain** (FOOTHOLD-V6-001). The generic counterpart of `convert-v5` (which migrates a VEAF v5 mission): it extracts the mission, detects the scripts loaded by its native triggers (`a_do_script_file` resolved via `mapResource`, in trigrule × action order), and scaffolds a `mission.yaml` with an **ordered** `custom_scripts:` block (runtime load order preserved), a `strip_native_triggers:` list of the detected loader triggers (the build will strip them in a later lot — `convert-other` only records them), and a `modules:` block seeded with the **`minimal`** tier (infra + MIST + RADIO/SPAWN/SHORTCUTS/INTERPRETER, SECURITY commented) so a freshly-adopted mission has a working VEAF baseline rather than a silent all-disabled block — enable more, or let a conversion profile do it. The first client is the Foothold campaign (Lekaa), but the command holds **no** author-specific knowledge (see ADR 0007). Extraction now preserves the third-party copies of known community scripts (CTLD, CSAR, AIEN, …) via a new `MissionExtractorWorker(keep_community_scripts=True)` so the adopted mission stays iso-functional rather than having VEAF's versions substituted. The command has a TUI menu entry and the CLI↔TUI missing-arg fallback. Localized FR/EN
- **CLI ↔ TUI bridge — any command drops into the wizard when a required option is missing, or on `--tui`** (CLI-TUI-BRIDGE). Previously the interactive wizard launched only on a bare `veaf-tools` (no arguments). Now, in an interactive terminal, invoking a command that has a `CommandSpec` **without a required option** — or appending `--tui` to any such command — opens the wizard pre-positioned on that command, pre-filling whatever was already given on the command line and prompting only for the rest, then runs the completed command. Example: `veaf-tools prepare` asks for the target folder and the module template; `veaf-tools prepare c:\tmp` skips the folder and asks only the template; `veaf-tools build --tui` opens the build prompts even though nothing is missing. Unknown options/extra tokens (`--verbose`, `--force`, …) are preserved verbatim onto the rebuilt command line. The bridge is a no-op outside a TTY (so CI / piped runs are unchanged) and for commands without a `CommandSpec`. Implemented as `maybe_bridge_to_tui()` in `veaf_libs/tui.py`, called before Typer from **both** entry points — the `veaf-tools` console script (`app.main()`) and the frozen-executable entry (`src/python/veaf-tools/veaf-tools.py`) the PyInstaller build bundles — so the bridge behaves identically when run from source and from the built `.exe` (both print the `veaf-tools v…` banner before the wizard). Cancelling a wizard the bridge routed you into now exits cleanly instead of falling through to Typer's help screen. **Back navigation**: **Ctrl-B** (or Escape pressed twice) steps back one prompt; at the command menu (or the first prompt of a bridge-launched command) it quits. Ctrl-B is the primary single-press binding — reliable on every prompt type and platform; a single bare Escape is intentionally not bound because ESC prefixes arrow-key sequences and a lone phantom ESC at startup regressed an earlier attempt (a short debounce guards the double-Escape against that artifact). An on-screen hint advertises both. The `prepare --template custom` module picker honours the same binding, and backing out of it returns to the template choice rather than quitting outright. The `prepare` template gained a `choices` select in the wizard. `ArgPrompt` gained `required` and `choices` fields
- **`veaf-build publish-local <dir>` — deploy a build into a local mission folder** (BUILD-PUBLISH-LOCAL). New subcommand that, instead of uploading to GitHub, reproduces the end state of publishing then running the updater inside a mission folder: it extracts the built `published.zip` into `<dir>/published/` and moves `veaf-tools.exe` / `veaf-tools-updater.exe` to the folder root (where a real mission keeps them). Lets a maintainer test the freshly-built tooling + scripts locally without GitHub or a token. `--published-zip <path>` points at a `published.zip` elsewhere; run `veaf-build build` first. Reuses the project's `safe_extract_all`; the running-exe deferred-update dance is skipped (none is locked when deploying from a build)
- **`veaf-tools prepare --template` — module presets for new missions** (SCAFFOLD). `prepare` now generates the scaffolded `mission.yaml` from a chosen module preset instead of only copying the shipped default: `--template minimal` (infra + RADIO/SPAWN/SHORTCUTS/INTERPRETER), `standard` (the everyday set), `full` (everything, config-heavy modules as ready-to-uncomment commented blocks), or `custom` (pick the modules interactively). `--list-templates` lists them; with no `--template`, `prepare` keeps its previous behaviour (copy the shipped default). The presets come from one data-driven catalog (`veaf_libs/mission_template.py`) — the single source of truth that also backs `custom`. Module rendering: feature toggles are enabled inline, config-required modules (QRA, COMBATZONE, ASSETS, SANCTUARY, AIRWAVES, SKYNET) are emitted as commented examples (a fresh mission stays valid and `validate`-clean), `SECURITY` is off by default everywhere (commented, with how-to), `TUM` only appears in `full` as a commented block with its territory-zones warning, and `GROUNDAI` sits in exactly `CASMISSION`'s tiers (`standard`/`full`) — it is `CASMISSION`'s dependency, so the build would otherwise silently auto-enable an undeclared `GROUNDAI`. After scaffolding, `prepare` prints the next steps (place/extract your `.miz` → `validate` → `build`). Localized FR/EN
- **`veaf-tools validate` — pre-build mission linter** (VALIDATE). A new command lints a mission folder **without building**, turning late DCS-side failures into clear design-time output. It aggregates every issue in one run (unlike the build, which aborts on the first): `mission.yaml` YAML syntax, `modules:` semantics (unknown key / wrong type / removed section), `custom_scripts` files that don't exist (**errors**); plus ASSETS/QRA groups declared but absent from the mission, presets/waypoints configured with no aircraft to apply them to, and `TUM: true` without BLUFOR/REDFOR territory zones (**warnings**). Exit code is non-zero on any error; `--strict` also fails on warnings. The mission-content checks read the unpacked source mission (`src/mission/mission`) and are skipped (with a notice) when it is absent. Messages are localized (FR/EN). The existing syntax/semantics checks were refactored into non-aborting helpers (`check_yaml_syntax`, `collect_module_issues`) so `build` and `validate` share the same logic. The presets/waypoints check is intentionally coarse (config present but no relevant aircraft); finer per-type matching is a possible follow-up

### Internal
- **Removed the dead `lupa` dependency** (CLEANUP-LUPA). SECREV-001 already routed all `.miz`/Lua parsing through the pure-Python `luadata` state machine (no `lua.execute`), but `lupa` (a native Lua runtime) was still a non-optional dependency, bundled in the `.exe` via `hiddenimports` (RC-002), and referenced in two dead spots: the unused `_lua_table_to_dict` path in the vendored `luadata` serializer, and the lupa-based reference oracle in `test_secrev_rce.py`. Dropped `lupa` from `pyproject.toml` + the `lupa.*` mypy override + the `.spec` `hiddenimports`, removed the dead serializer path, and re-pinned the SECREV dict/list-policy tests with direct expected-value assertions plus a real-`.miz` parse smoke test (the lupa oracle retired with the dependency). No `import lupa` remains; smaller dependency tree and binary. The pure-Python parser is unchanged.
- **`reindex-docs` command to rebuild the docs-chatbot index locally** (DOC-CHATBOT tooling). A new `poetry run reindex-docs` runs the same work as the `Rebuild docs chatbot index` CI workflow by hand — `node scripts/build-index.mjs` then the four `wrangler kv put` uploads — so the index can be refreshed on demand (the on-disk `.embed-cache.json` makes it incremental, staying well under the Gemini free-tier 1000 embeds/day cap). Handy while the CI workflow is temporarily disabled during a large doc pass (see the DOC-REVIEW lot). `--skip-upload` builds only; `--skip-build` uploads an already-built index. Resolves `node`/`npx` via PATH (handles the Windows `.cmd` shims)
- **Lua coverage gate + `veafUnits` backfill** (LUA-COVERAGE, wave 1). `test-lua` gained a `--cov-fail-under` option that fails the run when total luacov coverage drops below the floor; a new `lua-coverage` CI job enforces a **67 %** floor (ratchet — only ever goes up). Backfilled `veafUnits.lua` from 20 % to 93 % (33 new tests covering `placeGroup`/`processGroup` geometry and friends), lifting total Lua coverage to 69.7 %. Modules still around ~50 % (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, …) are left for later waves
- **mypy `ignore_errors` debt fully eroded** (QUALITY-GATE-FINISH). The six remaining application workers under the mypy `ignore_errors` override (`mission_converter_worker`, `mission_extractor_worker`, `waypoints_manager`, `weather_injector`'s `lua_converter` / `dcs_weather_converter` / `weather_injector_worker`) are now type-checked. Four had no errors; the seven surfaced errors were fixed without behaviour change (annotate `config: dict[str, Any]` in the weather lua-converter; drop redundant `: Path` re-annotations and rename a shadowed loop variable in the extractor). Only the bundled third-party `luadata` library stays excluded. The whole `src/python/veaf-tools` tree now passes `mypy` with no per-module opt-outs

### Fixed
- **An `AIRWAVES` zone with center/radius no longer logs an ERROR over a missing trigger zone** (FIX-AIRWAVES-OPTIONAL-TRIGGER-ZONE). An air-wave zone can be defined either by a Mission-Editor trigger zone (`trigger_zone_name`) **or** by explicit `zone_center_coordinates` + `zone_radius`. When `convert-v5` migrated a v5 mission carrying both, and the referenced trigger zone no longer existed in the `.miz`, `AirWaveZone:setTriggerZone()` logged a runtime **ERROR** (*"trigger zone [Airwaves-1] does not exist"*) — even though the zone still worked correctly via its center/radius (the missing-zone branch never overwrites the already-set center). The trigger zone is **optional** when a center is already configured: `setTriggerZone` now downgrades that case to a **WARN** and keeps the existing center/radius, reserving the ERROR for a genuine misconfiguration (no center at all). Reported by David on VEAF-Demo-Mission.
- **`convert-v5` no longer drops a combat operation's sub-zones** (FIX-CONVERT-V5-OPERATION-SUBZONES). A v5 operation chains sub-zones declared as locals — `local gori = VeafCombatZone:new():setMissionEditorZoneName("subCombatZone_gori")…` — and referenced by variable in `addTaskingOrder(gori)`. The migration neither extracted these sub-zones (the regex required `veafCombatZone.AddZone(`) nor resolved the tasking-order variable to the real `missionEditorZoneName`, so the generated `veafCombatZone.GetZone("gori")` found nothing at runtime — the operation couldn't locate its trigger zone (David, VEAF-Demo-Mission: "gori" → `subCombatZone_gori`). `convert-v5` now extracts the local sub-zones as `combat_zones` (with their `friendly_name`/`briefing`, emitted before the operation so `GetZone` resolves) and resolves the tasking-orders' `zone_var`/`dependencies_vars` to the real zone names. Verified on the real v5 `missionConfig.lua`; DCS runtime validation by David.
- **`cap_missions` no longer warns about a group that is actually present** (FIX-CAP-MISSION-PREFIX). `veafCombatMission.addCapMission()` has prefixed `OnDemand-` to the group name since v5, so a `cap_missions: group_name: CAP-Maykop-1` is backed by a Mission-Editor group named `OnDemand-CAP-Maykop-1`. The build's group-existence validation searched the raw `group_name` and emitted a false *"missing group"* warning; it now validates against the `OnDemand-`-prefixed name. `combat_missions` (no such prefix) is unaffected. Reported by David on VEAF-Demo-Mission.
- **An ADF/kHz radio no longer corrupts a slot's primary frequency (Yak-52 ARK-15M)** (FIX-DYNSLOT-RADIO-UNITS). When the presets-injector applied a preset whose first radio is an ADF/kHz radio (e.g. the Yak-52's ARK-15M, whose channels DCS stores in MHz: `0.625`), it promoted that **sub-VHF** frequency to the group's **primary** `frequency` — which DCS then refuses to save: *"Fréquence invalide 0.625 MHz"* (Tripack). The injector now only promotes a real primary-radio frequency (≥ 30 MHz; FM- and ADF-primary are excluded) to the group's main radio, leaving the original valid value (e.g. `132`) in place — so the dynamic-slot's VHF stays correct and the ARK channels stay in their own radio. As a **safety net**, the build now **fails fast** (listing the offending groups) if any human group would still ship a sub-VHF primary frequency, rather than producing a `.miz` the Mission Editor rejects at save. Root cause diagnosed from Tripack's Yak-52 dynamic-slot repro; the build/extraction itself preserves the channels faithfully.
- **Injected aircraft templates no longer pollute the multiplayer slot list** (FIX-TEMPLATE-SLOTS-VISIBLE). Templates injected by the tool (the `veafSpawn-` spawnables and the `dynSpawnTemplate` dynamic-slot templates) carry `skill: Client` units, so they showed up as **pickable slots** in the multiplayer briefing — a player could take a template slot by mistake (Tripack). The injector now hardens every injected template group with `hiddenOnPlanner` / `hiddenOnMFD` (removes it from the briefing slot list) **and** a locked slot password (defence in depth). DCS stores the slot password as a non-reversible salted `salt:hash` at group level, so the password is a fixed hash captured from the DCS Mission Editor. Dynamic-slot spawning (which references the template by name) is unaffected. Documented in the mission-maker `GUIDE` (FR/EN).
- **The generated `mission:` block is no longer mislabeled "Mission identity"** (FIX-MISSIONYAML-MISSION-SECTION). The block also holds mission-wide **behaviour** options (e.g. `silence_atc_on_all_airbases`), so labeling it pure "identity" was misleading (Tripack). The section header/description (generated template **and** `convert-v5` output, FR/EN) now reads as **Mission** — identity *and* mission-wide options. `silence_atc_on_all_airbases` is documented as an option in the commented template and the `MISSION_YAML_REFERENCE`, and `convert-v5` now annotates its **provenance** when migrating it (`# migrated from veaf.silenceAtcOnAllAirbases()`) so makers understand how it got there. The field stays under `mission:` (decided: the `settings:` block emits `veaf.config.KEY = value`, not a function call, so it does not fit there). Default `mission.yaml` updated in lockstep.
- **VEAF no longer integrates with a community library the mission disabled** (FIX-VEAF-MODULE-GATING). The framework's runtime integration with CTLD/SimpleTextToSpeech (`if ctld then …` in `veafAssets` / `veafGrass` / `veafSpawnAircraft` / `veafSpawnGround`, `if STTS then …` in `veafRadio`) fired on the **global existence**, not on the module being **enabled** in `mission.yaml`. So a mission maker who brings their **own version** of a lib (declared in `custom_scripts:`) while disabling the VEAF module (`modules: { ctld: false }`) got VEAF's integration applied to *their* version, assuming VEAF's API — the generalised form of the AIEN clobber the Foothold pilot hit. The build now emits `veaf.setConfig("<id>", "enable", false)` for each disabled community script into `veaf-config.lua`, and those eight runtime guards became `if ctld and veaf.isEnabled("ctld") then` / `if STTS and veaf.isEnabled("stts") then` (default-on, so enabled missions are unchanged). The top-level init blocks in `veaf.lua` / `veafSkynetIadsMonitor` are unchanged — they run at framework-load and only ever see VEAF's own bundled version (a maker's custom lib loads later, after the framework), so they are already self-gating by global existence. Surfaced by the FOOTHOLD-V6-007 pilot.
- **`custom_scripts:` declaration order is now actually honoured in the load sequence** (FOOTHOLD-V6-008). The docs already stated mission scripts load in `custom_scripts:` declaration order, but the build sequenced them by **glob/collection order**, so the ordered block scaffolded by `convert-other` was decorative for sequencing — a script that read a global defined by another `custom_script` could load first by accident. The build now reorders the declared scripts to their declaration order **in place**: declared scripts are reordered among the slots they already occupy, while undeclared files (VEAF infra `veaf-config.lua` / `mission-script.lua`, unknowns, the generated `veaf-config-override.lua`) never move — so a non-Foothold VEAF mission that happened to rely on glob order is unaffected, and the config-override still lands right after its `target`. Applies to both static and dynamic builds (single ordered source). Surfaced while shipping FOOTHOLD-V6-004.
- **CI: the `docs-chatbot-index` workflow was still on the deprecated Node.js 20 runtime** (CI-NODE24 follow-up). The original CI-NODE24 migration missed `.github/workflows/docs-chatbot-index.yml`, which kept `actions/setup-node@v4` and `actions/cache@v4` — both Node 20 — so every run logged the *"Node.js 20 is deprecated… forced to run on Node.js 24"* annotation. Bumped to `actions/setup-node@v5` and `actions/cache@v5` (both Node 24). A repo-wide sweep over all 9 workflows then caught a second miss — `peter-evans/create-pull-request@v7` (Node 20) in `dcs-data-drift.yml` — bumped to `@v8` (Node 24; v7→v8 is a runtime-only upgrade, no input/behaviour change, and the GitHub-hosted runner meets the v2.327.1 minimum). No other workflow now carries a Node 20 action
- **Pilot guide: broken screenshot references replaced with placeholders** (DOC-REVIEW follow-up). The pilot guide (`doc/pilot/GUIDE.{md,en.md}`) referenced 7 screenshots under `doc/assets/img/pilot/` that don't exist yet, so they rendered as broken images on the site. Each `![…](…png)` is now a clean *"📷 Capture à venir / Screenshot coming soon"* note that keeps the descriptive caption (the intended shot stays documented) without a broken image. The whole `doc/**` tree is now broken-link-clean; David can drop in the real screenshots later by restoring the `![…](…png)` syntax
- **Documentation fabricated-API rewrite — script/API docs now match the real Lua** (DOC-REVIEW, phase 2). A large share of the runtime-script docs documented Lua builder/class APIs that don't exist in the v6.5.25 sources; each was rewritten source-grounded, with every symbol grep-verified. Replaced: `VeafGrassRunway` (→ the real editor-naming workflow — name a static `…GRASS_RUNWAY…`, FARP units `FARP …`), the `VeafCombatZone`/`VeafCombatZoneElement`/`VeafCombatOperation` method tables (real `setMissionEditorZoneName`/`setFriendlyName`/`addZoneElement`/`addTaskingOrder`…), `veafCarrierOperations.addCarrier` (→ auto-discovery + the real CARRIER OPS menu, 45/90-min starts), `veafCasMission.start` (→ `initialize`), `VeafSanctuary` (→ `VeafSanctuaryZone` + `veafSanctuary.addZone`), the entirely-fictional `VeafMissileGuardian` builder (→ the real `VeafMG_Guardian`; module flagged experimental), `veafMove.moveTanker`/`changeTanker` signatures + the non-existent `_teleport` marker and `SpawnKeyphrase` constant, `veafNamedPoints.addNamedPoint`/`addNamedPointFromAirbase` (→ `addPoint` + `addDataToPoint`), the `veafTransportMission` builder + F10 menu (→ the marker-driven `_transport` with `size`/`defense`/`blocade`/`from`/`password` and the real Drop-zone menu), `veaf.weatherReport` (→ `veafWeatherData.getWeatherString`), the `veafAirWaves` builder method names + `:initialize()`→`:start()` (and a broken FR code-fence), `veafAssets` `groupName`/`carrier`/`information` field types, `veafRadio` example callbacks (→ the real `veafQraManager.get(name)` → `qra:start()/stop()`), and the whole `TOOLS_REFERENCE` publishing half (the non-existent `veaf-tools-updater publish` subcommand → `veaf-build publish` with its real flags). Deeper symbol-verification (an automated doc→source checker for every `:method()`/`module.func()` call in `doc/**`) also caught and fixed fabrications the first audit missed: `veafAirbases.setAirbaseData` (→ the real query API), the `LUA_API_REFERENCE` `Airbase`/`Runway`/`veafCombatMission` `mission:`/`objective:` sections (→ real `veafAirbase`/`VeafCombatMission`/`VeafCombatMissionObjective`), and the `mission-maker/GUIDE` QRA/Combat-Zone/Air-Waves/`VeafAlias` examples. The checker now reports every VEAF API call in the docs resolving to a real source definition. (The 8 missing `doc/pilot/GUIDE` screenshots remain — an asset decision, not a fabrication.)
- **Documentation clear-cut pass — broken links, stale facts, FR/EN parity** (DOC-REVIEW, phase 1). A 9-way parallel audit of every FR/EN doc pair drove a first wave of surgical corrections. **Links**: every `adr/00xx-*.md` reference was broken (the ADRs live in `docs/adr/`, outside the MkDocs `docs_dir: doc`) → switched to the absolute GitHub URL form already used for ADR 0005, in `MISSION_YAML_REFERENCE`, `PIPELINE_REFERENCE`, `MIGRATION_GUIDE` and `veafSpawn`; and fixed over-deep `../../MISSION_YAML_REFERENCE.md` links in `MIGRATION_GUIDE`. Cross-doc links stay bare `.md` (the established convention for the `mkdocs-static-i18n` *suffix* mode, which routes them to the right language at build time — the EN pages carry the English anchors). **Stale facts**: `TESTING` 31→34 Lua suites (+ the previously-undocumented `luacheck` and `lua-coverage` CI jobs); `PIPELINE_REFERENCE` 85→87 radio-spec aircraft and step numbers re-ordered to match the real build sequence (weather runs last); `LUA_API_REFERENCE` version strings (`veaf` 1.57.0, `veafSpawn` 1.59.3, `dcsUnits` `datamine-dc7d15e8`, doc header 6.5.25) and `dcsDataExport` module id `DCSDATAEXPORT`→`DCSEXPORT`. **Stale ids/keys**: `veafShortcuts` `SHCUT`→`SHORTCUTS`, blank→`SANCTUARY`, `enable`→`enabled` (`veafNamedPoints`/`veafRadio`), `lua_modules`→`modules` (developer guide). **Wrong commands/config**: removed the non-existent `convert-mission` command from `MIGRATION_GUIDE` (now `extract` + `build`); `veafWeather` `weather-inject`→`inject-weather` with the real `versions.yaml` schema; Skynet `external_modules:`→`modules.SKYNET`; QRA top-level `qra:`→`modules.QRA` (per ADR 0001); `_cas size 0-5`→`1-5` and the non-existent `_spawn unit … group N` parameter dropped (it now hard-aborts) in both `veafSpawn` and the pilot guide. **FR/EN parity**: synced `scripts/README`, `ROADMAP`, `veafCombatZone.en` (a constants table that rendered broken), `veafShortcuts`, `veafWeather` and the mission-maker GUIDE TOCs. The remaining ~14 doc sections that document **fabricated** Lua builder/class APIs (verified absent from the v6.5.25 sources) are a separate follow-up (DOC-REVIEW-003). The audit also surfaced a real runtime bug — the config generator emits `AirWaveZone` setters that don't exist in `veafAirWaves.lua` — tracked as its own lot (FIX-AIRWAVES-GENERATOR)
- **Generated AirWaves config no longer crashes the mission at start** (FIX-AIRWAVES-GENERATOR). `lua_config_generator._emit_airwave_zone` emitted five `AirWaveZone` setters that don't exist in `veafAirWaves.lua` — `setMessageWaveDeployed`, `setMessageEndZone`, `setMessageEndAll`, `setMinimumSecondsBetweenWaves`, `setMaximumSecondsBetweenWaves` — so any `mission.yaml` configuring an AirWaves zone produced a `veaf-config.lua` that raised `attempt to call method '…' (a nil value)` at mission start. The two real messages are now mapped to the actual setters (`message_wave_deployed` → `setMessageDeploy`, `message_end_zone` → `setMessageWon`); the inter-wave delay collapses to a single `setDelayBetweenWaves` (preferring the configured minimum — the runtime has no random min/max range), and the unsupported `message_end_all` ("all zones cleared") plus the maximum-delay bound are dropped (no runtime equivalent). A new test parses `veafAirWaves.lua` for the real `AirWaveZone` methods and asserts every method the generator emits exists, so a future renamed/removed setter can't silently reintroduce the crash
- **`veaf-tools prepare` with no arguments now shows its help instead of scaffolding the current directory** (SCAFFOLD follow-up). `mission_folder` defaulted to `.`, so a bare `prepare` silently copied the scaffold into the working directory (clobbering it). The command is now `no_args_is_help`: a bare `prepare` prints the usage/options — including the `--template minimal|standard|full|custom` list and `--list-templates` — and exits without touching anything; pass a folder (e.g. `prepare .`) to actually scaffold
- **`prepare` interactive prompts clarified** (SCAFFOLD follow-up). The overwrite prompt for an existing file is now a clear arrow-key menu (Replace this / Keep this / **Replace all** / **Keep all**) instead of a terse `[y/N/A]` single-key prompt — this also adds the previously-missing "keep all" (no-to-all); non-interactive runs keep everything without blocking. The `custom` template module picker now groups modules by category and tags each with the lowest tier it belongs to (e.g. `RADIO · minimal`, `WEATHER · standard`, `MISSILEGUARDIAN · full`)
- **`convert-v5` no longer emits phantom modules and ASSETS/QRA from commented-out config** (FIX-CONVERT-V5-COMMENTS). In the standard VEAF template each module body ships inside a `--[[ … ]]` "uncomment to enable" block. The converter ignored Lua comments, so it (1) marked a module active from its `if veafXxx then` guard even when the entire body was commented out, and (2) regex-scanned `name=…` definitions **inside** `--[[ ]]` blocks (and individually `--`-commented rows), emitting phantom ASSETS/QRA into `mission.yaml`. Found during DCS-UPDATE-VERIFY (R7) on Training-Syrie: 14 commented-out assets were emitted as active, then flagged "absent from the mission" at build. A new `_strip_lua_comments` helper masks single-line (`--`) and block (`--[[ ]]`, `--[==[ ]==]`) comments — offset-preserving, string- and long-string-aware — and all `pre_extract` anchor searches now run against the masked copy; module activation is gated on the guard body having genuinely active (non-commented) content. Active config is unaffected (masking is identity on uncommented code), and commented elements are still surfaced as commented YAML via the existing recovery path. Regression tests cover a fully-commented `veafAssets.Assets` block, a commented QRA chain, and a line-commented guard body
- **Full localization sweep of the remaining VEAF on-screen messages** (LUA-I18N-SWEEP). After LUA-I18N-CAS and LUA-I18N-WEATHER, an exhaustive audit of every non-community VEAF module found ~100 player-facing strings (via `outText*` / `markTo*`) still hardcoded in English. They are now routed through `veaf.t` with FR + EN catalog entries across `veafMove`, `veafNamedPoints`, `veafSpawn*` (effects/core/ground/aircraft feedback, AFAC/CAP reports), `veafQraManager`, `veafAirWaves`, `veafSanctuary`, `veafGroundAI`, `veafMissileGuardian`, `veafCombatZone`, `veafCombatMission`, `veafCarrierOperations` and `veafTransportMission` (briefings, target/ATC reports, completion/event messages, help texts). Modules whose status messages are mission-overridable defaults (QRA, AirWaves, Sanctuary, GroundAI, MissileGuardian, the default CAP objective) now store i18n **keys** as defaults and resolve them through `veaf.t` at send time, so the default localizes while a mission's custom message passes through verbatim. **Standardized aeronautical / brevity codes stay identical in both languages** (TACAN, ICLS, LINK 4, ACLS, BRC, COMM, BRA, MERGED, CAVOK, QNH, kn, kts, NM, MGRS…), and **F10 radio-menu labels are left untouched** because they double as `delCommand` identifiers. Logs stay English; only on-screen text is localized. Existing rendering tests in `test_veafCombatZone`/`test_veafCombatMission`/`test_veafCarrierOperations` now load `veafI18n.lua` and pin `language = "en"`; representative FR/EN coverage was added to `test_veafI18n.lua`
- **The `veafWeatherData` report is now localized** (LUA-I18N-WEATHER). Follow-up to LUA-I18N-CAS: the weather report (`veafWeather.lua` — `toString`, `toStringExtended`, `toStringAtis` and their helpers), shown after `_cas`, in `veafCombatZone` and on the carrier weather menu, stayed English even with `veaf.config.language = "fr"`. All user-facing descriptive words and line labels are now routed through `veaf.t` with FR + EN catalog entries: wind `calm`, cloud densities (`No clouds`/`Scattered`/`Broken`/`Overcast`/`Few clouds`), visibility affects (`fog`/`haze`/`mist`/`dust`/`precipitations`), and the report/ATIS labels (`Wind`/`Visibility`/`Clouds`/`Temperature`/`Dew point`/`Sunrise`/`Sunset`/`Time`/`Location`/`Altitude` + ATIS phraseology). **Standardized aeronautical abbreviations stay identical in both languages** (`CAVOK`, `QNH`, `QFE`, `kts`, `m/s`, `NM`, `SM`, `ft`, `Hpa`, `inHg`, `mmHg`, `°M`/`°T`, `AGL`/`ASL`, `FL`, `LASTE`) — a FR pilot reads them unchanged. Logs are unchanged. The existing `test_veafWeather.lua` rendering tests now load `veafI18n.lua` and pin `language = "en"`; FR coverage was added at the catalog level in `test_veafI18n.lua` (6 new tests)
- **`veafCasMission` on-screen messages are now localized** (LUA-I18N-CAS). LUA-I18N-004 routed most module messages through `veaf.t` but missed `veafCasMission`, so the `_cas` feedback stayed English even with `veaf.config.language = "fr"` (found during DCS-UPDATE-VERIFY, R3-FINDING-3). All of the module's user-facing text is now routed through `veaf.t` with FR + EN catalog entries: the short post-`_cas` spawn confirmation, the full F10 target report (target line, AFAC on station, LAT/LON decimal & DMS, MGRS/UTM, from-bullseye heading/distance, weather header), and the `_cas` HELP text (command tokens like `_cas`/`defense`/`size`/`armor`/`spacing` stay literal in both languages). The weather body of the report is produced by `veafWeatherData` and stays English for now (a separate data-report module, out of this lot's scope). Logs are unchanged; only on-screen text is localized
- **The 50 default CAP plane templates are no longer filed under the `helicopter` category** (FIX-SPAWNABLES-CATEGORY). The shipped `src/defaults/mission-folder/src/spawnables.yaml` placed every fixed-wing CAP template (F-15C, M-2000C, F-14A, F-5E, F-4E, Mirage-F1EE, MiG-21/23/25 — 50 groups) under the top-level `helicopters:` bucket, a stale extraction artifact (the live `extract-aircraft-groups` tool categorizes correctly). The injector maps the bucket straight onto the DCS table, so those planes landed under the country's `helicopter` group table in the built `.miz`. This is **not cosmetic**: at runtime the CAP spawn clones the template through MIST without re-deriving the category, so `mist.dynAdd` feeds `Unit.Category.HELICOPTER` to `coalition.addGroup` for a fixed-wing unit (wrong default altitude/speed and AI category). All 50 templates were re-categorized to `airplanes:` via a category-aware migration that looks up each unit's real DCS category in the canonical `dcsUnits.yaml`; no genuine helicopter was present. A regression test now asserts every shipped template sits in the bucket matching its units' DCS category (caught in both directions) and pins the bucket → DCS-table injector mapping
- **`convert-v5` no longer produces an unparseable `mission.yaml` when a QRA was disabled in v5** (FIX-CONVERT-V5-INVALID-YAML). A QRA defined with `start = false` made the converter emit `start: false` at the `definitions:` sequence level (6-space indent) instead of inside its `- name:` list item (8 spaces), because the comment translation hard-coded the indentation. DCS/YAML then rejected the file (`expected <block end>, but found '?'`, e.g. around line 212). The flag is now emitted with the same field indent as every other QRA field, and the FR/EN translation holds only the comment. Verified end-to-end on the reporting mission (Training-Syrie now parses); regression tests assert the generated QRA block always parses
- **The generated `_version.py` no longer shows up as permanently "modified"** (FIX-VERSION-PY-EOL). `veaf-build` wrote `veaf_tools/_version.py` in text mode, so on Windows Python translated `\n` to `\r\n`; the git-tracked stub is normalized to LF (`.gitattributes` `eol=lf`), so every build left the working tree dirty with a CRLF-only, content-less diff. `_write_version_py` / `_restore_version_py` now pass `newline="\n"`. The same latent issue in `radio_specs_updater` (the tracked `dcs-radio-specs.yaml` / `.md` artifacts) was fixed too, aligning it with the other `dcs_data` generators that already force LF
- **The Mission Editor form of the VEAF load triggers no longer drops `custom_scripts`** (CUSTOM-SCRIPTS-TRIGGERS). Each VEAF load trigger is written into the `.miz` twice: the compiled `trig` table (the `funcStartup` form DCS runs at mission start) and the `trigrules` table (the Mission Editor form). The two were hand-built separately and had drifted — the static-mission `trig` form loaded the full ordered mission-script list (so it honoured `custom_scripts`), while the static-mission `trigrules` form loaded only `veaf-config.lua` + `mission-script.lua`. A built mission ran correctly, but a mission maker who re-opened it in the ME and saved would have DCS recompile the trigrules into `trig` and **silently lose custom-script loading in static mode**. Both forms are now derived from a single ordered `VeafTriggerSpec` list, so they can never reference a different set of scripts. The now-unused `meters`/`zone` editor leftovers on the `env.info` actions were dropped
- **Static/distribution builds no longer drop `veafSpawnParser.lua`** (DCS-UPDATE-VERIFY). The static `veaf-scripts.lua` bundle is assembled from an explicit ordered list of modules; the spawn refactor split the text parser into `veafSpawnParser.lua` (defining `veafSpawn.convertLaserToFreq` and `markTextAnalysis`) and added it to the dynamic loader but **not** to that static list. So static/distribution missions silently lacked those functions — `_cas` crashed building the JTAC laser frequency (`attempt to call field 'convertLaserToFreq' (a nil value)`) and `_spawn` text parsing was broken — while dynamic dev builds (which glob every `veaf/*.lua`) kept working. Added the file to the bundle (after `veafSpawnCore.lua`), and a regression test now asserts every `src/scripts/veaf/*.lua` is either bundled or explicitly excluded, so a future split file can never be silently dropped again
- **Restored the MQ-9 AFAC spawnable template in the default `spawnables.yaml`** (DCS-UPDATE-VERIFY). The v5 default shipped a `veafSpawn-MQ-9 - AFAC - JTAC - DRONE` template; the reworked v6 default spawnable set (a different `foxN`-tagged CAP roster) dropped it. So `_cas` (which spawns an MQ-9 Reaper as aerial JTAC) and the `-afac` / `_spawn afac` alias logged `The AFAC aircraft template could not be found for "mq9"` and spawned no AFAC. The template is back (extracted from the demo mission, filed under `airplanes`) and named `veafSpawn-MQ9 - AFAC - JTAC - DRONE` so the literal `"mq9"` search resolves it (the matcher treats `mq9` as the substring `MQ9`, which would not match a `MQ-9` group name; the DCS unit type stays `MQ-9 Reaper`), so `_cas`/`-afac` work again. (A separate issue — the other 50 default CAP plane templates being filed under the `helicopter` category — is tracked as its own lot.)
- **Refreshed the airdrome table for the Syria-map expansion** (DCS-UPDATE-VERIFY). A DCS World update expanded the Syria theatre; `airdromes.yaml` was missing 6 airfields (`Cukurova`, `Diyarbakir`, `Hatzerim`, `Konya`, `Nevatim`, `Teyman`). A dynamic-slot warehouse referencing one of them silently failed to wire (`airdrome_id_for_name()` could not resolve the name → the airbase fell back to default slots, no error). Regenerated from the local install (`update-dcs-data --airdromes`); now 199 airfields. Airdromes are the only DCS-derived data sourced from the local install rather than the pinned datamine, so they are not CI-guarded and must be refreshed after a map-changing DCS update

### Changed
- **`TUM` (The Universal Mission) is now opt-in and auto-initialized** (TUM-AUTOINIT). TUM imposes a mission-design contract (BLUFOR/REDFOR territory zones, each owning an airbase) and aborts at start-up otherwise, so it must never start on its own. It is now the only community script that is **off by default**: a vanilla mission, a freshly v5-converted mission, or a `modules:` block that omits `TUM` all leave it disabled — only an explicit `TUM: true` enables it (the other community scripts stay opt-out, active unless set to `false`). Previously TUM followed the opt-out default, so it was enabled — and `TUM.initialize()` emitted — for missions that never set it up, producing the `Coalition red has no territory zones…` runtime error. When `TUM: true`, the build now calls `TUM.initialize()` automatically at start-up, so no manual `mission-script.lua` wiring is needed. `convert-v5` emits `TUM: false` even when the TUM file is detected
- **VEAF load-trigger generation refactored to a single source of truth** (CUSTOM-SCRIPTS-TRIGGERS). The compiled `trig` form and the editor `trigrules` form are derived from one ordered `VeafTriggerSpec` list via two emitters (`_emit_trig_action_string` / `_emit_trigrule_actions`), and the six trigger dictionary keys are shared between the dictionary population and the trigger specs. No runtime behaviour change for a freshly built mission

### Documentation
- **Foothold adoption "moulinette" guide** (FOOTHOLD-V6-007). New `mission-maker/FOOTHOLD.{md,en.md}` documents the end-to-end reproducible procedure for adopting a Lekaa Foothold mission onto the v6 toolchain: init (`convert-other --profile foothold`), tuning `mission.yaml` (turn the VEAF community scripts off since Foothold ships its own, the partial `config_override`, and Modern/Cold-War **`build_variants:`** flipping Foothold's `Era` global config-only), `validate`, building **both** variants in one `build`, the DCS test, and re-importing a newer upstream with `--update`. The procedure was exercised end-to-end on the real Caucasus `.miz` (one `build` → `…_MODERN.miz` + `…_COLD_WAR.miz`, each carrying the right `Era`). `CONVERT_OTHER` and the new guide are now in the MkDocs nav (the former was missing). FR/EN
- **Documented the `TUM` "no territory zones / no airfields" start-up error** (INVESTIGATE-REDFOR-ZONES spike). The runtime error `Coalition red has no territory zones and/or controls no airfields…` comes from the third-party **The Universal Mission (TUM)** community script, not from VEAF: it is an expected TUM mission-design prerequisite (`BLUFOR…`/`REDFOR…` trigger zones, each owning an airbase). `MISSION_YAML_REFERENCE` (FR/EN) now documents this next to the `TUM` module id. Full analysis journaled in the project backlog. No code change
- **Clarified `custom_scripts` loading semantics** (CUSTOM-SCRIPTS-TRIGGERS). `MISSION_YAML_REFERENCE` (FR/EN) now states that `generate_load_trigger` is a single flag governing **both** the static (embedded) and dynamic (from-disk) loading modes, documents the load order (`veaf-config.lua` → `mission-script.lua` → `custom_scripts`), and shows — with a worked FR/EN example — how to load a script in only one variant (e.g. a dynamic-only debug script) via a build **profile**, including the deep-merge pitfall (profile lists *replace*, so the profile must repeat the base scripts)

## [6.5.0] — 2026-06-13

### Changed
- **`SHORTCUTS` enabled by default** in the shipped `mission.yaml`, so the built-in spawn aliases (`-shilka`, `-sa2`, …) work out of the box. The default previously left `SHORTCUTS` commented as "needs a list", which was misleading — a `shortcuts:` list is only needed to add *custom* aliases on top of the built-in ones
- **`CASMISSION` and `TRANSPORTMISSION` enabled by default**. Both are marker-driven (`_cas` / `_transport`), need no configuration and impose nothing, so they join the default baseline. Default policy: a module ships ON when it is useful to everyone, needs no config block and changes nothing on its own; it stays OFF when it requires a config block (ASSETS/SANCTUARY/COMBATMISSION/COMBATZONE/QRA/AIRWAVES), changes gameplay (MISSILEGUARDIAN), is carrier-specific, or is a community script
- **Marker-command coalition handling clarified** (COALITION-REFACTOR). The scattered, hard-to-follow coalition inversion (`(event.coalition == 1) and 2 or 1`, duplicated in spawn / CAS / shortcuts) is replaced by two intent-revealing helpers in `veaf.lua`: `veaf.getOppositeCoalition(side)` (the default side of units spawned from a marker — markers spawn threats for the opposing side) and `veaf.getRequesterCoalition(event)` (the coalition that issued the command, for pilot feedback). This separates two concepts that were conflated. **Fix**: the "unknown spawn parameter" hint was addressed to the *spawn* side (opposite the pilot), so the pilot who placed the marker never saw it; it now goes to the requester (or all coalitions when unknown). Same spawn behaviour as before, but explicit and consistent.

### Fixed
- **An unknown spawn-marker parameter now aborts the command** instead of spawning anyway. A typo such as `_spawn unit, name shilka, headng 90` previously warned about `headng` but still spawned the unit; it now reports the hint (with a "did you mean …?" suggestion) and performs **no spawn**, leaving the marker in place so the pilot can fix the typo. Recognized parameter keys are derived from the spawn parameter rules, so a flagged key is always one that would otherwise have been silently ignored
- **Radio presets no longer make a mission unsaveable** (presets injector). When a resolved preset (e.g. a catch-all `all` UHF/VHF/FM plan) was only *partially* compatible with an aircraft — some channels in range, some not (a P-51D/TF-51D/P-47D capped at ~200 MHz, an SA342 Gazelle at ~88 MHz, both fed a 243 MHz UHF Guard channel) — the whole preset was injected, including the out-of-range channels, and the DCS Mission Editor refused to save ("Invalid frequency 243 MHz"). Out-of-range channels are now dropped per aircraft (the in-range ones are kept), so the mission always saves. A fully incompatible aircraft (e.g. Yak-52, sub-MHz ARK-15M) still keeps its original radio untouched, as before. Also added the missing MiG-15bis / MiG-15bis_FC radio spec (HF RSI-6K, 3.75-5 MHz) so the MiG-15 is correctly detected as incompatible with modern UHF/VHF presets (it was absent from the spec table, so a 243 MHz channel slipped through)
- **Dynamic-Slot warehouse templates now bind in-game** (DYNSLOT-WAREHOUSE). The warehouse wiring wrote each dynamic-slot aircraft entry **flat** under `aircrafts` (`aircrafts[<type>]`), but DCS nests them by category — `aircrafts.helicopters[<type>]` / `aircrafts.planes[<type>]`. A flat entry is silently ignored, so `dynamicSpawn`/fuel/munitions applied but the `linkDynTempl` template link never bound (the airbase fell back to default dynamic slots). Entries are now placed under the correct sub-table, classified via the committed DCS units database (`category`), with the mission's dynamic-spawn templates as a fallback for mod aircraft
- **`_spawn unit` success message is now localized** (i18n follow-up). The single-unit spawn feedback (`veafSpawn.spawnUnit`) and its JTAC variant were left as hardcoded English literals during LUA-I18N-004; they now go through `veaf.t` with new FR + EN catalog entries (`spawn.unit_spawned`, `spawn.jtac_spawned`), so `_spawn unit, name <alias>` reports in the mission language like `_spawn group` already did
- **Dynamic mode no longer initializes the VEAF modules twice**. The dynamic mission-loading trigger loaded `veaf-config.lua` explicitly *and* via `veafDynamicConfig.lua` (which already heads its `scriptsToLoad` list with it), so every module's `initialize()` ran twice — e.g. `veafCommands` registered its central marker-dispatch handler twice, making a single F10 marker command (such as `_spawn group, name sa2`) execute twice. The redundant explicit load was removed from the dynamic trigrule; `veafDynamicConfig.lua` remains the single entry point and loads `veaf-config.lua` first. Static mode was unaffected
- **`_spawn` / QRA are now initialized in dynamic mode**. The generated `veaf-config.lua` called `veafSpawnCore.initialize()` / `veafQraCore.initialize()` (nil globals) instead of `veafSpawn.initialize()` / `veafQraManager.initialize()`: the config generator derived the module variable from the file name, but a proxy module's table differs from its file (e.g. `veafSpawnCore.lua` defines `veafSpawn`). The `_spawn` marker handler was therefore never registered. The generator now maps each module id to its real table name (read from `<table>.Id`)
- **Dynamic mission loading no longer recurses infinitely**. The generated `veafDynamicConfig.lua` (the dynamic loader) listed itself among the scripts it loads, so at mission start it re-loaded itself endlessly. The loader is now excluded from the list it iterates
- **Split spawn/QRA proxies load under DCS dynamic `loadfile`**. `veafSpawn.lua` / `veafQraManager.lua` resolve their own directory to `dofile` their split parts; the detection assumed a `@`-prefixed chunk source, which DCS omits under dynamic `loadfile`, so the proxies aborted and cascaded `nil` errors (`veafRemote`/`veafUnits`). Directory detection now handles a source with or without the leading `@`

### Changed
- **Default `mission.yaml` documents the newest pipeline steps**: the commented `pipeline:` block (shipped default + the `convert-v5`/generated template) now also lists `warehouses` (Dynamic-Slot warehouses, `src/warehouses.yaml`) and `spawn_data` (always-on spawn-database injection, extended by `src/spawn-groups.yaml`), so mission makers discover them. No behaviour change — both steps and their default files already shipped; only the inline documentation was stale
- **In-game default language now follows the tools' language** (LUA-I18N). When `mission.yaml` does not set `mission.language`, the build emits `veaf.config.language` from the tools' resolved language (`--lang` > `VEAF_LANG` > user config > OS locale > `en`) instead of a hard-coded `fr`. So a mission built by a French maker defaults to French in-game and others to their locale; `mission.language` still overrides, and the Lua-side `veaf.I18N_DEFAULT_LANGUAGE = "fr"` remains only as the ultimate runtime fallback. No new CLI surface — the existing global `veaf-tools --lang` already drives it

### Added
- **In-game messages localized across the framework** (LUA-I18N-004, FR + EN). Building on the i18n layer, the pilot-facing messages of the VEAF modules are routed through `veaf.t` with FR + EN catalog entries: spawn (unit/group/cargo/static/teleport/convoy/IADS), combat zones / combat missions / missile guardians (shared `entity.*` activation states), CAS and transport mission calls (incl. the transport help), ground/tanker/AFAC moves, radio, security (password/lockdown), skynet helper, named points, ground AI (fire orders), carrier operations (errors/help/stop), sanctuary enforcement, shortcuts (alias errors), weather fog, and assets status/help. Logs stay in English; only the on-screen text is localized. **Deliberately out of scope** (documented): mission-**configurable** message templates (Air-Waves, QRA, Ground-AI start/stop, Combat-Zone events, Sanctuary warnings — these are user-overridable, not catalog material) and large **data reports** (weather/ATC METAR-style report, transport navigation report, carrier list/recovery status) — localizing those would be a separate lot
- **In-game message localization (Lua runtime i18n)** (LUA-I18N-001/002/003, FR default + EN). The Lua scripts had no i18n — every pilot-facing message was a hardcoded English literal. New `veaf.t(key, ...)` lookup (in `veaf.lua`) over a `veaf.i18nCatalog` catalog (new `veafI18n.lua` module), with `string.format` interpolation and fallback (requested language → French → the key). The active language is `veaf.config.language`, emitted into `veaf-config.lua` from `mission.yaml`'s `mission.language` (default `fr`; mission-global, since DCS exposes no per-pilot language). First consumers migrated: the UXPILOT pilot-feedback messages (marker-command failure, unknown spawn parameter + "did you mean" hint) now have FR + EN entries. The remaining `outText` literals are migrated module-by-module over time (LUA-I18N-004). See ADR 0006

### Changed
- **Spawn subsystem de-duplicated** (SPAWN-EXTERNALIZE-005 / SPAWN-REFACTOR-002), iso-functional and covered by the characterization tests. Three repetitive blocks became data-driven: (1) the per-command security preamble (`if not (bypassSecurity or veafSecurity.checkSecurity_Lx(...)) then return nil, nil, true end`, repeated in ~25 handlers) is now applied centrally by the dispatcher — `registerCommandHandler(key, security, fn)` declares the level (`L9`/`L1`/`MM`, or none for smoke/flare/signal); (2) the ~50-branch mark-text keyword parser (`if key:lower() == "…"`) is now a `veafSpawn.ParameterRules` descriptor list (the recognized-key set for typo hints is derived from it — single source of truth); (3) the command-detection if/elseif chain that seeds per-command defaults is now a `veafSpawn.CommandDescriptors` ordered list (first match wins). No behaviour change to `_spawn`/`_destroy`/`_teleport`/`_drawing`/`_mm` commands

### Added
- **Spawn database externalized to YAML** (SPAWN-EXTERNALIZE-002/003/004). `veafUnits.UnitsDatabase` / `GroupsDatabase` (the ~1450 lines of hand-coded `_spawn unit`/`_spawn group` data) are no longer literals in `veafUnits.lua`: they now live in a shipped `veaf_libs/data/veaf-units.yaml` (13 units, 78 groups), are rendered to Lua, and **injected into the `.miz` at mission build** (DCS can't parse YAML at runtime). The framework Lua now defaults the two tables to empty; a new always-on `spawn_data` build step embeds them after the framework bundle loads. A one-time parity oracle confirmed the generated Lua is semantically identical to the previous tables. Missions can extend or override the database with an optional `src/spawn-groups.yaml` (merged over the framework data — a shared alias replaces the framework entry; case-insensitive). Disable with `pipeline: { spawn_data: false }`. Ships a commented `src/spawn-groups.yaml` default. See `doc/PIPELINE_REFERENCE.*` and ADR 0005
- **Pilot feedback for marker commands** (UXPILOT-FEEDBACK). Mistyped or failing F10 marker commands are no longer silent: (1) the `veafMarkers` dispatch already wrapped handlers in `pcall` but only logged — it now also shows the placing coalition a short in-game message when a handler errors (the stack still goes to the DCS log); (2) a new `veaf.reportToPilot(message, duration, coalition)` helper (thin wrapper over `trigger.action.outText` / `outTextForCoalition`); (3) `veafSpawn` now warns the pilot about an **unknown spawn parameter** and suggests the nearest valid key (Levenshtein `veaf.nearestMatch`), e.g. `headng` → "did you mean 'heading'?"
- **Dynamic-Slot warehouse wiring** (`warehouses.yaml`, DYNSLOT-WAREHOUSE). A new build pipeline step configures DCS Dynamic Slots per coalition: it enables `dynamicSpawn` on the selected airbases, sets fuel/munitions and aircraft stock, and links each offered aircraft type to its `dynSpawnTemplate` group via `linkDynTempl` (the model providing loadout/livery/radio/route). Airbases are selected by **all-of-coalition** (default), by **name** (resolved via the airdrome table + mission theatre), or by **id**, with per-airport overrides. Runs after aircraft injection so the template groups exist. Ships a commented `src/warehouses.yaml` default (no-op until filled). See `doc/PIPELINE_REFERENCE.*`
- **Airdrome name→id table** (`veaf_libs/data/airdromes.yaml`, DYNSLOT-WAREHOUSE prerequisite). Maps, per theatre, an airfield display name to the numeric DCS airdrome id used as `airports[<id>]` in a mission's `warehouses`. Generated from a local DCS install's terrain `Beacons.lua` via `veaf-build update-dcs-data --airdromes --dcs-path <DCS>` (install-dependent, not CI-guarded). Resolver `veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)`. Ships 7 theatres / 194 airfields; beacon-less maps (Normandy) yield no entries (callers fall back to ids)

### Changed
- **DCS units database now comes from the datamine** (DCSDATA-008), retiring the in-DCS export (`dcsDataExport.lua`) as the source of `dcsUnits.lua` (the export stays for airbases/weapons). New two-stage pipeline: `veaf-build update-dcs-data --units` parses `Quaggles/dcs-lua-datamine` into a committed canonical `dcsUnits.yaml`, then renders `src/scripts/veaf/dcsUnits.lua` from it. The runtime schema is simplified — keyed by DCS type, with a single `kind` (`air`/`naval`/`infantry`/`vehicle`/`static`) replacing the four booleans — and `veafUnits` was updated accordingly (fast keyed lookup in `findDcsUnit`). Both artifacts are pure and CI-guarded (consistency + drift). Validated against the previous 833-unit file: 0 kind regressions, the 2 datamine-absent units carried over. Documented in `doc/developer/dcs-data.*`

### Added
- **`veaf-tools ask` — documentation chatbot in the CLI/TUI** (CHATBOT-CLI). Ask a question about the VEAF docs and get a grounded AI answer — the same assistant as the website chatbot. One-shot (`veaf-tools ask "how do I enable CTLD?"`) or an interactive REPL, plus a TUI entry « Ask the documentation ». **No API key and no setup**: the command proxies the question to the project's documentation Worker (which owns the Gemini key, runs the RAG and streams the answer), identifying itself with an `X-VEAF-Client: cli` header and bounded by the Worker's per-IP rate limit
- **Documentation chatbot — Gemini 429 handling** (DOC-CHATBOT-005): when the Gemini free-tier quota is hit, the docs chatbot now answers with the localized "too many requests, retry shortly" message instead of the generic "temporarily unavailable", on both the generation and embedding paths. Completes the chatbot lot (repo secrets set; the widget already ships to the versioned `mike` docs via `mkdocs.yml`)
- `build`: **automatic CTLD/CSAR sound packaging** (BUILD-COMMUNITY-SOUNDS-001). CTLD and CSAR play their sounds by filename at runtime, so the files must be in the mission's `l10n/DEFAULT/`. The tools now ship the canonical sounds (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`, sourced upstream) under `src/scripts/community/sounds/` and, when CTLD or CSAR is enabled, inject the ones a mission is missing — **without overwriting** sounds the mission already provides. Nothing is injected when both modules are off. A required sound shipped by neither the tools nor the mission (e.g. `radiobeep.ogg`, the JTAC fallback beep, which upstream does not redistribute) is reported with a build warning so the mission maker can add it. No DCS trigger or `mapResource` entry is created — packaging the file in `l10n/DEFAULT/` is sufficient

### Fixed
- `build`: the legacy v5 **CTLD/CSAR sound-preload trigger** (an `out_sound` registering `beacon.ogg` / `beaconsilent.ogg` / `CSAR.ogg`…) is now dropped — along with its `mapResource` entries — when **both** CTLD and CSAR are disabled, instead of surviving as dead weight. It is left untouched when either module is enabled. Non-community sounds are never touched. Re-creating/packaging the trigger when a module is enabled is tracked separately (`BUILD-COMMUNITY-SOUNDS`) (TRIGGERS-VERIFY-004)

### Removed
- **WeatherMark community script retired**: its weather-report helpers were already replaced by `veafWeather` (the only remaining usage was a commented-out, deprecated `veaf.weatherReport` body). Removed `src/scripts/community/WeatherMark.lua`, the `weathermark` community-script entry, the dead `veaf.weatherReport` body, and the docs reference (WEATHERMARK-REMOVE-001)
- Removed the now-empty deprecated `veaf.weatherReport` stub entirely (no callers; superseded by `veafWeatherData.getWeatherString`) (WEATHERMARK-REMOVE-002)

### Added
- `TUM` now actually starts: when enabled, `veaf-config.lua` emits `if TUM then TUM.initialize() end` so TheUniversalMission is initialized at runtime (previously `TUM: true` loaded the script but never called `initialize()`) (TUM-INIT-001)
- `veaf-build` **auto-computes the release build number** when `--version` is omitted: it reads the project base (`X.Y.Z`) and the previous `published.zip` version — same base → increments the build number (`X.Y.Z.4`), different base or no `published.zip` → starts at `X.Y.Z.1`. `--version` still overrides (BUILD-AUTOVERSION-001)
- **Automatic mission-era detection**: when `mission.era` is not set in `mission.yaml`, `build` infers it (`WW2` / `COLD_WAR` / `MODERN`) from the base mission — a combined heuristic over the DCS mission **year** and a **WW2-era unit/aircraft-type** reference table (WW2 wins on the unit signal even at a modern default year). A manually-set `mission.era` always takes precedence (ERA-AUTODETECT-001/002)
- `convert-v5`: **commented-out v5 elements are no longer silently dropped** — a combat zone, asset, QRA, shortcut, etc. that was disabled with `--` in `missionConfig.lua` is now re-emitted at the end of `mission.yaml` as a fully-commented **"Commented-out v5 elements"** block, so you can re-enable it by uncommenting. Generic across every extractor (a de-commented re-extraction is diffed against the active config; pattern-based extraction ignores prose) (CONVERT-FIDELITY-001)
- `convert-v5`: the annotated report (`convert-v5-report.md`) now opens with an at-a-glance **Summary** — how many modules were migrated and how many items still need manual action (with the source line numbers) — so you see whether work remains without reading the full annotated config (CONVERT-FIDELITY-004)
- `mission.silence_atc_on_all_airbases` (default `true` in the template): emits `veaf.silenceAtcOnAllAirbases()`; `convert-v5` detects an active call in `missionConfig.lua` and preserves it (CONVERT-FIDELITY-003)
- TUI: the mission-folder prompts (`build`, `extract`, `convert-v5`, `prepare`) now show a hint clarifying the `.` default — `'.' = current folder → <absolute path>` (FR/EN) — so it's obvious which directory will be used (TUI-FOLDER-HINT-001)
- `build` / `mission.yaml`: **dynamic loading is now controllable from `mission.yaml` and profiles** via `build.dynamic_loading` (profile-overridable); the CLI flag becomes `--dynamic-mode` / `--no-dynamic-mode` and takes precedence. So a `TEST` profile can switch dynamic loading on without a CLI flag (IMC2-008)
- **Dynamic loading now works in both DEV and PROD** (FIX-DYNLOAD-PUBLISHED). Previously a dynamic build always emitted the DEV loader (`VeafDynamicLoader.lua`, which loads the *individual* `veaf/*.lua`), but a `published/` install only ships the concatenated **bundle** → runtime "no file" error. Now: **DEV** (`dev_mode: true`, `scripts_path` → a repo checkout) loads the individual scripts; **PROD** (`dev_mode: false`) loads the bundle `veaf/veaf-scripts.lua` from `scripts_path` (default `<mission>/published`, already in `published.zip` — no packaging change). In **both** modes the mission maker's `custom_scripts` are loaded from disk via a now-**generated** `src/scripts/veafDynamicConfig.lua` (mirrors the static load list; do not edit by hand). The build fails with a clear localized error if the framework loader is missing under `scripts_path`. Use case: keep scripts out of the `.miz`/`.trk` shared by players
- `build`: **guides users with a custom Lua script-loader toward the v6 way** (CONVERT-CUSTOM-LOADER-HINT, resolves IMC2-003). When an undeclared `src/scripts/*.lua` loads other scripts (`loadfile`/`dofile`/`require`/`a_do_script_file`), the build now explains that v6 replaces custom loaders with the `custom_scripts:` section of `mission.yaml` (each script loaded in order, with an auto-generated trigger), instead of the misleading "declare it in custom_scripts" advice. Generic heuristic — no per-loader parsing. This was the real cause of the "custom F10 menu missing" report: a v5 `VeafDynamicLoader.lua` (a mission-scripts loader, distinct from the v6 framework loader of the same name) registered the scripts and was not migrated
- `build`: **warns when a config-declared group is missing from the mission** (IMC2-004/004b). Groups referenced by `ASSETS` (asset name + `linked`), `QRA` (deploy lists), `cap_missions` and `combat_missions` must be placed in the Mission Editor; a missing one now raises a clear localized warning at build instead of failing silently at runtime (e.g. `veafAssets.respawn` → MiST "group not found"). The ASSETS→MiST dependency and the ME-placed-group requirement are documented
- **Aircraft groups are split into two independent pipeline steps** (ADR 0002, hard break): `spawnable_aircrafts` (→ `src/spawnables.yaml`, groups cloned at runtime by `veafSpawn`, identified by the `veafSpawn-` name prefix) and `dynamic_slot_templates` (→ `src/dynamic-slot-templates.yaml`, DCS Dynamic-Slot models, identified by `dynSpawnTemplate == true`). `extract-aircraft-groups` sorts each group by that criterion (the flag wins over the prefix), writing **both** files by default with a `--kind spawnable|dynamic-template` restriction; `convert-v5` produces both files from the v5 `settings.lua`. The legacy `.*[tT]emplate.*` name sort (which misrouted a spawnable named "… Template …") is dropped. Fixes three field issues from IMC-Day testing (6.4.0, see `tests-mct6-imcday §8`): (1) the orphan warning and the injected file no longer disagree — pre-v6 `aircraft-templates.yaml`/`templates.yaml` now produce a clear "ignored, use spawnables.yaml/dynamic-slot-templates.yaml" message; (2) recopying a deleted default is no longer silent; (3) `spawnables.yaml` is now actually injected (it was previously copied but consumed by no step). The TUI `extract`/`inject` aircraft prompts are updated to the new options (AIRCRAFT-INJECT-001..006)
- **Documentation chatbot (RAG)**: a free, bilingual assistant embedded in the docs site. A Cloudflare Worker (free tier) holds the Gemini key, enforces an Origin allow-list + per-IP rate-limit, and answers via retrieval-augmented generation — embedding the question (`gemini-embedding-001`), ranking the language's doc passages by cosine similarity **inside the Worker** against an embeddings index stored in KV (binary Float32 vectors, no paid vector DB), and streaming a grounded answer from `gemini-2.5-flash-lite`. A vanilla-JS resizable sidebar widget is wired into MkDocs (`mkdocs.yml`), and a CI workflow rebuilds the index when docs change. RAG was chosen over full-document injection, which hit the Gemini free-tier tokens-per-minute ceiling (~2 questions/min). Code under `poc/doc-chatbot/` + `doc/assets/chatbot/`; not yet shipped to the public site (needs CI secrets) (DOC-CHATBOT-001..004)
- **DCS country name→id table**: a generated `veaf_libs/data/dcs-countries.yaml` (92 countries, matched by canonical name, Mission Editor display name and short code) produced from the `Quaggles/dcs-lua-datamine` dump at a pinned ref — no DCS install needed. New `veaf_build.dcs_data` provider package and a `veaf_libs.dcs_countries.country_id_for_name()` lookup (DCSDATA-002)
- **`veaf-build update-dcs-data [--countries] [--radio] [--all]`**: one command to regenerate the datamine-sourced DCS reference data. The datamine is cloned at a **pinned** ref (`DATAMINE_REF`), making generation reproducible and the provenance ref is stamped into each artifact header (also fixes the previously non-reproducible `master`/`--depth=1` clone in the radio updater). `--all` regenerates only the **pure** `countries` artifact and skips the **hybrid** radio artifact (which carries manual `dcs_rejects_on_load` overlays + a bilingual doc), while `--radio` regenerates but warns those overlays must be re-applied. `update-radio-specs` is kept as a compat alias. New developer doc page *DCS data generators* (FR/EN) covering the datamine vs in-DCS-export sourcing strategies (DCSDATA-003/004)
- **CI freshness guards for DCS data**: a per-PR consistency workflow regenerates the **pure** country table against the pinned ref and fails if the committed file drifts (forgot `update-dcs-data` or hand-edited); a weekly drift-watcher workflow compares the upstream datamine HEAD to the pin and opens a PR bumping it + regenerating, for human review. Country-table generation now forces LF so the artifact is byte-identical across platforms (DCSDATA-005/006)
- **No more mandatory hand-placed blue+red ground groups** (DCSDATA-007b): the build now ensures each side coalition owns at least one unit. If a side has none, it injects a single **hidden** placeholder ground group (a real, roster-valid unit on the coalition bullseye, with a valid locked-ETA route) so DCS registers the side and the injectors don't skip groups. A unit-less synthetic country does **not** work — DCS purges it on save (verified in the Mission Editor, DCSDATA-007), so a real hidden unit is used. Mission makers can still place their own ground groups; the placeholder is only added when a side is empty. Bundled data: `mission_builder/data/placeholder_groups.json`
### Fixed
- **`inject-presets` no longer overwrites an aircraft's radio with incompatible frequencies** (`"Invalid frequency 243 MHz"`, mission won't save). The injector replaces a player aircraft's `Radio` with the preset resolved from `presets.yaml` (often via an `all` fallback); when every preset frequency is out of range for the aircraft's actual radio — e.g. a UHF/VHF preset resolved for a **Yak-52**, whose only radio is the sub-MHz ARK-15M — DCS rejected the save. The injector now skips a preset that is **wholly** out of range for a known aircraft and keeps its original radio (logged), using the existing `dcs-radio-specs.yaml` ranges. Partially-valid presets are still injected. (243 MHz is the legitimate UHF guard channel — valid for the F18/A-10; the bug was applying it to the Yak-52.) (FIX-PRESETS-RADIO-001)
- **`inject-waypoints` no longer produces routes DCS refuses to save** (`"Route has no waypoints with locked time!"`). A flight plan from `waypoints.yaml` (matched by aircraft type, so a catch-all plan rewrites every player slot) rebuilt each route with `ETA_locked=false` on every waypoint; DCS then rejected the save on each affected group. The injector now locks the first waypoint when the flight plan locked none, mirroring DCS. *(The separate `"Invalid frequency 243 MHz"` error is mission config — `presets.yaml` presets the reserved UHF guard frequency.)* (FIX-WP-ETA-001)
- **`inject-aircrafts` no longer produces a `.miz` that crashes the DCS Mission Editor on load** (`me_mission.lua:512`, `fixCountriesNames` → `attempt to index field '?' (a nil value)`). When `mission.yaml` injects aircraft into a country absent from the source mission (e.g. French spawnables in a USA/Ukraine-only `.miz`), the injector created the country **without** a `country.id`, which DCS dereferences as nil on load. Country-id resolution is now systematic — an id already present in the mission wins, else it is looked up in the generated DCS country table, else the build fails loudly — so a country is never emitted without an id. Completes the partial `bc37be3` fix (which only recovered an id when the country existed in another coalition) (DCSDATA-001)
### Changed
- **Faster `.miz`/Lua parsing** (PERF-LUADATA-PARSER): the pure-Python `luadata` parser (introduced by SECREV-001 to remove code execution) was slow on large missions. Two fixes — (1) it no longer re-sorts and rescans the whole entry list on every table append (`O(n²·log n)` → `O(n)` amortised, crippling on big DCS arrays like route points), and (2) it skips runs of insignificant whitespace/indentation at C speed instead of one byte per iteration. `read_miz` on a real 8.9 MB mission dropped from **0.86 s to 0.33 s (~2.6×)**; the whole build benefits. Parsing output is unchanged (array/sparse-key ordering, whitespace-insensitivity guarded by tests)
- `convert-v5` radio presets: **bespoke per-aircraft radio layouts are now reproduced iso-functionally** instead of being flattened to a shared preset (ADR 0003). When a v5 `["Radio"]` table is non-standard — channel rotation (Mi-24P channel 0 → preset #20), leading dummy / hardcoded specials / per-channel AM/FM modulations (AJS37), or extra radios — `convert-v5` emits a dedicated `{coalition}_{aircraft}` preset that maps each channel to its exact frequency (resolving `radioPresets*` tokens, keeping hardcoded literals) plus its modulation flag. Standard 1:1 layouts keep the lightweight shared assignment. `RadioDefinition.to_dict()` re-enables the `modulations` table so the AM/FM selection round-trips (PRESETS-FIDELITY-001)
- Quality ratchet (PRESETS-FIDELITY-001): dropped `presets_injector.presets_manager` from the mypy `ignore_errors` list and fixed the surfaced type errors; raised the coverage gate (`--cov-fail-under`) from 64 to 65 to track actual coverage
- Quality ratchet (QUALITY-001): dropped `presets_injector.presets_injector_worker` and `waypoints_injector.waypoints_injector_worker` from the mypy `ignore_errors` list and fixed the surfaced type errors (route/output-data annotations, `unit_type` `None` → `"all"` coalesce)
- Docs: audited the `defaults/mission-folder/` scaffold — every shipped file is consumed at first build, nothing dead (the old `presets.md` / `README-versions.md` are already gone). Corrected the `mission-maker/GUIDE` project-layout tree (FR/EN) to list every default (`options`, `versions.yaml`, `templates.yaml`, `veafDynamicConfig.lua`, `.gitignore`) with its role (DEFAULTS-AUDIT-001)
- Docs: documented the static-vs-dynamic VEAF script loading flow and clarified that `VeafDynamicLoader.lua` (framework layer) and `veafDynamicConfig.lua` (mission layer) are complementary, not duplicates — neither is obsolete (new [ADR 0004](docs/adr/0004-dynamic-script-loading.md), DYNLOAD-CLARIFY-001). ADR 0004 also records the origin of the mission-scripts loader ([VEAF-mission-converter#17](https://github.com/VEAF/VEAF-mission-converter/issues/17)) and the naming history behind the two near-identical filenames
- Quality ratchet (AIRCRAFT-INJECT): dropped `aircrafts_injector.aircrafts_injector_worker` from the mypy `ignore_errors` list and fixed the surfaced type errors; raised the coverage gate (`--cov-fail-under`) from 65 to 66. Removed the now-dead `lua_module` branch of the defaults-copy logic (every default now maps to a pipeline step)
- Default `mission.yaml` template realigned with the build/convert-v5 output (IMC2-007): the `pipeline:` section uses the split `spawnable_aircrafts` / `dynamic_slot_templates` steps, a `build:` section documents `dev_mode`/`scripts_path`/`dynamic_loading`, and `WEATHERMARK` defaults to `false` (reported as rarely useful). `convert-v5` emits the matching `build.dynamic_loading` comment. CLAUDE.md §9 adds a "defaults lockstep" rule to keep the template aligned with generation
- **Default `mission.yaml` now ships an active `modules:` block** instead of an all-commented one (FIX-DEFAULT-MODULES-ACTIVE). Previously a freshly-scaffolded mission had every module commented out → no VEAF F10 menu at all. The default now activates a baseline mirroring `convert-v5`: mandatory infrastructure + `SECURITY`, `RADIO`, `GROUNDAI`, `SPAWN`, `NAMEDPOINTS`, `MOVE`, `GRASS`, `WEATHER`, `REMOTE`, `AIRBASES`, `INTERPRETER`; community scripts (`CTLD`, `SKYNET`, …) `false`; config-requiring modules (`ASSETS`, `QRA`, `SHORTCUTS`, combat, …) shown as commented examples to uncomment
- **MiST is now mandatory**: it is a hard dependency of the VEAF scripts, so the build **always injects it** regardless of the `modules:` entry (an explicit `MIST: false` is ignored with a warning). The default `mission.yaml` lists `MIST:` in the mandatory infrastructure block (FIX-DEFAULTS-MODULES)
- `WEATHERMARK` removed from the default `mission.yaml` (the script is being retired; full removal tracked in WEATHERMARK-REMOVE)
- `convert-v5`: a fully-migrated `if veafXxx then … end` init block is now commented out **in its entirety** (not just the `initialize()` line), so any non-migrated custom code left in `missionConfig.lua` visually stands out (CONVERT-FIDELITY-002)
- **`mission.yaml` `modules:` is now the single source of truth** (hard break, pre-release — see ADR 0001). Skynet, CTLD, CSAR and QRA are configured under their `modules:` entry instead of the removed `external_modules:` / `qra:` sections: `modules.SKYNET` (flags), `modules.CTLD` / `modules.CSAR` (with a `settings:` sub-block for `ctld.xxx` / `csar.xxx` pairs), `modules.QRA` (`silence_all` + `definitions:`). The default template and the generated mission.yaml emit the unified shape; `convert-v5` produces it directly and now extracts CTLD/CSAR settings from `missionConfig.lua`. Docs (`MISSION_YAML_REFERENCE*`, migration guides) updated (MODULES-UNIFY-001..005)
- **Semantic validation of the `modules:` block**: an unknown module key, a removed `external_modules:` / `qra:` section, a wrongly-typed value, or a bad `enabled` / `logLevel` now raise a localized error at build time; an unrecognized `init:` parameter emits a warning instead of being silently dropped (MODULES-UNIFY-006)

### Security
- **RCE fixed**: parsing a `.miz` file no longer executes embedded Lua. `luadata.unserialize()` ran `lua.execute()` on untrusted mission content via an unsandboxed lupa runtime; it now routes through the pure-Python `_unserialize()` state machine (no code execution). Output is proven byte-identical to the former path across every real `.miz` fixture; a malicious-payload test asserts no execution. Also fixes a parser fidelity bug (backslash + CRLF/CR Lua line-continuations are now collapsed to `\n`, matching DCS Windows briefing texts) (SECREV-001)
- **Time-expression eval removed**: the weather moment parser replaced `eval()` with an AST evaluator accepting only numeric literals and `+ - * / // %`; names, attribute access, calls and exponentiation (a huge-number DoS) are rejected (SECREV-003)
- **Archive hardening**: `.miz` and `published.zip` extraction now validate every member through `veaf_libs.safe_zip.safe_extract_all`, rejecting Zip-Slip paths (absolute or `..`-escaping) and capping entry count and total uncompressed size (zip bomb) (SECREV-004, SECREV-005)
- `veafSecurity`: stopped logging the cleartext password at debug level (SECREV-009)

### Fixed
- **A mission with no `mission.yaml` now builds with the VEAF config** (FIX-BUILD-COPY-DEFAULTS): when the user had deleted/never had a `mission.yaml`, the build resolved its config from the (absent) file **before** copying the default into the folder → no `veaf-config.lua` (no VEAF F10 menu) and wrong module/community toggles. The default `mission.yaml` is now copied **before** the config is read, so a fresh mission gets the active baseline
- **Waypoint injection no longer destroys a flight's takeoff** (which made taking a player slot show the DCS *"YOUR FLIGHT IS DELAYED TO START, PLEASE WAIT"* message and blocked the slot). The injector rebuilt each matched group's route from scratch with only the injected waypoints, wiping its `TakeOffParking`/`Landing` points. It now **appends** injected waypoints to the existing route and **replaces only a waypoint of the same name** in place, preserving the original departure (FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE-001)
- **`build` crashed on a mission with an empty coalition side** (`AttributeError: 'dict' object has no attribute 'append'`): an empty DCS `country = {}` table deserializes to a dict (not a list), so injecting the hidden placeholder unit into an empty side failed. The country container is now coerced to a list first. Reproduced with a single-aircraft Caucasus mission (one populated side, the other empty) (FIX-EMPTY-COALITION-COUNTRY-001)
- **`convert-v5` lost tables containing `nil` values** (regression from SECREV-001): the pure-Python `luadata` parser never handled Lua `nil`, so any table with a `key = nil` entry — pervasive in v5 (`country = nil`, commented-out `["waypoints"]` blocks) — failed to parse (`Unserialize luadata failed … unexpected character`) and was silently dropped (e.g. the `settings` table of `waypointsSettings.lua`). `nil` values are now accepted and dropped per Lua semantics (the entry does not exist); no code execution is reintroduced (FIX-LUADATA-NIL-001)
- `prepare` **broken in the packaged exe** (IMC2-001): default files were resolved relative to `__file__` (a PyInstaller temp dir in the frozen exe) → `Default files not found`. They are now resolved from the target mission folder's `published/src/defaults/mission-folder` (where the updater installs them from `published.zip`), with the dev checkout as fallback
- The updater no longer **moves `README.md` into the mission folder** (IMC2-002): it had dead relative links and overwrote the user's own README. The online documentation is the single source; the README stays under `/published/`
- Scaffold `.gitignore` now excludes built `*.miz` files and the `/missions/` output folder, and drops the stale `/build/` entry (IMC2-006). Existing missions must apply this to their own `.gitignore` (it is `NEVER_OVERWRITE`)
- **Helicopter extraction data loss**: `aircrafts_injector` only captured the *last* helicopter group of each country because the match/capture block was dedented out of its loop; every helicopter group is now extracted (SECREV-002)
- `convert-v5` weather: zero-valued weather params are no longer silently dropped — 0 °C, 0 wind speed (calm), 0 wind direction (due North), 0 visibility and ground-level cloud base now survive conversion (truthiness guards replaced by `is not None`) (SECREV-006)
- Lua nil-deref crashes guarded: `veafCasMission.generateAirDefenseGroup` (nil group), `veafCarrierOperations.getAtcForCarrierOperations`/`stopCarrierOperations` (nil carrier/unit), `veafSpawnGround.spawnConvoy` (`size/2` on nil size) (SECREV-007)
- `veafAirWaves.addWave`: a plain array-of-strings wave now stores each group name instead of the whole parameter table (SECREV-008)
- `veafSecurity.isAuthenticated`: now falls back to the real `veaf.SecurityDisabled` flag instead of the never-assigned `veafSecurity.SecurityDisabled` (SECREV-009) — **corrected 2026-08-11**: `veafSecurity.SecurityDisabled` was not never-assigned, it was a *mission-facing config knob*, and the only places that assign it are mission configs, including our own demo mission. Retiring it silently gave three years of v5-era missions security **on** while they asked for it **off**. Both spellings are honoured again, the old one with a deprecation warning (`REVIEW-SECURITY-LAYER` ticket 03).
- `veafMove`: an empty mandatory group name is now rejected (`""` is truthy in Lua, so the old guard never fired) (SECREV-010)

### Changed
- Test coverage gate (`--cov-fail-under`) raised from 15 to 60 to track actual line coverage (~63%) after the SECREV regression tests, per the Quality Ratchet Policy
- `CLAUDE.md` §3: documented the **Quality Ratchet Policy** — every lot that substantially edits a mypy-excluded worker must drop its `ignore_errors` entry (and fix the surfaced type errors), and every lot that adds tests must bump `--cov-fail-under` to stay within ~2 points of actual coverage. The exclusions list and the coverage gate are now explicitly erode-only forms of debt
- CI: migrated GitHub Actions off the deprecated Node.js 20 runtime ahead of the forced 2026-06-16 migration. Bumped `actions/checkout@v4`→`@v5`, `actions/setup-python@v5`→`@v6`, `actions/upload-artifact@v4`→`@v6` (first major running on `node24`), and the third-party actions `JohnnyMorganz/stylua-action@v4`→`@v5`, `softprops/action-gh-release@v2`→`@v3`, `gitleaks/gitleaks-action@v2`→`@v3`. `snok/install-poetry@v1` is a composite action with no Node runtime and was left unchanged

---

## [6.4.0] — 2026-06-09

### Fixed
- `build`: a bare mission name (not a `.miz` file) now produces an **absolute** output path anchored in the mission folder. Previously the path stayed relative, so the weather step looked for the mission under `<folder>/src/` and aborted with `Base mission not found`. This surfaced through the TUI, whose mission.yaml-aware default now pre-fills the real mission name
- `mission_extractor`: `extract` no longer crashes with `KeyError: 1` — the script-file cleanup loop now accepts both the `(path, dest)` tuples returned by `get_veaf_script_files()`/`get_legacy_script_files()` and the dict descriptors returned by `get_community_script_files()` (regression from the COMM-001 refactor)
- `config_migrator`: `_lua_extract_string()` no longer absorbs quoted strings from chained Lua setters after `:setBriefing(…)` — search is now bounded to the matching closing parenthesis (regression from PR #390)
- `mission_builder_worker`: missing-files error now uses i18n keys (`builder.missing_files`, `builder.update_hint`) instead of hardcoded English; `spinner_context` for `dcs-bridge.lua` injection also uses `t("builder.inject_dcs_bridge")`; fatal error no longer calls `exit()` (raises via `logger.error` instead, giving a non-zero exit code)
- `paths.py`: `resolve_path` now raises `FileNotFoundError` instead of calling `exit(-1)` when a required path does not exist — makes the function testable and avoids `SystemExit(0)` on error
- `v5_converter`: removed dead `is None` branch inside `if mr.mission_export_path is not None:` (unreachable)

### Added
- TUI wizard: when a `mission.yaml` is present in the working directory, the mission-name prompts (`build`, `extract`, `inject-presets`, …) now propose its `mission.name` field as the default instead of the static `mission.miz`. Resolution precedence is: last saved preference > value derived from `mission.yaml` > static fallback
- docs: documentation overhaul (bilingual FR/EN) — pilot guide rewritten (deduplicated, accessible, jargon explained, `_auth` standardized); mission.yaml example updated to the unified `modules:` block; mermaid diagrams added (F10 radio menu, build pipeline, v5→v6 migration flow); screenshot placeholders added under `doc/assets/img/`; created the missing French `veafInterpreter` page; fixed broken `GUIDE.fr.md` links
- docs: French/English parity for the large reference docs — `LUA_API_REFERENCE.md` (all module sections brought to full depth: missing functions, parameters, and code examples translated), `TOOLS_REFERENCE.md` (troubleshooting, command reference, best practices, security, FAQ sections added), and `dcs-radio-specs.md` (header and critical-aircraft prose translated)
- `mission.yaml`: new `dcs_bridge` section to optionally inject `dcs-bridge.lua` as the first DO SCRIPT FILE trigger in the mission; `lua_path` is optional — when absent, the file is downloaded automatically from GitHub (`VEAF/VEAF-dcs-bridge`)
- `community_scripts:` section in `mission.yaml`: individually enable/disable community Lua scripts (MIST, CTLD, CSAR, etc.) — absent section keeps all scripts active
- `convert-v5`: generated `mission.yaml` now includes a `community_scripts:` section pre-populated from scripts detected in `published/src/scripts/community/`
- `inject-presets`: DCS aircraft radio frequency validation — preset frequencies are now checked against each aircraft's hardware specs at build time; invalid frequencies (e.g. 284 MHz on a MiG-19P or Gazelle M) emit a warning before DCS rejects them at mission load
- `doc/mission-maker/dcs-radio-specs.md`: human-readable reference table of valid radio frequency ranges for all 85 DCS player-flyable aircraft, sourced from [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)
- `scripts/extract_dcs_radio_specs.py`: standalone utility to regenerate `dcs-radio-specs.yaml` and the reference doc after a DCS patch
- Klogg highlight profile for DCS logs added to `tools/klogg/veaf.conf`; GUIDE.md and GUIDE.en.md updated to reference it
- i18n coverage: all log messages in `mission_builder_worker.py`, `aircrafts_injector_worker.py`, and `waypoints_manager.py` now use `t()` — no more hardcoded English strings; matching French translations added to `fr.json`; tests verify all `t()` keys exist in `en.json` and that `fr.json` covers every `en.json` key
- i18n: AST-based test (`TestI18nNoHardcodedStrings`) scans all Python source files for hardcoded English prose in `logger.*()`, `console.print()`, and `return` statements; `aircrafts_injector_worker.py` and `lua_config_generator.py` now fully i18n-clean; remaining files listed in `_TODO_EXEMPTIONS` for progressive cleanup
- i18n: 90 additional hardcoded English strings replaced by `t()` calls across 24 source files (`mission_builder_worker.py`, `mission_extractor_worker.py`, `mission_constants.py`, `radio_frequency_validator.py`, `veaf-tools-updater.py`, `build_profiles.py`, `paths.py`, `tui.py`, all `veaf_tools/commands/*.py`, `waypoints_injector_worker.py`, `waypoints_manager.py`, `weather_injector/**/*.py`); `_TODO_EXEMPTIONS` emptied; Rich markup filter added to scanner `_has_prose`; all new keys added to `en.json` and `fr.json`

### Changed
- `veaf-tools-updater` and `veaf-build` now adopt the decluttered output model too: the transient status line is cleared at program exit (no lingering line), and the updater's outcome lines ("already up to date", "successfully updated to vX") are now permanent. Standalone `veaf-tools` commands already inherit the model.
- CLI output is now decluttered: low-importance progress messages (`logger.info`) are shown on a single overwriting status line in interactive terminals instead of scrolling endlessly; permanent technical lines (`logger.tech`) and chapter headers (`logger.step`) stay on screen. Spinner/progress "done" lines no longer persist. `--verbose` (and non-interactive/piped output) restores the classic line-by-line display; the full log file is unaffected and still records every message. The `build` command adopts the new chapter/technical classification: each pipeline step shows an animated spinner during its slow operations (reading/writing the `.miz`, validating), the weather step shows a progress bar over the variants it creates, and the aircraft-groups injection is now visible during a build (was silent). Every pipeline step ends with a concise persistent result line (e.g. "injected presets into 127 aircraft", "injected waypoints into 0 aircraft groups", "injected N aircraft groups", "created 6 weather variants"), so a `0` count immediately flags a configuration problem.
- `weather` pipeline step now uses `versions.yaml` exclusively — `missions.yaml` is no longer recognised as an alias; rename any existing `src/missions.yaml` to `src/versions.yaml`
- `mission.yaml` syntax simplified: `lua_modules:` + `community_scripts:` merged into a single `modules:` block; mandatory modules use bare null syntax (`MODULE:` with no value) instead of `MODULE: {}`; `enable:` replaced by `enabled:`; block-style lists replace inline `[...]`; generated files include a YAML syntax quick-reference header; legacy keys still accepted with a deprecation warning
- `convert-v5`: modules in generated `mission.yaml` are now sorted by category (Infrastructure → Core → Features → Combat → External); optional modules without extra config use `MODULE: true` shorthand instead of two-line block; community script IDs are emitted in uppercase (`MIST`, `STTS`, …); parser accepts uppercase or lowercase community IDs
- `mission.yaml` (all generators): each section now includes a `# Doc:` link to the relevant chapter of the Mission Maker Guide; section headers and descriptions improved (security, external modules, mandatory modules explanation)

### Fixed
- `convert-v5`: the generated `mission.yaml` now pre-resolves module dependencies — enabling a module such as `CASMISSION` automatically enables the modules it requires (`GROUNDAI`, `SPAWN`, and their transitive dependencies). The build no longer needs to auto-enable them with a warning, and the generated file accurately reflects what will run. The conversion report lists the auto-enabled modules.
- docs: removed the obsolete `convert` command from the Mission Maker Guide command tables (FR + EN); corrected the false "CSAR not available via mission.yaml" note in the mission.yaml reference (CSAR is supported via `external_modules.csar`); updated the Debug Logging section to reflect the single `veaf-scripts.lua` loader and `global_log_level`/`logLevel` control; created the missing French `veafInterpreter` page (fixes a broken FR nav link); consolidated duplicate `[Unreleased]` changelog sections and translated the stray French entry
- `veaf-tools-updater`: fixed the dead documentation URL shown on first install (`VEAF-Mission-Creation-Tools-v6/…` → `documentation/dev/…`)
- `convert-v5`: generated `mission.yaml` now includes the YAML syntax quick-reference header (was only present in `generate-config` output)
- `convert-v5`: all comment strings in generated `mission.yaml` are now localized via `t()` — French users see French comments
- `convert-v5`: multi-line Lua briefings using `..` concatenation (e.g. `"line1\n" .. "line2\n"`) are now fully extracted; `\n` escape sequences are decoded to real newlines and emitted as YAML block scalars
- `convert-v5`: `global_log_level` now defaults to `info` instead of `debug` when no log level is found in `missionConfig.lua`
- `convert-v5`: command now accepts being called without arguments (uses current directory by default); `no_args_is_help=True` removed
- `convert-v5`: all warning and manual-review messages are now fully translated via i18n — no more hardcoded English strings visible when running in French locale
- `veafRadio`: SRS config file absence no longer emits a warning — downgraded to `debug` when the file does not exist on disk
- `veafGrass`, `veafSpawnGround`, `veafSpawnEffects`: nil-safe guards added around `ctld.builtFOBS`, `ctld.logisticUnits`, `ctld.beaconCount` — prevent crashes when CTLD is not loaded or not yet initialized
- `presets inject`: `presets_assignments` keys now support regex patterns (e.g. `A[-]10C.*`, `FW[-]190.*`) — exact match takes priority, then pattern, then `all` fallback
- `convert-v5` presets: per-aircraft radio assignments are now extracted from `radioSettings` — warbird aircraft (e.g. Bf-109K-4) are auto-assigned to `{coalition}_warbird`, VHF-primary aircraft (e.g. I-16, Spitfire) get a new `{coalition}_vhf_primary` preset; hardcoded and typePattern entries emit explicit warnings listing the recommended preset
- i18n: all injector messages (presets, waypoints) and the radio frequency validator are now translated to French — no more English messages in the `veaf-tools build` log
- `presets inject`: radio frequency warnings are now deduplicated by aircraft type — instead of one warning block per group, a single block is emitted per unit type listing all affected groups in parentheses
- `build`: bundle `presets_injector/data/dcs-radio-specs.yaml` into the PyInstaller executable — fixes `ModuleNotFoundError: No module named 'presets_injector.data'` at runtime
- `aircraft-groups inject` (mode `add`): skip groups whose name already exists in the mission instead of creating duplicates — prevents DCS crash on FA-18C/F-16C units missing `datalinks` after a v5→v6 conversion
- `convert-v5`, `generate-config`, `migrate-config`: mandatory Lua modules (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS) are now emitted as `{}` in `mission.yaml` instead of `enable: true`, which would cause a build error
- `convert-v5`: `_BASE_ALWAYS_ON` now includes COMMANDS (previously missing) and is derived from the canonical `MANDATORY_MODULES` set
- `mission.yaml` (all generators and the default template): fixed broken doc URL (`doc/MISSION_MAKER_GUIDE.md` → `doc/mission-maker/GUIDE.en.md`)

---

## [6.3.4] — 2026-06-07

### Added
- `mission.yaml`: new `custom_scripts` section to declare custom Lua scripts in `src/scripts/` — declared scripts are included silently and can opt out of automatic DCS load-trigger generation with `generate_load_trigger: false` (global default or per-script override)

### Fixed
- `veafQraManager.md/en.md`, `veafSkynetIadsHelper.md/en.md`: références à `missionConfig.lua` remplacées par `mission-script.lua`
- `mission_builder_README.py`, `mission_extractor_README.py`: arborescences mises à jour (`missionConfig.lua` → `mission-script.lua`, ajout de `mission.yaml`)
- `veaf.lua`: commentaires AIEN/CTLD/CSAR mis à jour (`missionConfig.lua` → `mission-script.lua`, suppression de `(since v5.0)`)
- Fixtures de test (`veafDynamicConfig.lua`, `mapResource`): `missionConfig.lua` → `mission-script.lua`

### Removed
- `convert` command removed — it was broken on v6 missions (crash on missing `missionConfig.lua`) and its purpose is fully covered by `extract` followed by `build`

### Fixed
- `lua_config_generator.py`: specifying `enable` (true or false) on a mandatory Lua module in `mission.yaml` now raises an error instead of silently overriding — mandatory modules are always active and cannot be enabled or disabled


- `build.py`, `mission_builder_worker.py`: catch `yaml.YAMLError` when loading `mission.yaml` — display a clear, localised error message (file, line, column, plain-language hint) instead of crashing with a Python traceback

### Documentation
- `MISSION_YAML_REFERENCE.md`, `MISSION_YAML_REFERENCE.en.md`: added "Syntax errors" section explaining the new error messages and common causes

### Changed
- `mkdocs.yml`, `docs.yml`: deploy documentation to `veaf.github.io/documentation/` (was `veaf.github.io/VEAF-Mission-Creation-Tools-v6/`)
- Documentation: French is now the default language; English (`*.en.md`) is the secondary language — all 35 documentation page pairs renamed accordingly
- `mkdocs.yml`: `fr` locale set as default, `en` as secondary
- `doc/mission-maker/scripts/veafSkynetIadsHelper.md`: complete rewrite — corrected API names (`veafSkynet.*`), added point defence modes, group integration modes, dynamic spawn, command centers, network deactivation, and deferred network access pattern
- `doc/mission-maker/scripts/veafQraManager.md`: added note on `veafQraManager.initialize()` requirement for dynamic slots
- `doc/mission-maker/scripts/veafCombatZone.md`: added radio menu security note, cleanup options, and display options
- `doc/mission-maker/scripts/veafRadio.md`: added practical callback examples (QRA start/stop, group destroy, DCS flag management)
- `doc/mission-maker/scripts/veafWeather.md`: added fog management section (static/animated/dynamic constants, trigger usage, chat commands)

---

## [6.3.3] — 2026-06-06

### Fixed
- `veafCacheManager.lua`, `veafTime.lua`, `veafUnits.lua`, `veafSkynetIadsMonitor.lua`: added missing `initialize()` function — the generated `veaf-config.lua` calls `<module>.initialize()` on every listed module; absence caused a DCS runtime crash (`attempt to call field 'initialize' (a nil value)`)

### Added
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` now warns when unexpected `.lua` files are found in `src/scripts/` (potential v5 residues that would be loaded as DCS mission scripts and may conflict with the bundled `veaf-scripts.lua`)
- `prepare.py`: `.gitignore` template added to `src/defaults/mission-folder/` — copied on `veaf-tools prepare` when absent; never overwritten (even with `--force`) to preserve user customizations
- `lua_config_generator.py`: `_MODULE_CATEGORIES` dict — groups modules into 4 tiers (Infrastructure, Core, Features, Combat) plus External; category comment headers (`-- ── Category ──`) are emitted in `veaf-config.lua` and (`# ── Category ──`) in the YAML template
- `lua_config_generator.py`: `_MANDATORY_MODULES` frozenset — if a mandatory module (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS) has `enable: false`, a warning is logged and the flag is ignored (module still generated)
- `lua_config_generator.py`: `_MODULE_DEPS` dict + `_resolve_deps()` — after building the effective module list, missing or disabled dependencies are auto-enabled in memory with a `logger.warning` per auto-added module; transitive chains are fully resolved; disk is never modified
- `src/defaults/mission-folder/mission.yaml`: `lua_modules:` comment block reordered to match category grouping; Infrastructure modules annotated as mandatory
- `veaf_libs/build_profiles.py`: new `resolve_profile(yaml_data, profile_name)` function — deep-merges a named profile from the `profiles:` section of `mission.yaml` onto the base config; lists are replaced, not concatenated; `profiles:` key is stripped from the effective config
- `mission_builder_worker.py`: `MissionBuilderWorker.__init__` now accepts `profile_name: str | None`; calls `resolve_profile` immediately after loading `mission.yaml`, before any other config resolution
- `veaf_tools/commands/build.py`: new `--profile` / `-p` option on `veaf-tools build` to select a named build profile at build time
- `src/defaults/mission-folder/mission.yaml`: new commented `profiles:` section with `TEST` and `SERVER` examples
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `profiles:` section; entry added to the Build Pipeline index
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): new "Build Profiles" section explaining `--profile` usage with an example
- `lua_config_generator.py`: CSAR YAML support — `external_modules.csar` in `mission.yaml` generates `csar.xxx` property assignments and `csar.initialize()` in `veaf-config.lua`, symmetric to the existing CTLD support
- `lua_config_generator.py`: CTLD block now wrapped in `if ctld then … end` guard and includes `ctld.initialize()` call — no more manual `ctld.initialize()` required in `mission-script.lua` when using YAML-first config
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): CSAR YAML-first configuration documented; Lua fallback sections kept for complex settings (e.g. `aircraftType` tables)
- `doc/developer/GUIDE.md` (+ `.fr.md`): new "Developer Mode" section documenting `dev_mode` / `scripts_path` — concept, activation priority chain, workflow
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `build:` section documenting `dev_mode` and `scripts_path` fields

### Fixed
- `lua_config_generator.py`: asset `description`, `name`, `information` fields containing `\n` or `"` now use Lua long-string syntax (`[[...]]`) instead of plain `"..."` — prevents Lua syntax error at mission load
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` no longer copies the default `versions.yaml` when a legacy `missions.yaml` already exists in `src/`; emits a warning prompting to rename it
- `mission_builder_worker.py`: added `missions.yaml` to `_DEFAULT_FILE_MODULE_MAP` (pipeline `weather`) — covers future orphan-warning cases
- `v5_converter.py`: migration backup now uses the original filename `missionConfig.lua` instead of `missionConfig.lua.bak` — consistent with all other backup files in `backup_v5/`
- `mission_builder_worker.py`: `_DEFAULT_FILE_MODULE_MAP` no longer includes `presets.md`; corresponding default file `src/defaults/mission-folder/src/presets.md` deleted — docs are online, silent file creation was undesirable
- `build.py`: warn when `src/aircraft-templates.yaml` exists in the mission folder but the `aircraft_groups` pipeline step is disabled or skipped

---

## [6.3.2] — 2026-06-05

### Added
- `pyproject.toml` + `veaf_tools/app.py`: point d'entrée Poetry `veaf-tools` (équivalent à l'exe) avec affichage de la version au démarrage
- `veaf-tools.py`, `veaf-tools-updater.py`: pause automatique en fin d'exécution quand lancé par double-clic (détection par remontée de l'arbre de processus Windows, compatible PyInstaller one-file)

### Fixed
- `aircrafts_injector_worker.py`: lookup de country case-insensitive + préservation du champ `id` DCS lors de la création d'une country → empêche le crash `attempt to index field '?' (a nil value)` dans `me_mission.lua:fixCountriesNames` au chargement de mission

---

## [6.3.0] — 2026-05-31

### Added
- `veaf.initialize()`: nil-check for `veafCommands` with a clear error message if using outdated `veaf-scripts.lua` (IMC-010)
- `doc/MISSION_YAML_REFERENCE.md`: new intro section distinguishing build-pipeline YAML files from runtime `mission.yaml` config, with an ASCII tree diagram (IMC-007)
- Tests for `_is_double_clicked()` (IMC-001), annotated content in `ConversionReport.to_markdown()` (IMC-002), `complete_src_folder_with_defaults()` filtering and orphan warning (IMC-008), and `luadata._sort()` mixed-key crash (SORT-001)

### Fixed
- `luadata.serializer.serialize._sort()`: crash `TypeError: '<' not supported between instances of 'int' and 'str'` when sorting a Lua table with mixed integer and string keys (regression seen during v5 → v6 mission conversion) (SORT-001)

### Changed
- `veaf-tools convert-v5`: annotated `missionConfig.lua` is now embedded as a code block in `convert-v5-report.md` instead of being written to `backup_v5/src/scripts/missionConfig.lua`; a `README.txt` is added to `backup_v5/` explaining its contents (IMC-002)
- `veaf-tools build`: auto-pauses before exit when launched by double-click (Explorer.exe parent process) without an explicit `--pause`/`--no-pause` flag — no pause in CI or piped output (IMC-001)
- `complete_src_folder_with_defaults()`: skips copying a default file when its associated pipeline step or Lua module is disabled in `mission.yaml`; emits a warning if the now-orphan file already exists in the mission folder (IMC-008)

### Removed
- `src/defaults/mission-folder/src/README-versions.md` — stray documentation file removed from the defaults folder (IMC-003)

---

## [6.2.0] — 2026-05-30

### Added
- `veafCommands.lua` — central priority-ordered command dispatcher for F10 markers and interpreter path; exposes `registerCommandHandler(fn, priority)` and priority constants (`PRIORITY_SHORTCUTS`…`PRIORITY_REMOTE`)
- `veafSpawnParser.lua` — spawn command text parser extracted from `veafSpawnCore.lua` (`convertLaserToFreq`, `markTextAnalysis`)
- `veafRemote.registerRemoteModule(name, fn)` — registry for hook-server remote commands (replaces hardcoded if/elseif in `executeCommandFromRemote`)
- `.backlog/` — operational backlog (per-lot directories)
- `doc/ROADMAP.md` — project roadmap
- `CHANGELOG.md` — this file
- `veaf.lp()` — lazy log argument proxy: arguments are only stringified when the active log level warrants it
- `mission.yaml: global_log_level` — replaces `--scripts-variant`; writes `veaf.ForcedLogLevel` in the generated `veaf-modules-config.lua`
- `--log-modules` option on `veaf-tools build` to selectively set log levels per module
- `.github/workflows/release.yml` — automated release on `published-v*` tag push (build + publish via GitHub Actions, zero manual intervention)
- `--ci` flag on `veaf-build publish` and `veaf-build build-and-publish` for non-interactive CI mode
- `veaf_tools/_version.py` committed stub — version injected by `worker.py` at PyInstaller build time, restored to `"unknown"` after; `app.py` and `veaf-tools-updater.py` resolve `VERSION` via `importlib.metadata` then `_version.__version__` fallback (VER-001)
- `about` command now prints `veaf-tools vX.Y.Z` before VEAF info (VER-003)
- Windows PE version metadata (FILE_VERSION / PRODUCT_VERSION) embedded in `veaf-tools.exe` and `veaf-tools-updater.exe` via `VSVersionInfo` generated dynamically at build time (VER-002)
- `ConfigMigrator` test coverage: integration tests on real fixtures (`mission-builder` and `demo-mission`) + unit tests for all 9 extractors previously untested (MIG-001, MIG-002)
- `doc/PIPELINE_REFERENCE.md` (+ `.fr.md`) — full YAML reference for all 4 pipeline steps (presets, waypoints, aircraft groups, weather/time) (DOC-001)
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) — hub page for `mission.yaml` top-level sections; category index and module index (DOC-002)
- `## Configuration (mission.yaml)` sections added to: `veafRadio`, `veafShortcuts`, `veafNamedPoints`, `veafCarrierOperations`, `veafAssets`, `veafSanctuary`, `veafCombatZone`, `veafAirWaves`, `veafQraManager`, `veafCasMission` (DOC-003 to DOC-006)
- `doc/mission-maker/scripts/veafRadio.fr.md` — created (was missing) (DOC-003)
- Module index in `MISSION_YAML_REFERENCE.md` completed with direct anchored links to every module's YAML section (DOC-007)
- `doc/index.md` (+ `.fr.md`) — hook sentence added before role table; `flowchart LR` → `flowchart TD` (REV-007)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — DCS Mission Editor added to prerequisites; base mission requirement (blue + red ground group) documented; Notepad++ listed as recommended editor (REV-008)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — CTLD/CSAR section: YAML-first approach via `external_modules.ctld` documented; CSAR YAML config noted as planned; `Intégration CTLD et CSAR` section added to French guide (was missing) (REV-010)
- `doc/mission-maker/MIGRATION_GUIDE.md` (+ `.fr.md`) — "Common Issues": refs to `missionConfig.lua` replaced by `mission.yaml` YAML config; "Reading the logs" entry added (Klogg + Notepad++) (REV-004)

### Changed
- `veaf_build/lua_tests.py`: `Optional[str]` migrated to `str | None` (UP007 now enforced)
- `pyproject.toml`: `UP007` removed from ruff ignore list — `str | None` union syntax enforced across all Python files
- `pyproject.toml`: `testpaths` changed to `["test/python"]` — test discovery now targets the new location
- 28 `test_*.py` files moved from `src/python/veaf-tools/**` to `test/python/**` — mirrors `test/lua/` convention (TST-001)
- `veaf_libs/paths.py`: `resolve_mission_file` glob branch now returns `.resolve()` path — fixes Windows short-path comparison
- `src/defaults/mission-folder/mission.yaml`: `versions.yaml` is now the canonical filename for the weather pipeline step; `missions.yaml` noted as legacy alias (REV-001)
- `src/python/veaf-tools/veaf_libs/lua_config_generator.py`: generated `mission.yaml` template comment updated to `versions.yaml` (REV-001)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — "Typical Build Workflow" simplified to `veaf-tools.exe build`; individual inject-* commands moved to collapsible Advanced section (REV-006)

### Changed (Shortcuts, Spawn, NamedPoints, CasMission, Security, Move, Radio, Remote) self-register via `veafCommands.registerCommandHandler()` — per-module `onEventMarkChange` functions removed
- Developer Guide (`doc/developer/GUIDE.md` + `.fr.md`) — Mermaid architecture diagram and runtime logging section updated to reference `veaf-config.lua` and `mission-script.lua` (v6) instead of the v5 `missionconfig.lua` (DOC-008)
- `veafInterpreter.execute()` delegates to `veafCommands.execute()` — hardcoded 8-branch if/elseif removed
- `mission_tools.DcsMission` — added `Group` dataclass and `iter_groups()` iterator; all injectors now share a single traversal path (DEEP-001)
- `mission_tools.DcsMission` — added `get_weather()` / `set_weather()` / `get_options()` / `set_options()` accessors; `WeatherInjectorWorker` updated to use them (DEEP-002)
- `WaypointsInjectorWorker`, `PresetsInjectorWorker` — local group traversal removed; now delegated to `DcsMission.iter_groups()` (DEEP-003)
- `veafCommands.lua` — added `PRIORITY_GROUNDAI = 62` constant (DEEP-005)
- `veafGroundAI.initialize()` — migrated from `veafMarkers.registerEventHandler` to `veafCommands.registerCommandHandler` at `PRIORITY_GROUNDAI` (DEEP-005)
- `veafSpawnParser.markTextAnalysis()` — common option defaults now in a single header block; type-specific defaults moved into their respective IF/ELSEIF branches (DEEP-006)
- `MissionBuilderWorker.__init__()` — now reads `mission.yaml`, resolves `dev_mode` / `scripts_path` from priority chain (CLI override > YAML > user config), and applies `log_modules_filter`; `build.py` simplified from ~180 to ~110 lines (DEEP-007)

### Added
- `veaf_libs.GroupInjectorWorker` — abstract base class for group-iterating injectors; `PresetsInjectorWorker` and `WaypointsInjectorWorker` now inherit from it (DEEP-004)
- `veafSpawnCore.lua` reduced from ~1834 to ~900 lines: parser extracted; 25-branch if/elseif replaced by handler dispatch loop
- `veafSpawnGround`, `veafSpawnAircraft`, `veafSpawnEffects` sub-modules self-register their spawn handlers via `veafSpawn.registerCommandHandler()`
- 7 remote modules self-register via `veafRemote.registerRemoteModule()` — hardcoded switch in `executeCommandFromRemote` removed
- Branch renamed from `develop/v6-new-build-system` to `develop`
- `veaf.BaseLogLevel` default changed from `trace` to `info`
- All 1233 `veaf.p(` log-argument calls migrated to `veaf.lp(` across all Lua scripts
- Single build output (`veaf-scripts.lua`) — `veaf-scripts-debug.lua` / `veaf-scripts-trace.lua` variants removed
- `build-and-release.py`: removed build-time comment-out step and `_create_lua_variant_files()`
- `cliff.toml`: `tag_pattern` now matches both `published-v*` and `v*` tags

### Removed
- `module.onEventMarkChange()` functions from all 8 command modules (routing now handled by `veafCommands`)
- Hardcoded 8-branch command dispatch in `veafInterpreter.execute()`
- Hardcoded 25-branch if/elseif in `veafSpawnCore.executeCommand()`
- Hardcoded module switch in `veafRemote.executeCommandFromRemote()`
- `--scripts-variant` option from `veaf-tools build` and `veaf-tools convert`
- `.github/workflows/changelog.yml` — superseded by `release.yml`

---

## [6.0.5] — 2025-12-10

### Added
- Waypoint extractor and injector commands (`extract-waypoints`, `inject-waypoints`)
- Lua script debug and trace variants for enhanced mission development
- Option to hide radio menus for mission creators
- Defaults included in published artifacts for better out-of-the-box experience
- Confirmation prompt before overwriting `RELEASE_NOTES.md` during build

### Changed
- IADS package is now optional — missions that don't require IADS can omit it
- Refactored script file handling using `DEFAULT_SCRIPTS_LOCATION` constant for improved consistency
- Improved logging levels in Lua scripts for better clarity during development
- Streamlined mission conversion with better path management and error signaling
- Improved error signaling for missing VEAF and community script files

### Fixed
- File locking issues during updater operations
- Script path handling in mission builder
- CI: StyLua CRLF → LF line ending fix for cross-platform CI

---

## [6.0.2] — 2025-11-12

### Added
- Centralized `veaf_libs` module for logging and progress management (shared across all tools)

### Changed
- Migrated logging and progress management from individual tools to `veaf_libs`
- Updated version to 6.0.2

### Fixed
- Bug corrections in presets injector

---

## [6.0.1] — 2025-10-27

### Added
- `--pause` option on all commands — keeps the terminal open after execution for review

---

## [6.0.0] — 2025-10-26

### Added
- New `veaf-tools` CLI with 11 commands: `build`, `extract`, `convert`, `inject-presets`, `extract-aircraft-groups`, `inject-aircraft-groups`, `extract-waypoints`, `inject-waypoints`, `inject-weather`, `about`
- Auto-update mechanism via `veaf-tools-updater.exe`
- Radio presets injector with kneeboard image generation (PNG)
- Aircraft groups extractor and injector
- Weather injector (YAML-driven)
- Scripts injector — injects VEAF Lua scripts into missions
- Mission normalizer — deterministic Lua serialization to minimize diff noise
- Mission converter — converts legacy missions to v6 format
- Persian Gulf airport frequencies
- Documentation restructured into `doc/` folder by audience (pilot, mission maker, developer)
- GitHub Actions CI: `lua-unit-tests` + `stylua-check` jobs
- 31 Lua test suites (~915 tests) with `luaunit`, `dcs_mocks.lua`, `run_tests.ps1`

### Changed
- Reworked publication mechanism — `build-and-release.py` now orchestrates the full pipeline
- Refactored build and release: removed `published/` directory handling in favor of local ZIP artifacts
- Enhanced logging and error reporting throughout

### Fixed
- Trigger insertion method rewrite for reliability
- Normalizer sort key stability
- Presets injector: no duplicate kneeboard image files, inject only into human units

---

## v5.x

See git tags (`v5.80.0` → `v5.103.3`) for full v5 history.
Last v5 release: **v5.103.3**.
