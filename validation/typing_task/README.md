# Typing task: real typing errors with a known truth

The synthetic benchmark contains the errors we designed the rules for, and the study
data carry no record of what each participant meant. This task produces both: people
read a short description of a night and type it into a diary form, so every error in
what they typed has a truth that nobody on the project chose.

Nothing here contains participant data. Answers are study data: keep them outside the
repository.

## Materials

| File | What it is |
|---|---|
| `scenarios.csv` | 40 short stories with the true bed, sleep, awake and get-up times and the latency and wake-after-sleep-onset minutes (seeded; about a quarter use spoken forms such as "a quarter to midnight", which invite conversion errors) |
| `typing_task_form.html` | the participant form, one self-contained page: no network, no server; it saves the answers as a CSV on the participant's computer |
| `make_scenarios.R` | regenerates both from a seed (`--n`, `--seed`) |
| `score_typing_task.R` | compares what was typed with the truth and reports what the pipeline did with each entry |
| `demo_simulate.R` | tests the whole chain with simulated participants (not a result about people) |

## Running it

1. Send each participant `typing_task_form.html` (open it in any browser). It takes
   about 10 to 15 minutes for 40 nights. Ask them to type the way they normally would.
2. Each participant sends back the CSV the form saves. Put the files in one folder
   outside the repository.
3. Score:
   ```bash
   Rscript validation/typing_task/score_typing_task.R ~/typing_task_answers ~/typing_task_scores
   ```
   It builds the diary input, runs `run_pipeline()` (needs sleepcleanr installed),
   and prints: how many entries contain a wrong typed value (with an exact interval);
   what the pipeline did with those entries (corrected to the truth, changed to
   something else, flagged only, left alone and still wrong); the entries that were
   typed correctly and whether any was flagged or changed; and the error kinds (AM/PM,
   transposed times, duration field, other). `per_entry.csv` and `summary.csv` in the
   second folder are aggregate and carry only participant codes.

## What counts as an error

A typed value is wrong when it does not give the true time or duration. A format slip
that still reads as the right value ("1120" or "11.20" for 11:20) is not an error here,
because the pipeline reads it correctly. A missing AM/PM, an hour outside 1 to 12 and a
non-numeric duration count as wrong.

## Sample size

With 30 participants and 40 nights (1,200 entries) a typing-error rate of about 5% gives
about 60 error entries and an interval of roughly 4 to 6.5% for the rate; the share the
pipeline handles among them has an interval about 17 points wide at 90%. Ask more people
if the interest is in a rare kind (for example transposed times).

## Limits

- It tests the pipeline on errors made while reading a story, not on errors made while
  recalling one's own night; the latter may differ.
- Participants are not the study's participants. Say who they were.
- The scenarios have regular times (multiples of five minutes).
- The task measures typing errors, not participants' misremembering.
- If the people typing are the project's authors, state it.
