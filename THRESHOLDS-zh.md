# 检测阈值——默认值、依据，以及何时需要修改

[English](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md) ·
中文

标记阈值是**科学判断，不只是配置值。**
默认值**刻意偏宽松**，适用于**一般健康成人样本**：目标是抓住数据录入错误和明显离群值，而不是诊断失眠。对临床样本（失眠、老年、倒班），请逐行重新审视。

> **来源：** 默认值是在健康年轻成人的大学生 EMA
> 样本上调得的。请在这里记录你自己研究的人群，方便下游用户知道参照对象。

## 如何使用这些值

- **对我们自己的研究数据，下表的值是固定的。**
  它们就是该研究运行时用的规则。步骤 5 的限值（错误：7、7、24
  小时；异常记录：3、15、3、3 小时）写在项目 2026 年 3
  月的逻辑文档里。从第一个版本（2026 年 7
  月）起，代码一直使用这些值，直到它们改为可配置（见
  `NEWS.md`）。要复现我们的结果，请保持默认值。
- **对你自己的数据由你决定。** 表中每个键都可以在你的配置 YAML
  里设置（带注释的示例在
  `inst/config_template.yaml`）。管线会应用你设定的值并如实报告，不会替你选规则。值存在但不是数字时，运行会停止。
- **每次运行都会说明它用了哪些规则。** 运行时会打印
  `=== Rules in effect for this run ===`，并把同样的清单存为
  `output/effective_rules.csv`（键、值、默认值、该值来自默认还是你的配置、含义）。请把这个文件和结果放在一起，并在方法部分引用。要比较两次运行，比较它们的
  `effective_rules.csv` 即可。

## 阈值表

| 配置键 | 默认值 | 标记什么 | 依据 |
|----|----|----|----|
| `classification.metric_validation.sol.excessive_minutes` | `120` | SOL \> 2 小时 | 非常宽松。临床 SOL 标志约 30 分钟（Lichstein 等）。2 小时只抓严重离群值。 |
| `classification.metric_validation.se.min_valid_percent` | `0` | SE \< 0% | 结构上不可能 → 一律标记 |
| `classification.metric_validation.se.max_valid_percent` | `100` | SE \> 100% | 结构上不可能 → 一律标记 |
| `classification.flag_severity.poor_efficiency_threshold_pct` | `70` | SE \< 70% | 宽松。失眠切点约 85%。70% 标出明显偏低的效率。 |
| `classification.flag_severity.high_sol_threshold_hours` | `1` | SOL \> 1 小时 | 相对 30 分钟的临床标志而言宽松。 |
| `classification.flag_severity.high_waso_threshold_hours` | `1.5` | WASO \> 1.5 小时 | 宽松。临床 WASO 标志通常 \> 30 分钟。 |
| `classification.metric_validation.tst_tib_ratio.min_ratio` | `0.5` | TST/TIB \< 0.5 | 相当于 SE \< 50% |
| `classification.metric_validation.tst_tib_ratio.max_ratio` | `1.0` | TST/TIB \> 1.0 | 不可能 → 硬错误 |
| `timestamp.sequence.max_gap_hours` | `12` | AM/PM 翻转触发 | 假设不存在 ≥ 12 小时的合理间隔 |
| `classification.step5.error.bed_to_sleep_max_hours` | `7` | \|入睡 − 就寝\| \> 7 小时算错误 | 没有人要花 7 小时才睡着；更可能是两个时间里有一个填错了 |
| `classification.step5.error.awake_to_getup_max_hours` | `7` | \|起床 − 醒来\| \> 7 小时算错误 | 醒来后在床上躺超过 7 小时不合理 |
| `classification.step5.error.sleep_to_awake_max_hours` | `24` | \|醒来 − 入睡\| \> 24 小时算错误 | 一段睡眠不可能超过一天 |
| `classification.step5.unusual.sleep_to_awake_min_hours` / `_max_hours` | `3` / `15` | 睡眠时段 \< 3 小时或 \> 15 小时算异常 | 有可能，但值得看一眼 |
| `classification.step5.unusual.bed_to_sleep_max_hours` | `3` | 入睡 − 就寝 \> 3 小时算异常 | 多数人一小时内入睡 |
| `classification.step5.unusual.awake_to_getup_max_hours` | `3` | 起床 − 醒来 \> 3 小时算异常 | 醒来后在床上停留很久 |
| `review.clean_categories` | `clean`、`equal_time_ok`、`reasonable_unusual` | 审核状态表中算作“现已通过”的最终类别 | 由你定义。在我们的研究里，缺少某个时间的记录（`skipped_na`）不算通过，所以仍列为未通过 |
| `second_review.on_invalid_rows` | `skip` | `skip`：`pid` 或 `day_num` 不是数字的二次审核行会被跳过，并列在 `output/second_review_rows_skipped.csv`；`stop`：停止运行 | 这样的行无法确定对应哪条记录 |
| `duration_clock_rule.enabled` | `true` | `false` 会关闭步骤 6.5 中对被重新解读的 SOL / WASO 文本所用的时刻规则 | 默认开启；在研究数据上会改变约十几个交付值；每个决定都记录在 `output/duration_clock_rule_log.csv` |
| `duration_clock_rule.tolerance_min` | `5` | SOL：键入的时间须在记录的入睡时间前后这么多分钟之内（12 小时表盘） | 依据研究中 35 条被标记的 SOL 条目选定（估计精度约 90%）；请用你的数据调整 |
| `duration_clock_rule.window_min` | `60` | SOL：键入的时间须在记录的就寝时间之后 0 到这么多分钟 | 研究数据中，被键入为 00:MM 的正常自报 SOL 最多到 55 分钟 |
| `duration_clock_rule.near_min` | `15` | 键入的时间与就寝或入睡时间相差在这么多分钟之内，视为像时刻 | 落在此范围内、但不满足上面两个限值的条目留给人工处理 |
| `manual_corrections.manual_overrides_parser` | `false` | `true`：人工的睡眠指标时长行优先于时长解析器 | 长期以来的行为是解析器优先；每一条被跳过的行都列在 `output/manual_corrections_not_applied.csv` |

## 建议的配置注释

建议在每个阈值旁边直接写上依据：

``` yaml
  flag_severity:
    poor_efficiency_threshold_pct: 70   # 宽松（健康样本）。临床切点约 85%
    high_sol_threshold_hours: 1         # 宽松。临床标志约 30 分钟
    high_waso_threshold_hours: 1.5      # 宽松。临床标志约 30 分钟
  metric_validation:
    sol:
      excessive_minutes: 120            # 抓严重离群值，不是临床标准
```

## 验证对这些默认值说明了什么（以及没说明什么）

这些值是**参考值，不是优化过的值。** 合成基准在 20
个网格点上扫描了相邻对调阈值（1 到 5 小时）和 AM/PM 翻转阈值（8 到 14
小时）：召回率始终在 0.9950 到 0.9957
之间，误报始终为零。因此在这个范围内，基准对这两个阈值*不敏感*；它分不出
3 小时与 2 小时或 4 小时的区别，也不能证明 3 小时和 12
小时是最优的。在研究数据上，没有任何一个阈值使平均总睡眠时间改变超过
0.93 分钟，或使可分析行数改变超过
0.70%。默认值是在健康年轻成人样本上设定的，应当用你自己的数据重新核对（`validation/synthetic/operating_point_sweep.R`
可作模板）。

## 参考文献

- Lichstein 等 (2003)，*Behaviour Research and
  Therapy*——失眠的量化标准（30 分钟 SOL/WASO，约 85% SE）
- AASM 标准的体动记录仪-日记报告惯例
