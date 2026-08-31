# DOC-MIST-NO-LONGER-MANDATORY — the docs still say MiST cannot be turned off

Status: ⬜ ready

Origin: spotted while delivering `FIX-SCAFFOLD-OPTOUT-DRIFT` (PR #869). Verified on `develop`.

## Not stale — actively wrong

The `DROP-MIST` campaign made MiST opt-in: `MANDATORY_COMMUNITY_SCRIPTS` is now
`frozenset()` (`mission_builder_worker.py:476`), and MiST is injected only for a mission whose own
scripts call it. The documentation still describes the old world, and does so as a rule:

| Where | What it claims |
|---|---|
| `doc/MISSION_YAML_REFERENCE.md:399` / `.en.md:397` | "except `MIST`, a hard dependency of the VEAF scripts: an explicit `MIST: false` is overridden with a build warning and the script is injected anyway" |
| `doc/MISSION_YAML_REFERENCE.md:410` / `.en.md:408` | table row: "**mandatory, cannot be disabled**" |
| `src/defaults/mission-folder/mission.yaml:202` | "(MiST is mandatory and lives in the Infrastructure block above.)" |

The shipped `mission.yaml` contradicts **itself**: line 76 says MiST is "no longer injected by
default (336 KB saved)" and line 202 says it is mandatory infrastructure.

A reader who writes `MIST: false` today is told, in writing, that their setting will be ignored.
It will not be — and the 336 KB they were trying to save are already saved.

## Sweep, do not sample

The three places above are the ones already found, not the list. MiST appears across the docs
tree (`doc/developer/`, `doc/LUA_API_REFERENCE`, `doc/mission-maker/`), and the campaign changed
what is true about it in more than one respect: mandatory → opt-in, always injected → injected on
detected use, and `veaf.mist.*` surviving as aliases that forward to `veafMissionDb` rather than to
MiST. Enumerate the occurrences and judge each; do not fix the three and declare it done.

## Definition of done

- [ ] No page claims MiST is mandatory, non-disableable, or injected regardless of configuration
- [ ] The shipped `mission.yaml` stops contradicting itself
- [ ] What replaced the rule is stated where the old rule was: MiST is opt-in, and the build turns
      it on by itself when one of the mission's own scripts calls `mist.`
- [ ] Both languages, in step
- [ ] The sweep is reported in the PR, including occurrences judged correct and left alone
- [ ] `poetry run docs-check` passes

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Sweep the MiST claims](tickets/01-sweep-mist-claims.md) | docs |
