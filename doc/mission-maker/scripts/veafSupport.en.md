# veafSupport — AWACS and tankers out of reach

**Module ID:** `SUPPORT` | **File:** `veafSupport.lua`

## Purpose {#purpose}

Holds the AWACS and tankers of a mission out of the enemy's air defence, on their own: each asset retreats when a threat reaches its orbit, comes back when the way has long been clear, and tells its side where it now is.
It works in any mission; a [persistent campaign](../PERSISTENT_CAMPAIGN.en.md#support) configures it and hands it the reach measured on its zones.

## Enable {#enable}

In `mission.yaml`:

```yaml
modules:
  SUPPORT:
    enabled: true
    assets: [ "AWACS Magic", "Tanker Texaco", "Tanker Arco" ]
    margin: 30000
```

Each asset is a group placed in the Mission Editor, with an **Orbit** in its route (the AWACS and tanker tasks of the editor): that orbit is where it holds while nothing threatens it.
`MOVE` comes with it: the orbit is moved by `veafMove`'s tanker move.

## How an asset holds {#behaviour}

- **Where**: on the line from the threat nearest its Mission Editor orbit through that orbit, at the first point out of the reach of **every** threat plus `margin`. Never nearer the threat than its orbit — in a persistent campaign, than its side's own front zone —, and as far back as needed.
- **An AWACS holds further out**: at least `awacs_standoff` (100 km, about 55 nm) from the centre of **every** threat, whatever its reach, when it retreats as when it advances. Its radar sees far, it has no need to come near the front; the tankers, handy near the front, keep the reach rule. An asset is an AWACS when DCS gives its aircraft the `AWACS` attribute.
- **Retreat at once**: when a threat reaches its orbit (plus `margin`), it falls back with `retreat_margin`, wider, so as not to sit on the edge.
- **Advance only after a long calm**: it comes closer only when a new orbit `min_advance` (30 km) closer has stayed possible for `advance_seconds` (30 minutes), and no sooner than `advance_seconds` after its last move. A SAM that wakes and sleeps, or appears and dies, every few minutes does not make it shuttle: it falls back once, and holds.
- **Each move is told** to its side: the new orbit by bearing and range from the bullseye, frequency unchanged. In a campaign, its side's command speaks.
  `dcs.log` writes it too, with its distance to the threat: `[AWACS Magic] retreat: orbit moved 100 km (Jisr al-Shughur), orbit now 180/81 NM from the bullseye, 100 km from [Jisr al-Shughur]`.
- **Its marks follow it**: its leg and a label with its name and frequency, drawn on the F10 map for its side only, removed and redrawn at each move, so the map and the announcement always agree.
- **A respawned asset** (the assets menu, the campaign's shop) comes back on its Mission Editor orbit: it is weighed again from there.

## The threats {#threats}

- **In a mission alone**: the enemy's ground units carrying a surface-to-air missile reaching `sam_reach_floor` (15 km) or more — the reach DCS gives the missile, read while the unit is in the world. Guns and short-range missiles are no threat to an AWACS.
- **In a persistent campaign**: every enemy zone with a garrison, at the reach measured on its missiles while awake and remembered while asleep, so a zone falling asleep keeps its threat.

## Settings {#settings}

| Key | Default | What it sets |
|---|---|---|
| `assets` | none | the groups held, by name |
| `margin` | 30000 | metres beyond every enemy reach the orbit holds |
| `retreat_margin` | 50000 | metres beyond the reach, when it retreats |
| `seconds` | 60 | how often the threats are weighed |
| `advance_seconds` | 1800 | how long the way must be clear before it comes closer, and between two advances |
| `min_advance` | 30000 | metres closer a new orbit must be to be worth an advance |
| `leg` | 30 | nautical miles of the racetrack, laid across the axis |
| `sam_reach_floor` | 15000 | metres: in a mission alone, a missile reaching less is no threat |
| `awacs_standoff` | 100000 | metres an AWACS holds from every threat's centre, whatever its reach; not the tankers |

## Still to check in game {#to-verify}

The orbit moved by `veafMove`'s tanker move, its leg across the axis, and the marks redrawn: written and tested outside DCS.
