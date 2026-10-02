# FIX-CLEARSKY-METAR — `${METAR}` describes the capped sky of a `clearsky` variant

Status: ✅ done

Found by David on 2026-10-02 on the Syria Open Training v6 (`develop` at cba707a0). The `*-real-clear`
variants declare `airport_icao: LTAG` and `clearsky: true`. The built `dawn-real-clear.miz` flies
`Preset1` (FEW) where `dawn-real` flies `Preset13` (BKN), but both briefings read the same published
report, `METAR LTAG 021820Z 35006KT 9999 SCT030 BKN090 19/16 Q1015 NOSIG`: the pilot is told about a
broken layer that is not in the sky.

Cause: `_substitute_briefing_variables` applied `clearsky` to the composed METAR of a `weather:` variant
only; a `metar:` or `airport_icao:` variant always got the raw text. The caps were also written twice,
once in the converter and once in the worker.

Decisions (David, 2026-10-02):

- **a1** — with `clearsky: true`, `${METAR}` is always recomposed from the weather injected, even when the
  caps changed nothing: one rule, and no `TEMPO TSRA` contradicting a capped sky. The station, the
  temperature and the QNH are the real ones; the dew point is written `///`, as for a `weather:` variant.
- **b1** — a raw METAR keeps the time it was published at, which can be far from the variant's: written
  down in the documentation, not rewritten.
- **c** — the parser keeps only the last cloud layer (`SCT030 BKN090` flies BKN at 2743 m): recorded as a
  known limitation, not fixed here.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Compose `${METAR}` from the capped weather of a METAR or ICAO `clearsky` variant](tickets/01-clearsky-metar.md) | ✅ |
