# 02 — Validate the SRS text-to-speech parameters before the system command

Status: ✅ done

`STTS.TextToSpeech` builds a Windows command line from `freqs`, `modulations` and `name`.

## Done when

- `freqs` is a comma-separated list of numbers, `modulations` a comma-separated list of `AM`/`FM`, `name` filtered like `veafRadio._transmitViaSRS` does; otherwise nothing runs and the log says why.
- The VEAF change is recorded in `vendored.yaml`'s update steps for the script.
- Lua tests.
