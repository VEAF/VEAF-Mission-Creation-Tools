# Coalitions and countries

Four messages about the same thing: **who belongs to which side** in your mission. Two of them
announce a mission DCS will refuse to load, which makes them the most urgent in the whole
documentation.

## Why there are two tables, not one {#two-tables}

A `.miz` describes ownership **twice**, in two tables that do not talk to each other:

- `coalition.<side>.country[…]` — the objects themselves. Each country there carries its planes,
  helicopters, vehicles, ships and static objects.
- `coalitions.<side>` — the list of country ids that side owns. Nothing else: a list of numbers.

In the DCS editor you never see this split. You place an object, you pick a country, and the editor
fills both. But a tool that injects groups — VMCT included — writes the first and can forget the
second. That is exactly what these checks look for.

`<side>` is `red`, `blue` or `neutrals`. The check runs **side by side**.

## Countries own units but are not in the side's list {#validate-side-missing-countries}

> Side 'red': countries [68 (USSR)] own units but are not listed in coalitions.red ([0 (Russia),
> 81 (Combined Joint Task Forces Red)]): DCS will open the coalition assignment screen and refuse
> to load the mission. Add these country ids — the number alone, without the name — to
> coalitions.red, or re-assign the objects to a country already listed.

**In the editor.** You have red objects belonging to the USSR, but the mission's red side only
declares Russia and Combined Joint Task Forces Red. DCS does not know what to do with those
objects: on load it opens the **CHANGING COALITIONS** screen and stops there.

An id DCS does not know is printed **on its own**, with no name in brackets. That is already
information: the mission holds a country that does not exist in this version of the game.

**How to reproduce it.** The easiest way is to start from a fresh folder and let the build inject
groups: that is the path that produced the defect before it was fixed. An object placed by hand in
the editor does not produce it, since the editor keeps both tables in step.

**The two ways out, and what decides between them.** The message prints **both** lists on purpose,
because the choice is made by comparing them:

| Way out | When to prefer it | What it costs |
|---|---|---|
| Add the missing id to `coalitions.<side>` | The country is wanted — it is a scenario choice | Nothing, but the table has to be edited |
| Re-assign the objects to a country already listed | The country arrived by accident, or one of the two is enough | Going through the objects in the editor |

**Where you fix it, and where you do not.** Not in `mission.yaml`: that file has **no** `coalitions`
key, and trying to add one there does nothing at all. The table lives in the mission itself, so
either:

- in the **DCS editor** — open the `.miz`, make sure the missing country really is part of the
  side, save, then extract the mission folder again;
- in your folder's `src/mission/mission` file, under the `coalitions` key — that is the unpacked
  DCS table. Write **the number alone**, `68`, never `68 (USSR)`: the name is there for you only.

**What it is not.**

- **It is not your neutral statics.** That is the false lead that has cost the most so far, and it
  is half right, which is what makes it stick: static objects **do** count as units for this check,
  exactly like a vehicle. But a *neutral* object belongs to the `neutrals` side, and the check runs
  side by side. A message saying `red` can only be about a red object.
- **It is not an empty country.** A country owning no object never needs to be listed — DCS does
  not care, and the check leaves it alone.
- **It is not a build failure.** The `.miz` was written. It simply will not load.

## A side has no country assigned {#validate-side-without-country}

> Side 'blue' holds units but no country is assigned to it: DCS will open the coalition assignment
> screen and refuse to load the mission. Add the country id to coalitions.blue.

The extreme case of the previous one: the side's list is entirely empty although it owns objects.
The ways out, and where to fix them, are the same.

**How to reproduce it.** This was the behaviour of a mission created with `prepare --theatre`: the
generated blank mission left `coalitions = { blue = {}, red = {}, neutrals = {} }`, and later build
steps added groups without ever touching those lists. Fixed since, in the injectors — but a mission
produced before the fix stayed that way.

**What it is not.** Not the same thing as a side with no units at all: that one triggers nothing,
and even has its own message below.

## A hidden ground group was injected {#builder-coalition-placeholder-injected}

> Coalition 'blue' had no unit — injected a hidden placeholder ground group so DCS registers it (no
> manual ground group needed).

**Nothing is wrong.** This message announces a service rendered, not a problem.

**In the editor.** DCS purges countries that own nothing, and an entirely empty side eventually
disappears from the mission — which breaks everything referring to it at runtime. The classic
workaround was to ask the maker to place "one blue and one red ground group" by hand somewhere. The
build now does it itself, on the side's bullseye, with an invisible group.

**What it is not.** That group does not appear in game, counts towards no objective and triggers
nothing. There is nothing to do, and above all nothing to delete.

## A coalition `country` has an unexpected shape {#builder-coalition-country-unexpected}

> A coalition 'country' is neither a list nor a table (got str); ignoring it and treating the side
> as empty.

**Rare, and it means the mission was damaged.** The `coalition.<side>.country` table must be a list
of countries; the build found something else — usually after a hand edit of `src/mission/mission`,
or a pass from a third-party tool.

**What to do.** Reopen the mission in the DCS editor and save it again: DCS rewrites its tables in
the shape it expects. If you edited `src/mission/mission` by hand, go back to the previous version.
See also [holed tables](routes-and-tables.en.md#validate-holed-sequence), which belong to the same
family of damage.

## The DCS country table {#country-ids}

The messages now print the name next to the id, but an old log, a `.miz` opened by hand or the
`coalitions` table itself contain nothing but numbers. Here is the full mapping.

> **There is no country at id 14.** That is not a mistake in this table: DCS really does have a
> hole there.

| id | Country | id | Country | id | Country | id | Country |
|---|---|---|---|---|---|---|---|
| 0 | Russia | 24 | Belarus | 47 | Syria | 70 | Algeria |
| 1 | Ukraine | 25 | Bulgaria | 48 | Yemen | 71 | Kuwait |
| 2 | USA | 26 | Czech Republic | 49 | Vietnam | 72 | Qatar |
| 3 | Turkey | 27 | China | 50 | Venezuela | 73 | Oman |
| 4 | UK | 28 | Croatia | 51 | Tunisia | 74 | United Arab Emirates |
| 5 | France | 29 | Egypt | 52 | Thailand | 75 | South Africa |
| 6 | Germany | 30 | Finland | 53 | Sudan | 76 | Cuba |
| 7 | USAF Aggressors | 31 | Greece | 54 | Philippines | 77 | Portugal |
| 8 | Canada | 32 | Hungary | 55 | Morocco | 78 | GDR |
| 9 | Spain | 33 | India | 56 | Mexico | 79 | Lebanon |
| 10 | The Netherlands | 34 | Iran | 57 | Malaysia | 80 | Combined Joint Task Forces Blue |
| 11 | Belgium | 35 | Iraq | 58 | Libya | 81 | Combined Joint Task Forces Red |
| 12 | Norway | 36 | Japan | 59 | Jordan | 82 | United Nations Peacekeepers |
| 13 | Denmark | 37 | Kazakhstan | 60 | Indonesia | 83 | Argentina |
| 15 | Israel | 38 | North Korea | 61 | Honduras | 84 | Cyprus |
| 16 | Georgia | 39 | Pakistan | 62 | Ethiopia | 85 | Slovenia |
| 17 | Insurgents | 40 | Poland | 63 | Chile | 86 | Bolivia |
| 18 | Abkhazia | 41 | Romania | 64 | Brazil | 87 | Ghana |
| 19 | South Ossetia | 42 | Saudi Arabia | 65 | Bahrain | 88 | Nigeria |
| 20 | Italy | 43 | Serbia | 66 | Third Reich | 89 | Peru |
| 21 | Australia | 44 | Slovakia | 67 | Yugoslavia | 90 | Ecuador |
| 22 | Switzerland | 45 | South Korea | 68 | USSR | 91 | Afghanistan |
| 23 | Austria | 46 | Sweden | 69 | Italian Social Republic | 92 | New Zealand |

## Going further {#more}

- [Build messages](README.en.md) — the other families
- [The mission folder](../concepts/mission-folder.en.md) — where `src/mission/mission` lives
- [Getting help](../../SUPPORT.en.md)
