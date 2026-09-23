# fasttrack_review.csv 独立标注任务说明

## 背景

`fasttrack_review.csv` 里的 23 行是 `disambiguation_timegap_candidates.R` 用贝叶斯方法从
46 个候选行里筛出来的高置信度候选（`posterior_p_error` ≥ 99%，SOL crosscheck 结果为
"good"）——判断依据是 bed/sleep/awake/getup 四个时间字段之间出现了 3-6 小时的负向
时间差，这是 AM/PM 误填/误读的典型信号，但最终是不是真的填错了，需要人看过这个人
自己的历史记录之后再判断。

**数据来源链（可复现）**：`validation/reproduce_fasttrack_chain.R` 一条命令重跑
derive → disambiguate → promote → rebuild 全链，每步写 `*.provenance.json`（md5 审计）。

## 你要做的事

对 `fasttrack_review.csv` 里每一行：

1. 看 `Row_ID / PID / Day / Raw_*` 那几列——这是参与者**原始输入**（比如
   `2022-01-13 01:15 l`，日期 + hh:mm + 拨号；**C = AM, l = PM**）
2. 跑 `Rscript validation/query_pid.R <PID>`，看这个人自己全部有数据的天数的
   bed/sleep/awake/getup，被标记的那天会显示 `<-- FLAGGED`
3. 对比：这个人平常几点睡、几点醒？被标记的这一天是不是明显偏离了自己的基线
   （比如平时 sleep 都是 00:xx–02:xx，这天却是反过来的 pattern）——
   **偏离基线、且 AM/PM 翻转后能让睡眠时长变得合理 → 倾向判断为真实的 AM/PM 误填**；
   如果这个人本来就有类似的不规律记录、或者翻转后反而不合理 → 倾向判断为真实行为，
   不是误填
4. 在 `fasttrack_review.csv` 的 `Accept` 列填 Yes/No（是否接受 `Time_*_Corrected` 的
   翻转结果），`Notes` 列写一句话说明判断依据
5. 每行独立判断，判断的时候**不要先看别人（包括我）的结论，也不要互相讨论**，
   等你和 Maia 都各自填完整个文件之后再对比

## query_pid.R 用法

```bash
Rscript validation/query_pid.R 10989          # 看这个人全部天数
Rscript validation/query_pid.R 10989 4        # 只看第4天
Rscript validation/query_pid.R --interactive  # 交互模式，反复输入pid查
```

## 表列说明

| 列 | 含义 |
|---|---|
| `Raw_Bed/Sleep/Awake/Getup` | 参与者原始输入：`观测日 hh:mm 拨号`（拨号 C=AM, l=PM） |
| `Time_*_Original` | 同 Raw（原始值） |
| `Time_*_Corrected` | 忠实解码值（`01:15 l` → `13:15`）——disambiguation 用的解码 |
| `SOL_SelfReport_min` / `SOL_Calculated_min` / `SOL_Diff_min` | 自报 vs 计算 SOL |
| `SOL_Match` | SOL 交叉验证结果（good = 支持 ±12h 翻转） |
| `Confidence_Pct` | 贝叶斯后验 P(error) |
| `Accept` / `Notes` | **你填**：Yes/No + 判断依据 |

注意：`Time_*_Corrected` 是**忠实解码**（不是自动修正建议）——`01:15 l` 显示为
`13:15`，与 awake 的 `09:55` 形成负 gap，这正是需要你判断的矛盾。是否接受把它翻回
AM（`01:15`）由你的 `Accept` 决定。

## 完成后

两份独立标注完的 `fasttrack_review.csv`（各自存一份，比如
`fasttrack_review_cyra.csv` / `fasttrack_review_maia.csv`）可以对比 `Accept` 列，
算一致率 / Cohen's kappa（每行判断独立，不预先讨论是算 kappa 的前提）。

## 历史背景（2026-09-18 调试记录）

- 该表的显示曾有多层 bug：merge 行错位（跨 participant 时间串位）、.x/.y 列污染、
  AM/PM 方言未解码、raw_row_id 数据快照漂移——现已全部修复（零 join 重建 +
  match 索引取原始值 + provenance 审计）
- 23 行 = 46 候选 − 23 已解决（已解决行在 manual_error_corrections.csv 等有 ground
  truth）；另 3 行 hard cases（PID 3539 day 13、5239 day 6、6855 day 9）在
  `disambiguation_worksheet_tiered_fullreview_*.csv`，走双盲流程，不在本表