# Downstream-impact analysis for the BRM paper: plan (2026-10-06)

Purpose: show how a cleaning choice changes an estimate the study cares about. This is
what makes the paper a methods paper and not only a package description. It needs the
study data and the PI's agreement, so it is a plan, not a result.

## Question
How much does the estimated within-person association between a night's sleep and the
next day's outcome change when the diary data are cleaned in different ways?

## Design (to be fixed before looking at results)
- Outcome and model: the study's own primary sleep-to-affect model (outcome, predictor
  sleep metric, random effects). [CHECK with Maia: which outcome and model]
- Predictor: total sleep time (or the study's primary sleep metric) computed from
  four data sets built from the same raw entries:
  1. no cleaning (entries parsed as typed);
  2. naive rule (resolve midnight, swap inverted adjacent times);
  3. sleepcleanr, algorithmic corrections only, flagged rows kept as they are;
  4. sleepcleanr with the reviewers' corrections applied (the delivered data set).
  A fifth variant sets flagged rows aside.
- Report for each: n of analysable nights, the coefficient and its interval, and the
  difference from arm 4. Pre-specify that a difference larger than the width of the
  arm-4 interval is "material".
- Also report how the estimate moves when the swap and flip thresholds are varied over
  the multiverse grid (already computed for the summary metrics).

## Needs
- Access to the outcome variables in the study export (the files in the repository hold
  only the sleep diary columns).
- The PI's agreement to the analysis and to how the study is described in the paper.
- Script: `validation/downstream_effect.R` (to be written once the model is fixed; it
  will read the study data from a path outside the repository and write only
  aggregate coefficients).

## Caution
A change in a coefficient shows that cleaning matters, not which version is closer to
the truth. Say so; the benchmark and the blind audit address accuracy.
