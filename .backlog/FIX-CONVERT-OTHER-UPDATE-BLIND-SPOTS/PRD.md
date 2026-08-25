# FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS — what a Foothold refresh changes without saying so

Status: ⬜ ready

Origin: the 2026-08-25 refresh of the five VEAF Foothold missions onto Lekaa's 4.7.0
(GCW 5.7.0). Every defect below was met on that run, on real missions, and re-verified
against `develop` at `75aa264d` before being written down.

## The one sentence they share

`convert-other --update` is the command the whole Foothold moulinette rests on, and **it
reports nothing**: it collects what changed upstream into two lists the report never renders,
leaves behind a script the upstream release removed, and never reconciles the load staging.
Each failure is silent — `validate` stays green and the built `.miz` looks right.

Two of them were caught on 4.7.0 only because the archives were compared with the mission
folders **by hand**, before running anything. That is not a procedure anyone should have to
invent.

## What the 4.7.0 refresh actually did

| Claim | Verified |
|-------|----------|
| Syria's setup script was renamed upstream (`footholdSyriaSetup.lua` → `footholdSyriaSetupv2.lua`) | Compared the archive's `.miz` with `src/scripts/`: v2 present upstream, the old name absent |
| `--update` added v2 and **kept** the old file | `git status` after the run: `?? footholdSyriaSetupv2.lua`, the old file unmodified and still referenced by `mission.yaml` |
| So `validate` passed and the build would have loaded the **previous version's** setup over 4.7.0 data | `validate` returned 0 on the unfixed folder |
| The report mentions neither the added nor the removed script | `convert-other-report.md` says *"Aucun — la migration s'est terminée sans avertissement"*, and all five reports print the same `10 éléments`, Syria included |
| `report.actions` is never rendered | `grep -c "self\.actions"` over the markdown builder in `v5_converter.py`: **0** |
| `report.manual_review` is never rendered either | Used only at `v5_converter.py:310`, to count items for the summary line |
| The five missions carried **no** `delay_seconds` at all | Read from each `mission.yaml`: 12 scripts, all at delay 0 |
| Upstream stages them | Resolved through `l10n/DEFAULT/mapResource` from the loader triggers' `c_time_after`: 6 scripts at 0 s, 5 at 1–3 s per map, **AIEN at 12 s (15 s on Persian Gulf)** |
| `_delay_changes` *did* detect it | `declared` is non-empty (`_declared_delays` returns every script, `None` when it has no delay), so six lines per mission were produced — and appended to `manual_review`, which nothing prints |
| `Convert-FootholdBatch.ps1 -Update` cannot find an existing mission folder | The target is `<OutputFolder>\<archive base name>` (`Convert-FootholdBatch.ps1:363`) and the archive name carries the version, so `Foothold_CA_4.7.0_…` never matches `VEAF-Foothold-Caucasus` |

## Why the staging one is not cosmetic

`doc/mission-maker/FOOTHOLD.md` already explains it, under *Pourquoi l'étalement compte*:
**AIEN inventories ground groups once**, at load, and Foothold creates part of its groups from
scheduled tasks starting at 2 s. Loading AIEN at t=0 hands it a world those tasks have not
populated — and the symptom is nothing at all in the log, just ground AI that never manages
Foothold's groups.

`delay_seconds` landed on 2026-08-11 (`dc0d9970`); the five missions were adopted on 2026-07-28
and `--update` preserves a tuned `mission.yaml`. So the staging was **never** written into any of
them: they shipped flattened from the day they were adopted until 2026-08-25.

## Order, and why the report comes first

02 → 01 → 03 → 04.

Ticket 02 first because it is the instrument: it costs a rendering pass, and once the two lists
are printed, tickets 01 and 03 become visible failures instead of findings someone has to go
looking for. Fixing 01 without 02 would leave the *next* upstream rename silent again in every
other form (a script added and unused, a delay that moved).

Ticket 04 is the harness rather than the tool, and it is what makes the other three reachable
for the nine other maps.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [`--update` leaves behind a script the upstream release removed](tickets/01-update-keeps-removed-script.md) | fix |
| 02 | [The conversion report renders neither `actions` nor `manual_review`](tickets/02-report-drops-actions-and-review.md) | fix |
| 03 | [Reconcile the load staging on update](tickets/03-reconcile-delay-seconds.md) | feat |
| 04 | [`Convert-FootholdBatch -Update` cannot address an existing mission folder](tickets/04-batch-cannot-address-mission-folders.md) | fix |

## Out of scope, stated rather than assumed

- **Two duplicate `build:` keys** at the top level of all five Foothold `mission.yaml`, committed
  on 2026-07-28. No effect today (both say `dev_mode: false`, and the last one wins), but a
  `scripts_path` written into the first would be ignored. Belongs to the mission repositories,
  not to the tools.
- **Mojibake in those same files** (`â”€`, `â€”`) since July, and `mission.yaml` normalised to CRLF
  by the batch's rewrite pass — which turned a 6-line diff into 254 lines on the one mission whose
  file was LF. Cosmetic, recorded because it costs review time on every refresh.
- **The `MiG-15bis` preset warning** on Germany and Syria: every frequency of the preset plan is
  outside the aircraft's radio range, so the original radio is kept. Correct behaviour, new in
  4.7.0, no work here.
- **The `.miz` naming check** did not flag the previous build sitting beside the new one
  (`…_20260728.miz` next to `…_20260825.miz`). The base name is identical and only the date
  suffix differs, so the check matched. Whether it *should* flag it is a product question for
  the batch, deliberately left to David rather than assumed.
