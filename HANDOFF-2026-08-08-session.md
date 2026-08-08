# Handoff — 2026-08-08: six lots landed, and what is left

> Supersedes `HANDOFF-2026-08-07-session.md`, whose four PRs are long merged; its one surviving
> item (**cut a release**) is repeated below because it is still the highest-value next action.
> `.backlog/README.md` remains the source of truth for scope and status; this file is only this
> session's residue.

## 1. What landed

`develop` went from **6.13.30** to **6.13.36**. Coverage 79.33% → 79.69%.

| PR | What |
|----|------|
| — | Two decisions closed by direct commit: the historical documents are **exempt** (repairing a record of a past state into one that never existed is worse than a dead link), and `FIX-ATIS-NIL-MESSAGE` is ✅ |
| [#669](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/669) | The datamine pin bump the robot had stopped producing, plus its radio half merged by hand |
| [#671](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/671) | All 14 Dependabot alerts — **now 0 open**, verified after the rescan |
| [#672](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/672) | `CHORE-TOOLING-GATES` 02+03 — the lot closes |
| [#673](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/673) | `SECREV-2` ticket 04 — updater and `.miz` reader fail closed |
| [#674](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/674) | `SECREV-2` ticket 05 — both high-severity correctness bugs |
| [#675](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/675) | `FIX-RADIO-LAYOUT-GAPS` ticket 01 |

Branch hygiene, done once and prevented from recurring: **86 branches deleted** (54 local → 2,
70 remote → 3), each with its content proven present in `develop` first, and
`deleteBranchOnMerge` switched on so it cannot rebuild.

## 2. Four things that would cost a day to rediscover

- **`logger.error` raises `typer.Abort`.** It is not a log line, it is an abort. That is the whole
  mechanism behind VMR-011: the author reached for `logger.warning` to avoid stopping the run and
  got fail-open as the side effect. Tests must assert `typer.Abort`, not a `False` return.
- **A scheduled PR-opening workflow is silenced by its own leftover branch.** `dcs-data-drift.yml`
  always pushes to the fixed name `chore/datamine-pin-bump`; the branch survived a closed PR, so
  the action had nothing to push and opened nothing, for three weeks. Deleting the branch fixed it
  instantly. **When a robot goes quiet, check its branch before its code.**
- **`.styluaignore` excludes `src/scripts/veaf/dcsUnits.lua`** (generated). A direct
  `stylua --check` on that path bypasses the ignore file and fails misleadingly.
- **The radio specs are hybrid.** `update-dcs-data --radio` overwrites the manual layer — it drops
  `MiG-15bis`/`MiG-15bis_FC`, discards `dcs_rejects_on_load`, and replaces the hand-written French
  page with the generated English one. Generate at both pins into temp dirs, diff, merge only the
  new keys; the result must be insertions only.

## 3. Decisions David took this session

- **a** — `/login` becomes per-player by UCID, fail-closed with no actor. Menus can only be scoped
  to a **group** (DCS has no per-unit menu API), so a secured command may no longer be posted for a
  coalition, and a group's level is the **minimum** of its occupants. David added a toggle idea:
  a command that temporarily raises a group to the requester's own level — identified channel only,
  capped at the requester's level, time-boxed.
- **b** — tiers are renamed `OPEN` / `KNOWN_PILOT` / `SENIOR_PILOT` / `ADMIN`, values unchanged
  (90/10/1), old names kept as deprecated aliases for one release. Note there is a **fifth** gate,
  `MM` (Mission Master), password-only with no identity, used by `veafSpawnCore`.
- **c** — exempt the historical documents. Done.
- **d** — layered architecture: tool bricks → command bricks (CLI/TUI/MCP) → interfaces (web, a ME
  mod). Measured state: the **action layer is imprisoned in the MCP** — the CLI imports nothing
  from `veaf_mission_mcp`, so the 29 actions are unreachable outside it. That is why no non-AI
  fallback exists. Extract it first; the ME mod becomes a façade rather than a rewrite.
- **e** — `FIX-ATIS-NIL-MESSAGE` ✅. Done.
- **f** — keep the doc chatbot, fix its alerts. Done.

## 4. Where to resume

1. **Cut a release.** `develop` is at 6.13.36, last published is **6.13.0** (2026-08-01). 36 patch
   versions including every security fix above. Unblocked, and still the highest-value action.
2. **`REVIEW-SECURITY-LAYER`** (decisions **a**+**b**) — deliberately *not* started in autonomy:
   it is Lua that changes existing missions, and **this workstation has no Lua 5.1**, so there is
   no local red/green. Do it with a way to run `test-lua`, or accept CI as the only gate knowingly.
3. **`FEAT-ACTION-LAYER`** (decision **d**, step 1-2) — extract the action layer out of the MCP,
   then wire CLI/TUI onto it. No new behaviour; an ADR to fix the contract.
4. **`SECREV-2`** — ticket 04's network-download caps, then 06 (24 medium) and 07 (108 low/info).
5. `CHORE-SMS-QUICK-WINS`, and `FEAT-MCP-MUTATION-ACTIONS` ticket 01.

## 5. Waiting on David alone

- **The server hook is still not deployed** — both SECREV-2 criticals remain live on the VEAF
  servers. Nothing in this repository can close it.
- **The CLI/TUI ergonomics discussion** he asked for (25 `@app.command` entries today).
- **`FIX-RADIO-LAYOUT-GAPS` 02 and 03**, now measured rather than open: the datamine declares a
  *single* radio for the AJS-37 and **no `panelRadio` at all** for the ten FC3 types. Neither gap
  can be regenerated away; both need a hand-written VEAF overlay, which is one design decision, not
  two tickets. (`F-14BU` is no longer missing — it came with #669.)
- **`.claude/worktrees/` holds 889 MB** across 12 directories, only one of which is a registered
  worktree. They caused a false positive during this session. `silly-solomon-acb446` has **14
  uncommitted files**, so nothing was deleted.
- `ENRICH-DEFAULT-PRESETS` — the session with Tripack.
- The DCS-machine work: the harness's launch/load/quit slice, and the one measurement ADR 0017 says
  would reopen it (does ED still overwrite `package.path` without consulting `writedir`?).
