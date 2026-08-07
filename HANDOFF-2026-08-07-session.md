# Handoff — 2026-08-07: the four open PRs are merged, and what to pick up next

> Written at the end of a session that started as "summarise what is left" and became
> "merge the four open PRs". State as of `develop` @ `48ac7df3`. `.backlog/README.md` stays
> the source of truth for scope and status; `ROADMAP.md` for sequencing. This file is only
> the session's own residue — what changed today, and where to resume.

## 1. What landed today

Four PRs, squash-merged into `develop` in dependency order. All were green; three needed a
`develop` merge and a conflict resolution first, all of them on the same three files
(`pyproject.toml`, `plugin/.claude-plugin/plugin.json`, `CHANGELOG.md`) plus
`.backlog/README.md`.

| PR | What | Version after |
|----|------|---------------|
| [#668](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/668) | The smoke harness turned into evidence, plus the two bugs it found — including a correctness fix to day-old Lua: `Disposition`'s radius does not bound its answers and tier 1 had no distance test, so a spawn could move kilometres silently | 6.13.27 |
| [#665](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/665) | The prose half of the same work — backlog, roadmap, and the index rewritten as an index | 6.13.27 |
| [#667](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/667) | ATIS at a vanished airbase says words instead of raising a scripting error. Picks up the half of MacFlorent's PR #303 nobody reviewed | 6.13.28 |
| [#666](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/666) | Pillow 12.3.0 + cryptography 50.0.0 | 6.13.29 |

Conflict resolutions worth knowing about, because they were judgement calls rather than
mechanical:

- **Versions**: each branch had bumped the patch from a `develop` that has since moved, so
  every conflict was resolved *upward* — 6.13.28 then 6.13.29 — never by taking a side.
- **`.backlog/README.md`**: #665 rewrote every row of the active table into a short form,
  while #667 added a long-form `FIX-ATIS-NIL-MESSAGE` row on top of the old text. Resolved
  by keeping #665's rewritten table and re-writing the ATIS row in the new short form. Its
  status was left at 🔄 as the branch had it — **promoting it to ✅ is a call for you**, and
  the same question applies to `FEAT-SCENERY-AWARE-SPAWN` and
  `FEAT-COMBATZONE-MENU-COALITION`, whose in-game gates the harness answered on 2026-08-06.

## 2. Where to resume, in order

1. **Cut a release.** `develop` is at **6.13.29** and the last published is **6.13.0**
   (2026-08-01) — 29 patch versions, now including the security bumps. This is the single
   highest-value next action and it is unblocked.
2. **`FEAT-DCS-SMOKE-HARNESS`**, remaining slice — locate, launch, load, quit. No longer an
   investigation: `net.load_mission` and `Sim.exitProcess` are measured present, and
   `isServer()` is true in single-player, so the SERVER-ONLY caveat does not block a local
   instance. Needs the DCS workstation.
3. **`SECREV-2`** tickets 04–07 — fail-closed integrity, the two correctness bugs, then the
   24 medium and the 108 low/info. Doable anywhere.
4. **`FEAT-MCP-MUTATION-ACTIONS`** ticket 01 — the triage by mission-maker intent that
   decides what the rest of the lot even is.
5. Then the small ones, in whatever order suits: `CHORE-TOOLING-GATES` (2 of 3 left),
   `CHORE-SMS-QUICK-WINS`, `FIX-RADIO-LAYOUT-GAPS`, `FEAT-PORTABLE-PREFABS` (a decision, and
   a rejection is an acceptable outcome).

## 3. Waiting on you, and on nobody else

- **The server hook is fixed here and not deployed.** `REFACTOR-SERVER-HOOK-CANONICAL` made
  the repository copy the deployable source, so both SECREV-2 criticals remain live on the
  VEAF servers until it is copied there. Nothing in the repository can close this.
- **`REVIEW-SECURITY-LAYER`** — both tickets end in a decision: what a login session should
  mean, and whether the tier names change (breaking).
- **`ENRICH-DEFAULT-PRESETS`** — the collaboration session with Tripack.
- **`TOOLING-REPO-LINK-GATE`** ticket 04 — keep / fix / delete on the exempted links.
- The three lot statuses in §1 that the harness's evidence arguably promotes to ✅.

## 4. Found on the way — read before trusting a local run

- **`poetry install` cannot reach PyPI from the PwC workstation.** It fails on
  `Cannot install pillow` with `ConnectionResetError [WinError 10054]`, reproducibly, on
  every retry — the corporate proxy closes poetry's parallel downloader. **`pip` works**:
  `poetry run pip install --no-deps "pillow==12.3.0"` succeeded immediately, and that is how
  the environment was brought to the versions #666 ships. The lock file is fine; CI installed
  it without complaint.
- **One test fails locally and is not a regression**:
  `test_convert_other_command.py::TestConvertOtherInput::test_plain_miz_is_passed_straight_through`
  compares `C:/Users/dpierron001/...` against `C:/Users/DPIERR~1/...` — the Windows 8.3 short
  path of `%TEMP%`. It is green in CI. Do not chase it as part of whatever you are doing.
- **`test/python/` is under no ruff gate** and currently carries 12 `I001` errors. That is
  exactly `CHORE-TOOLING-GATES` ticket 03, still open — so the gate command from `CLAUDE.md`
  (which scopes ruff to `src/python/`) passes while the tree does not.
- **Dependabot is no longer blocked**: the default branch is `develop`, and there are **zero**
  open Dependabot PRs. **13 alerts remain open**, and none of them is what #666 addressed —
  they are `sharp`, `ws`, `undici` ×3, `esbuild` (npm, from the docs/POC side),
  `pymdown-extensions` and `setuptools`. A separate lot's worth of work, not a leftover of
  this one.
