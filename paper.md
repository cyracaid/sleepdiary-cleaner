---
title: 'sleepcleanr: a reproducible, auditable cleaning pipeline for self-reported sleep-diary EMA data'
tags:
  - R
  - sleep research
  - ecological momentary assessment
  - data cleaning
  - reproducibility
  - human-in-the-loop
authors:
  # NOTE (2026-09-29): additional authors may be added pending agreement.
  # The list below reflects confirmed contributions only; update before
  # final submission.
  - given-names: Cai
    family-names: Dong
    affiliation: "Yonsei University"
    orcid: "https://orcid.org/0009-0001-0706-0335"
  - given-names: Maia
    family-names: ten Brink
    affiliation: "Center for Behavioral Cardiovascular Health, Department of Medicine, Columbia University Irving Medical Center"
    orcid: "https://orcid.org/0000-0001-6987-1339"
date: 29 September 2026
repository: https://github.com/cyracaid/sleepdiary-cleaner
version: 1.4.7
license: MIT
---

# Summary

Self-reported sleep diaries collected through ecological momentary assessment
(EMA) are noisy at exactly the points that matter most. Clock times are
entered as free text, and that text carries AM/PM reversals, 12-hour dial
habits, order swaps between adjacent events, and duration values typed into
timestamp fields (and vice versa). Existing cleaning options sit at two
unhelpful extremes. Fully automated scripts silently "repair"
plausible-looking entries. Fully manual review of every record is
intractable at diary scale: a two-week study with ~250 participants already
produces thousands of entries.

`sleepcleanr` is an R package implementing a hybrid cleaning pipeline for
morning sleep diaries. Deterministic rules with validated operating points
(a 3-hour adjacent-swap threshold and a 12-hour AM/PM flip) correct only
unambiguous ordering and format errors. Every applied correction is recorded
with its type in the output data. Everything else — value-level
disagreements between self-reported durations and timestamp-derived
intervals, atypical-but-possible patterns, ambiguous formats — is routed to
structured human-review worksheets. The pipeline generates these worksheets
itself (`[NEW]manual_error_correction_review.csv` and
`manual_unusual_review.csv`); reviewers fill them in, and the next run
applies them. The loop converges: corrected records stop reappearing, and
the run ends when the review worksheets come back empty.

Three design commitments distinguish the pipeline. First, **no silent
repair**: a value is either left as reported or changed with a recorded
correction type — never reinterpreted without a trace. (A field-misentry bug
that silently misrepaired 96% of injected clock-in-duration-field errors was
found by the synthetic benchmark and closed; the current benchmark reports
0% silent misrepair.) Second, **auditability**: every run writes a per-step
flag ledger covering five independent evaluation systems across the
ten-stage pipeline. Human-review files are applied only when the caller
opts in (`include_manual_corrections = TRUE`), so a dataset can never be
modified by leftover review files without the analyst's knowledge. Third,
**threshold transparency**: shipped thresholds are YAML-configurable
references validated on our data — not gospel. The package ships an
operating-point sweep and a Bland–Altman measurement-noise analysis showing
how detection thresholds relate to measurement noise.

# Statement of need

Sleep-diary cleaning sits between two communities with different tools.
Sleep researchers typically clean diaries by hand in spreadsheets —
unreproducible, unscalable, and unauditable — or with bespoke scripts that
are not shared and silently alter data. General-purpose data-cleaning
frameworks know nothing of diary semantics: that bedtime precedes sleep
onset, which precedes final awakening, which precedes get-up; that a
12-hour flip can rescue a mis-entered AM/PM; and that a zero-length sleep
period is an error while a zero-latency report is a benign diary habit. We
know of no other R package that implements diary-aware, human-in-the-loop
cleaning with per-record correction provenance and a convergence-guaranteed
review cycle, and that ships validation of its detection thresholds against
both synthetic ground truth and independent real data.

The package was developed for a real EMA sleep study: 13,990 submissions
from 237 participants, up to 15 diary days each. It was validated on three
tiers. On synthetic ground truth (4,736 injected errors) it reaches recall
0.995 with 0% silent misrepair. On the real study data, controlled re-runs
quantify exactly what human corrections contribute to the final dataset. On
an independent, externally published real-world dataset
[@baigutanova2025hrv] — 49 healthy adults' four-week sleep diaries (1,372
entries, 24-hour clock format, a different schema with no separate get-up
field) — the pipeline ran end-to-end without intervention and recovered the
source study's sleep metrics (mean total sleep time 7.55 h). This is a
feasibility check on data without ground truth: it shows that the pipeline runs
unmodified and reproduces a published metric, not how accurately it detects
errors. That external run also exposed two input-handling defects, which are fixed in the current
version. Researchers collecting longitudinal diary data with free-text time
entries — in sleep, affect, or any protocol where participants type clock
times — should find the pipeline directly usable. Column mapping is
configurable via YAML, or inferred by a recorded, fail-loud guessing
function. A data-first entry point accepts an in-memory data frame without
any config file.

# References