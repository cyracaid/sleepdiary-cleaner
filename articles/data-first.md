# Data-first entry: clean_sleep_diary()

## Data-first entry: `clean_sleep_diary()`

The pipeline can run entirely from a data file or data.frame — no config
file required. Column names are inferred, every schema inference
decision is recorded, and a provenance manifest is written alongside the
cleaned output.

``` r
library(sleepcleanr)

# A file (CSV, RDS, or XLSX) ...
res <- clean_sleep_diary("my_diary.csv")

# ... or an in-memory data.frame
res <- clean_sleep_diary(df)

# Preview the inferred column mapping without running anything:
clean_sleep_diary("my_diary.csv", dry_run = TRUE)
```

### Return value (6-field contract)

| Field      | Contents                                                          |
|------------|-------------------------------------------------------------------|
| `cleaned`  | Cleaned Dataset A as a data.frame (`NULL` in dry-run)             |
| `config`   | Full effective config used (defaults + overrides)                 |
| `guesses`  | Per-column mapping decisions (recorded, never silent)             |
| `ledger`   | Per-step row-count ledger (step_id, label, n_rows)                |
| `outputs`  | Named output paths (`cleaned_csv`, `ledger_csv`, `manifest_json`) |
| `manifest` | Provenance manifest (also written to `outputs$manifest_json`)     |

### Column auto-guessing

[`guess_column_mapping()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/guess_column_mapping.md)
matches raw column names against known aliases:

- exact alias match (e.g. `bedtime` -\> `time_bed_hhmm`, confidence 1.0)
- semantic substring match (confidence 0.6)
- ambiguous ties are **never silently resolved** — they are recorded
  with their candidate set and left unmapped
- required schema fields with no matching column are marked `absent` and
  [`validate_schema()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_schema.md)
  fails loudly with the missing list

Every decision row carries:
`user_col, internal_col, match_rule, confidence, status, candidate_set`.
The package does not silently infer schema; it records every schema
inference decision.

### Provenance manifest

Each full run writes `run_manifest_<timestamp>.json`:

- input identity: **md5 hash** (the hash is the identity; path is
  auxiliary), size, basename
- `commit` (or `null` outside a git repo — “not available” is a distinct
  state)
- `timestamp_utc` (UTC only)
- environment: R version, platform, package versions
- the full effective `config`
- the per-step `ledger` (row counts per pipeline step)
- output file paths

### dry-run

`dry_run = TRUE` stops after input hashing + schema detection + column
mapping + config resolution. It prints the mapping preview, writes
`dry_run_manifest.json`, and **never writes a cleaned dataset**. The raw
input is never modified in any mode.

### Raw input is never modified

The adapted input is written to an internal copy inside the project
directory; the user’s original file or data.frame is untouched (verified
by test).
