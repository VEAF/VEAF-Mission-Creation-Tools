# 02 — `/ask` answers in a public thread

Status: ⬜ ready

Type: feat

## What to build

A `/ask` command on the VEAF Discord. It opens a **public thread** on the question and answers
there, streaming into an edited message.

Why a thread and not an ephemeral reply: the answer serves the next person who asks the same thing,
and anyone passing by can correct the bot. On a documentation assistant that is the only correction
loop that actually catches a wrong answer — no technical guard notices that the doc changed in 6.19.
It also gives the thread a durable identity, which lot 4 reuses to relay GitHub activity back.

## Mechanics

- Discord wants a response within **three seconds**: acknowledge deferred, then edit the message as
  the answer arrives. The Worker already streams over SSE, so the pieces exist.
- The bot cites the documentation pages it used, as links. An answer with no source is a claim.
- It says when the documentation does not cover the question, instead of extrapolating, and offers
  the route to `/bug` — which does nothing until lot 4, so in this lot it points at the support page
  instead.
- Language follows the asker; the corpus is indexed per language (`fr` / `en`) already.
- Errors from upstream are surfaced as a human sentence, including the rate-limited case, rather
  than a stack trace or silence.

## Notes

- The thread is created from the question, so the question text is visible in the channel; the
  answer lives inside. That keeps the channel readable.
- Nothing here writes to GitHub, and nothing here runs an agent. That is deliberate: this lot proves
  the channel, the permissions and the quotas first.

## Definition of done

- [ ] `/ask` registered and answering in a thread attached to the question
- [ ] Deferred acknowledgement inside three seconds, then progressive edit
- [ ] Sources cited as links to the documentation pages used
- [ ] "Not covered by the documentation" answered as such, with a route to the support page
- [ ] Upstream errors, including rate limiting, rendered as a sentence
- [ ] Unit tests with the Discord layer and the Worker both mocked, covering: normal answer,
      unknown answer, upstream error, rate limit
- [ ] Quality gate clean
