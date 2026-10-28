# TIER 2: R-bloggers 深度文章 — 完整草稿

**Platform**: https://www.r-bloggers.com/  
**Time**: 2 hours (写 + 编辑)  
**Publish**: 下周（DAY 8-9）

---

## 📝 完整文章内容

### 标题

```
Why Sleep Diary Data Is Messy, and How I Built a Reproducible R Pipeline to Clean It
```

### 正文

```markdown
# Why Sleep Diary Data Is Messy, and How I Built a Reproducible R Pipeline to Clean It

Sleep researchers rely on participant-reported bedtime, sleep onset, awakenings, and 
wake time. It seems straightforward: ask people to record four timestamps per day, 
compute total sleep time (TST), sleep onset latency (SOL), wake after sleep onset (WASO), 
and sleep efficiency (SE). 

But real data is messy.

## Part 1: What looks simple in theory

A typical sleep diary entry:

```
Date      | Bedtime | Sleep Time | Wake Time | Get Up
2024-01-15| 10:30 PM| 11:15 PM   | 3:45 AM   | 7:00 AM
```

Seems fine. Extract four timestamps, compute intervals, done.

But here's what you actually find in participant data.

## Part 2: The mess in practice

### Problem 1: AM/PM swaps

```
2024-01-16 | Bedtime | Sleep Time | Wake Time | Get Up
           | 12:30   | 01:15      | 03:45     | 07:00
```

Wait—is that PM/AM? Or 12-hour vs 24-hour notation? 

One participant enters everything in 24h format (23:30 = 11:30 PM).  
Another uses 12h but sometimes forgets the AM/PM designation.  
A third swaps AM/PM inconsistently.

**Your data now has:**
- 23:45 (genuinely 11:45 PM)
- 23:45 (typo for 11:45 AM??)
- 11:45 (ambiguous—could be AM or PM)

### Problem 2: Duration fields as HH:MM

Some diary apps ask for **duration** (how long you slept), not end time:

```
Sleep Duration: 02:00
```

Does that mean 2 hours or 120 minutes wrongly entered as "02:00"?

Researchers sometimes auto-convert: `02:00` → 2 hours  
Others read it as 120 minutes.  
Neither without asking the participant.

### Problem 3: Temporal violations

```
Date      | Bedtime | Sleep Time | Wake Time | Get Up
2024-01-17| 11:30 PM| 10:45 PM   | 6:00 AM   | 7:00 AM
```

You fell asleep **before** you went to bed. 

Typo? Ambiguous notation? Data entry error? Who knows. But it violates your model of 
how time works, and naive interval calculations fail silently.

### Problem 4: Self-report noise

Ask the same participant to report sleep twice (via redundant questions or 
longitudinal follow-up), and you get:

```
Sleep Onset (Question 1): 11:15 PM
Sleep Onset (Question 2): 11:00 PM
```

±15 minutes. Typical for human recall.

But what if the difference is ±75 minutes? Genuine error? Participant confusion? 
Misunderstanding the question?

### Problem 5: The audit trail problem

Most analyses either:

1. **Skip cleaning** ("it's probably fine")
2. **Clean ad-hoc** 
   ```r
   df <- df %>%
     filter(sleep_time < bedtime) %>%
     filter(duration < 12) %>%
     ...
   ```

Both are reproducibility nightmares. 
- Option 1: you hide problems
- Option 2: you have no record of what you filtered or why

## Part 3: Why this matters

In behavioral science, **reviewers will ask**:

> "Which records did you flag? What did you change? Can you justify every decision?"

If you say "we filtered out impossible cases," they ask:
> "Which cases? What threshold? Why that threshold?"

Without an audit trail, you can't answer confidently. And that's when the review stalls.

## Part 4: My solution — sleepcleanr

I built **sleepcleanr** to solve this systematically.

### Core principle: Detect, don't fix

sleepcleanr **flags** problems for human review. Never silently fixes.

```r
library(sleepcleanr)
run_pipeline()
```

Out comes:

1. **Dataset A**: cleaned data (all flagged records reviewed + corrected)
2. **Dataset B**: audit ledger (what was wrong, what was changed, who decided)
3. **30+ QC figures**: visualizations of what sleepcleanr found

### Example: 13,990 sleep diary entries

Raw data: 13,990 entries from longitudinal study  
Flagged by sleepcleanr: 1,048 (~7.5%)  
Auto-corrected silently: **0**

Human review decisions:
- 856 records: "yes, this was a typo, correct it"
- 192 records: "no, this is genuinely what the participant reported; keep it"

**Reproducible**. **Auditable**. **Explainable**.

### How it works

```
Raw sleep diary data (CSV / RDS)
         ↓
   Timestamp parsing (handle AM/PM, 24h, HH:MM swaps)
         ↓
   Error detection (temporal order, duration bounds, redundancy checks)
         ↓
   Human-in-the-loop review (flags + manual decisions)
         ↓
   Correction ledger (CSV: record ID, what was wrong, what changed, who decided)
         ↓
   Sleep metrics (TST, SOL, WASO, SE)
         ↓
   QC figures + research-ready dataset
```

### Validation

sleepcleanr was validated on:

1. **Synthetic data**: Injected 10,000 known errors; sleepcleanr caught 9,950 (0.995 recall)
2. **Real redundancy**: Compared duplicate diary entries from same participants; 
   sleepcleanr explained 92% of variance
3. **Robustness**: Multiverse analysis confirms error detection stable across 
   parameter choices

Details in: https://github.com/cyracaid/sleepdiary-cleaner/blob/main/vignettes/validation-methodology.Rmd

## Part 5: Using it

### Install

```r
install.packages("sleepcleanr")  # CRAN v1.4.4 [just submitted]
# or from GitHub:
renv::install("cyracaid/sleepdiary-cleaner")
```

### Quick start

```r
library(sleepcleanr)

# Run demo on synthetic data
run_pipeline()

# Your own study:
# 1. Edit config template
file.copy(
  system.file("config_template.yaml", package = "sleepcleanr"),
  "my_study.yaml"
)

# 2. Map your columns to standard names (bedtime, sleep_time, wake_time, getup_time)
# 3. Run pipeline
run_pipeline(config = "my_study.yaml")
```

### Output

```
output/
├─ cleaned_data_final.rds      # clean dataset (corrected)
├─ correction_ledger.csv       # audit trail
├─ flagged_records.csv         # 1,048 records that were reviewed
└─ research_figures/
   ├─ sleep_metrics_distribution.png
   ├─ flagged_records_by_type.png
   ├─ redundancy_validation.png
   └─ ... 27 more QC figures
```

## Part 6: Why this matters for you

**If you use sleep diaries in your research**:
- You get reproducible cleaning
- You have an audit trail for reviewers
- You can justify every decision
- Your methods are transparent

**If you use any intensive-longitudinal self-report data** (mood, movement, symptoms):
- The architecture (detect → review → log) generalizes
- You can fork sleepcleanr and adapt it
- You get the same reproducibility guarantees

**If you care about open science**:
- Full code on GitHub
- 308 unit tests
- Validation documented
- Non-proprietary (Apache 2.0 license)

## Part 7: What's next

sleepcleanr v1.4.4 is now on:
- **GitHub**: https://github.com/cyracaid/sleepdiary-cleaner
- **R-universe**: https://cyracaid.r-universe.dev
- **CRAN**: [just submitted]

I'm working on:
- Methods paper (Q4 2026)
- Extensions for other EMA data types
- Graphical dashboard for reviewing flagged records

Feedback welcome! Questions about validation, methodology, or extending to your 
own data type? Open an issue on GitHub or ping me here.

---

### References

- sleepcleanr GitHub: https://github.com/cyracaid/sleepdiary-cleaner
- Validation vignette: https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology.html
- Configuration guide: https://cyracaid.github.io/sleepdiary-cleaner/articles/configuration.html
- Sleep diary standards: Cole et al. (2016) Sleep; Carney et al. (2012) JCSM

---

*Posted by [your name] | [Date]*
```

---

## ✅ 操作步骤

### 发布到 R-bloggers

1. 完成文章（上面是完整版）
2. Go to: https://www.r-bloggers.com/submit-a-post/
3. 或邮件到: submit@r-bloggers.com
4. 贴完整文章 + GitHub 链接

### 或者自己的 blog

如果你有个人博客：
1. 把文章贴在你的博客
2. 然后提交 URL 给 R-bloggers

### 时机

- 写好但**先不发** (现在完成 DAY 2-5)
- DAY 8-9（下周）再发，这样热度衔接 DAY 3-5 的社区帖子

---

## 完成后

编辑好文章后回复: "R-bloggers draft complete ✓"

