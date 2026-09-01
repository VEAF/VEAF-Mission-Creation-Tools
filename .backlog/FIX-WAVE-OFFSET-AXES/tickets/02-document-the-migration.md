# 02 — Say what moves, in both languages

Status: ✅ done

Type: docs · Files: `doc/mission-maker/scripts/veafAirWaves.md`/`.en.md`,
`doc/mission-maker/scripts/veafQraManager.md`/`.en.md`, `CHANGELOG.md`

## The defect

Both examples under *VEAF commands as groups* were wrong:

```lua
"[0,5000]-spawn su-27, country russia",           -- 5 km north of zone centre
"[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km south, low level
```

Against the old code, `[0,5000]` was 5 km **south** and `[-3000,0]` was 3 km **west**. And `[0,5000]`
was wrong under *either* reading — the number it annotates is the longitude one, so even taking the
names at face value it should have said "east". Nobody was describing observed behaviour.

Beyond the examples, nothing on the page said which bracket number was which axis, or which sign went
which way. That is the information a mission maker actually needs.

## What was done

- The two examples rewritten so their numbers match their annotations, and a sentence added stating
  the order plainly: first number north–south, second east–west, both positive towards north and
  east.
- A `Behaviour change` admonition on both pages: which offsets move, and that an offset tuned by eye
  against the old behaviour has to be rewritten the way it reads. **No version number written by
  hand** — that is the changelog's job, and the repository rule.
- An explicit `{#spawn-offset}` anchor on the section, identical in both languages, with the two
  `veafQraManager` builder tables pointing at it: the QRA setter has the same two parameters and had
  the same defect, so a reader landing there needs the same explanation.
- `CHANGELOG.md` entry stating the migration.

## What the examples settled

`[-3000,0]` annotated *"3 km south"* is correct **only** under the corrected reading. So the author of
that line meant latitude first, and its companion was simply written with its numbers reversed. That
is what made option (a) — the code is wrong — the honest reading rather than a preference.

## Gate

`poetry run docs-check` clean, including the new cross-page anchor.
