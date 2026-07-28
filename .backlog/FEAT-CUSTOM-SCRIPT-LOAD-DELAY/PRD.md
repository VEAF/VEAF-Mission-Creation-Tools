# FEAT-CUSTOM-SCRIPT-LOAD-DELAY — a custom script cannot be loaded after a delay

Status: ⬜ ready

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
| 01 | [Per-script load delay in `custom_scripts`](tickets/01-per-script-load-delay.md) | ⬜ |

## Open question — is it actually breaking anything?

Unknown, and worth settling before designing too much. Two ways to find out, cheapest first:

1. **Run the built Foothold in DCS** and read `dcs.log` for AIEN / CTLD initialisation errors.
   That is the pending in-game test anyway.
2. Read AIEN's and Foothold CTLD's entry points for what they assume is already loaded.

If nothing breaks, the delay is upstream belt-and-braces and this lot is a fidelity nicety —
still worth having, lower priority. If something breaks, it is a **correctness** issue for every
adopted mission that staggers its loading, and it jumps the queue.
