# CHORE-VENDORED-DRIFT-618 — clear the drift watch, and say what it cannot see

Status: ✅ done · archived 2026-09-28

[#618](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/618) is the standing recap issue the
`vendored-drift-watch` workflow edits in place. On 2026-09-12 it reported two drifted artefacts and
one error. Measured rather than believed: **Skynet was already back in step** (its pin was bumped
after the issue body was last written), so the real work was TUM, CTLD, and one finding.

## What was synced

| Artefact | From | To | Why it is safe to take verbatim |
|---|---|---|---|
| CTLD | 2.0.0-rc7 | **2.0.0-rc8** | VEAF's own rewrite. Release notes: *"No existing setting was renamed or removed, and every default keeps today's behavior."* 410 added / 30 removed lines, matching the notes. Two of the fixes were reported by David. |
| TUM | 0.1.250722 | **0.3.251019** | Opt-in and **off by default** (`TUM: false` in the shipped `mission.yaml`), so no existing mission changes behaviour unless it asked for TUM. No new resource dependency, and the BLUFOR/REDFOR zone contract our validator checks is unchanged. |

CTLD's configuration catalogue is read **out of** the vendored `CTLD.lua` (ADR 0016), so rc8's two
new settings (`troopPickupAtFARP`, `farpTroopPickupRadius`) reach the next scaffold with nothing to
update on the Python side.

## Two traps met on the way, now written into `vendored.yaml`

- **TUM has no `.lua` asset.** A release ships `.miz` files and PDFs. The script lives inside each
  mission as `l10n/DEFAULT/Script.lua`; it is byte-identical across theatres (checked on Marianas and
  Syria). The old `manual_steps` told you to re-download a file that has never existed.
- **TUM's own version constant lies**: `TUM.VERSION_STRING` still reads `0.1.250722` inside the
  v0.3.251019 release. The release tag is the only trustworthy version, which is why the artefact
  cannot join `SELF_DECLARED` in `test_vendored_pins_match_the_files.py`.

## Verified here, and what is still not claimed

Both files load cleanly under a real **Lua 5.1** interpreter — the version DCS runs:

```
"/c/Program Files (x86)/Lua/5.1/lua.exe" -e "assert(loadfile('<file>'))"   -> OK for both
```

Worth stating how that was nearly missed: `lua` **on the PATH** here is scoop's 5.5, where a `for`
control variable is `const`, so it rejects both the incoming *and* the outgoing file — a check that
fails either way decides nothing. The 5.1 binary is installed off-PATH at the path above; see
[[lua-tests-need-lua-51]], which says exactly this and which the first pass of this lot did not
consult, concluding instead that no 5.1 existed on this machine.

Syntax is not behaviour: **neither artefact was run in DCS**. That guarantee is the one the previous
pin already had — upstream ships these files inside missions people fly.

> **2026-09-12, hours later — that caveat was the hole, and rc8 fell straight through it.**
> `assert(loadfile(...))` parses a file; it does not run it. The vendored rc8 **raises inside its own
> main chunk**, so every 6.22.0 mission with CTLD enabled came up with no radio menu at all — CTLD's
> *and* VEAF's, since they share one concatenated loading chunk. Reported by Tripack as
> [#957](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/957); fixed upstream in
> [VEAF/CTLD#144](https://github.com/VEAF/CTLD/pull/144) and vendored as rc9 by
> [`FIX-CTLD-RC9-LOAD-GATE`](FIX-CTLD-RC9-LOAD-GATE.md), which also adds the gate that was
> missing on both sides: a test that **loads** each vendored community script instead of parsing it.
> The sentence above was honest about what it did not claim. The lesson is that the missing claim was
> the one that mattered.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Sync CTLD rc8 and TUM v0.3](CHORE-VENDORED-DRIFT-618.md) | ✅ |
| 02 | [The watch is blind to pre-releases](CHORE-VENDORED-DRIFT-618.md) | ✅ |
| 03 | [Sync CTLD rc10](CHORE-VENDORED-DRIFT-618.md) | ✅ |

## Definition of done

- [x] `poetry run check-vendored` reports **0 drifted**
- [x] `vendored.yaml` pins match the files (`test_vendored_pins_match_the_files.py`)
- [x] The TUM entry's `manual_steps` describes a procedure that can actually be followed
- [x] Ticket 02 decided by David — **(c)**, an opt-in per watch, on 2026-09-18
- [x] The check reports something true about CTLD, and the `vendored.yaml` note agrees with the code

---

## Tickets, in full

## 01 — Sync CTLD rc8 and TUM v0.3

Status: ✅ done

### What was done

- `src/scripts/community/CTLD.lua` ← the `CTLD.lua` asset of `published-v2.0.0-rc8`, converted to LF.
- `src/scripts/community/TheUniversalMission.lua` ← `l10n/DEFAULT/Script.lua` extracted from
  `The.Universal.Mission.-.Marianas.miz` of `v0.3.251019`, converted to LF.
- `vendored.yaml`: both pins moved, and the TUM entry rewritten (its `manual_steps` described a
  download that is impossible; the two traps are now stated in the file itself).

### Line endings, because this has cost a release before

Both upstream files ship with CRLF. `.gitattributes` normalises `*.lua` to LF and its own comment
records why: the 6.13.0 release carried 25 000 changed lines, 24 000 of which were one copied CTLD.
Converting on the way in keeps the working tree and the index saying the same thing — CTLD's real
diff is then **410 added / 30 removed**, which can be read.

### Verified

- `poetry run check-vendored`: 0 drifted
- `poetry run pytest test/python/test_vendored_pins_match_the_files.py`: green — it is what would have
  caught a file swapped without its pin
- CTLD's version constant reads `2.0.0-rc8`; TUM's reads `0.1.250722` in every release, so there is
  nothing to assert there (see the PRD)
- Both files load under real Lua 5.1 (`C:\Program Files (x86)\Lua.1\lua.exe`, off the PATH).
  The `lua` on the PATH is 5.5 and rejects both the new and the old file over `const` loop variables,
  so it is not the interpreter to judge with.

---

## 02 — The watch is blind to pre-releases, and says the wrong thing about it

Status: ✅ done — **David chose (c)** on 2026-09-18, with (b)'s wording as its consequence

### The finding

`VendoredChecker.latest_release` asks GitHub for `/repos/{repo}/releases/latest`, which **skips
pre-releases by design**. Every VEAF/CTLD release is a pre-release (`published-v2.0.0-rc1` … `rc8`),
so that endpoint answers 404 and the watch reports `error`.

`vendored.yaml` already anticipated the 404 and says so — *"the watch reports `unresolved` rather than
drift. Expected; do not 'fix' it by listing releases."* Two things have not held up:

1. **The status is `error`, not `unresolved`.** The weekly issue prints it under *"Errors (could not
   resolve upstream)"* with the advice *"check the repo/ref still exists"* — which sends the reader
   to look for a deleted release. `published-v2.0.0-rc7` was there the whole time.
2. **The cost is now measured.** `rc8` shipped on 2026-08-26. The vendored copy stayed on `rc7` until
   2026-09-12 — seventeen days, three weekly runs, and the watch never said a word, because the only
   thing it can see about CTLD is an endpoint that will answer 404 until a stable 2.0.0 exists. The
   artefact the watch is least able to follow is the one VEAF ships itself and updates most often.

### Options

- **(a) List releases when `/latest` 404s**, take the newest by `published_at` (or the newest matching
  a pattern), and compare that to the pin. Contradicts the note in `vendored.yaml`, which was written
  before the cost was known — the note would be replaced by this reasoning.
- **(b) Keep `/latest`, but stop calling the 404 an error.** Report `unresolved` as the file already
  claims, and word the issue so it does not send anyone hunting a deleted release. Honest, and still
  blind: a future `rc9` would go unnoticed the same way.
- **(c) Add an opt-in `prereleases: true` on the watch**, so CTLD tracks pre-releases and nothing else
  changes. Narrower than (a), no repository-wide behaviour change.
- **(d) Do nothing.** Defensible only if CTLD updates are expected to reach us through David anyway —
  which is how rc8 was found, though seventeen days late and only because a different issue was being
  investigated.

Recommendation: **(c)**, then (b)'s wording as a consequence — it fixes the artefact that actually
drifts without changing how every other watch behaves.

### Done when

Whichever option is chosen is implemented, `check-vendored` reports something true about CTLD, and
the `vendored.yaml` note agrees with the code.

### What was built

`prereleases: true` on a watch lists the releases instead of asking for `/releases/latest`. Only
CTLD's watch carries it; the seven other release watches are untouched, and a test asserts that a
plain watch still asks for stable releases only.

**A second field was needed, and the option as written would not have survived without it.** CTLD
republishes a `dev` release on every `master` build — a moving tag, a pre-release like the rest. It
was the newest release in the listing at 23:55:05 on 2026-09-16, twenty-two seconds before rc10, and
it will be the newest again after the next build that cuts no rc. Listing without a filter would
therefore have reported drift towards `dev` most weeks: the noise option (a) was rejected for, pulled
in through the back door. `tag_pattern: "^published-v"` restricts what is eligible.

Also carried out, per the decision: the error line in the recap issue now names the pre-release cause
next to *"check the repo/ref still exists"*, for any release watch that fails to resolve.

Proven against the live API rather than asserted (a check must be able to fall both ways):

```
plain /releases/latest on VEAF/CTLD : None          <- the 404 this ticket is about
listing, ^published-v              : published-v2.0.0-rc10
pinned rc10 -> up-to-date ; pinned rc9 -> drifted (latest published-v2.0.0-rc10)
```

---

## 03 — Sync CTLD rc10, the first bump the watch reported itself

Status: ✅ done

### Why it is here rather than in a lot of its own

`published-v2.0.0-rc10` shipped on **2026-09-16**, two days before this ticket, and the watch had no
way to say so — which is exactly what ticket 02 fixes. Taking the bump in the same lot is what proves
the fix: the check was run before and after, and it moved from `error` to `drifted` to `up-to-date`.

### What changed

**CTLD `2.0.0-rc9` → `2.0.0-rc10`, verbatim.** Two F10 menu defects reported in flight upstream: a
transport asking for one command on the menu and getting another (a smoke grenade instead of a troop
load), and the whole-menu rebuild that made it possible. Upstream's fix introduces an *ambient* vs
*urgent* refresh distinction, detected automatically rather than tagged at each of ~30 call sites.

Measured, not assumed:

- The download arrives with **CRLF**; the vendored copy is LF. Converted before copying — a raw copy
  shows a 37 244-line diff and would make every later comparison unreadable. Real diff: **419 lines**,
  283 insertions / 92 deletions, which matches two fixes and their comments.
- **The configuration catalogue is byte-identical between rc9 and rc10.** It is extracted from the
  vendored `CTLD.lua` at build time (ADR 0016), so a new setting would have to reach the scaffold;
  none did, and no mission configuration changes.
- `test_community_scripts_load.lua` — the gate `FIX-CTLD-RC9-LOAD-GATE` added after rc8 came up dead
  in flight — **loads** rc10 under the DCS mocks rather than parsing it. It passes, along with the
  47 other Lua suites.
- `test_vendored_pins_match_the_files.py` still matches: `ctld.VERSION` in the file, the `pinned`
  field and the watch tag all read rc10.

### Not claimed

The file has not been flown in DCS here. Upstream ships it inside missions people fly, and the two
defects it fixes were reported from flight — but this repository's evidence stops at "it loads and
initialises under the mocks".

---
