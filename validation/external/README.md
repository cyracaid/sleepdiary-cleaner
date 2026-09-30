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

The adaptation script (`adapt_kaist.R`) and the config used for this run
(`kaist_config.yaml`) are in this directory. Re-running the script on the
downloaded file reproduces the converted input byte for byte.

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

## Second check: Manchester sleep diary

A second run used the sleep-diary file of Didikoglu et al., *Associations
between light exposure and sleep timing and sleepiness while awake in a sample
of UK adults in everyday life*, PNAS (2023); data: University of Manchester
Figshare, doi:10.48420/23786238.v1, CC BY 4.0, file
`Didikoglu_et_al_2023_PNAS_sleep.csv` (59 participants, 478 diary rows). The raw
data are not stored here.

Like the KAIST run, this is a feasibility check, not an accuracy evaluation.
Bed and wake times in this file are numeric hours, not typed clock times, so the
kinds of entry error the pipeline looks for (AM/PM swaps, midnight crossings,
typos) mostly cannot occur in it.

**Adaptation** (script: `adapt_manchester.R`, run against the bundled demo config
with no threshold changed, in a scratch directory, not in the project):

- numeric hours converted to 12-hour `hh:mm` plus AM/PM;
- fall-asleep time = bed time + sleep-onset latency; SOL converted to minutes;
- dates read as `dd/mm/yyyy` (read as ISO, every date is wrong and every row is skipped);
- participant identifiers renumbered to integers;
- **get-up time set equal to wake-up time** (no get-up field);
- **WASO set to 0** (no WASO field; left as `NA`, every row is skipped as incomplete);
- nap, exercise and substance columns left `NA`.

**What the run showed.** The pipeline ran from the first step to the last
without error. 473 of 478 rows had computed metrics; 5 were skipped for missing
onset latency. Mean total sleep time was 7.63 h against a self-reported mean
duration of 7.26 h in the source file (the two are defined differently, so the
0.37 h gap is not treated as a discrepancy). 0 rows were classed `error` or
`unusual` and 0 were corrected.

**What it does not show.** It does not measure detection accuracy. The 473
`equal_time_ok` rows are an artifact of setting get-up equal to wake-up.
