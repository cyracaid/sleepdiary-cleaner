# Tally one standard's labels into a fixed-level count vector. Returns all-NA (named by levels) if the label vector is entirely NA.

Tally one standard's labels into a fixed-level count vector. Returns
all-NA (named by levels) if the label vector is entirely NA.

## Usage

``` r
tally_standard(labels, levels)
```

## Arguments

- labels:

  Character vector of labels to tally.

- levels:

  Character vector of all possible category levels.

## Value

Named integer vector with counts per level.
