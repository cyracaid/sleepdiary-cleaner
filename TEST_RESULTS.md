# splsleep Package Test Results

**Date:** 2026-07-15
**R version:** 4.6.0
**Platform:** aarch64-apple-darwin23 (macOS Sequoia 15.4.1)

## R CMD CHECK Summary

```
Status: 5 WARNINGs, 3 NOTEs
```

- **0 ERRORs**
- **checking tests ... OK** (all 17 testthat tests pass)
- 5 WARNINGs are typical: missing documentation entries, unstated dependencies in examples
- 3 NOTEs are informational (non-ASCII code, subdirectory structure)

## Test Coverage (testthat)

### normalize_sleep_time_sequence — 15 tests

| # | Scenario | Status |
|---|----------|--------|
| 1 | Normal midnight crossing (bed 22:00 → getup 06:30+1) | ✅ |
| 2 | AM/PM error (bed 10:00 should be 22:00) → sleep_reduce_12h | ✅ |
| 3 | Short cross-midnight (23:30→02:00) | ✅ |
| 4 | All four timestamps equal (bed==sleep==awake==getup) | ✅ |
| 5 | All-NA row → skipped_na | ✅ |
| 6 | Partial NA (getup missing) → has_na=TRUE | ✅ |
| 7 | >3h temporal disorder → NOT auto-corrected | ✅ |
| 8 | <3h bed-sleep swap → bed_sleep_swap_3h | ✅ |
| 9 | <3h sleep-awake swap → sleep_awake_swap_3h | ✅ |
| 10 | <3h awake-getup swap → awake_getup_swap_3h | ✅ |
| 11 | Gap near 12h (11.5h) → no AM/PM flip | ✅ |
| 12 | Gap of exactly 12h → triggers correction | ✅ |
| 13 | checkforerrors cleared after valid correction | ✅ |
| 14 | Row count preserved (3 in = 3 out) | ✅ |
| 15 | Combined AM/PM + swap correction | ✅ |

### process_interval — 2 tests

| # | Scenario | Status |
|---|----------|--------|
| 1 | "00:000" normalizes to 00:00, mincalc=0 | ✅ |
| 2 | "000:45" normalizes to 00:45, mincalc=45 | ✅ |

## Running Tests

```r
# From R console (package root):
library(testthat)
test_dir("tests/testthat")

# Or via R CMD CHECK:
R CMD CHECK . --no-manual

# Or directly with testthat:
test_file("tests/testthat/test-normalize_sleep_time_sequence.R")
```

## Full Log

See `R_CMD_CHECK.log` in the `tests/` directory for the complete R CMD CHECK output.
