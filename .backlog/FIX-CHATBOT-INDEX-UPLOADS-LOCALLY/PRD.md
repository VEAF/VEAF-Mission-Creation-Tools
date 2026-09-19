# FIX-CHATBOT-INDEX-UPLOADS-LOCALLY — the index workflow writes to a throwaway folder and reports success

Status: ⬜ ready

Opened 2026-09-19, out of [DOC-VALIDATION-MESSAGES](../DOC-VALIDATION-MESSAGES/PRD.md), whose
closing check was to ask the documentation assistant the question that started the whole chain. It
still answers wrongly — and the reason is not the documentation.

## The report

`DOC-VALIDATION-MESSAGES` merged as #967 at 18:28. `docs-chatbot-index.yml` fired on the merge and
finished **success** at 18:29. Asked immediately afterwards, through `.\veaf-tools.exe ask`:

> **Q.** *Au build j'ai le message : Camp 'red' : les pays [68 (USSR)] possèdent des unités mais ne
> figurent pas dans coalitions.red. Qu'est-ce que ça veut dire et que dois-je faire ?*
>
> **A.** *…cette coalition n'est pas explicitement définie dans votre fichier mission.yaml. […]
> vous pouvez ajouter ceci à votre mission.yaml :* `red:` / `countries:` / `- USSR`

The same invented `mission.yaml` key that `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON` was opened for.
The new page says the opposite, in so many words, and the assistant never saw it.

## The cause, from wrangler's own output

The upload step's log, on every run:

```
Resource location: local
Use --remote if you want to access the remote instance.
Writing the contents of vec-en.bin to the key "idx:vec:en" on namespace binding: "CHAT_KV" …
Success!
```

`wrangler kv key put` and `wrangler kv bulk put` default to the **local** Miniflare store. In CI that
store is a directory inside the runner, deleted with the runner. The workflow has been embedding the
whole documentation, writing it to a temporary folder, printing `Success!`, and uploading nothing.

**Correction to the first version of this PRD, which said it had never worked.** It did. The upload
command dates from the chatbot's first commit (`b8000101`, 2026-06-11, #414) and has never been
touched — but the `wrangler` pin has: `^3.90.0` until **2026-08-08**, then `^4.120.0` (`33214954`,
#671, closing Dependabot alerts). **Wrangler 3 defaulted `kv key put` to remote; wrangler 4 defaults
to local.** The command kept working and stopped uploading.

The wrong claim came from a `git log -S '"wrangler"'` on `package.json`, which is blind to a change
of *value* — the string count does not move — while `wrangler.toml`'s own comment said otherwise and
was right.

## How stale the production index is — bracketed, not guessed

Three probes through `.\veaf-tools.exe ask`:

| Probe | Page, and when it was added | Does the assistant know it? |
|---|---|---|
| *Comment adopter une mission Foothold…* | `FOOTHOLD.md`, **2026-08-05** | **yes** |
| *Existe-t-il un tutoriel pas à pas…* | `TUTORIAL.md`, **2026-08-31** | no — it answers from the old README quick start |
| (same answer) | the `.\veaf-tools.exe` convention, **2026-09-01** | no — it still quotes the bare form |

So the index froze between **2026-08-05 and 2026-08-31**, which straddles the wrangler bump of
2026-08-08 exactly. **Six weeks of documentation is invisible to the assistant** — and to the
Discord `/ask` command, which reads the same index.

The most quotable part of the bump commit is its own note in `wrangler.toml`: *"the `wrangler kv key
put` form the docs-chatbot-index workflow calls still exists"*. The check made was that the command
still existed. What needed checking was that it still did the same thing.

That also means every previous lot that ended with *"the documentation now covers this"* has been
true of the repository and false of the assistant.

## What to do

1. **Pass `--remote`** on all four upload commands. Wrangler names the flag itself in the message
   above — but *verify it by running it*, do not ship the flag on the strength of a log line. The
   run must be checked against the live assistant, not against a green tick.
2. **Make the step fail when it uploads nothing.** This is the real defect: a pipeline that reports
   success while doing nothing is indistinguishable from one that works. Read a known key back after
   the upload and compare it with what was just written, or assert the byte length. A green run must
   mean the bytes are in the namespace.
3. **Check the `.\veaf-tools.exe ask` path reads the same namespace**, since it is the cheapest way
   anyone will verify this in future.
4. Once it is fixed, ask the coalition question again and close
   [DOC-VALIDATION-MESSAGES](../DOC-VALIDATION-MESSAGES/PRD.md) ticket 07, which is the only thing
   keeping that lot at 🧑.

## Watch out for

- The worker **code** is deployed by hand (carried over from `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON`):
  the similarity floor and the "these excerpts are search results" instruction from #966 may not be
  live either. Two separate things, both worth checking while in there — and the second `ask` of this
  investigation did decline politely, which suggests the instruction half *is* live.
- The first real upload will be the whole index rather than a delta. The embeddings themselves are
  cached (`actions/cache`), so this costs KV writes, not Gemini calls.
- `preview_id` is set in `wrangler.toml`. Make sure the fix targets the production namespace
  (`9599c6c3af6649b291ed8fdc26545dce`), which is what `--preview false` already asks for.

## Definition of done

- [ ] The index really lands in the production KV namespace, verified by reading it back
- [ ] The upload step fails loudly when it writes nothing, with a test or an assertion in the workflow
- [ ] The live assistant answers the coalition question from the new page
- [ ] `DOC-VALIDATION-MESSAGES` ticket 07 closed, and that lot moved to ✅
- [ ] Recorded how far back the staleness went, so the claim "the documentation covers this" can be
      re-read against the lots that made it
