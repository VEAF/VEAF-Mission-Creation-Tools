# FIX-DESTROY-NAME-KEY — `_destroy, name X` clears the circle instead of destroying X

Status: ✅ done — merged in #1069 (2026-10-04)

## Problem

`doc/mission-maker/scripts/veafSpawn{,.en}.md` showed `_destroy, name Tank-1`.
The parser maps `name` to `options.name` and `unitname` to `options.unitName`, and the `destroy` handler (`veafSpawnObjects.lua`) passed only `options.unitName` to `veafSpawn.destroy`.
With `name`, `unitName` is nil and `destroy` takes its radius branch: Tank-1 survives and every unit and static within 150 m of the marker is destroyed.

Measured through `executeCommand` with "Tank-1" and "Bystander" in the circle: `_destroy, name Tank-1` destroyed both.

## Decision

David, 2026-10-04: fix the doc **and** accept `name`, since that is what pilots type (as for `_teleport, name X`).
`unitname` wins when both are written; a blank `name` (the parser's default is `""`) still means "no name".

## Tickets

- [01 — accept `name` in `_destroy` and document the options](tickets/01-destroy-accepts-name.md)
