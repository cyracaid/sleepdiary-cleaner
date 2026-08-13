Subject: splsleep — benchmark results for our meeting, plus what we need to decide

Hi Maia,

Quick recap since you last looked: v1.3.9 → v1.4.0 was the delivery release
(`finalize_columns()`, the two analysis-ready datasets). v1.4.0 → v1.4.1
fixed two real bugs found while validating on real data (a silent
duration-misparse that a synthetic benchmark caught, and a human-review CSV
that was silently never being written). v1.4.1 → v1.4.2 (just now) tracks
that benchmark harness itself in the repo, since it had only existed in a
scratch environment until today.

That benchmark is what I want to spend most of our meeting on.

## What to look at before we talk

- `validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md` — the numbers.
  Headline ones: 0/10,000 false alterations on structurally-clean synthetic
  input (nothing gets touched that shouldn't be); a population-stratified
  flag-rate gradient (0.0% on a healthy-adult-like population up to 7.7% on
  an insomnia-like one, same thresholds); per-category detection results
  across 12 injected-error types, including the two categories that led to
  the v1.4.1 fixes.
- `benchmark-design.md` — the design rationale: why enriched sampling
  instead of injecting at the real-world error rate, the three-way split of
  "false correction" (silently altered / flagged for no reason / fixed to
  the wrong value — these have very different severities and get
  conflated if reported as one number), and what a full version of this
  would still need (recall/specificity/PPV curves, multiverse analysis).

## What we need to decide together

1. **Pre-registration mapping.** Since we'd already pre-registered before
   this benchmark existed, each result needs to be sorted into
   confirmatory / exploratory / "conflicts with what we registered, needs
   a dated addendum." I don't have the pre-reg text in front of me — can
   you bring it, or send it ahead so I can do a first pass?
2. **How much more of this to do before submission.** What's done now is a
   first pass: it already found and fixed two real bugs, and gives clean
   "zero false alterations" and per-category detection numbers. The full
   design also calls for proper recall/specificity/PPV curves with
   cluster-bootstrap CIs, a multiverse analysis over cleaning-choice
   parameters, and a leave-one-out ablation — realistically a couple more
   weeks of work, and the multiverse piece needs a small refactor first
   (two thresholds that matter a lot — the 3-hour adjacent-swap window and
   the cross-participant spike constants — are hardcoded rather than
   configurable). Is the first-pass benchmark enough methods evidence for
   this paper, with the rest flagged as future work, or do we want more of
   it done before we submit?
3. **Downstream sensitivity analysis** (how much TST/SOL/WASO/SE move under
   different cleaning-pipeline choices) is part of the same validation
   item but hasn't been started at all — same question, in scope now or
   later?
4. One finding worth a line in Methods or Limitations either way: on
   synthetic data with realistically long SOL and low SE (no injected
   errors at all), the pipeline's default thresholds flag records at
   roughly 26x the rate they do on the healthy-adult population they were
   tuned on. Expected — `THRESHOLDS.md` already said as much — but now we
   have an actual number.

## Also still on my list

The methods draft's "n=47/37... resolved disagreements (X%)" sentence
needs a rewrite before submission: we can't report a κ (the double-review
was collaborative on one shared sheet, not independently coded — so
report raw agreement instead: 64.0% for flagged errors n=75, 89.2% for
atypical cases n=37), and the n=47/37 counts are stale — the atypical count
still matches at 37, but flagged errors has grown to 75 since March.

## Attachments

(all in `manuscript_notes/` locally — that folder is gitignored on purpose,
since a couple of these still have real participant IDs in tables/prose,
unlike everything in the actual repo)

- `manuscript_notes/SYNTHETIC_BENCHMARK_RESULTS.md` — the benchmark numbers (also in the repo, at `validation/synthetic/`, scrubbed)
- `manuscript_notes/benchmark-design.md` — the design rationale and what's still open
- `manuscript_notes/channel-b-redundancy-validation.md` — full Channel B + B1 methods/results/caveats
- `manuscript_notes/development-evidence-audit.md` — full κ / n=47/37/84 writeup
- `2026-08-12_week_work_log_summary_EN.md` / `_CN.md` — full worklog if you want more detail on anything above

Best,
Cyra
