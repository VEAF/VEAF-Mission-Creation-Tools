--- The campaign economy's guard (FIX-CAMPAIGN-ECONOMY-BALANCE 04), as Iron Gall's `EditionTests`: the simulator plays
--- the average team on the Oronte campaign with the real campaign code, and a few milestones must stay within bounds.
--- A price or a reward that breaks the pacing turns this red.
---
--- The bounds were set from what the simulator measured after tickets 01 and 02 (2026-11-20, median of 3 seeds):
--- the average team buys its first CAP at 2 h 30 with the `cheapest` strategy, and its Hawk at 2 h 50 saving for it;
--- red can no longer pay a SEAD from 1 h 00, right after its first bomber raid (`bombers.seconds`, 3600) — the
--- milestone David asked for, "red does not run dry in the first hour", sits on that edge.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
local sim = dofile(_base .. "/campaign_sim.lua")

local SEEDS = 3

local function median(values)
  table.sort(values)
  return values[math.floor((#values + 1) / 2)]
end

--- The median over the seeds of a milestone, in hours; a run that never reaches it counts as never (huge).
local function medianHour(options, read)
  local values = {}
  for seed = 1, SEEDS do
    options.seed = seed
    table.insert(values, read(sim.run(options)) or math.huge)
  end
  return median(values)
end

TestCampaignEconomySim = {}

function TestCampaignEconomySim:test_an_average_team_affords_a_cap_in_its_first_evening()
  local hour = medianHour({ player = "average", strategy = "cheapest", hours = 3 }, function(run)
    return run.firstPurchase.cap
  end)
  -- measured 2 h 30: not trivial, and within the evening
  luaunit.assertTrue(hour >= 1 and hour <= sim.EVENING_HOURS, string.format("first CAP at %.2f h", hour))
end

function TestCampaignEconomySim:test_an_average_team_affords_a_hawk_within_two_evenings()
  local hour = medianHour({ player = "average", strategy = "hawk", hours = 2 * sim.EVENING_HOURS }, function(run)
    return run.firstPurchase["upgrade hawk"]
  end)
  -- measured 2 h 50
  luaunit.assertTrue(hour >= 1.5 and hour <= 2 * sim.EVENING_HOURS, string.format("first Hawk at %.2f h", hour))
end

function TestCampaignEconomySim:test_red_pays_its_sead_for_most_of_the_first_hour()
  local hour = medianHour({ player = "average", strategy = "never", hours = 2 }, function(run)
    return run.redDry.sead
  end)
  -- measured 1 h 00, after the first bomber raid
  luaunit.assertTrue(hour >= 0.75, string.format("red cannot pay a SEAD from %.2f h", hour))
end

function TestCampaignEconomySim:test_the_simulator_plays_the_real_campaign()
  local run = sim.run({ player = "average", strategy = "cheapest", seed = 1, hours = 1 })
  -- the kills reached the economy through the event handler, and red spent with its own decision code
  luaunit.assertTrue(run.counts.groundKills > 0)
  luaunit.assertTrue(run.ledger.credits.earned.kill_ground ~= nil or run.ledger.credits.earned.kill_sam ~= nil)
  luaunit.assertNotNil(run.ledger.red.spent.flight)
  luaunit.assertNotNil(run.ledger.red.earned.production)
  luaunit.assertEquals(#run.rows, 1)
end

os.exit(luaunit.LuaUnit.run())
