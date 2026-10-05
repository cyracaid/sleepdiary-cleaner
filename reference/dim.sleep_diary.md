# Dimensions of a sleep_diary

Defined so that [`nrow()`](https://rdrr.io/r/base/nrow.html) and
[`ncol()`](https://rdrr.io/r/base/nrow.html) work directly on the
object. Note that `nrow` itself is not generic in base R – it dispatches
through [`dim()`](https://rdrr.io/r/base/dim.html), which is why this
method exists rather than an `nrow.sleep_diary`.

## Usage

``` r
# S3 method for class 'sleep_diary'
dim(x)
```

## Arguments

- x:

  A `sleep_diary` object.

## Value

Integer vector of length 2: rows, columns.
