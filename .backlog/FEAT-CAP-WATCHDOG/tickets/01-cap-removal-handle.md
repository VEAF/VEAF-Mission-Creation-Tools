# 01 — a handle to remove a spawned CAP

Status: 🚫 wontfix — decided by David on 2026-10-04
Type: feature
Issue: [#178](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/178)

## Need

A pilot who spawned a `-cap` has no practical way to remove it: the group is named `<template> #NNNN`, the spawn message does not say so, and `-destroy` works on a 150 m radius around a marker. #178 asks for a short token (*"DF56G"*) given at spawn, then usable to destroy the groups.

## To decide

- The handle: a short random token as asked, or the group name made short and announced.
- Whether one handle covers every group of one `-cap` command, or one per group.
- Who may use it: anyone, or the side that spawned it.

## Decision

No handle.
`-destroy` is geographic — it removes everything within a radius of its marker — and that is enough to remove a CAP: a `-destroy, radius <metres>` marker placed on it.
It stays `SENIOR_PILOT`; a known pilot who spawned a CAP asks a senior one to remove it.

The radius form measures on the ground plane (`veaf.findUnitsInCircle`), so it reaches an aircraft in flight; the default radius is 150 m, so a moving CAP needs a larger one, which removes everything else in the circle too.
The mission-maker page says so in the CAP section (FR + EN).
