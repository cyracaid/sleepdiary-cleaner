# Validation Methodology

This vignette is the full validation walkthrough that appears in
condensed form in the README. It answers, step by step: does the
pipeline harm good data? can it catch known errors? does it fix them
*right*? is it better than doing nothing? does it improve real data? how
noisy is the self-report itself? what does it find in real data? do the
humans agree? do our choices matter?

``` r
library(splsleep)
```

## Why validation at all

Sleep-diary cleaning has no ground truth: nobody can know for certain
what a participant meant when they typed “10:30” into a duration field.
Testing coverage proves the code does what it was designed to do, but
not that the design is methodologically valid. Our answer is a
multi-step validation chain where each step asks one question, fails in
a different way, and is deliberately independent of the others.

                        VALIDATION CHAIN (9 steps, three tiers)
                        ──────────────────────────────────────────

      SYNTHETIC TIER (ground truth we record ourselves at injection)
      ────────────────────────────────────────────────────────────
      Step 1: Clean-input specificity ─── FCR / FAR_flag / FAR_alter
              (10,000 error-free records; expect ZERO changes/flags)
                        │
                        ▼
      Step 2: Injected-error benchmark ── pooled recall 0.995 [0.994, 0.997]
              (400 errors/category; ground truth recorded at injection)
                        │
                        ▼
      Step 3: Detection vs value-correctness ── L1 vs L3 gap
              (e.g. ampm_swap L1 1.0 / L3 0.565 → routed to human)
                        │
                        ▼
      Step 4: Controls ── no_cleaning 0 / naive_rule 0.623 / pipeline 0.995

      REAL-DATA TIER (n = 13,990, no synthetic standard needed)
      ────────────────────────────────────────────────────────────
      Step 5: Redundant-channel validation ── corrections move values
              toward self-report: 81/88 (92%) improved; 1 bad rule
              found & guarded (v1.4.3)
                        │
                        ▼
      Step 5.5: Bland-Altman (3 analyses) ── SOL ±75-min noise band
              → SOL flags INSIDE NOISE (descriptive, routed to human);
              WASO 3.3× above noise (SAFE)
                        │
                        ▼
      Step 6: Report-only audit ── 0 AUTO_FIX, 1048 FLAG
              (922 window violations, 140 order violations, ...)
                        │
                        ▼
      Step 7: Human co-review agreement ── 64.0% (n=75) / 89.2% (n=37)

      ROBUSTNESS TIER (does the choice matter?)
      ────────────────────────────────────────────────────────────
      Step 8: Multiverse + downstream + seeds ── D2 = 44% (swap
              threshold dominates); TST robust, SOL sensitive
              (12.1–48.4 min); recall stable 0.993–0.995 across seeds

## Step 1 — Does the pipeline touch clean data? (clean-input specificity)

**What we do.** Generate synthetic data with *no errors at all* (10,000
records), run the pipeline, and count how many records it changed or
flagged. **The rule.** On clean input the correct answer is zero of
both. Any change is pure iatrogenic damage; any flag is a false alarm.

**Result.** FCR (records altered) **0 / 9,996**; FAR_flag **0 / 1,609**;
FAR_alter **0 / 1,609** (rule-of-three 95% upper bound ≈ 0.03%).
**Meaning.** The pipeline does no harm to good data.

## Step 2 — Does the pipeline catch known errors? (injected-error benchmark)

**What we do.** Take clean synthetic data, deliberately corrupt it with
known errors — 400 injections per error category — and record the true
value of each injection *at injection time* (a ground-truth table). Run
the pipeline on the corrupted data. Compare its output against the
ground truth.

**Result.**

| Quantity                        | Value                      |
|---------------------------------|----------------------------|
| Pooled recall (errors detected) | **0.995** \[0.994, 0.997\] |
| Specificity                     | 1.0                        |

Cluster-bootstrap CIs at participant level (1,000 iterations), because
records from the same participant are correlated.

**Meaning.** 99.5% of injected errors are caught — either flagged for a
human or auto-corrected. This benchmark is also how we found and fixed
two real bugs that were invisible in logs and by eye (v1.4.1, see Step
3).

**What this ground truth is — and is not (important).** The ground truth
here is **not** an external gold standard (there is none for free-text
diary entry — nobody can know what a participant meant by “10:30”). It
is a *self-consistent* standard: the error definitions are ours, the
corruption is ours, and we record the true value *at the moment we
corrupt it* — before the pipeline ever runs. The benchmark proves the
pipeline does what *we defined* as cleaning, not that our definition
matches reality. Three mechanisms keep this from being circular:

1.  **The error taxonomy is a three-source union** — errors we have
    observed in real data, errors reported in the literature
    (e.g. SHUTi, RESTING), and errors that are theoretically possible
    but we have never caught. It is deliberately *not* “the errors the
    pipeline already detects”.
2.  **A real-data layer that needs no synthetic standard at all** (Steps
    5–7).
3.  **Closed-loop blind-spot closure**: when a new error type is
    discovered in real data, it is added to the catalog, injected, and
    the benchmark re-run.

## Step 3 — When we fix, do we fix *right*? (detection vs. value-correctness)

**What we do.** Split “caught” into two numbers: **detected** (L1:
flagged or corrected) and **value-correct** (L3: the final value
actually equals the ground truth). The gap between them is where human
review lives.

**Result.** `ampm_swap`: L1 1.0, L3 0.565. `field_misentry`: L1 1.0, L3
0.018. Mis-repair rate (MRR) in the current run: **0 across all
categories**.

**Meaning.** Detection is not the same as guessing a correct value. When
the correct restoration is uncertain (AM/PM flips,
clock-time-in-duration fields), the pipeline flags for a human instead
of guessing — that is the design working. The `field_misentry` L3 gap is
the *fixed* state of a bug the benchmark caught: pre-v1.4.1, 95.8% of
these entries were silently “repaired” to wrong but plausible values;
now 0% are — they go to human review.

## Step 4 — Is the pipeline better than doing nothing? (controls)

**What we do.** Compare three conditions on the same corrupted data: no
cleaning at all, a naive regex-only rule, and the full pipeline. The
no-cleaning condition is the floor (what the study team gets if they
skip cleaning entirely); the naive rule is the “someone wrote a quick
script” baseline; the pipeline is the full design. The gap between naive
and pipeline is the *incremental* value of the rule families — the
number that justifies the design’s complexity.

**Result.** no_cleaning **0** / naive_rule **0.623** / pipeline
**0.995**. **Meaning.** Raw strings give zero detection; a naive rule
catches 62%; the full pipeline 99.5%. The +37 points over naive is the
value the rule families add.

## Step 5 — Do corrections make real data *better*? (redundant-channel, no synthetic standard)

**What we do.** Real diaries measure sleep-onset latency two independent
ways: self-reported duration, and derived from timestamps. Step 4’s
correction logic never reads the duration columns (verified by source
inspection), so comparing the two after correction is non-circular. Run
on real production data (n = 13,990) — no injection needed.

**Result.** `bed_sleep_swap_3h` 39/39 improved (100% \[91–100%\]);
`sleep_reduce_12h_loop` 38/38; all bed/sleep-relevant corrections 81/88
(92%). This step also surfaced a *negative* rule, `sleep_awake_swap_3h`
(7/10 worsened, p = 0.036): **diagnosed and fixed in v1.4.3** with a
`bed <= awake` guard. Post-guard rerun: swap rows 10 → 4, 3/4 improved;
7 worsened → 1 disclosed boundary case.

**Meaning.** Corrections move values toward self-report 92% of the time,
on real data, with a redundant-channel yardstick that needs no synthetic
standard. The one bad rule was found *by this step* and guarded.

## Step 5.5 — How noisy is the self-report itself? (Bland-Altman, three analyses)

**What we do.** Ask a different question from Step 5: not “do
corrections improve values?” but “how much do the two self-report
measures of the same construct disagree in the first place?” This is
*measurement characterization* — it quantifies the noise floor that any
threshold must be judged against. Three analyses, all from
[`bland_altman()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/bland_altman.md)
on real data (n = 13,990):

| \#  | Analysis                     | Inputs (reported vs computed)                     | Output                                                                 |
|-----|------------------------------|---------------------------------------------------|------------------------------------------------------------------------|
| A1  | **SOL Bland-Altman**         | self-reported SOL vs computed SOL                 | bias, 95% LoA, half-width, % outside, proportional-bias p              |
| A2  | **WASO Bland-Altman**        | self-reported WASO vs computed WASO               | same as A1                                                             |
| A3  | **Threshold vs noise ratio** | each flag threshold ÷ its metric’s LoA half-width | per-threshold verdict: CONSERVATIVE / SAFE / BORDERLINE / INSIDE NOISE |

**Result.**

|         | Bias     | LoA half-width | Threshold            | Ratio | Verdict                   |
|---------|----------|----------------|----------------------|-------|---------------------------|
| A1 SOL  | +1.6 min | **75.4 min**   | excessive 120 min    | 1.59  | ⚠️ INSIDE NOISE           |
| A1 SOL  | —        | 75.4 min       | high severity 60 min | 0.80  | ⚠️⚠️ INSIDE NOISE         |
| A2 WASO | small    | **27.3 min**   | high severity 90 min | 3.29  | ✅ SAFE                   |
| A3      | —        | —              | SE poor (70%)        | —     | N/A (no self-report pair) |
| A3      | —        | —              | TST/TIB ratio        | —     | N/A (no self-report pair) |

**What this means (read carefully — this is a finding, not a bug).**

1.  Computed and reported SOL differ by up to **±75 min** — a quantified
    perception-bias estimate, and a publishable finding on its own.
2.  SOL flag thresholds (60/120 min) sit **inside** that noise band, so
    a “high SOL” flag cannot distinguish a real long SOL from ordinary
    reporting disagreement. This does **not** corrupt data:
    `flag_severity` is a descriptive column that feeds no correction
    path (verified in code). SOL flags are therefore **descriptive
    indicators routed to human review**, not automated error signals.
3.  WASO thresholds clear the noise floor by **3.3×** — safe.
4.  SE and TST/TIB have no self-report counterpart, so they cannot be
    Bland-Altman validated; stated explicitly rather than implied.
5.  LoA bound *consistency*, never *accuracy* — do not cite them as
    criterion validity (that would require actigraphy/PSG, which this
    EMA-only dataset lacks).

## Step 6 — What does the pipeline find in real data? (audit, n = 13,990)

**What we do.** Run the pipeline in report-only mode over all 13,990
real records; count what each rule family flags. No data is changed.

**Result.** 0 AUTO_FIX, 1048 FLAG — of which **922 logical-window
violations** (derived SOL longer than the bed→sleep window, max 225
min), 140 temporal order violations, 1 redundancy-confirmed worsening
(the known boundary case, independently reproduced from the work log), 1
cross-day spike, 0 unmapped correction notes (all 14,338 notes map to
known mechanisms).

**Meaning.** The pipeline finds real, previously unknown problems in our
data (922!) without changing a single value. This is the layer the
synthetic benchmark cannot provide: synthetic proves *detection
ability*, this proves *real-world prevalence*. Script:
`audit_review_queue_m1_m7.R`; output `audit_m1_m7_decision.csv`.

## Step 7 — Do the humans agree? (co-review agreement)

**What we do.** Two researchers jointly reviewed every record the
pipeline flagged. Report the proportion agreed on the spot vs. requiring
discussion.

**Result.** Flagged temporal errors: **64.0%** immediate agreement (n =
75), 36.0% required discussion. Statistically atypical records:
**89.2%** (n = 37), 10.8% required discussion. The two tracks are
independent and not additive; the flagged set grew 47 → 75 as detection
rules strengthened.

**Meaning.** Reported as **co-review agreement**, not inter-rater
reliability / Cohen’s κ — the review was collaborative (one shared
worksheet), so the independent label sets κ requires never existed.
Higher agreement on atypical cases than on corrections is consistent
with task difficulty: judging whether a record is unusual is easier than
deciding exactly how to fix it.

## Step 8 — Do our choices matter? (multiverse, downstream sensitivity, seeds)

**Why we ask this.** Every threshold and rule choice in the pipeline is
a judgment call: the 12-hour AM/PM flip trigger, the 3-hour
adjacent-swap window, the 4× MAD spike cutoff, the SOL/SE/WASO flag
thresholds, the 6-minute verification tolerance. A cleaning pipeline
whose *answers* depend heavily on which of these reasonable values we
picked is not trustworthy — the cleaning would be manufacturing its own
conclusions. This step measures how much the results and the downstream
metrics move when we vary those choices across a specification grid.

**What we do.** Three analyses, in increasing order of scope:

1.  **Multiverse analysis (specification curve).** Define the cleaning
    choices that are genuinely open (continuous thresholds — 12 h, 3 h,
    midnight 6, mmss 60, SOL 120/180, SE 70, WASO 1.5, TST/TIB 0.5, CP
    4× — plus discrete branches: which rows to trust, cross-participant
    layer on/off, manual-review layer on/off). Hard constraints are
    excluded (those are logic, not choice). Screen with one-at-a-time
    (OAT) runs, then a full factorial grid; each spec runs the real
    pipeline and records the same outputs. Two output contracts: a
    **specification curve** (Simonsohn-style plot of the metric across
    all specs) and a **variance decomposition** (how much of the
    variation each dimension explains). Script:
    `validation/synthetic/multiverse.R`; results in
    `results/multiverse/`.
2.  **Downstream sensitivity.** The same grid, but measuring the
    *deliverable* quantities the study team actually uses: mean TST,
    mean SOL, and analyzable n (records that survive the cleaning
    decisions).
3.  **Seed sensitivity.** Regenerate the whole benchmark under different
    random seeds and confirm the headline numbers do not move.

**Result.**

*Multiverse — which choice dominates?*

| Dimension                    | Share of variation |
|------------------------------|--------------------|
| D2 (adjacent-swap threshold) | **44%**            |
| D1 (AM/PM flip trigger)      | 10%                |
| others                       | remainder          |

*Downstream — do the delivered metrics move?*

| Quantity       | Base spec | Across specs                      |
|----------------|-----------|-----------------------------------|
| mean TST (h)   | 7.89      | \[7.76, 7.92\] — robust (±0.08 h) |
| mean SOL (min) | 20.7      | \[12.1, 48.4\] — **sensitive**    |
| analyzable n   | 6,611     | \[6,333, 6,692\]                  |

*Decision-relevant deltas (B1/B2):* B1 (which rows to trust) moves mean
TST by **29.6 min**; B2 (WASO trust gate variant) moves analyzable n by
**1,131 records**. These are not errors — they are the honest range of
what a *different reasonable* decision produces.

*Seeds:* pooled recall stable at 0.993–0.995 across 4 seeds, control FAR
0 in all; the one family that wobbles (0.886–0.907) is the known-weak
`cross_participant_spike` — already disclosed as audit-only below.

**Meaning.** Three separate questions, three clear answers: (1) *which
decision matters most?* — the swap threshold, at 44% of variation; (2)
*which conclusions are robust?* — TST yes (±0.08 h), SOL no (12–48 min),
and we now know why (perception bias, Step 5.5); (3) *are the numbers
reproducible?* — yes across seeds (recall 0.993–0.995, FAR 0), with the
single known-weak family disclosed rather than hidden.

## Honest caveats (read before using any number)

1.  **`cross_participant_spike` is the weakest family** — L1 0.886–0.907
    across seeds, value-correct 0 *by design* (it is audit-only: a
    single-day spike may be a real event — illness, shift work — so it
    flags for a human and never auto-fixes).
2.  **SOL flag thresholds sit inside the ±75-min Bland-Altman noise
    band** of self-reported SOL — SOL flags are descriptive indicators
    routed to human review, not automated error signals (verified in
    code: `flag_severity` feeds no correction path). WASO thresholds
    clear the noise floor by 3.3×.
3.  **Ablation recall uses a flag-based definition** (AUTO_FIXed records
    never enter the flag queue, so disabling a fixing rule inflates the
    flag count) — the ablation table is reported as supplementary with a
    footnote; the primary evidence is the multiverse variance
    decomposition.
