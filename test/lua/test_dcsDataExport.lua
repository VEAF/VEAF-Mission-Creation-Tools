--- Unit tests for dcsDataExport.lua
---
--- Run:  lua test/lua/test_dcsDataExport.lua
---
--- Covers:
---   - DcsDataExport.Logger.LEVEL constants
---   - DcsDataExport.Logger.splitText       (split long text into chunks ≤ 4000 chars)
---   - DcsDataExport.Logger level filtering  (only log at or above configured level)
---   - DcsDataExport.basicSerialize          (Lua literal serialisation of primitives)
---   - DcsDataExport.serialize               (recursive table/value serialisation)

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")

-- ---------------------------------------------------------------------------
-- Shim: satisfy the module-level file-writing code that runs when the file is
-- loaded.  dcsDataExport.lua writes unit data to disk at load time; we replace
-- io.open with a no-op and supply the empty database tables it iterates.
-- ---------------------------------------------------------------------------
local _origIoOpen = io.open
local _fakeFile = { write = function() end, close = function() end }
io.open = function()
  return _fakeFile
end

db = {
  Units = {
    Animals = { Animal = {} },
    Cargos = { Cargo = {} },
    Cars = { Car = {} },
    Effects = { Effect = {} },
    Fortifications = { Fortification = {} },
    GrassAirfields = { GrassAirfield = {} },
    GroundObjects = { GroundObject = {} },
    Helicopters = { Helicopter = {} },
    Heliports = { Heliport = {} },
    Personnel = { Personnel = {} },
    Planes = { Plane = {} },
    Ships = { Ship = {} },
    Warehouses = { Warehouse = {} },
  },
}
-- log.error is referenced inside DcsDataExport.serialize's error fallback
log = { error = function() end }

local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/dcsDataExport.lua")

io.open = _origIoOpen -- restore standard io.open

-- ============================================================================
-- TestDcsDataExportLoggerLevel
-- ============================================================================
TestDcsDataExportLoggerLevel = {}

function TestDcsDataExportLoggerLevel:test_error_level_is_1()
  luaunit.assertEquals(DcsDataExport.Logger.LEVEL["error"], 1)
end

function TestDcsDataExportLoggerLevel:test_warning_level_is_2()
  luaunit.assertEquals(DcsDataExport.Logger.LEVEL["warning"], 2)
end

function TestDcsDataExportLoggerLevel:test_info_level_is_3()
  luaunit.assertEquals(DcsDataExport.Logger.LEVEL["info"], 3)
end

function TestDcsDataExportLoggerLevel:test_debug_level_is_4()
  luaunit.assertEquals(DcsDataExport.Logger.LEVEL["debug"], 4)
end

function TestDcsDataExportLoggerLevel:test_trace_level_is_5()
  luaunit.assertEquals(DcsDataExport.Logger.LEVEL["trace"], 5)
end

-- Logger instance: level filtering via setLevel
function TestDcsDataExportLoggerLevel:test_level_string_info_accepted()
  local logger = DcsDataExport.Logger:new("TEST", "info")
  luaunit.assertEquals(logger:getLevel(), DcsDataExport.Logger.LEVEL["info"])
end

function TestDcsDataExportLoggerLevel:test_numeric_level_accepted()
  local logger = DcsDataExport.Logger:new("TEST", 5)
  luaunit.assertEquals(logger:getLevel(), 5)
end

function TestDcsDataExportLoggerLevel:test_unknown_string_level_defaults_to_info()
  local logger = DcsDataExport.Logger:new("TEST", "banana")
  luaunit.assertEquals(logger:getLevel(), DcsDataExport.Logger.LEVEL["info"])
end

function TestDcsDataExportLoggerLevel:test_name_stored_as_is()
  -- Logger:new stores the name verbatim; uppercasing is done by loggers.new
  local logger = DcsDataExport.Logger:new("mymod", "info")
  luaunit.assertEquals(logger:getName(), "mymod")
end

function TestDcsDataExportLoggerLevel:test_loggers_new_uppercases_name()
  local logger = DcsDataExport.loggers.new("testmod", "info")
  luaunit.assertEquals(logger:getName(), "TESTMOD")
end

-- ============================================================================
-- TestDcsDataExportSplitText
-- ============================================================================
TestDcsDataExportSplitText = {}

function TestDcsDataExportSplitText:test_short_text_is_single_element()
  local result = DcsDataExport.Logger.splitText("hello")
  luaunit.assertEquals(#result, 1)
  luaunit.assertEquals(result[1], "hello")
end

function TestDcsDataExportSplitText:test_empty_string_is_single_element()
  local result = DcsDataExport.Logger.splitText("")
  luaunit.assertEquals(#result, 1)
  luaunit.assertEquals(result[1], "")
end

function TestDcsDataExportSplitText:test_exactly_4000_chars_is_single_element()
  local text = string.rep("a", 4000)
  local result = DcsDataExport.Logger.splitText(text)
  luaunit.assertEquals(#result, 1)
end

function TestDcsDataExportSplitText:test_4001_chars_splits_into_two()
  local text = string.rep("x", 4001)
  local result = DcsDataExport.Logger.splitText(text)
  luaunit.assertEquals(#result, 2)
  luaunit.assertEquals(#result[1], 4000)
  luaunit.assertEquals(#result[2], 1)
end

function TestDcsDataExportSplitText:test_8001_chars_splits_into_three()
  local text = string.rep("y", 8001)
  local result = DcsDataExport.Logger.splitText(text)
  luaunit.assertEquals(#result, 3)
  luaunit.assertEquals(#result[1], 4000)
  luaunit.assertEquals(#result[2], 4000)
  luaunit.assertEquals(#result[3], 1)
end

function TestDcsDataExportSplitText:test_content_is_preserved()
  local text = "hello\nworld"
  local result = DcsDataExport.Logger.splitText(text)
  luaunit.assertEquals(result[1], text)
end

-- ============================================================================
-- TestDcsDataExportBasicSerialize
-- ============================================================================
TestDcsDataExportBasicSerialize = {}

function TestDcsDataExportBasicSerialize:test_nil_returns_empty_quoted_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(nil), '""')
end

function TestDcsDataExportBasicSerialize:test_integer_returns_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(42), "42")
end

function TestDcsDataExportBasicSerialize:test_float_returns_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(3.14), "3.14")
end

function TestDcsDataExportBasicSerialize:test_zero_returns_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(0), "0")
end

function TestDcsDataExportBasicSerialize:test_true_returns_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(true), "true")
end

function TestDcsDataExportBasicSerialize:test_false_returns_string()
  luaunit.assertEquals(DcsDataExport.basicSerialize(false), "false")
end

function TestDcsDataExportBasicSerialize:test_simple_string_is_quoted()
  -- Lua's %q wraps in double quotes
  luaunit.assertEquals(DcsDataExport.basicSerialize("hello"), '"hello"')
end

function TestDcsDataExportBasicSerialize:test_string_with_quotes_is_escaped()
  local result = DcsDataExport.basicSerialize('say "hi"')
  luaunit.assertStrContains(result, '\\"')
end

-- ============================================================================
-- TestDcsDataExportSerialize
-- ============================================================================
TestDcsDataExportSerialize = {}

function TestDcsDataExportSerialize:test_number_produces_assignment()
  local result = DcsDataExport.serialize("myVar", 42, "")
  luaunit.assertStrContains(result, "myVar")
  luaunit.assertStrContains(result, "42")
end

function TestDcsDataExportSerialize:test_boolean_produces_assignment()
  local result = DcsDataExport.serialize("flag", true, "")
  luaunit.assertStrContains(result, "flag")
  luaunit.assertStrContains(result, "true")
end

function TestDcsDataExportSerialize:test_string_produces_quoted_assignment()
  local result = DcsDataExport.serialize("name", "Alice", "")
  luaunit.assertStrContains(result, "name")
  luaunit.assertStrContains(result, '"Alice"')
end

function TestDcsDataExportSerialize:test_empty_table_produces_braces()
  local result = DcsDataExport.serialize("data", {}, "")
  luaunit.assertStrContains(result, "data")
  luaunit.assertStrContains(result, "{")
  luaunit.assertStrContains(result, "}")
end

function TestDcsDataExportSerialize:test_nested_table_contains_key()
  local result = DcsDataExport.serialize("obj", { x = 1 }, "")
  luaunit.assertStrContains(result, "obj")
  luaunit.assertStrContains(result, "x")
  luaunit.assertStrContains(result, "1")
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
