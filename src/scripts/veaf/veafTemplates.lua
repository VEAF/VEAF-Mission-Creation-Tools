-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF spawn templates, units and groups definitions library
-- By zip (2021)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafTemplates Table.
veafTemplates = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafTemplates.Id = "TEMPLATES - "

--- Version.
veafTemplates.Version = "1.0.0"

-- trace level, specific to this module
veafTemplates.Debug = true
veafTemplates.Trace = true

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- units definition library
veafTemplates.unitsLibrary = {}

-- groups definition library
veafTemplates.groupsLibrary = {}

-- templates library
veafTemplates.templatesLibrary = {}

-- templates aliases library
veafTemplates.templatesAliasesLibrary = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Units library
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local _unitsLibrary = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Templates library
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local _templates = {
    ------------------Helicopters------------------
    ["Ka-50-cas"] = {
        ["modulation"] = 0,
        ["task"] = "CAS",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 500,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Russia Standard Army",
                ["skill"] = "High",
                ["ropeLength"] = 15,
                ["speed"] = 46.25,
                ["type"] = "Ka-50",
                ["psi"] = 0,
                ["y"] = 527428.57142857,
                ["x"] = -346857.14285714,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{A6FD14D3-6D30-4C85-88A7-8D17BEE120E2}"
                        },
                        [2] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [3] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [4] = {
                            ["CLSID"] = "{A6FD14D3-6D30-4C85-88A7-8D17BEE120E2}"
                        }
                    },
                    ["fuel"] = "1450",
                    ["flare"] = 128,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 109,
                ["onboard_num"] = "050"
            }
        },
        ["y"] = 527428.57142857,
        ["x"] = -346857.14285714,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["Mi-24V-cas"] = {
        ["modulation"] = 0,
        ["task"] = "CAS",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 500,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "standard 1",
                ["skill"] = "High",
                ["ropeLength"] = 15,
                ["speed"] = 46.25,
                ["type"] = "Mi-24V",
                ["psi"] = 0,
                ["y"] = 528000,
                ["x"] = -328285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}"
                        },
                        [2] = {
                            ["CLSID"] = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}"
                        },
                        [3] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [4] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [5] = {
                            ["CLSID"] = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}"
                        },
                        [6] = {
                            ["CLSID"] = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}"
                        }
                    },
                    ["fuel"] = "1704",
                    ["flare"] = 192,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 110,
                ["onboard_num"] = "050"
            }
        },
        ["y"] = 528000,
        ["x"] = -328285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 127.5
    },
    ["Mi-28N-cas"] = {
        ["modulation"] = 0,
        ["task"] = "CAS",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 500,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "night",
                ["skill"] = "High",
                ["ropeLength"] = 15,
                ["speed"] = 46.25,
                ["type"] = "Mi-28N",
                ["psi"] = 0,
                ["y"] = 529428.57142857,
                ["x"] = -311714.28571429,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{57232979-8B0F-4db7-8D9A-55197E06B0F5}"
                        },
                        [2] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [3] = {
                            ["CLSID"] = "{FC56DF80-9B09-44C5-8976-DCFAFF219062}"
                        },
                        [4] = {
                            ["CLSID"] = "{57232979-8B0F-4db7-8D9A-55197E06B0F5}"
                        }
                    },
                    ["fuel"] = "1500",
                    ["flare"] = 128,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 111,
                ["onboard_num"] = "050"
            }
        },
        ["y"] = 529428.57142857,
        ["x"] = -311714.28571429,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 127.5
    },
    ["Mi-8MTV2-cas"] = {
        ["modulation"] = 0,
        ["task"] = "CAS",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 500,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Russia_VVS_Standard",
                ["skill"] = "High",
                ["ropeLength"] = 15,
                ["speed"] = 46.25,
                ["AddPropAircraft"] = {
                    ["ExhaustScreen"] = true,
                    ["CargoHalfdoor"] = true,
                    ["GunnersAISkill"] = 90,
                    ["AdditionalArmor"] = true,
                    ["NS430allow"] = true
                },
                ["type"] = "Mi-8MT",
                ["psi"] = 0,
                ["y"] = 529428.57142857,
                ["x"] = -296000,
                ["payload"] = {
                    ["pylons"] = {
                        [5] = {
                            ["CLSID"] = "GUV_YakB_GSHP"
                        },
                        [2] = {
                            ["CLSID"] = "GUV_YakB_GSHP"
                        },
                        [4] = {
                            ["CLSID"] = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}"
                        },
                        [3] = {
                            ["CLSID"] = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}"
                        }
                    },
                    ["fuel"] = "1929",
                    ["flare"] = 128,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 112,
                ["onboard_num"] = "050"
            }
        },
        ["y"] = 529428.57142857,
        ["x"] = -296000,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 127.5
    },
    ------------------Fighter Planes------------------

    ["MiG-29A-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["type"] = "MiG-29A",
                ["psi"] = 0,
                ["y"] = 565714.28571429,
                ["x"] = -306000,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [2] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [3] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [4] = {
                            ["CLSID"] = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}"
                        },
                        [5] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [6] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [7] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        }
                    },
                    ["fuel"] = "3376",
                    ["flare"] = 30,
                    ["chaff"] = 30,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 101,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 565714.28571429,
        ["x"] = -306000,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["MiG-29S-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["type"] = "MiG-29S",
                ["psi"] = 0,
                ["y"] = 565428.57142857,
                ["x"] = -284857.14285714,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [2] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [3] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [4] = {
                            ["CLSID"] = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}"
                        },
                        [5] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [6] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [7] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        }
                    },
                    ["fuel"] = "3493",
                    ["flare"] = 30,
                    ["chaff"] = 30,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 102,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 565428.57142857,
        ["x"] = -284857.14285714,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["MiG-29S-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["type"] = "MiG-29S",
                ["psi"] = 0,
                ["y"] = 566285.71428571,
                ["x"] = -330285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}"
                        },
                        [4] = {
                            ["CLSID"] = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}"
                        },
                        [5] = {
                            ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}"
                        },
                        [6] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [7] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = "3493",
                    ["flare"] = 30,
                    ["chaff"] = 30,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 102,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 566285.71428571,
        ["x"] = -330285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["MiG-29S-fox3"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["type"] = "MiG-29S",
                ["psi"] = 0,
                ["y"] = 565142.85714286,
                ["x"] = -348000,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [3] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [4] = {
                            ["CLSID"] = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}"
                        },
                        [5] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [6] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [7] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = "3493",
                    ["flare"] = 30,
                    ["chaff"] = 30,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 102,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 565142.85714286,
        ["x"] = -348000,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["Su-27-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-27",
                ["psi"] = 0,
                ["y"] = 585714.28571429,
                ["x"] = -352285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [4] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [5] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [6] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [7] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [8] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [9] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = 5590.18,
                    ["flare"] = 96,
                    ["chaff"] = 96,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 103,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 585714.28571429,
        ["x"] = -352285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 127.5
    },
    ["Su-27-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "Air Force Standard",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-27",
                ["psi"] = 0,
                ["y"] = 585714.28571429,
                ["x"] = -334571.42857143,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [8] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [9] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = 5590.18,
                    ["flare"] = 96,
                    ["chaff"] = 96,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 103,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 585714.28571429,
        ["x"] = -334571.42857143,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 127.5
    },
    ["Su-33-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "279th kiap 1st squad navy",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-33",
                ["psi"] = 0,
                ["y"] = 586571.42857143,
                ["x"] = -314285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}"
                        },
                        [4] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [5] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [6] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [7] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [8] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [9] = {
                            ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
                        },
                        [10] = {
                            ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}"
                        },
                        [11] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [12] = {
                            ["CLSID"] = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}"
                        }
                    },
                    ["fuel"] = 4750,
                    ["flare"] = 48,
                    ["chaff"] = 48,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 104,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 586571.42857143,
        ["x"] = -314285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["Su-33-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "279th kiap 1st squad navy",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-33",
                ["psi"] = 0,
                ["y"] = 586571.42857143,
                ["x"] = -296000,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [11] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [12] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = 4750,
                    ["flare"] = 48,
                    ["chaff"] = 48,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 104,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 586571.42857143,
        ["x"] = -296000,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["Su-33-fox2long"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "279th kiap 1st squad navy",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-33",
                ["psi"] = 0,
                ["y"] = 585714.28571429,
                ["x"] = -279428.57142857,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [11] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [12] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = 4750,
                    ["flare"] = 48,
                    ["chaff"] = 48,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 104,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 585714.28571429,
        ["x"] = -279428.57142857,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 124
    },
    ["MiG-23MLD-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 210.69444444444,
                ["type"] = "MiG-23MLD",
                ["psi"] = 0,
                ["y"] = 585714.28571429,
                ["x"] = -262571.42857143,
                ["payload"] = {
                    ["pylons"] = {
                        [3] = {
                            ["CLSID"] = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}"
                        },
                        [4] = {
                            ["CLSID"] = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}"
                        },
                        [5] = {
                            ["CLSID"] = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}"
                        }
                    },
                    ["fuel"] = "3800",
                    ["flare"] = 60,
                    ["chaff"] = 60,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 105,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 585714.28571429,
        ["x"] = -262571.42857143,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-23MLD-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 210.69444444444,
                ["type"] = "MiG-23MLD",
                ["psi"] = 0,
                ["y"] = 563428.57142857,
                ["x"] = -262285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [2] = {
                            ["CLSID"] = "{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}"
                        },
                        [3] = {
                            ["CLSID"] = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}"
                        },
                        [4] = {
                            ["CLSID"] = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}"
                        },
                        [5] = {
                            ["CLSID"] = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}"
                        },
                        [6] = {
                            ["CLSID"] = "{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}"
                        }
                    },
                    ["fuel"] = "3800",
                    ["flare"] = 60,
                    ["chaff"] = 60,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 105,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 563428.57142857,
        ["x"] = -262285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-23MLD-fox2long"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 210.69444444444,
                ["type"] = "MiG-23MLD",
                ["psi"] = 0,
                ["y"] = 604571.42857143,
                ["x"] = -263142.85714286,
                ["payload"] = {
                    ["pylons"] = {
                        [2] = {
                            ["CLSID"] = "{6980735A-44CC-4BB9-A1B5-591532F1DC69}"
                        },
                        [3] = {
                            ["CLSID"] = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}"
                        },
                        [4] = {
                            ["CLSID"] = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}"
                        },
                        [5] = {
                            ["CLSID"] = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}"
                        },
                        [6] = {
                            ["CLSID"] = "{6980735A-44CC-4BB9-A1B5-591532F1DC69}"
                        }
                    },
                    ["fuel"] = "3800",
                    ["flare"] = 60,
                    ["chaff"] = 60,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 105,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 604571.42857143,
        ["x"] = -263142.85714286,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-25PD-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-25PD",
                ["psi"] = 0,
                ["y"] = 604571.42857143,
                ["x"] = -280857.14285714,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        },
                        [2] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        },
                        [3] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        },
                        [4] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        }
                    },
                    ["fuel"] = "15245",
                    ["flare"] = 64,
                    ["chaff"] = 64,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 107,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 604571.42857143,
        ["x"] = -280857.14285714,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-25PD-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-25PD",
                ["psi"] = 0,
                ["y"] = 606571.42857143,
                ["x"] = -296571.42857143,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [4] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        }
                    },
                    ["fuel"] = "15245",
                    ["flare"] = 64,
                    ["chaff"] = 64,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 107,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 606571.42857143,
        ["x"] = -296571.42857143,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-25PD-fox2long"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "af standard",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-25PD",
                ["psi"] = 0,
                ["y"] = 606285.71428571,
                ["x"] = -316571.42857143,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        },
                        [2] = {
                            ["CLSID"] = "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}"
                        },
                        [3] = {
                            ["CLSID"] = "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}"
                        },
                        [4] = {
                            ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
                        }
                    },
                    ["fuel"] = "15245",
                    ["flare"] = 64,
                    ["chaff"] = 64,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 107,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 606285.71428571,
        ["x"] = -316571.42857143,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-31-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "174 GvIAP_Boris Safonov",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-31",
                ["psi"] = 0,
                ["y"] = 606285.71428571,
                ["x"] = -333428.57142857,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}"
                        },
                        [6] = {
                            ["CLSID"] = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}"
                        }
                    },
                    ["fuel"] = "15500",
                    ["flare"] = 0,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 106,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 606285.71428571,
        ["x"] = -333428.57142857,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["Su-30-fox2"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "`desert` test paint scheme",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-30",
                ["psi"] = 0,
                ["y"] = 627142.85714286,
                ["x"] = -320285.71428571,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [8] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [9] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = "9400",
                    ["flare"] = 96,
                    ["chaff"] = 96,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 108,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 627142.85714286,
        ["x"] = -320285.71428571,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-31-fox1"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "174 GvIAP_Boris Safonov",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-31",
                ["psi"] = 0,
                ["y"] = 606000,
                ["x"] = -353142.85714286,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        },
                        [6] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        }
                    },
                    ["fuel"] = "15500",
                    ["flare"] = 0,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 106,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 606000,
        ["x"] = -353142.85714286,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["Su-30-fox2long"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "`desert` test paint scheme",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-30",
                ["psi"] = 0,
                ["y"] = 624571.42857143,
                ["x"] = -301714.28571429,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [4] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [7] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [8] = {
                            ["CLSID"] = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}"
                        },
                        [10] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [9] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        }
                    },
                    ["fuel"] = "9400",
                    ["flare"] = 96,
                    ["chaff"] = 96,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 108,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 624571.42857143,
        ["x"] = -301714.28571429,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["MiG-31-fox3"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "174 GvIAP_Boris Safonov",
                ["skill"] = "High",
                ["speed"] = 277.5,
                ["type"] = "MiG-31",
                ["psi"] = 0,
                ["y"] = 625714.28571429,
                ["x"] = -354000,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        },
                        [2] = {
                            ["CLSID"] = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"
                        },
                        [3] = {
                            ["CLSID"] = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"
                        },
                        [4] = {
                            ["CLSID"] = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"
                        },
                        [5] = {
                            ["CLSID"] = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"
                        },
                        [6] = {
                            ["CLSID"] = "{4EDBA993-2E34-444C-95FB-549300BF7CAF}"
                        }
                    },
                    ["fuel"] = "15500",
                    ["flare"] = 0,
                    ["chaff"] = 0,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 106,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 625714.28571429,
        ["x"] = -354000,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    },
    ["Su-30-fox3"] = {
        ["modulation"] = 0,
        ["radioSet"] = false,
        ["task"] = "CAP",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["alt"] = 2000,
                ["hardpoint_racks"] = true,
                ["alt_type"] = "BARO",
                ["livery_id"] = "`desert` test paint scheme",
                ["skill"] = "High",
                ["speed"] = 169.58333333333,
                ["type"] = "Su-30",
                ["psi"] = 0,
                ["y"] = 622000,
                ["x"] = -282857.14285714,
                ["payload"] = {
                    ["pylons"] = {
                        [1] = {
                            ["CLSID"] = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}"
                        },
                        [2] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [3] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [4] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [5] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [6] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [7] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [8] = {
                            ["CLSID"] = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
                        },
                        [9] = {
                            ["CLSID"] = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
                        },
                        [10] = {
                            ["CLSID"] = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}"
                        }
                    },
                    ["fuel"] = "9400",
                    ["flare"] = 96,
                    ["chaff"] = 96,
                    ["gun"] = 100
                },
                ["heading"] = 0,
                ["callsign"] = 108,
                ["onboard_num"] = "010"
            }
        },
        ["y"] = 622000,
        ["x"] = -282857.14285714,
        ["communication"] = true,
        ["start_time"] = 0,
        ["frequency"] = 251
    }
}

local _aliases = {
    ["Ka-50-cas"] = {"ka50-cas", "ka50"},
    ["Mi-24V-cas"] = {"mi24v-cas", "mi24-cas", "mi24"},
    ["Mi-28N-cas"] = {"mi28n-cas", "mi28-cas", "mi28"},
    ["Mi-8MTV2-cas"] = {"mi8mtv2-cas", "mi8-cas", "mi8"},
    ["MiG-29A-fox2"] = {"mig29a-fox2"},
    ["MiG-29S-fox2"] = {"mig29s-fox2", "mig29-fox2"},
    ["MiG-29S-fox1"] = {"mig29s-fox1", "mig29-fox1"},
    ["MiG-29S-fox3"] = {"mig29s-fox3", "mig29-fox3", "mig29"},
    ["Su-27-fox1"] = {"su27-fox1", "su27-fox1", "su27"},
    ["Su-27-fox2"] = {"su27-fox2", "su27-fox2"},
    ["Su-33-fox1"] = {"su33-fox1", "su33-fox1", "su33"},
    ["Su-33-fox2"] = {"su33-fox2", "su33-fox2"},
    ["Su-33-fox2long"] = {"su33-fox2long", "su33-fox2long"},
    ["MiG-23MLD-fox2"] = {"mig23mld-fox2", "mig23-fox2"},
    ["MiG-23MLD-fox1"] = {"mig23mld-fox1", "mig23-fox1", "mig23"},
    ["MiG-23MLD-fox2long"] = {"mig23mld-fox2long", "mig23-fox2long"},
    ["MiG-25PD-fox1"] = {"mig25pd-fox1", "mig25-fox1", "mig25"},
    ["MiG-25PD-fox2"] = {"mig25pd-fox2", "mig25-fox2"},
    ["MiG-25PD-fox2long"] = {"mig25pd-fox2long", "mig25-fox2long"},
    ["Su-30-fox2"] = {"su30-fox2"},
    ["Su-30-fox2long"] = {"su30-fox2long"},
    ["Su-30-fox3"] = {"su30-fox3", "su30"},
    ["MiG-31-fox1"] = {"mig31-fox1"},
    ["MiG-31-fox2"] = {"mig31-fox2"},
    ["MiG-31-fox3"] = {"mig31-fox3", "mig31"}
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- template management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _cleanupTemplate(template)
    return veaf.deepCopy(template)
end

--- loads the _templates and _aliases into veafTemplates.templatesLibrary
local function _loadTemplates()
    for name, template in pairs(_templates) do
        local name = name:lower()
        local aliases = _aliases[name]
    end
end

--- add a template with its aliases to veafTemplates.templatesLibrary
function veafTemplates.addTemplate(name, template, aliases)
    local name = name:lower()
    local cleanTemplate = _cleanupTemplate(template)
    veafTemplates.templatesLibrary[name] = cleanTemplate
    if aliases then for _, alias in pairs(aliases) do
        veafTemplates.templatesAliasesLibrary[alias:lower()] = name
    end
    return cleanTemplate
end

--- get a template from veafTemplates.templatesLibrary
function veafTemplates.getTemplate(name)
    local name = name:lower()
    local template = veafTemplates.templatesLibrary[name]
    if not template then
        local actualName = veafTemplates.templatesAliasesLibrary[name]
        if actualName then 
            return veafTemplates.templatesLibrary[actualName]
        end
    end
    return template
end

function veafTemplates.getTemplateOrDcsGroupDefinition(name)
    local name = name:lower()

    -- search in the templates library
    local template = veafTemplates.getTemplate(name)
    if template then
        return template
    end

    -- search in DCS groups
    for _, coa_data in pairs(env.mission.coalition) do
        if type(coa_data) == 'table' then
            if coa_data.country then
                for cntry_id, cntry_data in pairs(coa_data.country) do
                  if type(cntry_data) == 'table' then    
                    for obj_type_name, obj_type_data in pairs(cntry_data) do
                      if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" or obj_type_name == "static" then --should be an unncessary check
                        if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then  --there's a group!
                            for group_num, group_template in pairs(obj_type_data.group) do
                                local group_name = env.getValueDictByKey( group_template.name )
                                if group_name then
                                    group_name = group_name:lower()
                                    if name == group_name then
                                        return veafTemplates.addTemplate(name, template)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- nothing found
    return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafTemplates.logError(message)
    veaf.logError(veafTemplates.Id .. message)
end

function veafTemplates.logInfo(message)
    veaf.logInfo(veafTemplates.Id .. message)
end

function veafTemplates.logDebug(message)
    if message and veafTemplates.Debug then
        veaf.logDebug(veafTemplates.Id .. message)
    end
end

function veafTemplates.logTrace(message)
    if message and veafTemplates.Trace then
        veaf.logTrace(veafTemplates.Id .. message)
    end
end
