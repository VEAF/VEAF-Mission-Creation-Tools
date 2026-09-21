# 04 — Hand-over to Skynet, and the three `mission.yaml` settings

Status: ⬜ ready

Where the alert lands, and how a mission maker turns any of it on. The first ticket in this lot that
touches Python.

## Handing over

The helper keeps the alert alive **per site**, and each cycle checks
`samSite:isTargetInRange(contact)` itself. When the aircraft finally enters the firing envelope it
calls `SkynetIADS:reportContact(dcsUnit, samSite)`.

A site that receives an alert therefore **does not light up**. It holds the contact and waits,
exactly as it would for an early-warning radar. The network is a **distributed EWR**, not a wake-up
trigger — that framing is David's, and it is what makes the feature fit Skynet instead of fighting
it. It is also what produces the domino: a battery that is warned lights up *and passes the word*,
so a line of batteries wakes in the direction of the penetration.

`reportContact` deliberately bypasses the kill-zone test — that is its documented contract, written
for the last line of defence. Here the bypass is harmless and in fact convenient: we have already
checked the envelope ourselves, so Skynet simply lets us decide. **Every other guard still
applies**: HARM silence, ammunition, power, destruction. Do not re-implement any of them.

`isTargetInRange` is annotated as an expensive call in Skynet's own source, so it is invoked **only
for sites actually holding an alert**. That is a property to assert, not a comment to write.

### Nothing here waits on a Skynet release

Both `isTargetInRange` and `reportContact` already exist, so the work can be written and unit-tested
against a **stubbed `SkynetIADS`** — which is what `test/lua/test_veafSkynetIadsHelper.lua` already
does (`_makeMockIads`, line 115). Only the in-game verification waits on
[the vendoring ticket](../../FIX-SKYNET-HELPER-AND-VENDORING/tickets/03-vendor-the-new-skynet-version.md).

A cleaner door in Skynet — something like `reportDistantContact`, putting the contact in the
network's own list so it ages, refreshes and logs with the others — is worth proposing **after**
this has run, designed on a measured need rather than a guess. Out of scope here.

## The three settings

Three keys under `modules.SKYNET`, per the decision of 2026-09-20. Everything else stays a constant:
detection period, the three graph periods, movement threshold, the 10 % margin, the 3-beat
tolerance, the heartbeat period and the forget delay. Those are stability and cost values nobody can
set without measuring, and **each exposed key is a contract to document, validate and keep**.

| Key | Default | Why exposed |
|---|---|---|
| enabled | **false** | changes the balance of every existing mission; opt-in |
| radio range | **20 km** | decides whether the network is connected on *their* map |
| propagation speed | **3 600 km/h** | decides the lead the alert takes over the aircraft |

### Naming — the one decision this ticket makes

The design settles what the keys *mean*, not what they are called. Recommendation, following the
flat snake_case of `include_red_in_radio` and `dynamic_spawn`:

```yaml
modules:
  SKYNET:
    enabled: true
    spotter_network: true               # ground units spot aircraft and relay the contact
    spotter_radio_range_km: 20          # how far one unit can pass the word
    spotter_propagation_speed_kmh: 3600 # how fast the alert crosses the map
```

The unit is in the key name on purpose: `spotter_radio_range: 20` reads as metres to half the people
who meet it, and the design's whole reason for exposing a **speed** was to stop a mission maker
changing something without seeing what it costs.

On the Lua side the module keeps metres and metres per second (`MaxPointDefenseDistanceFromSite` is
already in metres), and the **generator converts, once**, with a Python test pinning the exact line
emitted for the defaults. One conversion point, tested, rather than a conversion scattered through
the Lua.

### Emit only when the field is given

Follow the `dynamic_spawn` precedent exactly (`lua_config_generator.py:1857`), and read the comment
above it before writing anything: a line written **unconditionally from a `False` default** lands
~145 lines *after* the `module_settings:` hatch that sets the same variable, and silently undoes it.
That is not hypothetical — it broke `verify-mission-c`, the mission whose job is to verify this very
area, from 2026-08-20 until it was found on 2026-08-22, and its Skynet checks ran with the feature
off while reporting the documented default as a measurement.

Not emitting is safe rather than a behaviour change, provided `veafSkynetIadsHelper.lua` declares
the three defaults itself. An explicit `spotter_network: false` is a statement and still overrides a
hatch.

## Off by default carries an obligation

Or this becomes the `ewr` option all over again — present, undocumented, and dead for four years.
Two things are owed, and they are part of this lot's definition of done rather than someone's good
intentions:

- a **release-note entry that says the feature exists**;
- a **demonstration mission with it switched on**. `test/veaf-tools/verify-mission-c` is the natural
  home: it already runs with `SKYNET.enabled: true` and `dynamic_spawn: true`, and its README is
  where its checks are written down.

## Files this touches

| File | What |
|---|---|
| `src/scripts/veaf/veafSkynetIadsHelper.lua` | the hand-over, and the three defaults declared in the constants block |
| `src/python/veaf-tools/veaf_libs/lua_config_generator.py` | emit the three lines (conditionally), and the commented example in the generated `mission.yaml` |
| `src/defaults/mission-folder/mission.yaml` | §9.7 lockstep — the shipped default must match what the generator produces |
| `doc/MISSION_YAML_REFERENCE.md` + `.en.md` | the `modules.SKYNET` field table |
| `doc/mission-maker/scripts/veafSkynetIadsHelper.md` + `.en.md` | what the feature does, in mission-maker words |
| `test/veaf-tools/verify-mission-c/` | the demonstration, with it on |

Both doc pages already exist and are already in the `mkdocs.yml` nav, so no nav entry and no
`nav_translations` change is needed. **No support-bot index refresh either** — that is owed when a
page is added, renamed or retitled, not when a section is added to an existing one.

## Tests

- No `reportContact` while the aircraft is outside the envelope; **exactly one** when it enters.
- `isTargetInRange` is called only for sites holding an alert — count the calls against a site with
  no alert and assert zero.
- The other Skynet guards are left to Skynet: a site out of ammunition or under HARM silence is
  still reported to, and Skynet's own refusal is what stops it. Assert we do not second-guess it.
- Python: the three lines are emitted **only** when the field is present, and the km → m and
  km/h → m/s conversions produce exactly the expected Lua text at the defaults.
- Python: `src/defaults/mission-folder/mission.yaml` stays aligned with the generator's output.
- **Wiring**: the helper subscribes and the hand-over loop is scheduled — not just that the handler
  works when called by hand.

## Definition of done

- Hand-over written and covered; the three settings plumbed from `mission.yaml` to the Lua.
- Documentation updated in **both languages**, per the repo's docs rules.
- `poetry run test-lua` green; `stylua --check src/scripts/veaf/ test/lua/` clean.
- Python gate, the CI commands exactly: `poetry run ruff check src/python/ test/python/ veaf_build/
  --fix`, `poetry run ruff format --check src/python/ test/python/ veaf_build/`,
  `poetry run mypy src/python/veaf-tools/`, `poetry run pytest`.
- `poetry run docs-check` after touching `doc/`.
- Coverage floors bumped, Python (`--cov-fail-under` in `pyproject.toml`) and Lua.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section, with wording a
  release note can carry as-is.
