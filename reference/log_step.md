# Record the flag state after a step.

Record the flag state after a step.

## Usage

``` r
log_step(df, step_id, label, cfg = NULL, verbose = TRUE)
```

## Arguments

- df:

  Data frame in its state AFTER the step.

- step_id:

  Short ordered id, e.g. "1", "1.5", "2", ... "8.5".

- label:

  Human-readable step name.

- cfg:

  Config list (for thresholds).

- verbose:

  Logical. Print progress messages. Default: TRUE.

## Value

invisibly the row that was appended.
