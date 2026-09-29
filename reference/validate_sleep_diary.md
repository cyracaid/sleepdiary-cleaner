# Validate a sleep_diary object

Checks the structural invariants the pipeline relies on. Called by the
step adapters so a malformed object fails loudly at the boundary rather
than silently three steps later.

## Usage

``` r
validate_sleep_diary(x)
```

## Arguments

- x:

  An object to validate.

## Value

`x`, invisibly, if valid; otherwise an error is raised.
