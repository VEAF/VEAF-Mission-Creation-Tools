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
veafI18n.Version = "1.1.0"

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
    en = "Your radio has to be authenticated for '+' commands",
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
  ["security.already_locked"] = {
    fr = "Le système était déjà verrouillé",
    en = "The system was already locked down",
  },
  ["security.locked"] = {
    fr = "Le système a été verrouillé",
    en = "The system has been locked down",
  },
  ["security.authenticated_minutes"] = {
    fr = "Le système est authentifié pour %d minutes",
    en = "The system is authenticated for %d minutes",
  },

  -- veafShortcuts
  ["shortcuts.combatmission_name_mandatory"] = {
    fr = "VeafAliasForCombatMission : le nom de la mission est obligatoire",
    en = "VeafAliasForCombatMission: mission name is mandatory",
  },
  ["shortcuts.combatmission_not_found"] = {
    fr = "VeafAliasForCombatMission : la mission %s n'existe pas",
    en = "VeafAliasForCombatMission: mission %s does not exist",
  },
  ["shortcuts.combatzone_name_mandatory"] = {
    fr = "VeafAliasForCombatZone : le nom de la zone est obligatoire",
    en = "VeafAliasForCombatZone: zone name is mandatory",
  },
  ["shortcuts.combatzone_not_found"] = {
    fr = "VeafAliasForCombatZone : la zone %s n'existe pas",
    en = "VeafAliasForCombatZone: zone %s does not exist",
  },
  ["shortcuts.alias_not_found"] = {
    fr = "VeafAlias [%s] introuvable !",
    en = "VeafAlias [%s] was not found !",
  },
  ["shortcuts.running_batch_alias"] = {
    fr = "exécution de l'alias batch [%s] : %s",
    en = "running batch alias [%s] : %s",
  },
  ["shortcuts.running_batch_list"] = {
    fr = "exécution de la liste batch [%s]",
    en = "running batch list [%s]",
  },
  ["shortcuts.cannot_decode_coords"] = {
    fr = "impossible de décoder les coordonnées [%s]",
    en = "unable to decode coordinates [%s]",
  },

  -- veafNamedPoints
  ["namedpoints.no_remote"] = {
    fr = "aucune commande à distance pour veafNamedPoints ; pour l'atc et la météo, essayez -weather",
    en = "no remote command for veafNamedPoints; for atc and weather try -weather",
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

  -- Generic entity activation state (veafCombatZone / veafCombatMission / veafMissileGuardian).
  -- The "%s" is the already-composed "<Label> <name>" (e.g. "VeafCombatZone Alpha").
  ["entity.activated"] = {
    fr = "%s a été activé.",
    en = "%s has been activated.",
  },
  ["entity.already_active"] = {
    fr = "%s était déjà actif.",
    en = "%s was already active.",
  },
  ["entity.deactivated"] = {
    fr = "%s a été désactivé.",
    en = "%s has been deactivated.",
  },
  ["entity.already_inactive"] = {
    fr = "%s était déjà inactif.",
    en = "%s was already inactive.",
  },
  ["entity.is_already_active"] = {
    fr = "%s est déjà actif.",
    en = "%s is already active.",
  },
  ["entity.is_not_active"] = {
    fr = "%s n'est pas actif.",
    en = "%s is not active.",
  },

  -- veafCasMission
  ["cas.target_exists"] = {
    fr = "Un groupe cible CAS existe déjà !",
    en = "A CAS target group already exists !",
  },
  ["cas.smoke_requested"] = {
    fr = "Bien reçu, fumée demandée : fumée ROUGE sur la cible !",
    en = "Copy smoke requested, RED smoke on the deck!",
  },
  ["cas.smoke_available"] = {
    fr = "Marquage fumigène disponible",
    en = "Smoke marker available",
  },
  ["cas.illum_requested"] = {
    fr = "Bien reçu, fusée éclairante demandée : fusée éclairante au-dessus de la zone cible !",
    en = "Copy illumination flare requested, illumination flare over target area!",
  },
  ["cas.illum_available"] = {
    fr = "Éclairage de la cible disponible",
    en = "Target illumination available",
  },
  ["cas.objective_destroyed"] = {
    fr = "Groupe objectif CAS détruit !",
    en = "CAS objective group destroyed!",
  },
  ["cas.objective_cleaned"] = {
    fr = "Groupe objectif CAS nettoyé.",
    en = "CAS objective group cleaned up.",
  },

  -- veaf (core)
  ["mission.ending"] = {
    fr = "Fin de la mission !",
    en = "Ending mission !",
  },

  -- veafMove
  ["move.group_not_found"] = {
    fr = "%s introuvable pour la commande move group",
    en = "%s not found for move group command",
  },
  ["move.tanker_not_found"] = {
    fr = "%s introuvable pour la commande move tanker",
    en = "%s not found for move tanker command",
  },
  ["move.afac_not_found"] = {
    fr = "%s introuvable pour la commande move afac",
    en = "%s not found for move afac command",
  },
  ["move.no_tanker"] = {
    fr = "Impossible de trouver un ravitailleur autour du marqueur",
    en = "Cannot find tanker unit around marker",
  },
  ["move.invalid_fac"] = {
    fr = "%s a une configuration FAC/Orbite invalide",
    en = "%s has an invalid FAC/Orbit configuration",
  },
  ["move.tanker_moving"] = {
    fr = "%s - En route vers votre position immédiatement !",
    en = "%s - Moving to your position right away !",
  },

  -- veafTransportMission
  ["transport.exists"] = {
    fr = "Une mission de transport existe déjà !",
    en = "A transport mission already exists !",
  },
  ["transport.from_mandatory"] = {
    fr = "Le mot-clé « from » est obligatoire !",
    en = 'The "from" keyword is mandatory !',
  },
  ["transport.point_not_found"] = {
    fr = "Le point nommé %s est introuvable !",
    en = "A point named %s cannot be found !",
  },
  ["transport.failure"] = {
    fr = "Le groupe ami a été détruit ! La mission est un échec !",
    en = "Friendly group has been destroyed! The mission is a failure!",
  },
  ["transport.smoke_requested"] = {
    fr = "Bien reçu, fumée demandée : la fumée VERTE marque la zone de largage !",
    en = "Copy smoke requested, GREEN smoke marks the drop zone!",
  },
  ["transport.smoke_available"] = {
    fr = "Marquage fumigène sur la zone de largage disponible",
    en = "Smoke marker over drop zone available",
  },
  ["transport.illum_requested"] = {
    fr = "Bien reçu, fusée éclairante demandée : fusée éclairante au-dessus de la zone cible !",
    en = "Copy illumination flare requested, illumination flare over target area!",
  },
  ["transport.illum_available"] = {
    fr = "Fusée éclairante sur la zone de largage disponible",
    en = "Illumination flare over drop zone available",
  },
  ["transport.cleaned"] = {
    fr = "Mission de transport nettoyée.",
    en = "Transport mission cleaned up.",
  },
  ["transport.cargoes_respawned"] = {
    fr = "Toutes les cargaisons ont été réapparues",
    en = "All cargoes have been respawned",
  },
  ["transport.cargo_delivered"] = {
    fr = "Félicitations pour ce travail bien fait ! La cargaison %s a été livrée en toute sécurité",
    en = "Congratulations on a job well done ! Cargo %s has been delivered safely",
  },

  -- veafGroundAI
  ["groundai.handler_info"] = {
    fr = "Gestionnaire IA %s : %s",
    en = "AI handler %s: %s",
  },
  ["groundai.cannot_aim"] = {
    fr = "%s ne peut pas viser, aucune coordonnée de cible fournie",
    en = "%s cannot aim, no target coordinates provided",
  },
  ["groundai.cannot_fire_effect"] = {
    fr = "%s ne peut pas tirer pour effet, aucune coordonnée de cible fournie et aucune cible précédente",
    en = "%s cannot fire for effect, no target coordinates provided and no previous target exist",
  },
  ["groundai.firing"] = {
    fr = "%s tire %d obus sur %s avec une dispersion de %s m",
    en = "%s is firing %d shells at %s with a %s m dispersion",
  },

  -- veafWeather
  ["weather.fog_set"] = {
    fr = "Brouillard réglé sur %s",
    en = "Fog set to %s",
  },

  -- veafAssets
  ["assets.inactive"] = {
    fr = "%s n'est ni actif ni en vie",
    en = "%s is not active nor alive",
  },
  ["assets.active_one"] = {
    fr = "%s est actif ; une unité en vie\n",
    en = "%s is active ; one unit is alive\n",
  },
  ["assets.active"] = {
    fr = "%s est actif ; %d unités en vie\n",
    en = "%s is active ; %d units are alive\n",
  },
  ["assets.disposed"] = {
    fr = "J'ai éliminé %s",
    en = "I've disposed of %s",
  },
  ["assets.respawned"] = {
    fr = "J'ai fait réapparaître %s",
    en = "I've respawned %s",
  },
  ["assets.lasing"] = {
    fr = " désignation laser au code %s",
    en = " lasing with code %s",
  },
  ["assets.help"] = {
    fr = "Le menu radio liste tous les actifs, amis ou ennemis\nUtilisez ces menus pour faire réapparaître les actifs au besoin\n",
    en = "The radio menu lists all the assets, friendly or enemy\nUse these menus to respawn the assets when needed\n",
  },
}

veaf.loggers.get(veafI18n.Id):info(string.format("Loading version %s", veafI18n.Version))
