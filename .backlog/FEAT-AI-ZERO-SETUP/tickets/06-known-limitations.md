# 06 — Known limitations from the project memory

Status: ✅ done

Three traps lived only in an assistant's private memory on David's PC: a hole in a numbered table of `src/mission/mission` breaks the build; a slot whose module is disabled shows but cannot be taken; `veaf-tools` resolves `published/` and writes its output relative to the current directory, and `convert-v5` is not idempotent. Add them to `known-limitations.yaml` and regenerate `docs/agents/dcs-runtime-traps.md`.
