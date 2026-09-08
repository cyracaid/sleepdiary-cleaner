# Methods (long-form draft — methodology journal, e.g. Behavior Research Methods)

*Drafted 2026-09-07. Grounded in verified results from `channel-b-redundancy-validation.md`,
`synthetic-benchmark-run-results.md`, `development-evidence-audit.md`, `benchmark-design.md`,
`validation-design.md`, `validation-roadmap.md` (project docs), `VALIDATION_REPORT.md`, and
`validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md` (repo). Every number below is cited to
one of these sources; nothing is carried over from an earlier draft without re-checking against
the underlying result file. Items that are designed but not yet executed (pre-registration
mapping, multiverse analysis, a second dataset, SHUTi complementarity comparison, held-out
audit-trail analysis) are explicitly marked as such rather than folded into the empirical
claims — see "Planned but not yet executed" at the end.*

## 1. Motivation and framing

Sleep ecological momentary assessment (EMA) diaries are cleaned before every published
analysis, but the cleaning itself is rarely a first-class, inspectable research product: it
typically lives in study-specific scripts, is not configurable across datasets, and — most
consequentially — offers no way to distinguish "this looks wrong" from "this was fixed
correctly." Existing systematic approaches (e.g., SHUTi's automated validation pipeline,
45,598 diary-days, AM/PM and date-error correction; RESTING's 2024 diary QC report) demonstrate
that rule-based cleaning works at scale, but are implemented as study-specific code rather than
a transferable, auditable framework. We do not claim to be the first system to clean sleep
diaries; we ask whether the underlying principles can be generalized into a **configurable,
provenance-preserving, human-auditable software framework**, and we empirically validate when
and why it works, and — as important — when it does not.

Three contributions follow from this framing:

1. **A transferable, configurable framework.** The cleaning engine and the dataset-specific
   schema/threshold mapping are decoupled via a schema-validated YAML config; the same engine
   runs against different column layouts, units, and thresholds without touching code.
2. **A human-auditable correction architecture.** A non-destructive, four-layer design (raw
   input, immutable → automated baseline correction → human working layer → final confirmed
   layer) means every correction is logged, reversible, and traceable to its origin; nothing is
   silently overwritten.
3. **Empirical validation across evidence channels with non-overlapping failure modes**,
   establishing not just that the pipeline performs well on average, but specifically where its
   guarantees hold and where they do not.

## 2. The core validation problem, and how we address it

A cleaning pipeline cannot be validated against ground truth that does not exist: no one knows
with certainty what a participant meant when they typed an ambiguous value into a diary field.
Any validation design is therefore an attempt to work around this absence, and every workaround
has its own failure mode. Rather than rely on a single evidence channel, we use four, chosen
so that their failure modes do not overlap — this is the logic of triangulation: the evidence
is convincing not because there is a lot of it, but because no single flaw in one channel can
explain agreement across all of them.

| Channel | How ground truth is approximated | What it covers | Known failure mode |
|---|---|---|---|
| A. Synthetic injection | Errors are constructed, so the true value is known by design | Whether known errors are found and corrected | Injected errors may not resemble real ones; injecting with the same mental model used to write the detection rules risks circularity |
| B. Redundant channel | An independent measurement already present in the data | Correction correctness **on real data**, with no manual annotation | Only applies where genuine redundancy exists; the correction logic must be provably blind to the redundant channel |
| C. Human adjudication | Expert/team consensus substitutes for ground truth | Real, ambiguous cases needing domain judgment | Human raters are not ground truth either; team-internal raters can share systematic bias with the pipeline's authors |
| D. Downstream consequence | Whether cleaning changes the scientific conclusion | Practical importance of cleaning choices | Shows *that* something changed, not whether the change is *correct* |

### 2.1 Channel A — synthetic error-injection benchmark

An enrichment-sampling design was used rather than injecting at the real-world base rate: base
rate drives precision estimates but starves recall/specificity estimates of statistical power
at any feasible sample size, so recall and false-alteration rate were each estimated on their
own adequately powered sample, decoupled from the assumed real-world prevalence (base rates from
SHUTi, 2023: 1.07% of diary-days needed date/AM-PM correction; RESTING, 2024: 5.7% needed
post-hoc correction; this study's own real-data rate: 84/13,990 ≈ 0.6% routed to manual review,
automatic corrections counted separately).

**Clean-input specificity (false-alteration rate, FAR_alter).** 10,000 structurally clean
synthetic diary-days (monotonic bed→sleep→awake→getup ordering, internally consistent
durations, no format anomalies, enforced by construction) were run through the full pipeline.
**0/10,000 records had any field silently altered** (rule-of-three 95% upper bound: 0.03%),
verified against the pipeline's own parsed-truth columns rather than raw display strings (the
pipeline canonicalizes duration display format regardless of whether a correction fired, which
would otherwise register as 10,000/10,000 false "alterations"). A second run stratified by four
physiologically realistic populations (healthy adult, short sleeper, shift-like, insomnia-like;
n=3,000 each, no injected errors) confirmed zero value alterations across all 12,000 rows, with
flag rate rising from 0.0% (healthy adult, short sleeper) to 0.3% (shift-like) to **7.7%**
(insomnia-like) — an empirical, quantified confirmation that population-dependent plausibility
thresholds (tuned on a healthy young-adult sample) generate substantially more human-review
volume, not silent errors, when applied to a clinically atypical population.

**Detection and correction, by error category** (n=400 per category unless noted; a category is
scored CORRECT if the pipeline's derived value matches the injected ground truth, FLAGGED if
routed to human review without a value change, MISREPAIRED if silently changed to an incorrect
value, MISSED if neither flagged nor corrected):

| Category | Correct | Flagged | Misrepaired | Missed |
|---|---|---|---|---|
| format_no_colon | 100.0% | 0% | 0% | 0% |
| format_malformed_colon | 100.0% | 0% | 0% | 0% |
| implausible_duration | 0% | 100.0% | 0% | 0% |
| adjacent_swap_sleep_awake | 0% | 100.0% | 0% | 0% |
| adjacent_swap_bed_sleep† | 100.0% (378/378 genuine) | — | 0% | 0% |
| adjacent_swap_awake_getup† | 100.0% (323/323 genuine) | — | 0% | 0% |
| ampm_swap | 50.8% | 49.2% | 0% | 0% |
| compound_ampm_and_swap | 33.0% | 67.0% | 0% | 0% |
| mmss_confusion | 94.8% | 2.8% | 2.5% | 0% |
| field_misentry_sol (post-patch, re-verified) | 1.8% | 98.2% | **0%** | 0% |
| field_misentry_waso (post-patch, re-verified) | 3.2% | 96.8% | **0%** | 0% |
| cross_participant_spike | — | 88.7% | ~11.3%‡ | 0% |

† 22/400 and 77/400 injections in these two categories landed on already-identical
bed/sleep or awake/getup timestamps (an untestable no-op); the reported percentage is
restricted to the genuinely corrupted subset, cross-verified against the pipeline's own
`correction_type` audit column rather than trusting the evaluator's raw match rate.
‡ Not yet independently re-verified at the same rigor as the other categories (flag-only
reading); flagged as a limitation.

**The field-misentry finding is the sharpest single result and merits its own framing.** A
field misentry — a participant typing a clock time (e.g., "11:30") into a field that expects a
duration in minutes — is not merely hard to detect: prior to a targeted patch, the pipeline's
duration parser silently reinterpreted the clock-time string as a plausible-looking duration and
wrote it into the cleaned dataset with **no flag**, in 383/400 (95.8%) SOL and 384/400 (96.0%)
WASO injected cases, with only 4.2%/4.0% caught in any form. This is not a miss; it is a
**misrepair** — the record looks clean and is wrong. A patch ("PART A4",
`inst/scripts/checkforerrors_processing.R`) routes clock-time-shaped duration entries to human
review instead. A full re-run against the current pipeline shows misrepair now fully closed for
both fields (0/400 each), at the cost of resolving very little automatically: only 1.8%/3.2% of
SOL/WASO cases are auto-corrected to the true value, with the remaining 98.2%/96.8% flagged for
human review rather than resolved. (An intermediate re-run shortly after the patch had reported a
3.5% residual silent-misrepair rate for SOL specifically — clock-time strings of the form
"01:XX" that produce no textual correction signal for the patch to key off. This residual did
not reproduce in the later, current re-run reported here and has not been further investigated;
it is noted rather than silently dropped.) Both flagged and auto-corrected outcomes are safe in that neither delivers
a wrong value silently, but conflating them — e.g. reporting a combined "caught" percentage
without separating correction from flagging — would overstate how much the pipeline resolves
unassisted. We propose the **misrepair/miss distinction** as a general methodological point for
diary-cleaning evaluation: a detection metric that only asks "was this flagged" cannot see this
failure mode, because the record it should have flagged was never flagged — it was quietly
rewritten. Any cleaning pipeline that performs implicit type coercion (parsing a value into a
different unit or format than what was entered) without checking plausibility of the
*re-parsed* result, not just the raw input, is structurally exposed to this failure mode.

### 2.2 Channel B — redundant-channel validation (real data, n=13,990)

Two independent measures of sleep-onset latency exist in the raw diary data: self-reported
duration (`duration_totalmin_sol_estimate_am`) and the timestamp-derived gap
(`time_sleep − time_bed`). If the pipeline's timestamp-normalization step (Step 4: AM/PM
12-hour-flip correction and small-order-error swaps) is correcting records correctly, the
corrected gap should move closer to self-reported SOL than the raw gap was. This check is valid
only because Step 4 is provably blind to the duration columns (`duration_vars` is filtered and
declared in `normalize_sleep_time_sequence.R` but never referenced again in the file — verified
by direct source inspection before running the analysis, to rule out circularity).

Restricted to the three correction types that touch the bed/sleep pair (n=88 corrected records
on real production data, n=13,990 total):

| correction_type | n | improved | worsened | median before → after | P(improved), 95% CI | Wilcoxon p |
|---|---|---|---|---|---|---|
| bed_sleep_swap_3h | 39 | 39 | 0 | 31 → 5 min | 100% [91.0–100%] | 4.9e-08 |
| sleep_reduce_12h_loop | 38 | 38 | 0 | 720 → 9.5 min | 100% [90.7–100%] | 3.1e-08 |
| sleep_awake_swap_3h | 10 | 3 | 7 | 5 → 90 min (worse) | 30% [6.7–65.2%] | 0.036 |
| **all bed/sleep-relevant** | **88** | **81** | **7** | **120 → 8.5 min** | **92.0% [84.3–96.7%]** | **1.3e-12** |
| (control, not bed/sleep-relevant) | 11 | 0 | 0 | unchanged | — | — |
| (control, uncorrected rows) | 2,751 | — | — | Δ = 0 exactly, all rows | — | — |

`sleep_reduce_12h_loop`'s effect is the cleanest confirmation available: median discrepancy
starts at ~720 minutes (exactly 12 hours, mechanistically what the AM/PM-flip logic targets)
and lands at 9.5 minutes, inside the baseline self-report noise band (median 13 min on
uncorrected rows). `sleep_awake_swap_3h` is a genuine, disclosed negative finding: with only
n=10 the interval is wide, but the direction is consistently unfavorable (7/10 worse,
Wilcoxon p=0.036). Mechanistic tracing found the rule solves a sleep→awake ordering violation at
the cost of the bed→sleep relationship; 6 of the 7 worsened cases are themselves caught by a
downstream temporal-order check and routed to human review, but one case (a single real record)
is a genuinely silent worsening with no downstream flag. This is reported as an open,
un-resolved limitation of that specific rule rather than smoothed over.

A companion descriptive analysis (n=2,735 uncorrected real records) addressed a possible
confound in Channel B: whether `time_sleep` is answered as "fell asleep" or "lights out."
Point-level correlation between the raw gap and self-reported SOL is weak (Pearson r=0.13), but
the population-level trend rises from ~15 to ~37.5 minutes across SOL deciles, which rules out
the flat-line prediction implied by a "lights out" reading and is directionally consistent with
"fell asleep" — corroborating a direct survey-item confirmation obtained earlier in the study.
This settles the *direction* of the semantic question on real-data evidence but not a precise
per-record correspondence, so Channel B's results should be read as convergent validity (values
become more internally consistent) rather than absolute accuracy.

### 2.3 Channel C — human adjudication (development-time inter-rater agreement)

Two research-team coders independently reviewed all flagged and atypical real-data cases
identified during development (n=75: manual error and unusual-pattern review combined). Raw
agreement was 64.0% (48/75); the remaining 36.0% (27/75) reached consensus after discussion.
Cohen's κ could not be computed from the retained data — the CSV records only the adjudicated
outcome (`agreement_cd_mtb`: Agree / Consensus Reached), not each coder's original independent
label — and this is disclosed as a limitation rather than substituted with an estimated or
assumed value. This is development-time inter-rater reliability, not independent blind
annotation: both coders are members of the research team and had visibility into pipeline
output, which is stated plainly rather than framed as blinded expert review.

### 2.4 Channel D — downstream consequence

Not yet executed as a completed analysis at the time of this draft; see "Planned but not yet
executed" below.

## 3. Architecture as a validation-enabling design choice

The false-alteration-rate measurement in §2.1 is possible only because the architecture
preserves the original, uncorrected value alongside every correction: a pipeline that
overwrites raw values in place has no data left from which to compute "was a field changed that
should not have been." This is a structural argument, not an empirical comparison against other
published pipelines (which would require a systematic review this paper does not undertake): the
four-layer, non-destructive design is a necessary condition for the specific measurement in
§2.1 to be possible at all, and its absence in an in-place-editing pipeline would make that
measurement structurally uncomputable, not merely unreported.

## 4. Overall real-data outcome

Applied to the full study dataset (n=13,990 diary-days), the pipeline flags 1,048 records
(7.5%) for human review and performs 0 unaudited automatic corrections in the value-level
category error/unusual class; all automatic corrections that do fire are order/AM-PM-only
timestamp rules validated directly in §2.2. The flagged-not-corrected volume is a direct,
intended consequence of the design principle established by the field-misentry finding: where
value-level ambiguity exists, the pipeline defers to a human rather than silently resolving it.

## 5. Limitations, disclosed rather than smoothed over

- `sleep_awake_swap_3h`'s one silent-worsening case (§2.2) is real and unresolved at the level
  of that specific rule.
- Cohen's κ is not computable from the retained adjudication data (§2.3); only raw agreement is
  reported.
- `cross_participant_spike`'s 11.3% misrepair figure (§2.1) has not been independently
  re-verified at the same rigor as the other categories.
- Population-dependent plausibility thresholds (§2.1) are tuned on a healthy young-adult sample
  and produce substantially higher review volume — not silent errors, but real added workload —
  on atypical populations; this is disclosed quantitatively (7.7% vs 0.0–0.3%) rather than left
  as a qualitative caveat.
- Two consequential constants — the 3-hour adjacent-swap threshold and the cross-participant
  MAD-based spike-detection parameters — are currently hard-coded rather than exposed through
  the YAML config, which is a real gap against the "configurable framework" contribution and a
  precondition for the planned multiverse analysis (§6).

## 6. Planned but not yet executed

The following are part of the validation design (see project design documents) but have not
been run to completion as of this draft, and are not represented as findings above:

- Pre-registration confirmatory/exploratory mapping.
- Multiverse / specification-curve analysis across threshold and discrete-branch choices
  (blocked on exposing the two hard-coded constants noted in §5).
- A second, schema-different dataset or a formal held-out-by-audit-trail generalization check.
- A complementarity comparison against SHUTi's published rule set (framed as complementary
  coverage, not a performance contest).
- Downstream sensitivity analysis (raw vs. cleaned summary sleep metrics, and — kept
  deliberately lightweight — a single illustrative sleep×affect model).

## Open questions for the authors

- Placement: full Methods vs. a dedicated Validation section, given the length.
- Whether to cite the field-misentry patch commit hash in the manuscript text.
- Whether Channel D should be completed before submission or explicitly scoped as future work.
