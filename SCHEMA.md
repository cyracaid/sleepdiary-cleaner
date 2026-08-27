# Input Schema — Canonical Column Contract

Single source of truth for the raw input columns the pipeline consumes.
[`validate_schema()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_schema.md)
checks this contract right after
[`adapt_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/adapt_columns.md).

## Required columns (pipeline stops if missing)

| Logical field     | Default raw name                     | Type      | Notes                                                                                            |
|-------------------|--------------------------------------|-----------|--------------------------------------------------------------------------------------------------|
| `pid`             | `pid`                                | numeric   | Participant ID                                                                                   |
| `day_num`         | `day_num`                            | numeric   | Study day                                                                                        |
| `time_bed_hhmm`   | `time_bed_am_hhmm`                   | character | Bedtime HH:MM                                                                                    |
| `time_sleep_hhmm` | `time_sleep_am_hhmm`                 | character | Sleep-onset HH:MM                                                                                |
| `time_awake_hhmm` | `time_awake_am_hhmm`                 | character | **Final awakening** HH:MM — last wake before get-up (see Operational definitions)                |
| `time_getup_hhmm` | `time_getup_am_hhmm`                 | character | Get-up HH:MM — the moment the participant left bed                                               |
| `sol`             | `duration_totalmin_sol_estimate_am`  | numeric   | Self-reported SOL (min) — bed → sleep-onset latency                                              |
| `waso`            | `duration_totalmin_waso_estimate_am` | numeric   | Self-reported WASO (min) — *total* minutes awake after sleep onset (all middle-of-night wakings) |

## Required only when `timestamp.ampm.enabled: true`

| Logical field     | Default raw name     | Type      |
|-------------------|----------------------|-----------|
| `time_bed_ampm`   | `time_bed_am_ampm`   | character |
| `time_sleep_ampm` | `time_sleep_am_ampm` | character |
| `time_awake_ampm` | `time_awake_am_ampm` | character |
| `time_getup_ampm` | `time_getup_am_ampm` | character |

## Optional columns (feature degrades gracefully)

| Logical field | Default raw name                                | Type      | Enables               |
|---------------|-------------------------------------------------|-----------|-----------------------|
| `date_bed`    | `StartDate`                                     | character | Error-timeline figure |
| `waso_count`  | `num_waso_estimate_am`                          | numeric   | WASO-bout metrics     |
| `nap`         | `duration_totalmin_napstoday_PM`                | numeric   | Nap corrections       |
| `caffeine`    | `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` | numeric   | Substance figures     |
| `alcohol`     | `alcoholtoday_PM_NumAlcoholicDrinks_1`          | numeric   | Substance figures     |

## Operational definitions (canonical)

These are the constructs the timestamp and duration columns encode. They
follow the Consensus Sleep Diary (CSD) item wording; derivations are
defined in the sleep-metrics code.

| Variable          | Operational definition                                                                                          | Self-report anchor     | CSD analog                                                                                 |
|-------------------|-----------------------------------------------------------------------------------------------------------------|------------------------|--------------------------------------------------------------------------------------------|
| `time_bed_hhmm`   | Time participant **got into bed** to sleep                                                                      | —                      | Q1 “What time did you get into bed?”                                                       |
| `time_sleep_hhmm` | Time **fall-asleep** was attempted/succeeded (sleep onset)                                                      | `sol`                  | Q2 “What time did you try to go to sleep?” / Q3 “How long did it take you to fall asleep?” |
| `time_awake_hhmm` | **Final awakening** — the last wake-up of the night, ending the main sleep period (NOT middle-of-night wakings) | —                      | Q5 “What time was your final awakening?”                                                   |
| `time_getup_hhmm` | **Get-up time** — when the participant left bed, ≥ final awakening                                              | —                      | Q6 “What time did you get out of bed?”                                                     |
| `sol`             | Sleep-onset latency: bed(or sleep attempt) → sleep onset, minutes                                               | `sol`                  | Q3                                                                                         |
| `waso`            | **Total** wake-after-sleep-onset: sum of ALL middle-of-night wakings (minutes), excluding the final awakening   | `waso`                 | Q6?/Q7 (wake-up count × duration)                                                          |
| `waso_count`      | Number of middle-of-night waking bouts                                                                          | `num_waso_estimate_am` | CSD wake-count item                                                                        |

**Key distinction — `time_awake_hhmm` (final awakening) vs WASO (middle
wakings):** `time_awake_hhmm` is a single timestamp, the *last* wake of
the night; it is the end boundary of TST. WASO is the *summed duration*
of all earlier middle-of-night wakings and contributes to SE/TST — it is
a duration, not a timestamp. **These are different constructs and are
never interchangeable.** Cleaning found repeated cases where
participants entered their number/timing of middle wakings (WASO
material) into the `time_awake` field; such entries must be flagged, not
silently accepted as final-awakening times.
