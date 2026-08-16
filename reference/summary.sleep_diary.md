# Tabulate the whole pipeline chain recorded in a sleep_diary

Returns one row per step: how many records went in and out, how many
columns the step added, and how long it took. When the flag ledger from
[`log_step()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/log_step.md)
is populated it is joined on, so the same call answers both "what did
each step do" and "how many records were flagged after it".

## Usage

``` r
# S3 method for class 'sleep_diary'
summary(object, ...)
```

## Arguments

- object:

  A `sleep_diary` object.

- ...:

  Unused.

## Value

A data frame with one row per recorded step, invisibly printed.
