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

  -- veafRadio
  ["radio.auth_required"] = {
    fr = "Votre radio doit être authentifiée pour les commandes « + »",
    en = "Your radio has to be authenticated for '+'' commands",
  },
  ["radio.playing_format"] = {
    fr = "%s (%s) : diffusion de %s",
    en = "%s (%s) : playing %s",
  },

  -- veafRemote
  ["remote.bad_password"] = {
    fr = "Mot de passe incorrect ou manquant",
    en = "Bad or missing password",
  },

  -- veafSkynetIadsHelper
  ["skynet.no_sam_in_range"] = {
    fr = "Aucun site SAM à portée pour y ajouter des défenses rapprochées",
    en = "Could not find SAM site within range to add point defenses to",
  },

  -- veafSecurity
  ["security.password_invalid"] = {
    fr = "le mot de passe est absent ou incorrect",
    en = "password was not set or was not correct",
  },
  ["security.use_password"] = {
    fr = "Veuillez utiliser l'option « , password <mot de passe %s> »",
    en = "Please use the ', password <%s password>' option",
  },

  -- veafSpawn (aircraft / core / effects / ground)
  ["spawn.cannot_find_unit"] = {
    fr = "impossible de trouver l'unité %s",
    en = "cannot find unit %s",
  },
  ["spawn.cannot_find_group"] = {
    fr = "impossible de trouver le groupe %s",
    en = "cannot find group %s",
  },
  ["spawn.air_wip"] = {
    fr = "Les unités aériennes ne peuvent pas être créées pour le moment (en cours de développement)",
    en = "Air units cannot be spawned at the moment (work in progress)",
  },
  ["spawn.no_cap"] = {
    fr = "Aucune CAP disponible au spawn",
    en = "No CAP available for spawn",
  },
  ["spawn.afac_limit"] = {
    fr = "La limite d'AFAC est atteinte, il faut en détruire un",
    en = "The limit for AFACs was reached, one needs to be destroyed",
  },
  ["spawn.no_position_unit"] = {
    fr = "impossible de trouver une position adéquate pour faire apparaître l'unité %s",
    en = "cannot find a suitable position for spawning unit %s",
  },
  ["spawn.no_position_cargo"] = {
    fr = "impossible de trouver une position adéquate pour faire apparaître la cargaison %s",
    en = "cannot find a suitable position for spawning cargo %s",
  },
  ["spawn.no_position_static"] = {
    fr = "impossible de trouver une position adéquate pour faire apparaître l'objet statique %s",
    en = "cannot find a suitable position for spawning static %s",
  },
  ["spawn.cargo_type_not_found"] = {
    fr = "type de cargaison introuvable : %s",
    en = "could not find cargo type named %s",
  },
  ["spawn.group_spawned"] = {
    fr = "Un %s(%s) est apparu",
    en = "A %s(%s) has been spawned",
  },
  ["spawn.teleported"] = {
    fr = "Groupe téléporté %s",
    en = "Teleported group %s",
  },
  ["spawn.cannot_teleport"] = {
    fr = "Impossible de téléporter le groupe : %s",
    en = "Cannot teleport group : %s",
  },
  ["spawn.spawned_infantry"] = {
    fr = "Groupe d'infanterie dynamique créé %s",
    en = "Spawned dynamic infantry group %s",
  },
  ["spawn.spawned_armored"] = {
    fr = "Peloton blindé dynamique créé %s",
    en = "Spawned dynamic armored platoon %s",
  },
  ["spawn.spawned_airdef"] = {
    fr = "Batterie de défense aérienne dynamique créée %s",
    en = "Spawned dynamic air defense battery %s",
  },
  ["spawn.spawned_transport"] = {
    fr = "Compagnie de transport dynamique créée %s",
    en = "Spawned dynamic transport company %s",
  },
  ["spawn.spawned_combat"] = {
    fr = "Groupe de combat complet créé %s",
    en = "Spawned full combat group %s",
  },
  ["spawn.spawned_convoy"] = {
    fr = "Convoi créé %s",
    en = "Spawned convoy %s",
  },
  ["spawn.no_destination"] = {
    fr = "Aucune destination saisie !",
    en = "No destination entered!",
  },
  ["spawn.point_not_found"] = {
    fr = "Le point nommé %s est introuvable, et ce ne sont pas des coordonnées valides !",
    en = "A point named %s cannot be found, and these are not valid coordinates !",
  },
  ["spawn.no_convoy"] = {
    fr = "Aucun convoi trouvé",
    en = "No convoy found",
  },
  ["spawn.convoy_smoke_switch"] = {
    fr = "%s passe de la fumée verte à la fumée rouge",
    en = "%s is going from green to red smoke",
  },
  ["spawn.convoy_white_smoke"] = {
    fr = "%s marqué avec de la fumée blanche",
    en = "%s marked with white smoke",
  },
  ["spawn.convoys_cleaned"] = {
    fr = "Tous les convois ont été nettoyés",
    en = "All convoys cleaned up",
  },
  ["spawn.iads_group_added"] = {
    fr = "Groupe ajouté à l'IADS nommé « %s »",
    en = 'Group added to the IADS named "%s"',
  },
  ["spawn.iads_group_not_added"] = {
    fr = "Impossible d'ajouter le groupe à l'IADS nommé « %s », réseau introuvable ou groupe non pris en charge",
    en = 'Could not add group to the IADS named "%s", network not found or group not supported',
  },
}

veaf.loggers.get(veafI18n.Id):info(string.format("Loading version %s", veafI18n.Version))
