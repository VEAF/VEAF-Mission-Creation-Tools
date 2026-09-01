# 01 — Do not abort when nobody can answer

Status: ✅ done

Type: fix · Files: the `about` command, plus whatever the survey turns up

## Reproduce first

```bash
veaf-tools about < /dev/null ; echo $?      # 1, prints "Aborted."
echo n | veaf-tools about ; echo $?          # 0
```

## The change

Ask only when there is someone to answer. `veaf_tools/helpers.py` already reads
`sys.stdout.isatty()` for the exit pause (`_is_double_clicked`); use the same kind of test rather
than inventing a second convention, and put it where other commands can reuse it.

## Survey

Look for other commands that prompt unconditionally. The point of the lot is that a command must
not report failure when it succeeded; `about` is the instance we tripped over, not necessarily the
only one. Report what you find, including what you leave.

## What was done

`veaf_tools/helpers.py` gained `is_interactive()` and `confirm()`; the ten unconditional prompts
now go through them (see the survey table in the PRD). No new user-facing string, so no
translation work — the change removes a question, it does not add one.

## Definition of done

- [x] No terminal → no prompt, content printed, exit 0
- [x] With a terminal → unchanged, including opening the browser on `y`
- [x] A test covers the non-interactive path
- [x] The survey is in the PR
- [ ] `poetry run pytest`, ruff, mypy clean (`poetry install --without build --all-extras` first,
      or the coverage figure is wrong)
