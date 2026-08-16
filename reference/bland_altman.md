# Bland-Altman analysis and threshold validation

`bland_altman()` compares two measurement methods using the Bland-Altman
(1986) method. It is advisory only: it does not modify data and is never
fed back into the pipeline decision tree.

[`validate_thresholds`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_thresholds.md)
compares every configured cleaning threshold against the 95%
limits-of-agreement half-width to assess whether each cutoff sits safely
above measurement noise.

## Usage

``` r
bland_altman(data, reported_col, computed_col,
             label = "Metric", loa_ci = FALSE)
```

## Arguments

- data:

  A data frame (typically after Step 7).

- reported_col:

  Name of the self-reported column.

- computed_col:

  Name of the pipeline-computed column.

- label:

  Human-readable metric name for plot titles.

- loa_ci:

  Logical. Compute 95% CI for limits of agreement.

## Value

`bland_altman()` returns a list with components `bias`, `lower_loa`,
`upper_loa`, `prop_bias_p`, `n_pairs` and `plot`.

## References

Bland, J. M., \\ Altman, D. G. (1986). Statistical methods for assessing
agreement between two methods of clinical measurement. *The Lancet*,
327(8476), 307-310.
