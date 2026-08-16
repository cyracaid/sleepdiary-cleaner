# Plot a threshold validation report

Draws the Bland-Altman plots for SOL and WASO side by side, overlaid
with the configured threshold lines to show their position relative to
the measurement-noise envelope.

## Usage

``` r
# S3 method for class 'threshold_validation'
plot(x, ...)
```

## Arguments

- x:

  A `threshold_validation` object.

- ...:

  Unused.

## Value

The combined ggplot object, invisibly.
