# 06 — The answer comes back to where the user is

Status: ⬜ ready

Type: feat

## The debt this pays

Filing under a machine account means the reporter is subscribed to nothing. A maintainer asking
*"can you attach your `dcs.log`?"* on the issue is talking to an empty room, and the user never
learns his bug was even looked at. This is where integrations of this kind normally die: the report
travels fine, and then nobody speaks to anybody.

## What to build

- A durable link between a Discord thread and the issue it produced, surviving a restart.
- A listener for activity on those issues — new comments, labels that matter, closure — reposting
  into the originating thread, in a form a non-developer reads: who said what, and what it means for
  him.
- A tag on the thread when the issue closes, so the state is visible without opening anything.

## The direction not built

Discord → GitHub is deliberately left out. Letting a thread write comments onto a public repository
opens a write channel from a room anyone can join. If it is ever wanted, it needs its own decision
and its own guards; it is not a natural extension of this ticket.

The consequence is worth stating in the documentation: to add something to his report, the user
posts in the thread, and a maintainer carries it over. That is a manual step, and it is the accepted
cost.

## Notes

- Relaying every event turns a thread into noise. Relay what the reporter can act on or wants to
  know; ignore the rest.
- A deleted thread, an archived thread, or a user who left must not break the relay or crash the
  service.
- Bot comments must not feed back into the relay.

## Definition of done

- [ ] Durable thread ↔ issue association, surviving restart
- [ ] Comments and closure relayed into the originating thread, in plain language
- [ ] Thread marked when the issue closes
- [ ] Deleted, archived and orphaned threads handled without failure
- [ ] No relay loop on the bot's own activity
- [ ] Unit tests: relay of a comment, of a closure, and each degraded case
- [ ] Quality gate clean
