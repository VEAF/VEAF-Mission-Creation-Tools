# 02 — The fog commands are not translated

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafWeather.lua` (`createDynamicFog` / `createStaticFog` calls near l. 1672-1681, the animated fog titles), `src/scripts/veaf/veafI18n.lua`, tests

## What happens

In a `language: fr` mission, F10 > VEAF > MÉTÉO ET ATC > Réglages du brouillard shows translated submenus (« Brouillard animé », « Brouillard animé sur 1 minutes », « Brouillard statique ») but untranslated commands: « Animated HEAVY fog over 1 minutes », « Static SPARSE fog », « Dynamic MEDIUM fog »…
The command titles are English literals passed to `createDynamicFog("Dynamic HEAVY fog", …)` / `createStaticFog("Static HEAVY fog", …)`; `menu.weather.*` keys exist for the submenus only.

## Measured

Demo test mission, 2026-10-05: the whole subtree read from `veafRadio._builder._root` over the bridge, 48 commands in English under French submenus.

## Fix

Give each fog command an i18n key (a format key for the density level and duration rather than one key per combination), FR and EN, resolved when the menu is built.
Watch the `%d minutes` plural the submenu already gets wrong in French (« sur 1 minutes »).

## Test

With `veaf.config.language = "fr"`, every command title under the fog menu comes from `veafI18n` (no English literal left); the EN build keeps today's titles.
