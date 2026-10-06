# 08 — QRA logistics declared in mission.yaml

Status: ✅ done — 2026-10-05
Type: feature

Asked by David, 2026-10-05. The stock and resupply chain of a QRA (`setQRAcount`, `setQRAmaxCount`, `setQRAresupplyDelay`, `setResupplyAmount`, `setQRAmaxResupplyCount`, `setQRAminCountforResupply`) is only reachable from hand-written Lua today.
A `logistics:` block on a QRA definition emits those setters; `validate` knows its keys.
