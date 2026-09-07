# 03 — What is missing, and what was kept back, are two lists

Status: ✅ done

Type: fix

## What is wrong

Measured on **issue #938**, the first `/bug` filed with a mission attached. The section headed *Ce
qui manque, et pourquoi* holds 28 lines:

| lines | what they are |
|---|---|
| 25 | fields of the `.miz` the service **chose** not to publish — `descriptionText`, `goals`, `drawings`, `trigrules`, `weather`, `map`… |
| 1 | what the log profile filtered out |
| 1 | no `doctor` block was pasted |
| 1 | `EventHandlers.lua:13`, named by the trace, absent from the repository |

The last two are what the section is *for*. They are at the bottom, after twenty-five lines that say
the service did its job.

Worse, the framing is wrong in a way that matters to a reporter reading his own issue: `.miz` fields
are not *missing*, they are **deliberately withheld** — a mission is summarised, its published
fields chosen one by one, which is what keeps a squadron's briefing and a mission password off a
public tracker. Told as an absence, that protection reads as a failure.

## What to build

Two lists, because they answer two questions.

- **What is missing** — a `doctor` block nobody pasted, a file that could not be read, a location
  the trace named and the checkout does not hold. Things a maintainer may act on.
- **What was deliberately not published** — one line per file, not one per field:
  *`Snowfox_20260903.miz`: summarised, only the fields listed above are published.* The detail of
  which fields is not information a reader wants; that it was summarised, is.

`MaterialNote` carries which of the two it is, and the renderer puts each in its own section, with
its own heading, in both languages. The withheld section is **omitted entirely** when there is
nothing in it, which is the ordinary case for a report with no attachment.

## What must not change

The withholding itself. Not one field more is published than today — this ticket changes how it is
told, and nothing about what is told.

## Done when

- an attached `.miz` contributes **one** line, whatever its field count;
- the two genuine findings of #938 are readable without scrolling;
- the two sections are headed in French and in English;
- a report with nothing withheld shows no withheld section at all;
- tests: a mission's fields collapse to one line, a real absence stays in *what is missing*, and the
  two are never mixed.
