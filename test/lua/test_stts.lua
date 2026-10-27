--- DCS-SimpleTextToSpeech builds a Windows command line and hands it to os.execute
--- (FEAT-BFR-V6-SUPPORT ticket 02).
---
--- A JTAC placed from a marker carries the frequency a player typed, so `freqs`, `modulations` and
--- `name` reach the shell. They are validated (frequencies, modulations) or stripped (names, text)
--- before the command is built; a value that is not what it claims to be means nothing runs.
---
--- Run:  lua test/lua/test_stts.lua

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/community/DCS-SimpleTextToSpeech.lua")

TestStts = {}

function TestStts:setUp()
  dcs_mocks.reset()
  self.commands = {}
  STTS.DIRECTORY = "C:\\SRS"
  STTS.SRS_PORT = 5002
  STTS.configuredAndInstalled = true
  STTS.os = {
    execute = function(cmd)
      table.insert(self.commands, cmd)
    end,
    getenv = function()
      return "C:\\Temp"
    end,
    remove = function() end,
  }
  STTS.io = {
    open = function()
      return { write = function() end, close = function() end }
    end,
  }
end

function TestStts:test_a_plain_transmission_runs()
  STTS.TextToSpeech("Hello", "251,30.5", "AM,FM", "1.0", "JTAC 1", 2)
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertStrContains(self.commands[1], "-f 251,30.5 -m AM,FM -c 2")
  luaunit.assertStrContains(self.commands[1], '-n "JTAC 1"')
end

function TestStts:test_numbers_are_accepted_as_well_as_strings()
  STTS.TextToSpeech("Hello", 251, "am", 1.0, "SRS", 2)
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertStrContains(self.commands[1], "-f 251 -m am")
end

function TestStts:test_a_frequency_that_is_not_a_number_runs_nothing()
  STTS.TextToSpeech("Hello", "251 & calc", "AM", "1.0", "SRS", 2)
  luaunit.assertEquals(#self.commands, 0)
end

function TestStts:test_a_modulation_that_is_not_am_or_fm_runs_nothing()
  STTS.TextToSpeech("Hello", "251", "AM|calc", "1.0", "SRS", 2)
  luaunit.assertEquals(#self.commands, 0)
end

function TestStts:test_a_coalition_or_volume_that_is_not_a_number_runs_nothing()
  STTS.TextToSpeech("Hello", "251", "AM", "1.0", "SRS", "2 & calc")
  STTS.TextToSpeech("Hello", "251", "AM", "1.0 & calc", "SRS", 2)
  luaunit.assertEquals(#self.commands, 0)
end

function TestStts:test_shell_characters_are_stripped_from_the_name_and_the_message()
  STTS.TextToSpeech('Say "hi" & calc', "251", "AM", "1.0", 'x" & calc & "', 2)
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertNil(self.commands[1]:find("&", 1, true))
  luaunit.assertStrContains(self.commands[1], '-n "x    calc    "')
end

function TestStts:test_playmp3_is_validated_too()
  STTS.PlayMP3("C:\\music.mp3", "251 & calc", "AM", "1.0", "SRS", 2)
  luaunit.assertEquals(#self.commands, 0)
  STTS.PlayMP3("C:\\music.mp3", "251", "AM", "1.0", "SRS", 2)
  luaunit.assertEquals(#self.commands, 1)
end

os.exit(luaunit.LuaUnit.run())
