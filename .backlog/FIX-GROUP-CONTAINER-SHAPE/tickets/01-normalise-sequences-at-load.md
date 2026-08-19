# 01 — Normalise a mission's sequence tables once, at load

Status: ✅ done — 2026-08-19. `mission_tools.sequence_normalisation` normalises on the read path,
so the eight readers stop guessing without eight edits. The path-scoping earned itself: a blanket
"every numeric-keyed table" would have renumbered `payload.pylons` and moved every weapon to a
different station.
Type: fix
Files: `src/python/veaf-tools/mission_tools/miz_tools.py` (the read path), a new normaliser module,
tests

## The three measurements this ticket is built on

Taken 2026-08-19, with the settings `write_miz` actually passes to `luadata.serialize`
(`indent="  "`, `always_provide_keyname=True`, `sort=True`), before touching anything:

| Question | Answer |
|---|---|
| Does a list serialise like the contiguous `1..N` dict it came from? | **Yes, byte-identical** |
| Does a holed dict serialise with its holes? | **Yes** — `[1]`, `[3]` come back out as written |
| What does the parser return for each? | list → `list`, contiguous dict → `list`, **holed dict → `dict`** |

So the parser already hands back a list whenever the keys are contiguous. A reader assuming a list is
right on every well-formed mission and wrong only on a holed one — which is why eight of them have
survived, and why the failure appears at a random subsystem rather than at the edit.

## The chosen normal form: a **list**

The opposite of `FIX-WAREHOUSES-LIST-FORM`'s choice, and for a reason worth writing down: DCS keys
`warehouses.airports` by **airdrome id**, so the key carries information and normalising to a dict
preserves it. A group container's key carries nothing but **position**, so the sequence is the honest
form — and it is already what the parser returns in the nominal case, which is what makes an untouched
mission byte-identical.

## The trap: this must be path-scoped, not "every numeric-keyed table"

`payload.pylons` is keyed **by station number** — a real FA-18C carries stations 1, 4, 5, 6 and 9, and
`describe_units` says so in its own description. Normalising every numeric-keyed dict to a list would
turn `{1, 4, 5, 6, 9}` into positions `1..5` and **silently move every weapon to a different station**:
a new silent data-destroyer, of exactly the family this lot exists to stop.

So the normaliser descends an **explicit spec** of the mission's sequence tables, enumerated from the
readers that already treat them as sequences rather than guessed:

`coalition.<side>.country` · `…country.<category>.group` · `…group.units` · `…group.route.points` ·
`…points.task.params.tasks` (nested, a `ComboTask` holds tasks) · `triggers.zones` ·
`…zones.verticies` · `drawings.layers` · `…layers.objects`

`verticies` is not a typo here: it is **DCS's own misspelling**, and the key a mission file really
carries — every mission under `test/veaf-tools` writes `verticies`, none writes `vertices`. The
correctly spelled key is accepted beside it in case DCS ever repairs its own. (The VEAF MCP's
`vertices` parameter is spelled properly, because that one is our naming rather than the file
format's — which is what makes the pair look like an inconsistency.)

Anything not on that list — `payload.pylons` first among them — is left exactly as it is.

## Done when

- A dict-shaped or holed container is a list by the time any reader sees it
- Normalisation happens **once**, on the read path, not in the eight readers
- `payload.pylons` is provably untouched, station numbering included
- A mission nobody touched round-trips byte-identically, asserted with
  `testlib.writer_preservation.assert_round_trip_identical`
- The eight sites listed in the PRD stop being wrong, without eight edits
