# FEAT-EXTRACT-MERGE — extracting aircraft groups overwrites the file

Status: ✅ done

Origin: VEAF meeting, 2026-08-30. Shape chosen by David on 2026-08-31.

## The gap

`extract-aircraft-groups` writes its result with `open(path, "w")`
(`aircrafts_injector_worker.py::_write_structure`). Whatever the YAML held is gone.

That makes the command a one-shot: you cannot extract the dynamic-slot templates of a second
mission into the same catalogue, and you cannot re-extract after a Mission Editor change without
losing everything the file gathered before.

## The decision

**The mission wins, and the report says so.** A group extracted from the mission replaces the one
in the file; groups the file holds that the mission does not are kept untouched; every replacement
is named in the run's output, so an overwritten hand edit is never silent.

## Shape

The structure is `{category: {coalitions: {coalition: {country: {group name: data}}}}}` — the merge
happens at the group-name level, inside its category / coalition / country.

Merging is what the meeting asked for; whether it becomes the default or an opt-in flag is the
implementer's call, but **do not silently change what an existing script gets**: today's callers
expect a fresh file. State the choice in the PR.

**Choice made: an opt-in `--merge` flag.** Merging by default would not only change what an
existing caller gets, it would reverse a behaviour some rely on — a template deleted in the
Mission Editor currently disappears from the catalogue at the next extraction, and under a
default merge it would survive there forever and keep being injected. That failure is invisible;
having to type `--merge` is not.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Merge into an existing YAML](tickets/01-merge-into-existing-yaml.md) | feat |
