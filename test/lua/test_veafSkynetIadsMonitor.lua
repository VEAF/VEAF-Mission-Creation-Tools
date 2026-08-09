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

-- ---------------------------------------------------------------------------
-- Mock helper for skynet site objects
-- ---------------------------------------------------------------------------
local function _makeMockSkynetSite(name)
  return {
    dcsName = name,
    typeName = "TestType",
    isAPointDefence = false,
    dcsRepresentation = {
      isExist = function()
        return false
      end,
    },
    harmSilenceID = nil,
    getLaunchers = function(self)
      return {}
    end,
    getPointDefences = function(self)
      return {}
    end,
    isActive = function(self)
      return true
    end,
    getAutonomousState = function(self)
      return false
    end,
    getActAsEW = function(self)
      return false
    end,
    hasRemainingAmmo = function(self)
      return true
    end,
    getDetectedTargets = function(self)
      return {}
    end,
    getNatoName = function(self)
      return "SA-10"
    end,
  }
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorGetStringElementStructure
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorGetStringElementStructure = {}

function TestVeafSkynetMonitorDescriptorGetStringElementStructure:test_nil_elements_returns_no_prefix()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local s = desc:GetStringElementStructure(nil, "Launchers")
  luaunit.assertStrContains(s, "No Launchers")
end

function TestVeafSkynetMonitorDescriptorGetStringElementStructure:test_empty_elements_returns_no_prefix()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local s = desc:GetStringElementStructure({}, "Launchers")
  luaunit.assertStrContains(s, "No Launchers")
end

function TestVeafSkynetMonitorDescriptorGetStringElementStructure:test_elements_without_range_includes_count()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local s = desc:GetStringElementStructure({ {} }, "Launchers")
  luaunit.assertStrContains(s, "Launchers:1")
end

function TestVeafSkynetMonitorDescriptorGetStringElementStructure:test_elements_with_range_includes_nm()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local s = desc:GetStringElementStructure({ { maximumRange = 10000 } }, "Launchers")
  luaunit.assertStrContains(s, "nm")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorGetStringSkynetElement
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorGetStringSkynetElement = {}

function TestVeafSkynetMonitorDescriptorGetStringSkynetElement:test_nil_dcs_group_appends_not_found()
  local el = _makeMockSkynetSite("TestEl")
  local s = VeafSkynetMonitorDescriptor:GetStringSkynetElement(el)
  luaunit.assertStrContains(s, "not found")
end

function TestVeafSkynetMonitorDescriptorGetStringSkynetElement:test_existing_dcs_group_includes_id()
  local rep = {
    isExist = function()
      return true
    end,
    getID = function()
      return 42
    end,
    getUnits = function()
      return {}
    end,
  }
  setmetatable(rep, Group)
  local el = {
    dcsName = "TestSite",
    typeName = "SA-6",
    dcsRepresentation = rep,
    getNatoName = function(self)
      return "Gainful"
    end,
  }
  local s = VeafSkynetMonitorDescriptor:GetStringSkynetElement(el)
  luaunit.assertStrContains(s, "42")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorGetStringSam
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorGetStringSam = {}

function TestVeafSkynetMonitorDescriptorGetStringSam:test_active_sam_contains_active()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local sam = _makeMockSkynetSite("SA10")
  local s = desc:GetStringSam(sam, 0)
  luaunit.assertStrContains(s, "Active")
end

function TestVeafSkynetMonitorDescriptorGetStringSam:test_inactive_sam_contains_not_active()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local sam = _makeMockSkynetSite("SA10")
  sam.isActive = function(self)
    return false
  end
  local s = desc:GetStringSam(sam, 0)
  luaunit.assertStrContains(s, "Not active")
end

function TestVeafSkynetMonitorDescriptorGetStringSam:test_sam_no_ammo_contains_no_ammo()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local sam = _makeMockSkynetSite("SA10")
  sam.hasRemainingAmmo = function(self)
    return false
  end
  local s = desc:GetStringSam(sam, 0)
  luaunit.assertStrContains(s, "No ammo")
end

function TestVeafSkynetMonitorDescriptorGetStringSam:test_sam_acts_as_ew_contains_acting_as_ew()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local sam = _makeMockSkynetSite("SA10")
  sam.getActAsEW = function(self)
    return true
  end
  local s = desc:GetStringSam(sam, 0)
  luaunit.assertStrContains(s, "Acting as EW")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDescriptorGetStringEwr
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDescriptorGetStringEwr = {}

function TestVeafSkynetMonitorDescriptorGetStringEwr:test_active_ewr_contains_active()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local ewr = _makeMockSkynetSite("EWR1")
  local s = desc:GetStringEwr(ewr, 0)
  luaunit.assertStrContains(s, "Active")
end

function TestVeafSkynetMonitorDescriptorGetStringEwr:test_inactive_ewr_contains_not_active()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, nil)
  local ewr = _makeMockSkynetSite("EWR1")
  ewr.isActive = function(self)
    return false
  end
  local s = desc:GetStringEwr(ewr, 0)
  luaunit.assertStrContains(s, "Not active")
end

function TestVeafSkynetMonitorDescriptorGetStringEwr:test_ewr_with_element_targets_option_shows_no_targets()
  local desc = VeafSkynetMonitorDescriptor:Create(nil, {
    VeafSkynetMonitorDescriptor.Option.ElementTargets,
  })
  local ewr = _makeMockSkynetSite("EWR1")
  local s = desc:GetStringEwr(ewr, 0)
  luaunit.assertStrContains(s, "No targets")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorTask
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorTask = {}

function TestVeafSkynetMonitorTask:test_create_has_name()
  local t = VeafSkynetMonitorTask:Create("MyTask")
  luaunit.assertEquals(t.Name, "MyTask")
end

function TestVeafSkynetMonitorTask:test_to_string_returns_name()
  local t = VeafSkynetMonitorTask:Create("MyTask")
  luaunit.assertEquals(t:ToString(), "MyTask")
end

function TestVeafSkynetMonitorTask:test_execute_no_error()
  local t = VeafSkynetMonitorTask:Create("MyTask")
  t:Execute()
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorAddRemoveTask
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorAddRemoveTask = {}

function TestVeafSkynetMonitorAddRemoveTask:setUp()
  veafSkynetMonitor._monitoringTasks = {}
  veafSkynetMonitor._monitoringThreadId = nil
end

function TestVeafSkynetMonitorAddRemoveTask:test_add_nil_task_is_noop()
  veafSkynetMonitor.AddMonitoringTask(nil)
  luaunit.assertEquals(veaf.length(veafSkynetMonitor._monitoringTasks), 0)
end

function TestVeafSkynetMonitorAddRemoveTask:test_add_task_with_empty_name_is_error()
  local t = VeafSkynetMonitorTask:Create("")
  veafSkynetMonitor.AddMonitoringTask(t)
  luaunit.assertEquals(veaf.length(veafSkynetMonitor._monitoringTasks), 0)
end

function TestVeafSkynetMonitorAddRemoveTask:test_add_valid_task_is_added()
  local t = VeafSkynetMonitorTask:Create("task1")
  veafSkynetMonitor.AddMonitoringTask(t)
  luaunit.assertNotNil(veafSkynetMonitor._monitoringTasks["task1"])
end

function TestVeafSkynetMonitorAddRemoveTask:test_add_duplicate_task_is_error()
  local t1 = VeafSkynetMonitorTask:Create("dup")
  local t2 = VeafSkynetMonitorTask:Create("dup")
  veafSkynetMonitor.AddMonitoringTask(t1)
  veafSkynetMonitor.AddMonitoringTask(t2)
  luaunit.assertEquals(veafSkynetMonitor._monitoringTasks["dup"], t1)
end

function TestVeafSkynetMonitorAddRemoveTask:test_remove_existing_task()
  local t = VeafSkynetMonitorTask:Create("toRemove")
  veafSkynetMonitor.AddMonitoringTask(t)
  veafSkynetMonitor.RemoveMonitoringTask("toRemove")
  luaunit.assertNil(veafSkynetMonitor._monitoringTasks["toRemove"])
end

function TestVeafSkynetMonitorAddRemoveTask:test_remove_nonexistent_task_is_noop()
  veafSkynetMonitor.RemoveMonitoringTask("noSuchTask")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorExecuteTasks
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorExecuteTasks = {}

function TestVeafSkynetMonitorExecuteTasks:setUp()
  veafSkynetMonitor._monitoringTasks = {}
  veafSkynetMonitor._monitoringThreadId = nil
end

function TestVeafSkynetMonitorExecuteTasks:test_execute_empty_tasks_no_error()
  veafSkynetMonitor.ExecuteMonitoringTasks()
end

function TestVeafSkynetMonitorExecuteTasks:test_execute_runs_all_tasks()
  local execCount = 0
  local t1 = VeafSkynetMonitorTask:Create("et1")
  t1.Execute = function(self)
    execCount = execCount + 1
  end
  local t2 = VeafSkynetMonitorTask:Create("et2")
  t2.Execute = function(self)
    execCount = execCount + 1
  end
  veafSkynetMonitor.AddMonitoringTask(t1)
  veafSkynetMonitor.AddMonitoringTask(t2)
  veafSkynetMonitor.ExecuteMonitoringTasks()
  luaunit.assertEquals(execCount, 2)
end

os.exit(luaunit.LuaUnit.run())
