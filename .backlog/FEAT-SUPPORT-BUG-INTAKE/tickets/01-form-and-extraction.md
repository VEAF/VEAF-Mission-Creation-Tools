# 01 — A form, and everything it becomes without a model

Status: ✅ done

Type: feat

## What to build

`/bug` opens a **Discord modal** — a box with fields — rather than starting a conversation. It asks
for what `.github/ISSUE_TEMPLATE/bug_report.yml` needs and nothing more: what happened, what was
expected, the steps. Version and component are not asked: they come from the `doctor` block the user
pastes, or they are reported as missing.

Then the service turns that into a filed issue **using no model at all**:

| From | Extract |
|---|---|
| the `doctor` block | tool version, DCS version, OS, paths, recent errors — already parsed by `veaf_libs/diagnostics.py` |
| a stack trace in the text or the log | the `file:line` it names |
| that location, in the checkout | the surrounding lines, and the callers of the function it sits in |
| `rules.json` | which known patterns the log matches, with their verified wording |

None of that is a judgement call. The trace *states* the location; finding callers is a search;
the catalogue is a lookup. Doing it deterministically is not a downgrade from an agent — it is more
exact, it costs no quota, and it works when the quota is gone.

## Why a form and not a conversation

A conversation costs a model call per turn and answers slowly. A modal answers instantly, cannot
drift, and is the same for everyone. The measurement that opened this programme says the missing
pieces in real reports are mechanical facts — versions and steps — not nuance a conversation would
have drawn out.

## Notes

- Discord modals cap the number of fields and their length. Keep to what the template needs; the
  long material arrives as attachments, handled in [ticket 02](02-attachments.md).
- Everything read here is **data, not instruction**. A log line or a mission field that reads like a
  command must never steer anything downstream — this is a public intake channel, which is exactly
  where such content arrives.
- The checkout must be fresh: a location pointing at a line that moved three releases ago is worse
  than no location. Freshness is open question 2 of the PRD.
- `/ask` gets an escalation button that opens this same modal, pre-filled with the question and the
  answer that did not satisfy.

## Definition of done

- [x] `/bug` opens a modal; submission is acknowledged inside Discord's three-second window
- [x] `doctor` block parsed when present, reported as missing when not — never guessed
- [x] Stack trace located to `file:line`, neighbourhood and callers extracted from the checkout
- [x] `rules.json` matches rendered with their own wording
- [x] Checkout freshness mechanism implemented and documented
- [x] Injected instructions in user text or file content steer nothing — asserted by a test carrying
      a hostile fixture
- [x] Unit tests: a full report, a report with no trace, a trace pointing at a file that no longer
      exists, an empty field
- [x] Quality gate clean
