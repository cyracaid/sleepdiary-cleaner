# Run the complete pipeline on bundled synthetic demo data

Convenience function that runs the full pipeline using the synthetic EMA
diary dataset bundled with sleepcleanr. Useful for testing, demos, and
validation without needing real data.

## Usage

``` r
run_synthetic_demo(project_dir = ".", verbose = TRUE)
```

## Arguments

- project_dir:

  Character. Path to the project root (where output/ will be created).
  Default ".".

- verbose:

  Logical. Print progress. Default TRUE.

## Value

Invisibly TRUE on successful completion.

## Details

Synthetic data includes deliberately injected errors across all rule
categories to benchmark detection and correction performance. Results
are written to `output/latest_visualization_synth_nXXX/` in the current
working directory.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Run the full pipeline on synthetic data in the current directory
  run_synthetic_demo()

  # Run in a specific directory
  run_synthetic_demo(project_dir = "~/my_sleepcleanr_run")
} # }
```
