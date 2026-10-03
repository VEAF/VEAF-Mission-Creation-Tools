# 01 — a handle to remove a spawned CAP

Status: ⬜ ready
Type: feature
Issue: [#178](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/178)

## Need

A pilot who spawned a `-cap` has no practical way to remove it: the group is named
`<template> #NNNN`, the spawn message does not say so, and `-destroy` works on a 100 m radius around a
marker. #178 asks for a short token (*"DF56G"*) given at spawn, then usable to destroy the groups.

## To decide

- The handle: a short random token as asked, or the group name made short and announced.
- Whether one handle covers every group of one `-cap` command, or one per group.
- Who may use it: anyone, or the side that spawned it.

## Acceptance

- The spawn message gives the handle.
- A marker command with the handle destroys exactly those groups, and says so; an unknown handle says
  so too.
