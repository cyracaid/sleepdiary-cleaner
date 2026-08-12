---
title: 'splsleep: A Reproducible R Pipeline for Cleaning Sleep EMA Diary Data'
tags:
  - R
  - sleep
  - EMA
  - ecological momentary assessment
  - data cleaning
  - reproducibility
  - human-in-the-loop
authors:
  - name: Cai Dong
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Yonsei University, Department of Philosophy & Applied Statistics
    index: 1
date: 6 August 2026
bibliography: paper.bib
---

# Summary

`splsleep` is an R package for reproducible, auditable cleaning of sleep diary data collected via ecological momentary assessment (EMA). It parses raw bedtime, sleep onset, awake, and get-up timestamps from self-reported diary entries, detects and corrects temporal and duration errors through a configurable YAML-based threshold system, and computes standard sleep metrics including total sleep time (TST), sleep onset latency (SOL), wake after sleep onset (WASO), and sleep efficiency (SE). All corrections are recorded through a human-in-the-loop CSV workflow that preserves an audit trail — raw values are never overwritten, only labels and corrected columns are added. The pipeline generates publication-ready diagnostic figures, including a pipeline flow diagram and before/after correction impact plots. A schema-validated YAML configuration file lets any lab map their dataset's column names to the pipeline without modifying R code.

# Statement of Need

EMA sleep diary data is notoriously error-prone. Self-reported timestamps arrive as free-text strings with inconsistent AM/PM conventions, missing separators, decimal-hour instead of HH:MM formats, and temporal order violations (e.g., sleep onset recorded after awakening). Research labs typically handle these problems with ad-hoc Excel workflows or single-use R scripts that lack standardization, reproducibility, and correction traceability [@shiffman2008; @carney2012].

When these ad-hoc approaches fail, the downstream consequences are silent but severe: a small number of AM/PM swaps can shift group-level TST means by 30--60 minutes; an outlier removed without documentation becomes unexplainable to reviewers six months later; and a script that "worked last time" produces different results on the same data because of an unrecorded dependency change. These failures are rarely visible in published work but are endemic in labs collecting intensive longitudinal data.

# State of the Field

Existing tools for sleep data processing target accelerometer and wearable data (e.g., GGIR for actigraphy, SleepPy for consumer wearables) rather than self-reported diary timestamps. The consensus sleep diary [@carney2012] provides standard definitions for sleep variables but not software to compute them from raw entries. Diary data thus remains a manual-cleaning bottleneck in many EMA studies, sitting between data collection and statistical analysis with no standardized, installable tooling.

`splsleep` addresses this gap with a specific focus on self-reported sleep event timestamps — a data type present in virtually every EMA study that includes sleep variables, yet lacking a dedicated open-source toolchain.

# Implementation and Architecture

`splsleep` is implemented as a standard R package (MIT license, 94 commits, 68 tests, R CMD check 0 ERROR / 0 WARNING) and is available on GitHub at `github.com/cyracaid/sleepdiary-cleaner`. It depends on R ≥ 4.2 and uses the `tidyverse`, `ggplot2`, `yaml`, and `renv` (for dependency management) ecosystems.

## Pipeline Architecture

The pipeline consists of nine sequential steps: (1) data loading, (2) timestamp parsing, (3) interval processing, (4) temporal sequence normalization, (5) record classification with review CSV generation, (6) manual correction application, (7) sleep metric computation, (8) auto-detection of remaining anomalies, and (9) figure generation. An additional step (8.5) performs cross-participant consistency checking. Five independent evaluation standards — field misentry detection, temporal category classification, flag severity grading, extreme duration detection, and consolidated error checking — create a step-by-step audit ledger (`step_flag_ledger.csv`) showing exactly which flags appeared after each pipeline stage.

## Non-Destructive Data Model

The pipeline never deletes records. Every input record is retained in the output, with raw timestamp columns preserved untouched. Corrections are stored as new columns (prefixed `time_*_corrected`), and a `has_correction` enum column labels each record as `none`, `algorithmic`, `manual`, or `both`. Records that fail validation are tagged (e.g., `data_category = "error"`) but remain in the dataset, leaving the decision to include or exclude them to the researcher.

## Configurable Adaptation

A YAML configuration file maps any dataset's column names to pipeline internals: a user specifies their participant ID column, timestamp columns, duration estimates, and substance-use variables. Detection thresholds (e.g., SOL > 120 min, SE < 70%) are also configurable. The pipeline creates a configuration template (`config_template.yaml`) via `system.file()`, requiring only the data file path to run on a new dataset.

## Correction Traceability

A six-CSV human-in-the-loop workflow supports manual review: `manual_error_corrections.csv` (timestamp swaps and AM/PM fixes), `manual_unusual_corrections.csv` (accepted unusual patterns), `manual_nap_exercise_corrections.csv` (duration fixes), `manual_sleep_metric_duration_corrections.csv` (SOL/WASO corrections), `manual_metric_review_acceptances.csv` (human-accepted metric flags), and `second_review_checklist.csv` (second-person verification). Each correction is re-read on every pipeline run, ensuring that the full audit trail is always available.

## Diagnostic Figures

The pipeline generates two publication-ready figures:

- **Figure 1 — Pipeline Flow:** A vertical flow diagram showing raw records through parsing, algorithmic correction, manual review, and final classification, with per-stage counts and percentages.
- **Figure 2 — Correction Impact:** Three-panel delta-focused visualization showing only modified records for TST and SOL (lollipop plots sorted by magnitude), plus an identity scatter plot with unchanged records as faint reference.

Both figures read values directly from the pipeline data frame — no hardcoded numbers. An additional 26 diagnostic figures support quality control and exploratory analysis.

## Testing and Verification

The pipeline includes 68 tests covering timestamp normalization edge cases (AM/PM correction, midnight crossing, minor order errors), interval parsing (colon edge cases), correction engine logic, classification thresholds, auto-detection, config validation, and end-to-end synthetic data verification. A snapshot verification workflow confirms bit-identical output (280 rows × 95 columns) between the legacy pipeline and the current S3-based implementation, providing regression protection during refactoring.

# Acknowledgements

We thank James Gross and Maia ten Brink at the Stanford Psychophysiology Lab for providing the EMA sleep diary data and supporting the development of this pipeline.

# References
