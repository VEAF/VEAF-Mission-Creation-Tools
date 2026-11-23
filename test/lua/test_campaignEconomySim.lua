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
local DRAWS_PER_SEED = 5

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

--- Under luacov (`test-lua --coverage`, the CI's Lua Coverage job) the simulator's hours of play take longer than the
--- job may run: 2026-11-20, cancelled at its 15 minutes. The Lua Unit Tests job runs these bounds; the coverage job
--- skips them.
local UNDER_COVERAGE = package.loaded.luacov ~= nil or package.loaded["luacov.runner"] ~= nil

TestCampaignEconomySim = {}

function TestCampaignEconomySim:setUp()
  luaunit.skipIf(UNDER_COVERAGE, "the economy simulator does not run under luacov: too slow for the coverage job")
end

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

-- FIX-CAMPAIGN-ECONOMY-BALANCE 05: the upgrades, drawn from the real groups of veaf-units.yaml and priced unit by unit,
-- cost about Foothold's prices
function TestCampaignEconomySim:test_the_upgrades_cost_about_foothold_s_prices()
  -- FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY 03: the IRIS-T SLM as the Hawk and the NASAMS, the Rapier as an Avenger section
  local targets = { hawk = 2000, nasams = 2000, patriot = 5000, avenger = 1000, gepard = 750, iristslm = 2000, rapier = 1000 }
  local prices = {}
  for seed = 1, SEEDS do
    sim.run({ player = "average", strategy = "never", seed = seed, hours = 0 })
    veafCampaign.data.dynamic.economy.prices = {}
    -- several draws per run: with one, the median of three hung on where the run left the random sequence, and a
    -- garrison drawing one more random point (FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT 06) turned two NASAMS of three into
    -- batteries with two Avengers
    for _ = 1, DRAWS_PER_SEED do
      veafCampaignEconomy.offers = {} -- an offer is drawn once and kept: a new draw each time
      for id in pairs(targets) do
        prices[id] = prices[id] or {}
        table.insert(prices[id], veafCampaignEconomy.upgradePrice(id))
      end
    end
  end
  for id, target in pairs(targets) do
    -- a drawn group varies: a NASAMS battery draws one Avenger, sometimes two (about 3,000 credits then)
    local price = median(prices[id])
    luaunit.assertTrue(price >= target * 0.9 and price <= target * 1.1, string.format("%s %d for %d", id, price, target))
  end
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
