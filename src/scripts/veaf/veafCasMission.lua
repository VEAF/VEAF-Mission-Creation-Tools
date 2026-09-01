------------------------------------------------------------------
-- VEAF CAS (Close Air Support) command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and creates a CAS training mission, with optional parameters
-- * Create a CAS target group, protected by SAM, AAA and manpads, to use for CAS training
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCasMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCasMission.Id = "CASMISSION"

-- trace level, specific to this module
--veafCasMission.LogLevel = "trace"

veaf.loggers.new(veafCasMission.Id, veafCasMission.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafCasMission.Keyphrase = "_cas"

--- Number of seconds between each check of the CAS group watchdog function
veafCasMission.SecondsBetweenWatchdogChecks = 15

--- Number of seconds between each smoke request on the CAS targets group
veafCasMission.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the CAS targets group
veafCasMission.SecondsBetweenFlareRequests = 120

--- Name of the CAS targets vehicles group
veafCasMission.RedCasGroupName = "Red CAS Group"
veafCasMission.BlueCasGroupName = "Blue CAS Group"
veafCasMission.casGroupName = veafCasMission.RedCasGroupName
veafCasMission.afacName = nil

veafCasMission.RadioMenuName = "menu.casmission.root"

veafCasMission.TRANSPORT_TYPES = {
  [coalition.side.BLUE] = {
    [veaf.ERA.MODERN] = {
      [0] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [1] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [2] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [3] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [4] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [5] = { "LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3" },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
      [1] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
      [2] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
      [3] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
      [4] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
      [5] = { "Truck Land Rover 101 FC", "LUV Land Rover 109", "Truck M939 Heavy" },
    },
    [veaf.ERA.WW2] = {
      [0] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
      [1] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
      [2] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
      [3] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
      [4] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
      [5] = { "Bedford_MWD", "CCKW_353", "Willys_MB" },
    },
  },
  [coalition.side.RED] = {
    [veaf.ERA.MODERN] = {
      [0] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
      [1] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
      [2] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
      [3] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
      [4] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
      [5] = {
        "ATZ-60_Maz",
        "ZIL-135",
        "ATZ-5",
        "Ural-4320 APA-5D",
        "SKP-11",
        "GAZ-66",
        "KAMAZ Truck",
        "Ural-375",
        "KrAZ6322",
        "ZIL-131 KUNG",
        "Tigr_233036",
        "UAZ-469",
      },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
      [1] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
      [2] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
      [3] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
      [4] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
      [5] = {
        "LUV UAZ-469 Jeep",
        "Refueler ATMZ-5",
        "Refueler ATZ-10",
        "Refueler ATZ-5",
        "S-75 Tractor (ZIL-131)",
        "Truck GAZ-66",
        "Truck KAMAZ 43101",
        "Truck Ural-4320",
        "Truck Ural-4320-31 Arm'd",
        "Truck Ural-4320T",
        "Truck ZIL-131 (C2)",
        "Truck ZIL-135",
      },
    },
    [veaf.ERA.WW2] = {
      [0] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [1] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [2] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [3] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [4] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [5] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
    },
  },
}

-- Armour available to a spawned platoon, by side, era and tier (0 = none, 5 = the heaviest).
--
-- **Hand-written, deliberately** (FIX-PLATOON-UNITS, #296). Deriving these tiers from `dcsUnits` was the
-- alternative and it is not possible: a tier is an *editorial* judgement of relative power, and an era is
-- a judgement of period — the generated database carries neither. Its records hold `type`, `name`,
-- `kind`, `category` and DCS `attributes`, and nothing there separates a BMP-1 (tier 1) from a T-90
-- (tier 5). Deriving would mean inventing the data first.
--
-- What stops #296 recurring is therefore not derivation but the **enumerated sweep** in
-- `test_veafCasMission`: every entry of every table is checked against the database, so a type DCS
-- renames or drops fails the build instead of silently spawning nothing. That sweep is what found six
-- occurrences of `"APC TPz Fuchs"` resolving to nothing.
--
-- Entries use the DCS **type id** rather than the display name where the two differ (`CHAP_T90M`, not
-- `MBT T-90M [CH]`): a type id is stable, and a display name is what carried the trailing space that
-- broke the Fuchs.
veafCasMission.ARMOR_TYPES = {
  [coalition.side.BLUE] = {
    [veaf.ERA.MODERN] = {
      [0] = {},
      [1] = { "IFV Marder", "MCV-80", "IFV LAV-25", "M1134 Stryker ATGM", "M-2 Bradley", "CHAP_MATV" },
      [2] = { "IFV Marder", "MCV-80", "IFV LAV-25", "M1134 Stryker ATGM", "M-2 Bradley", "CHAP_MATV" },
      [3] = { "IFV Marder", "VAB_Mephisto", "M-2 Bradley", "MBT Leopard 1A3", "Chieftain_mk3", "CHAP_M1130" },
      [4] = { "M-2 Bradley", "MBT Leopard 1A3", "Merkava_Mk4", "M1128 Stryker MGS", "CHAP_M1130" },
      [5] = { "Merkava_Mk4", "Challenger2", "Leclerc", "Leopard-2", "M-1 Abrams", "CHAP_T84OplotM" },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = {},
      [1] = { "APC M113", "TPZ", "APC AAV-7 Amphibious", "CHAP_FV107" },
      [2] = { "APC M113", "TPZ", "APC AAV-7 Amphibious", "IFV Marder", "CHAP_FV107" },
      [3] = { "APC M113", "TPZ", "APC AAV-7 Amphibious", "IFV Marder", "MBT M60A3 Patton", "CHAP_FV101" },
      [4] = { "APC AAV-7 Amphibious", "IFV Marder", "MBT M60A3 Patton", "MBT Leopard 1A3", "MBT Chieftain Mk.3", "CHAP_FV101" },
      [5] = { "APC AAV-7 Amphibious", "IFV Marder", "MBT M60A3 Patton", "MBT Leopard 1A3", "MBT Chieftain Mk.3" },
    },
    [veaf.ERA.WW2] = {
      [0] = {},
      [1] = { "M30_CC", "M10_GMC" },
      [2] = { "M30_CC", "M10_GMC" },
      [3] = { "M30_CC", "M10_GMC", "Centaur_IV" },
      [4] = { "Centaur_IV", "Churchill_VII", "Cromwell_IV" },
      [5] = { "Centaur_IV", "Churchill_VII", "Cromwell_IV", "M4_Sherman", "M4A4_Sherman_FF" },
    },
  },
  [coalition.side.RED] = {
    [veaf.ERA.MODERN] = {
      [0] = {},
      [1] = { "BTR-82A", "BMP-1", "VAB_Mephisto" },
      [2] = { "BTR-82A", "BMP-1", "VAB_Mephisto", "BMP-2" },
      [3] = { "BTR-82A", "VAB_Mephisto", "BMP-2", "T-55", "Chieftain_mk3" },
      [4] = { "BTR-82A", "BMP-3", "Chieftain_mk3", "T-72B", "CHAP_T64BV", "CHAP_BMPT" },
      [5] = { "BMP-3", "ZTZ96B", "T-72B3", "T-80UD", "T-90", "CHAP_T90M", "CHAP_BMPT" },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = {},
      [1] = { "Scout BRDM-2", "APC MTLB" },
      [2] = { "Scout BRDM-2", "APC MTLB", "IFV BMD-1", "IFV BMP-1" },
      [3] = { "Scout BRDM-2", "APC MTLB", "IFV BMD-1", "IFV BMP-1", "APC BTR-RD" },
      [4] = { "APC MTLB", "IFV BMD-1", "IFV BMP-1", "APC BTR-RD", "LT PT-76" },
      [5] = { "IFV BMD-1", "IFV BMP-1", "APC BTR-RD", "LT PT-76", "MBT T-55" },
    },
    [veaf.ERA.WW2] = {
      [0] = {},
      [1] = { "Sd_Kfz_251", "Sd_Kfz_234_2_Puma" },
      [2] = { "Sd_Kfz_251", "Sd_Kfz_234_2_Puma" },
      [3] = { "Sd_Kfz_251", "Sd_Kfz_234_2_Puma", "Elefant_SdKfz_184" },
      [4] = { "Pz_IV_H", "Tiger_I", "Tiger_II_H", "Stug_III", "Stug_IV" },
      [5] = { "Pz_IV_H", "Tiger_I", "Tiger_II_H", "Stug_III", "Stug_IV", "JagdPz_IV", "Jagdpanther_G1", "Pz_V_Panther_G" },
    },
  },
}

veafCasMission.INFANTRY_TYPES = {
  [coalition.side.BLUE] = {
    [veaf.ERA.MODERN] = { "Soldier RPG", "Soldier M249", "Soldier M4 GRG" },
    [veaf.ERA.COLD_WAR] = { "Soldier RPG", "Soldier M249", "Soldier M4 GRG" },
    [veaf.ERA.WW2] = { "Soldier RPG", "Soldier M249", "Soldier M4 GRG" },
  },
  [coalition.side.RED] = {
    [veaf.ERA.MODERN] = { "Paratrooper RPG-16", "Infantry AK ver3", "Infantry AK ver2" },
    [veaf.ERA.COLD_WAR] = { "Paratrooper RPG-16", "Infantry AK ver3", "Infantry AK ver2" },
    [veaf.ERA.WW2] = { "Paratrooper RPG-16", "Infantry AK ver3", "Infantry AK ver2" },
  },
}

veafCasMission.INFANTRY_IFV_TYPES = {
  [coalition.side.BLUE] = {
    [veaf.ERA.MODERN] = {
      [0] = { "Land_Rover_101_FC", "Land_Rover_109_S3" },
      [1] = { "IFV Marder" },
      [2] = { "IFV Marder" },
      [3] = { "M-2 Bradley" },
      [4] = { "M-2 Bradley" },
      [5] = { "M-2 Bradley" },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = { "Truck M939 Heavy" },
      [1] = { "APC M113", "TPZ", "APC AAV-7 Amphibious" },
      [2] = { "APC M113", "TPZ", "APC AAV-7 Amphibious", "IFV Marder" },
      [3] = { "APC M113", "TPZ", "APC AAV-7 Amphibious", "IFV Marder" },
      [4] = { "APC AAV-7 Amphibious", "IFV Marder" },
      [5] = { "APC AAV-7 Amphibious", "IFV Marder" },
    },
    [veaf.ERA.WW2] = {
      [0] = { "Bedford_MWD" },
      [1] = { "APC M2A1 Halftrack" },
      [2] = { "APC M2A1 Halftrack" },
      [3] = { "M-2 Bradley" },
      [4] = { "M-2 Bradley" },
      [5] = { "M-2 Bradley" },
    },
  },
  [coalition.side.RED] = {
    [veaf.ERA.MODERN] = {
      [0] = { "Ural-4320 APA-5D", "GAZ-66", "KAMAZ Truck" },
      [1] = { "BMP-1" },
      [2] = { "BMP-1" },
      [3] = { "BMP-2" },
      [4] = { "BMP-2" },
      [5] = { "BMP-2" },
    },
    [veaf.ERA.COLD_WAR] = {
      [0] = { "Truck KAMAZ 43101", "Truck ZIL-135", "Truck Ural-4320-31 Arm'd" },
      [1] = { "APC MTLB" },
      [2] = { "APC MTLB", "APC BTR-RD" },
      [3] = { "APC MTLB", "APC BTR-RD", "IFV BMD-1" },
      [4] = { "APC MTLB", "APC BTR-RD", "IFV BMD-1", "IFV BMP-1" },
      [5] = { "APC BTR-RD", "IFV BMD-1", "IFV BMP-1" },
    },
    [veaf.ERA.WW2] = {
      [0] = { "Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" },
      [1] = { "Sd_Kfz_251" },
      [2] = { "Sd_Kfz_251" },
      [3] = { "Sd_Kfz_234_2_Puma" },
      [4] = { "Sd_Kfz_234_2_Puma" },
      [5] = { "Sd_Kfz_234_2_Puma" },
    },
  },
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCasMission.targetMarkersPath = nil
veafCasMission.targetInfoPath = nil
veafCasMission.rootPath = nil

-- CAS Group watchdog function id
veafCasMission.groupAliveCheckTaskID = "none"

-- Smoke reset function id
veafCasMission.smokeResetTaskID = "none"

-- Flare reset function id
veafCasMission.flareResetTaskID = "none"

veafCasMission.SIDE_RED = coalition.side.RED
veafCasMission.SIDE_BLUE = coalition.side.BLUE

--- Seconds a bare `disperse` keyword asks for, when the pilot names no delay.
veafCasMission.DEFAULT_DISPERSE_DELAY = 15

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCasMission.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity)
  veaf.loggers.get(veafCasMission.Id):debug(string.format("veafCasMission.executeCommand(eventText=[%s])", eventText))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("coalition=%s", veaf.p(coalition)))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("markId=%s", veaf.p(markId)))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("bypassSecurity=%s", veaf.p(bypassSecurity)))

  -- Check if marker has a text and the veafCasMission.keyphrase keyphrase.
  if eventText ~= nil and eventText:lower():find(veafCasMission.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafCasMission.markTextAnalysis(eventText)

    if options then
      -- A typo aborts — see veaf.reportUnknownParameters. nil: this handler is not given the requester.
      if veaf.reportUnknownParameters(options, veafCasMission.Id, nil) then
        return false
      end
      -- Check options commands
      if options.casmission then
        if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
          return
        end

        if not options.side then
          if options.country then
            -- deduct the side from the country
            options.side = veaf.getCoalitionForCountry(options.country, true)
          else
            options.side = coalition
          end
        end

        if not options.country then
          -- deduct the country from the side
          options.country = veaf.getCountryForCoalition(options.side)
        end

        -- create the group
        veafCasMission.generateCasMission(
          eventPos,
          options.size,
          options.defense,
          options.armor,
          options.spacing,
          options.disperseOnAttack,
          options.side
        )
        return true
      end
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The CAS module's marker specification, read by `veaf.parseMarkerText`.
---
--- REFACTOR-MARKER-PARSER ticket 03. Bounds are asymmetric and unchanged: `size` and `spacing`
--- start at 1, `defense` and `armor` accept 0. Out-of-range values stay *ignored* rather than
--- clamped, which is what `VMR-019` settled on.
---
--- The five `if switch.casmission and ...` guards are gone rather than translated into `when`
--- predicates: the flag is set before the loop and the function returns nil when the keyphrase is
--- absent, so all five were always true.
veafCasMission.MarkerSpec = {
  reportUnknownKeys = true,

  defaults = function(options)
    options.casmission = false
    options.size = 1 -- ranges from 1 to 5, 5 being the biggest
    options.defense = 1 -- defenses force ; 1 to 5, 5 being the toughest
    options.armor = 1 -- armor force ; 1 to 5, 5 being the strongest and most modern
    options.spacing = 1 -- 1 is the default, 5 the widest spacing
    options.disperseOnAttack = false
    options.password = nil
    options.side = nil
  end,
  commands = {
    {
      match = veafCasMission.Keyphrase,
      init = function(options)
        options.casmission = true
      end,
    },
  },
  parameters = {
    { keys = { "password" }, apply = veaf.markerRules.text("password") },
    { keys = { "size" }, apply = veaf.markerRules.boundedNumber("size", 1, 5) },
    { keys = { "defense" }, apply = veaf.markerRules.boundedNumber("defense", 0, 5) },
    { keys = { "armor" }, apply = veaf.markerRules.boundedNumber("armor", 0, 5) },
    { keys = { "spacing" }, apply = veaf.markerRules.boundedNumber("spacing", 1, 5) },
    {
      -- A valueless `side` leaves the side unset rather than falling through to RED, since
      -- executeCommand then derives it from the marker's own coalition. Note the value is NOT
      -- trimmed, so `side  BLUE` with two spaces is " BLUE" and resolves to RED — a recorded
      -- defect, reproduced here and fixed in its own commit.
      keys = { "side" },
      apply = function(options, value)
        if value then
          if value:upper() == "BLUE" then
            options.side = veafCasMission.SIDE_BLUE
          else
            options.side = veafCasMission.SIDE_RED
          end
        end
      end,
    },
    {
      -- A bare `disperse` means "disperse, after the default 15 seconds". The old code expressed
      -- that as `if val ~= "" then tonumber(val) else 15 end`, but `veaf.breakString` returns nil
      -- for a valueless keyword and never `""`, so the `else` was unreachable and a bare
      -- `disperse` silently did nothing at all. Both empty forms now reach the default.
      keys = { "disperse" },
      apply = function(options, value)
        if value == nil or value == "" then
          options.disperseOnAttack = veafCasMission.DEFAULT_DISPERSE_DELAY
          return
        end
        local converted = veaf.safeNumber(value)
        if converted then
          options.disperseOnAttack = converted
        end
      end,
    },
  },
  valueWhenAbsent = nil,
}

--- Extract keywords from mark text.
function veafCasMission.markTextAnalysis(text)
  return veaf.parseMarkerText(text, veafCasMission.MarkerSpec)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAS target group generation and management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _addDefenseForGroups(group, side, defense, multiple, forInfantry)
  veaf.loggers.get(veafCasMission.Id):trace(
    string.format(
      "_addDefenseForGroups(defense=[%s], side=[%s], multiple=[%s], forInfantry=[%s])",
      veaf.p(defense),
      veaf.p(side),
      veaf.p(multiple),
      veaf.p(forInfantry)
    )
  )
  local _actualDefense = defense
  if defense > 0 then
    -- roll a dice : 20% chance to get a -1 (lower) difficulty, 30% chance to get a +1 (higher) difficulty, and 50% to get what was asked for
    local _dice = math.random(100)
    veaf.loggers.get(veafCasMission.Id):trace("_dice = " .. _dice)
    if _dice <= 20 then
      _actualDefense = defense - 1
    elseif _dice > 80 then
      _actualDefense = defense + 1
    end
  end
  if _actualDefense > 5 then
    _actualDefense = 6
  end
  if _actualDefense < 0 then
    _actualDefense = 0
  end
  veaf.loggers.get(veafCasMission.Id):trace("_actualDefense = " .. _actualDefense)
  for _ = 1, multiple do
    if _actualDefense > 5 then
      if side == veafCasMission.SIDE_BLUE then
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            table.insert(group.units, { "Stinger comm", random = true })
            table.insert(group.units, { "Soldier stinger", random = true })
          end
        else
          table.insert(group.units, { "M1097 Avenger", random = true })
          table.insert(group.units, { "Roland ADS", random = true })
          table.insert(group.units, { "Gepard", random = true })
        end
      else
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            -- for _actualDefense = 4-5, spawn a modern Igla-S team
            table.insert(group.units, { "SA-18 Igla-S comm", random = true })
            table.insert(group.units, { "SA-18 Igla-S manpad", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "2S6 Tunguska", "Tor 9A331", "Tor 9A331" }), random = true })
          table.insert(group.units, { "Strela-10M3", random = true })
          table.insert(group.units, { "ZSU-23-4 Shilka", random = true })
        end
      end
    elseif _actualDefense == 5 then
      if side == veafCasMission.SIDE_BLUE then
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            table.insert(group.units, { "Stinger comm", random = true })
            table.insert(group.units, { "Soldier stinger", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "Gepard", "M1097 Avenger", "M1097 Avenger" }), random = true })
          table.insert(group.units, { "Roland ADS", random = true })
        end
      else
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            -- for _actualDefense = 4-5, spawn a modern Igla-S team
            table.insert(group.units, { "SA-18 Igla-S comm", random = true })
            table.insert(group.units, { "SA-18 Igla-S manpad", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "Osa 9A33 ln", "2S6 Tunguska" }), random = true })
          table.insert(group.units, { veaf.randomlyChooseFrom({ "ZSU-23-4 Shilka", "Strela-10M3" }), random = true })
        end
      end
    elseif _actualDefense == 4 then
      if side == veafCasMission.SIDE_BLUE then
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            table.insert(group.units, { "Stinger comm", random = true })
            table.insert(group.units, { "Soldier stinger", random = true })
          end
        else
          table.insert(group.units, { "Gepard", random = true })
          table.insert(group.units, { "Roland ADS", random = true })
        end
      else
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            -- for _actualDefense = 4-5, spawn a modern Igla-S team
            table.insert(group.units, { "SA-18 Igla-S comm", random = true })
            table.insert(group.units, { "SA-18 Igla-S manpad", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "ZSU-23-4 Shilka", "ZSU-23-4 Shilka", "ZSU_57_2" }), random = true })
          table.insert(group.units, { veaf.randomlyChooseFrom({ "HQ-7_LN_EO", "HQ-7_LN_SP" }), random = true })
        end
      end
    elseif _actualDefense == 3 then
      if side == veafCasMission.SIDE_BLUE then
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            table.insert(group.units, { "Stinger comm", random = true })
            table.insert(group.units, { "Soldier stinger", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "M48 Chaparral", "M6 Linebacker" }), random = true })
          table.insert(group.units, { "Gepard", random = true })
        end
      else
        if forInfantry then
          -- only spawn manpads
          for _ = 1, math.random(1, _actualDefense - 2) do
            -- for _actualDefense = 3, spawn an older Igla team
            table.insert(group.units, { "SA-18 Igla comm", random = true })
            table.insert(group.units, { "SA-18 Igla manpad", random = true })
          end
        else
          table.insert(group.units, { veaf.randomlyChooseFrom({ "Strela-1 9P31", "Strela-10M3" }), random = true })
          table.insert(group.units, { veaf.randomlyChooseFrom({ "ZSU-23-4 Shilka", "ZSU-23-4 Shilka", "ZSU_57_2" }), random = true })
        end
      end
    elseif _actualDefense == 2 then
      if side == veafCasMission.SIDE_BLUE then
        table.insert(group.units, { "Gepard", random = true })
        table.insert(group.units, { "Vulcan", random = true })
      else
        table.insert(group.units, { veaf.randomlyChooseFrom({ "ZSU-23-4 Shilka", "ZSU_57_2" }), random = true })
        table.insert(group.units, { veaf.randomlyChooseFrom({ "ZSU-23-4 Shilka", "ZSU_57_2" }), random = true })
      end
    elseif _actualDefense == 1 then
      if side == veafCasMission.SIDE_BLUE then
        table.insert(group.units, { "Vulcan", random = true })
      else
        table.insert(group.units, { veaf.randomlyChooseFrom({ "Ural-375 ZU-23", "ZSU_57_2" }), random = true })
      end
    end
  end
  --veaf.loggers.get(veafCasMission.Id):trace(string.format("group.units=%s", veaf.p(group.units)))
end

--- TODO/feat-era/ Generates an air defense group
function veafCasMission.generateAirDefenseGroup(groupName, defense, side)
  side = side or veafCasMission.SIDE_RED

  -- generate a primary air defense platoon
  local _actualDefense = defense
  if defense > 0 then
    -- roll a dice : 20% chance to get a -1 (lower) difficulty, 30% chance to get a +1 (higher) difficulty, and 50% to get what was asked for
    local _dice = math.random(100)
    veaf.loggers.get(veafCasMission.Id):trace("_dice = " .. _dice)
    if _dice <= 20 then
      _actualDefense = defense - 1
    elseif _dice > 80 then
      _actualDefense = defense + 1
    end
  end
  if _actualDefense > 5 then
    _actualDefense = 5
  end
  if _actualDefense < 0 then
    _actualDefense = 0
  end
  veaf.loggers.get(veafCasMission.Id):trace("_actualDefense = " .. _actualDefense)
  local _groupDefinition = "generateAirDefenseGroup-BLUE-"
  if side == veafCasMission.SIDE_RED then
    _groupDefinition = "generateAirDefenseGroup-RED-"
  end
  _groupDefinition = _groupDefinition .. tostring(_actualDefense)
  veaf.loggers.get(veafCasMission.Id):trace("_groupDefinition = " .. _groupDefinition)

  local group = veafUnits.findGroup(_groupDefinition)
  if not group then
    veaf.loggers
      .get(veafCasMission.Id)
      :error(string.format("veafCasMission.generateAirDefenseGroup cannot find group [%s]", _groupDefinition or ""))
    return nil
  end
  group.description = groupName
  group.groupName = groupName

  veaf.loggers.get(veafCasMission.Id):trace("#group.units = " .. #group.units)
  return group
end

--- Generates a transport company and its air defenses
function veafCasMission.generateTransportCompany(groupName, defense, side, size)
  veaf.loggers.get(veafCasMission.Id):trace(
    string.format(
      "veafCasMission.generateTransportCompany(groupName=[%s], defense=[%s], side=[%s], size=[%s])",
      groupName or "",
      defense or "",
      side or "",
      size or ""
    )
  )
  side = side or veafCasMission.SIDE_RED
  local groupCount = math.floor((size or math.random(10, 15)))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
  local group = {
    disposition = { h = groupCount, w = groupCount },
    units = {},
    description = groupName,
    groupName = groupName,
  }
  -- generate a transport company
  local chooseFrom = veafCasMission.TRANSPORT_TYPES[side][veaf.config.era][0]
  veaf.loggers.get(veafCasMission.Id):trace("chooseFrom=%s", chooseFrom)
  for _ = 1, groupCount do
    local transportType = veaf.randomlyChooseFrom(chooseFrom)
    table.insert(group.units, { transportType, random = true })
  end

  -- TODO/feat-era/ add an air defense vehicle every 10 vehicles
  local nbDefense = groupCount / 10 + 1
  if nbDefense == 0 then
    nbDefense = 1
  end
  veaf.loggers.get(veafCasMission.Id):debug("nbDefense = " .. nbDefense)
  if not veaf.config.ww2 then
    _addDefenseForGroups(group, side, defense, nbDefense)
  else
    -- nothing, there are no mobile defense units in WW2
  end

  return group
end

--- Generates an armor platoon and its air defenses
function veafCasMission.generateArmorPlatoon(groupName, defense, armor, side, size)
  veaf.loggers.get(veafCasMission.Id):trace(
    string.format(
      "veafCasMission.generateArmorPlatoon(groupName=[%s], defense=[%s], armor=[%s], side=[%s], size=[%s])",
      groupName or "",
      defense or "",
      armor or "",
      side or "",
      size or ""
    )
  )
  side = side or veafCasMission.SIDE_RED

  -- generate an armor platoon
  local groupCount = math.floor((size or math.random(3, 6)) * (math.random(8, 12) / 10))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
  local group = {
    disposition = { h = groupCount, w = groupCount },
    units = {},
    description = groupName,
    groupName = groupName,
  }
  if group.disposition.h < 4 then
    group.disposition.h = 4
    group.disposition.w = 4
  end
  local armorBias = 0
  if armor < 0 then
    armor = 0
  end
  if armor > 5 then
    armorBias = armor - 5
    armor = 5
  end

  local chooseFrom = veafCasMission.ARMOR_TYPES[side][veaf.config.era][armor]
  veaf.loggers.get(veafCasMission.Id):trace("chooseFrom=%s", chooseFrom)
  for _ = 1, groupCount do
    local armorType = veaf.randomlyChooseFrom(chooseFrom, armorBias)
    if armorType then
      table.insert(group.units, { armorType, random = true })
    end
  end

  -- TODO/feat-era/ add air defense vehicles
  if not veaf.config.ww2 then
    _addDefenseForGroups(group, side, defense, 1)
  else
    -- nothing, there are no mobile defense units in WW2
  end

  return group
end

--- Generates an infantry group along with its manpad units and tranport vehicles
function veafCasMission.generateInfantryGroup(groupName, defense, armor, side, size)
  side = side or veafCasMission.SIDE_RED
  veaf.loggers
    .get(veafCasMission.Id)
    :trace(string.format("veafCasMission.generateInfantryGroup(groupName=%s, defense=%d, armor=%d)", groupName, defense, armor))
  -- generate an infantry group
  local groupCount = math.floor((size or math.random(3, 6)) * (math.random(8, 12) / 10))
  veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
  local group = {
    disposition = { h = groupCount, w = groupCount },
    units = {},
    description = groupName,
    groupName = groupName,
  }
  if group.disposition.h < 4 then
    group.disposition.h = 4
    group.disposition.w = 4
  end
  local chooseFrom = veafCasMission.INFANTRY_TYPES[side][veaf.config.era]
  veaf.loggers.get(veafCasMission.Id):trace("chooseFrom=%s", chooseFrom)
  for _ = 1, groupCount do
    local unitType = veaf.randomlyChooseFrom(chooseFrom)
    table.insert(group.units, { unitType })
  end

  -- add a transport vehicle or an APC/IFV depending on the side and the era
  chooseFrom = veafCasMission.INFANTRY_IFV_TYPES[side][veaf.config.era][armor]
  veaf.loggers.get(veafCasMission.Id):trace("chooseFrom=%s", chooseFrom)
  local unitType = veaf.randomlyChooseFrom(chooseFrom)
  table.insert(group.units, { unitType, cell = 11, random = true })

  -- TODO/feat-era/ add air defense
  if not veaf.config.ww2 then
    _addDefenseForGroups(group, side, defense, 1, true)
  else
    -- nothing, there are no mobile defense units in WW2
  end

  return group
end

function veafCasMission.placeGroup(groupDefinition, spawnPosition, spacing, resultTable, hasDest)
  if spawnPosition ~= nil and groupDefinition ~= nil then
    veaf.loggers.get(veafCasMission.Id):trace(string.format("veafCasMission.placeGroup(#groupDefinition.units=%d)", #groupDefinition.units))

    -- process the group
    veaf.loggers.get(veafCasMission.Id):trace("process the group")
    local group = veafUnits.processGroup(groupDefinition)

    -- place its units
    local groupPosition = { x = spawnPosition.x, z = spawnPosition.y }
    local hdg = math.random(359)
    local group, cells = veafUnits.placeGroup(group, veaf.placePointOnLand(groupPosition), spacing + 3, hdg, hasDest)
    if veaf.Trace then
      veafUnits.traceGroup(group, cells)
    end

    -- add the units to the result units list
    if not resultTable then
      resultTable = {}
    end
    for _, u in pairs(group.units) do
      table.insert(resultTable, u)
    end
  end
  veaf.loggers.get(veafCasMission.Id):trace(string.format("#resultTable=%d", #resultTable))
  return resultTable
end

--- Generates a complete CAS target group
function veafCasMission.generateCasGroup(casGroupName, spawnSpot, size, defense, armor, spacing, side)
  veaf.loggers.get(veafCasMission.Id):trace("side = " .. tostring(side))
  side = side or veafCasMission.SIDE_RED
  local units = {}
  local zoneRadius = (size + spacing) * 350
  veaf.loggers.get(veafCasMission.Id):trace("zoneRadius = " .. zoneRadius)

  -- generate between size-2 and size+1 infantry groups
  local infantryGroupsCount = math.random(math.max(1, size - 2), size + 1)
  veaf.loggers.get(veafCasMission.Id):trace("infantryGroupsCount = " .. infantryGroupsCount)
  for infantryGroupNumber = 1, infantryGroupsCount do
    local groupName = casGroupName .. " - Infantry Section " .. infantryGroupNumber
    local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
    veaf.loggers
      .get(veafCasMission.Id)
      :trace(string.format("infantry group #%s position : %s", veaf.p(infantryGroupNumber), veaf.p(groupPosition)))
    local group = veafCasMission.generateInfantryGroup(groupName, defense, armor, side)
    veafCasMission.placeGroup(group, groupPosition, spacing, units)
  end

  if armor > 0 then
    -- generate between size-2 and size+1 armor platoons
    local armorPlatoonsCount = math.random(math.max(1, size - 2), size + 1)
    veaf.loggers.get(veafCasMission.Id):trace("armorPlatoonsCount = " .. armorPlatoonsCount)
    for armorGroupNumber = 1, armorPlatoonsCount do
      local groupName = casGroupName .. " - Armor Platoon " .. armorGroupNumber
      local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
      veaf.loggers
        .get(veafCasMission.Id)
        :trace(string.format("armor group #%s position : %s", veaf.p(armorGroupNumber), veaf.p(groupPosition)))
      local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor, side)
      veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end
  end

  if defense > 0 then
    -- generate between 1 and 2 air defense groups
    local airDefenseGroupsCount = 1
    if defense > 3 then
      airDefenseGroupsCount = 2
    end
    veaf.loggers.get(veafCasMission.Id):trace("airDefenseGroupsCount = " .. airDefenseGroupsCount)
    for airDefenseGroupNumber = 1, airDefenseGroupsCount do
      local groupName = casGroupName .. " - Air Defense Group " .. airDefenseGroupNumber
      local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
      veaf.loggers
        .get(veafCasMission.Id)
        :trace(string.format("air defense group #%s position : %s", veaf.p(airDefenseGroupNumber), veaf.p(groupPosition)))
      local group = veafCasMission.generateAirDefenseGroup(groupName, defense, side)
      veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end
  end

  -- generate between 1 and size transport companies
  local transportCompaniesCount = math.random(1, size)
  veaf.loggers.get(veafCasMission.Id):trace("transportCompaniesCount = " .. transportCompaniesCount)
  for transportCompanyGroupNumber = 1, transportCompaniesCount do
    local groupName = casGroupName .. " - Transport Company " .. transportCompanyGroupNumber
    local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
    veaf.loggers
      .get(veafCasMission.Id)
      :trace(string.format("transport group #%s position : %s", veaf.p(transportCompanyGroupNumber), veaf.p(groupPosition)))
    local group = veafCasMission.generateTransportCompany(groupName, defense, side)
    veafCasMission.placeGroup(group, groupPosition, spacing, units)
  end

  return units
end

--- Generates a CAS mission
function veafCasMission.generateCasMission(spawnSpot, size, defense, armor, spacing, disperseOnAttack, side)
  if veafCasMission.groupAliveCheckTaskID ~= "none" then
    trigger.action.outText(veaf.t("cas.target_exists"), 15)
    return
  end
  if side == veafCasMission.SIDE_BLUE then
    veafCasMission.casGroupName = veafCasMission.BlueCasGroupName
  end
  local country = veaf.getCountryForCoalition(side)
  local units = veafCasMission.generateCasGroup(veafCasMission.casGroupName, spawnSpot, size, defense, armor, spacing, side)

  -- prepare the actual DCS units
  local dcsUnits = {}
  for i = 1, #units do
    local unit = units[i]
    local unitType = unit.typeName
    local unitName = veafCasMission.casGroupName .. " / " .. unit.displayName .. " #" .. i
    local unitHdg = unit.hdg

    local spawnPosition = unit.spawnPoint

    -- check if position is correct for the unit type
    if veafUnits.checkPositionForUnit(spawnPosition, unit) then
      local toInsert = {
        ["x"] = spawnPosition.x,
        ["y"] = spawnPosition.z,
        ["alt"] = spawnPosition.y,
        ["type"] = unitType,
        ["name"] = unitName,
        ["speed"] = 0,
        ["skill"] = "Random",
        ["heading"] = unitHdg,
      }
      table.insert(dcsUnits, toInsert)
    end
  end

  -- actually spawn groups
  local spawned =
    veaf.addGroup({ country = country, category = "GROUND_UNIT", name = veafCasMission.casGroupName, hidden = false, units = dcsUnits })

  -- `addGroup` answers false on an unknown country or an empty unit list, and its return used to be
  -- discarded -- which is exactly when the lookup below comes back nil. Both are checked now: the
  -- rest of this function builds a radio menu, a watchdog and an AFAC around a group that does not
  -- exist, so there is nothing to carry on with.
  local casGroup = spawned and Group.getByName(veafCasMission.casGroupName)
  if not casGroup then
    veaf.loggers.get(veafCasMission.Id):warn(
      string.format(
        "generateCasMission: the CAS group [%s] could not be created ; the mission is not started",
        veaf.p(veafCasMission.casGroupName)
      )
    )
    trigger.action.outText(veaf.t("cas.spawn_failed"), 15)
    return
  end

  -- set AI options
  local controller = casGroup:getController()
  controller:setOption(9, 2) -- set alarm state to red
  controller:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, disperseOnAttack) -- set disperse on attack according to the option

  -- Spawn Reaper
  local opposing_side = coalition.side.BLUE
  if coalition.side.RED ~= side then
    opposing_side = coalition.side.RED
  end

  local avgPos = veaf.getAveragePosition(veafCasMission.casGroupName)
  veafCasMission.afacName = veafSpawn.spawnAFAC(
    avgPos,
    "mq9",
    veaf.getCountryForCoalition(opposing_side),
    nil,
    nil,
    nil,
    veafSpawn.convertLaserToFreq(1688),
    "FM",
    1688,
    true,
    false,
    false
  )

  -- build menu for each player
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.casmission.info"),
    veafCasMission.rootPath,
    veafCasMission.reportTargetInformation,
    nil,
    veafRadio.USAGE_ForGroup
  )

  -- add radio menus for commands
  veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.casmission.skip"), veafCasMission.rootPath, veafCasMission.skipCasTarget)
  veafCasMission.targetMarkersPath = veafRadio.addSubMenu(veaf.t("menu.casmission.markers"), veafCasMission.rootPath)
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.casmission.request_smoke"),
    veafCasMission.targetMarkersPath,
    veafCasMission.smokeCasTargetGroup
  )
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.casmission.request_flare"),
    veafCasMission.targetMarkersPath,
    veafCasMission.flareCasTargetGroup
  )

  local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)
  local message = veaf.t("cas.spawn_confirmation", nbVehicles, nbInfantry)
  trigger.action.outText(message, 5)

  veafRadio.refreshRadioMenu()

  -- start checking for targets destruction
  veafCasMission.casGroupWatchdog()
end

-- Ask a report
-- @param int groupId
function veafCasMission.reportTargetInformation(unitName)
  -- generate information dispatch
  local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)

  local message = veaf.t("cas.report_target", nbVehicles, nbInfantry)

  if veafCasMission.afacName then
    message = message .. veaf.t("cas.report_afac", veafCasMission.afacName)
  end

  message = message .. "\n"

  -- add coordinates and position from bullseye
  local averageGroupPosition = veaf.getAveragePosition(veafCasMission.casGroupName)
  ---@cast averageGroupPosition vec3
  local lat, lon = coord.LOtoLL(averageGroupPosition)
  local mgrsString = veaf.toStringMGRS(coord.LLtoMGRS(lat, lon), 3)
  local bullseyeData = veaf.getBullseye("blue") -- default to blue
  local requestingUnit = Unit.getByName(unitName)
  if requestingUnit and requestingUnit:getCoalition() == coalition.side.RED then
    bullseyeData = veaf.getBullseye("red")
  end
  -- `getBullseye` answers nil for a side the mission declares no bullseye for, and `makeVec3` reads
  -- `vec.z` straight away, so the report used to raise one line *before* the `need-check-nil` that was
  -- silencing the linter here. The three other lines of the report do not need a bullseye, so only
  -- that one is dropped.
  local bullseye = bullseyeData and veaf.makeVec3(bullseyeData, 0)

  message = message .. veaf.t("cas.report_latlon_decimal", veaf.toStringLL(lat, lon, 2))
  message = message .. veaf.t("cas.report_latlon_dms", veaf.toStringLL(lat, lon, 0, true))
  message = message .. veaf.t("cas.report_mgrs", mgrsString)
  if bullseye then
    local vec =
      { x = averageGroupPosition.x - bullseye.x, y = averageGroupPosition.y - bullseye.y, z = averageGroupPosition.z - bullseye.z }
    local dir = veaf.round(math.deg(veaf.getDir(vec, bullseye)), 0)
    local dist = veaf.get2DDist(averageGroupPosition, bullseye)
    local distMetric = veaf.round(dist / 1000, 0)
    local distImperial = veaf.round(veaf.metersToNM(dist), 0)
    local fromBullseye = veaf.t("cas.report_bullseye_value", dir, distMetric, distImperial)
    message = message .. veaf.t("cas.report_bullseye", fromBullseye)
  else
    veaf.loggers
      .get(veafCasMission.Id)
      :warn("reportTargetInformation: the mission declares no bullseye for this side ; the report omits it")
  end
  message = message .. "\n"

  message = message .. veaf.t("cas.report_weather_header") .. veafWeatherData.getWeatherString(averageGroupPosition, unitName)

  -- send message only for the unit
  veaf.outTextForGroup(unitName, message, 30)
end

--- add a smoke marker over the target area
function veafCasMission.smokeCasTargetGroup()
  veaf.loggers.get(veafCasMission.Id):trace("veafCasMission.smokeCasTargetGroup START")
  veafSpawn.spawnSmoke(veaf.getAveragePosition(veafCasMission.casGroupName), trigger.smokeColor.Red)
  trigger.action.outText(veaf.t("cas.smoke_requested"), 5)
  veafRadio.delCommand(veafCasMission.targetMarkersPath, "Request smoke on target area")
  veafRadio.addCommandToSubmenu(veaf.t("menu.casmission.smoke_done"), veafCasMission.targetMarkersPath, veaf.emptyFunction)
  veafCasMission.smokeResetTaskID =
    veaf.scheduleFunction(veafCasMission.smokeReset, {}, timer.getTime() + veafCasMission.SecondsBetweenSmokeRequests)
  veafRadio.refreshRadioMenu()
end

--- Reset the smoke request radio menu
function veafCasMission.smokeReset()
  veafRadio.delCommand(veafCasMission.targetMarkersPath, "Target is marked with red smoke")
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.casmission.request_smoke"),
    veafCasMission.targetMarkersPath,
    veafCasMission.smokeCasTargetGroup
  )
  trigger.action.outText(veaf.t("cas.smoke_available"), 5)
  veafRadio.refreshRadioMenu()
end

--- add an illumination flare over the target area
function veafCasMission.flareCasTargetGroup()
  veafSpawn.spawnIlluminationFlare(veaf.getAveragePosition(veafCasMission.casGroupName))
  trigger.action.outText(veaf.t("cas.illum_requested"), 5)
  veafRadio.delCommand(veafCasMission.targetMarkersPath, "Request illumination flare over target area")
  veafRadio.addCommandToSubmenu(veaf.t("menu.casmission.flare_done"), veafCasMission.targetMarkersPath, veaf.emptyFunction)
  veafCasMission.flareResetTaskID =
    veaf.scheduleFunction(veafCasMission.flareReset, {}, timer.getTime() + veafCasMission.SecondsBetweenFlareRequests)
  veafRadio.refreshRadioMenu()
end

--- Reset the flare request radio menu
function veafCasMission.flareReset()
  veafRadio.delCommand(veafCasMission.targetMarkersPath, "Target area is marked with illumination flare")
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.casmission.request_flare"),
    veafCasMission.targetMarkersPath,
    veafCasMission.flareCasTargetGroup
  )
  trigger.action.outText(veaf.t("cas.illum_available"), 5)
  veafRadio.refreshRadioMenu()
end

--- Checks if the vehicles group is still alive, and if not announces the end of the CAS mission
function veafCasMission.casGroupWatchdog()
  local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)
  if nbVehicles > 0 then
    veaf.loggers.get(veafCasMission.Id):trace("Group is still alive with " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers")
    veafCasMission.groupAliveCheckTaskID =
      veaf.scheduleFunction(veafCasMission.casGroupWatchdog, {}, timer.getTime() + veafCasMission.SecondsBetweenWatchdogChecks)
  else
    trigger.action.outText(veaf.t("cas.objective_destroyed"), 5)
    veafCasMission.cleanupAfterMission()
  end
end

--- Called from the "Skip target" radio menu : remove the current CAS target group
function veafCasMission.skipCasTarget()
  veafCasMission.cleanupAfterMission()
  trigger.action.outText(veaf.t("cas.objective_cleaned"), 5)
end

--- Cleanup after either mission is ended or aborted
function veafCasMission.cleanupAfterMission()
  veaf.loggers.get(veafCasMission.Id):trace("skipCasTarget START")

  -- destroy vehicles and infantry groups
  veaf.loggers.get(veafCasMission.Id):trace("destroy CAS group")
  local group = Group.getByName(veafCasMission.casGroupName)
  if group and group:isExist() == true then
    group:destroy()
  end
  veaf.loggers.get(veafCasMission.Id):trace("destroy AFAC group")
  group = Group.getByName(veafCasMission.afacName)
  if group and group:isExist() == true then
    group:destroy()
  end
  veafCasMission.afacName = nil

  -- remove the watchdog function
  veaf.loggers.get(veafCasMission.Id):trace("remove the watchdog function")
  if veafCasMission.groupAliveCheckTaskID ~= "none" then
    veaf.removeFunction(veafCasMission.groupAliveCheckTaskID)
  end
  veafCasMission.groupAliveCheckTaskID = "none"

  veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 1")
  veafRadio.delCommand(veafCasMission.rootPath, "Target information")

  veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 2")
  veafRadio.delCommand(veafCasMission.rootPath, "Skip current objective")
  veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 3")
  veafRadio.delCommand(veafCasMission.rootPath, "Get current objective situation")
  veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 4")
  veafRadio.delSubmenu(veafCasMission.targetMarkersPath, veafCasMission.rootPath)

  veafRadio.refreshRadioMenu()
  veaf.loggers.get(veafCasMission.Id):trace("skipCasTarget DONE")
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCasMission.buildRadioMenu()
  veafCasMission.rootPath = veafRadio.addSubMenu(veaf.t(veafCasMission.RadioMenuName))
  if not veafRadio.skipHelpMenus then
    veafRadio.addCommandToSubmenu(veaf.t("menu.common.help"), veafCasMission.rootPath, veafCasMission.help, nil, veafRadio.USAGE_ForGroup)
  end
end

function veafCasMission.help(unitName)
  local text = veaf.t("cas.help")

  veaf.outTextForGroup(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCasMission.initialize()
  veafCasMission.buildRadioMenu()
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    -- Markers spawn the CAS target for the opposing side by default.
    local spawnSide = fromMarker and veaf.getOppositeCoalition(event.coalition) or event.coalition
    return veafCasMission.executeCommand(pos, event.text, spawnSide, event.idx, bypass)
  end, veafCommands.PRIORITY_CASMISSION, veafCommands.SECURITY_HANDLED)
end

veaf.loggers.get(veafCasMission.Id):info(veaf.loggers.get(veafCasMission.Id):getVersionInfo())

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.registerModule(veafCasMission.Id, veafCasMission.initialize, { enable = true }, 90)
