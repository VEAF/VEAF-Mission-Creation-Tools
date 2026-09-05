# 03 — The page tells visitors the assistant is rationed

Status: ⬜ ready

Type: docs

## What to write

One short passage, where the chatbot lives and on the support page, saying that the assistant runs
on a free allowance shared by every visitor, that it can run out on a busy day, and that it comes
back the next day. Nothing more — no numbers that will age, no apology.

The point is that someone who meets the limit understands they met a limit, rather than concluding
the tool is broken and never coming back.

## Notes

- Both languages in lockstep, and `poetry run docs-check` passes.
- No hand-written version numbers, no quota figures in prose: the numbers move, and the deploy
  workflow does not stamp them.
- If ticket 01 finds the ceiling is never approached, this stays worth writing — it costs three
  sentences and covers the day someone links the chatbot on Discord.

## Definition of done

- [ ] The passage exists in both languages, next to the chatbot and on the support page
- [ ] It explains the ration and the reset without naming figures
- [ ] `poetry run docs-check` passes
