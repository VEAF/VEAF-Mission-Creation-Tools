# 01 — Explain, or stay quiet, about a default-enabled script

Status: ⬜ ready

Type: fix · Files: `src/python/veaf-tools/mission_builder/mission_builder_worker.py`,
`veaf_libs/locales/{en,fr}.json`

## Where it comes from

`_ctld_user_config_lua` (`mission_builder_worker.py:940`) returns early unless
`_community_enabled("ctld")`. With no `community_scripts:` section that call falls through to
`is_community_script_enabled_by_default`, and CTLD is opt-out — so the branch runs, finds no
`ctld-config.yaml`, and logs `builder.ctld_no_config`.

## Survey before fixing

Do not stop at CTLD. Walk the opt-out community scripts and find every message a mission gets for a
script it never named — same shape, same confusion, and fixing one leaves the others to be
discovered the same way, one beginner at a time.

That survey is the deliverable as much as the fix: list what you found in the PR, even the cases
you decide to leave alone.

## Then choose

Preferred: say **why** it is enabled and how to opt out, in one string. If the survey shows the
message is only ever actionable for someone who explicitly enabled the script, staying silent on
the defaulted case is better — decide on what the survey shows, and state the reasoning.

Do not touch the opt-out defaults themselves. That changes what every existing mission builds and
belongs to its own lot, if anyone ever wants it.

## Definition of done

- [ ] The survey is in the PR
- [ ] The chosen behaviour is implemented for the whole family, or the PR says why CTLD is special
- [ ] Both languages
- [ ] A test on a mission folder with **no** `community_scripts:` section asserts the output — the
      current message is untested, which is why it could read this way for so long
- [ ] `poetry run pytest`, ruff, mypy clean (run `poetry install --without build --all-extras`
      first, or the coverage figure is wrong)
