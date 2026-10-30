--- AIEN's group situational awareness is read through `AIEN.groupSA`, never `og.sa.pos` directly.
--
-- Why this file exists. On 2026-10-29 the dcs.log of a server running "Marteau du Golan" held 49
-- times `AIEN.lua:5631: attempt to index field 'sa' (a nil value)` in `counterBattery`, called from
-- the hit event. `og.sa` is filled only by the phase cycle, which skips the groups under attack: an
-- artillery group hit from the start never had one, and the counter-battery never fired.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")

local _aienPath = _base .. "/../../src/scripts/community/AIEN.lua"
dofile(_aienPath)

TestAienGroupSA = {}

function TestAienGroupSA:test_missing_sa_of_an_unknown_group_is_nil_without_raising()
  -- A group AIEN never enrolled: getSA answers false, the helper must turn that into nil.
  dcs_mocks.addGroup("ARTY-unknown", { _id = 4242 })
  local og = { group = Group.getByName("ARTY-unknown"), class = "ARTY", threat = 15000 }

  luaunit.assertNil(AIEN.groupSA(og))
  luaunit.assertNil((AIEN.groupSA(og) or {}).pos, "the call sites read `.pos` through `or {}`")
end

function TestAienGroupSA:test_missing_sa_of_a_dead_group_is_nil_without_raising()
  dcs_mocks.addGroup("ARTY-dead", {
    isExist = function()
      return false
    end,
  })
  local og = { group = Group.getByName("ARTY-dead"), sa = nil }

  luaunit.assertNil(AIEN.groupSA(og))
end

function TestAienGroupSA:test_an_existing_sa_is_reused_not_recomputed()
  local sa = { pos = { x = 1, y = 0, z = 2 } }
  local og = { group = nil, sa = sa }

  luaunit.assertIs(AIEN.groupSA(og), sa)
end

function TestAienGroupSA:test_a_false_sa_left_by_the_cycle_is_recomputed()
  -- getSA answers `false`, not nil, for a group it cannot assess; `false.pos` raises just the same.
  dcs_mocks.addGroup("ARTY-false", { _id = 4343 })
  local og = { group = Group.getByName("ARTY-false"), sa = false }

  luaunit.assertNil(AIEN.groupSA(og))
end

function TestAienGroupSA:test_no_direct_sa_field_read_is_left_on_a_db_entry()
  -- Enumerated over the whole file: every `<entry>.sa.<field>` read must sit behind a guard. The
  -- two that remain are inside `if ... db_group.sa then` / `if ... gData.sa then` blocks; any new
  -- one fails here and has to be looked at.
  local guarded = {
    ["point = gData.sa.pos,"] = true,
    ["o_cls = db_group.sa.cls"] = true,
    ["local d = db_group.sa.rng or 1500"] = true,
  }
  local unguarded = {}
  local n = 0
  for line in io.lines(_aienPath) do
    n = n + 1
    local code = line:gsub("%-%-.*$", "")
    if code:match("[%w_]+%.sa%.[%w_]+") then
      local trimmed = code:match("^%s*(.-)%s*$")
      if not guarded[trimmed] then
        table.insert(unguarded, n .. ": " .. trimmed)
      end
    end
  end
  luaunit.assertEquals(unguarded, {})
end

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
