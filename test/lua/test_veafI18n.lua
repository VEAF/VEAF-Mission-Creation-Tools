--- Tests for the Lua runtime i18n layer (LUA-I18N): veaf.t + veafI18n catalog.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")

-- ---------------------------------------------------------------------------
-- TestVeafI18n
-- ---------------------------------------------------------------------------
TestVeafI18n = {}

function TestVeafI18n:setUp()
  -- restore the default language before each test
  veaf.config.language = veaf.I18N_DEFAULT_LANGUAGE
end

function TestVeafI18n:test_default_language_is_fr()
  luaunit.assertEquals(veaf.I18N_DEFAULT_LANGUAGE, "fr")
  luaunit.assertEquals(veaf.config.language, "fr")
end

function TestVeafI18n:test_returns_french_by_default()
  luaunit.assertEquals(
    veaf.t("marker.command_failed"),
    "VEAF : votre commande de marqueur a échoué (voir le log DCS pour les détails)."
  )
end

function TestVeafI18n:test_returns_english_when_selected()
  veaf.config.language = "en"
  luaunit.assertEquals(
    veaf.t("marker.command_failed"),
    "VEAF: your marker command failed (see the DCS log for details)."
  )
end

function TestVeafI18n:test_unknown_key_returns_the_key()
  luaunit.assertEquals(veaf.t("no.such.key"), "no.such.key")
end

function TestVeafI18n:test_unknown_language_falls_back_to_french()
  veaf.config.language = "de" -- not in the catalog -> fall back to fr
  luaunit.assertEquals(veaf.t("spawn.did_you_mean", "heading"), " (vouliez-vous dire « heading » ?)")
end

function TestVeafI18n:test_format_interpolation()
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("spawn.unknown_parameters", "'wibble'"), "VEAF spawn: unknown parameter(s): 'wibble'")
end

function TestVeafI18n:test_did_you_mean_french()
  luaunit.assertEquals(veaf.t("spawn.did_you_mean", "heading"), " (vouliez-vous dire « heading » ?)")
end

function TestVeafI18n:test_missing_key_with_args_does_not_crash()
  -- a missing entry returns the key; format args are applied if the key has a
  -- placeholder, otherwise the key is returned unchanged (no error).
  luaunit.assertEquals(veaf.t("totally.unknown", "x"), "totally.unknown")
end

function TestVeafI18n:test_format_mismatch_returns_raw_without_crashing()
  -- a placeholder/argument mismatch must not crash: keep the raw text (and log).
  veaf.i18nCatalog["test.fmt"] = { fr = "count: %d" }
  local result = veaf.t("test.fmt", "not-a-number")
  veaf.i18nCatalog["test.fmt"] = nil
  luaunit.assertEquals(result, "count: %d")
end

-- ---------------------------------------------------------------------------
-- LUA-I18N-CAS: veafCasMission on-screen messages
-- ---------------------------------------------------------------------------

function TestVeafI18n:test_cas_spawn_confirmation_french()
  luaunit.assertEquals(
    veaf.t("cas.spawn_confirmation", 4, 6),
    "CIBLE : groupe de 4 véhicules et 6 fantassins. Voir le menu radio F10 pour les détails\n"
  )
end

function TestVeafI18n:test_cas_spawn_confirmation_english()
  veaf.config.language = "en"
  luaunit.assertEquals(
    veaf.t("cas.spawn_confirmation", 4, 6),
    "TARGET: Group of 4 vehicles and 6 soldiers. See F10 radio menu for details\n"
  )
end

function TestVeafI18n:test_cas_report_target_interpolates_both_languages()
  luaunit.assertEquals(veaf.t("cas.report_target", 2, 3), "CIBLE : groupe de 2 véhicules et 3 fantassins.\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("cas.report_target", 2, 3), "TARGET: Group of 2 vehicles and 3 soldiers.\n")
end

function TestVeafI18n:test_cas_report_afac()
  luaunit.assertEquals(veaf.t("cas.report_afac", "Texaco"), "AFAC en station : Texaco\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("cas.report_afac", "Texaco"), "AFAC on station: Texaco\n")
end

function TestVeafI18n:test_cas_report_bullseye_value_formats_heading_and_distances()
  -- %03d heading padding and the metric/imperial distances are interpolated.
  luaunit.assertEquals(veaf.t("cas.report_bullseye_value", 45, 12, 7), "045 pour 12 km /7 nm")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("cas.report_bullseye_value", 45, 12, 7), "045 for 12km /7nm")
end

function TestVeafI18n:test_cas_report_geo_labels_are_localized()
  luaunit.assertEquals(veaf.t("cas.report_mgrs", "37T 12345 67890"), "MGRS/UTM         : 37T 12345 67890.\n")
  luaunit.assertEquals(veaf.t("cas.report_bullseye", "045 pour 12 km /7 nm"), "DEPUIS BULLSEYE  : 045 pour 12 km /7 nm.\n")
end

function TestVeafI18n:test_cas_report_weather_header()
  luaunit.assertEquals(veaf.t("cas.report_weather_header"), "\n\nMÉTÉO :\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("cas.report_weather_header"), "\n\nWEATHER:\n")
end

function TestVeafI18n:test_cas_help_is_localized_and_keeps_command_tokens()
  local fr = veaf.t("cas.help")
  luaunit.assertStrContains(fr, "Créez un marqueur")
  -- command tokens must stay literal in both languages
  luaunit.assertStrContains(fr, "_cas")
  luaunit.assertStrContains(fr, "defense [1-5]")
  veaf.config.language = "en"
  local en = veaf.t("cas.help")
  luaunit.assertStrContains(en, "Create a marker")
  luaunit.assertStrContains(en, "_cas")
  luaunit.assertStrContains(en, "spacing [1-5]")
end

-- ---------------------------------------------------------------------------
-- LUA-I18N-WEATHER: veafWeatherData report / ATIS
-- Aeronautical abbreviations stay identical in both languages; only
-- descriptive words and line labels are translated.
-- ---------------------------------------------------------------------------

function TestVeafI18n:test_weather_calm_is_localized()
  luaunit.assertEquals(veaf.t("weather.wind_calm"), "calme")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("weather.wind_calm"), "calm")
end

function TestVeafI18n:test_weather_cloud_densities_french()
  luaunit.assertEquals(veaf.t("weather.clouds_none"), "Pas de nuages")
  luaunit.assertEquals(veaf.t("weather.clouds_scattered"), "Nuages épars")
  luaunit.assertEquals(veaf.t("weather.clouds_broken"), "Nuages fragmentés")
  luaunit.assertEquals(veaf.t("weather.clouds_overcast"), "Ciel couvert")
  luaunit.assertEquals(veaf.t("weather.clouds_few"), "Quelques nuages")
end

function TestVeafI18n:test_weather_visibility_affects_french()
  luaunit.assertEquals(veaf.t("weather.vis_fog"), " - brouillard")
  luaunit.assertEquals(veaf.t("weather.vis_haze"), " - brume sèche")
  luaunit.assertEquals(veaf.t("weather.vis_mist"), " - brume")
  luaunit.assertEquals(veaf.t("weather.vis_dust"), " - poussière")
  luaunit.assertEquals(veaf.t("weather.vis_precipitations"), " - précipitations")
end

function TestVeafI18n:test_weather_report_labels_interpolate_french()
  luaunit.assertEquals(veaf.t("weather.line_wind", "calme"), "Vent :         calme")
  luaunit.assertEquals(veaf.t("weather.line_temp_dew", "15°C", "8°C"), "\nTempérature :   15°C - Point de rosée : 8°C")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("weather.line_wind", "calm"), "Wind:          calm")
  luaunit.assertEquals(veaf.t("weather.line_temp_dew", "15°C", "8°C"), "\nTemperature:   15°C - Dew point: 8°C")
end

function TestVeafI18n:test_weather_atis_phraseology()
  luaunit.assertEquals(veaf.t("weather.atis_cavok"), "\nPlafond et visibilité OK, CAVOK")
  luaunit.assertEquals(veaf.t("weather.atis_sunrise", "06:12Z"), "\nLever 06:12Z")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("weather.atis_cavok"), "\nCeiling and visiblity OK, CAVOK")
  luaunit.assertEquals(veaf.t("weather.atis_sunrise", "06:12Z"), "\nSunrise 06:12Z")
end

function TestVeafI18n:test_weather_qnh_label_keeps_abbreviation_both_languages()
  -- QNH is a standardized aeronautical abbreviation: it stays in both languages,
  -- only the FR colon spacing/alignment differs.
  luaunit.assertEquals(veaf.t("weather.line_qnh", "1013Hpa"), "\nQNH :          1013Hpa")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("weather.line_qnh", "1013Hpa"), "\nQNH:           1013Hpa")
end

-- ---------------------------------------------------------------------------
-- LUA-I18N-SWEEP: remaining VEAF module messages
-- ---------------------------------------------------------------------------

function TestVeafI18n:test_sweep_spawn_messages()
  luaunit.assertEquals(veaf.t("spawn.cargo_spawned", "Box", 200), "Cargo Box pesant 200 kg apparu")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("spawn.cargo_spawned", "Box", 200), "Cargo Box weighing 200 kg has been spawned")
end

function TestVeafI18n:test_sweep_move_help_keeps_command_tokens()
  local fr = veaf.t("move.help")
  luaunit.assertStrContains(fr, "_move")
  luaunit.assertStrContains(fr, "name [groupname]")
end

function TestVeafI18n:test_sweep_namedpoints_label()
  luaunit.assertEquals(veaf.t("namedpoints.label", "ALPHA"), "VEAF - Point nommé ALPHA")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("namedpoints.label", "ALPHA"), "VEAF - Point named ALPHA")
end

function TestVeafI18n:test_sweep_template_defaults_resolve_as_keys()
  -- QRA / AirWaves / Sanctuary / GroundAI / MG default messages are catalog keys
  luaunit.assertEquals(veaf.t("qra.msg_start", "Batumi QRA"), "Batumi QRA est en ligne")
  luaunit.assertEquals(veaf.t("airwaves.msg_won", "Wave"), "Wave - gagné (plus de vagues)")
  luaunit.assertEquals(veaf.t("groundai.msg_start", "Convoy"), "L'unité terrestre Convoy exécute ou attend des ordres.")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("qra.msg_start", "Batumi QRA"), "Batumi QRA is online")
  luaunit.assertEquals(veaf.t("mg.warning", "Colt", "Viper"), "Warning, Colt : you've been attacked by Viper and a missile is in the air")
end

function TestVeafI18n:test_sweep_unknown_key_passes_through_for_custom_overrides()
  -- a mission overriding a default message with its own literal must keep it
  -- verbatim (veaf.t returns an unknown key unchanged, then formats it).
  luaunit.assertEquals(veaf.t("My custom %s message", "QRA"), "My custom QRA message")
end

function TestVeafI18n:test_sweep_shared_report_fragments()
  luaunit.assertEquals(veaf.t("report.count_vehicles", 3), "3 véhicule(s)")
  luaunit.assertEquals(veaf.t("report.mgrs", "37T 1 2"), "MGRS/UTM         : 37T 1 2.\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("report.count_vehicles", 3), "3 vehicle(s)")
end

function TestVeafI18n:test_sweep_combat_headers()
  luaunit.assertEquals(veaf.t("combatzone.header", "Alpha"), "ZONE DE COMBAT Alpha \n\n")
  luaunit.assertEquals(veaf.t("combatmission.not_active"), "la mission n'est pas encore active.")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("combatzone.header", "Alpha"), "COMBAT ZONE Alpha \n\n")
end

function TestVeafI18n:test_sweep_carrier_keeps_aero_codes()
  -- aeronautical codes (BRC, TACAN, COMM, kn) stay; only words are translated
  luaunit.assertEquals(veaf.t("carrier.atc_tanker", "Texaco", "51", "X", "127.5"), "\n  - Ravitailleur Texaco : TACAN 51X, COMM 127.5\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("carrier.atc_tanker", "Texaco", "51", "X", "127.5"), "\n  - Tanker Texaco : TACAN 51X, COMM 127.5\n")
end

function TestVeafI18n:test_sweep_transport_report()
  luaunit.assertEquals(veaf.t("transport.report_dropzone", 2, 5), "ZONE DE LARGAGE : ravitailler un groupe de 2 véhicules et 5 soldats.\n")
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t("transport.report_dropzone", 2, 5), "DROP ZONE : ressuply a group of 2 vehicles and 5 soldiers.\n")
end

os.exit(luaunit.LuaUnit.run())
