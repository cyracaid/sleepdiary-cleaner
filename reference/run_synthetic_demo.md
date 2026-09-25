<div id="main" class="col-md-9" role="main">

# Run the complete pipeline on bundled synthetic demo data

<div class="ref-description section level2">

Convenience function that runs the full pipeline using the synthetic EMA
diary dataset bundled with sleepcleanr. Useful for testing, demos, and
validation without needing real data.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
run_synthetic_demo(project_dir = ".", verbose = TRUE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   project\_dir:

    Character. Path to the project root (where output/ will be created).
    Default ".".

-   verbose:

    Logical. Print progress. Default TRUE.

</div>

<div class="section level2">

## Value

Invisibly TRUE on successful completion.

</div>

<div class="section level2">

## Details

Synthetic data includes deliberately injected errors across all rule
categories to benchmark detection and correction performance. Results
are written to `output/latest_visualization_synth_nXXX/` in the current
working directory.

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
if (FALSE) { # \dontrun{
  # Run the full pipeline on synthetic data in the current directory
  run_synthetic_demo()

  # Run in a specific directory
  run_synthetic_demo(project_dir = "~/my_sleepcleanr_run")
} # }
```

</div>

</div>

</div>
