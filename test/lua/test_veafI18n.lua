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

os.exit(luaunit.LuaUnit.run())
