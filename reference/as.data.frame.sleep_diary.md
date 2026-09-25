<div id="main" class="col-md-9" role="main">

# Extract the working data frame from a sleep\_diary

<div class="ref-description section level2">

The escape hatch for backward compatibility: any v1.2.0 code that
expects a plain data frame can call this and carry on unchanged.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
# S3 method for class 'sleep_diary'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

-   row.names:

    NULL or a character vector giving row names.

-   optional:

    Logical. Unused; present for S3 generic consistency.

-   ...:

    Unused.

</div>

<div class="section level2">

## Value

A data frame.

</div>

</div>
