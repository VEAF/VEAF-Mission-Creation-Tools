# Modules and community scripts

The family where people most often wonder "have I broken something?". Usually not — and that is one
of the reasons this page exists.

## The one fact that explains almost everything {#community-opt-out}

**Community scripts are enabled by default.** You do not have to write anything in `mission.yaml`
for CTLD, CSAR or MiST to be candidates for embedding: they are there unless you take them out.

That is convenient, but it has an unpleasant side effect: a warning may be about a module you
**never** asked for, and the message then reads as an accusation. To take a module out:

```yaml
modules:
  CTLD: false
```

## CTLD is enabled, but with no configuration {#builder-ctld-no-config}

> CTLD is enabled but no ctld-config.yaml was found in the mission folder — CTLD will run on its
> own defaults. Create one with ctld-tools.exe, downloadable from
> https://github.com/VEAF/CTLD/releases (CTLD 2 releases are pre-releases: go through the Releases
> tab).

**When it appears.** You **explicitly** wrote CTLD under `modules:` in your `mission.yaml`, and
there is no `ctld-config.yaml` in the mission folder.

**What it changes.** CTLD runs on its original settings: logistic unit types, troop zones and drop
points are the script's, not yours.

**The way out.** Create the file with `ctld-tools.exe`. The link in the message is the right place
— and the note about pre-releases matters: CTLD 2 versions do not show up in GitHub's main release
listing.

**What it is not.** Not an error, and CTLD works. If its defaults suit you, you can ignore this
message indefinitely.

## CTLD is there because it is there {#builder-ctld-no-config-by-default}

> CTLD is in this mission because community scripts are enabled by default — your mission.yaml
> never mentions it. There is no ctld-config.yaml here, so CTLD simply runs on its own settings:
> nothing is broken, and you can ignore this. To leave CTLD out of the mission, add 'CTLD: false'
> under 'modules:' in mission.yaml. To configure it instead, create ctld-config.yaml with
> ctld-tools.

**Nothing is broken.** This message exists because the previous one, shown in this situation, was
in effect telling somebody who had never heard of CTLD to go and download a tool. It was split off
deliberately.

**The difference with the previous message**, and that is the whole subtlety:

| | You wrote `CTLD` under `modules:` | You wrote nothing |
|---|---|---|
| Message | "CTLD is enabled but no file…" | "CTLD is in this mission because…" |
| What you are offered | Create the configuration | Remove CTLD, **or** configure it |

**The ways out.** Do nothing, or write `CTLD: false` under `modules:` if you do not want CTLD in
your mission.

## CTLD with no logistic point at all {#builder-ctld-logistics-unmanaged-and-empty}

> ════════════════════════════════════════════════════════════════
> WARNING — CTLD: NO LOGISTIC POINT AT ALL
> modules.CTLD.manage_logistics is false and, in ctld-config.yaml, logisticUnitTypes and
> troopZoneShipTypes are both empty.
> No FARP and no carrier placed in the editor will be a loading point.
> If that is not intended, set manage_logistics back to true, or fill those lists with ctld-tools.
> ════════════════════════════════════════════════════════════════

**In the editor.** Your FARPs and carriers are right there, visible, placed — and none of them will
be a CTLD loading point. Helicopters will be able to load troops or cargo nowhere.

**Why it is framed.** It is a legitimate combination — you may want to handle logistics entirely by
hand — but never an accident worth staying silent about. Hence the frame: it is the only way not to
miss it in a build's output.

**The ways out.** Set `manage_logistics: true` again so VMCT fills the lists, or fill them yourself
with `ctld-tools`.

## CTLD: the logistic types were extended {#builder-ctld-logistics-merged}

> CTLD: automatic logistics management — logisticUnitTypes extended with FARP, … Your
> ctld-config.yaml is untouched; the copy injected into the mission is what changed.

**Nothing is wrong.** The message has a second sentence for a good reason: your file on disk is
**not touched**. What changes is the copy handed to the engine. Without that clarification you
would read one thing in `ctld-tools` while another ran in game.

**To stop it.** `manage_logistics: false` under `modules.CTLD` — but read the previous message
first, as that is exactly the path leading to it.

## Sound files are missing {#builder-community-sounds-missing}

> Sound file(s) required by an enabled community module are shipped by neither the tools nor the
> mission: beacon.ogg. Add them to src/mission/l10n/DEFAULT/ or the related feature will be silent
> (e.g. CTLD beacons).

**What it means.** An enabled module calls for a sound that neither the tools nor your folder
provides. In game the feature will work — silently.

**Where the file must go.** In `src/mission/l10n/DEFAULT/`, and **nowhere else**. A sound placed
elsewhere in the mission (in the kneeboard folder, for example) does not count: the scripts look
for it in that exact place.

**The ways out.** Add the file, or disable the module asking for it.

## TUM with no territory zones {#validate-tum-zones-missing}

> TUM is enabled but no BLUFOR, REDFOR territory trigger zone was found — TheUniversalMission
> aborts at start-up without them.

**In the editor.** TUM needs at least one trigger zone whose name **starts with** `BLUFOR` and one
whose name starts with `REDFOR` — case does not matter. These are the two sides' starting
territories.

**What happens without them.** TUM stops at initialisation. No message in game, no menu: the module
is simply absent. So this build warning is the only notice you will get.

**The ways out.** Create the zones in the editor, or disable TUM in `mission.yaml`.

## A module is incompatible with the conversion profile {#validate-incompatible-module}

> modules: 'CTLD' is incompatible with the 'foothold' conversion profile and must stay disabled.

At build time it is a flat refusal:

> Cannot build: module(s) CTLD are incompatible with the 'foothold' conversion profile. Disable
> them in mission.yaml.

**What it means.** Your `mission.yaml` carries a `conversion_profile`, and that profile declares
certain VEAF modules incompatible. For `foothold` it is **CTLD**: a Foothold mission ships its own
CTLD among its `custom_scripts`, and loading both puts them in conflict.

**The single way out.** Disable the module:

```yaml
modules:
  CTLD: false
```

**What it is not.** Not an opinion on the module's quality — it is a double-loading problem. And it
is one of the rare messages in this documentation that really **stops** the build.

## An always-active module cannot be disabled {#builder-mandatory-module-enable}

> Module 'UNITS' is always active and cannot be enabled or disabled (enable: false) — remove the
> 'enable' key from its entry in mission.yaml.

**This one stops the build.** It is an error, not a warning: the `.miz` is not written.

**The modules concerned.** `UNITS`, `TIME`, `CACHE`, `EVENTS`, `MARKERS` and `COMMANDS`. They are
the foundations of the VEAF framework: everything else depends on them, so turning them on or off
makes no sense.

**What triggers it exactly.** Only the expanded form, with an `enable` or `enabled` key inside:

```yaml
modules:
  UNITS:
    enable: false      # ← refused
```

**The way out.** Remove that key. You can keep the entry in order to **configure** the module; it
is only claiming to switch it on or off that is refused.

## A community script id is unknown {#builder-unknown-community-script}

> Unknown community script id 'ctdl' in 'community_scripts:'; ignoring.

**Almost always a typo**, or the name of a script since removed from the tools. The entry is
ignored — so if you were trying to **disable** that script, be aware that nothing was disabled at
all.

**By the way:** `community_scripts:` is the deprecated form. See below.

## `lua_modules:` and `community_scripts:` are deprecated {#builder-modules-deprecated}

> Deprecated: 'lua_modules:' and 'community_scripts:' are replaced by 'modules:' — please update
> your mission.yaml

And if you have both forms at once:

> 'modules:' and 'lua_modules:'/'community_scripts:' both present — 'modules:' takes precedence

**What it means.** The old sections still work, but `modules:` replaces both of them: a single
block for VEAF modules and community scripts alike.

**The trap when both coexist.** `modules:` wins, **entirely**. A module you believe is enabled in
`lua_modules:` is not, unless it is also in `modules:` — which is the nastiest cause of a module
that "does not start" with no message saying so.

**The way out.** Merge into `modules:`, then delete both old sections. See
[`mission.yaml` and its modules](../concepts/mission-yaml.en.md).

## Going further {#more}

- [Build messages](README.en.md) — the other families
- [`mission.yaml` and its modules](../concepts/mission-yaml.en.md)
- [`mission.yaml` reference — `modules:`](../../MISSION_YAML_REFERENCE.en.md#modules)
