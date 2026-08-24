# FEAT-CUSTOM-SCRIPT-LOAD-DELAY — a custom script cannot be loaded after a delay

Status: ✅ done — delivered 2026-08-11; one in-game confirmation left to David

## Context

Reviewing the Foothold Caucasus `mission.yaml`, David asked whether
`strip_native_triggers: ["ScriptLoader 1", "ScriptLoader 2", "ScriptLoader 3", "AIEN"]` would
throw away Foothold's own script-loading triggers. Checked against the upstream `.miz`: those
four trigrules contain **nothing but `a_do_script_file` actions**, so removing them loses no
Foothold behaviour — the scripts are re-injected as `custom_scripts` and loaded by a
VEAF-generated trigger, which is the intent.

But the check turned up something the adoption **does** lose. Upstream staggers the loading:

| Trigger | Type | Condition | Scripts |
|---|---|---|---|
| `ScriptLoader 1` | `triggerStart` | — | Moose, Foothold_Localization, Foothold Config |
| `ScriptLoader 2` | `triggerStart` | — | zoneCommander, MA_Setup_CA, WelcomeMessage |
| `ScriptLoader 3` | `triggerOnce` | `c_time_after` **3 s** | Zeus, EWRS, Foothold CTLD, Foothold_CTLD_Red, Splash |
| `AIEN` | `triggerOnce` | `c_time_after` **12 s** | AIEN |

The built `.miz` loads **all fourteen scripts in one `triggerStart`**, in the declared order:

```
[6] Mission scripts loading - static  triggerStart  veaf-config.lua, mission-script.lua, Moose.lua,
    Foothold_Localization.lua, Foothold Config.lua, zoneCommander.lua, MA_Setup_CA.lua,
    WelcomeMessage.lua, Zeus.lua, EWRS.lua, Foothold CTLD.lua, Foothold_CTLD_Red.lua,
    Splash_Damage.lua, AIEN.lua
```

Order is preserved and each `a_do_script_file` runs synchronously, so a purely sequential
dependency is satisfied. What is **not** preserved is wall-clock delay. If a script needs a
frame to pass, or an asynchronous initialisation to complete (a Moose scheduler, a `world`
event), loading it immediately is not equivalent. AIEN's **12 seconds** are hard to read as
anything but "let the rest finish initialising".

`custom_scripts` offers no way to express this: the only knob is
`generate_load_trigger: true|false`. The workaround is to disable the generated trigger and load
the script by hand from `mission-script.lua` behind a timer — which pushes the mission-maker
into Lua for something the upstream expressed declaratively.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Per-script load delay in `custom_scripts` | ✅ |

## Open question — is it actually breaking anything?

Unknown, and worth settling before designing too much. Two ways to find out, cheapest first:

1. **Run the built Foothold in DCS** and read `dcs.log` for AIEN / CTLD initialisation errors.
   That is the pending in-game test anyway.
2. Read AIEN's and Foothold CTLD's entry points for what they assume is already loaded.

If nothing breaks, the delay is upstream belt-and-braces and this lot is a fidelity nicety —
still worth having, lower priority. If something breaks, it is a **correctness** issue for every
adopted mission that staggers its loading, and it jumps the queue.

## The open question, answered — 2026-08-11

This PRD said the flattening might be "upstream belt-and-braces", in which case the lot was a fidelity
nicety, or a **correctness** issue, in which case it jumped the queue. Option 2 was taken by reading the
code, which is the cheaper of the two routes it listed:

**AIEN inventories ground groups exactly once**, at load time (`populate_Db()`, upstream comment: *"launched
once at mission start and collect everything relevant that is already there"*). **Foothold creates part of
its groups from t+2 s onwards**, through `SCHEDULER:New(…, o:update(), …, 2, …)` and its deferred save
restores. Loading AIEN at t=0 therefore shows it a world those schedulers have not populated — and nothing
says so: no log error, just ground AI that never manages Foothold's groups.

So the lot delivered as a correctness fix. What remains is the in-game confirmation, which is the PRD's
own first suggestion and needs a DCS session: run the built Foothold and read `dcs.log`.

---

### The staging is now proven without DCS — 2026-08-24

Foothold Caucasus 4.4.1 was adopted fresh and the built `.miz` read back: 8 files at t=0, 5 at
`+3 s`, AIEN alone at `+12 s`, in static mode, with the generated `veafDynamicConfig.lua` scheduling
the same delays. So the *fidelity* half of this lot needs no session.

What still does is the PRD's own open question — whether the delay changes anything — and AIEN's log
cannot answer it: the line that would count each inventoried group is commented out upstream and there
is no total. A mission carrying an instrument that counts ground groups at t=0, +3 s, +12 s and +30 s
is prepared; see item 4 of `DCS-SESSION-TODO.md`.

## 01 — Per-script load delay in `custom_scripts`

Status: ✅ done
Type: feat

### Why

See the PRD. A third-party mission can stagger its script loading (Foothold: +3 s
and +12 s), and adopting it collapses everything into one `triggerStart`. `custom_scripts` cannot
express a delay, so the fidelity is lost silently — nothing in `validate` or the build mentions
it.

### Proposed shape

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/Moose.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12        # loaded by its own triggerOnce + c_time_after
```

- absent (the default) → today's behaviour exactly, in the shared `triggerStart`;
- present → the script moves to its **own** `triggerOnce` with a `c_time_after` condition;
- scripts sharing the same delay should share one trigger, so a five-script stage costs one
  trigger, not five — and their declared order must hold inside it;
- the ordering guarantee must stay intelligible: a delayed script loads after every
  non-delayed one regardless of where it sits in the list. Rejecting a list where a delayed
  script precedes a non-delayed one is one option; documenting the rule is another. Pick one and
  say so.

### Then close the loop with `convert-other`

Detection already reads the trigrules — it can read the delay too:

- [x] `detect_native_script_loaders` records each loader trigger's `c_time_after` seconds, when
      present.
- [x] The scaffold emits `delay_seconds:` on the affected scripts, so an adopted mission
      **reproduces the upstream staging by default** instead of silently flattening it.
- [x] `--update` reports a delay that changed upstream, like it reports added/removed scripts.

That is the real prize: the adoption becomes faithful without the mission-maker having to notice
the difference.

### Tasks

- [x] `mission.yaml` schema + validation for `delay_seconds` (positive number).
- [x] Trigger generation: group by delay, one `triggerOnce` + `c_time_after` per group, order
      preserved.
- [x] Same behaviour in **dynamic** builds (`veafDynamicConfig.lua`), or an explicit, documented
      refusal — `generate_load_trigger` governs both modes, this must not silently differ.
- [x] `convert-other`: detect and scaffold the delays (above).
- [x] Unit tests: no delay = today's single trigger; two delays = two extra triggers with the
      right seconds; order within a group.
- [x] Document in `MISSION_YAML_REFERENCE` (FR + EN) and mention it in `FOOTHOLD.md` as what
      reproduces Lekaa's staging.
- [x] CHANGELOG + version bump.

### Notes

Check first whether the flattening actually breaks Foothold (PRD, "Open question") — the answer
sets the priority, not the design.

### Delivered — 2026-08-11

#### The open question, answered — and it changes what this lot is

The PRD asked whether flattening the staging actually breaks anything, and said the answer sets the
priority. **It breaks something, silently.**

`AIEN.lua` ends with `AIEN.performPhaseCycle()`, whose initialisation phase calls `populate_Db()` —
commented, upstream, as *"launched once at mission start and collect everything relevant that is already
there"*. One inventory of ground groups, never repeated. Meanwhile Foothold's `BattleCommander:init()`
initialises its zones synchronously but creates groups from `SCHEDULER:New(self, function(o) o:update()
end, {}, 2, self.updateFrequency)` plus `_schedulePendingSurfaceAiRestore` / `_schedulePendingAirAiRestore`
— i.e. **from t+2 s onwards**.

So loading AIEN at t=0 instead of t+12 s hands it a world those schedulers have not populated. No log
error, no crash: just ground AI that never manages the groups Foothold created. This is a **correctness**
issue for every adopted mission that stages its loading, not a fidelity nicety.

Read out of the code, not measured in game — the in-game confirmation is still David's to make.

#### What ships

`custom_scripts.scripts[].delay_seconds` moves a script out of the shared `triggerStart` into a
`triggerOnce` of its own, **one trigger per distinct delay**, declaration order kept inside each group.

**The compiled form was read out of an upstream `.miz`** (Foothold_CA 4.4.1) rather than assumed, and it
differs from every other VEAF trigger in three ways that would each have been a silent bug:

| | A VEAF `triggerStart` | A deferred `triggerOnce` |
|---|---|---|
| dispatched from | `trig.funcStartup` (once) | **`trig.func`** (every tick) |
| condition | `return(c_predicate(…) )` | `return(c_predicate(…) and c_time_after(N) )` |
| action string | the actions | the actions **+ `mission.trig.func[i]=nil;`** |

That last suffix is what makes the "Once". And `c_predicate` is kept rather than replaced: its dictionary
entry reads `return VEAF_DYNAMIC_MISSIONPATH==nil`, which is what makes a *static* trigger inert in a
*dynamic* build — dropping it would have loaded the deferred script twice in dynamic mode.

The editor form gets a second rule beside the predicate one, and only `seconds`: an upstream mission also
carries `coalitionlist`/`unitType`/`zone` there, but those are leftovers of the editor's form and `zone`
names a zone of *that* mission.

#### Dynamic mode: the same behaviour, not a documented refusal

The ticket allowed either. `veafDynamicConfig.lua` already loops over a list, so its entries became
`{ name = …, delay = … }` and a delayed one is `timer.scheduleFunction`-ed. `generate_load_trigger`
governs both modes; a delay existing in only one would be exactly the kind of trap this lot is fixing.

#### The ordering decision the ticket asked us to take

**Documented, not enforced: the delay decides, not the position in the list.** A script at +12 s loads
after every undelayed one wherever it is written.

Refusing a list where a delayed script precedes an undelayed one was the alternative. It would reject
perfectly workable files — a maker may group their scripts by topic rather than by delay — so instead the
build **warns and names the pair**. That is the only case where reading the list top to bottom disagrees
with what actually runs, which is the confusion worth pointing at.

Same principle for a bad value: a zero, negative or non-numeric `delay_seconds` earns a warning and the
script loads in the shared trigger. Refusing the entry would silently drop a script the mission needs,
which is worse than losing the staging. `bool` is rejected explicitly — it is an `int` in Python, and
`delay_seconds: true` is a mistake, not a one-second delay.

#### convert-other closes the loop

`detect_native_script_loaders` records each loader trigger's `c_time_after`, `build_scaffold_yaml` writes
`delay_seconds:`, and `--update` reports a delay that moved upstream — the one change nothing else would
reveal, since `--update` deliberately preserves the tuned `mission.yaml`.

**Verified against the real mission**, not only against fixtures: run over Foothold Caucasus 4.4.1 it
detects 12 loaders — 6 with no delay, 5 at +3 s, `AIEN.lua` at +12 s — which is exactly the upstream
staging.

#### Tests, and two pre-existing defects found on the way

43 tests. The regression guard that matters most: with no delay declared, the specs and the shared
trigger are what they were.

- Three assertions in `test_dynamic_loading_prod.py` pinned the **syntax** of the generated list
  (`"x",`) rather than which scripts it holds, so they broke on a change that altered no behaviour.
  Rerouted through the script name.
- The factory-contract gate could not see attributes assigned by **tuple unpacking**, so it reported
  `custom_scripts` as no longer assigned when it plainly was. That is a blind spot, not a nuisance: a
  field assigned that way would have silently escaped the contract the gate exists to enforce. Fixed by
  flattening tuple/list targets.

The `custom_scripts` parsing moved out of `__init__` into `_parse_custom_scripts` so the new validation
is tested against the real code — the pre-existing parsing test had to **replicate** the loop, which is
how a copy comes to disagree with its original.

### Still open: the part no unit test can reach

Whether the staged build actually fixes AIEN's inventory in game. The reasoning is read out of upstream's
code, and the check is one run of the built Foothold with `dcs.log` open — which was the PRD's first
suggestion and is David's to make.
