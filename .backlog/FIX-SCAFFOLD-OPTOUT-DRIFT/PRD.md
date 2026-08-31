# FIX-SCAFFOLD-OPTOUT-DRIFT — two ways to start a mission, two different missions

Status: ⬜ ready

Origin: found while fixing `FIX-DEFAULT-COMMUNITY-NOISE` (PR #867), which explained *why* a
beginner was warned about CTLD. This is why they were in that situation at all. Verified on
`develop`.

## The drift

There are two ways to get a `mission.yaml`, and they disagree about the five opt-out community
scripts (`stts`, `ctld`, `aien`, `csar`, `skynet`).

| Path | What it writes | Effect |
|---|---|---|
| `src/defaults/mission-folder/mission.yaml` (copied as-is) | `STTS: false`, `CTLD: false`, `AIEN: false`, `CSAR: false`, `SKYNET: false` (lines 203-208) | the five are **off** |
| `prepare --template <tier>` (`render_modules_block`) | nothing at all — `mission_template.py:263` skips any module not in the tier | the five are **on**, because absent means default, and their default is on |

So `prepare --template minimal` produces a mission carrying five community scripts, and the word
"minimal" is where a newcomer would least expect it. That is exactly how the tutorial ended up
being told CTLD was enabled and misconfigured in a mission that never mentions CTLD.

## Why it stayed invisible

The default `mission.yaml` never triggers the CTLD warning — it says `CTLD: false`. Only the
`--template` path does. And `--template` is the path the new tutorial teaches, so the first person
to walk it found the message.

## The question

Which scaffold is right? They cannot both be.

- **The template should say `false` too**, matching the shipped default. "Minimal" then means
  minimal, and every scaffold agrees. Cost: a mission maker who *wanted* CTLD from a template now
  has to turn it on — but they had no way to know it was on, so nobody chose it deliberately.
- **The default should stop saying `false`**, matching the template. That makes the shipped file
  shorter and the opt-out default genuinely the default. Cost: it silently enables five scripts in
  every new mission folder, which is the behaviour this lot exists because of.

Recommendation: **the first**. An explicit `false` is readable; an omission that means "on" is not,
and it is what made the confusion undebuggable.

## What it does not change

Missions that already exist keep their own `mission.yaml` and build exactly as before — whatever
was written stays written. Only what a *new* scaffold produces changes. That makes this much safer
than it first sounds, and worth saying in the PR so nobody reads it as a behaviour change.

## Definition of done

- [ ] Both scaffolds produce the same answer for the five opt-out scripts
- [ ] A test compares them directly — not "the template emits X" and "the default contains Y" in
      two separate files, but the two side by side. The drift existed precisely because nothing
      looked at both
- [ ] `prepare --template minimal` followed by `build` no longer mentions a community script the
      mission never asked for
- [ ] The docs that describe what a template emits are checked against the new behaviour

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Make the two scaffolds agree](tickets/01-make-scaffolds-agree.md) | fix |

## Out of scope

- **Changing the opt-out defaults themselves** (making `ctld` opt-in). Much wider: it would change
  what missions with no `community_scripts:` section build today, including missions in service.
