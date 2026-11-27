# FEAT-AIRFIELD-CHANNELS-FROM-DCS — airfield channels come from DCS, and a mission picks the ones it needs

Status: ✅ done — merged in #1041 (2026-10-01) · archived 2026-11-24

Opened 2026-10-01 from the Open Training Caucasus v6, where David found in flight that the radio
plan does not match what DCS shows on the F10 view. Measured afterwards: the mission's `bases`
collection is an **invented series** — 270.1, 270.2, 270.3… — while Batumi's tower is on 260.0 and
Krasnodar's on 251.0.

## What was measured (2026-10-01)

**The reference is already right, and already reproducible.** `veaf-build update-dcs-data
--airfield-freqs --dcs-path <DCS>` reads every `Mods/terrains/<Theatre>/Radio.lua`. Re-run against
the installed DCS and compared with the committed file: **392 airfields over 7 theatres, 0 missing,
0 whose frequency changed.** Nothing to fix there.

**The default channel collections do not descend from it.** They are hand-written, and it shows:

| collection | channels | airfields in the reference | state |
|---|---|---|---|
| `airports-caucasus` | 8 | 21 | 7 right, 13 airfields with no channel |
| `airports-syria` | 60 | 81 | 29 right, **Sanliurfa 251.6 instead of 252.7** |
| `airports-persian-gulf` | 29 | 26 | no name matches the reference at all |
| GermanyColdWar | — | 119 | no collection |
| Normandy | — | 86 | no collection |
| Sinai | — | 54 | no collection |
| MarianaIslands | — | 5 | no collection |

**Who got it wrong, and who did not.** Across 56 `presets.yaml` on David's machine, 3 658 airfield
channels: the ten **Foothold** missions are at **0 wrong**, Open Training Caucasus **v5** at 0,
Open Training Syria at 0. The two **v6** Open Training missions are the outliers — Caucasus v6 at
**0 right out of 13**, GermanyCW v6 at **0 out of 12**, both with the same invented `270.x` series.
GermanyCW's pre-v6 backup was at 7 right out of 12, so v6 regressed on what it replaced. The 43
remaining wrong entries are Sanliurfa, replicated wherever the defaults file was copied.

So the trigger is not missing data: it is that **nothing offers a mission the real frequencies**,
and the v6 authoring prompt let a series be invented instead.

**And a mission cannot take them all.** 392 airfields against the twenty-odd preset channels a DCS
radio holds. Which airfields deserve a channel is a per-mission decision — today nobody makes it,
because there is nothing to make it with.

## Measured during the lot (2026-10-01) — the premise above was wrong on one point

**The reference was not sound.** The "0 drift" compared the generator with its own output. Three defects:

- **Wrong source.** Persian Gulf's `radio.lua` gives every field one VHF frequency; the editor showed
  David **39.5 / 126.5 / 251.1 / 4.3** for Al Dhafra. The editor (`MissionEditor/modules/Mission/AirdromeData.lua`)
  asks DCS with `DCS.getATCradiosData(radioId)` — and the capture measured that DCS returns those four
  bands where the file has one (and four for Bandar-e-Jask, whose file entry is empty). My first reading,
  that the terrain configuration's `frequency` field overrode the file, was **wrong**: no airdrome of any
  of the seven theatres has that field. Where DCS completes the bands is not visible; the reference is now
  captured from a running DCS (fiddle hook, GUI environment), one dump per theatre. The hand-written
  Persian Gulf collection was right all along.
- **Wrong key.** Fields were keyed by radio callsign (`OMAA`, `GESETZ`), and a second field sharing a
  callsign was dropped (`LeMolay`, `RAM`, `As_Suwayda`). `radioId = 'airfield<id>_n'` gives the DCS
  airdrome id, which joins the runtime airbase dumps on all 7 theatres with no miss.
- **Wrong theatre names.** `GermanyColdWar` / `Sinai` (install folders) where missions say `GermanyCW` /
  `SinaiMap`, so convert-v5's aliasing never matched those two theatres.

**TACAN** is in `Beacons.lua`, joined by the same id; a VORTAC counts (Persian Gulf declares Al Dhafra 96X
and Liwa 121X that way). Caucasus: 6, matching every hand-written title.

**Name collisions across theatres:** eight Israeli fields exist on both Sinai and Syria (Hatzor,
Nevatim…), and an alias resolves to the first collection holding it. Captured: **all eight differ**
(Hatzor 250.6 on Sinai, 250.75 on Syria). So a name found on two maps is aliased `<name> (<theatre>)` in
the generated collections — a bare `Hatzor` fails the build instead of taking the other map's tower —
and a test pins aliases unique across all `airports-*`. For the same reason a new `bases` entry is
aliased `Base-<name>`: a mission's own copy of `airports-<theatre>`, possibly stale, comes first.

**The Caucasus v6 `270.x` series was not careless:** its `presets.yaml` header, and the Open Training prompt
(§ presets, *"L'ATC étant coupé, les fréquences de base sont des fréquences de trafic de la mission"*),
chose mission-specific traffic frequencies because ATC is silenced. Whether a silenced-ATC mission keeps
its own base frequencies is **David's decision**, not this lot's; the prompt line stays until he makes it.

**Build warning on stale defaults: not done.** Comparing file dates cannot work — the defaults live
inside the executable (their mtime is the extraction time) and a clone resets every mission file's mtime;
the mission records no tools version either. A content check (a base channel whose frequency differs
from the reference) would work; recorded, not built.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [channel collections are generated from the reference](FEAT-AIRFIELD-CHANNELS-FROM-DCS.md) | ✅ |
| 02 | [a mission picks the airfields that deserve a channel](FEAT-AIRFIELD-CHANNELS-FROM-DCS.md) | ✅ |

## Definition of done

- One command regenerates reference **and** collections after a DCS update; a second run is a no-op.
- A mission author — human at the CLI, or Claude through MCP — gets the real frequencies of the
  bases his mission actually uses, without typing a number.
- Each ticket closed with what was measured, not only what was changed.
- `CHANGELOG.md` entry; `doc/` updated where the radio plan is explained.

## Not in this lot, but found on the way

- **Eight VEAF tactical channels sit on real DCS towers** on Caucasus: Arco 1 (251.0) is Krasnodar's
  tower, Texaco 1 (252.0) Novorossiysk, Shell 1 (253.0) Krymsk, Shell 2 (254.0) Khanskaya,
  AWACS Rouge (260.0) Batumi, Tanker Rouge (261.0) Kolkhi, Magic 1 (265.0) Nalchik, Overlord 1
  (266.0) Mozdok. Choosing a band clear of towers **on all seven theatres** is a decision of its
  own, and it moves callsigns on every mission — David's call, not opened here.
- The two v6 missions still carry their invented series; fixing them belongs to their repositories.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the radio plan's airfield channels are typed, not derived, and two v6 missions invented theirs.** Found in flight on 2026-10-01: Open Training Caucasus v6 puts Batumi on 270.3 where DCS's tower is on 260.0, 11 of 13 base channels wrong; GermanyCW v6 the same with 9 of 12, both carrying an invented `270.x` series. The reference was wrong too (corrected 2026-10-01 during the lot: it parsed `Radio.lua`, which the Mission Editor only reads as a fallback — Persian Gulf got one VHF frequency per field where the editor shows four — and keyed fields by radio callsign); and the default `airports-*` collections are hand-written and have drifted from it: 8 channels for Caucasus's 21 fields, Sanliurfa at 251.6 instead of 252.7, no name matching at all on Persian Gulf, and nothing for GermanyColdWar, Normandy, Sinai or the Marianas. Measured across 56 presets.yaml and 3 658 airfield channels: the ten Foothold missions and Open Training v5 are at 0 wrong, so this is a v6 authoring defect, not a data one. Two tickets: generate the collections from the reference in the same command, and a CLI + MCP tool that reads a mission, lists the fields it uses (blue and red) and writes the channels it deserves — 392 airfields do not fit in twenty presets. Recorded but not opened: eight VEAF tactical channels sit on real Caucasus towers (Arco 1 is Krasnodar's, Magic 1 is Nalchik's)

## Tickets, in full

## 01 — channel collections are generated from the reference, not typed

Status: ✅ done

`src/defaults/mission-folder/src/presets.yaml` carries `airports-caucasus`, `airports-syria` and
`airports-persian-gulf`, written by hand. `veaf_libs/data/airfield-frequencies.yaml` carries the
truth, extracted from DCS. The two have drifted, and four theatres never got a collection at all.

### Measured (2026-10-01)

| collection | channels | reference | state |
|---|---|---|---|
| `airports-caucasus` | 8 | 21 | 7 right, 13 airfields with no channel |
| `airports-syria` | 60 | 81 | 29 right, Sanliurfa **251.6** where DCS says **252.7** |
| `airports-persian-gulf` | 29 | 26 | not one name matches the reference |
| GermanyColdWar / Normandy / Sinai / MarianaIslands | — | 119 / 86 / 54 / 5 | nothing |

`update-dcs-data --airfield-freqs` was re-run against the installed DCS: 392 airfields, 7 theatres,
**0 drift**. The reference is sound; only the step after it is missing.

### Done when

- `veaf-build update-dcs-data --airfield-freqs` regenerates **both** the reference and one
  `airports-<theatre>` collection per theatre it holds, in the defaults. Running it twice in a row
  changes nothing the second time.
- A generated collection carries, per airfield, what the reference has — UHF, VHF and FM — and the
  TACAN suffix the hand-written ones use (`Batumi / 16X`) wherever that is known; if TACAN is not in
  the reference, say where it comes from or drop it rather than losing it silently.
- **Names are settled, and the Persian Gulf case decides the rule.** Its 29 channels match none of
  the 26 reference names; establish whether these are other airfields, other spellings, or a theatre
  renamed in DCS, and make the generated name the one the reference uses. A hand-written channel
  that no longer matches anything is reported, not dropped in silence.
- Sanliurfa is 252.7 and nothing else still says 251.6.
- A test fails if a committed collection diverges from the reference — the drift this ticket exists
  to end must not come back. The reference itself stays out of CI (it depends on which maps are
  installed), but the *derivation* can be checked offline.
- The authoring prompt and `doc/` say that a mission takes the collection of its theatre, and never
  writes frequencies by hand. The v6 Open Training prompt is where the invented `270.x` series came
  from on two missions.

### Known trap

A theatre absent from the installed DCS must leave its collection **alone**, not empty it: the
reference only holds what the machine running the command has installed, and the file is shared.

### Done (2026-10-01), and what waits for DCS

- Capture: `veaf-build update-dcs-data --airfield-freqs --capture --dcs-path <DCS>` runs the Mission
  Editor's own logic in the fiddle hook's GUI environment and writes
  `veaf_build/dcs_data/airfield_freq_dumps/<Theatre>.json`, TACAN folded in from `Beacons.lua`. Run
  against mocks of `terrain` and `DCS` under Lua 5.1 (both sources, abandoned fields filtered); **never
  run against a live DCS yet**.
- Generation: `veaf-build update-dcs-data --airfield-freqs` rebuilds reference + collections from the
  committed dumps, rewriting only what sits between the two markers of the default `presets.yaml`;
  idempotent (tested). A theatre without a dump is not touched — the known trap holds by construction.
- Guard test: the committed reference and collections must equal what the committed dumps derive.
- **Waiting:** one capture per theatre (blank missions in `Saved Games/DCS/Missions/VEAF-capture-frequences/`),
  then one generation. Until then the default `channel_lists` names `Sochi-Adler` / `Sukhumi-Babushara`,
  which the hand-written collections do not have: 9 tests red, all from that.
- **Not done, David's decision:** the Open Training prompt's rule that a silenced-ATC mission uses its own
  base frequencies (see PRD).

### Captured (2026-10-01)

David ran the guided command over the six remaining maps in one go (Caucasus was its test run):
396 airfields with at least one frequency over 7 theatres — Caucasus 21, GermanyCW 119, MarianaIslands 5,
Normandy 89, PersianGulf 27, SinaiMap 54, Syria 81 — and 52 TACAN. No airdrome anywhere has a terrain
`frequency` field; every list came from `DCS.getATCradiosData`, which on Persian Gulf returns four bands
where `radio.lua` holds one. Sanliurfa is 252.7. All nine tests that waited for the capture are green.

## 02 — a mission picks the airfields that deserve a channel

Status: ✅ done

392 airfields across the seven theatres, against the twenty-odd preset channels a DCS radio holds.
A mission cannot carry them all, so someone has to choose — and today nothing helps, which is how
two v6 missions ended up with a series nobody checked against DCS.

David, 2026-10-01: *lire la mission, lister les bases occupées, et (en demandant à un user de
décider, ou en fournissant l'outil à Claude via MCP) choisir les bases bleues (et rouges d'ailleurs)
qui méritent un canal et mettre à jour le plan de freq.*

### What it reads

The mission already says which airfields matter, and says it in more than one way:

- `warehouses` — which airfields a side holds, and `exclude_airports` for those it holds without
  offering slots;
- the player slots actually placed on each field, and the dynamic-slot links;
- FARPs and ships, which need a channel too and are not in the airfield reference at all.

An airfield a side holds **with slots** is the obvious candidate; one held without slots, or an
enemy field, is a judgement call — a SEAD mission may well want the tower of the field it is going
to strike. Hence a proposal, not an automatic verdict.

### Done when

- A command lists, for a mission folder, every airfield the mission uses, with side, whether it has
  slots, how many, and the frequencies the reference gives it — ranked, so the obvious ones come
  first and the budget is visible against the channel count.
- The choice can be made two ways, over the same code: a human at the CLI, and **an MCP action** so
  Claude can do it while authoring. The MCP action proposes and applies; it never silently decides
  what the mission author did not ask for.
- Applying writes the `bases` collection of `src/presets.yaml` with the **real** frequencies from
  the reference, keeps the hand-written tactical and flight channels untouched, and is idempotent.
- It refuses, with a message, to write a frequency that is not in the reference — that is the defect
  this whole lot comes from.
- Red fields are offered on the same footing as blue: *"et rouges d'ailleurs"*.
- Tested on the two real cases: Caucasus v6 (13 base channels, all wrong today) and GermanyCW v6
  (12, all wrong), each ending with the frequencies DCS shows on its F10 view.

### Open question for whoever takes this

Where does the channel **number** come from — the order in the collection, or a fixed map so that
channel 3 is the same field between two missions on the same theatre? The ten Foothold missions
share one plan and would answer this if their numbering is deliberate; worth reading before
choosing.

### Done (2026-10-01)

`presets_injector/airfield_channels_manager.py`, served by `veaf-tools content airfield-channels` and the
MCP actions `describe_airfield_channels` (read-only) / `set_airfield_channels`.

- **What it reads.** Side from `warehouses.airports[id].coalition`; dynamic slots as the build leaves them
  once `src/warehouses.yaml` is applied (declared side, `airports:` list, `exclude_airports`); parked
  player units by their group's first `airdromeId`, dynamic-slot templates excluded. Measured on both v6
  missions: their bases are known by their warehouses, not by parked slots (almost all slots start in the
  air or on a FARP/ship). FARPs and ships are not listed — no reference frequency to give them.
- **Channel number: the mission's `channel_lists`, untouched.** The command writes the `bases`
  collection only. An airfield already there keeps its alias (matched by DCS name, or by its first word
  when no other field of the theatre shares it — `Base-Krasnodar` is refused, two Krasnodar exist); a new
  one is aliased `Base-<DCS name>` (a bare name could be shadowed by a stale copy in the mission's `airports-*`); the written channels on no radio are reported for the author to place.
- Dry run on a provisional reference (from `Radio.lua`, scratch only): GermanyCW v6, 12 of 12 `Base-*`
  recognised; Caucasus v6, 11 of 13 (`Base-Krasnodar` ambiguous, `Base-MinVody` ≠ `Mineralnye Vody` —
  both reported as left untouched).
- **Run on the real reference (2026-10-01), on copies of both v6 missions** (their repositories untouched):
  GermanyCW 12 of 12 base channels rewritten with DCS's frequencies under their existing aliases;
  Caucasus 11 of 13, plus `Base-Krasnodar-Pashkovsky` / `Base-Mineralnye Vody` added and reported as on no
  radio, `Base-Krasnodar` / `Base-MinVody` reported as left untouched. A second run writes nothing.
- **Written as text, not through a YAML round trip.** ruamel rewrote ~40 lines of the GermanyCW file it
  had no business touching (`{ a }` → `{a}`) and its line endings; the rewrite now changes only the
  lines of the written entries — 42 lines on Caucasus, CRLF and flow style kept.
- **Fixing the two missions themselves belongs to their repositories.**
