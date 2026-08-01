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
  ["radio.next_page"] = {
    fr = "Page suivante",
    en = "Next page",
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

  -- veafCarrierOperations
  ["carrier.not_found"] = {
    fr = "Groupe porte-avions introuvable : %s",
    en = "Cannot find the carrier group %s",
  },
  ["carrier.stopped"] = {
    fr = "Le groupe porte-avions %s a cessé ses opérations aériennes ; il retourne à sa position initiale",
    en = "The carrier group %s has stopped air operations ; it's moving back to its initial position",
  },
  ["carrier.help"] = {
    fr = "Utilisez les menus radio pour démarrer et arrêter les opérations du porte-avions\n"
      .. "START : le porte-avions détermine le vent et fait route à vitesse optimale pour obtenir un vent debout de 25 kn\n"
      .. "        le menu radio affichera le cap de récupération et les informations TACAN\n"
      .. "END   : le porte-avions retourne à son point de départ (là où il était au lancement de la commande START)\n"
      .. "RESET : le porte-avions retourne à sa position au début de la mission",
    en = "Use the radio menus to start and end carrier operations\n"
      .. "START: carrier will find out the wind and set sail at optimum speed to achieve a 25kn headwind\n"
      .. "       the radio menu will show the recovery course and TACAN information\n"
      .. "END  : carrier will go back to its starting point (where it was when the START command was issued)\n"
      .. "RESET: carrier will go back to where it was when the mission started",
  },

  -- veafSanctuary (enforcement status shown to the protected coalition)
  ["sanctuary.unit_in_zone"] = {
    fr = "L'unité %s est dans la zone %s depuis %d secondes",
    en = "Unit %s is in the %s zone since %d seconds",
  },
  ["sanctuary.instant_kill"] = {
    fr = "Destruction immédiate de l'unité %s, dans la zone %s depuis %d secondes",
    en = "Instantly killing unit %s, in zone %s since %d seconds",
  },
  ["sanctuary.spawning_defenses"] = {
    fr = "Déploiement de défenses pour repousser l'unité %s, dans la zone %s depuis %d secondes",
    en = "Spawning defense systems to fend off unit %s, in zone %s since %d seconds",
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
  ["spawn.unit_spawned"] = {
    fr = "Un %s (%s) est apparu",
    en = "A %s (%s) has been spawned",
  },
  ["spawn.jtac_spawned"] = {
    fr = "JTAC créé, désignation sur %s, disponible sur %s %s",
    en = "JTAC spawned, lasing on %s, available on %s %s",
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
  ["cas.spawn_confirmation"] = {
    fr = "CIBLE : groupe de %d véhicules et %d fantassins. Voir le menu radio F10 pour les détails\n",
    en = "TARGET: Group of %d vehicles and %d soldiers. See F10 radio menu for details\n",
  },
  ["cas.report_target"] = {
    fr = "CIBLE : groupe de %d véhicules et %d fantassins.\n",
    en = "TARGET: Group of %d vehicles and %d soldiers.\n",
  },
  ["cas.report_afac"] = {
    fr = "AFAC en station : %s\n",
    en = "AFAC on station: %s\n",
  },
  ["cas.report_latlon_decimal"] = {
    fr = "LAT LON (décimal): %s.\n",
    en = "LAT LON (decimal): %s.\n",
  },
  ["cas.report_latlon_dms"] = {
    fr = "LAT LON (DMS)    : %s.\n",
    en = "LAT LON (DMS)    : %s.\n",
  },
  ["cas.report_mgrs"] = {
    fr = "MGRS/UTM         : %s.\n",
    en = "MGRS/UTM         : %s.\n",
  },
  ["cas.report_bullseye"] = {
    fr = "DEPUIS BULLSEYE  : %s.\n",
    en = "FROM BULLSEYE    : %s.\n",
  },
  ["cas.report_bullseye_value"] = {
    fr = "%03d pour %d km /%d nm",
    en = "%03d for %dkm /%dnm",
  },
  ["cas.report_weather_header"] = {
    fr = "\n\nMÉTÉO :\n",
    en = "\n\nWEATHER:\n",
  },
  ["cas.help"] = {
    fr = "Créez un marqueur et tapez « _cas » dans le texte\n"
      .. "Cela crée un groupe cible CAS par défaut\n"
      .. "Vous pouvez ajouter des options (séparées par des virgules) :\n"
      .. "   « defense 0 » désactive complètement les défenses aériennes\n"
      .. "   « defense [1-5] » règle la couverture de défense aérienne (1 = légère, 5 = lourde)\n"
      .. "   « size [1-5] » change la taille du groupe (1 = petit, 5 = énorme)\n"
      .. "   « armor [1-5] » règle la présence de blindés (1 = légère, 5 = lourde)\n"
      .. "   « spacing [1-5] » change l'espacement des groupes (1 = dense, 3 = défaut, 5 = épars)",
    en = 'Create a marker and type "_cas" in the text\n'
      .. "This will create a default CAS target group\n"
      .. "You can add options (comma separated) :\n"
      .. '   "defense 0" completely disables air defenses\n'
      .. '   "defense [1-5]" specifies air defense cover (1 = light, 5 = heavy)\n'
      .. '   "size [1-5]" changes the group size (1 = small, 5 = huge)\n'
      .. '   "armor [1-5]" specifies armor presence (1 = light, 5 = heavy)\n'
      .. '   "spacing [1-5]" changes the groups spacing (1 = dense, 3 = default, 5 = sparse)',
  },

  -- veafWeather (report / ATIS). Standardized aeronautical abbreviations
  -- (CAVOK, QNH, QFE, kts, m/s, NM, SM, ft, Hpa, inHg, mmHg, °M/°T, AGL/ASL,
  -- FL, LASTE) stay identical in both languages; only descriptive words and
  -- line labels are translated. Label padding aligns the values visually.
  ["weather.wind_calm"] = {
    fr = "calme",
    en = "calm",
  },
  ["weather.vis_fog"] = {
    fr = " - brouillard",
    en = " - fog",
  },
  ["weather.vis_haze"] = {
    fr = " - brume sèche",
    en = " - haze",
  },
  ["weather.vis_mist"] = {
    fr = " - brume",
    en = " - mist",
  },
  ["weather.vis_dust"] = {
    fr = " - poussière",
    en = " - dust",
  },
  ["weather.vis_precipitations"] = {
    fr = " - précipitations",
    en = " - precipitations",
  },
  ["weather.clouds_none"] = {
    fr = "Pas de nuages",
    en = "No clouds",
  },
  ["weather.clouds_scattered"] = {
    fr = "Nuages épars",
    en = "Scattered clouds",
  },
  ["weather.clouds_broken"] = {
    fr = "Nuages fragmentés",
    en = "Broken clouds",
  },
  ["weather.clouds_overcast"] = {
    fr = "Ciel couvert",
    en = "Overcast clouds",
  },
  ["weather.clouds_few"] = {
    fr = "Quelques nuages",
    en = "Few clouds",
  },
  ["weather.line_wind"] = {
    fr = "Vent :         %s",
    en = "Wind:          %s",
  },
  ["weather.line_visibility"] = {
    fr = "\nVisibilité :   %s",
    en = "\nVisibility:    %s",
  },
  ["weather.line_clouds"] = {
    fr = "\nNuages :       %s",
    en = "\nClouds:        %s",
  },
  ["weather.line_temp_dew"] = {
    fr = "\nTempérature :   %s - Point de rosée : %s",
    en = "\nTemperature:   %s - Dew point: %s",
  },
  ["weather.line_qnh"] = {
    fr = "\nQNH :          %s",
    en = "\nQNH:           %s",
  },
  ["weather.line_qfe"] = {
    fr = "\nQFE :          %s",
    en = "\nQFE:           %s",
  },
  ["weather.line_sunrise"] = {
    fr = "\nLever :        %s",
    en = "\nSunrise:       %s",
  },
  ["weather.line_sunset"] = {
    fr = "\nCoucher :      %s",
    en = "\nSunset:       %s",
  },
  ["weather.line_time"] = {
    fr = "Heure :        %s",
    en = "Time:          %s",
  },
  ["weather.line_location"] = {
    fr = "\nPosition :     %s",
    en = "\nLocation:      %s",
  },
  ["weather.line_altitude"] = {
    fr = "\nAltitude :     %s",
    en = "\nAltitude:      %s",
  },
  ["weather.atis_wind"] = {
    fr = "Vent %s",
    en = "Wind %s",
  },
  ["weather.atis_cavok"] = {
    fr = "\nPlafond et visibilité OK, CAVOK",
    en = "\nCeiling and visiblity OK, CAVOK",
  },
  ["weather.atis_visibility"] = {
    fr = "\nVisibilité %s, %s",
    en = "\nVisibility %s, %s",
  },
  ["weather.atis_temp_dew"] = {
    fr = "\nTempérature %s, point de rosée %s",
    en = "\nTemperature %s, dew point %s",
  },
  ["weather.atis_qnh"] = {
    fr = "\nQNH %s",
    en = "\nQNH %s",
  },
  ["weather.atis_sunrise"] = {
    fr = "\nLever %s",
    en = "\nSunrise %s",
  },
  ["weather.atis_sunset"] = {
    fr = "\nCoucher %s",
    en = "\nSunset %s",
  },

  -- veafMove
  ["move.tanker_set_no_orbit"] = {
    fr = "Impossible de régler le ravitailleur %s : aucune tâche ORBIT définie",
    en = "Cannot set tanker %s parameters because it has no ORBIT task defined",
  },
  ["move.tanker_set_params"] = {
    fr = "Ravitailleur %s réglé à %d kn (sol) à %d ft",
    en = "Set tanker %s to %d kn (ground) at %d ft",
  },
  ["move.tanker_move_no_orbit"] = {
    fr = "Impossible de déplacer le ravitailleur %s : aucune tâche ORBIT définie",
    en = "Cannot move tanker %s because it has no ORBIT task defined",
  },
  ["move.help"] = {
    fr = "Créez un marqueur et tapez « _move <group|tanker|afac>, name <groupname> » dans le texte\n"
      .. "Cela envoie un ordre de déplacement au groupe spécifié dans DCS\n"
      .. "Tapez « _move group, name [groupname] » pour déplacer le groupe vers le point du marqueur\n"
      .. "     ajoutez « , speed [speed] » pour déplacer le groupe à la vitesse indiquée (en nœuds)\n"
      .. "Tapez « _move tanker, name [groupname] » pour créer un nouveau plan de vol ravitailleur et déplacer le ravitailleur.\n"
      .. "     ajoutez « , speed [speed] » pour déplacer le ravitailleur et exécuter sa mission de ravitaillement à la vitesse indiquée (en nœuds)\n"
      .. "     ajoutez « , alt [altitude] » pour préciser l'altitude de la branche de ravitaillement (en pieds)\n"
      .. "Tapez « _move afac, name [groupname] » pour créer un nouveau plan de vol JTAC et déplacer le drone AFAC.\n"
      .. "     ajoutez « , speed [speed] » pour déplacer le drone et exécuter sa mission à la vitesse indiquée (en nœuds)\n"
      .. "     ajoutez « , alt [altitude] » pour préciser l'altitude à laquelle le drone tournera (en pieds)",
    en = 'Create a marker and type "_move <group|tanker|afac>, name <groupname> " in the text\n'
      .. "This will issue a move command to the specified group in the DCS world\n"
      .. 'Type "_move group, name [groupname]" to move the specified group to the marker point\n'
      .. '     add ", speed [speed]" to make the group move and at the specified speed (in knots)\n'
      .. 'Type "_move tanker, name [groupname]" to create a new tanker flight plan and move the specified tanker.\n'
      .. '     add ", speed [speed]" to make the tanker move and execute its refuel mission at the specified speed (in knots)\n'
      .. '     add ", alt [altitude]" to specify the refuel leg altitude (in feet)\n'
      .. 'Type "_move afac, name [groupname]" to create a new JTAC flight plan and move the specified afac drone.\n'
      .. '     add ", speed [speed]" to make the tanker move and execute its mission at the specified speed (in knots)\n'
      .. '     add ", alt [altitude]" to specify the altitude at which the drone will circle (in feet)',
  },

  -- veafNamedPoints
  ["namedpoints.added"] = {
    fr = "VEAF - Point nommé %s ajouté pour sa propre coalition.",
    en = "VEAF - Point named %s added for own coalition.",
  },
  ["namedpoints.label"] = {
    fr = "VEAF - Point nommé %s",
    en = "VEAF - Point named %s",
  },

  -- veafSpawn (effects / ground / aircraft feedback)
  ["spawn.logistic_spawned"] = {
    fr = "Unité logistique %s apparue et ajoutée à CTLD.",
    en = "Logistic unit %s has been spawned and was added to CTLD.",
  },
  ["spawn.logistic_failed"] = {
    fr = "L'unité logistique n'a pas pu être créée",
    en = "Logistic unit could not be spawned",
  },
  ["spawn.cargo_spawned"] = {
    fr = "Cargo %s pesant %s kg apparu",
    en = "Cargo %s weighing %s kg has been spawned",
  },
  ["spawn.marked_smoke_flares"] = {
    fr = ". Il est marqué par une fumée verte et des fusées rouges",
    en = ". It's marked with green smoke and red flares",
  },
  ["spawn.static_spawned"] = {
    fr = "Statique %s apparu",
    en = "Static %s has been spawned",
  },
  ["spawn.drawing_not_found"] = {
    fr = "Impossible de trouver un dessin nommé %s",
    en = "Could not find a drawing named %s",
  },
  ["spawn.fob_built"] = {
    fr = "FOB %s terminée ! Caisses et troupes peuvent maintenant être récupérées.",
    en = "Finished building FOB %s! Crates and Troops can now be picked up.",
  },
  ["spawn.convoy_info"] = {
    fr = " - %s, %d véhicules : %s",
    en = " - %s, %d vehicles : %s",
  },
  ["spawn.convoy_stopped"] = {
    fr = ", à l'arrêt",
    en = ", stopped",
  },
  ["spawn.convoy_destroyed"] = {
    fr = " - %s a été détruit",
    en = " - %s has been destroyed",
  },
  ["spawn.afac_template_not_found"] = {
    fr = "Le modèle d'avion AFAC est introuvable pour « %s »",
    en = 'The AFAC aircraft template could not be found for "%s"',
  },
  ["spawn.afac_report"] = {
    fr = "AFAC %s/%s - %s (%s) - sur %sAM (DCS AFAC) ou %s%s (SRS)",
    en = "AFAC %s/%s - %s (%s) - on %sAM (DCS AFAC) or %s%s (SRS)",
  },
  ["spawn.afac_namepoint"] = {
    fr = "AFAC - %s - %sAM (DCS) ou %s%s (SRS)",
    en = "AFAC - %s - %sAM (DCS) or %s%s (SRS)",
  },
  ["spawn.cap_template_not_found"] = {
    fr = "Le modèle d'avion CAP est introuvable pour « %s »",
    en = 'The CAP aircraft template could not be found for "%s"',
  },
  ["spawn.cap_spawned"] = {
    fr = "Une CAP de %s (%s) est apparue",
    en = "A CAP of %s (%s) has been spawned",
  },

  -- veafQraManager (default status messages; %s = QRA description)
  ["qra.msg_start"] = {
    fr = "%s est en ligne",
    en = "%s is online",
  },
  ["qra.msg_deploy"] = {
    fr = "%s se déploie",
    en = "%s is deploying",
  },
  ["qra.msg_destroyed"] = {
    fr = "%s a été détruit",
    en = "%s has been destroyed",
  },
  ["qra.msg_ready"] = {
    fr = "%s est prêt",
    en = "%s is ready",
  },
  ["qra.msg_out"] = {
    fr = "%s n'a plus d'avions",
    en = "%s is out of aircrafts",
  },
  ["qra.msg_resupplied"] = {
    fr = "%s a été réapprovisionné",
    en = "%s has been resupplied",
  },
  ["qra.msg_airbase_down"] = {
    fr = "%s a perdu sa base aérienne",
    en = "%s lost it's airbase",
  },
  ["qra.msg_airbase_up"] = {
    fr = "%s dispose maintenant d'une base aérienne",
    en = "%s now has an airbase",
  },
  ["qra.msg_stop"] = {
    fr = "%s est hors ligne",
    en = "%s is offline",
  },

  -- veafAirWaves (default messages)
  ["airwaves.msg_start"] = {
    fr = "%s - en ligne",
    en = "%s - online",
  },
  ["airwaves.msg_wait_for_humans"] = {
    fr = "%s - attente de %s secondes pour plus de joueurs",
    en = "%s - waiting %s seconds for more players",
  },
  ["airwaves.msg_wait_to_deploy"] = {
    fr = "%s - attente de %s secondes avant la prochaine vague",
    en = "%s - waiting %s seconds before next wave",
  },
  ["airwaves.msg_deploy"] = {
    fr = "%s - déploiement de la vague %s",
    en = "%s - deploying wave %s",
  },
  ["airwaves.msg_deploy_players"] = {
    fr = "Vague %s en déploiement, %s",
    en = "Wave %s deploying, %s",
  },
  ["airwaves.msg_outside_of_zone"] = {
    fr = "%s - vous êtes hors de la zone depuis %s secondes ; revenez à l'intérieur, ou vous serez détruit après %s secondes.",
    en = "%s - you've been outside of the zone for %s seconds; go back inside, or you'll be destroyed after %s seconds.",
  },
  ["airwaves.msg_destroyed"] = {
    fr = "%s - la vague %s a été détruite",
    en = "%s - wave %s has been destroyed",
  },
  ["airwaves.msg_won"] = {
    fr = "%s - gagné (plus de vagues)",
    en = "%s - won (no more waves)",
  },
  ["airwaves.msg_lost"] = {
    fr = "%s - perdu (plus de joueurs)",
    en = "%s - lost (no more players)",
  },
  ["airwaves.msg_stop"] = {
    fr = "%s - hors ligne",
    en = "%s - offline",
  },

  -- veafSanctuary (default messages)
  ["sanctuary.msg_warning"] = {
    fr = "Attention, %s : vous êtes entré dans une zone sanctuaire et serez abattu dans %d secondes si vous ne partez pas IMMÉDIATEMENT",
    en = "Warning, %s : you've entered a sanctuary zone and will be shot in %d seconds if you don't leave IMMEDIATELY",
  },
  ["sanctuary.msg_spawn"] = {
    fr = "Vous avez été prévenu : déploiement des systèmes de défense",
    en = "You've been warned : deploying defense systems",
  },
  ["sanctuary.msg_shot_target"] = {
    fr = "Attention, %s : vous avez été attaqué par %s ; nous avons détruit le missile en vol !",
    en = "Warning, %s : you've been attacked by %s ; we destroyed the missile in the air !",
  },
  ["sanctuary.msg_shot_launcher"] = {
    fr = "Attention, %s : vous avez attaqué %s ; nous avons détruit le missile en vol. Ne recommencez pas ou nous vous détruirons !",
    en = "Warning, %s : you've attacked %s ; we destroyed the missile in the air. Don't do that again or we'll destroy you !",
  },
  ["sanctuary.critical_prefix"] = {
    fr = "CRITIQUE : %s - %s",
    en = "CRITICAL: %s - %s",
  },

  -- veafGroundAI (default messages)
  ["groundai.msg_stop"] = {
    fr = "L'unité terrestre %s a cessé d'exécuter et attend des ordres.",
    en = "Ground unit %s has stopped executing and awaiting orders.",
  },
  ["groundai.msg_start"] = {
    fr = "L'unité terrestre %s exécute ou attend des ordres.",
    en = "Ground unit %s is executing or awaiting orders.",
  },

  -- veafMissileGuardian
  ["mg.warning"] = {
    fr = "Attention, %s : vous avez été attaqué par %s et un missile est en vol",
    en = "Warning, %s : you've been attacked by %s and a missile is in the air",
  },

  -- Shared report fragments (combat zone/mission, transport). Coordinate labels
  -- keep their aeronautical form; only the descriptive words are translated.
  ["report.briefing_label"] = {
    fr = "BRIEFING : \n",
    en = "BRIEFING: \n",
  },
  ["report.count_ships"] = {
    fr = "%d navire(s)",
    en = "%d ship(s)",
  },
  ["report.count_structures"] = {
    fr = "%d structure(s)",
    en = "%d structure(s)",
  },
  ["report.count_vehicles"] = {
    fr = "%d véhicule(s)",
    en = "%d vehicle(s)",
  },
  ["report.count_soldiers"] = {
    fr = "%d soldat(s)",
    en = "%d soldier(s)",
  },
  ["report.latlon_decimal"] = {
    fr = "LAT LON (décimal): %s.\n",
    en = "LAT LON (decimal): %s.\n",
  },
  ["report.latlon_dms"] = {
    fr = "LAT LON (DMS)    : %s.\n",
    en = "LAT LON (DMS)    : %s.\n",
  },
  ["report.mgrs"] = {
    fr = "MGRS/UTM         : %s.\n",
    en = "MGRS/UTM         : %s.\n",
  },
  ["report.from_bullseye"] = {
    fr = "DEPUIS BULLSEYE  : %s.\n",
    en = "FROM BULLSEYE    : %s.\n",
  },
  ["report.bullseye_value"] = {
    fr = "%03d pour %d km /%d nm",
    en = "%03d for %dkm /%dnm",
  },
  ["report.weather_header"] = {
    fr = "\n\nMÉTÉO :\n",
    en = "\n\nWEATHER:\n",
  },

  -- veafCombatZone
  ["combatzone.complete"] = {
    fr = "\n    Bien joué ! Tous les ennemis de la zone %s ont été détruits ou mis en déroute."
      .. "\n    La zone va maintenant être désactivée."
      .. "\n    Vous pouvez rejouer en l'activant à nouveau, dans le menu radio.",
    en = "\n    Well done ! All enemies in zone %s have been destroyed or routed."
      .. "\n    The zone will now be desactivated."
      .. "\n    You can replay by activating it again, in the radio menu.",
  },
  ["combatzone.smoke_requested"] = {
    fr = "Bien reçu, fumée ROUGE demandée sur %s !",
    en = "Copy RED smoke requested on %s !",
  },
  ["combatzone.flare_requested"] = {
    fr = "Bien reçu, fusée éclairante demandée sur %s !",
    en = "Copy illumination flare requested on %s !",
  },
  ["combatzone.operation_complete"] = {
    fr = "L'opération %s est terminée. Félicitations !",
    en = "Operation %s is over. Congratulations !",
  },
  ["combatzone.zone_not_in_mission"] = {
    fr = "La zone trigger [%s] n'existe pas dans la mission !",
    en = "Trigger zone [%s] does not exist in the mission !",
  },
  ["combatzone.header"] = {
    fr = "ZONE DE COMBAT %s \n\n",
    en = "COMBAT ZONE %s \n\n",
  },
  ["combatzone.friends"] = {
    fr = "AMIS : %s restants.\n",
    en = "FRIENDS: %s remaining.\n",
  },
  ["combatzone.enemies"] = {
    fr = "ENNEMIS : %s restants.\n",
    en = "ENEMIES: %s remaining.\n",
  },
  ["combatzone.not_active"] = {
    fr = "la zone n'est pas encore active.",
    en = "zone is not yet active.",
  },
  ["combatzone.zone_not_found"] = {
    fr = "VeafCombatZone [%s] introuvable !",
    en = "VeafCombatZone [%s] was not found !",
  },
  ["combatzone.help"] = {
    fr = "Les zones de combat sont définies par le créateur de mission\n"
      .. "Vous pouvez les activer et les désactiver à volonté,\n"
      .. "ainsi que demander des informations, un laser JTAC et de la fumée. \n\n"
      .. "Les opérations de combat sont définies par le créateur de mission\n"
      .. "Une opération de combat est une série de zones de combat à terminer,\n"
      .. "Vous pouvez demander des informations pour le briefing et le renseignement des ordres en cours.",
    en = "Combat zones are defined by the mission maker\n"
      .. "You can activate and desactivate them at will,\n"
      .. "as well as ask for information, JTAC laser and smoke. \n\n"
      .. "Combat operations are defined by the mission maker\n"
      .. "A combat operation is a series of combat zones to complete,\n"
      .. "You can ask information to get briefing and intel for current tasking orders.",
  },

  -- veafCombatMission
  ["combatmission.enemies_count"] = {
    fr = "%d en vie (%d endommagés), %d morts",
    en = "%d alive (%d damaged), %d dead",
  },
  ["combatmission.header"] = {
    fr = "MISSION DE COMBAT %s \n\n",
    en = "COMBAT MISSION %s \n\n",
  },
  ["combatmission.objectives_label"] = {
    fr = "OBJECTIFS : \n",
    en = "OBJECTIVES: \n",
  },
  ["combatmission.enemies_label"] = {
    fr = "ENNEMIS : %s\n",
    en = "ENEMIES : %s\n",
  },
  ["combatmission.not_active"] = {
    fr = "la mission n'est pas encore active.",
    en = "mission is not yet active.",
  },
  ["combatmission.objective_failed"] = {
    fr = "\nObjectif non atteint : %s\nLa mission %s va maintenant se terminer.\nVous pouvez rejouer en la relançant, dans le menu radio.",
    en = "\nObjective not met : %s\nThe mission %s will now end.\nYou can replay by starting it again, in the radio menu.",
  },
  ["combatmission.mission_success"] = {
    fr = "\nTous les objectifs ont été atteints !\nLa mission %s est un succès ! Elle va maintenant se terminer.\nVous pouvez rejouer en la relançant, dans le menu radio.",
    en = "\nAll objectives were met !\nThe mission %s is a success ! It will now end.\nYou can replay by starting it again, in the radio menu.",
  },
  ["combatmission.mission_not_found"] = {
    fr = "VeafCombatMission [%s] introuvable !",
    en = "VeafCombatMission [%s] was not found !",
  },
  ["combatmission.help"] = {
    fr = "Les missions de combat sont définies par le créateur de mission, et listées ici\n"
      .. "Vous pouvez les démarrer et les arrêter à volonté,\n"
      .. "ainsi que demander des informations sur leur état.",
    en = "Combat missions are defined by the mission maker, and listed here\n"
      .. "You can start and stop them at will,\n"
      .. "as well as ask for information about their status.",
  },
  ["combatmission.list_available"] = {
    fr = "Liste de toutes les missions de combat disponibles :\n",
    en = "List of all available combat missions:\n",
  },
  ["combatmission.no_active"] = {
    fr = "Aucune mission de combat active !",
    en = "No active combat mission !",
  },
  ["combatmission.list_active"] = {
    fr = "Liste des missions de combat actives :\n",
    en = "List of active combat missions:\n",
  },
  ["combatmission.obj_kill_all_desc"] = {
    fr = "vous devez tuer tous les ennemis",
    en = "you must kill all of the ennemies",
  },
  ["combatmission.obj_kill_all_msg"] = {
    fr = "%d ennemis détruits !",
    en = "%d ennemies destroyed !",
  },

  -- veafCarrierOperations (ATC report; aeronautical codes kept verbatim)
  ["carrier.alignment_delay"] = {
    fr = "\n\nObtenir un bon alignement peut prendre jusqu'à 5 minutes",
    en = "\n\nGetting a good alignment may require up to 5 minutes",
  },
  ["carrier.obstruction"] = {
    fr = "Obstruction détectée au cap %s, déroutement de %s vers le cap %s",
    en = "Obstruction found at heading %s, derouting %s to heading %s",
  },
  ["carrier.atc_conducting"] = {
    fr = "Le groupe porte-avions %s mène des opérations aériennes :\n",
    en = "The carrier group %s is conducting air operations :\n",
  },
  ["carrier.atc_acls_available"] = {
    fr = "ACLS est disponible",
    en = "ACLS is available",
  },
  ["carrier.atc_brc"] = {
    fr = "\n  - BRC : %s (vrai) à %s kn\n  - Temps restant : %s minutes\n",
    en = "\n  - BRC : %s (true) at %s kn\n  - Remaining time : %s minutes\n",
  },
  ["carrier.atc_tanker"] = {
    fr = "\n  - Ravitailleur %s : TACAN %s%s, COMM %s\n",
    en = "\n  - Tanker %s : TACAN %s%s, COMM %s\n",
  },
  ["carrier.atc_not_conducting"] = {
    fr = "Le groupe porte-avions %s ne mène pas d'opérations aériennes\n",
    en = "The carrier group %s is not conducting carrier air operations\n",
  },
  ["carrier.atc_navigation"] = {
    fr = "\nParamètres de navigation actuels :\n  - Cap actuel (vrai) %s\n  - Vitesse actuelle %s kn\n",
    en = "\nCurrent navigation parameters :\n  - Current heading (true) %s\n  - Current speed %s kn\n",
  },
  ["carrier.atc_weather_header"] = {
    fr = "\nMÉTÉO :\n",
    en = "\nWEATHER:\n",
  },
  ["carrier.available_list"] = {
    fr = "Porte-avions disponibles :\n",
    en = "Available carriers :\n",
  },

  -- veafTransportMission
  ["transport.see_f10"] = {
    fr = "Voir le menu radio F10 pour les détails\n",
    en = "See F10 radio menu for details\n",
  },
  ["transport.dropzone_too_close"] = {
    fr = "Cette zone de largage est trop proche ; placez-la à au moins %s km du point %s !",
    en = "This drop zone is too close ; you have to place it at least %s km away from point %s !",
  },
  ["transport.report_dropzone"] = {
    fr = "ZONE DE LARGAGE : ravitailler un groupe de %d véhicules et %d soldats.\n",
    en = "DROP ZONE : ressuply a group of %d vehicles and %d soldiers.\n",
  },
  ["transport.report_navigation"] = {
    fr = "NAVIGATION : ils émettront sur 550 kHz toutes les %s secondes.\n",
    en = "NAVIGATION: They will transmit on 550 kHz every %s seconds.\n",
  },
  ["transport.report_alt"] = {
    fr = "ALT ZONE LARGAGE    : %s mètres.\n",
    en = "DROP ZONE ALT       : %s meters.\n",
  },
  ["transport.wind_none"] = {
    fr = "pas de vent.\n",
    en = "no wind.\n",
  },
  ["transport.wind_from"] = {
    fr = "de %s à %s m/s.\n",
    en = "from %s at %s m/s.\n",
  },
  ["transport.report_wind"] = {
    fr = "VENT SUR ZONE LARGAGE : %s",
    en = "WIND OVER DROP ZONE : %s",
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
  ["transport.help"] = {
    fr = 'Créez un marqueur et tapez "_transport" dans le texte\n'
      .. "Cela créera un groupe ami par défaut attendant une cargaison à transporter\n"
      .. "Vous pouvez ajouter des options (séparées par des virgules) :\n"
      .. '   "defense [0-5]" pour préciser la couverture de défense aérienne en route (1 = légère, 5 = lourde)\n'
      .. "        defense = 1 : 3-7 soldats, transport GAZ-3308\n"
      .. "        defense = 2 : 3-7 soldats, APC BTR-80\n"
      .. "        defense = 3 : 3-7 soldats, possibilité d'IFV BMP-1, possibilité de manpad Igla\n"
      .. "        defense = 4 : 3-7 soldats, forte chance d'IFV BMP-1, forte chance de manpad Igla-S, possibilité de ZU-23 sur camion\n"
      .. "        defense = 5 : 3-7 soldats, IFV BMP-1, forte chance de manpad Igla-S, possibilité de ZSU-23-4 Shilka\n"
      .. '   "size [1-5]" pour changer le nombre de cargaisons à transporter (1 par hélico participant, en général)\n'
      .. '   "blocade [0-5]" pour préciser le blocus ennemi autour de la zone de largage (1 = léger, 5 = lourd)',
    en = 'Create a marker and type "_transport" in the text\n'
      .. "This will create a default friendly group awaiting cargo that you need to transport\n"
      .. "You can add options (comma separated) :\n"
      .. '   "defense [0-5]" to specify air defense cover on the way (1 = light, 5 = heavy)\n'
      .. "        defense = 1 : 3-7 soldiers, GAZ-3308 transport\n"
      .. "        defense = 2 : 3-7 soldiers, BTR-80 APC\n"
      .. "        defense = 3 : 3-7 soldiers, chance of BMP-1 IFV, chance of Igla manpad\n"
      .. "        defense = 4 : 3-7 soldiers, big chance of BMP-1 IFV, big chance of Igla-S manpad, chance of ZU-23 on a truck\n"
      .. "        defense = 5 : 3-7 soldiers, BMP-1 IFV, big chance of Igla-S manpad, chance of ZSU-23-4 Shilka\n"
      .. '   "size [1-5]" to change the number of cargo items to be transported (1 per participating helo, usually)\n'
      .. '   "blocade [0-5]" to specify enemy blocade around the drop zone (1 = light, 5 = heavy)',
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
    en = "%s cannot fire for effect, no target coordinates provided and no previous target exists",
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

  -- veafAssist — guided checklists. Short event texts; the persistent checklist
  -- itself is the generated picture, not a message.
  ["assist.started"] = {
    fr = "Assistance : %s",
    en = "Assistance: %s",
  },
  ["assist.step_validated"] = {
    fr = "Fait : %s",
    en = "Done: %s",
  },
  ["assist.step_skipped"] = {
    fr = "Étape passée : %s",
    en = "Step skipped: %s",
  },
  ["assist.completed"] = {
    fr = "Terminé : %s",
    en = "Complete: %s",
  },

  -- veafAssist — radio menu. "assist.menu.<slot>" labels a checklist's `menu` slot; an
  -- unknown slot resolves to itself, so a mission maker's own checklist still reads.
  ["assist.menu.root"] = {
    fr = "Assistance",
    en = "Assistance",
  },
  ["assist.menu.cold-start"] = {
    fr = "Démarrage à froid",
    en = "Cold start",
  },
  ["assist.menu.confirm"] = {
    fr = "Valider cette étape",
    en = "Confirm this step",
  },
  ["assist.menu.skip"] = {
    fr = "Passer cette étape",
    en = "Skip this step",
  },
  ["assist.menu.toggle_picture"] = {
    fr = "Masquer / afficher la checklist",
    en = "Hide / show the checklist",
  },
  ["assist.menu.stop"] = {
    fr = "Arrêter l'assistance",
    en = "Stop the assistance",
  },

  -- veafAssist — guided checklists.
  -- The F-16C wording follows ED's own autostart sequence (Macro_sequencies.lua); the
  -- cockpit labels stay in English because that is what is written in the cockpit.
  ["assist.f16c.coldstart.title"] = {
    fr = "F-16C — démarrage moteur",
    en = "F-16C — engine start",
  },
  ["assist.f16c.main_pwr_batt"] = {
    fr = "MAIN PWR sur BATT",
    en = "MAIN PWR switch to BATT",
  },
  ["assist.f16c.main_pwr_on"] = {
    fr = "MAIN PWR sur MAIN PWR",
    en = "MAIN PWR switch to MAIN PWR",
  },
  ["assist.f16c.jfs_start2"] = {
    fr = "JFS sur START 2",
    en = "JFS switch to START 2",
  },
  ["assist.f16c.jfs_run_light"] = {
    fr = "Voyant JFS RUN allumé — vérifier",
    en = "JFS RUN light on — check",
  },
  ["assist.f16c.throttle_idle"] = {
    fr = "Manette sur IDLE (20 % RPM minimum)",
    en = "Throttle to IDLE (20% RPM minimum)",
  },
  ["assist.f16c.engine_idle"] = {
    fr = "Moteur au ralenti — vérifier",
    en = "Engine at idle — check",
  },
}

veaf.loggers.get(veafI18n.Id):info(veaf.loggers.get(veafI18n.Id):getVersionInfo())
