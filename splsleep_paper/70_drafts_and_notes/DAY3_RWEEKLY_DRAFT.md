# DAY 3: R Weekly Pitch — 完整草稿

**To**: submit@rweekly.org  
**Subject**: Package: sleepcleanr — auditable sleep diary cleaning pipeline  
**Time**: 10 minutes

---

## 📧 完整邮件内容（复制粘贴）

```
Subject: Package: sleepcleanr — auditable sleep diary cleaning pipeline

Hi R Weekly team,

I'd like to submit sleepcleanr, an R package for reproducible, auditable 
cleaning of sleep EMA (ecological momentary assessment) diary data.

## Why it matters

Sleep diary data looks simple ("bedtime: 10:30 PM, wake: 7:00 AM") but is 
actually messy in practice:
- AM/PM swaps and duration misreadings (120 min entered as "02:00")
- Temporal order violations (fell asleep before bedtime?)
- Self-report noise (±75 min variance in sleep onset latency)

Most analyses either skip cleaning (reproducibility crisis) or clean ad-hoc 
(no audit trail).

## What sleepcleanr does

- **Detects, never silently fixes**: flags 1,048 suspicious records, 0 auto-corrections
- **Auditable**: every correction logged in reversible CSV ledgers
- **Validated**: 9-step validation chain (0.995 synthetic recall + 92% real-data 
  improvement + robustness multiverse proof)
- **Reproducible**: YAML config, full documentation, 308 unit tests

## Get started

```r
install.packages("sleepcleanr")
library(sleepcleanr)
run_pipeline()  # demo on synthetic data
```

## Links

- GitHub: https://github.com/cyracaid/sleepdiary-cleaner
- Docs: https://cyracaid.github.io/sleepdiary-cleaner/
- CRAN: [just submitted]

This is a methodologically transparent solution to a real pain point in 
longitudinal behavioral research.

Thanks!
```

---

## ✅ 操作步骤

1. 复制上面的邮件内容
2. 打开你的邮箱
3. 新建邮件 → submit@rweekly.org
4. 粘贴内容
5. 发送

**预期**: R Weekly 会在下一期 newsletter (usually Friday) 审核并可能收录 
→ ~10k R developers 看到

---

## 完成后

回复: "R Weekly submitted ✓"

