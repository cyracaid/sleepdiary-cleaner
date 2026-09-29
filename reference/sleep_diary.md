# The sleep_diary S3 class

A thin container that carries the working data frame plus the provenance
of every pipeline step that has touched it. Each step wraps its
unchanged v1.2.0 logic, only adding timing, column-diff tracking and
ledger logging.

## Details

Constructors, predicates and validation are documented individually:
[`new_sleep_diary`](https://cyracaid.github.io/sleepdiary-cleaner/reference/new_sleep_diary.md),
[`as_sleep_diary`](https://cyracaid.github.io/sleepdiary-cleaner/reference/as_sleep_diary.md),
[`is_sleep_diary`](https://cyracaid.github.io/sleepdiary-cleaner/reference/is_sleep_diary.md),
[`validate_sleep_diary`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_sleep_diary.md).
