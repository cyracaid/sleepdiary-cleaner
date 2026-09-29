# Guess column mapping from raw column names

Data-first schema inference for
[`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md).
Every inference decision is recorded (the package never silently infers
schema): each input column gets a row with the matched internal field,
the rule that matched, a confidence, a status, and the candidate set
when ambiguous.

## Usage

``` r
guess_column_mapping(cols)
```

## Arguments

- cols:

  Character vector of raw column names.

## Value

A list with two elements:

- decisions:

  data.frame, one row per input column: user_col, internal_col,
  match_rule, confidence, status, candidate_set.

- mapping:

  list in the config `column_mapping` shape, ready to merge into a
  config for
  [`adapt_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/adapt_columns.md).

## Details

Matching is deterministic: exact alias match (confidence 1.0) wins over
semantic substring match (0.6). A column that ties between two internal
fields is marked `ambiguous` with its candidate set and is NOT mapped.
Required schema fields with no matching column are marked `absent` so
[`validate_schema()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_schema.md)
can fail loudly instead of guessing.
