<div id="main" class="col-md-9" role="main">

# Plot the state of a sleep\_diary

<div class="ref-description section level2">

Degrades gracefully: with ggplot2 available it draws the record count
and flag composition across the recorded chain; without it, falls back
to a base R barplot. Never errors just because a Suggests package is
absent.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
# S3 method for class 'sleep_diary'
plot(x, y = NULL, ...)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

-   y:

    Unused; present for S3 generic consistency.

-   ...:

    Unused.

</div>

<div class="section level2">

## Value

The plot object, invisibly.

</div>

</div>
