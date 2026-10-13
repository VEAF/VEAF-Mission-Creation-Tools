# 06 — A Fw 190 tunes 38.4-42.4 MHz only: the plan has no role for it

Status: ✅ done — narrowed; the proposed feature rests on a wrong premise
Type: feat
Files: `presets_injector/presets_injector_worker.py` (l. 323), `presets_injector/data/dcs-radio-layouts.yaml`, `doc/developer/radio-preset-projection.en.md`, tests

## What happens

`primary_2` is « the warbirds' single radio », VHF band. The build log for the Normandy Open Training says: « FW-190A8 (121.5 MHz, primary limited to 38.4–42.4 MHz), FW-190D9 (…) : le canal 1 est hors de la plage de fréquence principale accordable de l'appareil ; le groupe conserve donc sa propre fréquence (les préréglages sont injectés normalement) ». So a red Fw 190 flies on its default radio, whatever the plan says, and the kneeboard lists VHF frequencies the aircraft cannot tune. The Bf 109 K-4 (38-156), P-51D, P-47D, Spitfire and Mosquito (38-156 or 100-156) are fine; the tower FM frequencies of the Normandy airfields are 38.4-42.4 MHz — exactly the Fw 190's band (`describe_airfield_channels`: every base has `fm`).

The mission worked around it with a manual `presets_assignments` (`FW-190A8`/`FW-190D9` → a `radios_collection` of type `fm` carrying the red bases' `fm` frequencies, `tools/gen_12_presets.py`).

## What ships

- A role for an aircraft whose only radio is narrower than the VHF band: the packer takes the channel's `fm` frequency when the radio's range only covers it (`radio-specs`: `FW-190A8` `min 38.4 max 42.4`), instead of dropping the channel and keeping the group's own frequency.
- The log line says which frequency the type got, not only what it could not.

## Done when

With a red `primary_2` list of bases, a Fw 190 slot gets the bases' FM frequencies without a hand-written assignment; a P-51D still gets VHF.

## Done

The finding is mostly wrong. A Fw 190's radio is a FuG 16 Z that tunes **38–156 MHz** as presets (`radios[0].ranges`); only the group's *primary frequency* is limited to 38.4–42.4 MHz (`human_radio`). So the plan's VHF channels are injected and tunable — the build log says « les préréglages sont injectés normalement » — and nothing the kneeboard lists is out of the aircraft's reach. What stays true is that channel 1 cannot become the primary frequency, and the group keeps its own.

The log line now says what the type got, not only what it did not: `FW-190A8 (134.0 MHz, primary limited to 38.4–42.4 MHz, stays on 38.4 MHz)`. The harm the Normandy session actually met is ticket 13: the group's own frequency was 251 MHz, which the editor refuses.

Left to David: whether the first plan channel that *fits* the primary range (a base's FM tower frequency, 38.4–42.4) should become the Fw 190's primary instead of its default. It is a packer design change (the role carries `fm` channels that are skipped for promotion today), not a defect, and nothing in the build needs it.
