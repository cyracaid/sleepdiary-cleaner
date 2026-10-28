# DAY 4: Posit Community Deep Post — 完整草稿

**Platform**: https://community.rstudio.com/  
**Time**: 20-30 minutes  
**Category**: "Posit Cloud & Products" or "R Programming"

---

## 📝 完整帖子内容（复制粘贴到 Posit Community）

### 标题

```
[New Package] sleepcleanr: Auditable pipeline for messy sleep diary data
```

### 帖子正文

```markdown
Hi Posit community!

I'm releasing **sleepcleanr**, an R package for reproducible, auditable 
cleaning of sleep diary data collected via intensive longitudinal research 
(ecological momentary assessment / EMA).

## The problem

Sleep diary timestamps seem simple, but real-world data is messy:

- **AM/PM swaps**: "got up at 23:45" (typo?) vs actual 11:45 PM
- **Duration entry errors**: 120 minutes entered as "02:00" (HH:MM instead of MM)
- **Temporal violations**: "fell asleep at 11:00 PM but went to bed at midnight"
- **Self-report noise**: ±75 min variance in sleep onset latency across duplicate reports

### Current approaches (both problematic)

1. **Skip cleaning** → reproducibility crisis, biased metrics
2. **Ad-hoc filtering** → no audit trail, hard to explain to co-authors/reviewers

### What sleepcleanr does differently

sleepcleanr **flags problems for human review** rather than silently auto-fixing:

- 1,048 flagged records (out of 13,990) → human review
- 0 silent corrections
- Every change logged in reversible CSV ledgers
- Full audit trail: who changed what, when, why

### Validation

Built on a **9-step validation chain**:

1. **Synthetic benchmarks**: 0.995 recall on injected errors
2. **Real-world redundancy**: 92% agreement between duplicate diary entries
3. **Robustness**: multiverse analysis + seed stability proof
4. **Methods documented**: long + short forms, publication-ready figures

308 unit tests passing. All code audited for correctness.

### Quick start

```r
install.packages("sleepcleanr")
library(sleepcleanr)

# Demo on synthetic data
run_pipeline()

# Your own study: YAML config, no code changes
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# Edit my_study.yaml → run_pipeline(config = "my_study.yaml")
```

### Output

- **Dataset A**: Final clean data (1,048 flagged records corrected)
- **Dataset B**: Full audit ledger (what changed, why)
- **30+ figures**: QC plots + research-ready visualizations

### Why transparent cleaning matters

In behavioral science, **we need to know**:
- Which records are flagged and why
- What corrections were made
- Who made them
- Whether they're reversible

This builds trust with reviewers and co-authors. No black boxes.

### Links

- **GitHub**: https://github.com/cyracaid/sleepdiary-cleaner
- **Docs**: https://cyracaid.github.io/sleepdiary-cleaner/
- **Paper** (in prep): Validation methodology + case study

### For researchers using EMA / intensive longitudinal methods

If you collect sleep diaries, movement logs, mood assessments, or any 
timestamp-based self-report data, this architecture (detect → review → log) 
is generalizable beyond sleep.

Feedback very welcome! Questions about validation, extensibility, or methods?

---

**GitHub**: https://github.com/cyracaid/sleepdiary-cleaner
**CRAN**: [just submitted, v1.4.4]
```

---

## ✅ 操作步骤

1. Go to: https://community.rstudio.com/new-topic
2. 选择 Category: **"R Programming"** 或 **"Package Development"**
3. 标题: `[New Package] sleepcleanr: Auditable pipeline for messy sleep diary data`
4. 正文: 复制上面的 markdown
5. 点 "Create Topic"

**预期**: 
- 100-300 views (Posit Community 是技术用户社区)
- 10-30 回复 (会有人问方法问题)
- 高质量反馈 (这个社区关心方法论)

---

## 完成后

回复: "Posit Community posted ✓"

