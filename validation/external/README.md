# External dataset check (KAIST / Nature Scientific Data)

This note records one run of the pipeline on a dataset that was **not** used to
develop it. It is a feasibility check, **not** an accuracy evaluation: the
dataset has no ground truth for diary errors, so nothing here estimates
sensitivity or false-positive rate. Those numbers come from the synthetic
benchmark (`validation/synthetic/`).

## The dataset

| | |
|---|---|
| Source | Baigutanova et al., *A continuous real-world dataset comprising wearable-based heart rate variability alongside sleep diaries*, Scientific Data 12, 1474 (2025), doi:10.1038/s41597-025-05801-3 |
| Data | Figshare, doi:10.6084/m9.figshare.28509740 |
| License | CC BY |
| Size | 49 healthy adults, four weeks of daily sleep diary, 1,372 diary rows |
| Fields used | bedtime, fall-asleep time, wake-up time, WASO, sleep efficiency |

The raw data are **not** stored in this repository. Download them from the
Figshare record above.

## What had to be adapted

The dataset uses a different schema, so before running the pipeline it was
converted to the diary layout the pipeline expects:

- 24-hour clock times converted to 12-hour `hh:mm` plus AM/PM columns;
- participant identifiers renumbered to integers;
- SOL and WASO converted from hours to minutes;
- **get-up time set equal to wake-up time**, because the dataset has no
  separate get-up field;
- substance-use columns, which the dataset lacks, filled with `NA`.

The adaptation script and the config used for this run are **not yet included
in the repository**; the list above is the complete set of changes that were
made. (To do: add the script and config here so the run can be repeated
exactly.)

## Settings

The pipeline was run with its existing rules and thresholds. **No threshold or
rule was tuned for this dataset.** No manual correction files were used.

## What the run showed

- The pipeline ran from the first step to the last without intervention and the
  result was the same on repeated runs.
- 1,094 of 1,372 rows (79.7%) had computed sleep metrics; mean total sleep time
  was 7.55 h, which agrees with the source study's reported value.
- 0 rows were classed `error` or `unusual`, and 0 were corrected by the
  algorithm. The source paper states that AM/PM entries had already been
  corrected by its authors, so this is plausible.

## What it does not show

- **It does not measure detection accuracy.** With no known diary errors in the
  data, "0 errors found" cannot be told apart from "errors missed".
- **The 100% `equal_time_ok` share is an artifact.** Setting get-up equal to
  wake-up makes the awake and get-up times identical by construction.
- It is a single dataset with a single diary design; it does not establish that
  the rules generalize to other diary platforms or populations.

## Defects the run exposed

Two input-handling defects were found and fixed in commit `10885a1`:

1. `cross_participant_field_misentry_check.R` loaded the main input with
   `readRDS()` regardless of format, so a `.csv` main input stopped at Step 1.5.
2. `process_interval()` returned early on an all-`NA` column without creating
   the placeholder columns the later steps require, so a dataset that lacks a
   field (no naps, no exercise, no substance data) stopped at Step 10.
