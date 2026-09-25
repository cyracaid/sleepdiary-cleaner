<div id="main" class="col-md-9" role="main">

# Data-first entry: clean\_sleep\_diary()

<div class="section level2">

## Data-first entry: `clean_sleep_diary()`

The pipeline can run entirely from a data file or data.frame — no config
file required. Column names are inferred, every schema inference
decision is recorded, and a provenance manifest is written alongside the
cleaned output.

<div id="cb1" class="sourceCode">

``` r
library(sleepcleanr)

# A file (CSV, RDS, or XLSX) ...
res <- clean_sleep_diary("my_diary.csv")

# ... or an in-memory data.frame
res <- clean_sleep_diary(df)

# Preview the inferred column mapping without running anything:
clean_sleep_diary("my_diary.csv", dry_run = TRUE)
```

</div>

<div class="section level3">

### Return value (6-field contract)

| Field      | Contents                                                          |
|------------|-------------------------------------------------------------------|
| `cleaned`  | Cleaned Dataset A as a data.frame (`NULL` in dry-run)             |
| `config`   | Full effective config used (defaults + overrides)                 |
| `guesses`  | Per-column mapping decisions (recorded, never silent)             |
| `ledger`   | Per-step row-count ledger (step\_id, label, n\_rows)              |
| `outputs`  | Named output paths (`cleaned_csv`, `ledger_csv`, `manifest_json`) |
| `manifest` | Provenance manifest (also written to `outputs$manifest_json`)     |

</div>

<div class="section level3">

### Column auto-guessing

`guess_column_mapping()` matches raw column names against known aliases:

-   exact alias match (e.g. `bedtime` -&gt; `time_bed_hhmm`, confidence
    1.0)
-   semantic substring match (confidence 0.6)
-   ambiguous ties are **never silently resolved** — they are recorded
    with their candidate set and left unmapped
-   required schema fields with no matching column are marked `absent`
    and `validate_schema()` fails loudly with the missing list

Every decision row carries:
`user_col, internal_col, match_rule, confidence, status, candidate_set`.
The package does not silently infer schema; it records every schema
inference decision.

</div>

<div class="section level3">

### Provenance manifest

Each full run writes `run_manifest_<timestamp>.json`:

-   input identity: **md5 hash** (the hash is the identity; path is
    auxiliary), size, basename
-   `commit` (or `null` outside a git repo — “not available” is a
    distinct state)
-   `timestamp_utc` (UTC only)
-   environment: R version, platform, package versions
-   the full effective `config`
-   the per-step `ledger` (row counts per pipeline step)
-   output file paths

</div>

<div class="section level3">

### dry-run

`dry_run = TRUE` stops after input hashing + schema detection + column
mapping + config resolution. It prints the mapping preview, writes
`dry_run_manifest.json`, and **never writes a cleaned dataset**. The raw
input is never modified in any mode.

</div>

<div class="section level3">

### Raw input is never modified

The adapted input is written to an internal copy inside the project
directory; the user’s original file or data.frame is untouched (verified
by test).

</div>

</div>

</div>
