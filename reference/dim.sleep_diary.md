<div id="main" class="col-md-9" role="main">

# Dimensions of a sleep\_diary

<div class="ref-description section level2">

Defined so that `nrow()` and `ncol()` work directly on the object. Note
that `nrow` itself is not generic in base R – it dispatches through
`dim()`, which is why this method exists rather than an
`nrow.sleep_diary`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
# S3 method for class 'sleep_diary'
dim(x)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

</div>

<div class="section level2">

## Value

Integer vector of length 2: rows, columns.

</div>

</div>
