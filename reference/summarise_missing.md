# Summarise missing-data patterns per participant

Summarise missing-data patterns per participant

## Usage

``` r
summarise_missing(data, group_col = "pid")
```

## Arguments

- data:

  A data frame after calling
  [`handle_missing()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/handle_missing.md).

- group_col:

  Character. Participant column.

## Value

A data frame: per participant, counts of each missing reason and the
number of LOCF-filled values.
