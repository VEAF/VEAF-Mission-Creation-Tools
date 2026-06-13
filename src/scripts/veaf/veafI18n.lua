------------------------------------------------------------------
-- VEAF in-game message localization catalog for DCS World
--
-- Features:
-- ---------
-- * Holds the translation catalog (veaf.i18nCatalog) consumed by veaf.t().
-- * The lookup function veaf.t(key, ...) lives in veaf.lua (always available);
--   this module only provides the catalog entries (FR default + EN).
-- * Add a message: add a `["my.key"] = { fr = "...", en = "..." }` entry here,
--   then call `veaf.t("my.key", ...)` at the message site. Migration is
--   incremental — modules are moved over to veaf.t() one at a time.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafI18n = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the module constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafI18n.Id = "I18N"

--- Version.
veafI18n.Version = "1.0.0"

-- trace level, specific to this module
--veafI18n.LogLevel = "trace"

veaf.loggers.new(veafI18n.Id, veafI18n.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Translation catalog: key -> { fr = "...", en = "..." }
-- FR is the default language; a missing language falls back to FR, then to the key.
-- Use %s/%d placeholders for values interpolated by veaf.t(key, ...).
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.i18nCatalog = {
  -- Pilot feedback for marker commands (UXPILOT-FEEDBACK).
  ["marker.command_failed"] = {
    fr = "VEAF : votre commande de marqueur a échoué (voir le log DCS pour les détails).",
    en = "VEAF: your marker command failed (see the DCS log for details).",
  },
  ["spawn.unknown_parameters"] = {
    fr = "VEAF spawn : paramètre(s) inconnu(s) : %s",
    en = "VEAF spawn: unknown parameter(s): %s",
  },
  ["spawn.did_you_mean"] = {
    fr = " (vouliez-vous dire « %s » ?)",
    en = " (did you mean '%s'?)",
  },
}

veaf.loggers.get(veafI18n.Id):info(string.format("Loading version %s", veafI18n.Version))
