# Input Schema — Canonical Column Contract

Single source of truth for the raw input columns the pipeline consumes.
`validate_schema()` checks this contract right after `adapt_columns()`.

## Required columns (pipeline stops if missing)

| Logical field | Default raw name | Type | Notes |
|---|---|---|---|
| `pid` | `pid` | numeric | Participant ID |
| `day_num` | `day_num` | numeric | Study day |
| `time_bed_hhmm` | `time_bed_am_hhmm` | character | Bedtime HH:MM |
| `time_sleep_hhmm` | `time_sleep_am_hhmm` | character | Sleep-onset HH:MM |
| `time_awake_hhmm` | `time_awake_am_hhmm` | character | Final awakening HH:MM |
| `time_getup_hhmm` | `time_getup_am_hhmm` | character | Get-up HH:MM |
| `sol` | `duration_totalmin_sol_estimate_am` | numeric | Self-reported SOL (min) |
| `waso` | `duration_totalmin_waso_estimate_am` | numeric | Self-reported WASO (min) |

## Required only when `timestamp.ampm.enabled: true`

| Logical field | Default raw name | Type |
|---|---|---|
| `time_bed_ampm` | `time_bed_am_ampm` | character |
| `time_sleep_ampm` | `time_sleep_am_ampm` | character |
| `time_awake_ampm` | `time_awake_am_ampm` | character |
| `time_getup_ampm` | `time_getup_am_ampm` | character |

## Optional columns (feature degrades gracefully)

| Logical field | Default raw name | Type | Enables |
|---|---|---|---|
| `date_bed` | `StartDate` | character | Error-timeline figure |
| `waso_count` | `num_waso_estimate_am` | numeric | WASO-bout metrics |
| `nap` | `duration_totalmin_napstoday_PM` | numeric | Nap corrections |
| `caffeine` | `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` | numeric | Substance figures |
| `alcohol` | `alcoholtoday_PM_NumAlcoholicDrinks_1` | numeric | Substance figures |
