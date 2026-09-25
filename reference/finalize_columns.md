<div id="main" class="col-md-9" role="main">

# Build the analysis-facing datasets from the full pipeline output

<div class="ref-description section level2">

Splits the pipeline output into two delivered datasets plus the full
archive, driven entirely by \`inst/extdata/column\_dictionary.csv\`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

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

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    The pipeline output (\`corrected\_ema\_data\`).

-   review\_data:

    Optional. \`review\_output$data\_with\_flags\`. Step 8 creates its
    flags on a copy and never writes them back to
    \`corrected\_ema\_data\` (see \`00\_MAIN\_entry.R\`, Step 8), so
    columns such as \`needs\_review\_flag\` are only reachable through
    this object. The dictionary's \`source\_object\` field records which
    columns need it.

-   dict\_path:

    Path to the column dictionary CSV. Defaults to the copy shipped in
    \`inst/extdata\`.

-   output\_dir:

    Directory for the delivered files.

-   write:

    Write files to disk. Set FALSE to inspect the return value without
    touching the filesystem.

-   verbose:

    Print a summary.

</div>

<div class="section level2">

## Value

Invisibly, a list with \`final\` (Dataset A), \`prepost\` (Dataset B)
and \`full\` (everything, unchanged).

</div>

<div class="section level2">

## Details

The dictionary is the single source of truth for three things that used
to drift apart: the column whitelist, the rename mapping, and the data
dictionary itself. Adding a column means editing one CSV row, not three
places.

</div>

</div>
