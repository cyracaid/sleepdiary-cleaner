<div id="main" class="col-md-9" role="main">

# Detection Thresholds — Defaults, Rationale, and When to Change

<div id="detection-thresholds--defaults-rationale-and-when-to-change"
class="section level1">

Flag thresholds are **scientific judgments, not just config values.**
Defaults are **deliberately lenient** — appropriate for a **general
healthy-adult sample** where the goal is to catch data-entry errors and
gross outliers, not to diagnose insomnia. For clinical samples
(insomnia, elderly, shift-work), revisit every row.

> **Provenance:** defaults tuned on healthy young-adult university EMA
> sample. Document your own study population here so downstream users
> know the reference.

<div class="section level2">

## Threshold table

| Config key                                                   | Default | Flags                          | Rationale                                                                                      |
|--------------------------------------------------------------|---------|--------------------------------|------------------------------------------------------------------------------------------------|
| `classification.metric_validation.sol.excessive_minutes`     | `120`   | SOL &gt; 2h                    | Very lenient. Clinical SOL marker \~30 min (Lichstein et al.). 2h catches only gross outliers. |
| `classification.metric_validation.se.min_valid_percent`      | `0`     | SE &lt; 0%                     | Structural impossibility → always flag                                                         |
| `classification.metric_validation.se.max_valid_percent`      | `100`   | SE &gt; 100%                   | Structural impossibility → always flag                                                         |
| `classification.flag_severity.poor_efficiency_threshold_pct` | `70`    | SE &lt; 70%                    | Lenient. Insomnia cutoff \~85%. 70% flags markedly poor efficiency.                            |
| `classification.flag_severity.high_sol_threshold_hours`      | `1`     | SOL &gt; 1h                    | Lenient vs 30-min clinical marker.                                                             |
| `classification.flag_severity.high_waso_threshold_hours`     | `1.5`   | WASO &gt; 1.5h                 | Lenient. Clinical WASO marker often &gt; 30 min.                                               |
| `classification.metric_validation.tst_tib_ratio.min_ratio`   | `0.5`   | TST/TIB &lt; 0.5               | Equivalent to SE &lt; 50%                                                                      |
| `classification.metric_validation.tst_tib_ratio.max_ratio`   | `1.0`   | TST/TIB &gt; 1.0               | Impossible → hard error                                                                        |
| `timestamp.sequence.max_gap_hours`                           | `12`    | AM/PM flip trigger             | Assumes no legitimate interval &gt;= 12h                                                       |
| `timestamp.midnight_threshold_hour`                          | `6`     | Times &lt; 6AM → next day      | Standard diary convention                                                                      |
| `interval.mmss_threshold_minutes`                            | `60`    | value &gt; 60 with `:` → MM:SS | Heuristic for ambiguous formats                                                                |

</div>

<div class="section level2">

## Suggested config comments

Add rationale inline next to each threshold:

<div id="cb1" class="sourceCode">

``` yaml
  flag_severity:
    poor_efficiency_threshold_pct: 70   # lenient (healthy sample). Clinical cutoff ~85%
    high_sol_threshold_hours: 1         # lenient. Clinical marker ~30 min
    high_waso_threshold_hours: 1.5      # lenient. Clinical marker ~30 min
  metric_validation:
    sol:
      excessive_minutes: 120            # gross-outlier catch, not clinical
```

</div>

</div>

<div class="section level2">

## References

-   Lichstein et al. (2003), *Behaviour Research and Therapy* —
    quantitative criteria for insomnia (30-min SOL/WASO, \~85% SE)
-   AASM standard actigraphy-diary reporting conventions

</div>

</div>

</div>
