# Clean a sleep diary: data-first entry point

One-call entry for new users: give it a file or a data.frame, get back
the cleaned data plus a full provenance manifest. No config file
required – column names are inferred
([`guess_column_mapping()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/guess_column_mapping.md))
and every schema decision is recorded, never silently guessed.

## Usage

``` r
clean_sleep_diary(data, config = NULL, dry_run = FALSE, project_dir = ".", ...)
```

## Arguments

- data:

  Character or data.frame. Path to a .csv / .rds / .xlsx file, or an
  in-memory data.frame. Ignored columns are left untouched; the raw
  input is never modified.

- config:

  Character or list or NULL. YAML config path, config list, or NULL to
  use the bundled defaults (recommended for first runs).

- dry_run:

  Logical. If TRUE, stop after input hashing + schema detection + column
  mapping + config resolution: print the mapping preview and write
  `dry_run_manifest.json`, but do NOT run the pipeline and do NOT write
  any cleaned dataset.

- project_dir:

  Character. Working directory for the run (default ".").

- ...:

  Additional arguments passed to
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md).

## Value

A 6-field list (see Description).

## Details

The returned object is a stable 6-field list:

- cleaned:

  Cleaned Dataset A as a data.frame. NULL when `dry_run = TRUE`.

- config:

  The full effective config used (defaults + overrides).

- guesses:

  Per-column mapping decisions from
  [`guess_column_mapping()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/guess_column_mapping.md).

- ledger:

  Per-step row-count ledger (step_id, label, n_rows).

- outputs:

  Named list of output file paths.

- manifest:

  The provenance manifest (also written to `outputs$manifest_json`).
