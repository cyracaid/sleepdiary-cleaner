# Build the analysis-facing datasets from the full pipeline output

Splits the pipeline output into two delivered datasets plus the full
archive, driven entirely by \`inst/extdata/column_dictionary.csv\`.

## Usage

``` r
finalize_columns(
  data,
  review_data = NULL,
  dict_path = NULL,
  output_dir = "output",
  write = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  The pipeline output (\`corrected_ema_data\`).

- review_data:

  Optional. \`review_output\$data_with_flags\`. Step 8 creates its flags
  on a copy and never writes them back to \`corrected_ema_data\` (see
  \`00_MAIN_entry.R\`, Step 8), so columns such as \`needs_review_flag\`
  are only reachable through this object. The dictionary's
  \`source_object\` field records which columns need it.

- dict_path:

  Path to the column dictionary CSV. Defaults to the copy shipped in
  \`inst/extdata\`.

- output_dir:

  Directory for the delivered files.

- write:

  Write files to disk. Set FALSE to inspect the return value without
  touching the filesystem.

- verbose:

  Print a summary.

## Value

Invisibly, a list with \`final\` (Dataset A), \`prepost\` (Dataset B)
and \`full\` (everything, unchanged).

## Details

The dictionary is the single source of truth for three things that used
to drift apart: the column whitelist, the rename mapping, and the data
dictionary itself. Adding a column means editing one CSV row, not three
places.
