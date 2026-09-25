# Plot the state of a sleep_diary

Degrades gracefully: with ggplot2 available it draws the record count
and flag composition across the recorded chain; without it, falls back
to a base R barplot. Never errors just because a Suggests package is
absent.

## Usage

``` r
# S3 method for class 'sleep_diary'
plot(x, y = NULL, ...)
```

## Arguments

- x:

  A `sleep_diary` object.

- y:

  Unused; present for S3 generic consistency.

- ...:

  Unused.

## Value

The plot object, invisibly.
