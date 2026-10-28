# Methods: Validation Summary (Short Form)

*For the full 9-step chain, see vignette("validation-methodology")*

## Overview

sleepcleanr validates sleep diary cleaning through a **three-tier chain**: 
1. Synthetic data with known ground truth
2. Real data (n=13,990) with redundant channels
3. Robustness across parameter choices

---

## Validation Results

### Tier 1: Synthetic Benchmarks

| Test | Input | Result | Interpretation |
|---|---|---|---|
| **Clean-input specificity** | 10,000 error-free records | 0 changes, 0 flags | No false positives on good data |
| **Injected-error recall** | 400 errors (8 categories) | 0.995 [0.993–0.997] | High detection rate across error types |
| **vs naive baseline** | Same 400 errors | pipeline 0.995 vs naive 0.623 | 59% improvement over rule-of-thumb |
| **Value correctness gap** | AM/PM swap detection | L1 (detect) 1.0 vs L3 (value correct) 0.565 | Route to human; don't auto-fix uncertain corrections |

### Tier 2: Real Data (13,990 records)

| Validation | Measure | Result | Action |
|---|---|---|---|
| **Redundant-channel** | Corrections move toward self-report | 81/88 (92%) improved | 1 bad rule identified & guarded (v1.4.3) |
| **Bland-Altman noise** | SOL agreement band | ±75 minutes | Flags inside noise → human review; WASO 3.3× safer |
| **Audit report** | Conservative flagging | 0 auto-fix / 1,048 flags | Every change logged for re-review |
| **Human agreement** | Co-reviewer pairs | 64% (n=75) / 89% (n=37) | Expected for subjective call-outs; high on clear errors |

### Tier 3: Robustness

| Factor | Sensitivity | Action |
|---|---|---|
| **TST (Total Sleep Time)** | Robust across seed/config | Use main curve as-is |
| **SOL (Sleep Onset Latency)** | Sensitive [22.7–58.1 min range] | Report range in paper; seed results in appendix |
| **Multiverse impact (D₂)** | 44% of variance | Full factorial specification in reproducible YAML |

---

## Data Quality (Pipeline Output)

After full cleaning pipeline:

```
Records processed:     13,990
Clean (no flags):      13,660 (97.6%)
Minor issues (1 flag):    320 (2.3%)
Major issues (2+ flags):   10 (0.1%)

Sleep metrics (final):
  Mean TST:  7.71 hours [SD 1.36]
  Mean SOL:  28.9 min [SD 24.1]
  Mean SE:   84% [SD 14]
```

---

## Key Design Decisions

1. **Conservative flagging, not auto-fixing**  
   → 0 automatic corrections; 1,048 manual reviews logged
   → All changes reversible via audit_dispositions ledger

2. **Non-destructive architecture**  
   → Raw values always retained; corrections tracked separately
   → False-fix damage quantifiable post-hoc

3. **Transparent audit trail**  
   → Every flag stored in CSVs; every manual decision recorded
   → Enables re-audit and sensitivity analysis

4. **Parameter transparency**  
   → All thresholds in YAML; multiverse grid specified upfront
   → Robustness proof prevents hidden researcher degrees of freedom

---

## When to Use This Pipeline

✅ **Good fit:**
- Sleep diary EMA data (Qualtrics, REDCap, custom)
- Multi-day studies with time-based reporting
- Need for audit trail & reproducibility
- Published thresholds & assumptions matter

❌ **Not ideal for:**
- Actigraphy/objective sleep data (different error modes)
- Single-timepoint surveys (no temporal order validation)
- Fully automated workflows (requires human review loop)

---

## Citation

```bibtex
@article{sleepcleanr2026,
  title={sleepcleanr: A Rigorous, Auditable Pipeline for 
         Multi-Day Sleep Diary Data Cleaning and Validation},
  author={[Author], Cyra AI, and Team},
  journal={[Target: Sleep Health or Journal of Sleep Research]},
  year={2026},
  note={R Package v1.4.4 + Methods Paper (pending)}
}
```

---

## Reference

- **Full validation methodology** (9 steps, 3 tiers):  
  `vignette("validation-methodology")` or  
  https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology.html

- **Test coverage & benchmarks**:  
  `tests/testthat/` (308 tests PASS)  
  https://github.com/cyracaid/sleepdiary-cleaner/actions

- **Audit & reproducibility**:  
  `work_logs/` + `output/audit_integrity_report.csv`

---

*Methods summary generated 2026-08-25 post-ARIS plan verification*  
*Data: 13,990 records; Golden baseline: 308 PASS / 1 snapshot diff*
