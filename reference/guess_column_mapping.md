<div id="main" class="col-md-9" role="main">

# Guess column mapping from raw column names

<div class="ref-description section level2">

Data-first schema inference for `clean_sleep_diary()`. Every inference
decision is recorded (the package never silently infers schema): each
input column gets a row with the matched internal field, the rule that
matched, a confidence, a status, and the candidate set when ambiguous.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
guess_column_mapping(cols)
```

</div>

</div>

<div class="section level2">

## Arguments

-   cols:

    Character vector of raw column names.

</div>

<div class="section level2">

## Value

A list with two elements:

-   decisions:

    data.frame, one row per input column: user\_col, internal\_col,
    match\_rule, confidence, status, candidate\_set.

-   mapping:

    list in the config `column_mapping` shape, ready to merge into a
    config for `adapt_columns()`.

</div>

<div class="section level2">

## Details

Matching is deterministic: exact alias match (confidence 1.0) wins over
semantic substring match (0.6). A column that ties between two internal
fields is marked `ambiguous` with its candidate set and is NOT mapped.
Required schema fields with no matching column are marked `absent` so
`validate_schema()` can fail loudly instead of guessing.

</div>

</div>
