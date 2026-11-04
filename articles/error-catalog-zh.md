# 错误类型清单

[English
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/error-catalog.md)

本页列出清洗管线的验证所考虑的录入错误，让读者看到测了什么、每类错误从哪里来、
管线应当怎么处理。这里只有数量和机制，没有参与者编号，也没有逐行数据。

机器可读的源文件是仓库里的
`validation/synthetic/error_catalog.yaml`。本页应与它一致；
不一致时以该文件为准，本页即已过期。

## 清单怎么数

清单共 **17 项**：

- **1 个阴性对照**（`no_error_control`）：行保持原样，用来测误报。
- **16 个错误类型**。其中 **14 个在已提交的合成基准里注入**（7,000
  行，5,391 行被注入错误， 1,609
  行为干净对照）。另外两个不在这次跑里：`awake_misread_as_waso`
  只有文档、还没有注入函数； `awake_is_getup`
  是可选项，单独跑过（见下）。

所以 README 里的”14
类错误”和[验证方法学](https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology-zh.md)里
2026-09-02 重跑所说的 “15 类”是同一个基准：14
个注入的错误类型；把干净对照也算一类就是 15。

## 错误类型从哪里来

每个类型带下面的一个或多个标签。标签有意义：只用项目已见过的错误建基准，测出来的是
“规则对它们当初针对的错误”。

| 标签         | 含义                                         |
|--------------|----------------------------------------------|
| `observed`   | 本项目自己的数据里见过                       |
| `literature` | 已发表的睡眠日记研究（SHUTi、RESTING）报告过 |
| `blind_spot` | 理论上会发生，且在加入专门检查之前管线抓不到 |

第三类来源是普通人填表时的行为：AM/PM
选错、把起床时间填成下床时间、在问时长的地方打了钟点。
已发表研究给了比率的，在下面注明；没有的，清单照实说，不补数字。

## 错误类型

### 钟点（上床、入睡、醒来、下床）

| 类型 | 发生了什么 | 来源 | 管线怎么处理 |
|----|----|----|----|
| `ampm_swap` | 晚上的时间 AM/PM 选错，出现 12 小时以上的间隔 | observed, literature | 第 4 步在能恢复合理顺序时减 12 小时；否则进入审核 |
| `adjacent_swap_bed_sleep` | 上床和入睡填到了对方的栏，间隔不到 3 小时 | observed, literature | 第 4 步换回来 |
| `adjacent_swap_sleep_awake` | 入睡和最后醒来对调，间隔不到 3 小时 | observed, literature | 第 4 步换回来 |
| `adjacent_swap_awake_getup` | 醒来和下床对调，间隔不到 3 小时 | observed, literature | 第 4 步换回来 |
| `adjacent_swap_large_gap_left_clean` | 对调且间隔超过 3 小时，换序规则有意不碰 | observed, blind_spot | 交给顺序检查去标记 |
| `compound_ampm_and_swap` | 同一晚既有 AM/PM 错又有对调 | observed, blind_spot | 两条规则各只看一对，管线可能怪错栏；该类型用来度量这个风险 |
| `awake_is_getup` | 把下床时间填进了醒来栏，两者相同 | literature | 相等的时间是合法的，所以这种形式与真实填写分不开。可选项，作为压力测试 |
| `awake_misread_as_waso` | 把夜里的短暂醒来当成最后醒来 | observed, blind_spot | 仅有文档，尚无注入函数 |

### 时长（入睡潜伏期、入睡后清醒时间）

| 类型 | 发生了什么 | 来源 | 管线怎么处理 |
|----|----|----|----|
| `field_misentry_sol` | 在问入睡潜伏期的地方打了钟点 | observed, blind_spot | 第 1.5 步检查；1.8.0 起第 6.5 步在所填时间贴近记录的入睡时间时重算潜伏期 |
| `field_misentry_waso` | 在问入睡后清醒时间的地方打了钟点 | blind_spot | 第 1.5 步检查；1.8.0 起像钟点的值置为缺失 |
| `format_no_colon` | 时长没打冒号 | observed | 区间解析器按位数读 |
| `format_malformed_colon` | 冒号位置不寻常 | observed | 区间解析器按模式重组 |
| `mmss_confusion` | 很短的时长，文本可以读成分:秒 | observed | MM:SS 规则可能读错；该条被标记审核 |
| `implausible_duration` | 格式正确但极端的时长，与本人基线无关 | literature | 第 8 步的行级阈值 |
| `cross_participant_spike` | 格式正确，但远超本人通常范围 | observed | 第 8.5 步 |
| `sol_window_contradiction` | 所报潜伏期放不进上床与入睡之间 | observed, blind_spot | 第 8 步标记 |

### 对照

| 类型               | 发生了什么                             |
|--------------------|----------------------------------------|
| `no_error_control` | 行保持原样，用来数误报和被改动的干净行 |

## 顺序颠倒的夜晚，按机制分

一晚的四个时间应满足：上床 ≤ 入睡 ≤ 醒来 ≤
下床。不满足就是顺序颠倒。多数并不是两栏对调。
研究数据里，四个时间都读得出的 2,848 晚中有 140 晚（4.9%）顺序颠倒；其中
6 晚下床值不可用， 不算顺序问题，剩 134 晚（4.7%）。按机制：

| 机制                                | 夜数 |
|-------------------------------------|------|
| 两栏对调                            | 47   |
| 单栏差 12 小时                      | 57   |
| 两栏一起差 12 小时                  | 14   |
| 醒来早于上床                        | 6    |
| 所有间隔都在舍入范围（10 分钟以内） | 3    |
| 任何单一改法都解释不了              | 7    |
| 下床值不可用                        | 6    |

包里的
[`classify_reversals()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/classify_reversals.md)
把每一晚归入其中一类，[`reversal_summary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/reversal_summary.md)
统计数量，图 33 画出结果。 具体类别和阈值见函数帮助。

研究数据里，自动规则修好了 140 晚中的 89 晚，人工审核修了另 49
晚。入睡一栏差 12 小时和一对对调， 规则几乎全中；上床差 12
小时或整晚一起挪的，规则几乎无效，需要人来处理。

## 基准和外部比率给出了什么

- 已提交的合成基准里，“检出”指这一行被标记，不是数值被恢复。修正另外按类型报告，见
  [验证报告](https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology-zh.md)。
- 两项已发表研究给出的比率不来自本项目数据。SHUTi 报告 45,598 份日记中有
  487 份（1.07%） 需要日期或 AM/PM 修正。RESTING（3,382
  个日记日）报告起床时间与下床时间混淆是最常见的录入错误 （150
  个日记日），另有 28 个 AM/PM 错误。据此建了两种按 5%
  行数的错误混合，注入本项目的合成日记数据。
  第一种（醒来与下床对调）：每个被注入的行都被修正。第二种（下床时间填进两栏）：一个都没检出，
  因为相等的时间是合法的；在所述假设下，它可能带来的平均总睡眠时间偏差上限约
  0.8 分钟。 两种混合都没有改动干净行。

## 没有外部比率的类型

多数时长类型（格式失误、MM:SS
混淆、突刺）在睡眠日记研究里没有已发表的比率。清单保留了本项目
自己审计中观察到的比率作为参照，并如实标注，不把它当作其他数据里的比率。

## 各部分在哪里

| 内容 | 位置 |
|----|----|
| 机器可读的清单 | `validation/synthetic/error_catalog.yaml` |
| 注入函数与基准运行 | `validation/synthetic/` |
| 外部比率的混合 | `validation/synthetic/prevalence_grid.R` |
| 顺序颠倒的分类 | [`classify_reversals()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/classify_reversals.md)、[`reversal_summary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/reversal_summary.md) |
| 时长的钟点规则 | 第 6.5 步，`config_default.yaml` 里的 `duration_clock_rule` |
| 真实数据上的图 | F33（顺序颠倒的夜晚，按机制）、F34（第 6.5 步对每条被重新解读的 SOL / WASO 条目做了什么）、F35（像钟点的 SOL 条目与本人上床、入睡时间的对照）；卡片见[如何解读输出](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output-zh.md) |

F34 和 F35 读的是第 6.5
步的日志，数的是管线实际处理过的条目。设计规则时另做过一次对原始输入的扫描，
数的是原始文本里的全部候选（72
条）。两个数回答的是不同的问题，不必相等。
