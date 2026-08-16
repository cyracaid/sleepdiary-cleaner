# Extract the working data frame from a sleep_diary

The escape hatch for backward compatibility: any v1.2.0 code that
expects a plain data frame can call this and carry on unchanged.

## Usage

``` r
# S3 method for class 'sleep_diary'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `sleep_diary` object.

- row.names:

  NULL or a character vector giving row names.

- optional:

  Logical. Unused; present for S3 generic consistency.

- ...:

  Unused.

## Value

A data frame.
