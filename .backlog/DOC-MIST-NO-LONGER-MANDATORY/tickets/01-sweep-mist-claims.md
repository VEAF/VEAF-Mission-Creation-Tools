# 01 — Sweep the MiST claims

Status: ✅ done

Type: docs · Files: `doc/**` (both languages), `src/defaults/mission-folder/mission.yaml`

## What is true now

Read the code before writing, rather than trusting this summary:

- `MANDATORY_COMMUNITY_SCRIPTS` is `frozenset()` (`mission_builder_worker.py:476`) — nothing is
  force-injected any more;
- MiST is **opt-in** (`mission_constants.get_optin_community_script_ids()` returns `{"tum", "mist"}`);
- the build enables it **by itself** when one of the mission's own `src/scripts/*.lua` calls
  `mist.` — see `mission_scripts_referencing_mist` in `mission_tools/mission_constants.py`, and the
  `mist_callers` path through the builder;
- `veaf.mist.*` still exists in the Lua, as aliases forwarding to `veafMissionDb` — VEAF's own code,
  not MiST. A page describing those as MiST calls is wrong in a second way.

## Known occurrences

`doc/MISSION_YAML_REFERENCE.md:399,410` and `.en.md:397,408`;
`src/defaults/mission-folder/mission.yaml:202` (which contradicts its own line 76).

**These are a starting point, not the list.** Enumerate every mention across `doc/` and
`src/defaults/`, judge each one, and report the sweep — including what you found correct and left
alone. Fixing the three known spots and stopping is how the next reader finds the fourth.

## Definition of done

- [x] No claim that MiST is mandatory, non-disableable, or always injected survives
- [x] The shipped `mission.yaml` says one thing about MiST, not two
- [x] The replacement rule is stated where the old one was — opt-in, auto-enabled on detected use
- [x] Both languages in step
- [x] The sweep, with its judgements, is in the PR
- [x] `poetry run docs-check` passes

## Do not

Change any behaviour. This lot is documentation only: if you find code that disagrees with the
intended behaviour, report it rather than fixing it here.
