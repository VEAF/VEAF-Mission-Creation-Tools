------------------------------------------------------------------
-- VEAF airfield frequencies: the tower frequencies (MHz) and TACAN DCS gives each airfield, per
-- theatre (env.mission.theatre) and DCS airdrome id (Airbase:getID()). Read by veafAirbases for the
-- welcome brief and the ATIS: the mission scripts have no API to ask DCS for them.
--
-- GENERATED from veaf_libs/data/airfield-frequencies.yaml by `veaf-build update-dcs-data --airfield-freqs`.
-- DO NOT EDIT BY HAND — edits are overwritten and a test fails on drift.
------------------------------------------------------------------

veafAirfieldFrequencies = {}

veafAirfieldFrequencies["Caucasus"] = {
  [12] = { uhf = 250.0, vhf = 121.0, fm = 38.4 }, -- Anapa-Vityazevo
  [13] = { uhf = 251.0, vhf = 122.0, fm = 38.6 }, -- Krasnodar-Center
  [14] = { uhf = 252.0, vhf = 123.0, fm = 38.8 }, -- Novorossiysk
  [15] = { uhf = 253.0, vhf = 124.0, fm = 39.0 }, -- Krymsk
  [16] = { uhf = 254.0, vhf = 125.0, fm = 39.2 }, -- Maykop-Khanskaya
  [17] = { uhf = 255.0, vhf = 126.0, fm = 39.4 }, -- Gelendzhik
  [18] = { uhf = 256.0, vhf = 127.0, fm = 39.6 }, -- Sochi-Adler
  [19] = { uhf = 257.0, vhf = 128.0, fm = 39.8 }, -- Krasnodar-Pashkovsky
  [20] = { uhf = 258.0, vhf = 129.0, fm = 40.0 }, -- Sukhumi-Babushara
  [21] = { uhf = 259.0, vhf = 130.0, fm = 40.2 }, -- Gudauta
  [22] = { uhf = 260.0, vhf = 131.0, fm = 40.4, tacan = "16X" }, -- Batumi
  [23] = { uhf = 261.0, vhf = 132.0, fm = 40.6, tacan = "31X" }, -- Senaki-Kolkhi
  [24] = { uhf = 262.0, vhf = 133.0, fm = 40.8, tacan = "67X" }, -- Kobuleti
  [25] = { uhf = 263.0, vhf = 134.0, fm = 41.0, tacan = "44X" }, -- Kutaisi
  [26] = { uhf = 264.0, vhf = 135.0, fm = 41.2 }, -- Mineralnye Vody
  [27] = { uhf = 265.0, vhf = 136.0, fm = 41.4 }, -- Nalchik
  [28] = { uhf = 266.0, vhf = 137.0, fm = 41.6 }, -- Mozdok
  [29] = { uhf = 267.0, vhf = 138.0, fm = 41.8, tacan = "25X" }, -- Tbilisi-Lochini
  [30] = { uhf = 268.0, vhf = 139.0, fm = 42.0 }, -- Soganlug
  [31] = { uhf = 269.0, vhf = 140.0, fm = 42.2, tacan = "22X" }, -- Vaziani
  [32] = { uhf = 270.0, vhf = 141.0, fm = 42.4 }, -- Beslan
}
veafAirfieldFrequencies["GermanyCW"] = {
  [1] = { uhf = 252.5, vhf = 118.5, fm = 40.9 }, -- Wittstock
  [2] = { uhf = 253.8, vhf = 122.5, fm = 42.2 }, -- Altes Lager
  [3] = { uhf = 254.0, vhf = 124.1, fm = 41.8 }, -- Barth
  [4] = { uhf = 254.05, vhf = 119.8, fm = 40.95 }, -- Zerbst
  [5] = { uhf = 254.1, vhf = 118.45, fm = 41.7 }, -- Bremen
  [6] = { uhf = 254.15, vhf = 135.55, fm = 40.2 }, -- Briest
  [7] = { uhf = 254.2, vhf = 118.05, fm = 39.55 }, -- Buckeburg
  [8] = { uhf = 254.6, vhf = 122.1, fm = 41.9 }, -- Celle
  [9] = { uhf = 254.7, vhf = 126.0, fm = 38.45 }, -- Cochstedt
  [10] = { uhf = 250.5, vhf = 127.1, fm = 38.9 }, -- Damgarten
  [11] = { uhf = 251.0, vhf = 122.1, fm = 39.4, tacan = "95X" }, -- Fassberg
  [12] = { uhf = 251.1, vhf = 125.8, fm = 39.5 }, -- Finow
  [13] = { uhf = 251.15, vhf = 132.8, fm = 39.55 }, -- Garz
  [14] = { uhf = 251.3, vhf = 122.1, fm = 39.7 }, -- Gatow
  [15] = { uhf = 251.65, vhf = 128.0, fm = 40.05 }, -- Templin
  [16] = { uhf = 252.2, vhf = 122.1, fm = 40.6, tacan = "108X" }, -- Gutersloh
  [17] = { uhf = 252.35, vhf = 126.85, fm = 40.75 }, -- Hamburg
  [18] = { uhf = 252.4, vhf = 123.2, fm = 40.8 }, -- Hamburg Finkenwerder
  [19] = { uhf = 252.45, vhf = 120.2, fm = 40.85 }, -- Hannover
  [20] = { uhf = 252.7, vhf = 129.5, fm = 41.1 }, -- Laage
  [21] = { uhf = 252.75, vhf = 129.9, fm = 41.15 }, -- Larz
  [22] = { uhf = 252.8, vhf = 126.1, fm = 41.2 }, -- Mahlwinkel
  [23] = { uhf = 253.0, vhf = 124.5, fm = 41.4 }, -- Neubrandenburg
  [24] = { uhf = 253.45, vhf = 123.5, fm = 41.85 }, -- Neuruppin
  [25] = { uhf = 253.55, vhf = 124.0, fm = 41.95 }, -- Peenemunde
  [26] = { uhf = 253.6, vhf = 121.3, fm = 42.0 }, -- Schonefeld
  [27] = { uhf = 253.65, vhf = 122.0, fm = 42.05 }, -- Stendal
  [28] = { uhf = 253.7, vhf = 124.5, fm = 42.1, tacan = "70X" }, -- Tegel
  [29] = { uhf = 253.75, vhf = 119.5, fm = 42.15, tacan = "88X" }, -- Tempelhof
  [30] = { uhf = 253.85, vhf = 125.5, fm = 42.25 }, -- Tutow
  [31] = { uhf = 253.9, vhf = 122.6, fm = 42.3 }, -- Werneuchen
  [32] = { uhf = 253.95, vhf = 121.1, fm = 39.95, tacan = "116X" }, -- Wunstorf
  [33] = { uhf = 257.8, vhf = 118.35, fm = 42.15, tacan = "57X" }, -- Bornholm
  [34] = { uhf = 255.1, vhf = 122.3, fm = 42.2 }, -- Brand
  [35] = { uhf = 255.15, vhf = 118.15, fm = 42.25 }, -- Brandis
  [36] = { uhf = 225.0, vhf = 118.0, fm = 38.4 }, -- Chojna
  [37] = { uhf = 255.2, vhf = 119.7, fm = 42.3 }, -- Cologne
  [38] = { uhf = 255.25, vhf = 118.3, fm = 42.4 }, -- Dusseldorf
  [39] = { uhf = 255.3, vhf = 118.4, fm = 42.35 }, -- Falkenberg
  [40] = { uhf = 257.8, vhf = 142.2, fm = 42.0 }, -- Heidelberg
  [41] = { uhf = 255.4, vhf = 118.1, fm = 39.65, tacan = "72X" }, -- Kastrup
  [42] = { uhf = 255.45, vhf = 119.9, fm = 41.85 }, -- Kiel
  [43] = { uhf = 266.65, vhf = 138.6, fm = 38.45 }, -- Landstuhl
  [44] = { uhf = 230.0, vhf = 124.0, fm = 38.8 }, -- Mainz Finthen
  [45] = { uhf = 255.6, vhf = 118.8, fm = 39.9 }, -- Sturup
  [46] = { uhf = 255.65, vhf = 120.5, fm = 41.85 }, -- Marxwalde
  [47] = { uhf = 315.7, vhf = 142.9, fm = 40.85 }, -- Nordholz
  [48] = { uhf = 365.0, vhf = 123.0, fm = 41.2, tacan = "77X" }, -- Norvenich
  [49] = { uhf = 365.5, vhf = 124.0, fm = 41.2 }, -- Oranienburg
  [50] = { uhf = 256.1, vhf = 121.25, fm = 42.0 }, -- Szczecin-Goleniow
  [51] = { uhf = 252.05, vhf = 122.9, fm = 40.45 }, -- Obermehler Schlotheim
  [52] = { uhf = 256.15, vhf = 118.0, fm = 42.0 }, -- Adelsheim
  [79] = { uhf = 315.7, vhf = 142.9, fm = 40.25 }, -- Revinge
  [80] = { uhf = 254.25, vhf = 127.0, fm = 40.35 }, -- Gross Mohrdorf
  [81] = { uhf = 254.3, vhf = 128.7, fm = 41.6 }, -- Lubeck
  [82] = { uhf = 254.35, vhf = 125.9, fm = 39.8 }, -- Kothen
  [83] = { uhf = 254.4, vhf = 127.5, fm = 41.3 }, -- Dessau
  [84] = { uhf = 254.45, vhf = 129.0, fm = 39.85 }, -- Parchim
  [86] = { uhf = 254.5, vhf = 119.0, fm = 41.55 }, -- Uetersen
  [87] = { uhf = 255.9, vhf = 118.0, fm = 42.0 }, -- Tagra
  [89] = { uhf = 254.55, vhf = 136.5, fm = 41.45 }, -- Luneburg
  [90] = { uhf = 254.65, vhf = 134.6, fm = 41.25 }, -- Northeim
  [101] = { uhf = 250.1, vhf = 123.1, fm = 38.5 }, -- Sperenberg
  [102] = { uhf = 250.15, vhf = 119.1, fm = 38.55 }, -- Uelzen
  [103] = { uhf = 250.2, vhf = 119.0, fm = 38.6 }, -- Dedelow
  [104] = { uhf = 250.25, vhf = 119.0, fm = 38.65 }, -- Kammermark
  [106] = { uhf = 250.3, vhf = 119.0, fm = 38.7 }, -- Weser Wumme
  [107] = { uhf = 250.35, vhf = 120.05, fm = 38.75 }, -- Braunschweig
  [108] = { uhf = 250.4, vhf = 134.3, fm = 38.8 }, -- Wismar
  [109] = { uhf = 250.45, vhf = 134.8, fm = 38.85 }, -- Waren Vielist
  [110] = { uhf = 250.55, vhf = 134.7, fm = 38.95 }, -- Bienenfarm
  [111] = { uhf = 250.6, vhf = 119.0, fm = 39.0 }, -- Pinnow
  [112] = { uhf = 250.65, vhf = 119.0, fm = 39.05 }, -- Gardelegen
  [113] = { uhf = 250.7, vhf = 119.0, fm = 39.1 }, -- Glindbruchkippe
  [114] = { uhf = 250.75, vhf = 134.2, fm = 39.15 }, -- Ummern
  [115] = { uhf = 250.8, vhf = 118.3, fm = 39.2 }, -- Hildesheim
  [116] = { uhf = 250.85, vhf = 127.7, fm = 39.25 }, -- Verden-Scharnhorst
  [117] = { uhf = 250.9, vhf = 134.8, fm = 39.3 }, -- Rinteln
  [118] = { uhf = 250.95, vhf = 118.2, fm = 39.35 }, -- Holzdorf
  [123] = { uhf = 251.05, vhf = 118.25, fm = 39.45 }, -- Airracing Koblenz
  [125] = { uhf = 255.85, vhf = 118.0, fm = 42.0 }, -- Perwenitz
  [131] = { uhf = 255.9, vhf = 118.0, fm = 42.0 }, -- Sittensen
  [135] = { uhf = 255.95, vhf = 118.0, fm = 42.0 }, -- Sprendlingen
  [136] = { uhf = 256.0, vhf = 118.0, fm = 42.0 }, -- Thurland
  [137] = { uhf = 256.05, vhf = 118.0, fm = 42.0 }, -- Zollschen
  [140] = { uhf = 251.2, vhf = 119.0, fm = 39.6 }, -- Hasselfelde
  [141] = { uhf = 251.25, vhf = 134.6, fm = 39.65 }, -- Grosse Wiese
  [154] = { uhf = 251.35, vhf = 126.5, fm = 39.75 }, -- Fritzlar
  [155] = { uhf = 251.4, vhf = 119.5, fm = 39.8, tacan = "24X" }, -- Hahn
  [156] = { uhf = 251.45, vhf = 121.5, fm = 39.85, tacan = "28X" }, -- Sembach
  [157] = { uhf = 251.5, vhf = 132.5, fm = 39.9 }, -- Allstedt
  [158] = { uhf = 251.55, vhf = 123.0, fm = 39.95, tacan = "48X" }, -- Zweibrucken
  [159] = { uhf = 251.6, vhf = 135.9, fm = 40.0, tacan = "47X" }, -- Giebelstadt
  [160] = { uhf = 251.7, vhf = 119.95, fm = 40.1 }, -- Schweinfurt
  [161] = { uhf = 251.75, vhf = 119.75, fm = 40.15 }, -- Haina
  [162] = { uhf = 251.8, vhf = 122.2, fm = 40.2, tacan = "32X" }, -- Spangdahlem
  [163] = { uhf = 251.85, vhf = 127.3, fm = 40.25, tacan = "89X" }, -- Frankfurt
  [164] = { uhf = 251.9, vhf = 122.1, fm = 40.3 }, -- Bindersleben
  [165] = { uhf = 251.95, vhf = 133.2, fm = 40.35, tacan = "81X" }, -- Ramstein
  [166] = { uhf = 252.0, vhf = 126.0, fm = 40.4 }, -- Fulda
  [168] = { uhf = 252.1, vhf = 122.1, fm = 40.5 }, -- Mendig
  [169] = { uhf = 252.15, vhf = 127.2, fm = 40.55 }, -- Merseburg
  [170] = { uhf = 252.25, vhf = 118.1, fm = 40.65, tacan = "88X" }, -- Wiesbaden
  [171] = { uhf = 252.3, vhf = 129.0, fm = 40.7 }, -- Schkeuditz
  [200] = { uhf = 252.55, vhf = 118.7, fm = 40.95, tacan = "56X" }, -- Bitburg
  [201] = { uhf = 252.6, vhf = 118.35, fm = 41.0 }, -- Airracing Lubeck
  [204] = { uhf = 252.65, vhf = 118.4, fm = 41.05 }, -- Airracing Frankfurt
  [232] = { uhf = 252.85, vhf = 132.65, fm = 41.25, tacan = "77X" }, -- Pferdsfeld
  [235] = { uhf = 252.9, vhf = 122.1, fm = 41.3, tacan = "118X" }, -- Buchel
  [236] = { uhf = 252.95, vhf = 119.75, fm = 41.35 }, -- Leipzig Mockau
  [242] = { uhf = 253.05, vhf = 134.5, fm = 41.45 }, -- Bad Durkheim
  [243] = { uhf = 253.1, vhf = 119.0, fm = 41.5 }, -- Gelnhausen
  [244] = { uhf = 253.15, vhf = 127.4, fm = 41.55 }, -- Herrenteich
  [245] = { uhf = 253.2, vhf = 134.6, fm = 41.6 }, -- Hockenheim
  [246] = { uhf = 253.25, vhf = 126.1, fm = 41.65 }, -- Langenselbold
  [247] = { uhf = 253.3, vhf = 134.6, fm = 41.7 }, -- Walldorf
  [248] = { uhf = 253.35, vhf = 134.6, fm = 41.75 }, -- Ober-Morlen
  [249] = { uhf = 253.4, vhf = 134.6, fm = 41.8 }, -- Pottschutthohe
  [250] = { uhf = 253.5, vhf = 127.1, fm = 41.9 }, -- Worms
}
veafAirfieldFrequencies["MarianaIslands"] = {
  [1] = { uhf = 250.0, vhf = 123.6, fm = 38.4 }, -- Rota Intl
  [2] = { uhf = 256.9, vhf = 125.7, fm = 38.45 }, -- Saipan Intl
  [3] = { uhf = 250.05, vhf = 123.65, fm = 38.5 }, -- Tinian Intl
  [4] = { uhf = 340.2, vhf = 118.1, fm = 38.55 }, -- Antonio B. Won Pat Intl
  [6] = { uhf = 250.1, vhf = 126.2, fm = 38.6, tacan = "54X" }, -- Andersen AFB
}
veafAirfieldFrequencies["Normandy"] = {
  [1] = { uhf = 250.5, vhf = 118.65, fm = 38.95 }, -- Saint Pierre du Mont
  [2] = { uhf = 251.05, vhf = 119.2, fm = 39.5 }, -- Lignerolles
  [3] = { uhf = 251.6, vhf = 119.8, fm = 40.05 }, -- Cretteville
  [4] = { uhf = 252.15, vhf = 120.35, fm = 40.6 }, -- Maupertus
  [5] = { uhf = 252.65, vhf = 120.85, fm = 41.05 }, -- Brucheville
  [6] = { uhf = 253.2, vhf = 121.4, fm = 41.6 }, -- Meautis
  [7] = { uhf = 253.75, vhf = 121.7, fm = 42.15 }, -- Cricqueville-en-Bessin
  [8] = { uhf = 253.95, vhf = 121.85, fm = 42.1 }, -- Lessay
  [9] = { uhf = 254.0, vhf = 121.9, fm = 42.0 }, -- Sainte-Laurent-sur-Mer
  [10] = { uhf = 250.0, vhf = 118.0, fm = 38.45 }, -- Biniville
  [11] = { uhf = 250.05, vhf = 118.1, fm = 38.5 }, -- Cardonville
  [12] = { uhf = 250.1, vhf = 118.15, fm = 38.55 }, -- Deux Jumeaux
  [13] = { uhf = 250.15, vhf = 118.2, fm = 38.6 }, -- Chippelle
  [14] = { uhf = 250.2, vhf = 118.3, fm = 38.65 }, -- Beuzeville
  [15] = { uhf = 250.25, vhf = 118.35, fm = 38.7 }, -- Azeville
  [16] = { uhf = 250.3, vhf = 118.4, fm = 38.75 }, -- Picauville
  [17] = { uhf = 250.35, vhf = 118.5, fm = 38.8 }, -- Le Molay
  [18] = { uhf = 250.4, vhf = 118.55, fm = 38.85 }, -- Longues-sur-Mer
  [19] = { uhf = 250.45, vhf = 118.6, fm = 38.9 }, -- Carpiquet
  [20] = { uhf = 250.55, vhf = 118.7, fm = 39.0 }, -- Bazenville
  [21] = { uhf = 250.6, vhf = 118.75, fm = 39.05 }, -- Sainte-Croix-sur-Mer
  [22] = { uhf = 250.65, vhf = 118.8, fm = 39.1 }, -- Beny-sur-Mer
  [23] = { uhf = 250.7, vhf = 118.85, fm = 39.15 }, -- Rucqueville
  [24] = { uhf = 250.75, vhf = 118.9, fm = 39.2 }, -- Sommervieu
  [25] = { uhf = 250.8, vhf = 118.95, fm = 39.25 }, -- Lantheuil
  [26] = { uhf = 250.85, vhf = 119.0, fm = 39.3 }, -- Evreux
  [27] = { uhf = 250.9, vhf = 119.05, fm = 39.35 }, -- Chailey
  [28] = { uhf = 250.95, vhf = 119.1, fm = 39.4 }, -- Needs Oar Point
  [29] = { uhf = 251.0, vhf = 119.15, fm = 39.45 }, -- Funtington
  [30] = { uhf = 251.1, vhf = 119.3, fm = 39.55 }, -- Tangmere
  [31] = { uhf = 251.15, vhf = 119.35, fm = 39.6 }, -- Ford
  [32] = { uhf = 251.2, vhf = 119.4, fm = 39.65 }, -- Argentan
  [33] = { uhf = 251.25, vhf = 119.45, fm = 39.7 }, -- Goulet
  [34] = { uhf = 251.3, vhf = 119.5, fm = 39.75 }, -- Barville
  [35] = { uhf = 251.35, vhf = 119.55, fm = 39.8 }, -- Essay
  [36] = { uhf = 251.4, vhf = 119.6, fm = 39.85 }, -- Hauterive
  [37] = { uhf = 251.45, vhf = 119.65, fm = 39.9 }, -- Lymington
  [38] = { uhf = 251.5, vhf = 119.7, fm = 39.95 }, -- Vrigny
  [39] = { uhf = 251.55, vhf = 119.75, fm = 40.0 }, -- Odiham
  [40] = { uhf = 251.65, vhf = 119.85, fm = 40.1 }, -- Conches
  [41] = { uhf = 251.7, vhf = 119.9, fm = 40.15 }, -- West Malling
  [42] = { uhf = 251.75, vhf = 119.95, fm = 40.2 }, -- Villacoublay
  [43] = { uhf = 251.8, vhf = 120.0, fm = 40.25 }, -- Kenley
  [44] = { uhf = 251.85, vhf = 120.05, fm = 40.3 }, -- Beauvais-Tille
  [45] = { uhf = 251.9, vhf = 120.1, fm = 40.35 }, -- Cormeilles-en-Vexin
  [46] = { uhf = 251.95, vhf = 120.15, fm = 40.4 }, -- Creil
  [47] = { uhf = 252.0, vhf = 120.2, fm = 40.45 }, -- Guyancourt
  [48] = { uhf = 252.05, vhf = 120.25, fm = 40.5 }, -- Lonrai
  [49] = { uhf = 252.1, vhf = 120.3, fm = 40.55 }, -- Dinan-Trelivan
  [51] = { uhf = 252.2, vhf = 120.4, fm = 40.65 }, -- Fecamp-Benouville
  [52] = { uhf = 252.25, vhf = 120.45, fm = 40.7 }, -- Farnborough
  [53] = { uhf = 252.3, vhf = 120.5, fm = 40.75 }, -- Friston
  [54] = { uhf = 252.35, vhf = 120.55, fm = 40.8 }, -- Deanland
  [55] = { uhf = 252.4, vhf = 120.6, fm = 40.85 }, -- Triqueville
  [56] = { uhf = 252.45, vhf = 120.65, fm = 40.9 }, -- Poix
  [57] = { uhf = 252.5, vhf = 120.7, fm = 40.95 }, -- Orly
  [58] = { uhf = 252.55, vhf = 120.75, fm = 41.0 }, -- Stoney Cross
  [59] = { uhf = 252.6, vhf = 120.8, fm = 38.4 }, -- Amiens-Glisy
  [60] = { uhf = 252.7, vhf = 120.9, fm = 41.1 }, -- Ronai
  [61] = { uhf = 252.75, vhf = 120.95, fm = 41.15 }, -- Rouen-Boos
  [62] = { uhf = 252.8, vhf = 121.0, fm = 41.2 }, -- Deauville
  [63] = { uhf = 252.85, vhf = 121.05, fm = 41.25 }, -- Saint-Aubin
  [64] = { uhf = 252.9, vhf = 121.1, fm = 41.3 }, -- Flers
  [65] = { uhf = 252.95, vhf = 121.15, fm = 41.35 }, -- Avranches Le Val-Saint-Pere
  [66] = { uhf = 253.0, vhf = 121.2, fm = 41.4 }, -- Gravesend
  [67] = { uhf = 253.05, vhf = 121.25, fm = 41.45 }, -- Beaumont-le-Roger
  [68] = { uhf = 253.1, vhf = 121.3, fm = 41.5 }, -- Broglie
  [69] = { uhf = 253.15, vhf = 121.35, fm = 41.55 }, -- Bernay Saint Martin
  [70] = { uhf = 253.25, vhf = 121.45, fm = 41.65 }, -- Saint-Andre-de-lEure
  [71] = { uhf = 253.3, vhf = 134.8, fm = 41.7 }, -- Biggin Hill
  [72] = { uhf = 253.35, vhf = 118.25, fm = 41.75 }, -- Manston
  [73] = { uhf = 253.4, vhf = 118.45, fm = 41.8 }, -- Detling
  [74] = { uhf = 253.45, vhf = 121.5, fm = 41.85 }, -- Lympne
  [75] = { uhf = 253.5, vhf = 118.05, fm = 41.9 }, -- Abbeville Drucat
  [76] = { uhf = 253.55, vhf = 121.55, fm = 41.95 }, -- Saint-Omer Wizernes
  [77] = { uhf = 253.6, vhf = 121.6, fm = 42.0 }, -- Merville Calonne
  [78] = { uhf = 253.65, vhf = 121.65, fm = 42.05 }, -- High Halden
  [79] = { uhf = 253.7, vhf = 132.45, fm = 42.1 }, -- Dunkirk-Mardyck
  [80] = { uhf = 253.8, vhf = 121.75, fm = 42.2 }, -- Lashenden
  [81] = { uhf = 253.85, vhf = 119.25, fm = 42.25 }, -- Eastchurch
  [82] = { uhf = 253.9, vhf = 121.8, fm = 42.3 }, -- Hawkinge
  [83] = { uhf = 254.1, vhf = 118.25, fm = 42.3 }, -- Guernsey
  [84] = { uhf = 254.15, vhf = 122.0, fm = 42.2 }, -- Jersey
  [85] = { uhf = 254.2, vhf = 122.05, fm = 42.4 }, -- Alderney
  [86] = { uhf = 254.25, vhf = 122.1, fm = 42.4 }, -- Headcorn
  [87] = { uhf = 254.3, vhf = 122.15, fm = 41.4 }, -- Saint-Pol-Bryas
  [88] = { uhf = 254.35, vhf = 122.5, fm = 41.6 }, -- Northolt
  [89] = { uhf = 254.4, vhf = 122.6, fm = 41.9 }, -- Holmsley South
  [90] = { uhf = 360.0, vhf = 123.0, fm = 42.35 }, -- Bembridg
}
veafAirfieldFrequencies["PersianGulf"] = {
  [1] = { uhf = 250.4, vhf = 122.9, fm = 38.85 }, -- Abu Musa Island
  [2] = { uhf = 251.0, vhf = 118.1, fm = 39.4, tacan = "78X" }, -- Bandar Abbas Intl
  [3] = { uhf = 251.05, vhf = 121.7, fm = 39.45 }, -- Bandar Lengeh
  [4] = { uhf = 251.1, vhf = 126.5, fm = 39.5, tacan = "96X" }, -- Al Dhafra AFB
  [5] = { uhf = 251.15, vhf = 118.75, fm = 39.55 }, -- Dubai Intl
  [6] = { uhf = 251.2, vhf = 118.6, fm = 39.6 }, -- Al Maktoum Intl
  [7] = { uhf = 251.25, vhf = 124.6, fm = 39.65 }, -- Fujairah Intl
  [9] = { uhf = 251.3, vhf = 123.15, fm = 39.7, tacan = "47X" }, -- Havadarya
  [10] = { uhf = 250.0, vhf = 124.35, fm = 38.4 }, -- Khasab
  [11] = { uhf = 250.05, vhf = 127.35, fm = 38.45 }, -- Lar
  [12] = { uhf = 250.1, vhf = 118.55, fm = 38.5, tacan = "99X" }, -- Al Minhad AFB
  [13] = { uhf = 250.15, vhf = 118.05, fm = 38.55 }, -- Qeshm Island
  [14] = { uhf = 250.2, vhf = 118.6, fm = 38.6 }, -- Sharjah Intl
  [15] = { uhf = 250.25, vhf = 135.05, fm = 38.65 }, -- Sirri Island
  [17] = { uhf = 250.8, vhf = 118.0, fm = 38.7 }, -- Sir Abu Nuayr
  [18] = { uhf = 250.3, vhf = 118.25, fm = 38.75, tacan = "97X" }, -- Kerman
  [19] = { uhf = 250.35, vhf = 121.9, fm = 38.8, tacan = "94X" }, -- Shiraz Intl
  [20] = { uhf = 250.45, vhf = 128.9, fm = 38.9 }, -- Sas Al Nakheel
  [21] = { uhf = 250.5, vhf = 118.15, fm = 38.95, tacan = "110X" }, -- Bandar-e-Jask
  [22] = { uhf = 250.55, vhf = 119.2, fm = 39.0 }, -- Abu Dhabi Intl
  [23] = { uhf = 250.6, vhf = 119.9, fm = 39.05 }, -- Al-Bateen
  [24] = { uhf = 250.65, vhf = 121.65, fm = 39.1, tacan = "112X" }, -- Kish Intl
  [25] = { uhf = 250.7, vhf = 119.85, fm = 39.15 }, -- Al Ain Intl
  [26] = { uhf = 250.75, vhf = 128.55, fm = 39.2 }, -- Lavan Island
  [27] = { uhf = 250.85, vhf = 136.0, fm = 39.25 }, -- Jiroft
  [28] = { uhf = 250.9, vhf = 121.6, fm = 39.3 }, -- Ras Al Khaimah Intl
  [29] = { uhf = 250.95, vhf = 119.3, fm = 39.35, tacan = "121X" }, -- Liwa AFB
}
veafAirfieldFrequencies["SinaiMap"] = {
  [1] = { uhf = 250.55, vhf = 118.45, fm = 38.95 }, -- Difarsuwar Airfield
  [2] = { uhf = 251.1, vhf = 118.85, fm = 39.5 }, -- Abu Suwayr
  [3] = { uhf = 251.65, vhf = 119.35, fm = 40.05 }, -- As Salihiyah
  [4] = { uhf = 252.0, vhf = 118.1, fm = 40.4 }, -- Al Ismailiyah
  [5] = { uhf = 252.05, vhf = 119.65, fm = 40.45 }, -- Melez
  [6] = { uhf = 252.1, vhf = 119.7, fm = 40.5 }, -- Fayed
  [7] = { uhf = 252.15, vhf = 119.75, fm = 40.55, tacan = "96X" }, -- Hatzerim
  [8] = { uhf = 252.2, vhf = 132.4, fm = 40.6 }, -- Nevatim
  [9] = { uhf = 252.25, vhf = 119.8, fm = 40.65, tacan = "105X" }, -- Ramon Airbase
  [10] = { uhf = 250.05, vhf = 129.9, fm = 38.45 }, -- Ovda
  [11] = { uhf = 250.1, vhf = 118.05, fm = 38.5, tacan = "55X" }, -- Kibrit Air Base
  [12] = { uhf = 250.15, vhf = 118.15, fm = 38.55 }, -- Kedem
  [13] = { uhf = 250.2, vhf = 118.9, fm = 38.6 }, -- Wadi al Jandali
  [14] = { uhf = 250.25, vhf = 118.25, fm = 38.65 }, -- Al Mansurah
  [15] = { uhf = 250.3, vhf = 118.3, fm = 38.7 }, -- AzZaqaziq
  [16] = { uhf = 250.35, vhf = 118.35, fm = 38.75 }, -- Bilbeis Air Base
  [17] = { uhf = 250.4, vhf = 118.1, fm = 38.8 }, -- Cairo International Airport
  [18] = { uhf = 250.45, vhf = 131.2, fm = 38.85 }, -- Cairo West
  [19] = { uhf = 250.5, vhf = 118.4, fm = 38.9 }, -- Inshas Airbase
  [20] = { uhf = 250.6, vhf = 118.55, fm = 39.0, tacan = "106X" }, -- Hatzor
  [21] = { uhf = 250.65, vhf = 118.6, fm = 39.05 }, -- Palmachim
  [22] = { uhf = 250.7, vhf = 118.65, fm = 39.1 }, -- Sde Dov
  [23] = { uhf = 250.75, vhf = 118.7, fm = 39.15, tacan = "87X" }, -- Tel Nof
  [24] = { uhf = 250.8, vhf = 134.6, fm = 39.2 }, -- Ben-Gurion
  [25] = { uhf = 250.85, vhf = 124.5, fm = 39.25 }, -- St Catherine
  [26] = { uhf = 250.9, vhf = 118.5, fm = 39.3 }, -- Abu Rudeis
  [27] = { uhf = 250.95, vhf = 118.75, fm = 39.35 }, -- Baluza
  [28] = { uhf = 251.0, vhf = 118.8, fm = 39.4 }, -- Bir Hasanah
  [29] = { uhf = 251.05, vhf = 121.0, fm = 39.45 }, -- El Arish
  [30] = { uhf = 251.15, vhf = 118.2, fm = 39.55 }, -- El Gora
  [31] = { uhf = 251.2, vhf = 118.95, fm = 39.6 }, -- Al Khatatbah
  [32] = { uhf = 251.25, vhf = 119.05, fm = 39.65 }, -- Al Rahmaniyah Air Base
  [33] = { uhf = 251.3, vhf = 127.1, fm = 39.7 }, -- Beni Suef
  [34] = { uhf = 251.35, vhf = 119.15, fm = 39.75 }, -- Birma Air Base
  [35] = { uhf = 251.4, vhf = 119.1, fm = 39.8 }, -- Borg El Arab International Airport
  [36] = { uhf = 251.45, vhf = 119.2, fm = 39.85 }, -- El Minya
  [37] = { uhf = 251.5, vhf = 119.25, fm = 39.9 }, -- Gebel El Basur Air Base
  [38] = { uhf = 251.55, vhf = 119.6, fm = 39.95 }, -- Hurghada International Airport
  [39] = { uhf = 251.6, vhf = 119.3, fm = 40.0 }, -- Jiyanklis Air Base
  [40] = { uhf = 251.7, vhf = 119.4, fm = 40.1 }, -- Kom Awshim
  [41] = { uhf = 251.75, vhf = 119.0, fm = 40.15 }, -- Ramon International Airport
  [42] = { uhf = 251.8, vhf = 118.9, fm = 40.2 }, -- Sharm El Sheikh International Airport
  [43] = { uhf = 251.85, vhf = 119.45, fm = 40.25 }, -- Wadi Abu Rish
  [44] = { uhf = 251.9, vhf = 119.5, fm = 40.3 }, -- Al Bahr al Ahmar
  [45] = { uhf = 251.95, vhf = 119.55, fm = 40.35 }, -- Quwaysina
  [47] = { uhf = 229.4, vhf = 125.9, fm = 42.15 }, -- Tabuk
  [48] = { uhf = 226.1, vhf = 118.5, fm = 40.95 }, -- Damascus Intl
  [49] = { uhf = 227.2, vhf = 126.0, fm = 41.35 }, -- Mezzeh Air Base
  [50] = { uhf = 251.1, vhf = 118.0, fm = 38.4, tacan = "84X" }, -- Ramat David
  [51] = { uhf = 225.9, vhf = 123.0, fm = 41.15 }, -- Megiddo
  [52] = { uhf = 227.85, vhf = 124.55, fm = 41.45 }, -- Ein Shamer
  [53] = { uhf = 227.15, vhf = 121.9, fm = 42.2 }, -- Taba International Airport
  [54] = { uhf = 227.95, vhf = 129.2, fm = 40.75 }, -- King Feisal Air Base
  [55] = { uhf = 227.9, vhf = 128.4, fm = 40.7 }, -- Khalkhalah Air Base
}
veafAirfieldFrequencies["Syria"] = {
  [1] = { uhf = 250.5, vhf = 122.2, fm = 38.95 }, -- Abu al-Duhur
  [2] = { uhf = 251.25, vhf = 121.1, fm = 39.7 }, -- Adana Sakirpasa
  [3] = { uhf = 251.8, vhf = 119.2, fm = 40.25 }, -- Al Qusayr
  [4] = { uhf = 252.3, vhf = 122.3, fm = 40.75 }, -- An Nasiriyah
  [5] = { uhf = 252.8, vhf = 118.0, fm = 41.25 }, -- Tha'lah
  [6] = { uhf = 253.2, vhf = 118.9, fm = 41.65 }, -- Beirut-Rafic Hariri
  [7] = { uhf = 253.25, vhf = 118.5, fm = 41.7 }, -- Damascus
  [8] = { uhf = 253.3, vhf = 122.9, fm = 41.75 }, -- Marj as Sultan South
  [9] = { uhf = 253.35, vhf = 120.3, fm = 41.8 }, -- Al-Dumayr
  [10] = { uhf = 250.05, vhf = 123.4, fm = 38.45 }, -- Eyn Shemer
  [11] = { uhf = 250.1, vhf = 120.1, fm = 38.5 }, -- Gaziantep
  [12] = { uhf = 250.15, vhf = 122.6, fm = 38.55 }, -- H4
  [13] = { uhf = 250.2, vhf = 127.8, fm = 38.6 }, -- Haifa
  [14] = { uhf = 250.25, vhf = 118.05, fm = 38.65 }, -- Hama
  [15] = { uhf = 250.3, vhf = 128.5, fm = 38.7 }, -- Hatay
  [16] = { uhf = 360.1, vhf = 122.1, fm = 38.75, tacan = "21X" }, -- Incirlik
  [17] = { uhf = 250.35, vhf = 118.1, fm = 38.8 }, -- Jirah
  [18] = { uhf = 250.4, vhf = 122.5, fm = 38.85 }, -- Khalkhalah
  [19] = { uhf = 250.45, vhf = 118.3, fm = 38.9 }, -- King Hussein Air College
  [20] = { uhf = 250.55, vhf = 118.4, fm = 39.0 }, -- Kiryat Shmona
  [21] = { uhf = 250.6, vhf = 118.1, fm = 39.05 }, -- Bassel Al-Assad
  [22] = { uhf = 250.85, vhf = 122.7, fm = 39.3 }, -- Marj as Sultan North
  [23] = { uhf = 250.9, vhf = 120.8, fm = 39.35 }, -- Marj Ruhayyil
  [24] = { uhf = 250.95, vhf = 119.9, fm = 39.4 }, -- Megiddo
  [25] = { uhf = 251.0, vhf = 120.7, fm = 39.45 }, -- Mezzeh
  [26] = { uhf = 251.05, vhf = 120.6, fm = 39.5 }, -- Minakh
  [27] = { uhf = 251.1, vhf = 119.1, fm = 39.55 }, -- Aleppo
  [28] = { uhf = 251.15, vhf = 121.9, fm = 39.6 }, -- Palmyra
  [29] = { uhf = 251.2, vhf = 122.6, fm = 39.65 }, -- Qabr as Sitt
  [30] = { uhf = 251.3, vhf = 118.6, fm = 39.75, tacan = "84X" }, -- Ramat David
  [31] = { uhf = 251.35, vhf = 120.5, fm = 39.8 }, -- Kuweires
  [32] = { uhf = 251.4, vhf = 124.4, fm = 39.85 }, -- Rayak
  [33] = { uhf = 251.45, vhf = 121.0, fm = 39.9 }, -- Rene Mouawad
  [34] = { uhf = 251.5, vhf = 118.45, fm = 39.95 }, -- Rosh Pina
  [35] = { uhf = 251.55, vhf = 120.4, fm = 40.0 }, -- Sayqal
  [36] = { uhf = 251.6, vhf = 120.2, fm = 40.05 }, -- Shayrat
  [37] = { uhf = 251.65, vhf = 118.5, fm = 40.1 }, -- Tabqa
  [38] = { uhf = 251.7, vhf = 122.8, fm = 40.15 }, -- Taftanaz
  [39] = { uhf = 251.75, vhf = 120.5, fm = 40.2 }, -- Tiyas
  [40] = { uhf = 251.85, vhf = 120.5, fm = 40.3 }, -- Wujah Al Hajar
  [41] = { uhf = 251.9, vhf = 119.25, fm = 40.35 }, -- Gazipasa
  [42] = { uhf = 251.95, vhf = 118.1, fm = 40.4 }, -- Deir ez-Zor
  [44] = { uhf = 252.0, vhf = 128.0, fm = 40.45, tacan = "107X" }, -- Akrotiri
  [45] = { uhf = 252.05, vhf = 121.0, fm = 40.5 }, -- Kingsfield
  [46] = { uhf = 252.1, vhf = 119.9, fm = 40.55, tacan = "79X" }, -- Paphos
  [47] = { uhf = 252.15, vhf = 121.2, fm = 40.6 }, -- Larnaca
  [48] = { uhf = 252.2, vhf = 120.2, fm = 40.65 }, -- Lakatamia
  [49] = { uhf = 252.25, vhf = 120.2, fm = 40.7 }, -- Ercan
  [50] = { uhf = 252.35, vhf = 120.0, fm = 40.8 }, -- Gecitkale
  [51] = { uhf = 252.4, vhf = 121.0, fm = 40.85 }, -- Pinarbashi
  [52] = { uhf = 252.45, vhf = 122.0, fm = 40.9 }, -- Naqoura
  [53] = { uhf = 252.5, vhf = 122.0, fm = 40.95 }, -- H3
  [54] = { uhf = 252.55, vhf = 122.1, fm = 41.0 }, -- H3 Northwest
  [55] = { uhf = 252.6, vhf = 122.4, fm = 41.05 }, -- H3 Southwest
  [56] = { uhf = 252.1, vhf = 119.9, fm = 40.55 }, -- Zarqa
  [57] = { uhf = 252.65, vhf = 122.1, fm = 41.1 }, -- Ruwayshid
  [58] = { uhf = 252.7, vhf = 118.4, fm = 41.15 }, -- Sanliurfa
  [59] = { uhf = 252.75, vhf = 122.2, fm = 41.2 }, -- Kharab Ishk
  [60] = { uhf = 252.85, vhf = 121.9, fm = 41.3 }, -- Tal Siman
  [61] = { uhf = 250.0, vhf = 118.5, fm = 40.0 }, -- H4 Emergency
  [62] = { uhf = 225.0, vhf = 132.4, fm = 38.9 }, -- Nevatim
  [63] = { uhf = 252.9, vhf = 121.1, fm = 41.35 }, -- At Tanf
  [64] = { uhf = 252.95, vhf = 122.6, fm = 41.4, tacan = "106X" }, -- Prince Hassan
  [65] = { uhf = 253.0, vhf = 118.4, fm = 41.45 }, -- King Abdullah II
  [66] = { uhf = 253.05, vhf = 122.2, fm = 41.5 }, -- Herzliya
  [67] = { uhf = 253.1, vhf = 118.1, fm = 41.55 }, -- Marka
  [68] = { uhf = 253.15, vhf = 120.5, fm = 41.6 }, -- Muwaffaq Salti
  [75] = { uhf = 225.0, vhf = 118.75, fm = 38.4 }, -- Kahramanmaras
  [81] = { uhf = 259.0, vhf = 128.2, fm = 41.95, tacan = "96X" }, -- Hatzerim
  [88] = { uhf = 256.0, vhf = 119.0, fm = 41.9 }, -- Kedem
  [90] = { uhf = 245.0, vhf = 120.8, fm = 38.4 }, -- Chukurova
  [91] = { uhf = 255.0, vhf = 123.5, fm = 42.0 }, -- Teyman
  [217] = { uhf = 225.0, vhf = 132.4, fm = 38.9, tacan = "37X" }, -- Diyarbakir
  [218] = { uhf = 225.0, vhf = 132.4, fm = 38.9, tacan = "88X" }, -- Konya
  [219] = { uhf = 243.0, vhf = 121.5, fm = 41.85 }, -- Adiyaman
  [220] = { uhf = 250.65, vhf = 128.1, fm = 39.1, tacan = "87X" }, -- Tel Nof
  [221] = { uhf = 250.7, vhf = 134.6, fm = 39.15 }, -- Ben Gurion
  [222] = { uhf = 250.75, vhf = 125.75, fm = 39.2, tacan = "106X" }, -- Hatzor
  [223] = { uhf = 250.8, vhf = 118.25, fm = 39.25 }, -- Palmachim
  [225] = { uhf = 255.0, vhf = 123.5, fm = 42.0 }, -- T2
  [226] = { uhf = 251.9, vhf = 119.25, fm = 40.35 }, -- T3
}
