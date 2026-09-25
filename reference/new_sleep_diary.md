# Construct a sleep_diary object

Construct a sleep_diary object

## Usage

``` r
new_sleep_diary(
  data,
  step_id = "0",
  step_label = "raw",
  cfg = NULL,
  history = list(),
  extra = list()
)
```

## Arguments

- data:

  A data frame holding the working records.

- step_id:

  Character. Short ordered step id, e.g. "1", "1.5", "2". Use "0" for a
  freshly loaded object that no step has processed yet.

- step_label:

  Character. Human-readable step name.

- cfg:

  List or NULL. Pipeline configuration in force.

- history:

  List of prior step records (oldest first).

- extra:

  List. Optional extra fields merged into the step record, for example
  `list(n_corrected = 12)`.

## Value

An object of class `sleep_diary`.
