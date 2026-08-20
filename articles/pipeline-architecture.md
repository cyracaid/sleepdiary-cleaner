# Pipeline Architecture

This vignette documents how the sleepcleanr pipeline is structured: the
steps, the rule families that do the actual cleaning, and the
classification systems that label every record.

``` r
library(sleepcleanr)
```

## Pipeline steps

    Raw Data ──→ Step 1: Load Data ──→ Step 2: Parse Timestamps ──→ Step 3: Parse Intervals ──→ Step 4: Normalize Sequence
                                                                                                          │
                                                                                                          ▼
                                                                                                 Step 5: Classify Records
                                                                                                 (generates review CSVs)
                                                                                                          │
                                                                                                 Step 5.75: Second Review
                                                                                                          │
                                                                                                 Step 6: Apply Manual Corrections
                                                                                                 (reads manual_error_corrections.csv)
                                                                                                          │
                                                                                                 Step 6.5: Apply Duration Corrections
                                                                                                 (nap, exercise, SOL/WASO corrections)
                                                                                                          │
                                                                                                 Step 7: Compute Sleep Metrics
                                                                                                 (TST, SOL, WASO, SE, TIB)
                                                                                                          │
                                                                                                 Step 8: Auto-Detect Remaining
                                                                                                 (TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED)
                                                                                                          │
                                                                                                 Step 8.5: Cross-Participant Check
                                                                                                          │
                                                                                                  Step 9: Generate Figures

**10 steps** (source: `inst/steps.yaml`):

| Step | Label                                | Description                                                                      |
|------|--------------------------------------|----------------------------------------------------------------------------------|
| 1    | Load data                            | .rds/.csv auto-detected; schema validated; optional supplementary file merged    |
| 1.5  | Field-misentry check                 | SOL/WASO clock-time vs duration-field misentry detection on raw data             |
| 2-4  | Parse & normalize (S3 chain)         | Parse timestamps → parse intervals → normalize sequence                          |
| 5    | Classify records                     | Generate manual review CSVs for human approval                                   |
| 5.75 | Second-review consensus              | Apply second-review checklist consensus                                          |
| 6-7  | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum      |
| 8    | Auto-detect remaining issues         | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification                      |
| 8.5  | Cross-participant consistency check  | Global consistency audit across participants                                     |
| 9    | Generate diagnostic figures          | 30 figures (14 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10   | Build delivered datasets             | finalize_columns() selects/renames to Dataset A/B per column dictionary          |

## Detection rule families

The cleaning logic is organized into eight rule families. Each family
targets one failure mode of free-text self-report, has a defined
decision behavior (see tri-state below), and is validated against a
synthetic error class that exercises it (see the validation-methodology
vignette). This is the part of the pipeline that does the actual work —
the steps above are the scaffolding around it.

| Family                            | Failure mode targeted                                                                                                               | Decision on hit                        |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------|
| **Timestamp standardization**     | Non-uniform raw strings (`10.30`, `7:30`, bare hours, hms/difftime types) that can silently misparse (e.g. minutes read as seconds) | FLAG (format risk only)                |
| **Temporal order validation**     | Bedtime entered after sleep onset; AM/PM flips near midnight; cross-day confusion                                                   | AUTO_FIX (needs corroboration) / FLAG  |
| **Free-text duration parsing**    | SOL/WASO typed as text (`90:00` meaning 90 min, `0130`, `p` for 0)                                                                  | FLAG (clock-form never auto-corrected) |
| **Internal consistency check**    | Derived SOL contradicts self-reported SOL; derived duration exceeds the bed→sleep window                                            | AUTO_FIX component / AUDIT             |
| **Redundancy-confirmation check** | A “correction” that moves values *away* from self-report (silent worsening)                                                         | **Veto authority over AUTO_FIX**       |
| **Cross-day stability screening** | Implausible day-to-day SOL/WASO jumps within a participant                                                                          | AUDIT-only (may be real signal)        |
| **Correction provenance audit**   | Human correction notes no code path understands (blind spots)                                                                       | AUDIT-only                             |
| **Post-correction verification**  | Corrected timestamps still disagree with reported durations                                                                         | FLAG / PASS (release gate)             |

**Decision tri-state:**

| Decision       | Meaning                                                                                                                                                                          |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **AUTO_FIX**   | Deterministic, reversible correction applied without human review. For temporal order, requires corroboration: order violation ∧ internal consistency ∧ redundancy confirmation. |
| **FLAG**       | Sent to the human review queue (CSV workflow); no automatic action.                                                                                                              |
| **AUDIT-only** | Counted and reported; never modifies data.                                                                                                                                       |

Every rule family is deterministic (same input → same output,
snapshot-verified), which is why inter-rater reliability statistics do
not apply — there is no rater variance. Human co-review agreement is
reported instead (see the validation-methodology vignette, Step 7).

## Classification systems

| System                   | Source                | Categories                                                              |
|--------------------------|-----------------------|-------------------------------------------------------------------------|
| `data_category`          | Step 6 (temporal)     | clean, error, unusual, equal_time_ok, skipped_na                        |
| `has_correction`         | Step 7 (traceability) | none, algorithmic, manual, both                                         |
| `flag_severity`          | Step 7 (metrics)      | Clean, Minor (1 flag), Major (2+ flags)                                 |
| `checkforerrors_summary` | Step 8 (auto-detect)  | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |
