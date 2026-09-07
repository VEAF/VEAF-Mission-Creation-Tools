# 03 — A direct run, for the rehearsal

Status: 🔄 in-progress

Type: feat

## What to build

`scripts/run.ps1`: read the same `.env` the container would, put it in **one process's**
environment, and start the module.

The gap it fills: the service reads its configuration from the environment and never from a file —
its own decision — so the container is started with `--env-file` and a direct run has no equivalent.
The README's instructions set the variables one at a time, which is fine for three variables and
unusable for sixteen.

- Process scope only. Nothing is written to the machine's environment, where every other program
  could read the bot token.
- A malformed line is **named**, not skipped in silence: a missing token reads exactly like a token
  nobody pasted, and the two are debugged differently.
- The exit code is propagated. **78** (`EX_CONFIG`) means this deployment is wrong and restarting
  will not help; anything else non-zero is a crash. Verified 2026-09-07: an incomplete `.env` gives
  78 and lists all five problems at once.
- `-Python` for a host with no Poetry, `-Healthcheck` to probe a running service.

## Why keep it once Docker is the target

Two uses that Docker does not cover. Watching the bot work on a developer machine — Docker is not
installed on DAVID-BUREAU — and the README's own claim that a direct run is a real rehearsal of the
deployment, since it is the same module with the same environment.

## Definition of done

- [x] Reads `.env`, process scope, no interpolation
- [x] Propagates the exit code, 78 included
- [ ] Documented where the direct run is documented
- [ ] Quality gate clean
