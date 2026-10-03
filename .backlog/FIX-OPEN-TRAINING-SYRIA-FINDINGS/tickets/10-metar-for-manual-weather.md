# 10 — ${METAR} for a manual-weather variant

Status: ✅ done

Files: the weather injector, `doc/PIPELINE_REFERENCE.md`, tests.

## What happened

The Open Training prompt asks for variants « réel / dégagé / épars / pluie » and the briefing carries
`${METAR}`. A variant with `weather:` only has no METAR, so the build left `${METAR}` printed raw in six of
the fifteen briefings (documented in `PIPELINE_REFERENCE.md`). The mission worked around it with a
hand-written `metar:` per variant.

## Done when

- A variant with `weather:` and no METAR gets one composed from it (wind, visibility, cover and base, rain,
  temperature, QNH when given), stamped with the variant's date and time, and used for `${METAR}`.
- The doc table says so.
