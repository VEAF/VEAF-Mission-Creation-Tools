---
status: rejected
---

# VMCT edits missions cold; it does not drive a live Mission Editor

[nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms) ships something VMCT has no equivalent of:
126 `me <noun> <verb>` commands that mutate the mission **currently open in the DCS Mission Editor**,
with no sim running. Our own [ADR 0014](0014-mission-editor-mcp-editor-parity-layer.md) editor-parity
layer mutates a closed `.miz` instead, so the Mission Maker has to close the editor, let us write, and
reopen. Adopting the live approach was investigated on 2026-08-01 and is **rejected**.

## What forced the question

VMCT already owns most of the plumbing, which is what made this look cheap:

- [dcs-fiddle-server.lua](../../src/scripts/other/dcs-fiddle-server.lua) is installed as a
  `Saved Games/DCS/Scripts/Hooks/` hook, serving HTTP on `127.0.0.1:12081`.
- Its `handle_request(luastring, env)` already has two branches: `net.dostring_in(env, …)` for the
  sandboxed mission environment, and — with `env=default` — a plain `loadstring` **in the hook's own
  environment**. That second branch is exactly dcs-sms's `--target gui`.

So the question reduced to: can a hook reach the editable mission table? dcs-sms's design spec asserts
it can, on the grounds that "the GUI hook env and ME env share one Lua VM". **That assertion is
wrong**, and their own shipped code contradicts it — their hook carries a comment explaining that
`UpdateManager.add` does nothing from the hook environment, which is why their poller had to move into
an editor mod.

## What was measured

Every claim below was established against DCS on David's machine, not inferred. Method and raw
figures: [DCS hook environment boundaries](../exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md).

1. **A hook does get a per-frame tick outside a mission** — `onSimulationFrame` fires at ~28 Hz at the
   main menu and in the editor. 2305 ticks elapsed before the first `onMissionLoadBegin`. The widely
   repeated claim that hook-based tools "die at the main menu" is false here.
2. **The bridge answers outside a mission.** `env=default` returned `alive: Lua 5.1` with DCS sitting
   at the main menu.
3. **The hook environment is not the editor's Lua state.** All 44 editor modules visible from a hook —
   `me_mission`, `me_trigrules`, `me_route`, … — hold exactly three keys (`_M`, `_NAME`, `_PACKAGE`).
   They are empty husks left by `module()` registering its table *before* the file body runs, then the
   load failing on a dependency (`me_modulesInfo.lua:21: module 'DcsWeb' not found`). The 9860 lines of
   `me_mission.lua` never executed. No table carrying a `theatre` field exists anywhere reachable.
4. **The editor cannot be reached by shadowing a module either.** `MissionEditor.lua:22` *overwrites*
   `package.path` with install-relative entries only — `lfs.writedir()` is absent. Dropping a
   replacement module in `Saved Games\DCS\Scripts\` works for anything loaded after `UserHooks.lua`
   (verified: our copy of `UpdateManager` did load) but the editor's own path never looks there.

## Decision

Rejected. Reaching the editor's Lua state requires **writing into the DCS installation directory** —
a module under `<DCS>\MissionEditor\modules\` plus a patch to `MissionEditor.lua` to load it. That is
what dcs-sms does, and point 4 shows the choice was forced rather than lazy.

The price of that entry ticket:

- The patch is **erased by every DCS update** (dcs-sms's own installer detects and re-applies it).
- It needs **administrator elevation** wherever DCS lives under `Program Files`.
- It means owning a `dxgui` editor mod, against an undocumented GUI toolkit, with no API stability
  promise from ED.

Against a workflow that produces nothing replayable. VMCT's value is that `mission.yaml` → build →
`.miz` is reproducible, diffable and testable; a mission mutated by voice in a live editor is none of
those. The cost is recurring and the benefit is a convenience.

## Consequences

- The editor-parity layer of ADR 0014 stays cold-`.miz`, and that is now a documented choice rather
  than an unexamined default.
- **Nothing in the guided-checklist lot depends on this.** It turned out not to need any editor work at
  all: the cockpit-training actions are native functions callable from the mission scripting environment,
  so the feature is a runtime module driven by data — see `.backlog/FEAT-ASSIST-CHECKLISTS/`.
- The four measured facts are kept in the exploration note because they outlive this decision: the
  out-of-mission tick and the `package.path` shadowing trick are usable for other purposes, and the
  environment boundary is the kind of trap that costs a day to rediscover.
- Should this ever be revisited, the question to re-test is narrow: does ED still overwrite
  `package.path` in `MissionEditor.lua` without consulting `writedir`? If that ever changes, a
  non-invasive editor mod becomes possible and this ADR should be reopened.
