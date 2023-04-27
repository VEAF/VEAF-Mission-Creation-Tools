---@diagnostic disable: lowercase-global
-- DEFINE THE PRESETS (CRYSTALLISATION) HERE AND REFER TO IT LATER IN THE FILE
-- THIS IS THE MAIN TABLE OF PRESETS. 
-- E.G. [1]  = radioPresets["##RADIO1_01##"],
--
-- THIS SHOULD BE THE ONLY PART OF THIS FILE YOU'LL NEED TO CHANGE IF YOU ONLY CHANGE THE FREQUENCIES
-- TO ADD OR CHANGE AIRCRAFT AND COALITION TEMPLATES, SEE FURTHER BELOW
radioPresetsBlue =
{
    -- radio 1 : left radio, red radio, UHF radio (Default range is 225MHz to 390MHz)
    ["##RADIO1_01##"] = 243.000,
    ["##RADIO1_02##"] = 260.000,
    ["##RADIO1_03##"] = 270.000,
    ["##RADIO1_04##"] = 259.000,
    ["##RADIO1_05##"] = 263.000,
    ["##RADIO1_06##"] = 256.000,
    ["##RADIO1_07##"] = 258.000,
    ["##RADIO1_08##"] = 267.000,
    ["##RADIO1_09##"] = 269.000,
    ["##RADIO1_10##"] = 225.000,
    ["##RADIO1_11##"] = 226.000,
    ["##RADIO1_12##"] = 227.000,
    ["##RADIO1_13##"] = 228.000,
    ["##RADIO1_14##"] = 282.200,
    ["##RADIO1_15##"] = 291.000,
    ["##RADIO1_16##"] = 305.100,
    ["##RADIO1_17##"] = 290.100,
    ["##RADIO1_18##"] = 290.300,
    ["##RADIO1_19##"] = 290.400,
    ["##RADIO1_20##"] = 290.500,

    -- radio 2 : right radio, green radio, VHF radio (Default range is 118MHz to 150MHz)
    ["##RADIO2_01##"] = 121.500,
    ["##RADIO2_02##"] = 120.000,
    ["##RADIO2_03##"] = 120.100,
    ["##RADIO2_04##"] = 120.200,
    ["##RADIO2_05##"] = 120.300,
    ["##RADIO2_06##"] = 120.400,
    ["##RADIO2_07##"] = 120.500,
    ["##RADIO2_08##"] = 120.600,
    ["##RADIO2_09##"] = 120.700,
    ["##RADIO2_10##"] = 120.800,
    ["##RADIO2_11##"] = 120.900,
    ["##RADIO2_12##"] = 121.100,
    ["##RADIO2_13##"] = 121.200,
    ["##RADIO2_14##"] = 121.300,
    ["##RADIO2_15##"] = 121.400,
    ["##RADIO2_16##"] = 121.600,
    ["##RADIO2_17##"] = 121.700,
    ["##RADIO2_18##"] = 118.800,
    ["##RADIO2_19##"] = 118.900,
    ["##RADIO2_20##"] = 118.850,

    -- radio 3 : FM radio (Default range is 20MHz (Russian Aircrafts) or 30MHz (NATO) to 59MHz (Russian aircrafts) or 87MHz (NATO))
    ["##RADIO3_01##"] = 30.000,
    ["##RADIO3_02##"] = 31.000,
    ["##RADIO3_03##"] = 32.000,
    ["##RADIO3_04##"] = 33.000,
    ["##RADIO3_05##"] = 34.000,
    ["##RADIO3_06##"] = 35.000,
    ["##RADIO3_07##"] = 36.000,
    ["##RADIO3_08##"] = 37.000,
    ["##RADIO3_09##"] = 38.000,
    ["##RADIO3_10##"] = 39.000,
    ["##RADIO3_11##"] = 40.000,
    ["##RADIO3_12##"] = 41.000,
    ["##RADIO3_13##"] = 42.000,
    ["##RADIO3_14##"] = 43.000,
    ["##RADIO3_15##"] = 44.000,
    ["##RADIO3_16##"] = 45.000,
    ["##RADIO3_17##"] = 46.000,
    ["##RADIO3_18##"] = 47.000,
    ["##RADIO3_19##"] = 48.000,
    ["##RADIO3_20##"] = 49.000,
    ["##RADIO3_21##"] = 50.000,
    ["##RADIO3_22##"] = 51.000,
    ["##RADIO3_23##"] = 52.000,
    ["##RADIO3_24##"] = 53.000,
    ["##RADIO3_25##"] = 54.000,
    ["##RADIO3_26##"] = 55.000,
    ["##RADIO3_27##"] = 56.000,
    ["##RADIO3_28##"] = 57.000,
    ["##RADIO3_29##"] = 58.000,
    ["##RADIO3_30##"] = 59.000,
}

radioPresetsRed =
{
    -- radio 1 : left radio, red radio, UHF radio (Default range is 225MHz to 390MHz)
    ["##RADIO1_01##"] = 243.000,
    ["##RADIO1_02##"] = 260.000,
    ["##RADIO1_03##"] = 270.000,
    ["##RADIO1_04##"] = 259.000,
    ["##RADIO1_05##"] = 263.000,
    ["##RADIO1_06##"] = 256.000,
    ["##RADIO1_07##"] = 258.000,
    ["##RADIO1_08##"] = 267.000,
    ["##RADIO1_09##"] = 269.000,
    ["##RADIO1_10##"] = 225.000,
    ["##RADIO1_11##"] = 226.000,
    ["##RADIO1_12##"] = 227.000,
    ["##RADIO1_13##"] = 228.000,
    ["##RADIO1_14##"] = 282.200,
    ["##RADIO1_15##"] = 291.000,
    ["##RADIO1_16##"] = 305.100,
    ["##RADIO1_17##"] = 290.100,
    ["##RADIO1_18##"] = 290.300,
    ["##RADIO1_19##"] = 290.400,
    ["##RADIO1_20##"] = 290.500,

    -- radio 2 : right radio, green radio, VHF radio (Default range is 118MHz to 150MHz)
    ["##RADIO2_01##"] = 121.500,
    ["##RADIO2_02##"] = 120.000,
    ["##RADIO2_03##"] = 120.100,
    ["##RADIO2_04##"] = 120.200,
    ["##RADIO2_05##"] = 120.300,
    ["##RADIO2_06##"] = 120.400,
    ["##RADIO2_07##"] = 120.500,
    ["##RADIO2_08##"] = 120.600,
    ["##RADIO2_09##"] = 120.700,
    ["##RADIO2_10##"] = 120.800,
    ["##RADIO2_11##"] = 120.900,
    ["##RADIO2_12##"] = 121.100,
    ["##RADIO2_13##"] = 121.200,
    ["##RADIO2_14##"] = 121.300,
    ["##RADIO2_15##"] = 121.400,
    ["##RADIO2_16##"] = 121.600,
    ["##RADIO2_17##"] = 121.700,
    ["##RADIO2_18##"] = 118.800,
    ["##RADIO2_19##"] = 118.900,
    ["##RADIO2_20##"] = 118.850,

    -- radio 3 : FM radio (Default range is 20MHz (Russian Aircrafts) or 30MHz (NATO) to 59MHz (Russian aircrafts) or 87MHz (NATO))
    ["##RADIO3_01##"] = 30.000,
    ["##RADIO3_02##"] = 31.000,
    ["##RADIO3_03##"] = 32.000,
    ["##RADIO3_04##"] = 33.000,
    ["##RADIO3_05##"] = 34.000,
    ["##RADIO3_06##"] = 35.000,
    ["##RADIO3_07##"] = 36.000,
    ["##RADIO3_08##"] = 37.000,
    ["##RADIO3_09##"] = 38.000,
    ["##RADIO3_10##"] = 39.000,
    ["##RADIO3_11##"] = 40.000,
    ["##RADIO3_12##"] = 41.000,
    ["##RADIO3_13##"] = 42.000,
    ["##RADIO3_14##"] = 43.000,
    ["##RADIO3_15##"] = 44.000,
    ["##RADIO3_16##"] = 45.000,
    ["##RADIO3_17##"] = 46.000,
    ["##RADIO3_18##"] = 47.000,
    ["##RADIO3_19##"] = 48.000,
    ["##RADIO3_20##"] = 49.000,
    ["##RADIO3_21##"] = 50.000,
    ["##RADIO3_22##"] = 51.000,
    ["##RADIO3_23##"] = 52.000,
    ["##RADIO3_24##"] = 53.000,
    ["##RADIO3_25##"] = 54.000,
    ["##RADIO3_26##"] = 55.000,
    ["##RADIO3_27##"] = 56.000,
    ["##RADIO3_28##"] = 57.000,
    ["##RADIO3_29##"] = 58.000,
    ["##RADIO3_30##"] = 59.000,
}

radioPresetsWarbirdBlue = {
    --Axis
    ["##RADIO_FuG16_01##"] = 39.000,
    ["##RADIO_FuG16_02##"] = 38.400,
    ["##RADIO_FuG16_03##"] = 41.000,
    ["##RADIO_FuG16_04##"] = 42.000,
    ["##RADIO_FuG16_BASE##"] = 38.400,
}

radioPresetsWarbirdRed = {
    --Axis
    ["##RADIO_FuG16_01##"] = 39.000,
    ["##RADIO_FuG16_02##"] = 38.400,
    ["##RADIO_FuG16_03##"] = 41.000,
    ["##RADIO_FuG16_04##"] = 42.000,
    ["##RADIO_FuG16_BASE##"] = 38.400,
}

-- THIS IS THE TABLE OF RADIO SETTINGS. 
-- MAKE USE OF THE RADIO PRESETS DEFINED EARLIER IF YOU WANT
-- BY SETTING THE VALUE OF THE type, coalition, AND country PARAMETERS, YOU CAN TARGET A TEMPLATE TO A SPECIFIC GROUP OF AIRCRAFTS
radioSettings =
{
    -----------------------------------------------------------------------------------------------------------------------------
    --prop planes
    -----------------------------------------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------------------------------------
    --warbirds
    ["blue Bf-109K-4"] = {
        type = "Bf-109K-4",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdBlue["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdBlue["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdBlue["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdBlue["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red Bf-109K-4"] = {
        type = "Bf-109K-4",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdRed["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdRed["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdRed["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdRed["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdRed["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue FW-190D9"] = {
        type = "FW-190D9",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdBlue["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdBlue["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdBlue["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdBlue["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red FW-190D9"] = {
        type = "FW-190D9",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdRed["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdRed["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdRed["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdRed["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdRed["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue FW-190A8"] = {
        type = "FW-190A8",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdBlue["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdBlue["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdBlue["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdBlue["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red FW-190A8"] = {
        type = "FW-190A8",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 38-42MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = radioPresetsWarbirdRed["##RADIO_FuG16_01##"],
                    [2] = radioPresetsWarbirdRed["##RADIO_FuG16_02##"],
                    [3] = radioPresetsWarbirdRed["##RADIO_FuG16_03##"],
                    [4] = radioPresetsWarbirdRed["##RADIO_FuG16_04##"],
                    [5] = radioPresetsWarbirdRed["##RADIO_FuG16_BASE##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue I-16"] = {
        type = "I-16",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red I-16"] = {
        type = "I-16",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue MosquitoFBMkVI"] = {
        type = "MosquitoFBMkVI",
        coalition = "blue",
        country = nil,
        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
            --HF (range 5.5-10MHz) with modulation selection box (but no modulation selection in the ME)
            [2] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 9.255,
                    [2] = 8,
                    [3] = 7.71,
                    [4] = 6.872,
                    [5] = 5.955,
                    [6] = 5.85,
                    [7] = 5.75,
                    [8] = 5.65,
                }, -- end of ["channels"]
            }, -- end of [2]
            --HF (range 3-5.5MHz) with modulation selection box (but no modulation selection in the ME)
            [3] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 5.25,
                    [2] = 5,
                    [3] = 4.75,
                    [4] = 4.5,
                    [5] = 4.25,
                    [6] = 3.25,
                    [7] = 3.012,
                    [8] = 3.011,
                }, -- end of ["channels"]
            }, -- end of [3]
            --LF/MF (range 0.2-0.5MHz) with modulation selection box (but no modulation selection in the ME)
            [4] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 0.444,
                    [2] = 0.421,
                    [3] = 0.303,
                    [4] = 0.3,
                    [5] = 0.27,
                    [6] = 0.26,
                    [7] = 0.25,
                    [8] = 0.24,
                }, -- end of ["channels"]
            }, -- end of [4]
        }, -- end of ["Radio"]
    },

    ["red MosquitoFBMkVI"] = {
        type = "MosquitoFBMkVI",
        coalition = "red",
        country = nil,
        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
            --HF (range 5.5-10MHz) with modulation selection box (but no modulation selection in the ME)
            [2] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 9.255,
                    [2] = 8,
                    [3] = 7.71,
                    [4] = 6.872,
                    [5] = 5.955,
                    [6] = 5.85,
                    [7] = 5.75,
                    [8] = 5.65,
                }, -- end of ["channels"]
            }, -- end of [2]
            --HF (range 3-5.5MHz) with modulation selection box (but no modulation selection in the ME)
            [3] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 5.25,
                    [2] = 5,
                    [3] = 4.75,
                    [4] = 4.5,
                    [5] = 4.25,
                    [6] = 3.25,
                    [7] = 3.012,
                    [8] = 3.011,
                }, -- end of ["channels"]
            }, -- end of [3]
            --LF/MF (range 0.2-0.5MHz) with modulation selection box (but no modulation selection in the ME)
            [4] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 0.444,
                    [2] = 0.421,
                    [3] = 0.303,
                    [4] = 0.3,
                    [5] = 0.27,
                    [6] = 0.26,
                    [7] = 0.25,
                    [8] = 0.24,
                }, -- end of ["channels"]
            }, -- end of [4]
        }, -- end of ["Radio"]
    },

    ["blue P-47D-30"] = {
        type = "P-47D-30",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red P-47D-30"] = {
        type = "P-47D-30",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue P-47D-30bl1"] = {
        type = "P-47D-30bl1",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red P-47D-30bl1"] = {
        type = "P-47D-30bl1",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue P-47D-40"] = {
        type = "P-47D-40",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red P-47D-40"] = {
        type = "P-47D-40",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue P-51D-25-NA"] = {
        type = "P-51D",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red P-51D-25-NA"] = {
        type = "P-51D",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue P-51D-30-NA"] = {
        type = "P-51D-30-NA",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red P-51D-30-NA"] = {
        type = "P-51D-30-NA",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue TF-51D"] = {
        type = "TF-51D",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red TF-51D"] = {
        type = "TF-51D",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --Radio Beacon Finder Base frequency (range 100-200MHz)
            [2] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue SpitfireLFMkIX"] = {
        type = "SpitfireLFMkIX",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red SpitfireLFMkIX"] = {
        type = "SpitfireLFMkIX",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue SpitfireLFMkIXCW"] = {
        type = "SpitfireLFMkIXCW",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red SpitfireLFMkIXCW"] = {
        type = "SpitfireLFMkIXCW",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (range 100-156MHz) without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = 108.9,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    -----------------------------------------------------------------------------------------------------------------------------
    --tourist planes

    ["blue Christen Eagle II"] = {
        type = "Christen Eagle II",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF with modulation selection box (but no modulation selection in ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red Christen Eagle II"] = {
        type = "Christen Eagle II",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF with modulation selection box (but no modulation selection in ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue Yak-52"] = {
        type = "Yak-52",
        coalition = "blue",
        country = nil,

        --ARK-15M ADF (Range 0.1-1.795MHz)
        ["Radio"] = 
        {
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 0.625,
                    [2] = 0.303,
                    [3] = 0.289,
                    [4] = 0.591,
                    [5] = 0.408,
                    [6] = 0.803,
                    [7] = 0.443,
                    [8] = 0.215,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red Yak-52"] = {
        type = "Yak-52",
        coalition = "red",
        country = nil,

        --ARK-15M ADF (Range 0.1-1.795MHz)
        ["Radio"] = 
        {
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1] = 0.625,
                    [2] = 0.303,
                    [3] = 0.289,
                    [4] = 0.591,
                    [5] = 0.408,
                    [6] = 0.803,
                    [7] = 0.443,
                    [8] = 0.215,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    -----------------------------------------------------------------------------------------------------------------------------
    --jets
    -----------------------------------------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------------------------------------
    --ww2

    --["blue Me-262"] = {}, --ED plz

    --["red Me-262"] = {}, --ED plz

    --["blue Meteor F.3"] = {}, --ED plz

    --["red Meteor F.3"] = {}, --ED plz

    -----------------------------------------------------------------------------------------------------------------------------
    --korea

    ["blue F-86F Sabre"] = {
        type = "F-86F Sabre",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --UHF without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red F-86F Sabre"] = {
        type = "F-86F Sabre",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --UHF without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    --["blue MiG-15Bis"] = {}, --no presets

    --["red MiG-15Bis"] = {}, --no presets

    -----------------------------------------------------------------------------------------------------------------------------
    --cold war

    ["blue AJS37"] = {
        type = "AJS37",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF (down to 103MHz) with modulation selection box (but no modulation selection in the ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                    [31] = 0,
                    [32] = 0,
                    [33] = 0,
                    [34] = 0,
                    [35] = 0,
                    [36] = 0,
                    [37] = 0,
                    [38] = 0,
                    [39] = 0,
                    [40] = 0,
                    [41] = 1,
                    [42] = 1,
                    [43] = 1,
                    [44] = 1,
                    [45] = 1,
                    [46] = 0,
                    [47] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                    [21]  = radioPresetsBlue["##RADIO2_01##"],
                    [22]  = radioPresetsBlue["##RADIO2_02##"],
                    [23]  = radioPresetsBlue["##RADIO2_03##"],
                    [24]  = radioPresetsBlue["##RADIO2_04##"],
                    [25]  = radioPresetsBlue["##RADIO2_05##"],
                    [26]  = radioPresetsBlue["##RADIO2_06##"],
                    [27]  = radioPresetsBlue["##RADIO2_07##"],
                    [28]  = radioPresetsBlue["##RADIO2_08##"],
                    [29]  = radioPresetsBlue["##RADIO2_09##"],
                    [30] = radioPresetsBlue["##RADIO2_10##"],
                    [31] = radioPresetsBlue["##RADIO2_11##"],
                    [32] = radioPresetsBlue["##RADIO2_12##"],
                    [33] = radioPresetsBlue["##RADIO2_13##"],
                    [34] = radioPresetsBlue["##RADIO2_14##"],
                    [35] = radioPresetsBlue["##RADIO2_15##"],
                    [36] = radioPresetsBlue["##RADIO2_16##"],
                    [37] = radioPresetsBlue["##RADIO2_17##"],
                    [38] = radioPresetsBlue["##RADIO2_18##"],
                    [39] = radioPresetsBlue["##RADIO2_19##"],
                    [40] = radioPresetsBlue["##RADIO2_20##"],
                    [41] = 30,
                    [42] = 31,
                    [43] = 32,
                    [44] = 33,
                    [45] = 34,
                    [46] = 127.5,
                    [47] = 243,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red AJS37"] = {
        type = "AJS37",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF (down to 103MHz) with modulation selection box (but no modulation selection in the ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                    [31] = 0,
                    [32] = 0,
                    [33] = 0,
                    [34] = 0,
                    [35] = 0,
                    [36] = 0,
                    [37] = 0,
                    [38] = 0,
                    [39] = 0,
                    [40] = 0,
                    [41] = 1,
                    [42] = 1,
                    [43] = 1,
                    [44] = 1,
                    [45] = 1,
                    [46] = 0,
                    [47] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                    [21]  = radioPresetsRed["##RADIO2_01##"],
                    [22]  = radioPresetsRed["##RADIO2_02##"],
                    [23]  = radioPresetsRed["##RADIO2_03##"],
                    [24]  = radioPresetsRed["##RADIO2_04##"],
                    [25]  = radioPresetsRed["##RADIO2_05##"],
                    [26]  = radioPresetsRed["##RADIO2_06##"],
                    [27]  = radioPresetsRed["##RADIO2_07##"],
                    [28]  = radioPresetsRed["##RADIO2_08##"],
                    [29]  = radioPresetsRed["##RADIO2_09##"],
                    [30] = radioPresetsRed["##RADIO2_10##"],
                    [31] = radioPresetsRed["##RADIO2_11##"],
                    [32] = radioPresetsRed["##RADIO2_12##"],
                    [33] = radioPresetsRed["##RADIO2_13##"],
                    [34] = radioPresetsRed["##RADIO2_14##"],
                    [35] = radioPresetsRed["##RADIO2_15##"],
                    [36] = radioPresetsRed["##RADIO2_16##"],
                    [37] = radioPresetsRed["##RADIO2_17##"],
                    [38] = radioPresetsRed["##RADIO2_18##"],
                    [39] = radioPresetsRed["##RADIO2_19##"],
                    [40] = radioPresetsRed["##RADIO2_20##"],
                    [41] = 30,
                    [42] = 31,
                    [43] = 32,
                    [44] = 33,
                    [45] = 34,
                    [46] = 127.5,
                    [47] = 243,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue A-4E-C"] = {
        type = "A-4E-C",
        coalition = "blue",
        country = nil,
        
        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["red A-4E-C"] = {
        type = "A-4E-C",
        coalition = "red",
        country = nil,
        
        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["blue F-5E-3"] = {
        type = "F-5E-3",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --UHF without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red F-5E-3"] = {
        type = "F-5E-3",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --UHF without modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue MiG-19P"] = {
        type = "MiG-19P",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --VHF (down to 100MHz) with modulation selection box (but no modulation selection in the ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red MiG-19P"] = {
        type = "MiG-19P",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --VHF (down to 100MHz) with modulation selection box (but no modulation selection in the ME)
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue MiG-21Bis"] = {
        type = "MiG-21Bis",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] = {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red MiG-21Bis"] = {
        type = "MiG-21Bis",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] = {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue Mirage-F1CE"] = {
        type = "Mirage-F1CE",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --UHF without modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["red Mirage-F1CE"] = {
        type = "Mirage-F1CE",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --UHF without modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

      ["blue Mirage-F1EE"] = {
        type = "Mirage-F1EE",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --UHF without modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["red Mirage-F1EE"] = {
        type = "Mirage-F1EE",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --UHF without modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    -----------------------------------------------------------------------------------------------------------------------------
    --modern

    ["blue A-10C"] = {
        type = "A-10C_2",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --Digital V/UHF 
            [1] = {
                ["channels"] = {
                    [01] = radioPresetsBlue["##RADIO2_01##"],
                    [02] = radioPresetsBlue["##RADIO2_02##"],
                    [03] = radioPresetsBlue["##RADIO2_03##"],
                    [04] = radioPresetsBlue["##RADIO2_04##"],
                    [05] = radioPresetsBlue["##RADIO2_05##"],
                    [06] = radioPresetsBlue["##RADIO2_06##"],
                    [07] = radioPresetsBlue["##RADIO2_07##"],
                    [08] = radioPresetsBlue["##RADIO2_08##"],
                    [09] = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
            }, -- end of [1]
            --UHF 
            [2] = {
                ["channels"] = {
                    [01] = radioPresetsBlue["##RADIO1_01##"],
                    [02] = radioPresetsBlue["##RADIO1_02##"],
                    [03] = radioPresetsBlue["##RADIO1_03##"],
                    [04] = radioPresetsBlue["##RADIO1_04##"],
                    [05] = radioPresetsBlue["##RADIO1_05##"],
                    [06] = radioPresetsBlue["##RADIO1_06##"],
                    [07] = radioPresetsBlue["##RADIO1_07##"],
                    [08] = radioPresetsBlue["##RADIO1_08##"],
                    [09] = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
            }, -- end of [2]
            --VHF FM
            [3] = {
                ["channels"] = {
                    [01] = radioPresetsBlue["##RADIO3_01##"],
                    [02] = radioPresetsBlue["##RADIO3_02##"],
                    [03] = radioPresetsBlue["##RADIO3_03##"],
                    [04] = radioPresetsBlue["##RADIO3_04##"],
                    [05] = radioPresetsBlue["##RADIO3_05##"],
                    [06] = radioPresetsBlue["##RADIO3_06##"],
                    [07] = radioPresetsBlue["##RADIO3_07##"],
                    [08] = radioPresetsBlue["##RADIO3_08##"],
                    [09] = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                    [11] = radioPresetsBlue["##RADIO3_11##"],
                    [12] = radioPresetsBlue["##RADIO3_12##"],
                    [13] = radioPresetsBlue["##RADIO3_13##"],
                    [14] = radioPresetsBlue["##RADIO3_14##"],
                    [15] = radioPresetsBlue["##RADIO3_15##"],
                    [16] = radioPresetsBlue["##RADIO3_16##"],
                    [17] = radioPresetsBlue["##RADIO3_17##"],
                    [18] = radioPresetsBlue["##RADIO3_18##"],
                    [19] = radioPresetsBlue["##RADIO3_19##"],
                    [20] = radioPresetsBlue["##RADIO3_20##"],
                    [21] = 50,
                    [22] = 51,
                    [23] = 52,
                    [24] = 53,
                    [25] = 54,
                    [26] = 55,
                    [27] = 56,
                    [28] = 57,
                    [29] = 58,
                    [30] = 59,
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 1,
                    [2] = 1,
                    [3] = 1,
                    [4] = 1,
                    [5] = 1,
                    [6] = 1,
                    [7] = 1,
                    [8] = 1,
                    [9] = 1,
                    [10] = 1,
                    [11] = 1,
                    [12] = 1,
                    [13] = 1,
                    [14] = 1,
                    [15] = 1,
                    [16] = 1,
                    [17] = 1,
                    [18] = 1,
                    [19] = 1,
                    [20] = 1,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
            }, -- end of [3]
        }, -- end of ["Radio"]
    },

    --["red A-10C"] = {}, --no presets

    --["blue A-10CII"] = {}, --no presets

    --["red A-10CII"] = {}, --no presets

    ["blue F-14A-135-GR"] = {
        type = "F-14A-135-GR",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red F-14A-135-GR"] = {
        type = "F-14A-135-GR",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue F-14B"] = {
        type = "F-14B",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red F-14B"] = {
        type = "F-14B",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --UHF without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },
    
    ["blue FA-18C_hornet"] = {
        type = "FA-18C_hornet",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF (down to 30MHz) with modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["red FA-18C_hornet"] = {
        type = "FA-18C_hornet",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF (down to 30MHz) with modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["blue F-16C"] = {
        type = "F-16C_50",
        coalition = "blue",
        country = nil,
        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --VHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["red F-16C"] = {
        type = "F-16C_50",
        coalition = "red",
        country = nil,
        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --VHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["blue Harrier"] = {
        type = "AV8BNA",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [3] =
            {
                ["modulations"] =
                {
                    [1] =  1,
                    [2] =  1,
                    [3] =  1,
                    [4] =  1,
                    [5] =  1,
                    [6] =  1,
                    [7] =  1,
                    [8] =  1,
                    [9] =  1,
                    [10] = 1,
                    [11] = 1,
                    [12] = 1,
                    [13] = 1,
                    [14] = 1,
                    [15] = 1,
                    [16] = 1,
                    [17] = 1,
                    [18] = 1,
                    [19] = 1,
                    [20] = 1,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                    [11] = radioPresetsBlue["##RADIO3_11##"],
                    [12] = radioPresetsBlue["##RADIO3_12##"],
                    [13] = radioPresetsBlue["##RADIO3_13##"],
                    [14] = radioPresetsBlue["##RADIO3_14##"],
                    [15] = radioPresetsBlue["##RADIO3_15##"],
                    [16] = radioPresetsBlue["##RADIO3_16##"],
                    [17] = radioPresetsBlue["##RADIO3_17##"],
                    [18] = radioPresetsBlue["##RADIO3_18##"],
                    [19] = radioPresetsBlue["##RADIO3_19##"],
                    [20] = radioPresetsBlue["##RADIO3_20##"],
                    [21] = radioPresetsBlue["##RADIO3_21##"],
                    [22] = radioPresetsBlue["##RADIO3_22##"],
                    [23] = radioPresetsBlue["##RADIO3_23##"],
                    [24] = radioPresetsBlue["##RADIO3_24##"],
                    [25] = radioPresetsBlue["##RADIO3_25##"],
                    [26] = radioPresetsBlue["##RADIO3_26##"],
                    [27] = radioPresetsBlue["##RADIO3_27##"],
                    [28] = radioPresetsBlue["##RADIO3_28##"],
                    [29] = radioPresetsBlue["##RADIO3_29##"],
                    [30] = radioPresetsBlue["##RADIO3_30##"],
                }, -- end of ["channels"]
            }, -- end of [3]
        },
    },

    ["red Harrier"] = {
        type = "AV8BNA",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                }, -- end of ["channels"]
            }, -- end of [2]
            --V/UHF (down to 30MHz) with modulation selection box (but no modulation selection in the ME)
            [3] =
            {
                ["modulations"] =
                {
                    [1] =  1,
                    [2] =  1,
                    [3] =  1,
                    [4] =  1,
                    [5] =  1,
                    [6] =  1,
                    [7] =  1,
                    [8] =  1,
                    [9] =  1,
                    [10] = 1,
                    [11] = 1,
                    [12] = 1,
                    [13] = 1,
                    [14] = 1,
                    [15] = 1,
                    [16] = 1,
                    [17] = 1,
                    [18] = 1,
                    [19] = 1,
                    [20] = 1,
                    [21] = 1,
                    [22] = 1,
                    [23] = 1,
                    [24] = 1,
                    [25] = 1,
                    [26] = 1,
                    [27] = 1,
                    [28] = 1,
                    [29] = 1,
                    [30] = 1,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                    [11] = radioPresetsRed["##RADIO3_11##"],
                    [12] = radioPresetsRed["##RADIO3_12##"],
                    [13] = radioPresetsRed["##RADIO3_13##"],
                    [14] = radioPresetsRed["##RADIO3_14##"],
                    [15] = radioPresetsRed["##RADIO3_15##"],
                    [16] = radioPresetsRed["##RADIO3_16##"],
                    [17] = radioPresetsRed["##RADIO3_17##"],
                    [18] = radioPresetsRed["##RADIO3_18##"],
                    [19] = radioPresetsRed["##RADIO3_19##"],
                    [20] = radioPresetsRed["##RADIO3_20##"],
                    [21] = radioPresetsRed["##RADIO3_21##"],
                    [22] = radioPresetsRed["##RADIO3_22##"],
                    [23] = radioPresetsRed["##RADIO3_23##"],
                    [24] = radioPresetsRed["##RADIO3_24##"],
                    [25] = radioPresetsRed["##RADIO3_25##"],
                    [26] = radioPresetsRed["##RADIO3_26##"],
                    [27] = radioPresetsRed["##RADIO3_27##"],
                    [28] = radioPresetsRed["##RADIO3_28##"],
                    [29] = radioPresetsRed["##RADIO3_29##"],
                    [30] = radioPresetsRed["##RADIO3_30##"],
                }, -- end of ["channels"]
            }, -- end of [3]
        },
    },

    ["blue JF-17"] = {
        type = "JF-17",
        coalition = "blue",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF (down to 30MHz) with modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red JF-17"] = {
        type = "JF-17",
        coalition = "red",
        country = nil,

        ["Radio"] = 
        {
            --V/UHF (down to 30MHz) with modulation selection box
            [1] = 
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] = 
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue Mirage"] = {
        type = "M-2000C",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                    [11] = radioPresetsBlue["##RADIO2_11##"],
                    [12] = radioPresetsBlue["##RADIO2_12##"],
                    [13] = radioPresetsBlue["##RADIO2_13##"],
                    [14] = radioPresetsBlue["##RADIO2_14##"],
                    [15] = radioPresetsBlue["##RADIO2_15##"],
                    [16] = radioPresetsBlue["##RADIO2_16##"],
                    [17] = radioPresetsBlue["##RADIO2_17##"],
                    [18] = radioPresetsBlue["##RADIO2_18##"],
                    [19] = radioPresetsBlue["##RADIO2_19##"],
                    [20] = radioPresetsBlue["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },

    ["red Mirage"] = {
        type = "M-2000C",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [2] =
            {
                ["modulations"] = 
                {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                    [11] = radioPresetsRed["##RADIO2_11##"],
                    [12] = radioPresetsRed["##RADIO2_12##"],
                    [13] = radioPresetsRed["##RADIO2_13##"],
                    [14] = radioPresetsRed["##RADIO2_14##"],
                    [15] = radioPresetsRed["##RADIO2_15##"],
                    [16] = radioPresetsRed["##RADIO2_16##"],
                    [17] = radioPresetsRed["##RADIO2_17##"],
                    [18] = radioPresetsRed["##RADIO2_18##"],
                    [19] = radioPresetsRed["##RADIO2_19##"],
                    [20] = radioPresetsRed["##RADIO2_20##"],
                }, -- end of ["channels"]
            }, -- end of [2]
        },
    },


    -----------------------------------------------------------------------------------------------------------------------------
    --trainers

    ["blue C-101CC"] = {
        type = "C-101CC",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red C-101CC"] = {
        type = "C-101CC",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue C-101EB"] = {
        type = "C-101EB",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --UHF, yes UHF, without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red C-101EB"] = {
        type = "C-101EB",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --UHF, yes UHF, without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue L-39C"] = {
        type = "L-39C",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["red L-39C"] = {
        type = "L-39C",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["blue L-39ZA"] = {
        type = "L-39ZA",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["red L-39ZA"] = {
        type = "L-39ZA",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --V/UHF with modulation selection box (but no modulation selection in the ME)
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
            }, -- end of [1]
        },
    },

    ["blue T-45"] = {
        type = "T-45",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --Unknown
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red T-45"] = {
        type = "T-45",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --Unknown
            [1] =
            {
                ["modulations"] =
                {
                    [1] =  0,
                    [2] =  0,
                    [3] =  0,
                    [4] =  0,
                    [5] =  0,
                    [6] =  0,
                    [7] =  0,
                    [8] =  0,
                    [9] =  0,
                    [10] = 0,
                    [11] = 0,
                    [12] = 0,
                    [13] = 0,
                    [14] = 0,
                    [15] = 0,
                    [16] = 0,
                    [17] = 0,
                    [18] = 0,
                    [19] = 0,
                    [20] = 0,
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                    [21] = 0,
                    [22] = 0,
                    [23] = 0,
                    [24] = 0,
                    [25] = 0,
                    [26] = 0,
                    [27] = 0,
                    [28] = 0,
                    [29] = 0,
                    [30] = 0,
                }, -- end of ["channels"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ------------------------------------------------------------------------------------------------------------------------------------------
    --helicopters
    ------------------------------------------------------------------------------------------------------------------------------------------

    ["blue AH-64D"] = {
        type = "AH-64D",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --VHF with modulation selection box (but no modulation selection in ME)
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                }, -- end of ["modulations"]
            }, -- end of [1]
            --UHF with modulation selection box (but no modulation selection in ME)
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO2_01##"],
                    [2]  = radioPresetsBlue["##RADIO2_02##"],
                    [3]  = radioPresetsBlue["##RADIO2_03##"],
                    [4]  = radioPresetsBlue["##RADIO2_04##"],
                    [5]  = radioPresetsBlue["##RADIO2_05##"],
                    [6]  = radioPresetsBlue["##RADIO2_06##"],
                    [7]  = radioPresetsBlue["##RADIO2_07##"],
                    [8]  = radioPresetsBlue["##RADIO2_08##"],
                    [9]  = radioPresetsBlue["##RADIO2_09##"],
                    [10] = radioPresetsBlue["##RADIO2_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                }, -- end of ["modulations"]
            }, -- end of [2]
            --FM without modulation selection box
            [3] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [3]
            --FM without modulation selection box
            [4] = {
                ["channels"] = {
                    [1] = 30,
                    [2] = 30.01,
                    [3] = 30.015,
                    [4] = 30.02,
                    [5] = 30.025,
                    [6] = 30.03,
                    [7] = 30.035,
                    [8] = 30.04,
                    [9] = 30.045,
                    [10] = 30.05,
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [4]
        }, -- end of ["Radio"]
    },

    ["red AH-64D"] = {
        type = "AH-64D",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --VHF with modulation selection box (but no modulation selection in ME)
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                }, -- end of ["modulations"]
            }, -- end of [1]
            --UHF with modulation selection box (but no modulation selection in ME)
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO2_01##"],
                    [2]  = radioPresetsRed["##RADIO2_02##"],
                    [3]  = radioPresetsRed["##RADIO2_03##"],
                    [4]  = radioPresetsRed["##RADIO2_04##"],
                    [5]  = radioPresetsRed["##RADIO2_05##"],
                    [6]  = radioPresetsRed["##RADIO2_06##"],
                    [7]  = radioPresetsRed["##RADIO2_07##"],
                    [8]  = radioPresetsRed["##RADIO2_08##"],
                    [9]  = radioPresetsRed["##RADIO2_09##"],
                    [10] = radioPresetsRed["##RADIO2_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    [2] = 0,
                    [3] = 0,
                    [4] = 0,
                    [5] = 0,
                    [6] = 0,
                    [7] = 0,
                    [8] = 0,
                    [9] = 0,
                    [10] = 0,
                }, -- end of ["modulations"]
            }, -- end of [2]
            --FM without modulation selection box
            [3] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [3]
            --FM without modulation selection box
            [4] = {
                ["channels"] = {
                    [1] = 30,
                    [2] = 30.01,
                    [3] = 30.015,
                    [4] = 30.02,
                    [5] = 30.025,
                    [6] = 30.03,
                    [7] = 30.035,
                    [8] = 30.04,
                    [9] = 30.045,
                    [10] = 30.05,
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [4]
        }, -- end of ["Radio"]
    },

    ["blue Gazelles"] = {
        type = "SA342.+",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --FM with modulation selection box (but no modulation selection in ME)
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1]  = 0,
                    [2]  = 0,
                    [3]  = 0,
                    [4]  = 0,
                    [5]  = 0,
                    [6]  = 0,
                    [7]  = 0,
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red Gazelles"] = {
        type = "SA342.+",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --FM with modulation selection box (but no modulation selection in ME)
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1]  = 0,
                    [2]  = 0,
                    [3]  = 0,
                    [4]  = 0,
                    [5]  = 0,
                    [6]  = 0,
                    [7]  = 0,
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["blue Ka-50"] = {
        type = "Ka-50",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --FM without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --ARK-22 ADF (Range 0.15 to 1.75MHz)
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = 0.441,
                    [2]  = 0.442,
                    [3]  = 0.443,
                    [4]  = 0.444,
                    [5]  = 0.445,
                    [6]  = 0.446,
                    [7]  = 0.447,
                    [8]  = 0.448,
                    [9]  = 0.449,
                    [10] = 0.450,
                    [11] = 0.451,
                    [12] = 0.452,
                    [13] = 0.453,
                    [14] = 0.454,
                    [15] = 0.455,
                    [16] = 0.456,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red Ka-50"] = {
        type = "Ka-50",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --FM without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --ARK-22 ADF (Range 0.15 to 1.75MHz)
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = 0.441,
                    [2]  = 0.442,
                    [3]  = 0.443,
                    [4]  = 0.444,
                    [5]  = 0.445,
                    [6]  = 0.446,
                    [7]  = 0.447,
                    [8]  = 0.448,
                    [9]  = 0.449,
                    [10] = 0.450,
                    [11] = 0.451,
                    [12] = 0.452,
                    [13] = 0.453,
                    [14] = 0.454,
                    [15] = 0.455,
                    [16] = 0.456,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

       ["blue Ka-50III"] = {
        type = "Ka-50_3",
        coalition = "blue",
        country = nil,

        ["Radio"] =
        {
            --FM without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --ARK-22 ADF (Range 0.15 to 1.75MHz)
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = 0.441,
                    [2]  = 0.442,
                    [3]  = 0.443,
                    [4]  = 0.444,
                    [5]  = 0.445,
                    [6]  = 0.446,
                    [7]  = 0.447,
                    [8]  = 0.448,
                    [9]  = 0.449,
                    [10] = 0.450,
                    [11] = 0.451,
                    [12] = 0.452,
                    [13] = 0.453,
                    [14] = 0.454,
                    [15] = 0.455,
                    [16] = 0.456,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red Ka-50III"] = {
        type = "Ka-50_3",
        coalition = "red",
        country = nil,

        ["Radio"] =
        {
            --FM without modulation selection box
            [1] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                }, -- end of ["channels"]
            }, -- end of [1]
            --ARK-22 ADF (Range 0.15 to 1.75MHz)
            [2] =
            {
                ["modulations"] =
                {
                }, -- end of ["modulations"]
                ["channels"] =
                {
                    [1]  = 0.441,
                    [2]  = 0.442,
                    [3]  = 0.443,
                    [4]  = 0.444,
                    [5]  = 0.445,
                    [6]  = 0.446,
                    [7]  = 0.447,
                    [8]  = 0.448,
                    [9]  = 0.449,
                    [10] = 0.450,
                    [11] = 0.451,
                    [12] = 0.452,
                    [13] = 0.453,
                    [14] = 0.454,
                    [15] = 0.455,
                    [16] = 0.456,
                }, -- end of ["channels"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue Mi-8MT"] = {
        type = "Mi-8MT",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
            --FM without modulation selection box
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red Mi-8MT"] = {
        type = "Mi-8MT",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
            --FM without modulation selection box
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },
    
    ["blue Mi-24P"] = {
        type = "Mi-24P",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
            --FM without modulation selection box
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO3_01##"],
                    [2]  = radioPresetsBlue["##RADIO3_02##"],
                    [3]  = radioPresetsBlue["##RADIO3_03##"],
                    [4]  = radioPresetsBlue["##RADIO3_04##"],
                    [5]  = radioPresetsBlue["##RADIO3_05##"],
                    [6]  = radioPresetsBlue["##RADIO3_06##"],
                    [7]  = radioPresetsBlue["##RADIO3_07##"],
                    [8]  = radioPresetsBlue["##RADIO3_08##"],
                    [9]  = radioPresetsBlue["##RADIO3_09##"],
                    [10] = radioPresetsBlue["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["red Mi-24P"] = {
        type = "Mi-24P",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --V/UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
            --FM without modulation selection box
            [2] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO3_01##"],
                    [2]  = radioPresetsRed["##RADIO3_02##"],
                    [3]  = radioPresetsRed["##RADIO3_03##"],
                    [4]  = radioPresetsRed["##RADIO3_04##"],
                    [5]  = radioPresetsRed["##RADIO3_05##"],
                    [6]  = radioPresetsRed["##RADIO3_06##"],
                    [7]  = radioPresetsRed["##RADIO3_07##"],
                    [8]  = radioPresetsRed["##RADIO3_08##"],
                    [9]  = radioPresetsRed["##RADIO3_09##"],
                    [10] = radioPresetsRed["##RADIO3_10##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [2]
        }, -- end of ["Radio"]
    },

    ["blue UH-1H"] = {
        type = "UH-1H",
        coalition = "blue",
        country = nil,

        ["Radio"] = {
            --UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsBlue["##RADIO1_01##"],
                    [2]  = radioPresetsBlue["##RADIO1_02##"],
                    [3]  = radioPresetsBlue["##RADIO1_03##"],
                    [4]  = radioPresetsBlue["##RADIO1_04##"],
                    [5]  = radioPresetsBlue["##RADIO1_05##"],
                    [6]  = radioPresetsBlue["##RADIO1_06##"],
                    [7]  = radioPresetsBlue["##RADIO1_07##"],
                    [8]  = radioPresetsBlue["##RADIO1_08##"],
                    [9]  = radioPresetsBlue["##RADIO1_09##"],
                    [10] = radioPresetsBlue["##RADIO1_10##"],
                    [11] = radioPresetsBlue["##RADIO1_11##"],
                    [12] = radioPresetsBlue["##RADIO1_12##"],
                    [13] = radioPresetsBlue["##RADIO1_13##"],
                    [14] = radioPresetsBlue["##RADIO1_14##"],
                    [15] = radioPresetsBlue["##RADIO1_15##"],
                    [16] = radioPresetsBlue["##RADIO1_16##"],
                    [17] = radioPresetsBlue["##RADIO1_17##"],
                    [18] = radioPresetsBlue["##RADIO1_18##"],
                    [19] = radioPresetsBlue["##RADIO1_19##"],
                    [20] = radioPresetsBlue["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },

    ["red UH-1H"] = {
        type = "UH-1H",
        coalition = "red",
        country = nil,

        ["Radio"] = {
            --UHF without modulation selection box
            [1] = {
                ["channels"] = {
                    [1]  = radioPresetsRed["##RADIO1_01##"],
                    [2]  = radioPresetsRed["##RADIO1_02##"],
                    [3]  = radioPresetsRed["##RADIO1_03##"],
                    [4]  = radioPresetsRed["##RADIO1_04##"],
                    [5]  = radioPresetsRed["##RADIO1_05##"],
                    [6]  = radioPresetsRed["##RADIO1_06##"],
                    [7]  = radioPresetsRed["##RADIO1_07##"],
                    [8]  = radioPresetsRed["##RADIO1_08##"],
                    [9]  = radioPresetsRed["##RADIO1_09##"],
                    [10] = radioPresetsRed["##RADIO1_10##"],
                    [11] = radioPresetsRed["##RADIO1_11##"],
                    [12] = radioPresetsRed["##RADIO1_12##"],
                    [13] = radioPresetsRed["##RADIO1_13##"],
                    [14] = radioPresetsRed["##RADIO1_14##"],
                    [15] = radioPresetsRed["##RADIO1_15##"],
                    [16] = radioPresetsRed["##RADIO1_16##"],
                    [17] = radioPresetsRed["##RADIO1_17##"],
                    [18] = radioPresetsRed["##RADIO1_18##"],
                    [19] = radioPresetsRed["##RADIO1_19##"],
                    [20] = radioPresetsRed["##RADIO1_20##"],
                }, -- end of ["channels"]
                ["modulations"] = {
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
    },
}
