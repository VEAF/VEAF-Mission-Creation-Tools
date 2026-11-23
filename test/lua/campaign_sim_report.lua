--- The campaign economy simulator's report (FIX-CAMPAIGN-ECONOMY-BALANCE 04): each virtual team plays each shop
--- strategy on several seeds; the report gives the medians. Run through `poetry run campaign-sim report`, or:
---
---   luae.exe test/lua/campaign_sim_report.lua [hours] [seeds] [csv path]
---   luae.exe test/lua/campaign_sim_report.lua calibrate [hours] [seeds]
---
--- `calibrate` plays the average team with no purchase on the rewards of before the lot (`sim.OLD_REWARDS`), whose
--- 2,000 credits an evening the server measured, and on today's.

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
local sim = dofile(_base .. "/campaign_sim.lua")

local args = arg or {}
local calibrate = args[1] == "calibrate"
local offset = calibrate and 1 or 0
local hours = tonumber(args[1 + offset]) or 9
local seeds = tonumber(args[2 + offset]) or 5
local csvPath = not calibrate and args[3] or nil

local function median(values)
  if #values == 0 then
    return nil
  end
  table.sort(values)
  local middle = math.floor((#values + 1) / 2)
  if #values % 2 == 1 then
    return values[middle]
  end
  return (values[middle] + values[middle + 1]) / 2
end

--- A time in hours as `2 h 05`, or `-` when the median run never got there.
local function clock(value)
  if not value then
    return "-"
  end
  local minutes = math.floor(value * 60 + 0.5)
  return string.format("%d h %02d", math.floor(minutes / 60), minutes % 60)
end

--- The median of a value over the runs, `nil` when fewer than half of them have it.
local function medianOf(runs, read)
  local values = {}
  for _, run in ipairs(runs) do
    local value = read(run)
    if value then
      table.insert(values, value)
    end
  end
  if #values * 2 < #runs then
    return nil
  end
  return median(values)
end

local function evenings()
  return hours / sim.EVENING_HOURS
end

if calibrate then
  for _, rewards in ipairs({ { "before the lot", sim.OLD_REWARDS }, { "today", nil } }) do
    local runs = {}
    for seed = 1, seeds do
      table.insert(runs, sim.run({ player = "average", strategy = "never", seed = seed, hours = hours, rewards = rewards[2] }))
    end
    local earned = medianOf(runs, function(run)
      local total = 0
      for _, row in ipairs(run.rows) do
        total = total + row.earned
      end
      return total / evenings()
    end)
    local kills = medianOf(runs, function(run)
      return run.counts.groundKills / evenings()
    end)
    local captures = medianOf(runs, function(run)
      return run.counts.captures / evenings()
    end)
    print(
      string.format(
        "rewards %s: %d credits an evening, %d ground kills, %.1f captures (median of %d seeds, %d h)",
        rewards[1],
        earned,
        kills,
        captures,
        seeds,
        hours
      )
    )
  end
  return
end

local csv = csvPath and assert(io.open(csvPath, "w"))
if csv then
  csv:write("player,strategy,seed,hour,credits,earned,spent,red_stock,red_earned,red_spent,blue_stock,captures,ground_kills\n")
end

local players = { "occasional", "average", "expert" }
print(string.format("Campaign economy simulator: %d h of play, %d seed(s), the median run", hours, seeds))
for _, player in ipairs(players) do
  for _, strategy in ipairs(sim.STRATEGIES) do
    local runs = {}
    for seed = 1, seeds do
      local run = sim.run({ player = player, strategy = strategy, seed = seed, hours = hours })
      table.insert(runs, run)
      for _, row in ipairs(csv and run.rows or {}) do
        csv:write(
          string.format(
            "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
            player,
            strategy,
            seed,
            row.hour,
            row.credits,
            row.earned,
            row.spent,
            row.red,
            row.redEarned,
            row.redSpent,
            row.blue,
            row.captures,
            row.groundKills
          )
        )
      end
    end
    print(string.format("\n## %s, %s", player, strategy))
    -- the first purchase of each item, the earliest first
    local items, seen = {}, {}
    for _, run in ipairs(runs) do
      for id in pairs(run.firstPurchase) do
        if not seen[id] then
          seen[id] = true
          table.insert(items, id)
        end
      end
    end
    local firsts = {}
    for _, id in ipairs(items) do
      firsts[id] = medianOf(runs, function(run)
        return run.firstPurchase[id]
      end)
    end
    table.sort(items, function(a, b)
      return (firsts[a] or 1e9) < (firsts[b] or 1e9)
    end)
    local parts = {}
    for _, id in ipairs(items) do
      table.insert(parts, string.format("%s %s", id, clock(firsts[id])))
    end
    print("first purchases: " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
    -- hour by hour
    local line = { "hour   " }
    for hour = 1, hours do
      table.insert(line, string.format("%6d", hour))
    end
    print(table.concat(line))
    for _, field in ipairs({ "earned", "spent", "credits", "red", "redSpent" }) do
      local cells = { string.format("%-7s", field == "red" and "red st." or field == "redSpent" and "red sp." or field) }
      for hour = 1, hours do
        local value = medianOf(runs, function(run)
          return run.rows[hour] and run.rows[hour][field]
        end)
        table.insert(cells, string.format("%6d", value or 0))
      end
      print(table.concat(cells))
    end
    print(
      string.format(
        "red can no longer pay a SEAD from %s, a raid from %s; captures %s, ground kills %s",
        clock(medianOf(runs, function(run)
          return run.redDry.sead
        end)),
        clock(medianOf(runs, function(run)
          return run.redDry.raid
        end)),
        tostring(medianOf(runs, function(run)
          return run.counts.captures
        end)),
        tostring(medianOf(runs, function(run)
          return run.counts.groundKills
        end))
      )
    )
  end
end
if csv then
  csv:close()
  print("\nhour-by-hour rows written to " .. csvPath)
end
