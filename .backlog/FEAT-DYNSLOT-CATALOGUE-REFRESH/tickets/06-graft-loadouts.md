# 06 — Graft the 11 loadouts

Status: ✅ done
Type: feat

## What changes

The shipped catalogue ships **18 of its 104 templates with a loadout** — 17 %. DCS serves the pilot
the aircraft *as the template describes it*, so the other 86 come out bare. Reaper's extract carries a
loadout on 11 types that ship empty:

| coalition | type | template | pylons |
|---|---|---|---|
| blue | `F-16C_50` | `F-16CM Template` | 0 → 10 |
| blue | `FA-18C_hornet` | `F/A-18C Template` | 0 → 9 |
| blue | `Ka-50_3` | `Ka-50III Template` | 0 → 6 |
| blue | `M-2000C` | `M-2000C Template` | 0 → 5 |
| blue | `MiG-29G` | `Mig-29G Template` | 0 → 7 |
| red | `F-16C_50` | `F-16CM Template Red` | 0 → 9 |
| red | `F-5E-3` | `F-5E-3 Template Red` | 0 → 3 |
| red | `FA-18C_hornet` | `F/A-18C Template Red` | 0 → 9 |
| red | `Ka-50` | `Ka-50 Template Red` | 0 → 2 |
| red | `M-2000C` | `M-2000C Template Red` | 0 → 5 |
| red | `Su-27` | `Su-27 Template Red` | 0 → 10 |

With ticket 05's `MiG-29S` and `Su-33` and their mirrors, the catalogue goes from 18 armed templates
to 33 out of 128 — 26 %.

## What is taken, and what is not

**The `payload` block only**, whole: `pylons`, `fuel`, `chaff`, `flare`, `gun`, `ammo_type`. Keeping
the graft to one key per template keeps the diff auditable, which matters on a 9 500-line YAML.

Explicitly not taken:

- **`livery_id`.** Reaper's liveries follow his real-country filing (a Czech L-39, a Luftwaffe
  MiG-29G); this lot keeps `CJTF Blue` / `CJTF Red`, so his liveries would be arbitrary here — and
  two of them are plainly wrong for their side anyway (his red JF-17 and red Mirage F1EE both wear
  blue camouflage).
- **`AddPropAircraft`.** His differ from ours on several types, in both directions, and the
  differences are module option drift rather than an improvement. Left alone.
- **Red `F-14B`.** The one type where the extract is poorer: `F-14B Template Red` carries 10 pylons
  today and 0 in his file. Not touched.

## Definition of Done

- The 11 templates carry their new `payload`, and nothing else about them changed — verifiable by
  the diff being one block per template.
- 33 templates in the catalogue carry a non-empty `payload.pylons`, asserted as a floor by ticket
  04's test so the count cannot silently fall back.
- Every `CLSID` in the grafted pylons is a string, non-empty, and the pylon keys are integers — a
  malformed pylon table is a DCS load failure and this is data copied from a foreign file.
