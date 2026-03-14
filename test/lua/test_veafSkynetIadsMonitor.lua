--- Tests for veafSkynetIadsMonitor.lua — pure string utility methods.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSkynetIadsHelper.lua")
dofile(src .. "/veafSkynetIadsMonitor.lua")

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorConstants
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorConstants = {}

function TestVeafSkynetMonitorConstants:test_id()
  luaunit.assertIsString(veafSkynetMonitor.Id)
end

function TestVeafSkynetMonitorConstants:test_version()
  luaunit.assertIsString(veafSkynetMonitor.Version)
end

function TestVeafSkynetMonitorConstants:test_interval_is_number()
  luaunit.assertIsNumber(veafSkynetMonitor._interval)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorCreate
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorCreate = {}

function TestVeafSkynetMonitorDescriptorCreate:test_create_returns_table()
  local d = VeafSkynetMonitorDescriptor:Create(nil, nil)
  luaunit.assertIsTable(d)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorAppendString
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorAppendString = {}

function TestVeafSkynetMonitorDescriptorAppendString:test_nil_base_returns_appended()
  local r = VeafSkynetMonitorDescriptor:AppendString(nil, "hello")
  luaunit.assertEquals(r, "hello")
end

function TestVeafSkynetMonitorDescriptorAppendString:test_empty_base_returns_appended()
  local r = VeafSkynetMonitorDescriptor:AppendString("", "hello")
  luaunit.assertNotNil(r)
end

function TestVeafSkynetMonitorDescriptorAppendString:test_both_defined_joins_with_separator()
  local r = VeafSkynetMonitorDescriptor:AppendString("hello", "world")
  luaunit.assertEquals(r, "hello | world")
end

function TestVeafSkynetMonitorDescriptorAppendString:test_nil_append_returns_base()
  local r = VeafSkynetMonitorDescriptor:AppendString("hello", nil)
  luaunit.assertEquals(r, "hello")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorGetIndentationString
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorGetIndentationString = {}

function TestVeafSkynetMonitorDescriptorGetIndentationString:test_zero_indentation_empty()
  local r = VeafSkynetMonitorDescriptor:GetIndentationString(0)
  luaunit.assertEquals(r, "")
end

function TestVeafSkynetMonitorDescriptorGetIndentationString:test_one_indentation()
  local r = VeafSkynetMonitorDescriptor:GetIndentationString(1)
  luaunit.assertEquals(r, "  ")
end

function TestVeafSkynetMonitorDescriptorGetIndentationString:test_two_indentation()
  local r = VeafSkynetMonitorDescriptor:GetIndentationString(2)
  luaunit.assertEquals(r, "    ")
end

function TestVeafSkynetMonitorDescriptorGetIndentationString:test_three_indentation()
  local r = VeafSkynetMonitorDescriptor:GetIndentationString(3)
  luaunit.assertEquals(r, "      ")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorNewLine
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorNewLine = {}

function TestVeafSkynetMonitorDescriptorNewLine:test_nil_base_with_zero_indent()
  -- NewLine requires a non-nil base; empty string is the minimal valid input
  local r = VeafSkynetMonitorDescriptor:NewLine("", 0)
  luaunit.assertEquals(r, "\n")
end

function TestVeafSkynetMonitorDescriptorNewLine:test_base_with_zero_indent()
  local r = VeafSkynetMonitorDescriptor:NewLine("hello", 0)
  luaunit.assertEquals(r, "hello\n")
end

function TestVeafSkynetMonitorDescriptorNewLine:test_base_with_indent()
  local r = VeafSkynetMonitorDescriptor:NewLine("hello", 1)
  luaunit.assertEquals(r, "hello\n  ")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorAppendLine
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorAppendLine = {}

function TestVeafSkynetMonitorDescriptorAppendLine:test_nil_base_returns_append_with_indent()
  local r = VeafSkynetMonitorDescriptor:AppendLine(nil, "hello", 0)
  luaunit.assertEquals(r, "hello")
end

function TestVeafSkynetMonitorDescriptorAppendLine:test_base_and_append()
  local r = VeafSkynetMonitorDescriptor:AppendLine("a", "b", 1)
  luaunit.assertEquals(r, "a\n  b")
end

function TestVeafSkynetMonitorDescriptorAppendLine:test_nil_append_returns_base()
  local r = VeafSkynetMonitorDescriptor:AppendLine("hello", nil, 0)
  luaunit.assertEquals(r, "hello")
end

os.exit(luaunit.LuaUnit.run())
