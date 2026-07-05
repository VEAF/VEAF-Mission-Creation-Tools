# Radio presets — per-type layout projection (analysis)

> **Status:** exploration / pre-design. No lot, branch or code yet.
> Captured so the design of an automatic *per-type channel-layout projection*
> starts from a shared, verified picture. Requested by David; source material is
> Tripack's v5 `radioSettings.lua` and the current v6 presets subsystem.

## 1. Goal

Let a mission-maker declare a **small set of logical channel lists** (by radio
*role*, globally and optionally per family / aircraft type) and have the build
**project** them onto each aircraft's *physical* radios while honouring that
aircraft's quirks (missing channel 1, channel-0 rotation, reserved "manual"
slots, hardcoded special channels, per-channel modulation, radio count, radio
fusion). Today those quirks must be hand-encoded per aircraft, so a change to
the global lists does **not** propagate to the special aircraft. The target
model is detailed in §6.

## 2. How it works today

### 2.1 v6 build tooling (Python) — already factorised, no projection

`presets.yaml` stacks four reusable layers (read bottom-up):

| Layer | Key | Role |
|---|---|---|
| Frequencies | `channels_collection` | a frequency written **once**, per mode (uhf/vhf/fm) |
| Radio config | `radios_collection` | one radio = ordered channels (aliases / literals / `{freq,mod}`), `type` picks the mode |
| Preset | `presets_collection` | groups radios into physical slots `radio_1..N` |
| Assignment | `presets_assignments` | `coalition → plane/helicopter → { all, <type>, <regex>, none }` |

Resolution is `exact type → regex → all(category) → all(coalition)`. Injection
(`presets_injector_worker.py`) resolves the preset per human-piloted group,
drops out-of-band channels using `dcs-radio-specs.yaml`, and writes
`unit["Radio"] = preset.to_dict()` (shape `[n] → {channels, channelsNames,
modulations}`), plus a kneeboard PNG.

Key point: the model assumes a **1:1** mapping *logical channel N → physical
slot N*. It represents arbitrary maps (via `RadioDefinition`), but does not
*derive* them — the map is authored.

### 2.2 v5 tooling (Lua) — verbatim copy, no projection either

`veafMissionRadioPresetsEditor.lua` (v5) `editUnit()` matches a `radioSettings`
entry by `coalition + country + type|typePattern` (first match wins) and does:

```lua
unit_t["Radio"] = _deepcopy(setting_t["Radio"])   -- line 204
```

So **every quirk is pre-computed by hand in `radioSettings.lua`**; the engine
adds nothing. The v6 fallback chain is already richer than v5's first-match.

### 2.3 Conclusion

Neither v5 nor v6 projects a logical list onto per-type physical layouts. The
per-type quirks live either in a **bespoke per-aircraft preset** (Mi-24P, AJS37
— see [ADR 0003](../adr/0003-presets-fidelity.md)) or **nowhere** (OH-58D falls
back to the standard preset, so its reserved slot is not honoured). The
requested feature is genuinely new.

## 3. Taxonomy of aircraft radio particularities

From reading the whole v5 `radioSettings.lua`, quirks fall into these classes
(only the first three break the 1:1 logical↔physical mapping):

1. **Leading reserved slots** — one or more physical slots at the head are not
   part of the user's list (a "manual" / "cue" channel, or a dummy). The user's
   channel 1 lands on physical slot 2 (or 3).
2. **Channel-0 rotation** — the radio exposes a *channel 0*; the last preset
   wraps to the head so slot `[1]` = preset `#N`, `[2..N]` = presets `1..N-1`.
3. **Trailing hardcoded specials** — a fixed block of constant frequencies
   (type property, not user data) appended after the user's channels.
4. **Per-channel modulation** — a parallel `modulations` map (0=AM, 1=FM),
   significant only on some channels of some types.
5. **Restricted frequency bands** — validation concern; already handled by
   `dcs-radio-specs.yaml` + the frequency validator (drop / warn).
6. **Radio count & ordering** — 1 to 4 physical radios; which user list feeds
   which slot is type-dependent.
7. **Channel names** — some digital radios display per-channel titles
   (`channelsNames`), most don't.

## 4. Per-type inventory

### 4.1 Bespoke layout — needs projection (the real targets)

| Aircraft | Radios | Particularity | Projection primitive |
|---|---|---|---|
| **Mi-24P** (blue) | 2 (V/UHF + FM) | R-828 **channel 0**: slot `[1]`=preset #20, `[2..20]`=presets 1..19. FM radio is standard. ⚠️ Tripack applied this to **blue only**; red uses plain order. | channel-0 **rotation** on radio 1 |
| **OH-58D** | 4 (UHF, VHF, FM1, FM2) | UHF/VHF: slot `[1]`=**"M"** (manual) reserved, `[2..20]`=user 1..19. FM1/FM2: slot `[1]`=**"C"**, `[2]`=**"M"**, `[3..21]`=user 1..19. This is the "no channel 1" case. | **leading reserved slots** (1 or 2), per radio |
| **AJS37** (Viggen) | 1 (V/UHF, 47 slots) | slot `[1]`=**dummy** (`0`, "channel 100"); `[2..40]`=39 user channels (20 UHF + 19 VHF); `[41..47]`=**7 hardcoded specials** (FR22 ×3, FR24 ×4 incl. GUARD 243); per-channel **modulations** (41–45 = FM). | leading dummy + **trailing fixed specials** + modulation |

### 4.2 Minor quirks — probably no dedicated projection needed

| Aircraft | Note |
|---|---|
| **A-10C** | trailing empty channels (`0`) with `modulations=1` on those slots; otherwise 1:1 over 3 radios. |
| **CH-47F** | explicit `modulations` table (all `0`); 3 radios; slot `[1]` on radio 1 is a `RADIO2_20` (near-rotation). |

### 4.3 Restricted-band families — validation only (already covered)

Standard 1:1 layout; the only concern is the valid band (handled by specs +
validator, cf. FIX-MIG15-PRIMARY-FREQ, Yak-52 ADF):

- Warbirds **Bf-109K-4 / FW-190** — VHF 38–42 MHz, no modulation box.
- Prop **I-16, MosquitoFBMkVI, P-47D, P-51D, TF-51D, Spitfire** — VHF 100–156 MHz.
- **Christen Eagle II / Yak-52** — HF 5.5–10, HF 3–5.5, LF/MF 0.2–0.5 MHz (low ADF bands).

### 4.4 Standard aircraft — fully covered by current factorisation

All other jets (F-86F, F-5E, MiG-19P/21/29, Mirage F1 family, F-14, F-4E,
FA-18C, F-16C, AV8BNA, JF-17, M-2000C, F-15ESE, C-130J, C-101, L-39, T-45,
AH-64D, SA342, Ka-50, Mi-8MT, UH-1H, …) are plain 1:1 maps over 1–3 radios and
are already served by `presets_assignments` (`all` + per-type/regex override).

## 5. What is covered vs what is missing

| Need | Status |
|---|---|
| One global list applied to all aircraft | ✅ `presets_assignments.<coalition>.<cat>.all` |
| Per-type / per-family override | ✅ exact type, regex, `none` |
| Change a frequency in one place | ✅ `channels_collection` |
| Band validation per type | ✅ `dcs-radio-specs.yaml` + validator |
| Bespoke layouts preserved on v5→v6 convert | ✅ dedicated per-aircraft preset (ADR 0003) |
| **Auto-apply a per-type layout to any list** | ❌ **missing** — quirks are frozen in bespoke presets or absent |

## 6. Target model — desired lists → per-type packing (David's vision)

The maker declares a **small set of logical channel lists, by radio *role***
(not by physical radio), each ~20 presets:

- **V/UHF #1** and **V/UHF #2** — the two primary radios.
- **FM (substitute)** — when FM stands in for a *missing* 2nd V/UHF, typical on
  helicopters carrying one V/UHF + one FM; it complements the single V/UHF.
  Content: general tactical + civil / airbase channels.
- **FM (supplement)** — when FM is added *on top of* two V/UHF radios (attack
  aircraft like the A-10, to talk to the ground). Content: ground-tactical only,
  distinct from and in addition to the substitute list.

A **packer** then, per aircraft, reads its physical radios from
`dcs-radio-specs.yaml` and assigns each list to the matching radio, applying the
type's layout rule:

| Aircraft shape | Physical radios | Packing |
|---|---|---|
| Standard jet | UHF + VHF + FM | one list per radio, 1:1 |
| Helicopter | one V/UHF + one FM | V/UHF list on the V/UHF, **FM (substitute)** on the FM; channel-0 rotation where the airframe has it (Mi-24P) |
| Attack aircraft | two V/UHF + FM | the two V/UHF lists, **FM (supplement)** on the FM |
| Fused single radio | one V/UHF (AJS-37) | concatenate V/UHF #1 + #2 into the one radio (leading dummy first), append the fixed specials block |

The FM role (substitute vs supplement) is **derived from how many V/UHF radios**
the airframe has (1 → substitute, 2 → supplement). **Manual override always
wins**: a bespoke preset assigned to a type bypasses the packer.

## 7. Layout primitives to model (per type)

The packer is driven by a per-type *layout* built from these primitives:

- **Physical-slot → list-role mapping** — which desired list (V/UHF #1, #2, FM
  substitute/supplement) feeds each physical radio. Explicit and **VEAF-fixed**
  for band-ambiguous radios (A-10C_2 ARC-210) or non-natural orderings (the
  A-10 wants VHF on radio 1). Band-based deduction is only the default for
  trivial single-band airframes.
- **Reserved leading slot(s)** — count + which list entry fills them. Tripack's
  convention: the reserved head slot takes the **list's last entry (#20, the
  guard)** — `RADIO*_20` = GARDE MILITAIRE/CIVILE, *not* a hardcoded value. The
  OH-58D FM adds a second head slot "C" = **#01**.
- **Channel-0 rotation** (Mi-24P channel 0, OH-58D "M") — same operation: the
  list's last entry rotates to the head, `1..19` follow.
- **Trailing fixed specials** (AJS-37 FR22/FR24, incl. GUARD 243) — a block of
  constant frequencies + modulations appended after the lists; airframe
  constant, maker-overridable.
- **Radio fusion** (AJS-37) — several logical lists packed into one physical
  radio.
- **Per-radio slot capacity** — how many channels the radio accepts (OH-58D
  UHF = 20 incl. M; AJS-37 = 47). **Not in `dcs-radio-specs.yaml`** → the layout
  file must carry it.
- **Per-channel modulation** — AM/FM per slot, needed by AJS-37 (specials FM)
  and A-10C (trailing slots).

### Design constraints

- `dcs-radio-specs.yaml` is **auto-generated** (Quaggles, `update-radio-specs`),
  carries only bands/modulation → layout data lives in a **separate,
  hand-maintained** file so it survives regeneration.
- Concept split to introduce: **logical channel list** (what the maker wants)
  vs **physical slot table** (what DCS stores); the per-type layout is the
  function mapping one onto the other. Bespoke presets become *derivable*
  instead of authored.
- Relationship to [ADR 0003](../adr/0003-presets-fidelity.md): convert-v5
  fidelity stays; projection is the forward-looking generalisation. Warrants a
  new ADR when scoped.

## 8. Decisions and remaining questions

**Resolved (David):**

1. **Mi-24P channel-0 rotation is an airframe property** → apply to *both*
   coalitions (fix Tripack's blue-only inconsistency).
2. **Reserved head slot = the list's last entry (#20 / the guard)**, not a
   hardcoded value; OH-58D FM additionally puts #01 in the "C" slot.
3. Everything is **overridable**, but the default is **automatic packing** of the
   maker's desired lists onto each airframe.

4. **Overflow / truncation follows the existing `validate` vs `build` split**:
   `validate` explains everything (verbose, nothing hidden); a normal `build`
   stays quiet and only surfaces *potential errors* (reuses the current
   presets-validation-report + critical-vs-silent behaviour). No noisy per-
   truncation warning during build.
5. **First-cut scope = every particularity found in Tripack's
   `radioSettings.lua`** — the full §3 taxonomy / §4 inventory (restricted bands,
   rotations, reserved slots, hardcoded specials, radio fusion, modulations), not
   just the three headline types. Design the general layout schema *and* populate
   all detected cases.
6. **Physical-slot → list-role mapping is a fixed, VEAF-maintained layout
   property, not maker-decided.** The layout maps each physical slot to a list
   role explicitly (A-10 → VHF on radio 1, UHF on radio 2); band-based deduction
   is only the fallback for trivial single-band airframes. The maker never needs
   to know an airframe's radio wiring.

**Responsibility split:**

- **VEAF (fixed knowledge base — the layout file):** the *structure* per type —
  slot→role mapping, channel-0 rotation, reserved slots, hardcoded specials,
  slot capacity, radio fusion, per-channel modulation.
- **Mission-maker (`presets.yaml`):** the *content* — the desired channel lists
  (by role), plus an optional explicit **override** (a bespoke preset assigned to
  a type still wins, as today).

All questions are resolved; the model is ready for the design phase.
