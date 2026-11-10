-- panelRadio block of _G/db/Units/Helicopters/Helicopter/OH58D.lua, verbatim from
-- Quaggles/dcs-lua-datamine @ 72ea893c (DCS 2.9.31.29434). Expected counts: 20, 20, 21, 21.
return {
	DisplayName = "OH-58D",
	panelRadio = { {
			channels = { {
					connect = true,
					default = 260,
					modulation = "AM",
					name = "Channel M"
				}, {
					default = 225,
					modulation = "AM",
					name = "Channel 1"
				}, {
					default = 230,
					modulation = "AM",
					name = "Channel 2"
				}, {
					default = 240,
					modulation = "AM",
					name = "Channel 3"
				}, {
					default = 250,
					modulation = "AM",
					name = "Channel 4"
				}, {
					default = 260,
					modulation = "AM",
					name = "Channel 5"
				}, {
					default = 270,
					modulation = "AM",
					name = "Channel 6"
				}, {
					default = 280,
					modulation = "AM",
					name = "Channel 7"
				}, {
					default = 290,
					modulation = "AM",
					name = "Channel 8"
				}, {
					default = 300,
					modulation = "AM",
					name = "Channel 9"
				}, {
					default = 310,
					modulation = "AM",
					name = "Channel 10"
				}, {
					default = 320,
					modulation = "AM",
					name = "Channel 11"
				}, {
					default = 330,
					modulation = "AM",
					name = "Channel 12"
				}, {
					default = 340,
					modulation = "AM",
					name = "Channel 13"
				}, {
					default = 350,
					modulation = "AM",
					name = "Channel 14"
				}, {
					default = 360,
					modulation = "AM",
					name = "Channel 15"
				}, {
					default = 370,
					modulation = "AM",
					name = "Channel 16"
				}, {
					default = 380,
					modulation = "AM",
					name = "Channel 17"
				}, {
					default = 390,
					modulation = "AM",
					name = "Channel 18"
				}, {
					default = 395,
					modulation = "AM",
					name = "Channel 19"
				} },
			name = "UHF AM",
			range = {
				max = 399.975,
				min = 225
			}
		}, {
			channels = { {
					default = 131,
					modulation = "AM",
					name = "Channel M"
				}, {
					default = 116,
					modulation = "AM",
					name = "Channel 1"
				}, {
					default = 118,
					modulation = "AM",
					name = "Channel 2"
				}, {
					default = 120,
					modulation = "AM",
					name = "Channel 3"
				}, {
					default = 122,
					modulation = "AM",
					name = "Channel 4"
				}, {
					default = 124,
					modulation = "AM",
					name = "Channel 5"
				}, {
					default = 126,
					modulation = "AM",
					name = "Channel 6"
				}, {
					default = 128,
					modulation = "AM",
					name = "Channel 7"
				}, {
					default = 130,
					modulation = "AM",
					name = "Channel 8"
				}, {
					default = 132,
					modulation = "AM",
					name = "Channel 9"
				}, {
					default = 134,
					modulation = "AM",
					name = "Channel 10"
				}, {
					default = 136,
					modulation = "AM",
					name = "Channel 11"
				}, {
					default = 138,
					modulation = "AM",
					name = "Channel 12"
				}, {
					default = 140,
					modulation = "AM",
					name = "Channel 13"
				}, {
					default = 142,
					modulation = "AM",
					name = "Channel 14"
				}, {
					default = 144,
					modulation = "AM",
					name = "Channel 15"
				}, {
					default = 146,
					modulation = "AM",
					name = "Channel 16"
				}, {
					default = 148,
					modulation = "AM",
					name = "Channel 17"
				}, {
					default = 150,
					modulation = "AM",
					name = "Channel 18"
				}, {
					default = 151,
					modulation = "AM",
					name = "Channel 19"
				} },
			name = "VHF AM",
			range = {
				max = 151.975,
				min = 116
			}
		}, {
			channels = { {
					default = 30,
					modulation = "FM",
					name = "Channel C"
				}, {
					default = 40.4,
					modulation = "FM",
					name = "Channel M"
				}, {
					default = 30,
					modulation = "FM",
					name = "Channel 1"
				}, {
					default = 32,
					modulation = "FM",
					name = "Channel 2"
				}, {
					default = 36,
					modulation = "FM",
					name = "Channel 3"
				}, {
					default = 38,
					modulation = "FM",
					name = "Channel 4"
				}, {
					default = 42,
					modulation = "FM",
					name = "Channel 5"
				}, {
					default = 44,
					modulation = "FM",
					name = "Channel 6"
				}, {
					default = 48,
					modulation = "FM",
					name = "Channel 7"
				}, {
					default = 50,
					modulation = "FM",
					name = "Channel 8"
				}, {
					default = 54,
					modulation = "FM",
					name = "Channel 9"
				}, {
					default = 56,
					modulation = "FM",
					name = "Channel 10"
				}, {
					default = 60,
					modulation = "FM",
					name = "Channel 11"
				}, {
					default = 62,
					modulation = "FM",
					name = "Channel 12"
				}, {
					default = 66,
					modulation = "FM",
					name = "Channel 13"
				}, {
					default = 68,
					modulation = "FM",
					name = "Channel 14"
				}, {
					default = 72,
					modulation = "FM",
					name = "Channel 15"
				}, {
					default = 74,
					modulation = "FM",
					name = "Channel 16"
				}, {
					default = 78,
					modulation = "FM",
					name = "Channel 17"
				}, {
					default = 80,
					modulation = "FM",
					name = "Channel 18"
				}, {
					default = 84,
					modulation = "FM",
					name = "Channel 19"
				} },
			name = "VHF FM1",
			range = {
				max = 87.975,
				min = 30
			}
		}, {
			channels = { {
					default = 30,
					modulation = "FM",
					name = "Channel C"
				}, {
					default = 40.4,
					modulation = "FM",
					name = "Channel M"
				}, {
					default = 30,
					modulation = "FM",
					name = "Channel 1"
				}, {
					default = 32,
					modulation = "FM",
					name = "Channel 2"
				}, {
					default = 36,
					modulation = "FM",
					name = "Channel 3"
				}, {
					default = 38,
					modulation = "FM",
					name = "Channel 4"
				}, {
					default = 42,
					modulation = "FM",
					name = "Channel 5"
				}, {
					default = 44,
					modulation = "FM",
					name = "Channel 6"
				}, {
					default = 48,
					modulation = "FM",
					name = "Channel 7"
				}, {
					default = 50,
					modulation = "FM",
					name = "Channel 8"
				}, {
					default = 54,
					modulation = "FM",
					name = "Channel 9"
				}, {
					default = 56,
					modulation = "FM",
					name = "Channel 10"
				}, {
					default = 60,
					modulation = "FM",
					name = "Channel 11"
				}, {
					default = 62,
					modulation = "FM",
					name = "Channel 12"
				}, {
					default = 66,
					modulation = "FM",
					name = "Channel 13"
				}, {
					default = 68,
					modulation = "FM",
					name = "Channel 14"
				}, {
					default = 72,
					modulation = "FM",
					name = "Channel 15"
				}, {
					default = 74,
					modulation = "FM",
					name = "Channel 16"
				}, {
					default = 78,
					modulation = "FM",
					name = "Channel 17"
				}, {
					default = 80,
					modulation = "FM",
					name = "Channel 18"
				}, {
					default = 84,
					modulation = "FM",
					name = "Channel 19"
				} },
			name = "VHF FM2",
			range = {
				max = 87.975,
				min = 30
			}
		} },
	type = "OH58D"
}
