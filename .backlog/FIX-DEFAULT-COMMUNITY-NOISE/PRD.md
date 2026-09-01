# FIX-DEFAULT-COMMUNITY-NOISE — a warning about a script the mission never asked for

Status: ✅ done

Origin: found while writing the tutorial (`DOC-TUTORIAL`, PR #863) — building the tutorial's own
minimal mission produced it.

## What happens

Building a minimal mission prints:

> CTLD is enabled but no ctld-config.yaml was found in the mission folder — CTLD will run on its
> own defaults. Create one with ctld-tools.exe, downloadable from …

on a `mission.yaml` where **CTLD is never mentioned**.

## It is not a bug, which is the problem

The message is accurate. With no `community_scripts:` section, `_community_enabled`
(`mission_builder_worker.py:890`) falls back to `is_community_script_enabled_by_default`, and CTLD
is opt-out — so it *is* enabled, and it *has* no configuration file.

The reader has no way to know that. They never wrote CTLD anywhere; the message tells them
something is enabled, misconfigured, and that they should download a separate tool to fix it. On a
first mission, that reads as "I have already broken something" — the tutorial hit exactly this.

## The decision to make

This lot is a wording and behaviour question, not a defect hunt. Options, in increasing order of
change:

1. **Say why it is enabled.** "CTLD is enabled (community scripts are on by default) but no
   ctld-config.yaml…" plus how to turn it off. One string, both languages, no behaviour change.
2. **Only warn when CTLD was asked for.** Stay silent when the mission never mentioned it and the
   default did the enabling — the message is actionable only for someone who chose CTLD.
3. **Reconsider the opt-out default** for a minimal template. Much wider, touches what a scaffolded
   mission ships, and would change existing missions' builds. Almost certainly out of scope, listed
   so it is visibly considered and rejected rather than overlooked.

Recommendation: **1, and check whether 2 is right for the whole family** — CTLD is unlikely to be
the only opt-out script that warns about its own absence of configuration. Look at the other
community scripts before settling: a fix that only covers CTLD leaves the next one to be found the
same way.

## Definition of done

- [ ] A build of the tutorial's minimal mission no longer tells a beginner about a tool they never
      asked for — or tells them in a way that explains itself and how to opt out
- [ ] Whatever is decided applies to the whole family of opt-out community scripts, not just CTLD,
      or the PR says why CTLD is special
- [ ] Both languages
- [ ] A test pins it: a mission with no `community_scripts:` section must produce the chosen
      output. This is the kind of message nothing tests today

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Explain, or stay quiet, about a default-enabled script](tickets/01-default-enabled-warning.md) | fix |
