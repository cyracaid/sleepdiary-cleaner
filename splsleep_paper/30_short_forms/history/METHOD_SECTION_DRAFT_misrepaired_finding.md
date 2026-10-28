# Method/Validation-section draft: field-misentry silent-misrepair finding

(Drafted per `validation/PROMPT_method_section_misrepaired_finding.md`. Source
verified directly against `validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md`'s
"Addendum (2026-09-02)" section and `detection_outcomes_v4_current.csv` before
writing — no numbers below are carried over from the prompt file without
re-checking against the underlying doc.)

## Draft prose

Field misentry — a participant typing a clock time (e.g., "11:30") into a field
that expects a duration in minutes, such as sleep-onset latency (SOL) or
wake-after-sleep-onset (WASO) — is an observed real-data error pattern with a
particularly dangerous failure mode. Before a targeted fix, the pipeline could
silently reinterpret the clock time as a plausible-looking duration and write an
incorrect value into the cleaned dataset with no flag: wrong and invisible, the
worst outcome available to an automated cleaning step. A synthetic
error-injection benchmark first surfaced this at scale: injecting field-misentry
errors into 400 SOL and 400 WASO records and running the then-current pipeline
produced silent misrepair in 383/400 (95.8%) and 384/400 (96.0%) of cases
respectively, with only 4.2%/3.0% caught or corrected in any way. A patch
("PART A4" in `inst/scripts/checkforerrors_processing.R`) added a check that
routes clock-time-shaped duration entries to human review instead of silently
accepting a reinterpreted value.

We re-ran the full synthetic benchmark end-to-end against the currently
installed pipeline (n = 7,000 records across all 15 injected error categories,
evaluated against the current ground-truth file) to verify the patch's actual
effect rather than relying on the original post-patch estimate. Silent
misrepair is now fully closed for both fields — 0/400 (0%) for SOL and 0/400
(0%) for WASO, stronger than the originally reported 3.5% residual for SOL,
which did not reproduce in this run and has not been further investigated.
This should not, however, be read as "auto-corrected": only 7/400 (1.8%) of
SOL and 13/400 (3.2%) of WASO field-misentry cases are corrected to the true
value automatically. The remaining 393/400 (98.2%) and 387/400 (96.8%) are
instead flagged for human review rather than resolved automatically. Both
outcomes are safe in the sense that neither delivers a wrong value silently,
but they are distinct claims: reporting a combined "96.5%/100% caught" figure
without separating the two would overstate how much the pipeline resolves on
its own. The patch's real effect is converting a silent wrong answer into a
routed human-review flag, not into an automatic fix.

## Open questions for the authors (per the prompt's request to flag rather than guess)

- Where in the paper this belongs (Methods proper vs. a Validation subsection)
  — the draft above is written as free-standing prose either way.
- The original 3.5% SOL residual ("01:XX"-shaped clock times) no longer
  reproduces on the current pipeline and has not been re-investigated. Worth a
  short follow-up to confirm whether it was fixed by a later, unrelated
  change, or whether the current re-run simply didn't happen to sample that
  edge case (n=400 per category, not exhaustive).
- Whether to cite the exact patch commit hash (`5dd0e27`) in the paper text or
  keep it implementation-detail-only (left out of the draft above by default).
