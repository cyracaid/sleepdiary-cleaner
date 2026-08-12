Subject: splsleep v1.4.1 — what changed since 1.3.9, two real-data validations, and a methods-text fix

Hi Maia,

Quick update on the sleep diary pipeline.

## Why we're at v1.4.1 now (last you saw was v1.3.9)

**v1.3.9 → v1.4.0** was the delivery release: `finalize_columns()` now runs as Step 10 and produces
the two analysis-ready datasets (A = 36 columns, B = 15), driven by a single column dictionary instead
of scattered logic. Added a guard against negative durations and CI-verified wiring so a broken
delivery step fails loudly instead of shipping bad output.

**v1.4.0 → v1.4.1** (today) fixes two bugs I found while validating the pipeline on real data:

1. A clock time typed into a duration field (e.g. "10:30" for SOL) was getting silently "corrected"
   by our parser into a small, plausible-looking number, with nothing downstream ever flagging it —
   95.8%/96.0% silent misrepair rate for SOL/WASO in testing. Fixed with a targeted flag; down to
   3.5%/0%.
2. The two human-review CSVs were never actually being written to disk — the code that saved them was
   commented out, even though the pipeline log said "Files saved" every run. Reviewers had nothing to
   review. Fixed.

Both tested and live at `github.com/cyracaid/sleepdiary-cleaner`.

## Two validation results on real data (n=13,990), no synthetic injection

- **Redundant-channel check**: real diaries have two independent SOL measures (self-report vs.
  timestamp gap), and our correction logic never reads the self-report column — so comparing them
  after correction is a clean, non-circular test. Our two biggest correction rules pass strongly
  (p < 1e-7). One smaller rule shows a real, disclosed negative effect (n=10) worth a closer look.
- **`time_sleep` semantics**: confirms what you told us directly — it's sleep onset, not lights-out —
  using real-data evidence this time instead of just the survey wording.

## One fix needed in the methods draft

Tracked down the "X%" in "two independent coders reviewed flagged errors (n=47) and atypical cases
(n=37) ... resolved disagreements (X%)":

- **We can't report a κ.** Since we always worked off one shared sheet rather than coding
  independently first, there's no independent pre-discussion label to compare — that's not
  recoverable, it never existed. Report raw agreement instead: 64.0% for flagged errors (n=75), 89.2%
  for atypical cases (n=37). Word it as "collaborative dual-review," not "inter-rater reliability."
- **n=47/37 are stale.** The atypical-cases count (37) still matches exactly; flagged errors has grown
  to 75 since March as we've added more detection logic. Needs updating to current numbers before
  submission, and the two tracks reported separately rather than summed to 84.

Nothing else is blocked on you right now — the OSF pre-registration is the next thing on my list, will
need your input on content once I get there.

## Attachments

- `2026-08-12_week_work_log_summary_EN.md` / `_CN.md` — full worklog behind this email
- `development-evidence-audit.md` — the κ / manuscript-numbers writeup in full

Best,
Cyra
