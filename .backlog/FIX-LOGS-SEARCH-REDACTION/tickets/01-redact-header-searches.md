# 01 — Redact the searches of the excerpt's header

Status: ✅ done

`veaf_logs.excerpt.build_excerpt` passes each `TextFilter.describe()` through `veaf_libs.redaction.redact`.

Done when `test_excerpt.py` proves an address and a home path typed in the search do not reach the header, and fails without the fix.
