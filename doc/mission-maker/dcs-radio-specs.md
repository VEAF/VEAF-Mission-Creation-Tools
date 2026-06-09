# Spécifications des fréquences radio DCS

Table de référence des plages de fréquences radio valides pour tous les appareils DCS pilotables
par les joueurs. Utilisée par `inject-presets` pour vérifier que les fréquences définies dans
`presets.yaml` sont compatibles avec le matériel radio de l'appareil cible.

> **Source** : [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)  
> Régénérez avec `poetry run update-radio-specs` après un patch DCS.

---

## Appareils critiques (`dcs_rejects_on_load`)

Certains appareils provoquent une erreur DCS bloquante au chargement de la mission si une fréquence
de preset se trouve hors de leur plage radio valide. Ils sont marqués `dcs_rejects_on_load: true`
dans `dcs-radio-specs.yaml` et émettent toujours un `WARNING` pendant `veaf-tools build`.

Appareils critiques actuellement connus :

| Appareil | ID DCS | Plage valide |
|----------|--------|--------------|
| MiG-19P | `MiG-19P` | 100–150 MHz |
| Gazelle SA342M | `SA342M` | 30–87.975 MHz (FM uniquement) |

Pour les autres appareils, DCS enregistre les fréquences silencieusement sans planter. Les
problèmes restent signalés dans le `presets-validation-report.md` généré automatiquement après
chaque build.

Si vous découvrez un autre appareil qui pousse DCS à rejeter la mission, ajoutez
`dcs_rejects_on_load: true` à son entrée dans
`src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml` et ouvrez une pull request.

---

## Avions

| Appareil | ID DCS | Radio | Min (MHz) | Max (MHz) | Modulation |
|----------|--------|-------|----------:|----------:|------------|
| **TurboFan** | `A-10C` | VHF AM: ARC-186 | 116.000 | 151.975 | AM / FM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-186 | 30.000 | 87.995 | AM / FM |
| **TurboFan** | `A-10C_2` | UHF/VHF: ARC-210 | 30.000 | 87.975 | FM |
|  |  |  | 108.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.975 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-186 | 30.000 | 87.995 | AM / FM |
| **A6E** | `A6E` | UHF AN/ARC-159 #1 | 225.000 | 399.975 | AM / FM |
|  |  | UHF AN/ARC-159 #2 | 225.000 | 399.975 | AM / FM |
| **AJS37** | `AJS37` | Radio frequencies | 103.000 | 400.000 | AM / FM |
| **AV8BNA** | `AV8BNA` | V/UHF Radio 1 | 30.000 | 400.000 | AM / FM |
|  |  | V/UHF Radio 2 | 30.000 | 400.000 | AM / FM |
|  |  | V/UHF RCS Presets | 30.000 | 400.000 | AM / FM |
| **Inline** | `Bf-109K-4` | FuG 16 ZY | 38.000 | 156.000 | AM / FM |
| **TurboFan** | `C-101CC` | V/TVU-740 | 118.000 | 399.975 | AM / FM |
| **TurboFan** | `C-101EB` | AN/ARC-164 | 225.000 | 399.975 | AM / FM |
| **TurboProp** | `C-130J-30` | UHF-1/2 | 225.000 | 399.975 | AM |
|  |  | VHF-1/2 | 30.000 | 200.975 | AM |
| **Christen Eagle II** | `Christen Eagle II` | KY 197A | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **F-14A-135-GR** | `F-14A-135-GR` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14A-135-GR-Early** | `F-14A-135-GR-Early` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14B** | `F-14B` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **TurboFan** | `F-15ESE` | UHF Radio 1 | 225.000 | 399.975 | AM / FM |
|  |  | V/UHF Radio 2 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **TurboFan** | `F-16C_50` | COMM 1 (UHF) AN/ARC-164 | 225.000 | 399.975 | AM |
|  |  | COMM 2 (VHF) AN/ARC-222 | 30.000 | 87.975 | FM |
|  |  |  | 116.000 | 155.975 | AM |
| **F-4E-45MC** | `F-4E-45MC` | UHF AN/ARC-164 COMM channels | 225.000 | 399.950 | AM / FM |
|  |  | UHF AN/ARC-164 AUX channels | 265.000 | 284.900 | AM / FM |
| **TurboJet** | `F-5E-3` | UHF Radio AN/ARC-164 | 225.000 | 399.999 | AM / FM |
| **TurboJet** | `F-86F Sabre` | AN/ARC-27 | 225.000 | 399.900 | AM / FM |
| **TurboJet** | `F-86F_FC` | AN/ARC-27 | 225.000 | 399.900 | AM / FM |
| **Radial** | `F4U-1D` | ARC-5 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
|  |  | ARR-2 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **Radial** | `F4U-1D_CW` | ARC-5 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
|  |  | ARR-2 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **TurboJet** | `FA-18C` | COMM 1: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | COMM 2: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **TurboFan** | `FA-18C_hornet` | COMM 1: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | COMM 2: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **Radial** | `FW-190A8` | FuG 16 Z | 38.000 | 156.000 | AM / FM |
| **Piston** | `FW-190D9` | FuG 16 Z | 38.000 | 156.000 | AM / FM |
| **Hawk** | `Hawk` | Radio 1 | 225.000 | 399.900 | AM / FM |
| **Radial** | `I-16` | SCR522 | 100.000 | 156.000 | AM / FM |
| **JF-17** | `JF-17` | COMM 1/2 Preset | 30.000 | 399.995 | AM / FM |
| **TurboJet** | `L-39C` | R-832M | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **TurboJet** | `L-39ZA` | R-832M | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **La-7** | `La-7` | SCR522 | 100.000 | 156.000 | AM / FM |
| **M-2000C** | `M-2000C` | UHF Radio | 225.000 | 400.000 | AM / FM |
|  |  | V/UHF Radio | 118.000 | 140.000 | AM / FM |
|  |  |  | 225.000 | 400.000 | AM / FM |
| **TurboJet** | `MB-339A` | AN/ARC-150(V)-2 | 225.000 | 399.975 | AM / FM |
|  |  | SRT-651/N | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 136.992 | AM / FM |
|  |  |  | 137.000 | 155.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `MB-339APAN` | AN/ARC-150(V)-2 | 225.000 | 399.975 | AM / FM |
|  |  | SRT-651/N | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 136.992 | AM / FM |
|  |  |  | 137.000 | 155.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **MiG-19P** | `MiG-19P` | RSIU-4V Radio | 100.000 | 150.000 | AM / FM |
| **MiG-21Bis** | `MiG-21Bis` | R-832 | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **TurboJet** | `MiG-29 Fulcrum` | VHF/UHF Radio R-862 | 100.000 | 149.975 | AM / FM |
|  |  |  | 220.000 | 399.975 | AM / FM |
|  |  | ARK-19 | 0.150 | 1.300 | AM / FM |
| **TurboJet** | `Mirage-F1AD` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1AZ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1B` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1BD` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1BE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1BQ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1C` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1C-200` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CG` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CH` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CJ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CK` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CR` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CT` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1CZ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1DDA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1ED` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1EDA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1EE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1EH` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1EQ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1JA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1M-CE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **TurboJet** | `Mirage-F1M-EE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Piston** | `MosquitoFBMkVI` | TR.1143 | 38.000 | 156.000 | AM / FM |
|  |  | T.1154N Range 1 | 5.500 | 10.000 | AM / FM |
|  |  | T.1154N Range 2 | 3.000 | 5.500 | AM / FM |
|  |  | T.1154N Range 3 | 200.000 | 500.000 | AM / FM |
| **Radial** | `P-47D-30` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Radial** | `P-47D-30bl1` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Radial** | `P-47D-40` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Piston** | `P-51D` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Piston** | `P-51D-30-NA` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **QF-4E** | `QF-4E` | UHF AN/ARC-164 COMM channels | 225.000 | 399.950 | AM / FM |
|  |  | UHF AN/ARC-164 AUX channels | 265.000 | 284.900 | AM / FM |
| **Piston** | `SpitfireLFMkIX` | TR.1143 | 38.000 | 156.000 | AM / FM |
| **Piston** | `SpitfireLFMkIXCW` | TR.1143 | 38.000 | 156.000 | AM / FM |
| **Piston** | `TF-51D` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Radial** | `Yak-52` | ARK-15M | 0.100 | 1.795 | AM / FM |

## Hélicoptères

| Appareil | ID DCS | Radio | Min (MHz) | Max (MHz) | Modulation |
|----------|--------|-------|----------:|----------:|------------|
| **TurboShaft** | `AH-64D_BLK_II` | ARC-186 | 108.000 | 151.975 | AM / FM |
|  |  | ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | FM 1: ARC-201D | 30.000 | 87.975 | FM |
|  |  | FM 2: ARC-201D | 30.000 | 87.975 | FM |
| **TurboShaft** | `CH-47Fbl1` | VHF FM: ARC-186 | 30.000 | 87.975 | FM |
|  |  |  | 108.000 | 115.975 | AM |
|  |  |  | 116.000 | 151.975 | AM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-201D | 30.000 | 87.975 | FM |
| **TurboShaft** | `Ka-50` | R-828 | 20.000 | 59.900 | AM / FM |
|  |  | ARK-22 | 0.150 | 1.750 | AM / FM |
| **TurboShaft** | `Ka-50_3` | R-828 | 20.000 | 59.900 | AM / FM |
|  |  | ARK-22 | 0.150 | 1.750 | AM / FM |
| **TurboShaft** | `Mi-24P` | R-863 | 100.000 | 399.900 | AM / FM |
|  |  | R-828 | 20.000 | 59.900 | AM / FM |
| **TurboShaft** | `Mi-8MT` | R-863 | 100.000 | 399.900 | AM / FM |
|  |  | R-828 | 20.000 | 59.900 | AM / FM |
| **OH58D** | `OH58D` | UHF AM | 225.000 | 399.975 | AM / FM |
|  |  | VHF AM | 116.000 | 151.975 | AM / FM |
|  |  | VHF FM1 | 30.000 | 87.975 | AM / FM |
|  |  | VHF FM2 | 30.000 | 87.975 | AM / FM |
| **SA342L** | `SA342L` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342M** | `SA342M` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342Minigun** | `SA342Minigun` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342Mistral** | `SA342Mistral` | FM Radio | 30.000 | 87.975 | AM / FM |
| **TurboShaft** | `UH-1H` | UHF AN/ARC-51 | 225.000 | 399.975 | AM / FM |
