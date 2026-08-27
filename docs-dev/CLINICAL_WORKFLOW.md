# sleepcleanr — Clinical Use Guidance

> **Status: guidance only. Not a clinical tool.**
> sleepcleanr is developed and validated for **research batch cleaning** of
> sleep-EMA diary data. Nothing in this doc claims diagnostic validity,
> clinical decision support, or regulatory approval. Use at your own judgment
> and under local clinical governance.

## When this applies

The pipeline's core design — deterministic cleaning + an auditable manual-review
ledger — is useful **per-patient**, not just per-study. A single client works
fine; most columns are optional and can be dropped (e.g. no substance-use
items). It can be a lighter-weight workflow than full-batch research cleaning.

## What the pipeline can and cannot do for you

| Can (validated) | Cannot (do not claim) |
|---|---|
| Detect AM/PM confusion and order violations in reported bed/sleep/awake/get-up timestamps | Make a diagnosis |
| Parse and normalize free-text sleep-diary timestamps | Replace clinical judgment on any single case |
| Flag probably-ambiguous records for human review | Substitute for a clinician's interpretation of severity |
| Keep a persistent, re-readable correction ledger (every change saved) | Guarantee an answer when input is self-contradictory |
| Recompute TST / SOL / WASO / SE from cleaned timestamps | Diagnose sleep disorders |
| Preserve (rather than delete) psychologically plausible large values | |

> **The persistent manual-CSV ledger is the key clinical win.** The
> walking-point pain that "the platform won't let me change the data" is solved
> here: corrections are written to a re-readable, versionable CSV that survives
> re-runs, so a clinician can fix an entry and it stays fixed.

## Step-by-step (single client)

1. **Prepare one-day-per-row CSV** with at minimum: `pid`, `day_num`,
   `time_bed_am_hhmm`, `time_sleep_am_hhmm`, `time_awake_am_hhmm`,
   `time_getup_am_hhmm` (+ `sol`/`waso` if collected, + optional `ampm` set if
   your source uses AM/PM codes). Only the required columns need to be present;
   omit the rest.
2. **Map columns** in a YAML config (see the `column-mapping` vignette). A small
   config is fine; schema validation runs automatically.
3. **Run the pipeline** — it classifies records and emits a manual-review CSV.
4. **Review FLAG rows.** Inspect the flagged records; on each, either keep as
   written, edit a timestamp, or blank an unusable duration. Each decision is
   stored in the manual CSV.
5. **Re-run to apply + export.** The ledger persists your edits; the final
   datasets and the QC figures come out.

## What to actually check per case

- **AM/PM flip candidates** — a timestamp off by ~12 h; usually resolvable.
- **Order violations** (get-up before final awakening, sleep-onset before bed) —
   usually a swap or a mis-key; see VALIDATION_REPORT for the order-only evidence.
- **SOL > the bed→sleep window** — this is **not** proven error. Per the
   sleep–affect design, a large self-reported SOL is plausible signal; keep it
   unless there is independent reason not to.
- **Middle-waking (WASO) material typed into the final-awakening field** — the
   number/timing of night wakings is NOT the final awakening; flag it.

## Guard-rails / disclaimers

- These rules were tuned on research samples; per-client thresholds may need
  re-checking (see `THRESHOLDS.md` for the population-dependency caveat).
- Never cite sleepcleanr output as a diagnostic or as gold-standard sleep.
- No regulatory approval; no clinical-validity claim. When in doubt, escalate.