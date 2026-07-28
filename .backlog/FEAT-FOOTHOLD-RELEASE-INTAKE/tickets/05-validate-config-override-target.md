# 05 — Bundle the conversion profiles, and validate `config_override.target`

Status: ✅ done
Type: fix

Two defects found by exercising tickets 01-04 **through the packaged executable** rather than
through `poetry`. Both predate this lot; both make the documented moulinette misbehave.

## a. `--profile` was broken in the shipped binary

```
FileNotFoundError: unknown conversion profile: foothold
[PYI-19868:ERROR] Failed to execute script 'veaf-tools'
```

`veaf-tools.exe convert-other … --profile foothold` died on every run. The conversion
profiles were **never** bundled into the executable: `git log -S "convert-profiles" --
veaf_build/worker.py` returns nothing.

The trap is that [`veaf-tools.spec`](../../veaf-tools.spec) *does* list
`veaf_libs\data\convert-profiles` — but that file is a leftover the build does not use. The
build passes `--add-data` from `BuildAndReleaseWorker._veaf_tools_extra_data`, and the
directory was missing there. Same family as `FIX-VEAF-BUILD-RADIO-LAYOUT-DATA` and the
`dcsUnits.yaml` bundling of `FIX-MCP-SCAFFOLD-THEATRE-HINT`.

Consequence: the moulinette documented in `FOOTHOLD.md` was unusable for any VEAF member
using the executable — only someone running from the sources could execute it. Which is
presumably why nobody reported it: it had only ever been run from this repo.

- [x] Bundle the whole `convert-profiles` directory (like `veaf_libs/locales`), so a new
      profile needs no build change.
- [x] Regression guard in `test_build_standalone.py`, on the pattern of the three already
      there; it also asserts both `foothold` and `foothold-ww2` are in the shipped directory.
- [x] Rebuild the executable and confirm `--profile foothold` and `--profile foothold-ww2`
      both work in the binary.

**Left alone deliberately**: `veaf-tools.spec` still lies about what ships. Deleting it or
making it authoritative is a tooling decision, not a detail — worth its own chore.

## b. `config_override.target` was never validated

Ticket 04 (and this lot's PRD) claimed that adopting Normandy with the modern `foothold`
profile "produces a scaffold that fails `validate`". **That was wrong** — it validated
cleanly. Verified by adopting `WWII_Normandy_Foothold_5.2.2` with `--profile foothold`,
uncommenting `config_override`, and running `validate`: `✓ no problem detected`.

Two reasons it passed:

1. `_check_config_override` only validated the `values` **key segments**, never the `target`.
2. The segments are searched across the **whole** `src/scripts/*.lua` corpus, so
   `StartNormal` is found in the engine scripts even though the WW2 *config* does not define
   it.

And the real behaviour is worse than a failed validation. `_position_config_override` states:
"When the target is not in the list, the override is appended so it still loads." Confirmed in
a built `.miz` — resource keys with the wrong profile:

| key | script |
|---|---|
| 11004 | `Foothold Config WW2.lua` |
| 11006 | `Normandy_Zone_Setup.lua` (reads the settings) |
| **11012** | **`veaf-config-override.lua`** ← last |

So the override was built, embedded, loaded — and had **no effect**, silently. With the right
profile the override sits at 11005, between the config and the setup script.

- [x] `validate` errors when `config_override.target` matches no script in `src/scripts/`
      (matched on basename, like the build's own positioning). No target → no check, since
      loading in collection order is a deliberate choice.
- [x] Message (FR + EN) states the *consequence* — loaded last, after the setup script, hence
      ineffective — and points at the matching conversion profile.
- [x] Four tests: missing target errors; basename matching (a `target` carrying a directory
      still resolves); no target is not flagged; the known-good case stays clean.
- [x] Correct the claim in the PRD, ticket 04, `FOOTHOLD.md`/`.en.md`, the CHANGELOG and the
      PR body: it did **not** fail validate before — it passed and produced a dud override.

## Why this belongs in this lot

Ticket 04 exists to stop someone adopting Normandy with the wrong profile. Without (b) the
protection was cosmetic: the wrong profile produced a mission that built, loaded, and quietly
ignored its configuration. Fixing the root cause is what makes ticket 04 worth anything, and
(a) is what makes any of it reachable from the shipped binary.
