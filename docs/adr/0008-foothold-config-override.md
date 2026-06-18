---
status: accepted
---

# Foothold config: untouched upstream + partial override + lexical token validation

A third-party mission like Foothold ships a large, author-controlled config file
(`Foothold Config.lua`, ~1100 lines, versioned by Lekaa with its own changelog).
VEAF only changes a handful of settings at deploy time (difficulty, start side,
auto-restart…). Two tempting designs were rejected: a full YAML→Lua generator
(would have to model and maintain the whole config against an upstream that moves
several times a month — permanent debt), and reusing Foothold's native `Saves/`
override mechanism (whole-file replacement + a separate server-side deployment,
re-introducing both the debt and the "scripts on disk **and** mission on servers"
pain we set out to remove).

## Decision

- **Upstream config is injected untouched** as a `custom_script`, so a new Lekaa
  version drops in with no rewrite.
- **A partial override** (`config_override:`, a **generic passthrough** of
  `lua-global = value`, nested paths supported) is rendered to a small Lua script
  that **reassigns only the changed globals**. It is loaded **between** the
  upstream config and the setup script (ordering carried by `custom_scripts:`
  declaration order), so it never restates the full config.
- **Validation is lexical, not syntactic.** For each override key, each path
  segment is searched as an identifier (`\bsegment\b`) across the **whole** Foothold
  code corpus (config + setup + zoneCommander + …). A segment found nowhere → a
  typo, rename, or upstream removal → the build **fails**. Pure-Python regex, **no
  Lua execution** (per SECREV-001, which removed the lupa runtime; lupa must not be
  reintroduced for this).

## Consequences

- A blocking error on a vanished key turns every silent upstream drift into a
  build-time alert — the intended signal, at the cost of keeping `config_override`
  in step with Lekaa's renames.
- The corpus is the full injected code (not just `Foothold Config.lua`) precisely
  so that overriding an advanced global defined in the setup does not false-fail
  the build.
- Validation judges existence, never value semantics (no `easy|medium|hard`
  enum) — Foothold validates its own values at runtime, keeping VMCT insensitive
  to the upstream schema.
